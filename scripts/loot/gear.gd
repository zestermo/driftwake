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
## (1.30.3, docs/v1_30_3_slots.md) The two "Accessory" slots are gone: capes, cloaks and the mantle go on the Back (with
## the pack), pauldrons on the Shoulders (left, right or a pair), straps across the body on the Strap, the scarf on the
## Face, the apron on the Belt, and small things in two Trinket slots.
const SLOTS := [
	["head", "Head", "head"], ["face", "Face", "face"], ["torso", "Torso", "torso"], ["vest", "Vest", "vest"],
	["coat", "Coat", "coat"], ["shoulders", "Shoulders", "shoulders"], ["back", "Back", "back"], ["strap", "Strap", "strap"],
	["belt", "Belt", "belt"], ["hands", "Hands", "hands"], ["legs", "Legs", "legs"], ["feet", "Feet", "feet"],
	["trinket1", "Trinket", "trinket"], ["trinket2", "Trinket", "trinket"], ["equipment", "Equipment", "equipment"]]
## The equipment slot (was the instrument slot, v1.18): what's carried for the hands (an instrument, a fishing
## rod, later tools). Its look keys name what's carried; "equip_hidden" keeps it off the body (still usable).
const EQUIP_KEYS := ["instrument", "rod"]

## Look keys each slot kind controls.
const SLOT_KEYS := {
	"head": ["hat", "hat_color"],
	"face": ["face_wear", "face_color", "scarf", "scarf_color"],
	"torso": ["top", "sleeves", "top_color", "top_pattern"],
	"vest": ["vest", "vest_color", "vest_pattern"],
	"coat": ["coat", "coat_color", "trim_color", "coat_pattern"],
	"shoulders": ["pauldron", "pauldron_r"],
	"hands": ["gloves", "gloves_color", "gauntlets", "bracers", "long_gloves", "arm_wraps", "wraps_color"],
	"legs": ["legs", "legs_color", "legs_pattern"],
	"feet": ["feet", "feet_color"],
	"belt": ["belt", "belt_color", "sash_color", "apron", "apron_color"],
	"back": ["backpack", "backpack_color", "cape", "cape_color", "cape_tatter", "cloak", "cloak_color", "cloak_tatter",
		"mantle", "mantle_color"],
	"strap": ["bandolier", "baldric"],
	"equipment": ["instrument", "rod", "equip_hidden"],
}
## Accessories are on/off look flags (+ a color for some). (1.30.3) Each now has a slot kind (ACC_KIND); the small ones
## are trinkets (TRINKETS), two worn at once.
const ACCESSORIES := ["scarf", "pauldron", "earring", "eyepatch", "pouch", "apron", "cape", "bandolier", "necklace", "goggles", "mantle",
	"baldric", "spyglass", "cloak", "pauldron_r"]
const TRINKETS := ["earring", "eyepatch", "goggles", "spyglass", "necklace", "pouch"]
## An accessory's slot kind (old saves' and drops' "accessory" items become these in make()).
const ACC_KIND := {"scarf": "face", "pauldron": "shoulders", "pauldron_r": "shoulders", "pauldrons": "shoulders",
	"cape": "back", "cloak": "back", "mantle": "back", "bandolier": "strap", "baldric": "strap", "apron": "belt",
	"earring": "trinket", "eyepatch": "trinket", "goggles": "trinket", "spyglass": "trinket", "necklace": "trinket",
	"pouch": "trinket", "shark_tooth": "trinket"}
## The three pauldron items: the left one (today's, on the left arm), the right, and the pair.
const PAULDRONS := {"pauldron": {"pauldron": true}, "pauldron_r": {"pauldron_r": true},
	"pauldrons": {"pauldron": true, "pauldron_r": true}}
