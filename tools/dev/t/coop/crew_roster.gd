extends SceneTree
## The crew (1.22): a captain aboard goes on the roster by their save's character id (seen today), seen again they're
## updated not doubled; the crew's name is "<Captain>'s Crew" until the Captain names it (trimmed, 28 at most); the
## crew rides in the world state a joining captain gets; it's saved with the host's world and loaded back.
const TK := preload("res://tools/dev/test_kit.gd")
const SAVE := "user://t_crew_roster.save"
var stage
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var net = root.get_node("Net")
	var gm = root.get_node("GameManager")
	var p = stage.player
	gm.crew = {"name": "", "members": {}}
	net.crew_member({"name": "Zilk", "char": "aaa"})
	net.crew_member({"name": "Nessa", "char": "bbb"})
	net.crew_member({"name": "Nessa the Bold", "char": "bbb"})
	var m: Dictionary = gm.crew["members"]
	check("two captains on the roster, by character", m.size() == 2 and m.has("aaa") and m.has("bbb"))
	check("...seen again: renamed, not doubled (%s)" % m["bbb"]["name"], m["bbb"]["name"] == "Nessa the Bold")
	check("...seen today", int(m["aaa"]["seen"]) == int(root.get_node("Weather").day()))
	check("unnamed: the Captain's crew (%s)" % net.crew_name(), net.crew_name().ends_with("'s Crew"))
	net.crew_rename("  The Salt Hounds of the Long Grey Northern Sea  ")
	check("named, trimmed to 28 (%s)" % net.crew_name(), net.crew_name() == "The Salt Hounds of the Long")
	net.crew_rename("The Salt Hounds")
	check("the crew rides in the world state", (net._world_state()["crew"] as Dictionary).get("name", "") == "The Salt Hounds")
	var SG = load("res://scripts/game/save_game.gd")
	SG.use_test_file(SAVE)
	SG.save(p)
	gm.crew = {"name": "", "members": {}}
	check("load", SG.load_into(p))
	check("saved with the world and back (%s, %d)" % [gm.crew.get("name", ""), (gm.crew.get("members", {}) as Dictionary).size()],
		gm.crew.get("name", "") == "The Salt Hounds" and (gm.crew["members"] as Dictionary).size() == 2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	return TK.done(fails)
