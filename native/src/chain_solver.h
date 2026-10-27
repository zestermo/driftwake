// ChainSolver: SpringChains' solver (scripts/npc/spring_chains.gd) in C++: modes "a0" and "a" (with the net), stepped
// and posed onto the Skeleton3D here. The GDScript solver stays as the fallback and the reference (t/chains tests).
#pragma once

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/skeleton3d.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/transform3d.hpp>

#include <vector>

namespace godot {

class ChainSolver : public RefCounted {
	GDCLASS(ChainSolver, RefCounted)

public:
	struct Cap {
		Vector3 a, b;
		double r = 0.0;
		Vector3 lo, hi;
		bool ok = false;
		bool hard = false;
	};

private:
	struct Collider {
		uint64_t node = 0;
		Vector3 a, b;
		double r = 0.0;
		bool ok = false;
		Transform3D t;
	};
	struct Chain {
		std::vector<Vector3> p, x, px, lp, lc, rest_dir;
		std::vector<int> bones, col;
		std::vector<Vector3> probe;
		std::vector<float> turn, slack;
		double k = 0.12, d = 0.08, g = 1.0;
		int side_of = -1;
		double side = 0.0;
		Vector3 axis = Vector3(1, 0, 0);
	};

	std::vector<Collider> cols;
	std::vector<Cap> cw;
	std::vector<int> net_caps;
	std::vector<bool> net_hard;
	std::vector<Chain> chains;
	std::vector<std::vector<Vector3>> drawn;
	bool blend = false;
	bool tuned = false;
	bool net = false;
	double cushion = 0.025;
	double swing = 1.5;
	double swing_top = 1.0;
	double net_from = 0.0;
	bool net_best = false;
	int iters = 1;
	double back_z = -INFINITY;
	Vector3 gravity = Vector3(0, -9.8, 0);
	double acc = 0.0;
	bool has_last = false;
	Vector3 last_origin;
	Transform3D g_step, g_prev;
	bool net_acted = false;

	void read_colliders();
	void world_caps();
	void snap(const Transform3D &g);
	void step(const Transform3D &g);
	void step_tuned(const Transform3D &g);
	void pose_local(Skeleton3D *skel, const Chain &c, const std::vector<Vector3> &loc);
	void net_clear(Chain &c, std::vector<Vector3> &loc, const std::vector<Cap> &caps, double delta);
	void net_side(const Chain &c, std::vector<Vector3> &loc, const std::vector<Vector3> &mid);
	Vector3 net_gap(const Vector3 &a, const Vector3 &d, const Vector3 &rest, const std::vector<Vector3> &probes,
			const std::vector<Cap> &caps, bool below_root) const;

protected:
	static void _bind_methods();

public:
	static const int API = 4;
	static int api() { return API; }

	// Colliders in order (nodes, their local capsules); chains name them by index.
	void set_colliders(const Array &nodes, const PackedVector3Array &a, const PackedVector3Array &b, const PackedFloat32Array &r);
	void add_chain(const PackedVector3Array &rest, const PackedInt32Array &bones, double k, double d, double g,
			const PackedInt32Array &col, const PackedVector3Array &probes, int side_of, double side, const Vector3 &axis);
	// Modes "a" (`p_tuned`: the tuned step) and "n" (the plain step), both drawn blended between steps: the back's
	// plane, constraint passes, the net, its capsules (indices) and which are hard, the cushion and the swing range.
	void set_drawn(bool p_tuned, double back, int passes, bool p_net, const PackedInt32Array &caps, const PackedInt32Array &hard,
			double p_cushion, double p_swing, double p_swing_top, double p_from, bool p_best);
	// Chain `ci`'s net slack per segment (spring_chains.gd's use_slack): judged that much further out of the soft capsules.
	void set_slack(int ci, const PackedFloat32Array &s);
	void set_gravity(const Vector3 &g) { gravity = g; }
	void reset() { has_last = false; }
	void simulate(Node3D *anchor, Skeleton3D *skel, double delta);

	double get_acc() const { return acc; }
	bool get_net_acted() const { return net_acted; }
	PackedVector3Array get_points(int ci) const;
	PackedVector3Array get_lp(int ci) const;
	PackedVector3Array get_lc(int ci) const;

	static Vector3 push_out(const Vector3 &pt, const Cap &cap);
	static Vector3 push_segment(const Vector3 &a, const Vector3 &b, const Cap &cap);
	// Closest points of segments p1-q1 and p2-q2: on the first, on the second, the first's parameter.
	static void closest_segments(const Vector3 &p1, const Vector3 &q1, const Vector3 &p2, const Vector3 &q2,
			Vector3 &on1, Vector3 &on2, double &s_out);
};

} // namespace godot
