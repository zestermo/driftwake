class_name WeaponPlus
extends RefCounted
## (1.26, docs/weapons_126.md) What each weapon tree gains on top of its branches: two ultimates (today's, and a second
## up the right of the split, each behind a lead-up node), a second crew technique (a variant switching which one C
## plays), three alternates (variants that come by themselves at ALT_LEVELS: the standard move or the alternate, for
## the aerial, the sprint attack and the right-click; PlusArts runs them) and four bridges between the branches (a stat
## and a passive each side of the middle; bought once you own a node they're linked to). SkillTrees._plus builds the
## nodes from TREES; a tree without an entry is as it was.
##
## TREES: tree -> {lead_a, lead_b: [id, name, effects], ult_b: [node id, skill], crew: crew technique id,
##   alts: [aerial, sprint, right-click] PlusArts move ids, bridges: [[id, name, effects] x4]: left/middle stat, its
##   passive, middle/right stat, its passive}

const ALT_SLOTS := ["air", "sprint", "heavy"]
const ALT_LEVELS := {"air": 8, "sprint": 14, "heavy": 20}
const ALT_NAMES := {"air": "Aerial", "sprint": "Sprint Attack", "heavy": "Right-Click"}
const ALT_STANDARD := {"air": "Your usual attack in the air (the tree's air move once learned, else the plunge).",
	"sprint": "Your usual attack at a sprint (the tree's sprint move once learned, else the combo's first blow).",
	"heavy": "Your usual right-click."}
## Where the split sits off the second element node (tree space): the lead-up, then the ultimate.
const LEAD_OFF := Vector2(76, -78)
const ULT_OFF := Vector2(104, -168)
## The bridges: [level, price], inner then outer.
const BRIDGE := [[6, 3], [15, 4]]
const LEAD_LEVEL := 26
const LEAD_PRICE := 3
const CREW_LEVEL := 12

## The aerial heavy (right-click in the air: the plunge until it's bought): its level.
const AIR_HEAVY_LEVEL := 10

