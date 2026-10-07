class_name Gear
extends RefCounted
## Clothing and armor as items. Each piece owns some CharacterLook keys (a coat
## sets coat/coat_color/trim_color); the character's look is their appearance
## (body, face, hair) with the equipped pieces laid over it, and plain
## smallclothes wherever a slot is empty.
##
## The outfit picked in the character creator becomes the starting gear
## (items_from_look), so what you designed is what you wear and can swap out.

## Paper-doll slots: [slot id, label, accepted gear_slot kind].
const SLOTS := [
	["head", "Head", "head"], ["torso", "Torso", "torso"], ["vest", "Vest", "vest"],
	["coat", "Coat", "coat"], ["belt", "Belt", "belt"],
	["hands", "Hands", "hands"], ["legs", "Legs", "legs"], ["feet", "Feet", "feet"],
	["acc1", "Accessory", "accessory"], ["acc2", "Accessory", "accessory"]]

## Look keys each slot kind controls.
const SLOT_KEYS := {
	"head": ["hat", "hat_color"],
	"torso": ["top", "sleeves", "top_color"],
	"vest": ["vest", "vest_color"],
	"coat": ["coat", "coat_color", "trim_color"],
	"hands": ["gloves", "gloves_color", "gauntlets"],
	"legs": ["legs", "legs_color"],
	"feet": ["feet", "feet_color"],
	"belt": ["belt", "belt_color", "sash_color"],
}
## Accessories are on/off look flags (+ a color for some).
const ACCESSORIES := ["scarf", "pauldron", "earring", "eyepatch", "pouch", "apron", "cape", "bandolier"]
const ACC_COLOR := {"scarf": "scarf_color", "apron": "apron_color", "cape": "cape_color"}
## Steel pieces are named plainly ("Morion", not "Grey Morion").
const STEEL_PIECES := ["morion", "cuirass", "mail", "gauntlets", "greaves", "pauldron"]

