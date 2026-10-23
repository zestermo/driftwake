class_name RivalCrews
extends RefCounted
## The rival pirate crews (docs/rival_crews_plan.md, docs/v1_19_plan.md): authored captains, each with a theme, a
## flag colour, a signature weapon, a voice and their lines, crewed by mates rolled from the crew's own pools
## (seeded per crew and save, so the same faces come back). Written with Driftwake's own names
## (docs/originality_plan.md); Zach reviews them.
##
## Lines by moment: meet (the first meeting's back-and-forth: [who, line], who = "cap" / "mate" / "you"),
## again (a later meeting), grudge_won (they beat you last time), grudge_lost (you beat them), taunt, hurt, ult,
## mate_down, retreat, gloat. Mates share MATE_LINES.

const CREWS := {
	"gilded_gulls": {
		"name": "the Gilded Gulls", "captain": "Marisol Vane", "title": "the Gilt Blade", "weapon": "cutlass",
		"pitch": 1.12, "body": "fem", "build": "slim", "hair": "long", "hair_color": Color(0.85, 0.66, 0.3),
		"hat": "cavalier", "coat": "frock", "flag": Color(0.95, 0.78, 0.25),
		"palette": [Color(0.94, 0.9, 0.82), Color(0.82, 0.62, 0.2), Color(0.25, 0.22, 0.3)],
		"mate_weapons": ["cutlass", "dagger", "spear"],
		"mate_names": ["Tobin", "Celeste", "Arlo", "Wren", "Jessamy", "Corwin", "Lisette", "Pell"],
		"lines": {
			"meet": [["cap", "Well now. A captain with a little bounty and a lot of nerve."],
				["you", "And you are?"],
				["cap", "Marisol Vane. Remember it. Everyone in this sea will, soon enough."],
				["mate", "She's all style, friend. The style just happens to cut."],
				["cap", "One at a time, Gulls. Let's give our guest a proper show."]],
			"again": [["cap", "You again! Good. Last time was far too short."],
				["cap", "Gulls, places. Same show, better ending."]],
			"grudge_won": [["cap", "Back for another lesson? I kept your gold warm."]],
			"grudge_lost": [["cap", "I've practised since you embarrassed me. A lot. Daily."],
				["cap", "This time the applause is mine."]],
			"taunt": ["Footwork, darling. Footwork.", "Is that a sword or a shovel?", "Keep up!",
				"You're making this look easy. For me.", "Again. And put some feeling in it."],
			"hurt": ["Rude!", "That'll scar. Beautifully.", "Oh, you'll pay for the coat."],
			"ult": ["Curtain call!", "Gilt Tempest!", "Watch closely. This is the good part."],
			"mate_down": ["Up, sweetheart, the crowd's watching!", "Nobody touches my Gulls but me!"],
			"retreat": ["Gulls, to the boat! We'll call it a draw. I'm calling it a draw.",
				"Fine! Fine. Enjoy it. Next time I bring a better coat."],
			"gloat": ["Thank you, thank you. The gold is my fee for the lesson.",
				"Don't sulk. You were nearly interesting."],
			"bounty": ["{b} gold on your head? Darling, my hat cost more.", "I saw your poster. They didn't get your good side."],
		},
	},
	"brine_wolves": {
		"name": "the Brine Wolves", "captain": "Haskel Rourke", "title": "Ironjaw", "weapon": "warhammer",
		"pitch": 0.78, "body": "masc", "build": "broad", "hair": "crop", "hair_color": Color(0.35, 0.33, 0.32),
		"hat": "none", "coat": "greatcoat", "flag": Color(0.4, 0.5, 0.6),
		"palette": [Color(0.35, 0.42, 0.5), Color(0.55, 0.55, 0.52), Color(0.2, 0.2, 0.22)],
		"mate_weapons": ["boarding_axe", "warhammer", "cutlass"],
		"mate_names": ["Grell", "Bodie", "Kask", "Mallory", "Teague", "Ruck", "Hesketh", "Brann"],
		"lines": {
			"meet": [["mate", "Cap'n. Fresh one on the beach."],
				["cap", "I see it. Small."],
				["you", "Small enough to knock you flat."],
				["cap", "Ha! It talks. Haskel Rourke. They call me Ironjaw. Want to know why?"],
				["cap", "Wolves! One at a time. Let it learn."]],
			"again": [["cap", "The small one's back. Bigger, maybe. Let's weigh it."]],
			"grudge_won": [["cap", "You still owe me a better fight."]],
			"grudge_lost": [["cap", "You cracked the jaw. Nobody cracks the jaw."],
				["cap", "I've been waiting. Teeth and all."]],
			"taunt": ["Hit harder.", "That all?", "Stand and take it.", "Feet planted. Like a wall.",
				"I've been hit harder by rain."],
			"hurt": ["Hah!", "Better!", "Now we're talking."],
			"ult": ["Breakwater!", "Down you go!", "Brace yourself."],
			"mate_down": ["Get up, pup.", "Who taught you to fall? Not me."],
			"retreat": ["Enough. Wolves, back to the ship. It earned this one.",
				"Pull back! Rourke doesn't lose twice in one day."],
			"gloat": ["The sea takes a toll. Today the toll is your purse.",
				"Rest there. You'll feel it tomorrow."],
			"bounty": ["{b} on your head. Somebody's scared of you. I'm not.", "Your poster's on every board. Let's see if you're worth the paper."],
		},
	},
	"lantern_saints": {
		"name": "the Lantern Saints", "captain": "Odessa Krane", "title": "the Quiet Lamp", "weapon": "katana",
		"pitch": 0.95, "body": "fem", "build": "average", "hair": "hime", "hair_color": Color(0.08, 0.07, 0.08),
		"hat": "none", "coat": "haori", "flag": Color(0.75, 0.15, 0.12),
		"palette": [Color(0.12, 0.1, 0.12), Color(0.7, 0.14, 0.12), Color(0.85, 0.8, 0.7)],
		"mate_weapons": ["katana", "spear", "dagger"],
		"mate_names": ["Ivo", "Sabine", "Teodor", "Nell", "Corrie", "Aldous", "Ysa", "Marten"],
		"lines": {
			"meet": [["cap", "Captain. We've been following your lights for three nights."],
				["you", "Why?"],
				["cap", "Because a light that bright draws everything in the dark. Better us than worse."],
				["mate", "The Saints take your measure. Don't take it personally."],
				["cap", "One blade at a time. Show me what keeps your lamp lit."]],
			"again": [["cap", "Your light's brighter. Let's see if it's steadier."]],
			"grudge_won": [["cap", "You fell too quickly last time. I hoped for more."]],
			"grudge_lost": [["cap", "You put out my lamp once. It burns again."],
				["cap", "I've studied every cut you gave me."]],
			"taunt": ["Breathe.", "Too eager.", "You're telling me where you'll strike.",
				"Again, slower. Then faster.", "The blade is honest. Are you?"],
			"hurt": ["Good.", "There it is.", "Hm."],
			"ult": ["Lantern Fall.", "Be still.", "Close your eyes."],
			"mate_down": ["Rise. We are not finished.", "Breathe, and stand."],
			"retreat": ["Saints, withdraw. The measure is taken.",
				"Enough. Your light holds. For now."],
			"gloat": ["A toll for the lesson. Light costs oil.", "Rest. The dark will wait for you."],
			"bounty": ["The Admiralty values you at {b}. I wonder what you value yourself at.", "Your name travels faster than your ship now."],
		},
	},
	"mudlark_brigade": {
		"name": "the Mudlark Brigade", "captain": "Pip Tallow", "title": "the Tide Rat", "weapon": "dagger",
		"pitch": 1.28, "body": "masc", "build": "slim", "hair": "messy", "hair_color": Color(0.55, 0.3, 0.15),
		"hat": "bandana", "coat": "jacket", "flag": Color(0.45, 0.55, 0.25),
		"palette": [Color(0.45, 0.4, 0.25), Color(0.35, 0.48, 0.25), Color(0.6, 0.45, 0.3)],
		"mate_weapons": ["dagger", "cutlass", "boarding_axe"],
		"mate_names": ["Nib", "Scraps", "Dally", "Fitch", "Moss", "Kip", "Tansy", "Grub"],
		"lines": {
			"meet": [["cap", "Oi! Oi! That's a real captain! With a real ship!"],
				["mate", "Told you, Pip. Told you they'd land here."],
				["you", "Who are you supposed to be?"],
				["cap", "Pip Tallow! Captain of the Mudlark Brigade! Future terror of the whole sea!"],
				["cap", "Brigade! Proper rules! One at a time, like real pirates!"]],
			"again": [["cap", "It's them! It's really them! Brigade, positions!"]],
			"grudge_won": [["cap", "We won last time! Did you see? Did everyone see?"]],
			"grudge_lost": [["cap", "I've been training! Every day! Mostly!"]],
			"taunt": ["Too slow, too slow!", "Over here! No, here!", "Ha! Missed!",
				"My gran swings harder!", "Is that a real sword?"],
			"hurt": ["Ow! Ow ow ow.", "That's not fair!", "Okay, that one hurt."],
			"ult": ["Mudslide Flurry!", "Brigade special!", "Watch this, watch this!"],
			"mate_down": ["Get up, Nib! Captain's orders!", "Nobody hits the Brigade!"],
			"retreat": ["Tactical retreat! That means run! To the boat!",
				"We'll be back! Bigger! Taller, probably!"],
			"gloat": ["We did it! We actually did it! Grab the gold!", "Mudlarks one, big captain nothing!"],
			"bounty": ["{b} gold! You're famous! Can I have your autograph? After we beat you!", "I've got your poster on my wall! Is that weird? That's weird."],
		},
	},
}

