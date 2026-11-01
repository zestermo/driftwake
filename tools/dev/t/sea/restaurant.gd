extends SceneTree
## The floating restaurant: there's floor from the landing stage's pontoon up the ramp to the deck and into the hall;
## a captain there is aboard and stands; the chef's stock has dishes; resting heals; the chef teaches the Captain's
## Feast then the house bouillabaisse for gold. Some restaurants are under attack (raiders on the deck): beat them and
## the chef's favour teaches the bouillabaisse for nothing (a world flag).
const TK := preload("res://tools/dev/test_kit.gd")
const Shops := preload("res://scripts/game/shops.gd")
var SeaStops
var Food
var stage
var p
var r
var raided
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "water": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _seed_for(attacked: bool) -> int:
	var R = load("res://scripts/sea/floating_restaurant.gd")
	for s in range(1, 200):
		if R.new().setup(Vector3.ZERO, 12, s).attacked == attacked:
			return s
	return -1


func _floor_y(local: Vector3) -> float:
	var at: Vector3 = r.to_global(local)
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 3.0, 1)
	var hit: Dictionary = stage.get_world_3d().direct_space_state.intersect_ray(q)
	return INF if hit.is_empty() else r.to_local(hit["position"]).y


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			SeaStops = load("res://scripts/sea/sea_stops.gd")
			Food = load("res://scripts/items/food.gd")
			p = stage.player
			p.health_component.max_health = 9999.0
			p.health_component.current_health = 9999.0
			r = SeaStops.build(stage, "restaurant", Vector2(140, 0), 12, _seed_for(false))
			r.set_meta("no_sleep", true)
			until = TK.wait_ticks(10)
		1:
			var spots := {"the pontoon": Vector3(12.6, -1.5, 8.0), "the ramp": Vector3(11.9, -0.8, -2.5), "the deck": Vector3(-6.0, 0.0, 12.0),
				"the hall": Vector3(0.0, 0.0, 0.0)}
			for k in spots:
				var y := _floor_y(spots[k])
				check("there's floor on %s (%.2f, want %.2f)" % [k, y, spots[k].y], absf(y - float(spots[k].y)) < 0.35)
			check("the pontoon sits just above the water (%.2f m)" % (r.to_global(Vector3(12.6, -1.5, 8.0)).y), r.to_global(Vector3(12.6, -1.5, 8.0)).y > 0.3 and r.to_global(Vector3(12.6, -1.5, 8.0)).y < 1.2)
			p.global_position = r.to_global(Vector3(0.0, 0.5, 4.5))
			p.reset_physics_interpolation()
			until = TK.wait_secs(2.0)
		2:
			check("a captain in the hall is aboard and stands", r.aboard(p.global_position) and p.is_on_floor())
			var ids: Array = Shops.stock(r.shop_id).map(func(e): return str(e[0]))
			check("the chef sells the day's dishes (%s)" % [ids], ids.any(func(i): return Food.MEALS.has(i)) and r.chef.shop_id == r.shop_id)
			p.health_component.current_health = 100.0
			r._rest(p)
			check("a room's rest heals", p.health_component.current_health >= p.health_component.max_health - 0.5)
			var inv = p.inventory_component
			inv.add_item(load("res://scripts/loot/item_db.gd").get_item("gold"), 600)
			var g0: int = inv.count("gold")
			r._recipes(p)
			check("the chef teaches the Captain's Feast for 150 gold", Food.known(p.progression, "captains_feast") and inv.count("gold") == g0 - 150)
			r._recipes(p)
			check("...then the house bouillabaisse for 400", Food.known(p.progression, "tidewater_bouillabaisse") and inv.count("gold") == g0 - 550)
			p.progression.recipes.erase("tidewater_bouillabaisse")
			raided = SeaStops.build(stage, "restaurant", Vector2(-400, 600), 12, _seed_for(true))
			raided.set_meta("no_sleep", true)
			until = TK.wait_secs(4.0)
		3:
			var alive: int = raided.camp.alive_count() if raided.camp else 0
			check("an attacked restaurant has raiders on her deck (%d)" % alive, alive >= 3)
			for g in raided.camp.grunts:
				var gl: Vector3 = raided.to_local((g as Node3D).global_position)
				check("...standing on her deck (%.1f)" % gl.y, gl.y > -0.5 and gl.y < 1.5)
				(g as Node).health.take_damage(99999.0)
			until = TK.wait_secs(3.0)
		4:
			check("beating them earns the chef's favour (the world flag)", stage.get_node("/root/GameManager").world_flags.has(raided._flag))
			check("...and the house recipe for nothing", Food.known(p.progression, "tidewater_bouillabaisse"))
			return TK.done(fails)
	step += 1
	return false
