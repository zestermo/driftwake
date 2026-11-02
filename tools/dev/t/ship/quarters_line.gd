extends SceneTree
## The Quarters line (1.29): an old save's kit (no "quarters") is level 0, the reworked cabin; each level costs its
## price on the economy's curve and grows the cabin: 1 a metre longer (the quarterdeck forward), 3 a taller deckhead,
## 4 a second step down; every level shows on her outside. At 4 you still walk in down the steps onto the floor, and
## the bunk, galley and chest answer F. A rest in the bunk leaves you rested, longer for every level.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var LINES
var step := 0
var until := 0
var fails := 0
var rest0 := 0.0


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
			LINES = load("res://scripts/ship/ship_lines.gd")
			var kit = load("res://scripts/ship/ship_kit.gd").merged({"hull": 2, "galley": 1})
			check("an old save's kit: Quarters 0", int(kit["quarters"]) == 0)
			var prices := []
			for lv in range(4):
				prices.append(LINES.price("quarters", lv))
			print("   Quarters prices %s" % str(prices))
			check("four levels in the Cabin group, the price on the curve (80 first)", LINES.max_level("quarters") == 4 and LINES.line("quarters")["group"] == "Cabin" and prices[0] == 80 and prices[3] > prices[2])
			var L0 = ship.layout
			ship.apply_kit({"quarters": 1})
			var L1 = ship.layout
			check("1: a metre longer, the quarterdeck forward with it (%.1f -> %.1f)" % [L0.qd_front, L1.qd_front], is_equal_approx(L0.qd_front - L1.qd_front, 1.0) and ship.parts.pieces("quarters") == 1)
			ship.apply_kit({"quarters": 3})
			check("3: a taller deckhead (%.2f -> %.2f)" % [L1.qd_y, ship.layout.qd_y], ship.layout.qd_y > L1.qd_y + 0.2 and ship.parts.pieces("quarters") == 3)
			check("...the helm and the quarterdeck guns' spot up with it", absf(ship.helm_position.position.y - ship.layout.qd_y) < 0.05 and is_equal_approx(float(ship.layout.gun_spots[2][2]), ship.layout.qd_y))
			ship.apply_kit({"quarters": 4})
			check("4: a second step down (floor %.2f)" % ship.layout.cabin_y, ship.layout.cabin_y < L1.cabin_y - 0.15 and ship.parts.pieces("quarters") == 4)
			put(Vector3(0, ship.layout.deck_y + 0.1, ship.layout.qd_front - 2.0), PI)
			TK.press("move_forward")
			until = TK.wait_secs(2.4)
		1:
			TK.release("move_forward")
			until = TK.wait_ticks(20)
		2:
			var L = ship.layout
			check("the great cabin: in and down the steps onto its floor (y %.2f)" % local().y, L.in_cabin(local()) and absf(local().y - L.cabin_y) < 0.15 and p.is_on_floor())
			put(L.bed_at + Vector3(0.85, 0.1, 0.0), -PI * 0.5)
			until = TK.wait_ticks(12)
		3:
			check("by the bunk: F rests (%s)" % prompt(), prompt().to_lower().contains("bunk"))
			var L = ship.layout
			put(L.counter_at + Vector3(-0.85, 0.1, 0.3), PI * 0.5)
			until = TK.wait_ticks(12)
		4:
			check("by the galley: F cooks (%s)" % prompt(), prompt().to_lower().contains("galley"))
			put(ship.layout.storage_at + Vector3(0.6, 0.1, 0.7), PI)
			until = TK.wait_ticks(12)
		5:
			check("by the chest: F opens the storage (%s)" % prompt(), prompt().to_lower().contains("storage"))
			ship.apply_kit({})
			var regen0: float = p.progression.stat("regen_pct")
			root.get_node("GameManager").rest(p)
			rest0 = p.progression.rest_left
			check("a rest leaves you rested (more regen: %.2f -> %.2f)" % [regen0, p.progression.stat("regen_pct")], rest0 > 0.0 and p.progression.stat("regen_pct") > regen0 + 0.2)
			ship.apply_kit({"quarters": 4})
			root.get_node("GameManager").rest(p)
			print("   rested %.0f s at Quarters 0, %.0f s at 4" % [rest0, p.progression.rest_left])
			check("...45% longer in the great cabin", is_equal_approx(p.progression.rest_left, rest0 * 1.45))
			return TK.done(fails)
	step += 1
	return false
