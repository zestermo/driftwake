extends SceneTree
## Island fidelity (docs/island_fidelity_plan.md, phase 0): Brinehollow and generated
## chain islands scored on the same metrics (settlement, props, landmarks and places,
## people, night, paths, ground, cost), each generated island as a ratio of
## Brinehollow. Prints a table and writes <out>/fidelity.json and fidelity.md. The
## definitions and today's numbers: docs/island_fidelity_baseline.md. measure() and
## anchors() are shared with fidelityshot.gd; fidelitytest.gd extends this.
## Headless is fine. Args: [chain seeds, comma separated | -] [node id | -] [out dir]
## (defaults: 777,31337,4242, each chain's first island, res://tools/dev/out/fidelity)

## Settled land: within SETTLE_R of a building's footprint edge, plus STREET_W either
## side of any path stretch within STREET_R of one, plus the pier.
const SETTLE_R := 15.0
const STREET_R := 30.0
const STREET_W := 3.0
const GRID := 2.0
## A prop this close to a street (past its half width) dresses it.
const LANE_R := 4.0
## A building is dressed with DRESSED_N props within DRESSED_R of its footprint.
const DRESSED_R := 5.0
const DRESSED_N := 3
## Buildings.house's own clutter, counted as props: the rain barrel's water, the woodpile's bark, the awning's basket.
const CLUTTER_TEX := ["water", "bark", "straw"]
const SHADOW_DIST := 120.0
const CAM_FAR := 1200.0
const CAM_FOV := 70.0

const BUILDINGS := {"House": "house", "Harbor": "house", "Warehouse": "house", "NetLoft": "house", "CaptainsShack": "house",
	"Home": "house", "Shop": "workshop", "Workshop": "workshop", "Shrine": "civic", "Storehouse": "house", "Ruin": "ruin",
	"Hut": "house", "Inn": "inn", "Tavern": "inn", "Smithy": "workshop", "HarbourBooth": "workshop", "Chapel": "civic",
	"MarketStall": "stall", "Boathouse": "house", "RuinedHut": "house"}
const PROPS := {
	"Torch": "lights", "Woodpile": "cargo", "Jar": "cargo", "Basket": "cargo", "Sack": "cargo", "Rubble": "wild",
	"Crate": "cargo", "Barrel": "cargo", "RopeCoil": "cargo", "Nets": "cargo", "Timber": "cargo", "Float": "cargo", "Wares": "cargo",
	"Handcart": "carts",
	"Bench": "furniture", "Table": "furniture", "Workbench": "furniture", "Sawhorses": "furniture", "Log": "furniture", "Well": "furniture",
	"Fence": "fences",
	"LanternPost": "lights", "Campfire": "lights",
	"Rowboat": "boats", "UpturnedBoat": "boats", "Longboat": "boats", "DenSloop": "boats", "BoatOnStocks": "boats",
	"Signpost": "signs", "NoticeBoard": "signs",
	"Planter": "gardens", "Garden": "gardens",
	"Bunting": "textiles", "Washing": "textiles", "CampFlag": "textiles", "CrewFlag": "textiles", "DenFlag": "textiles",
	"FishRack": "work", "WeaponRack": "work", "DockCrane": "work", "DummyTarget": "work",
	"Tent": "camp", "LootBag": "chests",
	"Burrow": "wild", "Boulders": "wild", "Thornbrush": "wild",
	"Canoe": "boats", "Wreck": "boats", "NetRack": "work", "FishTrap": "cargo", "Contraband": "cargo",
}
const LANDMARKS := {"Lighthouse": "lighthouse", "HarbourTower": "harbour tower", "Chapel": "chapel", "DockCrane": "crane",
	"Shrine": "shrine",
	"LookoutTower": "lookout tower", "Pillar": "ruins", "FallenPillar": "ruins", "Slabs": "ruins", "Driftstone": "standing stone",
	"BroodCave": "cave", "Well": "well", "Boulders": "beast's ground", "Dungeon": "cave",
	"Crag": "waterfall", "WreckHull": "wreck", "GreatTree": "great tree", "StepPyramid": "step pyramid", "Temple": "ruined temple", "SunkenHut": "sunken village",
	"Volcano": "volcano vent", "Skeleton": "giant skeleton", "Colossus": "fallen colossus", "SeaArch": "sea arch",
	"Springs": "hot springs", "Cenote": "cenote", "Spire": "giant nest", "Crystals": "crystal grove", "Fort": "old fort"}
## Walked into for the props on them (a pier's lantern), their own meshes not counted.
const INFRA := ["HarbourPier", "Quay", "Dock", "Pier", "Cobbles", "Ladder", "Boardwalk", "PierFender", "CoveRocks", "Walkway", "Ramp", "Deck", "Palisade", "Gate"]
const INTERIORS := ["Tavern", "BroodCave", "Dungeon", "Temple", "Home", "Shop"]
const SKIP := ["Terrain", "Ground", "Vegetation", "VegetationColliders", "ShotMarks", "CargoColliders", "Worn"]
## GenIsland.build_ms keys worked out in prepare (a worker thread in the game).
const PREP_KEYS := ["land", "places", "arrays", "trees", "undergrowth", "thicket", "bodies", "harbour plan", "dungeon_plan"]

