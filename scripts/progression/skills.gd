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
## Skills that became others (an old save's bar keeps the slot): the fists' wrestling moves went in 1.18.4.
const RENAMED := {"suplex": "cannonball_fist", "giant_swing": "meteor_fist", "mule_kick": "rising_heel", "cartwheel_crescent": "sky_chase"}

const ALL := {
	# --- Mobility / Survival (Rokushiki-style body techniques) ---
	"soru": {"name": "Squall Step", "tree": "base", "cost": 14.0, "cooldown": 4.0, "needs": "", "fruit": "",
		"desc": "Kick off the ground so fast you vanish: an instant step forward, untouchable, on the ground or in the air.",
		"tiers": [
			{"uses": 15, "cost": 2, "name": "Double Step", "desc": "Cast it again within a second of the first for a second step, free."},
			{"uses": 50, "cost": 3, "name": "Shadow Step", "desc": "Mastered: your dodge vanishes you too. For about a second you're invisible and nothing can touch you (8 energy a dodge; a normal dodge without it)."},
		]},
	"tekkai": {"name": "Ballast", "tree": "base", "cost": 20.0, "cooldown": 14.0, "needs": "", "fruit": "",
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
	"edy_reinforce": {"name": "Reinforce", "tree": "base", "cost": 25.0, "cooldown": 60.0, "needs": "", "fruit": "",
		"desc": "Iron Will. Edy through your whole body for 15 s: +10% speed, a quarter less stamina, +8 defense, and light blows don't make you flinch."},
	"armament_coat": {"name": "Infuse", "tree": "base", "cost": 30.0, "cooldown": 20.0, "needs": "", "fruit": "",
		"desc": "Iron Will. Pour your Edy into your weapon (or fists) for 8 s: +30% damage, nothing can block it, and your heavy attacks break guards.",
		"tiers": [
			{"uses": 12, "cost": 2, "name": "Hardened", "desc": "Infuse holds for 12 s."},
			{"uses": 40, "cost": 3, "name": "Outflow", "desc": "Mastered: Edy flows out of the blade. Every infused heavy hit bursts outward, striking everyone around the target."},
		]},
	"foresight": {"name": "Foresight", "tree": "base", "cost": 25.0, "cooldown": 18.0, "needs": "", "fruit": "",
		"desc": "Sense what's coming for 5 s: the next attack that would hit you is dodged automatically, and time slows for a moment.",
		"tiers": [
			{"uses": 12, "cost": 2, "name": "Second Sight", "desc": "Lasts 8 s and dodges the next two attacks."},
			{"uses": 40, "cost": 3, "cooldown": 3.0, "name": "Future Sight", "desc": "Mastered: a stance you switch on and off. While on, it dodges an attack by itself every 3 s; it drains 2 energy a second and drops when you run dry."},
		]},
	# --- Will (WillPaths' 1.24 paths; run by WillArts in the Technique state) ---
	"will_swell": {"name": "Swell", "tree": "base", "cost": 25.0, "cooldown": 45.0, "needs": "", "fruit": "", "state": "Technique",
		"desc": "Tide Will. Aboard your ship: stamp the deck and a wave rolls over it, throwing every boarder off."},
	"will_wind": {"name": "Call the Wind", "tree": "base", "cost": 20.0, "cooldown": 180.0, "needs": "", "fruit": "", "state": "Technique",
		"desc": "Tide Will. Aboard or beside your ship: whistle up a wind, 25% more sail speed for 30 s."},
	"will_twin": {"name": "Twin Finisher", "tree": "base", "cost": 0.0, "cooldown": 8.0, "needs": "", "fruit": "", "state": "Technique",
		"desc": "Bond Will. With the joint gauge full: you and your linked crewmate close on the nearest foe from both sides and cross your weapons through it (alone: your ship's broadside is the second weapon)."},
	"will_glimpse": {"name": "Glimpse", "tree": "base", "cost": 15.0, "cooldown": 30.0, "needs": "", "fruit": "", "state": "Technique",
		"desc": "Sense. For 3 s you see every foe and closed chest within 40 m, through walls."},
	"will_flag": {"name": "Plant the Flag", "tree": "base", "cost": 25.0, "cooldown": 60.0, "needs": "", "fruit": "", "state": "Technique",
		"desc": "Captain's Will. Drive your flag into the ground: for 20 s every captain within 6 m of it mends 3% of their health a second."},
	"will_still_point": {"name": "Still Point", "tree": "base", "cost": 30.0, "cooldown": 120.0, "needs": "", "fruit": "", "state": "Technique",
		"desc": "Tempo Will. Find the still point: for 3 s every foe within 20 m moves and strikes at half speed, and you don't."},
	"will_berserk": {"name": "Berserk", "tree": "base", "cost": 20.0, "cooldown": 40.0, "needs": "", "fruit": "", "state": "Technique",
		"desc": "Fury Will. Throw your guard away for 10 s: every blow you land heals you 4% of its damage, and blows on you land 20% harder."},
	# --- Ember Fruit (Logia) ---
	# (1.27) the Clockwork Fruit's first powers: Rewind (its movement) and Time Stop (its CC; its forms: FruitForms)
	"rewind": {"name": "Rewind", "tree": "Clockwork", "cost": 22.0, "cooldown": 10.0, "needs": "", "fruit": "clockwork",
		"desc": "Step back to where you stood 3 s ago, as if the last moments never happened to you."},
	"time_stop": {"name": "Time Stop", "tree": "Clockwork", "cost": 26.0, "cooldown": 12.0, "needs": "", "fruit": "clockwork",
		"desc": "Stop one foe in front of you in time for 3 s. Used often, time stops by itself for whoever strikes you."},
	# (1.27) the Echo Fruit's first powers: Echo Step (its movement) and Shatter Note (its CC; its forms: FruitForms)
	"echo_step": {"name": "Echo Step", "tree": "Echo", "cost": 20.0, "cooldown": 7.0, "needs": "", "fruit": "echo",
		"desc": "Follow your own echo: step out behind the nearest foe within 12 m."},
	"shatter_note": {"name": "Shatter Note", "tree": "Echo", "cost": 28.0, "cooldown": 9.0, "needs": "", "fruit": "echo",
		"desc": "One hard note down a 14 m line: everyone on it reels. Used often, your dodges ring out by themselves."},
	# (1.27) fourth powers, part 2
	"thunder_spear": {"name": "Thunder Spear", "tree": "Storm", "cost": 26.0, "cooldown": 9.0, "needs": "", "fruit": "storm",
		"desc": "Throw a bolt straight ahead: everyone on its 18 m line struck."},
	"pull_gale": {"name": "Pull Gale", "tree": "Gust", "cost": 24.0, "cooldown": 10.0, "needs": "", "fruit": "gust",
		"desc": "Turn the wind round: everyone in the cone ahead (10 m) dragged in to you."},
	"maul": {"name": "Maul", "tree": "Bear", "cost": 24.0, "cooldown": 8.0, "needs": "", "fruit": "bear",
		"desc": "One huge swing: everyone in a wide arc in front of you floored."},
	"hamstring": {"name": "Hamstring", "tree": "Wolf", "cost": 18.0, "cooldown": 7.0, "needs": "", "fruit": "wolf",
		"desc": "Cut the foe in front of you low: hurt, and at half speed for 4 s."},
	"root_field": {"name": "Root Field", "tree": "Vine", "cost": 30.0, "cooldown": 14.0, "needs": "", "fruit": "vine",
		"desc": "Roots up out of the ground 4 m ahead: everyone within 4 m of them held 2.5 s."},
	"echo_strike": {"name": "Echo Strike", "tree": "Echo", "cost": 25.0, "cooldown": 18.0, "needs": "", "fruit": "echo",
		"desc": "For 8 s every blow you land comes again a moment later, half as hard."},
	# (1.27) fourth powers: Clockwork's Haste, Bubble's and Iron's movement
	"haste": {"name": "Haste", "tree": "Clockwork", "cost": 30.0, "cooldown": 20.0, "needs": "", "fruit": "clockwork",
		"desc": "Wind the crew's clocks: everyone within 12 m of you 25% quicker for 8 s."},
	"bubble_bounce": {"name": "Bubble Bounce", "tree": "Bubble", "cost": 15.0, "cooldown": 5.0, "needs": "", "fruit": "bubble",
		"desc": "Off a bubble underfoot: high into the air and forward."},
	"iron_drop": {"name": "Iron Drop", "tree": "Iron", "cost": 22.0, "cooldown": 9.0, "needs": "", "fruit": "iron",
		"desc": "Leap ahead and come down like an anchor: everyone within 3.5 m of where you land floored."},
	# (1.27) third powers for Storm, Gust, Iron, Bubble and Bear
	"thundercloud": {"name": "Thundercloud", "tree": "Storm", "cost": 30.0, "cooldown": 15.0, "needs": "", "fruit": "storm",
		"desc": "A cloud 5 m ahead for 6 s, striking whoever stands under it every 1.2 s."},
	"gust_updraft": {"name": "Updraft", "tree": "Gust", "cost": 24.0, "cooldown": 10.0, "needs": "", "fruit": "gust",
		"desc": "Wind straight up from the ground 5 m ahead: everyone over it thrown into the air."},
	"iron_slam": {"name": "Iron Slam", "tree": "Iron", "cost": 26.0, "cooldown": 11.0, "needs": "", "fruit": "iron",
		"desc": "Both iron fists into the ground: everyone within 5 m floored."},
	"bubble_trap": {"name": "Bubble Trap", "tree": "Bubble", "cost": 22.0, "cooldown": 10.0, "needs": "", "fruit": "bubble",
		"desc": "Blow a bubble round the foe in front of you (9 m): it's held 3 s, then pops."},
	"bear_hug": {"name": "Bear Hug", "tree": "Bear", "cost": 24.0, "cooldown": 9.0, "needs": "", "fruit": "bear",
		"desc": "Seize the foe right in front of you, lift them, and throw them 10 m. Not bosses."},
	# (1.27) the Clockwork and Echo Fruits' third powers: Slow Field and Sonar
	"slow_field": {"name": "Slow Field", "tree": "Clockwork", "cost": 30.0, "cooldown": 16.0, "needs": "", "fruit": "clockwork",
		"desc": "A ring of slow time 4 m ahead of you for 5 s: foes in it move and swing at 40% speed."},
	"sonar": {"name": "Sonar", "tree": "Echo", "cost": 15.0, "cooldown": 12.0, "needs": "", "fruit": "echo",
		"desc": "One pulse out to 30 m: every foe and cache in it marked for 6 s, through walls."},
	# (1.27) the Bear Fruit's first powers: Bear Charge (its movement) and Roar (its CC; its forms: FruitForms)
	"bear_charge": {"name": "Bear Charge", "tree": "Bear", "cost": 20.0, "cooldown": 6.0, "needs": "", "fruit": "bear",
		"desc": "Charge 8 m the way you face and slam into whoever is at the end of it, knocking them flat."},
	"bear_roar": {"name": "Roar", "tree": "Bear", "cost": 24.0, "cooldown": 12.0, "needs": "", "fruit": "bear",
		"desc": "A roar that stuns everyone round you. Used often, you roar by yourself when you're surrounded."},
	# (1.27) the Gust Fruit's first powers: Gale Dash (its movement) and Gust Cone (its CC; its forms: FruitForms)
	"gale_dash": {"name": "Gale Dash", "tree": "Gust", "cost": 18.0, "cooldown": 4.0, "needs": "", "fruit": "gust",
		"desc": "Ride a rush of wind 12 m the way you face (not through walls)."},
	"gust_cone": {"name": "Gust Cone", "tree": "Gust", "cost": 24.0, "cooldown": 7.0, "needs": "", "fruit": "gust",
		"desc": "A blast of wind in a cone ahead: everyone in it is blown back and off their feet. Used often, the wind answers by itself when you're struck."},
	# (1.27) the Bubble Fruit's first powers: Bubble Shield (its forms: FruitForms) and Slick Floor (its CC)
	"bubble_shield": {"name": "Bubble Shield", "tree": "Bubble", "cost": 24.0, "cooldown": 14.0, "needs": "", "fruit": "bubble",
		"desc": "A bubble round you that takes the next 3 hits. Used often, one forms by itself when you're hurt, and in the end one hit in five just pops a bubble."},
	"slick_floor": {"name": "Slick Floor", "tree": "Bubble", "cost": 20.0, "cooldown": 8.0, "needs": "", "fruit": "bubble",
		"desc": "A soapy patch ahead of you: every foe on it slips and falls."},
	# (1.27) the Storm Fruit's first powers: Thunder Step (its movement) and Chain Lightning (its forms: FruitForms)
	"thunder_step": {"name": "Thunder Step", "tree": "Storm", "cost": 20.0, "cooldown": 5.0, "needs": "", "fruit": "storm",
		"desc": "Blink 9 m the way you face as a bolt of lightning, through the air and past foes (not through walls)."},
	"chain_lightning": {"name": "Chain Lightning", "tree": "Storm", "cost": 26.0, "cooldown": 7.0, "needs": "", "fruit": "storm",
		"desc": "A bolt at the nearest foe ahead that leaps on to three more close by. Used often, it starts leaping from you to whoever hits you."},
	# (1.27) the Iron Fruit's first powers: Iron Guard (its forms grow from its uses: FruitForms) and Iron Fist
	"iron_guard": {"name": "Iron Guard", "tree": "Iron", "cost": 22.0, "cooldown": 10.0, "needs": "", "fruit": "iron",
		"desc": "Your skin turns to iron for 3 s: blows do half damage and nothing staggers you. Used often, it starts to happen by itself against heavy blows, and in the end only a technique can shake you."},
	"iron_fist": {"name": "Iron Fist", "tree": "Iron", "cost": 18.0, "cooldown": 4.0, "needs": "", "fruit": "iron",
		"desc": "A punch of solid iron at whoever's in front of you: it breaks guards and shields and knocks them back."},
	# (1.27) Ember's Flame Body, its Active form (FruitForms: Reflex and Nature grow from its uses)
	"flicker": {"name": "Flicker", "tree": "Ember", "cost": 25.0, "cooldown": 12.0, "needs": "", "fruit": "ember",
		"desc": "Your body turns to flame for a moment: blades and shot pass through you. Used often, it starts to happen by itself, and in the end it's simply what you are."},
	"fire_fist": {"name": "Cinder Fist", "tree": "Ember", "cost": 18.0, "cooldown": 2.5, "needs": "", "fruit": "ember",
		"desc": "Hurl a ball of fire where you aim. It bursts on impact and sets enemies ablaze."},
	"fire_ring": {"name": "Blazing Ring", "tree": "Ember", "cost": 32.0, "cooldown": 9.0, "needs": "", "fruit": "ember",
		"desc": "A ring of fire explodes out around you, throwing nearby enemies off their feet."},
	"flame_dash": {"name": "Flame Dash", "tree": "Ember", "cost": 22.0, "cooldown": 6.0, "needs": "", "fruit": "ember",
		"desc": "Burst forward in a streak of fire, untouchable, scorching anyone in the way and leaving a trail of flame."},
	"ember_field": {"name": "Ember Field", "tree": "Ember", "cost": 28.0, "cooldown": 12.0, "needs": "", "fruit": "ember",
		"desc": "Set the ground ahead ablaze. Enemies won't walk through it, and those caught inside burn."},
	# (1.27) Ember's awakening (mastery 30): Sunborn, an ultimate
	"sunborn": {"name": "Sunborn", "tree": "Ember", "cost": 0.0, "cooldown": 3.0, "needs": "", "fruit": "ember", "ult": true,
		"desc": "The fruit awakened: for 30 s you burn like the sun. Everything near you catches, and blows pass through you half the time (shot always)."},
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
	"twin_waves": {"name": "Twin Waves", "tree": "katana", "cost": 22.0, "cooldown": 7.0, "styles": ["katana"], "needs_text": "a katana", "state": "Technique",
		"desc": "A rising cut and a falling one: two blades of wind sent out from either side, crossing ahead of you, knocking down everything either passes (a little lighter each than Wind Severer's one)."},
	"side_step": {"name": "Side Step", "tree": "katana", "cost": 16.0, "cooldown": 6.0, "styles": ["katana"], "needs_text": "a katana", "state": "Technique",
		"desc": "Slip the blade home and wait, hand on the hilt: the first melee blow aimed at you meets empty air. You're already out at their side, drawing across them. The cut can't be blocked."},
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
		"desc": "Ultimate. Cross both blades overhead, then spin in place with them out: a storm of cuts drags in everything around you, then a crossed burst hurls them away."},
	# --- Sword and pistol (Corsair); its techniques fire free shots (they don't use the pistol's load) ---
	"parley": {"name": "Parley", "tree": "corsair", "cost": 16.0, "cooldown": 6.0, "styles": ["sword_pistol"], "needs_text": "a cutlass and a pistol", "state": "Technique",
		"desc": "Raise the cutlass for a moment: the first melee blow aimed at you is turned aside on the blade, and the pistol is put to their chest and fired."},
	"grapeshot": {"name": "Grapeshot", "tree": "corsair", "cost": 20.0, "cooldown": 7.0, "styles": ["sword_pistol"], "needs_text": "a cutlass and a pistol", "state": "Technique",
		"desc": "A pistol packed with shot: one blast tears across everything in a wide cone in front of you and throws them back reeling."},
	"crossfire": {"name": "Crossfire", "tree": "corsair", "cost": 22.0, "cooldown": 8.0, "styles": ["sword_pistol"], "needs_text": "a cutlass and a pistol", "state": "Technique",
		"desc": "Dash through the enemy you're facing (up to 9 m) with a cut that breaks their guard, turn, and shoot them in the back. The shot can't be blocked and knocks them flat."},
	"broadside": {"name": "Broadside", "tree": "corsair", "cost": 0.0, "cooldown": 3.0, "styles": ["sword_pistol"], "needs_text": "a cutlass and a pistol", "state": "Technique", "ult": true,
		"desc": "Ultimate. Raise your cutlass and call the broadside: a shot into each of up to six enemies around you, then cannon fire lands on every one of them and throws them down."},
	# --- One dagger ---
	"slip": {"name": "Slip", "tree": "dagger", "cost": 16.0, "cooldown": 6.0, "styles": ["dagger"], "needs_text": "a dagger", "state": "Technique",
		"desc": "Sink low and offer an opening: the first melee blow aimed at you slips past, and you're behind them with the blade in their back. A sure crit, and it bleeds."},
	"cutthroat": {"name": "Cutthroat", "tree": "dagger", "cost": 18.0, "cooldown": 6.0, "styles": ["dagger"], "needs_text": "a dagger", "state": "Technique",
		"desc": "Step out of sight and out from behind the enemy you're facing (up to 8 m), and open their throat before they can turn: a sure crit that bleeds. It can't be blocked."},
	"knife_fan": {"name": "Knife Fan", "tree": "dagger", "cost": 16.0, "cooldown": 6.0, "styles": ["dagger"], "needs_text": "a dagger", "state": "Technique",
		"desc": "Flick five throwing knives out in a fan: everyone in front of you within 10 m is cut and bleeds."},
	"red_eclipse": {"name": "Red Eclipse", "tree": "dagger", "cost": 0.0, "cooldown": 3.0, "styles": ["dagger"], "needs_text": "a dagger", "state": "Technique", "ult": true,
		"desc": "Ultimate. Melt into the dark and cut every enemy around you (up to six) from behind, unseen; a heartbeat after you step back into sight, every wound opens at once and they fall, bleeding."},
	# --- Two daggers ---
	"viper_flurry": {"name": "Viper Flurry", "tree": "dual_dagger", "cost": 20.0, "cooldown": 7.0, "styles": ["dual_dagger"], "needs_text": "two daggers", "state": "Technique",
		"desc": "Eight stabs in a second, the blades striking in turn like a snake; the last pair rips out and throws them back, bleeding."},
	"scissor_leap": {"name": "Scissor Leap", "tree": "dual_dagger", "cost": 18.0, "cooldown": 6.0, "styles": ["dual_dagger"], "needs_text": "two daggers", "state": "Technique",
		"desc": "Leap at the enemy you're facing (up to 9 m) and scissor both blades through them as you land: it breaks their guard and opens a wound."},
	"bleeding_edge": {"name": "Bleeding Edge", "tree": "dual_dagger", "cost": 22.0, "cooldown": 20.0, "styles": ["dual_dagger"], "needs_text": "two daggers", "state": "Technique",
		"desc": "Whet the blades against each other: for 8 s every hit you land makes them bleed, and 20% more of your hits are crits."},
	"hundred_fangs": {"name": "Hundred Fangs", "tree": "dual_dagger", "cost": 0.0, "cooldown": 3.0, "styles": ["dual_dagger"], "needs_text": "two daggers", "state": "Technique", "ult": true,
		"desc": "Ultimate. Flash round the enemy you pick from every side, cutting everyone close each time until your path draws a star; then the star bursts and they all fall, bleeding."},
	# --- Polearm ---
	"hundred_thrusts": {"name": "Hundred Thrusts", "tree": "polearm", "cost": 20.0, "cooldown": 7.0, "styles": ["polearm"], "needs_text": "a polearm", "state": "Technique",
		"desc": "Plant your feet and drive the point out seven times in a second, every thrust reaching four paces ahead; the last drives through them and throws them back."},
	"dragon_sweep": {"name": "Dragon Sweep", "tree": "polearm", "cost": 22.0, "cooldown": 8.0, "styles": ["polearm"], "needs_text": "a polearm", "state": "Technique",
		"desc": "Drop low and swing the spear round twice at the shins: everyone within five paces is cut, and the second turn takes their legs out from under them."},
	"vault_strike": {"name": "Vaulting Strike", "tree": "polearm", "cost": 18.0, "cooldown": 6.0, "styles": ["polearm"], "needs_text": "a polearm", "state": "Technique",
		"desc": "Plant the butt and vault over the enemy you're facing (up to 9 m), driving the point down into them as you come over: it breaks their guard, and you land behind them."},
	"raijin_wheel": {"name": "Raijin's Wheel", "tree": "polearm", "cost": 0.0, "cooldown": 3.0, "styles": ["polearm"], "needs_text": "a polearm", "state": "Technique", "ult": true,
		"desc": "Ultimate. Leap up spinning the spear over your head into a wheel, come down in its middle cutting everyone around you on every turn, then drive the point into the ground: the wheel bursts and throws them all down."},
	"thunder_javelin": {"name": "Thunder Javelin", "tree": "polearm", "cost": 20.0, "cooldown": 7.0, "styles": ["polearm"], "needs_text": "a polearm", "state": "Technique",
		"desc": "Hurl the spear point-first where you aim, piercing everyone on a 16 m line and breaking their wind-ups; a beat later a crackle of lightning yanks it back to your hand, cutting the line again. With the storm awakened, a bolt drops on each one it pierced."},
	"windmill_guard": {"name": "Windmill Guard", "tree": "polearm", "cost": 18.0, "cooldown": 8.0, "styles": ["polearm"], "needs_text": "a polearm", "state": "Technique",
		"desc": "Hold to spin the pole before you like a windmill as you walk (up to 1.5 s): blows and shots from the front are batted aside, and anyone who steps in is clipped and shoved back out to the tip. Let go to lunge into a thrust that can't be blocked."},
	# --- Hammer ---
	"skullcracker": {"name": "Skullcracker", "tree": "hammer", "cost": 18.0, "cooldown": 6.0, "styles": ["hammer"], "needs_text": "a hammer", "state": "Technique",
		"desc": "A hop up with the hammer raised and the head brought straight down on the enemy in front: it goes through any guard, breaks their wind-up and leaves them reeling."},
	"rolling_quake": {"name": "Rolling Quake", "tree": "hammer", "cost": 22.0, "cooldown": 8.0, "styles": ["hammer"], "needs_text": "a hammer", "state": "Technique",
		"desc": "Three slams stepping forward, left, right and overhead, each a shockwave wider than the last; the third knocks everyone within four paces flat."},
	"cyclone_crusher": {"name": "Cyclone Crusher", "tree": "hammer", "cost": 24.0, "cooldown": 9.0, "styles": ["hammer"], "needs_text": "a hammer", "state": "Technique",
		"desc": "Let the hammer out at arm's length and spin three times, walking with it, battering everyone about you; the last turn ends in the ground with a shockwave."},
	"titans_fall": {"name": "Titan's Fall", "tree": "hammer", "cost": 0.0, "cooldown": 3.0, "styles": ["hammer"], "needs_text": "a hammer", "state": "Technique", "ult": true,
		"desc": "Ultimate. Leap high with the hammer heaved overhead and come down with the whole weight of it: the ground breaks in a great ring that throws everyone down, stone heaves up under them, and two aftershocks follow."},
	"cannonball_swing": {"name": "Cannonball Swing", "tree": "hammer", "cost": 20.0, "cooldown": 7.0, "styles": ["hammer"], "needs_text": "a hammer", "state": "Technique",
		"desc": "Take the hammer back high and drive it low and up through the enemy in front like a golf swing: it can't be blocked, a light foe is launched ten paces flying and everyone it comes down on is knocked flat. Anyone heavier, or a boss, is left reeling a long while."},
	"anvil_counter": {"name": "Anvil Counter", "tree": "hammer", "cost": 16.0, "cooldown": 6.0, "styles": ["hammer"], "needs_text": "a hammer", "state": "Technique",
		"desc": "Plant the head and brace on the haft for a second: the first blow rings off you like a hammer on an anvil and leaves them reeling, and you rip the head up into their chin, throwing them back with a shockwave at your feet. If nothing comes, you get half the energy back."},
	# --- Twin axes ---
	"gallows_hook": {"name": "Gallows Hook", "tree": "dual_axe", "cost": 16.0, "cooldown": 6.0, "styles": ["dual_axe"], "needs_text": "two axes", "state": "Technique",
		"desc": "Fling the left axe round the enemy you're facing (up to 7 m) and haul them in by the beard (too heavy to move, and you're hauled to them), then chop down through their guard: it can't be blocked and leaves them reeling."},
	"hewing_frenzy": {"name": "Hewing Frenzy", "tree": "dual_axe", "cost": 20.0, "cooldown": 7.0, "styles": ["dual_axe"], "needs_text": "two axes", "state": "Technique",
		"desc": "Eight chops trading hands as fast as you can swing them, walking in, then both axes crashed down crossed: everyone in front is knocked flat."},
	"axestorm": {"name": "Axestorm", "tree": "dual_axe", "cost": 24.0, "cooldown": 9.0, "styles": ["dual_axe"], "needs_text": "two axes", "state": "Technique",
		"desc": "Hook everyone close in, then whirl four times with both axes out, walking, cutting everyone about you, and finish with both crashed down crossed."},
	"fimbulwinter": {"name": "Fimbulwinter", "tree": "dual_axe", "cost": 0.0, "cooldown": 3.0, "styles": ["dual_axe"], "needs_text": "two axes", "state": "Technique", "ult": true,
		"desc": "Ultimate. A roar, every enemy close hooked in at once, three turns with both axes out, then up and both crashed into the ground: a great ring throws them all down, and with the frost, ice heaves up under every one of them."},
	"ravens_return": {"name": "Ravens' Return", "tree": "dual_axe", "cost": 22.0, "cooldown": 8.0, "styles": ["dual_axe"], "needs_text": "two axes", "state": "Technique",
		"desc": "Throw both axes at once: they fly out on two crossing arcs, left and right, ten paces ahead, cutting everyone in a wide cone, then curve back to your hands and cut them again on the way home. With the frost, ice chips burst off everyone they cut."},
	"raiders_haul": {"name": "Raider's Haul", "tree": "dual_axe", "cost": 20.0, "cooldown": 8.0, "styles": ["dual_axe"], "needs_text": "two axes", "state": "Technique",
		"desc": "Hook the enemy in front by the beard and swing them round you once at arm's length, battering everyone close flat, then fling them eight paces into whoever's behind. Too heavy to swing (a boss or a big brute), and you swing round them instead with three chops."},
	# --- Greatsword ---
	"guardbreaker": {"name": "Guardbreaker", "tree": "greatsword", "cost": 16.0, "cooldown": 6.0, "styles": ["greatsword"], "needs_text": "a greatsword", "state": "Technique",
		"desc": "Step in on the enemy you're facing with a short rising cut that knocks their guard up, then bring the blade straight down on them: neither can be blocked, and it leaves them reeling."},
	"crescent_gale": {"name": "Crescent Gale", "tree": "greatsword", "cost": 20.0, "cooldown": 7.0, "styles": ["greatsword"], "needs_text": "a greatsword", "state": "Technique",
		"desc": "One huge flat sweep that cuts everyone close in front and flings a crescent of air off the edge, ten paces down the line, cutting everything it passes."},
	"updraft": {"name": "Updraft", "tree": "greatsword", "cost": 22.0, "cooldown": 8.0, "styles": ["greatsword"], "needs_text": "a greatsword", "state": "Technique",
		"desc": "A rising cut that tears a gust up under the enemy in front and throws them high (a boss only reels). You ride the wind up after them and cleave them back down, landing in a crash that knocks everyone close flat."},
	"gatekeeper": {"name": "Gatekeeper", "tree": "greatsword", "cost": 18.0, "cooldown": 8.0, "styles": ["greatsword"], "needs_text": "a greatsword", "state": "Technique",
		"desc": "Hold to drive the blade point-down before you like a gate (up to 1.5 s): every blow and shot from the front stops on the flat. Let go to wrench it up out of the ground in a rising cut nothing blocks, flinging a crescent of air up the line."},
	"tempest_turns": {"name": "Tempest Turns", "tree": "greatsword", "cost": 24.0, "cooldown": 9.0, "styles": ["greatsword"], "needs_text": "a greatsword", "state": "Technique",
		"desc": "Let the blade carry you round three times, walking, each turn quicker than the last and cutting everyone about you, until the momentum breaks in a burst that throws them all down."},
	"skysplitter": {"name": "Skysplitter", "tree": "greatsword", "cost": 0.0, "cooldown": 3.0, "styles": ["greatsword"], "needs_text": "a greatsword", "state": "Technique", "ult": true,
		"desc": "Ultimate. Leap high with the blade heaved overhead and come down in one cleave: the ground splits in a line twelve paces long, everyone on it is thrown down, and three crescents of air tear on down the line."},
	# --- Black Leg ---
	"rising_heel": {"name": "Rising Heel", "tree": "black_leg", "cost": 16.0, "cooldown": 6.0, "styles": ["black_leg"], "needs_text": "black-leg kicks", "state": "Technique",
		"desc": "Sink low and swing your heel straight up under their chin: a light foe is launched into the air (a heavy one only once its guard is spent). Air-step after them to keep the combo going."},
	"hailstorm_heels": {"name": "Hailstorm Heels", "tree": "black_leg", "cost": 20.0, "cooldown": 7.0, "styles": ["black_leg"], "needs_text": "black-leg kicks", "state": "Technique",
		"desc": "Up on one foot, a hail of snapping kicks at every height into whoever's in front, walking in, and a last big one that knocks them flat."},
	"sky_chase": {"name": "Sky Chase", "tree": "black_leg", "cost": 18.0, "cooldown": 6.0, "styles": ["black_leg"], "needs_text": "black-leg kicks", "state": "Technique",
		"desc": "Stamp on the air up to a foe you've launched and kick it higher still, or hold forward to bring your heel down through it: it's spiked into the ground and you land after it in a ring that knocks everyone round you flat."},
	"cleaver_kick": {"name": "Cleaver Kick", "tree": "black_leg", "cost": 18.0, "cooldown": 7.0, "styles": ["black_leg"], "needs_text": "black-leg kicks", "state": "Technique",
		"desc": "A high crescent kick so fast it cuts the air: a blade of it shoots off your foot twelve paces down the line, cutting everyone it passes. With the heat awakened it flies red-hot and sets them burning."},
	"flambe_dash": {"name": "Flambe Dash", "tree": "black_leg", "cost": 22.0, "cooldown": 8.0, "styles": ["black_leg"], "needs_text": "black-leg kicks", "state": "Technique",
		"desc": "A hop as the leg heats, then a flying side kick that streaks five paces through the line, kicking everyone on it aside and off their feet. With the heat awakened it leaves a trail of crimson fire and them burning."},
	"last_course": {"name": "Last Course", "tree": "black_leg", "cost": 0.0, "cooldown": 3.0, "styles": ["black_leg"], "needs_text": "black-leg kicks", "state": "Technique", "ult": true,
		"desc": "Ultimate. Spin on one foot until your leg glows red-hot, then a storm of burning kicks through everyone in front, a leap, and the heel brought down: the ground bursts into a ring of crimson fire that throws them all down."},
	# --- Pistol ---
	"deadeye": {"name": "Deadeye", "tree": "pistol", "cost": 20.0, "cooldown": 7.0, "styles": ["pistol", "dual_pistol"], "needs_text": "a pistol", "state": "Technique",
		"desc": "A breath, a steady aim, and one shot that punches through every enemy in a line."},
	"smoke_bomb": {"name": "Smoke Bomb", "tree": "pistol", "cost": 18.0, "cooldown": 14.0, "styles": ["pistol", "dual_pistol"], "needs_text": "a pistol", "state": "Technique",
		"desc": "Throw down a smoke bomb: everyone close coughs and staggers, and you vanish from sight for 1.5 s."},
	"point_blank": {"name": "Point Blank", "tree": "pistol", "cost": 16.0, "cooldown": 5.0, "styles": ["pistol", "dual_pistol"], "needs_text": "a pistol", "state": "Technique",
		"desc": "Shove the barrel into the nearest enemy and fire: a blast that throws them off their feet."},
	"deaths_waltz": {"name": "Death's Waltz", "tree": "pistol", "cost": 0.0, "cooldown": 3.0, "styles": ["pistol", "dual_pistol"], "needs_text": "a pistol", "state": "Technique", "ult": true,
		"desc": "Ultimate. Turn through a deadly waltz, shooting every enemy within 18 m three times; the last shot knocks them down."},
	# --- Long guns ---
	"pin_shot": {"name": "Pinning Shot", "tree": "long_gun", "cost": 16.0, "cooldown": 7.0, "styles": ["long_gun"], "needs_text": "a long gun", "state": "Technique",
		"desc": "Drop to one knee and put a ball into the enemy in your sights: it can't be blocked, and it nails them where they stand for a few seconds."},
	"powder_burst": {"name": "Powder Burst", "tree": "long_gun", "cost": 20.0, "cooldown": 7.0, "styles": ["long_gun"], "needs_text": "a long gun", "state": "Technique",
		"desc": "A double charge fired from the hip: a cone of fire and shot throws everyone close in front off their feet, and the kick throws you back a step. It doesn't spend your load."},
	"volley_line": {"name": "Volley Line", "tree": "long_gun", "cost": 22.0, "cooldown": 8.0, "styles": ["long_gun"], "needs_text": "a long gun", "state": "Technique",
		"desc": "Three paper cartridges, loaded and fired as fast as you can bite them: a shot into each of up to three enemies ahead (the last knocks them down), and the gun's loaded again after."},
	"stock_sweep": {"name": "Stock Sweep", "tree": "long_gun", "cost": 16.0, "cooldown": 6.0, "styles": ["long_gun"], "needs_text": "a long gun", "state": "Technique",
		"desc": "Let the gun out at arm's length, butt first, and swing round once: everyone close is clubbed, then knocked flat."},
	"hawkeye": {"name": "Hawkeye", "tree": "long_gun", "cost": 0.0, "cooldown": 3.0, "styles": ["long_gun"], "needs_text": "a long gun", "state": "Technique", "ult": true,
		"desc": "Ultimate. Down on one knee, time slows while every enemy ahead (up to six) is marked; then a shot through each in turn, unblockable, knocking them all down. Nothing touches you until it's done."},
	# --- The cannon ---
	"canister_shot": {"name": "Canister Shot", "tree": "cannon", "cost": 18.0, "cooldown": 7.0, "styles": ["cannon"], "needs_text": "a cannon", "state": "Technique",
		"desc": "A canister of grape fired point-blank: a cone of a dozen balls that hurls everyone close in front back and off their feet. It doesn't spend your load."},
	"chain_shot": {"name": "Chain Shot", "tree": "cannon", "cost": 20.0, "cooldown": 7.0, "styles": ["cannon"], "needs_text": "a cannon", "state": "Technique",
		"desc": "Two balls on a chain, spinning down the line at the reticle: they cut through everyone on it, thirty paces, and leave them reeling."},
	"mortar_lob": {"name": "Mortar Lob", "tree": "cannon", "cost": 24.0, "cooldown": 9.0, "styles": ["cannon"], "needs_text": "a cannon", "state": "Technique",
		"desc": "Tip the cannon up and lob three shells high: they come down on the reticle and either side of it, each bursting and throwing everyone round it flat."},
	"rocket_charge": {"name": "Rocket Charge", "tree": "cannon", "cost": 20.0, "cooldown": 8.0, "styles": ["cannon"], "needs_text": "a cannon", "state": "Technique",
		"desc": "Turn the muzzle behind you and fire: the recoil hurls you ten paces forward, ramming everyone in your path off their feet."},
	"leviathan_shell": {"name": "Leviathan Shell", "tree": "cannon", "cost": 0.0, "cooldown": 3.0, "styles": ["cannon"], "needs_text": "a cannon", "state": "Technique", "ult": true,
		"desc": "Ultimate. Down on one knee, a breath, and one giant shell at the reticle: where it lands everything within eight paces is thrown down, unblockable, and the ground cracks open. Nothing touches you while you brace."},
	# --- The slingshot (its trick ammo) ---
	"fire_pellet": {"name": "Fire Pellet", "tree": "slingshot", "cost": 14.0, "cooldown": 6.0, "styles": ["slingshot"], "needs_text": "a slingshot", "state": "Technique",
		"desc": "A pellet packed with fire at the reticle: it bursts into flame where it lands, setting everyone close burning."},
	"smoke_pellet": {"name": "Smoke Pellet", "tree": "slingshot", "cost": 16.0, "cooldown": 9.0, "styles": ["slingshot"], "needs_text": "a slingshot", "state": "Technique",
		"desc": "A pellet of smoke at the reticle: a thick cloud where it lands blinds everyone in it for a couple of seconds, and if you're in it too, you slip out of sight."},
	"blast_pellet": {"name": "Blast Pellet", "tree": "slingshot", "cost": 18.0, "cooldown": 7.0, "styles": ["slingshot"], "needs_text": "a slingshot", "state": "Technique",
		"desc": "A pellet of black powder at the reticle: it goes off where it lands and throws everyone round it off their feet."},
	"sticky_pellet": {"name": "Sticky Pellet", "tree": "slingshot", "cost": 16.0, "cooldown": 8.0, "styles": ["slingshot"], "needs_text": "a slingshot", "state": "Technique",
		"desc": "A pellet of hot tar at the reticle: everyone in the splash is stuck where they stand for three seconds."},
	"bag_of_tricks": {"name": "Bag of Tricks", "tree": "slingshot", "cost": 0.0, "cooldown": 3.0, "styles": ["slingshot"], "needs_text": "a slingshot", "state": "Technique", "ult": true,
		"desc": "Ultimate. Empty the pouch: five trick pellets, one after another at the enemies ahead (fire, tar, powder, smoke and fire again), each half again as strong. Nothing touches you while you shoot."},
	# --- Unarmed: power ---
	"hip_toss": {"name": "Shoulder Throw", "tree": "unarmed", "cost": 16.0, "cooldown": 5.0, "styles": ["fist"], "needs_text": "empty hands", "state": "Technique",
		"desc": "Hands open to catch for a second: a blow caught in them is turned aside and whoever threw it goes over your shoulder, knocking down anyone they land on. A boss or a heavy gets a straight right back instead."},
	"cannonball_fist": {"name": "Cannonball Fist", "tree": "unarmed", "cost": 18.0, "cooldown": 6.0, "styles": ["fist"], "needs_text": "empty hands", "state": "Technique",
		"desc": "Plant your feet and drive a straight right through the enemy in front: they're launched down the line like a cannonball, bowling over everyone behind them."},
	"meteor_fist": {"name": "Meteor Fist", "tree": "unarmed", "cost": 24.0, "cooldown": 9.0, "styles": ["fist"], "needs_text": "empty hands", "state": "Technique",
		"desc": "A short hop and a burning overhand driven into the ground: the earth cracks and a shockwave knocks everyone around you flat. Used in the air you dive onto the ground instead, harder the further you fall."},
	# --- Unarmed: martial arts ---
	"hundred_fists": {"name": "Hundred Fists", "tree": "unarmed", "cost": 20.0, "cooldown": 7.0, "styles": ["fist"], "needs_text": "empty hands", "state": "Technique",
		"desc": "A blur of punches for a second, then a last straight that blows them away."},
	"rising_dragon": {"name": "Rising Dragon", "tree": "unarmed", "cost": 18.0, "cooldown": 6.0, "styles": ["fist"], "needs_text": "empty hands", "state": "Technique",
		"desc": "A leaping uppercut that launches you and everyone in front of you into the air."},
	"palm_strike": {"name": "Shockwave Palm", "tree": "unarmed", "cost": 16.0, "cooldown": 5.0, "styles": ["fist"], "needs_text": "empty hands", "state": "Technique",
		"desc": "Drive an open palm forward: a burst of air hurls everything in a cone in front of you."},
	"sea_king_fist": {"name": "Leviathan Fist", "tree": "unarmed", "cost": 0.0, "cooldown": 3.0, "styles": ["fist"], "needs_text": "empty hands", "state": "Technique", "ult": true,
		"desc": "Ultimate. Your fist takes the power and glows: for 8 s move as you like, then attack (or R) to let it go. On the ground a punch that tears 16 m ahead and blows up where it lands; in the air a dive onto the ground, harder the further you fall; right after a parry it hits the attacker first; out of a dash it carries your speed. Unused, it fades and half the ultimate comes back."},
	# --- (1.26, WeaponPlus) the second ultimates, run by PlusArts; "icon": another skill's picture until they have their own ---
	"undertow": {"name": "Undertow", "tree": "sword", "cost": 0.0, "cooldown": 3.0, "styles": ["sword"], "needs_text": "a cutlass", "state": "Technique", "ult": true, "icon": "kraken_wake",
		"desc": "Ultimate. Plant the blade: a whirlpool drags every foe within 8 m in to you, cut as they come; one rising cut flings them all up, and the sea comes down on every one of them."},
	"moonlit_severance": {"name": "Moonlit Severance", "tree": "katana", "cost": 0.0, "cooldown": 3.0, "styles": ["katana"], "needs_text": "a katana", "state": "Technique", "ult": true, "icon": "petal_storm",
		"desc": "Ultimate. Sheathe, a breath, and one draw along a 14 m line: the world goes pale, and a beat later everything on the line splits and falls. Nothing blocks it."},
	"volcano_course": {"name": "Volcano Course", "tree": "black_leg", "cost": 0.0, "cooldown": 3.0, "styles": ["black_leg"], "needs_text": "black-leg kicks", "state": "Technique", "ult": true, "icon": "last_course",
		"desc": "Ultimate. Stamp the ground five times: it erupts under up to five foes within 8 m and throws each one high, and you chase the last up with a burning heel that spikes it into the ground."},
	"golden_ricochet": {"name": "Golden Ricochet", "tree": "pistol", "cost": 0.0, "cooldown": 3.0, "styles": ["pistol", "dual_pistol"], "needs_text": "a pistol", "state": "Technique", "ult": true, "icon": "deaths_waltz",
		"desc": "Ultimate. Time slows; one gilded ball bounces between every foe within 16 m (up to eight), harder at every bounce, and ends in a gold burst that knocks them down."},
	"heavens_pike": {"name": "Heaven's Pike", "tree": "polearm", "cost": 0.0, "cooldown": 3.0, "styles": ["polearm"], "needs_text": "a polearm", "state": "Technique", "ult": true, "icon": "raijin_wheel",
		"desc": "Ultimate. Hurl the spear straight up: it comes down on the reticle as a bolt, and for a second a storm 6 m round it strikes everyone in it again and again, the last bolt throwing them down."},
	"eye_of_storm": {"name": "Eye of the Storm", "tree": "greatsword", "cost": 0.0, "cooldown": 3.0, "styles": ["greatsword"], "needs_text": "a greatsword", "state": "Technique", "ult": true, "icon": "skysplitter",
		"desc": "Ultimate. The blade held out at arm's length: a cyclone 7 m round you drags them in for two seconds, one full turn throws them all up, and a downdraft slams them into the ground."},
	"twin_comet": {"name": "Twin Comet", "tree": "dual", "cost": 0.0, "cooldown": 3.0, "styles": ["dual_sword"], "needs_text": "two blades", "state": "Technique", "ult": true, "icon": "steel_tempest",
		"desc": "Ultimate. A leap high with both blades crossed and a dive onto the foe you face: the ground bursts round you, an X of light tears ten paces on, and everyone close is struck again as it falls."},
	"executioners_moon": {"name": "Executioner's Moon", "tree": "axe", "cost": 0.0, "cooldown": 3.0, "styles": ["axe"], "needs_text": "an axe", "state": "Technique", "ult": true, "icon": "maelstrom",
		"desc": "Ultimate. A roar and a wind-up nothing interrupts, then one chop: a huge blow on the foe in front and a fissure of fire ten paces down the line. Nothing blocks it."},
	"blood_moon_mark": {"name": "Blood Moon Mark", "tree": "dagger", "cost": 0.0, "cooldown": 3.0, "styles": ["dagger"], "needs_text": "a dagger", "state": "Technique", "ult": true, "icon": "red_eclipse",
		"desc": "Ultimate. Out of the dark behind up to six foes within 12 m, one after another, each cut and bleeding; then every wound opens at once and they all fall."},
	"serpents_nest": {"name": "Serpent's Nest", "tree": "dual_dagger", "cost": 0.0, "cooldown": 3.0, "styles": ["dual_dagger"], "needs_text": "two daggers", "state": "Technique", "ult": true, "icon": "hundred_fangs",
		"desc": "Ultimate. Venom pools out 7 m round you; you dart between everyone in it eight times, then rip both blades out: they all fall, bleeding."},
	"mountain_breaker": {"name": "Mountain Breaker", "tree": "hammer", "cost": 0.0, "cooldown": 3.0, "styles": ["hammer"], "needs_text": "a hammer", "state": "Technique", "ult": true, "icon": "titans_fall",
		"desc": "Ultimate. Three slams walking forward, each a longer line of heaving stone; the last throws everything on it and round you into the air."},
	"avalanche": {"name": "Avalanche", "tree": "dual_axe", "cost": 0.0, "cooldown": 3.0, "styles": ["dual_axe"], "needs_text": "two axes", "state": "Technique", "ult": true, "icon": "fimbulwinter",
		"desc": "Ultimate. A roar and a leap; you crash down with both axes into a field of ice 6 m round you that freezes everyone in it, then shatters under them one by one."},
	"powder_trail": {"name": "Powder Trail", "tree": "corsair", "cost": 0.0, "cooldown": 3.0, "styles": ["sword_pistol"], "needs_text": "a cutlass and a pistol", "state": "Technique", "ult": true, "icon": "broadside",
		"desc": "Ultimate. A shot that pins each of up to six foes within 9 m, the powder laid round them as you go; then the ring goes up under all of them at once."},
	"constellation": {"name": "Constellation", "tree": "long_gun", "cost": 0.0, "cooldown": 3.0, "styles": ["long_gun"], "needs_text": "a long gun", "state": "Technique", "ult": true, "icon": "hawkeye",
		"desc": "Ultimate. Down on one knee, one shot straight up; it splits into stars that fall on up to eight foes within 20 m, each knocked flat. Nothing blocks them."},
	"hellfire_barrage": {"name": "Hellfire Barrage", "tree": "cannon", "cost": 0.0, "cooldown": 3.0, "styles": ["cannon"], "needs_text": "a cannon", "state": "Technique", "ult": true, "icon": "leviathan_shell",
		"desc": "Ultimate. Braced, five shells walked out from your feet down the line, each burst bigger than the last, everyone in them thrown down."},
	"fireworks_finale": {"name": "Fireworks Finale", "tree": "slingshot", "cost": 0.0, "cooldown": 3.0, "styles": ["slingshot"], "needs_text": "a slingshot", "state": "Technique", "ult": true, "icon": "bag_of_tricks",
		"desc": "Ultimate. A stone straight up bursts into a shower of sparks over everything within 10 m for two seconds, striking again and again; the last burst knocks them all down."},
	"typhoon_rush": {"name": "Typhoon Rush", "tree": "unarmed", "cost": 0.0, "cooldown": 3.0, "styles": ["fist"], "needs_text": "empty hands", "state": "Technique", "ult": true, "icon": "sea_king_fist",
		"desc": "Ultimate. Walk into them under a storm of fists in a ring of wind; the last throws them up, and both fists bring them down into the ground."},
	# --- Haki ---
	"conquerors_haki": {"name": "Captain's Will", "tree": "base", "cost": 0.0, "cooldown": 3.0, "state": "Technique", "ult": true,
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
	var path := ICON_DIR + "skill_" + str(get_skill(id).get("icon", id)) + ".png"
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
