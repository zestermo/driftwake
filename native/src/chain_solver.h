// ChainSolver: SpringChains' hot loop (scripts/npc/spring_chains.gd `_step`) in C++.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/transform3d.hpp>

namespace godot {

class ChainSolver : public RefCounted {
	GDCLASS(ChainSolver, RefCounted)

protected:
	static void _bind_methods();

public:
	// One verlet step of a chain (world space) against capsules `caps` (a, b, r flattened: 7 floats each).
	// `xpx` holds the points then their previous positions (2n); returns them stepped, the same layout.
	static PackedVector3Array step(const PackedVector3Array &xpx, const PackedVector3Array &rest, const Transform3D &g,
			const Vector3 &grav, float k, float keep, float gs, const PackedFloat32Array &caps);
	static Vector3 push_out(const Vector3 &pt, const Vector3 &a, const Vector3 &b, float r);
};

} // namespace godot
