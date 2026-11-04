extends SceneTree
## (1.30) Unstuck by the ship's rules: a captain who last stood on her deck is put back on her deck where she is now
## (the spot kept relative to the hull), not where she was.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var deck: Vector3
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func put(at: Vector3) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ship = stage.ship
			var L = ship.layout
			put(ship.global_transform * Vector3(0, L.deck_y + 0.1, L.qd_front - 2.0))
			until = TK.wait_secs(0.6)
		1:
			deck = ship.to_local(p.global_position)
			check("standing on her deck (%s)" % deck, p.is_on_floor() and ship.aboard(p.global_position))
			ship.place(ship.global_position + Vector3(0, 0, 30), ship.rotation.y + 0.6)
			put(Vector3(0, 3.2, 0))
			until = TK.wait_ticks(10)
		2:
			put(Vector3(0, 3.2, 0))
			var said: String = p.unstuck.request(p)
			var off: float = ship.to_local(p.global_position).distance_to(deck)
			check("Unstuck puts the captain back on her deck where she lies now (%s, %.2f m off)" % [said, off], ship.aboard(p.global_position) and off < 0.6)
			until = TK.wait_secs(0.4)
		3:
			check("...standing on it", p.is_on_floor() and ship.aboard(p.global_position))
			return TK.done(fails)
	step += 1
	return false
