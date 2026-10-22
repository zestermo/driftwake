class_name ActionSpecs
## Every Humanoid action in one table: the length its caller plays it at ("len", s), the
## strike window as fractions of the action ("hit", u) and how to preview it (stance,
## weapon, extras for tools/dev/animsheet.gd). Light and heavy attacks take their lengths
## and hitbox timing from here, so a pose and its hitbox can't drift apart.
## "hold": played with Humanoid.hold (len = the blend in). "react": played with
## Humanoid.react (preview "push" = which way the blow shoves the body, local).
## extras: "dual" (same weapon in the off hand), "beast", "sheathed", any Humanoid property;
## "variants" = more extras dicts, each rendered as another row.
## Feel (optional): "lead" {joint: s} samples that joint's keys ahead (+, leads) or behind
## (-, trails) in time, for overlap (hips lead, hands whip after); "sharp" how hard joints
## chase their keys (default 38; higher snaps); "snap": no blend in from the stance (a shot from the
## low ready is up at once); "step" fps the pose is sampled at (anime
## "on twos": hold each drawing, 0 = smooth). Pose keys may carry "_scale" (body squash/
## stretch about the feet: x side, y up, z forward) and "_smear" (Vector3, x = blade stretch).
## "chain" (s): when the next light attack can follow (overrides the state's durations).
## "swoosh": [u from, u to] when a swing's blade trail is drawn (default: the hit window).
## extras "after": the action played before this one in the preview, up to its "chain" time
## (a combo hit is checked as it chains).
## "retime": [[u played, u of the keys], ...] (0..1, rising): a piecewise-linear time map, to
## slow parts of a move (wind-up, follow-through) and keep others (the strike) at speed
## without re-keying; "hit" is in played time.
## "swing": the hand on a path instead of keyed arm angles (Humanoid._swing): {"hand": "r"|"l",
## "center": Vector3 in the root's space (feet, facing -Z), "follow": 0..1 how far the points
## turn with the chest, "anchor": 0..1 how far the points move with the shoulders (default 1),
## "lag": s behind the body, "from_shoulder": the points are offsets from the sword shoulder
## (use with "follow" 1 when the body turns a lot: "r" is then the reach), "plane": the cut plane's normal (default from the path's sweep from
## key "plane_from" on: skip wind-up keys that travel the other way),
## "cut": the overall direction (checks only), "break": default wrist break, "keys": [[u,
## {"dir": from the centre, "r": m, "break": rad the blade is cocked back off the forearm's
## line (~1.5 square, 0 in line)}, mode?], ...]}. The sword extends the forearm, broken toward
## the trailing side of the cut so its edge leads (Humanoid._swing); the posed arm is overridden.
## Start the keys at the guard hand and arc the wind-up round the shoulder, never across it.
## "reach": the free hand on a path the same way (Humanoid._reach): {"hand": "l"|"r", "center",
## "follow", "anchor", "lag", "from_shoulder": the points are offsets from the arm's shoulder
## (their distance sets the elbow bend), "pole": elbow direction (default out, down and back), "keys": [[u,
## {"dir", "r", "pole"?}, mode?], ...]}; arm IK, the wrist as posed.
## AnimLab variants override any of this while picked.

## Stances with their own parry pose (Humanoid "parry" plays it) and flourish (ParryState plays it when a parry lands).
const PARRIES := {"dual_sword": ["dual_parry", "dual_deflect"], "dagger": ["dg_parry", "dg_deflect"], "dual_dagger": ["dd_parry", "dd_deflect"],
	"polearm": ["pole_parry", "pole_deflect"], "hammer": ["ham_parry", "ham_deflect"],
	"dual_axe": ["dx_parry", "dx_deflect"], "greatsword": ["gs_parry", "gs_deflect"], "black_leg": ["bl_parry", "bl_deflect"]}

