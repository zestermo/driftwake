extends SceneTree
## 1.23 juggling: the air step toward a launched grunt carries the captain up to it, and an attack there is an air
## combo that hits it and keeps it up.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var p
var g
var G
var hp0 := 0.0
var combo := false


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass", "grunts": [
		{"post": Vector3(0.0, 0, -4.5), "role": "sword", "seed": 61}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if p and p.current_state_name() == "Plunge" and str(p.state_machine.current_state.get("_mode")) == "air_combo":
		combo = true
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 1:
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			p = stage.player
			g = stage.camp.grunts[0]
			p.set_ability("double_jump", true)
			until = TK.wait_secs(0.6)
		1:
			var h := HitData.new()
			h.damage = 4.0
			h.launch = 9.0
			g._on_hit(h, p)
			check("launched (state %d)" % g.state, g.state == G.S.AIR)
			TK.act("jump")
			until = TK.wait_secs(0.25)
		2:
			TK.act("jump")
			until = TK.wait_secs(0.3)
		3:
			var d: float = (p.global_position - g.global_position).length()
			check("the air step chased it up (%.2f m off, %.2f m up)" % [d, p.global_position.y], d < 2.4 and p.global_position.y > 1.0)
			hp0 = g.health.current_health
			TK.act("light_attack")
			until = TK.wait_secs(0.3)
		4:
			check("an attack there is an air combo", combo)
			check("it lands (%.1f -> %.1f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
			check("and it's still up (state %d)" % g.state, g.state == G.S.AIR)
			return TK.done(fails)
	step += 1
	return false
