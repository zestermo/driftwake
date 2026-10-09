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
		"trail": "overhead", "trail_len": 0.28, "sfx": "whoosh_big", "pitch": 0.95, "impact_fx": true, "reach": "wide", "double_trail": true},
	"kick": {"anim": "flying_kick", "impulse": 9.5, "wind": true,
		"damage": 26.0, "hitstop": 0.09, "shake": 0.2, "knockback": 12.0, "stagger": 0.5,
		"trail": "", "trail_len": 0.0, "sfx": "whoosh_big", "pitch": 1.2, "impact_fx": false, "reach": "fist"},
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
			cfg = STYLES["kata"] if player.progression.has_move("gun_kata") else STYLES["whip"]
		"claw":
			cfg = STYLES["maul"]
		_:
			cfg = STYLES[style_for(model)]
	player.set_reach(str(cfg.get("reach", "sword")))
	_kata_shots = 0
	_rehit_done = false
	_glinted = false

	# Snap to camera forward
	var forward := get_camera_forward()
	player.player_model.rotation.y = atan2(-forward.x, -forward.z)
	var anim := str(cfg["anim"])
	var length := ActionSpecs.length(anim)
	var w := ActionSpecs.hit_seconds(anim)
	_windup = w.x
	_active = w.y - w.x
	_recovery = length - w.y
	player.body_model.play(anim, length)


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
			# the point catches the light just before it goes
			if cfg.has("tree") and not _glinted and timer >= _windup - 0.07:
				_glinted = true
				var w: MeshInstance3D = player.body_model.weapon
				if w and w.mesh:
					Net.fx("glint", [w.global_transform * Vector3(0, 0, w.mesh.get_aabb().position.z * 0.85), Color.WHITE, 0.7])
			if timer >= _windup:
				phase = 1
				timer = 0.0
				var col := _trail_col()
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
				if cfg.has("tree"):
					_strike_fx()
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
				Net.fx("slash", [player.player_model, str(cfg["trail"]), float(cfg["trail_len"]), _trail_col()])
				Net.fx("sfx", [str(cfg["sfx"]), player.global_position, -4.0, 0.08, float(cfg["pitch"]) * 1.1])
				Net.fx("dust_ring", [player.global_position, 10, 0.8])
				_strike_fx()
			# gun kata: spin and put a shot into everyone close
			if cfg.get("kata", false):
				var due := int(timer / _active * 4.0)
				while _kata_shots < mini(due + 1, 4):
					_kata_shots += 1
					_kata_volley()
			if cfg["impact_fx"] and timer >= _active * 0.5 and not impact_fx:
				impact_fx = true
				var front := player.global_position - player.player_model.global_basis.z * 1.3
				Net.fx("dust_ring", [front, 16, 1.0])
				Net.fx("sparkle", [front + Vector3(0, 0.3, 0), 8, Color(1.0, 0.85, 0.5)])
			if timer >= _active:
				phase = 2
				timer = 0.0
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
## blow (the tree's second mastery passive), black with a Haki coat.
func _trail_col() -> Color:
	if player.power.buff("coat"):
		return Player.HAKI_TRAIL
	if cfg.has("tree") and player.progression.elemental(str(cfg["tree"]), 2):
		return FX.tree_col(str(cfg["tree"]), FX.EDGE)
	return cfg.get("color", Color(0.45, 0.75, 1.0))


## The strike's effects: a ring of air round the point and dust kicked up by the
## lunge (the whirlwind: a ring round you and rock kicked up); with the element on
## every blow (the tree's second mastery passive) they take its colours and throw
## its material.
func _strike_fx() -> void:
	var elem := player.progression.elemental(str(cfg["tree"]), 2)
	var tree := str(cfg["tree"]) if elem else "plain"
	if cfg.has("rehit"):
		var c := player.global_position
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
	var tip := player.global_position + Vector3(0, 1.2, 0) + f * 1.5
	Net.fx("ring", [tip, f, 1.3, FX.tree_col(tree, FX.EDGE), 0.22, 0.16])
	if elem:
		Net.fx("element", [tree, tip, f + Vector3.UP * 0.2, 10, 6.5])
	Net.fx("dust", [player.global_position + Vector3(0, 0.05, 0) - f * 0.4, 6, 0.6])
	CombatManager.apply_camera_kick(0.12, 0.3)


func _hit(knockdown: bool) -> HitData:
	var hit := player.melee_hit(float(cfg["damage"]), "heavy")
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
	if cfg.get("kata", false):
		# both guns emptied: a reload before they fire again
		reload_until = now_s() + KATA_RELOAD
		player.call("_toast", "Reloading...")
		Net.fx("sfx", ["blip_low", player.global_position, -8.0, 0.05, 1.4])
	player.align_hold = false
	player.sword_hitbox.deactivate()
	player.sword_pivot.rotation_degrees.z = 0.0
