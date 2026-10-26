#include "chain_solver.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <algorithm>
#include <cmath>

using namespace godot;

// The same numbers as spring_chains.gd's.
static const double STEP = 1.0 / 60.0;
static const int MAX_STEPS = 4;
static const Vector3 PROBES[3] = { Vector3(0, 0, 0), Vector3(-0.1, 0, 0), Vector3(0.1, 0, 0) };
static const double CUSHION = 0.025;
static const int NET_HIPS = 4;
static const double NET_SWING = 1.5;
static const double NET_SWING_TOP = 1.0;
static const double NET_TURN = 0.9;
static const double NET_IN = 40.0;
static const double NET_OUT = 8.0;
static const double NET_SHEET = 0.012;
static const double NET_MID = 0.12;
static const double PI_ = 3.14159265358979323846;

void ChainSolver::_bind_methods() {
	ClassDB::bind_static_method("ChainSolver", D_METHOD("api"), &ChainSolver::api);
	ClassDB::bind_method(D_METHOD("set_colliders", "nodes", "a", "b", "r"), &ChainSolver::set_colliders);
	ClassDB::bind_method(D_METHOD("add_chain", "rest", "bones", "k", "d", "g", "col", "probes", "side_of", "side"), &ChainSolver::add_chain);
	ClassDB::bind_method(D_METHOD("set_tuned", "back", "passes", "net", "caps"), &ChainSolver::set_tuned);
	ClassDB::bind_method(D_METHOD("set_gravity", "g"), &ChainSolver::set_gravity);
	ClassDB::bind_method(D_METHOD("reset"), &ChainSolver::reset);
	ClassDB::bind_method(D_METHOD("simulate", "anchor", "skel", "delta"), &ChainSolver::simulate);
	ClassDB::bind_method(D_METHOD("get_acc"), &ChainSolver::get_acc);
	ClassDB::bind_method(D_METHOD("get_net_acted"), &ChainSolver::get_net_acted);
	ClassDB::bind_method(D_METHOD("get_points", "ci"), &ChainSolver::get_points);
	ClassDB::bind_method(D_METHOD("get_lp", "ci"), &ChainSolver::get_lp);
	ClassDB::bind_method(D_METHOD("get_lc", "ci"), &ChainSolver::get_lc);
}

static PackedVector3Array to_packed(const std::vector<Vector3> &v) {
	PackedVector3Array out;
	out.resize(v.size());
	Vector3 *w = out.ptrw();
	for (size_t i = 0; i < v.size(); i++) {
		w[i] = v[i];
	}
	return out;
}

void ChainSolver::set_colliders(const Array &nodes, const PackedVector3Array &a, const PackedVector3Array &b, const PackedFloat32Array &r) {
	cols.clear();
	cols.resize(nodes.size());
	cw.resize(nodes.size());
	for (int i = 0; i < nodes.size(); i++) {
		Object *o = nodes[i];
		cols[i].node = o ? o->get_instance_id() : 0;
		cols[i].a = a[i];
		cols[i].b = b[i];
		cols[i].r = r[i];
	}
}

void ChainSolver::add_chain(const PackedVector3Array &rest, const PackedInt32Array &bones, double k, double d, double g,
		const PackedInt32Array &col, const PackedVector3Array &probes, int side_of, double side) {
	Chain c;
	for (int i = 0; i < rest.size(); i++) {
		c.p.push_back(rest[i]);
	}
	for (int i = 0; i + 1 < rest.size(); i++) {
		c.rest_dir.push_back((rest[i + 1] - rest[i]).normalized());
	}
	for (int i = 0; i < bones.size(); i++) {
		c.bones.push_back(bones[i]);
	}
	for (int i = 0; i < col.size(); i++) {
		c.col.push_back(col[i]);
	}
	for (int i = 0; i < probes.size(); i++) {
		c.probe.push_back(probes[i]);
	}
	c.turn.assign(std::max<int>(rest.size() - 1, 0), 0.0f);
	c.k = k;
	c.d = d;
	c.g = g;
	c.side_of = side_of;
	c.side = side;
	c.x = c.p;
	c.px = c.p;
	c.lp = c.p;
	c.lc = c.p;
	chains.push_back(c);
	drawn.resize(chains.size());
}

