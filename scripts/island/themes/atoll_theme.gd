extends ThemeDef
## The coral atolls (docs/v1_28_plan.md "Islands", 1.28): a ring of low islets and sandbars round a calm, shallow,
## turquoise lagoon (atoll_land.gd). You wade the sandbars and swim the passes between the islets; outside the ring a
## reef flat drops off to the deep. Coconut palms on every islet, screw pines, salt scrub and spider lilies, coral
## rubble at the waterline (AtollPlants). Its town is a stilt town over the lagoon (atoll_town.gd: boardwalks, huts on
## piles, fishing platforms) beside a village on stilts; its reef has wrecks, pearl beds and a blue hole to dive. The
## chain's best fishing: its spots are AtollSpots' (groups "fishing_spots" and "spear_spots"). Rolled apart like the
## fog isle, from the chain's second layer on.

const D := preload("res://scripts/island/themes/atoll_data.gd")

## Land (the jungle's keys, jungle_theme.gd). The mesh slots: "giant" tall palms (the "fig", "kapok" and "emergent"
## too), "roof" palm crowns; "tree" coconut palms and screw pines, "beach_tree" palms leaning out over the water,
## "bamboo" screw pine clumps, "bush" salt scrub, "fern" spider lilies, "grass" beach grass, "shrub" sprouting coconuts,
## "broadleaf" driftwood and beach litter, "mangrove" coral rubble at the waterline, "rock" coral boulders. The ring
## and the lagoon are the land's own (atoll_land.gd): the base stays low and flat under them.
const LAND := {
	"peak": [0.2, 0.6], "hills": [0, 0], "hill_h": [0.0, 0.0], "roll": 0.6, "base": D.BASE,
	"ramp": [30.0, 40.0], "cliffs": [0, 0], "cliff_h": [2.0, 3.0],
	"tree": 0.3, "edge": 0.1, "beach_tree": 0.42, "fern": 0.14, "bush": 0.22, "grass": 0.32, "rock": 0.03,
	"cover": 0.62,
	"canopy": 0.1, "giants": {"giant": 3.0, "fig": 1.0, "kapok": 0.5, "emergent": 0.5},
	"bamboo": 0.06, "palm_inland": 0.12, "mangrove": 0.05,
	"broadleaf": 0.06, "shrub": 0.1, "floor": 0.12, "overgrown": 0.15,
	"forests": [
		["palm islets", {}],
		["coconut groves", {"tree": 0.42, "canopy": 0.18, "beach_tree": 0.5, "shrub": 0.16}],
		["screw pine scrub", {"bamboo": 0.16, "bush": 0.34, "tree": 0.18, "beach_tree": 0.3}],
		["windswept cays", {"cover": 0.4, "tree": 0.16, "beach_tree": 0.3, "grass": 0.46, "broadleaf": 0.12}],
		["lily strands", {"fern": 0.3, "grass": 0.26, "bush": 0.18}],
	],
}

const LAND_FEATURES := preload("res://scripts/island/themes/atoll_land.gd")
const TOWN := preload("res://scripts/island/themes/atoll_town.gd")
const PLACES := preload("res://scripts/island/themes/atoll_places.gd")