const NAMES := {
	"tricorn": "Tricorn", "bicorne": "Bicorne", "bandana": "Bandana", "cap": "Sailor's Cap",
	"knit": "Knit Cap", "straw": "Straw Hat", "hood": "Hood",
	"tunic": "Tunic", "blouse": "Blouse",
	"vest": "Vest", "corset": "Corset",
	"jacket": "Jacket", "longcoat": "Long Coat", "captain": "Captain's Coat",
	"gloves": "Leather Gloves",
	"trousers": "Trousers", "breeches": "Breeches", "shorts": "Shorts", "skirt": "Skirt",
	"tall_boots": "Tall Boots", "boots": "Boots", "shoes": "Shoes",
	"belt": "Belt", "sash": "Sash", "belt_sash": "Belt and Sash",
	"scarf": "Scarf", "pauldron": "Pauldron", "earring": "Gold Earring", "eyepatch": "Eyepatch",
	"pouch": "Belt Pouch", "apron": "Apron",
	"cavalier": "Cavalier Hat", "morion": "Morion", "turban": "Turban",
	"cuirass": "Cuirass", "brigandine": "Brigandine", "mail": "Mail Shirt",
	"greatcoat": "Greatcoat", "gauntlets": "Gauntlets", "greaves": "Greaves",
	"cape": "Cape", "bandolier": "Bandolier",
}
const DESCRIPTIONS := {
	"tricorn": "A three-cornered hat. Keeps the sun and the spray off.",
	"bicorne": "A wide officer's hat, worn crosswise. Hard to ignore.",
	"bandana": "A knotted kerchief. Sweat out, hair in.",
	"cap": "A soft sailor's cap with a short bill.",
	"knit": "A thick wool cap for cold watches.",
	"straw": "A broad straw hat. Light, cool and full of holes.",
	"hood": "A heavy cloth hood.",
	"shirt": "Plain linen. Every sailor owns three and wears one.",
	"tunic": "A long belted tunic.",
	"blouse": "A loose blouse with full sleeves.",
	"vest": "A buttoned vest. Pockets for whatever you find.",
	"corset": "A stiff laced bodice. Turns a glancing blow.",
	"jacket": "A short sea jacket, cut for climbing rigging.",
	"longcoat": "A long heavy coat. The tails take a beating so you don't.",
	"captain": "A captain's coat with brass and braid. Commands a deck.",
	"gloves": "Worn leather gloves. Rope burns are someone else's problem.",
	"trousers": "Sturdy canvas trousers.",
	"breeches": "Knee breeches with stockings.",
	"shorts": "Cut-off trousers for hot decks.",
	"skirt": "A long skirt that moves with you.",
	"tall_boots": "Knee-high boots, folded at the cuff.",
	"boots": "Ankle boots with hobnailed soles.",
	"shoes": "Buckled shoes. Light on deck.",
	"belt": "A leather belt with a brass buckle.",
	"sash": "A wide cloth sash knotted at the hip.",
	"belt_sash": "A sash under a leather belt. Pirate fashion.",
	"scarf": "A long scarf against the wind.",
	"pauldron": "A riveted shoulder plate.",
	"earring": "A gold hoop. Pays for your burial, they say.",
	"eyepatch": "Covers the eye. Whether you need it is your business.",
	"pouch": "A small leather pouch on the belt.",
	"apron": "A work apron, stained with something.",
	"cavalier": "A broad hat with a plume swept back over the crown. Every duel deserves one.",
	"morion": "A crested steel helmet, its brim rising fore and aft.",
	"turban": "Cloth wound round and round, a jewel at the front. Cool in the sun, soft on a blow.",
	"cuirass": "A steel breast- and backplate. Heavy, hot, and worth both.",
	"brigandine": "Leather with steel plates riveted inside. Bends where a cuirass won't.",
	"mail": "A shirt of riveted rings that hangs to the hips. Turns a cut, not a club.",
	"greatcoat": "A long coat with a cape over the shoulders. For wind, rain and making an entrance.",
	"gauntlets": "Steel over the forearms and the backs of the hands.",
	"greaves": "Tall boots with steel down the shins and a cop over each knee.",
	"cape": "A cloak from the shoulders to the knees. Mostly for the look of it.",
	"bandolier": "A strap across the chest, cartridges along it.",
}
const DEFENSE := {
	"tricorn": 2.0, "bicorne": 2.0, "bandana": 1.0, "cap": 1.0, "knit": 1.0, "straw": 0.0, "hood": 1.0,
	"shirt": 1.0, "tunic": 2.0, "blouse": 1.0,
	"vest": 2.0, "corset": 3.0,
	"jacket": 3.0, "longcoat": 4.0, "captain": 5.0,
	"gloves": 1.0,
	"trousers": 2.0, "breeches": 2.0, "shorts": 1.0, "skirt": 1.0,
	"tall_boots": 2.0, "boots": 2.0, "shoes": 1.0,
	"belt": 0.0, "sash": 0.0, "belt_sash": 1.0,
	"scarf": 0.0, "pauldron": 3.0, "earring": 0.0, "eyepatch": 0.0, "pouch": 0.0, "apron": 1.0,
	"cavalier": 2.0, "morion": 5.0, "turban": 2.0,
	"cuirass": 7.0, "brigandine": 5.0, "mail": 5.0,
	"greatcoat": 5.0, "gauntlets": 3.0, "greaves": 4.0,
	"cape": 1.0, "bandolier": 1.0,
}

## Rough color names for item names ("Navy Long Coat").
const COLOR_NAMES := [
	["White", Color(0.90, 0.88, 0.80)], ["Cream", Color(0.82, 0.76, 0.62)], ["Tan", Color(0.62, 0.52, 0.38)],
	["Brown", Color(0.40, 0.28, 0.18)], ["Dark Brown", Color(0.24, 0.17, 0.12)], ["Black", Color(0.10, 0.09, 0.09)],
	["Charcoal", Color(0.28, 0.28, 0.30)], ["Grey", Color(0.55, 0.55, 0.55)], ["Navy", Color(0.14, 0.18, 0.34)],
	["Blue", Color(0.20, 0.32, 0.62)], ["Teal", Color(0.16, 0.42, 0.44)], ["Green", Color(0.18, 0.34, 0.20)],
	["Olive", Color(0.42, 0.42, 0.20)], ["Red", Color(0.66, 0.14, 0.12)], ["Maroon", Color(0.40, 0.10, 0.12)],
	["Mustard", Color(0.80, 0.62, 0.20)], ["Purple", Color(0.36, 0.20, 0.44)], ["Rust", Color(0.68, 0.36, 0.18)],
	["Oxblood", Color(0.36, 0.12, 0.10)], ["Fawn", Color(0.62, 0.44, 0.26)]]