## [key, label, gated]: gated ones are what phase 3 holds at >= 80% of Brinehollow.
const METRICS := [
	["buildings", "Buildings", true],
	["dressed_share", "Buildings dressed (3+ props within 5 m, own clutter counted), share", true],
	["interiors", "Interiors", true],
	["settled_ha", "Settled land (ha)", false],
	["props_settled", "Props in settled land", false],
	["props_per_ha", "Props per settled ha", true],
	["lane_props_50m", "Street props per 50 m", true],
	["prop_cats", "Prop categories in settled land", true],
	["landmarks", "Distinct landmarks", true],
	["pois", "Places (POIs)", true],
	["walk_dock_mean", "Walk dock -> place, mean (m)", false],
	["walk_spacing", "Walk place -> nearest place, mean (m)", false],
	["npcs", "NPCs", true],
	["npcs_talk", "NPCs who talk (tree, shop or barks)", true],
	["npcs_dialogue", "NPCs with a dialogue tree", false],
	["npcs_routes", "NPCs walking a route", true],
	["npcs_per_ha", "NPCs per settled ha", false],
	["hostiles", "Hostiles (camp men, burrows, bosses)", false],
	["night_lights", "NightLights", false],
	["lights_per_ha", "Real lights in settled land per ha", true],
	["windows", "Lit windows", false],
	["windows_per_ha", "Lit windows per settled ha", true],
	["glow_surfaces", "Other glowing surfaces", false],
	["path_m", "Path length (m)", false],
	["paved_share", "Path length paved, share", true],
	["street_m_per_ha", "Street length per settled ha (m)", false],
	["veg_meshes", "Vegetation meshes (variety)", true],
	["veg_per_ha", "Vegetation per land ha", true],
	["land_ha", "Land (ha)", false],
	["surfaces", "Surfaces, static", false],
	["tris_k", "Triangles, static, instanced (k)", false],
	["mm_instances", "MultiMesh instances", false],
	["draws_plaza", "Draw calls, plaza view (est.)", false],
	["draws_harbour", "Draw calls, harbour view (est.)", false],
	["shadow_draws", "Shadow-pass draws near the plaza (est.)", false],
	["char_surfaces", "Character surfaces (NPCs, enemies)", false],
	["nodes", "Nodes", false],
	["geo_mb", "Geometry memory, est. (MB)", false],
	["mem_mb", "Static memory of the build (MB)", false],
	["build_ms", "Build, all (ms)", false],
	["build_main_ms", "Build, main thread (ms)", false],
]

var seeds: Array = [777, 31337, 4242]
var want_id := -1
var out_dir := "res://tools/dev/out/fidelity"
var test_mode := false
var timeout := 300.0
var results: Array = []
var t := 0.0
var step := 0
var wait := 0
var _next := 0


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "-":
		seeds = Array(a[0].split(",")).map(func(s): return int(s))
	if a.size() > 1 and a[1] != "-":
		want_id = int(a[1])
	if a.size() > 2:
		out_dir = a[2]
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	if t > timeout:
		print("FAIL timed out at island %d" % _next)
		print("RESULT FAILED (1)")
		quit()
		return true
	if wait > 0:
		wait -= 1
		return false
	var w = root.get_node_or_null("World/Islands")
	if w == null or t < 1.5:
		return false
	match step:
		0:
			if not w.chain_ready():
				return false
			# (the world builds no more of its own chain islands: the ones measured here are built by hand)
			w.set_process(false)
			for n in root.find_children("*", "CharacterCreator", true, false):
				n._finish(true)
			results.append(_brinehollow(w))
			step = 1
			wait = 3
		1:
			if _next >= seeds.size():
				_report()
				quit()
				return true
			results.append(_generated(w, int(seeds[_next])))
			_next += 1
			wait = 3
	return false


## Brinehollow as it stands, and a second copy built far off to time it (then freed).
func _brinehollow(w) -> Dictionary:
	var isl = w.get_node("Brinehollow")
	var r := measure(isl)
	r["name"] = "Brinehollow"
	var copy = load("res://scripts/island/starter_island.gd").new()
	copy.name = "FidelityTiming"
	copy.position = Vector3(0.0, 0.0, 9000.0)
	w.add_child(copy)
	var m0 := OS.get_static_memory_usage()
	var t0 := Time.get_ticks_usec()
	copy.build(int(w.world_seed))
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	r["m"]["build_ms"] = ms
	r["m"]["build_main_ms"] = ms
	r["m"]["mem_mb"] = (OS.get_static_memory_usage() - m0) / 1048576.0
	r["d"]["build_steps"] = copy.build_ms.duplicate()
	copy.queue_free()
	print("measured Brinehollow (built again in %d ms) %s" % [ms, JSON.stringify(r["d"]["build_steps"])])
	return r


## Chain `s`'s island (node want_id, or the first the log pose points at), built here
## all at once (GenIsland.build), measured, freed.
func _generated(w, s: int) -> Dictionary:
	var gm = root.get_node("GameManager")
	gm.chain_seed = s
	var c = w.chain()
	var id: int = clampi(want_id, 0, c.nodes.size() - 1) if want_id >= 0 else int(c.start_next[0])
	var n: Dictionary = c.node(id)
	var g = load("res://scripts/island/gen_island.gd").new()
	g.name = "FidelityIsle"
	g.position = Vector3(n["pos"].x, 0.0, n["pos"].y)
	w.add_child(g)
	var m0 := OS.get_static_memory_usage()
	var t0 := Time.get_ticks_usec()
	# GenIsland.build step by step, keeping each step name's slowest (the world runs one a frame)
	load("res://scripts/island/island_theme.gd").meshes(str(n["theme"]))
	g.prepare(n)
	var worst := {}
	for st in g.finish_steps():
		worst[st[0]] = maxi(int(worst.get(st[0], 0)), g.run_step(st))
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var mem := (OS.get_static_memory_usage() - m0) / 1048576.0
	var r := measure(g)
	r["name"] = "%s (seed %d, node %d)" % [n["name"], s, id]
	r["short"] = str(n["name"])
	r["seed"] = s
	r["id"] = id
	var main := 0
	for k in g.build_ms.keys():
		if not PREP_KEYS.has(k):
			main += int(g.build_ms[k])
	r["m"]["build_ms"] = ms
	r["m"]["build_main_ms"] = main
	r["m"]["mem_mb"] = mem
	r["d"]["build_steps"] = g.build_ms.duplicate()
	r["d"]["build_worst_step"] = worst
	g.queue_free()
	print("measured %s: r %.0f, built in %d ms (main thread %d) %s" % [r["name"], g.radius, ms, main, g.build_ms])
	print("   slowest step of each name (ms): %s" % [worst])
	return r


