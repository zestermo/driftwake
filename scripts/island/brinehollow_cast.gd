class_name BrinehollowCast
extends RefCounted
## Brinehollow's people as data for KitLife.spawn: who they are, where they stand
## (spots from the layout and from markers in its buildings), their looks,
## dialogue ids, shops and barks (`before`/`after` story flags), walking routes.

const L := preload("res://scripts/npc/character_look.gd")
## The market street's customers, porters and kids (10 townsfolk): off for v1.17, which failed the perf gate at
## Brinehollow (+28-32% frame time over v1.16; Zach, 2026-10-17). True brings them back once the town is cheaper.
const CROWD := false


## The dockhands walking the quay (along its back, clear of the booth, the yard and the crane).
static func dockhands(isl: StarterIsland) -> Array:
	var h: KitHarbour = isl.harbour
	var y := h.quay_y
	var a := h.quay_pt(maxf(h.s0 + 4.0, -30.0), 14.0)
	var b := h.quay_pt(-11.0, 14.0)
	var c := h.quay_pt(minf(h.s1 - 6.0, 38.0), 13.5)
	var d := h.quay_pt(22.0, 13.5)
	var out: Array = []
	for spec in [[[a, b], "Dockhand Rook", ["Mind your feet, Captain. Rope everywhere, and half of it's attached to something.",
			"That junk's out of the far east. Smells of tea and gunpowder.", "Odile's got us hauling cargo since dawn. I've forgotten what my hands are for.",
			{"text": "You're the one Pell found on the west sand? You look better. Not good. Better.", "before": "see_vey"},
			{"text": "Tackett finally let that sloop go? To you? Bold. I like it.", "after": "tackett_ship"}], 0.85],
			[[c, d], "Merchant Ysolde", ["Silk, spice, and nothing the harbourmaster needs to see. Kidding. Mostly.",
			"The merchantman's mine. Well. The bank's. Well. Mine on Tuesdays.",
			{"text": "Pirates past the reef again. Bad for trade. Good for the price of rum.", "before": "morrow"},
			{"text": "Trade's picking up since Morrow fell. I might even pay the bank.", "after": "morrow"}], 1.15]]:
		var route := KitLife.route(isl.kit, spec[0], y)
		out.append({"cfg": {"name": spec[1], "voice": spec[3], "barks": spec[2], "look": KitLife.look_for(spec[1]), "waypoints": route},
			"at": Vector2(route[0].x, route[0].z), "face": Vector2(1, 0), "y": y})
	return out


