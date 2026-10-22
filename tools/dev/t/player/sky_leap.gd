extends SceneTree
## Sky Leap (Acrobatics): a tap is still a normal jump; a full charge leaps ~25 m (Haki Legs x3: 40, Heavenward: 60)
## and a little forward, costs its stamina, never tumbles on the way up and lands with no fall damage.
const TK := preload("res://tools/dev/test_kit.gd")
const LEAPS := [[0, false, 25.0, 5.0, 40.0], [3, false, 40.0, 11.0, 40.0], [3, true, 60.0, 15.0, 50.0]]
var stage
var p
var step := 0
var until := 0
var fails := 0
var y0 := 0.0
var peak := 0.0
var apex := Vector3.ZERO
var from := Vector3.ZERO
var seen := {}
var leap := 0
var s0 := 0.0
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _physics_process(_d: float) -> bool:
	if p != null:
		seen[p.current_state_name()] = true
		if p.global_position.y > peak:
			peak = p.global_position.y
			apex = p.global_position
	return false


func _track() -> void:
	peak = p.global_position.y
	from = p.global_position
	seen.clear()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.progression.owned["ac_skyleap"] = true
			p.progression._dirty()
			y0 = p.global_position.y
			TK.press("jump")
			until = TK.wait_ticks(4)
		1:
			_track()
			TK.release("jump")
			until = TK.wait_secs(1.4)
		2:
			check("a tap is a normal jump (%.1f m up, %s)" % [peak - y0, seen.keys()], peak - y0 > 0.8 and peak - y0 < 3.0 and seen.has("Jump"))
			check("back on the ground (%s)" % p.current_state_name(), p.current_state_name() in ["Idle", "Move"])
		3:
			var l: Array = LEAPS[leap]
			p.progression.steps["ac_hakilegs"] = l[0]
			if l[1]:
				p.progression.owned["ac_heavenward"] = true
			p.progression._dirty()
			p.stamina = p.max_stamina
			hp0 = p.health_component.current_health
			TK.press("jump")
			until = TK.wait_secs(1.35)
		4:
			check("charging (%s, %s)" % [p.current_state_name(), p.body_model.current_action()], p.current_state_name() == "SkyLeap" and p.body_model.current_action() == "sky_leap_charge")
			s0 = p.stamina
			_track()
			TK.release("jump")
			until = TK.wait_ticks(4)
		5:
			var l: Array = LEAPS[leap]
			check("leap %d costs %.0f stamina (%.1f)" % [leap, l[4], s0 - p.stamina], absf(s0 - p.stamina - l[4]) < 2.0)
			until = TK.wait_secs(6.5)
		6:
			var l: Array = LEAPS[leap]
			var fwd := Vector2(apex.x - from.x, apex.z - from.z).length()
			check("leap %d reaches %.1f m (want %.0f)" % [leap, peak - from.y, l[2]], absf(peak - from.y - l[2]) < 1.5)
			check("leap %d carries %.1f m forward (want %.0f)" % [leap, fwd, l[3]], absf(fwd - l[3]) < 1.0)
			check("leap %d: no tumble (%s)" % [leap, seen.keys()], not seen.has("Downed"))
			check("leap %d: no fall damage (%.0f -> %.0f)" % [leap, hp0, p.health_component.current_health], p.health_component.current_health >= hp0)
			check("leap %d: landed on your feet (%s)" % [leap, p.current_state_name()], p.current_state_name() in ["Idle", "Move"] and absf(p.global_position.y - y0) < 0.3)
			leap += 1
			if leap < LEAPS.size():
				step = 3
				until = TK.wait_secs(0.3)
				return false
			return TK.done(fails)
	step += 1
	return false