# ==========================================================================
# The metrics
# ==========================================================================
## Every metric of `isl` (a StarterIsland or a GenIsland in the tree):
## {"m": metric -> number, "d": detail (anchors, buildings, props, landmarks, streets,
## districts, walks, settled cells) for the report and fidelityshot}.
static func measure(isl: Node3D) -> Dictionary:
	var a := anchors(isl)
	var w := {"buildings": [], "props": [], "landmarks": [], "npcs": [], "hostiles": 0, "interiors": [], "unknown": {}, "fp": {}}
	_learn(isl, w["fp"])
	_walk(isl, isl, w, false)
	var m := {}
	var d := {"anchors": a, "unknown": w["unknown"], "buildings": w["buildings"], "props": w["props"]}
	# land
	var half: float = a["half"]
	var land := 0
	var x := -half
	while x < half:
		var z := -half
		while z < half:
			if isl.hv(Vector2(x, z)) > 0.3:
				land += 1
			z += 3.0
		x += 3.0
	var land_ha := land * 9.0 / 10000.0
	m["land_ha"] = land_ha
	# settled land
	var settled := {}
	for b in w["buildings"]:
		_mark(settled, b["p"], float(b["r"]) + SETTLE_R)
	var samples := _samples(a["paths"], a["widths"])
	var streets: Array = []
	var path_m := 0.0
	for s in samples:
		path_m += float(s[3])
		if _edge_dist(w["buildings"], s[0]) < STREET_R:
			streets.append(s)
			_mark(settled, s[0], float(s[1]) + STREET_W)
	var pier_len: float = (a["dock_end"] as Vector2).distance_to(a["dock"])
	var k := -5.0
	while k <= pier_len:
		_mark(settled, a["dock"] + a["dock_dir"] * k, 6.0)
		k += 2.0
	var districts := {}
	for dn in ["harbour", "village", "outskirts", "wilds"]:
		districts[dn] = {"area_ha": 0.0, "buildings": 0, "dressed": 0, "props": 0, "cats": {}, "lights": 0, "windows": 0, "npcs": 0,
			"street_m": 0.0, "lane_props": 0}
	var settled_land := 0
	for c in settled.keys():
		var q := (Vector2(c) + Vector2(0.5, 0.5)) * GRID
		if isl.hv(q) > 0.3:
			settled_land += 1
			districts[_district(q, settled, a)]["area_ha"] += GRID * GRID / 10000.0
	var settled_ha := settled_land * GRID * GRID / 10000.0
	m["settled_ha"] = settled_ha
	d["settled"] = settled
	# buildings and props
	var by_cat := {}
	var props_settled := 0
	for p in w["props"]:
		var dn := _district(p["p"], settled, a)
		p["district"] = dn
		districts[dn]["props"] += 1
		districts[dn]["cats"][p["cat"]] = int(districts[dn]["cats"].get(p["cat"], 0)) + 1
		if dn != "wilds":
			props_settled += 1
			by_cat[p["cat"]] = int(by_cat.get(p["cat"], 0)) + 1
	var dressed := 0
	var by_kind := {}
	for b in w["buildings"]:
		var near: int = b["clutter"]
		for p in w["props"]:
			if (p["p"] as Vector2).distance_to(b["p"]) < float(b["r"]) + DRESSED_R:
				near += 1
		b["props_near"] = near
		b["district"] = _district(b["p"], settled, a)
		by_kind[b["kind"]] = int(by_kind.get(b["kind"], 0)) + 1
		districts[b["district"]]["buildings"] += 1
		if near >= DRESSED_N:
			dressed += 1
			districts[b["district"]]["dressed"] += 1
	m["buildings"] = w["buildings"].size()
	m["dressed_share"] = dressed / maxf(w["buildings"].size(), 1.0)
	m["interiors"] = w["interiors"].size()
	m["props_settled"] = props_settled
	m["props_per_ha"] = props_settled / maxf(settled_ha, 0.01)
	m["prop_cats"] = by_cat.size()
	d["by_cat"] = by_cat
	d["by_kind"] = by_kind
	d["interiors"] = w["interiors"]
	# streets and what's along them
	var street_m := 0.0
	for s in streets:
		street_m += float(s[3])
		districts[_district(s[0], settled, a)]["street_m"] += float(s[3])
	var lane_props := 0
	for p in w["props"]:
		for s in streets:
			if (p["p"] as Vector2).distance_to(s[0]) < float(s[1]) + LANE_R:
				lane_props += 1
				districts[p["district"]]["lane_props"] += 1
				break
	m["lane_props_50m"] = lane_props / maxf(street_m / 50.0, 0.01)
	m["street_m_per_ha"] = street_m / maxf(settled_ha, 0.01)
	m["path_m"] = path_m
	d["streets"] = streets
	# paving
	var paved := _paved_cells(isl)
	var paved_m := 0.0
	for s in samples:
		if paved.has(Vector2i(floori(s[0].x), floori(s[0].y))):
			paved_m += float(s[3])
	m["paved_share"] = paved_m / maxf(path_m, 0.01)
	# landmarks and places
	var lms: Array = []
	for l in w["landmarks"]:
		var dup := false
		for q in lms:
			if q["kind"] == l["kind"] and (q["p"] as Vector2).distance_to(l["p"]) < 30.0:
				dup = true
				q["top"] = maxf(float(q["top"]), float(l["top"]))
				break
		if not dup:
			lms.append(l)
	m["landmarks"] = lms.size()
	d["landmarks"] = lms
	var pois: Dictionary = a["pois"]
	var wd := _walks(a, pois)
	m["pois"] = pois.size()
	m["walk_dock_mean"] = _mean(wd["dock"].values())
	m["walk_spacing"] = _mean(wd["nearest"].values())
	d["walks"] = wd
	# people
	var talk := 0
	var dlg := 0
	var routes := 0
	var people: Array = []
	for n in w["npcs"]:
		var has_dlg := str(n.dialogue_id) != ""
		if has_dlg:
			dlg += 1
		if has_dlg or str(n.shop_id) != "" or not (n.barks as Array).is_empty():
			talk += 1
		if not (n.waypoints as Array).is_empty() or n.get("stays") != null:
			routes += 1
		var np := _pos(isl, n)
		districts[_district(np, settled, a)]["npcs"] += 1
		people.append(str(n.npc_name))
	m["npcs"] = w["npcs"].size()
	m["npcs_talk"] = talk
	m["npcs_dialogue"] = dlg
	m["npcs_routes"] = routes
	m["npcs_per_ha"] = w["npcs"].size() / maxf(settled_ha, 0.01)
	m["hostiles"] = w["hostiles"]
	d["people"] = people
	# night
	var nl := 0
	var lights_settled := 0
	var other := {}
	for l in isl.find_children("*", "Light3D", true, false):
		if _cls(l) == "NightLight":
			nl += 1
		else:
			other[_base(str(l.name))] = int(other.get(_base(str(l.name)), 0)) + 1
		var lp := _pos(isl, l)
		districts[_district(lp, settled, a)]["lights"] += 1
		if settled.has(_cell(lp)):
			lights_settled += 1
	m["night_lights"] = nl
	m["lights_per_ha"] = lights_settled / maxf(settled_ha, 0.01)
	d["other_lights"] = other
	# cost (and the lit windows, found on the way)
	var cost := _cost(isl, districts, settled, a)
	m["windows"] = cost["windows"]
	m["windows_per_ha"] = cost["windows_settled"] / maxf(settled_ha, 0.01)
	m["glow_surfaces"] = cost["glow_surfaces"]
	m["surfaces"] = cost["surfaces"]
	m["tris_k"] = cost["tris"] / 1000.0
	m["mm_instances"] = cost["mm_instances"]
	m["char_surfaces"] = cost["char_surfaces"]
	m["geo_mb"] = cost["geo_bytes"] / 1048576.0
	m["nodes"] = isl.find_children("*", "", true, false).size()
	var v: Vector2 = a["village"]
	var to_dock: Vector2 = ((a["dock"] as Vector2) - v).normalized()
	var plaza := view_draws(cost["items"], isl.to_global(_v3(isl, v + to_dock * 14.0, 3.0)), isl.to_global(_v3(isl, v, 1.5)))
	var pier_at: Vector2 = a["dock"] + a["dock_dir"] * 8.0
	var harbour := view_draws(cost["items"], isl.to_global(Vector3(pier_at.x, float(a["deck_y"]) + 2.5, pier_at.y)), isl.to_global(_v3(isl, v, 2.0)))
	m["draws_plaza"] = plaza["draws"]
	m["draws_harbour"] = harbour["draws"]
	m["shadow_draws"] = plaza["shadow"]
	d["draws"] = {"plaza": plaza, "harbour": harbour}
	# ground
	var veg := isl.get_node_or_null("Vegetation")
	var meshes := {}
	var kinds := {}
	var veg_n := 0
	if veg:
		for mmi in veg.get_children():
			var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
			var kind := _veg_kind(mmi)
			meshes[mm.mesh.get_instance_id()] = kind
			kinds[kind] = int(kinds.get(kind, 0)) + mm.instance_count
			veg_n += mm.instance_count
	var kind_meshes := {}
	for kk in meshes.values():
		kind_meshes[kk] = int(kind_meshes.get(kk, 0)) + 1
	m["veg_meshes"] = meshes.size()
	m["veg_per_ha"] = veg_n / maxf(land_ha, 0.01)
	d["veg"] = {"instances": kinds, "meshes": kind_meshes}
	d["districts"] = districts
	return {"m": m, "d": d}