## Clothing and armour that turns up as plunder (prize chests at sea).
const PLUNDER := [
	["head", "morion", {"hat": "morion"}],
	["head", "cavalier", {"hat": "cavalier", "hat_color": Color(0.1, 0.09, 0.09)}],
	["head", "bicorne", {"hat": "bicorne", "hat_color": Color(0.14, 0.18, 0.34)}],
	["vest", "mail", {"vest": "mail"}],
	["vest", "brigandine", {"vest": "brigandine", "vest_color": Color(0.24, 0.15, 0.09)}],
	["vest", "cuirass", {"vest": "cuirass", "vest_color": Color(0.55, 0.55, 0.58)}],
	["coat", "greatcoat", {"coat": "greatcoat", "coat_color": Color(0.1, 0.09, 0.09), "trim_color": Color(0.85, 0.68, 0.24)}],
	["coat", "captain", {"coat": "captain", "coat_color": Color(0.4, 0.1, 0.12), "trim_color": Color(0.85, 0.68, 0.24)}],
	["hands", "gauntlets", {"gloves": true, "gloves_color": Color(0.1, 0.08, 0.07), "gauntlets": true}],
	["feet", "greaves", {"feet": "greaves", "feet_color": Color(0.1, 0.08, 0.07)}],
	["accessory", "pauldron", {"pauldron": true}],
	["accessory", "cape", {"cape": true, "cape_color": Color(0.4, 0.1, 0.12)}],
]


static func random_piece(rng: RandomNumberGenerator, tier: int) -> ItemData:
	var p: Array = PLUNDER[rng.randi() % PLUNDER.size()]
	return make(str(p[0]), str(p[1]), p[2], "", tier)


static func is_outfit_key(k: String) -> bool:
	for keys in SLOT_KEYS.values():
		if k in keys:
			return true
	return k in ACCESSORIES or k in ACC_COLOR.values()


static func slot_label(kind: String) -> String:
	for s in SLOTS:
		if s[2] == kind:
			return s[1]
	return "Gear"


static func color_name(c: Color) -> String:
	var best := ""
	var bd := INF
	for e in COLOR_NAMES:
		var k: Color = e[1]
		var d := Vector3(c.r - k.r, c.g - k.g, c.b - k.b).length_squared()
		if d < bd:
			bd = d
			best = e[0]
	return best


## Make (and register) a gear item. `style` is the look value that names it
## (e.g. "longcoat"); `look` holds the keys it sets when worn.
static func make(kind: String, style: String, look: Dictionary, display: String = "", tier: int = 0) -> ItemData:
	var it := ItemData.new()
	it.item_type = ItemData.ItemType.GEAR
	it.rarity = tier as ItemData.Rarity
	it.gear_slot = kind
	it.look = look.duplicate(true)
	it.icon_kind = style
	it.stackable = false
	it.max_stack = 1
	it.defense = float(DEFENSE.get(style, 0.0))
	it.value = 4 + int(it.defense) * 3
	it.description = str(DESCRIPTIONS.get(style, ""))
	var nm := display
	if nm == "":
		nm = str(NAMES.get(style, style.capitalize()))
		if kind == "torso" and style == "shirt":
			nm = {"long": "Shirt", "short": "Short-sleeved Shirt", "none": "Sleeveless Shirt"}.get(str(look.get("sleeves", "long")), "Shirt")
		var ck := _main_color_key(kind, style)
		if ck != "" and look.has(ck) and style != "straw" and not style in STEEL_PIECES:
			nm = color_name(look[ck]) + " " + nm
	it.display_name = nm
	it.id = "gear_%s_%s_%d" % [kind, style, absi(hash(var_to_str(look)))] + ("@%d" % tier if tier > 0 else "")
	it.icon = GearIcons.icon(it)
	return ItemDB.register(it)