## Everyone else, in the order they're made.
static func people(isl: StarterIsland) -> Array:
	var kit := isl.kit
	var cast: Array = []
	# Harbormaster at her booth by the pier
	cast.append({"cfg": {
		"name": "Harbormaster Odile", "dialogue": "odile", "voice": 1.15,
		"look": {"body": "fem", "build": "average", "height": 1.02, "skin": L.SKIN_TONES[4],
			"head": "square", "nose": "straight", "eyes": 4, "brows": 3, "mouth": 0, "eye_color": L.EYE_COLORS[0],
			"hair": "bun", "hair_color": L.HAIR_COLORS[0], "hat": "cap", "hat_color": L.CLOTH[8],
			"top": "shirt", "top_color": L.CLOTH[1], "coat": "jacket", "coat_color": L.CLOTH[8],
			"trim_color": L.TRIM[0], "legs": "trousers", "legs_color": L.CLOTH[6],
			"feet": "tall_boots", "feet_color": L.LEATHER[0], "belt": "belt", "belt_color": L.LEATHER[1],
			"pouch": true},
	}, "at": isl.odile_at, "face": isl.odile_face})

	# the shipwright by the boat he's building (talk: his yard, GameMenu "yard")
	cast.append({"cfg": {
		"name": "Shipwright Tackett", "dialogue": "tackett", "voice": 0.78,
		"look": {"body": "masc", "build": "broad", "height": 1.0, "skin": L.SKIN_TONES[2],
			"head": "square", "nose": "broad", "eyes": 2, "brows": 1, "mouth": 2,
			"hair": "crop", "hair_color": L.HAIR_COLORS[3], "facial_hair": "chops", "hat": "none",
			"top": "shirt", "top_color": L.CLOTH[2], "sleeves": "short", "apron": true, "apron_color": L.LEATHER[1],
			"legs": "trousers", "legs_color": L.CLOTH[6], "feet": "boots", "feet_color": L.LEATHER[0],
			"belt": "belt", "belt_color": L.LEATHER[2]},
	}, "at": isl.tackett_at, "face": Vector2(-1, 0.25)})

	# Tavern keeper behind his bar, inside
	cast.append({"cfg": {
		"name": "Gus Brannock", "dialogue": "gus", "voice": 0.72,
		"look": {"body": "masc", "build": "stout", "height": 1.05, "skin": L.SKIN_TONES[1],
			"head": "round", "nose": "broad", "eyes": 0, "brows": 1, "mouth": 1,
			"hair": "bald", "hair_color": L.HAIR_COLORS[1], "facial_hair": "beard", "hat": "none",
			"top": "shirt", "top_color": L.CLOTH[0], "sleeves": "short", "apron": true, "apron_color": L.CLOTH[0],
			"legs": "trousers", "legs_color": L.CLOTH[3], "feet": "boots", "feet_color": L.LEATHER[1],
			"belt": "belt", "belt_color": L.LEATHER[2]},
	}}.merged(KitLife.at_marker(kit, isl._tavern, "Barkeep")))

	# the old net-mender on his bench at the quay's edge, looking out to sea
	cast.append({"cfg": {
		"name": "Old Pell", "dialogue": "pell", "voice": 0.82, "seated": true,
		"look": {"body": "masc", "build": "slim", "height": 0.96, "skin": L.SKIN_TONES[3],
			"head": "long", "nose": "hooked", "eyes": 3, "brows": 4, "mouth": 0, "marks": "age_lines",
			"hair": "crop", "hair_color": L.HAIR_COLORS[8], "facial_hair": "long_beard", "hat": "straw",
			"hat_color": L.CLOTH[13], "top": "tunic", "top_color": L.CLOTH[10], "sleeves": "short",
			"legs": "breeches", "legs_color": L.CLOTH[2], "feet": "barefoot", "belt": "sash",
			"sash_color": L.CLOTH[1], "scarf": true, "scarf_color": L.CLOTH[13]},
	}, "at": isl.pell_at, "face": isl.dock_dir, "y": isl.harbour.quay_y})

	# Retired marine in the training yard
	cast.append({"cfg": {
		"name": "Sergeant Vey", "dialogue": "vey", "voice": 0.9,
		"look": {"body": "masc", "build": "broad", "height": 1.05, "skin": L.SKIN_TONES[5],
			"head": "square", "nose": "broad", "eyes": 1, "brows": 3, "mouth": 3,
			"hair": "crop", "hair_color": L.HAIR_COLORS[7], "facial_hair": "chops", "hat": "bicorne",
			"hat_color": L.CLOTH[5], "top": "shirt", "top_color": L.CLOTH[0],
			"coat": "jacket", "coat_color": L.CLOTH[13], "trim_color": L.TRIM[2],
			"legs": "trousers", "legs_color": L.CLOTH[0], "feet": "tall_boots", "feet_color": L.LEATHER[0],
			"belt": "belt", "belt_color": L.LEATHER[0], "pauldron": true},
	}, "at": StarterIsland.TRAINING + Vector2(3, 2), "face": Vector2(1, 0)})

	# Trader at the fruit stall in the market
	cast.append(_vendor(kit, isl._stall_a, {
		"name": "Nessa", "dialogue": "nessa", "voice": 1.25,
		"look": {"body": "fem", "build": "average", "skin": L.SKIN_TONES[6],
			"head": "round", "nose": "small", "eyes": 5, "brows": 2, "mouth": 1,
			"hair": "braids", "hair_color": L.HAIR_COLORS[0], "hat": "bandana", "hat_color": L.CLOTH[15],
			"top": "blouse", "top_color": L.CLOTH[13], "vest": "corset", "vest_color": L.CLOTH[3],
			"legs": "skirt", "legs_color": L.CLOTH[14], "feet": "shoes", "feet_color": L.LEATHER[2],
			"belt": "sash", "sash_color": L.CLOTH[15], "earring": true},
	}))

	# the other market vendors
	cast.append(_vendor(kit, isl._stall_fish, {
		"name": "Marlo", "voice": 0.85, "shop": "marlo",
		"barks": [
			"Fresh off the boat! Well. Fresh-ish. Off a boat.",
			"Snapper, mackerel, something with too many teeth. Pick one.",
			"Gus buys my fish for his stew. Don't ask him what else goes in it.",
			{"text": "Smugglers gone off the south beach, and the boats come home full. Coincidence? Marlo thinks not.", "after": "smugglers"},
		],
		"look": {"body": "masc", "build": "stout", "skin": L.SKIN_TONES[2],
			"head": "square", "nose": "broad", "eyes": 0, "brows": 1, "mouth": 2,
			"hair": "crop", "hair_color": L.HAIR_COLORS[1], "facial_hair": "moustache", "hat": "cap",
			"hat_color": L.CLOTH[10], "top": "shirt", "top_color": L.CLOTH[0], "sleeves": "short",
			"apron": true, "apron_color": L.CLOTH[7], "legs": "breeches", "legs_color": L.CLOTH[8],
			"feet": "boots", "feet_color": L.LEATHER[1], "belt": "belt", "belt_color": L.LEATHER[1]},
	}))
	cast.append(_vendor(kit, isl._stall_cloth, {
		"name": "Clothier Sela", "voice": 1.2, "shop": "sela",
		"barks": [
			"Sailcloth, silk, and wool from three islands over. Touch with your eyes, Captain.",
			"That coat of yours has seen weather. Sell me the old one, wear something better.",
			"Blue's the fashion this season. Blue's always the fashion at sea.",
		],
		"look": {"body": "fem", "build": "slim", "height": 1.03, "skin": L.SKIN_TONES[5],
			"head": "long", "nose": "small", "eyes": 4, "brows": 2, "mouth": 4,
			"hair": "long", "hair_color": L.HAIR_COLORS[0], "hat": "none",
			"top": "blouse", "top_color": L.CLOTH[16], "vest": "vest", "vest_color": L.CLOTH[15],
			"legs": "skirt", "legs_color": L.CLOTH[9], "feet": "shoes", "feet_color": L.LEATHER[3],
			"belt": "sash", "sash_color": L.CLOTH[15], "earring": true, "scarf": true, "scarf_color": L.CLOTH[9]},
	}))
	cast.append(_vendor(kit, isl._stall_pots, {
		"name": "Old Ida", "voice": 1.05, "shop": "ida",
		"barks": [
			"Pots, jugs, jars. Everything here holds water except my patience.",
			"Thrown on my own wheel, fired in my own kiln, dropped by my own nephew.",
			"Hardtack, Captain. Packed in my jars, it'll outlast your ship.",
		],
		"look": {"body": "fem", "build": "average", "height": 0.92, "skin": L.SKIN_TONES[1],
			"head": "round", "nose": "hooked", "eyes": 3, "brows": 4, "mouth": 0, "marks": "age_lines",
			"hair": "bun", "hair_color": L.HAIR_COLORS[8], "hat": "knit", "hat_color": L.CLOTH[2],
			"top": "tunic", "top_color": L.CLOTH[12], "sleeves": "long", "apron": true, "apron_color": L.CLOTH[2],
			"legs": "skirt", "legs_color": L.CLOTH[4], "feet": "shoes", "feet_color": L.LEATHER[1], "belt": "none"},
	}))

	# tavern regulars, seated
	var patrons := [
		{"name": "Dunk", "voice": 0.78, "barks": [
			"Another round? Don't mind if I do. Don't mind if I don't, either.",
			"I was a pirate once. For an afternoon. Lovely afternoon.",
			"Mind the bugs in the jungle, friend. Big ones. Head-butt you right off your feet."],
		 "look": {"body": "masc", "build": "stout", "skin": L.SKIN_TONES[3], "hair": "short",
			"hair_color": L.HAIR_COLORS[3], "facial_hair": "beard", "top": "shirt", "top_color": L.CLOTH[2],
			"vest": "vest", "vest_color": L.CLOTH[4], "legs": "trousers", "legs_color": L.CLOTH[3], "hat": "none"}},
		{"name": "Moira", "voice": 1.15, "barks": [
			"Gus says the rum's aged. Aged a week, maybe.",
			"You've the look of someone who's going to do something foolish. I like it.",
			"The scuttlebugs come out under the jungle trees. Hit 'em when they're dizzy from charging.",
			{"text": "Grell's lot used to drink here and never pay. You've done Gus a favour, and Gus doesn't forget those.", "after": "grell"}],
		 "look": {"body": "fem", "build": "average", "skin": L.SKIN_TONES[0], "hair": "ponytail",
			"hair_color": L.HAIR_COLORS[5], "top": "blouse", "top_color": L.CLOTH[9],
			"vest": "corset", "vest_color": L.CLOTH[14], "legs": "skirt", "legs_color": L.CLOTH[5], "hat": "none"}},
		{"name": "Quiet Tobin", "voice": 0.95, "barks": ["...", "Mm.", "...the sea remembers."],
		 "look": {"body": "masc", "build": "slim", "skin": L.SKIN_TONES[6], "hair": "long",
			"hair_color": L.HAIR_COLORS[0], "hat": "hood", "hat_color": L.CLOTH[6],
			"top": "tunic", "top_color": L.CLOTH[6], "coat": "longcoat", "coat_color": L.CLOTH[5],
			"legs": "trousers", "legs_color": L.CLOTH[5]}},
	]
	for i in range(patrons.size()):
		var cfg: Dictionary = patrons[i]
		cfg["seated"] = true
		cast.append({"cfg": cfg}.merged(KitLife.at_marker(kit, isl._tavern, "Patron%d" % (i + 1))))

	# the smith at his anvil, and his rack of blades (talk: his forge)
	cast.append({"cfg": {
		"name": "Haldor the Smith", "voice": 0.7, "shop": "haldor",
		"barks": [
			"Every blade on this island's been through my fire. Twice, if the owner was careless.",
			"Cutlass, hanger, axe, a pistol if you must. Vey sends them all to me now. He says I talk less.",
			"Bring me your spare steel. I'll pay for it, then I'll sell it back to someone braver.",
			{"text": "Bug chitin? Takes an edge better than iron, I'll grant. Smells worse.", "before": "queen"},
			{"text": "That's queen chitin on Tackett's keel, I hear. I'd have made a fine blade of it. Typical.", "after": "queen"},
			"Hear that hammer? That's the sound of Brinehollow not being robbed.",
		],
		"look": {"body": "masc", "build": "broad", "height": 1.06, "skin": L.SKIN_TONES[4],
			"head": "square", "nose": "broad", "eyes": 1, "brows": 1, "mouth": 3, "marks": "scar",
			"hair": "bald", "hair_color": L.HAIR_COLORS[1], "facial_hair": "beard", "hat": "none",
			"top": "bare", "apron": true, "apron_color": L.LEATHER[0],
			"legs": "trousers", "legs_color": L.CLOTH[6], "feet": "boots", "feet_color": L.LEATHER[0],
			"belt": "belt", "belt_color": L.LEATHER[1], "gloves": true, "gloves_color": L.LEATHER[2]},
	}}.merged(KitLife.at_marker(kit, isl._smithy, "Smith")))

	# Lighthouse keeper on the hill
	cast.append({"cfg": {
		"name": "Keeper Ambrose", "dialogue": "ambrose", "voice": 0.8,
		"look": {"body": "masc", "build": "average", "skin": L.SKIN_TONES[1],
			"head": "long", "nose": "straight", "eyes": 3, "brows": 0, "mouth": 0, "eye_color": L.EYE_COLORS[4],
			"hair": "short", "hair_color": L.HAIR_COLORS[7], "facial_hair": "beard", "hat": "hood",
			"hat_color": L.CLOTH[6], "top": "shirt", "top_color": L.CLOTH[7],
			"coat": "longcoat", "coat_color": L.CLOTH[3], "legs": "trousers", "legs_color": L.CLOTH[4],
			"feet": "boots", "feet_color": L.LEATHER[1], "belt": "belt", "belt_color": L.LEATHER[1],
			"gloves": true, "gloves_color": L.LEATHER[2]},
	}, "at": StarterIsland.HILL + Vector2(-5, 4.5), "face": Vector2(-1, 0.2)})

	# Castaway at the cove campfire
	cast.append({"cfg": {
		"name": "Wren", "dialogue": "wren", "voice": 1.1,
		"look": {"body": "fem", "build": "slim", "skin": L.SKIN_TONES[3],
			"head": "round", "nose": "small", "eyes": 4, "brows": 0, "mouth": 4, "marks": "freckles",
			"hair": "wild", "hair_color": L.HAIR_COLORS[4], "hat": "bandana", "hat_color": L.CLOTH[13],
			"top": "shirt", "top_color": L.CLOTH[1], "sleeves": "none",
			"legs": "shorts", "legs_color": L.CLOTH[2], "feet": "barefoot", "belt": "belt_sash",
			"belt_color": L.LEATHER[2], "sash_color": L.CLOTH[10], "eyepatch": true, "earring": true},
	}, "at": StarterIsland.CAMP + Vector2(-1.5, 1.8), "face": Vector2(1.5, -1.8)})

	# Wandering villagers with one-liners
	var ring := KitLife.ring(kit, StarterIsland.VILLAGE, 9.0)
	cast.append({"cfg": {
		"name": "Tilly", "voice": 1.3,
		"barks": [
			"Morning, Captain! Mind the chickens. We don't have chickens. Yet.",
			"Gus waters the rum, but don't tell him I said so.",
			"If you're heading into the jungle, take a lantern. Or a braver friend.",
			"The lighthouse keeper talks to the sea. Sometimes I think it answers.",
			"Something up in the big trees out west spits. Mind your head in the deep woods.",
			{"text": "Is it true you can't remember anything? Not even your birthday? I'd pick a new one. Something in summer.", "before": "smugglers"},
			{"text": "They say you put Captain Grell in the sand! Mum says you're a hero. Dad says you're trouble.", "after": "grell"},
		],
		"look": {"body": "fem", "build": "average", "height": 0.93, "skin": L.SKIN_TONES[0],
			"head": "round", "nose": "small", "eyes": 2, "brows": 2, "mouth": 1, "marks": "freckles", "eye_color": L.EYE_COLORS[2],
			"hair": "bun", "hair_color": L.HAIR_COLORS[4], "hat": "none",
			"top": "blouse", "top_color": L.CLOTH[12], "apron": true, "apron_color": L.CLOTH[1],
			"legs": "skirt", "legs_color": L.CLOTH[3], "feet": "shoes", "feet_color": L.LEATHER[1],
			"belt": "none"},
		"waypoints": ring,
	}, "at": Vector2(ring[0].x, ring[0].z), "face": Vector2(0, 1)})

	var fish_route := KitLife.route(kit, [isl.dock_shore + Vector2(-8.0, 9.0), isl.dock_shore + Vector2(3.0, 12.0),
		StarterIsland.VILLAGE + Vector2(1.5, -26), StarterIsland.VILLAGE + Vector2(3, -14)])
	cast.append({"cfg": {
		"name": "Bram", "voice": 0.95,
		"barks": [
			{"text": "Nets came up empty again. The smugglers on the south beach scare the fish. And me.", "before": "smugglers"},
			{"text": "Boats are safe off the south beach again. Drinks are on me. Well. On Gus.", "after": "smugglers"},
			"Saw lights out past the reef last night. Not lanterns. Something else.",
			"Odile won't let me tie up past sundown. Says the tide gets hungry.",
		],
		"look": {"body": "masc", "build": "broad", "skin": L.SKIN_TONES[4],
			"head": "round", "nose": "straight", "eyes": 0, "brows": 1, "mouth": 0,
			"hair": "short", "hair_color": L.HAIR_COLORS[2], "facial_hair": "stubble", "hat": "knit",
			"hat_color": L.CLOTH[17], "top": "shirt", "top_color": L.CLOTH[1], "sleeves": "short",
			"vest": "vest", "vest_color": L.CLOTH[8], "trim_color": L.TRIM[1],
			"legs": "trousers", "legs_color": L.CLOTH[8], "feet": "boots", "feet_color": L.LEATHER[0],
			"belt": "belt", "belt_color": L.LEATHER[1]},
		"waypoints": fish_route,
	}, "at": Vector2(fish_route[0].x, fish_route[0].z), "face": Vector2(0, 1)})

	# (1.25.4) the Edy master in his reading hall on the shrine terrace: the story's reading (Story "shrine")
	var isao := KitLife.look_for("Master Isao")
	isao.merge({"body": "masc", "build": "slim", "height": 0.97, "marks": "age_lines", "hair": "topknot", "hair_color": L.HAIR_COLORS[8],
		"facial_hair": "long_beard", "hat": "none", "top": "kimono", "top_color": L.CLOTH[5], "sleeves": "long", "coat": "none",
		"legs": "trousers", "legs_color": L.CLOTH[6], "feet": "sandals", "belt": "sash", "sash_color": L.CLOTH[13]}, true)
	cast.append({"cfg": {"name": "Master Isao", "dialogue": "isao", "voice": 0.86, "look": isao}}.merged(KitLife.at_marker(kit, isl.reading_hall, "Master")))
	return cast


