extends SceneTree
## The Strangler's train (docs/v1_20_beasts.md 2; Zach: it barely came into its arena): it goes under the brush and
## comes out at the floor's edge, crossing the whole floor in a straight line and out the far side (each pass at least
## the floor's width), twice; it hits like a train (a knockdown) and ends lying there open (a recovery).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var s
var step := 0
var until := 0
var fails := 0
var passes := 0
var was_hidden := false
var lo := Vector3.INF
var hi := -Vector3.INF
var longest := 0.0
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			var at: Vector3 = p.global_position + Vector3(0, 0, -14.0)
			s = load("res://scripts/enemies/beasts/strangler.gd").new()
			s.setup({"post": at, "yaw": 0.0, "level": 6, "name": "The Strangler"})
			stage.add_child(s)
			s.global_position = at
			until = TK.wait_ticks(10)
			step = 1
		1:
			s.alert()
			until = TK.wait_secs(2.5)
			step = 2
		2:
			hp0 = p.get_node("HealthComponent").current_health
			s.film("train")
			step = 3
		3:
			var hidden: bool = not s.model.visible
			if was_hidden and not hidden:
				# out of the brush: a new pass
				passes += 1
				lo = s.global_position
				hi = s.global_position
			was_hidden = hidden
			if not hidden and s.move == "train":
				lo = Vector3(minf(lo.x, s.global_position.x), 0, minf(lo.z, s.global_position.z))
				hi = Vector3(maxf(hi.x, s.global_position.x), 0, maxf(hi.z, s.global_position.z))
				longest = maxf(longest, (hi - lo).length())
			if s.move == "train":
				return false
			var floor_w: float = 2.0 * float(load("res://scripts/island/beast_arena.gd").FLOOR_R)
			check("it comes out of the brush and crosses, %d passes" % passes, passes >= 2)
			check("each pass runs the whole floor and beyond (%.1f m, the floor %.0f m)" % [longest, floor_w], longest >= floor_w)
			check("it hits like a train (%.0f hp taken)" % (hp0 - p.get_node("HealthComponent").current_health), p.get_node("HealthComponent").current_health < hp0)
			check("then it lies there open (a recovery: %.2f)" % s.mv_t, s.mv_t < 0.0 and s.model.visible)
			return TK.done(fails)
	return false
