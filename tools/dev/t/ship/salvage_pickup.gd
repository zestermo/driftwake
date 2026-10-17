extends SceneTree
## Salvage at sea: a sunk brig leaves her haul floating (six pieces, more than a gunboat's three), bobbing on
## the swell; sailing the ship through a piece with the captain aboard takes it, so does swimming up to one; a
## full bag leaves it afloat. The loot-table hook rolls the same for the same seed, and a rich roll finds more
## iron and copper.
const TK := preload("res://tools/dev/test_kit.gd")
var SAL
var stage
var p
var ship
var es
var piece
var step := 0
var until := 0
var fails := 0
var y0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func pieces() -> Array:
	return get_nodes_in_group("salvage")


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			SAL = load("res://scripts/ship/salvage.gd")
			p = stage.player
			ship = stage.ship
			var a := RandomNumberGenerator.new()
			a.seed = 77
			var b := RandomNumberGenerator.new()
			b.seed = 77
			check("the loot-table hook rolls the same for the same seed", SAL.roll(a, 3, 0.3) == SAL.roll(b, 3, 0.3) and not SAL.roll(a, 1).is_empty())
			var poor := {}
			var rich := {}
			for i in range(300):
				for e in SAL.roll(a, 1, 0.0):
					poor[e[0]] = int(poor.get(e[0], 0)) + 1
				for e in SAL.roll(a, 1, 1.0):
					rich[e[0]] = int(rich.get(e[0], 0)) + 1
			print("   poor %s, rich %s" % [poor, rich])
			check("a rich haul finds more iron and copper", int(rich.get("iron", 0)) > int(poor.get("iron", 0)) and int(rich.get("copper", 0)) > int(poor.get("copper", 0)))
			es = load("res://scripts/ship/enemy_ship.gd").new().setup(Vector3(95, 0, 30), 20.0, 0.0, 99, "brig")
			es.position = Vector3(95, 0, 30)
			stage.add_child(es)
			until = TK.wait_ticks(10)
		1:
			es._start_sink()
			until = TK.wait_secs(2.5)
		2:
			var near := pieces().filter(func(s): return s.global_position.distance_to(Vector3(95, 0, 30)) < 14.0)
			check("a sunk brig leaves six pieces of salvage afloat round her (%d)" % near.size(), near.size() == 6)
			check("...more than a gunboat's haul", SAL.HAULS["brig"][0] > SAL.HAULS["gunboat"][0])
			piece = near[0] if not near.is_empty() else null
			y0 = piece.global_position.y if piece else 0.0
			check("...floating at the waves' height", piece != null and absf(piece.global_position.y - (root.get_node("Ocean").get_wave_height(piece.global_position) - 0.12)) < 0.05)
			until = TK.wait_secs(1.0)
		3:
			check("...bobbing with the swell", piece != null and absf(piece.global_position.y - y0) > 0.001)
			for s in pieces():
				s.queue_free()
			# sail through one: the captain aboard, a piece under her bow
			p.global_position = ship.global_transform * Vector3(0, 0.72, 0)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			until = TK.wait_ticks(20)
		4:
			piece = SAL.new()
			piece.item_id = "timber"
			piece.qty = 3
			stage.add_child(piece)
			piece.global_position = ship.global_transform * Vector3(1.0, 0, -6.0)
			until = TK.wait_ticks(12)
		5:
			check("sailing through it from aboard takes it (+3 timber)", not is_instance_valid(piece) and p.inventory_component.count("timber") == 3)
			# swim up to one
			p.global_position = Vector3(70, 0.5, -20)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.5)
		6:
			piece = SAL.new()
			piece.item_id = "copper"
			piece.qty = 1
			stage.add_child(piece)
			piece.global_position = Vector3(p.global_position.x + 0.8, 0.0, p.global_position.z)
			until = TK.wait_ticks(12)
		7:
			check("swimming up to one takes it (+1 copper; swimming %s)" % p.is_swimming(), not is_instance_valid(piece) and p.inventory_component.count("copper") == 1)
			# a full bag: it stays afloat
			var inv = p.inventory_component
			inv.max_slots = inv.used_slots()
			piece = SAL.new()
			piece.item_id = "iron"
			piece.qty = 2
			stage.add_child(piece)
			piece.global_position = Vector3(p.global_position.x + 0.8, 0.0, p.global_position.z)
			until = TK.wait_ticks(12)
		8:
			check("a full bag leaves it afloat", is_instance_valid(piece) and p.inventory_component.count("iron") == 0)
			return TK.done(fails)
	step += 1
	return false
