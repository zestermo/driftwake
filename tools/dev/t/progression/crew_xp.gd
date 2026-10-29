extends SceneTree
## XP in co-op (1.26, docs/v1_26_plan.md "XP in co-op"): a boss's XP reaches every captain wherever they are
## (Net.award_xp with reach INF; each machine's _all_xp), an ordinary kill only those within XP_RANGE; and a quest
## turned in pays each captain QuestRewards.XP_SHARE of their next level, shown in the reward text.
const TK := preload("res://tools/dev/test_kit.gd")
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var net = root.get_node("Net")
	match step:
		0:
			var far: Vector3 = p.global_position + Vector3(600, 0, 0)
			var x0: int = p.progression.xp
			net._all_xp(50, far, net.XP_RANGE)
			check("a kill 600 m off: no XP (%d)" % (p.progression.xp - x0), p.progression.xp == x0)
			net._all_xp(50, far, INF)
			check("a boss 600 m off: the whole crew's (%d)" % (p.progression.xp - x0), p.progression.xp > x0)
			var QR = load("res://scripts/quests/quest_rewards.gd")
			var want: int = QR.xp_for(p)
			var x1: int = p.progression.xp
			var lv0: int = p.progression.level
			var got: String = QR.give({"gold": 10}, p)
			check("a quest turned in pays XP (%d, %s)" % [p.progression.xp - x1, got], (p.progression.xp - x1 >= want - 1 or p.progression.level > lv0) and want > 0 and "XP" in got)
			check("...and says so up front", "experience" in QR.text({"gold": 10}))
			return TK.done(fails)
	step += 1
	return false