## Corin, who sells instruments (Shops "corin").
static func corin() -> Dictionary:
	return {
		"name": "Corin", "voice": 1.08, "shop": "corin",
		"barks": [
			"Whistle, drum, squeezebox, fiddle, banjo. The hurdy-gurdy's for people who hate their neighbours.",
			"Every crew needs a tune at the capstan. Haul to the beat and the anchor weighs half.",
			"Gus used to sell these behind the bar. Kept getting rum in the bellows. So now there's me.",
			"Play it badly in a tavern and they'll pay you to stop. That's still getting paid.",
			{"text": "The Brinehollow Lass? Every child on the island can hum it. Learn it before you sail.", "before": "tackett_ship"},
			{"text": "Your own sloop and no shanty to sail her by? Tackett would weep. Buy a whistle.", "after": "tackett_ship"},
		],
		"look": {"body": "masc", "build": "slim", "height": 1.02, "skin": L.SKIN_TONES[2],
			"head": "long", "nose": "straight", "eyes": 2, "brows": 2, "mouth": 4, "eye_color": L.EYE_COLORS[1],
			"hair": "ponytail", "hair_color": L.HAIR_COLORS[5], "facial_hair": "goatee", "hat": "cavalier", "hat_color": L.CLOTH[9],
			"top": "shirt", "top_color": L.CLOTH[12], "sleeves": "long", "vest": "vest", "vest_color": L.CLOTH[14],
			"legs": "breeches", "legs_color": L.CLOTH[5], "feet": "cavalier_boots", "feet_color": L.LEATHER[2],
			"belt": "sash", "sash_color": L.CLOTH[16], "earring": true, "scarf": true, "scarf_color": L.CLOTH[15]},
	}


