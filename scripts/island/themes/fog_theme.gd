extends ThemeDef
## The fog isles (docs/v1_20_plan.md, 1.20): a haunted grey isle under fog that never quite lifts. Dead woods of
## giant trees twisting up like wrung rope, gnarled giants snaking their limbs along the ground; moor and peat, a grey
## shingle strand; a cursed fishing village keeping its lanterns lit against the fog and what walks in it - the
## drowned up out of the bay, ghosts among the dead trees, a wreck in the bay whose captain never left her. Its
## plants are FogPlants, its land the forest's (forest_land.gd: rolling ground, slow black rivers), its people's
## text fog_life.gd. Ghosts take no harm from shot; the drowned shrug most of it off.

## Land (the jungle's keys, jungle_theme.gd; the forest's own: roll_h, rivers, river_w, falls). The mesh slots:
## "giant" spiral giants, "fig" gnarled giants, "kapok" both, "emergent" more spiral giants; "tree" crooked snags and
## a dark living fir now and then; "beach_tree" snags and a shore pine; "shrub" dead whips, "bush" brambles,
## "fern" withered bracken, "grass" pale dead grass, "broadleaf" fallen logs, stumps and pale caps, "bamboo"
## stumps and caps, "mangrove" cattails in the black water, "rock" dark lichened stones. The woods are deep and dark
## (Zach, 2026-10-24: "big spooky forests"), the moor and the fog the open ground between.
const LAND := {
	"peak": [22.0, 34.0], "hills": [3, 6], "hill_h": [6.0, 13.0], "roll": 4.0, "base": 3.8,
	"ramp": [30.0, 50.0], "cliffs": [1, 3], "cliff_h": [8.0, 15.0],
	"tree": 0.3, "edge": 0.12, "beach_tree": 0.1, "fern": 0.36, "bush": 0.26, "grass": 0.46, "rock": 0.05,
	"cover": 0.6,
	"canopy": 0.75, "giants": {"giant": 4.0, "fig": 2.4, "kapok": 0.8, "emergent": 1.6},
	"bamboo": 0.05, "palm_inland": 0.0, "mangrove": 0.12,
	"broadleaf": 0.14, "shrub": 0.2, "floor": 0.3, "overgrown": 0.2,
	"roll_h": [4.0, 8.0], "rivers": [1, 2], "river_w": [6.0, 9.0], "falls": 0.25,
	"forests": [
		["dead wood", {}],
		["gnarled hollows", {"giants": {"giant": 1.0, "fig": 6.0, "kapok": 2.0, "emergent": 0.4}, "mangrove": 0.2, "rivers": [2, 3], "river_w": [8.0, 11.0]}],
		["the twisted wood", {"giants": {"giant": 4.0, "fig": 0.4, "kapok": 0.2, "emergent": 2.0}, "canopy": 0.9, "tree": 0.36, "grass": 0.52}],
		["bare moor", {"canopy": 0.28, "tree": 0.18, "grass": 0.6, "rock": 0.08, "bush": 0.32, "roll_h": [6.0, 10.0]}],
	],
}

const LAND_FEATURES := preload("res://scripts/island/themes/forest_land.gd")
const PLACES := preload("res://scripts/island/themes/fog_places.gd")

