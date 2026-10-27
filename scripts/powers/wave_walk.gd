class_name WaveWalk
extends StaticBody3D
## Tide Will's Wave Walk: run off the shore or a deck and the sea holds you for a few steps. A small floor under the
## captain's feet at the water's surface, moved with them each tick on their own machine (the others see their
## snapshots), so every on-foot state works on it as on ground. A step every STEP_S on it; STEPS of them, then it's
## gone and you're swimming. Solid ground fills the steps again (WillPowers).

const STEPS := 6
const STEP_S := 0.32
const SIZE := Vector3(1.6, 0.3, 1.6)
## Faster than a walk to step onto the water, and deep water under it (a beach's shallows are waded).
const MIN_SPEED := 5.0
const MIN_DEPTH := 1.0
## Your feet this close above the surface (or this little under it) to step on.
const ABOVE := 0.6
const UNDER := 0.25
const FOAM := Color(0.85, 0.95, 1.0)

var player: Player
var steps := STEPS
var _t := 0.0


static func can_start(p: Player) -> bool:
	if p.context != Player.Context.ON_FOOT or p.current_state_name() not in ["Move", "Jump", "Fall", "Dodge", "LightAttack"]:
		return false
	if Vector2(p.velocity.x, p.velocity.z).length() < MIN_SPEED:
		return false
	var d := p.water_depth()
	return d > -ABOVE and d < UNDER and p.water_depth_at(p.global_position) > MIN_DEPTH


static func start(p: Player, steps_left: int) -> WaveWalk:
	var w := WaveWalk.new()
	w.name = "WaveWalk"
	w.player = p
	w.steps = steps_left
	w.collision_layer = 1
	w.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	cs.shape = box
	w.add_child(cs)
	p.get_tree().current_scene.add_child(w)
	w._follow()
	w._arrive()
	return w


func _arrive() -> void:
	var at := Vector3(player.global_position.x, player.water_surface(), player.global_position.z)
	Net.fx("water_ring", [at, 1.4, 0.8])
	Net.fx("splash", [at, 6, 0.7])
	Net.fx("sfx", ["splash", at, -6.0, 0.1, 1.1])


## Under the captain's feet again; false once it's done (out of steps, off the water, swimming, aboard).
func tick(delta: float) -> bool:
	if not is_instance_valid(player) or player.context != Player.Context.ON_FOOT or player.current_state_name() in ["Swim", "Downed", "Climb", "Helm"]:
		return false
	if player.water_depth() < -3.0 or Ocean.depth_at(player.global_position, [player.get_rid(), get_rid()]) < MIN_DEPTH * 0.5:
		return false
	if player.is_on_floor():
		_t += delta
		if _t >= STEP_S:
			_t -= STEP_S
			steps -= 1
			var at := Vector3(player.global_position.x, player.water_surface(), player.global_position.z)
			Net.fx("water_ring", [at, 0.9, 0.6])
			Net.fx("spray", [at + Vector3(0, 0.1, 0), Vector3.UP, 5, FOAM, 2.5])
			Net.fx("sfx", ["splash", at, -12.0, 0.15, 1.3])
	if steps <= 0:
		return false
	_follow()
	return true


func _follow() -> void:
	var p := player.global_position
	global_position = Vector3(p.x, player.water_surface() - SIZE.y * 0.5, p.z)
