extends SceneTree
## The cutlass's drawn water: FX.water_arc / water_wake make one WaterRibbon each that draws a mesh
## and frees itself by its life (none beyond BURST_RANGE); FX.water_burst plays one of the water
## sheets unlit; BladeWater shows round a drawn cutlass only with the sea awakened (elem_sword),
## hides when it's sheathed, and puts NF_TIDE in the snapshot for the other screens.
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
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _ribbons() -> Array:
	var out: Array = []
	for n in fx._scene_root().get_children():
		var sc = n.get_script()
		if sc and str(sc.resource_path).ends_with("water_ribbon.gd") and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _aura():
	var w = p.body_model.weapon
	return w.get_node_or_null("BladeWater") if w else null


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			fx = root.get_node("FX")
			p = stage.player
			at = p.global_position + Vector3(0, 1.0, -4.0)
			fx.water_arc(at, Vector3.UP, Vector3.RIGHT, 1.5, PI, 0.5, 0.1, 0.4)
			fx.water_wake(p.global_position, p.global_position + Vector3(0, 0, -5), 0.6, 0.4)
			check("an arc and a wake are a ribbon each (%d)" % _ribbons().size(), _ribbons().size() == 2)
			var burst = fx.flipbook(at, "water_swirl", 1, 2.0, 0.4, {"lit": false})
			var mat: StandardMaterial3D = burst.mesh.material if burst else null
			check("the water sheets load and play", mat != null and mat.albedo_texture != null
				and mat.albedo_texture.resource_path.ends_with("flip_water_swirl.png"))
			until = TK.wait_secs(0.15)
		1:
			var drawn := true
			for r in _ribbons():
				drawn = drawn and r.mesh.get_surface_count() == 1
			check("each ribbon draws its water", drawn and _ribbons().size() == 2)
			until = TK.wait_secs(0.5)
		2:
			check("and they're gone by their life (%d left)" % _ribbons().size(), _ribbons().is_empty())
			fx.water_arc(at + Vector3(0, 0, -300), Vector3.UP, Vector3.RIGHT)
			check("nothing beyond BURST_RANGE", _ribbons().is_empty())
			p.equip_weapon(load("res://resources/items/cutlass.tres"), false)
			p.progression.owned.erase("s_elem")
			TK.act("ready_weapon")
			until = TK.wait_secs(0.6)
		3:
			check("a drawn cutlass before the sea's awakened: no water on it", p.armed and (_aura() == null or not _aura().visible))
			check("and no NF_TIDE in the snapshot", not (int(p.net_pack()[8]) & p.NF_TIDE))
			p.progression.owned["s_elem"] = true
			until = TK.wait_secs(0.2)
		4:
			check("awakened: water winds round the blade", _aura() != null and _aura().visible and _aura().mesh != null)
			check("and the snapshot carries NF_TIDE", int(p.net_pack()[8]) & p.NF_TIDE)
			TK.act("ready_weapon")
			until = TK.wait_secs(0.8)
		5:
			check("sheathed: the water's gone", not p.armed and (_aura() == null or not _aura().visible))
			return TK.done(fails)
	step += 1
	return false