## The settlement style over KitStyle.BRINEHOLLOW: huts of woven palm and bamboo on stilts under palm thatch, rope
## lashings, torches on bamboo poles; bright cloth against white sand and the lagoon's turquoise.
const STYLE := {
	"lamp": Color(1.0, 0.72, 0.4),
	"lamp_range": 11.0,
	"paving": "atoll_sand",
	"quay_wall": Color(0.86, 0.82, 0.72),
	"quay_cope": Color(0.78, 0.74, 0.64),
	"iron": Color(0.3, 0.26, 0.22),
	"row_walls": ["woven", "bamboo", "planks_weathered", "woven", "bamboo"],
	"row_upper": ["woven", "bamboo", "planks_weathered"],
	"row_roofs": ["hip", "gable", "hip", "gable_front"],
	"row_roof_tex": ["palm_thatch", 1.0, "palm_thatch"],
	"row_awnings": ["", "blue", "", "green", ""],
	"pennants": [Color(0.95, 0.4, 0.3), Color(0.2, 0.62, 0.72), Color(0.98, 0.82, 0.3), Color(0.92, 0.9, 0.84), Color(0.3, 0.6, 0.36)],
	"washing": [Color(0.94, 0.92, 0.86), Color(0.45, 0.72, 0.82), Color(0.92, 0.5, 0.38), Color(0.95, 0.85, 0.5), Color(0.5, 0.75, 0.55)],
	"rugs": [["woven", Color(0.95, 0.88, 0.75)], ["cloth_blue", Color(0.9, 0.95, 0.95)]],
	"goods": [Color(0.95, 0.9, 0.82), Color(0.9, 0.5, 0.4), Color(0.55, 0.42, 0.26), Color(0.4, 0.7, 0.75), Color(0.95, 0.75, 0.3)],
	"tent": Color(0.94, 0.9, 0.8),
	"camp_tent": Color(0.66, 0.6, 0.48),
	"rough": {"flowers": false, "trim": Color(0.4, 0.34, 0.26), "wall": "woven", "roof_tex": "palm_thatch", "beam": "palm_bark", "pitch": 0.75, "eaves": 0.7,
		"poles": true, "lashings": true},
	"crew_flag": Color(0.2, 0.55, 0.65),
	"pirate_flag": Color(0.12, 0.12, 0.14),
	"high_birds": "dark",
	"ambient_bugs": true,
	"mat": {"wall": "woven", "beam": "palm_bark", "floor": "planks", "deck": "planks_weathered", "post": "palm_bark",
		"rail": "bamboo", "roof": "palm_thatch", "thatch": "palm_thatch", "rope": "rope", "stone": "atoll_coral", "cloth": "canvas",
		"weave": "woven"},
	"house": {"w": [4.6, 6.2], "d": [4.0, 5.2], "h": [2.4, 2.8], "walls": ["woven", "woven", "bamboo", "planks_weathered"],
		"roofs": ["hip", "gable", "hip"], "roof_tex": ["palm_thatch", "palm_thatch", "palm_thatch"], "pitch": [0.7, 0.9], "eaves": 0.8,
		"beam": "palm_bark", "floor": "planks", "poles": true, "lashings": true, "stilts": true,
		"porch": [0.6, 1.2, 2.0], "flowers": 0.4, "chimney": 0.0,
		"trims": [Color(0.2, 0.55, 0.65), Color(0.85, 0.4, 0.3), Color(0.95, 0.8, 0.35), Color(0.9, 0.88, 0.8), Color(0.3, 0.55, 0.35)]},
	"inn": {"w": 9.0, "d": 7.0, "h": 3.0, "roof": "hip", "wall": "woven", "porch": 2.4, "flowers": true},
	"stall": {"canopies": ["cloth_blue", "canvas", "cloth_red"], "post": "palm_bark"},
	"pier": {"deck": "planks_weathered", "post": "palm_bark", "rail": "bamboo", "lashings": true, "rope_rail": true},
	"props": {"crate": "atoll_basket", "barrel": "atoll_pot", "lamp": "atoll_torch", "marker": "notice_board"},
	"yard_fences": 0.05,
	"vendors_always": [],
	"village_layouts": {"town": 0, "hamlets": 1, "post": 2, "stilts": 5, "ruins": 0, "medina": 0},
	"folk": {
		"pick": {"skin": [Color(0.84, 0.66, 0.5), Color(0.72, 0.54, 0.4), Color(0.62, 0.44, 0.3), Color(0.52, 0.36, 0.24), Color(0.4, 0.27, 0.18)],
			"hair_color": [Color(0.1, 0.08, 0.07), Color(0.18, 0.12, 0.08), Color(0.36, 0.22, 0.12), Color(0.12, 0.1, 0.1), Color(0.8, 0.78, 0.72)],
			"hat": ["none", "none", "none", "bandana", "straw"], "hat_fem": ["none", "none", "bandana"],
			"top": ["shirt", "bare", "tunic", "shirt"], "top_fem": ["blouse", "tunic", "blouse"], "sleeves": ["short", "short", "none"],
			"vest": ["none", "none", "vest"], "coat": ["none"],
			"legs": ["slops", "shorts", "trousers"], "legs_fem": ["skirt", "skirt", "slops"], "feet": ["barefoot", "barefoot", "sandals"],
			"belt": ["sash", "belt", "sash"], "gloves": [false],
			"top_color": [Color(0.94, 0.92, 0.86), Color(0.45, 0.72, 0.82), Color(0.92, 0.5, 0.38), Color(0.95, 0.85, 0.5), Color(0.3, 0.55, 0.45)],
			"vest_color": [Color(0.55, 0.42, 0.26), Color(0.2, 0.4, 0.5)],
			"coat_color": [Color(0.5, 0.4, 0.3)],
			"legs_color": [Color(0.86, 0.82, 0.7), Color(0.3, 0.45, 0.6), Color(0.62, 0.5, 0.34), Color(0.8, 0.45, 0.32)],
			"hat_color": [Color(0.92, 0.84, 0.6), Color(0.2, 0.55, 0.65), Color(0.85, 0.4, 0.3)]},
		"set": {"eyepatch": false, "scarf": false},
	},
	"music": "atoll",
	"music_town": "atoll_town",
	"ambience": "atoll",
	"ground": {"grass": "atoll_turf", "sand": "atoll_sand", "wet_sand": "atoll_sand", "dirt": "atoll_sand", "rock": "atoll_coral",
		"seafloor": "atoll_seafloor", "cliff": "atoll_coral"},
	"ground_prints": "sand",
	"arena": "open",
	"cave_look": {"rock": ["atoll_coral", Color(1.0, 1.0, 1.0)], "moss": ["atoll_turf", Color(0.9, 0.95, 0.88)], "turf": ["atoll_turf", Color.WHITE],
		"wall": ["atoll_coral", Color(0.85, 0.85, 0.8)], "floor": ["atoll_sand", Color(0.9, 0.88, 0.84)]},
	# bright and fair most days, a squall now and then, a storm rarely; a sea-blue haze
	"weather": [0.5, 0.78, 0.94],
	"haze": 0.1,
	"haze_color": Color(0.6, 0.82, 0.92, 0.35),
	"storm_color": Color(0.32, 0.38, 0.44),
	"rock_tint": Color(0.82, 0.78, 0.68),
	"moss_tint": Color(0.55, 0.68, 0.45),
	"temple_stone": Color(0.82, 0.78, 0.68),
	"fort_stone": Color(0.8, 0.76, 0.66),
	"water_tint": Color(0.3, 0.72, 0.74, 0.8),
	"falls_tint": Color(0.82, 0.94, 0.96, 0.85),
	"spring_tint": Color(0.45, 0.8, 0.8, 0.85),
	"travertine": Color(0.92, 0.88, 0.76),
	"wreck_hull": Color(0.6, 0.55, 0.46),
	"bone": Color(0.94, 0.9, 0.82),
	"basalt": Color(0.5, 0.48, 0.44),
	"lava": Color(1.0, 0.5, 0.2),
	"crystal": Color(0.6, 0.9, 1.0),
	"rust": Color(0.5, 0.32, 0.2),
	"harbour_kinds": ["stilts", "stilts", "cove", "wharf"],
	"harbour_wild_kinds": ["landing", "stilts", "cove"],
	"harbour_pile": "palm_bark",
	"harbour_deck": "planks_weathered",
	"harbour_roof": "palm_thatch",
	"harbour_walls": ["woven", "bamboo", "planks_weathered"],
	"harbour_tarp": Color(0.86, 0.82, 0.7),
	"harbour_floats": [Color(0.95, 0.4, 0.3), Color(0.98, 0.82, 0.3), Color(0.92, 0.9, 0.84)],
	"harbour_signal": Color(1.0, 0.7, 0.35),
}