## Where things are by role, the same keys for both kinds of island (island space):
## dock (the pier's root), dock_dir (out to sea), dock_end, deck_y, village (its
## middle), camp (the pirates'), pois (name -> point), paths + widths, half (extent),
## harbour (a polyline along the waterfront).
static func anchors(isl: Node3D) -> Dictionary:
	var a := {}
	var k: Dictionary = (isl.get_script() as GDScript).get_script_constant_map()
	if isl.get("is_generated"):
		var s: Dictionary = isl.sites
		a["dock"] = s["dock"]
		a["dock_dir"] = isl.dock_dir
		a["dock_end"] = s["dock_end"]
		a["deck_y"] = float(k["DOCK_DECK_Y"])
		a["village"] = s["village"]
		a["camp"] = s["camp"]
		var pois := {}
		for p in ["village", "camp", "lair", "ruins", "summit", "boss"]:
			pois[p] = s[p]
		for e in isl.interiors:
			pois[e["name"]] = e["mouth"]
		for pl in isl.places:
			pois[str(pl["kind"])] = pl["at"]
		a["pois"] = pois
		a["paths"] = isl.paths
		a["widths"] = isl._path_widths
		a["half"] = float(isl.half)
		a["harbour"] = isl.harbour.waterfront()
	else:
		a["dock"] = isl.dock_shore
		a["dock_dir"] = isl.dock_dir
		a["dock_end"] = isl.dock_shore + isl.dock_dir * float(k["DOCK_LENGTH"])
		a["deck_y"] = float(k["QUAY_Y"])
		a["village"] = k["VILLAGE"]
		a["camp"] = k["SMUGGLERS"]
		a["pois"] = {"village": k["VILLAGE"], "market": k["MARKET"], "training yard": k["TRAINING"], "lighthouse": k["HILL"],
			"ruins": k["RUINS"], "cove camp": k["CAMP"], "smugglers' camp": k["SMUGGLERS"], "pirate den": k["DEN"],
			"brood cave": k["CAVE"], "jungle stash": k["JUNGLE_STASH"]}
		a["paths"] = isl.paths
		a["widths"] = isl.path_widths
		a["half"] = float(k["HALF"])
		var quay: Array = []
		var x: float = isl.port_x0
		while x <= isl.port_x1:
			quay.append(isl._quay_pt(x, 0.0))
			x += 8.0
		a["harbour"] = quay + [a["dock"], a["dock_end"]]
	return a


static func _known(base: String) -> bool:
	return BUILDINGS.has(base) or PROPS.has(base) or LANDMARKS.has(base) or INFRA.has(base) or SKIP.has(base) \
		or base.begins_with("Stall_") or base.begins_with("Moored") or base.begins_with("Site_")


## A second copy of a thing added under the same parent loses its name
## ("@StaticBody3D@123"): so every named thing's meshes are fingerprinted here and
## the unnamed ones are known by them (see _kind_of).
static func _learn(n: Node, fp: Dictionary) -> void:
	for c in n.get_children():
		if not c is Node3D or c.is_in_group("npcs") or c is CharacterBody3D:
			continue
		var base := _base(str(c.name))
		if _known(base) and not base.begins_with("Site_") and not SKIP.has(base):
			var keys := _fingerprints(c)
			for i in range(keys.size()):
				if keys[i] == "":
					continue
				var k := "%d|%s" % [i, keys[i]]
				fp[k] = base if not fp.has(k) or fp[k] == base else "?"
			if keys[3] != "":
				if not fp.has("_sets"):
					fp["_sets"] = []
				fp["_sets"].append([c.get_class(), keys[3].split("/"), base])
			continue
		_learn(c, fp)


