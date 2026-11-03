extends SceneTree
## 1.30 (playtest 2026-11-02 row 7: Morrow dashed out his gate into the sea): Tide Rush's lane ends before water or a
## drop (here the stage's shore), stops in a hard skid, and Morrow's lane stays inside his arena wall: a rush at a captain
## standing out past the gate never takes him out of the arena; a lane cut too short is no rush at all.
const TK := preload("res://tools/dev/test_kit.gd")
const BOSS := "res://scripts/enemies/pirate_boss.gd"
const SHORE_X := 24.0
var stage
var b
var arena: Node3D
var c := Vector3.ZERO
var far := 0.0
var moved := 0.0
var start := Vector3.ZERO
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "water": true, "grunts": [{"post": Vector3(0, 0, -25.0), "yaw": PI, "mode": "stand", "seed": 3,
		"captain": true, "script": BOSS, "title": "Test Boss"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if b and arena and step >= 3:
		var l := arena.to_local(b.global_position)
		far = maxf(far, Vector2(l.x, l.z).length())
		moved = maxf(moved, b.global_position.distance_to(start))
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var R = load("res://scripts/island/redtide_fort.gd")
	match step:
		0:
			if stage.camp.grunts.is_empty():
				return false
			b = stage.camp.grunts[0]
			var gy: float = b.global_position.y
			var from := Vector3(SHORE_X - 12.0, gy, 10.0)
			var lane: float = b._rush_lane(from, Vector3.RIGHT, 17.5)
			var skid: float = b._rush_speed() * b._rush_speed() / (2.0 * b.RUSH_SKID)
			check("a lane at the shore ends before the water (%.1f m of 12, skid %.1f)" % [lane, skid], lane > 4.0 and from.x + lane + skid < SHORE_X)
			check("...a lane inland runs its full length", is_equal_approx(b._rush_lane(from, Vector3.LEFT, 17.5), 17.5))
			# his arena: centred 18 m behind him, the "gate" towards the captain
			arena = Node3D.new()
			p.get_parent().add_child(arena)
			arena.global_position = Vector3(0, gy, -40.0)
			b.arena = arena
			b.global_position = arena.global_position + Vector3(0, 0.1, 6.0)
			b.reset_physics_interpolation()
			p.global_position = arena.global_position + Vector3(0, 0.1, 24.0)
			p.reset_physics_interpolation()
			var in_lane: float = b._rush_lane(b.global_position, Vector3.BACK, 17.5)
			check("his lane toward the gate stops inside the wall (%.1f m)" % in_lane, 6.0 + in_lane + skid < R.WALL_R)
			b.global_position = arena.global_position + Vector3(0, 0.1, R.WALL_R - 4.0)
			check("...and from beside the wall it's too short to rush (%.1f m)" % b._rush_lane(b.global_position, Vector3.BACK, 17.5),
				b._rush_lane(b.global_position, Vector3.BACK, 17.5) < b.RUSH_MIN)
			b.global_position = arena.global_position + Vector3(0, 0.1, 2.0)
			b.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		1:
			b._set_state(b.S.CIRCLE)
			until = TK.wait_ticks(2)
		2:
			start = b.global_position
			b._rush_cd = 0.0
			b._start_rush()
			step = 3
			until = TK.wait_secs(3.0)
			return false
		3:
			check("he rushed at the captain past the gate (moved %.1f m)" % moved, moved > 5.0)
			check("...and never left the arena (%.1f m from its middle, wall %.1f)" % [far, R.WALL_R], far < R.WALL_R - 0.5)
			return TK.done(fails)
	step += 1
	return false