void ChainSolver::set_tuned(double back, int passes, bool p_net, const PackedInt32Array &caps) {
	tuned = true;
	back_z = back;
	iters = passes;
	net = p_net;
	net_caps.clear();
	for (int i = 0; i < caps.size(); i++) {
		net_caps.push_back(caps[i]);
	}
}

// Each collider's drawn transform, once a frame (a frame's steps all saw the same one).
void ChainSolver::read_colliders() {
	for (Collider &c : cols) {
		Node3D *n = Object::cast_to<Node3D>(ObjectDB::get_instance(c.node));
		c.ok = n != nullptr && n->is_inside_tree();
		if (c.ok) {
			c.t = n->get_global_transform_interpolated();
		}
	}
}

void ChainSolver::world_caps() {
	for (size_t i = 0; i < cols.size(); i++) {
		const Collider &c = cols[i];
		cw[i].ok = c.ok;
		if (c.ok) {
			cw[i].a = c.t.xform(c.a);
			cw[i].b = c.t.xform(c.b);
			cw[i].r = c.r * c.t.basis.get_scale().x;
		}
	}
}

void ChainSolver::snap(const Transform3D &g) {
	for (Chain &c : chains) {
		for (size_t i = 0; i < c.p.size(); i++) {
			c.x[i] = g.xform(c.p[i]);
		}
		c.px = c.x;
	}
}

Vector3 ChainSolver::push_out(const Vector3 &pt, const Cap &cap) {
	const Vector3 ab = cap.b - cap.a;
	double t = 0.0;
	const double l2 = ab.length_squared();
	if (l2 > 1e-8) {
		t = CLAMP((pt - cap.a).dot(ab) / l2, 0.0, 1.0);
	}
	const Vector3 closest = cap.a + ab * t;
	const Vector3 off = pt - closest;
	const double dist = off.length();
	if (dist >= cap.r) {
		return pt;
	}
	if (dist < 1e-5) {
		return closest + Vector3(0, 0, cap.r);
	}
	return closest + off / dist * cap.r;
}

void ChainSolver::closest_segments(const Vector3 &p1, const Vector3 &q1, const Vector3 &p2, const Vector3 &q2,
		Vector3 &on1, Vector3 &on2, double &s_out) {
	const Vector3 d1 = q1 - p1;
	const Vector3 d2 = q2 - p2;
	const Vector3 r = p1 - p2;
	const double a = d1.dot(d1);
	const double e = d2.dot(d2);
	const double f = d2.dot(r);
	double s = 0.0;
	double t = 0.0;
	if (a <= 1e-10) {
		t = e > 1e-10 ? CLAMP(f / e, 0.0, 1.0) : 0.0;
	} else {
		const double c = d1.dot(r);
		if (e <= 1e-10) {
			s = CLAMP(-c / a, 0.0, 1.0);
		} else {
			const double b = d1.dot(d2);
			const double den = a * e - b * b;
			s = den > 1e-10 ? CLAMP((b * f - c * e) / den, 0.0, 1.0) : 0.0;
			t = (b * s + f) / e;
			if (t < 0.0) {
				t = 0.0;
				s = CLAMP(-c / a, 0.0, 1.0);
			} else if (t > 1.0) {
				t = 1.0;
				s = CLAMP((b - c) / a, 0.0, 1.0);
			}
		}
	}
	on1 = p1 + d1 * s;
	on2 = p2 + d2 * t;
	s_out = s;
}

Vector3 ChainSolver::push_segment(const Vector3 &a, const Vector3 &b, const Cap &cap) {
	Vector3 on1, on2;
	double s;
	closest_segments(a, b, cap.a, cap.b, on1, on2, s);
	const Vector3 off = on1 - on2;
	const double dist = off.length();
	if (dist >= cap.r) {
		return b;
	}
	const Vector3 n = dist > 1e-5 ? off / dist : Vector3(0, 0, 1);
	const double t = std::max(s, 0.35);
	return b + n * std::min((cap.r - dist) / t, cap.r * 2.0);
}

