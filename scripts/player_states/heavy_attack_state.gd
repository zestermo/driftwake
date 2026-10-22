extends PlayerState
## Heavy attack, shaped by the weapon in hand:
## * cutlass (and other blades): a lunging thrust - coil back, then drive
##   forward with the point leading, long reach, quick recovery
## * axe: the whirlwind - the axe swung out two-handed and round twice,
##   hitting everything about you on each turn (the second knocks them flat);
##   you can steer it, slowly
## * dual wield: both blades raised, then crashing down together in an X
## * sword and pistol (Powder Lunge): the lunging thrust, then a ball fired into
##   whoever's on the point as it comes out (knocks them flat; the butt with
##   nothing loaded)
## * one dagger (Shadow Lunge): sunk low, then out from behind the one in front with
##   the blade in their back, untouchable on the way; the wound bleeds
## * two daggers (Scissor Rip): both driven in side by side, then ripped apart
## * polearm (Skewer): a lunge driving the shaft through the line in front
## * hammer (Earthquake): heaved overhead and slammed into the ground, a shockwave knocking everyone round it down
## * twin axes (Berserker Frenzy): chop, chop, chop stepping in, then both crashed down crossed
## * greatsword (the charged cleave): held overhead charging, let go to bring it down; a full charge flings a
##   crescent of air down the line
## * fists (the haymaker): a huge overhand right, over the top and down through them
## * black-leg (Guillotine Heel): the axe kick, the heel brought down from over the head through a guard
## * one pistol: a pistol-whip; two pistols: gun kata (a hop into a double
##   spin, arms crossed, shooting everyone close)
## * claws (Zoan hybrid): a pouncing maul
## * anything else: the leaping two-handed slam