const SPECS := {
	# --- cutlass ---
	"draw": {"len": 0.35, "stance": "sword", "weapon": "cutlass", "extras": {"sheathed": true}},
	"sheathe": {"len": 0.4, "stance": "sword", "weapon": "cutlass"},
	# (the cutlass combo's first two hits ride swing paths: SwordMoves; slash_r is the
	# reference swing, see the driftwake-animation skill)
	"slash_r": {"len": 0.85, "hit": [0.45, 0.6], "chain": 0.62, "swoosh": [0.4, 0.66], "sharp": 55.0,
		"lead": {"pivot": 0.02, "hips": 0.04, "torso": 0.02},
		"swing": SwordMoves.SLASH_R_SWING, "reach": SwordMoves.SLASH_R_REACH, "stance": "sword", "weapon": "cutlass"},
	"slash_l": {"len": 0.7, "hit": [0.34, 0.5], "chain": 0.5, "swoosh": [0.28, 0.62], "sharp": 55.0,
		"lead": {"pivot": 0.02, "hips": 0.04, "torso": 0.02},
		"swing": SwordMoves.SLASH_L_SWING, "reach": SwordMoves.SLASH_L_REACH, "stance": "sword", "weapon": "cutlass",
		"extras": {"after": "slash_r"}},
	"slash_spin": {"len": 0.8, "hit": [0.26, 0.78], "chain": 0.68, "swoosh": [0.2, 0.84], "sharp": 55.0,
		"lead": {"pivot": 0.02, "hips": 0.04, "torso": 0.02},
		"swing": SwordMoves.SLASH_SPIN_SWING, "reach": SwordMoves.SLASH_SPIN_REACH, "stance": "sword", "weapon": "cutlass",
		"extras": {"after": "slash_l"}},
	# (the boss's quick spin; the player's combo finisher is slash_spin)
	"spin_slash": {"len": 0.62, "hit": [0.21, 0.68], "stance": "sword", "weapon": "cutlass"},
	"dash_cut": {"len": 0.62, "hit": [0.27, 0.48], "stance": "sword", "weapon": "cutlass"},
	"thrust": {"len": 0.75, "hit": [0.29, 0.53], "stance": "sword", "weapon": "cutlass"},
	"flying_slash": {"len": 0.5, "stance": "sword", "weapon": "cutlass"},
	"heavy": {"len": 0.8, "hit": [0.375, 0.625], "stance": "sword", "weapon": "cutlass"},
	"parry": {"len": 0.66, "stance": "sword", "weapon": "cutlass"},
	"guard_block": {"len": 0.24, "hold": true, "stance": "sword", "weapon": "cutlass"},
	"guard_block_hit": {"len": 0.2, "stance": "sword", "weapon": "cutlass"},
	# (the stances with their own parry and flourish, PARRIES; *_stance and *_block are previews:
	# the stance as it stands, the held guard_block)
	"dual_parry": {"len": 0.66, "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"dual_deflect": {"len": 0.42, "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"dual_block": {"len": 0.24, "hold": true, "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"dual_stance": {"len": 1.0, "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"dg_parry": {"len": 0.66, "stance": "dagger", "weapon": "dagger"},
	"dg_deflect": {"len": 0.42, "stance": "dagger", "weapon": "dagger"},
	"dg_block": {"len": 0.24, "hold": true, "stance": "dagger", "weapon": "dagger"},
	"dg_stance": {"len": 1.0, "stance": "dagger", "weapon": "dagger"},
	"dd_parry": {"len": 0.66, "stance": "dual_dagger", "weapon": "dagger", "extras": {"dual": true}},
	"dd_deflect": {"len": 0.42, "stance": "dual_dagger", "weapon": "dagger", "extras": {"dual": true}},
	"dd_block": {"len": 0.24, "hold": true, "stance": "dual_dagger", "weapon": "dagger", "extras": {"dual": true}},
	"dd_stance": {"len": 1.0, "stance": "dual_dagger", "weapon": "dagger", "extras": {"dual": true}},
	"plunge_air": {"len": 0.6, "stance": "sword", "weapon": "cutlass"},
	"plunge_land": {"len": 0.48, "stance": "sword", "weapon": "cutlass"},
	# the learned air attacks (PlungeState)
	"twin_cyclone": {"len": 0.8, "hit": [0.18, 0.85], "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"cyclone_land": {"len": 0.48, "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"meteor_kick": {"len": 0.6, "hit": [0.2, 0.6], "stance": "fist", "weapon": ""},
	"meteor_land": {"len": 0.44, "stance": "fist", "weapon": ""},
	"boarding_dive": {"len": 0.6, "hit": [0.27, 0.6], "stance": "sword", "weapon": "cutlass"},
	"vault_back": {"len": 0.45, "stance": "sword", "weapon": "cutlass"},
	"hang_shot": {"len": 0.62, "hit": [0.48, 0.52], "stance": "pistol", "weapon": "pistol"},
	"climb_chop": {"len": 0.5, "stance": "sword", "weapon": "cutlass"},
	# --- katana ---
	# (the combo rides swing paths: KatanaMoves)
	"katana_r": {"len": 0.85, "hit": [0.44, 0.6], "chain": 0.62, "swoosh": [0.46, 0.66], "sharp": 55.0,
		"lead": {"pivot": 0.02, "hips": 0.04, "torso": 0.02}, "swing": KatanaMoves.KR_SWING, "stance": "katana", "weapon": "katana"},
	"katana_l": {"len": 0.75, "hit": [0.4, 0.56], "chain": 0.52, "swoosh": [0.41, 0.62], "sharp": 55.0,
		"lead": {"pivot": 0.02, "hips": 0.04, "torso": 0.02}, "swing": KatanaMoves.KL_SWING, "stance": "katana", "weapon": "katana",
		"extras": {"after": "katana_r"}},
	"katana_stab": {"len": 0.9, "hit": [0.42, 0.58], "chain": 0.7, "swoosh": [0.38, 0.56], "sharp": 55.0,
		"lead": {"pivot": 0.02, "hips": 0.04, "torso": 0.02}, "swing": KatanaMoves.KS_SWING, "stance": "katana", "weapon": "katana",
		"extras": {"after": "katana_l"}},
	"quick_draw": {"len": 1.3, "hit": [0.04, 0.15], "swoosh": [0.02, 0.15], "stance": "katana", "weapon": "katana"},
	"iai_ready": {"len": 0.3, "hold": true, "stance": "katana", "weapon": "katana"},
	"iai_slash": {"len": 0.6, "hit": [0.05, 0.2], "swoosh": [0.03, 0.3], "sharp": 55.0, "swing": KatanaMoves.IAI_SWING, "stance": "katana", "weapon": "katana"},
	# (Tiger Rush with a katana: SkillState plays it in place of the cutlass's thrust)
	"tiger_rush": {"len": 0.55, "hit": [0.3, 0.76], "swoosh": [0.6, 0.78], "sharp": 55.0, "swing": KatanaMoves.TIGER_SWING, "stance": "katana", "weapon": "katana"},
	"air_slash": {"len": 0.6, "hit": [0.34, 0.6], "swoosh": [0.34, 0.62], "sharp": 55.0, "swing": KatanaMoves.AIR_SWING, "stance": "katana", "weapon": "katana"},
	# --- axe ---
	"axe_hack": {"len": 0.62, "hit": [0.39, 0.56], "stance": "axe", "weapon": "axe"},
	"axe_hook": {"len": 0.62, "hit": [0.35, 0.53], "stance": "axe", "weapon": "axe"},
	"axe_split": {"len": 0.9, "hit": [0.42, 0.6], "stance": "axe", "weapon": "axe"},
	"axe_whirl": {"len": 1.24, "hit": [0.18, 0.76], "stance": "axe", "weapon": "axe"},
	"axe_flip": {"len": 0.58, "stance": "axe", "weapon": "axe"},
	"axe_land": {"len": 0.53, "stance": "axe", "weapon": "axe"},
	# --- dual wield (WieldMoves; dual_2 changes with an axe or a dagger in the off hand) ---
	"dual_1": {"len": 0.5, "hit": [0.32, 0.48], "chain": 0.34, "swoosh": [0.26, 0.52], "lead": {"hips": 0.03, "torso": 0.015},
		"stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"dual_2": {"len": 0.5, "hit": [0.32, 0.48], "chain": 0.34, "swoosh": [0.26, 0.52], "lead": {"hips": 0.03, "torso": 0.015},
		"stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true, "after": "dual_1"},
		"variants": [{"dual": false, "offhand": "dagger", "after": "dual_1"}]},
	"dual_cross": {"len": 0.58, "hit": [0.36, 0.54], "chain": 0.42, "swoosh": [0.3, 0.56], "stance": "dual_sword", "weapon": "cutlass",
		"extras": {"dual": true, "after": "dual_2"}},
	"dual_spin": {"len": 0.7, "hit": [0.24, 0.74], "chain": 0.56, "swoosh": [0.24, 0.76], "stance": "dual_sword", "weapon": "cutlass",
		"extras": {"dual": true, "after": "dual_cross"}},
	"dual_heavy": {"len": 0.88, "hit": [0.42, 0.6], "swoosh": [0.4, 0.62], "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	# --- sword + pistol (WieldMoves; "shot": u when the pistol fires) ---
	"sp_cut": {"len": 0.7, "hit": [0.38, 0.54], "chain": 0.46, "swoosh": [0.32, 0.6], "lead": {"hips": 0.03, "torso": 0.015},
		"stance": "sword_pistol", "weapon": "cutlass", "extras": {"offhand": "pistol"}},
	"sp_shot": {"len": 0.62, "hit": [0.3, 0.36], "shot": 0.32, "chain": 0.4, "stance": "sword_pistol", "weapon": "cutlass",
		"extras": {"offhand": "pistol", "after": "sp_cut"}},
	"sp_rise": {"len": 0.72, "hit": [0.36, 0.52], "chain": 0.48, "swoosh": [0.3, 0.58], "lead": {"hips": 0.03, "torso": 0.015},
		"stance": "sword_pistol", "weapon": "cutlass", "extras": {"offhand": "pistol", "after": "sp_shot"}},
	"sp_finale": {"len": 1.05, "hit": [0.2, 0.44], "shot": 0.59, "chain": 0.86, "swoosh": [0.18, 0.46],
		"stance": "sword_pistol", "weapon": "cutlass", "extras": {"offhand": "pistol", "after": "sp_rise"}},
	"sp_lunge": {"len": 0.95, "hit": [0.31, 0.47], "shot": 0.6, "swoosh": [0.3, 0.46], "stance": "sword_pistol", "weapon": "cutlass",
		"extras": {"offhand": "pistol"}},
	"sp_drop": {"len": 0.7, "hit": [0.2, 0.22], "stance": "sword_pistol", "weapon": "cutlass", "extras": {"offhand": "pistol"}},
	"sp_drop_land": {"len": 0.5, "stance": "sword_pistol", "weapon": "cutlass", "extras": {"offhand": "pistol"}},
	# --- one dagger (DaggerMoves) ---
	"dg_stab": {"len": 0.4, "hit": [0.34, 0.52], "chain": 0.26, "swoosh": [0.3, 0.55], "lead": {"hips": 0.03, "torso": 0.015},
		"stance": "dagger", "weapon": "dagger"},
	"dg_slash": {"len": 0.42, "hit": [0.34, 0.52], "chain": 0.28, "swoosh": [0.3, 0.56], "lead": {"hips": 0.03, "torso": 0.015},
		"stance": "dagger", "weapon": "dagger", "extras": {"after": "dg_stab"}},
	"dg_rise": {"len": 0.45, "hit": [0.34, 0.52], "chain": 0.3, "swoosh": [0.3, 0.56], "lead": {"hips": 0.03, "torso": 0.015},
		"stance": "dagger", "weapon": "dagger", "extras": {"after": "dg_slash"}},
	"dg_gut": {"len": 0.66, "hit": [0.48, 0.64], "chain": 0.5, "swoosh": [0.14, 0.62], "stance": "dagger", "weapon": "dagger",
		"extras": {"after": "dg_rise"}},
	"dg_shadow": {"len": 0.75, "hit": [0.36, 0.5], "swoosh": [0.38, 0.52], "stance": "dagger", "weapon": "dagger"},
	"fang_dive": {"len": 0.6, "hit": [0.33, 0.6], "stance": "dagger", "weapon": "dagger"},
	# --- two daggers (DaggerMoves) ---
	"dd_1": {"len": 0.38, "hit": [0.32, 0.5], "chain": 0.24, "swoosh": [0.28, 0.54], "lead": {"hips": 0.03, "torso": 0.015},
		"stance": "dual_dagger", "weapon": "dagger", "extras": {"dual": true}},
	"dd_2": {"len": 0.38, "hit": [0.32, 0.5], "chain": 0.24, "swoosh": [0.28, 0.54], "lead": {"hips": 0.03, "torso": 0.015},
		"stance": "dual_dagger", "weapon": "dagger", "extras": {"dual": true, "after": "dd_1"}},
	"dd_3": {"len": 0.48, "hit": [0.36, 0.54], "chain": 0.32, "swoosh": [0.3, 0.56], "stance": "dual_dagger", "weapon": "dagger",
		"extras": {"dual": true, "after": "dd_2"}},
	"dd_4": {"len": 0.66, "hit": [0.22, 0.72], "chain": 0.52, "swoosh": [0.2, 0.72], "stance": "dual_dagger", "weapon": "dagger",
		"extras": {"dual": true, "after": "dd_3"}},
	"dd_heavy": {"len": 0.85, "hit": [0.42, 0.74], "swoosh": [0.4, 0.78], "stance": "dual_dagger", "weapon": "dagger", "extras": {"dual": true}},
	"knife_rain": {"len": 0.7, "hit": [0.3, 0.34], "stance": "dual_dagger", "weapon": "dagger", "extras": {"dual": true}},
	# --- polearm (PoleMoves: the body keyed, the two-handed grip solved; no "lead": its offset samples would
	# overwrite the grip) ---
	"pole_stance": {"len": 1.0, "stance": "polearm", "weapon": "polearm"},
	"pole_thrust": {"len": 0.6, "hit": [0.38, 0.6], "chain": 0.42, "swoosh": [0.36, 0.62], "sharp": 50.0, "stance": "polearm", "weapon": "polearm"},
	"pole_rise": {"len": 0.64, "hit": [0.39, 0.6], "chain": 0.46, "swoosh": [0.36, 0.62], "sharp": 50.0, "stance": "polearm", "weapon": "polearm",
		"extras": {"after": "pole_thrust"}},
	"pole_sweep": {"len": 0.78, "hit": [0.4, 0.64], "chain": 0.58, "swoosh": [0.38, 0.66], "sharp": 50.0, "stance": "polearm", "weapon": "polearm",
		"extras": {"after": "pole_rise"}},
	"pole_wheel": {"len": 0.95, "hit": [0.3, 0.7], "chain": 0.74, "swoosh": [0.28, 0.72], "sharp": 50.0, "stance": "polearm", "weapon": "polearm",
		"extras": {"after": "pole_sweep"}},
	"pole_heavy": {"len": 0.95, "hit": [0.46, 0.62], "swoosh": [0.44, 0.64], "sharp": 50.0, "stance": "polearm", "weapon": "polearm"},
	"pole_legsweep": {"len": 0.75, "hit": [0.32, 0.56], "swoosh": [0.3, 0.6], "sharp": 50.0, "stance": "polearm", "weapon": "polearm"},
	"pole_vault": {"len": 0.8, "stance": "polearm", "weapon": "polearm", "extras": {"grounded": false, "vertical_speed": 6.0}},
	"pole_dive": {"len": 0.6, "hit": [0.4, 0.98], "stance": "polearm", "weapon": "polearm", "extras": {"grounded": false}},
	"pole_land": {"len": 0.5, "stance": "polearm", "weapon": "polearm"},
	"pole_flurry": {"len": 1.1, "hit": [0.12, 0.7], "stance": "polearm", "weapon": "polearm"},
	"pole_dragon": {"len": 1.2, "hit": [0.35, 0.67], "stance": "polearm", "weapon": "polearm"},
	"pole_vstrike": {"len": 1.0, "hit": [0.4, 0.44], "stance": "polearm", "weapon": "polearm"},
	"pole_raijin": {"len": 2.4, "hit": [0.21, 0.75], "stance": "polearm", "weapon": "polearm"},
	"pole_parry": {"len": 0.66, "stance": "polearm", "weapon": "polearm"},
	"pole_deflect": {"len": 0.42, "stance": "polearm", "weapon": "polearm"},
	"pole_block": {"len": 0.24, "hold": true, "stance": "polearm", "weapon": "polearm"},
	# --- hammer (HammerMoves: keyed like the polearm, its grip solved by PoleMoves.hands) ---
	"ham_stance": {"len": 1.0, "stance": "hammer", "weapon": "hammer"},
	"ham_smash": {"len": 0.8, "hit": [0.45, 0.62], "chain": 0.58, "swoosh": [0.42, 0.64], "sharp": 50.0, "stance": "hammer", "weapon": "hammer"},
	"ham_upper": {"len": 0.76, "hit": [0.38, 0.58], "chain": 0.56, "swoosh": [0.36, 0.62], "sharp": 50.0, "stance": "hammer", "weapon": "hammer",
		"extras": {"after": "ham_smash"}},
	"ham_sweep": {"len": 0.9, "hit": [0.44, 0.62], "chain": 0.7, "swoosh": [0.42, 0.66], "sharp": 50.0, "stance": "hammer", "weapon": "hammer",
		"extras": {"after": "ham_upper"}},
	"ham_spin": {"len": 1.15, "hit": [0.3, 0.76], "chain": 0.95, "swoosh": [0.28, 0.76], "sharp": 50.0, "stance": "hammer", "weapon": "hammer",
		"extras": {"after": "ham_sweep"}},
	"ham_heavy": {"len": 1.0, "hit": [0.5, 0.64], "swoosh": [0.46, 0.6], "sharp": 50.0, "stance": "hammer", "weapon": "hammer"},
	"ham_rush": {"len": 0.8, "hit": [0.36, 0.56], "swoosh": [0.34, 0.6], "sharp": 50.0, "stance": "hammer", "weapon": "hammer"},
	"ham_dive": {"len": 0.7, "stance": "hammer", "weapon": "hammer", "extras": {"grounded": false}},
	"ham_land": {"len": 0.55, "stance": "hammer", "weapon": "hammer"},
	"ham_skull": {"len": 0.9, "hit": [0.47, 0.52], "stance": "hammer", "weapon": "hammer"},
	"ham_quakes": {"len": 1.5, "hit": [0.24, 0.78], "stance": "hammer", "weapon": "hammer"},
	"ham_cyclone": {"len": 1.7, "hit": [0.18, 0.82], "stance": "hammer", "weapon": "hammer"},
	"ham_titan": {"len": 1.0, "stance": "hammer", "weapon": "hammer", "extras": {"grounded": false}},
	"ham_parry": {"len": 0.66, "stance": "hammer", "weapon": "hammer"},
	"ham_deflect": {"len": 0.45, "stance": "hammer", "weapon": "hammer"},
	"ham_block": {"len": 0.24, "hold": true, "stance": "hammer", "weapon": "hammer"},
	# --- twin axes (DualAxeMoves): quick chops trading hands, the hook, the whirl ---
	"dx_stance": {"len": 1.0, "stance": "dual_axe", "weapon": "axe", "extras": {"dual": true}},
	"dx_1": {"len": 0.44, "hit": [0.3, 0.46], "chain": 0.28, "swoosh": [0.24, 0.5], "sharp": 50.0, "lead": {"hips": 0.03, "torso": 0.015},
		"stance": "dual_axe", "weapon": "axe", "extras": {"dual": true}},
	"dx_2": {"len": 0.44, "hit": [0.3, 0.46], "chain": 0.28, "swoosh": [0.24, 0.5], "sharp": 50.0, "lead": {"hips": 0.03, "torso": 0.015},
		"stance": "dual_axe", "weapon": "axe", "extras": {"dual": true, "after": "dx_1"}},
	"dx_3": {"len": 0.56, "hit": [0.3, 0.48], "chain": 0.36, "swoosh": [0.26, 0.5], "sharp": 50.0,
		"stance": "dual_axe", "weapon": "axe", "extras": {"dual": true, "after": "dx_2"}},
	"dx_4": {"len": 0.8, "hit": [0.2, 0.78], "chain": 0.62, "swoosh": [0.2, 0.8], "sharp": 50.0,
		"stance": "dual_axe", "weapon": "axe", "extras": {"dual": true, "after": "dx_3"}},
	"dx_heavy": {"len": 1.15, "hit": [0.2, 0.84], "swoosh": [0.18, 0.86], "sharp": 50.0, "stance": "dual_axe", "weapon": "axe", "extras": {"dual": true}},
	"dx_rush": {"len": 0.72, "hit": [0.36, 0.56], "swoosh": [0.36, 0.56], "sharp": 50.0, "stance": "dual_axe", "weapon": "axe", "extras": {"dual": true}},
	"dx_dive": {"len": 1.2, "hit": [0.1, 0.95], "stance": "dual_axe", "weapon": "axe", "extras": {"dual": true, "grounded": false}},
	"dx_land": {"len": 0.52, "stance": "dual_axe", "weapon": "axe", "extras": {"dual": true}},
	"dx_parry": {"len": 0.66, "stance": "dual_axe", "weapon": "axe", "extras": {"dual": true}},
	"dx_deflect": {"len": 0.45, "stance": "dual_axe", "weapon": "axe", "extras": {"dual": true}},
	"dx_block": {"len": 0.24, "hold": true, "stance": "dual_axe", "weapon": "axe", "extras": {"dual": true}},
	"dx_gallows": {"len": 0.9, "hit": [0.53, 0.6], "stance": "dual_axe", "weapon": "axe", "extras": {"dual": true}},
	"dx_frenzy": {"len": 1.2, "hit": [0.08, 0.82], "stance": "dual_axe", "weapon": "axe", "extras": {"dual": true}},
	"dx_storm": {"len": 1.8, "hit": [0.18, 0.92], "stance": "dual_axe", "weapon": "axe", "extras": {"dual": true}},
	"dx_winter": {"len": 2.6, "hit": [0.25, 0.78], "stance": "dual_axe", "weapon": "axe", "extras": {"dual": true}},
	# --- greatsword (GreatswordMoves: keyed like the hammer, its grip solved by PoleMoves.hands; "carry": a chained
	# blow starts where the one "after" it left off, Humanoid._begin_action) ---
	"gs_stance": {"len": 1.0, "stance": "greatsword", "weapon": "greatsword"},
	"gs_1": {"len": 0.8, "hit": [0.24, 0.42], "chain": 0.42, "swoosh": [0.22, 0.46], "sharp": 50.0, "stance": "greatsword", "weapon": "greatsword"},
	"gs_2": {"len": 0.78, "hit": [0.25, 0.42], "chain": 0.42, "swoosh": [0.23, 0.46], "sharp": 50.0, "carry": true, "stance": "greatsword", "weapon": "greatsword",
		"extras": {"after": "gs_1"}},
	"gs_3": {"len": 0.84, "hit": [0.28, 0.48], "chain": 0.48, "swoosh": [0.26, 0.52], "sharp": 50.0, "carry": true, "stance": "greatsword", "weapon": "greatsword",
		"extras": {"after": "gs_2"}},
	"gs_4": {"len": 1.1, "hit": [0.14, 0.72], "chain": 0.95, "swoosh": [0.12, 0.74], "sharp": 50.0, "carry": true, "stance": "greatsword", "weapon": "greatsword",
		"extras": {"after": "gs_3"}},
	"gs_charge": {"len": 0.2, "hold": true, "stance": "greatsword", "weapon": "greatsword"},
	"gs_heavy": {"len": 0.8, "hit": [0.13, 0.3], "swoosh": [0.1, 0.3], "sharp": 55.0, "stance": "greatsword", "weapon": "greatsword"},
	"gs_rush": {"len": 0.8, "hit": [0.38, 0.56], "swoosh": [0.36, 0.6], "sharp": 50.0, "stance": "greatsword", "weapon": "greatsword"},
	"gs_dive": {"len": 0.7, "stance": "greatsword", "weapon": "greatsword", "extras": {"grounded": false}},
	"gs_land": {"len": 0.55, "stance": "greatsword", "weapon": "greatsword"},
	"gs_guardbreak": {"len": 0.95, "hit": [0.23, 0.6], "stance": "greatsword", "weapon": "greatsword"},
	"gs_crescent": {"len": 0.8, "hit": [0.3, 0.45], "stance": "greatsword", "weapon": "greatsword"},
	"gs_tempest": {"len": 1.7, "hit": [0.12, 0.85], "stance": "greatsword", "weapon": "greatsword"},
	"gs_sky": {"len": 1.0, "stance": "greatsword", "weapon": "greatsword", "extras": {"grounded": false}},
	"gs_parry": {"len": 0.66, "stance": "greatsword", "weapon": "greatsword"},
	"gs_deflect": {"len": 0.45, "stance": "greatsword", "weapon": "greatsword"},
	"gs_block": {"len": 0.24, "hold": true, "stance": "greatsword", "weapon": "greatsword"},
	# --- black-leg (BlackLegMoves): kicks low, mid, high, the handstand spin; "legs": which leg's trail is drawn ---
	"bl_stance": {"len": 1.0, "stance": "black_leg", "weapon": ""},
	"bl_1": {"len": 0.42, "hit": [0.26, 0.5], "chain": 0.3, "swoosh": [0.2, 0.5], "legs": "l", "sharp": 46.0, "lead": {"hips": 0.03, "torso": 0.012},
		"stance": "black_leg", "weapon": ""},
	"bl_2": {"len": 0.5, "hit": [0.3, 0.54], "chain": 0.34, "swoosh": [0.24, 0.54], "legs": "r", "sharp": 46.0, "lead": {"hips": 0.03, "torso": 0.012},
		"stance": "black_leg", "weapon": "", "extras": {"after": "bl_1"}},
	"bl_3": {"len": 0.56, "hit": [0.34, 0.6], "chain": 0.4, "swoosh": [0.3, 0.6], "legs": "l", "sharp": 46.0, "lead": {"hips": 0.03, "torso": 0.012},
		"stance": "black_leg", "weapon": "", "extras": {"after": "bl_2"}},
	"bl_4": {"len": 1.1, "hit": [0.24, 0.78], "chain": 0.95, "swoosh": [0.24, 0.78], "legs": "lr", "sharp": 46.0,
		"stance": "black_leg", "weapon": "", "extras": {"after": "bl_3"}},
	"bl_heavy": {"len": 0.95, "hit": [0.5, 0.64], "swoosh": [0.4, 0.62], "legs": "r", "sharp": 48.0, "stance": "black_leg", "weapon": ""},
	"bl_rush": {"len": 0.75, "hit": [0.28, 0.6], "swoosh": [0.26, 0.6], "legs": "r", "sharp": 46.0, "stance": "black_leg", "weapon": ""},
	"bl_air": {"len": 1.2, "hit": [0.1, 0.95], "stance": "black_leg", "weapon": "", "extras": {"grounded": false}},
	"bl_air_land": {"len": 0.55, "stance": "black_leg", "weapon": ""},
	"bl_parry": {"len": 0.66, "stance": "black_leg", "weapon": ""},
	"bl_deflect": {"len": 0.55, "stance": "black_leg", "weapon": ""},
	"bl_block": {"len": 0.24, "hold": true, "stance": "black_leg", "weapon": ""},
	"bl_mule": {"len": 0.95, "hit": [0.42, 0.5], "sharp": 46.0, "stance": "black_leg", "weapon": ""},
	"bl_hail": {"len": 1.3, "hit": [0.12, 0.86], "sharp": 64.0, "stance": "black_leg", "weapon": ""},
	"bl_wheel": {"len": 1.45, "hit": [0.07, 0.8], "sharp": 46.0, "stance": "black_leg", "weapon": ""},
	"bl_last": {"len": 2.7, "hit": [0.26, 0.73], "sharp": 50.0, "stance": "black_leg", "weapon": ""},
	# --- unarmed ---
	"fists_up": {"len": 0.25, "stance": "fist", "weapon": ""},
	# (boxing: the body keyed, the punching hand on a reach path; FistMoves)
	"fs_jab": {"len": 0.36, "hit": [0.24, 0.46], "chain": 0.2, "sharp": 50.0, "lead": {"hips": 0.03, "torso": 0.015},
		"reach": FistMoves.JAB_REACH, "stance": "fist", "weapon": ""},
	"fs_cross": {"len": 0.42, "hit": [0.28, 0.5], "chain": 0.25, "sharp": 50.0, "lead": {"hips": 0.03, "torso": 0.015},
		"reach": FistMoves.CROSS_REACH, "stance": "fist", "weapon": "", "extras": {"after": "fs_jab"}},
	"fs_hook": {"len": 0.46, "hit": [0.32, 0.54], "chain": 0.3, "sharp": 50.0, "lead": {"hips": 0.04, "torso": 0.02},
		"reach": FistMoves.HOOK_REACH, "stance": "fist", "weapon": "", "extras": {"after": "fs_cross"}},
	"fs_upper": {"len": 0.6, "hit": [0.36, 0.56], "chain": 0.44, "sharp": 50.0, "lead": {"hips": 0.04, "torso": 0.02},
		"reach": FistMoves.UPPER_REACH, "stance": "fist", "weapon": "", "extras": {"after": "fs_hook"}},
	"fs_hay": {"len": 1.0, "hit": [0.44, 0.56], "sharp": 50.0, "lead": {"hips": 0.04, "torso": 0.02},
		"reach": FistMoves.HAY_REACH, "stance": "fist", "weapon": ""},
	# --- pistols ---
	"shoot_r": {"len": 0.6, "stance": "pistol", "weapon": "pistol", "sharp": 90.0, "snap": true},
	"pistol_whip": {"len": 0.62, "hit": [0.32, 0.52], "stance": "pistol", "weapon": "pistol"},
	"reload": {"len": 1.0, "stance": "pistol", "weapon": "pistol"},
	"bullet_storm": {"len": 0.75, "stance": "pistol", "weapon": "pistol"},
	"shoot_l": {"len": 0.6, "stance": "dual_pistol", "weapon": "pistol", "sharp": 90.0, "snap": true, "extras": {"dual": true}},
	"gun_kata": {"len": 0.82, "hit": [0.15, 0.76], "stance": "dual_pistol", "weapon": "pistol", "extras": {"dual": true}},
	"gun_rain": {"len": 0.6, "stance": "dual_pistol", "weapon": "pistol", "extras": {"dual": true}},
	# --- Zoan hybrid ---
	# the silverback (JungleApe, ApePoses)
	"ape_beat": {"len": 2.0, "stance": "ape", "weapon": ""},
	"ape_swipe": {"len": 0.9, "hit": [0.42, 0.6], "stance": "ape", "weapon": ""},
	"ape_slam_wind": {"len": 0.6, "stance": "ape", "weapon": ""},
	"ape_slam": {"len": 0.7, "stance": "ape", "weapon": ""},
	"ape_crouch": {"len": 0.45, "stance": "ape", "weapon": ""},
	"ape_air": {"len": 0.2, "stance": "ape", "weapon": ""},
	"ape_lift": {"len": 0.9, "stance": "ape", "weapon": ""},
	"ape_hurl": {"len": 0.6, "stance": "ape", "weapon": ""},
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
	# (the katana's cuts ride swing paths: KatanaMoves)
	"wind_sever": {"len": 0.75, "hit": [0.42, 0.5], "swoosh": [0.4, 0.56], "sharp": 55.0, "swing": KatanaMoves.SEVER_SWING, "stance": "katana", "weapon": "katana"},
	"phantom_cut": {"len": 0.6, "hit": [0.24, 0.32], "swoosh": [0.2, 0.42], "sharp": 55.0, "swing": KatanaMoves.PHANTOM_SWING, "stance": "katana", "weapon": "katana"},
	"petal_storm": {"len": 2.0, "hit": [0.68, 0.72], "swoosh": [0.22, 0.28], "swing": KatanaMoves.PETAL_SWING, "stance": "katana", "weapon": "katana"},
	"axe_throw": {"len": 0.6, "hit": [0.38, 0.44], "stance": "axe", "weapon": "axe"},
	"earthsplitter": {"len": 0.95, "hit": [0.45, 0.52], "stance": "axe", "weapon": "axe"},
	"berserk_roar": {"len": 0.75, "stance": "axe", "weapon": "axe"},
	"maelstrom": {"len": 3.0, "hit": [0.13, 0.95], "stance": "axe", "weapon": "axe"},
	"cross_guard": {"len": 1.0, "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"blade_dance": {"len": 1.0, "hit": [0.1, 0.88], "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"cross_fang": {"len": 0.85, "hit": [0.44, 0.52], "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"steel_tempest": {"len": 2.4, "hit": [0.2, 0.9], "stance": "dual_sword", "weapon": "cutlass", "extras": {"dual": true}},
	"parley_shot": {"len": 0.6, "hit": [0.18, 0.5], "stance": "sword_pistol", "weapon": "cutlass", "extras": {"offhand": "pistol"}},
	"grapeshot": {"len": 0.7, "hit": [0.37, 0.4], "stance": "sword_pistol", "weapon": "cutlass", "extras": {"offhand": "pistol"}},
	"crossfire": {"len": 0.95, "hit": [0.17, 0.53], "stance": "sword_pistol", "weapon": "cutlass", "extras": {"offhand": "pistol"}},
	"broadside": {"len": 2.4, "hit": [0.25, 0.73], "stance": "sword_pistol", "weapon": "cutlass", "extras": {"offhand": "pistol"}},
	"dg_cutthroat": {"len": 0.6, "hit": [0.2, 0.3], "stance": "dagger", "weapon": "dagger"},
	"dg_fan": {"len": 0.7, "hit": [0.35, 0.4], "stance": "dagger", "weapon": "dagger"},
	"dg_slip_guard": {"len": 1.0, "stance": "dagger", "weapon": "dagger"},
	"dg_slip": {"len": 0.55, "hit": [0.16, 0.26], "stance": "dagger", "weapon": "dagger"},
	"red_eclipse": {"len": 2.2, "hit": [0.2, 0.8], "stance": "dagger", "weapon": "dagger"},
	"viper_flurry": {"len": 1.0, "hit": [0.1, 0.84], "stance": "dual_dagger", "weapon": "dagger", "extras": {"dual": true}},
	"scissor_leap": {"len": 0.75, "hit": [0.53, 0.6], "stance": "dual_dagger", "weapon": "dagger", "extras": {"dual": true}},
	"edge_whet": {"len": 0.7, "stance": "dual_dagger", "weapon": "dagger", "extras": {"dual": true}},
	"hundred_fangs": {"len": 2.4, "hit": [0.18, 0.8], "stance": "dual_dagger", "weapon": "dagger", "extras": {"dual": true}},
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
	"dash": {"len": 0.3, "sharp": 50.0, "stance": "sword", "weapon": "cutlass", "extras": {"dash_dir": Vector2(0, 1)},
		"variants": [{"dash_dir": Vector2(1, 0)}, {"dash_dir": Vector2(0, -1)}, {"dash_dir": Vector2(-1, 0), "armed": false}]},
	"roll": {"len": 0.6, "stance": "sword", "weapon": "cutlass"},
	"flip": {"len": 0.45, "stance": "sword", "weapon": "cutlass"},
	# v1.11 moves: the take-offs and the double jump (MovePoses)
	"jump_stand": {"len": 0.42, "stance": "sword", "weapon": "", "extras": {"armed": false, "grounded": false, "vertical_speed": 6.0}},
	"jump_run": {"len": 0.42, "stance": "sword", "weapon": "", "extras": {"armed": false, "grounded": false, "vertical_speed": 6.0, "ground_speed": 6.0}},
	"jump_sprint": {"len": 0.48, "stance": "sword", "weapon": "", "extras": {"armed": false, "grounded": false, "vertical_speed": 6.0, "ground_speed": 9.0}},
	"double_jump": {"len": 0.5, "sharp": 50.0, "stance": "sword", "weapon": "", "extras": {"armed": false, "grounded": false, "vertical_speed": 6.0},
		"variants": [{"armed": true}]},
	"breakfall": {"len": 0.45, "sharp": 45.0, "stance": "sword", "weapon": "", "extras": {"armed": false, "grounded": false, "vertical_speed": -4.0}},
	"hit": {"len": 0.32, "react": true, "stance": "sword", "weapon": "cutlass", "extras": {"push": Vector3(0, 0, 1)},
		"variants": [{"push": Vector3(0, 0, -1)}, {"push": Vector3(1, 0, 0)}]},
	"stagger": {"len": 1.0, "react": true, "stance": "sword", "weapon": "cutlass", "extras": {"push": Vector3(0, 0, 1)},
		"variants": [{"push": Vector3(0, 0, -1)}, {"push": Vector3(1, 0, 0)}, {"push": Vector3(-0.7, 0, 0.7)}]},
	"mantle": {"len": 1.0, "stance": "sword", "weapon": "cutlass"},
	"drink": {"len": 1.0, "stance": "sword", "weapon": "cutlass"},
	"eat": {"len": 1.0, "stance": "sword", "weapon": "cutlass"},
	"wave": {"len": 1.5, "stance": "sword", "weapon": "cutlass"},
	"log_pose": {"len": 0.25, "stance": "sword", "weapon": "cutlass"},
	# --- the held map (MapPoses) ---
	"map_open": {"len": 0.34, "stance": "sword", "weapon": ""},
	"map_hold": {"len": 0.1, "stance": "sword", "weapon": ""},
	"map_away": {"len": 0.2, "stance": "sword", "weapon": ""},
	# --- sailing downtime (DowntimePoses; held, looping: len is the blend in) ---
	"dt_train_blade": {"len": 0.4, "stance": "katana", "weapon": "katana"},
	"dt_train_fist": {"len": 0.4, "stance": "fist", "weapon": ""},
	"dt_train_gun": {"len": 0.4, "stance": "pistol", "weapon": "pistol"},
	"clip_read": {"len": 0.4, "stance": "sword", "weapon": ""},
	"dt_tinker": {"len": 0.4, "stance": "sword", "weapon": ""},
	"dt_sleep": {"len": 0.4, "stance": "sword", "weapon": ""},
	"dt_startle": {"len": 0.5, "stance": "sword", "weapon": ""},
	# --- fishing (FishPoses, the rod and both hands on it FishRod's; Fishing's lengths) ---
	"rod_cast": {"len": 1.1, "stance": "sword", "weapon": ""},
	"rod_wait": {"len": 0.35, "stance": "sword", "weapon": ""},
	"rod_reel": {"len": 1.3, "stance": "sword", "weapon": ""},
	"rod_strike": {"len": 0.8, "stance": "sword", "weapon": ""},
	"rod_land": {"len": 1.2, "stance": "sword", "weapon": ""},
	# --- the emote wheel (EmotePoses) ---
	"emote_wave": {"len": 1.8, "stance": "sword", "weapon": ""},
	"emote_point": {"len": 1.4, "stance": "sword", "weapon": ""},
	"emote_salute": {"len": 1.5, "stance": "sword", "weapon": ""},
	"emote_laugh": {"len": 2.0, "stance": "sword", "weapon": ""},
	"emote_cheer": {"len": 1.6, "stance": "sword", "weapon": ""},
	"emote_dance": {"len": 3.6, "stance": "sword", "weapon": ""},
	"emote_shrug": {"len": 1.4, "stance": "sword", "weapon": ""},
	"emote_bow": {"len": 2.0, "stance": "sword", "weapon": ""},
	"emote_flex": {"len": 2.0, "stance": "sword", "weapon": ""},
	"emote_facepalm": {"len": 1.8, "stance": "sword", "weapon": ""},
	"emote_shanty": {"len": 5.0, "stance": "sword", "weapon": ""},
	# --- playing an instrument (InstrumentPoses, held by Jam; len = the blend in) ---
	"music_concertina": {"len": 0.35, "stance": "sword", "weapon": ""},
	"music_fiddle": {"len": 0.35, "stance": "sword", "weapon": ""},
	"music_whistle": {"len": 0.35, "stance": "sword", "weapon": ""},
	"music_bodhran": {"len": 0.35, "stance": "sword", "weapon": ""},
	"music_gurdy": {"len": 0.35, "stance": "sword", "weapon": ""},
	# --- talk and interact gestures (EmotePoses) ---
	"gesture_talk_a": {"len": 1.4, "stance": "sword", "weapon": ""},
	"gesture_talk_b": {"len": 1.6, "stance": "sword", "weapon": ""},
	"gesture_talk_c": {"len": 1.4, "stance": "sword", "weapon": ""},
	"gesture_nod": {"len": 0.9, "stance": "sword", "weapon": ""},
	"gesture_open": {"len": 1.2, "stance": "sword", "weapon": ""},
	"gesture_pickup": {"len": 1.0, "stance": "sword", "weapon": ""},
	"gesture_lever": {"len": 1.2, "stance": "sword", "weapon": ""},
	"gesture_push": {"len": 1.1, "stance": "sword", "weapon": ""},
	"gesture_reach": {"len": 1.0, "stance": "sword", "weapon": ""},
	"gesture_hand": {"len": 1.3, "stance": "sword", "weapon": ""},
	# --- healing (quick-slot food, rum, tonics: Player.use_item) ---
	"bite": {"len": 0.7, "stance": "sword", "weapon": "cutlass"},
	"swig": {"len": 0.75, "stance": "sword", "weapon": "cutlass"},
	"slurp": {"len": 0.95, "stance": "sword", "weapon": "cutlass"},
	"tonic": {"len": 0.9, "stance": "sword", "weapon": "cutlass"},
	# --- grunts and bosses ---
	"wind_r": {"len": 0.6, "stance": "sword", "weapon": "cutlass"},
	"swing_r": {"len": 0.5, "stance": "sword", "weapon": "cutlass"},
	"wind_l": {"len": 0.32, "stance": "sword", "weapon": "cutlass"},
	"swing_l": {"len": 0.5, "stance": "sword", "weapon": "cutlass"},
	"lunge_wind": {"len": 0.8, "stance": "sword", "weapon": "cutlass"},
	"lunge": {"len": 0.8, "stance": "sword", "weapon": "cutlass"},
	"block": {"len": 0.4, "stance": "sword", "weapon": "cutlass"},
	"sweep_wind": {"len": 0.62, "stance": "sword", "weapon": "cutlass"},
	"sweep": {"len": 0.55, "stance": "sword", "weapon": "cutlass"},
	"shoulder_wind": {"len": 0.95, "stance": "sword", "weapon": "cutlass"},
	"shoulder_rush": {"len": 1.4, "stance": "sword", "weapon": "cutlass"},
	"dash_wind": {"len": 0.85, "stance": "sword", "weapon": "cutlass"},
	"peril_chop": {"len": 2.6, "stance": "sword", "weapon": "cutlass"},
	"slash_down": {"len": 0.5, "stance": "sword", "weapon": "cutlass"},
	"aim_pistol": {"len": 1.3, "stance": "pistol", "weapon": "pistol", "extras": {"auto_point_guns": false}},
	"aim_rifle": {"len": 1.3, "stance": "sword", "weapon": "rifle"},
	"shove": {"len": 0.95, "stance": "sword", "weapon": "rifle"},
}


## When a swing's blade trail (FX.blade_swoosh) is drawn, seconds [from, to): its
## "swoosh" (u), else its hit window; (-1, -1) for actions with neither a swing path nor a
## "swoosh" (they keep the fixed arc effects).
static func swoosh_seconds(n: String) -> Vector2:
	var s := AnimLab.spec(n)
	if not s.has("swing") and not s.has("swoosh"):
		return Vector2(-1, -1)
	var w: Array = s.get("swoosh", s["hit"])
	return Vector2(float(w[0]), float(w[1])) * float(s["len"])


static func length(n: String) -> float:
	return float(AnimLab.spec(n)["len"])


## When the pistol fires in a sword-and-pistol move (its "shot", seconds), or -1.
static func shot_seconds(n: String) -> float:
	var s: Dictionary = AnimLab.spec(n)
	return float(s["shot"]) * float(s["len"]) if s.has("shot") else -1.0


## The hitbox window in seconds at the spec's length (x = opens, y = closes).
static func hit_seconds(n: String) -> Vector2:
	var s: Dictionary = AnimLab.spec(n)
	var h: Array = s["hit"]
	return Vector2(float(h[0]), float(h[1])) * float(s["len"])