## The second crew techniques (CrewTechniques.def): no styles (the tree's "Crew Technique" variant picks them), the tree
## whose colours they wear, a kind CrewTechniqueState plays from its DUETS ("setup", "combined", "support").
const CREW := {
	"crossed_cutlass": {"name": "Crossed Cutlasses", "styles": [], "tree": "sword", "kind": "combined", "solo": "Double Cross",
		"desc": "You and your crewmate cut across the foe ahead from opposite sides at once: an X bursts on everyone round it and throws them down.",
		"solo_desc": "Through the foe ahead and back again, a cut each way, and the X bursts."},
	"blade_sheath": {"name": "Blade and Sheath", "styles": [], "tree": "katana", "kind": "setup", "solo": "Sheath Strike",
		"desc": "The scabbard sweeps the legs of the foe ahead and pins it down; your crewmate is beside it in a blink with a drawing cut that can't be blocked.",
		"solo_desc": "The scabbard sweeps its legs, then your own drawing cut."},
	"double_course": {"name": "Double Course", "styles": [], "tree": "black_leg", "kind": "combined", "solo": "Scissor Kick",
		"desc": "You and your crewmate kick the foe ahead from opposite sides at once: an X of heat, and everyone round it is thrown up.",
		"solo_desc": "Both legs scissored through the foe ahead, and everyone round it thrown up."},
	"powder_share": {"name": "Powder Share", "styles": [], "tree": "pistol", "kind": "support", "solo": "Hot Reload",
		"desc": "Toss your crewmate a loaded pistol: you're both reloaded, they get 25 energy, and you both hit 20% harder for 8 s.",
		"solo_desc": "Reloaded at once, 12 energy, and 20% harder for 8 s."},
	"ground_pin": {"name": "Pinned", "styles": [], "tree": "polearm", "kind": "setup", "solo": "Ground Pin",
		"desc": "Sweep the foe ahead off its feet and pin it under the shaft; your crewmate vaults in and drives the finisher down like a thunderclap.",
		"solo_desc": "The sweep and the pin, then the point driven down yourself."},
	"lift_cleave": {"name": "Lift and Cleave", "styles": [], "tree": "greatsword", "kind": "setup", "solo": "Lift and Fall",
		"desc": "The flat lifts the foe ahead off its feet and holds it up; your crewmate leaps in and cleaves it back down into the ground.",
		"solo_desc": "The lift, then your own cleave down."},
	"blade_wall": {"name": "Blade Wall", "styles": [], "tree": "dual", "kind": "support", "solo": "Whirling Guard",
		"desc": "Four blades between you and the crowd: the next two blows on each of you, for 10 s, are turned aside.",
		"solo_desc": "Your blades whirl up: the next two blows on you, for 10 s, are turned aside."},
	"chopping_block": {"name": "Chopping Block", "styles": [], "tree": "axe", "kind": "setup", "solo": "Woodsman",
		"desc": "Hook the legs of the foe ahead out from under it and pin it down; your crewmate is over it in a blink with the chop.",
		"solo_desc": "The hook, then your own chop."},
	"smoke_mirrors": {"name": "Smoke and Mirrors", "styles": [], "tree": "dagger", "kind": "support", "solo": "Vanish",
		"desc": "A cloud of smoke round the two of you: you both slip out of sight for a moment, and each one's next blow is a sure crit.",
		"solo_desc": "You slip out of sight a moment, and your next blow is a sure crit."},
	"twin_viper": {"name": "Twin Viper", "styles": [], "tree": "dual_dagger", "kind": "combined", "solo": "Viper Spiral",
		"desc": "You and your crewmate strike the foe ahead from opposite sides like a pair of snakes, and a crossed rip opens everyone round it, bleeding.",
		"solo_desc": "A strike from each side of the foe ahead, and the crossed rip."},
	"hammer_anvil": {"name": "Hammer and Anvil", "styles": [], "tree": "hammer", "kind": "combined", "solo": "Anvil Strike",
		"desc": "You and your crewmate strike the foe ahead from opposite sides at once: everyone round it is thrown flat by the clang.",
		"solo_desc": "A blow from each side of the foe ahead, and the clang."},
	"hook_hew": {"name": "Hook and Hew", "styles": [], "tree": "dual_axe", "kind": "setup", "solo": "Hew",
		"desc": "Both beards hook the legs of the foe ahead and pin it down; your crewmate is over it in a blink and hews it.",
		"solo_desc": "The hook, then your own hew."},
	"steady_bind": {"name": "Hold Them Steady", "styles": [], "tree": "corsair", "kind": "setup", "solo": "Bind and Fire",
		"desc": "Your blade binds the foe ahead and pins it; your crewmate is beside it in a blink and puts a shot into it point-blank.",
		"solo_desc": "The bind, then your own shot point-blank."},
	"pin_shoot": {"name": "Pin and Shoot", "styles": [], "tree": "long_gun", "kind": "setup", "solo": "Nail",
		"desc": "Nail the foe ahead's foot to the ground; your crewmate, wherever they stand, puts the finisher into it.",
		"solo_desc": "The foot nailed, then your own finisher."},
	"double_barrel": {"name": "Double Barrel", "styles": [], "tree": "cannon", "kind": "combined", "solo": "Double Charge",
		"desc": "You and your crewmate fire on the same foe at once, wherever you stand: one merged blast twice the size throws everyone round it down.",
		"solo_desc": "Two shells as fast as you can load them, and the blast."},
	"pouch_pass": {"name": "Pouch Pass", "styles": [], "tree": "slingshot", "kind": "support", "solo": "Sleight",
		"desc": "Toss your crewmate a handful of trick pellets: you both get energy (they 25, you 10) and hit 20% harder for 8 s.",
		"solo_desc": "12 energy, and 20% harder for 8 s."},
	"hold_down": {"name": "Hold Him Down", "styles": [], "tree": "unarmed", "kind": "setup", "solo": "Suplex",
		"desc": "Grab the foe ahead and hold it in a full nelson; your crewmate is in front of it in a blink with the biggest punch they have.",
		"solo_desc": "The grab, then a throw over your head into the ground."},
}

