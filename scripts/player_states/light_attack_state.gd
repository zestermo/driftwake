extends PlayerState
## Light attack combo, shaped by your fighting style (player.style()):
##   sword       diagonal forehand -> flat backhand -> spinning finisher; at a sprint, a running cut
##   katana      high right diagonal -> wide left-to-right cut -> lunging stab (slow, two-handed)
##   axe         diagonal hack -> rising backhand hook -> two-handed overhead smash (knocks down)
##   dual_sword  right forehand -> off-hand cut (an axe hacks, a dagger stabs) -> X-cross with
##               both blades -> twin spin (Twin Spin)
##   sword_pistol diagonal cut -> point-blank shot -> rising cut -> a spin cut and a shot
##               that knocks them flat (Powder Finale); no ball loaded, a shot is a butt-strike
##   dagger      stab -> flat slash -> rising cut -> a turn into a low stab that bleeds (Gutting Strike)
##   dual_dagger slash -> off-hand stab -> scissor across -> whirl into both driven in (Fang Whirl)
##   fist        jab -> cross -> hook -> spinning roundhouse kick
##   claw        (Zoan hybrid) right rake -> left rake -> double rake
## The chain is remembered for a moment after each hit, so you can reposition
## (move, even jump) and the next click continues the combo instead of restarting.
## Pistols shoot instead (Shoot state).

