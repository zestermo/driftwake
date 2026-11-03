extends SceneTree
## 1.30 the Captain's Log (J): NEXT numbers what you follow 1, the other leads after it with owner chips, then the chain
## (always on); the map carries the same numbers; T on the chain follows it (the box shows the chain), QUESTS lists
## every live quest with its owner chip, a story line SHARED; NEWS keeps what happened.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var j
var scr
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


func key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	j._input(ev)


func q(id: String, title: String, src := "npc") -> Dictionary:
	return {"id": id, "title": title, "giver": "Kai", "isle": "Test", "pos": p.global_position + Vector3(0, 0, -40), "src": src,
		"steps": [{"do": "reach", "goal": "Go and look at " + title}, {"do": "turnin", "goal": "Tell Kai"}], "reward": {"gold": 5}}


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			j = root.get_node("Journal")
			j.reset()
			var w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			root.get_node("GameManager").chain_at = -1
			root.get_node("Dialogue").set_flag("log_pose")
			p.progression.level = 6
			for e in [q("t_a", "The reef"), q("t_b", "The cache")]:
				j.register(e, null)
				j.take(e["id"])
			j.track("t_a")
			until = TK.wait_ticks(10)
		1:
			j.open()
			scr = j.screen
			until = TK.wait_ticks(5)
		2:
			check("the log opens on NEXT", scr.tab == "next")
			var kinds: Array = scr.rows.map(func(r): return r["kind"])
			check("1 followed, 2 a lead, 3 the chain (%s)" % [kinds], kinds == ["now", "lead", "chain"] and scr.rows.map(func(r): return r["n"]) == [1, 2, 3])
			check("...1 is the followed quest", scr.rows[0]["id"] == "t_a" and scr.rows[1]["id"] == "t_b")
			check("...the lead's owner chip (%s)" % scr.rows[1].get("chip", ""), scr.rows[1].get("chip", "") == "YOURS")
			check("...the chain row sails on (%s)" % scr.rows[2]["goal"], str(scr.rows[2]["goal"]).begins_with("Sail to"))
			check("the map carries the same rows", scr._map != null and scr._map.marks.size() == 3)
			key(KEY_S)
			key(KEY_S)
			key(KEY_T)
			until = TK.wait_ticks(5)
		3:
			check("T on the chain follows it", j.tracked == "")
			check("...NEXT's 1 is the chain now (%s)" % [scr.rows.map(func(r): return r["kind"])], scr.rows[0]["kind"] == "now" and scr.rows[0]["id"] == "")
			j.register(q("t_line", "A royal errand", "line").merged({"steps": [{"goal": "Wait", "until": ["flag", "never"], "at": []}, {"goal": "Tell", "until": ["flag", "never"], "at": []}]}, true), null)
			j.take("t_line", 0)
			key(KEY_D)
			until = TK.wait_ticks(5)
		4:
			check("D: QUESTS lists all three", scr.tab == "quests" and scr.rows.size() == 3)
			var line: Dictionary = j.entries["t_line"]
			check("...a story line is SHARED, yours is YOURS", j.owner_chip(line) == "SHARED" and j.owner_chip(j.entries["t_a"]) == "YOURS")
			key(KEY_D)
			until = TK.wait_ticks(3)
		5:
			check("D: NEWS keeps the new quests (%d)" % j.news.size(), scr.tab == "news" and j.news.filter(func(n): return n["kind"] == "quest").size() == 3)
			j.close()
			return TK.done(fails)
	step += 1
	return false