void ChainSolver::step(const Transform3D &g) {
	const Vector3 grav = gravity * STEP * STEP;
	for (Chain &c : chains) {
		const double keep = 1.0 - c.d;
		c.x[0] = g.xform(c.p[0]);
		c.px[0] = c.x[0];
		for (size_t i = 1; i < c.p.size(); i++) {
			const Vector3 rest_vec = g.basis.xform(c.p[i] - c.p[i - 1]);
			const double seg = rest_vec.length();
			const Vector3 prev = c.x[i - 1];
			const Vector3 cur = c.x[i];
			Vector3 nx = cur + (cur - c.px[i]) * keep + grav * c.g;
			nx = nx.lerp(prev + rest_vec, c.k);
			for (int ci : c.col) {
				if (cw[ci].ok) {
					nx = push_out(nx, cw[ci]);
				}
			}
			const Vector3 d = nx - prev;
			if (d.length_squared() > 1e-10) {
				nx = prev + d.normalized() * seg;
			}
			c.px[i] = cur;
			c.x[i] = nx;
		}
	}
}

void ChainSolver::step_tuned(const Transform3D &g) {
	const Transform3D inv = g.affine_inverse();
	const Vector3 grav = gravity * STEP * STEP;
	Vector3 ow[3];
	for (int o = 0; o < 3; o++) {
		ow[o] = g.basis.xform(PROBES[o]);
	}
	for (Chain &c : chains) {
		const double keep = 1.0 - c.d;
		const size_t n = c.p.size();
		c.x[0] = g.xform(c.p[0]);
		c.px[0] = c.x[0];
		for (size_t i = 1; i < n; i++) {
			const Vector3 cur = c.x[i];
			const Vector3 nx = cur + (cur - c.px[i]) * keep + grav * c.g;
			c.px[i] = cur;
			c.x[i] = nx.lerp(c.x[i - 1] + g.basis.xform(c.p[i] - c.p[i - 1]), c.k);
		}
		for (int it = 0; it < iters; it++) {
			for (size_t i = 1; i < n; i++) {
				const Vector3 prev = c.x[i - 1];
				const double seg = g.basis.xform(c.p[i] - c.p[i - 1]).length();
				const Vector3 d = c.x[i] - prev;
				Vector3 nx = d.length_squared() > 1e-10 ? prev + d.normalized() * seg : c.x[i];
				for (int o = 0; o < 3; o++) {
					for (int ci : c.col) {
						if (cw[ci].ok) {
							nx = push_segment(prev + ow[o], nx + ow[o], cw[ci]) - ow[o];
						}
					}
				}
				Vector3 l = inv.xform(nx);
				if (l.z < back_z) {
					l.z = back_z;
					nx = g.xform(l);
				}
				c.x[i] = nx;
			}
		}
	}
}

void ChainSolver::pose_local(Skeleton3D *skel, const Chain &c, const std::vector<Vector3> &loc) {
	for (size_t i = 0; i < c.bones.size(); i++) {
		const Vector3 a = loc[i];
		Vector3 cur = loc[i + 1] - a;
		Quaternion q;
		if (cur.length_squared() > 1e-10) {
			cur = cur.normalized();
			const Vector3 &rest_dir = c.rest_dir[i];
			q = rest_dir.dot(cur) > -0.9999 ? Quaternion(rest_dir, cur) : Quaternion(Vector3(1, 0, 0), PI_);
		}
		skel->set_bone_global_pose(c.bones[i], Transform3D(Basis(q), a));
	}
}

