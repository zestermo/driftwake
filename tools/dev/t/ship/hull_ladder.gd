extends SceneTree
## The sloop's hull ladders (1.29): they end at the waterline and lie on the hull (each rung just off the planks as the
## side tucks in). From the deck F at the head and S takes you down into the sea; from the water F grabs the foot and W
## climbs you back aboard.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var lad
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


func put_world(at: Vector3) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func prompt() -> String:
	var ic = p.interaction_component
	return ic.current_interactable.prompt_text if ic.current_interactable else ""


func interact() -> void:
	var ic = p.interaction_component
	if ic.current_interactable:
		ic.current_interactable.interact(p)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ship = stage.ship
			L = ship.layout
			lad = ship.ship_model.get_node("LadderStarboard")
			var foot: Vector3 = ship.ship_model.to_local(lad.to_global(lad.rung_at(-lad.length)))
			var water: float = -ship.FREEBOARD
			print("   ladder %.2f m, its foot at y %.2f (the waterline %.2f), x %.2f (the hull there %.2f)" % [lad.length, foot.y, water, foot.x, L.side_at(foot.z, foot.y)])
			check("the ladder ends at the waterline", absf(foot.y - water) < 0.25)
			var hug := true
			for k in range(5):
				var y: float = -lad.length * k / 4.0
				var r: Vector3 = ship.ship_model.to_local(lad.to_global(lad.rung_at(y)))
				if absf(r.x - L.side_at(r.z, r.y)) > 0.2:
					hug = false
			check("...its rungs lie on the hull all the way down", hug)
			put_world(lad.global_transform * Vector3(0, 0.1, -0.6))
			until = TK.wait_ticks(20)
		1:
			check("at the ladder's head on deck (%s)" % prompt(), prompt().contains("ladder"))
			interact()
			until = TK.wait_secs(0.9)
		2:
			check("...over the rail onto the ladder", p.current_state_name() == "Climb")
			Input.action_press("move_back")
			until = TK.wait_secs(4.0)
		3:
			Input.action_release("move_back")
			until = TK.wait_secs(1.5)
		4:
			check("S down off the foot: into the sea (%s)" % p.current_state_name(), p.current_state_name() == "Swim")
			put_world(lad.global_transform * (lad.rung_at(-lad.length + 0.4) + Vector3(0, 0, 0.8)))
			until = TK.wait_secs(1.0)
		5:
			check("in the sea by the ladder: swimming", p.current_state_name() == "Swim")
			interact()
			until = TK.wait_secs(0.5)
		6:
			check("F grabs the ladder", p.current_state_name() == "Climb")
			Input.action_press("move_forward")
			until = TK.wait_secs(5.0)
		7:
			Input.action_release("move_forward")
			until = TK.wait_secs(0.5)
		8:
			check("W: up the ladder onto the deck (y %.2f)" % local().y, absf(local().y - L.deck_y) < 0.25 and ship.aboard(p.global_position))
			return TK.done(fails)
	step += 1
	return false
