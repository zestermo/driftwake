extends SceneTree
## 1.30 enemy personalities: rolled from the seed (the same twice), by kind (fodder mostly berserker/opportunist, a
## grunt without a blade's guard never a duelist or bulwark), riflemen none, a setup's own kept; the tells: its own
## shout on spotting you and its stance held while it circles.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var P
var g
var G
var step := 0
var until := 0
var fails := 0
var stance_seen := false


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [
		{"post": Vector3(0, 0, -5.0), "role": "sword", "seed": 11, "personality": "duelist"},
		{"post": Vector3(4, 0, -12.0), "role": "rifle", "seed": 12},
		{"post": Vector3(-4, 0, -12.0), "role": "sword", "seed": 13}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func share(kind: String, guarded: bool) -> Dictionary:
	var n := {}
	for s in range(600):
		var p: String = P.roll(s, kind, guarded)
		n[p] = int(n.get(p, 0)) + 1
	for k in n:
		n[k] = float(n[k]) / 600.0
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 3:
				return false
			P = load("res://scripts/enemies/personality.gd")
			G = load("res://scripts/enemies/pirate_grunt.gd")
			check("the same seed rolls the same", P.roll(77, "grunt", true) == P.roll(77, "grunt", true))
			var f := share("fodder", true)
			check("fodder mostly berserker or opportunist (%s)" % str(f), float(f.get("berserker", 0.0)) + float(f.get("opportunist", 0.0)) > 0.75)
			var u := share("grunt", false)
			check("no guard, never a duelist or bulwark", not u.has("duelist") and not u.has("bulwark"))
			var o := share("officer", true)
			check("an officer can be any of the four", o.size() == 4)
			g = stage.camp.grunts[0]
			check("a setup's personality is kept", g.personality == "duelist")
			check("a rifleman has none", stage.camp.grunts[1].personality == "")
			check("an unlevelled (Brinehollow) grunt stays plain", stage.camp.grunts[2].personality == "")
			check("its shouts take its colour", g._bark.modulate == P.COLOR["duelist"])
			stage.player.hurtbox.monitorable = false
			for x in stage.camp.grunts:
				x._cooldown = 99.0
			g.alert()
			until = TK.wait_ticks(2)
		1:
			check("its own shout on spotting you (%s)" % g._bark.text, g._bark.text in P.BARK_SPOT["duelist"] or not g._bark.visible)
			until = TK.wait_secs(4.0)
		2:
			for x in stage.camp.grunts:
				x._cooldown = 99.0
			if g.humanoid.current_action() == "fo_en_garde":
				stance_seen = true
			if not stance_seen and g._fight_t < 9.0:
				return false
			check("en garde held while it circles (%s, %s)" % [g.humanoid.current_action(), G.S.keys()[g.state]], stance_seen)
			return TK.done(fails)
	step += 1
	return false
