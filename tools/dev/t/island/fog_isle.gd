extends SceneTree
## The fog isle (1.20): fog isles turn up in chains past the first island (rolled apart from the weighted draw) and
## never first; one prepared is a "fog" island in thick haze; its lantern posts stand along its ways, cold, and one
## lit sets its world flag, glows and pushes the dead out of its glow; its graveyard is planned by the village; its
## haunts are crews of the drowned and ghosts; its boss ground is the drowned captain's wreck with him asleep in it, a
## captain-style AI glowing as a spirit.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var gi
var arena


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
			var Chain = load("res://scripts/world/chain.gd")
			var found := {}
			var fog_first := 0
			var total := 0
			var fogs := 0
			for s in range(1, 41):
				var c = Chain.make(s, Vector2.ZERO, Vector2(0, -1))
				for id in c.start_next:
					if str(c.node(int(id))["theme"]) == "fog":
						fog_first += 1
				for n in c.nodes:
					total += 1
					if str(n["theme"]) == "fog":
						fogs += 1
						if found.is_empty() and str(n["role"]) == "regular":
							found = (n as Dictionary).duplicate(true)
			check("fog isles turn up in chains (%d of %d islands)" % [fogs, total], fogs > total / 20 and fogs < total / 3)
			check("...never the first island (%d)" % fog_first, fog_first == 0)
			if found.is_empty():
				return TK.done(fails)
			load("res://scripts/island/island_theme.gd").meshes("fog")
			gi = load("res://scripts/island/gen_island.gd").new()
			gi.prepare(found)
			stage.add_child(gi)
			var st: Dictionary = load("res://scripts/island/kit/kit_style.gd").of("fog")
			check("a fog island, in thick haze (%.2f)" % float(st["haze"]), gi.theme == "fog" and float(st["haze"]) >= 0.5)
			var P = load("res://scripts/island/themes/fog_places.gd")
			P.lanterns(gi)
			var graves := (gi.places as Array).filter(func(pl): return str(pl.get("kind", "")) == "fog_graveyard")
			check("its graveyard is planned near the village (%d)" % graves.size(), graves.size() == 1
				and (graves[0]["at"] as Vector2).distance_to(gi.sites["village"]) < 90.0)
			P.haunts(gi)
			until = TK.wait_ticks(4)
		1:
			var ls: Array = get_nodes_in_group("fog_lanterns")
			check("lantern posts along its ways (%d)" % ls.size(), ls.size() >= 5)
			check("...all cold to begin with", ls.all(func(l): return not l.lit))
			var l = ls[0]
			l._on_light(stage.player)
			var gm = root.get_node("GameManager")
			check("lighting one sets its world flag (%s)" % l.key, gm.world_flags.has(l.key) and l.lit)
			var P = load("res://scripts/island/themes/fog_places.gd")
			var near: Vector3 = l.global_position + Vector3(3.0, 0, 0)
			check("...the dead are pushed out of its glow", P.lit_near(self, near) and P.away_from_light(self, near).x > 0.5)
			var kinds := {}
			for c in gi.get_children():
				if c.get("specs") is Array:
					for spec in c.specs:
						kinds[str(spec.get("script", "")).get_file()] = true
			check("its haunts are the drowned and ghosts (%s)" % str(kinds.keys()), kinds.has("ghost.gd") and kinds.has("drowned.gd"))
			arena = load("res://scripts/island/beast_arena.gd").rebuild(gi, "ghost_captain")
			until = TK.wait_ticks(10)
		2:
			var boss = arena.boss
			check("its boss is the drowned captain, asleep (%s)" % str(boss.state if boss else "none"), boss != null and boss.asleep())
			var cap = boss.captain if boss else null
			check("...a captain-style AI glowing as a spirit", cap != null and cap.is_ai and cap.appearance.get("spirit", false))
			var hp0: float = cap.health_component.current_health if cap else 0.0
			var shot := HitData.new()
			shot.damage = 40.0
			shot.ranged = true
			shot.impact = "shot"
			if cap:
				cap._on_hit_received(shot, stage.player)
			check("...whom shot passes through (%.0f -> %.0f)" % [hp0, cap.health_component.current_health if cap else 0.0], cap and cap.health_component.current_health == hp0)
			check("...on his wreck (a dressed ground)", arena.get_parent().find_children("Dressing", "", true, false).size() > 0)
			return TK.done(fails)
	step += 1
	return false
