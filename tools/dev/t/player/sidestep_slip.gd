extends SceneTree
## Sidestep (Acrobatics' dodge style): slipping aside while a foe's blow is live next to you makes your next hit a
## sure crit (once); a sidestep with no blow coming does nothing of the sort.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass",
		"grunts": [{"post": Vector3(0, 0, -1.8), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			g = stage.camp.grunts[0]
			g.process_mode = Node.PROCESS_MODE_DISABLED
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			p.progression.owned["ac_dodge"] = true
			p.progression.versions["ac_dodge"] = 1
			p.progression._own("ac_sidestep")
			until = TK.wait_secs(0.4)
		1:
			TK.act("dodge")
			until = TK.wait_secs(0.5)
		2:
			check("no blow coming: nothing slipped", not p.power.buff("slipped"))
			g.hitbox.active = true   # (live, without striking: the slip reads that it's live)
			TK.act("dodge")
			until = TK.wait_ticks(4)
		3:
			g.hitbox.active = false
			check("a live blow slipped", p.power.buff("slipped"))
			var h = p.melee_hit(10.0)
			check("the next hit is a sure crit", h.has_meta("crit"))
			check("only the one", not p.power.buff("slipped"))
			return TK.done(fails)
	step += 1
	return false