## From exact to loose: [texture, tint and vertex count per surface, texture and
## vertex count, vertex counts, textures].
static func _fingerprints(n: Node) -> Array:
	var tinted: Array = []
	var parts: Array = []
	var counts: Array = []
	var texs := {}
	var mis: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		mis.append(n)
	for mi in mis:
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null or not mesh is ArrayMesh:
			continue
		for s in range(mesh.get_surface_count()):
			var mat := (mi as MeshInstance3D).get_active_material(s)
			var tn := _tex_name(mat)
			var tint = (mat as ShaderMaterial).get_shader_parameter("albedo_color") if mat is ShaderMaterial else null
			var vc := (mesh as ArrayMesh).surface_get_array_len(s)
			tinted.append("%s#%s:%d" % [tn, (tint as Color).to_html() if tint is Color else "", vc])
			parts.append("%s:%d" % [tn, vc])
			counts.append(vc)
			texs[tn] = true
	if parts.is_empty():
		return ["", "", "", ""]
	tinted.sort()
	parts.sort()
	counts.sort()
	var tl: Array = texs.keys()
	tl.sort()
	return ["/".join(tinted), "/".join(parts), str(counts), "/".join(tl)]


static func _tex_name(mat: Material) -> String:
	if mat is ShaderMaterial:
		var tex = (mat as ShaderMaterial).get_shader_parameter("albedo_tex")
		if tex is Texture2D:
			return (tex as Texture2D).resource_path.get_file().get_basename()
	return "flat"


## What an unnamed thing is: the named one whose meshes match it (most exact key
## first; one with a door is a house unless its geometry matched exactly), else the
## named one of its class whose textures mostly match (Jaccard >= 0.5, one best).
static func _kind_of(c: Node, fp: Dictionary) -> String:
	var keys := _fingerprints(c)
	if keys[3] == "":
		return ""
	var mine: PackedStringArray = keys[3].split("/")
	for i in range(keys.size()):
		var k := "%d|%s" % [i, keys[i]]
		if i == 2 and c is StaticBody3D and mine.has("door"):
			return "House"
		if fp.has(k) and fp[k] != "?":
			return fp[k]
	var best := ""
	var best_j := 0.499
	var tie := false
	for e in fp.get("_sets", []):
		if e[0] != c.get_class():
			continue
		var both := 0
		for tx in mine:
			if (e[1] as PackedStringArray).has(tx):
				both += 1
		var j := both / float(mine.size() + (e[1] as PackedStringArray).size() - both)
		if j > best_j + 0.001:
			best_j = j
			best = e[2]
			tie = false
		elif absf(j - best_j) <= 0.001 and best != "" and e[2] != best:
			tie = true
	return "" if tie else best


## The things on the island by name (props, buildings, landmarks), its people and
## hostiles. `quiet`: inside a pier or quay (their own meshes aren't unknowns).
static func _walk(n: Node, isl: Node3D, w: Dictionary, quiet: bool) -> void:
	for c in n.get_children():
		if not c is Node3D or c is Area3D or c is Light3D or c is AudioStreamPlayer3D or c is CollisionShape3D:
			continue
		var base := _base(str(c.name))
		if SKIP.has(base):
			continue
		var cls := _cls(c)
		if c.is_in_group("npcs"):
			w["npcs"].append(c)
			continue
		if cls == "Ladder":
			continue
		if cls == "MooredHull":
			base = "Moored"
		if not _known(base) and not quiet:
			var kb := _kind_of(c, w["fp"])
			if kb != "":
				base = kb
		if cls == "GruntCamp":
			w["hostiles"] += (c.specs as Array).size()
			continue
		if cls == "ScuttlebugNest":
			w["hostiles"] += (c.spots as Array).size()
			continue
		if cls == "BeastArena":
			w["hostiles"] += 1
			continue
		if cls == "LootBag":
			w["props"].append({"cat": "chests", "kind": "Chest", "p": _pos(isl, c)})
			continue
		if c is CharacterBody3D:
			continue
		var p := _pos(isl, c)
		if INTERIORS.has(base):
			w["interiors"].append(base)
		if LANDMARKS.has(base):
			var box := _local_aabb(c)
			w["landmarks"].append({"kind": LANDMARKS[base], "p": p, "top": c.global_position.y - isl.global_position.y + box.end.y, "h": box.size.y})
		var bk: String = BUILDINGS.get(base, "stall" if base.begins_with("Stall_") else "")
		if bk != "":
			var box := _local_aabb(c)
			var texs: PackedStringArray = _fingerprints(c)[3].split("/")
			var clutter := 0
			for tx in CLUTTER_TEX:
				if texs.has(tx):
					clutter += 1
			w["buildings"].append({"kind": bk, "name": base, "p": p, "r": maxf(box.size.x, box.size.z) * 0.5, "front": _front(isl, c), "clutter": clutter})
			continue
		var pk: String = PROPS.get(base, "boats" if base.begins_with("Moored") else "")
		if pk != "" and c is MultiMeshInstance3D:
			# (instanced cargo: each copy is a prop)
			var mm: MultiMesh = (c as MultiMeshInstance3D).multimesh
			for i in range(mm.instance_count):
				var o := isl.to_local((c as Node3D).global_transform * mm.get_instance_transform(i).origin)
				w["props"].append({"cat": pk, "kind": base, "p": Vector2(o.x, o.z)})
			continue
		if pk != "":
			w["props"].append({"cat": pk, "kind": base, "p": p})
			continue
		if INFRA.has(base):
			_walk(c, isl, w, true)
			continue
		if LANDMARKS.has(base):
			continue
		if c is GeometryInstance3D or c is StaticBody3D:
			if not quiet:
				var uk := "%s in %s (%s)" % [base, _base(str(n.name)), _fingerprints(c)[0]]
				w["unknown"][uk] = int(w["unknown"].get(uk, 0)) + 1
			continue
		_walk(c, isl, w, quiet)


