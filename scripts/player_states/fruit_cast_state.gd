class_name FruitCastState
extends PlayerState
## Casting a Driftfruit power (1.27; PowerComponent.try_cast puts you here with {"slot", "id"} for anything in CASTS):
## the power's pose (FruitPoses) plays with its wind-up drawn in the fruit's colours (FruitFX.windup), the power goes off
## on the pose's strike key (PowerComponent._fire), the release lands with it (FruitFX.release), and the follow-through
## holds before you're free. You face where the camera looks as it starts. An ultimate or awakening holds a longer
## gather, can't be hurt until a moment after it goes off, and has its moment (FruitFX.moment). A power that moves you
## (a dash, a blink, a leap) moves you on the strike key; a leap leaves this state for the fall.
## Its own forms (PowerComponent.auto_effect) fire at once, without a cast.

## id -> [pose, length (s)]. The strike key: FruitPoses.STRIKE[pose] * length.
const CASTS := {
	# Storm
	"thunder_step": ["df_dash", 0.32], "chain_lightning": ["df_thrust", 0.5], "thundercloud": ["df_sky", 0.7],
	"static_burst": ["df_spin", 0.6], "thunder_spear": ["df_thrust", 0.6], "thunder_lance": ["df_thrust", 0.65],
	"tempest": ["df_sky", 1.1], "judgement_bolt": ["df_sky", 1.2], "stormborn": ["df_burst", 1.4],
	# Gust
	"gale_dash": ["df_dash", 0.32], "gust_cone": ["df_thrust", 0.55], "gust_updraft": ["df_uppercut", 0.6],
	"pull_gale": ["df_pull", 0.7], "gale_burst": ["df_spin", 0.65], "wind_blade": ["df_sweep", 0.55],
	"cyclone": ["df_spin", 1.0], "hurricane": ["df_burst", 1.2], "skyborn": ["df_burst", 1.4],
	# Wolf (Rending Fang, Pounce and Alpha Howl keep their own SkillState casts)
	"hamstring": ["df_sweep", 0.55], "lunge": ["df_dash", 0.35], "shadow_pounce": ["df_dash", 0.35],
	"blood_moon": ["df_roar", 1.2], "pack_fury": ["df_spin", 0.9], "moonborn": ["df_burst", 1.4],
	# Bear
	"bear_charge": ["df_dash", 0.4], "bear_roar": ["df_roar", 0.9], "bear_hug": ["df_hug", 1.0], "maul": ["df_slam", 0.8],
	"second_wind": ["df_self", 0.6], "overhead_smash": ["df_slam", 0.85], "bear_avalanche": ["df_dash", 0.55],
	"great_roar": ["df_roar", 1.2], "mountainborn": ["df_burst", 1.4],
	# Vine (Vine Snare, Vine Swing and Thorn Whip keep their own)
	"root_field": ["df_stomp", 0.65], "grasping_vine": ["df_pull", 0.75], "thorn_lash": ["df_sweep", 0.55],
	"forest_prison": ["df_burst", 1.2], "thorn_storm": ["df_spin", 1.0], "rootborn": ["df_burst", 1.4],
	# Iron
	"iron_guard": ["df_self", 0.5], "iron_fist": ["df_thrust", 0.55], "iron_slam": ["df_slam", 0.8],
	"iron_drop": ["df_leap", 0.4], "anvil": ["df_slam", 0.75], "iron_uppercut": ["df_uppercut", 0.6],
	"iron_fortress": ["df_slam", 1.1], "meteor_drop": ["df_leap", 0.6], "ironborn": ["df_burst", 1.4],
	# Bubble
	"bubble_shield": ["df_self", 0.5], "slick_floor": ["df_stomp", 0.6], "bubble_trap": ["df_thrust", 0.55],
	"bubble_bounce": ["df_leap", 0.4], "bubble_bath": ["df_self", 0.7], "soap_spray": ["df_thrust", 0.55],
	"bubble_prison": ["df_burst", 1.1], "bubble_sanctuary": ["df_self", 1.0], "foamborn": ["df_burst", 1.4],
	# Clockwork
	"rewind": ["df_self", 0.35], "time_stop": ["df_thrust", 0.5], "slow_field": ["df_stomp", 0.6], "haste": ["df_sky", 0.6],
	"accelerate": ["df_self", 0.5], "slow_bolt": ["df_thrust", 0.55], "time_freeze": ["df_burst", 1.2],
	"overclock": ["df_sky", 1.0], "timeborn": ["df_burst", 1.4],
	# Echo
	"echo_step": ["df_dash", 0.3], "shatter_note": ["df_thrust", 0.6], "sonar": ["df_self", 0.55],
	"echo_strike": ["df_self", 0.5], "ringing_ears": ["df_roar", 0.8], "echo_ring": ["df_spin", 0.6],
	"sonic_boom": ["df_thrust", 1.0], "resonance_cascade": ["df_burst", 1.2], "soundborn": ["df_burst", 1.4],
	# Ember (its first powers keep their own SkillState casts)
	"flicker": ["df_self", 0.35], "flare_burst": ["df_spin", 0.6], "solar_flare": ["df_burst", 1.2], "sunborn": ["df_burst", 1.4],
}
## After an ultimate goes off you stay untouchable this long.
const ULT_GRACE := 0.25

