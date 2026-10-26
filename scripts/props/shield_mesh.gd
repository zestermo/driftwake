class_name ShieldMesh
extends RefCounted
## The shield grunt's round shield (1.23): planks banded in iron with a boss, held on the off hand (the face toward
## -Z, the grip at the origin, the rim 0.34 m out). Built once.

const R := 0.34
static var _mesh: ArrayMesh


static func mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks", Color(0.62, 0.42, 0.26))
	var iron := PSXMat.lit("metal", Color(0.55, 0.55, 0.58))
	# (the disc's axis along -Z: the face out in front of the forearm)
	var face := Basis(Vector3.RIGHT, -PI * 0.5)
	mb.add_cylinder(wood, Transform3D(face, Vector3(0, 0, 0.02)), R, R, 0.04, 10, 3.0, Color.WHITE, true, true)
	mb.add_cylinder(iron, Transform3D(face, Vector3(0, 0, 0.015)), R + 0.015, R + 0.015, 0.05, 10, 3.0, Color.WHITE, false, false)
	mb.add_cylinder(iron, Transform3D(face, Vector3(0, 0, -0.02)), 0.09, 0.05, 0.06, 8, 3.0)
	mb.add_box(iron, Transform3D(Basis(), Vector3(0, 0, -0.025)), Vector3(R * 1.9, 0.04, 0.012), 2.0)
	_mesh = mb.commit()
	_mesh.set_meta("model", "shield")
	return _mesh
