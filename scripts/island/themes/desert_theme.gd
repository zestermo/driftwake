extends ThemeDef
## The desert: the largest islands, sand-yellow and nearly bare - dune fields with sharp crests
## and soft lee sides, sandstone ridges and mesas, canyons, a dry wadi from the highlands to the
## sea, a raised plateau the capital may stand on, salt flats and the odd oasis in palms. The
## detail is in the land, the rock and the wind; plants are few on purpose (DesertPlants). Its
## towns are pastel plaster and sandstone (DesertProps), its people's text desert_life.gd.

## Land (the jungle's keys, then the desert's own features, planned per island in plan_land):
## "dune_fields" [lo, hi] fields of transverse dunes, "dune_h" crest height, "dune_len" crest to crest;
## "ridges", "mesas", "canyons", "wadis", "salt", "oases" [lo, hi] counts; "plateau" the chance of a
## raised centre, "plateau_h" its rise, "capital" the chance the village moves up onto it.
## "forests" are its land variants (one per island from its seed).
const LAND := {
	"peak": [12.0, 22.0], "hills": [3, 6], "hill_h": [5.0, 13.0], "roll": 4.0, "base": 4.8,
	"ramp": [32.0, 54.0], "cliffs": [1, 3], "cliff_h": [8.0, 15.0],
	"tree": 0.08, "edge": 0.004, "beach_tree": 0.03, "fern": 0.05, "bush": 0.05, "grass": 0.06, "rock": 0.035,
	"cover": 0.3,
	"canopy": 0.0, "giants": {"giant": 1.0, "fig": 0.0, "kapok": 0.0, "emergent": 0.0},
	"bamboo": 0.06, "palm_inland": 0.14, "mangrove": 0.03,
	"broadleaf": 0.035, "shrub": 0.02, "floor": 0.0, "overgrown": 0.0,
	"dune_fields": [1, 3], "dune_h": [4.5, 9.0], "dune_len": [40.0, 72.0],
	"ridges": [1, 3], "mesas": [1, 3], "canyons": [0, 1], "wadis": [1, 2], "salt": [0, 1], "oases": [1, 2],
	"plateau": 0.65, "plateau_h": [11.0, 17.0], "capital": 0.55,
	"forests": [
		["open desert", {}],
		["sand sea", {"dune_fields": [3, 4], "dune_h": [7.0, 12.0], "ridges": [0, 1], "mesas": [0, 1], "plateau": 0.35}],
		["badlands", {"dune_fields": [0, 1], "ridges": [3, 5], "mesas": [3, 6], "canyons": [1, 2], "rock": 0.06, "plateau": 0.5}],
		["high plateau", {"plateau": 1.0, "plateau_h": [16.0, 23.0], "wadis": [2, 3], "capital": 0.8}],
		["salt pans", {"salt": [2, 3], "dune_fields": [1, 2], "mesas": [1, 2], "oases": [0, 1]}],
		["oasis coast", {"oases": [2, 3], "beach_tree": 0.14, "palm_inland": 0.2, "cover": 0.36, "mangrove": 0.08}],
	],
}

