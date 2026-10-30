extends SceneTree
## The cities' hidden caches (1.27, CityCaches): the capital has 8 or more and the canal city 6 or more, every one a
## LootBag standing on something solid (a roof, a belfry floor, the maze's ground, a stage), and one already opened in
## the save isn't placed again.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var cap
var canal
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.collide_with_areas = false
	return root.world_3d.direct_space_state.intersect_ray(q)


func _solid(bags: Array) -> Array:
	var bad: Array = []
	for b in bags:
		var p: Vector3 = (b as Node3D).global_position
		var hit := _ray(p + Vector3.UP * 0.3, p + Vector3.DOWN * 0.8)
		if hit.is_empty():
			bad.append(str(b.name))
	return bad


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			# (one cache already opened in this save: it mustn't come back)
			root.get_node("GameManager").opened["capital_cache_theatre"] = true
			until = TK.wait_ticks(2)
		1:
			cap = w.build_capital(Vector3(900, 0, 900))
			canal = w.build_canal(Vector3(-900, 0, -900))
			until = TK.wait_ticks(4)
		2:
			var cb: Array = cap.city.find_children("Cache_*", "", true, false)
			var kb: Array = canal.city.find_children("Cache_*", "", true, false)
			check("the capital's caches (%d)" % cb.size(), cb.size() >= 8)
			check("the canal city's caches (%d)" % kb.size(), kb.size() >= 6)
			var bad: Array = _solid(cb) + _solid(kb)
			check("every cache stands on something solid (%s)" % [bad.slice(0, 6)], bad.is_empty())
			check("an opened one isn't placed again", cap.city.get_node_or_null("Cache_capital_cache_theatre") == null)
			return TK.done(fails)
	step += 1
	return false