## Civilian bounty hunters (Bounty: from Notorious): no captain, no meeting; they jump the captain together.
const HUNTERS := {
	"name": "the bounty hunters", "captain": "", "weapon": "cutlass", "pitch": 0.9,
	"palette": [Color(0.4, 0.33, 0.25), Color(0.3, 0.28, 0.25), Color(0.22, 0.2, 0.18)], "flag": Color(0.5, 0.42, 0.3),
	"mate_weapons": ["cutlass", "spear", "boarding_axe", "dagger", "warhammer"],
	"mate_names": ["Corvin Shale", "Dagny Hale", "Morrow Pike", "Ilse Brand", "Tam Ruckett", "Quill Varga", "Sorrel Fenn",
		"Ansel Crook", "Bree Mallin", "Wick Holloway"],
	"lines": {
		"ambush": ["There's the face from the poster!", "That bounty's mine!", "Easy money, lads. Take them!",
			"Nothing personal, captain. It's the gold."],
		"taunt": ["Hold still, you're worth more in one piece!", "The Admiralty pays either way!", "Surround them!"],
		"hurt": ["Argh!", "Watch it!", "They bite back!"],
		"down": ["Not worth it...", "Ugh.", "Should've stuck to smugglers..."],
		"gloat": ["Your purse'll do for now. We'll be back for the rest.", "Lighter purse, same bounty. See you soon."],
	},
}