## The settlement style over KitStyle.BRINEHOLLOW: pastel plaster and sandstone, brass lanterns, striped souk canvas.
const STYLE := {
	"lamp": Color(1.0, 0.72, 0.38),
	"lamp_range": 11.0,
	"paving": "sandstone",
	"quay_wall": Color(0.95, 0.86, 0.68),
	"quay_cope": Color(0.86, 0.76, 0.58),
	"iron": Color(0.55, 0.42, 0.2),
	"row_walls": ["adobe", "sandstone", "adobe", "plaster", "adobe"],
	"row_upper": ["adobe", "sandstone"],
	"row_roofs": ["hip", "shed", "hip"],
	"row_roof_tex": ["sandstone", 0.6, "adobe"],
	"row_awnings": ["red", "", "blue", "green", "", "red"],
	"pennants": [Color(0.75, 0.2, 0.15), Color(0.95, 0.75, 0.2), Color(0.18, 0.3, 0.6), Color(0.92, 0.88, 0.78), Color(0.25, 0.5, 0.3)],
	"washing": [Color(0.95, 0.92, 0.85), Color(0.85, 0.55, 0.3), Color(0.3, 0.42, 0.7), Color(0.9, 0.8, 0.4), Color(0.75, 0.4, 0.5)],
	"rugs": [["rug_kilim", Color(1.0, 1.0, 1.0)], ["rug_kilim", Color(0.85, 0.9, 1.05)], ["cloth_red", Color(0.95, 0.75, 0.6)]],
	"goods": [Color(0.95, 0.62, 0.15), Color(0.85, 0.25, 0.12), Color(0.95, 0.85, 0.35), Color(0.55, 0.32, 0.18), Color(0.6, 0.18, 0.3)],
	"tent": Color(0.92, 0.84, 0.66),
	"camp_tent": Color(0.6, 0.48, 0.36),
	"rough": {"flowers": false, "trim": Color(0.45, 0.32, 0.2), "wall": "adobe", "roof_tex": "adobe", "pitch": 0.2},
	"crew_flag": Color(0.78, 0.3, 0.2),
	"mat": {"wall": "adobe", "beam": "planks_dark", "floor": "planks", "deck": "planks_weathered", "post": "planks_dark",
		"rail": "planks_dark", "roof": "adobe", "thatch": "adobe", "rope": "rope", "stone": "sandstone", "cloth": "canvas",
		"weave": "straw"},
	"house": {"w": [4.5, 6.5], "d": [4.0, 5.5], "h": [2.6, 3.0], "walls": ["adobe", "adobe", "sandstone", "plaster"],
		"roofs": ["hip", "hip", "shed"], "roof_tex": ["adobe", "sandstone"], "pitch": [0.12, 0.2], "eaves": 0.2,
		"beam": "planks_dark", "floor": "planks", "poles": false, "lashings": false, "stilts": false,
		"porch": [0.25, 1.4, 1.8], "flowers": 0.15, "chimney": 0.0,
		"trims": [Color(0.24, 0.42, 0.62), Color(0.2, 0.52, 0.48), Color(0.72, 0.36, 0.22), Color(0.82, 0.66, 0.3), Color(0.42, 0.3, 0.52)]},
	"inn": {"w": 8.0, "d": 6.0, "h": 2.9, "roof": "hip", "wall": "sandstone", "porch": 2.0, "flowers": false},
	"stall": {"canopies": ["awning_red", "awning_blue", "awning_gold", "awning_green"], "post": "planks_dark"},
	"pier": {"deck": "planks_weathered", "post": "planks_dark", "rail": "planks_dark", "lashings": false, "rope_rail": true},
	"props": {"crate": "crate", "barrel": "desert_urn", "lamp": "desert_lantern_post", "marker": "desert_marker"},
	"folk": {
		"pick": {"skin": [Color(0.86, 0.68, 0.52), Color(0.76, 0.56, 0.4), Color(0.66, 0.47, 0.32), Color(0.55, 0.38, 0.26), Color(0.42, 0.29, 0.2)],
			"hair_color": [Color(0.08, 0.06, 0.05), Color(0.12, 0.08, 0.06), Color(0.22, 0.14, 0.08)],
			"hat": ["turban", "turban", "bandana", "none", "hood"], "hat_fem": ["hood", "hood", "bandana", "none"],
			"top": ["tunic", "kimono", "shirt", "tunic"], "top_fem": ["kimono", "tunic", "blouse"],
			"sleeves": ["long", "long", "short"], "legs": ["trousers", "trousers", "hakama"], "legs_fem": ["skirt", "skirt", "trousers"],
			"feet": ["sandals", "sandals", "shoes", "barefoot"], "belt": ["sash", "sash", "belt_sash"], "marks": ["none"],
			"top_color": [Color(0.94, 0.92, 0.86), Color(0.92, 0.86, 0.72), Color(0.25, 0.32, 0.6), Color(0.72, 0.3, 0.2), Color(0.86, 0.7, 0.35)],
			"legs_color": [Color(0.92, 0.88, 0.78), Color(0.72, 0.6, 0.42), Color(0.4, 0.3, 0.22), Color(0.26, 0.3, 0.5)],
			"sash_color": [Color(0.72, 0.18, 0.14), Color(0.86, 0.66, 0.2), Color(0.2, 0.32, 0.62), Color(0.3, 0.52, 0.36)],
			"hat_color": [Color(0.95, 0.93, 0.88), Color(0.92, 0.84, 0.66), Color(0.25, 0.32, 0.62), Color(0.72, 0.22, 0.16)]},
		"set": {"coat": "none", "vest": "none", "eyepatch": false, "gloves": false},
	},
	"music": "desert",
	"music_town": "desert_town",
	"ambience": "desert",
	"weather": [0.62, 0.9, 0.93],
	"haze": 0.12,
	"ground": {"grass": "desert_sand", "sand": "desert_beach", "wet_sand": "wet_sand", "dirt": "desert_hardpan", "rock": "desert_rock",
		"seafloor": "seafloor", "cliff": "desert_rock"},
	"arena": "open",
	"cave_look": {"rock": ["desert_rock", Color(1.0, 0.96, 0.92)], "moss": ["desert_rock", Color(1.05, 1.0, 0.92)], "turf": ["desert_sand", Color.WHITE],
		"wall": ["desert_rock", Color(0.85, 0.8, 0.76)], "floor": ["desert_hardpan", Color(0.8, 0.76, 0.7)]},
	"rock_tint": Color(0.86, 0.66, 0.46),
	"moss_tint": Color(0.82, 0.72, 0.52),
	"temple_stone": Color(0.92, 0.82, 0.62),
	"fort_stone": Color(0.95, 0.86, 0.68),
	"water_tint": Color(0.22, 0.55, 0.52, 0.85),
	"falls_tint": Color(0.78, 0.9, 0.95, 0.85),
	"spring_tint": Color(0.45, 0.8, 0.75, 0.85),
	"travertine": Color(0.96, 0.92, 0.82),
	"wreck_hull": Color(0.62, 0.55, 0.45),
	"bone": Color(0.94, 0.9, 0.8),
	"basalt": Color(0.36, 0.3, 0.28),
	"lava": Color(1.0, 0.45, 0.12),
	"crystal": Color(0.95, 0.75, 0.4),
	"rust": Color(0.55, 0.36, 0.22),
	"harbour_kinds": ["wharf", "cove", "ruins", "wharf"],
	"harbour_wild_kinds": ["landing", "landing", "ruins", "cove"],
	"harbour_pile": "planks_dark",
	"harbour_deck": "planks_weathered",
	"harbour_roof": "adobe",
	"harbour_walls": ["adobe", "sandstone", "adobe"],
	"harbour_tarp": Color(0.86, 0.78, 0.6),
	"harbour_floats": [Color(0.86, 0.3, 0.18), Color(0.92, 0.86, 0.72), Color(0.25, 0.38, 0.65)],
	"harbour_signal": Color(1.0, 0.55, 0.2),
}

