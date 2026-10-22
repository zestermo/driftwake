extends SceneTree
## A format-5 save (big nodes came by mastery level) loads into the two pools: its levels kept, then what it owned
## bought back while the pool affords it. Captain 18 has 32 Combat points: the cutlass's Riposte on the bar first
## (3), then the katana (mastery 24, the higher tree) lowest gate first while it fits (Phantom Step at 4 doesn't,
## with 2 left), then the cutlass's Running Cut (2); the rest of both trees and every step refunded. A variant keeps
## its picked version. Saved again (format 6) it loads as it is.
const TK := preload("res://tools/dev/test_kit.gd")
const SAVE := "user://t_buy_back.dat"
const KATANA := ["k_draw", "k_deflect", "k_wind", "k_full", "k_arc", "k_counter", "k_tiger", "k_iai", "k_through", "k_eye",
	"k_clean", "k_phantom", "k_elem", "k_return", "k_calm"]
const CUTLASS := ["s_dash", "s_deflect", "s_flying", "s_dive", "s_riposte", "s_swordfish"]
var SG
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "katana"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			SG = load("res://scripts/game/save_game.gd")
			p = stage.player
			pr = p.progression
			SG.use_test_file(SAVE)
			SG.save(p)
			var f := FileAccess.open(SAVE, FileAccess.READ)
			var data: Dictionary = f.get_var()
			f.close()
			data["progression"] = {"format": 5, "level": 18, "xp": 50,
				"owned": ["c_root", "k_root", "s_root", "m_soru", "c_quarter", "v_tekkai"] + KATANA + CUTLASS,
				"mastery": {"katana": {"lv": 24, "xp": 30}, "sword": {"lv": 12, "xp": 0}},
				"steps": {"k_keen": 5, "s_edge": 3}, "versions": {"k_iai": 1}, "found": ["katana"],
				"tiers": {}, "uses": {"wind_sever": 7}, "passives": ["", "", ""]}
			data["power"]["loadout"] = ["riposte", "", "", "", "", ""]
			f = FileAccess.open(SAVE, FileAccess.WRITE)
			f.store_var(data)
			f.close()
			pr.from_dict({})
			check("load", SG.load_into(p))
			print("   pool %d bought %s steps %s" % [pr.pool("combat"), pr.bought.keys(), pr.steps])
			check("levels kept: Captain 18, katana 24, cutlass 12", pr.level == 18 and pr.mastery_level("katana") == 24 and pr.mastery_level("sword") == 12)
			check("the Captain's milestones still by level", pr.owns("m_soru") and pr.owns("v_tekkai") and pr.owns("c_quarter"))
			check("Riposte (on the bar) bought back first, still on the bar", pr.owns("s_riposte") and "riposte" in p.power.loadout)
			check("the katana bought back to Clean Line", ["k_draw", "k_deflect", "k_wind", "k_full", "k_arc", "k_counter", "k_tiger", "k_iai", "k_clean"].all(func(k): return pr.owns(k)))
			check("...Mind's Eye still the active version", pr.version_of("k_iai") == 1 and pr.owns("k_eye") and not pr.owns("k_through"))
			check("...Phantom Step, the element, Bullet Return, Empty Mind refunded", ["k_phantom", "k_elem", "k_return", "k_calm"].all(func(k): return not pr.owns(k)))
			check("the cutlass's Running Cut fits the last 2", pr.owns("s_dash") and not pr.owns("s_flying") and not pr.owns("s_swordfish"))
			check("every step refunded, the pool spent to 0", pr.steps.is_empty() and pr.pool("combat") == 0)
			check("uses kept", pr.uses_of("wind_sever") == 7)
			SG.save(p)
			pr.from_dict({})
			check("load again", SG.load_into(p))
			check("...as it was", pr.owns("k_clean") and pr.owns("s_riposte") and pr.owns("s_dash") and not pr.owns("k_phantom") and pr.version_of("k_iai") == 1 and pr.pool("combat") == 0)
			SG.use_test_file("")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
			return TK.done(fails)
	step += 1
	return false