static func _main_color_key(kind: String, style: String) -> String:
	match kind:
		"head": return "hat_color"
		"torso": return "top_color"
		"vest": return "vest_color"
		"coat": return "coat_color"
		"legs": return "legs_color"
		"feet": return "feet_color"
		"belt": return "sash_color" if style == "sash" else ""
		"accessory": return str(ACC_COLOR.get(style, ""))
	return ""


## The outfit in a look as gear: {slot: ItemData} for the paper doll, plus
## "extra" -> Array of accessories beyond the two accessory slots.
static func items_from_look(lk: Dictionary) -> Dictionary:
	var out := {}
	var hat := str(lk.get("hat", "none"))
	if hat != "none":
		out["head"] = make("head", hat, {"hat": hat, "hat_color": lk.get("hat_color")})
	var top := str(lk.get("top", "shirt"))
	if top != "bare":
		out["torso"] = make("torso", top, {"top": top, "sleeves": lk.get("sleeves", "long"), "top_color": lk.get("top_color")})
	var vest := str(lk.get("vest", "none"))
	if vest != "none":
		out["vest"] = make("vest", vest, {"vest": vest, "vest_color": lk.get("vest_color")})
	var coat := str(lk.get("coat", "none"))
	if coat != "none":
		out["coat"] = make("coat", coat, {"coat": coat, "coat_color": lk.get("coat_color"), "trim_color": lk.get("trim_color")})
	if lk.get("gauntlets", false):
		out["hands"] = make("hands", "gauntlets", {"gloves": true, "gloves_color": lk.get("gloves_color"), "gauntlets": true})
	elif lk.get("gloves", false):
		out["hands"] = make("hands", "gloves", {"gloves": true, "gloves_color": lk.get("gloves_color")})
	var legs := str(lk.get("legs", "trousers"))
	out["legs"] = make("legs", legs, {"legs": legs, "legs_color": lk.get("legs_color")})
	var feet := str(lk.get("feet", "boots"))
	if feet != "barefoot":
		out["feet"] = make("feet", feet, {"feet": feet, "feet_color": lk.get("feet_color")})
	var belt := str(lk.get("belt", "none"))
	if belt != "none":
		out["belt"] = make("belt", belt, {"belt": belt, "belt_color": lk.get("belt_color"), "sash_color": lk.get("sash_color")})
	var extra: Array = []
	var n := 0
	for a in ACCESSORIES:
		if not lk.get(a, false):
			continue
		var part := {a: true}
		if ACC_COLOR.has(a):
			part[ACC_COLOR[a]] = lk.get(ACC_COLOR[a])
		var it := make("accessory", a, part)
		if n < 2:
			out["acc%d" % (n + 1)] = it
		else:
			extra.append(it)
		n += 1
	out["extra"] = extra
	return out


## What an empty slot looks like (smallclothes).
static func bare(kind: String, fem: bool) -> Dictionary:
	match kind:
		"head": return {"hat": "none"}
		"torso":
			# a plain sleeveless undershirt for feminine bodies, bare-chested otherwise
			return {"top": "shirt", "sleeves": "none", "top_color": CharacterLook.CLOTH[1]} if fem else {"top": "bare"}
		"vest": return {"vest": "none"}
		"coat": return {"coat": "none"}
		"hands": return {"gloves": false, "gauntlets": false}
		"legs": return {"legs": "shorts", "legs_color": CharacterLook.CLOTH[1]}
		"feet": return {"feet": "barefoot"}
		"belt": return {"belt": "none"}
	return {}


## Appearance + worn gear -> the full look for the body builder.
static func compose(appearance: Dictionary, equipped: Dictionary) -> Dictionary:
	var lk := appearance.duplicate(true)
	var fem := str(lk.get("body", "masc")) == "fem"
	for kind in SLOT_KEYS.keys():
		var it: ItemData = equipped.get(kind)
		lk.merge(it.look if it else bare(kind, fem), true)
	for a in ACCESSORIES:
		lk[a] = false
	for slot in ["acc1", "acc2"]:
		var it: ItemData = equipped.get(slot)
		if it:
			lk.merge(it.look, true)
	return lk
