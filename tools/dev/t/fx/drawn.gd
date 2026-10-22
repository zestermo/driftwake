extends SceneTree
## The other weapons' drawn elements (gen_drawn_fx.py): every element's slash and cloud sheets load and play; an
## awakened hit of each tree plays its slash sheet; dual wield's off-hand cuts lay their slash along the off hand's
## blade; BladeAura shows on both drawn blades only with the tree awakened, hides sheathed, and the snapshot carries
## NF_AURA for the other screens.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var fx
var step := 0
var until := 0
var fails := 0
var at := Vector3.ZERO


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _sheets() -> Array:
	var out: Array = []
	for n in fx._scene_root().get_children():
		if n is CPUParticles3D and n.mesh and n.mesh.material is StandardMaterial3D and n.mesh.material.albedo_texture:
			out.append(n.mesh.material.albedo_texture.resource_path.get_file())
	return out


func _auras() -> Array:
	var out: Array = []
	for w in [p.body_model.weapon, p.body_model.offhand]:
		if w and w.get_node_or_null("BladeAura"):
			out.append(w.get_node("BladeAura"))
	return out


func _ribbons(left: bool) -> int:
	var k := 0
	for n in p.body_model.find_children("*", "MeshInstance3D", true, false):
		var sc = n.get_script()
		if sc and str(sc.resource_path).ends_with("petal_ribbon.gd") and n.left == left and not n.is_queued_for_deletion():
			k += 1
	return k


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			fx = root.get_node("FX")
			p = stage.player
			at = p.global_position + Vector3(0, 1.0, -4.0)
			for tree in fx.DRAWN:
				var el: String = fx.DRAWN[tree]
				var a = fx.flipbook(at, el + "_slash", 1, 1.5, 0.3, {"lit": false})
				var b = fx.flipbook(at, el + "_cloud", 1, 1.5, 0.3, {"lit": false})
				check("%s: the slash and cloud sheets load" % el, a != null and b != null and a.mesh.material.albedo_texture != null
					and b.mesh.material.albedo_texture.resource_path.ends_with("flip_%s_cloud.png" % el))
				check("%s: its strip loads" % el, ResourceLoader.exists("res://assets/textures/fx/%s_trail.png" % el))
			for tree in ["dagger", "dual", "dual_dagger", "corsair"]:
				fx.elem_hit(tree, at, Vector3.FORWARD)
				check("an awakened %s hit plays its drawn slash" % tree, "flip_%s_slash.png" % fx.DRAWN[tree] in _sheets())
			p.set_offhand(p.equipped_weapon.duplicate())
			if not p.armed:
				TK.act("ready_weapon")
			until = TK.wait_secs(1.0)
		1:
			check("drawn with two blades, before the element: no aura (%s)" % p.style(), p.style() == "dual_sword" and _auras().all(func(a): return not a.visible))
			check("and no NF_AURA in the snapshot", not (int(p.net_pack()[8]) & p.NF_AURA))
			p.progression.owned["d_elem"] = true
			until = TK.wait_secs(0.3)
		2:
			check("awakened: the twin currents on both blades (%d)" % _auras().filter(func(a): return a.visible).size(),
				_auras().size() == 2 and _auras().all(func(a): return a.visible and a.tree == "dual"))
			check("and the snapshot carries NF_AURA", int(p.net_pack()[8]) & p.NF_AURA)
			DrawnFx.blow(p, "dual", "dual_2", 0.2)
			check("an off-hand cut lays its slash along the off hand's blade", _ribbons(true) == 1 and _ribbons(false) == 0)
			DrawnFx.blow(p, "dual", "dual_cross", 0.2)
			check("a cut with both lays one along each", _ribbons(true) == 2 and _ribbons(false) == 1)
			TK.act("ready_weapon")
			until = TK.wait_secs(0.8)
		3:
			check("sheathed: the auras are gone", not p.armed and _auras().all(func(a): return not a.visible))
			return TK.done(fails)
	step += 1
	return false
