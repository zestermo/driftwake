extends PlayerState
## Light attack combo, shaped by your fighting style (player.style()):
##   sword       diagonal forehand -> flat backhand -> spinning finisher; at a sprint, a running cut
##   katana      high right diagonal -> wide left-to-right cut -> lunging stab (slow, two-handed)
##   axe         diagonal hack -> rising backhand hook -> two-handed overhead smash (knocks down)
##   dual_sword  forehand -> backhand -> X-cross with both blades -> twin spin
##   fist        jab -> cross -> hook -> spinning roundhouse kick
##   claw        (Zoan hybrid) right rake -> left rake -> double rake
## The chain is remembered for a moment after each hit, so you can reposition
## (move, even jump) and the next click continues the combo instead of restarting.
## Pistols shoot instead (Shoot state).

## Each anim's length and hitbox window (its strike frames) come from ActionSpecs.
## "durations" is how long the state lasts before the next hit can chain.
const STYLES := {
	"sword": {"anims": ["slash_r", "slash_l", "spin_slash"], "trails": ["right", "left", "spin"],
		"durations": [0.3, 0.3, 0.46], "impulses": [4.5, 4.5, 6.5],
		"damages": [10.0, 12.0, 22.0], "hitstops": [0.05, 0.05, 0.09], "shakes": [0.09, 0.09, 0.18],
		"reach": "sword", "color": Color(0.45, 0.75, 1.0)},
	# cutlass, attacked at a sprint: one low cut driving through the target,
	# breaking its wind-up
	"sword_dash": {"anims": ["dash_cut"], "trails": ["right"],
		"durations": [0.5], "impulses": [12.0],
		"damages": [14.0], "hitstops": [0.06], "shakes": [0.12],
		"reach": "wide", "color": Color(0.45, 0.75, 1.0), "breaker": true},
	# two-handed: slow, wide cuts with a held wind-up, hitting hard
	"katana": {"anims": ["katana_r", "katana_l", "katana_stab"], "trails": ["kesa_r", "sweep_l", "thrust"],
		"durations": [0.62, 0.62, 0.7], "impulses": [5.0, 5.0, 9.0],
		"damages": [16.0, 18.0, 26.0], "hitstops": [0.06, 0.06, 0.1], "shakes": [0.1, 0.1, 0.18],
		"reach": "katana", "color": Color(0.85, 0.92, 1.0)},
	# katana, attacked at a sprint: a quick cut straight out of the scabbard,
	# stepping in a little; catches the target mid-move (breaks wind-ups, staggers)
	# (the follow-through is held about a second before you can move on)
	"katana_draw": {"anims": ["quick_draw"], "trails": ["iai"],
		"durations": [0.95], "impulses": [9.0],
		"damages": [14.0], "hitstops": [0.05], "shakes": [0.1],
		"reach": "katana", "color": Color(0.85, 0.92, 1.0), "breaker": true},
	# axe: heavy, deliberate hacks with the weight behind them; the finisher
	# smashes down two-handed into the ground and knocks them flat
	"axe": {"anims": ["axe_hack", "axe_hook", "axe_split"], "trails": ["kesa_r", "left", "overhead"],
		"durations": [0.46, 0.46, 0.72], "impulses": [4.0, 4.5, 6.0],
		"damages": [14.0, 15.0, 30.0], "hitstops": [0.065, 0.065, 0.13], "shakes": [0.11, 0.11, 0.28],
		"reach": "sword", "color": Color(1.0, 0.78, 0.5), "slam": true},
	"dual_sword": {"anims": ["dual_1", "dual_2", "dual_cross", "dual_spin"], "trails": ["right", "left", "cross", "spin"],
		"durations": [0.24, 0.24, 0.32, 0.44], "impulses": [4.0, 4.0, 5.0, 6.0],
		"damages": [8.0, 8.0, 13.0, 20.0], "hitstops": [0.035, 0.035, 0.06, 0.09], "shakes": [0.07, 0.07, 0.12, 0.18],
		"reach": "wide", "color": Color(0.55, 0.85, 1.0)},
	"fist": {"anims": ["jab", "cross", "hook", "roundhouse"], "trails": ["", "", "", ""],
		"durations": [0.2, 0.22, 0.28, 0.42], "impulses": [3.0, 3.5, 3.5, 4.5],
		"damages": [6.0, 7.0, 9.0, 16.0], "hitstops": [0.03, 0.035, 0.05, 0.08], "shakes": [0.05, 0.06, 0.09, 0.15],
		"reach": "fist", "color": Color(1.0, 0.95, 0.8),
		# rush of air for each hit: [side (m, + = right), height, sideways slant, big]
		"winds": [[-0.16, 1.32, 0.0, false], [0.16, 1.3, 0.0, false], [-0.5, 1.28, 0.55, false], [0.35, 1.0, -0.35, true]]},
	"claw": {"anims": ["claw_r", "claw_l", "claw_double"], "trails": ["right", "left", "cross"],
		"durations": [0.28, 0.28, 0.44], "impulses": [6.5, 6.5, 9.0],
		"damages": [12.0, 12.0, 22.0], "hitstops": [0.05, 0.05, 0.09], "shakes": [0.1, 0.1, 0.2],
		"reach": "claw", "color": Color(1.0, 0.35, 0.3)},
}

var cfg: Dictionary = STYLES["sword"]
var combo_count: int = 3
## Time after the chain opens during which another click continues instantly.
@export var combo_window: float = 0.45

var combo_index: int = 0
var timer: float = 0.0
var can_combo: bool = false
var combo_timer: float = 0.0
var hitbox_activated: bool = false
var hitbox_deactivated: bool = false
var chained: bool = false
var _window := Vector2.ZERO