var id := ""
var slot := -1
var t := 0.0
var dur := 0.5
var _strike := 0.2
var _pose := ""
var _dir := Vector3.FORWARD
var _ult := false
var _fired := false
var _pc: PowerComponent


## How long after a cast its power goes off (the tests and the forms wait on it).
static func strike_of(power_id: String) -> float:
	if not CASTS.has(power_id):
		return 0.0
	return float(FruitPoses.STRIKE[CASTS[power_id][0]]) * float(CASTS[power_id][1])


func enter(data: Dictionary) -> void:
	id = str(data.get("id", ""))
	slot = int(data.get("slot", -1))
	_pc = player.power
	t = 0.0
	_fired = false
	var c: Array = CASTS.get(id, ["df_thrust", 0.5])
	_pose = str(c[0])
	dur = float(c[1])
	_strike = float(FruitPoses.STRIKE[_pose]) * dur
	_ult = Skills.is_ult(id)
	player.sprinting = false
	player.is_parrying = false
	player.sword_hitbox.deactivate()
	player.reset_combo()
	# (aimed where the camera looks; the body turns to it at once so the wind-up reads toward the target)
	_dir = get_camera_forward()
	_dir.y = 0.0
	_dir = _dir.normalized() if _dir.length() > 0.01 else -player.player_model.global_basis.z
	face_direction(_dir, 1.0)
	player.body_model.play(_pose, dur)
	if _ult:
		player.hurtbox.set_deferred("monitorable", false)
	FruitFX.windup(player, _pc.fruit, _pose, _dir, _strike, _ult)


func physics_update(delta: float) -> void:
	t += delta
	if not _fired:
		face_direction(_dir, 1.0)
	_rooted(delta)
	if not _fired and t >= _strike:
		_fired = true
		player.player_model.look_at(player.player_model.global_position - _dir, Vector3.UP)
		_pc._fire(slot, id, Skills.get_skill(id))
		FruitFX.release(player, _pc.fruit, _pose, _dir, _ult)
		# (a leap hands over to the fall: nothing more here)
		if player.current_state_name() != "FruitCast":
			return
	if _ult and _fired and t >= _strike + ULT_GRACE:
		player.hurtbox.set_deferred("monitorable", true)
	if t >= dur:
		_finish()


## Stand your ground through the cast (the power moves you if it's meant to).
func _rooted(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 40.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, 40.0 * delta)
	player.move_and_slide()


func _finish() -> void:
	if not player.is_on_floor():
		transitioned.emit(self, "Fall", {})
	elif get_movement_input().length() > 0.1:
		transitioned.emit(self, "Move", {})
	else:
		transitioned.emit(self, "Idle", {})


func exit() -> void:
	player.hurtbox.set_deferred("monitorable", true)
	# (cut short before it went off, knocked down mid-wind-up: it fizzles, as SkillState's casts do)