## The settlement style over KitStyle.BRINEHOLLOW: weathered grey plank cottages under black shingles, a lamp at every
## door, grey nets and grey washing, iron and old rope; the fog thick on every roll.
const STYLE := {
	"lamp": Color(1.0, 0.78, 0.5),
	"lamp_range": 12.0,
	"paving": "river_cobbles",
	"quay_wall": Color(0.5, 0.52, 0.52),
	"quay_cope": Color(0.44, 0.46, 0.46),
	"iron": Color(0.16, 0.16, 0.17),
	"row_walls": ["planks_weathered", "plaster_wash", "planks_dark", "planks_weathered", "stone_brick"],
	"row_upper": ["planks_weathered", "planks_dark", "plaster_wash"],
	"row_roofs": ["gable", "gable_front", "gable", "gable_front"],
	"row_roof_tex": ["shingles", 1.0, "shingles"],
	"row_awnings": ["", "", "", "", ""],
	"pennants": [Color(0.42, 0.44, 0.44), Color(0.62, 0.6, 0.54), Color(0.26, 0.3, 0.3), Color(0.72, 0.7, 0.62), Color(0.36, 0.22, 0.2)],
	"washing": [Color(0.78, 0.77, 0.72), Color(0.5, 0.52, 0.52), Color(0.36, 0.38, 0.4), Color(0.62, 0.58, 0.5), Color(0.44, 0.4, 0.38)],
	"rugs": [["canvas", Color(0.6, 0.6, 0.56)], ["cloth_blue", Color(0.55, 0.58, 0.6)]],
	"goods": [Color(0.7, 0.68, 0.6), Color(0.46, 0.48, 0.44), Color(0.58, 0.5, 0.36), Color(0.82, 0.8, 0.74), Color(0.36, 0.4, 0.36)],
	"tent": Color(0.6, 0.6, 0.56),
	"camp_tent": Color(0.4, 0.4, 0.38),
	"rough": {"flowers": false, "trim": Color(0.22, 0.22, 0.22), "wall": "planks_weathered", "roof_tex": "shingles", "beam": "planks_dark", "pitch": 0.85, "eaves": 0.5},
	"crew_flag": Color(0.4, 0.42, 0.4),
	"pirate_flag": Color(0.12, 0.12, 0.12),
	"crew_script": "res://scripts/enemies/drowned.gd",
	"ghost_script": "res://scripts/enemies/ghost.gd",
	"ghost_share": 0.35,
	"high_birds": "dark",
	"ambient_bugs": false,
	"mat": {"wall": "planks_weathered", "beam": "planks_dark", "floor": "planks", "deck": "planks_weathered", "post": "planks_dark",
		"rail": "planks_dark", "roof": "shingles", "thatch": "shingles", "rope": "rope", "stone": "stone_brick", "cloth": "canvas",
		"weave": "straw"},
	"house": {"w": [4.6, 6.4], "d": [4.0, 5.2], "h": [2.4, 2.8], "walls": ["planks_weathered", "planks_weathered", "plaster_wash", "planks_dark", "stone_brick"],
		"roofs": ["gable", "gable_front", "gable"], "roof_tex": ["shingles"], "pitch": [0.85, 1.05], "eaves": 0.45,
		"beam": "planks_dark", "floor": "planks", "poles": false, "lashings": false, "stilts": false,
		"porch": [0.35, 1.0, 1.6], "flowers": 0.0, "chimney": 0.8,
		"trims": [Color(0.24, 0.26, 0.28), Color(0.4, 0.42, 0.4), Color(0.3, 0.2, 0.18), Color(0.62, 0.6, 0.54), Color(0.18, 0.2, 0.22)]},
	"inn": {"w": 8.5, "d": 6.6, "h": 2.8, "roof": "gable", "wall": "planks_dark", "porch": 2.0, "flowers": false},
	"stall": {"canopies": ["canvas", "cloth_blue", "canvas"], "post": "planks_dark"},
	"pier": {"deck": "planks_weathered", "post": "planks_dark", "rail": "planks_dark", "lashings": false, "rope_rail": true},
	"props": {"crate": "crate", "barrel": "barrel", "lamp": "lantern_post", "marker": "notice_board"},
	# (the forest town's buildings: log cabins and timber houses under shingles, a shed, a store, a shrine for the chapel)
	"village_models": {"hut": "fog_cabin", "tall": "fog_timber_house", "workshop": "fog_workshop", "storehouse": "fog_store",
		"shrine": "fog_shrine"},
	"item_models": {"fence": "fog_fence", "woodpile": "fog_woodpile"},
	"yard_fences": 0.3,
	"village_layouts": {"town": 2, "hamlets": 3, "post": 2, "stilts": 1, "ruins": 2, "medina": 0},
	"folk": {
		"pick": {"skin": [Color(0.92, 0.82, 0.74), Color(0.86, 0.74, 0.64), Color(0.8, 0.68, 0.56), Color(0.7, 0.56, 0.44), Color(0.56, 0.42, 0.32)],
			"hair_color": [Color(0.2, 0.18, 0.16), Color(0.36, 0.3, 0.26), Color(0.62, 0.6, 0.56), Color(0.82, 0.8, 0.76), Color(0.44, 0.24, 0.14), Color(0.12, 0.1, 0.09)],
			"hat": ["knit", "hood", "cap", "none", "none", "slouch"], "hat_fem": ["hood", "coif", "knit", "none"],
			"top": ["shirt", "tunic", "shirt"], "top_fem": ["blouse", "tunic", "shirt"], "sleeves": ["long", "long", "long", "short"],
			"vest": ["vest", "none", "none", "jerkin"], "coat": ["none", "jacket", "duster", "none"],
			"legs": ["trousers", "breeches"], "legs_fem": ["skirt", "skirt", "trousers"], "feet": ["boots", "tall_boots", "boots"],
			"belt": ["belt", "belt", "wide_belt"], "scarf": [false, true, true],
			"top_color": [Color(0.7, 0.68, 0.62), Color(0.42, 0.44, 0.44), Color(0.3, 0.32, 0.34), Color(0.56, 0.52, 0.46), Color(0.22, 0.24, 0.26)],
			"vest_color": [Color(0.24, 0.24, 0.24), Color(0.34, 0.3, 0.26), Color(0.3, 0.32, 0.3)],
			"coat_color": [Color(0.22, 0.22, 0.24), Color(0.34, 0.34, 0.32), Color(0.28, 0.24, 0.2), Color(0.46, 0.44, 0.4)],
			"legs_color": [Color(0.22, 0.2, 0.18), Color(0.28, 0.28, 0.28), Color(0.34, 0.3, 0.26), Color(0.2, 0.22, 0.24)],
			"hat_color": [Color(0.3, 0.3, 0.3), Color(0.44, 0.42, 0.38), Color(0.22, 0.24, 0.26), Color(0.5, 0.2, 0.16)],
			"scarf_color": [Color(0.5, 0.2, 0.16), Color(0.4, 0.42, 0.42), Color(0.62, 0.6, 0.54)]},
		"set": {"eyepatch": false, "gloves": false},
	},
	"music": "forest_night",
	"music_town": "village_night",
	"ambience": "forest",
	"ground": {"grass": "fog_moor", "sand": "fog_beach", "wet_sand": "shingle_wet", "dirt": "fog_mud", "rock": "fog_rock", "seafloor": "seafloor", "cliff": "fog_rock"},
	"arena": "open",
	"cave_look": {"rock": ["fog_rock", Color(1.0, 1.0, 1.0)], "moss": ["fog_rock", Color(0.85, 0.92, 0.85)], "turf": ["fog_moor", Color.WHITE],
		"wall": ["fog_rock", Color(0.85, 0.85, 0.85)], "floor": ["fog_mud", Color(0.9, 0.9, 0.9)]},
	# grey and wet: clear rarely, cloud and drizzle mostly, a storm now and then; the fog thick over all of it
	"weather": [0.1, 0.6, 0.9],
	"haze": 0.7,
	# the fog close in all round (Weather "mist"): the next house a shape in it; thinned round a lit lantern
	"mist": 0.8,
	"haze_color": Color(0.64, 0.68, 0.68, 0.85),
	"storm_color": Color(0.28, 0.3, 0.32),
	"rock_tint": Color(0.46, 0.47, 0.47),
	"moss_tint": Color(0.44, 0.5, 0.42),
	"temple_stone": Color(0.56, 0.57, 0.56),
	"fort_stone": Color(0.58, 0.58, 0.57),
	"water_tint": Color(0.14, 0.18, 0.18, 0.88),
	"falls_tint": Color(0.7, 0.74, 0.74, 0.86),
	"spring_tint": Color(0.3, 0.4, 0.38, 0.85),
	"travertine": Color(0.7, 0.7, 0.66),
	"wreck_hull": Color(0.36, 0.36, 0.34),
	"bone": Color(0.86, 0.84, 0.78),
	"basalt": Color(0.24, 0.24, 0.25),
	"lava": Color(0.5, 0.9, 0.7),
	"crystal": Color(0.6, 0.9, 0.82),
	"rust": Color(0.4, 0.28, 0.22),
	"harbour_kinds": ["wharf", "cove", "cove", "ruins"],
	"harbour_wild_kinds": ["landing", "landing", "cove", "ruins", "ruins"],
	"harbour_pile": "planks_dark",
	"harbour_deck": "planks_weathered",
	"harbour_roof": "shingles",
	"harbour_walls": ["planks_weathered", "planks_dark", "plaster_wash"],
	"harbour_tarp": Color(0.4, 0.4, 0.38),
	"harbour_floats": [Color(0.6, 0.58, 0.52), Color(0.36, 0.38, 0.38), Color(0.5, 0.22, 0.18)],
	"harbour_signal": Color(0.7, 1.0, 0.8),
}

