extends SceneTree
## The sloop's cabin (1.29): stepped down into the hull and bigger than the pirates'. In through the door and down the
## steps you stand on the cabin floor, below the main deck, under the quarterdeck; the bunk, galley and storage chest
## each answer F beside them; back out up the steps onto the main deck. You wake beside the bunk.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var L
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


func local() -> Vector3:
	return ship.to_local(p.global_position)


func put(v: Vector3, yaw: float) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = ship.global_transform * v
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	stage.camera_rig.global_rotation.y = ship.global_rotation.y + yaw
	p.player_model.global_rotation.y = ship.global_rotation.y + yaw


func prompt() -> String:
	var ic = p.interaction_component
	return ic.current_interactable.prompt_text if ic.current_interactable else ""


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ship = stage.ship
			L = ship.layout
			var base = load("res://scripts/ship/hull_layout.gd").base()
			check("the cabin floor is below the main deck (%.2f < %.2f)" % [L.cabin_y, L.deck_y], L.cabin_y < L.deck_y - 0.3)
			check("...and the cabin longer than the pirates' (%.1f > %.1f m)" % [L.qd_back - L.qd_front, base.qd_back - base.qd_front], L.qd_back - L.qd_front > base.qd_back - base.qd_front + 0.4)
			put(Vector3(0, L.deck_y + 0.1, L.qd_front - 2.0), PI)
			Input.action_press("move_forward")
			until = TK.wait_secs(2.2)
		1:
			Input.action_release("move_forward")
			until = TK.wait_ticks(20)
		2:
			check("in through the door and down the steps (z %.1f, y %.2f)" % [local().z, local().y], L.in_cabin(local()) and absf(local().y - L.cabin_y) < 0.15 and p.is_on_floor())
			check("...under the quarterdeck", local().y < L.qd_y - 1.8)
			put(L.bed_at + Vector3(0.85, 0.1, 0.0), -PI * 0.5)
			until = TK.wait_ticks(12)
		3:
			check("by the bunk: F rests (%s)" % prompt(), prompt().to_lower().contains("bunk"))
			put(L.counter_at + Vector3(-0.85, 0.1, 0.3), PI * 0.5)
			until = TK.wait_ticks(12)
		4:
			check("by the galley: F cooks (%s)" % prompt(), prompt().to_lower().contains("galley"))
			put(L.storage_at + Vector3(0.6, 0.1, 0.7), PI)
			until = TK.wait_ticks(12)
		5:
			check("by the chest: F opens the storage (%s)" % prompt(), prompt().to_lower().contains("storage"))
			check("you wake beside the bunk, in the cabin", L.in_cabin(ship.to_local(ship.respawn_point.global_position)) and ship.respawn_point.position.distance_to(L.bed_at) < 1.6)
			put(Vector3(0, L.cabin_y + 0.1, L.qd_front + 2.0), 0.0)
			Input.action_press("move_forward")
			until = TK.wait_secs(2.2)
		6:
			Input.action_release("move_forward")
			until = TK.wait_ticks(20)
		7:
			check("back up the steps and out on the main deck (z %.1f, y %.2f)" % [local().z, local().y], local().z < L.qd_front - 0.3 and absf(local().y - L.deck_y) < 0.15 and p.is_on_floor())
			return TK.done(fails)
	step += 1
	return false
