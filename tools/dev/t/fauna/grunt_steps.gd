extends SceneTree
## Pirates' footsteps (2026-11-06): grunts running in are heard (Footsteps.npc_step), and a crowd stays
## inside the shared cap (NPC_STEP_CAP in any NPC_STEP_WINDOW ticks).
const TK := preload("res://tools/dev/test_kit.gd")
const FS := preload("res://scripts/game/footsteps.gd")
var stage
var step := 0
var until := 0
var fails := 0
var t0 := 0
var worst := 0
var _win := 0
var _seen := 0


func _initialize() -> void:
	TK.seed_of(self)
	var gs: Array = []
	for i in range(5):
		gs.append({"post": Vector3(-6.0 + 3.0 * i, 0, -14.0), "role": "sword", "seed": 70 + i})
	stage = TK.stage(self, {"hud": false, "grunts": gs})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if step == 1:
		var f := Engine.get_physics_frames()
		if f - _win >= FS.NPC_STEP_WINDOW:
			_win = f
			_seen = FS.npc_steps
		worst = maxi(worst, FS.npc_steps - _seen)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 5:
				return false
			stage.player.hurtbox.monitorable = false
			for g in stage.camp.grunts:
				g.alert()
			t0 = FS.npc_steps
			until = TK.wait_secs(4.0)
		1:
			check("grunts running in are heard (%d steps)" % (FS.npc_steps - t0), FS.npc_steps - t0 > 0)
			check("a crowd stays in the cap (worst %d in a window)" % worst, worst <= FS.NPC_STEP_CAP)
			return TK.done(fails)
	step += 1
	return false
