class_name Skills
extends RefCounted
## Every active skill in the game: what it costs, its cooldown, which tree it
## comes from and what it needs (a weapon style, a Devil Fruit, a form).
## The timelines live in the player's Skill state; skills are learned on the
## skill map (or come with a Devil Fruit) and slotted on keys 1-4 (+ R for an
## ultimate).
##
##   needs: "sword" / "gun" (the weapon style you're fighting with) or "".
##   fruit: a fruit id, or "" for skills anyone can learn.
##   tiers: the upgrades past tier 1, in order: {uses, cost, name, desc, cooldown?}. Using
##     the skill `uses` times opens the tier, then it costs `cost` points from
##     its tree (Progression.rank_up). The top tier changes how it works.

const ICON_DIR := "res://assets/textures/icons/"

const ALL := {
	# --- Mobility / Survival (Rokushiki-style body techniques) ---
	"soru": {"name": "Soru", "tree": "base", "cost": 14.0, "cooldown": 4.0, "needs": "", "fruit": "",
		"desc": "Kick off the ground so fast you vanish: an instant step forward, untouchable, on the ground or in the air.",
		"tiers": [
			{"uses": 15, "cost": 2, "name": "Double Step", "desc": "Cast it again within a second of the first for a second step, free."},
			{"uses": 50, "cost": 3, "name": "Shadow Step", "desc": "Mastered: your dodge vanishes you too. For about a second you're invisible and nothing can touch you (8 energy a dodge; a normal dodge without it)."},
		]},
	"tekkai": {"name": "Tekkai", "tree": "base", "cost": 20.0, "cooldown": 14.0, "needs": "", "fruit": "",
		"desc": "Harden your whole body for 3 s: take 70% less damage and nothing knocks you down or makes you flinch, but you can barely move.",
		"tiers": [
			{"uses": 12, "cost": 2, "name": "Walking Iron", "desc": "Lasts 5 s, and you can still walk at a steady pace."},
			{"uses": 40, "cost": 3, "name": "Iron Reflex", "desc": "Mastered: it happens by itself. A blow that would knock you down hardens you on the spot for 1.5 s instead (once every 15 s)."},
		]},
	# --- Sword ---
	"flying_slash": {"name": "Flying Slash", "tree": "sword", "cost": 16.0, "cooldown": 3.5, "needs": "sword", "fruit": "",
		"desc": "A cut so fast it flies: a crescent of wind that slices through every enemy in its path."},
	"tiger_rush": {"name": "Tiger Rush", "tree": "katana", "cost": 22.0, "cooldown": 7.0, "needs": "sword", "fruit": "",
		"desc": "Dash straight through the enemy line with a single drawing cut. Nothing touches you on the way."},
	# --- Gun ---
	"bullet_storm": {"name": "Bullet Storm", "tree": "pistol", "cost": 24.0, "cooldown": 9.0, "needs": "gun", "fruit": "",
		"desc": "Fan the hammer: seven shots swept across everything in front of you. Doesn't use your loaded shots."},
	# --- Haki ---
	"armament_coat": {"name": "Armament: Coat", "tree": "base", "cost": 30.0, "cooldown": 20.0, "needs": "", "fruit": "",
		"desc": "Coat your weapon (or fists) in black Haki for 8 s: +30% damage, nothing can block it, and your heavy attacks break guards.",
		"tiers": [
			{"uses": 12, "cost": 2, "name": "Hardened", "desc": "The coat holds for 12 s."},
			{"uses": 40, "cost": 3, "name": "Ryuo", "desc": "Mastered: Haki flows out of the blade. Every coated heavy hit bursts outward, striking everyone around the target."},
		]},
	"foresight": {"name": "Foresight", "tree": "base", "cost": 25.0, "cooldown": 18.0, "needs": "", "fruit": "",
		"desc": "Sense what's coming for 5 s: the next attack that would hit you is dodged automatically, and time slows for a moment.",
		"tiers": [
			{"uses": 12, "cost": 2, "name": "Second Sight", "desc": "Lasts 8 s and dodges the next two attacks."},
			{"uses": 40, "cost": 3, "cooldown": 3.0, "name": "Future Sight", "desc": "Mastered: a stance you switch on and off. While on, it dodges an attack by itself every 3 s; it drains 2 energy a second and drops when you run dry."},
		]},
	# --- Ember Fruit (Logia) ---
	"fire_fist": {"name": "Fire Fist", "tree": "Ember", "cost": 18.0, "cooldown": 2.5, "needs": "", "fruit": "ember",
		"desc": "Hurl a ball of fire where you aim. It bursts on impact and sets enemies ablaze."},
	"fire_ring": {"name": "Blazing Ring", "tree": "Ember", "cost": 32.0, "cooldown": 9.0, "needs": "", "fruit": "ember",
		"desc": "A ring of fire explodes out around you, throwing nearby enemies off their feet."},
	"flame_dash": {"name": "Flame Dash", "tree": "Ember", "cost": 22.0, "cooldown": 6.0, "needs": "", "fruit": "ember",
		"desc": "Burst forward in a streak of fire, untouchable, scorching anyone in the way and leaving a trail of flame."},
	"ember_field": {"name": "Ember Field", "tree": "Ember", "cost": 28.0, "cooldown": 12.0, "needs": "", "fruit": "ember",
		"desc": "Set the ground ahead ablaze. Enemies won't walk through it, and those caught inside burn."},
	"inferno": {"name": "Great Inferno", "tree": "Ember", "cost": 0.0, "cooldown": 3.0, "needs": "", "fruit": "ember", "ult": true,
		"desc": "Ultimate. Leap up wreathed in flame and slam down: a pillar of fire floors everything around you and leaves the ground burning."},
	# --- Wolf Fruit (Zoan) ---
	"rending_fang": {"name": "Rending Fang", "tree": "Wolf", "cost": 18.0, "cooldown": 4.0, "needs": "", "fruit": "wolf",
		"desc": "Lunge at the nearest enemy and rake it three times. Much stronger in hybrid form."},
	"pounce": {"name": "Pounce", "tree": "Wolf", "cost": 16.0, "cooldown": 5.0, "needs": "", "fruit": "wolf",
		"desc": "A huge bounding leap toward where you aim, landing with a slam that knocks small fry down."},
	"howl": {"name": "Alpha Howl", "tree": "Wolf", "cost": 30.0, "cooldown": 20.0, "needs": "", "fruit": "wolf",
		"desc": "Howl: for 8 s you hit 25% harder and run faster, and nearby enemies flinch in fear."},
	# --- Vine Fruit (Paramecia) ---
	"vine_snare": {"name": "Vine Snare", "tree": "Vine", "cost": 18.0, "cooldown": 6.0, "needs": "", "fruit": "vine",
		"desc": "Fling a seed that bursts into grasping vines, rooting enemies where they stand for a few seconds."},
	"vine_swing": {"name": "Vine Swing", "tree": "Vine", "cost": 10.0, "cooldown": 1.5, "needs": "", "fruit": "vine",
		"desc": "Shoot a vine at whatever you aim at (trees, cliffs, walls) and swing from it. Jump to let go and keep your momentum."},
	"thorn_whip": {"name": "Thorn Whip", "tree": "Vine", "cost": 20.0, "cooldown": 6.0, "needs": "", "fruit": "vine",
		"desc": "Lash a thorned vine through everything in a line in front of you and drag them toward you."},

	# === Weapon techniques (TechniqueState). styles: the fighting styles that can use it ===
	# --- Cutlass ---
	"riposte": {"name": "Riposte", "tree": "sword", "cost": 16.0, "cooldown": 6.0, "styles": ["sword"], "needs_text": "a cutlass", "state": "Technique",
		"desc": "Raise your guard for a moment: the first melee blow aimed at you is turned aside and answered with a heavy cut that staggers."},
	"iai_counter": {"name": "Iai Counter", "tree": "katana", "cost": 16.0, "cooldown": 6.0, "styles": ["katana"], "needs_text": "a katana", "state": "Technique",
		"desc": "Slip the blade home and wait, hand on the hilt: the first melee blow aimed at you is met by a drawing cut before it lands."},
	"cross_counter": {"name": "Crossed Counter", "tree": "dual", "cost": 16.0, "cooldown": 6.0, "styles": ["dual_sword"], "needs_text": "two blades", "state": "Technique",
		"desc": "Cross both blades in front of you: the first melee blow aimed at you is caught in the X and answered with a scissoring cut."},
	"swordfish": {"name": "Swordfish Flurry", "tree": "sword", "cost": 22.0, "cooldown": 8.0, "styles": ["sword"], "needs_text": "a cutlass", "state": "Technique",
		"desc": "Five lightning thrusts driving forward; the last one throws them back."},
	"kraken_wake": {"name": "Kraken's Wake", "tree": "sword", "cost": 0.0, "cooldown": 3.0, "styles": ["sword"], "needs_text": "a cutlass", "state": "Technique", "ult": true,
		"desc": "Ultimate. Flash between up to six enemies around you, cutting each as you pass, then every one of them is torn open at once and thrown down."},
	# --- Katana ---
	"wind_sever": {"name": "Wind Severer", "tree": "katana", "cost": 20.0, "cooldown": 7.0, "styles": ["katana"], "needs_text": "a katana", "state": "Technique",
		"desc": "A rising two-handed cut that sends a towering blade of wind tearing along the ground, knocking down everything it passes."},
	"phantom_step": {"name": "Phantom Step", "tree": "katana", "cost": 18.0, "cooldown": 6.0, "styles": ["katana"], "needs_text": "a katana", "state": "Technique",
		"desc": "Blink behind the nearest enemy (up to 9 m) and cut them down from behind before they can turn. It can't be blocked."},
	"petal_storm": {"name": "Thousand Petals", "tree": "katana", "cost": 0.0, "cooldown": 3.0, "styles": ["katana"], "needs_text": "a katana", "state": "Technique", "ult": true,
		"desc": "Ultimate. Draw and sheathe in a single motion. A heartbeat later every enemy within 9 m is cut a dozen times at once, and falls."},
	# --- Axe ---
	"axe_throw": {"name": "Hatchet Throw", "tree": "axe", "cost": 16.0, "cooldown": 5.0, "styles": ["axe"], "needs_text": "an axe", "state": "Technique",
		"desc": "Hurl your axe spinning ahead: it cuts through everything in its path and comes back to your hand."},
	"earthsplitter": {"name": "Earthsplitter", "tree": "axe", "cost": 26.0, "cooldown": 9.0, "styles": ["axe"], "needs_text": "an axe", "state": "Technique",
		"desc": "Leap and drive the axe into the ground: a crack tears 9 m ahead and everyone on it is knocked flat."},
	"berserk": {"name": "Berserk", "tree": "axe", "cost": 24.0, "cooldown": 22.0, "styles": ["axe"], "needs_text": "an axe", "state": "Technique",
		"desc": "Roar: for 8 s you hit 25% harder and nothing makes you flinch or falls you, but you take 15% more damage."},
	"maelstrom": {"name": "Maelstrom", "tree": "axe", "cost": 0.0, "cooldown": 3.0, "styles": ["axe"], "needs_text": "an axe", "state": "Technique", "ult": true,
		"desc": "Ultimate. Become a whirlwind of steel for 3 s: you move freely, drag enemies in and cut them again and again; the last turn throws them all down."},
	# --- Dual wield ---
	"blade_dance": {"name": "Blade Dance", "tree": "dual", "cost": 22.0, "cooldown": 8.0, "styles": ["dual_sword"], "needs_text": "two blades", "state": "Technique",
		"desc": "Dance forward through the enemy line in six spinning cuts."},
	"cross_fang": {"name": "Cross Fang", "tree": "dual", "cost": 18.0, "cooldown": 6.0, "styles": ["dual_sword"], "needs_text": "two blades", "state": "Technique",
		"desc": "Leap forward and crash down with both blades crossed, knocking down everything in front of you."},
	"steel_tempest": {"name": "Tempest of Steel", "tree": "dual", "cost": 0.0, "cooldown": 3.0, "styles": ["dual_sword"], "needs_text": "two blades", "state": "Technique", "ult": true,
		"desc": "Ultimate. Spin in place with both blades out: a storm of cuts drags in everything around you, then a crossed burst hurls them away."},
	# --- Pistol ---
	"deadeye": {"name": "Deadeye", "tree": "pistol", "cost": 20.0, "cooldown": 7.0, "styles": ["pistol", "dual_pistol"], "needs_text": "a pistol", "state": "Technique",
		"desc": "A breath, a steady aim, and one shot that punches through every enemy in a line."},
	"smoke_bomb": {"name": "Smoke Bomb", "tree": "pistol", "cost": 18.0, "cooldown": 14.0, "styles": ["pistol", "dual_pistol"], "needs_text": "a pistol", "state": "Technique",
		"desc": "Throw down a smoke bomb: everyone close coughs and staggers, and you vanish from sight for 1.5 s."},
	"point_blank": {"name": "Point Blank", "tree": "pistol", "cost": 16.0, "cooldown": 5.0, "styles": ["pistol", "dual_pistol"], "needs_text": "a pistol", "state": "Technique",
		"desc": "Shove the barrel into the nearest enemy and fire: a blast that throws them off their feet."},
	"deaths_waltz": {"name": "Death's Waltz", "tree": "pistol", "cost": 0.0, "cooldown": 3.0, "styles": ["pistol", "dual_pistol"], "needs_text": "a pistol", "state": "Technique", "ult": true,
		"desc": "Ultimate. Turn through a deadly waltz, shooting every enemy within 18 m three times; the last shot knocks them down."},
	# --- Unarmed: grapples ---
	"suplex": {"name": "Suplex", "tree": "unarmed", "cost": 18.0, "cooldown": 6.0, "styles": ["fist"], "needs_text": "empty hands", "state": "Technique",
		"desc": "Grab the enemy in front of you, arch back and slam them head-first into the ground behind you."},
	"hip_toss": {"name": "Shoulder Throw", "tree": "unarmed", "cost": 16.0, "cooldown": 5.0, "styles": ["fist"], "needs_text": "empty hands", "state": "Technique",
		"desc": "Grab the enemy in front of you and hurl them over your shoulder; anyone they land on goes down too."},
	"giant_swing": {"name": "Giant Swing", "tree": "unarmed", "cost": 24.0, "cooldown": 10.0, "styles": ["fist"], "needs_text": "empty hands", "state": "Technique",
		"desc": "Grab an enemy and spin, smashing everyone around you with them, then let them fly."},
	# --- Unarmed: martial arts ---
	"hundred_fists": {"name": "Hundred Fists", "tree": "unarmed", "cost": 20.0, "cooldown": 7.0, "styles": ["fist"], "needs_text": "empty hands", "state": "Technique",
		"desc": "A blur of punches for a second, then a last straight that blows them away."},
	"rising_dragon": {"name": "Rising Dragon", "tree": "unarmed", "cost": 18.0, "cooldown": 6.0, "styles": ["fist"], "needs_text": "empty hands", "state": "Technique",
		"desc": "A leaping uppercut that launches you and everyone in front of you into the air."},
	"palm_strike": {"name": "Shockwave Palm", "tree": "unarmed", "cost": 16.0, "cooldown": 5.0, "styles": ["fist"], "needs_text": "empty hands", "state": "Technique",
		"desc": "Drive an open palm forward: a burst of air hurls everything in a cone in front of you."},
	"sea_king_fist": {"name": "Sea King Fist", "tree": "unarmed", "cost": 0.0, "cooldown": 3.0, "styles": ["fist"], "needs_text": "empty hands", "state": "Technique", "ult": true,
		"desc": "Ultimate. Draw your fist back as the air trembles, then punch: a shockwave as wide as a ship tears 14 m ahead, knocking everything flat."},
	# --- Haki ---
	"conquerors_haki": {"name": "Conqueror's Haki", "tree": "base", "cost": 0.0, "cooldown": 3.0, "state": "Technique", "ult": true,
		"desc": "Ultimate. Unleash the will of a king: weak foes around you (common pirates and bugs below 40% health) faint on the spot; everyone else is thrown back, reeling."},
}


static func get_skill(id: String) -> Dictionary:
	return ALL.get(id, {})


static func is_ult(id: String) -> bool:
	return bool(get_skill(id).get("ult", false))


static func max_tier(id: String) -> int:
	return 1 + (get_skill(id).get("tiers", []) as Array).size()


## The upgrade that makes tier `tier` (2 and up).
static func tier_def(id: String, tier: int) -> Dictionary:
	var t: Array = get_skill(id).get("tiers", [])
	return t[tier - 2] if tier >= 2 and tier - 2 < t.size() else {}


static var _icon_cache: Dictionary = {}


## The skill's icon. Falls back to reading the PNG straight off disk when the
## editor hasn't imported it yet (fresh files added while it was closed).
static func icon(id: String) -> Texture2D:
	if _icon_cache.has(id):
		return _icon_cache[id]
	var path := ICON_DIR + "skill_" + id + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null and FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	if tex:
		_icon_cache[id] = tex
	return tex
