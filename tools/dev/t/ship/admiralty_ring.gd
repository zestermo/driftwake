extends SceneTree
## The Admiralty answers a big deed (docs/v1_23_plan.md, "Marines"): an island boss beaten (Admiralty.deed, the public
## hook the island arcs call too) puts a blockade at the island's mouth (two ships holding station and a boom between
## them, which crew fire breaks), and once the crew's ship is out at sea a ring of warships closes round her, sized by
## the crew's bounty tier. A late joiner gets the same ships from the spawner list.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var adm
var step := 0
var until := 0
var fails := 0
var answered := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _role(r: String) -> Array:
	return adm.get_children().filter(func(c): return c.get("role") == r)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var ES = load("res://scripts/ship/enemy_ship.gd")
	match step:
		0:
			p = stage.player
			ship = stage.ship
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			p.bounty = 25000
			# an island off her port side, the boss beaten on it
			var c: Vector3 = ship.global_position - ship.global_basis.x * 260.0
			ES.no_go = [[Vector2(c.x, c.z), 60.0]]
			var A = load("res://scripts/ship/admiralty.gd")
			adm = A.ensure(self)
			adm.deed_answered.connect(func(_a, _w): answered += 1)
			A.deed(self, c + Vector3(20, 0, 0), "boss")
			var block: Array = _role("block")
			check("the deed is answered (the hook's signal fires)", answered == 1)
			check("a blockade at the island's mouth: two ships holding station (%d)" % block.size(), block.size() == 2 and block.all(func(s): return s.state == ES.S.BLOCK))
			check("...on her side of the island", block.all(func(s): return s.global_position.distance_to(ship.global_position) < c.distance_to(ship.global_position)))
			check("...a boom across between them", get_nodes_in_group("booms").size() == 1)
			until = TK.wait_secs(2.5)
		1:
			var ring: Array = _role("ring")
			print("   ring of %d at %s m" % [ring.size(), ring.map(func(s): return int(s.global_position.distance_to(ship.global_position)))])
			check("out at sea: a ring closes round her, three for a Notorious crew (%d)" % ring.size(), ring.size() == 3)
			check("...all round her, coming for her", ring.all(func(s): return s.pursuing() and absf(s.global_position.distance_to(ship.global_position) - adm.RING_R) < 25.0))
			var gen: Array = adm.net_gen()
			check("...a late joiner gets them all (spawner list: %d ships, %d boom)" % [gen[0].size(), gen[1].size()], gen[0].size() == 5 and gen[1].size() == 1)
			# crew fire on the boom
			var boom = get_nodes_in_group("booms")[0]
			for i in range(5):
				var hd = load("res://scripts/combat/hit_data.gd").new()
				hd.damage = 30.0
				hd.siege = true
				boom.hurtbox.take_hit(hd, ship)
			until = TK.wait_secs(0.5)
		2:
			check("crew fire breaks the boom", get_nodes_in_group("booms").is_empty() and adm.booms.is_empty())
			ES.no_go = []
			return TK.done(fails)
	step += 1
	return false
