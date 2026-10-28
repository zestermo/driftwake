extends SceneTree
## Every instrument kind is a whole instrument (an item with its icon, a model, carried on the back, a playing action),
## and every tune has a stem for every kind, all of one tune the same length (one band off one clock).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	for k in Instruments.KINDS:
		var it: ItemData = ItemDB.get_item(Instruments.item_id(k))
		check("%s: an item with an icon, sold by Corin" % k, it != null and Instruments.kind_of(it) == k and it.icon != null
			and Instruments.stock([k])[0] in load("res://scripts/game/shops.gd").SHOPS["corin"]["stock"])
		check("%s: a model, carried on the back, a playing action" % k, Instruments.mesh(k).get_surface_count() > 0
			and stage.player.jam.BACK.has(k) and ActionSpecs.SPECS.has("music_" + k))
	for t in range(Instruments.TUNES.size()):
		var lens: Array = []
		for k in Instruments.KINDS:
			var path := Instruments.tune_path(t, k)
			lens.append(snappedf((load(path) as AudioStream).get_length(), 0.01) if ResourceLoader.exists(path) else -1.0)
		var same: bool = lens.min() > 0.0 and lens.max() - lens.min() < 0.005
		check("%s: a stem for every kind, all one length %s" % [Instruments.TUNES[t][0], str(lens)], same)
	return TK.done(fails)