## Per-style feel. Timing (windup -> active, hitbox on -> recovery) is the anim's
## length and strike window in ActionSpecs.
const STYLES := {
	"thrust": {"anim": "thrust", "impulse": 11.0,
		"damage": 32.0, "hitstop": 0.08, "shake": 0.16, "knockback": 12.0, "stagger": 0.4,
		"trail": "thrust", "trail_len": 0.22, "sfx": "whoosh", "pitch": 1.25, "impact_fx": false,
		"tree": "sword"},
	"whirl": {"anim": "axe_whirl", "impulse": 2.5,
		"damage": 22.0, "hitstop": 0.06, "shake": 0.16, "knockback": 9.0, "stagger": 0.5,
		"trail": "spin", "trail_len": 0.36, "sfx": "whoosh_big", "pitch": 0.85, "impact_fx": false,
		"reach": "whirl", "color": Color(1.0, 0.78, 0.5), "rehit": 0.36, "steer": 0.45, "tree": "axe"},
	"dual_heavy": {"anim": "dual_heavy", "impulse": 6.0,
		"damage": 42.0, "hitstop": 0.12, "shake": 0.28, "knockback": 11.0, "stagger": 0.6,
		"trail": "", "trail_len": 0.0, "sfx": "whoosh_big", "pitch": 0.95, "impact_fx": true, "reach": "wide",
		"color": Color(0.55, 0.85, 1.0), "color_l": Color(0.75, 0.65, 1.0), "tree": "dual"},
	# sword + pistol: the thrust, then a ball fired into them as the blade comes out
	"powder_lunge": {"anim": "sp_lunge", "impulse": 10.0,
		"damage": 22.0, "hitstop": 0.08, "shake": 0.14, "knockback": 4.0, "stagger": 0.7,
		"trail": "", "trail_len": 0.0, "sfx": "whoosh", "pitch": 1.2, "impact_fx": false,
		"shot": 20.0, "color": Color(1.0, 0.85, 0.7), "tree": "corsair"},
	# one dagger (Shadow Lunge): sunk low, then gone - out from behind the one in front
	# (within "blink" m) with the blade in their back; untouchable until you're there
	"shadow_lunge": {"anim": "dg_shadow", "impulse": 0.0, "blink": 5.5,
		"damage": 26.0, "hitstop": 0.08, "shake": 0.14, "knockback": 3.0, "stagger": 0.9,
		"trail": "", "trail_len": 0.0, "sfx": "whoosh_big", "pitch": 1.45, "impact_fx": false, "reach": "dagger",
		"color": Color(1.0, 0.78, 0.82), "tree": "dagger", "bleed": 4.0},
	# two daggers (Scissor Rip): both driven in side by side, then ripped apart outward
	"scissor_rip": {"anim": "dd_heavy", "impulse": 7.5, "rehit": 0.243, "rehit_damage": 22.0, "rehit_down": false,
		"damage": 14.0, "hitstop": 0.06, "shake": 0.12, "knockback": 8.0, "stagger": 0.8,
		"trail": "", "trail_len": 0.0, "sfx": "whoosh", "pitch": 1.3, "impact_fx": false, "reach": "dagger",
		"color": Color(0.78, 1.0, 0.62), "color_l": Color(0.92, 1.0, 0.7), "tree": "dual_dagger", "bleed": 4.0},
	# polearm (Skewer): coiled deep, then a lunge driving the whole shaft through the line in front, knocking
	# down everyone on it (the point holds them off at its full reach)
	"skewer": {"anim": "pole_heavy", "impulse": 10.5,
		"damage": 30.0, "hitstop": 0.09, "shake": 0.2, "knockback": 13.0, "stagger": 0.6,
		"trail": "", "trail_len": 0.0, "sfx": "whoosh_big", "pitch": 1.15, "impact_fx": false, "reach": "pole_long",
		"color": Color(1.0, 0.93, 0.72), "tree": "polearm", "pole": true},
	# hammer (Earthquake): heaved overhead, a beat, then slammed into the ground ahead: the one under it knocked
	# flat through any guard, and a shockwave ("quake" m, x the design's weight) knocks down everyone round it
	"quake": {"anim": "ham_heavy", "impulse": 3.0,
		"damage": 34.0, "hitstop": 0.13, "shake": 0.3, "knockback": 12.0, "stagger": 0.8,
		"trail": "", "trail_len": 0.0, "sfx": "whoosh_big", "pitch": 0.75, "impact_fx": false, "reach": "hammer_slam",
		"color": Color(0.92, 0.86, 0.74), "tree": "hammer", "hammer": true, "quake": 3.6, "quake_damage": 14.0},
	# twin axes (Berserker Frenzy): right, left, right in quick chops stepping in, then both raised and crashed
	# down crossed; "chops": the later blows (s after the first, at the pair's speed 1) and their damage, the
	# last puts them down
	"frenzy": {"anim": "dx_heavy", "impulse": 4.0,
		"damage": 9.0, "hitstop": 0.05, "shake": 0.12, "knockback": 3.5, "stagger": 0.5,
		"trail": "", "trail_len": 0.0, "sfx": "whoosh", "pitch": 1.1, "impact_fx": false, "reach": "twin_axe",
		"color": Color(0.86, 0.92, 1.0), "color_l": Color(0.7, 0.8, 0.98), "tree": "dual_axe", "pair": true,
		"chops": [0.184, 0.368, 0.621], "chop_damages": [9.0, 9.0, 24.0]},
	# greatsword (the charged cleave): held, the blade raised overhead charging (CHARGE_AT); let go, it comes straight
	# down through them into the ground. Harder by the level (CHARGE_DAMAGE), always through a wind-up; a full charge
	# can't be blocked, knocks them flat and flings a crescent of air on down the line (GreatswordArts.cleave_fx)
	"cleave": {"anim": "gs_heavy", "impulse": 7.0,
		"damage": 30.0, "hitstop": 0.1, "shake": 0.22, "knockback": 10.0, "stagger": 0.8,
		"trail": "", "trail_len": 0.0, "sfx": "whoosh_big", "pitch": 0.8, "impact_fx": false, "reach": "great_cleave",
		"color": Color(0.9, 0.96, 1.0), "tree": "greatsword", "great": true, "charge": true},
	# black-leg (Guillotine Heel): a skip in, the leg swung straight up over the head and the heel brought down through
	# them into the ground: through a guard, flat on their back
	"axe_kick": {"anim": "bl_heavy", "impulse": 3.5,
		"damage": 30.0, "hitstop": 0.12, "shake": 0.26, "knockback": 6.0, "stagger": 0.8,
		"trail": "", "trail_len": 0.0, "sfx": "whoosh_big", "pitch": 1.0, "impact_fx": false, "reach": "kick_axe",
		"color": Color(1.0, 0.94, 0.86), "tree": "black_leg", "legs": true, "breaker": true},
	# fists (the haymaker): rocked back with the fist drawn up behind the head, then a long step in and the overhand
	# brought over the top and down through them; breaks a wind-up, knocks them flat
	"haymaker": {"anim": "fs_hay", "impulse": 7.5, "wind": true,
		"damage": 30.0, "hitstop": 0.13, "shake": 0.26, "knockback": 14.0, "stagger": 0.7,
		"trail": "", "trail_len": 0.0, "sfx": "whoosh_big", "pitch": 0.85, "impact_fx": false, "reach": "fist",
		"color": Color(1.0, 0.95, 0.8), "tree": "unarmed", "breaker": true},
	"whip": {"anim": "pistol_whip", "impulse": 5.0,
		"damage": 18.0, "hitstop": 0.07, "shake": 0.14, "knockback": 10.0, "stagger": 0.4,
		"trail": "left", "trail_len": 0.2, "sfx": "whoosh", "pitch": 1.1, "impact_fx": false, "reach": "fist"},
	"kata": {"anim": "gun_kata", "impulse": 0.0,
		"damage": 0.0, "hitstop": 0.05, "shake": 0.12, "knockback": 4.0, "stagger": 0.3,
		"trail": "", "trail_len": 0.0, "sfx": "whoosh", "pitch": 1.3, "impact_fx": false, "reach": "fist", "kata": true},
	"maul": {"anim": "maul", "impulse": 10.0,
		"damage": 36.0, "hitstop": 0.1, "shake": 0.24, "knockback": 11.0, "stagger": 0.5,
		"trail": "overhead", "trail_len": 0.26, "sfx": "whoosh_big", "pitch": 0.85, "impact_fx": true, "reach": "claw", "color": Color(1.0, 0.35, 0.3)},
	"slam": {"anim": "heavy", "impulse": 5.0,
		"damage": 35.0, "hitstop": 0.1, "shake": 0.2, "knockback": 10.0, "stagger": 0.5,
		"trail": "overhead", "trail_len": 0.3, "sfx": "whoosh_big", "pitch": 1.0, "impact_fx": true},
}

