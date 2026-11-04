extends SceneTree
## Where rival crews turn up (RivalWatch, GameManager's): not on the first island, the first meeting on the first chain
## island past it with the Mudlark Brigade; never the capital, the canal city or the stronghold; after a meeting none until
## MIN_GAP islands have passed, then rolled (seeded: the same island decides the same), crews not met yet first and never
## the same twice running. 1.30: every node is a real chain node (Chain.make), not a hand-made role.
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


## (1.30) Real chain nodes (Chain.make): the regular islands of chains seeded 1.., `n` of them, a fresh seed per call.
var _regular: Array = []
var _regular_seed := 1


func node(_layer: int, s: int, _role := "") -> Dictionary:
	while _regular.is_empty():
		var c = load("res://scripts/world/chain.gd").make(_regular_seed, Vector2.ZERO, Vector2(0, -1))
		_regular_seed += 1
		_regular = c.nodes.filter(func(n): return n["role"] == "regular" and int(n["layer"]) >= 2)
	var n: Dictionary = _regular.pop_back().duplicate()
	n["seed"] = s
	return n


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var gm := root.get_node("GameManager")
	var w = gm.rival_watch
	gm.rivals.clear()
	var pl: Dictionary = w.plan()
	var chain = load("res://scripts/world/chain.gd").make(4242, Vector2.ZERO, Vector2(0, -1))
	# (before the first meeting any chain island past Brinehollow would do: the cities and the stronghold must say no)
	var capital: Dictionary = chain.nodes.filter(func(n): return n.get("capital", false))[0]
	var canal: Dictionary = chain.nodes.filter(func(n): return n.get("canal", false))[0]
	w.decide(capital, int(capital["id"]))
	check("never at the capital (%s, role %s)" % [capital["name"], capital["role"]], int(pl["pending"]) == -1)
	w.decide(canal, int(canal["id"]))
	check("never at the canal city (%s)" % canal["name"], int(pl["pending"]) == -1)
	w.decide(chain.stronghold, int(chain.stronghold["id"]))
	check("never at the stronghold (%s)" % chain.stronghold["name"], int(pl["pending"]) == -1)
	var first: Dictionary = chain.nodes.filter(func(n): return int(n["layer"]) == 1)[0]
	w.decide(first, int(first["id"]))
	check("the first meeting: the first chain island, the Mudlark Brigade (%s)" % pl["crew"], int(pl["pending"]) == int(first["id"]) and pl["crew"] == "mudlark_brigade")
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
		came.size() >= 4 and came.size() <= 15 and came.all(func(c): return int(c[1]) >= w.MIN_GAP))
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
	# an infamous crew: named Admiralty hunters wait at harbours, the officers in turn
	stage.player.bounty = 70000
	var officers := []
	var crews_kept := 0
	var both := 0
	for i in range(20):
		w.decide(node(2, 700 + i), 100 + i)
		if int(pl.get("officer", -1)) >= 0:
			officers.append(str(pl["officer_id"]))
			pl["officers_met"] = int(pl.get("officers_met", 0)) + 1
		if int(pl["pending"]) >= 0:
			crews_kept += 1
			both += 1 if int(pl.get("officer", -1)) >= 0 else 0
	# (1.26: the crew comes first; an officer only takes an island no crew came to)
	check("...a rival crew still comes to an infamous crew's islands, never pushed aside by an officer (%d crews, %d both)" % [crews_kept, both],
		crews_kept >= 1 and both == 0)
	check("an infamous crew: a named hunter waits at some harbours (%d of 20: %s)" % [officers.size(), str(officers.slice(0, 3))],
		officers.size() >= 5 and officers.size() <= 15 and officers.slice(0, 3).size() == {officers[0]: 1, officers[1]: 1, officers[2]: 1}.size())
	stage.player.bounty = 0
	gm.rivals.clear()
	return TK.done(fails)
