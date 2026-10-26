extends SceneTree
## Points per tree (1.23): a format-6 save (one Combat pool) loads with its levels kept and every weapon purchase
## refunded once into that weapon's own points (katana 24: 52, cutlass 12: 26), nothing bought again; a node that's
## no more (a removed black-leg technique) just goes. The bar's refunded skill comes off it. Adventure's purchases
## are bought back as they were. Saved again (format 7) it loads as it is: a node bought after stays bought.
const TK := preload("res://tools/dev/test_kit.gd")
const SAVE := "user://t_weapon_refund.dat"
const KATANA := ["k_draw", "k_deflect", "k_wind", "k_full", "k_iai", "k_clean"]
const CUTLASS := ["s_dash", "s_riposte"]
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
			data["progression"] = {"format": 6, "level": 18, "xp": 50,
				"owned": ["c_root", "k_root", "s_root", "m_soru"] + KATANA + CUTLASS + ["k_eye", "m_geppo", "m_swift"],
				"bought": KATANA + CUTLASS + ["bl_gone_node", "m_geppo", "m_swift"],
				"mastery": {"katana": {"lv": 24, "xp": 30}, "sword": {"lv": 12, "xp": 0}, "acrobatics": {"lv": 6, "xp": 0}},
				"steps": {"k_keen": 5, "s_edge": 3, "ac_light": 2}, "versions": {"k_iai": 1}, "found": ["katana", "acrobatics"],
				"tiers": {}, "uses": {"wind_sever": 7}, "passives": ["", "", ""]}
			data["power"]["loadout"] = ["riposte", "wind_sever", "", "", "", ""]
			f = FileAccess.open(SAVE, FileAccess.WRITE)
			f.store_var(data)
			f.close()
			pr.from_dict({})
			check("load", SG.load_into(p))
			print("   katana %d cutlass %d adventure %d bought %s steps %s" % [pr.pool("katana"), pr.pool("sword"), pr.pool("adventure"), pr.bought.keys(), pr.steps])
			check("levels kept: Captain 18, katana 24, cutlass 12", pr.level == 18 and pr.mastery_level("katana") == 24 and pr.mastery_level("sword") == 12)
			check("every weapon node and step refunded, nothing bought again", (KATANA + CUTLASS).all(func(k): return not pr.owns(k)) and pr.steps_of("k_keen") == 0 and pr.steps_of("s_edge") == 0)
			check("...the katana's own 52 points, the cutlass's 26", pr.pool("katana") == 52 and pr.pool("sword") == 26)
			check("...the bar's refunded skills off it", not ("riposte" in p.power.loadout) and not ("wind_sever" in p.power.loadout))
			check("Adventure's purchases bought back: Geppo, Swift Step, 2 Light Steps, 1 point left", pr.owns("m_geppo") and pr.owns("m_swift") and pr.steps_of("ac_light") == 2 and pr.pool("adventure") == 1)
			check("uses kept", pr.uses_of("wind_sever") == 7)
			check("a node bought after the refund", pr.buy("k_draw") and pr.pool("katana") == 50)
			SG.save(p)
			pr.from_dict({})
			check("load again", SG.load_into(p))
			check("...as it was: nothing refunded twice", pr.owns("k_draw") and pr.pool("katana") == 50 and pr.pool("sword") == 26 and pr.owns("m_geppo") and pr.pool("adventure") == 1)
			SG.use_test_file("")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
			return TK.done(fails)
	step += 1
	return false
