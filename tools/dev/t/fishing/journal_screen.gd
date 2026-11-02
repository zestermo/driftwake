extends SceneTree
## The fish journal screen (1.28): opens from GameMenu ("fish_journal", also on the action wheel); counts what's
## caught over every page; a caught fish's card shows times caught, the biggest and where; an uncaught one says so
## with a hint; a finished page reads DONE.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var gm
var scr
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


func card_text() -> String:
	var t := ""
	for l in scr._card.find_children("*", "Label", true, false):
		t += (l as Label).text + " | "
	return t


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var F = load("res://scripts/fishing/fishing.gd")
			for id in ["fish_parrotfish", "fish_lionfish", "fish_tarpon", "fish_jade_gar", "fish_sardine"]:
				F.record(p, id, p.global_position)
			gm = root.get_node("GameMenu")
			check("the action wheel has a Fish journal", load("res://scripts/game/action_wheel.gd")._entries.has("fish_journal"))
			gm.open("fish_journal")
			scr = gm._screens["fish_journal"]
			until = TK.wait_ticks(2)
			step = 1
		1:
			check("it's open", gm._current == "fish_journal" and scr.is_visible_in_tree())
			check("five caught of all of them (%s)" % scr._count.text, scr._count.text.begins_with("5 OF "))
			scr.pick("fish_tarpon")
			var t := card_text()
			check("a caught fish's card: times, biggest, where (%s)" % t, t.contains("CAUGHT 1") and t.contains("BIGGEST") and t.contains("FIRST CAUGHT"))
			scr.pick("fish_reef_emperor")
			t = card_text()
			check("an uncaught one: not caught yet, where it bites (%s)" % t, t.contains("Not caught yet") and t.contains("ATOLL"))
			var rows := ""
			for l in scr._rows.find_children("*", "Label", true, false):
				rows += (l as Label).text + " | "
			check("the jungle page reads DONE (%s)" % rows.left(200), rows.contains("JUNGLE  4/4  -  DONE"))
			gm.close()
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit(1 if fails else 0)
			step = 2
	return false
