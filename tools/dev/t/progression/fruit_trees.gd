extends SceneTree
## The fruit trees at near weapon size (1.27, the previewed shape): every fruit's tree has its gates (powers at 1, 1,
## 4, 8, 12), mechanics, an alternate at 16, the bent at 22, ultimates at 20/24, the awakening at 30, 20+ nodes (the
## preview's table) and more points than mastery 30 gives (66) but not wildly more; owned, the mechanics and the bent
## change the powers.
const TK := preload("res://tools/dev/test_kit.gd")
const FRUITS := ["ember", "storm", "gust", "wolf", "bear", "vine", "iron", "bubble", "clockwork", "echo"]
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
	var pr = p.progression
	var ST = load("res://scripts/progression/skill_trees.gd")
	match step:
		0:
			until = TK.wait_secs(2.0)
		1:
			for f in FRUITS:
				var ids: Array = ST.nodes_of(f)
				var total := 0
				var kinds := {}
				for k in ids:
					var n: Dictionary = ST.node_def(k)
					kinds[n["kind"]] = int(kinds.get(n["kind"], 0)) + 1
					total += ST.price(k) * (int(n["max_steps"]) if n["kind"] == "step" else 1)
				var g: Dictionary = ST.FRUIT_GROWTH[f]
				var lv: Array = (g["powers"] as Array).map(func(k): return int(ST.node_def(k)["level"]))
				lv.sort()
				check("%s: %d nodes, %d points (%s), powers at %s" % [f, ids.size(), total, kinds, lv],
					ids.size() >= 20 and total >= 66 and total <= 110 and kinds.get("variant", 0) >= 1 and kinds.get("ult", 0) == 3
					and int(lv[0]) == 1 and int(lv[1]) == 1 and int(lv[4]) <= 12)
			# the mechanics and the bent, owned
			p.power.fruit = "bubble"
			p.power.loadout[0] = "bubble_shield"
			p.power.energy = p.power.max_energy()
			p.power.cooldowns.clear()
			pr.owned["bb_thick"] = true
			p.state_machine.force_state("Idle", {})
			p.power.try_cast(0)
			check("Thick Film owned: Bubble Shield takes 4 hits (%d)" % p.power.bubble_hits, p.power.bubble_hits == 4)
			var sk: Dictionary = p.power.skill(0)
			var c0: float = p.power.cost_of(sk)
			pr.owned["bb_variant"] = true
			pr.owned["bb_bent_b"] = true
			check("the Foam bent: Bubble powers cost 20%% less (%.1f -> %.1f)" % [c0, p.power.cost_of(sk)], absf(p.power.cost_of(sk) - c0 * 0.8) < 0.05)
			p.power.fruit = "storm"
			pr.owned["sm_forked"] = true
			check("Forked owned: Chain Lightning leaps once more (%d)" % int(p.power.sv("storm_jumps")), p.power.sv("storm_jumps") == 1.0)
			return TK.done(fails)
	step += 1
	return false