## Each tree's first (1.24) crew technique, as its variant's first version shows it: [name, text].
const CREW_FIRST := {
	"sword": ["Crossed Blades", "Brace your blade at shoulder height: your crewmate vaults off it into a leaping slash."],
	"katana": ["Guardian Stance", "Stand guard over a crewmate for 8 s: whoever strikes them eats your iai counter."],
	"black_leg": ["Skyward Kick", "Your crewmate steps onto your raised foot and you kick them high along your aim; they come down with a free plunge."],
	"pistol": ["Covering Fire", "Pin down the foes ahead with a volley: crewmates in the fight take less damage and reload faster."],
	"polearm": ["Pole Vault", "Plant the polearm: your crewmate runs up it and vaults far (gaps, ledges, onto a boss)."],
	"greatsword": ["Shield Wall", "Raise the flat as a wall for 8 s: shots from the front stop at it, and a crewmate behind it takes less from blows."],
	"dual": ["Crossed Blades", "Brace your blades at shoulder height: your crewmate vaults off them into a leaping slash."],
	"axe": ["Hurl", "Swing your crewmate round by the arm and throw them into the crowd: they land in a ground slam."],
	"dagger": ["Pincer", "Mark a foe: your crewmate's next hit on it and yours strike together for a crit."],
	"dual_dagger": ["Pincer", "Mark a foe: your crewmate's next hit on it and yours strike together for a crit."],
	"hammer": ["Anvil", "Swing low: your crewmate stands on the head and is batted skyward."],
	"dual_axe": ["Hurl", "Swing your crewmate round by the arm and throw them into the crowd: they land in a ground slam."],
	"corsair": ["Covering Fire", "Pin down the foes ahead with a volley: crewmates in the fight take less damage and reload faster."],
	"long_gun": ["Covering Fire", "Pin down the foes ahead with a volley: crewmates in the fight take less damage and reload faster."],
	"cannon": ["Cannon Ride", "Your crewmate climbs onto the barrel and you fire: they ride the blast far along your aim and land in a slam."],
	"slingshot": ["Sling Launch", "Plant the fork and draw the band right back with your crewmate in the pouch: they're flung high over everything ahead."],
	"unarmed": ["Human Cannonball", "Cup your hands: your crewmate launches from your grip, short and fast, through anything in the way."],
}

