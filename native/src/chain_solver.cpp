#include "chain_solver.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void ChainSolver::_bind_methods() {
	ClassDB::bind_static_method("ChainSolver", D_METHOD("step", "xpx", "rest", "g", "grav", "k", "keep", "gs", "caps"), &ChainSolver::step);
	ClassDB::bind_static_method("ChainSolver", D_METHOD("push_out", "pt", "a", "b", "r"), &ChainSolver::push_out);
}

Vector3 ChainSolver::push_out(const Vector3 &pt, const Vector3 &a, const Vector3 &b, float r) {
	const Vector3 ab = b - a;
	real_t t = 0.0;
	const real_t l2 = ab.length_squared();
	if (l2 > 1e-8) {
		t = CLAMP((pt - a).dot(ab) / l2, 0.0, 1.0);
	}
	const Vector3 closest = a + ab * t;
	const Vector3 off = pt - closest;
	const real_t dist = off.length();
	if (dist >= r) {
		return pt;
	}
	if (dist < 1e-5) {
		return closest + Vector3(0, 0, r);
	}
	return closest + off / dist * r;
}

PackedVector3Array ChainSolver::step(const PackedVector3Array &xpx, const PackedVector3Array &rest, const Transform3D &g,
		const Vector3 &grav, float k, float keep, float gs, const PackedFloat32Array &caps) {
	const int n = rest.size();
	PackedVector3Array out = xpx;
	if (n == 0 || xpx.size() != n * 2) {
		return out;
	}
	Vector3 *x = out.ptrw();
	Vector3 *px = x + n;
	const Vector3 *p = rest.ptr();
	const float *cp = caps.ptr();
	const int nc = caps.size() / 7;
	x[0] = g.xform(p[0]);
	px[0] = x[0];
	for (int i = 1; i < n; i++) {
		const Vector3 rest_vec = g.basis.xform(p[i] - p[i - 1]);
		const real_t seg = rest_vec.length();
		const Vector3 prev = x[i - 1];
		const Vector3 cur = x[i];
		Vector3 nx = cur + (cur - px[i]) * keep + grav * gs;
		nx = nx.lerp(prev + rest_vec, k);
		for (int c = 0; c < nc; c++) {
			const float *q = cp + c * 7;
			nx = push_out(nx, Vector3(q[0], q[1], q[2]), Vector3(q[3], q[4], q[5]), q[6]);
		}
		const Vector3 d = nx - prev;
		if (d.length_squared() > 1e-10) {
			nx = prev + d.normalized() * seg;
		}
		px[i] = cur;
		x[i] = nx;
	}
	return out;
}