void ChainSolver::simulate(Node3D *anchor, Skeleton3D *skel, double delta) {
	const Transform3D g = anchor->get_global_transform_interpolated();
	const bool jump = !has_last || g.origin.distance_to(last_origin) > 2.5;
	read_colliders();
	if (!tuned) {
		// (posed against the body as of the last step: see spring_chains.gd's simulate)
		if (jump) {
			snap(g);
			g_step = g;
		}
		has_last = true;
		last_origin = g.origin;
		acc = std::min(acc + delta, STEP * MAX_STEPS);
		if (acc >= STEP) {
			world_caps();
		}
		while (acc >= STEP) {
			acc -= STEP;
			step(g);
			g_step = g;
		}
		const Transform3D inv = g_step.affine_inverse();
		std::vector<Vector3> loc;
		for (const Chain &c : chains) {
			loc.resize(c.x.size());
			for (size_t i = 0; i < c.x.size(); i++) {
				loc[i] = inv.xform(c.x[i]);
			}
			pose_local(skel, c, loc);
		}
		return;
	}
	if (jump) {
		snap(g);
		g_prev = g;
		for (Chain &c : chains) {
			c.lp = c.p;
			c.lc = c.p;
		}
	}
	has_last = true;
	last_origin = g.origin;
	acc = std::min(acc + delta, STEP * MAX_STEPS);
	if (acc >= STEP) {
		world_caps();
	}
	while (acc >= STEP) {
		acc -= STEP;
		// each step against the anchor where it was at that step's moment in the frame
		const Transform3D gs = g_prev.interpolate_with(g, CLAMP(1.0 - acc / std::max(delta, 1e-6), 0.0, 1.0));
		step_tuned(gs);
		const Transform3D inv = gs.affine_inverse();
		for (Chain &c : chains) {
			c.lp.swap(c.lc);
			for (size_t i = 0; i < c.x.size(); i++) {
				c.lc[i] = inv.xform(c.x[i]);
			}
		}
	}
	g_prev = g;
	const double w = acc / STEP;
	std::vector<Cap> caps;
	if (net) {
		const Transform3D inv = g.affine_inverse();
		for (int ci : net_caps) {
			Cap cap;
			cap.ok = ci >= 0 && cols[ci].ok;
			if (cap.ok) {
				const Collider &cd = cols[ci];
				const Transform3D t = inv * cd.t;
				cap.a = t.xform(cd.a);
				cap.b = t.xform(cd.b);
				cap.r = cd.r * t.basis.get_scale().x;
				const Vector3 reach = Vector3(1, 1, 1) * (cap.r + CUSHION);
				cap.lo = cap.a.min(cap.b) - reach;
				cap.hi = cap.a.max(cap.b) + reach;
			}
			caps.push_back(cap);
		}
	}
	net_acted = false;
	for (size_t ci = 0; ci < chains.size(); ci++) {
		Chain &c = chains[ci];
		std::vector<Vector3> &loc = drawn[ci];
		loc.resize(c.lc.size());
		for (size_t i = 0; i < c.lc.size(); i++) {
			loc[i] = c.lp[i].lerp(c.lc[i], w);
		}
		if (net) {
			net_clear(c, loc, caps, delta);
			if (c.side_of >= 0) {
				net_side(c, loc, drawn[c.side_of]);
			}
		}
		pose_local(skel, c, loc);
	}
}

void ChainSolver::net_side(const Chain &c, std::vector<Vector3> &loc, const std::vector<Vector3> &mid) {
	const std::vector<Vector3> &mp = chains[c.side_of].p;
	for (size_t i = 1; i < loc.size(); i++) {
		const double least = std::abs(c.p[i].x - mp[i].x) * 0.5;
		if ((loc[i].x - mid[i].x) * c.side < least) {
			loc[i].x = mid[i].x + c.side * least;
			net_acted = true;
		}
	}
}

static inline bool net_ok(const Vector3 &g, const Vector3 &want) {
	return g.x >= want.x && g.y >= want.y && g.z >= want.z;
}

static inline double move_toward(double from, double to, double delta) {
	return std::abs(to - from) <= delta ? to : from + (to > from ? delta : -delta);
}

