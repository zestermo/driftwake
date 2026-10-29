extends SceneTree
## 1.25.4 Tomo's spar on the shrine terrace (Story step "tomo"), on the real Brinehollow: the sparring ground east of
## the shrine is flat and open (nothing to get stuck on within 4 m); Master Isao stands in his reading hall; coming up
## to the ground on that step sends Tomo out onto it (ArenaBout "master:black_leg"); knocked off it mid-fight he's put
## back on it; put him down and black leg's learned and the story moves on to the ruins.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var isl
var story
var bout
var spot: Vector3
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			load("res://scripts/world/actor_sleep.gd").enabled = false
			p = stage.player
			story = root.get_node("Story")
			isl = load("res://scripts/island/starter_island.gd").new()
			isl.name = "Brinehollow"
			isl.position = Vector3(0, 0, 9000)
			stage.add_child(isl)
			isl.build(42)
			spot = isl.ground_of("spar")
			var lo := INF
			var hi := -INF
			var space: PhysicsDirectSpaceState3D = isl.get_world_3d().direct_space_state
			var hits: Array = []
			for k in range(16):
				var a := TAU * k / 16.0
				var d := Vector3(cos(a), 0, sin(a))
				var g: Vector3 = isl.to_local(spot + d * 4.0)
				var h: float = isl.hv(Vector2(g.x, g.z))
				lo = minf(lo, h)
				hi = maxf(hi, h)
				for y: float in [0.5, 1.4]:
					var q := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * y, spot + Vector3.UP * y + d * 4.0, 1)
					q.exclude = [p.get_rid()]
					var hit := space.intersect_ray(q)
					if hit:
						hits.append("%s at %.1f m" % [hit["collider"].name, spot.distance_to(hit["position"])])
			check("the sparring ground is flat (%.2f m across it)" % (hi - lo), hi - lo < 0.25)
			check("...and open: nothing within 4 m %s" % str(hits.slice(0, 4)), hits.is_empty())
			var top: float = isl._flat_zones[0][1] + isl.UP_RISE
			check("...up on the shrine terrace (%.1f vs %.1f)" % [isl.to_local(spot).y, top], absf(isl.to_local(spot).y - top) < 0.3)
			var isao: Node3D = null
			for n in get_nodes_in_group("npcs"):
				if n.npc_name == "Master Isao":
					isao = n
			check("Master Isao in his reading hall", isao != null and isao.global_position.distance_to(isl.reading_hall.get_node("Master").global_position) < 1.0)
			var hc = p.get_node("HealthComponent")
			hc.max_health = 99999.0
			hc.current_health = 99999.0
			story.begin()
			story.step = "tomo"
			p.global_position = spot + Vector3(0, 0.5, 6.0)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.5)
		1:
			var bouts := get_nodes_in_group("arena_bouts")
			bout = bouts[0] if not bouts.is_empty() else null
			check("on the step, coming up: Tomo goes out onto the ground", bout != null and is_instance_valid(bout.rival) and bout.spot.distance_to(spot) < 0.5)
			if bout == null:
				return TK.done(fails + 1)
			p.global_position = bout.rival.global_position + Vector3(0, 0, 2.0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		2:
			var dlg = root.get_node("Dialogue")
			check("walk up: he asks if you're ready", dlg.active and dlg._id == "spar")
			dlg.dialogue_event.emit("spar:go")
			dlg._close()
			until = TK.wait_secs(5.0)
		3:
			check("the bow, the count, the fight (%s)" % bout.phase, bout.phase == "fight")
			bout.rival.global_position = spot + Vector3(-12.0, 0.5, 0.0)
			bout.rival.reset_physics_interpolation()
			p.global_position = spot + Vector3(2.0, 0.5, 0.0)
			p.reset_physics_interpolation()
			until = TK.wait_secs(2.5)
		4:
			check("knocked 12 m off the ground, he's put back on it (%.1f m off)" % spot.distance_to(bout.rival.global_position), spot.distance_to(bout.rival.global_position) < bout.LEASH_R)
			bout.rival.health_component.current_health = 1.0
			until = TK.wait_secs(0.6)
		5:
			check("put him down: black leg learned", p.knows_black_leg())
			check("...and the story's on to the ruins (%s)" % story.step, story.step == "ruins")
			story.reset()
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