## Each anim's length and hitbox window (its strike frames) come from ActionSpecs.
## "durations" is how long the state lasts before the next hit can chain.
const STYLES := {
	"sword": {"anims": ["slash_r", "slash_l", "slash_spin"], "trails": ["right", "left", "spin"],
		"durations": [0.3, 0.3, 0.46], "impulses": [4.5, 4.5, 6.5],
		"damages": [10.0, 12.0, 22.0], "hitstops": [0.05, 0.05, 0.09], "shakes": [0.09, 0.09, 0.18],
		"reach": "sword", "color": Color(0.45, 0.75, 1.0)},
	# cutlass, attacked at a sprint: one low cut driving through the target,
	# breaking its wind-up
	"sword_dash": {"anims": ["dash_cut"], "trails": ["right"],
		"durations": [0.5], "impulses": [12.0],
		"damages": [14.0], "hitstops": [0.06], "shakes": [0.12],
		"reach": "wide", "color": Color(0.45, 0.75, 1.0), "breaker": true},
	# two-handed: slow, wide cuts with a held wind-up, hitting hard; "drawn": the weapon's drawn
	# slash laid along the blade (DrawnFx)
	"katana": {"anims": ["katana_r", "katana_l", "katana_stab"], "trails": ["", "", ""],
		"durations": [0.62, 0.62, 0.7], "impulses": [5.0, 5.0, 9.0],
		"damages": [18.0, 20.0, 30.0], "hitstops": [0.06, 0.06, 0.1], "shakes": [0.1, 0.1, 0.18],
		"reach": "katana", "color": Color(0.85, 0.92, 1.0), "drawn": "katana"},
	# katana, attacked at a sprint: a quick cut straight out of the scabbard,
	# stepping in a little; catches the target mid-move (breaks wind-ups, staggers)
	# (the follow-through is held about a second before you can move on)
	"katana_draw": {"anims": ["quick_draw"], "trails": [""],
		"durations": [0.95], "impulses": [9.0],
		"damages": [14.0], "hitstops": [0.05], "shakes": [0.1],
		"reach": "katana", "color": Color(0.85, 0.92, 1.0), "breaker": true, "drawn": "katana"},
	# axe: heavy, deliberate hacks with the weight behind them; the finisher
	# smashes down two-handed into the ground and knocks them flat
	"axe": {"anims": ["axe_hack", "axe_hook", "axe_split"], "trails": ["", "", ""],
		"durations": [0.46, 0.46, 0.72], "impulses": [4.0, 4.5, 6.0],
		"damages": [14.0, 15.0, 30.0], "hitstops": [0.065, 0.065, 0.13], "shakes": [0.11, 0.11, 0.28],
		"reach": "sword", "color": Color(1.0, 0.78, 0.5), "slam": true, "drawn": "axe"},
	# two blades, quick and alternating: the blades draw their own paired trails;
	# "hands": which hand cuts ("l": the off hand's weapon changes it, OFFHAND)
	"dual_sword": {"anims": ["dual_1", "dual_2", "dual_cross", "dual_spin"], "trails": ["", "", "", ""],
		"durations": [0.34, 0.34, 0.42, 0.56], "impulses": [4.0, 4.0, 5.0, 6.0],
		"damages": [9.0, 9.0, 15.0, 22.0], "hitstops": [0.045, 0.045, 0.07, 0.1], "shakes": [0.08, 0.08, 0.14, 0.2],
		"reach": "wide", "reaches": ["wide", "wide", "wide", "spin"], "hands": ["r", "l", "x", "x"],
		"color": Color(0.55, 0.85, 1.0), "color_l": Color(0.75, 0.65, 1.0), "tree": "dual"},
	# a cutlass and a pistol: cuts and point-blank shots ("kinds"); "shots": a ball's damage
	"sword_pistol": {"anims": ["sp_cut", "sp_shot", "sp_rise", "sp_finale"], "trails": ["", "", "", ""],
		"kinds": ["cut", "shot", "cut", "cut_shot"], "durations": [0.46, 0.4, 0.48, 0.86], "impulses": [4.5, 3.0, 4.5, 5.0],
		"damages": [10.0, 0.0, 12.0, 11.0], "shots": [0.0, 14.0, 0.0, 20.0],
		"hitstops": [0.05, 0.05, 0.06, 0.08], "shakes": [0.09, 0.1, 0.11, 0.16],
		"reach": "sword", "reaches": ["sword", "sword", "sword", "spin"], "color": Color(1.0, 0.85, 0.7), "tree": "corsair"},
	# one dagger: quick and close - a stab, a slash, a rising cut, and (Gutting Strike)
	# a turn into a low stab that bleeds them; "bleeds": seconds a hit makes them bleed
	"dagger": {"anims": ["dg_stab", "dg_slash", "dg_rise", "dg_gut"], "trails": ["", "", "", ""],
		"durations": [0.26, 0.28, 0.3, 0.5], "impulses": [4.5, 4.0, 4.5, 6.0],
		"damages": [7.0, 7.0, 9.0, 15.0], "hitstops": [0.035, 0.035, 0.045, 0.08], "shakes": [0.06, 0.06, 0.08, 0.16],
		"reach": "dagger", "color": Color(1.0, 0.78, 0.82), "tree": "dagger", "bleeds": [0.0, 0.0, 0.0, 4.0]},
	# two daggers: a slash, a stab with the other, a scissor across, and (Fang Whirl) a
	# whirl into both driven in
	"dual_dagger": {"anims": ["dd_1", "dd_2", "dd_3", "dd_4"], "trails": ["", "", "", ""],
		"durations": [0.24, 0.24, 0.32, 0.52], "impulses": [4.0, 4.0, 5.0, 5.5],
		"damages": [6.0, 6.0, 11.0, 17.0], "hitstops": [0.03, 0.03, 0.05, 0.08], "shakes": [0.05, 0.05, 0.1, 0.16],
		"reach": "dagger", "reaches": ["dagger", "dagger", "wide", "spin"], "color": Color(0.78, 1.0, 0.62), "color_l": Color(0.92, 1.0, 0.7),
		"tree": "dual_dagger", "bleeds": [0.0, 0.0, 0.0, 4.0]},
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

## A dual-wield cut with the off hand, by what's in it: [damage, knockback, hit-stop,
## chain shift (s)]: an axe hits harder and recovers later, a dagger lighter and sooner.
const OFFHAND := {"sword": [1.0, 1.0, 1.0, 0.0], "axe": [1.25, 1.4, 1.4, 0.06], "dagger": [0.85, 0.8, 0.8, -0.06]}
## The combo's last hit is a skill-tree unlock (a "move" node) for these styles.
const FOURTH := {"fist": "roundhouse", "dual_sword": "twin_spin", "sword_pistol": "powder_finale",
	"dagger": "gut_strike", "dual_dagger": "fang_whirl"}

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
## When the blade's own trail is drawn (moves on a swing path), seconds; x < 0: arc effects.
var _swoosh := Vector2(-1, -1)
var _swooshed: bool = false
## This hit: "cut", "shot" (the sword-and-pistol's point-blank shot, no blade) or
## "cut_shot"; when its shot fires (s); the off hand's weapon numbers (OFFHAND).
var _kind := "cut"
var _shot_t := -1.0
var _shot_done := false
var _off: Array = OFFHAND["sword"]


func enter(data: Dictionary) -> void:
	var st := player.style()
	if player.quick_draw:
		st = "katana_draw" if st == "katana" else "sword_dash"
		player.quick_draw = false
	cfg = STYLES.get(st, STYLES["sword"])
	combo_count = (cfg["anims"] as Array).size()
	if FOURTH.has(st) and not player.progression.has_move(str(FOURTH[st])):
		combo_count -= 1
	# Continue the remembered chain unless this attack came straight from a chain.
	combo_index = int(data.get("combo_index", 0)) if data.get("chain", false) else player.next_combo_index()
	combo_index = clampi(combo_index, 0, combo_count - 1)
	player.set_reach(str((cfg["reaches"] as Array)[combo_index]) if cfg.has("reaches") else str(cfg["reach"]))
	_kind = str((cfg["kinds"] as Array)[combo_index]) if cfg.has("kinds") else "cut"
	_shot_done = false
	_off = OFFHAND["sword"]
	if cfg.has("hands") and str((cfg["hands"] as Array)[combo_index]) == "l":
		_off = OFFHAND.get(player.offhand_kind(), OFFHAND["sword"])
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
	_swoosh = ActionSpecs.swoosh_seconds(anim)
	_swooshed = false
	_shot_t = ActionSpecs.shot_seconds(anim) if _kind != "cut" else -1.0
	player.body_model.play(anim, ActionSpecs.length(anim))
	player.squash(-1.5 if combo_index < 2 else -2.5)


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 15.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, 15.0 * delta)
	player.move_and_slide()

	timer += delta

	# a swing path's trail comes off the blade itself, from just before the strike
	if _swoosh.x >= 0.0 and timer >= _swoosh.x and not _swooshed:
		_swooshed = true
		var sc: Color = Player.HAKI_TRAIL if player.power.buff("coat") else _trail_col()
		var sl: Color = Player.HAKI_TRAIL if player.power.buff("coat") else _trail_col(true)
		# (an awakened drawn element is its trail: the thin line of light under it went)
		var dk := str(cfg.get("drawn", ""))
		if dk == "" or not DrawnFx.awake(player, dk) or player.power.buff("coat"):
			Net.fx("blade_swoosh", [player.body_model, _swoosh.y - _swoosh.x, sc, sl])
		if dk != "":
			DrawnFx.slash(player, dk, _swoosh.y - _swoosh.x, str(cfg["anims"][combo_index]) == "katana_stab", 1.25 if combo_index == combo_count - 1 and dk == "axe" else 1.0)

	if _shot_t >= 0.0 and timer >= _shot_t and not _shot_done:
		_shot_done = true
		_shot()

	if timer >= _window.x and not hitbox_activated and _kind == "shot":
		hitbox_activated = true
	if timer >= _window.x and not hitbox_activated:
		hitbox_activated = true
		var last := combo_index == combo_count - 1
		var hit := player.melee_hit(float(cfg["damages"][combo_index]) * float(_off[0]), "finisher" if last else "")
		hit.hitstop_duration = float(cfg["hitstops"][combo_index]) * float(_off[2])
		hit.camera_shake_intensity = float(cfg["shakes"][combo_index]) * float(_off[2])
		hit.knockback_force = (8.0 if last else 4.0) * float(_off[1])
		hit.breaker = cfg.get("breaker", false)
		hit.sever = str(cfg["reach"]) != "fist"
		if cfg.has("bleeds") and float(cfg["bleeds"][combo_index]) > 0.0:
			hit.set_meta("bleed", float(cfg["bleeds"][combo_index]))
		# (the axe's finisher puts them on the ground)
		hit.knockdown = last and cfg.get("slam", false)
		player.sword_hitbox.activate(hit)
		if last and cfg.get("slam", false):
			var fwd := -player.player_model.global_basis.z
			var at := player.global_position + fwd * 1.2
			# a short crack where it bites, rock thrown up (molten, with embers, at the tree's tier 2)
			var hot := player.progression.elemental("axe", 2)
			Net.fx("ground_crack", [at - fwd * 0.3, fwd, 1.8, FX.tree_col("axe", FX.ACCENT) if hot else Color(0, 0, 0, 0), randi() % 10000, 0.08])
			Net.fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP + fwd * 0.2, 6, Color(0.35, 0.3, 0.25), 4.5])
			if hot:
				Net.fx("embers", [at + Vector3(0, 0.2, 0), Vector3.UP, 8, FX.tree_col("axe", FX.ACCENT), 3.5])
			Net.fx("dust_ring", [at, 16, 1.1])
			Net.fx("impact", [at + Vector3(0, 0.2, 0), Color(1.0, 0.85, 0.55)])
			Net.fx("sfx", ["thud", at, -2.0, 0.05, 0.75])
			CombatManager.apply_camera_shake(0.18)
			CombatManager.apply_camera_kick(0.12, 0.25)
		# swoosh!
		var trail_len := 0.4 if last else 0.26
		var trail := str(cfg["trails"][combo_index])
		var col: Color = _trail_col()
		if player.power.buff("coat"):
			col = Player.HAKI_TRAIL
		if _swoosh.x >= 0.0:
			pass  # (the blade draws its own trail)
		elif trail == "cross":
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

	var duration := float(AnimLab.spec(str(cfg["anims"][combo_index])).get("chain", cfg["durations"][combo_index])) + float(_off[3])
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