## The cleave's charge: seconds held to reach levels 1 and 2, each level's damage, the longest hold before it goes
## by itself, and the creep while it's held (x move speed).
const CHARGE_AT := [0.45, 1.0]
const CHARGE_DAMAGE := [30.0, 42.0, 58.0]
const CHARGE_MAX := 1.8
const CHARGE_CREEP := 0.25

## Gun kata hop (m/s up).
const KATA_HOP := 5.0
## The kata keeps moving with the stick (x move speed), tipped hard into the travel.
const KATA_MOVE := 1.05
const KATA_TILT := 0.6

var timer: float = 0.0
var phase: int = 0  # 0 = windup, 1 = active, 2 = recovery
var hitbox_activated: bool = false
var impact_fx: bool = false
var cfg: Dictionary = {}
var _kata_shots: int = 0
var _rehit_done: bool = false
var _glinted: bool = false
var _windup: float = 0.0
var _active: float = 0.0
var _recovery: float = 0.0
## Time since it began (the phases reset `timer`), and when its pistol fires (s, -1: none).
var _t_all: float = 0.0
var _shot_t: float = -1.0
var _shot_done := false
var _swooshed := false
## Shadow Lunge: out from behind them (and untouchable until _seen).
var _blinked := false
var _seen := false
var _blink_from := Vector3.ZERO
var _quaked := false
## A polearm, hammer or axe pair's speed (1: other weapons).
var _spd := 1.0
## The frenzy's blows landed after the first.
var _chop := 0
## The cleave: held and charging, the level reached, how long it's been held.
var _charging := false
var _level := 0
var _charge_t := 0.0


static func style_for(weapon_model: String) -> String:
	match weapon_model:
		"axe":
			return "whirl"
		"polearm":
			return "skewer"
		"hammer":
			return "quake"
		"greatsword":
			return "cleave"
		"cutlass", "sword", "rapier", "dagger":
			return "thrust"
	return "slam"