## The townsfolk on routines (BrinehollowLife, in this order): `cfg` for NPC.setup, `plan` [[hour, spot id
## (BrinehollowLife._spot), act (optional: the spot's own otherwise)]...] by hour, the day wrapping, `speed`,
## `carry` (a load on the shoulder walking to a stay marked "carry"). Shopkeepers keep the market street's
## shops and stalls by day and drink at the Salted Gull after; customers browse; porters haul from the quay;
## kids run the plaza and the long stair until supper.
static func townsfolk() -> Array:
	var out: Array = []
	out.append({"cfg": corin(), "plan": [[7.4, "vendor:Shop4"], [12.6, "bench:0"], [13.3, "vendor:Shop4"],
		[19.0, "tavern:fire:0"], [23.6, "home:UpperHouse4"]]})
	var keepers := [
		["Hester Quill", "Shop0", 1.12, "UpperHouse0", [
			"Rope, tar, lamp oil, nails by the pound. If it's on a ship and it isn't the crew, I sell it.",
			"Ysolde's junk brought in Eastern twine. Stronger than ours. Don't tell the ropewalk.",
			"Pay what it's worth, not what you think it's worth. We'll both be happier."]],
		["Abel Marsh", "Shop1", 0.86, "UpperHouse1", [
			"First shop off the quay. Sailors with a full purse see me before they see Gus.",
			"Lanterns, oilskins, a good knife. Everything for weather, except luck.",
			{"text": "Since you cleared the south beach my shutters stay up past dark. Thank you.", "after": "smugglers"}]],
		["Rosa Tamm", "Shop2", 1.18, "UpperHouse2", [
			"Up early, closed late, and the upper town still says I keep bankers' hours.",
			"The stair's a hundred and some steps. I carry my stock up it every night. Look at these calves.",
			"Buy something, Captain. You've been looking at it for a full minute."]],
		["Pip Calloway", "Shop3", 1.3, "UpperHouse7", [
			"Best shop on the street! Well. Best shop on this side of the street.",
			"Mum lets me run the shop now. Mum also counts the takings. Twice.",
			"Fresh this morning! Well. This morning-ish."]],
		["Mags Ferrow", "Shop5", 1.05, "UpperHouse8", [
			"Sit on my step if you like. The shade's free. The step's free. Buy something.",
			"I've had this spot since before the street had cobbles. The cobbles are new. I'm not.",
			"Haggle with me, dear. It's the only exercise I get."]],
		["Jory Lusk", "StreetStall0", 0.92, "UpperHouse9", [
			"Two for one, Captain. One for you, one for the sea when you drop it overboard.",
			"Corin plays the Gull most nights. Come by. I'll be the one singing the wrong words.",
			"Quiet day. The quiet days are when the pirates are busy somewhere else."]],
	]
	for i in range(keepers.size()):
		var k: Array = keepers[i]
		out.append({"cfg": {"name": k[0], "voice": k[2], "barks": k[4], "look": KitLife.look_for(k[0])},
			"plan": [[7.0 + 0.15 * i, "vendor:" + k[1]], [12.2 + 0.2 * i, ("bench:%d" % (1 + i / 2)) if i % 2 == 0 else ("plaza:%d" % (12 + i / 2))],
				[13.2 + 0.1 * i, "vendor:" + k[1]],
				[18.8 + 0.25 * i, ("tavern:bar:%d" % (i / 2)) if i % 2 == 0 else ("tavern:seat:%d" % (i / 2))], [22.4 + 0.2 * i, "home:" + k[3]]]})
	var customers := [
		["Widow Maple", 1.1, "UpperHouse3", [
			"I don't need anything. I just like to know what everything costs.",
			"My Albert sailed with a captain like you. Mind you come back, unlike Albert."]],
		["Fennick", 0.95, "UpperHouse5", [
			"Shopping for my wife. She gave me a list. I've lost the list.",
			"Don't buy from Pip before noon. Prices drop when his mum goes for lunch."]],
		["Agatha Brine", 1.2, "UpperHouse6", [
			"No relation to the island. People always ask.",
			"I come down the stair for bread and go back up for my breath."]],
		["Cobb", 0.8, "UpperHouse3", [
			"Market day's every day here. Even Sundays. Especially Sundays.",
			"Mind the porters. They don't stop for captains and they don't stop for Cobb."]],
	]
	var fronts := ["front:Shop0", "front:Shop5", "front:market0", "front:Shop3", "front:StreetStall0", "front:market2", "front:Shop1",
		"front:Shop4", "front:market1", "front:Shop2", "front:market3"]
	for i in range(customers.size() if CROWD else 0):
		var c: Array = customers[i]
		var plan: Array = []
		for j in range(4):
			plan.append([8.0 + i * 0.3 + j * 0.9, fronts[(i * 3 + j) % fronts.size()]])
		plan.append([12.0 + i * 0.25, "plaza:%d" % i, "talk"])
		for j in range(3):
			plan.append([13.6 + i * 0.3 + j * 1.0, fronts[(i * 3 + j + 5) % fronts.size()]])
		plan.append([17.4 + i * 0.3, "plaza:%d" % (4 + i), "talk"])
		plan.append([19.2 + i * 0.2, "tavern:seat:%d" % (3 + i), "sit"])
		plan.append([21.8 + i * 0.3, "home:" + c[2]])
		out.append({"cfg": {"name": c[0], "voice": c[1], "barks": c[3], "look": KitLife.look_for(c[0])}, "plan": plan})
	var porters := [["Gideon", 0.8], ["Lou Haskett", 1.05], ["Bastian", 0.9]]
	var drops := ["front:market0", "front:Shop1", "front:market1", "front:Shop0", "front:Shop3", "front:market3", "front:Shop5"]
	for i in range(porters.size() if CROWD else 0):
		var plan: Array = []
		var h := 6.6 + i * 0.35
		var n := 0
		while h < 17.5:
			plan.append([h, "quay:%d" % i, "kneel"])
			plan.append([h + 0.55, drops[(i * 2 + n) % drops.size()], "kneel", true])
			h += 1.25
			n += 1
		plan.append([h, "plaza:%d" % (8 + i), "talk"])
		plan.append([19.6 + i * 0.3, ["tavern:bar:3", "tavern:bar:4", "tavern:fire:1"][i]])
		plan.append([23.2, "home:UpperHouse%d" % (5 + i)])
		out.append({"cfg": {"name": porters[i][0], "voice": porters[i][1], "barks": [
				"Can't stop, Captain. Odile counts the crates and Odile counts the minutes.",
				"Quay to the warehouse, warehouse to the quay. Some days I dream in sacks.",
				"Heaviest thing I ever carried? Dunk. Home. Twice a week."],
			"look": KitLife.look_for(porters[i][0])}, "plan": plan, "carry": true})
	var kids := [["Nell", 1.45], ["Tam", 1.4], ["Wick", 1.5]]
	var runs := ["plaza:%d", "stair:%d", "front:market%d", "stair:%d", "plaza:%d", "front:Shop%d"]
	for i in range(kids.size() if CROWD else 0):
		var plan: Array = []
		var h := 8.0 + i * 0.1
		var n := 0
		while h < 19.0:
			if h > 12.4 and h < 13.4:
				plan.append([h, "home:UpperHouse%d" % [1, 7, 8][i]])
				h = 13.4
			var run: String = runs[n % runs.size()]
			plan.append([h, run % ((n + i) % 3 + (12 if run.begins_with("plaza") else 0))])
			h += 0.5
			n += 1
		plan.append([19.0 + i * 0.1, "home:UpperHouse%d" % [1, 7, 8][i]])
		var lk := KitLife.look_for(kids[i][0])
		lk.merge({"height": 0.78, "build": "slim", "facial_hair": "none", "coat": "none", "marks": "freckles" if i != 1 else "none"}, true)
		out.append({"cfg": {"name": kids[i][0], "voice": kids[i][1], "look": lk, "walk_speed": 2.4, "barks": [
				"You can't catch me! You're not even trying. Try!",
				"Tam says you're a pirate. I said pirates have parrots. Where's your parrot?",
				"We're not allowed past the old ruins. So we only go a bit past."]}, "plan": plan})
	out.append_array(harbourfolk())
	out.append_array(outskirts())
	return out