## Each kind: its zones, how likely an island has it, how many groups, a group's size. Few living things: crows
## and bats, a starved wolf pack, shore crabs on the strand, a rotting boar; and the ghost-lights drifting
## between the dead trees.
const FAUNA := {
	"wisp": {"zones": ["floor"], "p": 0.95, "dens": [3, 5], "pack": [2, 4]},
	"wolf": {"zones": ["floor"], "p": 0.45, "dens": [1, 2], "pack": [2, 4]},
	"boar": {"zones": ["floor"], "p": 0.3, "dens": [1, 2]},
	"fox": {"zones": ["floor"], "p": 0.25, "dens": [1, 2], "pack": [1, 2]},
	"bat": {"zones": ["canopy", "cave"], "p": 0.8, "dens": [2, 4]},
	"crab": {"zones": ["shore"], "p": 0.7, "dens": [2, 5]},
}
const CREATURES := {
	"wisp": "res://scripts/enemies/fauna/wisp.gd",
	"wolf": "res://scripts/enemies/fauna/wolf.gd",
	"boar": "res://scripts/enemies/fauna/boar.gd",
	"fox": "res://scripts/enemies/fauna/red_fox.gd",
	"bat": "res://scripts/enemies/fauna/bat.gd",
	"crab": "res://scripts/enemies/fauna/crab.gd",
	"mite": "res://scripts/enemies/fauna/swarm_mite.gd",
}