## The Admiralty's named hunters (docs/v1_19_plan.md: persistent, built like the crews; from Infamous they wait at a
## harbour): an officer and a squad of marines in the grey (EnemyShip.marine_look), the whole squad at once.
## Generic naval ranks (docs/originality_plan.md).
const ADMIRALTY := {
	"vael": {
		"name": "Commander Vael's squad", "captain": "Commander Idris Vael", "title": "the Grey Ledger", "weapon": "katana",
		"pitch": 0.88, "body": "masc", "build": "slim", "hair": "slick", "hair_color": Color(0.2, 0.19, 0.2),
		"hat": "none", "coat": "longcoat", "flag": Color(0.68, 0.7, 0.74), "marines": true,
		"palette": [Color(0.2, 0.22, 0.25), Color(0.36, 0.39, 0.43), Color(0.2, 0.22, 0.25)],
		"mate_weapons": ["cutlass", "spear"], "mate_names": ["Marine Hale", "Marine Orrin", "Marine Tess", "Marine Dunmore", "Marine Pike", "Marine Ansel"],
		"lines": {
			"meet": [["cap", "Captain. You've been entered in my ledger."],
				["you", "Is that supposed to scare me?"],
				["cap", "Every name in it has been crossed out. In time."],
				["mate", "Squad, form up! By order of the Admiralty!"],
				["cap", "Lay down your weapon. Or don't. The ledger balances either way."]],
			"again": [["cap", "Your page is still open. Let's close it."]],
			"grudge_won": [["cap", "You escaped my custody once. Clerical error. Corrected today."]],
			"grudge_lost": [["cap", "You cost me a squad and a promotion. I've come to collect both."]],
			"taunt": ["Predictable.", "Noted.", "Your form is untidy.", "Every mistake goes in the ledger."],
			"hurt": ["Hm.", "Careless of me.", "That will be recorded."],
			"ult": ["Final Entry.", "Account settled.", "Close the book."],
			"mate_down": ["Up, marine. Discipline.", "Hold the line!"],
			"retreat": ["Squad, withdraw in order. This page stays open.", "Fall back. I'll see you at the next harbour, Captain."],
			"gloat": ["Restrain them. Gently. The Admiralty wants them whole.", "Entered and filed."],
			"bounty": ["{b} gold. The Admiralty has never paid me so much to do so little.", "Your bounty is a sentence, Captain. I'm here to read it."],
		},
	},
	"hollow": {
		"name": "Captain Hollow's squad", "captain": "Captain Bertrand Hollow", "title": "the Breakwall", "weapon": "greatsword",
		"pitch": 0.72, "body": "masc", "build": "stout", "hair": "crop", "hair_color": Color(0.55, 0.53, 0.5),
		"hat": "morion", "coat": "greatcoat", "flag": Color(0.68, 0.7, 0.74), "marines": true,
		"palette": [Color(0.3, 0.32, 0.35), Color(0.62, 0.65, 0.68), Color(0.22, 0.23, 0.25)],
		"mate_weapons": ["warhammer", "boarding_axe", "cutlass"], "mate_names": ["Marine Brock", "Marine Kettering", "Marine Yull", "Marine Graves", "Marine Stoll", "Marine Ainsley"],
		"lines": {
			"meet": [["mate", "Captain Hollow, sir! The pirate's in sight!"],
				["cap", "I see them. Shields up. Nobody runs."],
				["you", "Who's running?"],
				["cap", "You will be. Bertrand Hollow. They built the harbour walls after me."],
				["cap", "Marines! Together! Like a wall!"]],
			"again": [["cap", "Back again. The wall doesn't move."]],
			"grudge_won": [["cap", "I carried you to the brig myself last time. You were lighter than you look."]],
			"grudge_lost": [["cap", "You knocked down the wall. It's been rebuilt. Thicker."]],
			"taunt": ["Hit the wall.", "Go on.", "Is that all you've got?", "Stand still and be arrested."],
			"hurt": ["Hrm.", "Good arm.", "Hah!"],
			"ult": ["Breakwall!", "Down!", "Hold fast!"],
			"mate_down": ["On your feet, marine!", "Close ranks!"],
			"retreat": ["Marines, back to the ship. In order! We'll come for them again.", "Withdraw. The wall bends. It doesn't break."],
			"gloat": ["Irons on. Gently, they fought well.", "Into the brig with them."],
			"bounty": ["{b} gold. That's a lot of harbour walls.", "Your face is on every board from here to the capital."],
		},
	},
	"quill": {
		"name": "Commodore Quill's squad", "captain": "Commodore Sabra Quill", "title": "the Iron Tide", "weapon": "cutlass",
		"pitch": 1.02, "body": "fem", "build": "average", "hair": "bun", "hair_color": Color(0.75, 0.74, 0.72),
		"hat": "bicorne", "coat": "admiral", "flag": Color(0.68, 0.7, 0.74), "marines": true,
		"palette": [Color(0.18, 0.19, 0.22), Color(0.66, 0.68, 0.72), Color(0.18, 0.19, 0.22)],
		"mate_weapons": ["cutlass", "spear", "dagger"], "mate_names": ["Marine Corbett", "Marine Vane", "Marine Lisle", "Marine Ferris", "Marine Ogden", "Marine Wren"],
		"lines": {
			"meet": [["cap", "So this is the captain who's been embarrassing my patrols."],
				["you", "Your patrols embarrass themselves."],
				["cap", "Ha. I like you. Sabra Quill, Commodore of the Grey Fleet. I'm still arresting you."],
				["mate", "Marines, ready!"],
				["cap", "All together, then. I don't do duels on the Admiralty's time."]],
			"again": [["cap", "You again. Good. My patrols needed the practice."]],
			"grudge_won": [["cap", "The brig didn't hold you. I've had words with the brig."]],
			"grudge_lost": [["cap", "You beat me once. I've been looking forward to this."]],
			"taunt": ["Too slow, pirate.", "Keep your guard up.", "Is that how they fight out there?", "Again!"],
			"hurt": ["Nice.", "Oh, well done.", "That stung."],
			"ult": ["Iron Tide!", "Full broadside!", "All hands!"],
			"mate_down": ["Marine down! Cover him!", "Reform!"],
			"retreat": ["Disengage! Back to the ships. We'll pick this up at sea.", "Enough. You've earned the day. Not the war."],
			"gloat": ["Clap them in irons. Then get them some water.", "A fine fight. A finer arrest."],
			"bounty": ["{b} on your head. The Admiralty thinks you're dangerous. I'd like to see.", "My clerks read your poster aloud every morning."],
		},
	},
}