## Each kind: its zones, how likely an island has it, how many groups (dens).
const FAUNA := {
	"crab": {"zones": ["shore"], "p": 0.75, "dens": [3, 7]},
	"snake": {"zones": ["floor"], "p": 0.65, "dens": [3, 7]},
	"burrower": {"zones": ["floor", "shore"], "p": 0.45, "dens": [2, 5]},
	"mite": {"zones": ["floor", "cave"], "p": 0.35, "dens": [1, 3]},
	"bat": {"zones": ["cave"], "p": 0.5, "dens": [1, 3]},
}
const CREATURES := {
	"crab": "res://scripts/enemies/fauna/crab.gd",
	"snake": "res://scripts/enemies/fauna/snake.gd",
	"burrower": "res://scripts/enemies/fauna/burrower.gd",
	"mite": "res://scripts/enemies/fauna/swarm_mite.gd",
	"bat": "res://scripts/enemies/fauna/bat.gd",
}


func _init() -> void:
	name = "desert"
	display = "Desert"
	blurb = "a sun-scorched desert isle"
	island_names = ["Sunscar", "Dunmara", "Saffra", "Ashbar", "Mirage", "Scorpa", "Dustwell", "Qadir"]
	weight = 1.0
	color = Color(0.95, 0.78, 0.35)
	glyph = _glyph
	flocks = 0
	land = LAND
	radius = [480.0, 640.0]
	style = STYLE
	props = {
		"desert_urn": func(rng: RandomNumberGenerator, size: float) -> Node3D: return DesertProps.urn(size, rng.randi()),
		"desert_lantern_post": func(_rng: RandomNumberGenerator, size: float) -> Node3D: return DesertProps.lantern_post(2.5 * size),
		"desert_marker": func(rng: RandomNumberGenerator, _size: float) -> Node3D: return DesertProps.waymarker(rng.randi()),
	}
	life = preload("res://scripts/island/themes/desert_life.gd").TEXT
	# (interim: the jungle's beasts until the desert's own)
	bosses = ["ape", "serpent", "stalker", "mantis"]
	minis = ["boar"]
	roamers = ["behemoth"]
	beasts = {
		"ape": {"script": "res://scripts/enemies/jungle_ape.gd", "names": ["The Silverback"], "looks": 1, "stock": func() -> Dictionary: return JungleApe.ape_look()},
		"serpent": {"script": "res://scripts/enemies/beasts/strangler.gd", "names": ["The Strangler", "Old Coil", "Mother of Vines"], "looks": 3},
		"stalker": {"script": "res://scripts/enemies/beasts/stalker.gd", "names": ["The Shade", "Nightmaw", "The Spotted Death"], "looks": 3},
		"mantis": {"script": "res://scripts/enemies/beasts/mantis_queen.gd", "names": ["The Mantis Queen", "The Orchid Queen", "The Leaf Queen"], "looks": 3},
		"boar": {"script": "res://scripts/enemies/beasts/alpha_boar.gd", "names": ["Tuskmaw", "Old Gristle", "Mudking", "Ironbristle"], "site": "ruins"},
		"behemoth": {"script": "res://scripts/enemies/beasts/behemoth.gd", "names": ["The Thornback", "Old Ironhide", "The Mossback"]},
	}
	fauna = FAUNA
	creatures = CREATURES
	cave_fauna = {"ceiling": "bat", "floor": ["mite", "burrower", "snake"]}


