extends SceneTree
## The magma salamander (scripts/enemies/beasts/volcanic_salamander.gd): every volcanic isle's boss, its ground the
## caldera's floor, dressed (basalt and glass round the edge, glowing cracks), asleep at first; on the beast pass. Its
## dive: it sinks out of sight and can't be struck, swims at the captain, a red ring shows where they stood and it
## bursts up through it (a knockdown); down a third of its health it erupts into its next phase (a moment).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var gi
var arena
var boss
var hp0 := 0.0
var hidden := false
var unhittable := false


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
			var v = load("res://scripts/island/themes/island_themes.gd").of("volcanic")
			check("the volcanic isle's boss is the magma salamander", v.bosses == ["salamander"])
			var c = load("res://scripts/world/chain.gd").make(23, Vector2.ZERO, Vector2(0, -1))
			var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
			n["theme"] = "volcanic"
			n.merge({"beast": "salamander", "beast_look": 0, "beast_name": "x", "minis": [v.minis[0]], "roamer": v.roamers[0]}, true)
			load("res://scripts/island/island_theme.gd").meshes("volcanic")
			gi = load("res://scripts/island/gen_island.gd").new()
			gi.prepare(n)
			stage.add_child(gi)
			gi.position = Vector3(0, -float(gi.hv(gi.sites["boss"])), 0)
			# (its ground under the fight: the terrain and its colliders, nothing else)
			for s in gi.finish_steps():
				if str(s[0]) in ["terrain", "ground"]:
					gi.run_step(s)
			check("its ground is the caldera's floor", (gi.sites["boss"] as Vector2).distance_to(gi.land_plan["cone"]["c"]) < 1.0)
			arena = load("res://scripts/island/beast_arena.gd").rebuild(gi, "salamander")
			until = TK.wait_ticks(10)
		1:
			boss = arena.boss
			check("the salamander asleep on its ground, on the beast pass (%s)" % str(boss.state if boss else "none"), boss != null and boss.asleep() and boss.bp != null)
			check("...dressed: basalt and glass round the edge", arena.get_parent().find_children("Dressing", "", true, false).size() > 0)
			var p = stage.player
			p.health_component.max_health = 9999.0
			p.health_component.current_health = 9999.0
			p.global_position = boss.global_position + boss._fwd() * 12.0 + Vector3.UP * 0.5
			p.reset_physics_interpolation()
			boss.alert()
			until = TK.wait_ticks(20)
		2:
			boss.phase = 2
			boss.end_move()
			boss.film("dive")
			hp0 = stage.player.health_component.current_health
			until = TK.wait_secs(1.6)
		3:
			hidden = not boss.model.visible
			unhittable = not boss.hurtbox.monitorable
			check("it dives out of sight and can't be struck (hidden %s, unhittable %s)" % [hidden, unhittable], hidden and unhittable)
			until = TK.wait_secs(3.2)
		4:
			var p = stage.player
			check("...bursts up under the captain: hurt (%.0f -> %.0f), back in sight" % [hp0, p.health_component.current_health], p.health_component.current_health < hp0 and boss.model.visible)
			var ph: int = boss.phase
			boss.health.current_health = boss.health.max_health * 0.3
			boss._phase_check()
			check("down past two thirds of its health it erupts into its last phase, a moment (%d -> %d, %s)" % [ph, boss.phase, boss.move], boss.phase == 3 and boss.move == "moment")
			return TK.done(fails)
	step += 1
	return false
