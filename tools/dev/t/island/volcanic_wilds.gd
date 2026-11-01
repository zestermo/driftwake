extends SceneTree
## The volcanic isle's wilds (volcanic_theme.gd's roster, volcanic_places.gd, volcanic_vents.gd, the fauna and beasts):
## its rolls bring ash hound packs and ember beetles (nothing guaranteed); both build and stand; an ember beetle bursts
## in embers when it dies; its minibosses and roamer are its own (the obsidian golem, the ash alpha, the Cinderhorn);
## the chain's waterfall and cenote become an obsidian quarry (a bandit crew working it) and a vent field, built on
## its island; a vent burst burns a captain standing on that vent.
const TK := preload("res://tools/dev/test_kit.gd")
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
var stage
var fails := 0
var step := 0
var until := 0
var isl
var vents
var hp0 := 0.0
var slot := 0


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
			var FS = load("res://scripts/island/fauna_spawner.gd")
			var hounds := 0
			var beetles := 0
			for s in range(30):
				var r: Dictionary = FS.roll("volcanic", s * 101)
				hounds += 1 if r.has("ash_hound") else 0
				beetles += 1 if r.has("ember_beetle") else 0
			check("ash hound packs and ember beetles on some volcanic islands, not all (%d, %d of 30)" % [hounds, beetles], hounds > 5 and hounds < 30 and beetles > 5 and beetles < 30)
			for k in ["ash_hound", "ember_beetle"]:
				var cr = FS.make("volcanic", k)
				cr.setup(Vector3(4, 0.5, -6 if k == "ash_hound" else -9), {"lead": true, "pack": 1})
				cr.name = k
				stage.add_child(cr)
			var v = load("res://scripts/island/themes/island_themes.gd").of("volcanic")
			check("its own minibosses and roamer: %s, %s" % [v.minis, v.roamers], v.minis == ["obsidian_golem", "ash_alpha"] and v.roamers == ["cinderhorn"]
				and str(v.beasts["cinderhorn"]["script"]).contains("volcanic_"))
			var stub: Node = stage.get_node("NoIslands")
			stub.remove_from_group("world_gen")
			var s := GDScript.new()
			s.source_code = WORLD
			s.reload()
			var world := Node.new()
			world.set_script(s)
			world.name = "Islands"
			stage.add_child(world)
			world.c = load("res://scripts/world/chain.gd").make(11, Vector2.ZERO, Vector2(0, -1))
			var n: Dictionary = world.c.node(int(world.c.start_next[0])).duplicate(true)
			n["theme"] = "volcanic"
			n.merge({"beast": v.bosses[0], "beast_look": 0, "beast_name": "x", "minis": [v.minis[0]], "roamer": v.roamers[0],
				"setpiece": "cenote", "landmarks": ["waterfall"], "landmark_count": 1}, true)
			load("res://scripts/island/island_theme.gd").meshes("volcanic")
			isl = load("res://scripts/island/gen_island.gd").new()
			isl.name = "VolcanicWilds"
			isl.position = Vector3(0, 0, -3000)
			world.add_child(isl)
			isl.prepare(n)
			var kinds: Array = isl.places.map(func(pl): return pl["kind"])
			check("the cenote and the waterfall become a vent field and a quarry %s" % [kinds], kinds.has("volcanic_vents") and kinds.has("volcanic_quarry"))
			isl.make_beasts(n)
			isl._prebuild_beasts()
			isl.finish()
			until = TK.wait_ticks(10)
		1:
			var h = stage.get_node("ash_hound")
			var b = stage.get_node("ember_beetle")
			check("an ash hound and an ember beetle build and stand (%s, %s)" % [h.kind, b.kind], h.kind == "ash_hound" and b.kind == "ember_beetle"
				and h.model.get_child_count() > 0 and b.model.get_child_count() > 0)
			b.queue_free()
			var q = isl.get_node_or_null("Place_volcanic_quarry")
			check("the quarry is built, its crew working it", q != null and q.get_node_or_null("Quarry") != null and isl.get_node_or_null("QuarryCrew") != null)
			var vf = isl.get_node_or_null("Place_volcanic_vents")
			vents = vf.get_node("VentBursts") if vf else null
			check("the vent field is built with its bursts (%d vents)" % (vents.spots.size() if vents else 0), vents != null and vents.spots.size() >= 4)
			if vents == null:
				return TK.done(fails)
			# stand on the vent of the next slot, wait for its burst
			var t: float = root.get_node("Ocean").clock()
			slot = int(floor(t / vents.PERIOD)) + 1
			var qv: Vector2 = vents.spots[posmod(hash([vents.seed_value, slot]), vents.spots.size())]
			var p = stage.player
			p.global_position = isl.to_global(Vector3(qv.x, isl.hv(qv) + 0.1, qv.y))
			p.reset_physics_interpolation()
			hp0 = p.health_component.current_health
			until = TK.wait_secs(vents.PERIOD * 2.0 + 0.5)
		2:
			var p = stage.player
			check("a vent's burst burns the captain standing on it (%.0f -> %.0f)" % [hp0, p.health_component.current_health], p.health_component.current_health < hp0)
			return TK.done(fails)
	step += 1
	return false
