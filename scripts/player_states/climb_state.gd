extends PlayerState
## Climbing out of the water: up a rope ladder (hand over hand, then over the
## rail onto the deck) or pulling yourself up onto a low ledge. The path is
## kept in the frame of what you climb, so it works on a rocking ship.

const LADDER_SPEED := 1.7

var anchor: Node3D
var keys: Array = []      # [[time, local_pos], ...]
var total: float = 0.0
var t: float = 0.0
var kind: String = ""
var _yaw_local: float = 0.0
var _climb_top: float = 0.0


func enter(data: Dictionary) -> void:
	t = 0.0
	kind = str(data.get("kind", "ledge"))
	player.velocity = Vector3.ZERO
	player.sprinting = false
	player.body_model.swimming = false
	player.stamina_regen_mult = 1.0
	keys.clear()
	if kind == "ladder":
		var lad: Ladder = data["ladder"]
		anchor = lad
		var start := lad.to_local(player.global_position)
		var y0 := minf(start.y, lad.rail - 0.6)
		var climb_to := lad.rail + 0.05
		_climb_top = climb_to
		var t_grab := 0.25
		var t_up := t_grab + maxf(climb_to - y0, 0.2) / LADDER_SPEED
		var t_over := t_up + (0.55 if lad.rail > 0.0 else 0.4)
		var t_end := t_over + 0.3
		keys = [[0.0, start], [t_grab, Vector3(0, y0, 0.4)], [t_up, Vector3(0, climb_to, 0.4)],
			[t_over, Vector3(0, lad.rail + 0.12, -0.2)], [t_end, Vector3(0, 0.0, -lad.deck_depth)]]
		total = t_end
		_yaw_local = 0.0  # face -Z of the ladder (toward the deck)
		player.body_model.climbing = true
		player.body_model.climb_phase = 0.0
	else:
		anchor = data.get("anchor") as Node3D
		var edge: Vector3 = data["edge"]
		var top: Vector3 = data["top"]
		var fwd: Vector3 = data["fwd"]
		var start := player.global_position
		var hang := Vector3(edge.x, edge.y - 0.95, edge.z) - fwd * 0.42
		if anchor:
			start = anchor.to_local(start)
			hang = anchor.to_local(hang)
			var e := anchor.to_local(edge - fwd * 0.1 + Vector3.UP * 0.05)
			var tp := anchor.to_local(top)
			keys = [[0.0, start], [0.18, hang], [0.5, e], [0.78, tp]]
			_yaw_local = _local_yaw(anchor, fwd)
		total = 0.78
		player.body_model.play("mantle", total)
		FX.splash(Vector3(player.global_position.x, player.water_surface(), player.global_position.z), 5, 0.6)
	FX.sfx("splash", player.global_position, -8.0, 0.1, 1.2)
	player.sheathe_weapon(true)


func _local_yaw(a: Node3D, world_dir: Vector3) -> float:
	var d := a.global_basis.orthonormalized().inverse() * world_dir
	return atan2(-d.x, -d.z)


func physics_update(delta: float) -> void:
	if anchor == null or not is_instance_valid(anchor) or keys.is_empty():
		transitioned.emit(self, "Idle", {})
		return
	t += delta
	var lp := _sample(minf(t, total))
	player.global_position = anchor.global_transform * lp
	player.velocity = Vector3.ZERO
	# face the ladder / the ledge
	var f := anchor.global_basis.orthonormalized() * Vector3(-sin(_yaw_local), 0.0, -cos(_yaw_local))
	f.y = 0.0
	if f.length() > 0.1:
		player.player_model.rotation.y = atan2(-f.x, -f.z)
	if kind == "ladder":
		player.body_model.climb_phase = lp.y
		# over the rail: let go of the climbing pose
		if lp.y >= _climb_top - 0.01 and t > keys[2][0]:
			player.body_model.climbing = false
	if t >= total:
		transitioned.emit(self, "Idle", {})


func _sample(time: float) -> Vector3:
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if time <= float(b[0]):
			var x := clampf((time - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0)
			x = x * x * (3.0 - 2.0 * x)
			return (a[1] as Vector3).lerp(b[1], x)
	return keys[keys.size() - 1][1]


func exit() -> void:
	player.body_model.climbing = false
	player.velocity = Vector3.ZERO
	anchor = null
