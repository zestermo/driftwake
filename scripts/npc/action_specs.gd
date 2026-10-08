class_name ActionSpecs
## Every Humanoid action in one table: the length its caller plays it at ("len", s), the
## strike window as fractions of the action ("hit", u) and how to preview it (stance,
## weapon, extras for tools/dev/animsheet.gd). Light and heavy attacks take their lengths
## and hitbox timing from here, so a pose and its hitbox can't drift apart.
## "hold": played with Humanoid.hold (len = the blend in). "react": played with
## Humanoid.react (preview "push" = which way the blow shoves the body, local).
## extras: "dual" (same weapon in the off hand), "beast", "sheathed", any Humanoid property;
## "variants" = more extras dicts, each rendered as another row.

const SPECS := {
	# --- cutlass ---
	"draw": {"len": 0.35, "stance": "sword", "weapon": "cutlass", "extras": {"sheathed": true}},
	"sheathe": {"len": 0.4, "stance": "sword", "weapon": "cutlass"},
	"slash_r": {"len": 0.48, "hit": [0.23, 0.44], "stance": "sword", "weapon": "cutlass"},
	"slash_l": {"len": 0.48, "hit": [0.21, 0.42], "stance": "sword", "weapon": "cutlass"},
	"spin_slash": {"len": 0.62, "hit": [0.21, 0.68], "stance": "sword", "weapon": "cutlass"},
	"dash_cut": {"len": 0.62, "hit": [0.27, 0.48], "stance": "sword", "weapon": "cutlass"},
	"thrust": {"len": 0.75, "hit": [0.29, 0.53], "stance": "sword", "weapon": "cutlass"},
	"flying_slash": {"len": 0.5, "stance": "sword", "weapon": "cutlass"},
	"heavy": {"len": 0.8, "hit": [0.375, 0.625], "stance": "sword", "weapon": "cutlass"},
	"parry": {"len": 0.66, "stance": "sword", "weapon": "cutlass"},
	"guard_block": {"len": 0.24, "hold": true, "stance": "sword", "weapon": "cutlass"},
	"guard_block_hit": {"len": 0.2, "stance": "sword", "weapon": "cutlass"},
	"plunge_air": {"len": 0.6, "stance": "sword", "weapon": "cutlass"},
	"plunge_land": {"len": 0.48, "stance": "sword", "weapon": "cutlass"},
	"climb_chop": {"len": 0.5, "stance": "sword", "weapon": "cutlass"},
	# --- katana ---
	"katana_r": {"len": 0.85, "hit": [0.39, 0.55], "stance": "katana", "weapon": "katana"},
	"katana_l": {"len": 0.85, "hit": [0.39, 0.55], "stance": "katana", "weapon": "katana"},
	"katana_stab": {"len": 0.9, "hit": [0.4, 0.56], "stance": "katana", "weapon": "katana"},
	"quick_draw": {"len": 1.3, "hit": [0.04, 0.15], "stance": "katana", "weapon": "katana"},
	"iai_ready": {"len": 0.3, "hold": true, "stance": "katana", "weapon": "katana"},
	"iai_slash": {"len": 0.6, "stance": "katana", "weapon": "katana"},
	"air_slash": {"len": 0.6, "stance": "katana", "weapon": "katana"},
	# --- axe ---
	"axe_hack": {"len": 0.62, "hit": [0.39, 0.56], "stance": "axe", "weapon": "axe"},
	"axe_hook": {"len": 0.62, "hit": [0.35, 0.53], "stance": "axe", "weapon": "axe"},
	"axe_split": {"len": 0.9, "hit": [0.42, 0.6], "stance": "axe", "weapon": "axe"},
	"axe_whirl": {"len": 1.24, "hit": [0.18, 0.76], "stance": "axe", "weapon": "axe"},
	"axe_flip": {"len": 0.58, "stance": "axe", "weapon": "axe"},
	"axe_land": {"len": 0.53, "stance": "axe", "weapon": "axe"},
	# --- dual swords ---
	"dual_1": {"len": 0.4, "hit": [0.25, 0.55], "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"dual_2": {"len": 0.4, "hit": [0.25, 0.55], "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"dual_cross": {"len": 0.5, "hit": [0.34, 0.58], "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"dual_spin": {"len": 0.6, "hit": [0.17, 0.7], "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"dual_heavy": {"len": 0.88, "hit": [0.36, 0.57], "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	# --- unarmed ---
	"fists_up": {"len": 0.25, "stance": "fist", "weapon": ""},
	"jab": {"len": 0.34, "hit": [0.21, 0.5], "stance": "fist", "weapon": ""},
	"cross": {"len": 0.36, "hit": [0.22, 0.5], "stance": "fist", "weapon": ""},
	"hook": {"len": 0.42, "hit": [0.29, 0.57], "stance": "fist", "weapon": ""},
	"roundhouse": {"len": 0.56, "hit": [0.34, 0.59], "stance": "fist", "weapon": ""},
	"flying_kick": {"len": 0.85, "hit": [0.39, 0.65], "stance": "fist", "weapon": ""},
	# --- pistols ---
	"shoot_r": {"len": 0.6, "stance": "pistol", "weapon": "pistol"},
	"pistol_whip": {"len": 0.62, "hit": [0.32, 0.52], "stance": "pistol", "weapon": "pistol"},
	"reload": {"len": 1.0, "stance": "pistol", "weapon": "pistol"},
	"bullet_storm": {"len": 0.75, "stance": "pistol", "weapon": "pistol"},
	"shoot_l": {"len": 0.6, "stance": "dual_pistol", "weapon": "pistol", "extras": {"dual": true}},
	"gun_kata": {"len": 0.82, "hit": [0.15, 0.76], "stance": "dual_pistol", "weapon": "pistol", "extras": {"dual": true}},
	"gun_rain": {"len": 0.6, "stance": "dual_pistol", "weapon": "pistol", "extras": {"dual": true}},
	# --- Zoan hybrid ---
	"claw_r": {"len": 0.44, "hit": [0.27, 0.59], "stance": "claw", "weapon": "", "extras": {"beast": true}},
	"claw_l": {"len": 0.44, "hit": [0.27, 0.59], "stance": "claw", "weapon": "", "extras": {"beast": true}},
	"claw_double": {"len": 0.62, "hit": [0.32, 0.58], "stance": "claw", "weapon": "", "extras": {"beast": true}},
	"rending_fang": {"len": 0.6, "stance": "claw", "weapon": "", "extras": {"beast": true}},
	"maul": {"len": 0.82, "hit": [0.37, 0.61], "stance": "claw", "weapon": "", "extras": {"beast": true}},
	"pounce": {"len": 1.0, "stance": "claw", "weapon": "", "extras": {"beast": true}},
	"howl": {"len": 0.9, "stance": "claw", "weapon": "", "extras": {"beast": true}},
	# --- fruit, body and Haki skills ---
	"fire_punch": {"len": 0.45, "stance": "fist", "weapon": ""},
	"flame_dash": {"len": 0.5, "stance": "fist", "weapon": ""},
	"fire_ring": {"len": 0.6, "stance": "fist", "weapon": ""},
	"fire_plant": {"len": 0.55, "stance": "fist", "weapon": ""},
	"inferno": {"len": 1.15, "stance": "fist", "weapon": ""},
	"soru": {"len": 0.24, "stance": "fist", "weapon": ""},
	"tekkai": {"len": 3.0, "stance": "fist", "weapon": ""},
	"coat": {"len": 0.45, "stance": "fist", "weapon": ""},
	"foresight": {"len": 0.4, "stance": "fist", "weapon": ""},
	"vine_throw": {"len": 0.45, "stance": "fist", "weapon": ""},
	"thorn_whip": {"len": 0.55, "stance": "fist", "weapon": ""},
	"vine_pull": {"len": 0.55, "stance": "fist", "weapon": ""},
	"vine_zip": {"len": 1.9, "stance": "fist", "weapon": ""},
	"vine_hang": {"len": 0.2, "hold": true, "stance": "fist", "weapon": ""},
	"vine_release": {"len": 0.75, "stance": "fist", "weapon": ""},
	"vine_shoot": {"len": 0.5, "stance": "fist", "weapon": ""},
	# --- weapon techniques (TechniqueState; poses in technique_poses.gd). "hit" marks
	# the moment the state strikes, for the animsheet bar ---
	"deflect": {"len": 0.35, "stance": "sword", "weapon": "cutlass"},
	"riposte_guard": {"len": 1.0, "stance": "sword", "weapon": "cutlass"},
	"riposte_cut": {"len": 0.5, "hit": [0.16, 0.34], "stance": "sword", "weapon": "cutlass"},
	"swordfish": {"len": 0.95, "hit": [0.1, 0.7], "stance": "sword", "weapon": "cutlass"},
	"kraken_cut": {"len": 1.6, "hit": [0.6, 0.7], "stance": "sword", "weapon": "cutlass"},
	"wind_sever": {"len": 0.75, "hit": [0.38, 0.46], "stance": "katana", "weapon": "katana"},
	"phantom_cut": {"len": 0.6, "hit": [0.24, 0.32], "stance": "katana", "weapon": "katana"},
	"petal_storm": {"len": 1.6, "hit": [0.66, 0.72], "stance": "katana", "weapon": "katana"},
	"axe_throw": {"len": 0.6, "hit": [0.38, 0.44], "stance": "axe", "weapon": "axe"},
	"earthsplitter": {"len": 0.95, "hit": [0.45, 0.52], "stance": "axe", "weapon": "axe"},
	"berserk_roar": {"len": 0.75, "stance": "axe", "weapon": "axe"},
	"maelstrom": {"len": 3.0, "hit": [0.05, 0.95], "stance": "axe", "weapon": "axe"},
	"cross_guard": {"len": 1.0, "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"blade_dance": {"len": 1.0, "hit": [0.1, 0.88], "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"cross_fang": {"len": 0.85, "hit": [0.44, 0.52], "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"steel_tempest": {"len": 2.2, "hit": [0.07, 0.9], "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"deadeye": {"len": 1.0, "hit": [0.55, 0.58], "stance": "pistol", "weapon": "pistol"},
	"smoke_throw": {"len": 0.5, "hit": [0.34, 0.4], "stance": "pistol", "weapon": "pistol"},
	"point_blank": {"len": 0.6, "hit": [0.32, 0.38], "stance": "pistol", "weapon": "pistol"},
	"deaths_waltz": {"len": 2.0, "hit": [0.1, 0.85], "stance": "dual_pistol", "weapon": "pistol", "extras": {"dual": true}},
	"suplex": {"len": 1.1, "hit": [0.58, 0.64], "stance": "fist", "weapon": ""},
	"shoulder_throw": {"len": 0.95, "hit": [0.51, 0.56], "stance": "fist", "weapon": ""},
	"giant_swing": {"len": 2.1, "hit": [0.19, 0.78], "stance": "fist", "weapon": ""},
	"hundred_fists": {"len": 1.3, "hit": [0.08, 0.85], "stance": "fist", "weapon": ""},
	"rising_dragon": {"len": 0.9, "hit": [0.17, 0.26], "stance": "fist", "weapon": ""},
	"palm_strike": {"len": 0.55, "hit": [0.35, 0.42], "stance": "fist", "weapon": ""},
	"sea_king_fist": {"len": 1.45, "hit": [0.53, 0.58], "stance": "fist", "weapon": ""},
	"conqueror": {"len": 1.2, "hit": [0.31, 0.36], "stance": "fist", "weapon": ""},
	# --- moving, reacting, everyday ---
	"dash": {"len": 0.3, "stance": "sword", "weapon": "cutlass", "extras": {"dash_dir": Vector2(0, 1)},
		"variants": [{"dash_dir": Vector2(1, 0)}]},
	"roll": {"len": 0.6, "stance": "sword", "weapon": "cutlass"},
	"flip": {"len": 0.45, "stance": "sword", "weapon": "cutlass"},
	"hit": {"len": 0.32, "react": true, "stance": "sword", "weapon": "cutlass", "extras": {"push": Vector3(0, 0, 1)},
		"variants": [{"push": Vector3(0, 0, -1)}, {"push": Vector3(1, 0, 0)}]},
	"stagger": {"len": 1.0, "react": true, "stance": "sword", "weapon": "cutlass", "extras": {"push": Vector3(0, 0, 1)},
		"variants": [{"push": Vector3(0, 0, -1)}, {"push": Vector3(1, 0, 0)}, {"push": Vector3(-0.7, 0, 0.7)}]},
	"mantle": {"len": 1.0, "stance": "sword", "weapon": "cutlass"},
	"drink": {"len": 1.0, "stance": "sword", "weapon": "cutlass"},
	"eat": {"len": 1.0, "stance": "sword", "weapon": "cutlass"},
	"wave": {"len": 1.5, "stance": "sword", "weapon": "cutlass"},
	# --- grunts and bosses ---
	"wind_r": {"len": 0.6, "stance": "sword", "weapon": "cutlass"},
	"swing_r": {"len": 0.5, "stance": "sword", "weapon": "cutlass"},
	"wind_l": {"len": 0.32, "stance": "sword", "weapon": "cutlass"},
	"swing_l": {"len": 0.5, "stance": "sword", "weapon": "cutlass"},
	"lunge_wind": {"len": 0.8, "stance": "sword", "weapon": "cutlass"},
	"lunge": {"len": 0.8, "stance": "sword", "weapon": "cutlass"},
	"block": {"len": 0.4, "stance": "sword", "weapon": "cutlass"},
	"peril_chop": {"len": 2.6, "stance": "sword", "weapon": "cutlass"},
	"slash_down": {"len": 0.5, "stance": "sword", "weapon": "cutlass"},
	"aim_pistol": {"len": 1.3, "stance": "pistol", "weapon": "pistol", "extras": {"auto_point_guns": false}},
	"aim_rifle": {"len": 1.3, "stance": "sword", "weapon": "rifle"},
	"shove": {"len": 0.75, "stance": "sword", "weapon": "rifle"},
}


static func length(n: String) -> float:
	return float(SPECS[n]["len"])


## The hitbox window in seconds at the spec's length (x = opens, y = closes).
static func hit_seconds(n: String) -> Vector2:
	var s: Dictionary = SPECS[n]
	var h: Array = s["hit"]
	return Vector2(float(h[0]), float(h[1])) * float(s["len"])
