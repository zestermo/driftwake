extends SceneTree
## A captain-style AI (RivalDuel / CaptainBrain, docs/v1_19_plan.md) duels the captain: it's on the enemies' side and
## out of the captains' groups, draws, closes to its reach and swings with the player's own states (the captain's
## health drops), the captain's blows reach it (a rookie's health drops), a sharp one answers attacks (dodges, parries
## or blocks some of them), and beaten it stays down and says so (defeated).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var r
var rookie
var hp0 := 0.0
var defences := 0
var swings := 0
var got_defeated := false
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## (loaded, not named: a --script compiles before the autoloads RivalDuel reaches through Player)
func duel() -> Script:
	return load("res://scripts/ai/rival_duel.gd")


func face(a: Node3D, b: Node3D) -> void:
	var d: Vector3 = b.global_position - a.global_position
	a.player_model.rotation.y = atan2(d.x, d.z) + PI


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.health_component.current_health = p.health_component.max_health
			hp0 = p.health_component.current_health
			r = duel().spawn(p, 0.9, "cutlass")
			until = TK.wait_ticks(2)
		1:
			check("the rival is an AI captain on the enemies' side", r.is_ai and r.is_in_group("enemies") and r.is_in_group("rivals"))
			check("...out of the captains' groups (the local captain is still the player)", not r.is_in_group("players") and not r.is_in_group("player") and get_first_node_in_group("player") == p)
			until = TK.wait_secs(5.0)
		2:
			var d: float = r.global_position.distance_to(p.global_position)
			check("it drew its cutlass and closed to its reach (%.1f m)" % d, r.armed and d < 3.2)
			until = TK.wait_secs(6.0)
		3:
			var lost: float = hp0 - p.health_component.current_health
			check("it swings with the captain's own moves and hurts the captain (%.0f damage)" % lost, lost > 0.0)
			var lo: Array = r.power.loadout
			check("its loadout fits its cutlass (%s) and it used it (%d casts)" % [str(lo), r.get_node("Brain").casts], lo.filter(func(s): return s != "").size() >= 3 and r.get_node("Brain").casts > 0)
			p.health_component.current_health = p.health_component.max_health
			# the captain attacks the sharp one: count what it answers
			swings = 0
			defences = 0
			until = TK.wait_ticks(1)
		4:
			if swings < 8:
				face(p, r)
				if p.current_state_name() in ["Idle", "Move"]:
					TK.act("light_attack")
					swings += 1
				until = TK.wait_ticks(4)
				return false
			var ans: Dictionary = r.get_node("Brain").answers
			defences = int(ans.get("dodge", 0)) + int(ans.get("parry", 0)) + int(ans.get("block", 0))
			check("a sharp rival answers the captain's attacks (%s, %d swings)" % [str(ans), swings], defences > 0)
			r.queue_free()
			rookie = duel().spawn(p, 0.0, "cutlass")
			rookie.global_position = p.global_position + (-p.player_model.global_basis.z) * 1.6
			rookie.reset_physics_interpolation()
			rookie.defeated.connect(func(): got_defeated = true)
			until = TK.wait_ticks(3)
		5:
			hp0 = rookie.health_component.current_health
			swings = 0
			until = TK.wait_ticks(1)
		6:
			if swings < 10 and rookie.health_component.current_health >= hp0:
				face(p, rookie)
				if p.current_state_name() in ["Idle", "Move"]:
					TK.act("light_attack")
					swings += 1
				until = TK.wait_ticks(6)
				return false
			check("the captain's blows reach a rookie rival (%.0f -> %.0f)" % [hp0, rookie.health_component.current_health], rookie.health_component.current_health < hp0)
			rookie.health_component.take_damage(99999.0)
			until = TK.wait_secs(0.6)
		7:
			check("beaten, it's down (%s) and said so" % rookie.current_state_name(), got_defeated and rookie.current_state_name() == "Downed")
			return TK.done(fails)
	step += 1
	return false
