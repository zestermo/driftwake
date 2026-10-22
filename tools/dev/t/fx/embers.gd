extends SceneTree
## The axe's drawn fire: BladeEmbers shows on a drawn axe only with its element awakened (elem_axe), sits along the
## bit (not the haft), lets cinders go, hides sheathed and puts NF_EMBERS in the snapshot for the other screens; an
## awakened hit (elem_hit "axe") plays the drawn fire sheets; FX.element("axe") throws drawn cinders; the whirlwind
## lays a drawn slash along the bit on each turn.
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
	stage = TK.stage(self, {"hud": false, "weapon": "boarding_axe"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _aura():
	var w = p.body_model.weapon
	return w.get_node_or_null("BladeEmbers") if w else null


func _sheets() -> Array:
	var out: Array = []
	for n in fx._scene_root().get_children():
		if n is CPUParticles3D and n.mesh and n.mesh.material is StandardMaterial3D and n.mesh.material.albedo_texture:
			out.append(n.mesh.material.albedo_texture.resource_path.get_file())
	return out


func _ribbons() -> int:
	var k := 0
	for n in p.body_model.find_children("*", "MeshInstance3D", true, false):
		var sc = n.get_script()
		if sc and str(sc.resource_path).ends_with("petal_ribbon.gd") and n.kind == "axe" and not n.is_queued_for_deletion():
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
			p.progression.owned.erase("a_elem")
			if not p.armed:
				TK.act("ready_weapon")
			until = TK.wait_secs(1.0)
		1:
			check("a drawn axe before its element wakes: no fire on it", p.armed and (_aura() == null or not _aura().visible))
			check("and no NF_EMBERS in the snapshot", not (int(p.net_pack()[8]) & p.NF_EMBERS))
			p.progression.owned["a_elem"] = true
			until = TK.wait_secs(0.3)
		2:
			var a = _aura()
			check("awakened: fire on the axe", a != null and a.visible and a.mesh != null)
			check("...cinders let go off it", a != null and a._cinders.emitting)
			check("and the snapshot carries NF_EMBERS", int(p.net_pack()[8]) & p.NF_EMBERS)
			var w: MeshInstance3D = p.body_model.weapon
			var hz := WeaponDesigns.axe_head_z(str(w.mesh.get_meta("model", "")))
			var mid: Vector3 = a.global_transform * a.mesh.get_aabb().get_center()
			var bit: Vector3 = w.global_transform * Vector3(0, w.mesh.get_aabb().position.y, hz)
			check("the flames are on the bit's edge, not the haft (%.2f m from it)" % mid.distance_to(bit), mid.distance_to(bit) < 0.15)
			fx.elem_hit("axe", at, Vector3.FORWARD)
			var s := _sheets()
			check("an awakened hit plays the drawn fire (%s)" % ", ".join(s), "flip_ember_slash.png" in s and "flip_ember_cloud.png" in s and "flip_cinder.png" in s)
			var before: int = fx._scene_root().get_child_count()
			fx.element("axe", at, Vector3.UP, 4, 3.0)
			check("the element's a burst of drawn cinders", fx._scene_root().get_child_count() == before + 1 and "flip_cinder.png" in _sheets())
			p.state_machine.force_state("HeavyAttack", {})
			until = TK.wait_secs(0.5)
		3:
			check("the whirlwind lays a drawn slash along the bit (%d)" % _ribbons(), _ribbons() >= 1)
			until = TK.wait_secs(1.5)
		4:
			TK.act("ready_weapon")
			until = TK.wait_secs(0.8)
		5:
			check("sheathed: the fire's gone", not p.armed and (_aura() == null or not _aura().visible))
			return TK.done(fails)
	step += 1
	return false