func enter(data: Dictionary) -> void:
	timer = 0.0
	phase = 0
	hitbox_activated = false
	impact_fx = false
	player.reset_combo()
	var model := player.equipped_weapon.weapon_model if player.equipped_weapon else ""
	match player.style():
		"dual_sword":
			cfg = STYLES["dual_heavy"]
		"sword_pistol":
			cfg = STYLES["powder_lunge"]
		"dagger":
			cfg = STYLES["shadow_lunge"]
		"dual_dagger":
			cfg = STYLES["scissor_rip"]
		"dual_axe":
			cfg = STYLES["frenzy"]
		"fist":
			cfg = STYLES["haymaker"]
		"black_leg":
			cfg = STYLES["axe_kick"]
		"pistol":
			cfg = STYLES["whip"]
		"dual_pistol":
			cfg = STYLES["kata"] if player.progression.has_move("gun_kata") else STYLES["whip"]
		"claw":
			cfg = STYLES["maul"]
		_:
			cfg = STYLES[style_for(model)]
	player.set_reach(str(cfg.get("reach", "sword")))
	_kata_shots = 0
	_rehit_done = false
	_glinted = false
	_quaked = false

	# Snap to camera forward
	var forward := get_camera_forward()
	player.player_model.rotation.y = atan2(-forward.x, -forward.z)
	var anim := str(cfg["anim"])
	_spd = 1.0
	if cfg.get("pole", false):
		_spd = WeaponDesigns.pole(player.equipped_weapon.design, "speed")
	elif cfg.get("hammer", false):
		_spd = WeaponDesigns.hammer(player.equipped_weapon.design, "speed")
	elif cfg.get("pair", false):
		_spd = DualAxeArts.pair(player, "speed")
	elif cfg.get("great", false):
		_spd = WeaponDesigns.great(player.equipped_weapon.design, "speed")
	_chop = 0
	var length := ActionSpecs.length(anim) / _spd
	var w := ActionSpecs.hit_seconds(anim) / _spd
	_windup = w.x
	_active = w.y - w.x
	_recovery = length - w.y
	_t_all = 0.0
	_shot_t = ActionSpecs.shot_seconds(anim) if cfg.has("shot") else -1.0
	_shot_done = false
	_swooshed = false
	_blinked = false
	_seen = not cfg.has("blink")
	if cfg.has("blink"):
		player.hurtbox.set_deferred("monitorable", false)
	_charging = cfg.has("charge")
	_level = 0
	_charge_t = 0.0
	if _charging:
		# (out of a combo blow's follow-through the blade's already moving: the charge starts a level up)
		if int(data.get("momentum", 0)) > 0:
			_level = 1
			_charge_t = float(CHARGE_AT[0])
			GreatswordArts.charged(player, _level)
		player.body_model.hold("gs_charge", 0.12 if _level > 0 else 0.2)
		return
	player.body_model.play(anim, length)


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	if _charging:
		_charge_update(delta)
		return
	if cfg.get("kata", false):
		_kata_move(delta)
	elif cfg.has("steer") and phase == 1:
		_steer(delta, float(cfg["steer"]))
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, 20.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, 20.0 * delta)
	player.move_and_slide()

	timer += delta
	_t_all += delta
	# (moves keyed with a "swoosh" draw the real blades' trails, both hands' for two blades)
	var sw := ActionSpecs.swoosh_seconds(str(cfg["anim"])) / _spd
	if sw.x >= 0.0 and _t_all >= sw.x and not _swooshed:
		_swooshed = true
		if cfg.get("legs", false):
			BlackLegArts.swoosh(player, str(cfg["anim"]), sw.y - sw.x, _trail_col())
		else:
			Net.fx("blade_swoosh", [player.body_model, sw.y - sw.x, _trail_col(), _trail_col(true)])
	if _shot_t >= 0.0 and _t_all >= _shot_t and not _shot_done:
		_shot_done = true
		_powder_shot()

	match phase:
		0:  # Windup
			# the point catches the light just before it goes
			if cfg.has("tree") and not _glinted and timer >= _windup - 0.07:
				_glinted = true
				var w: MeshInstance3D = player.body_model.weapon
				if w and w.mesh:
					Net.fx("glint", [w.global_transform * Vector3(0, 0, w.mesh.get_aabb().position.z * 0.85), Color.WHITE, 0.7])
			if timer >= _windup:
				phase = 1
				timer = 0.0
				if cfg.has("blink"):
					_blink(float(cfg["blink"]))
				var col := _trail_col()
				if str(cfg["trail"]) != "":
					Net.fx("slash", [player.player_model, str(cfg["trail"]), float(cfg["trail_len"]), col])
				Net.fx("sfx", [str(cfg["sfx"]), player.global_position, -4.0, 0.08, float(cfg["pitch"])])
				if cfg.get("wind", false):
					var b := player.player_model.global_basis
					Net.fx("punch_wind", [player.global_position + Vector3.UP * 1.05 + b.x * 0.15 - b.z * 0.3, -b.z, 1.7,
						col if player.power.buff("coat") else Color(1.0, 0.97, 0.9), true])
				player.squash(-3.0)
				if cfg.has("tree"):
					_strike_fx()
				if cfg.get("kata", false):
					if player.is_on_floor():
						player.velocity.y = KATA_HOP   # spins in the air, not planted on the ground
				elif cfg.has("blink"):
					pass
				else:
					var face_dir := get_camera_forward()
					player.velocity.x = face_dir.x * float(cfg["impulse"])
					player.velocity.z = face_dir.z * float(cfg["impulse"])
				# (the whirlwind's first turn only staggers: the second knocks them flat;
				# Powder Lunge's thrust holds them up for the shot)
				var hit := _hit(not cfg.has("rehit") and not cfg.has("shot") and not cfg.has("chops") and not cfg.has("charge"))
				hit.breaker = hit.breaker or cfg.has("quake") or cfg.get("breaker", false)
				if cfg.has("charge"):
					hit.damage *= float(CHARGE_DAMAGE[_level]) / float(cfg["damage"])
					GreatswordArts.cleave_hit(player, hit, _level)
				if not cfg.get("kata", false):
					player.sword_hitbox.activate(hit)
				hitbox_activated = true

		1:  # Active
			# the hammer's shockwave, a moment after the blow (so the one it landed on is already struck)
			if cfg.has("quake") and not _quaked and timer >= 0.04:
				_quaked = true
				var wt := WeaponDesigns.hammer(player.equipped_weapon.design, "weight")
				var wave := player.melee_hit(float(cfg["quake_damage"]), "heavy")
				wave.knockdown = true
				wave.breaker = true
				wave.knockback_force = 9.0 * wt
				wave.stagger_duration = 0.6
				wave.hitstop_duration = 0.06
				wave.camera_shake_intensity = 0.0
				HammerArts.quake(player, HammerArts.head_ground(player), float(cfg["quake"]) * wt, wave,
					player.sword_hitbox.hit_targets.duplicate(), player.progression.elemental("hammer", 2))
			# the frenzy's next chop: a fresh hit (the hitbox off a few frames first), a step in behind it
			if cfg.has("chops") and _chop < (cfg["chops"] as Array).size():
				var at := float(cfg["chops"][_chop]) / _spd
				if timer >= at - 0.05:
					player.sword_hitbox.deactivate()
				if timer >= at:
					var last := _chop == (cfg["chops"] as Array).size() - 1
					var hd := _hit(last, float(cfg["chop_damages"][_chop]) * (DualAxeArts.off_k(player) if _chop == 0 else 1.0))
					if last:
						hd.hitstop_duration = 0.11
						hd.camera_shake_intensity = 0.24
						hd.knockback_force = 10.0
					player.sword_hitbox.activate(hd)
					_chop += 1
					var f := -player.player_model.global_basis.z
					player.velocity.x = f.x * float(cfg["impulse"]) * (0.9 if last else 0.6)
					player.velocity.z = f.z * float(cfg["impulse"]) * (0.9 if last else 0.6)
					Net.fx("sfx", ["whoosh_big" if last else "whoosh", player.global_position, -5.0, 0.08, 0.9 if last else 1.1 + 0.08 * _chop])
					player.squash(-3.0 if last else -1.5)
					_strike_fx(last)
			# the whirlwind's second turn: a fresh hit on everyone about you (the
			# hitbox off for a few frames first, so those already inside it register again)
			if cfg.has("rehit") and not _rehit_done and timer >= float(cfg["rehit"]) - 0.06:
				player.sword_hitbox.deactivate()
			if cfg.has("rehit") and not _rehit_done and timer >= float(cfg["rehit"]):
				_rehit_done = true
				player.sword_hitbox.activate(_hit(cfg.get("rehit_down", true), float(cfg.get("rehit_damage", cfg["damage"]))))
				if str(cfg["trail"]) != "":
					Net.fx("slash", [player.player_model, str(cfg["trail"]), float(cfg["trail_len"]), _trail_col()])
				Net.fx("sfx", [str(cfg["sfx"]), player.global_position, -4.0, 0.08, float(cfg["pitch"]) * 1.1])
				_strike_fx(true)
			if _blinked and timer >= 0.15 and not _seen:
				_seen = true
				player.hurtbox.set_deferred("monitorable", true)
			# gun kata: spin and put a shot into everyone close
			if cfg.get("kata", false):
				var due := int(timer / _active * 4.0)
				while _kata_shots < mini(due + 1, 4):
					_kata_shots += 1
					_kata_volley()
			if cfg["impact_fx"] and timer >= _active * 0.5 and not impact_fx:
				impact_fx = true
				var front := player.global_position - player.player_model.global_basis.z * 1.3
				Net.fx("heavy_dust", [front, 16, 1.0])
				Net.fx("sparkle", [front + Vector3(0, 0.3, 0), 8, Color(1.0, 0.85, 0.5)])
			if timer >= _active:
				phase = 2
				timer = 0.0
				if cfg.get("tree", "") == "unarmed":
					FistArts.haymaker_landed(player, player.sword_hitbox.hit_targets.duplicate())
				player.sword_hitbox.deactivate()
				if not cfg["impact_fx"]:
					Net.fx("dust", [player.global_position + Vector3(0, 0.05, 0), 5, 0.5])

		2:  # Recovery
			if timer >= _recovery:
				transitioned.emit(self, "Idle", {})

	# Allow dodge cancel during recovery
	if phase == 2 and wants_dodge():
		transitioned.emit(self, "Dodge", {})


