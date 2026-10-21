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
##   polearm     thrust -> rising cut -> flat sweep -> a full turn (Wheel Sweep); at a sprint, Leg Sweep
##   hammer      overhead smash -> upswing -> flat swing (breaks a guard) -> a full turn into the ground
##               (Wrecking Spin); at a sprint, Rising Crush
##   dual_axe    right chop -> left chop -> the hook (drags them in) -> two turns with both axes out
##               (Reaping Whirl); at a sprint, Raider's Leap
##   greatsword  rising diagonal -> falling diagonal -> flat backhand (breaks a guard) -> a full turn (Gale Turn),
##               each out of the last one's follow-through, faster and harder as the momentum builds; at a sprint,
##               Running Cleave
##   black_leg   low kick -> mid kick -> high kick -> down on the hands spinning (Handstand Spin); at a sprint,
##               Arrow Kick
##   fist       jab -> cross -> hook -> spinning roundhouse kick
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
	# two-handed: slow, wide cuts with a held wind-up, hitting hard; "drawn": the katana's drawn
	# slash laid along the blade (FX.katana_slash)
	"katana": {"anims": ["katana_r", "katana_l", "katana_stab"], "trails": ["", "", ""],
		"durations": [0.62, 0.62, 0.7], "impulses": [5.0, 5.0, 9.0],
		"damages": [18.0, 20.0, 30.0], "hitstops": [0.06, 0.06, 0.1], "shakes": [0.1, 0.1, 0.18],
		"reach": "katana", "color": Color(0.85, 0.92, 1.0), "drawn": true},
	# katana, attacked at a sprint: a quick cut straight out of the scabbard,
	# stepping in a little; catches the target mid-move (breaks wind-ups, staggers)
	# (the follow-through is held about a second before you can move on)
	"katana_draw": {"anims": ["quick_draw"], "trails": [""],
		"durations": [0.95], "impulses": [9.0],
		"damages": [14.0], "hitstops": [0.05], "shakes": [0.1],
		"reach": "katana", "color": Color(0.85, 0.92, 1.0), "breaker": true, "drawn": true},
	# axe: heavy, deliberate hacks with the weight behind them; the finisher
	# smashes down two-handed into the ground and knocks them flat
	"axe": {"anims": ["axe_hack", "axe_hook", "axe_split"], "trails": ["kesa_r", "left", "overhead"],
		"durations": [0.46, 0.46, 0.72], "impulses": [4.0, 4.5, 6.0],
		"damages": [14.0, 15.0, 30.0], "hitstops": [0.065, 0.065, 0.13], "shakes": [0.11, 0.11, 0.28],
		"reach": "sword", "color": Color(1.0, 0.78, 0.5), "slam": true},
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
	# polearm: a thrust that hits from three paces, a rising cut, a wide flat sweep and (Wheel Sweep) the spear
	# swung round once all about you; "pole": a design's speed and pierce apply (WeaponDesigns.pole)
	"polearm": {"anims": ["pole_thrust", "pole_rise", "pole_sweep", "pole_wheel"], "trails": ["", "", "", ""],
		"durations": [0.42, 0.46, 0.58, 0.74], "impulses": [5.5, 4.5, 4.0, 3.0],
		"damages": [10.0, 11.0, 15.0, 20.0], "hitstops": [0.05, 0.05, 0.07, 0.1], "shakes": [0.08, 0.09, 0.13, 0.2],
		"reach": "pole", "reaches": ["pole", "pole_sweep", "pole_sweep", "pole_spin"], "color": Color(1.0, 0.93, 0.72), "pole": true},
	# polearm, attacked at a sprint (Leg Sweep): dropped into a kneeling slide, the head swept flat through their
	# shins; it breaks a wind-up and puts them on the ground
	"pole_dash": {"anims": ["pole_legsweep"], "trails": [""],
		"durations": [0.62], "impulses": [11.0],
		"damages": [13.0], "hitstops": [0.06], "shakes": [0.14],
		"reach": "pole_low", "color": Color(1.0, 0.93, 0.72), "breaker": true, "trip": true, "pole": true},
	# hammer: off the shoulder and down across the front into the ground, an upswing, a flat swing at the waist
	# that breaks a guard, and (Wrecking Spin) one full turn ending in the head brought down; slow, every blow
	# shoves them back ("knocks", x the design's weight: WeaponDesigns.hammer), the big ones are "breakers"
	# and the spin puts them down ("downs"); the head thuds into the ground on HammerMoves.THUD
	"hammer": {"anims": ["ham_smash", "ham_upper", "ham_sweep", "ham_spin"], "trails": ["", "", "", ""],
		"durations": [0.58, 0.56, 0.7, 0.95], "impulses": [4.0, 4.0, 3.5, 2.5],
		"damages": [14.0, 15.0, 21.0, 26.0], "hitstops": [0.08, 0.08, 0.11, 0.14], "shakes": [0.13, 0.13, 0.2, 0.28],
		"knocks": [7.0, 7.5, 11.0, 12.0], "breakers": [false, false, true, true], "downs": [false, false, false, true],
		"reach": "hammer", "reaches": ["hammer", "hammer", "hammer_wide", "hammer_spin"], "color": Color(0.92, 0.86, 0.74), "hammer": true},
	# hammer, attacked at a sprint (Rising Crush): the head dragged low, then swung up off the ground through
	# them; it breaks a wind-up and throws them down
	"ham_dash": {"anims": ["ham_rush"], "trails": [""],
		"durations": [0.62], "impulses": [10.0],
		"damages": [17.0], "hitstops": [0.1], "shakes": [0.2],
		"knocks": [11.0], "breakers": [true], "downs": [true],
		"reach": "hammer_low", "color": Color(0.92, 0.86, 0.74), "breaker": true, "hammer": true},
	# twin axes: quick chops trading hands (right, left), the hook (the left axe round them and yanked back: it
	# drags them in) and (Reaping Whirl) both axes out level and two turns that put them down; "lefts": the off
	# hand's axe strikes (its own power); "pair": the pair's speed (DualAxeArts.pair)
	"dual_axe": {"anims": ["dx_1", "dx_2", "dx_3", "dx_4"], "trails": ["", "", "", ""],
		"durations": [0.28, 0.28, 0.36, 0.62], "impulses": [4.5, 4.5, 3.0, 4.0],
		"damages": [10.0, 10.0, 12.0, 24.0], "hitstops": [0.05, 0.05, 0.07, 0.1], "shakes": [0.1, 0.1, 0.13, 0.2],
		"reach": "twin_axe", "reaches": ["twin_axe", "twin_axe", "hook", "spin"], "lefts": [false, true, true, false],
		"color": Color(0.86, 0.92, 1.0), "color_l": Color(0.7, 0.8, 0.98), "pair": true, "hooks": [false, false, true, false]},
	# twin axes, attacked at a sprint (Raider's Leap): launched up with both raised, crashed down crossed into
	# them; it breaks a wind-up and puts them down
	"dx_dash": {"anims": ["dx_rush"], "trails": [""],
		"durations": [0.56], "impulses": [11.0],
		"damages": [16.0], "hitstops": [0.08], "shakes": [0.18], "lefts": [false],
		"reach": "twin_axe", "color": Color(0.86, 0.92, 1.0), "color_l": Color(0.7, 0.8, 0.98), "breaker": true, "trip": true, "pair": true},
	# greatsword: out of the low guard up across to high right, back down to low left, flat round to the right (breaks a
	# guard) and (Gale Turn) on round in a full turn that puts them down; each blow flows out of the last one's follow-through
	# ("momentum": chained straight on, it plays MOMENTUM_SPEED faster and lands MOMENTUM_DAMAGE harder per blow built);
	# "great": the design's speed, reach, weight and bleed (WeaponDesigns.great)
	"greatsword": {"anims": ["gs_1", "gs_2", "gs_3", "gs_4"], "trails": ["", "", "", ""],
		"durations": [0.48, 0.4, 0.5, 0.95], "impulses": [4.5, 4.0, 3.5, 3.0],
		"damages": [14.0, 15.0, 19.0, 24.0], "hitstops": [0.07, 0.07, 0.1, 0.13], "shakes": [0.12, 0.12, 0.18, 0.26],
		"knocks": [6.5, 7.0, 10.0, 12.0], "breakers": [false, false, true, true], "downs": [false, false, false, true],
		"reach": "great", "reaches": ["great", "great", "great_wide", "great_spin"], "color": Color(0.9, 0.96, 1.0), "great": true, "momentum": true},
	# greatsword, attacked at a sprint (Running Cleave): the blade trailed low, then one flat sweep through them in a
	# long lunge; it breaks a wind-up and throws them down
	"gs_dash": {"anims": ["gs_rush"], "trails": [""],
		"durations": [0.62], "impulses": [11.0],
		"damages": [17.0], "hitstops": [0.1], "shakes": [0.2],
		"knocks": [11.0], "breakers": [true], "downs": [true],
		"reach": "great_low", "color": Color(0.9, 0.96, 1.0), "breaker": true, "great": true},
	# black-leg: kicks only, flowing low (the left leg at the knee) -> mid (the right at the ribs) -> high (the left at
	# the head, a breaker) and (Handstand Spin) down on the hands, legs split, two turns that put everyone round you
	# down; "legs": BlackLegArts shapes the hits and draws the legs' trails
	"black_leg": {"anims": ["bl_1", "bl_2", "bl_3", "bl_4"], "trails": ["", "", "", ""],
		"durations": [0.3, 0.34, 0.4, 0.95], "impulses": [3.5, 4.5, 4.0, 2.5],
		"damages": [8.0, 11.0, 14.0, 22.0], "hitstops": [0.04, 0.055, 0.08, 0.1], "shakes": [0.06, 0.1, 0.14, 0.2],
		"reach": "kick", "reaches": ["kick", "kick", "kick", "kick_spin"], "color": Color(1.0, 0.94, 0.86), "legs": true,
		"winds": [[-0.35, 0.55, 0.5, false], [0.3, 0.95, -0.6, false], [-0.3, 1.45, 0.55, false], [0.0, 0.5, 0.0, true]]},
	# black-leg, attacked at a sprint (Arrow Kick): launched side-on, the right leg shot straight out through them; it
	# breaks a wind-up and throws them down
	"bl_dash": {"anims": ["bl_rush"], "trails": [""],
		"durations": [0.6], "impulses": [12.5],
		"damages": [16.0], "hitstops": [0.08], "shakes": [0.18],
		"reach": "kick_fly", "color": Color(1.0, 0.94, 0.86), "breaker": true, "trip": true, "legs": true,
		"winds": [[0.0, 1.0, 0.0, true]]},
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
	"dagger": "gut_strike", "dual_dagger": "fang_whirl", "polearm": "wheel_sweep", "hammer": "wrecking_spin",
	"dual_axe": "reaping_whirl", "greatsword": "gale_turn", "black_leg": "handstand_spin"}