## Pieces that can't be worn together ([look key, values or true] each side, the reason), and pieces worn but not drawn
## while another covers them (docs/v1_30_3_slots.md). Judged on the look the pieces carry, so a styled piece (the
## Bulwark Helm, drawn as a helm) follows its shape.
const HELMS := ["helm", "kettle", "morion"]
const FULL_MASKS := ["oni", "iron_mask", "mask"]
const BLOCKS := [
	[["cloak", true], ["pauldron", true], "The cloak covers the shoulders"],
	[["cloak", true], ["pauldron_r", true], "The cloak covers the shoulders"],
	[["mantle", true], ["coat", ["greatcoat"]], "The greatcoat has its own shoulder cape"],
	[["mantle", true], ["coat_drape", true], "The mantle and a draped coat both sit on the shoulders"],
	[["hat", HELMS], ["face_wear", FULL_MASKS], "A helm's face guards won't go over a full mask"],
	[["apron", true], ["coat", ["frock"]], "The frock is buttoned closed to the knee"],
]
const HIDES := [
	[["goggles", true], ["hat", HELMS + ["hood", "coif"]]],
	[["eyepatch", true], ["face_wear", FULL_MASKS + ["eye_wrap"]]],
	[["earring", true], ["hat", ["hood", "coif", "helm"]]],
	[["necklace", true], ["scarf", true]],
]
const ACC_COLOR := {"scarf": "scarf_color", "apron": "apron_color", "cape": "cape_color", "mantle": "mantle_color", "cloak": "cloak_color"}
## How torn a cape or cloak is (0..1, BodyBuilder._drape_rows), carried by the item.
const ACC_TATTER := {"cape": "cape_tatter", "cloak": "cloak_tatter"}
## Tailors' skins (1.24): a pattern woven into a piece's cloth ("<slot>_pattern": BodyBuilder._cloth), named first.
const PATTERN_NAMES := {"stripes": "Striped", "check": "Check", "brocade": "Brocade", "patched": "Patched"}
## Steel (and gold) pieces are named plainly ("Morion", not "Grey Morion").
const STEEL_PIECES := ["morion", "cuirass", "mail", "gauntlets", "greaves", "pauldron", "pauldron_r", "pauldrons", "kettle", "coif", "crown", "scale", "sabatons", "helm",
	"bulwark_helm", "bulwark_gauntlets", "iron_mask"]