const TREES := {
	"sword": {
		"lead_a": ["s_call", "Kraken's Call", {"ult_charge_pct": 0.1}],
		"lead_b": ["s_deep", "Deep Current", {"skill_sword": 0.08}],
		"ult_b": ["s_undertow", "undertow"],
		"crew": "crossed_cutlass",
		"alts": ["anchor_drop", "boarding_hook", "broadside_sweep"], "air_heavy": "whirlpool_descent",
		"bridges": [["s_legs", "Sea Legs", {"def_sword": 3.0, "parry_sword": 0.03}],
			["s_current", "Counter-current", {"parry_sword": 0.04, "skill_sword": 0.06}],
			["s_salt", "Salt Edge", {"skill_sword": 0.06}],
			["s_seas", "High Seas", {"flow_sword": 0.2, "cdr_sword": 0.1}]],
	},
	"katana": {
		"lead_a": ["k_still", "Still Water", {"ult_charge_pct": 0.1}],
		"lead_b": ["k_breath", "Long Breath", {"skill_katana": 0.08}],
		"ult_b": ["k_moonlit", "moonlit_severance"],
		"crew": "blade_sheath",
		"alts": ["heron_dive", "wind_step", "mirror_draw"], "air_heavy": "blossom_cleave",
		"bridges": [["k_grip", "Settled Grip", {"def_katana": 3.0, "parry_katana": 0.03}],
			["k_water", "Clear Water", {"skill_katana": 0.06, "heavy_katana": 0.06}],
			["k_honed", "Honed", {"skill_katana": 0.06}],
			["k_drawn", "Drawn Breath", {"flow_katana": 0.2, "cdr_katana": 0.1}]],
	},
	"black_leg": {
		"lead_a": ["bl_mise", "Mise en Place", {"ult_charge_pct": 0.1}],
		"lead_b": ["bl_stove", "Hot Stove", {"skill_black_leg": 0.08}],
		"ult_b": ["bl_volcano", "volcano_course"],
		"crew": "double_course",
		"alts": ["meteor_heel", "sliding_shank", "flambe_lift"], "air_heavy": "comet_heels",
		"bridges": [["bl_callous", "Calloused", {"def_black_leg": 3.0, "parry_black_leg": 0.03}],
			["bl_simmer", "Simmer", {"skill_black_leg": 0.06, "parry_black_leg": 0.04}],
			["bl_pace", "Searing Pace", {"skill_black_leg": 0.06}],
			["bl_service", "Service", {"flow_black_leg": 0.2, "cdr_black_leg": 0.1}]],
	},
	"pistol": {
		"lead_a": ["g_card", "Dance Card", {"ult_charge_pct": 0.1}],
		"lead_b": ["g_gilt", "Gilt Rounds", {"skill_pistol": 0.08}],
		"ult_b": ["g_golden", "golden_ricochet"],
		"crew": "powder_share",
		"alts": ["spiral_shot", "slide_shot", "barrel_lift"], "air_heavy": "downward_volley",
		"bridges": [["g_hands", "Quick Hands", {"reload_pct": 0.08, "def_pistol": 3.0}],
			["g_show", "Showman", {"skill_pistol": 0.06, "flow_pistol": 0.2}],
			["g_wrist", "Steady Wrist", {"skill_pistol": 0.06}],
			["g_call", "Close Call", {"pointblank_pct": 0.12, "cdr_pistol": 0.1}]],
	},
	"polearm": {
		"lead_a": ["pl_gather", "Gathering Storm", {"ult_charge_pct": 0.1}],
		"lead_b": ["pl_rod", "Lightning Rod", {"skill_polearm": 0.08}],
		"ult_b": ["pl_pike", "heavens_pike"],
		"crew": "ground_pin",
		"alts": ["spinning_descent", "skyward_pike", "halberd_hook"], "air_heavy": "thunder_spike",
		"bridges": [["pl_shaft2", "Iron Shaft", {"def_polearm": 3.0, "parry_polearm": 0.03}],
			["pl_static", "Static", {"skill_polearm": 0.06, "parry_polearm": 0.04}],
			["pl_arm", "Long Arm", {"skill_polearm": 0.06}],
			["pl_head", "Thunderhead", {"flow_polearm": 0.2, "cdr_polearm": 0.1}]],
	},
	"greatsword": {
		"lead_a": ["gs_rising", "Rising Gale", {"ult_charge_pct": 0.1}],
		"lead_b": ["gs_front", "Stormfront", {"skill_greatsword": 0.08}],
		"ult_b": ["gs_eye", "eye_of_storm"],
		"crew": "lift_cleave",
		"alts": ["gale_glide", "wind_shear", "whirlwind_draw"], "air_heavy": "heavens_cleave",
		"bridges": [["gs_back", "Broad Back", {"def_greatsword": 3.0, "parry_greatsword": 0.03}],
			["gs_weather", "Weathered", {"skill_greatsword": 0.06, "def_greatsword": 3.0}],
			["gs_heft2", "Heft of Wind", {"skill_greatsword": 0.06}],
			["gs_breath", "Second Breath", {"flow_greatsword": 0.2, "cdr_greatsword": 0.1}]],
	},
	"dual": {
		"lead_a": ["d_eye", "Eye of Steel", {"ult_charge_pct": 0.1}],
		"lead_b": ["d_comet", "Comet Tail", {"skill_dual": 0.08}],
		"ult_b": ["d_twin_comet", "twin_comet"],
		"crew": "blade_wall",
		"alts": ["falling_scissors", "twin_rush", "rising_twins"], "air_heavy": "twin_meteor",
		"bridges": [["d_paired", "Paired Guard", {"def_dual": 3.0, "parry_dual": 0.03}],
			["d_undertow", "Undertow Step", {"skill_dual": 0.06, "parry_dual": 0.04}],
			["d_cross2", "Crossing Edge II", {"skill_dual": 0.06}],
			["d_breath", "Dancer's Breath", {"flow_dual": 0.2, "cdr_dual": 0.1}]],
	},
	"axe": {
		"lead_a": ["a_storm", "Whirl's Eye",{"ult_charge_pct": 0.1}],
		"lead_b": ["a_headsman", "Headsman", {"skill_axe": 0.08}],
		"ult_b": ["a_moon", "executioners_moon"],
		"crew": "chopping_block",
		"alts": ["woodsmans_drop", "shoulder_charge", "uppercut_hew"], "air_heavy": "splitting_maul",
		"bridges": [["a_neck", "Thick Neck", {"def_axe": 3.0, "heavy_axe": 0.06}],
			["a_stoked", "Stoked", {"skill_axe": 0.06, "def_axe": 3.0}],
			["a_hot", "Hot Edge", {"skill_axe": 0.06}],
			["a_warm", "Bloodwarm", {"flow_axe": 0.2, "cdr_axe": 0.1}]],
	},
	"dagger": {
		"lead_a": ["dg_eclipse_call", "Darkening", {"ult_charge_pct": 0.1}],
		"lead_b": ["dg_moon", "Red Moonrise", {"skill_dagger": 0.08}],
		"ult_b": ["dg_blood_moon", "blood_moon_mark"],
		"crew": "smoke_mirrors",
		"alts": ["shadow_drop", "hamstring", "throat_flip"], "air_heavy": "shadow_fall",
		"bridges": [["dg_light", "Light Step", {"def_dagger": 3.0, "crit_dagger": 0.03}],
			["dg_ghost", "Ghost Cut", {"skill_dagger": 0.06, "crit_dagger": 0.04}],
			["dg_thread", "Red Thread", {"skill_dagger": 0.06}],
			["dg_night", "Night Breath", {"flow_dagger": 0.2, "cdr_dagger": 0.1}]],
	},
	"dual_dagger": {
		"lead_a": ["dd_fangs_call", "Bared Fangs", {"ult_charge_pct": 0.1}],
		"lead_b": ["dd_nest", "Nesting", {"skill_dual_dagger": 0.08}],
		"ult_b": ["dd_serpents", "serpents_nest"],
		"crew": "twin_viper",
		"alts": ["coiled_strike", "snake_slide", "fang_lift"], "air_heavy": "viper_dive",
		"bridges": [["dd_supple", "Supple", {"def_dual_dagger": 3.0, "crit_dual_dagger": 0.03}],
			["dd_coil", "Coil", {"skill_dual_dagger": 0.06, "crit_dual_dagger": 0.04}],
			["dd_venom", "Venom Edge", {"skill_dual_dagger": 0.06}],
			["dd_cold", "Cold Blood", {"flow_dual_dagger": 0.2, "cdr_dual_dagger": 0.1}]],
	},
	"hammer": {
		"lead_a": ["hm_titan_call", "Titan's Breath", {"ult_charge_pct": 0.1}],
		"lead_b": ["hm_mountain", "Mountain Root", {"skill_hammer": 0.08}],
		"ult_b": ["hm_breaker", "mountain_breaker"],
		"crew": "hammer_anvil",
		"alts": ["pendulum_drop", "battering_ram", "upheaval"], "air_heavy": "meteor_hammer",
		"bridges": [["hm_stone", "Stone Hide", {"def_hammer": 3.0, "heavy_hammer": 0.06}],
			["hm_bedrock", "Bedrock", {"skill_hammer": 0.06, "def_hammer": 3.0}],
			["hm_rolling", "Rolling Weight", {"skill_hammer": 0.06}],
			["hm_swell", "Groundswell", {"flow_hammer": 0.2, "cdr_hammer": 0.1}]],
	},
	"dual_axe": {
		"lead_a": ["dx_winter_call", "Long Winter", {"ult_charge_pct": 0.1}],
		"lead_b": ["dx_slide", "Snowslide", {"skill_dual_axe": 0.08}],
		"ult_b": ["dx_avalanche", "avalanche"],
		"crew": "hook_hew",
		"alts": ["frost_fall", "reavers_sweep", "rising_hooks"], "air_heavy": "glacier_drop",
		"bridges": [["dx_coat", "Winter Coat", {"def_dual_axe": 3.0, "heavy_dual_axe": 0.06}],
			["dx_numb", "Numb", {"skill_dual_axe": 0.06, "def_dual_axe": 3.0}],
			["dx_ice", "Black Ice", {"skill_dual_axe": 0.06}],
			["dx_fury", "Cold Fury", {"flow_dual_axe": 0.2, "cdr_dual_axe": 0.1}]],
	},
	"corsair": {
		"lead_a": ["cs_call", "All Hands", {"ult_charge_pct": 0.1}],
		"lead_b": ["cs_trail", "Long Fuse", {"skill_corsair": 0.08}],
		"ult_b": ["cs_powder_trail", "powder_trail"],
		"crew": "steady_bind",
		"alts": ["powder_leap", "boarding_rush", "rising_shot"], "air_heavy": "broadside_drop",
		"bridges": [["cs_gunwale", "Gunwale", {"def_corsair": 3.0, "parry_corsair": 0.03}],
			["cs_swagger", "Swagger", {"skill_corsair": 0.06, "parry_corsair": 0.04}],
			["cs_edge", "Powder Edge", {"skill_corsair": 0.06}],
			["cs_prize", "Prize Money", {"flow_corsair": 0.2, "cdr_corsair": 0.1}]],
	},
	"long_gun": {
		"lead_a": ["lg_hawk_call", "Hawk's Patience", {"ult_charge_pct": 0.1}],
		"lead_b": ["lg_stars", "Star Chart", {"skill_long_gun": 0.08}],
		"ult_b": ["lg_constellation", "constellation"],
		"crew": "pin_shoot",
		"alts": ["scatter_down", "bayonet_rush", "butt_lift"], "air_heavy": "starfall_volley",
		"bridges": [["lg_shoulder", "Shoulder Strap", {"def_long_gun": 3.0, "heavy_long_gun": 0.06}],
			["lg_calm", "Calm", {"skill_long_gun": 0.06, "def_long_gun": 3.0}],
			["lg_polaris", "Polaris", {"skill_long_gun": 0.06}],
			["lg_watch", "Night Watch", {"flow_long_gun": 0.2, "cdr_long_gun": 0.1}]],
	},
	"cannon": {
		"lead_a": ["cn_levi_call", "Deep Charge", {"ult_charge_pct": 0.1}],
		"lead_b": ["cn_hellfire", "Hellfire Rack", {"skill_cannon": 0.08}],
		"ult_b": ["cn_barrage", "hellfire_barrage"],
		"crew": "double_barrel",
		"alts": ["shell_drop", "ram_and_fire", "barrel_upswing"], "air_heavy": "bombard_drop",
		"bridges": [["cn_shoulders", "Iron Shoulders", {"def_cannon": 3.0, "heavy_cannon": 0.06}],
			["cn_keg", "Powder Keg", {"skill_cannon": 0.06, "def_cannon": 3.0}],
			["cn_hot", "Hot Barrel", {"skill_cannon": 0.06}],
			["cn_sulphur", "Sulphur", {"flow_cannon": 0.2, "cdr_cannon": 0.1}]],
	},
	"slingshot": {
		"lead_a": ["sl_bag_call", "Deep Pockets", {"ult_charge_pct": 0.1}],
		"lead_b": ["sl_fuse", "Long Fuses", {"skill_slingshot": 0.08}],
		"ult_b": ["sl_fireworks", "fireworks_finale"],
		"crew": "pouch_pass",
		"alts": ["bounce_shot", "skid_spin", "kick_up"], "air_heavy": "spark_shower",
		"bridges": [["sl_fingers", "Nimble Fingers", {"def_slingshot": 3.0, "heavy_slingshot": 0.06}],
			["sl_luck", "Prankster's Luck", {"skill_slingshot": 0.06, "crit_slingshot": 0.04}],
			["sl_spark", "Spark", {"skill_slingshot": 0.06}],
			["sl_streak", "Wild Streak", {"flow_slingshot": 0.2, "cdr_slingshot": 0.1}]],
	},
	"unarmed": {
		"lead_a": ["u_tide", "Rising Tide", {"ult_charge_pct": 0.1}],
		"lead_b": ["u_typhoon", "Eye of the Typhoon", {"skill_unarmed": 0.08}],
		"ult_b": ["u_typhoon_rush", "typhoon_rush"],
		"crew": "hold_down",
		"alts": ["spinning_backfist", "flying_knee", "dragon_uppercut"], "air_heavy": "hammer_fists",
		"bridges": [["u_jaw", "Iron Jaw", {"def_unarmed": 3.0, "parry_unarmed": 0.03}],
			["u_breath2", "Breath Control", {"skill_unarmed": 0.06, "parry_unarmed": 0.04}],
			["u_hands2", "Heavy Hands II", {"skill_unarmed": 0.06}],
			["u_wind", "Wind in the Fists", {"flow_unarmed": 0.2, "cdr_unarmed": 0.1}]],
	},
}