// The drawn chain (anchor space) with every segment that comes within the cushion of a capsule, or ends in front of the
// back's plane, swung back about its root just enough (spring_chains.gd's _net_clear).
void ChainSolver::net_clear(Chain &c, std::vector<Vector3> &loc, const std::vector<Cap> &caps, double delta) {
	const Vector3 right(1, 0, 0);
	Vector3 a = loc[0];
	for (size_t j = 0; j + 1 < loc.size(); j++) {
		const Vector3 rest = c.rest_dir[j];
		Vector3 d = loc[j + 1] - loc[j];
		const double len = (c.p[j + 1] - c.p[j]).length();
		Vector3 full = d.normalized() * len;
		const double most = j == 0 ? NET_SWING_TOP : NET_SWING;
		if (full.angle_to(rest) > most) {
			const Vector3 axis = rest.cross(full);
			full = (axis.length_squared() > 1e-10 ? rest.rotated(axis.normalized(), most) : rest) * full.length();
			d = full;
			net_acted = true;
		}
		const bool below = j > 0;
		const Vector3 g0 = net_gap(a, full, rest, c.probe, caps, below);
		double target = 0.0;
		if (g0.x < CUSHION || g0.y < 0.0 || g0.z < -0.0001) {
			Vector3 want(g0.x < CUSHION ? CUSHION * std::exp((g0.x - CUSHION) / CUSHION) : g0.x, 0.0, 0.0);
			double hi = NET_TURN;
			if (!net_ok(net_gap(a, full.rotated(right, -hi), rest, c.probe, caps, below), want)) {
				want.x = std::min<double>(want.x, 0.0);
			}
			if (net_ok(net_gap(a, full.rotated(right, -hi), rest, c.probe, caps, below), want)) {
				double lo = 0.0;
				for (int k = 0; k < 8; k++) {
					const double mid = (lo + hi) * 0.5;
					if (net_ok(net_gap(a, full.rotated(right, -mid), rest, c.probe, caps, below), want)) {
						hi = mid;
					} else {
						lo = mid;
					}
				}
				target = hi;
			}
		}
		const double turn = move_toward(c.turn[j], target, (target > c.turn[j] ? NET_IN : NET_OUT) * delta);
		c.turn[j] = (float)turn;
		if (turn > 0.0) {
			d = full.rotated(right, -turn);
			net_acted = true;
		}
		const double need = back_z - a.z;
		if (a.z + d.z < back_z - 0.0001 && std::abs(need) < d.length()) {
			const Vector2 side = Vector2(d.x, d.y).normalized() * std::sqrt(d.length_squared() - need * need);
			d = Vector3(side.x, side.y, need);
			net_acted = true;
		}
		loc[j] = a;
		a += d;
	}
	loc[loc.size() - 1] = a;
}

// How far segment a-(a+d)'s probe lines are from the legs (x) and the hips (y) (INF past the cushion's reach), and its
// end (and the sheet across the middle) from the back's plane (z); negative inside.
Vector3 ChainSolver::net_gap(const Vector3 &a, const Vector3 &d, const Vector3 &rest, const std::vector<Vector3> &probes,
		const std::vector<Cap> &caps, bool below_root) const {
	const Vector3 x = a + d;
	double gap = INFINITY;
	double hips = INFINITY;
	double plane = x.z - back_z;
	const Vector3 dn = d.normalized();
	const Quaternion q = rest.dot(dn) > -0.9999 ? Quaternion(rest, dn) : Quaternion(Vector3(1, 0, 0), PI_);
	for (const Vector3 &o : probes) {
		const Vector3 ow = q.xform(o);
		const Vector3 pa = a + ow;
		const Vector3 pb = x + ow;
		if (std::abs(pb.x) <= NET_MID) {
			plane = std::min(plane, (double)pb.z - back_z + NET_SHEET);
		}
		if (below_root && std::abs(pa.x) <= NET_MID) {
			plane = std::min(plane, (double)pa.z - back_z + NET_SHEET);
		}
		const Vector3 lo = pa.min(pb);
		const Vector3 hi = pa.max(pb);
		for (size_t ci = 0; ci < caps.size(); ci++) {
			const Cap &cap = caps[ci];
			if (!cap.ok || lo.x > cap.hi.x || hi.x < cap.lo.x || lo.y > cap.hi.y || hi.y < cap.lo.y || lo.z > cap.hi.z || hi.z < cap.lo.z) {
				continue;
			}
			Vector3 on1, on2;
			double s;
			closest_segments(pa, pb, cap.a, cap.b, on1, on2, s);
			const double gc = on1.distance_to(on2) - cap.r;
			if ((int)ci == NET_HIPS) {
				hips = std::min(hips, gc);
			} else {
				gap = std::min(gap, gc);
			}
		}
	}
	return Vector3(gap, hips, plane);
}

PackedVector3Array ChainSolver::get_points(int ci) const {
	return to_packed(chains[ci].x);
}

PackedVector3Array ChainSolver::get_lp(int ci) const {
	return to_packed(chains[ci].lp);
}

PackedVector3Array ChainSolver::get_lc(int ci) const {
	return to_packed(chains[ci].lc);
}
