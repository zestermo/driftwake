extends SceneTree
## Air Dash (Acrobatics, 1.30): in mid-air the dodge dashes the way you hold, level, ~6.5 m (Dash Distance further),
## once before you land (Twin Dash: twice), and teaches Acrobatics; Dash Strike: an attack out of it dives on along the
## dash (the plunge). A plain jump teaches nothing.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0
var a := Vector3.INF
var b := Vector3.INF
var x0 := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _physics_process(_d: float) -> bool:
	if p != null:
		if p.current_state_name() == "Dodge" and a == Vector3.INF:
			a = p.global_position
		elif a != Vector3.INF and b == Vector3.INF and p.current_state_name() != "Dodge":
			b = p.global_position
	return false


func xp() -> int:
	return int(pr.mastery_of("acrobatics")["xp"])


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			pr.owned["ac_airdash"] = true
			pr._dirty()
			p.global_position.y += 9.0
			p.reset_physics_interpolation()
			p.state_machine.force_state("Fall", {})
			until = TK.wait_ticks(4)
		1:
			x0 = xp()
			TK.press("move_right")
			TK.act("dodge")
			until = TK.wait_secs(0.5)
		2:
			TK.release("move_right")
			var d := Vector2(b.x - a.x, b.z - a.z).length()
			check("an air dash, the way you hold (%.1f m, +x %.1f)" % [d, b.x - a.x], a != Vector3.INF and b != Vector3.INF and b.x - a.x > 5.0 and absf(d - p.state_machine.states["dodge"].AIR_DASH_DIST) < 1.0)
			check("...level (%.2f m drop)" % (a.y - b.y), a.y - b.y < 0.6)
			check("...teaches Acrobatics (+%d)" % (xp() - x0), xp() - x0 == pr.ACRO_XP["air_dash"])
			TK.act("dodge")
			until = TK.wait_ticks(4)
		3:
			check("once before you land (%s)" % p.current_state_name(), p.current_state_name() != "Dodge")
			until = TK.wait_secs(1.5)
		4:
			check("landed", p.is_on_floor())
			pr.owned["ac_dashstrike"] = true
			pr._dirty()
			until = TK.wait_secs(0.3)
		5:
			p.global_position.y += 8.0
			p.reset_physics_interpolation()
			p.state_machine.force_state("Fall", {})
			until = TK.wait_ticks(4)
		6:
			TK.press("move_right")
			TK.act("dodge")
			until = TK.wait_ticks(6)
		7:
			TK.act("light_attack")
			until = TK.wait_ticks(3)
		8:
			TK.release("move_right")
			var st = p.state_machine.states["plunge"]
			check("Dash Strike: an attack out of the dash dives on along it (%s)" % p.current_state_name(), p.current_state_name() == "Plunge" and st._dash and st._dir.x > 0.7)
			until = TK.wait_ticks(8)
		9:
			check("...diving down and forward (%s)" % str(p.velocity), p.velocity.x > 5.0 and p.velocity.y < -5.0)
			return TK.done(fails)
	step += 1
	return false