func _init() -> void:
	name = "fog"
	display = "Fog Isle"
	blurb = "a haunted isle under endless fog"
	island_names = ["Gallowmere", "Wraithholm", "Lantern Rest", "Greyhollow", "Drowner's Reach", "Mourne", "Ashenwick", "Bellmouth", "Saltgrave", "Pale Strand"]
	# (rolled apart: its own chance on a regular island past the first, leaving every other island of a chain as it was)
	weight = 0.18
	apart = true
	color = Color(0.62, 0.74, 0.7)
	glyph = _glyph
	flocks = 0
	land = LAND
	radius = [300.0, 420.0]
	style = STYLE
	arena_dress = _dress_graves
	props = {
		"fog_cabin": func(rng: RandomNumberGenerator, size: float) -> Node3D: return ForestTown.log_cabin(rng.randi(), size, 1),
		"fog_timber_house": func(rng: RandomNumberGenerator, size: float) -> Node3D: return ForestTown.timber_house(rng.randi(), size),
		"fog_workshop": func(rng: RandomNumberGenerator, size: float) -> Node3D: return ForestTown.workshop(rng.randi(), size),
		"fog_store": func(rng: RandomNumberGenerator, size: float) -> Node3D: return ForestTown.storehouse(rng.randi(), size),
		"fog_shrine": func(rng: RandomNumberGenerator, _size: float) -> Node3D: return ForestTown.shrine(rng.randi()),
		"fog_fence": func(rng: RandomNumberGenerator, size: float) -> Node3D: return ForestTown.fence(rng.randi(), 4.4 * size),
		"fog_woodpile": func(rng: RandomNumberGenerator, size: float) -> Node3D: return ForestTown.woodpile(rng.randi(), size),
	}
	life = preload("res://scripts/island/themes/fog_life.gd").TEXT
	encounters = preload("res://scripts/island/themes/fog_encounters.gd").TEXT
	# the fog's own shapes of the forest's and the jungle's: a shade that prowls the fog as a grey lynx, a drowned
	# coil in the black water, the hanging tree that walks; the pale rider the roamer (ghosts: no harm from shot)
	bosses = ["ghost_captain", "stalker", "serpent", "elder_treant"]
	minis = ["moss_golem", "huntsman", "boar"]
	roamers = ["wild_hunt"]
	beasts = {
		"ghost_captain": {"script": "res://scripts/enemies/ghost_captain.gd", "names": ["The Drowned Captain", "Captain Mourne", "Old Bellwether"], "looks": 3,
			"captain": true, "banner": ["The Wreck in the Fog", "A ship broken in two on dry land, her lantern still lit. Someone is still aboard."], "dress": _dress_wreck},
		"stalker": {"script": "res://scripts/enemies/beasts/stalker.gd", "names": ["The Fog Shade", "Greymalkin", "The Lantern-Eater"], "looks": 3, "spirit": true,
			"banner": ["The Shade's Hollow", "Lanterns smashed and cold. The fog sits thicker here than anywhere."]},
		"serpent": {"script": "res://scripts/enemies/beasts/strangler.gd", "names": ["The Drowned Coil", "Old Blackwater", "The Mire Serpent"], "looks": 3, "spirit": true,
			"banner": ["The Black Water", "Still as glass under the dead willows. Something below it breathes."]},
		"elder_treant": {"script": "res://scripts/enemies/beasts/elder_treant.gd", "names": ["The Hanging Tree", "Old Gallows", "The Moss Father"], "looks": 3, "spirit": true,
			"banner": ["The Gallows Hollow", "Old rope hangs from every limb. The tree in the middle isn't standing still."]},
		"moss_golem": {"script": "res://scripts/enemies/beasts/moss_golem.gd", "names": ["The Grave Golem", "Old Headstone", "The Barrow-Heap", "Cairnwight"], "site": "ruins"},
		"huntsman": {"script": "res://scripts/enemies/huntsman.gd", "names": ["The Drowned Bosun", "Bosun Gallows", "The Wreck-Warden", "Black Silas"],
			"site": "camp", "camp": true},
		"boar": {"script": "res://scripts/enemies/beasts/alpha_boar.gd", "names": ["Rotgut", "Old Mire", "Grave-Tusk", "Bogmaw"], "site": "lair"},
		"wild_hunt": {"script": "res://scripts/enemies/beasts/wild_hunt.gd", "names": ["The Pale Rider", "The Fog Hunt", "The Grey Elk"]},
	}
	fauna = FAUNA
	creatures = CREATURES
	cave_fauna = {"ceiling": "bat", "floor": ["mite", "wisp"]}


## The land (forest_land.gd): rolling ground, slow rivers in their valleys, the village by a river.
func plan_land(isl, rng: RandomNumberGenerator) -> Dictionary:
	return LAND_FEATURES.plan(isl, rng)


func shape(isl, p: Vector2, h: float) -> float:
	return LAND_FEATURES.shape(isl, p, h)


func village_at(isl, p: Vector2) -> Vector2:
	return LAND_FEATURES.village_at(isl, p)


func cover(isl, p: Vector2, c: float) -> float:
	return LAND_FEATURES.cover(isl, p, c)


