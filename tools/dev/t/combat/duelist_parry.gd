extends SceneTree
## 1.30 the Duelist: it reads a captain's light swing (the parry raised, a blue glint), and a blow inside that window is
## turned aside (no damage, "Parried!"), the captain reels and it ripostes; a heavy into the raised guard breaks it.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g
var G
var step := 0
var until := 0
var fails := 0
var tries := 0
var hp := 0.0
var read := false
var parried := false
var reeled := false
var riposte := false


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass", "grunts": [{"post": Vector3(0, 0, -2.0), "role": "sword", "seed": 21, "personality": "duelist"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func set_up() -> void:
	g.global_position = Vector3(0, g.global_position.y, -1.9)
	var to: Vector3 = p.global_position - g.global_position
	g.facing.rotation.y = atan2(-to.x, -to.z)
	g._yaw = g.facing.rotation.y
	g._set_state(G.S.CIRCLE)
	g._cooldown = 99.0
	g._parry_cd = 0.0
	g._foe_st = ""
	g.health.current_health = g.health.max_health
	hp = g.health.current_health


func _process(_d: float) -> bool:
	if g and G and g._parry_t > 0.0:
		read = true
	if g and G and g.state == G.S.BLOCK and g.humanoid.current_action() == "fo_parry":
		parried = true
	if p and p.current_state_name() == "Stagger":
		reeled = true
	if parried and g.state == G.S.WIND:
		riposte = true
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 1:
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			p = stage.player
			g = stage.camp.grunts[0]
			g.alert()
			until = TK.wait_secs(0.8)
		1:
			# swing at it until it reads one (PARRY_ODDS of the time) and the blow lands in the window
			set_up()
			read = false
			parried = false
			reeled = false
			riposte = false
			TK.act("light_attack")
			until = TK.wait_secs(0.9)
		2:
			tries += 1
			if not parried and tries < 12:
				step = 1
				until = TK.wait_secs(0.5)
				return false
			check("it reads the swing (the window opens)", read)
			check("the blow is parried (no damage)", parried and g.health.current_health >= hp)
			check("the captain reels", reeled)
			check("it ripostes", riposte)
			p.hurtbox.monitorable = false
			until = TK.wait_secs(1.5)
		3:
			# a heavy into the raised parry breaks it: the blow lands and it reels long
			set_up()
			g._parry_t = 0.6
			var h := HitData.new()
			h.damage = 5.0
			h.poise = 25.0
			h.knockback_force = 1.0
			g._on_hit(h, p)
			check("a heavy breaks the parry (damage taken)", g.health.current_health < hp)
			check("and it reels long", g.state == G.S.STAGGER and g._stagger_len >= 1.3)
			return TK.done(fails)
	step += 1
	return false