## Each kind: its zones, how likely an island has it, how many groups. Crabs everywhere on the sand, monitor lizards
## basking on the islets, sea snakes in the shallows, bats in its few caves.
## Coconut crabs up under the palms, boobies nesting in the crowns ("toucan": the perching birds' slot, FaunaSpawner).
const FAUNA := {
	"crab": {"zones": ["shore"], "p": 0.98, "dens": [6, 10]},
	"coconut_crab": {"zones": ["floor"], "p": 0.85, "dens": [3, 6], "pack": [1, 2], "young": 0.3},
	"toucan": {"zones": ["canopy"], "p": 0.8, "dens": [2, 5]},
	"lizard": {"zones": ["floor"], "p": 0.5, "dens": [2, 4], "pack": [1, 2], "young": 0.4},
	"snake": {"zones": ["shore", "floor"], "p": 0.45, "dens": [1, 3]},
	"bat": {"zones": ["cave"], "p": 0.6, "dens": [1, 3]},
	"mite": {"zones": ["cave"], "p": 0.3, "dens": [1, 2]},
}
const CREATURES := {
	"crab": "res://scripts/enemies/fauna/crab.gd",
	"coconut_crab": "res://scripts/enemies/fauna/atoll_coconut_crab.gd",
	"toucan": "res://scripts/enemies/fauna/atoll_booby.gd",
	"lizard": "res://scripts/enemies/fauna/monitor_lizard.gd",
	"snake": "res://scripts/enemies/fauna/snake.gd",
	"bat": "res://scripts/enemies/fauna/bat.gd",
	"mite": "res://scripts/enemies/fauna/swarm_mite.gd",
}