func growth(isl, p: Vector2) -> Vector2:
	return LAND_FEATURES.growth(isl, p)


func paint(isl, p: Vector2, h: float, splat: Color) -> Color:
	return LAND_FEATURES.paint(isl, p, h, splat)


func steps(isl) -> Array:
	return LAND_FEATURES.steps(isl) + PLACES.steps(isl)


## The graveyard by the village (fog_places.gd).
func plan_places(isl, avoid: Array) -> Array:
	return PLACES.plan_places(isl, avoid)


func place_steps(isl, ctx, pl: Dictionary) -> Array:
	if str(pl["kind"]) == "fog_graveyard":
		return [func(): PLACES.graveyard(isl, pl, KitLandmarks.place_node(ctx, pl))]
	push_error("FogTheme: no place %s" % pl["kind"])
	return []


func meshes() -> Dictionary:
	return {
		"tree": [FogPlants.snag(901), FogPlants.snag(902), FogPlants.snag(903), FogPlants.whip(904)],
		"beach_tree": [FogPlants.snag(911), FogPlants.snag(912), FogPlants.whip(913)],
		"bush": [FogPlants.bramble(921), FogPlants.bramble(922), FogPlants.bramble(923)],
		"fern": [FogPlants.bracken(931), FogPlants.bracken(932)],
		"grass": [FogPlants.grass()],
		"rock": [FogPlants.bog_stone(941), FogPlants.bog_stone(942), FogPlants.bog_stone(943)],
		# big trees: [body, detail, lean]
		# (Zach, 2026-10-24: spiral giants the main tree, gnarled giants mixed in)
		"giant": [FogPlants.spiral_giant(951), FogPlants.spiral_giant(952), FogPlants.spiral_giant(953), FogPlants.spiral_giant(954)],
		"fig": [FogPlants.gnarl_giant(955), FogPlants.gnarl_giant(956), FogPlants.gnarl_giant(957)],
		"kapok": [FogPlants.spiral_giant(958), FogPlants.gnarl_giant(959)],
		"emergent": [FogPlants.spiral_giant(961), FogPlants.spiral_giant(962)],
		"roof": [FogPlants.limb_roof(965), FogPlants.limb_roof(966)],
		"mangrove": [ForestPlants.cattails(971), ForestPlants.cattails(972)],
		"bamboo": [FogPlants.stump(975), FogPlants.pale_caps(976)],
		"broadleaf": [FogPlants.fallen_log(981), FogPlants.fallen_log(982), FogPlants.pale_caps(983), FogPlants.stump(984)],
		"shrub": [FogPlants.whip(991), FogPlants.whip(992), FogPlants.whip(993)],
	}


