extends SceneTree
## The island theme registry (IslandThemes, ThemeDef): every registered theme fills the whole contract
## (walked from ThemeDef.CONTRACT, not a list here), its beast and creature scripts exist, its style's
## prop slots build (a lamp with its Flame) and name models no other theme does, its style's ambience and
## music are real beds and tracks; the jungle's land def, style, roster, cave fauna, beasts and text are what
## they were in the hubs (spot checks), FaunaSpawner and ChainMarks read it; the chain's theme pick is
## one rng draw whatever the themes, and with the jungle alone every island is jungle with a jungle name;
## a blank theme is refused whole and an unknown name fails loudly (an error naming it, null back).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0


class ErrorLog extends Logger:
	var errors: Array = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		errors.append(rationale if rationale != "" else code)


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var IT = load("res://scripts/island/themes/island_themes.gd")
	var TD = load("res://scripts/island/themes/theme_def.gd")
	var KS = load("res://scripts/island/kit/kit_style.gd")
	var LP = load("res://scripts/island/kit/life_pools.gd")
	var BP = load("res://scripts/enemies/beasts/beast_pool.gd")
	var CH = load("res://scripts/world/chain.gd")
	var themes: Array = IT.all()
	check("themes registered, the jungle first: %s" % [themes.map(func(t): return t.name)], not themes.is_empty() and themes[0].name == "jungle" and IT.has("jungle"))
	# the contract, member by member, for every theme
	var gaps: Array = []
	var models := {}
	for t in themes:
		for k in TD.CONTRACT:
			var v = t.get(k)
			var empty: bool = v == null or (v is String and v == "") or (v is Array and v.is_empty()) or (v is Dictionary and v.is_empty() and k != "props") \
				or (v is float and v <= 0.0) or (v is int and v < 0) or (v is Color and v.a <= 0.0) or (v is Callable and not v.is_valid())
			if empty:
				gaps.append("%s.%s" % [t.name, k])
		for k in t.missing():
			gaps.append("%s: %s" % [t.name, k])
		for k in t.beasts:
			if not ResourceLoader.exists(t.beasts[k]["script"]):
				gaps.append("%s.beasts.%s script %s" % [t.name, k, t.beasts[k]["script"]])
		for k in t.creatures:
			if not ResourceLoader.exists(t.creatures[k]):
				gaps.append("%s.creatures.%s script %s" % [t.name, k, t.creatures[k]])
		if (t.meshes() as Dictionary).is_empty():
			gaps.append("%s.meshes()" % t.name)
		for m in t.props:
			if models.has(m):
				gaps.append("%s and %s both make a prop called %s" % [models[m], t.name, m])
			models[m] = t.name
		for slot in t.style["props"]:
			var m: String = t.style["props"][slot]
			if not KS.BASE_PROPS.has(m) and not t.props.has(m):
				gaps.append("%s style props.%s names %s, which no theme makes" % [t.name, slot, m])
		if not IT.of(t.name) == t:
			gaps.append("%s: of() gives another instance" % t.name)
		var amb: String = t.style.get("ambience", "")
		if amb != "" and not load("res://scripts/world/ambience.gd").LOOPS.has(amb):
			gaps.append("%s style ambience %s is no Ambience.LOOPS bed" % [t.name, amb])
		if t.style.has("music") and not load("res://scripts/game/music.gd").TRACKS.has(t.style["music"]):
			gaps.append("%s style music %s is no Music.TRACKS track" % [t.name, t.style["music"]])
	check("every theme fills every contract member, its scripts exist, its prop models are its own %s" % [gaps], gaps.is_empty())
	# every style's prop slots build, lamps with their Flame
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bad_props: Array = []
	for sn in KS.styles().keys():
		var st: Dictionary = KS.of(sn)
		for slot in KS.BRINEHOLLOW["props"].keys():
			var prop: Node3D = KS.prop(st, slot, rng)
			if prop == null or (slot == "lamp" and prop.get_node_or_null("Flame") == null):
				bad_props.append("%s %s" % [sn, slot])
			if prop:
				prop.free()
	check("every style's prop slots build (%s) %s" % [KS.styles().keys(), bad_props], bad_props.is_empty() and KS.styles().has("jungle") and KS.styles().has("brinehollow"))
	# the jungle, as it was in the hubs
	var j = IT.of("jungle")
	var land: Dictionary = load("res://scripts/island/island_theme.gd").def("jungle")
	check("the jungle's land def: peak 24-36, base 4.4, canopy 0.74, six forests, old growth's kapoks 2.2", land == j.land and land["peak"] == [24.0, 36.0] and land["base"] == 4.4
		and land["canopy"] == 0.74 and (land["forests"] as Array).size() == 6 and land["forests"][1][1]["giants"]["kapok"] == 2.2)
	var st: Dictionary = KS.of("jungle")
	check("the jungle's style over Brinehollow's: flagstones, torch posts, lamp range 12, palm thatch houses on stilts, Brinehollow's rugs kept",
		st["paving"] == "flagstones" and st["props"]["lamp"] == "torch_post" and st["lamp_range"] == 12.0 and st["house"]["stilts"] == true
		and st["house"]["roof_tex"] == ["palm_thatch"] and st["rugs"] == KS.BRINEHOLLOW["rugs"] and st["ambience"] == "jungle" and st["music"] == "island" and st.is_read_only())
	check("the jungle's beasts: ape/serpent/stalker/mantis, the boar at the ruins, the behemoth; the strangler's 3 looks and 3 names",
		j.bosses == ["ape", "serpent", "stalker", "mantis"] and j.minis == ["boar"] and j.roamers == ["behemoth"] and BP.info("jungle", "boar")["site"] == "ruins"
		and BP.info("jungle", "serpent")["looks"] == 3 and BP.info("jungle", "serpent")["names"].size() == 3 and BP.info("jungle", "ape")["names"] == ["The Silverback"])
	check("the ape's body is stocked ahead (a look named Silverback), the others' aren't",
		(BP.stock_looks({"theme": "jungle", "beast": "ape"}) as Array).size() == 1 and BP.stock_looks({"theme": "jungle", "beast": "ape"})[0]["name"] == "Silverback"
		and (BP.stock_looks({"theme": "jungle", "beast": "mantis"}) as Array).is_empty())
	check("the jungle's roster: ten creatures, boars 60% likely in 2-5 dens on the floor, bats in the canopy and caves",
		j.fauna.size() == 10 and j.fauna["boar"] == {"zones": ["floor"], "p": 0.6, "dens": [2, 5]} and j.fauna["bat"]["zones"] == ["canopy", "cave"] and j.creatures.size() == 10
		and j.cave_fauna == {"ceiling": "bat", "floor": ["mite", "burrower", "snake"]})
	var FS = load("res://scripts/island/fauna_spawner.gd")
	var r: Dictionary = FS.roll("jungle", 1234)
	var kinds: Array = r.keys().filter(func(k): return k != "morph" and k != "ambient")
	var cr = FS.make("jungle", "crab")
	check("FaunaSpawner rolls from the theme's roster (%s) and makes its creatures (%s)" % [kinds, cr.get_class()],
		kinds.size() >= FS.MIN_KINDS and kinds.all(func(k): return j.fauna.has(k)) and JSON.stringify(r) == JSON.stringify(FS.roll("jungle", 1234))
		and cr.get_script().resource_path == j.creatures["crab"])
	cr.free()
	check("ChainMarks reads the theme's colour (and darkens it for the chart)", load("res://scripts/ui/chain_marks.gd").theme_color("jungle") == j.color
		and load("res://scripts/ui/chain_marks.gd").theme_color("jungle", true) == j.color.darkened(0.5))
	var life: Dictionary = LP.of("jungle")
	check("the jungle's text: 36 first names, 7 roles, the elder's two lines about the island, every quest kind",
		(life["first"] as Array).size() == 36 and life["roles"].size() == 7 and life["roles"].has("netmender") and (life["elder_about"] as Array).size() == 2
		and life["quests"].keys() == ["lost", "scout", "deliver", "fetch", "clear"] and LP.fill("{a}-{b}", {"a": 1, "b": "x"}) == "1-x")
	check("the chain's words: Jungle, a steaming jungle isle, eight names, weight 1, parrots in two parties, a green glyph",
		j.display == "Jungle" and j.blurb == "a steaming jungle isle" and j.island_names.size() == 8 and j.weight == 1.0 and j.flocks == 2 and j.color.g > 0.8)
	check("Chain.describe reads the theme's display name", CH.describe({"theme": "jungle", "role": "city", "level": 10}) == "Jungle city  Lv 10")
	# the chain's theme pick: one draw, the same stream as before the registry
	var c = CH.make(4242, Vector2.ZERO, Vector2(0, -1))
	var a := RandomNumberGenerator.new()
	a.seed = 5
	var picked: String = c._pick_theme(a, [])
	var b := RandomNumberGenerator.new()
	b.seed = 5
	b.randi()
	check("the theme pick is one rng draw (%s)" % picked, IT.has(picked) and a.state == b.state)
	var known := true
	var named := true
	for n in c.nodes:
		if not IT.has(n["theme"]):
			known = false
		elif not IT.of(n["theme"]).island_names.has(n["base"]):
			named = false
	check("every island of a chain has a registered theme and a name from that theme's list (%d islands)" % c.nodes.size(), known and named and c.nodes.size() >= 9)
	# refusals
	var blank = TD.new()
	var missing: Array = blank.missing()
	check("a blank theme is refused on every contract member but props, which may be empty (%d of %d)" % [missing.size(), TD.CONTRACT.size()],
		TD.CONTRACT.all(func(k): return missing.has(k) or k == "props") and not missing.has("props"))
	var errlog := ErrorLog.new()
	OS.add_logger(errlog)
	var nope = IT.of("nope")
	OS.remove_logger(errlog)
	check("an unknown theme fails loudly: %s" % [errlog.errors], nope == null and not IT.has("nope") and errlog.errors.any(func(e): return str(e).contains("no theme called nope")))
	return TK.done(fails)
