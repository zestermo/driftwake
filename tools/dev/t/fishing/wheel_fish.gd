extends SceneTree
## The action wheel's Fish starts the rod's minigame: with no rod it says to equip one (and doesn't start);
## aboard with a rod it takes you to the nearer rail facing out and casts (no lashing needed: the float keeps
## to the ship's frame). A crewmate's screen sees it: the puppet's rod gets the cast, the float and the catch.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pup
var ship
var AW
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true, "crew": [{"name": "Wren", "at": Vector3(3, 0, -2)}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pup = stage.crew[0]
			ship = stage.ship
			AW = load("res://scripts/game/action_wheel.gd")
			p.global_position = ship.global_transform * Vector3(0.3, ship.DECK_Y + 0.3, -1.0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		1:
			check("aboard, Fish can be picked (%s)" % AW.why_not("fish", p), AW.place(p) == "ship" and AW.why_not("fish", p) == "")
			AW.run("fish", p)
			check("with no rod it doesn't start", p.current_state_name() != "Fish")
			p.inventory_component.add_item(ItemDB.get_item("rod_steel"), 1)
			p.equip_gear_from_bag(p.inventory_component.find_index("rod_steel"))
			ship.sail = 1.0 / 3.0
			ship.speed = 3.0
			until = TK.wait_ticks(4)
		2:
			AW.run("fish", p)
			var l: Vector3 = ship.global_transform.affine_inverse() * p.global_position
			check("with a rod: at the starboard rail facing out, casting (%s, x %.2f)" % [p.current_state_name(), l.x],
				p.current_state_name() == "Fish" and l.x > HullBuilder.half_width(l.z) - 1.0 and not ship.lashed)
			until = TK.wait_secs(2.0)
		3:
			var rod = p.fish_rod
			var off: Vector3 = ship.global_transform.affine_inverse() * rod._bob.global_position
			check("the float's out over the side, under way (%s, %.1f m off the centreline)" % [rod.phase, off.x], rod.phase == "float" and off.x > HullBuilder.half_width(off.z) + 1.0)
			# what a crewmate's screen gets (Net.event arrives as net_event on the puppet's rod)
			var at: Vector3 = pup.global_position + Vector3(4, 0, 0)
			pup.body_model.apply_look(pup.body_model.look.merged({"rod": "bamboo"}, true))
			pup.fish_rod.net_event("throw", [Vector3(at.x, 0.0, at.z)])
			until = TK.wait_secs(1.0)
		4:
			check("a crewmate's cast: their float out on the water", pup.fish_rod.phase == "float" and pup.fish_rod._bob.visible)
			pup.fish_rod.net_event("land", ["fish_snapper"])
			until = TK.wait_ticks(3)
		5:
			check("...their catch on the line", pup.fish_rod.phase == "land" and pup.fish_rod._fish.visible)
			pup.fish_rod.net_event("stop", [])
			until = TK.wait_ticks(2)
		6:
			check("...and put away", pup.fish_rod.phase == "" and not pup.fish_rod._fish.visible)
			ship.sail = 0.0
			return TK.done(fails)
	step += 1
	return false