## A crew's (or the hunters', or an Admiralty squad's) data.
static func crew(crew_id: String) -> Dictionary:
	if crew_id == "bounty_hunters":
		return HUNTERS
	return CREWS.get(crew_id, ADMIRALTY.get(crew_id, {}))


## `n` bounty hunters for this save (seeded by `seed_`), sharper with `tier` (the captain's bounty tier).
static func hunters(seed_: int, n: int, tier: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["hunters", seed_])
	var names: Array = (HUNTERS["mate_names"] as Array).duplicate()
	var out := []
	for i in range(n):
		var lk: Dictionary = CharacterLook.random_look(rng)
		_dress(lk, HUNTERS, rng)
		var nm := str(names[rng.randi() % names.size()])
		names.erase(nm)
		lk["name"] = nm
		out.append({"name": nm, "look": lk, "captain": false,
			"weapon": str((HUNTERS["mate_weapons"] as Array)[rng.randi() % (HUNTERS["mate_weapons"] as Array).size()]),
			"pitch": rng.randf_range(0.8, 1.1), "skill": clampf(0.35 + 0.12 * tier + rng.randf_range(-0.08, 0.08), 0.2, 0.9)})
	return out

## Every crew's mates say these (taunts across the ring, a mate down, a cheer for their captain).
const MATE_LINES := {
	"taunt": ["Go on, then!", "Get 'em!", "Next one's mine!", "Show 'em, Cap'n!", "Watch the left!",
		"Too slow!", "Make it quick!"],
	"hurt": ["Argh!", "Cheap shot!", "Lucky!"],
	"down": ["Ugh...", "Not... yet...", "Cap'n..."],
}