func _init() -> void:
	name = "atoll"
	display = "Coral Atoll"
	blurb = "a ring of palm islets round a turquoise lagoon"
	island_names = ["Pearlring", "Saltlagoon", "Coralhaven", "Sandbar Key", "Lantern Atoll", "Brightwater", "Shellcay", "Palmcrown", "Tidewell", "Blue Hollow"]
	# (rolled apart: its own chance on a regular island, from the second layer on; every other island stays as it was)
	weight = D.WEIGHT
	apart = true
	from_layer = D.FROM_LAYER
	color = Color(0.3, 0.85, 0.85)
	glyph = _glyph
	flocks = 0
	land = LAND
	radius = D.RADIUS
	style = STYLE
	props = {
		"atoll_basket": func(rng: RandomNumberGenerator, size: float) -> Node3D: return JungleProps.basket(0.8 * size, rng.randi()),
		"atoll_pot": func(rng: RandomNumberGenerator, size: float) -> Node3D: return JungleProps.pot(size, rng.randi()),
		"atoll_torch": func(_rng: RandomNumberGenerator, size: float) -> Node3D: return JungleProps.torch_post(2.4 * size),
	}
	life = preload("res://scripts/island/themes/atoll_life.gd").TEXT
	encounters = preload("res://scripts/island/themes/atoll_encounters.gd").TEXT
	bosses = ["hermit_crab"]
	minis = ["salt_croc"]
	roamers = ["tidemaw"]
	beasts = {
		"hermit_crab": {"script": "res://scripts/enemies/beasts/atoll_hermit.gd", "names": ["The Shell King", "Old Wreckback", "The Tide Hermit", "Barnaclehouse"], "looks": 3,
			"banner": ["The Tidal Flat", "The flat is scored with furrows and littered with smashed shell. Out in the middle, something's house is moving."]},
		"salt_croc": {"script": "res://scripts/enemies/beasts/atoll_croc.gd", "names": ["Old Saltjaw", "The Lagoon Croc", "Bonecrusher", "Mangrove Mother"], "site": "lair"},
		"tidemaw": {"script": "res://scripts/enemies/beasts/atoll_tidemaw.gd", "names": ["The Tidemaw", "Old Barnacle", "The Reef Grazer"]},
	}
	arena_dress = _dress_flat
	fauna = FAUNA
	creatures = CREATURES
	cave_fauna = {"ceiling": "bat", "floor": ["mite", "snake", "crab"]}


