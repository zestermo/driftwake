extends SceneTree
## The skill icon redo (2026-11-11): every weapon and base skill has a picture of its own at each of the three sizes
## it's rendered at (16 / 32 / 48 px: Skills.icon(id, px) picks the nearest), so do the moves' and the perks' names;
## a fruit power without one still shows its fruit; the HUD bar's slots hold a 32 px picture exactly.
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
	# (by path: Skills reaches the autoloads)
	var S = load("res://scripts/progression/skills.gd")
	check("a picture 14 px across uses the 16 px one, 26 the 32, 48 the 48", S.icon_size(14.0) == 16 and S.icon_size(26.0) == 32 and S.icon_size(48.0) == 48)
	var own := 0
	var missing: Array = []
	var fruit_ok := true
	var fruits := 0
	for id in S.ALL.keys():
		var sk: Dictionary = S.ALL[id]
		var tree := str(sk.get("tree", ""))
		if tree != "" and tree[0] == tree[0].to_lower():
			own += 1
			for px in S.ICON_SIZES:
				var t: Texture2D = S.icon(id, float(px))
				if t == null or t.get_width() != px or t.get_height() != px:
					missing.append("%s@%d" % [id, px])
		elif str(sk.get("fruit", "")) != "":
			fruits += 1
			fruit_ok = fruit_ok and S.icon(id) != null
	print("   %d weapon and base skills, %d fruit powers" % [own, fruits])
	check("every weapon and base skill has its own picture at 16, 32 and 48 px (%d skills; missing: %s)" % [own, str(missing.slice(0, 6))], own > 100 and missing.is_empty())
	check("every fruit power shows something (its own picture, or its fruit)", fruits > 50 and fruit_ok)
	var named := 0
	var bad: Array = []
	var dir := DirAccess.open("res://assets/textures/icons")
	for f in dir.get_files():
		if f.begins_with("skill_") and f.ends_with("_32.png") and (f.begins_with("skill_move_") or f.begins_with("skill_perk_")):
			named += 1
			var id2 := f.trim_prefix("skill_").trim_suffix("_32.png")
			for px in S.ICON_SIZES:
				var t2: Texture2D = S.icon(id2, float(px))
				if t2 == null or t2.get_width() != px:
					bad.append("%s@%d" % [id2, px])
	check("the moves and perks have theirs too (%d names; missing: %s)" % [named, str(bad.slice(0, 6))], named >= 40 and bad.is_empty())
	var B = load("res://scripts/ui/skill_bar.gd")
	check("the HUD bar's slots hold a 32 px picture exactly (skill %d, ultimate %d)" % [int(B.SKILL), int(B.ULT)], int(B.SKILL) - 2 == 32 and int(B.ULT) - 4 == 32)
	return TK.done(fails)
