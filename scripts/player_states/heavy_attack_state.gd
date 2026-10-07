extends PlayerState
## Heavy attack, shaped by the weapon in hand:
## * cutlass (and other blades): a lunging thrust - coil back, then drive
##   forward with the point leading, long reach, quick recovery
## * axe: the whirlwind - the axe swung out two-handed and round twice,
##   hitting everything about you on each turn (the second knocks them flat);
##   you can steer it, slowly
## * dual swords: both blades raised, then crashing down together
## * fists: a flying kick
## * one pistol: a pistol-whip; two pistols: gun kata (a hop into a double
##   spin, arms crossed, shooting everyone close)
## * claws (Zoan hybrid): a pouncing maul
## * anything else: the leaping two-handed slam

## Per-style timing / feel. windup -> active (hitbox on) -> recovery.
const STYLES := {
	"thrust": {"anim": "thrust", "windup": 0.22, "active": 0.18, "recovery": 0.35, "impulse": 11.0,
		"damage": 32.0, "hitstop": 0.08, "shake": 0.16, "knockback": 12.0, "stagger": 0.4,
		"trail": "thrust", "trail_len": 0.22, "sfx": "whoosh", "pitch": 1.25, "impact_fx": false},
	"whirl": {"anim": "axe_whirl", "windup": 0.22, "active": 0.72, "recovery": 0.3, "impulse": 2.5,
		"damage": 22.0, "hitstop": 0.06, "shake": 0.16, "knockback": 9.0, "stagger": 0.5,
		"trail": "spin", "trail_len": 0.36, "sfx": "whoosh_big", "pitch": 0.85, "impact_fx": false,
		"reach": "whirl", "color": Color(1.0, 0.78, 0.5), "rehit": 0.36, "steer": 0.45},
	"dual_heavy": {"anim": "dual_heavy", "windup": 0.32, "active": 0.18, "recovery": 0.38, "impulse": 6.0,
		"damage": 42.0, "hitstop": 0.12, "shake": 0.28, "knockback": 11.0, "stagger": 0.6,
		"trail": "overhead", "trail_len": 0.28, "sfx": "whoosh_big", "pitch": 0.95, "impact_fx": true, "reach": "wide", "double_trail": true},
	"kick": {"anim": "flying_kick", "windup": 0.33, "active": 0.22, "recovery": 0.3, "impulse": 9.5, "wind": true,
		"damage": 26.0, "hitstop": 0.09, "shake": 0.2, "knockback": 12.0, "stagger": 0.5,
		"trail": "", "trail_len": 0.0, "sfx": "whoosh_big", "pitch": 1.2, "impact_fx": false, "reach": "fist"},
	"whip": {"anim": "pistol_whip", "windup": 0.2, "active": 0.12, "recovery": 0.3, "impulse": 5.0,
		"damage": 18.0, "hitstop": 0.07, "shake": 0.14, "knockback": 10.0, "stagger": 0.4,
		"trail": "left", "trail_len": 0.2, "sfx": "whoosh", "pitch": 1.1, "impact_fx": false, "reach": "fist"},
	"kata": {"anim": "gun_kata", "windup": 0.12, "active": 0.5, "recovery": 0.2, "impulse": 0.0,
		"damage": 0.0, "hitstop": 0.05, "shake": 0.12, "knockback": 4.0, "stagger": 0.3,
		"trail": "", "trail_len": 0.0, "sfx": "whoosh", "pitch": 1.3, "impact_fx": false, "reach": "fist", "kata": true},
	"maul": {"anim": "maul", "windup": 0.3, "active": 0.2, "recovery": 0.32, "impulse": 10.0,
		"damage": 36.0, "hitstop": 0.1, "shake": 0.24, "knockback": 11.0, "stagger": 0.5,
		"trail": "overhead", "trail_len": 0.26, "sfx": "whoosh_big", "pitch": 0.85, "impact_fx": true, "reach": "claw", "color": Color(1.0, 0.35, 0.3)},
	"slam": {"anim": "heavy", "windup": 0.3, "active": 0.2, "recovery": 0.3, "impulse": 5.0,
		"damage": 35.0, "hitstop": 0.1, "shake": 0.2, "knockback": 10.0, "stagger": 0.5,
		"trail": "overhead", "trail_len": 0.3, "sfx": "whoosh_big", "pitch": 1.0, "impact_fx": true},
}

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


static func style_for(weapon_model: String) -> String:
	match weapon_model:
		"axe":
			return "whirl"
		"cutlass", "sword", "rapier", "dagger":
			return "thrust"
	return "slam"


