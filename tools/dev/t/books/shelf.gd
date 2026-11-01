extends SceneTree
## The bookshelf in the ship's cabin: empty at first, a spine for each book read (within its 1 s refresh), and F at it
## opens the collection screen counting what's been read.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var shelf
var B
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			B = load("res://scripts/books/books.gd")
			shelf = stage.ship.find_child("BookShelf", true, false)
			check("the cabin has a bookshelf", shelf != null)
			check("...empty to start", shelf.spine_count() == 0 and shelf.get_node("Spines").mesh == null)
			for id in ["book_feast", "manual_wind", "lore_deep_1"]:
				B.read(p, id)
			until = TK.wait_secs(1.3)
		1:
			check("a spine for each book read (%d)" % shelf.spine_count(), shelf.spine_count() == 3 and shelf.get_node("Spines").mesh != null)
			shelf.get_node("Use").interacted.emit(p)
			until = TK.wait_ticks(3)
		2:
			var gm = root.get_node("GameMenu")
			check("F at the shelf opens the collection", gm.is_open() and gm._current == "books")
			var scr = gm._screens["books"]
			check("...counting what's read (%s)" % scr._count.text, scr._count.text.begins_with("3 OF "))
			scr.pick("manual_wind")
			check("...a read book's card says what it taught", scr._card.get_child_count() >= 3)
			gm.close()
			return TK.done(fails)
	step += 1
	return false