## The trail's colour: the style's own, its tree's once the element follows every
## blow (the tree's second mastery passive), black with a Haki coat. `left`: the off
## hand's blade.
func _trail_col(left: bool = false) -> Color:
	if player.power.buff("coat"):
		return Player.HAKI_TRAIL
	if cfg.has("tree") and player.progression.elemental(str(cfg["tree"]), 2):
		return FX.tree_col(str(cfg["tree"]), FX.ACCENT if left and FX.TWIN_TREES.has(cfg["tree"]) else FX.EDGE)
	if left:
		return cfg.get("color_l", cfg.get("color", Color(0.45, 0.75, 1.0)))
	return cfg.get("color", Color(0.45, 0.75, 1.0))


## Powder Lunge's shot: a ball into whoever's on the point as the blade comes out.
func _powder_shot() -> void:
	var fwd := -player.player_model.global_basis.z
	var on: Node3D = null
	for e in player.sword_hitbox.hit_targets:
		if is_instance_valid(e) and e is Node3D:
			on = e
			break
	var elem := player.progression.elemental("corsair", 2)
	CorsairGun.shoot_or_butt(player, fwd, float(cfg["shot"]), "heavy",
		{"knock": 11.0, "stagger": 0.6, "down": true, "stop": 0.1, "shake": 0.22, "elem": elem, "size": 1.5}, on)
	CombatManager.apply_camera_kick(0.16, 0.3)
	player.squash(-2.0)