## The land (atoll_land.gd): the ring, the sandbars and passes, the lagoon, its causeway and blue hole.
func plan_land(isl, rng: RandomNumberGenerator) -> Dictionary:
	return LAND_FEATURES.plan(isl, rng)


func shape(isl, p: Vector2, h: float) -> float:
	return LAND_FEATURES.shape(isl, p, h)


func village_at(isl, p: Vector2) -> Vector2:
	return LAND_FEATURES.village_at(isl, p)


func site_at(isl, site: String, p: Vector2) -> Vector2:
	return LAND_FEATURES.site_at(isl, site, p)


func route(isl, site: String, pts: Array) -> Array:
	return LAND_FEATURES.route(isl, site, pts)


func cover(isl, p: Vector2, c: float) -> float:
	return LAND_FEATURES.cover(isl, p, c)


func growth(isl, p: Vector2) -> Vector2:
	return LAND_FEATURES.growth(isl, p)


func paint(isl, p: Vector2, h: float, splat: Color) -> Color:
	return LAND_FEATURES.paint(isl, p, h, splat)


func steps(isl) -> Array:
	return LAND_FEATURES.steps(isl)


## The stilt town out over the lagoon (atoll_town.gd). (The big lagoon islet is kept for the caves: KitDungeons plans
## after the places, and nowhere else on an atoll has the room.)
func plan_places(isl, avoid: Array) -> Array:
	var big: Array = isl.land_plan["motu"][0]
	avoid.append([big[0], float(big[1])])
	return TOWN.plan_places(isl, avoid)


## The chain's set pieces become the reef's (atoll_places.gd): a wreck on the reef flat, a pearl bed, the blue hole.
func place_kind(kind: String) -> String:
	return PLACES.KINDS.get(kind, "")


