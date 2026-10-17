extends SceneTree
## The katana's drawn element: FX.katana_slash lays a PetalRibbon on the blade, katana_line / katana_arc lay one
## along a path; each draws its strip and frees itself by its life (none far off); the katana sheets play;
## sakura are one burst; BladePetals shows on a drawn katana only with its element awakened (elem_katana),
## lets petals go from the tip, hides sheathed, and puts NF_PETALS in the snapshot for the other screens.
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
	stage = TK.stage(self, {"hud": false, "weapon": "katana"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _ribbons() -> Array:
	var out: Array = []
	for n in fx._scene_root().find_children("*", "MeshInstance3D", true, false):
		var sc = n.get_script()
		if sc and str(sc.resource_path).ends_with("petal_ribbon.gd") and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _aura():
	var w = p.body_model.weapon
	return w.get_node_or_null("BladePetals") if w else null


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			fx = root.get_node("FX")
			p = stage.player
			at = p.global_position + Vector3(0, 1.0, -4.0)
			p.progression.owned.erase("k_elem")
			until = TK.wait_secs(0.4)
		1:
			check("a drawn katana before its element wakes: no cloud on it", p.armed and (_aura() == null or not _aura().visible))
			check("and no NF_PETALS in the snapshot", not (int(p.net_pack()[8]) & p.NF_PETALS))
			fx.katana_slash(p.body_model, 0.2, true, 0.7)
			fx.katana_line(at, at + Vector3(4, 0, 0), 0.5, true, 0.08)
			fx.katana_arc(at, Vector3.RIGHT, Vector3.FORWARD, 2.0, PI, 0.8, false, 0.1)
			check("a slash, a line and an arc are a ribbon each (%d)" % _ribbons().size(), _ribbons().size() == 3)
			var burst = fx.flipbook(at, "katana_cloud", 1, 2.0, 0.4, {"lit": false})
			var mat: StandardMaterial3D = burst.mesh.material if burst else null
			check("the katana sheets load and play", mat != null and mat.albedo_texture != null
				and mat.albedo_texture.resource_path.ends_with("flip_katana_cloud.png"))
			var before: int = fx._scene_root().get_child_count()
			fx.sakura(at, Vector3.UP, 6, 3.0)
			check("sakura are one burst", fx._scene_root().get_child_count() == before + 1)
			until = TK.wait_secs(0.15)
		2:
			var drawn := 0
			for r in _ribbons():
				if r.mesh.get_surface_count() == 1:
					drawn += 1
			check("the line and the arc draw their strip (%d drawn)" % drawn, drawn >= 2)
			until = TK.wait_secs(0.8)
		3:
			check("and they're gone by their life (%d left)" % _ribbons().size(), _ribbons().is_empty())
			fx.katana_arc(at + Vector3(0, 0, -300), Vector3.RIGHT, Vector3.FORWARD)
			check("nothing beyond BURST_RANGE", _ribbons().is_empty())
			p.progression.owned["k_elem"] = true
			until = TK.wait_secs(0.2)
		4:
			check("awakened: cloud on the blade", _aura() != null and _aura().visible and _aura().mesh != null)
			check("...and petals let go from its tip", _aura() != null and _aura()._petals.emitting)
			check("and the snapshot carries NF_PETALS", int(p.net_pack()[8]) & p.NF_PETALS)
			TK.act("ready_weapon")
			until = TK.wait_secs(0.8)
		5:
			check("sheathed: the cloud's gone", not p.armed and (_aura() == null or not _aura().visible))
			return TK.done(fails)
	step += 1
	return false