## Shadow Lunge: out from behind the enemy in front within `reach` (on their far
## side, facing them), leaving an afterimage and a streak where you were; nobody
## there: a short dash on.
func _blink(reach: float) -> void:
	var fwd := get_camera_forward()
	var best: Node3D = null
	var best_d := reach
	for e in player.power.enemies_in(player.global_position + Vector3(0, 0.9, 0) + fwd * reach * 0.5, reach):
		var to: Vector3 = (e as Node3D).global_position - player.global_position
		to.y = 0.0
		if to.length() < best_d and (to.length() < 0.6 or to.normalized().dot(fwd) > 0.3):
			best_d = to.length()
			best = e
	_blink_from = player.global_position + Vector3(0, 1.0, 0)
	_blinked = true
	var col := _trail_col()
	Net.fx("afterimage", [player.body_model, col, 0.35])
	if best == null:
		player.velocity.x = fwd.x * 10.0
		player.velocity.z = fwd.z * 10.0
		return
	var through := best.global_position - player.global_position
	through.y = 0.0
	through = through.normalized() if through.length() > 0.05 else fwd
	player.global_position = best.global_position + through * 1.1
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	player.player_model.rotation.y = atan2(through.x, through.z)
	Net.fx("streak", [_blink_from, player.global_position + Vector3(0, 1.0, 0), col, 0.1, 0.3])
	Net.fx("dust", [player.global_position + Vector3(0, 0.05, 0), 5, 0.5])