## Surfaces, triangles, MultiMesh instances and a geometry memory estimate (each
## mesh once: 32 bytes a vertex, 2-4 an index; 48 a MultiMesh instance), the static
## world apart from characters; lit windows (window-textured glow, 10 triangles each)
## and other glowing surfaces. "items" [geometry, surfaces, is a character] feed view_draws.
static func _cost(isl: Node3D, districts: Dictionary, settled: Dictionary, a: Dictionary) -> Dictionary:
	var c := {"surfaces": 0, "tris": 0, "mm_instances": 0, "char_surfaces": 0, "char_tris": 0, "windows": 0, "windows_settled": 0,
		"glow_surfaces": 0, "geo_bytes": 0, "items": []}
	var seen := {}
	for gi in isl.find_children("*", "GeometryInstance3D", true, false):
		if not (gi as GeometryInstance3D).is_visible_in_tree():
			continue
		var ch := _in_character(gi, isl)
		var surf := 1
		var tris := 0
		if gi is MeshInstance3D:
			var mesh: Mesh = (gi as MeshInstance3D).mesh
			if mesh == null:
				continue
			surf = mesh.get_surface_count()
			tris = _tris(mesh, -1)
			_mem(mesh, seen, c)
			if not ch:
				for s in range(surf):
					var mat := (gi as MeshInstance3D).get_active_material(s)
					if not mat is ShaderMaterial:
						continue
					var et = (mat as ShaderMaterial).get_shader_parameter("emission_tex")
					if et == null:
						continue
					if et is Texture2D and (et as Texture2D).resource_path.ends_with("window.png"):
						var wn := int(_tris(mesh, s) / 10.0)
						c["windows"] += wn
						var wp := _pos(isl, gi)
						districts[_district(wp, settled, a)]["windows"] += wn
						if settled.has(_cell(wp)):
							c["windows_settled"] += wn
					else:
						c["glow_surfaces"] += 1
		elif gi is MultiMeshInstance3D:
			var mm: MultiMesh = (gi as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null:
				continue
			surf = mm.mesh.get_surface_count()
			tris = _tris(mm.mesh, -1) * mm.instance_count
			c["mm_instances"] += mm.instance_count
			c["geo_bytes"] += mm.instance_count * 48
			_mem(mm.mesh, seen, c)
		if ch:
			c["char_surfaces"] += surf
			c["char_tris"] += tris
		else:
			c["surfaces"] += surf
			c["tris"] += tris
		c["items"].append([gi, surf, ch])
	return c


## Draw calls from a camera at `cam` looking at `look` (world): every visible surface
## whose bounds are in the view frustum (fov 70, 16:9, far 1200) and inside its
## visibility range, the characters' share, and shadow casters within the sun's
## shadow distance all round (one pass; cascades not counted).
static func view_draws(items: Array, cam: Vector3, look: Vector3) -> Dictionary:
	var xf := Transform3D(Basis.looking_at(look - cam, Vector3.UP), cam)
	var planes := _frustum(xf)
	var draws := 0
	var chars := 0
	var shadow := 0
	for it in items:
		var gi: GeometryInstance3D = it[0]
		if not is_instance_valid(gi):
			continue
		var box: AABB = gi.global_transform * gi.get_aabb()
		var vend := gi.visibility_range_end
		if vend > 0.0 and cam.distance_to(box.get_center()) > vend:
			continue
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and _box_dist(box, cam) < SHADOW_DIST:
			shadow += int(it[1])
		if _outside(box, planes):
			continue
		draws += int(it[1])
		if it[2]:
			chars += int(it[1])
	return {"draws": draws, "chars": chars, "shadow": shadow}


static func _frustum(xf: Transform3D) -> Array:
	var va := deg_to_rad(CAM_FOV * 0.5)
	var ha := atan(tan(va) * 16.0 / 9.0)
	var local := [[Vector3(0, 0, 1), -0.05], [Vector3(0, 0, -1), CAM_FAR],
		[Vector3(-cos(ha), 0, sin(ha)), 0.0], [Vector3(cos(ha), 0, sin(ha)), 0.0],
		[Vector3(0, cos(va), sin(va)), 0.0], [Vector3(0, -cos(va), sin(va)), 0.0]]
	var out: Array = []
	for pl in local:
		var nw: Vector3 = (xf.basis * (pl[0] as Vector3)).normalized()
		var on: Vector3 = xf * ((pl[0] as Vector3) * float(pl[1]))
		out.append(Plane(nw, nw.dot(on)))
	return out


static func _outside(box: AABB, planes: Array) -> bool:
	for pl in planes:
		var all_out := true
		for i in range(8):
			if (pl as Plane).distance_to(box.get_endpoint(i)) <= 0.0:
				all_out = false
				break
		if all_out:
			return true
	return false


static func _box_dist(box: AABB, p: Vector3) -> float:
	return p.distance_to(p.clamp(box.position, box.end))


static func _tris(mesh: Mesh, only: int) -> int:
	var n := 0
	for s in range(mesh.get_surface_count()):
		if only >= 0 and s != only:
			continue
		if mesh is ArrayMesh:
			var ix := (mesh as ArrayMesh).surface_get_array_index_len(s)
			n += int((ix if ix > 0 else (mesh as ArrayMesh).surface_get_array_len(s)) / 3.0)
		else:
			n += int(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size() / 3.0)
	return n


static func _mem(mesh: Mesh, seen: Dictionary, c: Dictionary) -> void:
	var id := mesh.get_instance_id()
	if seen.has(id) or not mesh is ArrayMesh:
		return
	seen[id] = true
	for s in range(mesh.get_surface_count()):
		var v := (mesh as ArrayMesh).surface_get_array_len(s)
		c["geo_bytes"] += v * 32 + (mesh as ArrayMesh).surface_get_array_index_len(s) * (2 if v < 65536 else 4)


static func _in_character(n: Node, isl: Node) -> bool:
	var p := n.get_parent()
	while p and p != isl:
		if p is CharacterBody3D or p.is_in_group("npcs"):
			return true
		p = p.get_parent()
	return false


## 1 m cells (island space) under cobbled ground: the paving's near-level triangles.
static func _paved_cells(isl: Node3D) -> Dictionary:
	var cells := {}
	for mi in isl.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null or _in_character(mi, isl):
			continue
		for s in range(mesh.get_surface_count()):
			var mat := (mi as MeshInstance3D).get_active_material(s)
			if not mat is ShaderMaterial:
				continue
			var tex = (mat as ShaderMaterial).get_shader_parameter("albedo_tex")
			if not (tex is Texture2D and (tex as Texture2D).resource_path.ends_with("cobbles.png")):
				continue
			var arr := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var to_isl: Transform3D = isl.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform
			var n := idx.size() if idx.size() > 0 else verts.size()
			for i in range(0, n - 2, 3):
				var va := to_isl * verts[idx[i] if idx.size() > 0 else i]
				var vb := to_isl * verts[idx[i + 1] if idx.size() > 0 else i + 1]
				var vc := to_isl * verts[idx[i + 2] if idx.size() > 0 else i + 2]
				var nrm := (vb - va).cross(vc - va)
				if nrm.length() < 0.0001 or absf(nrm.normalized().y) < 0.9:
					continue
				# (the triangle's area covered in 1 m cells, sampled on a 0.5 m lattice)
				var lo := Vector2(minf(va.x, minf(vb.x, vc.x)), minf(va.z, minf(vb.z, vc.z)))
				var hi := Vector2(maxf(va.x, maxf(vb.x, vc.x)), maxf(va.z, maxf(vb.z, vc.z)))
				var x := floorf(lo.x)
				while x <= hi.x:
					var z := floorf(lo.y)
					while z <= hi.y:
						if Geometry2D.point_is_inside_triangle(Vector2(x + 0.5, z + 0.5), Vector2(va.x, va.z), Vector2(vb.x, vb.z), Vector2(vc.x, vc.z)):
							cells[Vector2i(int(x), int(z))] = true
						z += 1.0
					x += 1.0
				cells[Vector2i(floori((va.x + vb.x + vc.x) / 3.0), floori((va.z + vb.z + vc.z) / 3.0))] = true
	return cells


static func _veg_kind(mmi: Node) -> String:
	var end: float = (mmi as GeometryInstance3D).visibility_range_end
	if end > 0.0:
		return "undergrowth" if end < 120.0 else "bushes"
	return "trees" if (mmi as MultiMeshInstance3D).multimesh.mesh.get_aabb().size.y > 3.0 else "rocks"


## Walking distances along the paths (straight across within 20 m of another path
## point, x1.2; a place joins the paths within 40 m, x1.2, or its nearest point, x1.5):
## dock -> each place, and each place -> its nearest other place.
static func _walks(a: Dictionary, pois: Dictionary) -> Dictionary:
	var pts: Array = []
	var adj: Array = []
	var link := func(i: int, j: int, cost: float) -> void:
		adj[i].append([j, cost])
		adj[j].append([i, cost])
	for path in a["paths"]:
		var pp: PackedVector2Array = path
		for j in range(pp.size()):
			pts.append(pp[j])
			adj.append([])
			if j > 0:
				link.call(pts.size() - 2, pts.size() - 1, pp[j].distance_to(pp[j - 1]))
	var n_path := pts.size()
	for i in range(n_path):
		for j in range(i + 1, n_path):
			var dd := (pts[i] as Vector2).distance_to(pts[j])
			if dd < 20.0:
				link.call(i, j, dd * 1.2)
	var idx := {}
	for nm in ["dock"] + pois.keys():
		var p: Vector2 = a["dock"] if nm == "dock" else pois[nm]
		var i := pts.size()
		pts.append(p)
		adj.append([])
		idx[nm] = i
		var best := -1
		var bd := INF
		for j in range(n_path):
			var dd := p.distance_to(pts[j])
			if dd < 40.0:
				link.call(i, j, dd * 1.2)
			if dd < bd:
				bd = dd
				best = j
		if bd >= 40.0 and best >= 0:
			link.call(i, best, bd * 1.5)
	var from_dock := _dijkstra(adj, idx["dock"])
	var dock := {}
	var nearest := {}
	for nm in pois.keys():
		dock[nm] = from_dock[idx[nm]]
		var dist := _dijkstra(adj, idx[nm])
		var best := INF
		for o in pois.keys():
			if o != nm:
				best = minf(best, dist[idx[o]])
		nearest[nm] = best
	return {"dock": dock, "nearest": nearest}


static func _dijkstra(adj: Array, src: int) -> PackedFloat32Array:
	var n := adj.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(INF)
	var done := PackedByteArray()
	done.resize(n)
	dist[src] = 0.0
	for _k in range(n):
		var u := -1
		var bu := INF
		for i in range(n):
			if done[i] == 0 and dist[i] < bu:
				bu = dist[i]
				u = i
		if u < 0:
			break
		done[u] = 1
		for e in adj[u]:
			var nd := bu + float(e[1])
			if nd < dist[e[0]]:
				dist[e[0]] = nd
	return dist


## Every path in 1 m steps: [point, half width, direction, metres it stands for].
static func _samples(paths: Array, widths: Array) -> Array:
	var out: Array = []
	for i in range(paths.size()):
		var pts: PackedVector2Array = paths[i]
		for j in range(pts.size() - 1):
			var a := pts[j]
			var b := pts[j + 1]
			var n := maxi(int(a.distance_to(b)), 1)
			for k in range(n):
				out.append([a.lerp(b, float(k) / n), float(widths[i]), (b - a).normalized(), a.distance_to(b) / n])
	return out


static func _mark(cells: Dictionary, c: Vector2, r: float) -> void:
	var n := int(ceil(r / GRID))
	var k0 := _cell(c)
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var k := k0 + Vector2i(dx, dz)
			if not cells.has(k) and ((Vector2(k) + Vector2(0.5, 0.5)) * GRID).distance_to(c) <= r:
				cells[k] = true


static func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / GRID), floori(p.y / GRID))


