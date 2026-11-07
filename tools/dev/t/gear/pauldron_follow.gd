extends SceneTree
## Pauldrons ride the shoulder (1.30.3): each plate is skinned whole on its shoulder chain's helper
## (BodyBuilder.PAULDRON_FOLLOW of 8: the helper turns that much of the arm's bend about the shoulder; ArmBody /
## LowerBody pose it), not on the arm. Whole on the arm, a raised arm swung the plate up beside the jaw. (How it looks
## through the moves: clothlab's "pauldrons" and "pauld_coat" looks.)
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## How many vertices of `mi` are bound wholly to `bone`.
func _bound(mi: MeshInstance3D, bone: int) -> int:
	var n := 0
	var am := mi.mesh as ArrayMesh
	for s in range(am.get_surface_count()):
		var arr := am.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var b: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		if b.is_empty() or v.is_empty():
			continue
		var per := b.size() / v.size()
		for i in range(v.size()):
			for k in range(per):
				if b[i * per + k] == bone and w[i * per + k] > 0.99:
					n += 1
	return n


## Vertices bound wholly to each side's helper, in every skinned mesh of the body.
func _count(lk: Dictionary) -> Dictionary:
	var hm = p.body_model
	hm.apply_look(lk)
	var out := {"l": 0, "r": 0}
	for mi in hm.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).skin == null:
			continue
		var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
		if skel == null:
			continue
		for side in out:
			var bone := skel.find_bone("shoulder_%s_%d" % [side, BodyBuilder.PAULDRON_FOLLOW])
			if bone >= 0:
				out[side] += _bound(mi, bone)
	return out


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var lk: Dictionary = CharacterLook.default_look()
			lk.merge({"coat": "none", "hat": "none"}, true)
			for pair in [[{}, "on a shirt"], [{"coat": "longcoat"}, "over a coat"], [{"coat": "greatcoat"}, "over a greatcoat"]]:
				var on: Dictionary = lk.duplicate()
				on.merge(pair[0], true)
				var base := _count(on)
				on.merge({"pauldron": true, "pauldron_r": true}, true)
				var with := _count(on)
				for side in ["l", "r"]:
					var added: int = with[side] - base[side]
					check("%s, the %s plate rides its shoulder's helper %d/8, not the arm (%d vertices)" % [pair[1], side,
						BodyBuilder.PAULDRON_FOLLOW, added], added >= 20)
			return TK.done(fails)
	step += 1
	return false