func meshes() -> Dictionary:
	var big := [DesertPlants.old_acacia(461), DesertPlants.old_acacia(462)]
	return {
		"tree": [DesertPlants.acacia(421), DesertPlants.acacia(422), DesertPlants.dead_tree(423), DesertPlants.dead_tree(424)],
		"beach_tree": [DesertPlants.date_palm(411), DesertPlants.date_palm(412), DesertPlants.date_palm(413)],
		"bush": [DesertPlants.scrub(431), DesertPlants.scrub(432), DesertPlants.saltbush(433)],
		"fern": [DesertPlants.barrel_cactus(441), DesertPlants.prickly_pear(442), DesertPlants.barrel_cactus(443)],
		"grass": [DesertPlants.dry_grass()],
		"rock": [DesertPlants.boulder(451), DesertPlants.boulder(452), DesertPlants.boulder(453, true)],
		"giant": big, "fig": big, "kapok": big, "emergent": big, "roof": big,
		"mangrove": [DesertPlants.reeds(481)],
		"bamboo": [DesertPlants.reeds(482, true), DesertPlants.reeds(483, true)],
		"broadleaf": [DesertPlants.column_cactus(491), DesertPlants.column_cactus(492)],
		"shrub": [DesertPlants.tumbleweed(495), DesertPlants.dead_tree(496), DesertPlants.saltbush(497)],
	}