## The shrine terrace's, the windmill hamlet's and the second cove's people (piece 5; "area": the walks they keep to).
static func outskirts() -> Array:
	var out: Array = []
	out.append({"cfg": {"name": "Keeper Sanae", "voice": 1.0, "look": KitLife.look_for("Keeper Sanae"), "barks": [
			"The shrine's older than the harbour. Sailors built it before they built houses. Tells you their priorities.",
			"Ring the bell before you sail and the sea remembers your name. Forget, and it remembers that too.",
			{"text": "You came back from Grell's den. Whatever you prayed to, keep it up.", "after": "grell"}]},
		"plan": [[5.8, "mark:shrine:Priest"], [12.0, "mark:teahouse:Seat1"], [13.0, "mark:shrine:Priest"], [19.6, "door:shrine"]]})
	# (1.24.1: the teahouse keeper reads your Edy; Bao, her cook out front, is the black-leg master and sets Tomo's test)
	out.append({"cfg": {"name": "Hana Teal", "voice": 1.2, "look": KitLife.look_for("Hana Teal"), "dialogue": "hana", "barks": [
			"Tea from the far east, by way of Ysolde's junk and a great deal of arguing.",
			"Climb the stair, drink the tea, look at the sea. That's the whole teahouse. People pay for it.",
			"The keeper takes her lunch here every day and pays every other day. It evens out at the shrine."]},
		"plan": [[6.5, "mark:teahouse:Vendor"], [20.5, "home:UpperHouse10"]]})
	out.append({"cfg": {"name": "Bao", "voice": 0.9, "look": KitLife.look_for("Bao"), "dialogue": "bao", "barks": [
			"Low kick, high kick. Stir the pot. Low kick, high kick.",
			"A cook's hands are for the pot. The legs do the rest.",
			"Gus kicks like a chair. Don't tell him I said so. Do tell him."]},
		"plan": [[6.0, "mark:teahouse:Yard"], [20.0, "home:UpperHouse10"]]})
	out.append({"cfg": {"name": "Old Oda", "voice": 0.85, "look": KitLife.look_for("Old Oda"), "barks": [
			"Sixty years I've climbed that stair. It's got longer.",
			"I pray for my son's ship every morning. It's a good ship. It doesn't need it. I do."]},
		"plan": [[7.0, "mark:shrine:Worshipper"], [8.4, "mark:teahouse:Seat2"], [11.5, "mark:teahouse:Seat3"], [15.0, "mark:shrine:Worshipper"],
			[16.2, "home:UpperHouse5"]]})
	out.append({"cfg": {"name": "Miller Brann", "voice": 0.75, "look": KitLife.look_for("Miller Brann"), "barks": [
			"Every loaf in Brinehollow started on my stones. Ida's hardtack too. I'm not proud of that one.",
			"The wind off the south lands is the best on the island. Steady. Like me. Mostly.",
			"Mind the sails when they're turning. I've lost two hats and a nephew. The nephew came back."]},
		"plan": [[5.8, "mark:windmill:Miller"], [12.2, "yard:0"], [13.2, "mark:windmill:Miller"], [19.4, "door:windmill"]], "area": "farm"})
	var hands := [["Joss", 1.05, [8, 4], "Farmhouse0"], ["Wynn", 0.9, [5, 3], "Farmhouse1"]]
	for i in range(hands.size()):
		var hd: Array = hands[i]
		var a: int = hd[2][0]
		var b: int = hd[2][1]
		out.append({"cfg": {"name": "Farmhand " + str(hd[0]), "voice": hd[1], "look": KitLife.look_for(hd[0]), "barks": [
				"Up before the sun, in after it. The crops don't care whose captain you are.",
				"Brann grinds it, Ida bakes it, Gus soaks it in stew. Somebody has to grow it.",
				"The scarecrow's named Morrow. He scares the crows about as well as the real one scared you."]},
			"plan": [[6.2 + 0.3 * i, "field:%d:0" % a], [7.6 + 0.3 * i, "field:%d:1" % a], [9.0 + 0.3 * i, "field:%d:2" % a], [10.4 + 0.3 * i, "field:%d:0" % b],
				[12.0 + 0.2 * i, "yard:%d" % (1 + i)], [13.2 + 0.3 * i, "field:%d:1" % b], [14.6 + 0.3 * i, "field:%d:2" % b], [16.0 + 0.3 * i, "field:%d:3" % b],
				[18.6 + 0.3 * i, "door:" + str(hd[3])]], "area": "farm"})
	out.append({"cfg": {"name": "Old Gannet", "voice": 0.78, "look": KitLife.look_for("Old Gannet"), "barks": [
			"Nobody comes round this side. That's why I live on it.",
			"Town's too loud. Twelve people in it last I counted. Twelve!",
			"The wreck up the coast? Don't go poking in her. She's still got her crew, in a manner of speaking."]},
		"plan": [[5.0, "cove:jetty"], [10.6, "cove:rack"], [13.0, "cove:jetty"], [17.6, "cove:rack"], [20.4, "door:hut"]], "area": "cove"})
	return out