## (1.25) Pieces cut from another style's garment: style -> the garment it's drawn as (its look carries that garment;
## its icon is that garment's). Their stats, names and sets go by their own style.
const SHAPE_OF := {
	"bulwark_helm": "helm", "bulwark_brigandine": "brigandine", "bulwark_gauntlets": "gauntlets",
	"bosun_coat": "longcoat", "powder_belt": "belt_sash",
}
## Named plainly, with no colour or pattern before it (a set's pieces).
const NAMED_PIECES := ["bulwark_brigandine", "bosun_coat"]
## (1.25) The new pieces' looks, as the shops, the treasure merchants and plunder make them.
const LOOKS := {
	"bulwark_helm": ["head", {"hat": "helm"}],
	"bulwark_brigandine": ["vest", {"vest": "brigandine", "vest_color": Color(0.36, 0.12, 0.1)}],
	"bulwark_gauntlets": ["hands", {"gloves": true, "gloves_color": Color(0.36, 0.12, 0.1), "gauntlets": true}],
	"bosun_coat": ["coat", {"coat": "longcoat", "coat_color": Color(0.14, 0.18, 0.34), "trim_color": Color(0.92, 0.9, 0.84)}],
	"powder_belt": ["belt", {"belt": "belt_sash", "belt_color": Color(0.1, 0.08, 0.07), "sash_color": Color(0.28, 0.28, 0.3)}],
	"shark_tooth": ["trinket", {"necklace": true}],
}

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
	"scarf": "Scarf", "pauldron": "Pauldron (Left)", "earring": "Gold Earring", "eyepatch": "Eyepatch",
	"pouch": "Belt Pouch", "apron": "Apron",
	"cavalier": "Cavalier Hat", "morion": "Morion", "turban": "Turban",
	"cuirass": "Cuirass", "brigandine": "Brigandine", "mail": "Mail Shirt",
	"greatcoat": "Greatcoat", "gauntlets": "Gauntlets", "greaves": "Greaves",
	"cape": "Cape", "bandolier": "Bandolier",
	"kettle": "Kettle Helm", "fez": "Fez", "headband": "Headband", "crown": "Crown", "coif": "Mail Coif",
	"doublet": "Doublet", "kimono": "Kimono",
	"jerkin": "Leather Jerkin", "padded": "Padded Jack", "scale": "Scale Vest",
	"haori": "Haori", "duster": "Duster", "frock": "Frock Coat",
	"bracers": "Leather Bracers", "long_gloves": "Long Gloves",
	"hakama": "Hakama", "leathers": "Leather Trousers",
	"sandals": "Sandals", "sabatons": "Sabatons",
	"wide_belt": "Wide Belt",
	"necklace": "Tooth Necklace", "goggles": "Brass Goggles", "mantle": "Fur Mantle",
	"slouch": "Slouch Hat", "helm": "Boarding Helm", "striped": "Striped Shirt", "harness": "Leather Harness",
	"admiral": "Admiral's Coat", "slops": "Slops", "cavalier_boots": "Cavalier Boots", "baldric": "Sword Baldric", "spyglass": "Spyglass",
	"cloak": "Cloak",
	"bulwark_helm": "Bulwark Helm", "bulwark_brigandine": "Bulwark Brigandine", "bulwark_gauntlets": "Bulwark Gauntlets",
	"bosun_coat": "Bosun's Coat", "powder_belt": "Powder Belt", "shark_tooth": "Shark's Tooth",
	"pauldron_r": "Pauldron (Right)", "pauldrons": "Pauldrons",
	"mask": "Carved Mask", "oni": "Oni Mask", "half_mask": "Half Mask", "iron_mask": "Iron Faceplate", "kerchief": "Kerchief",
	"mouth_guard": "Mouth Guard", "bandage": "Head Bandage", "eye_wrap": "Eye Wrap", "arm_wraps": "Arm Wraps", "foot_wraps": "Foot Wraps",
	"backpack": "Traveller's Pack", "parachute": "Parachute Pants", "jester": "Jester's Cap", "motley": "Motley Doublet", "motley_hose": "Motley Hose", "curled": "Curled Shoes",
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
	"pauldron": "A riveted shoulder plate for the left arm.",
	"pauldron_r": "A riveted shoulder plate for the right arm.",
	"pauldrons": "A matched pair of riveted shoulder plates.",
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
	"cape": "A light cape from the shoulders to the knees. Mostly for the look of it.",
	"cloak": "Heavy canvas from a gathered collar to the knees, the hem rolled and sewn. Turns wind, rain and the odd glancing cut.",
	"bandolier": "A strap across the chest, cartridges along it.",
	"kettle": "A steel skullcap under a wide brim. Rain, sun and falling spars all run off it.",
	"fez": "A tall felt cap with a tassel. Worn by men who have been somewhere.",
	"headband": "A strip of cloth tied round the brow. Keeps the sweat out of your eyes in a long fight.",
	"crown": "A gold circlet with a stone at the brow. Someone, somewhere, is missing it.",
	"coif": "A hood of riveted rings that falls to the shoulders. Turns a cut to the neck.",
	"doublet": "A fitted jacket buttoned to the throat, with a short skirt. Townsman's wear.",
	"kimono": "A wrapped robe with crossed lapels and wide sleeves, from the far side of the sea.",
	"jerkin": "A sleeveless leather jerkin laced up the front. Takes a knife better than linen does.",
	"padded": "A jack of thick quilted cloth. Soft armour, and warmer than it looks.",
	"scale": "Leather hung with rows of steel scales, front and back. Heavy, and nothing gets through.",
	"haori": "A straight half-coat worn open over the kimono, tied with two cords. A swordsman's coat.",
	"duster": "A long oilskin coat with a high collar, split for riding or climbing. Sheds a squall.",
	"frock": "A long coat buttoned closed in two rows of brass, its skirts to the knee. Dressed for town.",
	"bracers": "Laced leather guards over the forearms. Catches a blade that gets past the hilt.",
	"long_gloves": "Leather gloves cuffed to the elbow. Hauling anchor chain, or holding a hawk.",
	"hakama": "Wide pleated trousers that hide the feet. Nobody sees your stance coming.",
	"leathers": "Trousers of soft leather. Wear through canvas and these are still going.",
	"sandals": "A leather sole and two straps. All a deck needs in the heat.",
	"sabatons": "Boots under steel: a toe cap and plates over the instep and ankle. Kick a door in.",
	"wide_belt": "A broad belt in two straps with a buckle on each. Holds everything up and takes a blow.",
	"necklace": "A cord strung with the teeth of something big. You'd rather not say what.",
	"goggles": "Brass goggles with sea-green glass, pushed up on the brow. For spray, sand and looking the part.",
	"mantle": "A fur mantle over the shoulders, clasped at the throat. Warm on the night watch.",
	"slouch": "A soft wide hat with one side pinned up by a brooch and a plume. Swagger you can wear.",
	"helm": "An open-faced steel helm with a nose bar, cheek plates and a guard over the nape. Made for the first man over the rail.",
	"striped": "A boat-necked sailor's shirt in broad stripes. You can spot a hand who's lost overboard in it.",
	"harness": "Leather straps crossed over chest and back, ringed with iron where they meet. A brawler's armour.",
	"admiral": "A long coat heavy with gold: braid down the front, bullion fringe on the shoulders. Fleets have struck to less.",
	"slops": "Wide sailors' trousers that flare below the knee. Roll them up and they never drag in the bilge.",
	"cavalier_boots": "Tall boots turned down in a wide bucket cuff, a gilt buckle over the instep. For the deck and the duel.",
	"baldric": "A broad strap from shoulder to hip, a gilt buckle on the chest. It carries the sword and the look.",
	"spyglass": "A brass spyglass tucked in the belt. Sails on the horizon are a lot less surprising.",
	"bulwark_helm": "A boarding helm with its plates doubled. Made for the man who goes over the rail first and holds the gap.",
	"bulwark_brigandine": "Oxblood leather over close-set steel plates. The front rank's coat: it means to be hit.",
	"bulwark_gauntlets": "Plate over oxblood leather, the knuckles ridged. A guard that doesn't give.",
	"bosun_coat": "A long navy coat with white piping and a whistle on a lanyard. Every hand on deck knows who's wearing it.",
	"powder_belt": "A belt hung with powder flasks and a priming horn over a grey sash. Reloading is half the fight.",
	"shark_tooth": "One great tooth on a cord. Sailors swear the sea gives back a man who wears it.",
	"mask": "A lacquered wooden mask with narrow eyes. Nobody reads your face, and nobody forgets it.",
	"oni": "A red demon's face with horns and fangs, carved for a festival and worn for worse.",
	"half_mask": "A strip of stiff cloth over the eyes. Hides who you are, if not very well.",
	"iron_mask": "A riveted steel plate over the whole face, slit for the eyes. Blows meant for your nose ring off it.",
	"kerchief": "A cloth tied over the nose and mouth. Keeps out dust, smoke and witnesses.",
	"mouth_guard": "A leather guard strapped over the mouth and jaw. Bite down and keep fighting.",
	"bandage": "Linen wound round the brow, the ends left trailing. Proof you've been in a fight.",
	"eye_wrap": "A bandage wound round the head and over one eye. You'll see well enough with the other.",
	"arm_wraps": "Cloth strips wound from the knuckles up the forearms. A brawler's gloves.",
	"foot_wraps": "Strips of cloth bound round bare feet and ankles. Quiet on a deck and quick on rigging.",
	"backpack": "A canvas pack on two straps, a bedroll under it and a pot and a lantern hung off its sides. Everything you need for a night ashore, rattling.",
	"parachute": "Trousers with yards too much cloth, gathered at the ankle. They billow when you run and nobody sees your knees move.",
	"jester": "A cap of two colours with three floppy points, a bell on each. Hard to be taken seriously in. That's the trick.",
	"motley": "A doublet split down the middle in two colours, its collar cut into points hung with bells.",
	"motley_hose": "Tight hose, one leg in each colour. The court's fool and the deck's acrobat swear by them.",
	"curled": "Soft shoes whose toes curl up and back into a spiral, a bell at the tip. You'll never sneak anywhere again.",
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
	"scarf": 0.0, "pauldron": 3.0, "pauldron_r": 3.0, "pauldrons": 5.0, "earring": 0.0, "eyepatch": 0.0, "pouch": 0.0, "apron": 1.0,
	"cavalier": 2.0, "morion": 5.0, "turban": 2.0,
	"cuirass": 7.0, "brigandine": 5.0, "mail": 5.0,
	"greatcoat": 5.0, "gauntlets": 3.0, "greaves": 4.0,
	"cape": 1.0, "bandolier": 1.0,
	"kettle": 4.0, "fez": 1.0, "headband": 0.0, "crown": 2.0, "coif": 4.0,
	"doublet": 2.0, "kimono": 1.0,
	"jerkin": 3.0, "padded": 4.0, "scale": 6.0,
	"haori": 2.0, "duster": 4.0, "frock": 4.0,
	"bracers": 2.0, "long_gloves": 2.0,
	"hakama": 2.0, "leathers": 3.0,
	"sandals": 0.0, "sabatons": 3.0,
	"wide_belt": 1.0,
	"necklace": 0.0, "goggles": 0.0, "mantle": 2.0,
	"slouch": 2.0, "helm": 5.0, "striped": 1.0, "harness": 2.0, "admiral": 6.0, "slops": 2.0, "cavalier_boots": 3.0,
	"baldric": 1.0, "spyglass": 1.0,
	"cloak": 2.0,
	"bulwark_helm": 5.0, "bulwark_brigandine": 5.0, "bulwark_gauntlets": 3.0, "bosun_coat": 4.0,
	"powder_belt": 1.0, "shark_tooth": 0.0,
	"mask": 1.0, "oni": 1.0, "half_mask": 0.0, "iron_mask": 4.0, "kerchief": 0.0, "mouth_guard": 2.0, "bandage": 0.0, "eye_wrap": 0.0,
	"arm_wraps": 1.0, "foot_wraps": 1.0,
	"backpack": 1.0, "parachute": 2.0, "jester": 1.0, "motley": 1.0, "motley_hose": 1.0, "curled": 1.0,
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
	["accessory", "cape", {"cape": true, "cape_color": Color(0.4, 0.1, 0.12), "cape_tatter": 0.85}],
	["head", "kettle", {"hat": "kettle"}],
	["head", "coif", {"hat": "coif"}],
	["head", "crown", {"hat": "crown"}],
	["vest", "scale", {"vest": "scale", "vest_color": Color(0.24, 0.15, 0.09)}],
	["coat", "duster", {"coat": "duster", "coat_color": Color(0.24, 0.17, 0.12), "trim_color": Color(0.1, 0.09, 0.09)}],
	["coat", "frock", {"coat": "frock", "coat_color": Color(0.14, 0.18, 0.34), "trim_color": Color(0.85, 0.68, 0.24)}],
	["feet", "sabatons", {"feet": "sabatons", "feet_color": Color(0.1, 0.08, 0.07)}],
	["accessory", "mantle", {"mantle": true, "mantle_color": Color(0.9, 0.88, 0.8)}],
	["coat", "admiral", {"coat": "admiral", "coat_color": Color(0.14, 0.18, 0.34), "trim_color": Color(0.88, 0.7, 0.28)}],
	["head", "helm", {"hat": "helm"}],
	["head", "slouch", {"hat": "slouch", "hat_color": Color(0.1, 0.09, 0.09)}],
	["feet", "cavalier_boots", {"feet": "cavalier_boots", "feet_color": Color(0.36, 0.12, 0.1)}],
	["accessory", "spyglass", {"spyglass": true}],
	["head", "bulwark_helm", LOOKS["bulwark_helm"][1]],
	["vest", "bulwark_brigandine", LOOKS["bulwark_brigandine"][1]],
	["hands", "bulwark_gauntlets", LOOKS["bulwark_gauntlets"][1]],
	["coat", "bosun_coat", LOOKS["bosun_coat"][1]],
	["accessory", "shark_tooth", LOOKS["shark_tooth"][1]],
	["face", "oni", {"face_wear": "oni", "face_color": Color(0.66, 0.14, 0.12)}],
	["face", "iron_mask", {"face_wear": "iron_mask"}],
	["face", "half_mask", {"face_wear": "half_mask", "face_color": Color(0.1, 0.09, 0.09)}],
	["head", "jester", {"hat": "jester", "hat_color": Color(0.36, 0.2, 0.44), "motley_color": Color(0.8, 0.62, 0.2)}],
	["legs", "parachute", {"legs": "parachute", "legs_color": Color(0.42, 0.42, 0.2)}],
	["back", "backpack", {"backpack": true, "backpack_color": Color(0.42, 0.42, 0.2)}],
]