## The combo's trail: the style's own colour, or its tree's once the element
## follows every blow (the tree's second mastery passive). `left`: the off hand's
## blade (the dual blades' second colour).
func _trail_col(left: bool = false) -> Color:
	var tree := SkillTree.style_tree(player.style())
	if tree != "" and player.progression.elemental(tree, 2):
		return FX.tree_col(tree, FX.ACCENT if left and FX.TWIN_TREES.has(tree) else FX.EDGE)
	return cfg.get("color_l", cfg["color"]) if left else cfg["color"]


## The sword-and-pistol's shot: a ball point-blank into whoever's in front (the
## finisher's knocks them flat), or the pistol's butt with nothing loaded.
func _shot() -> void:
	var last := combo_index == combo_count - 1
	var fwd := -player.player_model.global_basis.z
	var elem := player.progression.elemental("corsair", 2)
	CorsairGun.shoot_or_butt(player, fwd, float(cfg["shots"][combo_index]), "finisher" if last else "",
		{"knock": 10.0 if last else 5.0, "stagger": 0.6 if last else 0.4, "down": last, "stop": 0.09 if last else 0.05,
		"shake": 0.2 if last else 0.1, "elem": elem, "size": 1.4 if last else 1.0})
	CombatManager.apply_camera_kick(0.14 if last else 0.06, 0.22)
	player.squash(-1.5 if last else -1.0)


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