func enter(_data: Dictionary) -> void:
	timer = 0.0
	phase = 0
	hitbox_activated = false
	impact_fx = false
	player.reset_combo()
	var model := player.equipped_weapon.weapon_model if player.equipped_weapon else ""
	match player.style():
		"dual_sword":
			cfg = STYLES["dual_heavy"]
		"fist":
			cfg = STYLES["kick"]
		"pistol":
			cfg = STYLES["whip"]
		"dual_pistol":
			cfg = STYLES["kata"]
		"claw":
			cfg = STYLES["maul"]
		_:
			cfg = STYLES[style_for(model)]
	player.set_reach(str(cfg.get("reach", "sword")))
	_kata_shots = 0
	_rehit_done = false

	# Snap to camera forward
	var forward := get_camera_forward()
	player.player_model.rotation.y = atan2(-forward.x, -forward.z)
	player.body_model.play(str(cfg["anim"]), float(cfg["windup"]) + float(cfg["active"]) + float(cfg["recovery"]))


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	if cfg.get("kata", false):
		_kata_move(delta)
	elif cfg.has("steer") and phase == 1:
		_steer(delta, float(cfg["steer"]))
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, 20.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, 20.0 * delta)
	player.move_and_slide()

	timer += delta

	match phase:
		0:  # Windup
			if timer >= float(cfg["windup"]):
				phase = 1
				timer = 0.0
				var col: Color = cfg.get("color", Color(0.45, 0.75, 1.0))
				if player.power.buff("coat"):
					col = Player.HAKI_TRAIL
				if str(cfg["trail"]) != "":
					Net.fx("slash", [player.player_model, str(cfg["trail"]), float(cfg["trail_len"]), col])
				if cfg.get("double_trail", false):
					Net.fx("slash", [player.player_model, "spin", float(cfg["trail_len"]), col])
				Net.fx("sfx", [str(cfg["sfx"]), player.global_position, -4.0, 0.08, float(cfg["pitch"])])
				if cfg.get("wind", false):
					var b := player.player_model.global_basis
					Net.fx("punch_wind", [player.global_position + Vector3.UP * 1.05 + b.x * 0.15 - b.z * 0.3, -b.z, 1.7,
						col if player.power.buff("coat") else Color(1.0, 0.97, 0.9), true])
				player.squash(-3.0)
				if cfg.get("kata", false):
					if player.is_on_floor():
						player.velocity.y = KATA_HOP   # spins in the air, not planted on the ground
				else:
					var face_dir := get_camera_forward()
					player.velocity.x = face_dir.x * float(cfg["impulse"])
					player.velocity.z = face_dir.z * float(cfg["impulse"])
				# (the whirlwind's first turn only staggers: the second knocks them flat)
				var hit := _hit(not cfg.has("rehit"))
				if not cfg.get("kata", false):
					player.sword_hitbox.activate(hit)
				hitbox_activated = true

		1:  # Active
			# the whirlwind's second turn: a fresh hit on everyone about you (the
			# hitbox off for a few frames first, so those already inside it register again)
			if cfg.has("rehit") and not _rehit_done and timer >= float(cfg["rehit"]) - 0.06:
				player.sword_hitbox.deactivate()
			if cfg.has("rehit") and not _rehit_done and timer >= float(cfg["rehit"]):
				_rehit_done = true
				player.sword_hitbox.activate(_hit(true))
				var col2: Color = Player.HAKI_TRAIL if player.power.buff("coat") else cfg.get("color", Color(0.45, 0.75, 1.0))
				Net.fx("slash", [player.player_model, str(cfg["trail"]), float(cfg["trail_len"]), col2])
				Net.fx("sfx", [str(cfg["sfx"]), player.global_position, -4.0, 0.08, float(cfg["pitch"]) * 1.1])
				Net.fx("dust_ring", [player.global_position, 10, 0.8])
			# gun kata: spin and put a shot into everyone close
			if cfg.get("kata", false):
				var due := int(timer / float(cfg["active"]) * 4.0)
				while _kata_shots < mini(due + 1, 4):
					_kata_shots += 1
					_kata_volley()
			if cfg["impact_fx"] and timer >= float(cfg["active"]) * 0.5 and not impact_fx:
				impact_fx = true
				var front := player.global_position - player.player_model.global_basis.z * 1.3
				Net.fx("dust_ring", [front, 16, 1.0])
				Net.fx("sparkle", [front + Vector3(0, 0.3, 0), 8, Color(1.0, 0.85, 0.5)])
			if timer >= float(cfg["active"]):
				phase = 2
				timer = 0.0
				player.sword_hitbox.deactivate()
				if not cfg["impact_fx"]:
					Net.fx("dust", [player.global_position + Vector3(0, 0.05, 0), 5, 0.5])

		2:  # Recovery
			if timer >= float(cfg["recovery"]):
				transitioned.emit(self, "Idle", {})

	# Allow dodge cancel during recovery
	if phase == 2 and wants_dodge():
		transitioned.emit(self, "Dodge", {})


func _hit(knockdown: bool) -> HitData:
	var hit := player.melee_hit(float(cfg["damage"]))
	# Armament Haki: heavy attacks can't be blocked
	if player.progression.has_flag("armament"):
		hit.unblockable = true
		hit.haki = true
	hit.hitstop_duration = float(cfg["hitstop"])
	hit.camera_shake_intensity = float(cfg["shake"])
	hit.knockback_force = float(cfg["knockback"])
	hit.stagger_duration = float(cfg["stagger"])
	hit.knockdown = knockdown
	hit.sever = str(cfg.get("reach", "sword")) != "fist" and not cfg.get("kata", false)
	return hit


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


func _kata_volley() -> void:
	var c := player.global_position + Vector3(0, 1.1, 0)
	var pc := player.power
	var hit_any := false
	for e in pc.enemies_in(c, 6.0):
		var hb := (e as Node).get("hurtbox") as Hurtbox
		if hb == null:
			continue
		var hd := player.melee_hit(9.0)
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
	player.align_hold = false
	player.sword_hitbox.deactivate()
	player.sword_pivot.rotation_degrees.z = 0.0
