extends SceneTree
## The coral atoll's seabed (1.30, atoll_seabed.gd): built on an atoll, the floor under the water is dressed in every
## kind (seagrass meadows, rubble, boulders, shells, starfish, urchins, sponges, dead coral), all of it under the
## surface, ranged and unshadowed; the terrain lays the lagoon's pale sand by the vertex alpha (the beaches' palette
## through the waterline, no seam), going over to the open sea's dark floor down the drop-off; and the lagoon's water
## and a diver's fog there are the atoll's clear blue.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var isl
var fails := 0
var step := 0
var until := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var v = load("res://scripts/island/themes/island_themes.gd").of("atoll")
			var c = load("res://scripts/world/chain.gd").make(11, Vector2.ZERO, Vector2(0, -1))
			var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
			n["theme"] = "atoll"
			n.merge({"beast": v.bosses[0], "beast_look": 0, "beast_name": "x", "minis": [v.minis[0]], "roamer": v.roamers[0]}, true)
			load("res://scripts/island/island_theme.gd").meshes("atoll")
			isl = load("res://scripts/island/gen_island.gd").new()
			isl.prepare(n)
			isl.name = "AtollSeabed"
			stage.add_child(isl)
			var SB = load("res://scripts/island/themes/atoll_seabed.gd")
			var st := {"lists": {}}
			SB._start(isl, st)
			for kind in SB.KINDS:
				SB.plan_kind(isl, st, kind)
			SB._basin_floor(isl, st)
			var by_kind := {}
			var dry := 0
			for key in st["lists"]:
				var kind: String = (key as String).split("_")[0]
				for e in st["lists"][key]:
					by_kind[kind] = int(by_kind.get(kind, 0)) + 1
					var o: Vector3 = (e[0] as Transform3D).origin
					if o.y > -0.3:
						dry += 1
			for kind in SB.KINDS:
				check("the floor has its %s (%d)" % [kind, int(by_kind.get(kind, 0))], int(by_kind.get(kind, 0)) >= int(SB.KINDS[kind]["n"]) * 0.6)
			check("...all of it under the water (%d above)" % dry, dry == 0)
			for s in isl._theme.steps(isl):
				if str(s[0]).begins_with("atoll seabed") or str(s[0]) == "atoll water":
					s[1].call()
			var bed: Node3D = isl.get_node("AtollSeabed")
			var mms: Array = bed.get_children()
			check("built as MultiMeshes by cell (%d)" % mms.size(), mms.size() >= 60 and mms.size() <= 800 and mms.all(func(m): return m is MultiMeshInstance3D))
			check("...ranged and unshadowed", mms.all(func(m): return m.visibility_range_end > 0.0 and m.visibility_range_end <= 160.0 and m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
			# the terrain: the atoll's sand under the lagoon, the open sea's floor past the drop-off
			var mat: ShaderMaterial = load("res://scripts/psx/psx_mat.gd").terrain(true, 0.0, load("res://scripts/island/kit/kit_style.gd").of("atoll")["ground"], "sand")
			check("the terrain lays two seabeds, mottled", mat.get_shader_parameter("sea_mix") == true and float(mat.get_shader_parameter("sea_mottle")) > 0.0)
			var L = isl._theme.LAND_FEATURES
			var a := 0.7
			var lagoon: Vector2 = L.ring_point(isl, a, 1.0) * 0.6
			var far := Vector2.from_angle(a) * (float(isl.radius) + 120.0)
			var pl: Color = L.paint(isl, lagoon, isl.hv(lagoon), Color(0, 0, 1, 1))
			var pf: Color = L.paint(isl, far, isl.hv(far), Color(0, 0, 1, 1))
			check("...the lagoon's pale sand (a %.2f) going over to the deep's floor outside (a %.2f)" % [pl.a, pf.a], pl.a > 0.99 and pf.a < 0.01)
			var w: Node = isl.get_node("AtollWater")
			check("the lagoon's clear water covers it (r %.0f)" % w.radius, w.radius > lagoon.length() and w.radius < float(isl.radius))
			var under: Array = load("res://scripts/island/kit/kit_style.gd").of("atoll")["under"]
			var home: Array = load("res://scripts/island/kit/kit_style.gd").of("jungle")["under"]
			check("a diver there sees further through clearer water (%.0f m vs %.0f)" % [(under[3] as Vector2).y, (home[3] as Vector2).y],
				(under[3] as Vector2).y > (home[3] as Vector2).y * 2.0 and float(under[2]) > float(home[2]))
			isl.queue_free()
			return TK.done(fails)
	return false