static func _edge_dist(buildings: Array, p: Vector2) -> float:
	var best := INF
	for b in buildings:
		best = minf(best, p.distance_to(b["p"]) - float(b["r"]))
	return best


## harbour (within 30 m of the waterfront, or nearer it than the village and within
## 60 m), village (within 60 m of its middle), outskirts (the rest of the settled
## land), wilds (everything else).
static func _district(p: Vector2, settled: Dictionary, a: Dictionary) -> String:
	if not settled.has(_cell(p)):
		return "wilds"
	var dh := _poly_dist(a["harbour"], p)
	var dv := p.distance_to(a["village"])
	if dh <= 30.0:
		return "harbour"
	if dv <= 60.0:
		return "village"
	if dh <= 60.0:
		return "harbour"
	return "outskirts"


static func _poly_dist(pts: Array, p: Vector2) -> float:
	var best := INF
	for i in range(pts.size() - 1):
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
	return best


static func _local_aabb(c: Node3D) -> AABB:
	var inv := c.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for mi in c.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh == null:
			continue
		var b: AABB = (inv * (mi as MeshInstance3D).global_transform) * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	if c is MeshInstance3D and (c as MeshInstance3D).mesh:
		box = (c as MeshInstance3D).get_aabb() if first else box.merge((c as MeshInstance3D).get_aabb())
		first = false
	return AABB(Vector3(-2, 0, -2), Vector3(4, 3, 4)) if first else box


static func _pos(isl: Node3D, n: Node3D) -> Vector2:
	var l := isl.to_local(n.global_position)
	return Vector2(l.x, l.z)


## The way a thing faces (its +Z), island space.
static func _front(isl: Node3D, n: Node3D) -> Vector2:
	var z: Vector3 = isl.global_basis.inverse() * n.global_basis.z
	return Vector2(z.x, z.z).normalized()


