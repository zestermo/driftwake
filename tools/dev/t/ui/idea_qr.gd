extends SceneTree
## The pause menu's Suggest an Idea opens the idea screen, whose link carries the project version and the whole
## seconds played and whose QR is that link; Esc goes back to the pause menu.
const TK := preload("res://tools/dev/test_kit.gd")
const QR := preload("res://scripts/ui/qr_code.gd")
var stage
var gm
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self)


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			gm = root.get_node("GameMenu")
			root.get_node("GameManager").play_time = 7384.6
			gm.open("pause")
			var entry: Button = null
			for b in gm._screens["pause"].find_children("*", "Button", true, false):
				if b.text == "Suggest an Idea":
					entry = b
			check("pause menu has Suggest an Idea", entry != null)
			entry.pressed.emit()
			until = TK.wait_ticks(4)
		1:
			check("it opens the idea screen", gm._current == "idea" and gm._idea.visible)
			var v := str(ProjectSettings.get_setting("application/config/version"))
			var want := "driftwake://idea?v=%s&t=7384" % v
			check("link is %s (got %s)" % [want, gm._idea._link.text], gm._idea._link.text == want)
			var tex: Texture2D = gm._idea._qr.texture
			var img := QR.image(QR.encode(want))
			check("QR shown is the link's", tex != null and tex.get_image().get_data() == img.get_data())
			check("QR drawn %d px per module" % gm._idea.MODULE_PX, gm._idea._qr.custom_minimum_size == Vector2(img.get_size() * gm._idea.MODULE_PX))
			TK.act("pause")
			until = TK.wait_ticks(4)
		2:
			check("Esc goes back to pause", gm._current == "pause")
			gm.close()
			return TK.done(fails)
	step += 1
	return false