func enter(data: Dictionary) -> void:
	var st := player.style()
	if player.quick_draw:
		st = "katana_draw" if st == "katana" else "sword_dash"
		player.quick_draw = false
	cfg = STYLES.get(st, STYLES["sword"])
	combo_count = (cfg["anims"] as Array).size()
	# the fourth hit is a skill-tree unlock (Roundhouse / Twin Spin)
	if (st == "fist" and not player.progression.has_move("roundhouse")) or (st == "dual_sword" and not player.progression.has_move("twin_spin")):
		combo_count -= 1
	player.set_reach(str(cfg["reach"]))
	# Continue the remembered chain unless this attack came straight from a chain.
	combo_index = int(data.get("combo_index", 0)) if data.get("chain", false) else player.next_combo_index()
	combo_index = clampi(combo_index, 0, combo_count - 1)
	player.reset_combo()
	timer = 0.0
	can_combo = false
	combo_timer = 0.0
	hitbox_activated = false
	hitbox_deactivated = false
	chained = false

	var forward := get_camera_forward()
	player.player_model.rotation.y = atan2(-forward.x, -forward.z)
	player.velocity.x = forward.x * float(cfg["impulses"][combo_index])
	player.velocity.z = forward.z * float(cfg["impulses"][combo_index])
	var anim := str(cfg["anims"][combo_index])
	_window = ActionSpecs.hit_seconds(anim)
	player.body_model.play(anim, ActionSpecs.length(anim))
	player.squash(-1.5 if combo_index < 2 else -2.5)


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 15.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, 15.0 * delta)
	player.move_and_slide()

	timer += delta

	if timer >= _window.x and not hitbox_activated:
		hitbox_activated = true
		var last := combo_index == combo_count - 1
		var hit := player.melee_hit(float(cfg["damages"][combo_index]), "finisher" if last else "")
		hit.hitstop_duration = float(cfg["hitstops"][combo_index])
		hit.camera_shake_intensity = float(cfg["shakes"][combo_index])
		hit.knockback_force = 8.0 if last else 4.0
		hit.breaker = cfg.get("breaker", false)
		hit.sever = str(cfg["reach"]) != "fist"
		# (the axe's finisher puts them on the ground)
		hit.knockdown = last and cfg.get("slam", false)
		player.sword_hitbox.activate(hit)
		if last and cfg.get("slam", false):
			var at := player.global_position - player.player_model.global_basis.z * 1.2
			Net.fx("dust_ring", [at, 16, 1.1])
			Net.fx("impact", [at + Vector3(0, 0.2, 0), Color(1.0, 0.85, 0.55)])
			Net.fx("sfx", ["thud", at, -2.0, 0.05, 0.75])
			CombatManager.apply_camera_shake(0.18)
		# swoosh!
		var trail_len := 0.4 if last else 0.26
		var trail := str(cfg["trails"][combo_index])
		var col: Color = cfg["color"]
		if player.power.buff("coat"):
			col = Player.HAKI_TRAIL
		if trail == "cross":
			Net.fx("slash", [player.player_model, "right", trail_len, col])
			Net.fx("slash", [player.player_model, "left", trail_len, col])
		elif trail != "":
			Net.fx("slash", [player.player_model, trail, trail_len, col])
		var punchy := str(cfg["reach"]) == "fist"
		if cfg.has("winds"):
			_punch_wind((cfg["winds"] as Array)[combo_index], col)
		Net.fx("sfx", ["whoosh", player.global_position, -8.0 if punchy else -6.0, 0.12, (1.35 if punchy else 1.0) + combo_index * 0.08])
		player.squash(1.5)
		if last:
			Net.fx("dust_ring", [player.global_position, 8, 0.6])

	if timer >= _window.y and not hitbox_deactivated:
		hitbox_deactivated = true
		player.sword_hitbox.deactivate()

	var duration := float(AnimLab.spec(str(cfg["anims"][combo_index])).get("chain", cfg["durations"][combo_index]))
	if timer >= duration and not can_combo:
		can_combo = true
		combo_timer = combo_window

	if can_combo:
		combo_timer -= delta
		if input_buffer.consume_action("light_attack") and player.spend_stamina(player.LIGHT_COST * player.attack_cost_k()):
			chained = true
			transitioned.emit(self, "LightAttack", {"combo_index": (combo_index + 1) % combo_count, "chain": true})
			return
		if wants_dodge():
			transitioned.emit(self, "Dodge", {})
			return
		# reposition between hits without losing the chain
		if get_movement_input().length() > 0.1:
			transitioned.emit(self, "Move", {})
			return
		if Input.is_action_just_pressed("jump"):
			transitioned.emit(self, "Jump", {})
			return
		if combo_timer <= 0.0:
			transitioned.emit(self, "Idle", {})
			return


## The straight streak of air in front of a punch or kick.
func _punch_wind(w: Array, col: Color) -> void:
	var b := player.player_model.global_basis
	var fwd := -b.z
	var right := b.x
	var from := player.global_position + Vector3.UP * float(w[1]) + right * float(w[0]) + fwd * 0.25
	var dir := (fwd + right * float(w[2])).normalized()
	var c := col if player.power.buff("coat") else Color(1.0, 0.97, 0.9)
	Net.fx("punch_wind", [from, dir, 1.25 if not bool(w[3]) else 1.5, c, bool(w[3])])


func exit() -> void:
	player.sword_hitbox.deactivate()
	player.sword_pivot.rotation_degrees.z = 0.0
	if not chained:
		if combo_index < combo_count - 1:
			player.remember_combo(combo_index + 1)
		else:
			player.reset_combo()