## Every fog boss's ground: a drowned graveyard - leaning headstones in a broken ring, a stretch of iron railing,
## a dead snag or two, a cold lantern on a post (the way in left open).
static func _dress_graves(arena, body: StaticBody3D, mb: MeshBuilder, rng: RandomNumberGenerator, c: Vector2, y0: float) -> void:
	if str(arena.kind) == "ghost_captain":
		return
	var isl = arena.isl
	var r := float(BeastArena.FLOOR_R)
	var stone := PSXMat.lit("moss_stone", Color(0.62, 0.64, 0.64), {"affine": 0.6})
	var iron := PSXMat.flat(Color(0.12, 0.12, 0.13))
	var b_m := FogPlants.bark()
	var gy := func(q: Vector2) -> float: return float(isl.hv(c + q)) - y0
	var ent: float = (arena._ground()["entry"] as Vector2).angle()
	# headstones: two broken rings round the floor's edge, leaning every which way, a few fallen flat
	for ring in range(2):
		var n := rng.randi_range(12, 16)
		var a0 := rng.randf() * TAU
		for k in range(n):
			var a := a0 + TAU * k / n + rng.randf_range(-0.12, 0.12)
			if absf(wrapf(a - ent, -PI, PI)) < 0.4 or rng.randf() < 0.2:
				continue
			var q := Vector2.from_angle(a) * (r - 3.0 + ring * 2.2 + rng.randf_range(-0.6, 0.6))
			var h := rng.randf_range(0.7, 1.4)
			var w := rng.randf_range(0.5, 0.8)
			var base := Vector3(q.x, gy.call(q) - 0.15, q.y)
			var flat := rng.randf() < 0.12
			var b := Basis(Vector3.UP, -a + PI * 0.5 + rng.randf_range(-0.3, 0.3))
			b = b * (Basis(Vector3.RIGHT, -PI * 0.5) if flat else Basis(Vector3.BACK, rng.randf_range(-0.25, 0.25)) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)))
			var at := base + (Vector3(0, 0.1, 0) if flat else Vector3(0, h * 0.5, 0))
			mb.add_box(stone, Transform3D(b, at), Vector3(w, h, 0.16), 0.6, Color.WHITE.darkened(rng.randf() * 0.25))
			if not flat and rng.randf() < 0.3:
				# a cross on top
				mb.add_box(stone, Transform3D(b, at + b.y * (h * 0.5 + 0.25)), Vector3(0.12, 0.5, 0.12), 0.6, Color.WHITE.darkened(0.15))
				mb.add_box(stone, Transform3D(b, at + b.y * (h * 0.5 + 0.32)), Vector3(0.42, 0.1, 0.12), 0.6, Color.WHITE.darkened(0.15))
			if not flat:
				KitLandmarks.box_col_xf(body, Vector3(w, h, 0.16), Transform3D(b, at))
	# a stretch of iron railing on the far side, bars bent, a gap where it's fallen
	var fa := ent + PI + rng.randf_range(-0.6, 0.6)
	var span := rng.randf_range(0.6, 0.9)
	var bars := 22
	for k in range(bars):
		var a := fa - span * 0.5 + span * k / (bars - 1)
		if k > bars * 0.45 and k < bars * 0.6:
			continue
		var q := Vector2.from_angle(a) * (r + 1.6)
		var base := Vector3(q.x, gy.call(q) - 0.2, q.y)
		var tilt := Basis(Vector3.UP, -a) * Basis(Vector3.BACK, rng.randf_range(-0.12, 0.12))
		mb.add_box(iron, Transform3D(tilt, base + Vector3(0, 0.9, 0)), Vector3(0.05, 1.8, 0.05), 1.0)
		mb.add_cone(iron, Transform3D(tilt, base + Vector3(0, 1.8, 0)), 0.06, 0.18, 4)
	for t in [0.35, 1.5]:
		var pts := PackedVector3Array()
		for k in range(9):
			var a := fa - span * 0.5 + span * k / 8.0
			var q := Vector2.from_angle(a) * (r + 1.6)
			pts.append(Vector3(q.x, gy.call(q) - 0.2 + t, q.y))
		mb.add_tube(iron, pts, 0.03, 0.03, 3, 1.0)
	# dead snags at the edge, bare over the stones
	for k in range(rng.randi_range(2, 3)):
		var a := rng.randf() * TAU
		if absf(wrapf(a - ent, -PI, PI)) < 0.5:
			a += PI
		var q := Vector2.from_angle(a) * (r + rng.randf_range(0.5, 2.5))
		var base := Vector3(q.x, gy.call(q) - 0.3, q.y)
		var h := rng.randf_range(5.0, 8.0)
		var top := base + Vector3(rng.randf_range(-0.8, 0.8), h, rng.randf_range(-0.8, 0.8))
		mb.add_tube(b_m, PackedVector3Array([base, base.lerp(top, 0.5) + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)), top]), 0.35, 0.08, 5, 0.6)
		for j in range(3):
			var aa := rng.randf() * TAU
			var from := base.lerp(top, rng.randf_range(0.5, 0.85))
			mb.add_tube(b_m, PackedVector3Array([from, from + Vector3(cos(aa), rng.randf_range(0.3, 0.9), sin(aa)) * rng.randf_range(1.2, 2.2)]), 0.1, 0.02, 4, 1.0)
		KitLandmarks.box_col_xf(body, Vector3(0.6, h, 0.6), Transform3D(Basis(), base + Vector3(0, h * 0.5, 0)))
	# a lantern post by the way in, its glass cold and black
	var lq := Vector2.from_angle(ent + 0.55) * (r - 0.8)
	var lb := Vector3(lq.x, gy.call(lq) - 0.2, lq.y)
	mb.add_box(iron, Transform3D(Basis(), lb + Vector3(0, 1.3, 0)), Vector3(0.1, 2.6, 0.1), 1.0)
	mb.add_box(iron, Transform3D(Basis(), lb + Vector3(0.3, 2.5, 0)), Vector3(0.6, 0.06, 0.06), 1.0)
	mb.add_box(PSXMat.flat(Color(0.08, 0.1, 0.1)), Transform3D(Basis(), lb + Vector3(0.55, 2.2, 0)), Vector3(0.24, 0.34, 0.24), 1.0)
	KitLandmarks.box_col_xf(body, Vector3(0.2, 2.6, 0.2), Transform3D(Basis(), lb + Vector3(0, 1.3, 0)))


