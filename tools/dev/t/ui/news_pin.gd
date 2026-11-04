extends SceneTree
## 1.30 notifications: important news pins as a card under the objective box ("+1 MORE" with two) and stays put until
## the log is opened; small news stacks bottom left and fades in a few seconds; everything is kept for the log's NEWS.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var j
var hud
var obj
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			j = root.get_node("Journal")
			j.reset()
			hud = stage.hud
			obj = hud._objective
			hud.pin_news("rival", "The Lantern Saints have anchored off the harbour", "Their captain wants a word.")
			until = TK.wait_ticks(5)
		1:
			check("a pinned card under the objective box", obj._pin.visible and obj._pin_title.text.begins_with("The Lantern Saints"))
			check("...saying what it is (%s)" % obj._pin_head.text, obj._pin_head.text.contains("RIVAL"))
			hud.pin_news("boss", "The Silverback falls!")
			hud.show_toast("+40 gold  -  arena purse")
			until = TK.wait_secs(2.0)
		2:
			check("two pinned: the newest shown, +1 MORE (%s)" % obj._pin_head.text, obj._pin_title.text == "The Silverback falls!" and obj._pin_head.text.contains("+1 MORE"))
			check("small news on the stack, not the card (%s)" % [hud.news_text()], hud.news_text() == ["+40 gold  -  arena purse"])
			until = TK.wait_secs(4.0)
		3:
			check("the stack fades out in a few seconds", hud.news_text().is_empty())
			check("...the card's still pinned", obj._pin.visible)
			j.open()
			until = TK.wait_ticks(3)
		4:
			j.close()
			until = TK.wait_ticks(5)
		5:
			check("opening the log unpins it", not obj._pin.visible and j.pinned().is_empty())
			check("everything kept in the news (%d)" % j.news.size(), j.news.size() == 3 and j.news.any(func(n): return n["kind"] == "rival"))
			return TK.done(fails)
	step += 1
	return false
