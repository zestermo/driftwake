extends SceneTree
## A dungeon far from every captain doesn't fall asleep while one of its nests is still hatching a bug a frame (as on a
## chain island being built): asleep mid-way, its last spots stayed empty on that machine, and a co-op guest was
## missing bugs the host had (nettest's "all host enemies exist here": Dungeon0/Enemies/Bugs/B3_0, B4_0).
const TK := preload("res://tools/dev/test_kit.gd")
const SPOTS := 4
var stage
var d
var nest
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _bugs() -> int:
	return nest.get_children().filter(func(c): return c.name.begins_with("B")).size()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			# (by path: these classes touch autoloads)
			d = load("res://scripts/island/dungeon.gd").new()
			d.name = "Dungeon0"
			d.info = {"radius": 20.0}
			stage.add_child(d)
			d.global_position = stage.player.global_position + Vector3(400, 0, 0)
			# (only the sleep check under test: _process wants a real cave's mouth and title)
			d.set_process(false)
			var en := Node3D.new()
			en.name = "Enemies"
			d.add_child(en)
			d.enemies = en
			nest = load("res://scripts/enemies/scuttlebug_nest.gd").new()
			nest.name = "Bugs"
			nest.start_empty = true
			for i in range(SPOTS):
				nest.add_spot(Vector3(i * 2.0, 0.5, 0.0))
			en.add_child(nest)
			# as on a building chain island: a bug a frame
			nest._hatching = true
			d._sleep_check()
			check("a far dungeon stays awake while its nest is hatching", en.process_mode == Node.PROCESS_MODE_INHERIT and d._awake)
			until = TK.wait_ticks(SPOTS + 6)
		1:
			d._sleep_check()
			check("the nest hatched every spot (%d of %d)" % [_bugs(), SPOTS], _bugs() == SPOTS)
			check("names match the host's (B0_0..B%d_0)" % (SPOTS - 1), nest.get_node_or_null("B%d_0" % (SPOTS - 1)) != null)
			check("then, hatching done, the far dungeon sleeps", not nest._hatching and d.enemies.process_mode == Node.PROCESS_MODE_DISABLED)
			return TK.done(fails)
	step += 1
	return false