## Mates per crew (with the captain, 3-5 in all), by how often you've met them.
const MATES := [2, 3, 3, 4]


## The crew's faces as rolled for this save: [{name, look, weapon, captain, pitch}], the captain last.
## `tier` (how many times you've met: they come back stronger) raises the count and their skill.
static func members(crew_id: String, save_seed: int, tier: int) -> Array:
	var c: Dictionary = crew(crew_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([crew_id, save_seed])
	var out := []
	var names: Array = (c["mate_names"] as Array).duplicate()
	for i in range(names.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = names[i]
		names[i] = names[j]
		names[j] = t
	var n: int = MATES[mini(tier, MATES.size() - 1)]
	for i in range(n):
		var lk: Dictionary = CharacterLook.random_look(rng)
		_dress(lk, c, rng)
		if c.get("marines", false):
			EnemyShip.marine_look(lk, rng, false)
		lk["name"] = str(names[i % names.size()])
		out.append({"name": lk["name"], "look": lk, "captain": false,
			"weapon": str((c["mate_weapons"] as Array)[rng.randi() % (c["mate_weapons"] as Array).size()]),
			"pitch": rng.randf_range(0.85, 1.25), "skill": clampf(0.3 + 0.12 * tier + rng.randf_range(-0.1, 0.1), 0.15, 0.85)})
	var cap: Dictionary = CharacterLook.random_look(rng)
	_dress(cap, c, rng)
	for k in ["body", "build", "hair", "hair_color", "hat", "coat"]:
		cap[k] = c[k]
	cap["name"] = str(c["captain"])
	cap["coat_color"] = (c["palette"] as Array)[0]
	cap["trim_color"] = c["flag"]
	out.append({"name": cap["name"], "look": cap, "captain": true, "weapon": str(c["weapon"]),
		"pitch": float(c["pitch"]), "skill": clampf(0.7 + 0.08 * tier, 0.7, 1.0)})
	return out


## A mate in the crew's colours.
static func _dress(lk: Dictionary, c: Dictionary, rng: RandomNumberGenerator) -> void:
	var pal: Array = c["palette"]
	lk["top_color"] = pal[rng.randi() % pal.size()]
	lk["coat_color"] = pal[0]
	lk["legs_color"] = pal[2]
	lk["sash_color"] = c["flag"]
	lk["scarf_color"] = c["flag"]
	lk["hat_color"] = pal[1]


static func line(crew_id: String, moment: String, rng: RandomNumberGenerator, captain := true) -> String:
	var own := captain or crew_id == "bounty_hunters"   # (hunters have only their own lines)
	var pool: Array = (crew(crew_id).get("lines", {}) as Dictionary).get(moment, []) if own else MATE_LINES.get(moment, [])
	if pool.is_empty():
		return ""
	var l = pool[rng.randi() % pool.size()]
	return str(l[1]) if l is Array else str(l)


static func ids() -> Array:
	return CREWS.keys()
