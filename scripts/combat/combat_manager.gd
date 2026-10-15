extends Node

var _hitstop_active: bool = false
## What time runs at when no hit-stop holds it (slow motion sets it).
var _base_scale: float = 1.0
var _slowmo_id: int = 0


## `bodies`: who's in the clash (attacker, target). Alone the whole world
## freezes; in co-op it can't (enemies, the other captains and the clock keep
## going), so only those bodies freeze here, and only when one is our captain.
func apply_hitstop(duration: float, bodies: Array = []) -> void:
	var net := get_node_or_null("/root/Net")
	if net and net.active:
		if net.local_player not in bodies:
			return
		for b in bodies:
			if is_instance_valid(b) and b.has_method("hit_freeze"):
				b.hit_freeze(duration)
		return
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = _base_scale
	_hitstop_active = false


## An ultimate's moment: the world runs at `scale` for `secs` (real time), then
## eases back over `ease_out`. Single player only (co-op can't slow the world).
func apply_slowmo(scale: float, secs: float, ease_out: float = 0.25) -> void:
	var net := get_node_or_null("/root/Net")
	if net and net.active:
		return
	_slowmo_id += 1
	var id := _slowmo_id
	_set_base(scale)
	await get_tree().create_timer(secs, true, false, true).timeout
	var steps := 6
	for i in range(steps):
		if id != _slowmo_id:
			return
		_set_base(lerpf(scale, 1.0, float(i + 1) / steps))
		await get_tree().create_timer(ease_out / steps, true, false, true).timeout


func _set_base(s: float) -> void:
	_base_scale = s
	if not _hitstop_active:
		Engine.time_scale = s


func apply_camera_shake(intensity: float, duration: float = 0.2) -> void:
	var rig := _rig()
	if rig and rig.has_method("shake"):
		rig.shake(intensity, duration)


## Punch the camera in on the action (0..1), easing back over `secs`.
func apply_camera_kick(amount: float, secs: float = 0.5) -> void:
	var rig := _rig()
	if rig and rig.has_method("kick"):
		rig.kick(amount, secs)


func _rig() -> Node:
	var camera := get_viewport().get_camera_3d()
	return camera.get_parent().get_parent() if camera else null  # Camera3D -> SpringArm3D -> CameraRig


## A blow thrown off its feet sounds heavier.
const HEAVY_IMPACT := {"slice": "slice_heavy", "punch": "punch_heavy"}
## Blows of steel (or lead): on a steel guard they clash, anything else on a guard knocks ("block").
const STEEL := ["slice", "slice_heavy", "chop", "shot"]
## The last impact and guard sounds played here (tests read them).
var last_impact: String = ""
var last_guard: String = ""


## The sound a blow makes on a body, by what struck (HitData.impact).
func impact_sound(hit: HitData) -> String:
	if hit.impact == "":
		return "hit"
	if hit.impact == "shot":
		return "shot_hit"
	if hit.knockdown or hit.crumple:
		return HEAVY_IMPACT.get(hit.impact, hit.impact)
	return hit.impact


## Play a blow landing on a body at `at`, on every screen.
func impact(hit: HitData, at: Vector3, volume_db: float, jitter: float, pitch: float) -> void:
	last_impact = impact_sound(hit)
	Net.fx("sfx", [last_impact, at, volume_db, jitter, pitch])


## A blow stopped by a guard (a block, a parry, a blade's edge turning it): steel on steel
## clashes, anything else on a guard is a duller knock.
func guard(hit: HitData, steel_guard: bool, at: Vector3, volume_db: float, jitter: float, pitch: float) -> void:
	last_guard = "clash" if steel_guard and hit.impact in STEEL else "block"
	Net.fx("sfx", [last_guard, at, volume_db, jitter, pitch])


func apply_hit_effects(hit_data: HitData, bodies: Array = []) -> void:
	if hit_data.hitstop_duration > 0.0:
		apply_hitstop(hit_data.hitstop_duration, bodies)
	if hit_data.camera_shake_intensity > 0.0:
		apply_camera_shake(hit_data.camera_shake_intensity)