static func _v3(isl: Node3D, p: Vector2, up: float) -> Vector3:
	return Vector3(p.x, maxf(isl.hv(p), 0.0) + up, p.y)


## "@Barrel@123" / "Barrel2" -> "Barrel".
static func _base(n: String) -> String:
	var parts := n.replace("@", " ").strip_edges().split(" ", false)
	var s: String = parts[0] if parts.size() > 0 else n
	while s.length() > 1 and s[s.length() - 1] >= "0" and s[s.length() - 1] <= "9":
		s = s.substr(0, s.length() - 1)
	return s


static func _cls(n: Node) -> String:
	var s: Script = n.get_script()
	while s:
		if s.get_global_name() != "":
			return s.get_global_name()
		s = s.get_base_script()
	return n.get_class()


static func _mean(xs: Array) -> float:
	var sum := 0.0
	var n := 0
	for x in xs:
		if float(x) < INF:
			sum += float(x)
			n += 1
	return sum / maxf(n, 1.0)


# ==========================================================================
# The report
# ==========================================================================
static func ratio(g: float, b: float) -> float:
	return g / b if absf(b) > 0.000001 else (1.0 if absf(g) < 0.000001 else INF)


static func fmt(v) -> String:
	var f := float(v)
	if f == INF:
		return "inf"
	if absf(f - roundf(f)) < 0.0001 and absf(f) >= 1.0:
		return str(int(roundf(f)))
	return "%.2f" % f if absf(f) < 10.0 else "%.1f" % f


func _report() -> void:
	var b: Dictionary = results[0]
	var gens: Array = results.slice(1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var lines: Array = []
	var head := "| Metric | Brinehollow |"
	var rule := "|---|---:|"
	for g in gens:
		head += " %s | ratio |" % g["short"]
		rule += "---:|---:|"
	lines.append(head)
	lines.append(rule)
	var gated_low := {}
	for mt in METRICS:
		var key: String = mt[0]
		var bv := float(b["m"].get(key, 0.0))
		var row := "| %s%s | %s |" % [mt[1], " *" if mt[2] else "", fmt(bv)]
		var rs: Array = []
		for g in gens:
			var gv := float(g["m"].get(key, 0.0))
			var r := ratio(gv, bv)
			rs.append(r)
			row += " %s | %s |" % [fmt(gv), fmt(r)]
		lines.append(row)
		if mt[2]:
			gated_low[key] = rs.reduce(func(x, y): return minf(x, y), INF)
	var md: Array = ["# Island fidelity: Brinehollow vs generated islands", "",
		"%s. Ratio = generated / Brinehollow; * = gated metric (phase 3 wants >= 0.8). Definitions: docs/island_fidelity_baseline.md." % Time.get_date_string_from_system(), ""]
	md.append_array(lines)
	for r in results:
		md.append("")
		md.append("## %s" % r["name"])
		md.append("")
		md.append("| District | Area (ha) | Buildings | Dressed | Props | Props/ha | Street (m) | Street props | Lights | Windows | NPCs | Prop categories |")
		md.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|")
		for dn in ["harbour", "village", "outskirts", "wilds"]:
			var dd: Dictionary = r["d"]["districts"][dn]
			var cats := ", ".join(dd["cats"].keys().map(func(k): return "%s %d" % [k, dd["cats"][k]]))
			md.append("| %s | %s | %d | %d | %d | %s | %d | %d | %d | %d | %d | %s |" % [dn, fmt(dd["area_ha"]), dd["buildings"], dd["dressed"], dd["props"],
				fmt(dd["props"] / maxf(float(dd["area_ha"]), 0.01)) if dn != "wilds" else "-", int(dd["street_m"]), dd["lane_props"], dd["lights"], dd["windows"], dd["npcs"], cats])
		md.append("")
		md.append("- Buildings by kind: %s; interiors: %s" % [JSON.stringify(r["d"]["by_kind"]), ", ".join(r["d"]["interiors"])])
		md.append("- Landmarks: %s" % ", ".join(r["d"]["landmarks"].map(func(l): return str(l["kind"]))))
		md.append("- Walk from the dock (m): %s" % ", ".join(r["d"]["walks"]["dock"].keys().map(func(k): return "%s %d" % [k, int(minf(r["d"]["walks"]["dock"][k], 99999.0))])))
		md.append("- Vegetation: %s instances, %s meshes" % [JSON.stringify(r["d"]["veg"]["instances"]), JSON.stringify(r["d"]["veg"]["meshes"])])
		md.append("- Other lights: %s; people: %s" % [JSON.stringify(r["d"]["other_lights"]), ", ".join(r["d"]["people"])])
		md.append("- Views: plaza %s, harbour %s" % [JSON.stringify(r["d"]["draws"]["plaza"]), JSON.stringify(r["d"]["draws"]["harbour"])])
		if r["d"].has("build_steps"):
			md.append("- Build steps (ms): %s" % JSON.stringify(r["d"]["build_steps"]))
		if not r["d"]["unknown"].is_empty():
			md.append("- Unclassified: %s" % JSON.stringify(r["d"]["unknown"]))
	var f := FileAccess.open(out_dir.path_join("fidelity.md"), FileAccess.WRITE)
	f.store_string("\n".join(md) + "\n")
	f.close()
	var js: Array = []
	for r in results:
		var dd: Dictionary = r["d"]
		js.append({"name": r["name"], "seed": r.get("seed", -1), "id": r.get("id", -1), "metrics": r["m"], "districts": dd["districts"],
			"by_kind": dd["by_kind"], "by_cat": dd["by_cat"], "interiors": dd["interiors"], "landmarks": dd["landmarks"].map(func(l): return l["kind"]),
			"walks": dd["walks"], "veg": dd["veg"], "other_lights": dd["other_lights"], "people": dd["people"], "build_steps": dd.get("build_steps", {}),
			"unknown": dd["unknown"]})
	f = FileAccess.open(out_dir.path_join("fidelity.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"date": Time.get_date_string_from_system(), "islands": js}, "  "))
	f.close()
	print("")
	for l in lines:
		print(l)
	print("")
	print("written: %s/fidelity.md, fidelity.json" % out_dir)
	if test_mode:
		for mt in METRICS:
			if mt[2]:
				print("PASS (report) %s: lowest ratio %s" % [mt[1], fmt(gated_low[mt[0]])])
		print("PASS measured Brinehollow and %d generated islands" % gens.size())
		print("RESULT OK")