## A dune: a long crest with a slip face, a sun over it.
static func _glyph(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	ci.draw_polyline(PackedVector2Array([p + Vector2(-s, s * 0.7), p + Vector2(s * 0.2, -s * 0.15), p + Vector2(s * 0.45, s * 0.05), p + Vector2(s, s * 0.7)]), col, 1.0)
	ci.draw_arc(p + Vector2(-s * 0.35, -s * 0.55), s * 0.28, 0.0, TAU, 8, col, 1.0)


# ==========================================================================
# The land: features planned per island (plan_land), heights (shape),
# where things grow (cover, growth) and the ground's colours (paint)
# ==========================================================================
func plan_land(isl, rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = isl._def
	var r: float = isl.radius
	var L := {"sites_n": -1}
	var nz := FastNoiseLite.new()
	nz.seed = rng.randi()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 0.012
	nz.fractal_octaves = 2
	L["noise"] = nz
	# the plateau, round the middle with the summit on its far side (the town keeps 45 m off the summit's site):
	# [centre, radius, rise, two phases for its rim's wobble, the way from the summit across it]
	L["plateau"] = []
	if rng.randf() < float(d["plateau"]):
		var peak: Vector2 = isl._bumps[0][0]
		var away := -peak.normalized() if peak.length() > 1.0 else Vector2.from_angle(rng.randf() * TAU)
		var pr := r * rng.randf_range(0.2, 0.28)
		var c := peak + away * (pr * 0.45 + 40.0)
		L["plateau"] = [c, pr, rng.randf_range(d["plateau_h"][0], d["plateau_h"][1]), rng.randf() * TAU, rng.randf() * TAU, away]
	L["capital"] = not (L["plateau"] as Array).is_empty() and rng.randf() < float(d["capital"])
	# mesas: flat-topped buttes, steep all round: [centre, radius, height, phase, rim width]
	L["mesas"] = []
	for i in range(rng.randi_range(d["mesas"][0], d["mesas"][1])):
		var c := Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.25, 0.62)
		L["mesas"].append([c, rng.randf_range(14.0, 34.0), rng.randf_range(10.0, 24.0), rng.randf() * TAU, rng.randf_range(3.0, 6.0)])
	# ridges: sharp-crested rock spines along a polyline
	L["ridges"] = []
	for i in range(rng.randi_range(d["ridges"][0], d["ridges"][1])):
		var a := rng.randf() * TAU
		var dir := Vector2.from_angle(a + rng.randf_range(-1.2, 1.2))
		var pts := PackedVector2Array([Vector2.from_angle(a) * r * rng.randf_range(0.15, 0.4)])
		for k in range(rng.randi_range(3, 5)):
			dir = dir.rotated(rng.randf_range(-0.5, 0.5))
			pts.append(pts[pts.size() - 1] + dir * rng.randf_range(50.0, 90.0))
		L["ridges"].append(_line(pts, rng.randf_range(16.0, 28.0), rng.randf_range(10.0, 22.0)))
	# dune fields: transverse dunes across one wind, crests meandering: [centre, radius, wind, crest to crest, height, noise offset]
	L["dunes"] = []
	var wind := Vector2.from_angle(rng.randf() * TAU)
	for i in range(rng.randi_range(d["dune_fields"][0], d["dune_fields"][1])):
		var c := Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.2, 0.6)
		L["dunes"].append([c, r * rng.randf_range(0.32, 0.5), wind.rotated(rng.randf_range(-0.4, 0.4)), rng.randf_range(d["dune_len"][0], d["dune_len"][1]),
			rng.randf_range(d["dune_h"][0], d["dune_h"][1]), rng.randf() * 1000.0])
	# wadis: from the highlands (the plateau's rim, or inland) meandering out past the coast
	L["wadis"] = []
	for i in range(rng.randi_range(d["wadis"][0], d["wadis"][1])):
		var a := rng.randf() * TAU
		var from := Vector2.from_angle(a) * r * rng.randf_range(0.12, 0.25)
		if not (L["plateau"] as Array).is_empty():
			from = (L["plateau"][0] as Vector2) + Vector2.from_angle(a) * float(L["plateau"][1]) * 0.9
		var to := Vector2.from_angle(a + rng.randf_range(-0.5, 0.5)) * (r + 40.0)
		L["wadis"].append(_line(_meander(from, to, rng, 5, 45.0), rng.randf_range(6.0, 10.0), rng.randf_range(2.2, 3.8)))
	# canyons: narrow and deep, the highlands to the sea
	L["canyons"] = []
	for i in range(rng.randi_range(d["canyons"][0], d["canyons"][1])):
		var a := rng.randf() * TAU
		var from := Vector2.from_angle(a) * r * rng.randf_range(0.3, 0.45)
		var to := Vector2.from_angle(a + rng.randf_range(-0.3, 0.3)) * (r + 40.0)
		L["canyons"].append(_line(_meander(from, to, rng, 4, 30.0), rng.randf_range(5.0, 9.0), rng.randf_range(8.0, 14.0)))
	# salt flats: low flat pans [centre, radius, level]
	L["salt"] = []
	for i in range(rng.randi_range(d["salt"][0], d["salt"][1])):
		L["salt"].append([Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.25, 0.55), rng.randf_range(35.0, 70.0), rng.randf_range(3.2, 4.2)])
	# oases: a hollow in palms [centre, radius] (its pool is a set piece's)
	L["oases"] = []
	for i in range(rng.randi_range(d["oases"][0], d["oases"][1])):
		L["oases"].append([Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.2, 0.6), rng.randf_range(22.0, 34.0)])
	return L


## [points, half width, height or depth, bounding rect grown past the width]
static func _line(pts: PackedVector2Array, w: float, h: float) -> Array:
	var rect := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		rect = rect.expand(q)
	return [pts, w, h, rect.grow(w * 2.0 + 12.0)]


