extends SceneTree
## The capital by night (1.27, CapitalCrowd): at noon the whole crowd is out and the watch isn't; at one in the morning
## about a quarter of the townsfolk are still about, and the night watch walks the main lanes with their lanterns lit.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
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


## [townsfolk out, of how many, watchmen out, lanterns lit].
func census() -> Array:
	var c = isl.crowd
	# (the share at the hour now: the crowd ticks every 0.1 s, and only while a camera is near)
	c.share = c.out_share(root.get_node("Weather").hour())
	var folk := 0
	var all := 0
	var watch := 0
	for i in range(c.walkers.size()):
		if c.walkers[i].get("watch", false):
			watch += 1 if c.is_out(i) else 0
		else:
			all += 1
			folk += 1 if c.is_out(i) else 0
	var lit := 0
	# (where each lantern goes: the headless renderer keeps no MultiMesh transforms to read back)
	var t := float(root.get_node("Ocean").clock())
	for i in range(c.walkers.size()):
		if c.walkers[i].get("watch", false) and c.lantern_pos(i, c.place_of(i, t)) != c.HIDDEN:
			lit += 1
	return [folk, all, watch, lit]


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var wx = root.get_node("Weather")
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_capital(Vector3(900, 0, 900))
			wx.set_world_time(wx.time_at(12.0))
			# (the crowd wakes for a camera nearby: the stage's is on the captain, so the captain goes to the plaza)
			stage.player.global_position = isl.city_global(Vector2(0, 10), 6.0)
			stage.player.reset_physics_interpolation()
			until = TK.wait_secs(1.0)
		2:
			var c := census()
			check("noon: the whole crowd out (%d of %d), no watch (%d, %d lanterns)" % [c[0], c[1], c[2], c[3]], c[0] == c[1] and c[2] == 0 and c[3] == 0)
			wx.set_world_time(wx.time_at(1.0, 2))
			until = TK.wait_secs(1.0)
		3:
			var c := census()
			check("one in the morning: a quarter of the crowd about (%d of %d)" % [c[0], c[1]], c[0] > 0 and float(c[0]) / c[1] > 0.12 and float(c[0]) / c[1] < 0.4)
			check("...the night watch walking (%d) with their lanterns lit (%d)" % [c[2], c[3]], c[2] >= 4 and c[3] == c[2])
			return TK.done(fails)
	step += 1
	return false
