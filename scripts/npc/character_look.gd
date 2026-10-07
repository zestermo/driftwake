class_name CharacterLook
extends RefCounted
## Character appearance data: option lists, color palettes, defaults,
## randomizing, legacy-key conversion and save/load of the player's look.
##
## A look is a plain Dictionary (so NPC configs can stay inline). Keys:
##   name                      String
##   body      "masc"|"fem"    build "slim"|"average"|"broad"|"stout"
##   height    float (scale)   skin Color
##   head      "round"|"square"|"long"       nose "small"|"straight"|"broad"|"hooked"
##   eyes int, eye_color Color, brows int, mouth int, marks "none"|"freckles"|...
##   hair (see HAIR), hair_color, facial_hair (see FACIAL_HAIR)
##   hat (see HATS), hat_color
##   top "shirt"|"tunic"|"blouse"|"bare", top_color, sleeves "long"|"short"|"none"
##   vest "none"|"vest"|"corset", vest_color
##   coat "none"|"jacket"|"longcoat"|"captain", coat_color, trim_color
##   legs "trousers"|"breeches"|"shorts"|"skirt", legs_color
##   feet "tall_boots"|"boots"|"shoes"|"barefoot", feet_color
##   belt "none"|"belt"|"sash"|"belt_sash", belt_color, sash_color
##   gloves bool, gloves_color, apron bool, apron_color
##   earring bool, eyepatch bool, scarf bool, scarf_color, pauldron bool, pouch bool

const SAVE_PATH := "user://character.cfg"

const BODIES := ["masc", "fem"]
const BUILDS := ["slim", "average", "broad", "stout"]
const HEIGHTS := [0.92, 0.96, 1.0, 1.04, 1.08]
const HEADS := ["round", "square", "long"]
const NOSES := ["small", "straight", "broad", "hooked"]
const EYE_STYLES := 6
const BROW_STYLES := 5
const MOUTH_STYLES := 6
const MARKS := ["none", "freckles", "scar", "blush", "war_paint", "age_lines"]
const HAIR := ["bald", "crop", "short", "long", "ponytail", "bun", "braids", "wild",
	"swept", "messy", "slick", "topknot", "hime", "twintails", "bob", "side_pony",
	"quiff", "curtains", "spiky", "shag", "swoop", "low_pony", "layered", "lob", "braid"]
## Styles the random looks give each body (any style can still be picked for either).
const HAIR_MASC := ["bald", "crop", "short", "long", "ponytail", "wild", "swept", "messy", "slick", "topknot",
	"quiff", "curtains", "spiky", "shag", "swoop"]
const HAIR_FEM := ["long", "ponytail", "bun", "braids", "short", "wild", "hime", "twintails", "bob", "side_pony", "swept",
	"low_pony", "layered", "lob", "braid", "curtains", "shag"]
const FACIAL_HAIR := ["none", "stubble", "moustache", "goatee", "chops", "beard", "long_beard"]
const HATS := ["none", "tricorn", "bicorne", "bandana", "cap", "knit", "straw", "hood", "cavalier", "morion", "turban"]
const TOPS := ["shirt", "tunic", "blouse", "bare"]
const SLEEVES := ["long", "short", "none"]
const VESTS := ["none", "vest", "corset", "cuirass", "brigandine", "mail"]
const COATS := ["none", "jacket", "longcoat", "captain", "greatcoat"]
const LEGS := ["trousers", "breeches", "shorts", "skirt"]
const FEET := ["tall_boots", "boots", "shoes", "barefoot", "greaves"]
const BELTS := ["none", "belt", "sash", "belt_sash"]
## What a new captain can start in (the character creator and its Randomize):
## plain clothes. Hats of rank, coats of office and armour are bought or found.
const CREATOR_HATS := ["none", "bandana", "cap", "knit", "straw", "hood"]
const CREATOR_VESTS := ["none", "vest"]
const CREATOR_COATS := ["none", "jacket"]
const CREATOR_FEET := ["boots", "shoes", "barefoot"]

