extends SceneTree
## Where rival crews turn up (RivalWatch, GameManager's): not on the first island, the first meeting on the first chain
## island past it with the Mudlark Brigade; never the capital; after a meeting none until MIN_GAP islands have passed,
## then rolled (seeded: the same island decides the same), crews not met yet first and never the same twice running.
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


func node(layer: int, s: int, role := "") -> Dictionary:
	return {"layer": layer, "seed": s, "role": role}


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var gm := root.get_node("GameManager")
	var w = gm.rival_watch
	gm.rivals.clear()
	var pl: Dictionary = w.plan()
	w.decide(node(0, 11), 0)
	check("not on the first island (layer 0)", int(pl["pending"]) == -1)
	w.decide(node(1, 12, "capital"), 1)
	check("never at the capital", int(pl["pending"]) == -1)
	w.decide(node(1, 13), 2)
	check("the first meeting: the first chain island past it, the Mudlark Brigade (%s)" % pl["crew"], int(pl["pending"]) == 2 and pl["crew"] == "mudlark_brigade")
	# (the meeting happened: RivalWatch's trigger sets these)
	pl["pending"] = -1
	pl["since"] = 0
	pl["met_first"] = true
	pl["last"] = "mudlark_brigade"
	gm.rivals["mudlark_brigade"] = {"met": 1, "won": 1, "lost": 0}
	var came := []
	for i in range(30):
		w.decide(node(2, 100 + i), 10 + i)
		if int(pl["pending"]) >= 0:
			came.append([i, int(pl["since"]), str(pl["crew"])])
			pl["pending"] = -1
			pl["since"] = 0
			pl["last"] = str(pl["crew"])
			gm.rivals[str(pl["crew"])] = {"met": 1, "won": 0, "lost": 0}
	check("then rolled: some islands of 30 (%d), never before %d have passed" % [came.size(), w.MIN_GAP],
		came.size() >= 3 and came.size() <= 10 and came.all(func(c): return int(c[1]) >= w.MIN_GAP))
	var crews := came.map(func(c): return c[2])
	check("...the crews not met yet first (%s)" % str(crews.slice(0, 3)), crews.size() >= 3 and not "mudlark_brigade" in crews.slice(0, 3)
		and crews.slice(0, 3).size() == {crews[0]: 1, crews[1]: 1, crews[2]: 1}.size())
	var twice := false
	for i in range(1, crews.size()):
		twice = twice or crews[i] == crews[i - 1]
	check("...never the same crew twice running", not twice)
	# seeded: the same island decides the same
	pl["since"] = 5
	w.decide(node(2, 4242), 50)
	var a := int(pl["pending"])
	pl["since"] = 5
	w.decide(node(2, 4242), 50)
	check("the same island decides the same", int(pl["pending"]) == a)
	# a notorious captain: bounty hunters on some islands no crew comes to
	stage.player.bounty = 25000
	var hunted := 0
	for i in range(30):
		pl["since"] = 0
		w.decide(node(2, 500 + i), 60 + i)
		if int(pl.get("hunters", -1)) >= 0:
			hunted += 1
	check("a notorious captain: bounty hunters wait on some islands no crew comes to (%d of 30)" % hunted, hunted >= 5 and hunted <= 18)
	stage.player.bounty = 0
	pl["since"] = 0
	w.decide(node(2, 4242), 90)
	check("...none for a captain who isn't", int(pl.get("hunters", -1)) == -1)
	gm.rivals.clear()
	return TK.done(fails)
