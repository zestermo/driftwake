extends SceneTree
## Redtide's mountain: the stair is the one way into Morrow's arena. A captain walks off the jetty up the stair and
## through the gate into the arena; dropped at the foot of the cliffs all round (the mountain's outside, its arms'
## ends on the cove, the arena rock's own cliff), running at the rock and jumping, nobody gets up; dropped from high
## over the mountain and the arena, nobody falls through. The fort stands on the stage's dry ground (sea level =
## the ground), Morrow and his guards cleared away.
const TK := preload("res://tools/dev/test_kit.gd")
const FOOT_TICKS := 240
var stage
var p
var fort
var step := 0
var until := 0
var fails := 0
var walk_i := 0
var walk_t := 0
var spots: Array = []
var spot_i := 0
var spot_t := 0
var spot_top := -INF
var drops: Array = []
var drop_i := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _local() -> Vector3:
	return fort.to_local(p.global_position)


func _put(local: Vector3) -> void:
	p.global_position = fort.to_global(local)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _steer_to(local: Vector3) -> void:
	var d: Vector3 = fort.to_global(local) - p.global_position
	stage.camera_rig.rotation.y = atan2(-d.x, -d.z)
	TK.press("move_forward")


## The highest solid under fort-local (x, z), from well above the mountain.
func _surface(x: float, z: float) -> float:
	var top: Vector3 = fort.to_global(Vector3(x, 120.0, z))
	var q := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 200.0, 1)
	q.exclude = [p.get_rid()]
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return fort.to_local(h["position"]).y if not h.is_empty() else -INF


## Out along bearing `a` from the arena, the first ground off the rock (marching in from the open sea).
func _foot(a: float) -> Vector3:
	var dir := Vector3(cos(a), 0.0, sin(a))
	var r := 110.0
	while r > 5.0:
		if _surface(dir.x * r, dir.z * r) > 1.5:
			var out := dir * (r + 1.5)
			return Vector3(out.x, 0.05, out.z)
		r -= 0.5
	return Vector3.INF


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			fort = load("res://scripts/island/redtide_fort.gd").new()
			fort.name = "RedtideRock"
			fort.position = Vector3(0, stage.GROUND_Y, -170)
			var ground := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(400, 2, 400)
			cs.shape = box
			ground.add_child(cs)
			ground.position = Vector3(0, stage.GROUND_Y - 1.0, -170)
			stage.add_child(ground)
			stage.add_child(fort)
			until = TK.wait_ticks(20)
		1:
			for g in fort.find_children("*", "PirateGrunt", true, false):
				g.queue_free()
			fort.guards.queue_free()
			fort.set_process(false)
			_put(Vector3(0, 1.85, 40.0))
			until = TK.wait_ticks(10)
		2:
			# up the stair: each tick, steer for the curve a little ahead, then on in to the arena
			var pts: Array = fort._curve_pts()
			var at := _local()
			while walk_i < pts.size() and Vector2(at.x - pts[walk_i].x, at.z - pts[walk_i].z).length() < 0.8:
				walk_i += 1
			_steer_to(pts[walk_i] if walk_i < pts.size() else fort.ARENA)
			walk_t += 1
			var inside: bool = Vector2(at.x - fort.ARENA.x, at.z - fort.ARENA.z).length() < 3.0 and at.y > fort.TOP - 0.5
			if not inside and walk_t < 60 * 30:
				return false
			TK.release("move_forward")
			check("off the jetty, up the stair and through the gate into the arena (%.1f s, at %s)" % [walk_t / 60.0, at], inside)
			for a in [-PI * 0.5, -0.25, 0.35, -1.1, -2.1, 2.95, 3.6]:
				spots.append(["the mountain's outside cliff, bearing %.2f" % a, _foot(a)])
			var lo: float = fort.OPEN_A - fort.OPEN_HALF
			var hi: float = fort.OPEN_A + fort.OPEN_HALF
			spots.append(["the east arm's end on the cove", _foot(lo + 0.06)])
			spots.append(["the west arm's end on the cove", _foot(hi - 0.06)])
			spots.append(["the arena rock's cliff, east of the stair", _foot(0.84)])
			spots.append(["the arena rock's cliff, west of the stair", _foot(2.2)])
			for s in spots:
				check("found the foot of %s" % s[0], s[1] != Vector3.INF)
			spots = spots.filter(func(s): return s[1] != Vector3.INF)
			spot_i = -1
		3:
			# each spot: run at the arena and keep jumping for a while
			if spot_i >= 0:
				var at := _local()
				spot_top = maxf(spot_top, at.y)
				spot_t += 1
				if spot_t % 20 == 0:
					TK.act("jump")
				if spot_t < FOOT_TICKS:
					_steer_to(fort.ARENA)
					return false
				TK.release("move_forward")
				TK.release("sprint")
				check("from the foot of %s nobody gets up (highest %.1f m, the arena's at %.1f)" % [spots[spot_i][0], spot_top, fort.TOP], spot_top < fort.TOP - 1.0)
			spot_i += 1
			if spot_i < spots.size():
				_put(spots[spot_i][1])
				spot_t = 0
				spot_top = -INF
				TK.press("sprint")
				until = TK.wait_ticks(2)
				return false
			for a in [-PI * 0.5, -1.0, 0.3, 2.9]:
				var c: Dictionary = fort._col(a)
				var r: float = c["rc"]
				drops.append(["on the crest at bearing %.2f" % a, Vector3(cos(a) * r, 0, sin(a) * r)])
			var arm: float = fort.OPEN_A - fort.OPEN_HALF - 0.15
			var ca: Dictionary = fort._col(arm)
			var ra: float = float(ca["rc"]) + float(ca["tw"]) * 0.5
			drops.append(["on the east arm", Vector3(cos(arm) * ra, 0, sin(arm) * ra)])
			drops.append(["in the arena", Vector3(4.0, 0, 3.0)])
			drop_i = -1
		4:
			if drop_i >= 0:
				var at := _local()
				var s := _surface(at.x, at.z)
				check("dropped %s: lands on the rock, not through it (at %.1f, the surface under is %.1f)" % [drops[drop_i][0], at.y, s], at.y > s - 0.6 and at.y > -1.0)
			drop_i += 1
			if drop_i < drops.size():
				var d: Vector3 = drops[drop_i][1]
				_put(Vector3(d.x, _surface(d.x, d.z) + 12.0, d.z))
				until = TK.wait_ticks(180)
				return false
			return TK.done(fails)
	step += 1
	return false
