extends PlayerState
## (1.30) An AI captain boss's phase reset (BossReset: the drowned captain's, the stronghold officers'): a crouch, a
## leap to the arena's middle, the landing's shockwave, a roar; untouchable throughout (Player._on_hit_received). The
## host's brain stands down while it runs; then back to the fight.

var reset: BossReset
var _roared := false


func enter(data: Dictionary) -> void:
	reset = data["reset"]
	_roared = false
	player.velocity = Vector3.ZERO
	player.body_model.hold("sky_leap_charge", BossReset.WIND)


func exit() -> void:
	reset.stop()


func physics_update(delta: float) -> void:
	match reset.tick(delta):
		"air":
			player.body_model.hold("sky_leap", BossReset.AIR)
		"land":
			player.body_model.play("plunge_land", 0.45)
			player.squash(-9.0)
		"done":
			transitioned.emit(self, "Idle", {})
			return
	if reset.stage() == "roar" and not _roared and reset.t > BossReset.WIND + BossReset.AIR + 0.4:
		_roared = true
		player.body_model.play("berserk_roar", BossReset.ROAR_S - 0.4)
	var foe := Net.nearest_player(player.global_position) as Node3D
	var look := (reset.to - player.global_position) if reset.stage() == "wind" or foe == null else (foe.global_position - player.global_position)
	face_direction(Vector3(look.x, 0.0, look.z), delta)
	if reset.stage() == "air":
		return
	apply_gravity(delta)
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.move_and_slide()