const SKIN_TONES := [
	Color(0.96, 0.82, 0.70), Color(0.92, 0.74, 0.60), Color(0.87, 0.67, 0.50), Color(0.80, 0.60, 0.44),
	Color(0.72, 0.52, 0.38), Color(0.62, 0.43, 0.30), Color(0.50, 0.34, 0.23), Color(0.38, 0.25, 0.17)]
const HAIR_COLORS := [
	Color(0.08, 0.06, 0.05), Color(0.18, 0.11, 0.07), Color(0.32, 0.20, 0.11), Color(0.45, 0.20, 0.10),
	Color(0.70, 0.34, 0.14), Color(0.82, 0.66, 0.38), Color(0.62, 0.56, 0.48), Color(0.55, 0.55, 0.56),
	Color(0.88, 0.87, 0.84), Color(0.20, 0.24, 0.42)]
const EYE_COLORS := [
	Color(0.30, 0.18, 0.10), Color(0.48, 0.34, 0.16), Color(0.25, 0.45, 0.25), Color(0.25, 0.42, 0.68),
	Color(0.48, 0.52, 0.56), Color(0.72, 0.52, 0.16)]
const CLOTH := [
	Color(0.90, 0.88, 0.80), Color(0.82, 0.76, 0.62), Color(0.62, 0.52, 0.38), Color(0.40, 0.28, 0.18),
	Color(0.24, 0.17, 0.12), Color(0.10, 0.09, 0.09), Color(0.28, 0.28, 0.30), Color(0.55, 0.55, 0.55),
	Color(0.14, 0.18, 0.34), Color(0.20, 0.32, 0.62), Color(0.16, 0.42, 0.44), Color(0.18, 0.34, 0.20),
	Color(0.42, 0.42, 0.20), Color(0.66, 0.14, 0.12), Color(0.40, 0.10, 0.12), Color(0.80, 0.62, 0.20),
	Color(0.36, 0.20, 0.44), Color(0.68, 0.36, 0.18)]
const LEATHER := [
	Color(0.10, 0.08, 0.07), Color(0.24, 0.15, 0.09), Color(0.40, 0.26, 0.14), Color(0.62, 0.44, 0.26),
	Color(0.36, 0.12, 0.10)]
const TRIM := [
	Color(0.85, 0.68, 0.24), Color(0.75, 0.76, 0.78), Color(0.92, 0.90, 0.84), Color(0.10, 0.09, 0.09),
	Color(0.66, 0.14, 0.12)]

## Which palette each color key uses (for the creator's swatches).
const COLOR_PALETTES := {
	"skin": "SKIN_TONES", "hair_color": "HAIR_COLORS", "eye_color": "EYE_COLORS",
	"hat_color": "CLOTH", "top_color": "CLOTH", "vest_color": "CLOTH", "coat_color": "CLOTH",
	"trim_color": "TRIM", "legs_color": "CLOTH", "feet_color": "LEATHER", "belt_color": "LEATHER",
	"sash_color": "CLOTH", "gloves_color": "LEATHER", "scarf_color": "CLOTH", "apron_color": "CLOTH", "cape_color": "CLOTH"}


static func palette(key: String) -> Array:
	match str(COLOR_PALETTES.get(key, "CLOTH")):
		"SKIN_TONES": return SKIN_TONES
		"HAIR_COLORS": return HAIR_COLORS
		"EYE_COLORS": return EYE_COLORS
		"LEATHER": return LEATHER
		"TRIM": return TRIM
	return CLOTH


