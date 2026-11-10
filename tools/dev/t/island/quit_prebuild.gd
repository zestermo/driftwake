extends SceneTree
## Quitting while a crew is still being built ahead on a worker exits cleanly. A worker mid-body can be waiting on
## the main thread to flush the rendering server, so the engine's own shutdown hung on the pool task (the runner's
## 150 s stall: t/island/volcanic_town, crowd_size and t/quests/island_tracker, 2026-11-10). GameManager's _exit_tree
## now drains them (Humanoid.clear_prebuilt / wait_task). This test passes by ending: a hang is the runner's stall.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	# (by path: Humanoid and CharacterLook reach the autoloads)
	var H = load("res://scripts/npc/humanoid.gd")
	var L = load("res://scripts/npc/character_look.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var looks: Array = []
	for i in 10:
		looks.append(L.random_look(rng))
	H.prebuild(looks)
	# (a body on the main thread in the same frame, as an island built in one call does: the workers hold off for it)
	var mine = H.make(L.random_look(rng))
	check("a body built on the main thread while the crew builds", mine != null and mine.get_child_count() > 0)
	mine.free()
	check("the crew is still building as the test ends", not H.prebuilt_for(looks))
	return TK.done(fails)