## The strike's effects: a ring of air round the point and dust kicked up by the
## lunge (the whirlwind: a ring round you and rock kicked up); with the element on
## every blow (the tree's second mastery passive) they take its colours and throw
## its material. `second`: a heavy's second blow (the whirlwind's turn, the rip).
func _strike_fx(second: bool = false) -> void:
	var elem := player.progression.elemental(str(cfg["tree"]), 2)
	var tree := str(cfg["tree"]) if elem else "plain"
	var face := -player.player_model.global_basis.z
	face.y = 0.0
	face = face.normalized()
	# (the hammer's is its shockwave, a moment later: HammerArts.quake)
	if cfg["tree"] == "hammer":
		return
	if cfg["tree"] == "black_leg":
		BlackLegArts.heel_fx(player)
		return
	if cfg["tree"] == "greatsword":
		GreatswordArts.cleave_fx(player, _level)
		return
	if cfg["tree"] == "dual_axe":
		# each chop a ring where it bites; the crossed crash an X on the ground and a ring round it
		var at := player.global_position + face * 1.3
		if second:
			Net.fx("twin_cross", [at + Vector3(0, 0.12, 0), face, 1.0, FX.tree_col(tree, FX.EDGE), FX.tree_col(tree, FX.ACCENT if elem else FX.CORE), 0.35, true])
			Net.fx("ring", [at, Vector3.UP, 2.2, FX.tree_col(tree, FX.EDGE), 0.26, 0.12])
			Net.fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP + face * 0.3, 6, Color(0.35, 0.3, 0.25), 4.5])
			if elem:
				Net.fx("element", [tree, at + Vector3(0, 0.4, 0), Vector3.UP + face * 0.3, 12, 4.5])
			CombatManager.apply_camera_kick(0.16, 0.3)
		else:
			Net.fx("ring", [at + Vector3(0, 1.0, 0), face, 0.8, FX.tree_col(tree, FX.EDGE), 0.16, 0.18])
			if elem:
				Net.fx("element", [tree, at + Vector3(0, 1.0, 0), face + Vector3.UP * 0.3, 5, 3.5])
		return
	if cfg["tree"] == "dagger":
		var at := player.global_position + Vector3(0, 1.1, 0) + face * 0.9
		Net.fx("ring", [at, face, 0.9, FX.tree_col(tree, FX.EDGE), 0.2, 0.16])
		Net.fx("glint", [at, FX.tree_col(tree, FX.CORE), 0.7])
		if elem:
			Net.fx("element", [tree, at, face + Vector3.UP * 0.3, 10, 3.5])
		CombatManager.apply_camera_kick(0.14, 0.28)
		return
	if cfg["tree"] == "dual_dagger":
		var at := player.global_position + Vector3(0, 1.1, 0) + face * 1.0
		if second:
			Net.fx("twin_cross", [at, face, 0.65, FX.tree_col(tree, FX.EDGE), FX.tree_col(tree, FX.ACCENT if elem else FX.CORE), 0.25])
			Net.fx("ring", [at, face, 1.2, FX.tree_col(tree, FX.EDGE), 0.22, 0.14])
			if elem:
				Net.fx("element", [tree, at, face + Vector3.UP * 0.3, 10, 4.0])
			CombatManager.apply_camera_kick(0.16, 0.3)
		else:
			Net.fx("ring", [at, face, 0.7, FX.tree_col(tree, FX.EDGE), 0.16, 0.18])
		return
	if cfg["tree"] == "polearm":
		# the line it drives through: a streak of air down its whole length, a ring where the point stops
		var from := player.global_position + Vector3(0, 1.15, 0) + face * 0.8
		var tip := from + face * 3.6 * WeaponDesigns.pole(player.equipped_weapon.design, "reach")
		Net.fx("streak", [from, tip, FX.tree_col(tree, FX.EDGE), 0.16, 0.3])
		Net.fx("ring", [tip, face, 1.1, FX.tree_col(tree, FX.EDGE), 0.22, 0.16])
		Net.fx("dust", [player.global_position + Vector3(0, 0.05, 0) - face * 0.3, 7, 0.6])
		if elem:
			Net.fx("bolt", [from, tip, FX.tree_col(tree, FX.EDGE), 0.1, 0.25, randi() % 1000])
			Net.fx("element", [tree, tip, face + Vector3.UP * 0.2, 10, 5.0])
		CombatManager.apply_camera_kick(0.14, 0.3)
		return
	if cfg.has("rehit"):
		var c := player.global_position
		if second:
			Net.fx("dust_ring", [c, 10, 0.8])
		Net.fx("ring", [c + Vector3(0, 1.0, 0), Vector3.UP, 2.8, FX.tree_col(tree, FX.EDGE), 0.24, 0.1])
		var a := randf() * TAU
		Net.fx("debris", [c + Vector3(cos(a), 0.1, sin(a)) * 1.6, Vector3(cos(a), 1.3, sin(a)), 4, Color(0.35, 0.3, 0.25), 4.0])
		if elem:
			Net.fx("element", [tree, c + Vector3(0, 1.0, 0) + Vector3(cos(a), 0, sin(a)) * 1.8, Vector3(cos(a), 0.4, sin(a)), 8, 4.0])
		CombatManager.apply_camera_kick(0.08, 0.25)
		return
	var f := get_camera_forward()
	f.y = 0.0
	f = f.normalized()
	if cfg["tree"] == "dual":
		# the two blades bite the ground in an X
		var at := player.global_position + f * 1.4
		Net.fx("twin_cross", [at + Vector3(0, 0.12, 0), f, 1.0, FX.tree_col(tree, FX.EDGE), FX.tree_col(tree, FX.ACCENT if elem else FX.CORE), 0.35, true])
		Net.fx("ring", [at, Vector3.UP, 2.2, FX.tree_col(tree, FX.EDGE), 0.28, 0.12])
		if elem:
			Net.fx("element", [tree, at + Vector3(0, 0.4, 0), Vector3.UP + f * 0.3, 12, 4.5])
		CombatManager.apply_camera_kick(0.16, 0.3)
		return
	var tip := player.global_position + Vector3(0, 1.2, 0) + f * 1.5
	Net.fx("ring", [tip, f, 1.3, FX.tree_col(tree, FX.EDGE), 0.22, 0.16])
	if elem:
		Net.fx("element", [tree, tip, f + Vector3.UP * 0.2, 10, 6.5])
	Net.fx("dust", [player.global_position + Vector3(0, 0.05, 0) - f * 0.4, 6, 0.6])
	CombatManager.apply_camera_kick(0.12, 0.3)