## Neutral plain-clothes base: anything a look doesn't specify comes from here.
static func base_look() -> Dictionary:
	return {
		"name": "Villager",
		"body": "masc", "build": "average", "height": 1.0, "skin": SKIN_TONES[2],
		"head": "round", "nose": "straight", "eyes": 0, "eye_color": EYE_COLORS[0], "brows": 0, "mouth": 0,
		"marks": "none",
		"hair": "short", "hair_color": HAIR_COLORS[2], "facial_hair": "none",
		"hat": "none", "hat_color": CLOTH[3],
		"top": "shirt", "top_color": CLOTH[0], "sleeves": "long",
		"vest": "none", "vest_color": CLOTH[3],
		"coat": "none", "coat_color": CLOTH[3], "trim_color": TRIM[0],
		"legs": "trousers", "legs_color": CLOTH[3],
		"feet": "boots", "feet_color": LEATHER[1],
		"belt": "belt", "belt_color": LEATHER[1], "sash_color": CLOTH[13],
		"gloves": false, "gloves_color": LEATHER[1], "gauntlets": false,
		"apron": false, "apron_color": CLOTH[0],
		"earring": false, "eyepatch": false, "scarf": false, "scarf_color": CLOTH[13],
		"pauldron": false, "pouch": false, "cape": false, "cape_color": CLOTH[13], "bandolier": false,
	}


## The starting captain.
static func default_look() -> Dictionary:
	var lk := base_look()
	lk.merge(_captain(), true)
	return lk


static func _captain() -> Dictionary:
	return {
		"name": "Captain",
		"body": "masc", "build": "average", "height": 1.0, "skin": SKIN_TONES[2],
		"head": "round", "nose": "straight", "eyes": 0, "eye_color": EYE_COLORS[0], "brows": 0, "mouth": 0,
		"marks": "scar",
		"hair": "short", "hair_color": HAIR_COLORS[2], "facial_hair": "stubble",
		"hat": "bandana", "hat_color": CLOTH[13],
		"top": "shirt", "top_color": CLOTH[0], "sleeves": "long",
		"vest": "none", "vest_color": CLOTH[3],
		"coat": "jacket", "coat_color": CLOTH[8], "trim_color": TRIM[0],
		"legs": "trousers", "legs_color": CLOTH[4],
		"feet": "boots", "feet_color": LEATHER[0],
		"belt": "belt_sash", "belt_color": LEATHER[1], "sash_color": CLOTH[13],
		"gloves": false, "gloves_color": LEATHER[1],
		"apron": false, "apron_color": CLOTH[0],
		"earring": false, "eyepatch": false, "scarf": false, "scarf_color": CLOTH[13],
		"pauldron": false, "pouch": false,
	}


## Fill in defaults (from the neutral base) and convert the older look keys
## (shirt/pants/boots, coat as a bool, hat "hair"/"bald"/"bun", face 0..7,
## width) used by older NPC configs.
static func normalize(src: Dictionary) -> Dictionary:
	var lk := base_look()
	var legacy := src.has("shirt") or src.has("face") or src.has("pants") or (src.has("coat") and src["coat"] is bool)
	for k in src.keys():
		lk[k] = src[k]
	if legacy:
		if src.has("shirt"): lk["top_color"] = src["shirt"]
		if src.has("pants"): lk["legs_color"] = src["pants"]
		if src.has("boots"): lk["feet_color"] = src["boots"]
		if src.has("coat") and src["coat"] is bool:
			lk["coat"] = "longcoat" if src["coat"] else "none"
		if src.get("sash", false) is bool and src.get("sash", false):
			lk["belt"] = "belt_sash"
		lk.erase("sash")
		match str(src.get("hat", "hair")):
			"hair": lk["hat"] = "none"; lk["hair"] = "short"
			"bald": lk["hat"] = "none"; lk["hair"] = "bald"
			"bun": lk["hat"] = "none"; lk["hair"] = "bun"
		if src.has("width"):
			var w := float(src["width"])
			lk["build"] = "stout" if w > 1.15 else ("slim" if w < 0.9 else "average")
		match int(src.get("face", 0)):
			1: lk["mouth"] = 1
			2: lk["facial_hair"] = "beard"
			3: lk["facial_hair"] = "beard"; lk["hair_color"] = HAIR_COLORS[8]; lk["marks"] = "age_lines"
			4: lk["brows"] = 3
			5: lk["eyes"] = 3
			6: lk["facial_hair"] = "moustache"; lk["brows"] = 3
			7: lk["eyepatch"] = true
	for k in ["shirt", "pants", "boots", "face", "width"]:
		lk.erase(k)
	return lk


