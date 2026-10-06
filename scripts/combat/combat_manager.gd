extends Node

var _hitstop_active: bool = false


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
	Engine.time_scale = 1.0
	_hitstop_active = false


func apply_camera_shake(intensity: float, duration: float = 0.2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		var rig := camera.get_parent().get_parent()  # Camera3D -> SpringArm3D -> CameraRig
		if rig and rig.has_method("shake"):
			rig.shake(intensity, duration)


func apply_hit_effects(hit_data: HitData, bodies: Array = []) -> void:
	if hit_data.hitstop_duration > 0.0:
		apply_hitstop(hit_data.hitstop_duration, bodies)
	if hit_data.camera_shake_intensity > 0.0:
		apply_camera_shake(hit_data.camera_shake_intensity)
