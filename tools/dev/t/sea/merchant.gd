extends SceneTree
## The wandering merchant ship: under sail on her round while the crew's far off; she heaves to and hails when the
## crew's ship comes near; her factor's stock (a fine weapon, rare gear, blueprints, parts, exotic ingredients) is
## rolled from her seed (the same seed, the same stock; another, another); a captain on her deck counts as aboard and
## rides her; the factor trades.
const TK := preload("res://tools/dev/test_kit.gd")
const Shops := preload("res://scripts/game/shops.gd")
var SeaStops
var Gadgets
var MerchantShip
var stage
var p
var ship
var m
var step := 0
var until := 0
var fails := 0
var start := Vector3.ZERO


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _ids(stock: Array) -> Array:
	return stock.map(func(e): return "%s:%s" % [e[0], e[1]] if e.size() > 2 else Shops.item_of(e).id)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			SeaStops = load("res://scripts/sea/sea_stops.gd")
			Gadgets = load("res://scripts/gadgets/gadgets.gd")
			MerchantShip = load("res://scripts/sea/merchant_ship.gd")
			p = stage.player
			ship = stage.ship
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			var at: Vector3 = ship.global_position + Vector3(400, 0, 0)
			m = SeaStops.build(stage, "merchant", Vector2(at.x, at.z), 12, 4242)
			m.set_meta("no_sleep", true)
			until = TK.wait_ticks(5)
		1:
			start = m.global_position
			until = TK.wait_secs(4.0)
		2:
			check("she sails her round while the crew's far off (%.1f m, %.1f m/s, mode %d, asleep %s)" % [m.global_position.distance_to(start), m.speed, m.mode, m.process_mode == 4],m.global_position.distance_to(start) > 3.0 and m.mode == m.M.SAIL)
			m.place(ship.global_position + Vector3(70, 0, 20), 0.0)
			until = TK.wait_secs(6.0)
		3:
			check("she heaves to when the crew's ship comes near (%.2f m/s)" % m.speed, m.mode == m.M.HOVE and m.speed < 0.6)
			var stock: Array = Shops.stock(m.shop_id)
			var ids := _ids(stock)
			print("   stock: %s" % [ids])
			check("her factor trades from this visit's stock", m.factor.shop_id == m.shop_id and Shops.extra.has(m.shop_id))
			check("...gadget blueprints and parts", ids.any(func(i): return str(i) in Gadgets.blueprint_ids()) and ids.any(func(i): return str(i) in Gadgets.part_ids()))
			check("...exotic ingredients", ids.any(func(i): return str(i) in MerchantShip.EXOTIC))
			check("...a fine weapon and rare gear", stock.any(func(e): return Shops.item_of(e).is_weapon() and int(Shops.item_of(e).rarity) >= 2) and stock.any(func(e): return e.size() > 2))
			var again = SeaStops.build(stage, "merchant", Vector2(9000, 9000), 12, 4242)
			check("the same seed rolls the same stock", _ids(Shops.stock(again.shop_id)) == ids)
			again.free()
			var other = SeaStops.build(stage, "merchant", Vector2(9000, 9000), 12, 777)
			check("another visit rolls another stock", _ids(Shops.stock(other.shop_id)) != ids)
			other.free()
			p.global_position = m.to_global(Vector3(1.0, 0.9, 2.0))
			p.reset_physics_interpolation()
			until = TK.wait_secs(4.0)
		4:
			check("a captain on her deck is aboard her (and rides her)", m.aboard(p.global_position) and p.is_on_floor())
			check("...she waits for them", m.mode == m.M.HOVE)
			return TK.done(fails)
	step += 1
	return false