func plan_place(isl, kind: String, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	return PLACES.plan(isl, kind, rng, avoid)


func place_steps(isl, ctx, pl: Dictionary) -> Array:
	if str(pl["kind"]) == TOWN.KIND:
		return TOWN.steps(isl, ctx, pl)
	return PLACES.steps(isl, ctx, pl)


func meshes() -> Dictionary:
	return {
		"tree": [AtollPlants.coconut_palm(1401), AtollPlants.coconut_palm(1402), AtollPlants.coconut_palm(1403), AtollPlants.pandanus(1404), AtollPlants.pandanus(1405)],
		"beach_tree": [AtollPlants.coconut_palm(1411, true), AtollPlants.coconut_palm(1412, true), AtollPlants.coconut_palm(1413, true)],
		"bush": [AtollPlants.scrub(1421), AtollPlants.scrub(1422)],
		"fern": [AtollPlants.lily(1431), AtollPlants.lily(1432)],
		"grass": [AtollPlants.grass()],
		"rock": [AtollPlants.coral_rock(1441), AtollPlants.coral_rock(1442), AtollPlants.coral_rock(1443, 1.3)],
		# big trees: [body, detail, lean]
		"giant": [AtollPlants.tall_palm(1451), AtollPlants.tall_palm(1452), AtollPlants.tall_palm(1453)],
		"fig": [AtollPlants.tall_palm(1455)],
		"kapok": [AtollPlants.tall_palm(1457)],
		"emergent": [AtollPlants.tall_palm(1458)],
		"roof": [AtollPlants.crown_roof(1461)],
		"mangrove": [AtollPlants.rubble(1471), AtollPlants.rubble(1472)],
		"bamboo": [AtollPlants.pandanus_clump(1475), AtollPlants.pandanus_clump(1476)],
		"broadleaf": [AtollPlants.driftwood(1481), AtollPlants.beach_litter(1482), AtollPlants.driftwood(1483)],
		"shrub": [AtollPlants.sprout(1491), AtollPlants.sprout(1492)],
	}


## The hermit crab's tidal flat (ThemeDef.arena_dress): tide pools left in its hollows, its ground scored in furrows
## by the crab's legs, smashed shell and coral rubble everywhere, a stove-in canoe and driftwood at the edge.
## Arena-local (the floor's middle at 0, its ground y0).
static func _dress_flat(arena, body: StaticBody3D, mb: MeshBuilder, rng: RandomNumberGenerator, c: Vector2, y0: float) -> void:
	var isl = arena.isl
	var r := float(BeastArena.FLOOR_R)
	var gy := func(q: Vector2) -> float: return float(isl.hv(c + q)) - y0
	var pool := PSXMat.lit("atoll_seafloor", Color(0.5, 0.82, 0.86))
	var shell := PSXMat.lit("atoll_coral", Color(1.15, 1.08, 1.0))
	var furrow := PSXMat.flat(Color(0.58, 0.52, 0.4))
	for k in range(6):
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(r * 0.35, r - 3.0)
		KitLandmarks.water_disc(mb, pool, Vector3(q.x, float(gy.call(q)) + 0.03, q.y), rng.randf_range(1.2, 2.6), 10, 0.3)
	for k in range(9):
		var a := rng.randf() * TAU
		var p0 := Vector2.from_angle(a) * rng.randf_range(2.0, r - 4.0)
		var dir := Vector2.from_angle(a + rng.randf_range(-0.6, 0.6))
		var ln := rng.randf_range(2.5, 5.0)
		for s in [-0.35, 0.35]:
			var o: Vector2 = dir.orthogonal() * s
			var w: Vector2 = dir.orthogonal() * 0.08
			var pa: Vector2 = p0 + o
			var pb: Vector2 = p0 + o + dir * ln
			var ya := float(gy.call(pa)) + 0.03
			var yb := float(gy.call(pb)) + 0.03
			mb.add_quad(furrow, Vector3(pa.x - w.x, ya, pa.y - w.y), Vector3(pa.x + w.x, ya, pa.y + w.y), Vector3(pb.x + w.x, yb, pb.y + w.y), Vector3(pb.x - w.x, yb, pb.y - w.y),
				Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, Vector3.UP)
	for k in range(40):
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.0, r + 2.0)
		var s := rng.randf_range(0.1, 0.35)
		mb.add_blob(shell, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.6, 0.6)), Vector3(q.x, float(gy.call(q)) + s * 0.2, q.y)),
			Vector3(s * 1.3, s * 0.5, s), rng, 0.35, 2, 5, 0.5, Color.WHITE.lerp(Color(1.0, 0.7, 0.62), rng.randf() * 0.6))
	for k in range(3):
		var a := rng.randf() * TAU
		var q := Vector2.from_angle(a) * (r + rng.randf_range(1.0, 3.0))
		var at := Vector3(q.x, float(gy.call(q)), q.y)
		mb.add_tube(PSXMat.lit("planks_grey", Color(1.1, 1.05, 0.95)), PackedVector3Array([at + Vector3(-1.4, 0.2, 0).rotated(Vector3.UP, a), at + Vector3(1.4, 0.25, 0.2).rotated(Vector3.UP, a)]), 0.22, 0.16, 6, 0.8)
		KitLandmarks.box_col_xf(body, Vector3(2.8, 0.4, 0.5), Transform3D(Basis(Vector3.UP, -a), at + Vector3.UP * 0.2))


## An atoll: a ring with a gap, a palm on it.
static func _glyph(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	ci.draw_arc(p, s * 0.75, 0.5, TAU - 0.2, 10, col, 1.0)
	var foot := p + Vector2(s * 0.55, -s * 0.5)
	var top := foot + Vector2(s * 0.15, -s * 0.5)
	ci.draw_line(foot, top, col, 1.0)
	for a in [-2.6, -1.6, -0.6]:
		ci.draw_line(top, top + Vector2(cos(a), sin(a) + 0.8) * s * 0.4, col, 1.0)