## (a purple or better one gets its own roll from the stream's state: read, not drawn, so the caller's draws stay put)
static func random_piece(rng: RandomNumberGenerator, tier: int) -> ItemData:
	var p: Array = PLUNDER[rng.randi() % PLUNDER.size()]
	return make(str(p[0]), str(p[1]), p[2], "", tier, absi(rng.state % 9973) + 1 if tier >= GearStats.BONUS_TIER else 0)


static func is_outfit_key(k: String) -> bool:
	for keys in SLOT_KEYS.values():
		if k in keys:
			return true
	return k in ACCESSORIES or k in ACC_COLOR.values() or k in ACC_TATTER.values() or k in ["coat_drape", "motley_color"]


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
static func make(kind: String, style: String, look: Dictionary, display: String = "", tier: int = 0, roll: int = 0) -> ItemData:
	# (1.30.3) "accessory" is the old kind: old saves, chests and the shops' tables still name it; each piece has its slot now
	if kind == "accessory":
		kind = str(ACC_KIND.get(style, "trinket"))
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
		if ck != "" and look.has(ck) and style != "straw" and not style in STEEL_PIECES and not style in NAMED_PIECES:
			nm = color_name(look[ck]) + " " + nm
		var pat := str(look.get(ck.trim_suffix("_color") + "_pattern", "")) if ck != "" and not style in NAMED_PIECES else ""
		if pat != "":
			nm = str(PATTERN_NAMES[pat]) + " " + nm
	it.display_name = nm
	it.gear_roll = roll
	it.id = "gear_%s_%s_%d" % [kind, style, absi(hash(var_to_str(look)))] + ("~%d" % roll if roll != 0 else "") + ("@%d" % tier if tier > 0 else "")
	it.icon = GearIcons.icon(it)
	return ItemDB.register(it)