## A random but coherent look (used by the creator's Randomize button).
static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var lk := default_look()
	var fem := rng.randf() < 0.5
	lk["body"] = "fem" if fem else "masc"
	lk["build"] = _pick(rng, BUILDS)
	lk["height"] = _pick(rng, HEIGHTS)
	lk["skin"] = _pick(rng, SKIN_TONES)
	lk["head"] = _pick(rng, HEADS)
	lk["nose"] = _pick(rng, NOSES)
	lk["eyes"] = rng.randi() % EYE_STYLES
	lk["eye_color"] = _pick(rng, EYE_COLORS)
	lk["brows"] = rng.randi() % BROW_STYLES
	lk["mouth"] = rng.randi() % MOUTH_STYLES
	lk["marks"] = "none" if rng.randf() < 0.55 else _pick(rng, MARKS)
	lk["hair"] = _pick(rng, HAIR_FEM if fem else HAIR_MASC)
	lk["hair_color"] = _pick(rng, HAIR_COLORS)
	lk["facial_hair"] = "none" if fem or rng.randf() < 0.3 else _pick(rng, FACIAL_HAIR)
	lk["hat"] = _pick(rng, CREATOR_HATS)
	lk["hat_color"] = _pick(rng, CLOTH)
	lk["top"] = _pick(rng, ["shirt", "shirt", "tunic", "blouse", "bare"] if not fem else ["shirt", "tunic", "blouse"])
	lk["top_color"] = _pick(rng, CLOTH)
	lk["sleeves"] = _pick(rng, SLEEVES)
	lk["vest"] = _pick(rng, CREATOR_VESTS)
	lk["vest_color"] = _pick(rng, CLOTH)
	lk["coat"] = _pick(rng, CREATOR_COATS)
	lk["coat_color"] = _pick(rng, CLOTH)
	lk["trim_color"] = _pick(rng, TRIM)
	lk["legs"] = _pick(rng, LEGS if fem else ["trousers", "trousers", "breeches", "shorts"])
	lk["legs_color"] = _pick(rng, CLOTH)
	lk["feet"] = _pick(rng, CREATOR_FEET)
	lk["feet_color"] = _pick(rng, LEATHER)
	lk["belt"] = _pick(rng, BELTS)
	lk["belt_color"] = _pick(rng, LEATHER)
	lk["sash_color"] = _pick(rng, CLOTH)
	lk["gloves"] = rng.randf() < 0.2
	lk["gloves_color"] = _pick(rng, LEATHER)
	lk["earring"] = rng.randf() < 0.3
	lk["eyepatch"] = rng.randf() < 0.1
	lk["scarf"] = rng.randf() < 0.25
	lk["scarf_color"] = _pick(rng, CLOTH)
	lk["pauldron"] = false
	lk["pouch"] = rng.randf() < 0.3
	return lk


static func _pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	return arr[rng.randi() % arr.size()]


# --------------------------------------------------------------------------
# Save / load (the player's look)
# --------------------------------------------------------------------------
static func has_saved() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func save_look(lk: Dictionary) -> void:
	var cf := ConfigFile.new()
	for k in lk.keys():
		cf.set_value("look", str(k), lk[k])
	cf.save(SAVE_PATH)


static func load_look() -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return default_look()
	var lk := {}
	for k in cf.get_section_keys("look"):
		lk[k] = cf.get_value("look", k)
	return normalize(lk)
