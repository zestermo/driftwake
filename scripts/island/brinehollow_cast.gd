class_name BrinehollowCast
extends RefCounted
## Brinehollow's people as data for KitLife.spawn: who they are, where they stand
## (spots from the layout and from markers in its buildings), their looks,
## dialogue ids, shops and barks (`before`/`after` story flags), walking routes.

const L := preload("res://scripts/npc/character_look.gd")


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

	# the smith at his anvil
	cast.append({"cfg": {
		"name": "Haldor the Smith", "voice": 0.7,
		"barks": [
			"Every blade on this island's been through my fire. Twice, if the owner was careless.",
			"Bring me something to mend and gold to mend it with. Not in that order.",
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
		StarterIsland.VILLAGE + Vector2(8, -26), StarterIsland.VILLAGE + Vector2(3, -14)])
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
	return cast


## A vendor behind a stall's counter (its "Vendor" marker), on the ground.
static func _vendor(kit: KitContext, stall: Node3D, cfg: Dictionary) -> Dictionary:
	return {"cfg": cfg, "at": kit.marker_point(stall, "Vendor"), "face": kit.marker_face(stall, "Vendor")}
