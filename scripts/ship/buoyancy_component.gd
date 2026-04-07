extends Node
class_name BuoyancyComponent

## How far above the wave surface the ship center should sit
@export var height_offset: float = 4.5
## How smoothly the ship follows the wave height
@export var follow_speed: float = 5.0

# Wave params — must match ocean_manager.gd and ocean.gdshader
var wave_amp: float = 0.8
var wave_freq: float = 0.8
var wave_spd: float = 1.5
var wave_dir: Vector2 = Vector2(1.0, 0.6).normalized()
var wave2_amp: float = 0.3
var wave2_freq: float = 1.5
var wave2_spd: float = 0.8
var wave2_dir: Vector2 = Vector2(-0.7, 1.0).normalized()


func _get_wave_height(pos: Vector3, time: float) -> float:
	var d1 := pos.x * wave_dir.x + pos.z * wave_dir.y
	var d2 := pos.x * wave2_dir.x + pos.z * wave2_dir.y
	return sin(d1 * wave_freq + time * wave_spd) * wave_amp + sin(d2 * wave2_freq + time * wave2_spd) * wave2_amp


func _physics_process(delta: float) -> void:
	var ship := get_parent() as RigidBody3D
	if not ship:
		return
	var time := Time.get_ticks_msec() / 1000.0

	# Lock Y to wave surface + offset
	var wave_y := _get_wave_height(ship.global_position, time)
	var target_y := wave_y + height_offset
	ship.global_position.y = lerpf(ship.global_position.y, target_y, follow_speed * delta)

	# Kill any vertical velocity so physics doesn't fight us
	ship.linear_velocity.y = 0.0