## A greatsword blow chained straight out of the last one's follow-through: this much faster and harder per blow
## built (the second x1, the third x2, the turn x3).
const MOMENTUM_SPEED := 0.07
const MOMENTUM_DAMAGE := 0.06

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
## The running cut's reach with a Rushing weapon (TraitMoves.rush_k; 1: plain).
var _rush := 1.0
## A polearm, hammer or axe pair's speed (its moves play that much faster; 1: other weapons).
var _spd := 1.0
## When a hammer's head thuds into the ground (s; < 0: it doesn't).
var _thud_t := -1.0
## A greatsword's momentum: blows built in an unbroken flow (0: this one started from the guard).
var _mom := 0


func enter(data: Dictionary) -> void:
	var st := player.style()
	if player.quick_draw:
		st = {"katana": "katana_draw", "polearm": "pole_dash", "hammer": "ham_dash", "dual_axe": "dx_dash", "greatsword": "gs_dash",
			"black_leg": "bl_dash"}.get(st, "sword_dash")
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
	_rush = TraitMoves.rush_k(player) if cfg.get("breaker", false) else 1.0
	player.velocity.x = forward.x * float(cfg["impulses"][combo_index]) * _rush
	player.velocity.z = forward.z * float(cfg["impulses"][combo_index]) * _rush
	var anim := str(cfg["anims"][combo_index])
	_spd = 1.0
	if cfg.get("pole", false):
		_spd = WeaponDesigns.pole(player.equipped_weapon.design, "speed")
	elif cfg.get("hammer", false):
		_spd = WeaponDesigns.hammer(player.equipped_weapon.design, "speed")
	elif cfg.get("pair", false):
		_spd = DualAxeArts.pair(player, "speed")
		if bool(cfg["lefts"][combo_index]):
			_off = [DualAxeArts.off_k(player), 1.0, 1.0, 0.0]
	elif cfg.get("great", false):
		_spd = WeaponDesigns.great(player.equipped_weapon.design, "speed")
	# (momentum: chained while the body is still in the last blow's follow-through, this one flows out of it)
	_mom = 0
	if cfg.get("momentum", false) and data.get("chain", false) and combo_index > 0 \
			and player.body_model.current_action() == str(cfg["anims"][combo_index - 1]):
		_mom = int(data.get("momentum", 0)) + 1
		_spd *= 1.0 + MOMENTUM_SPEED * _mom
	_window = ActionSpecs.hit_seconds(anim) / _spd
	_swoosh = ActionSpecs.swoosh_seconds(anim) / _spd
	_thud_t = float(HammerMoves.THUD[anim]) * ActionSpecs.length(anim) / _spd if HammerMoves.THUD.has(anim) else -1.0
	_swooshed = false
	_shot_t = ActionSpecs.shot_seconds(anim) if _kind != "cut" else -1.0
	player.body_model.play(anim, ActionSpecs.length(anim) / _spd)
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
		# (the awakened katana's cloud is its trail: the thin line of light under it went)
		if cfg.get("legs", false):
			BlackLegArts.swoosh(player, str(cfg["anims"][combo_index]), _swoosh.y - _swoosh.x, sc)
		elif not cfg.get("drawn", false) or not KatanaFx.awake(player) or player.power.buff("coat"):
			Net.fx("blade_swoosh", [player.body_model, _swoosh.y - _swoosh.x, sc, sl])
		if cfg.get("drawn", false):
			KatanaFx.slash(player, _swoosh.y - _swoosh.x, str(cfg["anims"][combo_index]) == "katana_stab")

	if _shot_t >= 0.0 and timer >= _shot_t and not _shot_done:
		_shot_done = true
		_shot()

	if timer >= _window.x and not hitbox_activated and _kind == "shot":
		hitbox_activated = true
	if timer >= _window.x and not hitbox_activated:
		hitbox_activated = true
		var last := combo_index == combo_count - 1
		var hit := player.melee_hit(float(cfg["damages"][combo_index]) * float(_off[0]) * (1.0 + MOMENTUM_DAMAGE * _mom), "finisher" if last else "")
		hit.hitstop_duration = float(cfg["hitstops"][combo_index]) * float(_off[2])
		hit.camera_shake_intensity = float(cfg["shakes"][combo_index]) * float(_off[2])
		hit.knockback_force = (8.0 if last else 4.0) * float(_off[1])
		hit.breaker = cfg.get("breaker", false)
		hit.sever = str(cfg["reach"]) != "fist" and not cfg.get("legs", false)
		if cfg.has("bleeds") and float(cfg["bleeds"][combo_index]) > 0.0:
			hit.set_meta("bleed", float(cfg["bleeds"][combo_index]))
		# (the axe's finisher puts them on the ground)
		hit.knockdown = (last and cfg.get("slam", false)) or _rush > 1.0 or cfg.get("trip", false)
		# (a polearm's thrust shoves them back to the point; a trident's goes through a guard)
		if cfg.get("pole", false) and str(cfg["anims"][combo_index]) == "pole_thrust":
			hit.knockback_force = 6.5
			hit.unblockable = hit.unblockable or WeaponDesigns.pole(player.equipped_weapon.design, "pierce", 0.0) > 0.0
		if cfg.has("knocks"):
			var d := player.equipped_weapon.design
			var wt := WeaponDesigns.great(d, "weight") if cfg.get("great", false) else WeaponDesigns.hammer(d, "weight")
			hit.knockback_force = float(cfg["knocks"][combo_index]) * wt
			hit.breaker = hit.breaker or bool(cfg["breakers"][combo_index])
			hit.knockdown = hit.knockdown or bool(cfg["downs"][combo_index])
			hit.stagger_duration = 0.6 * (wt if cfg.get("great", false) else 1.0)
		if cfg.get("great", false):
			GreatswordArts.shape_hit(player, hit)
		# (the twin axes' whirl puts them down)
		if cfg.get("pair", false) and str(cfg["anims"][combo_index]) == "dx_4":
			hit.knockdown = true
		if cfg.get("legs", false):
			BlackLegArts.shape_hit(player, hit, str(cfg["anims"][combo_index]))
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
		if cfg.get("great", false):
			GreatswordArts.swing_fx(player, _mom, last or cfg.get("breaker", false))
		if cfg.get("legs", false):
			BlackLegArts.kick_fx(player, str(cfg["anims"][combo_index]))

	if _thud_t >= 0.0 and timer >= _thud_t:
		_thud_t = -1.0
		HammerArts.thud(player, str(cfg["anims"][combo_index]) == "ham_spin")

	if timer >= _window.y and not hitbox_deactivated:
		hitbox_deactivated = true
		# (the twin axes' hook hauls in whoever it caught)
		if cfg.has("hooks") and bool(cfg["hooks"][combo_index]):
			for e in player.sword_hitbox.hit_targets.duplicate():
				DualAxeArts.hook(player, e)
		player.sword_hitbox.deactivate()

	var duration := float(AnimLab.spec(str(cfg["anims"][combo_index])).get("chain", cfg["durations"][combo_index])) / _spd + float(_off[3])
	if timer >= duration and not can_combo:
		can_combo = true
		combo_timer = combo_window

	if can_combo:
		combo_timer -= delta
		if input_buffer.consume_action("light_attack") and player.spend_stamina(player.LIGHT_COST * player.attack_cost_k()):
			chained = true
			transitioned.emit(self, "LightAttack", {"combo_index": (combo_index + 1) % combo_count, "chain": true, "momentum": _mom})
			return
		# (a greatsword's momentum carries into the heavy too: right-click out of the follow-through and the cleave is
		# already part charged)
		if cfg.get("momentum", false) and input_buffer.consume_action("heavy_attack") and player.spend_stamina(heavy_cost()):
			_heavy_used("HeavyAttack:" + player.style())
			transitioned.emit(self, "HeavyAttack", {"momentum": _mom + 1 if player.body_model.current_action() == str(cfg["anims"][combo_index]) else 0})
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