static func _main_color_key(kind: String, style: String) -> String:
	match kind:
		"head": return "hat_color"
		"face": return "scarf_color" if style == "scarf" else "face_color"
		"back": return str(ACC_COLOR.get(style, "backpack_color"))
		"shoulders", "strap", "trinket": return str(ACC_COLOR.get(style, ""))
		"hands": return "wraps_color" if style == "arm_wraps" else ""
		"torso": return "top_color"
		"vest": return "vest_color"
		"coat": return "coat_color"
		"legs": return "legs_color"
		"feet": return "feet_color"
		"belt": return "sash_color" if style == "sash" else ("apron_color" if style == "apron" else "")
		"accessory": return str(ACC_COLOR.get(style, ""))
	return ""


## The outfit in a look as gear: {slot: ItemData} for the paper doll, plus
## "extra" -> Array of accessories beyond the two accessory slots.
static func items_from_look(lk: Dictionary) -> Dictionary:
	var out := {}
	# (the jester's pieces carry their second colour)
	var mot := {"motley_color": lk.get("motley_color", CharacterLook.CLOTH[15])}
	var hat := str(lk.get("hat", "none"))
	if hat != "none":
		out["head"] = make("head", hat, {"hat": hat, "hat_color": lk.get("hat_color")}.merged(mot if hat in CharacterLook.JESTER else {}))
	var fw := str(lk.get("face_wear", "none"))
	if fw != "none":
		out["face"] = make("face", fw, {"face_wear": fw, "face_color": lk.get("face_color", CharacterLook.CLOTH[0])})
	var top := str(lk.get("top", "shirt"))
	if top != "bare":
		out["torso"] = make("torso", top, {"top": top, "sleeves": lk.get("sleeves", "long"), "top_color": lk.get("top_color")}.merged(mot if top in CharacterLook.JESTER else {}))
	var vest := str(lk.get("vest", "none"))
	if vest != "none":
		out["vest"] = make("vest", vest, {"vest": vest, "vest_color": lk.get("vest_color")})
	var coat := str(lk.get("coat", "none"))
	if coat != "none":
		out["coat"] = make("coat", coat, {"coat": coat, "coat_color": lk.get("coat_color"), "trim_color": lk.get("trim_color")})
	if lk.get("gauntlets", false):
		out["hands"] = make("hands", "gauntlets", {"gloves": true, "gloves_color": lk.get("gloves_color"), "gauntlets": true})
	elif lk.get("long_gloves", false):
		out["hands"] = make("hands", "long_gloves", {"gloves": true, "gloves_color": lk.get("gloves_color"), "long_gloves": true})
	elif lk.get("bracers", false):
		out["hands"] = make("hands", "bracers", {"gloves": false, "gloves_color": lk.get("gloves_color"), "bracers": true})
	elif lk.get("gloves", false):
		out["hands"] = make("hands", "gloves", {"gloves": true, "gloves_color": lk.get("gloves_color")})
	elif lk.get("arm_wraps", false):
		out["hands"] = make("hands", "arm_wraps", {"arm_wraps": true, "wraps_color": lk.get("wraps_color", CharacterLook.CLOTH[0])})
	var legs := str(lk.get("legs", "trousers"))
	out["legs"] = make("legs", legs, {"legs": legs, "legs_color": lk.get("legs_color")}.merged(mot if legs in CharacterLook.JESTER else {}))
	var feet := str(lk.get("feet", "boots"))
	if feet != "barefoot":
		out["feet"] = make("feet", feet, {"feet": feet, "feet_color": lk.get("feet_color")}.merged(mot if feet in CharacterLook.JESTER else {}))
	if lk.get("backpack", false):
		out["back"] = make("back", "backpack", {"backpack": true, "backpack_color": lk.get("backpack_color", CharacterLook.CLOTH[2])})
	var belt := str(lk.get("belt", "none"))
	if belt != "none":
		out["belt"] = make("belt", belt, {"belt": belt, "belt_color": lk.get("belt_color"), "sash_color": lk.get("sash_color")})
	# (1.30.3) the accessories each to their slot (the first piece in a slot wins; the rest go to the bag)
	var extra: Array = []
	var pl: bool = lk.get("pauldron", false)
	var pr: bool = lk.get("pauldron_r", false)
	if pl or pr:
		var ps := "pauldrons" if pl and pr else ("pauldron" if pl else "pauldron_r")
		out["shoulders"] = make("shoulders", ps, PAULDRONS[ps])
	var n := 0
	for a in ACCESSORIES:
		if not lk.get(a, false) or a in ["pauldron", "pauldron_r"]:
			continue
		var part := {a: true}
		if ACC_COLOR.has(a):
			part[ACC_COLOR[a]] = lk.get(ACC_COLOR[a])
		if ACC_TATTER.has(a) and lk.has(ACC_TATTER[a]):
			part[ACC_TATTER[a]] = lk[ACC_TATTER[a]]
		var kind := str(ACC_KIND[a])
		var it := make(kind, a, part)
		var slot := kind
		if kind == "trinket":
			slot = "trinket%d" % (n + 1) if n < 2 else ""
			n += 1
		if slot == "" or out.has(slot):
			extra.append(it)
		else:
			out[slot] = it
	out["extra"] = extra
	return out