## The drowned captain's ground: his ship, broken in two round the floor. Her stern on the far side, rolled over on
## her bilge, the raised quarterdeck and the cabin under it still standing, a green lantern burning at her taffrail;
## her bow off to one side nosed up into the air; ribs of the middle of her between them like a whale's, the
## mainmast fallen across the floor's edge, barrels and a cannon spilled out. The way in open.
static func _dress_wreck(arena, body: StaticBody3D, mb: MeshBuilder, rng: RandomNumberGenerator, c: Vector2, y0: float) -> void:
	var isl = arena.isl
	var r := float(BeastArena.FLOOR_R)
	var plank := PSXMat.lit("planks_weathered", Color(0.62, 0.64, 0.64), {"affine": 0.6})
	var dark := PSXMat.lit("planks_dark", Color(0.6, 0.62, 0.62), {"affine": 0.6})
	var iron := PSXMat.flat(Color(0.12, 0.12, 0.13))
	var gy := func(q: Vector2) -> float: return float(isl.hv(c + q)) - y0
	var ent: float = (arena._ground()["entry"] as Vector2).angle()
	var box := func(m: Material, b: Basis, at: Vector3, size: Vector3, col := true) -> void:
		mb.add_box(m, Transform3D(b, at), size, 0.5, Color.WHITE.darkened(rng.randf() * 0.15))
		if col:
			KitLandmarks.box_col_xf(body, size, Transform3D(b, at))
	# a half hull: keel along its local x (+x the whole end, -x the broken one), its sides at z +-beam/2
	var half := func(q: Vector2, yaw: float, roll: float, pitch: float, L: float, beam: float, H: float, stern: bool) -> void:
		var bb := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, pitch) * Basis(Vector3.RIGHT, roll)
		var o := Vector3(q.x, gy.call(q) - 0.6, q.y)
		var at := func(v: Vector3) -> Vector3: return o + bb * v
		box.call(dark, bb, at.call(Vector3(0, 0.25, 0)), Vector3(L, 0.5, beam * 0.55))
		for s in [-1.0, 1.0]:
			var sb: Basis = bb * Basis(Vector3.RIGHT, s * 0.28)
			box.call(plank, sb, at.call(Vector3(0, H * 0.5, s * beam * 0.5)), Vector3(L, H, 0.3))
			# the broken end: ragged planks sticking out past the break
			for k in range(rng.randi_range(3, 5)):
				var y := rng.randf_range(0.6, H - 0.4)
				box.call(plank, sb, at.call(Vector3(-L * 0.5 - rng.randf_range(0.4, 1.6), y, s * beam * 0.5)), Vector3(rng.randf_range(0.8, 2.4), 0.3, 0.12), false)
		# ribs at the break
		for k in range(3):
			var x := -L * 0.5 + 0.6 + k * 0.9
			for s in [-1.0, 1.0]:
				mb.add_tube(dark, PackedVector3Array([at.call(Vector3(x, 0.4, 0)), at.call(Vector3(x, H * 0.4, s * beam * 0.55)), at.call(Vector3(x - 0.3, H + 0.4, s * beam * 0.62))]), 0.16, 0.1, 4, 0.8)
		if stern:
			# the transom, the quarterdeck over the cabin, its windows black, the taffrail's lantern green
			box.call(plank, bb, at.call(Vector3(L * 0.5, H * 0.6, 0)), Vector3(0.3, H * 1.2, beam))
			box.call(dark, bb, at.call(Vector3(L * 0.22, H * 0.92, 0)), Vector3(L * 0.56, 0.25, beam * 1.02))
			box.call(plank, bb, at.call(Vector3(L * 0.02, H * 0.55, 0)), Vector3(0.25, H * 0.75, beam * 0.9))
			for s in [-0.25, 0.25]:
				box.call(PSXMat.flat(Color(0.04, 0.05, 0.05)), bb, at.call(Vector3(L * 0.5 + 0.17, H * 0.75, s * beam)), Vector3(0.05, 0.6, 0.7), false)
			mb.add_box(iron, Transform3D(bb, at.call(Vector3(L * 0.5 - 0.3, H * 1.3, 0))), Vector3(0.08, 1.4, 0.08))
			mb.add_box(PSXMat.glow(Color(0.45, 1.0, 0.7), 2.4), Transform3D(bb, at.call(Vector3(L * 0.5 - 0.3, H * 1.95, 0))), Vector3(0.3, 0.42, 0.3))
			# the mizzen stump and a rag of sail
			mb.add_cylinder(dark, Transform3D(bb, at.call(Vector3(L * 0.3, H * 0.92, 0))), 0.24, 0.18, 3.6, 6, 0.6)
			mb.add_box(PSXMat.lit("canvas", Color(0.5, 0.52, 0.5)), Transform3D(bb * Basis(Vector3.UP, 0.3), at.call(Vector3(L * 0.3 + 0.3, H * 0.92 + 2.6, 0.5))), Vector3(0.05, 1.6, 1.1))
		else:
			# the stem post and a bowsprit up into the fog
			box.call(dark, bb, at.call(Vector3(L * 0.5, H * 0.55, 0)), Vector3(0.5, H * 1.1, 0.5))
			mb.add_cylinder(dark, Transform3D(bb * Basis(Vector3.BACK, -PI * 0.5 + 0.35), at.call(Vector3(L * 0.5 + 0.4, H, 0))), 0.2, 0.1, 5.0, 5, 0.6)
	# her stern on the far side, her bow off to one side (never across the way in)
	var sa := ent + PI + rng.randf_range(-0.3, 0.3)
	var sq := Vector2.from_angle(sa) * (r + 2.5)
	half.call(sq, -sa + PI * 0.5 + rng.randf_range(-0.2, 0.2), 0.32, 0.04, 14.0, 6.4, 4.6, true)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var ba := ent + PI * 0.5 * side + rng.randf_range(-0.15, 0.15)
	var bq := Vector2.from_angle(ba) * (r + 1.5)
	half.call(bq, -ba + PI * 0.5, -0.2, 0.42, 10.0, 6.0, 4.2, false)
	# ribs of her middle across the other side, half buried
	var ra := ent - PI * 0.5 * side + rng.randf_range(-0.2, 0.2)
	for k in range(5):
		var a := ra + (k - 2) * 0.09
		var q := Vector2.from_angle(a) * (r + 0.5)
		var tang := Vector2.from_angle(a + PI * 0.5)
		var base := Vector3(q.x, gy.call(q) - 0.4, q.y)
		var out := Vector3(tang.x, 0, tang.y)
		var rad := Vector3(cos(a), 0, sin(a))
		for s in [-1.0, 1.0]:
			mb.add_tube(dark, PackedVector3Array([base, base + rad * s * 1.8 + Vector3.UP * 2.6, base + rad * s * 2.2 + Vector3.UP * 4.6 + out * 0.2]), 0.18, 0.08, 4, 0.8)
	# the mainmast fallen across the floor's edge, its yard and a tangle of rigging
	var ma := ent + PI + PI * 0.5 * side + rng.randf_range(-0.3, 0.3)
	var m0 := Vector2.from_angle(ma) * (r + 3.0)
	var m1 := Vector2.from_angle(ma + 0.9 * side) * (r - 2.0)
	var p0 := Vector3(m0.x, gy.call(m0) + 0.3, m0.y)
	var p1 := Vector3(m1.x, gy.call(m1) + 0.3, m1.y)
	var d := p1 - p0
	mb.add_cylinder(dark, Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), p0), 0.34, 0.24, d.length(), 7, 0.6)
	KitLandmarks.box_col_xf(body, Vector3(0.6, d.length(), 0.6), Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), p0.lerp(p1, 0.5)))
	var ym := p0.lerp(p1, 0.7)
	var yd := d.cross(Vector3.UP).normalized()
	mb.add_cylinder(dark, Transform3D(Basis(Quaternion(Vector3.UP, yd)), ym - yd * 3.0 + Vector3.UP * 0.1), 0.14, 0.1, 6.0, 5, 0.6)
	var rope := PSXMat.lit("rope", Color(0.6, 0.58, 0.54))
	for k in range(3):
		var a0 := p0.lerp(p1, rng.randf_range(0.2, 0.8)) + Vector3.UP * 0.3
		var a1 := a0 + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
		a1.y = gy.call(Vector2(a1.x, a1.z)) + 0.05
		mb.add_tube(rope, PackedVector3Array([a0, a0.lerp(a1, 0.5) + Vector3.UP * 0.2, a1]), 0.04, 0.04, 3, 1.0)
	# barrels and a cannon spilled across the sand
	for k in range(rng.randi_range(5, 8)):
		var a := rng.randf() * TAU
		if absf(wrapf(a - ent, -PI, PI)) < 0.5:
			continue
		var q := Vector2.from_angle(a) * rng.randf_range(r - 4.0, r - 1.0)
		var lie := rng.randf() < 0.5
		var bb := Basis(Vector3.UP, rng.randf() * TAU) * (Basis(Vector3.RIGHT, PI * 0.5) if lie else Basis())
		mb.add_cylinder(dark, Transform3D(bb, Vector3(q.x, gy.call(q) + (0.36 if lie else 0.0), q.y)), 0.38, 0.38, 0.95, 7, 0.6)
	var cq := Vector2.from_angle(sa + 0.5) * (r - 2.5)
	var cb := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, 0.2)
	mb.add_cylinder(iron, Transform3D(cb * Basis(Vector3.BACK, PI * 0.5), Vector3(cq.x, gy.call(cq) + 0.3, cq.y)), 0.26, 0.18, 2.2, 7, 0.6)


## A lantern: a ring on top, the glass body, a flame inside.
static func _glyph(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	var w := s * 0.5
	var top := p + Vector2(0, -s * 0.55)
	var bot := p + Vector2(0, s * 0.75)
	ci.draw_arc(top + Vector2(0, -s * 0.2), s * 0.22, PI, TAU, 6, col, 1.0)
	ci.draw_polyline(PackedVector2Array([top + Vector2(-w * 0.6, 0), top + Vector2(w * 0.6, 0), p + Vector2(w, -s * 0.25), bot + Vector2(w * 0.8, 0),
		bot + Vector2(-w * 0.8, 0), p + Vector2(-w, -s * 0.25), top + Vector2(-w * 0.6, 0)]), col, 1.0)
	ci.draw_line(p + Vector2(0, -s * 0.05), p + Vector2(0, s * 0.4), col, 1.0)
