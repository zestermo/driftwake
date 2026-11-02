extends SceneTree
## The coral atoll's reef (1.28.1, atoll_reef.gd): built on an atoll, coral gardens fill the water (hundreds of corals of
## every kind, all under the surface, ranged, unshadowed MultiMeshes), eight giant clams sit on the deeper floor and ten
## coral outcrops on the heads, rays and turtles glide over it; opening a clam gives a pearl once (the second time
## there's nothing left), its glowing pearl gone.
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
			isl.name = "AtollReef"
			stage.add_child(isl)
			for s in isl._theme.steps(isl):
				s[1].call()
			var reef: Node3D = isl.get_node("AtollReef")
			var gardens: Array = reef.get_children().filter(func(m): return m.name.begins_with("Corals"))
			var count := 0
			# (the headless renderer keeps no MultiMesh transforms: where they stand is the build's, below -0.75 m)
			for g in gardens:
				count += (g as MultiMeshInstance3D).multimesh.instance_count
			check("coral gardens fill the water (%d corals in %d batches)" % [count, gardens.size()], count > 2000 and gardens.size() >= 40)
			check("...ranged and unshadowed", gardens.all(func(m): return m.visibility_range_end > 0.0 and m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
			var clams: Array = reef.get_children().filter(func(m): return m.name.begins_with("Clam_"))
			var spars: Array = reef.get_children().filter(func(m): return m.name.begins_with("Spar_"))
			check("eight giant clams and ten coral outcrops (%d, %d)" % [clams.size(), spars.size()], clams.size() == 8 and spars.size() == 10)
			check("rays and turtles glide over it", reef.get_children().any(func(m): return m.name.begins_with("Shoal")))
			var p = stage.player
			var R = load("res://scripts/island/themes/atoll_reef.gd")
			var clam: Node3D = clams[0]
			var pearl: Node3D = clam.get_node("Pearl")
			var key := clam.name.trim_prefix("Clam_")
			var before: int = p.inventory_component.count("lagoon_pearl") + p.inventory_component.count("pearl")
			R._take(p, key, R.CLAM_LOOT, "x", pearl)
			var after: int = p.inventory_component.count("lagoon_pearl") + p.inventory_component.count("pearl")
			check("opening a clam gives a pearl (%d -> %d)" % [before, after], after > before)
			check("...its glowing pearl gone", not pearl.visible)
			R._take(p, key, R.CLAM_LOOT, "x", pearl)
			check("...once", p.inventory_component.count("lagoon_pearl") + p.inventory_component.count("pearl") == after)
			var arches: Array = reef.get_children().filter(func(m): return m.name.begins_with("Arch"))
			var morays: Array = reef.get_children().filter(func(m): return m.name.begins_with("Moray"))
			check("six swim-through arches, solid (%d)" % arches.size(), arches.size() == 6 and arches.all(func(m): return m is StaticBody3D and m.get_child_count() >= 4))
			check("seven moray crevices (%d)" % morays.size(), morays.size() == 7)
			# a diver in reach of a moray through its tell gets bitten
			var m: Node3D = morays[0]
			p.health_component.max_health = 500.0
			p.health_component.current_health = 500.0
			p.global_position = m.global_position + Vector3(0, 0.3, 1.2)
			p.reset_physics_interpolation()
			m.set("_phase", 1)
			m.set("_t", 0.0)
			m.set("_check", 0.0)
			until = TK.wait_secs(0.9)
			step = 1
			return false
		1:
			check("a diver in reach through the moray's tell is bitten (%.0f)" % stage.player.health_component.current_health, stage.player.health_component.current_health < 500.0)
			isl.queue_free()
			return TK.done(fails)
	return false