## The harbour's people (piece 4): fishers on the piers' edges at dawn and after lunch, dockers loading the
## merchantman from a stack on the quay.
static func harbourfolk() -> Array:
	var out: Array = []
	var fishers := [
		["Sully Penhallow", 0.8, "UpperHouse10", ["tavern:side:0", "tavern:side:0"], [
			"Forty years off this pier. The fish have learned my face. That's the trouble.",
			"Bram goes out in the boats. Boats are for people who can't wait.",
			{"text": "The water's been sweeter since the smugglers went. Ask the mackerel.", "after": "smugglers"}]],
		["Kit Garrow", 1.15, "UpperHouse6", ["tavern:side:1", "tavern:side:1"], [
			"Don't stand on my line. Don't stand near my line. Don't look at my line.",
			"Hob and Marrin take the smacks out at dawn. Back by the afternoon, if the Leviathan's in a good mood.",
			"A pier's the only place on the island nobody asks you to carry anything."]],
		["Fen Doyle", 0.95, "UpperHouse4", ["tavern:seat:7", "tavern:seat:7"], [
			"Ysolde lets me fish off her pier if I keep the gulls off her deck. I do not keep the gulls off her deck.",
			"Caught a boot once. Wore it for a year. Lovely boot.",
			"Best spot's the end of the merchant pier. Don't tell Sully."]],
	]
	for i in range(fishers.size()):
		var f: Array = fishers[i]
		out.append({"cfg": {"name": f[0], "voice": f[1], "barks": f[4], "look": KitLife.look_for(f[0])},
			"plan": [[3.8 + 0.2 * i, "fish:%d" % i], [10.9 + 0.2 * i, f[3][0], "talk"], [14.2 + 0.2 * i, "fish:%d" % i],
				[19.1 + 0.2 * i, f[3][1], "talk"], [22.6 + 0.2 * i, "home:" + f[2]]]})
	var dockers := [["Docker Abby", 1.1], ["Docker Thom", 0.85]]
	for i in range(dockers.size()):
		var plan: Array = []
		var h := 7.0 + i * 0.5
		while h < 17.0:
			plan.append([h, "stack:%d" % i, "kneel"])
			plan.append([h + 0.5, "dock:%d" % i, "kneel", true])
			h += 1.0
		plan.append([h, "tavern:side:%d" % (2 + i), "talk"])
		plan.append([22.0 + i * 0.4, "home:UpperHouse%d" % [9, 3][i]])
		out.append({"cfg": {"name": dockers[i][0], "voice": dockers[i][1], "barks": [
				"Ysolde's cargo, Ysolde's ship, Ysolde's shouting. My back.",
				"Spice in, salt fish out. Brinehollow's whole economy, one crate at a time.",
				"If you're not lifting, Captain, you're in the way. Kindly."],
			"look": KitLife.look_for(dockers[i][0])}, "plan": plan, "carry": true})
	return out


## A vendor behind a stall's counter (its "Vendor" marker), on the ground.
static func _vendor(kit: KitContext, stall: Node3D, cfg: Dictionary) -> Dictionary:
	return {"cfg": cfg, "at": kit.marker_point(stall, "Vendor"), "face": kit.marker_face(stall, "Vendor")}