## What an empty slot looks like (smallclothes).
static func bare(kind: String, fem: bool) -> Dictionary:
	match kind:
		"head": return {"hat": "none"}
		"face": return {"face_wear": "none", "scarf": false}
		"back": return {"backpack": false, "cape": false, "cloak": false, "mantle": false}
		"shoulders": return {"pauldron": false, "pauldron_r": false}
		"strap": return {"bandolier": false, "baldric": false}
		"torso":
			# a plain sleeveless undershirt for feminine bodies, bare-chested otherwise
			return {"top": "shirt", "sleeves": "none", "top_color": CharacterLook.CLOTH[1]} if fem else {"top": "bare"}
		"vest": return {"vest": "none"}
		"coat": return {"coat": "none"}
		"hands": return {"gloves": false, "gauntlets": false, "bracers": false, "long_gloves": false, "arm_wraps": false}
		"legs": return {"legs": "shorts", "legs_color": CharacterLook.CLOTH[1]}
		"feet": return {"feet": "barefoot"}
		"belt": return {"belt": "none", "apron": false}
		"equipment": return {"instrument": "none", "rod": "none", "equip_hidden": false}
	return {}


## Appearance + worn gear -> the full look for the body builder. `hidden`: item ids kept off the body; `draped`: coats
## (item ids) worn over the shoulders, their sleeves empty (look "coat_drape").
static func compose(appearance: Dictionary, equipped: Dictionary, hidden: Dictionary = {}, draped: Dictionary = {}) -> Dictionary:
	var lk := appearance.duplicate(true)
	var fem := str(lk.get("body", "masc")) == "fem"
	for a in ACCESSORIES:
		lk[a] = false
	for k in ACC_TATTER.values():
		lk.erase(k)
	for kind in SLOT_KEYS.keys():
		var it: ItemData = equipped.get(kind)
		for k in SLOT_KEYS[kind]:
			if k.ends_with("_pattern"):
				lk.erase(k)
		# (1.30.3: the slot's bare look first, then the piece: a slot holds several kinds of piece now, a cape or a pack)
		lk.merge(bare(kind, fem), true)
		if it:
			lk.merge(it.look, true)
	var eq: ItemData = equipped.get("equipment")
	lk["equip_hidden"] = eq != null and hidden.has(eq.id)
	var ct: ItemData = equipped.get("coat")
	lk["coat_drape"] = ct != null and draped.has(ct.id)
	for slot in ["trinket1", "trinket2"]:
		var it: ItemData = equipped.get(slot)
		if it:
			lk.merge(it.look, true)
	# what another piece covers is worn, not drawn
	for hd in HIDES:
		if _has(lk, hd[0]) and _has(lk, hd[1]):
			lk[hd[0][0]] = false
	return lk


## Whether a look has [key, true] or [key, [values...]].
static func _has(lk: Dictionary, cond: Array) -> bool:
	var v = lk.get(cond[0])
	if cond[1] is Array:
		return str(v) in cond[1]
	return v == cond[1]


## (1.30.3) Why the pieces in `equipped` (slot -> item) can't be worn together, or "" when they can; `draped` as compose's.
static func clash(equipped: Dictionary, draped: Dictionary = {}) -> String:
	var lk := compose({}, equipped, {}, draped)
	for b in BLOCKS:
		if _has(lk, b[0]) and _has(lk, b[1]):
			return str(b[2])
	return ""