static func has(tree: String) -> bool:
	return TREES.has(tree)


## The PlusArts move a tree's alternate is for `slot` ("air", "sprint", "heavy"); "" if it has none.
static func alt_id(tree: String, slot: String) -> String:
	if not TREES.has(tree):
		return ""
	return str(TREES[tree]["alts"][ALT_SLOTS.find(slot)])


## A tree's aerial heavy (PlusArts move id) and the key its node sets.
static func air_heavy(tree: String) -> String:
	return str(TREES.get(tree, {}).get("air_heavy", ""))


static func air_heavy_key(tree: String) -> String:
	return "airheavy_" + tree


## The effect key that switches a tree's alternate on (its variant's second version).
static func alt_key(tree: String, slot: String) -> String:
	return "alt_%s_%s" % [slot, tree]


## The second crew technique of a weapon tree ("" for none).
static func crew_of(tree: String) -> String:
	return str(TREES.get(tree, {}).get("crew", ""))


## A node's text from its effects (bridges and lead-ups: stat nodes).
static func describe(effects: Dictionary, tree: String) -> String:
	var w := str(SkillTrees.HEADERS[tree][0]).to_lower()
	var parts: Array = []
	for k in effects.keys():
		var v := float(effects[k])
		var pct := roundi(v * 100.0)
		var pre := str(k).trim_suffix("_" + tree)
		match pre:
			"dmg":
				parts.append("+%d%% %s damage" % [pct, w])
			"skill":
				parts.append("%s techniques hit %d%% harder" % [w, pct])
			"def":
				parts.append("+%d defense with it in hand" % roundi(v))
			"parry":
				parts.append("a wider parry window")
			"crit":
				parts.append("%d%% more of your hits land 50%% harder" % pct)
			"flow":
				parts.append("%s hits give %d%% more energy" % [w, pct])
			"cdr":
				parts.append("%s techniques come back %d%% sooner" % [w, pct])
			"heavy":
				parts.append("your right-click hits %d%% harder" % pct)
			"ult_charge_pct":
				parts.append("your ultimate charges %d%% faster" % pct)
			"reload_pct":
				parts.append("you reload %d%% faster" % pct)
			"pointblank_pct":
				parts.append("shots from within 5 m hit %d%% harder" % pct)
			_:
				push_error("WeaponPlus.describe: no words for " + str(k))
	var s := ", ".join(parts.slice(0, -1)) + (" and " if parts.size() > 1 else "") + str(parts[-1])
	return s.substr(0, 1).to_upper() + s.substr(1) + "."
