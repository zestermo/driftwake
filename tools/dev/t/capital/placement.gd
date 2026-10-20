extends SceneTree
## The royal capital's place in the chain (docs/capital_plan.md): on every path of several seeds the crew reaches it
## after exactly two islands (Brinehollow, island, island, the capital), it's the only capital, a city on layer 3,
## its harbour facing the islands it's sailed to from; its name is one of the three, stable for a seed and rolled
## apart from the chain's stream (Chain.capital_name); the log pose tells it as the royal capital.
const TK := preload("res://tools/dev/test_kit.gd")
const SEEDS := [1, 77, 4242, 90210, 31337, 2024, 555, 8086]
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


## Every path from Brinehollow's sea to the capital, as the node ids before it.
func _paths(c, id: int, before: Array, out: Array) -> void:
	for nid in c.next_of(id):
		var n: Dictionary = c.node(nid)
		if n.get("capital", false):
			out.append(before.duplicate())
		elif before.size() < 6:
			_paths(c, nid, before + [nid], out)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var CH = load("res://scripts/world/chain.gd")
	var bad_paths: Array = []
	var bad_nodes: Array = []
	var bad_face: Array = []
	var bad_name: Array = []
	var forks := 0
	for s in SEEDS:
		var c = CH.make(s, Vector2(150, 150), Vector2(0, -1))
		var caps: Array = c.nodes.filter(func(n): return n.get("capital", false))
		if caps.size() != 1 or int(caps[0]["layer"]) != 3 or str(caps[0]["role"]) != "city":
			bad_nodes.append(s)
			continue
		var cap: Dictionary = caps[0]
		var paths: Array = []
		_paths(c, -1, [], paths)
		if c.start_next.size() > 1:
			forks += 1
		if paths.size() != c.start_next.size() or paths.any(func(p): return p.size() != 2 or p.any(func(i): return c.node(i).get("capital", false))):
			bad_paths.append("%d: %s" % [s, paths])
		var from := Vector2.ZERO
		var befores: Array = c.nodes.filter(func(n): return int(n["layer"]) == 2)
		for b in befores:
			from += (b["pos"] as Vector2) / befores.size()
		var face: Vector2 = cap.get("face", Vector2.ZERO)
		if absf(face.length() - 1.0) > 0.01 or face.dot((from - (cap["pos"] as Vector2)).normalized()) < 0.999:
			bad_face.append(s)
		var again = CH.make(s, Vector2(150, 150), Vector2(0, -1))
		var others: Array = c.nodes.filter(func(n): return not n.get("capital", false)).map(func(n): return n["name"])
		if not CH.CAPITAL_NAMES.has(cap["name"]) or again.node(cap["id"])["name"] != cap["name"] or CH.capital_name(s) != cap["name"] \
				or others.any(func(nm): return CH.CAPITAL_NAMES.has(nm)):
			bad_name.append(s)
		if not CH.describe(cap).begins_with("The royal capital"):
			bad_name.append("%d describe" % s)
	check("one capital a chain, a city on layer 3 %s" % [bad_nodes], bad_nodes.is_empty())
	check("every path reaches the capital after exactly two islands %s" % [bad_paths], bad_paths.is_empty())
	check("some of the seeds fork at the start (%d)" % forks, forks >= 2)
	check("the capital's harbour faces the islands before it %s" % [bad_face], bad_face.is_empty())
	check("the capital's name is one of the three, stable for its seed, no other island's %s" % [bad_name], bad_name.is_empty())
	var names := {}
	for s in range(40):
		names[CH.capital_name(s * 7919)] = true
	check("all three names come up over seeds (%s)" % [names.keys()], names.size() == 3)
	return TK.done(fails)
