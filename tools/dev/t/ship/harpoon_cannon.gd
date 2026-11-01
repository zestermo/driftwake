extends SceneTree
## The harpoon cannon (1.28, a ship gadget; HarpoonCannon's contract): with nothing ahead it's refused (no charge);
## with an enemy ship ahead of the bow U at the wheel shoots the line, the harpoon bites (her hull hurt, she's told she's
## harpooned), she's reeled in toward the ship for the tier's hold, then the line's let go (she's told, it's gone).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var es
var h0 := 0.0
var d0 := 0.0
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


func _dist() -> float:
	return Vector2(es.global_position.x - ship.global_position.x, es.global_position.z - ship.global_position.z).length()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ship = stage.ship
			p.gadgets.give("harpoon", 0)
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			until = TK.wait_ticks(5)
		1:
			p.current_ship = ship
			p.state_machine.force_state("Helm", {})
			until = TK.wait_ticks(3)
		2:
			TK.act("gadget_fire")
			until = TK.wait_ticks(3)
		3:
			check("nothing ahead: refused, no charge spent", p.gadgets.charges("harpoon") == GadgetData.tier_val("harpoon", "charges", 0) and get_nodes_in_group("harpoons").is_empty())
			var fwd: Vector3 = -ship.global_basis.z
			fwd.y = 0.0
			var at: Vector3 = ship.global_position + fwd.normalized() * 28.0
			es = load("res://scripts/ship/enemy_ship.gd").new().setup(at, 30.0, 0.0, 14, "sloop")
			stage.add_child(es)
			es.set_meta("no_sleep", true)
			es.global_transform = Transform3D(Basis(Vector3.UP, ship.global_rotation.y + PI * 0.5), at + Vector3(0, HullBuilder.FREEBOARD, 0))
			es._pos = Vector3(at.x, 0.0, at.z)
			es._heading = ship.global_rotation.y + PI * 0.5
			es.reset_physics_interpolation()
			es.set_physics_process(false)
			until = TK.wait_ticks(3)
		4:
			h0 = es.hull
			d0 = _dist()
			TK.act("gadget_fire")
			until = TK.wait_secs(1.0)
		5:
			check("a ship ahead: the line's out (%d)" % get_nodes_in_group("harpoons").size(), get_nodes_in_group("harpoons").size() == 1)
			check("...the harpoon bites: her hull hurt (%.0f -> %.0f)" % [h0, es.hull], es.hull < h0)
			check("...and she's harpooned", es.harpooned_by == ship)
			check("...a charge spent", p.gadgets.charges("harpoon") == GadgetData.tier_val("harpoon", "charges", 0) - 1)
			until = TK.wait_secs(3.0)
		6:
			check("she's reeled in toward the ship (%.1f -> %.1f m)" % [d0, _dist()], _dist() < d0 - 6.0)
			until = TK.wait_secs(GadgetData.tier_val("harpoon", "hold", 0) - 3.0)
		7:
			check("its hold over, the line's let go", get_nodes_in_group("harpoons").is_empty() and es.harpooned_by == null)
			return TK.done(fails)
	step += 1
	return false
