extends PlayerState
## Heavy attack, shaped by the weapon in hand:
## * cutlass (and other blades): a lunging thrust - coil back, then drive
##   forward with the point leading, long reach, quick recovery
## * axe: a one-handed overhead chop - rear back, then hack down through a
##   forward step, slower but hits hardest and staggers longest
## * anything else: the leaping two-handed slam

## Per-style timing / feel. windup -> active (hitbox on) -> recovery.
const STYLES := {
	"thrust": {"anim": "thrust", "windup": 0.22, "active": 0.18, "recovery": 0.35, "impulse": 11.0,
		"damage": 32.0, "hitstop": 0.08, "shake": 0.16, "knockback": 12.0, "stagger": 0.4,
		"trail": "thrust", "trail_len": 0.22, "sfx": "whoosh", "pitch": 1.25, "impact_fx": false},
	"axe": {"anim": "axe_heavy", "windup": 0.34, "active": 0.14, "recovery": 0.42, "impulse": 4.0,
		"damage": 40.0, "hitstop": 0.12, "shake": 0.3, "knockback": 9.0, "stagger": 0.6,
		"trail": "overhead", "trail_len": 0.26, "sfx": "whoosh_big", "pitch": 0.9, "impact_fx": true},
	"slam": {"anim": "heavy", "windup": 0.3, "active": 0.2, "recovery": 0.3, "impulse": 5.0,
		"damage": 35.0, "hitstop": 0.1, "shake": 0.2, "knockback": 10.0, "stagger": 0.5,
		"trail": "overhead", "trail_len": 0.3, "sfx": "whoosh_big", "pitch": 1.0, "impact_fx": true},
}

var timer: float = 0.0
var phase: int = 0  # 0 = windup, 1 = active, 2 = recovery
var hitbox_activated: bool = false
var impact_fx: bool = false
var cfg: Dictionary = {}


static func style_for(weapon_model: String) -> String:
	match weapon_model:
		"axe":
			return "axe"
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
	cfg = STYLES[style_for(model)]

	# Snap to camera forward
	var forward := get_camera_forward()
	player.player_model.rotation.y = atan2(-forward.x, -forward.z)
	player.body_model.play(str(cfg["anim"]), float(cfg["windup"]) + float(cfg["active"]) + float(cfg["recovery"]))


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 20.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, 20.0 * delta)
	player.move_and_slide()

	timer += delta

	match phase:
		0:  # Windup
			if timer >= float(cfg["windup"]):
				phase = 1
				timer = 0.0
				FX.slash(player.player_model, str(cfg["trail"]), float(cfg["trail_len"]))
				FX.sfx(str(cfg["sfx"]), player.global_position, -4.0, 0.08, float(cfg["pitch"]))
				player.squash(-3.0)
				var face_dir := get_camera_forward()
				player.velocity.x = face_dir.x * float(cfg["impulse"])
				player.velocity.z = face_dir.z * float(cfg["impulse"])
				var hit := HitData.new()
				hit.damage = float(cfg["damage"]) * player.damage_multiplier()
				hit.hitstop_duration = float(cfg["hitstop"])
				hit.camera_shake_intensity = float(cfg["shake"])
				hit.knockback_force = float(cfg["knockback"])
				hit.stagger_duration = float(cfg["stagger"])
				hit.knockdown = true
				player.sword_hitbox.activate(hit)
				hitbox_activated = true

		1:  # Active
			if cfg["impact_fx"] and timer >= float(cfg["active"]) * 0.5 and not impact_fx:
				impact_fx = true
				var front := player.global_position - player.player_model.global_basis.z * 1.3
				FX.dust_ring(front, 16, 1.0)
				FX.sparkle(front + Vector3(0, 0.3, 0), 8, Color(1.0, 0.85, 0.5))
			if timer >= float(cfg["active"]):
				phase = 2
				timer = 0.0
				player.sword_hitbox.deactivate()
				if not cfg["impact_fx"]:
					FX.dust(player.global_position + Vector3(0, 0.05, 0), 5, 0.5)

		2:  # Recovery
			if timer >= float(cfg["recovery"]):
				transitioned.emit(self, "Idle", {})

	# Allow dodge cancel during recovery
	if phase == 2 and wants_dodge():
		transitioned.emit(self, "Dodge", {})


func exit() -> void:
	player.sword_hitbox.deactivate()
	player.sword_pivot.rotation_degrees.z = 0.0