func _hit(knockdown: bool, base: float = -1.0) -> HitData:
	var hit := player.melee_hit(float(cfg["damage"]) if base < 0.0 else base, "heavy")
	if cfg.has("bleed"):
		hit.set_meta("bleed", float(cfg["bleed"]))
	# Armament Haki: heavy attacks can't be blocked
	if player.progression.has_flag("armament"):
		hit.unblockable = true
		hit.haki = true
	hit.predictable = read_chance()
	hit.hitstop_duration = float(cfg["hitstop"])
	hit.camera_shake_intensity = float(cfg["shake"])
	hit.knockback_force = float(cfg["knockback"])
	hit.stagger_duration = float(cfg["stagger"])
	hit.knockdown = knockdown
	hit.sever = str(cfg.get("reach", "sword")) != "fist" and not cfg.get("kata", false) and not cfg.get("legs", false)
	return hit


## The cleave held: creeping, turning with the camera, the charge climbing its levels; let go (or held too long) it
## comes down. A dodge drops it.
func _charge_update(delta: float) -> void:
	var mi := get_movement_input()
	var want := get_camera_relative_direction(mi) * player.move_speed * CHARGE_CREEP if mi.length() > 0.1 else Vector3.ZERO
	player.velocity.x = move_toward(player.velocity.x, want.x, 30.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, want.z, 30.0 * delta)
	player.move_and_slide()
	face_camera(delta)
	_charge_t += delta
	while _level < CHARGE_AT.size() and _charge_t >= float(CHARGE_AT[_level]):
		_level += 1
		GreatswordArts.charged(player, _level)
	if wants_dodge():
		transitioned.emit(self, "Dodge", {})
		return
	if not Input.is_action_pressed("heavy_attack") or _charge_t >= CHARGE_MAX:
		_charging = false
		var forward := get_camera_forward()
		player.player_model.rotation.y = atan2(-forward.x, -forward.z)
		var anim := str(cfg["anim"])
		player.body_model.play(anim, ActionSpecs.length(anim) / _spd)


## Steered with the stick at a fraction of walking pace (the whirlwind).
func _steer(delta: float, k: float) -> void:
	var input := get_movement_input()
	var want := get_camera_relative_direction(input) * player.move_speed * k * player.wade_mult() if input.length() > 0.1 else Vector3.ZERO
	player.velocity.x = move_toward(player.velocity.x, want.x, 12.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, want.z, 12.0 * delta)


func _kata_move(delta: float) -> void:
	var input := get_movement_input()
	if input.length() < 0.1:
		player.velocity.x = move_toward(player.velocity.x, 0.0, 20.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, 20.0 * delta)
		player.align_hold = false
		return
	var dir := get_camera_relative_direction(input)
	var speed := player.move_speed * KATA_MOVE * player.wade_mult()
	player.velocity.x = dir.x * speed
	player.velocity.z = dir.z * speed
	player.align_hold = true
	player.align_up = (Vector3.UP + dir * tan(KATA_TILT)).normalized()
	player.align_w = move_toward(player.align_w, 1.0, 8.0 * delta)


## One turn of the kata: a shot into each of its targets still within 6 m, the
## KATA_TARGETS nearest when it began.
const KATA_TARGETS := 3
var _kata_targets: Array = []

func _kata_volley() -> void:
	var c := player.global_position + Vector3(0, 1.1, 0)
	var pc := player.power
	var hit_any := false
	var near: Array = pc.enemies_in(c, 6.0)
	if _kata_shots == 1:
		near.sort_custom(func(a, b): return (a as Node3D).global_position.distance_to(c) < (b as Node3D).global_position.distance_to(c))
		_kata_targets = near.slice(0, KATA_TARGETS)
	for e in _kata_targets:
		if not (e in near):
			continue
		var hb := (e as Node).get("hurtbox") as Hurtbox
		if hb == null:
			continue
		var hd := player.melee_hit(7.0)
		hd.knockback_force = 4.0
		hd.ranged = true
		hb.take_hit(hd, player)
		Net.fx("tracer", [c, hb.global_position])
		hit_any = true
	var a := randf() * TAU
	var d := Vector3(cos(a), 0, sin(a))
	Net.fx("muzzle_sparks", [c + d * 0.5, d, 6])
	Net.fx("sfx", ["gunshot", c, -6.0, 0.1, 1.35])
	if hit_any:
		CombatManager.apply_hitstop(0.03, [player])


func exit() -> void:
	if not _seen:
		player.hurtbox.set_deferred("monitorable", true)
	if cfg.get("kata", false):
		# both guns emptied: a reload before they fire again
		reload_until = now_s() + KATA_RELOAD
		player.call("_toast", "Reloading...")
		Net.fx("sfx", ["blip_low", player.global_position, -8.0, 0.05, 1.4])
	player.align_hold = false
	player.sword_hitbox.deactivate()
	player.sword_pivot.rotation_degrees.z = 0.0
	if player.body_model.current_action() == "gs_charge":
		player.body_model.stop_action()
