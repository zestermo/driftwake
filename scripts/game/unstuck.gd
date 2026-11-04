class_name Unstuck
extends RefCounted
## (1.30, playtest 2026-11-02 row 6: captains fell through the capital and the fortress with no way back.) The way out of
## a hole: the pause menu's Unstuck puts the captain back on the last safe ground they stood on (a few metres back, on a
## ship's deck where she is now), or in the ship's cabin; and a captain under an island's ground with nothing under
## them for a second is put back there by itself. Each captain moves themselves (the local one; puppets follow).
## Below the sea it's GroundNet's (a swimmer under an island).

## Checked once every this many physics ticks.
const EVERY := 8
const COOLDOWN := 10.0
## Safe spots kept this far apart, this many of them; Unstuck takes the newest at least AWAY from the captain.
const SPACING := 3.0
const KEEP := 6
const AWAY := 2.0
## Under the island's ground by this much, with nothing under the feet for WARP_AFTER seconds: the automatic warp.
const BELOW := 1.5
const WARP_AFTER := 1.0
## Below this nothing is ever right.
const VOID_Y := -60.0
## Standing in these is safe ground; in these Unstuck is refused (you're not stuck, or it would undo something).
const SAFE_STATES := ["Idle", "Move", "Crouch"]
const REFUSE := ["Downed", "Helm", "Cannon", "Skimmer", "Downtime", "Swim"]

## The safe spots, oldest first: [ship or null, position (ship-local on a deck)].
var spots: Array = []
var _below := 0.0
var _ready_at := -INF


func tick(p: Node3D) -> void:
	if Engine.get_physics_frames() % EVERY != 0:
		return
	if p.is_on_floor() and p.context == Player.Context.ON_FOOT and p.current_state_name() in SAFE_STATES:
		_note(p)
	if _under(p):
		_below += float(EVERY) / Engine.physics_ticks_per_second
		if _below >= WARP_AFTER:
			_below = 0.0
			var at := spot_for(p)
			if at != Vector3.INF:
				_put(p, at)
				p._toast("Back on solid ground")
	else:
		_below = 0.0


## The pause menu's Unstuck: what the captain is told.
func request(p: Node3D) -> String:
	if p.health_component.current_health <= 0.0 or p.is_bleeding() or p.current_state_name() in REFUSE:
		return "You can't get unstuck right now"
	var left := _ready_at - PlayerState.now_s()
	if left > 0.0:
		return "Unstuck again in %d s" % ceili(left)
	var at := spot_for(p)
	if at == Vector3.INF:
		return "Nowhere safe to go"
	_put(p, at)
	_ready_at = PlayerState.now_s() + COOLDOWN
	return "Back on solid ground"


## Where Unstuck would put the captain: the newest safe spot at least AWAY from them, else the ship's cabin.
func spot_for(p: Node3D) -> Vector3:
	for i in range(spots.size() - 1, -1, -1):
		var at := _world(spots[i])
		if at != Vector3.INF and at.distance_to(p.global_position) >= AWAY:
			return at
	var ship := p.get_tree().get_first_node_in_group("ship")
	if ship:
		return (ship.respawn_point as Node3D).global_position
	return Vector3.INF


func _note(p: Node3D) -> void:
	var pos := p.global_position
	var ship = p._deck_ship()
	var spot: Array
	if ship:
		spot = [ship, (ship as Node3D).global_transform.affine_inverse() * pos]
	else:
		var land := GroundNet.land_height(p.get_tree(), pos)
		if not is_nan(land) and pos.y < land - BELOW:
			return
		spot = [null, pos]
	if not spots.is_empty() and spots[-1][0] == spot[0] and _world(spots[-1]).distance_to(pos) < SPACING:
		spots[-1] = spot
		return
	spots.append(spot)
	if spots.size() > KEEP:
		spots.pop_front()


func _world(spot: Array) -> Vector3:
	if spot[0] == null:
		return spot[1]
	if not is_instance_valid(spot[0]):
		return Vector3.INF
	return (spot[0] as Node3D).global_transform * (spot[1] as Vector3)


## Under an island's ground with nothing to stand on below (not swimming: that's GroundNet's), or far under the world.
func _under(p: Node3D) -> bool:
	var pos := p.global_position
	if p.current_state_name() in ["Swim", "Downed"] or p.is_on_floor():
		return false
	if pos.y < VOID_Y:
		return true
	var land := GroundNet.land_height(p.get_tree(), pos)
	if is_nan(land) or pos.y > land - BELOW:
		return false
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.1, pos + Vector3.DOWN * 6.0, 1)
	q.exclude = [p.get_rid()]
	return p.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _put(p: Node3D, at: Vector3) -> void:
	p.global_position = at + Vector3.UP * 0.1
	p.velocity = Vector3.ZERO
	p.fall_top = at.y
	p._last_air_vy = 0.0
	p.reset_physics_interpolation()
	p.state_machine.force_state("Idle", {})
