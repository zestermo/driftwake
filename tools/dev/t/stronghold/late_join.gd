extends SceneTree
## A captain who joins a stronghold raid late (StrongholdReinforce.net_set_gen): the host is on wave 4, so the guest gets
## that wave only, the three before it aren't replayed; then the next wave, called as the host musters it, comes whole.
const TK := preload("res://tools/dev/test_kit.gd")
const STUB := "extends Node3D\nvar node := {\"level\": 5, \"seed\": 1}\n"
var stage
var camp
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
	match step:
		0:
			var sc := GDScript.new()
			sc.source_code = STUB
			sc.reload()
			var isl := Node3D.new()
			isl.set_script(sc)
			root.add_child(isl)
			camp = load("res://scripts/island/stronghold_reinforce.gd").new().setup(isl, "ward", "door", Vector2(0, 0), Vector2(0, 1), 0)
			isl.add_child(camp)
			until = TK.wait_ticks(2)
		1:
			camp.net_set_gen(4)
			check("a late joiner is on the host's wave (%d)" % camp.gen, camp.gen == 4)
			check("...with that wave's %d men, not four waves of them (%d)" % [camp.size(), camp.grunts.size()], camp.grunts.size() == camp.size())
			check("...all from wave 4 (%s)" % [camp.grunts.map(func(g): return g.name)], camp.grunts.all(func(g): return str(g.name).begins_with("G4_")))
			camp.net_set_gen(5)
			check("the next wave comes whole when the host calls it (%d men)" % camp.grunts.size(), camp.gen == 5 and camp.grunts.size() == camp.size() * 2)
			return TK.done(fails)
	step += 1
	return false