static func _meander(from: Vector2, to: Vector2, rng: RandomNumberGenerator, n: int, wander: float) -> PackedVector2Array:
	var pts := PackedVector2Array([from])
	var side := (to - from).orthogonal().normalized()
	for k in range(1, n):
		pts.append(from.lerp(to, float(k) / n) + side * rng.randf_range(-wander, wander))
	pts.append(to)
	return pts


## Distance from p to a polyline (x) and how far along it (y, 0..1 by points).
static func _seg_dist(pts: PackedVector2Array, p: Vector2) -> Vector2:
	var best := INF
	var at := 0.0
	for j in range(pts.size() - 1):
		var a := pts[j]
		var ab := pts[j + 1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var dd := p.distance_to(a + ab * t)
		if dd < best:
			best = dd
			at = (j + t) / float(pts.size() - 1)
	return Vector2(best, at)


static func _sm(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## The ways the paths will take (dock to village, village to each site, straight) and the sites, worked out
## again whenever GenIsland has placed more of them: ridges part, mesas give way, canyons ford, dunes stay off.
func _ways(isl, L: Dictionary) -> void:
	var sites: Dictionary = isl.sites
	if int(L["sites_n"]) == sites.size():
		return
	L["sites_n"] = sites.size()
	var ways: Array = []
	if sites.has("village"):
		ways.append([sites["dock"], sites["village"]])
		for s in ["boss", "camp", "lair", "ruins", "summit"]:
			if sites.has(s):
				ways.append([sites["village"], sites[s]])
	L["ways"] = ways
	L["sites"] = sites.values()
	var keep_mesa: Array = []
	for m in L["mesas"]:
		var c: Vector2 = m[0]
		var ok := 1.0
		for q in L["sites"]:
			if c.distance_to(q) < float(m[1]) + 34.0:
				ok = 0.0
		for wy in ways:
			if _seg_dist(PackedVector2Array([wy[0], wy[1]]), c).x < float(m[1]) + 18.0:
				ok = 0.0
		keep_mesa.append(ok)
	L["keep_mesa"] = keep_mesa


static func _way_dist(L: Dictionary, p: Vector2) -> float:
	var best := INF
	for wy in L["ways"]:
		var a: Vector2 = wy[0]
		var ab: Vector2 = wy[1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


static func _site_dist(L: Dictionary, p: Vector2) -> float:
	var best := INF
	for q in L["sites"]:
		best = minf(best, p.distance_to(q))
	return best


func village_at(isl, p: Vector2) -> Vector2:
	var L: Dictionary = isl.land_plan
	if not L["capital"]:
		return p
	return (L["plateau"][0] as Vector2) + (L["plateau"][5] as Vector2) * float(L["plateau"][1]) * 0.25


func shape(isl, p: Vector2, h: float) -> float:
	var L: Dictionary = isl.land_plan
	_ways(isl, L)
	var k_in := _sm(1.0, 3.6, h)
	if k_in <= 0.0:
		return h
	var nz: FastNoiseLite = L["noise"]
	var add := 0.0
	# the plateau: a flat top, its rim steep but for gentle ramps toward the sites off it
	var pl: Array = L["plateau"]
	if not pl.is_empty():
		var pc: Vector2 = pl[0]
		var dv := p - pc
		var dist := dv.length()
		var pr: float = pl[1]
		if dist < pr * 1.3 + 30.0:
			var ang := atan2(dv.y, dv.x)
			var rr := pr * (1.0 + 0.14 * sin(3.0 * ang + float(pl[3])) + 0.07 * sin(7.0 * ang + float(pl[4])))
			var gentle := 0.0
			for q in L["sites"]:
				if (q as Vector2).distance_to(pc) > rr * 0.6:
					gentle = maxf(gentle, 1.0 - _sm(0.18, 0.45, absf(angle_difference(ang, ((q as Vector2) - pc).angle()))))
			var rim := lerpf(7.0, 42.0, gentle)
			add += float(pl[2]) * (1.0 - _sm(rr - rim * 0.5, rr + rim * 0.5, dist))
	# mesas (gone where a site or a way would be)
	var keep: Array = L["keep_mesa"]
	for i in range(keep.size()):
		var m: Array = L["mesas"][i]
		var mc: Vector2 = m[0]
		var mr: float = m[1]
		var dist := p.distance_to(mc)
		if keep[i] > 0.0 and dist < mr * 1.3 + 8.0:
			var dv := p - mc
			var ang := atan2(dv.y, dv.x)
			var rr := mr * (1.0 + 0.16 * sin(2.0 * ang + float(m[3])) + 0.08 * sin(5.0 * ang - float(m[3])))
			var rim: float = m[4]
			add += float(m[2]) * (1.0 - _sm(rr - rim * 0.5, rr + rim * 0.5, dist))
	# ridges: sharp crests, tapering at the ends, parting where a way crosses
	for rg in L["ridges"]:
		if not (rg[3] as Rect2).has_point(p):
			continue
		var sd := _seg_dist(rg[0], p)
		var w: float = rg[1]
		if sd.x < w:
			var crest := pow(1.0 - sd.x / w, 1.7) * float(rg[2]) * (0.6 + 0.2 * (nz.get_noise_2d(p.x * 3.0, p.y * 3.0) + 1.0))
			crest *= sin(sd.y * PI) * 0.6 + 0.4
			crest *= _sm(10.0, 26.0, _way_dist(L, p)) * _sm(28.0, 50.0, _site_dist(L, p))
			add += crest
	# dunes: a long stoss slope up to a sharp crest, a soft-footed slip face behind; off the sites and the wadis
	var dune := 0.0
	for f in L["dunes"]:
		var fc: Vector2 = f[0]
		var fr: float = f[1]
		var dist := p.distance_to(fc)
		if dist >= fr:
			continue
		var dir: Vector2 = f[2]
		var lam: float = f[3]
		var u := p.dot(dir) + nz.get_noise_2d(p.x * 0.6 + float(f[5]), p.y * 0.6) * lam * 0.9
		var ph := fposmod(u / lam, 1.0)
		var prof: float
		if ph < 0.7:
			var s := ph / 0.7
			prof = s * (2.0 - s) * 0.9 + s * 0.1
		else:
			prof = pow(1.0 - (ph - 0.7) / 0.3, 1.6)
		var amp := float(f[4]) * (0.55 + 0.45 * nz.get_noise_2d(p.x * 0.35 - float(f[5]), p.y * 0.35))
		dune = maxf(dune, prof * amp * (1.0 - _sm(fr * 0.6, fr, dist)))
	if dune > 0.0:
		dune *= _sm(40.0, 75.0, _site_dist(L, p))
		for wd in L["wadis"]:
			if (wd[3] as Rect2).has_point(p):
				dune *= _sm(float(wd[1]) + 6.0, float(wd[1]) + 30.0, _seg_dist(wd[0], p).x)
	var out := h + (add + dune) * k_in
	# salt flats: pans levelled low
	for s in L["salt"]:
		var sw := 1.0 - _sm(float(s[1]) * 0.7, float(s[1]), p.distance_to(s[0]))
		if sw > 0.0:
			out = lerpf(out, float(s[2]), sw * k_in)
	# oases: a hollow
	for o in L["oases"]:
		var od := p.distance_to(o[0])
		if od < float(o[1]):
			out -= 1.8 * (1.0 - _sm(0.0, float(o[1]), od)) * k_in
	# wadis and canyons: a flat bed between banks (a canyon's steep, forded where a way crosses)
	for wd in L["wadis"]:
		if (wd[3] as Rect2).has_point(p):
			var w: float = wd[1]
			out -= float(wd[2]) * (1.0 - _sm(w, w + 14.0, _seg_dist(wd[0], p).x))
	for cy in L["canyons"]:
		if (cy[3] as Rect2).has_point(p):
			var w: float = cy[1]
			out -= float(cy[2]) * (1.0 - _sm(w, w + 5.0, _seg_dist(cy[0], p).x)) * _sm(8.0, 26.0, _way_dist(L, p))
	# (inland stays land: GenIsland finds the dock by walking out until the ground drops under 0.4 m)
	if h > 1.2:
		out = maxf(out, 1.2)
	return out


## How green: the oases and the wadis' beds lush, dunes and the rest thinner than the base's noise.
func cover(isl, p: Vector2, c: float) -> float:
	var z := _zone(isl, p)
	return maxf(c * 0.35 * (1.0 - z.r), maxf(z.a, z.b * 0.7))


## [plants, rocks]: dunes and salt pans bare, stony on the ridges and mesas, rich in the oases and the wadis.
func growth(isl, p: Vector2) -> Vector2:
	var z := _zone(isl, p)
	var salt := _salt(isl.land_plan, p)
	var bare := 1.0 - _sm(0.25, 0.75, z.r)
	var plants := bare * (1.0 - z.g * 0.4) * (1.0 + z.b * 1.5 + z.a) * (1.0 - salt * 0.97)
	return Vector2(plants * 0.7, bare * (1.0 + z.g * 3.0) * (1.0 - salt * 0.8))


## Hardpan on the salt pans and the wadis' beds, rock on the ridges and the mesas.
func paint(isl, p: Vector2, _h: float, splat: Color) -> Color:
	var L: Dictionary = isl.land_plan
	var z := _zone(isl, p)
	var dirt := maxf(splat.r, _salt(L, p))
	for wd in L["wadis"]:
		if (wd[3] as Rect2).has_point(p):
			dirt = maxf(dirt, (1.0 - _sm(float(wd[1]) * 0.6, float(wd[1]) + 3.0, _seg_dist(wd[0], p).x)) * 0.75)
	var rock := maxf(splat.g, _sm(0.45, 0.8, z.g) * (1.0 - dirt))
	return Color(dirt * (1.0 - rock), rock, splat.b * (1.0 - dirt) * (1.0 - rock), 1.0)


static func _salt(L: Dictionary, p: Vector2) -> float:
	var k := 0.0
	for s in L["salt"]:
		k = maxf(k, 1.0 - _sm(float(s[1]) * 0.75, float(s[1]) * 0.95, p.distance_to(s[0])))
	return k


## The island's zones on a ZONE_CELL grid (worked out on first use, once the sites are placed):
## r dunes, g rock (ridges, mesas; the plateau's steep rim is the terrain shader's slope rock), b the wadis' beds, a the oases.
const ZONE_CELL := 8.0


func _zone(isl, p: Vector2) -> Color:
	var L: Dictionary = isl.land_plan
	if not L.has("zones"):
		_zones(isl, L)
	var n: int = L["zones_n"]
	var half: float = isl.half
	var fx := clampf((p.x + half) / ZONE_CELL, 0.0, n - 1.001)
	var fz := clampf((p.y + half) / ZONE_CELL, 0.0, n - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var z: PackedColorArray = L["zones"]
	var a := z[iz * n + ix].lerp(z[iz * n + ix + 1], fx - ix)
	var b := z[(iz + 1) * n + ix].lerp(z[(iz + 1) * n + ix + 1], fx - ix)
	return a.lerp(b, fz - iz)


func _zones(isl, L: Dictionary) -> void:
	_ways(isl, L)
	var half: float = isl.half
	var n := int(half * 2.0 / ZONE_CELL) + 2
	var z := PackedColorArray()
	z.resize(n * n)
	for iz in range(n):
		for ix in range(n):
			var p := Vector2(-half + ix * ZONE_CELL, -half + iz * ZONE_CELL)
			var dune := 0.0
			for f in L["dunes"]:
				dune = maxf(dune, 1.0 - _sm(float(f[1]) * 0.55, float(f[1]) * 0.95, p.distance_to(f[0])))
			if dune > 0.0:
				dune *= _sm(40.0, 75.0, _site_dist(L, p))
			var rock := 0.0
			for rg in L["ridges"]:
				if (rg[3] as Rect2).has_point(p):
					rock = maxf(rock, 1.0 - _sm(float(rg[1]) * 0.3, float(rg[1]) * 1.1, _seg_dist(rg[0], p).x))
			for i in range((L["mesas"] as Array).size()):
				var m: Array = L["mesas"][i]
				if L["keep_mesa"][i] > 0.0:
					rock = maxf(rock, 1.0 - _sm(float(m[1]) * 0.9, float(m[1]) + 10.0, p.distance_to(m[0])))
			var bed := 0.0
			for wd in L["wadis"]:
				if (wd[3] as Rect2).has_point(p):
					bed = maxf(bed, 1.0 - _sm(float(wd[1]), float(wd[1]) + 12.0, _seg_dist(wd[0], p).x))
			var oasis := 0.0
			for o in L["oases"]:
				oasis = maxf(oasis, 1.0 - _sm(float(o[1]) * 0.8, float(o[1]) + 14.0, p.distance_to(o[0])))
			z[iz * n + ix] = Color(dune * (1.0 - oasis), rock, bed, oasis)
	L["zones"] = z
	L["zones_n"] = n
