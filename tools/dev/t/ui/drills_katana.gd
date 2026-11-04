extends SceneTree
## 1.30 (playtest 2026-11-02 row 11): Vey's drills can be finished with a katana: its heavy is the iai draw (state
## "Iai", not "HeavyAttack"), and that ticks the drills' lunge.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var d
var step := 0
var until := 0
var fails := 0
var seen := {}


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": true, "dummy": true, "weapon": "katana"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	if p:
		seen[p.current_state_name()] = true
	var story = root.get_node("Story")
	match step:
		0:
			p = stage.player
			story.step = "vey_drills"
			story.changed.emit()
			until = TK.wait_ticks(3)
		1:
			var ds := get_nodes_in_group("drills")
			d = ds[0] if not ds.is_empty() else null
			check("Vey's checklist shows with a katana in hand (%s)" % p.style(), d != null and p.style() == "katana")
			if d == null:
				return TK.done(fails)
			TK.press("heavy_attack")
			until = TK.wait_secs(0.3)
		2:
			TK.release("heavy_attack")
			until = TK.wait_secs(1.5)
		3:
			check("the katana's heavy is the iai draw (%s)" % [seen.keys()], seen.has("Iai") and not seen.has("HeavyAttack"))
			check("...and it ticks the lunge", d.done.has("heavy"))
			story.step = "done"
			return TK.done(fails)
	step += 1
	return false
