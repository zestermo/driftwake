# Driftwake — dev notes (history)

Long-form history of every round of work: what was built, why, file/function
names, tunings and gotchas. Search it (grep) for a system before changing it;
don't read it top to bottom. CLAUDE.md at the repo root has the short version.
Rounds before 2026-10-05 were done from a cloud workspace (Linux, headless
Godot 4.6.3 + 4.7.2, software rendering), so timings mentioned there are slow.

## Setup
- Repo: github.com/zestermo/driftwake (private). Active branch `multiplayer`. Upstream base ab9e913 (2026-04-07).
- Zach runs **Godot 4.7** on Windows (project.godot features tag "4.7"). Tests also pass on 4.6.3.
- **UI canvas is 640x360** (project stretch mode "viewport", aspect expand; PSX autoload keeps it). Size all UI for 640x360 (slots ~26-30 px, Pixelify 12-16, Silkscreen 8 for tiny text). Screenshot UI WITHOUT forcing CONTENT_SCALE_MODE_DISABLED (tools/invshot_real.gd) or it looks 2x roomier than the player sees.
- Testing gotchas: software-rendered frames are slow (~8 fps in-game), so any `lerp(a, b, k * delta)` must clamp the weight, and short effects (0.26 s trails) are easy to miss in screenshots. New `class_name` scripts need `godot --headless --import` before they resolve. `--script` test scripts must not statically type project classes that reference autoloads (use untyped vars / root.get_node("Settings")). Nodes added in a test's `_initialize()` aren't inside the tree yet (do timing work in `_process`). xvfb screenshots: re-set `root.content_scale_mode = DISABLED` a frame after start (PSX autoload resets it); pass `--script` with an absolute path when running from outside the project dir. The cloud user dir is `~/.local/share/godot/app_userdata/Grand Line Prototype/` (spaces! use `find -print0 | xargs -0`); delete `character.cfg` there to get the first-launch creator.
- New textures: copy import settings from existing ones (mipmaps/generate=true, detect_3d/compress_to=0).

## 2026-10-03: Brinehollow + PSX pass
- **PSX pipeline**: `scripts/psx/psx_settings.gd` autoload `PSX` (low-res viewport stretch 640x360 default; F2 presets, F3 dither, F11/Alt+Enter fullscreen), global shader uniforms `psx_snap_res` / `psx_affine`, `shaders/psx/*` (lit, cutout, post dither, common include). Depth fog env; SSAO/SSIL/volumetrics removed. Mouse look uses `screen_relative`.
- **Materials/meshes**: `PSXMat` (cached ShaderMaterials, `terrain()`), `MeshBuilder` (procedural low-poly with auto winding; `add_loft` rings+profile lofts with optional per-ring profile at ring[5], ring bones and a projected decal region; `add_strip_grid` double-sided cloth sheets; `profile_oct`, `profile_mirror`, `add_profile_disc`, `merge`; `skinned` + `bone` → ARRAY_BONES/WEIGHTS), `Props` factory.
- **psx_lit has NO instance uniforms** (each instance using one reserves 16 slots; GL compat caps at 4096 → ~256 instances). Hit flashes use `tint_mul` on per-object material copies (see dummy_target.gd).
- **Starter island**: `scripts/island/starter_island.gd` (StarterIsland extends Island) replaces random island 0 at world (150,150). Layout: village (0,-62), training (-58,-38), lighthouse hill (78,-30), ruins (-62,58), cove (80,94), camp (65,76). Dialogue tokens `{rumor}`, `{nearest_island}`, `{banked}`, `{captain}` (player name).
- **NPCs/dialogue**: `NPC`, `Dialogue` autoload + `DialogueBox`, player `Talk` state. JSON in `data/dialogue/`. Barks for Tilly/Bram. Export needs `data/dialogue/*.json` in non-resource filters.
- **Assets**: `tools/texture_gen/gen_psx_textures.py` (icons, FX sprites, hair/leather; face_parts.png is now UNUSED — faces are painted at runtime) and `gen_psx_audio.py`; fonts Pixelify Sans + Silkscreen (OFL). UIStyle disables font ligatures.

## 2026-10-03: fullscreen + shadow flicker fixes
- PSX vertex snapping must skip the shadow pass (`if (!IN_SHADOW_PASS)`). Sun: 2-split PSSM, 120 m, atlas 4096.
- Physics interpolation on. Camera rig interpolation OFF, follows `get_global_transform_interpolated()`. Teleports call `reset_physics_interpolation()`.
- Fullscreen unavailable when embedded in the editor's Game tab.

## 2026-10-03: player character + feel passes
- **Humanoid** (`scripts/npc/humanoid.gd`): skeleton Pivot→Hips→thigh/shin, Torso→Neck→Head, arm/forearm→HandL/HandR, HipSocket (built by BodyBuilder). Procedural locomotion + one-shot actions `play(name, dur)`: draw, sheathe, slash_r, slash_l, slash_down, spin_slash, heavy, dash (`dash_dir`), flip, parry, stagger, hit, drink, wave. `hip_y` per style (pivot = hip_y + lift scaled by hip_y/0.9). Joint conventions: arm/leg x+ = forward/up, shin x− = knee bend, arm_l/leg_l z− = out left, arm_r/leg_r z+ = out right, pivot z− = lean right, pivot x− = lean forward.
- **Player**: armed/weapons/hotbar/inventory/use_item; `open_creator(first_time)`. Lean node `PlayerModel/Lean/Body` (slope tilt + camera-frame lean + squash spring). Coyote 0.12 s, jump buffer 0.14 s, variable jump, combo memory 0.9 s. FX autoload (slash trails, dust, sparkles, sfx); CPUParticles3D bursts MUST use `local_coords = true`.
- **Movement**: Zach wants **absolute precise control** (velocity = input × speed every tick; deceleration 160; turn_speed 20; sprint 12, walk 6). Weight is visual only (camera-frame lean: forward smoothed 6/s, sideways 2.5/s, bank from camera yaw rate).
- Style direction: Mario 64 / Hat in Time were references for bounce, not literal — avoid overtly cartoony/arcade. Jump pose both arms up; jump SFX low thump. Dodge = sidestep dash (keeps facing, 3.3 m / 0.3 s, unarmed lead arm out front).
- UI: Settings autoload (user://settings.cfg), GameMenu (Esc → Inventory/Appearance/Options/Controls/Quit; ignores input while `CharacterCreator.active`).

## 2026-10-03: character creator
- **CharacterLook** (`scripts/npc/character_look.gd`): look = Dictionary; option lists + palettes; `base_look()` neutral, `default_look()` captain; `normalize()` converts legacy keys; `random_look`, `save_look/load_look/has_saved` (user://character.cfg). Optional key `style` overrides the art style.
- **CharacterCreator** (`scripts/ui/character_creator.gd`): `open_for(tree, look, first_time, cb)`; SubViewport preview (camera frames from the preview's real head position/scale); tabs Body/Face/Hair/Outfit/Extras; Randomize; name; opens on first launch unless headless.
- Villagers in starter_island.gd use explicit looks (Odile, Gus, Pell, Vey, Nessa, Ambrose, Wren, Tilly, Bram).

## 2026-10-03: anime bodies, wrapped faces, hair/cloth physics, art styles
- Zach's notes: face looked like a flat card → wrap it; heads more anime / One Piece-like; female body looked wrong; wants physics hair + clothing; asked for 3 body-style mockups to pick from.
- **Art styles** (`BodyBuilder.STYLES`; superseded below — shonen is now permanent): **shonen** (head 0.74, leg 1.13, torso 0.86, sh 1.15, wa 0.84, hand 1.18, foot 1.15 → ~6 heads, hips 1.04 m), **chibi** (head 1.1, leg 0.46, torso 0.62 → ~3 heads, hips 0.44 m), **heroic** (head 0.6, leg 1.08 → ~7.5 heads).
- **FacePainter** (`scripts/npc/face_painter.gd`): 64×64 procedural anime face (eyes: sclera, iris w/ darker top, pupil, highlights, lashes; 6 styles incl. dot eyes; brows; mouths incl. toothy grin; marks, stubble, eyepatch), cached per look. Cylindrical UV: u = 0.5 + atan2(x,−z)/(2·80°), v = (0.36 − y/yk)/0.36 (head-local y). Eyes at ±23°, y 0.165; brows above (~0.21); nose shade y 0.112; mouth y 0.072. Head quads with |angle| < 80° and y < 0.36 get the face material (decal over skin tint).
- **Body**: 12-pt per-ring torso profiles P_BODY/P_PEC/P_BUST; fem torso has narrow waist, bust rings, flared pelvis, wider thighs; masc V-taper. Vest/coat shells use `open_body(gap)` (P_BODY with a front gap) so the torso never pokes through. Head profiles P_CHIN_V (fem), P_JAW (masc), P_HEAD; geometric nose (`_front_z`), lofted ears, fringe bangs (`_fringe`), wild = 14 spikes.
- **SpringChains** (`scripts/npc/spring_chains.gd`): child of an anchor joint (head/hips/torso), owns Skeleton3D + skinned MeshInstance. `add_chain(points, stiffness, damping, gravity, collide[])` → per-point bone ids for `add_loft(..., ring_bones)` / `add_strip_grid`. Verlet at fixed 60 Hz (≤4 steps), rest-shape pull, length constraint, capsule colliders (thigh_l/r, shin_l/r, hips, torso, head) defined in BodyBuilder._colliders; `set_bone_global_pose` per segment; snaps to rest on teleport (>2.5 m) or when >30 m from camera (Humanoid._update_physics). Chains: coat-tail sectors (4, open front), skirt sectors (6), long-hair strands (4) + side locks, ponytail, braids, bandana tails, sash tail, apron.
- Perf: 12 worst-case characters / 114 chains ≈ 2.1 ms/frame physics (cloud CPU).
- Mockups: mockup.gd (style full|heads|back), physdemo.gd (run/stop/turn/jump frames → GIF), outputs in /home/claude/tools/mock.

## 2026-10-03: shonen locked in + model fixes
- Zach picked **shonen**. `BodyBuilder.current_style()` always returns it; Options "Art style" row and the `gameplay/art_style` setting are gone; chibi/heroic presets remain only for looks with an explicit `style` key (mockups). shonen leg_gap now 0.1.
- **MeshBuilder caps are geometric**: `cap_top` closes the upper end ring and `cap_bottom` the lower one regardless of ring order (limbs loft top-down). This fixed the open arm/shoulder tops. Hands, thumbs and hair-strand/ponytail/braid tips are capped both ends.
- Arms/coat sleeves start with a small rounded shoulder dome. Thighs start as a closed dome at leg-local y 0.12 (inside the pelvis) and run to −0.45·Ls (past the knee); shins are capped at the top. `_hips_hw()` = max(old width, leg_gap + 0.082/0.088·limb) so the pelvis (6 rings, closing between the legs at ~−0.2) wraps the thigh tops.
- **Head** shortened: rings 0..0.195 unchanged (face), cranium 0.235→0.346 with a flattish rounded top (was up to 0.46). Retuned: hair rim 0.25, cap clip 0.262 (crown rings lifted by off+0.006 to avoid the scalp z-fight/bald spot), back hair ≤0.27, fringe base 0.272 / length 0.052–0.072, hats y0 0.268, bandana 0.245 (knot 0.258), long-hair roots 0.22/0.235, ponytail (0,0.275,0.165), bun 0.335, spikes 0.262+, eyepatch band 0.222–0.24, hood top 0.385, head collider b 0.26. FacePainter Y_TOP stays 0.36. Creator frames head at +0.16·scale.
- **Neck joint**: Torso → Neck (ty(0.6), z 0.012) → Head; neck mesh on Neck. Humanoid splits the posed head rotation 35% neck / 65% head and adds `_update_look()`: idle glances (new random target every 1.6–4.2 s, 30% straight ahead; reduced when talking/armed), tilt, breathing nod; gait stabilisation (head cancels 92% of hips+torso yaw and 70% of roll, unsmoothed so it stays in phase, plus a per-step nod — superseded below); turn lead from global yaw rate (×0.09, clamp 0.5, smoothed). Fades by `_action_w` during actions.
- Tests (cloud /home/claude/tools): feat, feel, dash, chartest 15/15, styletest rewritten (9 checks: shonen hips, chains, neck parenting, no art_style setting, explicit style still builds, idle head moves, running head yaw deviation ≪ torso) — all pass 4.6.3/4.7.2. topview.gd modes top|front|low|face|crown on a magenta background finds holes. Commit 278188c (11 local commits unpushed).

## 2026-10-03: gait, head life, hairlines
- Zach's notes: walk too stiff/upright, not fun; sprint stride too fast and cartoony; head/neck stiff; open neck top at the nape; hairlines too square → wants bangs and tufts. He chose to **keep 6 m/s** default speed with a lively jog-style stride (asked via question).
- **Gait** (`Humanoid._locomotion`): blends walk (≤1.5 m/s weight `walk`), `jog = smoothstep(2, 5.5, spd)`, `run = smoothstep(7, 11.5, spd)`. Cadence cycles/s = 0.75+0.1·spd below 6, 1.35+0.035·(spd−6) above (sprint ≈1.56 cps vs old 2.6). Thigh amp 0.5/0.62/0.92 (knee lifts more in front), knee fold 0.85/1.45/1.95 with heel-kick phase lead, stance give, soft landing bend on the leading leg; arms 0.4/0.62/0.82 with elbows 0.22/1.0/1.4 and forearm trail (phase −0.7); torso lean 0.07/0.13/0.22, shoulder counter-twist, hip drop (c·0.07) with torso counter-roll, chest bob; vertical bob rises at passing for a walk, dips at mid-stance for jog/run; weight shift lift.x. The player's Lean node adds up to 0.28 rad at sprint on top.
- **Head** (`_update_look`): look target is a spring (ω 9.5, ζ 0.62) — glances every 1.4–3.6 s (yaw ±0.7, pitch, tilt), constant drift + breathing, looks toward strafe direction, turn lead; inertia spring (ω 13, ζ 0.4) driven by the body's angular acceleration (×0.12) and the lift's vertical acceleration (×0.32 → nods with steps/landings); gaze steadying 70% yaw / 50% roll; pitch compensates 60% of whole-body lean (global basis). Split: neck = pose·0.4 + look·0.45, head = pose·0.6 + look·0.55. Fixed 120 Hz substeps.
- **Neck mesh** now goes to head-local 0.15 with a capped top (no open ring at the nape).
- **Hair** (`BodyBuilder._hair`): `HAIRLINES` table per style ([deg, y] mirrored: forehead ~0.262, temples, sideburn dip ~0.15 at 75°, up over the ear ~0.245 at 92°, nape 0.05–0.15). `_hair_shell` = 32×7 grid two-sided (inside darker), bottom rows tuck to the scalp (hang 0/0.55/1), normals from (0, 0.06·yk); crown fan. `_hair_pt(a, y, off, hang_k)` uses the real ring profile (`_surf_r` ray/polygon) and hangs straight below the skull at back/sides. `_clump` = pointed strand along the head (sweep, flick, jittered length per look via seeded RNG); `_spike` for cowlicks. Recipes in `_tufts`: short/wild (side-swept bangs, locks before ears, over-ear tufts, 7 nape tufts, crown cowlick unless hatted), crop (short bangs + nape), long/braids (centre-parted bangs + face-framing locks; ears hidden via `hair_hides_ears`), ponytail/bun (swept bangs, side strands). Old `_fringe`/cap/back shell removed; bun moved to (0, 0.3, 0.15).
- Tools: gaitview.gd (treadmill walk/jog/sprint, side|three view, frames → sheet.py contact sheet / GIF), hairshots.gd (all 8 styles, args out yaw set). styletest threshold: running head yaw dev < 0.75 × torso (head is intentionally less locked now). All suites pass 4.6.3/4.7.2; perf 2.15 ms/frame. Commit c10d7c2 (12 local commits unpushed).

## 2026-10-03: camera look-at, skull, weapon heavies, stamina, sprint 9
- **Head look-at**: `Humanoid.look_target` (world) + `look_weight`; in `_update_look` the target's yaw/pitch (body frame, clamp ±1.15 / −0.45..0.5) replaces 85% of idle glances, then the look spring smooths it. Player `_update_head_look()`: aim = head + (cam forward + 0.12 up)·30 while the camera is behind; once the camera is >100° around (back below 80°, hysteresis) `_looking_at_cam` → target = camera position. Off in Talk / helm.
- **Skull**: `_back_ext(prof, kb, kw)` pushes only the back half of the jaw-level ring profiles out (masc kb/kw 1.85/1.3 at y 0.035, 1.33/1.12 at 0.085, 1.08 at 0.135; fem 2.0/1.35, 1.4/1.15, 1.05) — the back of the head reaches jaw level, face untouched.
- **Wrist joint**: "hand_r" added to Humanoid JOINTS/UPPER (rotates only the weapon socket). Blade direction = Rx(arm.x + fore.x + hand.x)·(0,0,−1): sum 0 = blade forward.
- **Heavy attacks** (`heavy_attack_state.gd` STYLES via `style_for(weapon_model)`): cutlass → "thrust" (0.22/0.18/0.35 s, impulse 11, dmg 32, FX trail "thrust" = new straight streak mesh in FX); axe → "axe_heavy" (0.34/0.14/0.42, impulse 4, dmg 40, hitstop 0.12, stagger 0.6, overhead trail + dust ring); others → old "heavy" slam. Axe item id is `boarding_axe` (weapon_model "axe").
- **Stamina** (Player): MAX 100, LIGHT 12, HEAVY 30, DODGE 18; `spend_stamina(cost)` needs ≥ half the cost, may drain to 0; regen 38/s after 0.75 s. Signals `stamina_changed`, `stamina_denied`. Gated in `combat_input()`, light-combo chaining and `wants_dodge()` (all dodge entries). HUD: StaminaRow built in code under HealthRow (green, amber below a light's cost, red flash on refusal). Parry and drawing are free.
- **Sprint 9 m/s** (was 12). Player lean scales by `LEAN_REF_SPEED` 12 (jog lean unchanged). Gait `run = smoothstep(6.3, 8.8)`, cadence above 6 m/s = max(1.35 − 0.03·(spd−6), 1.1) → ~1.26 cps at sprint.
- Tests: new stamtest.gd (12 checks: stamina, refusal, regen, dodge cost, thrust/axe anims, sprint ≈9, look-at behind/front) + all old suites pass on 4.6.3/4.7.2. Tools: heavyshots.gd (action strip with weapon), hudshot.gd. Commit 2eeb430; device verified by hash (13 local commits unpushed).

## 2026-10-03: slimmer torso, sprint stamina, bouncier jog
- `_torso_rings()` hw ×0.95 for the two waist rings, ×0.88 above (depth unchanged); pelvis top ring ×0.95 to match. Shoulder joints: masc `0.22*sh+0.032`, fem `0.174*sh+0.026` (arm tops overlap the shoulders more).
- Sprint drain: `SPRINT_DRAIN` 16/s via `Player.drain_sprint(delta)` in MoveState; `can_sprint()` false when empty or `winded` (cleared at `SPRINT_RECOVER` 30). Regen delay while sprinting = 0.45 s. HUD amber while winded.
- Jog: forward knee swing ×1.3 (`knee_up`, fades out toward sprint), lift_bias uses jog·0.75, knee fold 1.7, bob −0.078 plus a small `pop` (|s|²·0.03), base dip 0.04.
- styletest idle-head check now samples an idle NPC (the player's head follows the camera). stamtest +2 checks (sprint drain, winded stop). All suites pass 4.6.3/4.7.2. Commit c3b6d35; device verified by hash (14 local commits unpushed).

## 2026-10-03: inventory overlay, gear, character sheet, locked double jump
- Zach's picks: world **pauses**, camera swings round to the real character (no separate preview); **real gear items** that change the look + give defense; **core stats + attributes**; double jump **debug unlock only** for now (skill system later).
- **InventoryScreen** (`scripts/ui/inventory_screen.gd`, built by GameMenu as the "inventory" screen; GameMenu hides its dim for it and calls `on_open/on_close`, `focus_bag`, `assign_hotbar`). Paper-doll slots anchored at x 0.075 / 0.355 of the screen, rows from y 0.16 step 0.125, weapon slot at (0.215, 0.80) + "DEF n"; name title over the character; panel anchors x 0.53–0.97, y 0.08–0.84 with Inventory (5×4 bag of 48 px slots, info column, hotbar, footer) and Character tabs; left half is a drag area that turns `player_model`. While open the body runs with PROCESS_MODE_ALWAYS (breathing / looking at the camera, look_weight 0.55).
- **Camera showcase** (`camera_rig.set_showcase(on, facing_yaw)`): yaw facing + PI − 0.42, pitch −0.06, zoom 2.4, h_offset +1.65, v_offset −0.3, target height 0.88, blend 2.6/s, rig PROCESS_MODE_ALWAYS during it, spring-arm collision mask cleared (restored after) so props behind the camera can't ruin the framing; wheel zoom ignored.
- **Gear** (`scripts/loot/gear.gd`): ItemType.GEAR with `gear_slot`, `look` (CharacterLook keys), `defense`, `icon_kind`. `Gear.SLOTS` (head, torso, vest, coat, belt, hands, legs, feet, acc1, acc2), `SLOT_KEYS`, `ACCESSORIES`, names/descriptions/defense tables, color-named items ("Navy Long Coat"); `make()` registers runtime items in `ItemDB.register` (id = kind+style+hash(look)). `items_from_look(look)` → starting gear (+ "extra" accessories to the bag); `compose(appearance, equipped)`; `bare()` smallclothes (masc bare chest, fem sleeveless linen undershirt; linen shorts; barefoot). `is_outfit_key()`.
- **GearIcons**: 24×24 runtime pixel icons from polygons per style in the item's colors (very dark colors lifted), cached.
- **EquipmentComponent** on Player (`equipment`); Player: `appearance`, `refresh_look()` (compose → apply_look → save_look → _recalc_stats), `_wear_outfit_of(look)`, `equip_gear_from_bag(idx)` (swaps into the same bag slot), `unequip_gear(slot)`, `attributes` {strength, agility, endurance} = 5, `max_stamina` (100 + (END−5)·8), max health 100 + (END−5)·10, `damage_multiplier` × (1 + (STR−5)·0.05), `defense()`, `damage_reduction()` = d/(d+40), hurtbox hit → reduced damage. InventoryComponent: `has_room`, `insert_item`, `take_at`; gear never auto-goes to the hotbar.
- **Creator**: first time → outfit becomes starting gear; later (Appearance) Outfit/Extras tabs and hat rows hidden, only non-outfit keys applied, randomize keeps gear.
- **Abilities**: `abilities` {double_jump: false}, `set_ability()` sets `max_jumps` 1/2; F9 toggles in debug builds (OS.is_debug_build). FallState drops the ground jump once coyote time ends (no free air jump after walking off a ledge).
- Island chests now hold: Ruin-Warden's Pauldron (ruins), Leather Gloves (camp), Red Bandana (hill), Weathered Green Vest (cove).
- Tests: new invtest.gd (20 checks); feat unlocks the double jump before testing it; chartest expects Appearance to keep gear. All 7 suites pass 4.6.3/4.7.2. Tools: invshot.gd (overlay screenshots; finishes the first-launch creator), iconsheet.gd. Commit ce1b321; device verified by hash (15 local commits unpushed).

## 2026-10-03: inventory scale fix, knees-up fall, sprint bounce, shake
- Zach saw the inventory hanging off the right edge: it had been laid out at 1280x720 (my screenshots forced content scale off). Re-laid out for 640x360: SLOT 28 / DOLL_SLOT 30 via `_small_slot` (icon pad matched to 24 px icons), `_tiny()` Silkscreen 8 labels, info/rows Pixelify 12, panel anchors x 0.5–0.985, y 0.05–0.95 with clip_contents; doll columns x 0.05 / 0.33, rows 0.15 + i·0.135; weapon slot under the left column (0.05, 0.83), name centered at y 0.86, DEF at (0.33, 0.845). Doll slots SIZE_SHRINK_CENTER (the "Accessory" label was stretching them).
- HUD is paused while menus are open, so GameMenu calls group "hud" `set_menu_open(bool)` (hides HUD hotbar, toast, banner).
- Bug found: the squash/stretch spring (explicit Euler) blew up on a long frame (first frame after the creator's pause) and froze the character at 1.5x tall. Now fixed 120 Hz substeps (delta capped 0.1) + `Player.reset_squash()` on inventory open.
- Fall pose (Humanoid air, vy < −2): legs 1.75 / 1.5 rad, shins −2.2 / −2.05 (knees up in front of the chest), arms 0.45 forward + out, torso −0.12, flail 0.12.
- Sprint bob −0.07 (was −0.045) and pop |s|²·0.035 now applies to the sprint too.
- Camera shake: `Player.DASH_SHAKE` 0.06 in DodgeState.enter; `SPRINT_SHAKE` 0.045 + squash via `Player.on_sprint_start()` from MoveState when sprint begins (suppressed if sprinting was seen within 0.6 s, so landings mid-sprint don't shake). Uses CombatManager.apply_camera_shake (honours the camera shake option).
- All 7 suites pass 4.6.3/4.7.2. Commit 7f349cf; device verified by hash (16 local commits unpushed).

## 2026-10-03: village rework, tavern + market, scuttlebugs, hitstun, ragdolls
- `Buildings` (scripts/props/buildings.gd): `house(spec)` (w, d, h, floors/h2/jetty, wall/wall2, roof gable|gable_front|hip|shed, porch, lean_to, chimney, stilts, foundation), `tavern_hall()` (enterable; markers Barkeep/Patron1-3/Door), `stall(kind)` (fish/fruit/cloth/pots, "Vendor" marker), `tiled_box` (splits big boxes so PSX affine warp stays small). Village: `_house()` sets stone footing down to the lowest ground; market at `MARKET`; keeper's hut on the enlarged HILL flat zone. NPC cfg `"seated": true` -> `Humanoid.seated`.
- Combat: `HitData.knockdown`. Player heavy attacks set it. `StateMachine.force_state()`. Player `_on_hit_received`: parry -> `attacker.parried(player)`, light hit -> Stagger with `flinch` (0.12-0.22 s, "hit" anim), knockdown -> new `Downed` state, death -> Downed{dead}. GameManager respawn delay 3 s; respawn's forced Idle exits Downed (resets the rig).
- `Ragdoll` (scripts/combat/ragdoll.gd): RigidBody3D parts (layer 1024, mask 1) + Generic6DOFJoint3D; limits given as the rig node's local euler range, converted relative to the start pose. **Jolt sign: LIMIT_SIGN = -1** (verified with tools/ragsign.gd). Bodies drive node global transforms each frame (`get_global_transform_interpolated`).
- Humanoid: `start_ragdoll(v, spin)` (10 parts), `ragdoll_rest_info()`, `begin_getup(face_up, dur, hips_xform)` (pivot ±PI/2 lying, "getup" action keys: face up flat->sit->crouch->stand; face down prone->kneel->crouch->stand), `reset_pose()`. Player `get_up_from_ragdoll()` turns PlayerModel (face up: forward = -head_dir) and `reset_lean()`. F10 (debug) knocks you down.
- `Scuttlebug` (scripts/enemies/scuttlebug.gd, built in code): states WANDER/NOTICE/APPROACH/REAR/RAM/RECOVER/DAZED/HITSTUN/DOWN/DEAD (test scripts must use the ints 0-9, not the enum — class references the FX autoload). Small 30 hp ram 10; big (x1.45, red) 75 hp ram 18 + knockdown. Wall bonk = 2 s daze. DOWN: shell+head ragdoll, flip attempts steer angular velocity toward upright (`_righting`). Dead: rolled onto its back, legs curl, sinks after 3.2 s. `ScuttlebugNest` (4 burrows along the ruins path, found by `_find_burrow_spot`), respawn 45 s when player > 24 m away. `CoinPickup.spawn()` gold that magnets to the player.
- New sfx (gen_psx_audio.py): chitter, bug_hiss, thud, coin. Note: the device delivery path appends a C2PA chunk to .wav files (audio data identical, so the sha1 check fails for wavs only; harmless).
- Tests: tools/ragtest.gd, bugtest.gd, bigtest.gd (+ all 7 old suites) pass on 4.6.3/4.7.2. Render tools: ragshot.gd (knockdown frames), bugshot.gd (pose|posebig|fight|down|die), sheet2.py.
- Commit d5e69c6 (17 local commits unpushed).

## 2026-10-03: ship rework
- Ship is an `AnimatableBody3D` (sync_to_physics, moving platform) with its own boat model in `_physics_process`: internal `_pos`/`_heading` state (**external transform sets get overwritten by the physics sync — use `Ship.place(pos, yaw)`**, world_generator does). Sails: MAX_SPEED 13, ACCEL 2.6, BRAKE 4, reverse 3; rudder smoothed, turn MAX_TURN 0.55 × flow(speed/4, min 0.3). `test_move` + slide along shores/docks, thud + shake on head-on hits.
- Swell: waves sampled at bow/stern (±5.8), sides (±2.7), midships; heave = lerp(mean, center, 0.5) × 0.45 + FREEBOARD 0.85; pitch atan(Δ/11.6)·0.35 (±0.045), roll atan(Δ/5.4)·0.3 (±0.05) + turn heel; critically damped springs (ω 2.2 / 2.6). Moored heave ~0.35 m, tilt < 0.09 rad.
- Collision (built in `_build_collision`): convex hull with deck top at DECK_Y 0.32, bulwarks 0.75 high, transom, cabin+roof, mast, helm post, chest. BuoyancyComponent and the old box/DeckCollider are deleted.
- Helm: captain visible (`Humanoid.at_helm`, `helm_steer` = ship.rudder), pinned to HelmPosition (y 0.33) facing the bow, lean follows the deck (Player._update_lean HELM branch), grounded forced true at helm. Wheel is its own node (`Ship.wheel`, rotation.z = −rudder·2.4). Exit leaves you standing at the wheel. ShipCamera is top_level, follows interpolated position/heading, `Ship.cam_yaw` is the mouse offset.
- `FX.splash()` bow spray / wake. Test: tools/shiptest.gd; render: tools/helmshot.gd.
- Commit ecaf47a (18 local commits unpushed). Zach should delete scripts/ship/buoyancy_component.gd(+.uid) on his PC (deleted in git, can't delete remotely).

## 2026-10-04: water & swimming
- Zach chose: surface swim + short dive; stamina drain then health loss; ladders + low-ledge climb.
- Player: `water_surface()`, `water_depth()`, `wade_mult()` (MoveState speed), `SWIM_ENTER_DEPTH` 1.15 / `SWIM_EXIT_DEPTH` 0.95; `_physics_process` forces "Swim" from `SWIM_FROM_STATES`. `drain_stamina()`, `stamina_regen_mult`. Wading footsteps splash.
- SwimState: float spring (k 14, c 7.5) to hips depth lerp(0.42 tread, 0.34 moving) below the surface; speeds 3.2 / 4.6 (Shift) / 2.0 exhausted; dive (Ctrl, +12 stamina, 8/s, 0.5-2.6 s, 1.7 m down); drain 3.5/13/s, tread regen 15%; exhausted (≤0.5) sticky until 25 → −5 HP/s. Space: ladder in reach or `_find_ledge` (walkable top 0.15-1.5 m above water, capsule room check). Exits to Move/Idle on floor in shallow water.
- ClimbState: keyframed path in the anchor's local frame (ladder node or ledge collider, e.g. the moving ship). `Ladder` (scripts/interaction/ladder.gd; group "ladders"; origin at the top surface, +Z = water side; length/rail/deck_depth) — 2 on the ship (±3.0, DECK_Y, 0.6, rail 0.75), 3 at the dock end. Interactable.usable_in_water; InteractionComponent ignores others while swimming/climbing; helm needs `is_free()`.
- Humanoid: swimming/diving/climbing/climb_phase poses (`_swim_pose`), "mantle" action. Camera rig lifts itself above the waves. New sfx: splash.
- Test: tools/swimtest.gd (ledge check is relative to the block top — waves move ±1.1 m). Render: tools/swimshot.gd (shot camera must sit under two Node3Ds or PlayerState camera-relative input crashes).
- Commit a51697b (19 local commits unpushed).

## 2026-10-04: pirate grunts + smugglers camp
- Zach chose: smugglers' camp at the cove; swordsman with tells + guard; fair fight (~110 HP, hits 12, max 2 attackers); varied crew looks.
- `PirateGrunt` (scripts/enemies/pirate_grunt.gd, CharacterBody3D, body layer 4|2048, mask 1|2|2048; Facing node holds the Humanoid + sword Hitbox 64/128; Hurtbox 32/16 owner = grunt). States IDLE ALERT CHASE CIRCLE CLOSE WIND SWING RECOVER BLOCK STAGGER HITSTUN DOWN GETUP RETURN DEAD (= ints 0-14 in tests). `crew_look(rng)` = random_look + red sash CLOTH[13]. Combo: wind_r 0.6 → swing_r → wind_l 0.32 → swing_l, hitbox 0.06-0.22 of each swing; lunge: lunge_wind 0.7 → 9 m/s for 0.32 s; glint (FX.sparkle + blip_high) at 55% of wind. Guard: front light hits blocked while CIRCLE/CHASE/ALERT/BLOCK/CLOSE, GUARD_BLOCKS 3 then break → 1.1 s stagger; riposte (35%, always after 2 blocks) skips the token. Parry → 1.5 s stagger. Knockdown → humanoid ragdoll → begin_getup. Death → ragdoll, 3-6 coins, sinks after 8 s. `_lost()` → RETURN (heals, sheathes). Stuck detection → 0.9 s detour sidestep.
- `GruntCamp`: specs (posts in island-local, converted with to_global), tokens max 2, `alert_all` within 22 m, full respawn after 120 s when player ≥ 50 m away.
- Humanoid actions added: wind_r/l, swing_r/l, lunge_wind, lunge, block (E_* pose consts).
- starter_island: `SMUGGLERS := (46,110)` flat zone, `_tent()`/`_log()` helpers (beach camp refactored), `_build_smugglers_camp()` (2 sitters, sentry facing CAMP, patroller, boat guard; strongbox LootBag with treasure x2, gold x6, Smuggler Captain's Tricorn).
- Player collision_mask now 2049 (World + EnemySolid). project.godot names layer 11 Ragdoll, 12 EnemySolid.
- Swim float spring now feed-forwards the surface velocity (head was dipping on rising waves).
- Tests: tools/grunttest.gd (+ all others) pass on both versions. Render: tools/gruntshot.gd.
- Commit 32127b9 (20 local commits unpushed).

## 2026-10-04: grunt firearms, heavy glow, parry window
- Lunge = grunt heavy attack: wind 0.8 s, weapon `material_override` = yellow glow (PSXMat metal + emission) for HEAVY_GLOW 1 s, `_hit_heavy` 16 dmg. ParryState.parry_window 0.26.
- New grunt states appended (tests use ints): AIM 15, KEEP 16, REPOSITION 17, SHOVE 18. `role` "sword"/"rifle" (cfg "role"); riflemen = sentry + boat guard; `_fight_state()` → KEEP for rifle, CIRCLE for sword. Riflemen: `humanoid.carry = "rifle"`, no guard, notice range ×1.4, keep 10-16 m, shot every ~8 s, reposition (candidates ground-snapped by raycast, need LOS), shove within 3 m (6 dmg, kb 9, cd 5 s).
- Pistol: `_want_pistol` (sword role, dist ≥ 9.1, 35%/s, cd 10 s, LOS, `_guns_free` < 2 aiming). Weapon swapped with `set_weapon(pistol)` and back.
- Aim: `_aim_point` lerps (7/s) to the chest until `_aim_len - _lock_len`, then locked (line red → white). `_fire`: ray to world for the end point; hit if `Geometry3D.get_closest_points_between_segments` muzzle→end vs player feet→head < 0.45 and hurtbox monitorable (dodge passes). HitData.ranged; parrying a bullet calls parried() while grunt is in AIM → ignored (deflect, no stagger). Grunt `process_priority = 10` so its `_process` points the gun after the humanoid poses (Basis.looking_at aim point; rifle carry basis facing*(0.75,0.25,0.85)). Aim line = top_level BoxMesh scaled along the segment, hidden 0.1 s after firing / on leaving AIM.
- Props.weapon_mesh "pistol", "rifle"; Humanoid actions aim_pistol, aim_rifle (use `aim_pitch`), shove; gunshot + blip_low sfx.
- Test: tools/guntest.gd (sidestep keeps the player on land — the camp is on the shore). Render: tools/gunshot_r.gd.
- Commit b41db7c (21 local commits unpushed).

## 2026-10-04: plunge attack, two-handed riflemen, neck, ragdoll-shooting fix
- Bug fixed: grunt `_on_hit` while DOWN/GETUP used to fall through to HITSTUN → fight resumed with the body still a ragdoll (riflemen shot from the ground). Now DOWN/GETUP hits only damage (+ ragdoll push / re-knockdown on heavy); `_physics_process` also forces DOWN whenever `humanoid.ragdoll` exists.
- Shove HitData.knockdown = true (kb 7). Tests: guntest expects Downed.
- `Humanoid.reach_left_hand(target, pole)`: analytic two-bone IK (plane of shoulder→target & pole; forearm bends via local +x toward the arm's -Z). Riflemen call it in their `_process` after pointing the gun, target = furthest forestock point (z -0.6..-0.2 on the weapon) within 95% reach; pole = facing*(-1,-1.3,0.4). aim_rifle right arm pulled in (0.75, 0.65, 0.4)/fore 1.65/hand -2.4.
- Shonen neck 0.9 → 0.55.
- Dash (armed): `reach` (forward/leftward) → arm_l (1.2, 0, -0.95) fore 0.1; `fling` (back/rightward) → (0.35, 0, -1.35) fore 0.3.
- PlungeState ("Plunge" node): Jump/Fall call `air_attack_input()` (PlayerState): needs can_attack + `Player.height_above_ground()` ≥ 0.9 (else the press stays buffered), PLUNGE_COST 16. Hang 0.16 s → dive 22 m/s with sword hitbox (22 dmg) → land: dust ring, shake, sphere query (r 2.4, mask 32, areas) shockwave 8 dmg to hurtboxes not already hit, recovery 0.38 s. Humanoid actions plunge_air / plunge_land. "Plunge" is in SWIM_FROM_STATES.
- Tests: tools/fixtest.gd (+ all others) pass on both versions. Renders: tools/moveshot.gd, dashpose.gd (standalone humanoid poses — capture by time, xvfb frames are slow).
- Commit 4d9f7f9 (22 local commits unpushed).

## 2026-10-04: faint aim lines + gun smoke, jump lean, diagonal legs
- Aim line colours: AIM_TRACK (0.82 grey, a 0.16), AIM_LOCKED (a 0.34), AIM_FIRE (white a 0.7); `_locked` flag (don't key off colour). Fire FX: FX.impact + FX.muzzle_sparks(pos, dir, n) + FX.smoke(pos, n, size, life) cloud at the muzzle + puffs every ~1.6 m along the shot (max 18, 1.3 s).
- Player `air_lean` 0.16: in Jump/Fall, `tilt += hv_dir * air_lean * clamp(vy/jump_force) * travel` after the airborne 0.4 scale (travel = (speed-1)/4 clamped) → forward on the rise, back on the way down.
- Humanoid gait: legs swing along `local_move * dir_sign` (x = swing·|mv.y|, z = swing·mv.x·0.6 clamped so a leg never crosses: leg_l z ≤ 0.08, leg_r z ≥ -0.08). Measured with tools/gaitnum.gd (foot-path PCA axis vs travel, crossing frames). Old combat diagonal: axis·travel 0.46, feet crossed by 25 cm.
- Commit cc6321b (23 local commits unpushed).

## 2026-10-04: water for grunts + floating ragdolls
- Ragdoll._physics_process: per-part buoyancy (1.3 x weight, ramped over the last 15 cm below the surface) + water drag; splash on root entry (FX via get_node, chartest loads Ragdoll without autoloads). `in_water`, `root_depth()`.
- Ocean.depth_at(pos, exclude, calm=false): surface (or mean level 0 if calm) minus world-layer ground; INF over open water. Waves are +-1.1 m, so grunt avoidance uses calm depth > 0 (WADE_MAX 0.0).
- Player Downed: in deep water the root follows the hips in y; recovers via player.recover_into_swim() (Humanoid.recover_from_ragdoll: soft pose blend, no action) once hips < 0.45 under and rising, or after 4 s. Swim.enter takes {"quiet": true}.
- Grunt state SWIM = 19: same depths and spring as the player, SWIM_SPEED 2.6, `_find_shore` (16 dirs x radii, beach depth -0.45..0.6, normal y > 0.75, line check, blacklists a stuck target), exits on floor at depth < 0.95 to CHASE/KEEP or RETURN. Hits in SWIM: damage + push; knockdown → floating ragdoll → back to SWIM. `_avoid_water(want)` runs on every state except HITSTUN/STAGGER.
- Test: tools/watertest.gd (17 checks). Render: tools/watershot.gd (grunt thrown off the beach, player knocked under). All 15 suites pass 4.6.3/4.7.2.

## 2026-10-04: Ember Fruit, skill bar, braced ragdolls, foot IK, parry sparks
- Zach's picks: Ember Fruit first; canon curse (sink + drown); fruit in the smugglers' strongbox, eaten from the bag with a confirm; 4 skills + ultimate + items on the bar with a separate energy resource.
- Keys: skills 1-4 (skill_1..4), ultimate R, item hotbar 5-9 (hotbar_1..5), ready weapon moved to Z. Inventory assigns hotbar with 5-9.
- scripts/powers: DevilFruits (data; icon = assets/textures/icons/skill_<id>.png), PowerComponent (player.power; energy 100, regen 7/s, +4 per sword hit; ult 0-100 from damage x0.3, locked 6 s after casting the ult; suppressed() waist-deep/swimming; blast/burn_area/enemies_in (hurtbox areas, layer 32); ignite_burnables), Fireball, FireZone (group fire_zones, contains(), grunts avoid), BurnStatus (child "Burn", dot ticks every 0.5 s).
- HitData: `dot` (no flinch; grunt + scuttlebug handle), `unblockable` (bypasses grunt guard). Hitbox signal hit_landed(target, data).
- Player state "Skill" (skill_state.gd) runs the timelines: fire_fist, flame_dash, fire_ring, ember_field, inferno. Humanoid actions fire_punch, flame_dash, fire_ring, fire_plant, inferno, eat.
- Curse: swim_state `_cursed` → `_sink_update` (sink 1.6 m/s, seabed walk, drown 10 HP/s after 1 s under, ladder still works). Downed sets ragdoll.buoyancy 0.2.
- Burnable (scripts/world): thornbrush walls (4) around JUNGLE_STASH; texture psx/thornbrush.png.
- SkillBar (scripts/ui/skill_bar.gd) replaces the old top-left HP/stamina and the item hotbar; toast/prompt moved up. Textures must be loaded OUTSIDE _draw (loading inside _draw renders white) — icons cached in _load_icons.
- Ragdoll muscles: set_targets(BRACE, BRACE_WIGGLE), stiffness/stiffness_target, relax() on death; start_ragdoll(v, spin, alive). PD torque in parent frame, inertia-scaled.
- Humanoid foot IK (_foot_ik after leg rotations): ray under each ankle, hips drop to lower foot, 2-bone solve in thigh parent's y/z; off when airborne/swim/climb/seated/helm/ragdoll/getup; skips >40 m from camera.
- Parry: FX.parry_sparks + "parry" sound. New sounds: parry, fire_burst, fire_blast, crunch.
- Tests: tools/powertest.gd (43 checks; keeps grunts passive by pinning their cooldowns). grunttest get-up check accepts AIM/KEEP/REPOSITION. All 16 suites pass 4.6.3/4.7.2. Renders: powershot.gd (keep content scale on for HUD shots), ikshot.gd, thornshot.gd, ragshot.gd diag mode.


## 2026-10-04: skill map, leveling, fighting styles, fruit types, save game
- Zach's picks: phased (core systems now, full sword/gun/Haki/fruit trees next round); one big constellation; Ember = Logia, new Wolf (Zoan) and Vine (Paramecia: snare root, swing, Photosynthesis passive); save progress.
- scripts/progression: `Skills` (ALL: actives with tree/cost/cooldown/needs sword|gun/fruit/ult; icon = icons/skill_<id>.png), `SkillTree` (constellation nodes `_add(id,name,kind,region,pos,links,effects,desc,req,skill,cost)`; regions Mobility -125°, Survival -55°, Sword 180°, Gun 0°, Armament 125°, Observation 55°, Fruit 90°; core ring r82 + web r128; Haki needs L10), `Progression` (player child: level/xp/skill_points/owned; xp_to_next = round(50·lv^1.3), MAX 40, 2 SP/level; can_learn reasons; grant_fruit owns root + cost-0 nodes; stat()/has_flag(); to_dict/from_dict).
- XP: grunts 45/55, scuttlebugs 25/120, via GameManager.award_xp. F9 (debug) = +1 level.
- PowerComponent is loadout-driven: `loadout` [5] of skill ids (slot 4 = ult only), cooldowns keyed by id, buffs dict, max_energy = 100 + stat; power_multiplier = 1 + damage_pct + 0.02/level + fire_pct + coat 0.3 + howl 0.25. can_cast reasons incl. "Needs a sword"/"Needs a pistol" (draws weapon quickly).
- Styles (`Player.style()`): fist, sword, dual_sword, pistol, dual_pistol, claw (wolf hybrid). Off-hand: right-click a bag weapon / auto when you pick up a second. Light/heavy STYLES tables; guns route light attack to "Shoot" (shoot_state: 14 dmg single / 11 dual alternating, ammo 2 + extra_shots, reload 1.1/1.5 s, aim assist 0.2 rad); gun kata heavy (4 shots within 6 m).
- Fruits (DevilFruits.FRUITS): ember logia (intangible dash: full i-frames, EnemySolid bit off, body hidden; Fire Fist + Blazing Ring), wolf zoan (V toggles hybrid: fur re-skin, ears/muzzle/claws/tail via Humanoid.set_beast, +15% speed; Rending Fang + Pounce), vine paramecia (Photosynthesis regen; Vine Swing (swing_state pendulum) + Vine Snare (Projectile "seed", roots 3 s); Thorn Whip later). Locations: ember = smugglers' strongbox, wolf = ruins chest, vine = hill chest; pistol in the camp chest; grunts drop pistols/cutlasses.
- Skill map UI (`SkillMapScreen`, K or pause menu): drag/WASD pan, wheel/QE zoom, click/Enter/F learn, 1-4/R assign actives, right-click a bar slot to clear.
- SaveGame (user://savegame.dat via store_var; disabled under --script unless use_test_file): progression, power, hybrid, health, items (gear rebuilt by Gear.make), hotbar, worn, weapons, banked, opened chests (LootBag.save_id), burned brush, player/ship pos. Saves on level-up, fruit, banking, every 120 s, quit. GameManager loads 2 frames after start.
- Tests: tools/progtest.gd (~60 checks incl. save/load round trip). All 17 suites pass 4.6.3/4.7.2. Renders: styleshot.gd, styleshot2.gd, wolfpose.gd.


## 2026-10-04: title screen + 3 slots, boxing stance, vine swing rework, grapple, energy
- Zach's reports: skill map showed a dotted constellation with no icons or names (new PNGs not yet imported by his editor; names were hidden at default zoom); abilities didn't seem to cost energy (regen 7/s refilled during cooldowns); unarmed stance/punches oriented wrong. Picks: title screen + 3 slots; big bugs + bosses are "heavy" for the grapple.
- Skills.icon caches and falls back to Image.load_from_file when the import is missing. Skill map: opaque bg, names always shown for actives/ults/roots, PANEL_W 160, region labels r470 with the Haki "awakens at level 10" under them, hint line at 0 SP.
- Energy: ENERGY_REGEN 2.5/s, REGEN_DELAY 1.5 s after a cast, ENERGY_PER_HIT 5; PowerComponent.energy_spent signal -> SkillBar orb chip (_en_chip/_en_hold) + white flash.
- SaveGame: SLOTS 3 (user://save_N.dat), static `slot` / `new_game`, `begin(slot, fresh, tree)` (wipes the slot on fresh, GameManager.reset_session, clears Dialogue flags), `ensure_session()` (world launched directly: latest slot or new game in slot 1), `migrate()` (savegame.dat -> slot 1), `slot_info(i)` (name, level, fruit, play_time, saved_at), `latest_slot`, `peek_look`, `format_time`, `use_test_dir(dir)` for tests. VERSION 2 saves meta, look, play_time, Dialogue flags/_talked. Player._build_body: first_launch = SaveGame.new_game when enabled; the creator callback saves. GameManager.play_time (counted unpaused), autosave skipped while the creator is open.
- TitleScreen (scenes/ui/title_screen.tscn = main scene; group "title_screen"; procedural dusk sea + brig) and SaveSlotList (rows + Delete, confirm for overwrite/delete/in-game load). GameMenu: `_on_title()` (only Options/Esc there), `_back()`, pause items Save Game / Load Game ("load" screen) / Quit to Title / Quit Game. Ocean manager re-reads the ocean material every frame (new world scenes).
- Unarmed: FIST_GUARD (hips -0.5, torso -0.12, head +0.58, lead arm (1.15,0.5,-0.12)/fore 1.45, rear (0.75,0.75,0.12)/fore 2.3); guard "hips" eases out while walking; fist stance legs (0.12,0,-0.2)/(-0.12,0,0.2). New jab/cross/hook/roundhouse (pivot y +1.35 so the right leg lands in front)/flying_kick poses. Joint math: Node3D YXZ euler; arm x+ = forward/up, z+ = toward +X for every limb, Ry(+) swings a forward limb toward -X. Light attack fist "starts"/"ends" per hit and "winds"; FX.punch_wind(from, dir, len, color, big) (speed-line boxes + air ring); heavy kick windup 0.33 + wind.
- Hands: Humanoid.swappable_hands (player only, set before setup) builds "Mitten" + hidden "Fist" meshes under each forearm; set_fists() auto in _process when stance "fist" + armed + no weapon in hand. NPCs keep the merged hand (chartest max 16 mesh instances).
- Vine: GrapplePoints (tree crowns, registered by StarterIsland._add_tree and WorldGenerator decor via crown_of(mesh AABB); cleared in WorldGenerator._ready; best(from, dir, origin, max_dist, max_angle, min_y)). SkillState._vine_target(): enemy within 0.16 rad + line of sight -> crown within 0.2 rad -> world hit above you -> crown within 0.42 rad. Light enemies (vine_weight()) get vine_yank(to, dmg) (grunt: STAGGER + _yank velocity override; bug: DAZED); heavy -> Swing {"zip": e} (24 m/s, crash hit 14, bounce). VineRope node (shoots out, follows, retracts). FX.arm_vines(h, "r"/"l"/"both", secs) + wither_vines.
- SwingState: feet-to-anchor rope (GRIP 1.95), _clearance() caps the length so the arc clears the ground (fast reel 12 m/s), pumping, ends on floor after 0.6 s. Player.align_up/align_w/align_hold in _update_lean (max 80 deg; decays 1/s in the air, 4.5/s within 2.5 m of the ground, 0 on landing). Humanoid.dangle + dangle_g/dangle_v -> _update_dangle springs for leg_l/leg_r/arm_l (DANGLE_LIMBS); poses vine_hang (uses _dg), vine_shoot, vine_release (played on let-go), vine_zip, vine_pull.
- Tests: tools/savetest.gd (26), tools/vinetest.gd (31). grunttest accepts SWIM after a knockdown and waits 20 s for the walk home (both were flaky). Pose bench: tools/posebench.gd (<out> <stance> <weapon|none> <action:u,...> <views>; PB_BASE=1 for a plain look) + sheet3.py. Renders: mapshot.gd, titleshot.gd, vineshot.gd (use World/CameraRig/SpringArm3D/Camera3D explicitly and aim from the rig pivot).


## 2026-10-04: menus fit, skill map tabs + key fix, quick items, block, red unblockables, Haki look, afterglow, fall damage, shoulders
- Zach's reports: menus hanging off the screen; skill map sometimes off-center; after equipping skills the 1-4 keys kept reassigning instead of casting. Asked: quick-consumable section instead of a hotbar (no weapons, not in the inventory), fruit power afterglow (vine wraps + leaves), fall damage, Devil Fruit tab, shoulders into the torso, haki sound + black/purple arm + purple trails, hold parry to block, red unblockable enemy heavies broken by haki, fist thumbs, vine ground effects on dash.
- Key bug: SkillMapScreen._input/_process checked its own `visible` (stays true inside GameMenu's hidden root) -> it swallowed 1-4/R/Q/E/F/Enter in-game. Now is_visible_in_tree().
- UI: the PSX presets used to shrink the whole canvas (480x270/320x180) so 640x360 layouts hung off. Now content_scale_size is always 640x360 and psx_post.gdshader pixelates the 3D (pixelate + pixel_res from PSX.pixel_res(); snap res uses it too). UIStyle: default font 12, buttons pad 5, label() default 12, title 22, fit_to_screen(c, margin) (scale-down fallback). GameMenu: pause 190 wide/sep 3, options 420x210 scroll, controls in 4 columns, _fit_current() on open + resize, _back() for Options/Controls on the title.
- Skill map: _tab 0/1 (header tab buttons, Tab key), set_tab(), _frame_tab() on every open (main: pan 0, zoom fits r470; fruit: bbox of your fruit's nodes), fruit nodes only in tab 1; long node names drop to 8 px in the side panel.
- Quick items: InventoryComponent.HOTBAR_SIZE 3 (hotbar = quick slots, ids, consumables only via quick_ok()); hotbar_4/5 actions removed; Player.activate_hotbar uses consumables only; inventory no longer shows a hotbar (5-7 over a consumable assigns); SkillBar W 352 with a divider and counts; SaveGame filters old hotbar ids.
- FX: arm_vines/leg_vines/limb_vines (holders "ArmVines", add_child(..., true)), power_aura(h, fruit, secs) (vine: limb vines + leaf particles from a code-made leaf texture; ember: hand flames + embers; wolf: wisps + motes), ground_vines(pos, dir), punch_wind reused for the haki burst. PowerComponent.linger(id) from SkillState.exit (not when going to Swing) and SwingState.exit; wolf aura on set_hybrid(true). DodgeState spawns ground vines every 0.9 m with the Vine Fruit.
- Haki: Player.update_coat_visual overrides arm/forearm/hand meshes (weapon arm; both arms for fist/claw/dual) with PSXMat.lit black + purple emission (material_overlay didn't render over PSX-snapped verts), blade PSXMat metal black/purple; HAKI_BLACK/HAKI_TRAIL/HAKI_SPARK consts, purple sparks while coated; sounds haki/block/peril in gen_psx_audio.py. HitData.haki (melee_hit with coat, armament heavies).
- Block: BlockState ("Block" node) entered from Parry when parry is still held after the window; Player.is_blocking; frontal (dot > 0.25) non-unblockable hits -> absorb() (stamina max(dmg*1.1, 8), push, sparks, "block" sound) or guard break (Stagger 0.6 + half damage). Humanoid guard_block/guard_block_hit poses (_block_pose per stance, upper body). Parry ignores unblockable hits.
- Grunt peril attack: _attack "peril" (40% when _peril_cd <= 0, cd 9-14 s), wind PERIL_WIND 1.0 with humanoid "axe_heavy" (dur 2.6) spanning wind+swing, _set_peril() red overlay on all humanoid meshes (pulsing static material) + red-hot blade, peril sting; super armor during wind/early swing; hit.haki -> stagger 1.6; _hit_peril 24 dmg knockdown unblockable.
- Fall damage: SAFE_FALL_SPEED 18 (falling uses 1.6x gravity: ~5 m), 5.3 per m/s over (8 m ~25, 12 m ~50, terminal ~85), stagger past +4 m/s; not in Plunge/Swim/Downed; damage number.
- Body: shoulder joints at x 0.2*sh+0.004 (fem 0.158*sh+0.004), y ty(0.52); new torso rings at 0.535 (deltoid cap) and 0.57/0.575; arm dome lowered. Fist thumb: Basis(Vector3.BACK, inward*1.5), tucked across the fingers.
- Hurtbox monitorable toggles in dodge/skill/downed now set_deferred (were blocked inside area signals).
- Tests: tools/r6test.gd (34 checks). feat/powertest updated for quick slots. run_all.sh timeout 330 (grunttest's 20 s walk home). Known flakes (pass on rerun): watertest float thresholds, grunttest walk-home timing, vinetest big-bug aim. Renders: uishots.gd (every menu; arg 2 = PSX preset), r6shot.gd, creatorshot.gd, posebench views chest/chestf/chests + PB_REST.


## 2026-10-04: co-op multiplayer (branch `multiplayer`)
- Zach: do the whole migration; ENet now (decide on Steam/relay later); defaults: no friendly fire, nothing pauses with 2+ players, knocked out + teammate revive, one shared ship. Ignore the "fruit from another world" rule for now.
- `Net` autoload (scripts/net/network_manager.gd): listen server over ENet, port 24680, up to 4 captains. active/hosting/is_host()/is_client()/coop()/my_id(), players (peer -> Player), roster (peer -> {name, look, level}), time() = host clock (ping/pong offset), INTERP 0.1 s. All RPCs live on /root/Net. host_game/join_game/leave; hello -> welcome -> world loads -> world_loaded() -> _in_world (host spawns puppets everywhere, world sync, places the joiner next to the host). Host from the pause menu too (GameMenu "Host Co-op"). Title: Co-op panel (Host = pick a save; Join = IP + pick a save; last IP in user://last_host.txt; disconnect reason shown).
- Node keys = path from the world scene (key_of/node_of). Local player renamed P<id>; puppets are the same player.tscn with is_local=false, net_id, net_profile (no state machine/input/components processing, not in group "player" -> every old get_first_node_in_group("player") still means "you"; all captains in group "players"). Snapshots 20 Hz, unreliable, chunked under 1100 bytes (sample(node) -> [a, b, f]); events (Net.event -> node.net_event) and FX (Net.fx) are played at the same 0.1 s delay; Net.everyone(_all_*) for coins, XP (within 40 m), weapon drops, damage numbers, gunshots.
- Player snapshot: pos (ship-local on deck), yaw, lean basis, state name, hp, flags (coat/bleed/floor), HumanoidSync.pack (22 fields + weapon/offhand/in-hand/left-prop models; meshes tagged with meta "model" in Props), vine rope end. Humanoid.net_sync mirrors play/stop/ragdoll/getup/recover/reset_pose/relax. "look" event on gear/hybrid changes. Power objects (Projectile/Fireball/FireZone) spawn harmless copies via Player.net_power (PowerComponent.enemies_in/ignite are no-ops for puppets); BurnStatus broadcasts burn_fx (dps 0 copies).
- Combat: Hurtbox.take_hit -> Net.route_hit (hit on another machine's captain -> that machine; client hit on an enemy -> host, with attacker pos for blasts). Hitbox ignores overlaps with remote captains (still adds them to hit_targets so rams bounce). Enemy forward() for parried/vine_yank/rooted. Hitstop off in co-op; hit feedback on the attacker's screen.
- Enemies: host-run, group "net_sync", net_pack/_net_update/net_event; grunt snapshot includes hitbox serial (puppet swings its own hitbox so it can hit you), aim line, glow, peril, bark. Names G<gen>_<i> / B<spot>_<gen>; camps/nests (group "net_spawner") respawn only on the host (clearance vs all captains), Net.spawned -> net_set_gen. Targeting: nearest valid captain with stickiness; camp tokens per target (cap +2 in co-op); HP x(1 + 0.5 per extra captain), rescaled on join/leave.
- Knocked out: with a crewmate standing, death -> Player.bleeding (Downed dead, 20 s); hold F within 1.9 m for 2.5 s revives at 30% (Net.revive); timeout / everyone down -> GameManager.bleed_out (normal drop + respawn). HUD: crew list (name, HP, down) + show_prompt(text, progress); nameplates on puppets.
- Ship: Net.ship_owner (host by default; helmsman after request_helm/grant); owner simulates + sends pose, others ride it (_puppet_physics, still a moving platform); net_take_over on hand-off. Ocean.clock() = session clock (swell + ship match).
- Saves: guests keep their own world (burned, fruit_claims, ship/player pos) when saving; load skips world parts; char_id. Devil Fruits: one per world, host-arbitrated (GameManager.fruit_claims, saved by the host; chests are per-captain locally).
- Menus: Net.set_paused -> in co-op only Player.input_locked (StateMachine skips; locked_physics stands you still). Load Game blocked in co-op; Quit to Title leaves.
- Tests: tools/nettest.sh [godot|godot47] [""|late|three|hostquit] runs nethost.gd + netclient.gd (+ netwatch.gd) on localhost with nettest_node.gd (/root/NetTest RPC helper): ~50 checks incl. puppets both ways, enemy sync, hits each way, gunshot, kill rewards, revive, actions, fruit claims, waves, brush, helm, guest save, leave/host quit. Render: tools/coopshot.gd.
- Known flakes in this environment (also fail on b03ef0d): swimtest "head still above water while swimming", vinetest 4.7 big-bug aim. grunttest 4.7 can time out under CPU load (passes alone).


## 2026-10-05: co-op fixes, sharper PSX, loot window + drag/drop inventory, trading, wolf stance
- Zach's reports after playing co-op: joined players' models desync from their nametag in the water (float / sink); names not showing/sending right; PSX too blurry far away; loot prompt sticks; wants a pickup feed, drag/drop inventory management, dropping items, consumables onto quick slots, chest window, trading fruits; wolf hybrid too janky (wants low feral crouch, claws at sides, aggressive run, exaggerated attacks).
- Water desync: the visible body can only leave its root (and nametag) while ragdolled - puppet ragdolls simulated locally (different buoyancy: the puppet's power has no fruit). Fix: Ragdoll.net_pack()/net_follow(a, b, f) - snapshot the owner's bodies, puppets go kinematic and follow (player snap[11], grunt [19], bug [8]). Ragdoll.drive frees itself if its body node is gone. Test: nettest.sh godot water (swim + knocked down in water; hips within 0.05 m).
- Names: puppet "look" event now also updates net_profile.name, Net.roster and the nameplate (a new captain names themselves in the creator after joining). display_name() falls back to the look's name. Nameplate font 34 / pixel 0.007. Test checks rename + host name both ways.
- PSX: psx_common psx_far(depth) (12-45 m): snap grid 6x finer and affine warp off far away; albedo filter_nearest_mipmap_anisotropic; new preset index 4 "960x540 (sharper)" (CANVAS_ITEMS + post pixelate grid) is the default; Settings v2 migrates a saved preset 0 -> 4 once (meta/version in settings.cfg).
- Interaction prompt hides when its interactable is freed / disabled / queued (InteractionComponent._shown) and right after interact().
- HUD pickup feed (top-right under the compass): rows icon + "+N Name", merges repeats, 3.5 s, max 5, hidden under menus.
- Inventory: InventoryComponent.move_stack / take_amount / room_for. InventoryScreen drag & drop via set_drag_forwarding (bag <-> bag move/merge/swap, bag -> gear/weapon/off-hand slots, consumables -> quick slots (new QUICK ITEMS row, keys 5-7, right-click clears), slot -> bag to unequip, bag -> world (left half) drops, X / shift+X drops hovered). Player.drop_from_bag(idx, qty) + check_equipped().
- LootBag rework: contents_changed, take(idx, player, qty), take_all, store(player, bag_idx, qty), title(), prompt "Open chest"/"Pick up X"; >1 item opens GameMenu.open_container(bag) (inventory with a loot panel instead of the paper doll; F = take all; headless just takes all). Empty -> freed (save_id chests marked opened). Fruit claim only for chests (save_id).
- Co-op shared drops: Net.drop_items(stacks, at) -> host makes "Drop_D<n>" on every machine (single player "Drop_L<n>", not saved); bag_take/bag_store go through the host (_take_req/_take_ok, _store_req, _bag_contents); world sync includes drops. Props.sack_mesh(). Test: nettest trades rum + a Devil Fruit both ways.
- Wolf hybrid: claw guard (hunched, claws low at the sides); Humanoid._feral(p, walk, run, s) for stance "claw" (pivot pitched forward, deep crouch -0.44, wide legs, arms swept back on the run, sprint more horizontal); claw_r/claw_l coil + low lunge rake, claw_double raise + crossing slam; light attack claw durations 0.28/0.28/0.44, impulses 6.5/9, starts/ends. posebench PB_BEAST / PB_SPEED / PB_SPRINT.
- Tests: tools/r7test.gd (27 checks, in run_all). Renders: r7shot.gd (feed, loot window, wolf), psxshot.gd (far view; args key=value video settings), coopshot.gd.
- Known flakes here (also on earlier commits): swimtest "head still above water while swimming", grunttest 4.7 "survivors return to their posts". Co-op suite: default/water/hostquit on 4.6, default/three/late on 4.7 all OK.


## 2026-10-05: co-op polish, cannons + pirate ships, Captain Morrow, music
- Zach: do the small co-op fixes and new content (skip online transport + lag testing for now). Picked: pirate-captain boss with phases; crew-manned cannons (helm broadside for solo); enemy ships that patrol, fire broadsides and board; generated PSX music.
- Co-op polish: pings (client sends its rtt in _ping, host broadcasts Net.pings every 2 s; Net.ping_ms(id); party rows: crew colour swatch, name, HP, ping coloured; guests see "Ping N ms"). Crew markers: action `ping_marker` (G / middle mouse) -> Player.place_marker (camera-centre ray, sea plane, enemies with is_dead() get followed) -> Net.mark -> everyone `_all_mark` -> HUD.add_marker -> MarkerLayer (scripts/ui/marker_layer.gd: diamond, name + distance, sticks to screen edge with an arrow, 12 s, one per captain; Net.crew_color by roster order). Kneel: Humanoid.kneeling (+ manning) poses, synced via HumanoidSync FIELDS; reviver faces the downed crewmate. Observation sense: PirateGrunt._sense -> on the target's machine only (Net.event "sense"). Puppet wolf aura on the look event. Scaling: hp_scale 1 + 0.6/extra captain; Net.extra_attackers() (+1/+2 tokens with 3/4 captains); boarders/boss crew +1 per captain beyond 2. PROTOCOL 2.
- Cannons: ShipCannon (scripts/ship/cannon.gd; swivel gun on a post, local -Z out, yaw ±0.9 / pitch -0.14..0.42, muzzle 46 m/s + hull velocity, reload 3.2 s). Mannable ones have an Interactable seat + GunCam (over the shoulder). Player "Cannon" state (cannon_state.gd, Context.CANNON; mouse aims, LMB fire, F/Space leaves; dashed arc + landing ring via ImmediateMesh ribbons; knockdowns knock you off). Seats are host-arbitrated (Net.request_seat/release_seat/seat_holder, _seats broadcast, freed on disconnect; in world sync). Firing: local ball (authority) + Net.event(cannon, "fire") -> cosmetic copies elsewhere. Helm: LMB = Ship.broadside(side by camera, target where the view meets the sea). Crew ship: 2 guns a side (Ship.cannons, side_cannons).
- Cannonball (scripts/ship/cannonball.gd): gravity 14, ray mask 1|4|2048, sea via Ocean.get_wave_height. Crew shot (authority only): direct hit -> enemy ship Hurtbox take_hit(HitData.siege); burst knocks down enemy hurtboxes (mask 32, r 2.7). Enemy shot: every machine checks its own captain (monitorable = not dodging); host applies Ship.hull_hit. HitData.siege (packed at index 10).
- Crew ship hull: MAX_HULL 400; at 0 crippled (35% speed, smoke + flames) until 50%; repairs 5/s after 10 s without hits; host-authoritative (Net.ship_hull -> Ship.net_hull; world sync "hull"). HUD hull bar above the skill bar while aboard and damaged / at the helm or a gun. Note: Ship.place() teleports carry anything standing on the deck (AnimatableBody platform velocity) - move people off first.
- Enemy ships: EnemyShip (AnimatableBody3D, group enemy_ships + net_sync; HullBuilder model with black sails + runtime-painted jolly roger; 3 guns a side; Hurtbox box). States PATROL/HUNT/BROADSIDE/BOARD/HOLD/SINK. Hunts the crew ship when a captain is within 14 m of it and it's outside Brinehollow's harbour (EnemyShip.safe_center, SAFE_RADIUS 250). Broadside orbit 24-46 m, volley every 7.5 s (1 s warning: muzzle sparkles + bark; 3 guns 0.24 s apart, leading the target, spread 1.5 + 6%/m). After 2 volleys (slow/close target) pulls alongside (7.4 m) and boards: PirateGrunt.leap (new state LEAP = 20, boarder flag: no post leash) named BD_<ship>_<i> under the fleet; ship acts as their token "camp". Hull 260 x hp_scale; sinks (roll, flames, bell) and drops a floating LootBag (LootBag.floating bobs on the waves, usable while swimming; per machine). XP 150 within 160 m (Net.award_xp has a reach arg). EnemyFleet (net_spawner, ES<zone>_<gen>, respawn 150 s out of sight): zone around Redtide Rock + one toward the nearest island.
- Redtide Rock (scripts/island/redtide_fort.gd, placed by WorldGenerator._build_redtide: Brinehollow + (0,-400) if deep water, else ring search; +Z faces home): sea-stack rock (trimesh), jetty + ramp (south), palisade ring (r 17.5, gate south) with gate skull, Morrow's tent + chair, braziers, flag, stores, two fort guns on the south wall (fire at the crew ship while a captain is aboard and Morrow lives), GruntCamp guards (2 at the gate + rifleman). Arrival banner. Gus has a "Who runs these waters?" line ({redtide} token).
- PirateBoss (scripts/enemies/pirate_boss.gd extends PirateGrunt; new grunt hooks _choose_attack/_begin_attack/_combo_hits/_guard_max): Captain Morrow "Red Tide" (height 1.2, captain coat), 900 HP x scale, longer hitbox, light 17 / heavy 26 (knockdown) / peril 34. 3-hit combo (finisher slash_down glowing), lunge, peril chop, pistol volley (3 shots). Phase 2 (<60%): roar (AoE r 5.5) + fort.call_crew() (MC<gen>_<i> leap over the wall) + slam (telegraph ring via FX.telegraph, ballistic hop, AoE r 4). Phase 3 (<30%): Red Tide glowing blade, faster wind-ups, whirl (spinning, re-arming hitbox every 0.3 s, parry breaks it). No knockdown unless staggered; armour vs light hits while winding up; Haki breaks the slam wind-up. AoEs: Net.event "aoe" -> each machine checks its own captain (jump over / dodge). Resets when everyone leaves (fort: 5 s, or when he walks home). Death: banner + Music.victory(); "Hoard" chest per captain (save_id redtide_hoard): Red Tide cutlass (resources/items/morrow_cutlass.tres, damage x1.4), Red Tide Coat, 40 gold, 4 treasure, 2 rum. Respawns after 10 min (gold only then). HUD boss bar (top centre, 60/30% marks).
- Music: Music autoload (scripts/game/music.gd): title/island/sea/combat/boss loops (assets/audio/music_*.ogg, loop set at runtime) crossfade by context; victory sting ducks it. "Music" bus + Options slider (Settings audio/music 0.6). Generated by tools/texture_gen/gen_psx_music.py (numpy sequencer, ffmpeg -> ogg). New SFX via gen_psx_audio.py <names>: cannon, cannon_hit, wood_crack, horn, roar, bell, splash_big, rope.
- Tests: tools/r8test.gd (in run_all): markers, kneel, man/fire/reload/leave a gun, broadside, siege-only hull damage, a real ball holing a hull, a pirate ship hunting + firing, combat music, hull bar, boarders leap + land, sinking + flotsam, Morrow: engage, bar, boss music, phase 2 roar + crew, slam AoE, Red Tide, reset, death, hoard + cutlass. nettest adds: kneel revive seen by the client, pings both ways, marker on the host, cannon seat granted/denied/freed, cosmetic ball on the host, pirate ships + boss puppets, hull sync, boss AoE judged on the client. Renders: cannonshot.gd, r8shot.gd, r8show.gd.


## 2026-10-05: texture swim fix, waves in sync, hair, dynamic sky + weather + 3D clouds (current)
- Zach's reports: textures shift/slide with the camera relative to surfaces; characters and waves out of sync (floating above troughs); wants dynamic weather/skies/godrays/clouds/rain/storms, physical fly-through 3D clouds for later flight powers; head showing through hair when zoomed out. Picked: ~24 min day/night, storms = rough seas + cosmetic lightning, PSX puff-cluster clouds.
- Texture swim = PS1 affine warp. psx_common psx_affine_at(depth): none within ~2-7 m and none far; psx_lit/cutout use it; terrain + ocean (world-space UVs on huge triangles) never warp now. Settings default warp 0.0, Settings VERSION 3 migrates a saved 0.6 (old default) to 0.
- Waves: the old ocean PlaneMesh had 7.8 m cells for a 7.85 m / 4.2 m wavelength swell, so the visible sea was aliased junk vs the computed waves. OceanManager.graded_mesh(): one seamless grid, 1 m cells within ±80 m, growing x1.13 to ±1000 m (~56k verts), snapped to 8 m, custom AABB. Ocean.clock() now advances with physics ticks (process_physics_priority -100, slews 2%/tick to the session clock, snaps if >0.5 s off) and returns the interpolated time outside physics frames, so swimmers/ship/enemies and the rendered sea use the same time even when FPS < 60. Ocean.amp_mult scales both waves (CPU + shader). Debug render: tools/wavegrid.gd (balls on computed heights sit on the rendered sea).
- Hair: psx_lit depth_pull (pulls the surface toward the camera, 1-5 cm by distance; PSXMat opts "pull"), hair uses 0.01. The head loft's non-face quads above the style's hairline use a flat hair-colour material (MeshBuilder.add_loft face_pick may now return a Material), and FacePainter paints hair colour above the hairline (material(lk, eye, hairline)), so the scalp reads as hair wherever snapping lets it through.
- Weather autoload (scripts/world/weather.gd), attaches to a scene named World with a WorldEnvironment: world_time() = session clock + world_offset (saved as "world_time"; guests keep their own; host's offset/override in the world sync "weather" and Net._all_weather). hour(): START_HOUR 9, DAY_LEN 1440 s. Weather slots of 300 s (first 2 slots always clear), deterministic hash -> CLEAR/CLOUDY/RAIN/STORM (no back-to-back storms), 60 s blends; PARAMS = coverage, rain, storm, wind, waves (Ocean.amp_mult up to 1.8), fog. force(s) (-1 natural; 8 s blend). Debug builds (single player or host): F6 cycles weather, F7 +2 h.
- Sky: shaders/psx/psx_sky.gdshader (gradient by hour keyframes, sun disc + low-sun glow, moon with crescent, twinkling stars, fbm high cloud layer with coverage, storm grey, lightning flash). Sky incremental radiance, ambient from colour. The DirectionalLight3D is the sun by day and moonlight at night (dimmer, bluish), energy/colour by hour and storm, shadows off when dim. Fog colour/begin/end by hour, weather and in-cloud. Ocean deep/shallow colours darken in storms. CloudShadows coverage/strength follow the weather.
- Rain: GPUParticles3D around the camera (2200 crossed streaks, amount_ratio = rain, wind slant, distance fade near the lens), stops under roofs (upward ray every 0.3 s). Lightning: every 0.5 s tick hash vs storm -> jagged bolt mesh 120-540 m away, flash on sky/ambient/sun, thunder (near/far) delayed by distance/340. Sounds: rain_loop, wind_loop, thunder, thunder_far (gen_psx_audio.py).
- Godrays: 14 additive beams (shaders/world/godray.gdshader, cylindrical billboards along the sun direction), strongest with a low sun and broken cloud, off in rain/storm/night.
- 3D clouds: scripts/world/cloud_spawner.gd is now PuffClouds (world "Clouds" node): 64 clouds of 7-14 puffs in one MultiMesh (shaders/world/cloud_puff.gdshader: camera-facing, noisy round edge, 4x4 Bayer screen-door alpha so no sorting, fade within 3-22 m of the camera, per-instance shade/opacity + custom seed). Wrap every 2400 m around the camera, drift with the wind; coverage decides how many show; storms pull them down 38% and swell them. density_at(pos) (0..1) for gameplay/flight; Weather whites out the view (fog + white overlay) when the camera is inside.
- HUD: clock under the compass ("Day N, HH:MM"; FPS above it when enabled); pickup feed moved down to y 44.
- Tests: tools/r9test.gd (in run_all): warp default, graded sea mesh, hair-coloured scalp, swimmer depth spread < 0.35 m over 6 s, physics wave clock, noon/midnight sun + moon, forced storm (rough sea, rain, fog, low dark clouds, lightning), back to clear, deterministic cycle with all 4 weathers, cloud density inside/above, world time save/restore. nettest: same time of day + weather as the host, host's weather change reaches the client. swimtest measures against the waves. Renders: weathershot.gd, waveshot.gd, wavegrid.gd, hairdist.gd.


## 2026-10-05 (later): horizon fog, natural waves, blended clouds, ragdoll rig drift
- Zach's reports: a strip near the horizon where the sky/weather "ends" (wanted a long-range fog fade); the waves looked perfectly modulated/symmetrical; dithering misbehaved on the clouds; player models stretched/misshaped after repeated ragdoll + get-up (fixed by re-equipping clothes).
- Horizon: the band was the old CloudShadows plane (blend_mul plane at y=30, 3 km, fogged), which multiplied the sky and everything seen through it by the fog colour (dark strip above the horizon; square edge from altitude); and the sky below the horizon used a darker "ground" colour. CloudShadows node + scenes/world/cloud_shadows.gdshader removed; cloud shadows now come from shaders/world/cloud_shadow.gdshaderinc (global `cloud_shadow` vec4: coverage, strength, drift xz), applied in terrain.gdshader + ocean.gdshader. psx_sky: `fog_color` + `haze_height` uniforms, sky hazes into the fog colour toward the horizon and is pure fog below it. Env fog_sky_affect 0, sun_scatter 0, fog 110..820 m clear (28..240 storm), so the 1 km sea is fogged out inside its edge. Ocean shader: global `sky_haze` (rgb fog colour sRGB, a haze height) mirrors the sky's haze below the horizon (emission, distance-gated 30-160 m), so the sea melts into the sky. Weather keeps fog_color/fog_begin/fog_end/haze_height/cloud_shadow vars.
- Waves: OceanManager.WAVES table (6 trains: heading, wavelength, amplitude, phase; omega = 0.62*sqrt(g k)), crest shape 2*((sin+1)/2)^2 - 0.75 (peaked crests, broad troughs), wave-group envelope 1 + 0.28*sin*sin over a few hundred metres. Same table pushed to the shader (uniform arrays waves / wave_amp_phase, amp_mult, crest, env_*). Sea grid now 1 m cells to ±120 m, growth 1.08 (~120k verts); shader fades waves too short for the local cell size (so far away is calm, not aliased noise). get_wave_height exact within ~112 m of the camera.
- Clouds: cloud_puff.gdshader now alpha-blended (depth_draw_never, fog_disabled, own haze + far fade 0.72..1.0 x clamp(2*fog_end, 500, 1150) m); PuffClouds sorts puffs back-to-front each frame (PackedFloat64Array keys, native sort) and writes the whole MultiMesh buffer (stride 20) + visible_instance_count. The old 4x4 screen-door at native res aliased against the PSX pixel grid (post pass samples every Nth pixel).
- Ragdoll drift: Ragdoll.add_part records each rig joint's local origin + scale; restore_rig() puts them back (keeps rotation) and is called from Humanoid.end_ragdoll (and Scuttlebug). _capture_ragdoll_pose re-zeroes the hips' local origin and scale after setting its global transform. Before: ~15 cm of joint drift after 6 knockdowns.
- Tests: tools/r10test.gd (in run_all): fog/sky agreement, sea fogged inside its edge, cloud shadow global, no CloudShadows node, wave table in the shader, mean sea level ~0, sd 0.35-0.8, no stripe repeat at one wavelength, positive skew, 1 m cells to 120 m, clouds blended/fog_disabled, sorted far-to-near, none past the fade, storm haze/fog, 6 knockdowns leave the rig unchanged.
- Combat-stance strafing (commit 08d22f5): Humanoid._locomotion eases a travel angle (_travel_ang, atan2(local_move.x, local_move.y), 12/s), picks forward vs backpedal with hysteresis (>114 deg back, <96 deg forward), turns the hips toward the stride heading (_hip_yaw, up to HIP_YAW_MAX 0.95 rad, 10/s; applied as hips.y -= yaw, torso.y += yaw so the chest/guard stay on the target), and the residual angle drives the old forward/side leg mix. Backpedal fixed: the lifted leg is the one with cos(phase) > 0 in both directions (it used to fold the wrong leg, so the feet moonwalked), reach asymmetry mirrored, steps 0.7x amplitude, cadence x1.08. Planted-foot slide (tools/strafeview.gd): back-diagonal 8.9 -> 0.7 m/s, back 10.4 -> 0.7, fwd diagonal 1.7 -> 1.15, forward unchanged 1.15. Player.gd lean: side lean eases at 5/s (was 2.5), backward lean x0.4, side x0.8.
- Waves trimmed (amplitudes x0.85, groups 0.22) and crests soft-capped past 0.85 m (CREST_KNEE/ROOM, CPU + shader crest_cap) after a progtest run found the surf flooding the beach test spot (player went to Swim).
- 2026-10-05 fix: _travel_ang is wrapped after lerp_angle (it drifted past ±PI after an attack/backstep turn, so |angle| > 114 deg latched _gait_back while moving forward-diagonal = reversed, mirrored legs). Combat-stance chest tip: torso pitches/rolls by (body-space velocity - a 5/s lagged copy) x TIP_GAIN 0.075, max 0.5 rad, braking x0.6, head counter-pitches 40%. r10test: turn through straight back then forward-diagonal (no latched backpedal, angle in ±PI), chest rolls into a forward->right switch. strafeview.gd takes a 3rd arg (switch to dir index) to film a direction change.
- 2026-10-05 jump variety: Humanoid airborne pose picks a lead side (_jside) + 8 per-limb offsets (_jv) on each take-off or double-jump kick (vy jumps > 4). Lead knee tucks/draws up, the other trails/hangs lower; arms go up and out to the sides (x ~0.9-1.4, z ~1.0-1.35), the one over the trailing leg higher. r10test jump_poses (both sides seen, knee gap > 0.3, arms more sideways than forward, varied poses). jumpshot.gd takes a 2nd arg `front` (front three-quarter camera).
- 2026-10-05 ragdoll shimmer/slide: Ragdoll._muscles scaled torque by the child's inertia and applied the reaction to the parent, so the light pelvis (parent of chest + thighs) got ~7x the spring/damping and oscillated (c*dt > 2); now the pair's reduced inertia. _settle: after 0.5 s, root slower than 1.2 m/s eases _calm to 1 over 0.4 s (muscles relax, damping 0.8->7 / 0.05->2.5); fully calm + still 0.3 s pins every part (freeze STATIC, velocities zeroed, settled() true). push() or water within 0.4 m wakes it; net puppets skip it. Driven rig parts are top_level + interpolation OFF while ragdolled (restored in restore_rig) so they draw on the bodies, not on the interpolated root that chases the hips. ragtest: slide < 0.08 m/s, at-rest spin < 0.3, pinned 0.5-2.6 s, parts world-space + handed back.
- 2026-10-05 pistol aim: the combat camera's over-the-shoulder shift is camera.h_offset/v_offset, which camera.global_transform doesn't include, so everything casting from it aimed ~0.55 m left of the crosshair. Player.reticle_ray() (project_ray_origin/normal at the screen centre) is used by pistols, place_marker, skill _aim_point/_vine_target/fireball and the HUD on-target reticle. Pistol ray stops on enemies (1|4|2048), starts level with the player; assist only within 0.06 rad of the ray with line of sight; muzzle = shoulder + 0.7 m along the shot. Reticle goes red at pistol RANGE with a gun out. progtest aim_at() aims like the mouse: hit on target, miss 1.5 m beside.
- 2026-10-05 casual moves: the landing squash never ran (_air_time was zeroed in the grounded branch before the check read it; now air_before). Landing: the foot that hung lower lands first and takes the weight (shin -1.4k vs -0.6k), the tucked one 60 ms later, torso tips over the first foot, the late-side arm swings out. Idle weight shift (not in combat stance): clamped sin(_t*0.35 + _idle_seed)*3 holds ~7 s per leg, ~2 s shifts; standing leg straight, relaxed knee bent, hip drops on the relaxed side; suppressed during a landing. Humanoid._casual_moves (out of combat, tracked always): push-off lean (torso -0.28) on setting off after 0.15 s still; planted stop with a dip after >4 m/s; skid on a >5 m/s reversal (lean toward the new way in body space, deep knees, arms out, FX dust + "land" sfx pitched up; tools/texture_gen has a "skid" scrape, not generated yet). r10test body_run() checks all of these; render tools/dev/skidshot.gd.
- 2026-10-05 follow-ups: (a) braced ragdolls were too limp after the reduced-inertia fix (hip muscles ~2.4x weaker): muscle_k 480 / muscle_c 32, thigh extension limit -0.45 (was -0.7, legs swung back behind the body); ragtest: thighs reach > 0.65 rad up, never < -0.6 back. (b) casual stop/skid never fired for the player: Idle brakes at 160 m/s^2 (3 ticks) and reversals pass through a moment of no input, so stop uses a decaying _peak_spd and skid the last fast direction within 0.3 s (_fast_dir/_fast_t); r10test drives them with real input (weapon away). (c) waist clipping: the strafe turn is split, PELVIS_SHARE 0.4 on the pelvis (chest counters it), the rest as thigh yaw in the sockets; foot IK solves in the twisted thigh plane. Waist twist on a diagonal 18 deg (was ~45). (d) elbows: BodyBuilder._dome/_elbow_end/_elbow_start round the upper-arm end and forearm start about the elbow pivot (bare, sleeves, blouse, coat), forearm tops capped. Renders: strafeview zoom arg (hip close-ups), posebench fists_up for elbows.
- 2026-10-05 ragdoll self-collision + hips: Ragdoll.enable_self_collision() (called after the humanoid's parts are added) puts every part in mask LAYER and adds collision exceptions only for pairs whose capsules already touch in the start pose (Geometry3D closest points between the stored body-local segments). Thigh capsules start 0.1 m below the hip so the thigh/chest pair isn't exempted. Limits: thigh flex 1.5 (was 1.9), chest curl -0.75 (was -1.0). ragtest: self-collision armed (thighs not exempt from the chest), knees > 0.17 m from the chest axis over forward/side/backflip falls plus shins flung at the chest (the limits stop them ~0.36 m out). Hips (checked from directly behind, the game camera's view): thigh top domes lowered/slimmed (their sides poked out above the shirt hem); pelvis top tucks inside the shirt waist (0.9x at +0.04), meets it flush at 0, widens only below; _hips_hw floor leg_gap + 0.09 (fem 0.098) so the pelvis, not the thighs, makes the hip outline; "belt" straddles the seam (by -0.025). posebench views hipsb/hipss/hips3 (PB_BASE=1 PB_REST=1 for the coatless base look).
- 2026-10-05 female hips/thighs (judged from directly behind + front): torso bottom ring flares (0.128 -> 0.142 w) so the waist narrows at 0.11 and curves out (hourglass); the pelvis eases to full width over -0.03/-0.065/-0.1 (55/88/100%), a seat that sits back (cz up to 0.024, depth x1.08) and curves under to -0.222 instead of a flat bottom edge, on a 12-point _seat_profile whose seat rings pull the back centre in (the cleft between the glutes). Thighs: fuller and rounder (an extra -0.14 ring), set 2 cm toward the middle so they meet near the top. Male unchanged. posebench: PB_FEM=1, views hipsb/hipss/hips3/hipsf. chartest + invtest can fail when run in parallel with other suites (shared user:// saves); pass alone.
- 2026-10-05 female glutes: BodyBuilder._glute() adds two ellipsoid lobes to the female pelvis mesh, centred behind each hip joint (x = leg_gap*0.72, y -0.124, z hd*0.6; radii 0.082/0.102/0.084 x hp/de), overlapping at the middle so the intersection is the crease and each has its own round underside. The seat rings fill out right under the belt (-0.025/-0.055) for a high, round top; the tube's own cleft is milder (0.8-0.92) since the lobes shape it. _seat_profile has extra back points (16 total). The lobes use face_uv (wrapped around the lobe centre, seam at the front) because add_loft takes u from its first ring, which near a pole squeezed the cloth texture into stripes. Checked from behind, quarter, side and mid-stride (PB_SPEED=6).
- 2026-10-05 glute underside: the lower half of each _glute lobe is no longer a hemisphere (its underside left a ledge + shadowed undercut, very lumpy with shorts on the broad build): it stays full to ~half way down, then tapers forward (z -0.03) and ends at 0.88 x ry, above a shorts hem, so it sinks into the back of the thigh / shorts leg. posebench PB_KV="legs=shorts;build=broad;top=bare" overrides look keys.
- 2026-10-05 builds: _hips_hw grows with hp/wa (stout ~0.26) but the thighs only scaled with limb, so the pelvis's lower corners hung out past the legs (lumpy, worst on stout). _thigh_rings now widens the upper thigh (both bodies) by g = (hw*0.92 - centre - r)/1.6, full at the top, fading to 0 by -0.38 Ls, mostly outward (cx +0.6g); average builds barely change. Glutes are placed/sized from hw (x hw*0.36, rx hw*0.41) and flatter (z hd*0.48, rz 0.076 de); the female pelvis seat is shallower (hd, cz 0.012) and its lower rings taper in (0.82/0.56).
- 2026-10-05 round glutes: _glute is a plain ellipsoid again (symmetric rings, Zach's call: the tapered underside still looked odd); the pelvis tube's lower back rings tuck in (depth 0.72/0.46/0.26, cz forward) so its bottom edge stays behind the glutes instead of peeking out between their undersides.
- 2026-10-05 skinned lower body (replaces the rigid pelvis + thigh lofts + glute lobes, which kept showing seams/lumps where pieces overlapped): BodyBuilder._lower_body builds ONE surface in hips space: 12-point pelvis rings (_hip_ring: front centre, 5 +x, back centre, 5 -x; female back pulled in + bulged = seat/cleft) down to a split ring at the crotch (ys -0.18 fem / -0.165 masc) whose two halves are the tops of the two thigh tubes (_thigh_ring ellipses from _thigh_rings, leg space + (+-leg_gap, -0.02)); the thighs share their inner edge on x = 0. Skinned to LowerBody (scripts/npc/lower_body.gd, a Skeleton3D under the hips: pelvis + thigh_l/r bones posed every frame at process_priority 100 from hips^-1 * leg global, so animation, foot IK and ragdolls all drive it). Weights are a pure function of rest position (MeshBuilder.weight_fn): pelvis above, thigh below (-0.04..-0.21), and near the crotch the centre stays with the pelvis (|x| 0..0.07, released over 0.2 m below the split; a narrow blend folded the surface). Materials per quad by height (shorts: cloth to the hem then skin, + a closed rolled cuff; skirt: bare thighs). New MeshBuilder: add_rings (tube through absolute point rings; one winding per tube by vote; each quad split along the diagonal that folds least, triangles faced by their own vertex normals: a twisted quad split the other way was inside-out), weld_normals (smooth across tube joins), weight_fn. Shins/feet stay rigid on the shin joints. chartest: every body x build x legs builds a skinned lower body with no inside-out triangles and no thigh meshes; the player's thigh bone follows a swung leg. tools/dev/lbprobe.gd lists inside-out triangles. Known: fx.gd afterimages copy meshes without their skin (lower body shows its rest pose), like hair/cloth already did. swimtest "head still above water while swimming" fails on this commit and the one before (pre-existing, wave timing).
- 2026-10-05 seat volume: linear-blend skinning dragged the seat forward with a lifted thigh (flat butt in jumps/strides, a pinched point at the crotch). LowerBody gained seat helper bones (SEAT_L/R at the hip joints): they turn SEAT_FOLLOW 0.32 of the thigh and push out SEAT_PUSH (0, -0.012, 0.035) x hip flex. Weights (4 slots: pelvis, own thigh, seat_l, seat_r): the back of the seat and the middle of the crotch (near the split height) take their leg share from the two helpers, split by side (to_left over 0.1 m), fading to the thigh below the crotch; this replaced the "centre stays with the pelvis" rule. chartest skins the seat on the CPU: lifting the left leg (x 1.4) keeps the back of the left glute >= 90% deep (now 0.141 -> 0.135; the previous weights gave 0.125 and fail). posebench PB_AIR=<vy> renders the airborne pose.
- 2026-10-05 thigh pinch + hourglass thighs: the pelvis/thigh weight blend ran from -0.04 to -0.21, so the upper third of a lifted thigh was half pelvis and lost ~12% of its girth (pinched in jumps/strides); now -0.03..-0.12 (seat helpers still carry the back). chartest thigh_keep(): CPU-skinned mean distance from the thigh axis per 2 cm section, lifted vs rest, worst >= 90% (now 100%). Female thighs fuller and bulging outward up top (o = 1.4 cm, radii 0.116/0.118 x L at -0.05/-0.12 Ls, an extra -0.2/-0.28 ring) so from behind the outline curves from the widest point of the hips to the knee.
- 2026-10-05 hip side notch + stout width: the crotch (split) ring's outer half used the thigh top's radius, narrower than both the last hip ring above and the bulged thigh below, so the side dipped in where the thigh joins; its outer radius is now raised so the side sits halfway between the two. Female _hips_hw = 0.198 x (1 + 0.6(hp-1)) x (1 + 0.3(wa-1)) and _hips_hd = 0.122 x (1 + 0.6(de-1)) (stout compounded to ~1.33x wide). Male unchanged. Note: look "height" is a float (HEIGHTS), e.g. PB_KV="height=0.92".
- 2026-10-05 knees: the skinned lower body now runs through the knee to the ankle (thigh rings stop above -0.33 Ls, a kneecap ring on the joint at kj = -0.02 - 0.42 Ls, then _shin_ring()s from _shin_rings()). LowerBody bones 5-8: shin_l/r copy the shin joints; knee_l/r sit on the knee joint turned slerp(thigh, shin, 0.5). Knee weights by height from the joint (dk): thigh -> knee helper (k = 1 - |dk|/0.05) -> shin. Materials: trousers cloth (+ hem flare), breeches cloth to kj - 0.085 Ls then stockings (+ the rigid cuff band), shorts/skirt skin. The rigid shin mesh is only footwear (and the breeches cuff). chartest knee_keep(): knee bent -2.0 rad keeps 100% of the knee section's size (77% without the helper = fails). swimtest passed this run.
- 2026-10-05 skinned arms + joint chains: ArmBody (scripts/npc/arm_body.gd, Skeleton3D under the torso) carries both arms shoulder to wrist, one mesh per arm (MeshL/MeshR, so Armament Haki can blacken just the weapon arm: Player.update_coat_visual uses arm_mesh(right)). _arms builds 12-point _limb_ring tubes: shoulder dome, rings across the shoulder, upper arm, nine rings across the elbow, forearm to the wrist; outfit by position (long/short/none sleeves, blouse forearm, coats use their sleeve shape + coat colour; the coat's turned-back cuff, blouse cuff, gloves and hands stay rigid on the forearm). _coat no longer builds sleeves. Joints (knee, elbow, shoulder) are now chains of 9 bones turning 0, 1/8 ... all of the bend (LowerBody.KNEE_*_CHAIN, ArmBody.SHOULDER/ELBOW_*_CHAIN), with a ring at every step (BodyBuilder._chain_w blends neighbours): a 3-bone (thigh/half/shin) blend left the bent knee pointed (82 deg turn at one ring, the jump tuck) because blended rings sit on the chord. The knee ring on the joint is the thigh's/shin's own size there (a kneecap bump jutted out of the arc). chartest: arms build for every body/top/sleeves/coat with nothing inside-out; bent knee/elbow keep 100% volume and turn <= 30 deg per ring (knee 29, elbow 24); raised shoulder keeps 100%. Max mesh instances per character 16 -> 12. grunttest: the "waits forever for a circling grunt" hang was the player knocked into the sea by a hit (grunts don't follow); the test now puts the player back on land, and after 10 s with no circling grunt logs the states and sets one circling.
- 2026-10-05 shoulders/neck/head: BodyBuilder.tu(v) = ty() with heights above UPPER_FROM 0.45 compressed by UPPER_K 0.82; used for the torso rings, shoulder joints, neck, collars, coat collar/lapels/epaulettes, scarf (everything placed on the upper chest), so the shoulders sit lower and the traps no longer climb the neck. Head sits 0.06 x neck above the neck base (was 0.1). Skull: rings up to 0.268 unchanged (face, forehead, hairlines); above it a round dome DOME_H 0.12 tall (was a flattish 0.078 cap), widths/depths x cos(a)^0.85. Hat crowns that didn't clear it rise by DOME_EXTRA (bicorne, cap, hood); crown cowlick spikes too. Checked front/side/back with plain, female long hair, captain (tricorn + coat), bicorne, cap, hood.
- 2026-10-05 pistols: gun pointing moved from Player._point_pistols (local only, run before the body posed) into Humanoid.point_guns(), run at the end of Humanoid._process when auto_point_guns (set on the player's bodies, so co-op puppets too: they have no equipped weapon, but stance/actions are synced). Puppets' pistols used to point up the wrist (straight up with the hand down). In the gun kata each gun follows its own forearm. Dual-pistol guard: held low, elbows a little bent, close in; shoot_r/l with dual pistols raise both guns in front, close together, the firing one kicking. Gun kata (heavy): crouch, hop (heavy_attack_state KATA_HOP 5 m/s when the active phase starts), double spin with the arms crossed (each gun out to the opposite side), land; split from dual_spin. Tests: progtest (drawn dual pistols point forward 0.99, the kata hops 5 m/s), nettest (the host's drawn pistols point forward on its puppet; new nettest_node command host_pistols). posebench PB_DUAL=1 puts the weapon in both hands.
- 2026-10-05 pistols held in the hand: aiming every gun at the facing kept them rigidly level whatever the arms did (captures 232649-232727). point_guns() now just sets a fixed local grip (Humanoid.GUN_GRIP: barrel along the hand's -Y = the forearm, tilted GUN_GRIP_TILT 0.12 toward the thumb side), so the guns move with the arms and the arm poses do the aiming. The hand_r wrist bends that compensated for the old sword-style grip are gone (pistol guard, single shoot_r); shoot arm pitch lowered to 1.33 (dual) / 1.4 (single) + aim_pitch so the barrel is level. Grunts keep their own grip (they don't use auto_point_guns). Humanoid._gun_tuck(): dash, roll, flip and airborne with guns out = elbows bent, guns up by the chest (single pistol: gun hand only). Dual pistols jogging/sprinting: both carried low at the sides, elbows soft, hands a little out, blended in by max(jog, run). Gun kata: castable on the move (heavy_attack_state._kata_move: velocity = stick x move_speed x KATA_MOVE 1.05, no impulse) and tipped KATA_TILT 0.6 rad into the travel via the player's align_up/align_w/align_hold (released in exit()); legs clearly uneven (crouch: one knee high; in the air one knee tucked, the other leg long). Tests: progtest (guns ride along the forearms 0.99, ahead in the guard 0.94, the kata keeps moving 6.6 m/s and leans 0.60 rad; the test then puts the player back, since the move ran into the sea), nettest (the host's puppet grips its pistols along the forearms).
- 2026-10-06 Gun Rain + dual-pistol sprint: dual shoot_r/l arms parallel and a little out (y +-0.02, z +-0.1; they converged and looked crossed). Sprinting with dual pistols (blend `run`): arms swept back ~30 deg (arm x -0.52) and out (z +-0.38), elbows nearly straight, torso -0.2 / pivot -0.1 extra lean; the low side carry now blends by jog x (1 - run). Air attack with dual pistols = Gun Rain, inside plunge_state (`_rain`, no new state node, so fall damage stays exempt): RAIN_DUR 0.62, 6 shots on Humanoid's GUN_RAIN_FIRST/STEP schedule (fractions of the action, shared with the "gun_rain" pose) alternating hands, the last from both; each shot sets vy >= RAIN_KICK 1.6 (last x1.8) and gravity runs at RAIN_GRAVITY 0.45 between, so you hang; stick drift x0.4. Each shot goes straight down from the muzzle and hits the enemy nearest under that gun within RAIN_REACH 2.6 m (RAIN_DAMAGE 5, last x1.5 + knockdown), else dust on the ground; the last shot puts a dust ring if the ground is close. Pose: knees up unevenly, both guns pointing down at the sides with per-shot kicks, a full pivot spin through the volley, then the chest tuck. Ends in Fall (or Idle if it touches down). progtest: Gun Rain enters (Plunge / gun_rain), fires 6, slowest fall 1.0 m/s, hits the grunt below (uses grunts[3]: the knockdown would spoil Bullet Storm's grunt).
- 2026-10-06 Gun Rain twice as fast (RAIN_DUR 0.31) and once per jump: Player.gun_rains counts uses since leaving the ground (reset in _physics_process on the floor); air_attack_input refuses (press consumed) at 1 + stat "gun_rain_uses". New Gun node g_hang "Hang Time" (after Extra Powder, level 6, +1 use). progtest: a second air attack in the same jump stays in Fall (used 1).
- 2026-10-06 Gun Rain reworked (Zach: no spin, one double shot, scatter, launched forward): RAIN_DUR 0.6. A beat hanging (vy -> 0) with the guns snapped down and a little back, then at Humanoid.GUN_RAIN_AT (0.1 of the action) _rain_blast(): both guns at once along (DOWN - facing x 0.3), RAIN_PELLETS 4 tracers per gun scattered in the cone (show + dust), and every enemy within RAIN_CONE 0.55 rad and RAIN_DEPTH 10 m of that line takes one hit (RAIN_DAMAGE 20, knockdown, knockback 7). Recoil: velocity = facing x 7.5 + up 5.5 (normal gravity after). The body is pitched forward through align_up/align_w/align_hold: RAIN_PITCH 0.85 rad within 0.05 s of the blast, easing back upright over the rest of the state (smoothstep 35%..95%), released in exit(). Pose: the recoil flings both arms up and out, the legs trail, then the guns come in to the chest (no pivot spin). progtest: launched up 5.5 / forward 7.5 m/s, pitched forward 0.73, upright again (0.05 rad) when it ends, the scatter hits the grunt below; then puts the player back on land.
- 2026-10-06 shooting hold: shoot_r/l arms higher and straight (arm 1.5 + aim_pitch, fore 0), keyed in seconds from _action["dur"] (kick 0.03 s, settled 0.13 s, held until the last 0.3 s); shoot_state plays them dur + LINGER 1.0 so the arms stay up about a second after firing (any other action, e.g. reload or dash, cuts it). Dual-pistol guard uneven: right arm 0.48 / elbow 0.85, left 0.22 / 0.5.
- 2026-10-06 floating islands/ships on the horizon (capture 003049): the ocean's sky_haze emission was distance-gated 30..160 m, but islands/ships only get the scene depth fog (begin..end, curve 1.6: ~8% at 255 m in clear weather), so the sea under the Redtide fort (255 m) was already sky-coloured and the fort sat on a band of haze. The gate is now smoothstep(0.7 x fog_end, fog_end) via a new shader global `fog_range` (vec2 begin, end; project.godot [shader_globals], set by Weather with sky_haze). tools/dev/horizonshot.gd renders it. Dual-pistol shots: no camera shake (0.04 decays in ~1 frame = a one-frame jolt per shot, read as stutter) and no hitstop/shake on their hits; single pistol unchanged. Dual guard right elbow 1.1 (up a little).

## 2026-10-07: cloth/hair haze, belts through coats, legs through boots (captures 143723-143746)
- Haze on coat tails and hair: SpringChains simulated against the anchor's global_transform, which under physics interpolation is the last physics tick's pose, while the body renders at the interpolated pose; at 165 fps vs 60 ticks the chains were shaken back and forth relative to the body every frame. simulate() and the body colliders now use get_global_transform_interpolated() (like the ragdoll's drive).
- Belt/sash under a coat: a closed band 1 cm inside the coat shell was pushed through it by vertex snapping (PSX snap at 320x180). With any coat, the belt and sash are a front arc only (+-1.25 rad, open loft) and the sash knot (and its physics tail) sits in the coat's opening.
- Legs through boots: the trouser hem flared to 4 mm inside the boot shaft, and the tall boot's cuff reached into the knee's blend band (bending, the skinned knee rings pushed out through it). _boot_top(): inside any footwear the shin rings are tucked 8 mm in and no hem flare; tall boots' shaft/cuff end just below the knee band (cuff -0.19 Ls .. -KNEE_BAND - 0.012).

## 2026-10-07: hats over hair, clothing layering, new hairstyles
- Hats: hair clumps, bangs, cowlicks and spikes sit outside the hair shell, which hats are sized to, so hair poked through every hat (wild worst). BodyBuilder._press_under_hat() runs after _hair on the head's hair and its strand sim mesh (MeshBuilder.map_vertices): every hair vertex above _hat_cut() (brim 0.262, bandana 0.241, knit 0.244 x yk; hood: all) is pulled in to the scalp + 4 mm (easing from hair_off over the first 14 mm above the cut) and under the crown. 4 mm because the hair material is drawn 1 cm toward the camera ("pull"): anything nearer the hat showed through it. Under a hat the ponytail / twin tails tie lower (below the brim), the bun becomes a low nape bun, the topknot is tucked away, crown cowlicks only with no hat (the bandana used to grow them through itself). Hood: its own profile with the opening's edges set back along the cheeks (it hid half the face from any angle but straight on).
- Clothing: the tunic's skirt was a rigid tube on the torso (thighs through it, ragged white shards under vests/coats): now 6 cloth panels (_cloth_sectors, new top_off 0.014 so the belt sits over them, flare 0.012-0.032 so they hang inside coat tails; tucked away with a skirt). The jacket's rigid hip hem likewise became short tails (cloth panels). Apron: out past a vest/corset, narrow (0.1) in a coat's open front instead of through its tails. Scarf: outside a coat's collar. Pouch: on the belt in a coat's front opening instead of through the coat at the hip.
- New hairstyles (CharacterLook.HAIR; HAIR_MASC / HAIR_FEM for random looks): swept (long bangs swept over one eye), messy (uneven mop, tufts out over the ears), slick (_comb_strand: flat strands laid over the crown from the hairline, built with add_rings along the scalp), topknot (crop sides, knot + tail, tie), hime (blunt bangs, cheek-length side locks, _back_strands long straight back), twintails / side_pony (_tails: tied physics tails, _hair_tie), bob (jaw-length clumps all round). HAIRLINE_OF / hairline_for() map styles to shared hairlines; hime and bob hide the ears.
- tools/dev/outfitgrid.gd (combination sheets) and tools/dev/hairtest.gd (in run_all).
- More styles from Zach's reference sheet: quiff (_comb_strand with `lift`: the front rolled up and back), curtains (middle part, fringe falling to both sides, an antenna strand off the crown with no hat), spiky (ragged fringe + 16 short spikes), shag (wolf cut: choppy layers to the shoulders, fringe over one eye), swoop (crop sides, _sweep_strand: the top swept from the left round to the back right, ends standing out), low_pony (_low_pony: gathered at the nape on the right and drawn over the right shoulder, tied), layered (shoulder-length layers flicking out, curtain bangs), lob (long bob, side-swept bangs), braid (_single_braid: one thick plait down the back, tied at the end; face-framing strands). Hair ledges (Zach): every clump started at full width with a flat cap, half its thickness outside the hair shell, so bangs/tufts showed a flat step from the side. _clump now starts with three rings above the root (0.05 / 0.028 / 0.012 m higher, width 0.25 / 0.6 / 0.88, sunk 1.4 / 0.6 / 0.15 x its thickness into the shell) so it slopes up out of the cap; _path_strand swells out of the cap the same way over its first fifth. Checked before/after with hairshots at 60 and 100 deg. New helpers: _scalp_pt (hair surface point lifted along the head's normal), _path_strand (flat tapering strand through any head-local path, add_rings), _sweep_strand. hairtest: 50/50 builds, nothing pokes out under any hat.

## 2026-10-06: blood + dismemberment (always on)
- FX.blood(pos, dir, n): square red flecks thrown along dir (arcing down), a little red mist, and FX.blood_splat on the ground ahead: an irregular flat blob (+ droplets) laid on whatever the ray hits (layer 1), up to MAX_SPLATS 60 (oldest go), each shrinks away after SPLAT_LIFE 40 s. On every grunt/boss hit that lands (PirateGrunt._take_damage; not blocked, not burning) and on the player (not dot).
- HitData.sever (cutting blows: blade/claw light and heavy attacks, the katana draw and air slash, a sword plunge): as the killing blow, PirateGrunt._on_died severs a head (40%) or an arm with SEVER_CHANCE 0.6 (a full-charge draw, crumple, always). Humanoid.sever(part, v) (mirrored to co-op peers): Ragdoll.detach() frees the part's joint and throws it; an arm first gets ArmBody.bake_arm() (CPU-skinned copy of the posed arm mesh: MeshInstance3D.bake_mesh_from_current_skeleton_pose needs a renderer-side skin and fails headless) as "SeveredArm" on the arm node, the skinned arm hidden, and Ragdoll.weld() rides the forearm rigidly on the arm body. A dark-red "Stump" on the torso at the joint's rest spot spurts blood 5 more times. Net.hit_pack now carries crumple, breaker and sever (guests' katana crumple / running draw didn't reach the host before).
- tools/dev/goreshot.gd renders it; katanatest checks splats, a severing kill, and a baked severed arm.
- Darker blood (FX.BLOOD 0.3, 0.01, 0.02; the flecks use it straight). The spray also splats whatever it meets within WALL_REACH 2.4 m along the blow (slightly downward, layer 1, surfaces steeper than ~45 deg): FX._place_splat(at, normal, size) lays a splat on any surface; blood_splat is the downward case.
- Katana: in the air (no action) it's held out behind one-handed like the dash (KATANA_TRAIL, shared with the dash) and the hilt IK is off; drinking keeps the katana in the right hand (no hilt IK during "drink").

## 2026-10-06: katana
- Item resources/items/katana.tres (weapon_model "katana", damage x1.15, icon from gen_psx_textures.gen_icons; found in the starter island's cove stash). Props.weapon_mesh("katana"): right-hand grip at the origin just behind a round guard, wrapped hilt to +0.26 (left hand at +0.17), blade to -0.85 curving toward +Y; Props.saya_mesh() scabbard.
- Player: class stays "sword" (sword skills, sword_pct), style() "katana"; never dual (_offhand_valid). REACH "katana" (2.5 x 2.2 m) and "iai" (3.0 x 2.4).
- Humanoid: is_katana() (mesh meta model); _build_saya() makes KatanaSocket under the torso at the hip socket (scabbard down-back from the left hip, edge up) with the Saya mesh, rebuilt in set_weapon/apply_look; sheathed, the blade sits in it (+0.04 so the guard rests at the mouth). Stance "katana": KATANA_GUARD (two-handed, blade up and forward), KATANA_HANG for block and parry (both hands overhead, blade hanging point-down in front). _katana_hands() runs after posing: the left hand IK'd onto the hilt (except draw/sheathe/iai_slash and one-handed at a sprint); in iai_ready the right hand IKs to the hilt at the scabbard and the left to its mouth. reach_left_hand is now reach_hand(right, target, pole). Draw/sheathe end/start in KATANA_GUARD.
- Light combo (light_attack_state STYLES["katana"]): katana_r (blade up behind the head over the right shoulder, held, long diagonal down-left: trail kesa_r), katana_l (round to the left shoulder, wide flat cut across to the right stepping through: sweep_l), katana_stab (drawn back to the right hip, driven out through a long lunge: thrust). Lengths 0.85/0.85/0.9 s, hits ~0.33-0.5 s, damage 16/18/26, deep lunges (_strike_lift). FX slash kinds kesa_r, sweep_l, iai.
- Heavy = Iai state (scripts/player_states/iai_state.gd, player.tscn node "Iai"; combat_input routes heavy there for style katana). Holding heavy: iai_ready (blade back into the scabbard at 0.1 s, low forward lunge via _iai_pose, feet shuffle when moving), creep at x0.3 move speed facing the camera, charge levels at 0.5 / 1.2 s (sparkle + rising blip, impact at full). Attack while holding: iai_slash, dash DASH_SPEED 11/15/20 m/s for 0.18 s through enemies (collision mask 12 off), damage 20/34/55, recovery 0.42 s. Let go of heavy first: stands down (draw). Interrupted: _finish_action puts the blade back in the hand.
- Full charge crumples: HitData.crumple (with knockdown). PirateGrunt._crumple(): limp ragdoll (alive = false, no throw, no spin), root ignores players while down (mask bit 2, restored on any other state), gets up after 0.6 s once nearly still (or 1.0 s). _down_min replaces the fixed 1.0 s.
- tools/dev/katanatest.gd (in run_all). posebench: the first view of each pose waits 20 frames (the "three" shots used to show the previous pose still easing).
- Same day, Zach's notes: dashing with the katana lets go with the left hand (the dash's free-hand fling) and trails the blade out behind in the right (arm -0.85, hand -2.3; no hilt IK during "dash"). Slash trails kesa_r / sweep_l / iai ran the opposite way to the cuts: their arcs are reversed (the stab's thrust trail was fine). The drawing stance is no longer a lunge: _iai_pose sets only the upper body (chest pitched -0.55, turned a little) and adds a slight crouch to the gait's own legs (thighs +0.28, shins -0.5, lift locomotion + IAI_CROUCH -0.12); the charge creeps at CREEP 0.2 x move speed.
- Running draw: Humanoid._update_run_sheath() (before locomotion): sprinting (> 6.5 m/s, grounded) with the katana out puts it in the scabbard, hands on hilt and scabbard (_hands_on_scabbard IK, chest -0.15), and takes it back in hand when the run ends (only between actions; puppets do the same from synced sprinting/armed). Light attack at a sprint: combat_input sets Player.quick_draw, LightAttack uses STYLES["katana_draw"] (one hit, "quick_draw" anim: a fast flat cut across to the right out of the scabbard, impulse 6, damage 14, hit 0.05-0.2 s, trail iai) with HitData.breaker: slips past a grunt's guard, breaks the red wind-up (like Haki) and staggers (1.0 s) whatever it was doing; breaks the boss's slam before he leaves the ground and his wind-up armour. katanatest covers the sheathed run, the running draw breaking a peril wind-up, and the blade back in hand after.
- Tweaks (captures 020020/020032): the scabbard hand's IK pole is now back and down (global_basis * (-0.15, -0.5, 1.0)) so its elbow tucks along the body instead of sticking out; drawing-stance chest lean -0.45 (was -0.55). Running draw: impulse 9 (was 6), length 1.3 s with the follow-through held until the last 0.3 s (quick_draw keyed in seconds), the state commits for 0.95 s.
- Katana air attack (plunge_state `_slash`, once per jump: Player.air_slashes, reset on the floor, refused in air_attack_input): SLASH_BOOST 4 m/s up (variable jump off), stick drift x0.5, "air_slash" pose (knees up unevenly, blade whipped up and back one-handed with the chest wound round, then an overshooting ("back" ease) arc down under the body with the pivot pitched forward, then guard), hitbox SLASH_HIT 0.17-0.34 s with REACH "under" (3.2 x 3.6 x 3.2, centred 1.4 m down), damage 24, trail "under" (a vertical arc from up front round under the feet). No hilt IK during it. katanatest: lift, hits the grunt below, one per jump. Later the same day the air slash was turned to cut left to right: wind-up over the left shoulder (arm 2.6, -0.45, -0.8), the arc down under the feet and up out to the right; trail "under" now in the body's left-right plane (160..380 deg, leaned 0.3 forward).
- Katana parry/block: arms lower and further forward (KATANA_HANG arm 1.55, fore 0.65), and the wrist is set directly by _hang_blade() (Euler wrist angles kept pointing the blade into the body): the blade along HANG_DIR (-0.6, -0.6, -0.55) in the body frame = point down, out in front, slanted across to the left; eased in over 0.08 s of a parry. katanatest checks down/out/across.
- Bug: the katana grew with every parry. _hang_blade wrote hand_r's world basis back with its measured world scale, so rounding fed back each frame (the animator's `rotation =` keeps the local scale). Now it sets hand_r.basis = rotation (in the parent's frame) x the hand's own local scale. katanatest checks the blade's scale before/after a parry. Parry/block lean forward a little (KATANA_HANG torso -0.18, head 0.24).
- Katana parry/block feet wider (KATANA_SPREAD 0.12 rad leg roll: in the parry's crouch keys, and on the gait legs while guard_block plays). Air slash angled forward: the "under" pose reaches further ahead (arm 0.75, pivot -0.28), trail plane leaned 0.65 forward, REACH "under" centred 0.9 m ahead (3.4 deep).
- r10test now also: planted-foot slide on diagonals/backpedal < 1.6 m/s (pure strafes < 2.0), hips turn > 0.5 rad into a diagonal with the chest within 0.15 rad. All 24 suites x 2 Godot versions passed in one go; co-op default + water OK.

## 2026-10-07: v1.5 on the title
- project.godot application/config/version="1.5" (bump it for the next release; the ribbon and the pop-up read it).
- Title screen: a red version ribbon beside the logo (RIBBON rect, glint; click it to open what's new) and a "What's New" menu item. scripts/ui/whats_new.gd: the version's NOTES (heading, line), shown by itself the first time a new version is opened (user://whats_new_seen.txt holds the last version seen; "Set sail" or Esc marks it). Update NOTES each release.
- Render: tools/dev/newsshot.gd (clears the seen file, shoots the pop-up and the menu).

## 2026-10-07: cutlass polish
- The wrist cuts now: hand_r cocks the blade back in each wind-up and flings it out along the arm into the cut (before, it stayed upright and the swings read as waves). slash_r is a diagonal forehand (high over the right shoulder, down across to the lower left), slash_l a flat backhand (back past the left shoulder, out level to the right; the upper arm untwisted at the strike - twisted, the wrist bent the blade back up), spin_slash flings the blade out level for the turn. The off arm no longer sticks straight out.
- SWORD_GUARD (Humanoid._guard() for stance "sword"): side on, blade angled forward, off hand up; the thrust heavy blends from and back to it.
- Hitbox timing matches the strikes ("starts" 0.11/0.1/0.13, "ends" 0.21/0.2/0.42; was 0.08-0.24 for all, opening before the swing and closing halfway through the spin).
- Running cut (LightAttackState "sword_dash", anim dash_cut): attacking at a sprint with one cutlass (Player.quick_draw now covers sword as well as katana) - a low cut driving through the target, impulse 12, breaks wind-ups.
- axetest also covers the cutlass: its style, combo, guard and running cut.

## 2026-10-07: the axe's own moveset
- Player.style() is "axe" for an axe in the main hand (two axes are still dual_sword); it counts as a blade for sword_pct.
- Light combo (LightAttackState.STYLES["axe"]): axe_hack (hauled over the right shoulder, hacked down across to the lower left), axe_hook (dropped low left, ripped up and across to the right), axe_split (two-handed, a hop, smashed into the ground ahead: knockdown, dust ring, thud). Slower than the cutlass (0.46/0.46/0.72 s), harder (14/15/30).
- Heavy (right click): the whirlwind (HeavyAttackState "whirl", anim axe_whirl): two-handed, two full turns (pivot -2 TAU), reach "whirl" (4.4 m box all round), first turn staggers, the second (rehit at 0.36 s; the hitbox off 0.06 s before so those inside re-register) knocks down; steerable at 0.45 x walk. Replaces the old one-handed overhead chop (axe_heavy, removed).
- Jump attack (PlungeState, Skybreaker): springs higher (4.5 m/s) into a forward somersault (axe_flip, held 0.36 s), dives like the plunge, lands into axe_land and splits the ground: a 1.6 x 5.5 m box ahead knocks down everyone along it not already hit on the way down (18 dmg).
- Humanoid: AXE_TWO_HANDED actions put the left hand on the haft (_axe_hands, like the katana's). axe_whirl and axe_flip are SPIN_ACTIONS. heavyshots.gd takes an optional stance arg.
- axetest (new): style, the combo and its knockdown, the whirlwind behind you and its second turn, Skybreaker's somersault, landing and ground split reaching a grunt ahead.

## 2026-10-07: more clothing and armour; a plainer character creator
- New looks (BodyBuilder): hats cavalier (broad brim, plume), morion (crested steel helmet), turban (wound cloth, a jewel); vest-slot armour cuirass (breast- and backplate, front ridge, two lames), brigandine (studded leather), mail (a ring shirt to the hips: fabric texture, metal tiled read as stripes); coat greatcoat (long tails + a short cape over the shoulders); feet greaves (tall boots, shin plates, knee cops); hands gauntlets (look key `gauntlets` with gloves: a vambrace past any sleeve and plates on the hand, on the forearm so they stay when the hand swaps to a fist); accessories cape (`cape`, `cape_color`: cloth on a chain hung out past the deepest point of the back's ring profiles, only the thighs colliding - the torso's and hips' colliders twisted it) and bandolier (strap shoulder to hip, cartridges). Steel uses the metal texture at uv 0.5.
- Gear: names, descriptions, defense (cuirass 7, morion/brigandine/mail/greatcoat 5, greaves 4, gauntlets 3...), STEEL_PIECES named without a colour, hands slot owns `gauntlets` too, GearIcons shapes for all of them. PLUNDER + Gear.random_piece: pirate prize chests have a 40% chance of a piece (green/blue, now and then purple).
- Character creator: CREATOR_HATS/VESTS/COATS/FEET (plain clothes: no tricorn/bicorne/cavalier/morion/turban, no corset or armour, jacket the only coat, no tall boots or greaves) and no pauldron toggle; Randomize uses the same. The starting captain is a bandana, jacket and boots. Hats of rank, coats of office and armour are bought (Sela: cavalier, turban, greatcoat, cape, bandolier; Vey's Armoury: morion, brigandine, mail, cuirass, gauntlets, greaves - Vey now buys gear too) or plundered. Pirates now and then wear mail/brigandine, a morion, a bandolier.
- Fixed: Sela's gloves had "gloves": "gloves" (a String into a bool).
- qoltest: the creator's lists and Randomize stay plain; every new piece wears, has an icon and guards better at blue; gauntlets plain-named. Renders: tools/dev/armorshot.gd (lineup, "close a b" for two up close), tools/dev/capeshot.gd (worn through the slots in the world, front and back).

## 2026-10-07: weapon designs
- WeaponDesigns (scripts/props/weapon_designs.gd): 27 looks from a few numbers each. Cutlass family: cutlass, naval sabre (stirrup guard), scimitar, broadsword (basket), rapier (cup), falchion (clipped point), hunting hanger (shell guard, stag grip), dao (ring pommel, tassel). Katanas: katana, uchigatana (square guard, red cord), nodachi (longer), tachi (deep curve, flower guard), kuro katana (dark blued blade: black blades are Supreme's alone), wakizashi (short), ninjato (straight). Axes: boarding axe, hatchet, bearded, double, ship's cleaver, war axe (crescent + spikes). Pistols: flintlock, duelling, blunderbuss (bell), double-barrel, pepperbox, dragon (brass, glowing eyes). Each design is an item (DESIGNS[kind][design]["id"], made by ItemDB from the kind's base .tres: name, description, damage x dmg, value x worth).
- The tier shows on the weapon: rare blued fittings, epic dark fittings + a purple gem, legendary gold + a gem, ultra a crimson blade with a glowing edge, supreme an obsidian blade with a pale glowing edge.
- Model strings: ItemData.model() = "<kind>:<design>:<tier>"; Props.weapon_mesh(model) builds it (only the rifle is still in Props) and the mesh carries the string, so co-op (HumanoidSync), drops and dual wielding rebuild the same weapon. ItemData.weapon_model stays the kind ("katana", "pistol"...), so styles, guns and cannonball cutting are unchanged. Humanoid.is_katana reads the kind from the model; a katana's scabbard is scaled to its blade (WeaponDesigns.sheath_scale).
- Icons for every weapon, design and tier are drawn from the mesh (side on, corner to corner, a dark outline; texture tones from TEX_TONE so it works headless). The painted cutlass/katana/axe/pistol PNGs are no longer used for weapons.
- Pirates each carry a random cutlass-family blade (grunts and ship crews) and drop that one. Vey stocks a dozen designs (white/green); pirate prizes and the Sea King's hoard roll any design of any kind.
- qoltest: every design is an item with an icon, a tiered rapier's model, a nodachi is a katana with a longer scabbard, pirates carry different blades. Renders: tools/dev/weaponshot.gd (racks per kind, tiers, icon sheet), tools/dev/handshot.gd (in hand).

## 2026-10-07: item tiers, clothier + armoury, slower levelling
- ItemData.rarity (enum Rarity: Common white, Uncommon green, Rare blue, Epic purple, Legendary yellow, Ultra red, Supreme black; RARITY_NAMES/COLORS). A tier adds RARITY_DAMAGE 8% per step to a weapon (power()), RARITY_DEFENSE 25% per step to gear (armor()), and multiplies what it's worth (worth(), RARITY_VALUE 1 / 1.6 / 2.6 / 4 / 7 / 12 / 20). Player.damage_multiplier and EquipmentComponent.defense use them; traders pay by worth.
- Tiered copies: ItemDB.tiered(base, tier) / get_item("<id>@<tier>") duplicates the base with its own id (saved, stacked and sent by that id); the base's own tier gives the base. Gear: Gear.make(..., tier) (id gets "@tier"); SaveGame gear refs carry the tier (older refs: common).
- Shown: tier colours on bag/doll slot borders (Supreme: a pale slot, black edge), the name in the item info (with "Epic weapon" etc.), the loot feed, shop rows (and the tier in the hover note). Black text gets a pale outline (ItemData.rarity_outline).
- Tiers set: treasure green (value 16: worth 26), stew green, katana green (base 1.065: still ~1.15), Red Tide epic (base 1.13: still ~1.4), Devil Fruits legendary; the rest white. Brinehollow's stock is white and green only (qoltest checks). At sea: pirate prize weapons green/blue (6% purple); the Sea King's hoard rare treasure and a purple (25% yellow) blade. Nothing drops Ultra or Supreme yet.
- Clothier Sela (renamed; jackets, coats, corset, gloves, breeches, boots, pauldron... buys clothes at 60%) and Vey's Armoury ("Buy or sell weapons": white and green steel, buys weapons at 60%). Nessa still buys anything at her rates.
- Levelling: Progression.xp_to_next doubled (100 x lv^1.3), so XP rewards stay readable and levels come half as fast.
- qoltest: Brinehollow's goods white/green, the XP curve, selling clothes to Sela and a blue cutlass to Vey, tier power. Render: tools/dev/tiershot.gd.

## 2026-10-07: Brinehollow QoL (traders, capstan + chain, compass, chart marks)
- Traders: scripts/game/shops.gd (SHOPS: name, line, stock [item id, price] or [gear slot, style, look, price] made with Gear.make, and what they buy: item kind -> share of `value`). ShopScreen (scripts/ui/shop_screen.gd, GameMenu "shop", open_shop(id)): for sale left, what of yours they'll buy right (Sell / All), gold from your bag, hover for descriptions; its own coin AudioStreamPlayer (menus pause the tree, so FX.sfx is silent there). Nessa (dialogue "Let's trade", a fence: loot at full value - treasure 25 - gear and weapons half), Gus ("Something to eat and drink": rum 8, new stew 18), Marlo (new grilled fish 5), Sela (hats, coats, vest, boots, sash, scarf), Old Ida (new hardtack 3, rum), Vey ("I need a better blade": cutlass 45 / axe 70 / pistol 90 / katana 160; buys weapons at half). Bark-only NPCs take cfg "shop" (prompt "Trade with ..."; the stall opens after their line). Dialogue events "shop:<id>" / "shipwright" open their screen when the talk ends (GameMenu._after_talk); closing a stall saves.
- New items fish/stew/biscuit (resources/items, icons from gen_psx_textures.py, which now takes `icons` to redo just the icons).
- Gold counter (HUD, top right under the clock): shows for 4 s with +/- when your gold changes, always with the inventory open.
- The yard: a column on the left, no dim, a camera circling the ship on the right (h_offset -6.5) while you pick; GameMenu ends the preview when leaving the screen. Right-click a look steps back.
- Anchor on a chain: a capstan on the foredeck (CAPSTAN_AT, with a collider), chain along the deck to the rail, and 36 links down to the anchor shown as it's let go. Hold F at the capstan (kneeling, ANCHOR_TIME 1.6 s) lets go / weighs; Net.ship_anchor routes it to the ship's owner (helmsman or host). Space at the helm still works. net_take_over now carries `anchored` too.
- Auto-anchor: leaving the wheel within PORT_REACH 40 m of a DockingArea lets the anchor go ("Anchored in port").
- Kneel fix: Player cleared body_model.kneeling every physics tick when nobody needed reviving (and every tick in single player), which made the ship jobs' kneel (patch, douse, capstan) flicker. Now only a revive's own kneel is ended there.
- Compass strip (scripts/ui/compass_strip.gd, HUD top centre; below the boss bar when it's up): at the helm, aboard, or whenever chart marks are set; N/E/S/W, where the wind blows from, the crew's marks with distance.
- Chart marks: click the chart to set one (up to Net.MAX_WAYPOINTS 6 each; the oldest goes), right-click one to remove it, C clears yours and your G marker. Net.waypoints {net id: [Vector2]} via everyone("_all_waypoints"), in the join world state, dropped when a captain leaves. Drawn on the chart (numbered flags, crew colours), in the world by MarkerLayer (flag + number + distance, pinned to the screen edge) and on the compass. Your own clear themselves when you come within 25 m.
- Gus: "What's out in the deep water?" tells of the Sea King and charts its lair (event "rumour_king").
- Sea King: TAIL_WARN 0.6 s before the slam, a roar and a pale ring over the whole deck (follows the ship).
- Hull hits float "-N hull" over the spot (Ship.hull_hit -> Net.fx float_text).
- qoltest (new): stalls trade, selling treasure, buying, gear to order, no gold no sale, gold counter, the yard camera and back, right-click back, capstan kneel + let go + chain + weigh, the compass at the helm, auto-anchor in port, chart marks set/remove/clear/reached, the rumour, hull numbers. seatest: the tail warning. shiptest weighs anchor after its helm re-take at the dock. Render: tools/dev/qolshot.gd.

## 2026-10-07: sea polish (foam wakes, turquoise shallows, rain on deck)
- Foam wakes: Ship/EnemyShip._wake call Ocean.wake(hull, stern, speed/9) every tick under way (> 1 m/s). OceanManager keeps a trail per hull (a point every WAKE_EVERY 0.45 s, WAKE_PTS 18, WAKE_LIFE 8 s, plus the live stern) and sends the two trails nearest the camera to ocean.gdshader as `wake[40]` (x, z, age, strength; a zero point between hulls) with a bounding `wake_box`. The shader takes the distance to the nearest point of the whole trail (per-segment maxima drew a ring at every joint), then: churned water within ~half the width for the first ~2.4 s, and two arms at half-width 1.2 + 0.85 m per second of age; broken up in 0.5 m noise cells that thin out as it ages.
- Turquoise shallows: WorldGenerator.bake_shallows() bakes the seabed depth (r = -height / Ocean.SHOAL_DEPTH 14 m, 0 on land) into two L8 textures: the world heightmap (257 px over 5 km) and Brinehollow's own terrain (140 px over 420 m, it isn't in the world heightmap). ocean.gdshader: shoal_depth() picks the fine map inside fine_rect; over shoals the colour goes to shoal_color (a lacing of light on top), a broken line of surf where it's almost dry, and the water is clearer (alpha -0.22). WorldGenerator._exit_tree clears the rects (the title sea has none).
- Rain on deck: Ship.wet rises with Weather.rain (full in WET_TIME 50 s of heavy rain), dries in DRY_TIME 160 s. The deck planks (a per-ship copy of the deck material) darken with it; six ragged puddles (PUDDLES, glossy dark StandardMaterial) grow in turn as it soaks, run to the low side as she rolls and pitches, and drops splash in them while it rains.
- yardtest: shallows baked (Brinehollow dry, open sea deep), a wake laid under way, rain soaking but not yet pooled, pooled once soaked. Render: tools/dev/polishshot.gd (wake astern and from above, shallows at Brinehollow and an island, puddles in the rain).

## 2026-10-07: the shipwright (Tackett's yard)
- Shipwright Tackett (NPC, data/dialogue/tackett.json) at the foot of the Brinehollow dock by a timber stack. "Let's see what you can do for her" shows a node with `"event": "shipwright"`; GameMenu remembers it and opens screen "yard" (scripts/ui/shipwright_screen.gd) when the talk ends. Closing the yard saves.
- ShipKit (scripts/ship/ship_kit.gd, class_name): the kit Dictionary (GameManager.ship_kit, saved as "ship_kit"; a guest keeps their own like ship_pos). Refits, once each, for gold from the inventory: armour 220 (max_hull x1.4, topped up; iron straps + rubbing band, node "Armour"), guns 180 (third pair at GUN_SPOTS[2], z 2.2: three a side), sails 150 (top speed x1.15, rig scaled 1.18 x 1.12), rudder 120 (MAX_TURN and rudder rate x1.3). Looks, free: hull paint (6, a per-ship copy of the plank material on the hull surfaces), sails (5), flag field (6) / emblem (none, skull, crossed swords, anchor, star) / emblem colour (4) painted into a 48x30 image, figurehead (none, mermaid, lion, sea serpent, eagle; MeshBuilder, x1.7 under the bowsprit).
- Ship.apply_kit(kit) puts it on (called in _ready from GameManager, after a load, and on every screen via Net.set_ship_kit -> everyone("_all_ship_kit")); Ship.MAX_HULL is now the base: use ship.max_hull. The flag is its own mesh ("Flag", 1.4 x 0.85, flying aft of the masthead).
- Co-op: the host's world, so only the host orders work (a guest sees the yard greyed out with a note); the kit is in the join world state.
- yardtest (new): Tackett is there, his talk ends in the yard, no gold no refit, each refit's effect and cost, once only, paint/sails/flag/figurehead, looks free, every figurehead builds, saved and loaded. nettest: the host's refit reaches the guest's ship. Render: tools/dev/yardshot.gd.

## 2026-10-07: the Sea King
- scripts/enemies/sea_king.gd (groups net_sync, sea_kings), made by SeaFeatures at a lair from `_open_spot(80)` placed LAST so the seed keeps every other feature where it was. Hidden (LURK) until our ship is within NOTICE 220 m of the lair with a captain aboard; then RISE beside her (banner, roar, charted "king": the chart draws "here be a Sea King"), CIRCLE at 24 m with its head 5-8 m up, picking every 4-7 s: BITE 50% / TAIL 30% / DIVE 20% (comes up on the far side, spin reversed). Leaves (dives, back to LURK) once the ship's out of range or unmanned.
- BITE: REAR 1.3 s over a random deck spot (FX.telegraph with `follow` = the ship's key, so the ring rides the deck), STRIKE, then DOWN 1.7 s with its head on the planks (DOWN_Y 1.3) - the window for blades. Hull 45 (Ship.hull_hit, host) and 34 + knockdown to a captain within BITE_R 3.6 not more than 1.6 m above the deck (jump it), judged per screen like pirate_boss._aoe_local.
- TAIL: the last 6 pieces lift to 12 m 9 m off her beam (segments stretch to fit), slam at 1.75 s: Net.everyone("_all_rammed") - now also calls Ship.jolt(push) (roll/pitch/heave kick) - knocks down anyone standing on deck.
- Body: 16 tapered pieces following the head like a rope, sinking toward the tail (Ocean height - 0.3..4 m); head x1.4 on a child (the head's basis is set outright). roof_tiles tinted green for scales, leather belly, red fins.
- Hits: Hurtbox on the head (layer 32, r 3.6); crew cannonballs test `struck(from, to)` against head and body along their flight (they only raycast bodies), direct hit = cannon damage x1.5 (siege), near misses count like enemy ships. HP 1600 x Net.hp_scale. Dead: sinks, banner, floating hoard (gold 90, treasure 6, rum 3, each captain their own), XP 400 within 120 m, back after 600 s.
- Co-op: net_pack = state, hp, head pos/rot, jaw, the 16 piece positions, visible; guests interpolate. bite/flash/dead/banner are events.
- FX.SOUNDS was missing bell, cannon, cannon_hit, horn, roar, rope, splash_big, wood_crack (generated but never registered: every ship sound was silent). Added.
- seatest steps 360-44: lurks unseen; rises for a manned ship and charts; circles 12-40 m off; ring on deck; bite holes the hull and hits the captain; head down on deck; a blade hurts it; tail tip rises > 5 m and the slam throws the captain; a deck gun's ball strikes it; killed it sinks, the hoard floats, it's gone under. Render: tools/dev/kingshot.gd.

## 2026-10-07: the sea chart (M)
- New input action sea_chart (M). GameMenu screen "chart" (scripts/ui/sea_chart.gd, preloaded; also "Sea Chart" in the pause menu and the controls list): a 560x320 parchment, Brinehollow in the middle, north up, REACH 1400 m to the short edge, a 500 m grid; anything past the edge is pinned to the margin. Draws charted islands (names), Redtide Rock, reefs, whirlpools, fog banks (their extent), wrecks ("picked over" once looted), a red X for each treasure map held and not dug, the ship (pointing its heading) and our captain.
- Charting (SeaFeatures._chart_near, every 0.5 s, our captain): islands within radius + 250 m ("island:<name>", toast "Charted ..."), Redtide within 350 m, reefs/whirlpools/wrecks within 220 m, fog banks within their radius + 320 m. GameManager.charted is saved.
- seatest: passing a reef charts it, coming near an island charts it, M opens the chart. seashot's last shot is the chart with everything charted.

## 2026-10-07: wrecks, bottles, buried treasure
- SeaFeatures: 3 wrecks (StaticBody heeled 0.32 rad, sunk to -0.95, HullBuilder "wreck" option: mast snapped short, no sail/flag/lights; collides, so you can climb onto the high side) each with a LootBag chest ("wreck_<i>", remembered via GameManager.opened, removed at load by apply_world_state); wrecks go into EnemyShip.no_go. 4 treasures: an X of planks on a beach of the first 4 islands (height 1.2-7 m, 45-70% of the radius out), hidden until its map is known; "Dig up the treasure" spawns a chest (gold 40-70, treasure 3-6), XP 60, "treasure_<i>" opened. 4 bottles bobbing at open spots (glinting every 1.4 s within 160 m), each with a treasure's map: "Fish out the bottle" (usable in water) -> GameManager.maps[i], banner naming the island.
- GameManager.maps and .charted (sea chart) are saved ("maps", "charted"). island_infos now carry "name".
- seatest: wrecks/bottles/treasures exist; the wreck heels over with a chest that's remembered once looted; no X before the map; a bottle gives the map and shows the X; digging gives a chest once.

## 2026-10-07: sea hazards (reefs, fog banks, whirlpools, storm cells)
- scripts/world/sea_features.gd (WorldGenerator child "SeaFeatures", group "sea_features", placed from world_seed: identical on every screen). _open_spot: deep water 450-1500 m from Brinehollow, huntable, 260 m from other features. 4 reefs, 3 fog banks, 2 whirlpools, 2 storm cells; reefs (+30 m) and whirlpools (+10 m) go into EnemyShip.no_go.
- Reefs: 9 dark rocks (Props.rock_mesh) breaking the surface, the big ones with cylinder colliders (layer 1: they stop a hull); surf splashes near the camera. Ship host _damage_tick: over the shoals (reef_at) at > 1.5 m/s: hull - speed x 1.4/s, slowed, every 1.2 s a crack, dust, shake and a 40% chance of a hole.
- Whirlpools: current_at(p) pulls round and in (WHIRL_PULL 4.5 m/s, harder near the eye) - Ship adds it to its motion (every screen), swimmers get 0.7 of it; the eye (WHIRL_EYE 8 m) grinds 6 hull/s. Drawn by the sea itself: Ocean.whirls (Vector4 x, z, r, depth 2.6) -> OceanManager.funnel() and the shader's funnel() sink the surface (CPU and GPU alike, so floating things ride the funnel) and whirl_foam() spirals foam in to a dark eye.
- Storm cells: storm_at(i) wanders 180 m about its home with world time; Ocean.storm_cells (set each physics tick) -> local_swell() (x up to 2.1 at the middle) in get_wave_height and the shader's wave_h. Weather reads SeaFeatures.local_weather(camera): storm/rain/cloud/wind (storm cells) and fog (fog banks) never lower than the local value. Fog banks: 60 big soft billboards from 6 to 26 m.
- seatest: all four exist; a reef grinds and slows her; a whirlpool carries her round and in; a storm cell's swell x2.1 and the weather under it; fog inside a fog bank. (Tests moving the hull: Ship.place's new spot reads back after the next physics step.) tools/dev/seashot.gd renders them.

## 2026-10-07: holes, flooding, fires and the crew's jobs
- Ship.hull_hit (host) with >= 15 damage: BREACH_CHANCE 0.55 to hole her (add_breach: [id, deck spot at the rail above the hole], side and z from the impact, MAX_BREACHES 6, wood crack) and FIRE_CHANCE 0.35 to start a deck fire (add_fire: [id, spot, age], MAX_FIRES 5). Host _damage_tick (end of _physics_process): water comes in at FLOOD_RATE 0.012/s per hole (flood 0..1; at 1 she founders: crippled until it's under 0.5 and the hull over half); each fire burns FIRE_BURN 1.5 hull/s (no self-repair while anything burns) and after FIRE_SPREAD 14 s catches 1.6 m away. Flood: top speed x (1 - 0.55 flood), freeboard -0.6 flood, lists 0.12 flood toward her holes (_list_side).
- Sync: the host sends [breaches, fires, flood] on any change (and flood every 0.5 s while it moves) through Net.ship_damage -> Ship.net_damage; jobs come back through Net.ship_work(kind, id, amount) -> Ship.do_work on the host (patch / douse / bail).
- Every screen (_damage_view): flames + smoke on each fire, water gushing at each hole (a dark patch on the hull at the waterline, _rebuild_holes), 4 dmg a half second (dot) to our captain standing in a fire, and our captain's nearest job within WORK_REACH 1.6 m (hold F, HUD prompt with progress, kneeling): patch a hole (PATCH_TIME 2.2 s) from the rail above it, beat out a fire (DOUSE_TIME 1.4 s), work the bilge pump by the mast (PUMP_AT; BAIL_RATE 0.035/s while held, sent every 0.25 s). HUD: a blue water bar beside the hull bar.
- seatest: heavy hits hole her and can set her alight; half full she sits 0.34 m lower; a hole lets water in; holding F patches it; the pump bails; a fire burns you and F beats it out; awash she founders. nettest: holes reach the guest, the guest's patching reaches the host. helmshot's last shot shows a hole and a fire.

## 2026-10-07: wind and sail trim, the anchor, the sailing gauge
- Weather.wind_dir(): where the wind blows (unit x/z), swinging slowly round through the day from world time (same on every screen); strength stays `wind`. Cloud shadows and rain drift with it now (they had a fixed (1, 0.3)).
- Ship: speed target = MAX_SPEED x sail_shown x wind_effect(). wind_effect(): the point of sail from _wind_rel() (wind direction relative to the bow): running 0.85, a reach (60-100 deg) 1.0, close-hauled (135) 0.6, 158 deg 0.12, head to wind 0.08 (in irons), x lerp(0.85, 1.25, wind). The yard is in a "Rig" node on the mast (pivot (0, 9.2, -1.2)) with the sail and furled canvas: braced to rel x 0.5 (max 0.8 rad); the sail's belly (scale z) fills with the effect, and flaps (sin flutter) when it's < 0.3.
- Anchor: Space at the wheel (_read_helm) set_anchored(): stops her at 3 m/s/s whatever the sails, no turning; an anchor (boxes) at the cathead ANCHOR_AT goes down 4.5 m on a cable as _anchor_drop eases; splash + rope sound; toast. net_pack index 14 (PACK_SIZE 15), followed on the other screens.
- HUD: scripts/ui/sail_gauge.gd (PlayerHUD._sail_gauge, bottom right, aboard or at the helm): a dial with the bow up, north marked, the wind arrow coloured by wind_effect (red in irons .. green on a reach), knots, three sail pips, ANCHORED. Helm toast mentions Space: anchor.
- shiptest: now sails from open water with the wind on the beam (pirates cleared away first), and checks: head to wind she barely moves and the sail flaps; on a reach > 9 m/s with the yard braced; the gauge at the helm; Space anchors her (stops under full sail, anchor 4.5 m down) and weighs it again. helmshot's helmcam shot keeps the HUD.

## 2026-10-07: enemy ship kinds and tactics
- EnemyShip.KINDS (setup(..., kind)): sloop (the old one), gunboat (13 m/s, hull 150, 2 guns a side, 4 crew, red sail, rams), brig (8 m/s, hull 420, 4 guns a side, 8 crew (CREW_SPOTS grew to 8), black sails, rams, double broadside), marine (11 m/s, hull 320, long range 36-58 m, scatter x0.5, never boards or yields; white hull/sails, HullBuilder emblem "marine" = a painted blue gull (marine_material), crew in Marine whites: marine_look, the officer at the wheel in a white coat). Per kind: speed (_max_speed), broadside range, aim scatter, boards / rams / double / yields. HullBuilder.build takes "emblem" ("jolly"/"marine") instead of "jolly".
- EnemyFleet.add_zone(center, radius, kinds): each zone cycles its kinds by respawn generation. Zones: Redtide [sloop, brig], the lane to the nearest island [gunboat, sloop], plus WorldGenerator._open_sea() picks two more on deep open water ~600/850 m out, 400 m from other lanes: [marine], [brig, gunboat].
- Tactics (host): S.RAM (8): from BROADSIDE when it rams, has volleyed, hull > 50%, target slow (< 6 m/s) and within 45 m; heads for where the target will be at x1.15 speed; the hit is the bow meeting the crew ship's hull in _sail's test_move -> _ram(): hull_hit RAM_DAMAGE 45 x speed share (x1.4 brig), 6% of its own hull, Net.everyone("_all_rammed") knocks down every captain standing on that deck (camera shake near), backs off (-3 m/s) to BROADSIDE, RAM_EVERY 25 s. Double broadside: guns reload 1.2 s and a second volley follows 0.6 s after the first ("Again! Fire!"). S.FLEE (9): below FLEE_AT 25% hull it runs (once); escaped (> LOSE) it patrols, patching up to 60% at 1.5/s (won't hunt again under 40%); caught under YIELD_AT 15% within 40 m (if it yields) -> _surrender(): XP 120 and the prize (colours struck, chest), its crew stay aboard unarmed.
- seatest: all four kinds sail; brig 4 guns a side / 8 crew / heavy, gunboat 2 / 4 / fast, Marines in whites, never board; the brig rams (hull 400 -> 328, captain thrown) and backs off; the brig's double broadside is 8 shots; a holed gunboat flees, then strikes when caught. tools/dev/fleetshot.gd renders them side by side.

## 2026-10-07: boarding the pirates' ship
- Group "decks" (Ship, EnemyShip): aboard(p), deck_delta(). Net.deck_pack / deck_unpack: snapshot positions as [pos, deck key] relative to whichever hull you're over ("" = world), unpacked against its interpolated transform. Player.net_pack index 1 and grunt index 20 are now the deck key (was a bool for our ship only); Player._deck_ship / _ride_ship work on any deck, so jumps on a pirate deck are carried too.
- EnemyShip on guests: _puppet now sails its own copy from Net.latest (state carried forward to now with its speed and turn rate, net_pack index 11) and eases onto it (2.5/s, jumps past 8 m) instead of replaying snapshots 0.1 s late; transforms go through _place_hull (records _deck_delta). Rope ladders amidships both sides.
- A captain aboard (host, any state but SINK/DECK/PRIZE) -> S.DECK (6): bark + horn, _crew_to_deck() swaps every crewman still aboard, helmsman included, for a boarder-mode grunt where he stood ("DK_<ship>_<i>", alerted one after another; guests make the same puppets from the "deck" event); the ship stops. All of deck_crew dead -> _strike(): S.PRIZE (7), XP 200, "prize" event -> _prize() on every screen: the Jolly emblems hidden, "Prize taken!" banner, bell, each captain's own chest (LootBag "Prize_<ship>": gold 30-50, treasure, rum, 60% a weapon) on her deck by the cabin. A prize with nobody aboard for SCUTTLE_AFTER 60 s is scuttled (_start_sink(false): no XP, no flotsam).
- seatest: our captain on a pirate deck -> all hands (6 grunts, no crewman left standing) come at us; cleared -> prize, colours struck, chest on her deck; left empty -> scuttled.

## 2026-10-07: pirates keep off the land, ignore empty ships
- EnemyShip._crew_ship(): a target only with a captain Ship.aboard() it (was: anyone within 14 m, swimmers included); nobody aboard, nobody gets shot at.
- EnemyShip.no_go (static, WorldGenerator._build_redtide fills it): [centre, radius] for Brinehollow (HALF + 5), the Redtide rock (45) and every island (radius + 30). huntable_at(p): outside every circle by STANDOFF 60 m, so a ship pulling in to land or moored at a dock is left alone (replaces the old SAFE_RADIUS check; music still uses SAFE_RADIUS). _sail() bends every course with _steer_clear(): probes at the hull and LOOK_AHEAD 45 m ahead push the heading out of any circle.
- seatest: target only with a captain aboard, harbour and island shore not huntable, a patrol whose waypoints sit on an island keeps out of its circle (closest 148 m to a 137 m circle). r8test's hunt now happens out at sea (it used to park the crew's ship by the Redtide patrol).

## 2026-10-07: cutting cannonballs
- Cannonballs have ids (ShipCannon._shots, sent with the "fire" event: "<cannon key>#<n>", Cannonball.live) and, enemy ones, a Hurtbox (layer 32, r 0.9: catching one is timing, not a pixel hunt). Cannonball._on_hit: a cutting blow (HitData.sever) from a captain holding a katana or cutlass (CUTTERS, equipped_weapon.weapon_model) cuts it; a ranged/siege hit pops it in mid-air; nothing else touches it (no parrying, Zach). Net.everyone("_all_ball") -> Cannonball.net_act on every screen. Cut: two Cannonball.Half rigid bodies (hemispheres, mask 1, continuous CD) carrying the ball's full velocity rotated +-45 degrees about up (SPLIT), splash and sink slowly in the sea, freed after HALF_LIFE 20 s.
- With crewmates (Net.coop) an enemy burst's damage (captain + hull) waits GRACE 0.35 s and is dropped if the ball turns out to have been cut on another screen.
- Enemy balls now burst on a captain's body they fly into (ray mask + layer 2): before, a dead-on shot flew through you.
- tools/dev/seatest.gd (new suite): axe can't, katana cuts (two halves, +-45 deg at 46 m/s, they come down, hull and captain untouched), cutlass cuts, a shot pops it harmlessly, left alone it hits the hull.

## 2026-10-07: pirate ship crews on deck
- EnemyShip builds its crew at _ready (_build_crew): six Humanoids (PirateGrunt.crew_look, seeded from look_seed so every machine has the same men) under the ship's Model at CREW_SPOTS (helmsman at the wheel, bosun by the mast, a gunner each side, two more), no AI or physics: they ride the hull exactly. _crew_update (every machine, from the ship's state): drawn only within CREW_SHOW 220 m of the camera; cutlasses drawn (draw/sheathe actions) for HUNT/BROADSIDE/BOARD/HOLD (the helmsman never); in BOARD the party walks (CREW_WALK 2.5 m/s) to the rail on the side the crew's ship is on and faces it.
- Boarding swaps crewmen 1..n for PirateGrunts with the same look, where each stood, facing his way (setup "look"), and hides them; the helmsman and any left over stay aboard. net_pack carries how many went over (index 10) for guests who join after.
- r8test: all six on deck, cutlasses out while hunting (not the helmsman), the first boarder has his crewman's look and starts where he stood (0.05 m), those are gone from the deck and the rest stay. r8shot: enemy_crew close-up.

## 2026-10-07: sun glare on the sea, chains on a moving ship, jumping on deck
- White sea (guest capture 161506, saved under user://captures: a second instance's F12 goes to Godot's app_userdata, not the repo): not co-op; at some sun angles the ocean's specular (rough 0.5) spread the sun into pale sand-coloured sheets over most of the sea. ROUGHNESS 0.2, SPECULAR 0.2: a glitter path instead. Reproduced both ways with horizonshot (dock_sea / sea_9 at 9.24 h) and the new tools/dev/guestshot.gd (a rendered guest joining a headless nethost.gd: `nethost.gd -- <port>` then `guestshot.gd -- <port> <out_prefix>`).
- Hair/cloth stutter under sail: SpringChains steps at 60 Hz but posed the bones every frame against the body as it is now; between steps the body had moved on (0.2 m a step at 13 m/s) and the chains were drawn a frame's travel behind, snapping forward each step. _write_pose now uses the anchor transform of the last step (_g_step): between steps the chains ride along rigidly.
- Jumping on the moving deck slid you aft: Godot adds the platform's velocity on leaving it, but Jump/Fall (and most air states) set the horizontal velocity from the stick every tick and dropped it. Player.platform_on_leave = DO_NOTHING and Player._ride_ship() (start of _physics_process): airborne and Ship.aboard() (not Swim/Climb/Swing/Downed/Helm/Cannon), the position is carried by Ship.deck_delta() (the hull's last-tick motion) and the model yawed with it. shiptest: a jump at 13 m/s comes down 0.0 m from where it went up.

## 2026-10-07: co-op ship sync + sails
- Why it was bad (Zach: the rider not steering lags behind / looks about to fall off): (1) on non-helmsman machines the ship replayed the helmsman's snapshots 0.1 s late; a late packet stopped the hull dead and the next one lurched it forward, jerking everyone on deck; (2) deck puppets were placed with the ship's physics-tick transform, up to a tick behind the hull as drawn (~20 cm at 13 m/s, every frame); (3) captains only counted as on deck while touching the floor, so a jump switched them to world coordinates and they fell behind the hull.
- Now every machine runs the same Ship._physics_process: the helmsman's machine reads the wheel (_read_helm), the others take sail / rudder input / backing from the newest snapshot (Net.latest; ignored when older than 1 s, i.e. from before the wheel changed hands) and _follow_helmsman() eases their copy (FIX_RATE 2.5/s on position, heading, speed, turn rate, rudder; jump past FIX_SNAP 6 m) onto the helmsman's state carried forward to now. Heave/pitch/roll are local (shared wave clock). net_pack adds sail, turn input, backing (PACK_SIZE 14); net_take_over keeps our own copy and only takes the sails (or everything if we never ran one).
- Ship.aboard(p) (|x| < 3.4, z -9.5..7.5, y -0.7..13 in hull space: deck, rigging, ladders, mid-jump), pack_pos / unpack_pos (deck-relative, unpacked against get_global_transform_interpolated). Player._deck_ship() uses aboard(); _net_pos/_net_yaw use the interpolated hull. Grunt snapshots carry the same flag (index 20; the boss's phase/red moved to 21/22), so boarders ride the ship on guests' screens too.
- Sails: W/S at the wheel step them (furled, 1/3, 2/3, full; toast + whoosh) and they stay set: the ship keeps making way when you let go or leave the wheel (the rudder eases back to centre). Speed eases toward MAX_SPEED x sail_shown (ACCEL up, drag down); sail_shown follows the setting at SAIL_RATE 0.5/s. Furled and under 1.5 m/s, holding S backs her. place() furls them. Visual: the sail is its own node hanging from the yard (scale y 0.03..1), with a canvas bundle on the yard that thins as it's let down.
- Tests: shiptest (one notch per W press, the canvas comes down, keeps sailing with nobody at the wheel, rudder recentres); nettest: the host's sails match, the host rides along on its deck while we steer, our puppet stands at the wheel on the host's ship (< 0.35 m), the host stands on our deck where they are on theirs (< 0.5 m). helmshot frames the furled sail.

## 2026-10-07: stuck sprint, blood pass 2
- Sprint stuck on: sprint is Shift and dodge is Ctrl, and Ctrl+Shift is Windows' keyboard-layout hotkey, which can eat Shift's key-up. Player._input: any mouse/key event carries the OS's real Shift state (raw mouse input reads GetKeyState); when it says Shift is up while the sprint action (bound to Shift) is still held, Input.action_release("sprint").
- Blood colours: the "darker blood" request was for the spray, not the ground. Splats are back to SPLAT (0.42, 0.02, 0.03); the spray is BLOOD (0.2, 0, 0.012) with _blood_mat.vertex_color_is_srgb (taken as linear it displayed as a pinkish mid red), opaque until the drops shrink (ramp holds alpha to 80%).
- FX.blood = bleed (2 x amount flecks, sizes 0.35-1.9, "hold" curve; a jet of amount/2 streaks: thin BoxMesh particles aligned to their velocity, 4.5-8.5 m/s) + dark mist + a bigger ground splat (0.3 + 0.014 x amount) and 1-3 smaller ones strung out 1.2-2.8 m along the spray + the wall splat (0.24 + 0.012 x amount). Splats: lumpy blobs run together, droplets and tapering fingers, stretched x1.2-1.6 and flung onward along the spray when it has a direction (_place_splat `along`). MAX_SPLATS 120. _burst takes scale_min/max, hold, align, mesh.
- Severing: blood 34 at the cut, FX.blood_pool under the stump (0.9 head / 0.65 arm, spreading over 6 s), 18 weakening arterial spurts (FX.bleed, out of the neck or the shoulder's side) over ~5 s with a splat every 4th, and the severed head/arm drips from its cut end for ~3.4 s as it tumbles. goreshot frames at 0.1 / 0.3 / 0.8 / 1.6 / 3.5 s.

## 2026-10-07: skills pass (trauma shake, co-op hit-stop, camera follow, grunt navmesh)
- Claude Code skills from skills.sh in .claude/skills (skills.txt lists them). This round applies game-feel, camera-systems and game-ai.
- Camera shake (camera_rig.gd): was a fresh randf offset every frame at max(intensity), draining 8/s (most shakes lasted 1-2 frames). Now trauma 0..1: shake(i) adds i x SHAKE_PER 2.5 x the setting, drains SHAKE_DECAY 3/s; offset = trauma^1.5 x layered sines (h 0.6 m, v 0.45 m at full) + roll 0.05 rad. Ticks in real time so a hit-stop's freeze frame still shakes. Settings gameplay/camera_shake is a 0..1 slider (saved true/false load as 1/0 through the default-type cast); call sites unchanged.
- Follow and zoom smoothing are exponential (1 - exp(-rate x dt)): the same at any frame rate. follow_speed 24 / zoom 11 match the old clamped lerp at 60 fps.
- Co-op hit-stop: CombatManager.apply_hitstop(d, bodies) / apply_hit_effects(hit, bodies). Alone: Engine.time_scale as before. In co-op (was skipped entirely): only when our captain is one of `bodies`, each gets hit_freeze(d): Humanoid.freeze holds the pose (skips _process), Player.hitstop_left makes the StateMachine skip its ticks (our captain stops dead), PirateGrunt.hit_freeze freezes its body. Grunt/bug hit feedback now also runs on the host for the host's own blows (it was single-player only); a guest's own blows get it in Net.route_hit (was shake only).
- Grunt navigation: scripts/world/nav_baker.gd (WorldGenerator child, not on guests). Each island (procedural ones, Brinehollow, the Redtide fort) is baked on a worker thread the first time a captain is within its radius + 150 m: NavigationMesh (cell 0.4 / 0.2, agent r 0.4, h 1.8, climb 0.4, slope 50: whole cells, or Godot warns about lost precision) from static colliders on layers 1 | 2048 under the island node plus the world terrain's faces over its square (heightmap, same triangles as _build_mesh), clipped below y -0.3 (shoreline), into a NavRegion under the island. The world map's cell size is set to match; project setting navigation/3d/merge_rasterizer_cell_scale 0.1 (the default 1.0 logged edge-merge errors on the baked islands). PirateGrunt._nav_dir(goal): map_get_path when the grunt stands on the mesh (closest point < 1.2 m), refreshed every ~0.5 s or when the goal moves 1.5 m; follows the next waypoint (advance within 0.8 m), straight at the goal off the mesh or past the last waypoint. Used by CHASE, REPOSITION and RETURN; the stuck detour and water avoidance still apply on top.


## 2026-10-07: performance pass (late-session slowdown, stutter)
- Zach's report: ~35 fps and stutters about 50 min into an exported build on another PC, back at Brinehollow. Measured here (RTX 4060 laptop, 1920x1080, preset 960x540) with tools/dev/perfbench.gd: frame 7.5-8 ms -> 4.5-6 ms; GPU 2.3-2.8 -> 1.4-2.1 ms; prims 1.5-1.8M -> 1.0-1.3M; respawn hitches 450-590 ms -> 10-20 ms.
- Measuring: Perf autoload (scripts/game/perf_monitor.gd), every build. F8 (video/perf_overlay) shows fps, process/physics, render CPU/GPU, draws, nodes, enemies (swimming). In the world it appends a line every 30 s to user://perf.log (header: version, GPU, driver, window, preset; previous session kept as perf_prev.log): avg fps, 1% low, worst frame, hitches > 50 ms, enemies, swimmers, loot bags, position.
- Things that piled up: pirates in open sea swam forever (PirateGrunt._swim_update: drown after SWIM_GIVE_UP 20 s with no beach found, or 60 s whatever; vanish(sink) = no loot/XP, Net.event "vanish"; not the boss); _bad_shores capped at 12; boarders idle with no captain within 90 m for 8 s slip away (_left_behind); Redtide call_crew re-alerts a still-standing crew instead of calling 3-5 more on every reset; LootBag.lifetime (weapon drops 300 s, item drops 600 s, floating plunder 600 s; never chests or the recovery bag; waits if a captain is within 8 m; shared bags expire via Net.bag_expire on the host); coins always expire; burned thornbrush frees its light and emitters.
- Rendering: the 3D renders at the PSX grid's size (PSX._update_pixelate sets root.scaling_3d_scale = grid height / render height; 0.5 at 1080p) - the post pass only ever sampled one texel per cell. Ocean wakes only from hulls within WAKE_SEND 180 m (far trails stretched wake_box over the whole sea). Vegetation MultiMeshes split into 70 m cells (StarterIsland VEG_CELL, WorldGenerator DECOR_CELL); grass/ferns end at 90 m, bushes 160 m, both shadowless; island trees/rocks end at 1000 m. World terrain in 8x8 chunks (WorldGenerator._build_chunk, one ConcavePolygonShape3D for all). Player/gun cameras far 1200 m (fog is solid by 820). Fog banks and reef rocks end at 1000 m.
- CPU: Humanoid.lod (villagers, grunts out of combat, ship crews, co-op puppets; never your own rig or tool-made rigs): pose every 1/2/3/6 frames by distance and frustum (off screen 6/12), carrying the skipped time; pose_frame tells LowerBody/ArmBody whether to re-skin. One camera lookup per frame for all rigs; spring chains reset once when leaving range. Enemy ships > 350 m from the camera: no test_move on patrol, heave only, no wake/splashes. Grunt enemies list fetched once per physics tick (_all_enemies); FireZone.any_contains returns early with no fires. Progression.stat() memoised until the owned set changes; PowerComponent.skill() returns a shared dict (read only). Clouds re-sort/upload every 0.05 s and slide in between. Ocean re-sends shoal textures only when they change. FX bursts > 160 m off and sounds > 64 m off aren't made; burst Curves/Gradients/QuadMeshes shared. Props.weapon_mesh caches by model. Skill bar orbs skip slivers (the "triangulation failed" error + backtrace every frame).
- Hitches: bodies are built ahead on a WorkerThreadPool task (Humanoid.prebuild(looks) / Humanoid.make(look)); PSXMat and FacePainter caches are mutex-guarded for it. GruntCamp, EnemyFleet (EnemyShip.crew_plan(seed, kind)), the Redtide crew and Morrow prebuild their next wave while away; Humanoid.clear_prebuilt on world exit. Boarders and deck crew take over the crewman's own body ("body" in the setup dict) instead of building one. NavBaker bakes the remaining islands one a second from 2 s in (parse is main-thread, 2-9 ms each) instead of when a ship arrives.
- Stuck sprint: the Shift-up workaround no longer also requires Godot's own Shift state to be down (it could be stuck too).
- Tests: tools/dev/perftest.gd (in run_tests). r8test/seatest check boarders keep their bodies. Tools: perfbench.gd (views; `probe` / `probe:<view>` times every script's _process/_physics_process), hitchprobe.gd (one-off jobs), buildprobe.gd (body build stages). feat and stamtest fail the same way on the previous commit (not this round).


## 2026-10-07: knockdowns on a moving ship; stale tests
- Zach's report: knocked down on a ship (cannons, enemies), the body flew off while the camera stayed, then the character popped back on deck and stood up. Cause: DownedState's root follows the hips with move_and_slide, so the rail blocked it while the ragdoll flew on (the camera follows the root), and get-up stands up at the root; the ragdoll also started without the deck's velocity, so the ship sailed out from under it. Fix (downed_state.gd): the ragdoll starts with _deck_velocity() (platform velocity, else the crew ship's hull_velocity when aboard); after move_and_slide, a root more than FOLLOW_GAP 1 m from the hips jumps to the ground under them (ray, mask 1). tools/dev/decktest.gd (in run_tests): light knockdown at 8 m/s stays aboard, gap 0.3 m; thrown overboard the root follows (1.1 m) and you come up swimming. Without the fix: 25.8 m gap, back on deck Idle.
- feat and stamtest were stale, not broken: feat pressed Z while the polished cutlass cut was still recovering (now waits until free); stamtest looked for the removed axe_heavy (now axe_whirl) and swung the camera in front while armed (you strafe facing the camera then; it sheathes first).


## 2026-10-07: bigger ships, crew cabin, crow's nest, rigging and rope swings (step 2a)
- Zach's picks (step 2 of the plan): ships ~1.5x; a crew cabin under a raised captain's deck at the stern with stairs both sides (bed, kitchen, storage); crow's nest, climbable rigging, ropes to swing from. The gameplay half (shared storage bank, bed respawn/heal, kitchen refill, gravestone death, summoning the ship) is 2b.
- HullBuilder (scripts/ship/hull_builder.gd) is now the one layout for the crew's ship and the pirates': RINGS 1.5x (~22.5 m, 8.8 m beam), main deck still DECK_Y 0.32 (so ship-local deck spots in tests and code carry over), FREEBOARD 1.45 (deck ~1.8 m above the sea, level with Brinehollow's dock), quarterdeck QD_FRONT 5.0..QD_BACK 9.9 at QD_Y 2.72 roofing the cabin (walls at +-CABIN_HW 3.95, door 1.3 wide), stairs STAIR_X0..CABIN_HW from STAIR_Z0 1.4 (8 steps, wedge collision, ~34 deg), mast at MAST_Z -1.8 to MAST_TOP 16.8, yard YARD_Y 13.8, crow's nest NEST_Y 15.0 (rail with gaps each side), ratlines RIG_BOTTOM->RIG_TOP, ladders at LADDER_Z -2.9 (LADDER_LEN 3.0). hull(mb, mats, rig) / collide(body, rig) / build(parent, opts) / aboard_local / in_cabin / half_width. Wrecks use rig=false.
- Ship: model and collision from HullBuilder; helm on the quarterdeck (HELM_Z 7.4, WHEEL_Z 6.6); _build_cabin: bunk (BED_AT), galley stove + counter (STOVE_AT, COUNTER_AT), storage chest (STORAGE_AT, the BankZone now), table, stern windows, lantern + a small OmniLight (no shadow); RespawnPoint by the bunk. GUN_SPOTS [z, x, y]: foredeck, forward of the mast, refit pair on the quarterdeck. Holes at WATERLINE_Y; holes/fires within DECK_Z_MIN..MAX, DECK_X_MAX. Ship camera +4.5 m, spring 21. Brinehollow moors her 7.2 m off the dock's centreline.
- ShipRigging (scripts/ship/ship_rigging.gd, one per side under ShipModel): F at the foot (deck_spot) climbs, F in the nest climbs down; ClimbState kind "rig" (RIG_SPEED 2.8 m/s, ~6 s up), facing the mast. SwingRope (scripts/ship/swing_rope.gd, one at each yard end under the Rig node, so they turn with the brace): F at its foot (grab point at deck level, closer than any cannon seat) -> SwingState rope mode (_enter_rope: rope_len = feet to the yard - 0.6, deck velocity + a 5 m/s kick the way you look; the anchor follows the yard each tick; no time limit; jump lets go; landing ends it; point_to/hang move the rope mesh). Co-op: others see you swing/climb via your position; the rope mesh doesn't move on their screens.
- Enemy ships: same hull/deck/cabin; FREEBOARD/swell/wake from HullBuilder, ALONGSIDE 10.8, CREW_SPOTS 1.5x with the helmsman on the quarterdeck (spot.y), guns spec z scaled (clear of the stairs), hurtbox 9 x 5.2 x 23.4. Sea King: bite spots 1.5x, tail ring 9.5, tail 12 m off, CIRCLE_R 30. Shipwright yard camera 26 m out.
- Tests: tools/dev/riggingtest.gd (in run_tests): stairs to the quarterdeck, helm up there, cabin door, storage chest prompt, respawn point in the cabin, rigging up/down, rope swing (3.9 m across the deck), ladder from the sea. seatest isolates the fleet (the rest froze until the ram test) and starts each shot on a clean, undamaged ship (a fire from an earlier hit burned the hull during "untouched" checks); r8test/swimtest/seatest bounds updated. Render: tools/dev/bigshipshot.gd (outside, deck, cabin, quarterdeck, nest, rigging, alongside an enemy).


## 2026-10-07: storage chest, bunk, galley, graves, summoning the ship (step 2b)
- Zach's picks: respawn by the bed in the cabin; storage shared by the crew; the kitchen refills quick-slot consumables to a cap; the grave holds your bag (worn gear and the weapons in hand stay on you); die again before getting back and the old grave shakes and sinks; summon by holding a key, cooldown, any captain; the ship fades in out of nothing and sails to the shore nearest you ("Cannot summon ship" away from water).
- Storage: GameManager.storage (replaces banked_items) is the contents array of ship.storage, a persistent LootBag (label "Ship's storage", chest mesh, in the cabin at STORAGE_AT). Persistent bags always open the container window and stay when empty. Co-op: shared_id "storage" (Net._shared_bag resolves it to the ship's chest), so take/store go through the host like dropped bags; the world sync carries its refs. stored_count() reads the chest (the host's on a guest). Save "storage" (old saves' "banked" loads into it); guests keep their own.
- Bunk (GameManager.rest): full health, stamina, energy, then a save; refused with an in-combat enemy within 40 m. Galley (restock): each quick-slot item (rum if none) topped up to RESTOCK_CAP 3.
- Death (_die_for_real): the old grave (if any) sinks (_sink_grave: interactable off, shake tween, dust, down 1.4 m over 2.2 s, freed with its loot); InventoryComponent.take_all_except([equipped, offhand]) goes on a new grave (Props.grave_mesh: mound, headstone, candle) where you fell: on the ground (ray down), on the ship's deck (parented to ShipModel, sails with her), or a floating sack in deep water. Emptying it calls grave_recovered. You wake at ship.respawn_point in the cabin. Saved as "grave": [pos (ship-local if aboard), on_ship, floating, refs], restored after the ship is placed.
- Summon (hold B 1 s, SUMMON_COOLDOWN 60 s; player.try_summon): refused aboard, with crew on her, or no water. Ship.summon_spot: rings 14..45 m x 24 angles around you, the nearest centre where it and 8 points 12 m out have >= SUMMON_DEPTH 2.4 m (Ocean.depth_at probed from y 80, or hills read as water); she appears 30 m further out, weighs anchor and sails in at SUMMON_SPEED 5 (helm input cancels it), anchoring within 2.5 m, after 30 s or when stuck 6 s. Fade: psx_lit's body moved to shaders/psx/psx_lit_body.gdshaderinc; psx_lit_fade.gdshader adds a `fade` uniform with a Bayer discard; the ship's psx_lit materials are swapped for fade copies for SUMMON_FADE 2.5 s, plus mist. Co-op: Net.summon_ship -> everyone("_all_summon").
- Tests: tools/dev/looptest.gd (in run_tests): store/take/partial stacks, rest, restock + cap, death and grave contents, kept weapon/gear, wake in the cabin, save/load of storage and grave, second death sinks the old grave, recovering, summon refused inland, summon at the dock (fades, cooldown, appears ~45 m off, anchors ~16 m off). nettest: a guest stores treasure and the host's storage has it.


## 2026-10-07: hull texture fixes, climbing by hand, tight interaction zones
- Zach's captures (18:09-18:11): the bow open at the stem; bulwarks invisible from outside (only an inner face); deck planks across the ship at 12 cm (shimmer far off); stairs stacked boxes; the crow's nest too small to get round the mast; climbing arms straight overhead; prompts popping up metres away.
- HullBuilder: outer hull faces run up LIP 0.45 to the rail; the bow closed (stem face, inner face, rail cap, stem post; a collision box across it); planks mapped by position (_plank_uv: decks fore and aft, 0.25 m boards; _side_uv: strakes 0.25 m) on the decks, quarterdeck, ceiling, sides and bulwarks; stairs are treads with nosing, risers and stepped stringers either side. NEST_R 1.05 -> 1.6 (12 sides), RIG_TOP x 1.5.
- ClimbState (rewritten): ladders and ratlines are climbed by hand. F grabs (from the water, from deck at a ladder's head - Ladder.at_head, the foot of the ratlines, the nest by the rail gap); W/S along the line (ladder 1.9/2.4 m/s, ratlines 2.8/3.2, x0.6 armed); Space jumps off the way the camera looks (from a ladder never into the hull), F lets go; off the top: keyed over the rail / into the nest; off the bottom of the ratlines onto the deck, of a ladder into the sea. A cutlass or single axe can be drawn on the climb (Z): Humanoid.climb_hold "l" (left hand on, right side turned out toward the camera, 60-150 deg from facing the climb), left click "climb_chop" (upper-body action, hitbox 0.26-0.38 s, 10 dmg). Climbing pose: hands at the rungs in front (arms ~1.85 rad), not overhead. The climber is now outboard of the shrouds facing in (ShipRigging.hold +0.3 outboard). climb_hold is synced (humanoid_sync).
- Interaction: Interactable.reach (flat distance from its origin, 1.8 m up/down) or reach_test (ladders); InteractionComponent picks the nearest in reach, preferring the one you face, and stands aside while climbing (F lets go). Ship: cannons 0.9, rope 0.75, wheel 1.0, chest 1.1, bunk/galley 0.9, rigging 0.8/0.7; WORK_REACH 1.6 -> 1.3. Prompts are plain verbs ("Man the cannon"); the HUD shows held jobs in the same panel ("[Hold F] Patch the hole" with a bar under it).
- Tests: riggingtest rewritten (prompts at 2 m vs right there, climb by hand up/down, room round the mast via test_move, jump off, armed climb + chop, F lets go, ladder down from deck into the sea and back up); swimtest holds W up the ladder. Render: bigshipshot adds bow_deck, stairs, climb_ladder, climb_rig, climb_armed.


## 2026-10-07: skill trees step 1 (weapon trees, mastery, moveset unlocks, ability tiers)
- Zach's picks: weapon trees paid with weapon mastery (Base/Haki and Fruit keep level SP); tiers open by use, then cost points; a tab per tree; old saves fully refunded.
- SkillTree: TREES + TAB_ORDER (base, unarmed, sword = cutlass, katana, axe, dual, pistol, fruit); nodes carry "tree"; STYLE_TREE maps Player.style() to a weapon tree (claw has none). Base: 8 core stats + 8 web (new Grit, Sea Legs), regions Mobility -135 / Survival -45 / Observation 45 / Armament 135 (old Shadow Step passive is now Slip Step). Weapon trees: a root owned from the start (starting_nodes), dmg_/stam_/flow_<tree> stats (damage, attack stamina, energy per hit; Progression.style_stat), and kind "move" nodes whose effect is a flag mv_<move> (Progression.has_move). Flying Slash -> cutlass, Tiger Rush -> katana, Bullet Storm/Quick Hands/Extra Powder/Hang Time -> pistol, Twin Blades -> dual.
- Moveset unlocks (fall back to the plain move without them): cutlass Running Cut (dash_cut), katana Full Draw (iai_full: Iai stops at level 1), Quick Draw, Crescent Arc (air_slash: else the plain plunge), axe Skybreaker (else plain plunge), dual Twin Spin and unarmed Roundhouse (4th combo hit), pistol Gun Kata (else pistol-whip) and Gun Rain (else no air attack).
- Progression: mastery {tree: lv, xp, pts} (MASTERY_PER_HIT 4 from PowerComponent.on_sword_hit, local only; 25% of kill XP to the weapon in hand; mastery_to_next = 60 lv^1.3, MAX 30, 1 point a level, toast); points(tree)/points_word; uses + tiers (note_use on every cast, can_rank_up/rank_up, cost from the skill node's tree). FORMAT 2 in to_dict; older saves: skill_points = (level-1)*2, owned reset; after_load() (SaveGame.load_into) regrants fruit freebies, clears unknown bar slots, banner.
- Tiers (Skills "tiers": uses, cost, name, desc, optional cooldown): Soru 2 Double Step (_free_recast 1 s) / 3 Shadow Step (dodge -> Player.vanish 0.9 s, 8 energy: hidden, hits ignored); Tekkai 2 Walking Iron (5 s, 0.6x speed) / 3 Iron Reflex (a knockdown hit -> tekkai 1.5 s, every 15 s); Coat 2 Hardened (12 s) / 3 Ryuo (coated hit in HeavyAttack/Iai/Plunge -> 3.2 m haki blast round the target); Foresight 2 Second Sight (8 s, 2 dodges: foresight_charges) / 3 Future Sight (toggle stance, cooldown 3, one auto-dodge every 3 s, drains 2 energy/s).
- Skill map: tabs from TAB_ORDER (green dot = points to spend), opens on the drawn weapon's tree (hybrid -> fruit), header row 2 shows Lv/XP/SP or mastery/points, move nodes are hexagons, tier pips under actives, a skill ready to rank up pulses, click it again to rank up; panel shows tier, next tier, uses, cost.
- Debug: F9 also levels the drawn weapon's mastery; Shift+F9 opens every known skill's next tier.
- Not yet: Vanish isn't shown to co-op puppets (body hidden locally only); weapon/fruit skills have no tiers yet; the webs are small (about 6-8 nodes per weapon).
- Tests: progtest (start nodes, mastery points per tree, unlocks, uses -> rank up, mastery from punches, save/load of mastery + tiers, old-save refund), r6test (tree tabs), katanatest/axetest own their unlocks first. Render: styleshot 15-17 (base map, Soru tier panel, cutlass tab).

## 2026-10-07: weapons worn on the hip
- Zach: the stowed sword looked wrong, katanas poked out of their scabbards, the axe hung backwards.
- HipSocket (BodyBuilder) now points down-back at ~40 deg (was near vertical, so long blades nearly touched the ground) with up (0, 0.6, 0.78): the flat lies against the thigh, edge forward, spine and curve trailing back (before, the blade's width cut into the hip). Pistols tuck barrel-down, butt forward. The off-hand socket mirrors it as before.
- Axes on the hip (Humanoid._on_hip) hang head up through the belt, bit to the back, the haft down (WeaponDesigns.axe_head_z puts the head 0.1 above the socket); they hung head-down by the boots.
- Katana scabbards: WeaponDesigns.saya(model) builds each design's own, the same segment chain as its blade (len, curve) plus room past the point; it sits at the weapon's offset (Humanoid.KATANA_SHEATHED). The old Props.saya_mesh was one fixed curve stretched in z (WeaponDesigns.sheath_scale, both gone): curved blades left it through the top edge and every tip ran ~7 cm past the end.
- Tests: qoltest checks the nodachi's scabbard covers its blade tip; katanatest. Render: tools/dev/sheathshot.gd.

## 2026-10-07: animation review fixes
- Full review of every action with tools/dev/animsheet.gd (contact sheets at each move's played length); rules from it are in the driftwake-animation skill.
- Humanoid: `hand_l` is a joint now (JOINTS, UPPER; written after hand_r), same signs as hand_r. Nothing else writes HandL's rotation (IK only sets arm/fore), so it rests at zero unless a pose keys it.
- Dual swords: the guard angles both blades forward (wrists -0.5); dual_1/dual_2/dual_cross/dual_heavy cock the cutting blade back on the wind-up (+0.5..0.6) and fling it out along the arm on the hit (-0.9..-1.4); dual_spin holds both out along the arms (-1.5). Before, both blades stood upright through every hit.
- Dual-sword hitboxes per hit (were one 0.07-0.21 window for all four): starts 0.1/0.1/0.17/0.1, ends 0.22/0.22/0.29/0.42, from the strike keys (dual_cross lands at 0.21 s, dual_spin turns 0.09-0.45 s).
- bullet_storm: no wrist key (its -1.55 bent the player's fixed-grip pistol to point at the ground).
- thorn_whip has its own pose (was vine_throw's): arm folded high behind the shoulder, held, cracked down across through a lunge at u 0.48 (the whip fires at dur x 0.48), small recoil.
- Humanoid.play of an unknown action name logs an error once per play (the removed axe_heavy played nothing for weeks).
- Tests: fixtest, katanatest, progtest, r10test. Render: animsheet `dual_sword,bullet_storm,thorn_whip`.

## 2026-10-07: animation pipeline (action table, keyed lift, gaze, holds, hit reactions)
- ActionSpecs (scripts/npc/action_specs.gd): one table of every action: "len" (s), "hit" [u open, u close] for attacks, "hold"/"react" flags, preview stance/weapon/extras/variants. LightAttackState and HeavyAttackState take lengths and hitbox windows from it (their STYLES lost lengths/starts/ends/start/end and windup/active/recovery). Windows were converted from the old seconds, so timing in game is unchanged. animsheet renders from it (its CAT is gone) and marks the window with a red bar.
- Keyed lift: a pose dict may carry "_lift" (Vector3); it's taken out of the joints and eases with the keys, overriding the returned lift (peril_chop and thorn_whip use it; older moves still compute lift by hand).
- Gaze: Humanoid._keep_gaze caps pivot + torso + head pitch at GAZE_UP_MAX (0.3) during actions by tilting the head down (heavy, axe_split, slash_down, dual_heavy stared at the sky); GAZE_FREE lists moves meant to look up.
- Holds: Humanoid.hold(name, blend_in = spec len) eases in and stays (no end) until stop_action/another action; `_action["hold"]`. guard_block, iai_ready, vine_hang use it (were play(…, 600.0)). Net event "hold".
- Hit reactions: Humanoid.react(name, dur, push) stores the shove in body space (_react_dir: x right, y back) and a random variant; "hit" and "stagger" blend front/back/side poses through _react_pose (side mirrored for the left, front/back mirrored by variant, scale 0.85-1.2); the stagger reels, then the upper body comes back 30% over the planted feet. Player StaggerState, grunt (guard break, Haki break, breaker, flinch, parried, vine yank) and the boss's slam break use it; rooted (no direction) keeps play. Net event "react" carries dir + variant. _mirror(dict) flips a pose left/right.
- Tests: fixtest, stamtest, katanatest, axetest, progtest, r6test, r10test, vinetest, grunttest, feat, nettest. Render: animsheet `stagger,hit,slash_r,guard_block,iai_ready,vine_hang,peril_chop,thorn_whip,heavy,axe_split,slash_down,dual_heavy`.

## 2026-10-07: skill trees step 2 (bigger weapon trees, techniques, ultimates, grapples, base passives)
- Zach's picks: one R slot (any learned ultimate; a weapon ult needs that weapon in hand); grapples are bar skills that grab a light enemy in front (not bosses or big bugs) with passives upgrading them; every tree gets 2-4 new actives, an ultimate and many passives.
- Trees: weapon trees 19-22 nodes each on a grid (SkillTree._g(col, row): 100 x 72; moveset/defence left, skills up the middle to the ult at row 6, crit/leech/cooldown right; no node sits under a skill's name). Base gains 17: c_learner (xp_pct), Mobility Featherfall/Long Stride/Sea Born/Gale Step, Survival Iron Stomach/Adrenaline/Sea Air/Weathered, Armament Hardening/Haki Flow/Black Fists, Observation Instinct/Reading Blows/Weak Points, a Conqueror region (angle 90: King's Will L18, Conqueror's Haki ult L20). Default cost: active 2, ult 3. Map: move hexagons label on hover/zoom only; Conqueror's region shows only its "awakens" line.
- Generic weapon-tree effects (Progression.style_stat for the weapon in hand): dmg_, stam_, flow_, crit_ (x1.5, plus base crit_all), heavy_/finisher_/skill_ (Player.melee_hit(base, kind): HeavyAttack and Iai pass "heavy", the combo's last hit "finisher", techniques/projectiles "skill"), leech_, exec_ (extra dot hit when a hit leaves them under 30%), parry_ (+ base parry_all), deflect_/deflect_cd_/return_ (Player._try_deflect: blade drawn, shot from the front, 4 s cooldown minus deflect_cd, "deflect" pose, return sends 2x damage back), unblock_ (heavies), armor_ (no flinch/knockdown in LightAttack/HeavyAttack/Plunge/Technique), def_, cdr_ (PowerComponent.skill_cooldown via Skills "tree" ids). Specific: iai_speed, throw_splash, ricochet (ShootState._ricochet 60% to the nearest other enemy within 9 m), pointblank_pct (shots within 5 m). Base: featherfall, sprint_cost_pct, swim_pct, potion_pct, adrenaline (<35% hp), evade_chance (_foresight_dodge "Instinct!"), xp_pct.
- TechniqueState ("Technique" node; Skills entries with "state": "Technique" and "styles"/"needs_text" checked in can_cast) runs 26 skills in seconds: cutlass riposte (buff "riposte" 1 s; Player._on_hit_received forces {"id": "riposte_counter", target}) / swordfish / kraken_wake ult (blinks between up to 6, then all take 45 knockdown); katana wind_sever (Projectile "wave") / phantom_step (blink behind the enemy nearest the aim) / petal_storm ult; axe axe_throw (Projectile "axe" out 13 m and back, held axe hidden until `returned`) / earthsplitter / berserk (buff: +25% damage, no flinch, +15% taken) / maelstrom ult; dual blade_dance / cross_fang (leap sized to land 1.2 m short of the aimed enemy) / steel_tempest ult; pistol deadeye (pierces a line through the reticle target, snapped within 0.12 rad) / smoke_bomb (stagger + Player.vanish 1.5) / point_blank / deaths_waltz ult; unarmed grapples suplex / hip_toss / giant_swing (target.grabbed(secs): grunt STAGGER or bug DAZED without the vine fx, Net HOST_CALLS; the body is carried each tick on the host only; throws hit through a proxy so knockback goes the throw's way; _landing splashes the drop point) and martial arts hundred_fists / rising_dragon / palm_strike / sea_king_fist ult; conquerors_haki ult (non-boss under 40% faint = killed, the rest stagger 1.2 s). No target for a grab/blink refunds energy (or ult) and cooldown.
- Projectile: kinds "wave" and "axe" (weapon mesh, spins, turns back at range or a wall, `returned` signal); hits are tested along the whole step (_cut_along, long frames skipped targets); slash/wave/axe hits go through melee_hit(..., "skill") and on_sword_hit. Net "projectile" args carry the weapon model.
- Poses: scripts/npc/technique_poses.gd (TechniquePoses.pose, reached from the end of Humanoid._action_pose); 27 actions in ActionSpecs; SPIN_ACTIONS + maelstrom/blade_dance/steel_tempest/deaths_waltz/giant_swing, GAZE_FREE + berserk_roar/suplex/rising_dragon/conqueror, petal_storm skips the katana hand IK, earthsplitter/maelstrom are AXE_TWO_HANDED. Icons: gen_psx_textures.py gen_technique_icons (`py tools/texture_gen/gen_psx_textures.py techniques` makes only those).
- Not yet: no tiers for the new techniques; in co-op a guest's grab can't carry the body (it's thrown from where it stands) and the thrown axe's copy on other screens doesn't hide the thrower's axe; Smoke Bomb's vanish is local only (like Shadow Step).
- Bullet deflection reworked the same day (see "deflecting shots is a parry upgrade" below).
- Tests: tools/dev/techtest.gd (new, in run_tests): every node learnable, each technique lands with its weapon, knockdowns, grapple carry, deflect + return, Riposte, Berserk, Smoke Bomb, grab refund, Quick Learner, Adrenaline, Conqueror's Haki. Full suite 36/36, nettest OK (one rerun: clock-sync rtt 930 ms at start). Renders: animsheet of all 27 poses, styleshot 15-17.

## 2026-10-07: deflecting shots is a parry upgrade; Iai Counter, Crossed Counter
- Zach: deflection should be a skill upgrade you get early, not a late passive. Picks: an early parry upgrade (a later node makes it automatic); katana and dual each get their own guard skill.
- A timed parry used to stop any non-unblockable hit, gunshots included, for every weapon. Now a parry stops a shot only with the blade tree's parryshot_ node (Player.parries_shots; ParryState ignores ranged hits otherwise): Arrow Cutting (s_deflect), Cut the Shot (k_deflect), Twin Deflect (d_deflect), each 1 point right after the root's moveset node, no level. A cut shot plays Player._cut_shot (sparks, "Deflected!", sent back with return_). Holding block still absorbs frontal shots for any weapon; fists, axes and pistols can't parry shots.
- The automatic deflect moved to the mastery nodes s_return / k_return / d_return (level 4): deflect_ + return_ + deflect_cd_ 1.0 (one shot every 3 s by itself, fired back at 2x). Old ids kept so saves keep their points.
- Guard skills: iai_counter (katana) and cross_counter (dual) run Riposte's flow in TechniqueState (GUARD_POSE: riposte_guard / iai_ready / cross_guard; the hit forces riposte_counter, whose pose, length and damage come from COUNTER_POSE by style: riposte_cut 35, iai_slash 45, dual_cross 40). The guard buff lasts 1.05 s against a 1.0 s guard so exit() knows an unanswered Iai Counter and plays "draw" (iai_ready sheathes the blade). New pose cross_guard; icons skill_iai_counter / skill_cross_counter.
- Fixes from the tests: thrown axes are ranged (a guarding grunt blocked them as melee, so Hatchet Throw missed whenever the grunt had its guard up); techniques aim at an enemy's body (its hurtbox shape, TechniqueState._body_center) instead of the Hurtbox node at its feet (Deadeye and Hatchet Throw dived at the ground).
- Tests: techtest adds Arrow Cutting with and without the node, all three guard counters, the katana back in hand after a counter and after an unanswered guard. Full suite: all pass but shiptest "deck sits ~1.2 m above sea", which reads 1.82 against a 1.8 limit (moored heave 0.22 m; unrelated, the check now prints the height). Render: animsheet cross_guard.

## 2026-10-08: Brinehollow grows west (forest, pirate den, spitters, the brood cave)
- Zach's picks: about 1.5x bigger, existing places stay put; an irregular coast (asked mid-way: "not circular"); a hostile pirate den on a broad north-west beach; spitters that drop from the trees on a thread and spit; a cave with a big bug boss whose reward is a big hoard plus a unique venom weapon. The den's captain is a miniboss: name always over his head, a health bar there after each hit, nothing on the top HUD.
- Terrain (starter_island.gd): EXTENT 630 / RES 210 (HALF 315). Coast radius by bearing = 126 + angular noise + _coast_extra (forest lobe +85 round 160 deg, beach lobe +62 round -138 deg, max of the two) + _capes (SW forest point +70 at 118, den spit +42 at -114, NE spur +34 at -52, bays -48 at 190 and -34 at 96), then a 2D _shape_noise wobble (+-34 m) scaled by _wild(bearing), which is 0 by the dock (-90) and along the cove/smugglers' shore (57). LAND_KEEP unions disks of land round every place that matters (t = min(t, dist - r)), so no bay can eat the village, cave or den. The beach lobe stretches the inland ramp (44 -> 90 m) and calms the roll noise, so it's wide sand; palms thin out there (_beach_lobe). New consts FOREST (-125, 70), CAVE (-150, 45), DEN (-112, -112); flat zones for the cave clearing and the den (1.8 m).
- World: the starter's seafloor clamp box is HALF + 5; EnemyShip.no_go takes StarterIsland.NO_GO (four circles: centre 225, west lobe 225, SW point, den spit) before Redtide and the islands (seatest reads the island index after them); the navmesh zone is LAND_R 305; the chart's Brinehollow circle is offset west.
- Forest: _jungle() adds the FOREST blob (72-112 m) to the old jungle weight; deep trees are denser and up to 1.3x taller; their crowns go in forest_crowns. Paths: ruins -> cave mouth, training path -> den. Burrows 4 -> 11 (3 big).
- Den (_build_den): the pier runs the shortest way to the sea (32 bearings), MooredHull sloop (AnimatableBody3D riding Ocean.get_wave_height at bow/mid/stern; HullBuilder.build + collide), shacks (_house), _lookout_tower (posts, railed platform at 6 m, Ladder), campfire, contraband, jolly flag, the strongbox (_strongbox helper, save_id den_strongbox: treasure, gold, rum, Harbor Captain's Longcoat, a rare pistol). GruntCamp "PirateDen" sits at DEN (so its respawn clearance is measured there): 4 cutlasses, 2 riflemen, Captain Grell; 180 s respawn.
- Captains (PirateGrunt cfg "captain"/"title"): 3.2x hp (_max_hp, also in net_rescale and the heal on returning), 1.35x damage, 14-22 coins, 220 XP; OverheadBar (scripts/ui/overhead_bar.gd): a Label3D name plus a billboard quad whose shader draws the fill, shown 5 s after any health drop (track(hp, max) every frame, so puppets show it too).
- Poison: PoisonStatus (DoT ticks every 0.5 s, FX.poison bubbles, refreshes instead of stacking, "poison_fx" net event like burn_fx). Player._on_hit_received: a dot tick no longer staggers or counts as parried. PoisonGlob: ballistic blob, FX.spit spawns it on every screen (Net.fx), each machine checks only its own captain against a segment-capsule test; it poisons only if the hit took health (not dodged, parried or cut). Weapons: ItemData.poison (dps for 4 s per sword hit, PowerComponent.on_sword_hit).
- CanopySpitter (extends Scuttlebug; new states HIDE/DROP/DANGLE/CLIMB/FALL at the end of S): purple and green, size 0.8, 24 hp. Hides at an anchor 1.4 m out from a deep-forest crown; a captain under it within 8 m -> drops at 9 m/s on a silk thread (top-level box) to 2.6 m above the ground; spits every ~1.9 s (0.5 s hiss and shake first) with a 0.25 s lead; loses you after 4 s beyond 18 m -> climbs. Hit while aloft -> FALL (gravity) -> DAZED -> the ground bug's brain; once in WANDER for 2.5 s it walks under its anchor and climbs. ScuttlebugNest.add_spitter; the island's "SpitterRoosts" nest (9, picked from forest_crowns 16 m apart, not near burrows or the cave, 60 s respawn).
- Brood cave (scripts/island/brood_cave.gd): a dome of inner and outer shells (R 17/25, 36 bearings, rings at 0-76 deg leaving a roof hole), a mouth cut through the lower three bands at +X with jambs and a lintel, trimesh collision, boulders round the foot. Inside: silk nest, three egg-sac clusters, bones, glowing fungus, a teal OmniLight. Runs the fight like RedtideFort: banner at 40 m, the queen wakes when a standing captain is inside, resets (healed, back on her nest) 6 s after everyone leaves, top boss bar "The Brood Queen" with her phase, victory banner and fanfare, the hoard on the nest once per character (brood_hoard: Queen's Fang at epic, 60 gold, 6 treasure, 2 rum, Chitin Pauldron), back after 15 min with nobody within 70 m (net_spawner gen).
- BroodQueen (extends Scuttlebug, size 4.2, 1100 hp, "bosses" group): asleep in WANDER; APPROACH picks brood (fewer than 2 alive; ScuttlebugNest.start_empty + call_out), slam (SLAM_R 5.5 ring telegraph, 1 s, 24 unblockable knockdown judged per machine via the "aoe" event like Morrow's), volley (5 blobs, 7 in phase 2, 14 deg apart, size 1.6, 10 damage, 5 s poison) or the base rear-and-ram (26 damage, knocks down). New S.SPECIAL state; "special" net event tells puppets which. No hitstun or throws: poise (150, x1.6 for heavies, -25/s) staggers her 2.2 s, a parried ram 2.4 s. Below 50% she roars into phase 2 (faster, wider fan, brood again).
- Queen's Fang: WeaponDesigns cutlass design "chitin" (unique: designs_of/item_ids skip it, so grunts, shops and loot never roll it; make_items still registers it), purple chitin blade with a glowing green edge ("venom" in _mats), dmg 1.15, poison 5.
- Tests: tools/dev/foresttest.gd (new): the land (west coast, den beach, dock shore unchanged, flat cave floor), the den crew, the captain's name/bar and hp, strongbox, sloop; a spitter's drop, thread, spit + poison, fall, ground fight and climb back; the queen's wake, boss bar, no throw, stagger, brood, slam, venom fan, reset, death, hoard and the Fang's poison. bugtest counts the new burrows. Renders: islandshot top/around, the den, the cave outside/inside.

## 2026-10-08: the village polish (Brinehollow's houses, tavern, market, plaza)
- Zach's picks: detail + fill in (every building dressed, a few new ones, existing places and NPC spots unmoved); a richer tavern (still the only interior); budgeted real lights at night.
- Buildings.house dresses every house from a seeded rng (spec "seed", else hash of its size/roof/door): a trim paint from TRIM_COLORS (spec "trim") on shutters (hung open, angled) and the door frame; sills and head-boards on every window; flower boxes on the front and upper windows (spec "flowers", ~65%; never under a porch); a hood over the door when there's no porch; a wall lantern by the door (spec "lantern"; "lamp_light" adds its NightLight); ridge caps, barge boards and fascias on gable / gable_front roofs, hip ridges on hip roofs; a chimney cap, pot and smoke (FX.chimney_smoke; spec "smoke"); and on level ground (foundation <= 1.15) a rain barrel, a woodpile against a side wall, a bench by the door. Helpers dress_window / dress_door / wall_lantern / beam_between / lean_side are public (the tavern and island use them). The den's shacks pass flowers false and a tarred grey trim.
- Tavern: roof trim, shutters and flower boxes front and upstairs, lanterns either side of the door with a NightLight, chimney smoke, a bench, a menu board, kegs stacked on the north side. Inside (_tavern_inside): a rug, a swordfish over the mantel, a sea chart, a ship's wheel, a net with floats, two cutlasses crossed (weapon meshes), candles/plates/mugs on the tables, herbs and onions from the beams, barrels (with collision) in the front-left corner, a tapped keg on the counter. Markers (Barkeep, Patron1-3, Door) are where they were.
- New: Buildings.smithy (open-fronted, stone floor, back wall of tools, forge with coals, hood and chimney, bellows, anvil on a stump, quench trough, grindstone, weapon rack, iron stock, sign_smithy; an always-on forge NightLight; marker "Smith") at (-38, -78) with Haldor the Smith (barks); Buildings.chapel (whitewashed hall with buttresses and tall windows, a bell tower over the door with an open belfry, bronze bell, weathervane, round window, door light) at (42, -82); a harbour warehouse (house spec, crates and barrels at its door) at (20, -106); two houses at (-30, -100) and (-30, -24).
- Island (_dress_village): cobbles (new texture "cobbles", gen_psx_textures.py `village` mode also makes sign_smithy) over the plaza (r 12.5), the market (r 7) and the main road to the dock (_pave_disk / _pave_path, 5 cm over the ground, no collision); benches round the well, planters; four lamp posts with NightLights (three on the plaza, one at the market); bunting on poles round the plaza (between neighbouring clear spots) and across the market (_bunting); a notice board; washing lines (_laundry) at three houses; a fenced vegetable plot (_garden) behind the porch house; a hand cart; nets and a crate at the dock. The market gets rugs of wares with baskets of produce and heaps of sacks.
- NightLight (scripts/world/night_light.gd): an OmniLight on from 18:30 to 6:00 (or always), no shadows, distance fade 45-60 m, checks Weather.hour() once a second. Budget: 4 lamps, tavern door, harbour office, warehouse, chapel, forge = 9.
- islandshot takes ISHOT_HOUR (e.g. 21) to render at an hour.
- Tests: qoltest, yardtest, r7test, savetest, feat, r6test, perftest, foresttest, looptest. Renders: islandshot aerial, plaza, tavern outside and in, market, houses, smithy, chapel; the plaza, tavern and smithy at 21:00.

## 2026-10-08: cutlass combo hits 1-2 signed off; animation skill rewritten
- Hits 1 and 2 (SwordMoves, swing paths) are what Zach likes now; the anim lab log
  (docs/anim_lab.md, rounds 1-9) has every ranking and takeaway.
- Swing release (Humanoid._swing): after a path's last key the arm now turns back to its
  posed rotation joint by joint (quaternion slerp, swivel and wrist held at the path's end)
  instead of IK toward the posed hand, which picked another elbow solution and popped the
  blade over in one frame at the end of both hits (tip ~120 m/s). Clearance pushes are off
  while releasing.
- animsheet AS_TRACE=<live|a|b|c> (lab mode): the swing frame by frame (hand and tip height
  and speed, elbow bend). It found the pop above; it's how wobbles get diagnosed.
- .claude/skills/driftwake-animation/SKILL.md rewritten around what training taught: how Zach
  judges a move, keyed poses vs paths, the swing authoring recipe (spacing by distance,
  reach/bend, monotonic height, the anchor across chains, ending the path), body keys for a
  swing, timing, a symptom -> cause table, the tools and check targets.
- Tests: fixtest, feat, stamtest. Renders: animsheet lab:slash_r, lab:slash_l with AS_TRACE.

## 2026-10-08: modeling skill, modelshot, new MeshBuilder primitives
- .claude/skills/driftwake-modeling/SKILL.md: how models are built here (builders, conventions,
  scale table from the player capsule/jump/slope, materials and draw calls, texel density, a
  primitive cheat sheet with its gotchas, a build recipe, measured budgets, recipes per kind of
  model, tools, a symptom -> cause table), from the village, ship and weapon rounds.
- MeshBuilder: `add_extrude` (a 2D outline, concave fine, extruded along local Z: axe heads,
  guards, flukes, stepped carriage cheeks), `add_tube` (round tube through points, tapering,
  parallel-transported rings: rope, branches, tails, rings), `profile_circle` (add_loft with
  rings [y, r, r] = a lathe), `sag_points` (hanging rope), `curve_points` (quadratic Bezier).
  Nothing existing uses them yet.
- tools/dev/modelshot.gd: renders any builder expression (or a row of them, or statements
  ending in return) high over the sea on a ground slab, framed to fit the bounds' corners, the
  views of your choice plus a contact sheet, and prints size, tris, surfaces, tris per material,
  colliders, lights. tools/dev/model_samples.gd: anchor, lantern, cannon as worked examples,
  `body()` for scale. Measured: lantern 304 tris / 2 surfaces, anchor 671 / 3, cannon 976 / 4,
  smithy 731 / 14, enemy sloop 2066 / 11 (888 of it rope boxes), war axe 120 / 4.
- Renders: modelshot of the samples, the smithy (front3, eye, wire, back3, a night close-up
  of the anvil), the jolly sloop, weapons stacked along y at MS_PSX=0, a body beside a house.

## 2026-10-08: cutlass combo hit 3 on a swing path (slash_spin)
- The cutlass light combo's finisher is now `slash_spin` (SwordMoves, ActionSpecs; the boss
  still plays the keyed `spin_slash`). It chains from hit 2's coil: dip, unwind, hop into a
  full turn left with the blade level, land and sweep into a low wrap. Blade trail off the
  real blade (no arc FX).
- Humanoid: swings take `from_shoulder` (points from the sword shoulder, for paths that turn
  with the chest); the elbow search reads its side and rest direction in the swing's frame
  (`_swing_b`, same as before for paths that don't turn); a keyed full turn's pivot is
  wrapped when the action ends (not unwound).
- animsheet: "after" follows the chain back to the opener; AS_TRACE measures the blade as
  modelled (smear excluded).
- Tests: fixtest, feat, stamtest, r7test. Renders: animsheet lab:slash_spin (+ AS_TRACE),
  lab:slash_r and lab:slash_l unchanged.

## 2026-10-08: the harbour town (Brinehollow's dock shore)
- Zach's picks (from a reference map of a packed harbour town): the shore where the ship docks (north on the compass), a harbour town (quay, piers with ships, packed waterfront rows with awnings), the harbour tower and a moored fleet. The dock, its NPCs (Odile, Tackett, Pell, Bram) and the ship's mooring are where they were.
- The quay follows the real shoreline (_setup_port, after _find_dock so the dock isn't moved): the coast found every 2 m from the dock outward until it turns away (steps < 5 m, < 40 m off the dock's), smoothed, the sea wall 2 m out from it. It's a built platform (QUAY_Y 1.62) over lowered ground: paving 15.5 m deep (PLAT_D: the quay plus the street behind), the sea wall down to -4 (wet band below 0.4), coping, a curb face at the back, closed ends; its shell mesh is also its trimesh collision. The ground under it is kept >= 0.6 m below (5 cm let the terrain fight the paving under the PS1 vertex snap: sand stripes), the terrace behind at QUAY_Y - 0.2 fading back to the land by 38 m, painted packed earth. hv() / walk_height() return the paving's height on the platform, so everything placed and every NPC (ground_func) stands on it; _pave_quad skips what's on the platform.
- Piers (Props.dock) at x -32, 30, 46 (if the quay reaches) with ships on MooredHull (now with freeboard/half_len): TraderShips.junk (HullBuilder hull without rig, two masts of battened fan sails), merchantman (fore and main with two square sails each, bellied; a mizzen gaff; a jib; a painted band), sloop (HullBuilder's rig, trader colours), two longboats along the wall. Bollards and swimmers' ladders along the edge.
- Buildings.harbor_tower (8-sided, battered base, band courses, arched windows, a corbelled gallery with a rail, a lantern room, a tiled cap, a flag; a NightLight up top) at the east end; Buildings.dock_crane (post, jib, treadwheel, rope and a hanging crate) by the merchantman's pier. House spec "awning" ("red", "blue", "green": a striped cloth canopy on poles with a scalloped edge, a crate and a basket under it).
- _build_waterfront: two rows of houses facing the water, shoulder to shoulder (seeded widths, walls, roofs mostly gable_front, 2 storeys, jettied), the front row with awnings; skips the road up from the dock, the village's buildings and paths. _dress_quay: cargo stacks, barrels and nets, hand carts, three quay lamps (NightLight), fish and fruit stalls on the street, Dockhand Rook and Merchant Ysolde walking the quay (barks).
- Lights: 9 in the village + 3 quay lamps + the tower = 13.
- Tests: qoltest, looptest, foresttest, perftest, swimtest, yardtest, r7test, seatest pass, nettest OK; shiptest's "deck sits ~1.2 m above sea" reads 1.83 against its 1.8 limit (it read 1.82 before this; unrelated). Renders: islandshot aerial, quay, street, from the sea.

## 2026-10-08: the brood cave rebuilt (a crag outside, dripstone inside)
- Zach's ask: a more interesting interior (stalagmites, stalactites, dripping puddles, glow lichen) and an outside that looks naturally occurring on the island instead of a black dome.
- BroodCave (scripts/island/brood_cave.gd), everything in the cave's own file (the island's placement, reserve and flat clearing unchanged): one polar grid, N_A 48 bearings. Outside (_outer): a cliff foot whose height and steepness vary by bearing (fixed only round the mouth), concave slopes up to a crest (a ~26 m crag WSW, lower ones N and S, lowest over the mouth), down into a crater round the sinkhole; foot radius _foot() irregular, clamped 2.5 m outside the chamber's wall, inside the 32 m reserve. Chamber (_inner_at): near upright at the foot, vaulted above, rough. Every triangle flat with its own normal (_facet), material by normal (grass on flats, moss, bare rock; noise-gated), strata in vertex colour, UVs projected per facet with an offset. The mouth (cells 0-2, +X) is a ragged arch (_arch: edge columns lean in toward the top, the lintel lifted mid-span). Boulders in the trimesh; scree, ferns/bushes on flat facets, three trees on the crest, vines over the mouth have no collision.
- Inside: 18 stalactite clusters (tips >= 4.8 m over the middle, >= 2.8 m near the walls), ~24 stalagmites and two columns (_clear keeps them off the nest, the egg clusters and brood spots, the way in, the middle r < 9 and the back wall's foot behind the eggs), cylinder colliders on the bigger ones; up to 8 puddles under drips with a CPUParticles3D drop and a ripple ring each (one particle, synced by preprocess); a dirt/rock floor mesh 3-6 cm over the ground, damp round the puddles; 11 lichen colonies low on the walls plus strays in the vault (two glow materials), two LichenLights (teal, no shadows) beside the FungusLight (now 1.4 / 24 m). Nest, eggs, bones, fungus and the fight unchanged (NEST / EGGS consts).
- ~21k tris for the whole cave (dripstone ~7.5k), 16 one-particle emitters, 3 lights.
- Tests: foresttest. Renders: modelshot (outside views, interior with MS_FOCUS), islandshot from the path's end, the mouth, the hills, inside by day and at 21:00.

## 2026-10-08: the dock fitted into the quay (pier, Odile, Tackett, Pell, the mooring)
- Zach: make the dock and its people fit the new quay. The wooden dock that started 5 m up the beach (and lay over the quay's paving) is now a stone jetty from the sea wall (_build_dock): dock_shore is the sea wall's point at x 0 (_quay_pt(0, 0), set right after _setup_port; _find_dock is gone), DOCK_LENGTH 28 so its head is about where the old dock ended, PIER_HW 3, its top flush with the quay (QUAY_Y), sides and head walled down to -5, coping both sides and across the head, iron bollards, a timber fender with a rubbing strake down the east side, ladders at the head and twice down the west side, a lamp with a NightLight at the head and one halfway, cargo; its shell is its trimesh collision. _on_platform counts the jetty, so hv() and NPCs stand on it.
- The ship moors alongside the head against the fender: dock_world_pos = _dock_point(DOCK_LENGTH - 4) + east * (PIER_HW + 4.4 + 0.5). The DockingArea is at the head (QUAY_Y + 1).
- _build_harbour_front (in _build_port, after the quay): Odile's booth beside the pier root (_harbour_booth: counter, striped awning on posts, ledger and inkpot, a slate of ships, a lantern; "Keeper" marker), Odile behind it facing the pier; Tackett's yard east of the pier (_boat_on_stocks: keel on blocks, stem and sternpost, U-shaped frames as tubes on a Bezier, the lower strakes and the gunwale laths between them, shores; plus his timber stack, sawhorses, a workbench with a saw and mallet), Tackett beside it facing the pier; Pell seated on a bench at the quay's edge looking out to sea with his nets, the upturned boat, the fish rack and floats, his net loft (a house, no stilts) behind; the longboats lie in front of him. Bram walks the quay and up the road; the dockhands walk the back of the quay (their old routes crossed the booth and the crane); quay lamps skip spots that are taken.
- The old pieces are gone from _build_village (the stilted fisher shack, the dock props, the yard's timber), _build_beach_camp (Pell's spot) and _dress_village (dock crates).
- Tests: looptest (summon from the pier head), qoltest, yardtest, shiptest, seatest, savetest, foresttest, r7test, feat, nettest. Renders: islandshot of the pier root, the yard, Pell's corner, from the sea; modelshot of the booth and the boat on stocks.


## 2026-10-08: easier naval fights, wind as a bonus, ship health bars, Redtide Rock reworked
- Zach: too hard (holes, fires, pumping), the wind fights you, enemy ships can't be engaged until they board, the ship is wrecked as soon as a fight starts; wanted enemy health bars, ramming, no cannon fire up close, the Redtide fort's guns gone (they sank you during the boss), and more to Redtide (rocky outcrops, a rocky path up).
- Ship damage (ship.gd): holes and fires per hit 0.55/0.35 -> BREACH_CHANCE 0.15 / FIRE_CHANCE 0.1 (from hits of BREACH_MIN_DMG 10+), at most 3 of each, FLOOD_RATE 0.012 -> 0.006 a hole, BAIL_RATE 0.035 -> 0.12 (half full pumps out in ~4 s), fires burn 1.0 hull/s and spread every 24 s.
- Wind: wind_effect() is now 1.0 on any heading (no more in irons) plus up to FAIR_BOOST 0.3 with the wind on the beam or behind (x wind strength); it multiplies top speed, so the boost isn't clamped away. The helmsman gets "A fair wind! (+n% speed)"; the sail gauge's arrow is pale normally, green in a fair wind; the sail just bellies fuller.
- Enemy ships (enemy_ship.gd): balls BALL_HULL 14 (was 26) / BALL_SPLASH 14, a volley every 10 s (7.5) with 1.6 s of warning (1.0), the first not before FIRST_VOLLEY 6 s into a chase, at most MAX_ATTACKERS 2 ships on you at once (the rest keep patrolling). No fire inside CLOSE 24 m: there they ram (every kind can now, RAM_DAMAGE 30) or board; broadside ranges moved out to 28-58 m. Health bar: OverheadBar (now with size, range and an `always` mode) over the masthead, "Pirate Sloop" etc., up for the whole fight (puppets read hull from the snapshot).
- Redtide (redtide_fort.gd): the fort guns are gone. The rock is a faceted polar grid (56 bearings, strata, grass on ledges, buttresses, irregular rim) instead of an 18-sided ring; a stone stair (two flagstones a step, boulders along the edges) cut into a rubble spur curls from the jetty round the east side to the gate along a Catmull-Rom curve (straight flights left a 0.5 m lip on the inside of each bend), walked on one smooth ribbon collider; sea stacks round the rock and crags rearing up behind the arena (convex colliders). islandshot takes ISHOT_AT=RedtideRock.
- Tests: r8test (no fort guns; the stair's walking surface checked every 0.5 m across its width, worst 0.06 m; pausing the pirate's AI while it forces a boarding, since that close she now boards by herself), seatest (holes now and then, capped; a slow hole; pumping half a hull out in 3 s), shiptest (head to wind she sails at full speed; a fair wind beats her top speed). Renders: islandshot of Redtide (approach, east, north, stair, stair top, arena).

## 2026-10-08: the story start (loading screen, waking on the beach, a lite quest chain)
- Zach's picks: the chain Pell -> Gus -> Nessa -> Vey -> the smugglers -> Vey (skills) -> Grell -> Odile -> Tackett -> the Brood Queen -> Tackett (the ship) -> Gus -> Morrow; the skill map locked until Vey; the ship moored but unsailable until Tackett; no save migration (new versions ship without saves).
- LoadingScreen (scripts/ui/loading_screen.gd, a CanvasLayer on the root so it outlasts the scene change): the title's New/Continue/co-op start and the pause menu's Load go through it. A dusk card, the logo, a tip; the world scene loads on a thread (bar to 70%), "Raising Brinehollow" is drawn before change_scene_to_packed (the island's build freezes the frame there), then it fades once the player exists.
- Story (autoload scripts/game/story.gd): STEPS [id, goal, npc or place, who]; step "done" = no story (every session but a new game, so tests and the editor's run have nothing locked). begin() (a new game, after the creator: Player.wake_on_beach) sets the ship kit's "owned" false (host only) and the Dialogue flag ship_not_owned. Talk steps: the NPC's JSON has "story": {"<step>": node, "until:<step>": node} (Dialogue.start enters there) and the node's "event": "story:<step>" completes it. Fights (smugglers' camp cleared, Grell dead, the queen dead, Morrow dead) are polled every 0.5 s within NEAR of them, per screen (guests see the host's enemies' states); won early, a fight step finishes as soon as it comes up. complete("vey_skills") gives a skill point; complete("tackett_ship") sets the kit owned (host) and clears ship_not_owned. Saved as "story" (to_dict/from_dict; none = done); SaveGame.begin resets it. Co-op: per captain; the ship's lock is the host's kit.
- Locks: GameMenu.open("skills") refuses with a toast until Vey; Ship.owned() (kit "owned", default true): the helm, the dock's "Board ship" and summoning refuse; the HUD's ship compass hides; Tackett's yard choice hides while ship_not_owned.
- Waking (WakeState, scenes/player/player.tscn "Wake"; StarterIsland.wake_spot(): the sand 9 m past the quay's west end, head to the sea): input locked, eyelids over the screen (shut, a squint, shut, open by 2.6 s), Humanoid action "wake" (7 s: sprawled on your back breathing, a jolt with the head snapping right at the caw, then flat -> a sit with a hand to your head -> a crouch -> standing; foot IK off, gaze free), the camera beside the head. A Seagull (scripts/world/seagull.gd, procedural: blob body and head, extruded wings and tail, a jaw that opens) glides in at 1.0 s, struts and pecks, caws at 2.8 s (new sfx "gull", gen_psx_audio.py), flies off at 3.6 s. Standing: "Where am I...?" banner and the first objective.
- HUD: ObjectiveHud (scripts/ui/objective_hud.gd): OBJECTIVE + distance and the goal, top left (the loot line and crew list move down under it), flashing gold "NEW OBJECTIVE" with a chime on each step (show_objective_banner); a gold "!" diamond over the NPC or place with its name and distance, pinned to the screen edge off screen, gone within 3.5 m of an NPC / 22 m of a fight. Hidden in menus, dialogue and the wake.
- Dialogue: story lines for Pell, Gus (x2), Nessa, Vey (intro, reminder, skills, Grell reminder), Odile, Tackett (busy before his turn, the chitin, the queen reminder, the keel). NPCs join group "npcs".
- Tests: storytest (new, in run_tests): 59 checks through the whole chain. Render: storyshot.gd (loading, the wake frames, the marker, Pell's line, the next objective).

## 2026-10-09: sharper, smaller UI; Esc leaves a conversation; dialogue gated on the story
- Zach: no way out of a conversation but the right choice; the dialogue window too big and its text hard to read; keep the pixel look but finer, menus a bit smaller; the island's dialogue to fit the questline, lines held back until they make sense.
- UI resolution (PSX._apply_preset): always canvas_items stretch on PSX.UI_SIZE 800x450 (project viewport 800x450 too), so menus and the HUD are laid out on 800x450 and drawn at the window's resolution: the hard-edged pixel fonts (antialiasing off) stay pixel fonts, just finer, and everything is ~80% the old size. The 3D grid is the preset's (640x360 default) through the post pass for every low-res preset (pixel_res = canvas x preset.x / UI_SIZE.x; the 3D renders at the grid's size via scaling_3d_scale). Before, 640x360 drew the whole window, UI too, on a 640x360 viewport.
- DialogueBox: 460 wide, centred at the bottom, the UI theme (Pixelify 12; it had Godot's default 16), name tag on the panel's top-left, a footer "Esc  leave" and the blinking "F >". HUD LabelSettings_small 16 -> 12 (compass, prompt, toast, banner subtitle); the compass sits higher so the clock clears it.
- Esc (pause / ui_cancel) closes any conversation (Dialogue._input), the pause menu stays shut.
- Gating: a choice may carry "after": "<step>" (once that step's done, or with no story) / "before": "<step>" (Story.allows); NPC barks may be {"text", "after"/"before"}. Odile: a neutral intro, "Whose sloop is that?" before the ship, her rules and "How do I sail?" after; Nessa: a neutral intro, loot advice without the ship before it, her "work" tip sets heard_shiny (Ambrose's shiny choice requires it); Wren: a neutral intro, the smugglers before and after; Gus: the Sea King after the ship, Morrow after his story line; Tackett points you to Odile's rules with the ship. Reactive barks: Rook, Ysolde, Marlo, Moira, Haldor, Tilly, Bram.
- Before the ship's yours you respawn on the sand where you first woke (GameManager._respawn_player), not in her cabin.
- Tests: storytest (Esc leaves, gated choices for Odile/Gus/Ambrose before and after, the beach respawn), r6test (the UI canvas check now 800x450), r7test, feat, qoltest, yardtest, savetest, invtest. Renders: uishots, storyshot.

## 2026-10-08: the island chain, step 1 (the chain map, the log pose; placeholder islands gone)
- Plan: docs/island_chain_plan.md (Zach's Q&A: a roguelike hybrid, Brinehollow fixed, then a generated chain; seas of 9, cities at 3 and 6, a sea-boss island last, forks that rejoin, one-way, continuous sailing).
- Chain (scripts/world/chain.gd, class_name): made from GameManager.chain_seed (randi() per new game, saved as "chain_seed"/"chain_at", the host's in co-op via the world sync "chain"; a guest's save keeps its own). WorldGenerator.chain() rebuilds it when the seed changes (a load comes after the world's built); it runs from Brinehollow toward Redtide and on past it. Layers: FIRST_LEG 1900-2300 m, then LEG 1100-2600 m, the line bending up to BEND 0.22 rad a layer; the pairs 1-2 / 4-5 / 7-8 fork with FORK_CHANCE 0.6 (two islands 520-820 m either side, branch to branch, rejoining at the city); level 10 + 2 x layer + 0..1; themes from FIRST_SEA_THEMES (jungle, snow, desert, forest), never the same as the island before on that branch or the other side of a fork; names from per-theme lists + Isle/Key/Atoll/Rock (cities Port X / X Harbour / X Haven). chain_at -1 = Brinehollow's sea. Chain.describe(n) -> "Snow city  Lv 17".
- Placeholder islands removed: WorldGenerator no longer scatters the 6 IslandGenerator islands (island_generator.gd deleted, its decoration pass too); island_infos stays (empty) for the chain's built islands. The bottle treasures now lie on Brinehollow's beaches (SeaFeatures._place_treasures: height 1.2-4 m, 45 m clear of its places, 120 m apart, their own rng). The Redtide-to-nearest-island gunboat patrol went with the islands (sea legs get their own in step 7). Tokens: {rumor} tells of the chain / Morrow's log pose, {nearest_island} is Redtide Rock.
- The log pose (Dialogue flag "log_pose", per captain): Morrow's, given 4.5 s after his defeat to every captain at the arena (Player.give_log_pose: banner, refresh_look); Ctrl+F9 in debug builds. Player.refresh_look puts look key "log_pose" on the composed look, so BodyBuilder builds it on every screen (puppets too) and it survives look rebuilds; SaveGame.load_into now restores the Dialogue flags first for that.
- LogPose (scripts/npc/log_pose.gd): on fore_l at the wrist (+0.05), a leather band over the sleeve (radius by outfit: coat cuff 0.09, long sleeve 0.056, bare 0.05 x limb), a brass cup, cap and two posts, a glass ball (StandardMaterial alpha 0.3, rim, no shadow) BALL_R 0.042 on the back of the wrist (-z), two needles (red, blue) set in world space each frame toward GameManager.log_pose_targets() (with a 0.04 rad tremble); unset, one needle drifts round.
- GameManager.log_pose_targets(): the chain nodes next_of(chain_at), [] at Brinehollow while our captain is under LOG_POSE_LEVEL 10 (every wrist on a screen shows what our captain's would).
- Hold L (input action log_pose; "You've no log pose" without one): Player.log_pose_up; on foot and free, Humanoid holds "log_pose" (upper mask, ActionSpecs len 0.25: the left forearm across the chest, ball up, head down a touch). The HUD's LogPose (scripts/ui/log_pose_icon.gd, bottom right above the bar) pops up with an overshoot in any context (helm too): strap, cradle, glass, needles turning with the camera (up = facing, a 0.62 squash so they float flat in the ball), and per island its name in the needle's colour plus theme, level (green at or under yours, yellow up to +3, red past it) and distance; unset: "The needle won't settle (Lv 10)".
- Tests: chaintest (new, in run_tests and test_map): the graph (9 layers, cities, sea boss, links, forks differ, levels rising, all reachable, first island past Redtide, same seed same chain), no placeholder islands, treasures on Brinehollow, the log pose (given, on the wrist, unset under 10, set at 10, hold L raises it and shows the icon, the needle points, let go), save/load of seed + place + flag, the rumour. seatest charts Redtide instead of an island; polishshot lost its island-shallows shot.

## 2026-10-08: ability pass, round 1 (cutlass), FX toolkit, abilities and fx skills
- Zach: a pass on every weapon skill and animation (refine, polish, effects where they fit, cooler effects on the advanced abilities), plus skills to help. Picks: one tree at a time (cutlass first, check in between), polish the keyed poses (not rebuilt on swing paths), a colour identity per tree, big ultimates.
- Juice: CombatManager.apply_slowmo(scale, secs, ease_out) (single player; _base_scale is what a hit-stop returns to, the anim lab's Shift+F5 goes through it) and apply_camera_kick(amount, secs) (CameraRig.kick: FOV down up to 14 deg and the spring arm in by a quarter, easing back in real time; the FOV setting sets _base_fov and the camera at once, so it applies while paused).
- FX: TREE_FX palettes [CORE, EDGE, ACCENT] per tree (tree_col), and ring (a band racing out flat to a normal), spray (droplets + mist along a direction), gather (motes rushing in), streak (a hot-cored line that thins), glint (a star flash), water_tentacles (curved tubes on Beziers that lash up, hang and fall as spray; seeded), screen_flash (CanvasLayer, real time, cameras within 35 m). All through Net.fx.
- Cutlass: Flying Slash re-keyed in TechniquePoses (wound right, a held beat, a stretched/smeared flat cut, step-through; the old humanoid branch removed), a gather at the hand, a glint, the real blade's trail, an air ring and spray at the launch, a light camera kick; the projectile is a blue sheath round a white core, leaves a wake of spray, and hits throw spray and a ring. Swordfish: hips/head/squash driving behind each thrust, the fifth deepest with smear; per-thrust air rings and spray, the last with a streak, a bigger ring and a kick; a glint as it starts. Riposte: the guard's blade glints; the counter throws parry sparks, a ring and a glint at the clash with a beat of slow motion and a kick, the backhand answer on the real blade's trail with spray off its edge (stretch/smear keys), damage on the answer (0.11 s). Kraken's Wake (ult): a 0.45 s gather (coiled low, blade back; motes, a ground ring, spray rising; the moment: slow 0.4 for 0.25 s, kick, flash), blinks leave a streak of light, the blade trail, spray and a glint on each victim, then a flick and a held beat with your back to them (a glint on the blade), then water tentacles erupt under every victim with a 9 m ring, the big moment (slow 0.3 for 0.35 s, kick 0.7, flash) and a splash. Thrust heavy: hips/squash/stretch/smear keys, a glint at the point before it goes, an air ring, spray and dust on the strike, a kick (HeavyAttackState STYLES "tree").
- tools/dev/abilityshot.gd: films a skill (or "heavy" / "riposte_counter") on a flat stage on the water north of the harbour against three staggered grunts; rows per view (game, side, front3, top), frames along game time; AB_HOUR for night.
- Skills: .claude/skills/driftwake-abilities (data, timeline, beat sheet, poses, effects, co-op, checking) and driftwake-fx (palettes, primitives, the layering recipe, co-op rules, budgets, checking).


## 2026-10-08: music style samples, the ambience (surf, swell, hull, wind)
- Zach: the music is too Stardew Valley; wanted more adventurous, RuneScape / Pirates of the Caribbean. gen_psx_music.py gained orchestral voices (horn, harp, harp_dark, pizz, strings, oboe, choir, taiko, glock, swell) and `samples` (to tools/dev/out/music_samples, nothing in the game changed): corsair (6/8 D minor gallop, horns, timpani), harbour (A dorian town), waters (3/4 sea theme), storm (C minor battle), then from his picks corsair_waters (Corsair's band on Waters' tunes) and harbour_calm (the harbour slower and warmer: low strings and oboe, a dark harp, no flute or glockenspiel). Not yet turned into the game's tracks.
- Ambience (scripts/world/ambience.gd, made by Weather under /root/Weather/Ambience, local to each machine): loops mixed every frame for the local captain. Twice a second Ocean.depth_at is probed (from y 80) at 8 points 30 m and 8 at 90 m round you: land and water mixed = shore surf, all water = open sea swell, all land = inland (the surf goes, the wind drops). Aboard: hull wash with speed (volume, pitch 0.85-1.25), slaps at rest, creaking timbers; wind always a breath at sea, more with Weather wind/storm, under way and up the mast (quieter inland); the rigging whistles in a strong wind, under way or up high. Weather's own wind loop is gone (Ambience plays it); Brinehollow's constant ocean loop is gone.
- Sounds (gen_psx_audio.py, built in the frequency domain and placed circularly so they loop with no seam): shore_surf_loop (five waves building, crashing and fizzing back), sea_swell_loop, hull_wash_loop (rush, gurgle, bubbles), hull_slap_loop, ship_creak_loop (stick-slip creaks through wood resonances, rope strains), wind_loop (random gusts, whistle on the peaks), rigging_wind_loop (shrouds moaning on their own swells, canvas flutter).
- Tests: tools/dev/ambiencetest.gd (in run_tests): surf at the dock end, quieter inland, aboard under way at sea the swell, the wash rising in volume and pitch, creaks and wind.


## 2026-10-08: weapon mastery unlocks the elements; right-click spam limits
- Zach: the elemental flair should be earned (abilities start clean and physical; a mastery passive wakes the element on the tree's skills, a higher one puts it on the basic attacks too); and the dual pistol and katana right-clicks were spammable enough to kill everything. Picks: fatigue cost + enemies adapt; the gun kata hits fewer, the full draw costs more, a charge can be broken.
- Mastery (SkillTree._build_mastery, MASTERY const): per tree two passives in its region, tier 1 (`<p>_elem`, level 8, after the mid-tree skill, 2 mastery: flag `elem_<tree>`) and tier 2 (`<p>_elem2`, level 16, after the late skill and tier 1, 3 mastery: `elem2_<tree>`). Names: Call of the Tide / Tidewalker (cutlass), Falling Petals / Blossom Path (katana), Ember Heart / Living Fire (axe), Twin Currents / Crossing Storm (dual), Golden Powder / Gilded Gun (pistol), Rushing Wind / Gale Fists (unarmed). Requirements can now name a node (`{"node": id}`: "Needs <name>"). Progression.elemental(tree, tier).
- Gating: FX.TREE_FX "plain" (white/steel/dust). TechniqueState `_elem()`, `_col()` (plain colours until tier 1), `_spray()` (only with the element); Kraken's Wake without it is a dust gather and rings, no tentacles; Flying Slash sends a plain slash (Projectile model "elem" carries the element; its wake/hit spray only then). Tier 2: the heavy's trail takes the tree's edge colour and its strike sprays; light attack trails take the edge colour; each light/heavy/plunge hit throws FX.elem_hit (spray + ring for the cutlass, sparkle + ring otherwise) through PowerComponent.on_sword_hit.
- Fatigue (PlayerState): heavies within 3 s of each other cost HEAVY_COST x1.5 per one in the chain (30, 45, 68...) and push stamina regen back 50% more each; a light attack resets the chain. The same heavy (state:style) again within 4 s grows predictable: read_chance 0.35, 0.6, 0.8, carried on HitData.predictable (packed in hit_pack). A grunt hit from the front while circling/chasing/blocking reads it with that chance: a bark and "Read!", the sword grunt blocks and ripostes, the rifle sidesteps; no damage.
- Gun kata: locks the 3 nearest targets on its first volley (KATA_TARGETS), then a 1.2 s reload (no shooting or kata, "Reloading..."). Full iai draw: 20 extra stamina, regen delay x1.5, 0.6 s recovery. A hit while the iai charges breaks it into a short stagger ("Charge broken!").
- abilityshot: AB_TIER=0/1/2 (default 2) films a skill at that mastery tier.
- Tests: tools/dev/balancetest.gd (in run_tests): fatigue costs, predictability and the light reset, a grunt reads a predictable heavy but not a fresh one, the charge broken by a hit, the full draw's cost, the kata hits at most 3 and reloads, the mastery requirements.


## 2026-10-08: wind and waves you can see (surf rolling in, whitecaps, wind streaks, spray)
- Zach: wanted visual effects for wind and waves too (spray, foam on the beach, wind streaks).
- Ocean shader: surf rolls in over the shallows (bands of foam moving shoreward on the baked shoal depth, fract(sd * 7 + t * 0.22), a bright leading edge and a short tail, kept to sd 0.03..0.35) and a swash sheet at the waterline whose reach rises and drains (sd under 0.009..0.025), both in PSX cell blocks; whitecaps (uniform `whitecaps`, `wind_dir`): broken patches only on the tops of crests, cells drawn out 3.3 m along the wind and moving downwind, more with the wind; foam is opaque (ALPHA). Fragment only: the swell (wave_h) is untouched, so CPU and GPU still agree. A first pass had swash over the whole gentle shallows and caps over most of each wave (snowy): narrowed after a render.
- Weather.whitecaps() = (wind - 0.3) x 1.3 + storm x 0.8, sent to the ocean each frame with wind_dir().
- SeaSpray (scripts/world/sea_spray.gd, made by Weather beside Ambience, local to each screen): wind streaks (one MultiMesh of 48 tapered quads, one draw call; spawned 9-28 m from the camera along the felt wind - aft over the deck under way - more with wind/storm, speed and height, fewer inland via Ambience's land probe), spray blown off crests in view over deep water when whitecapping (FX.spray), surf bursts where a beach is in view (Ocean.depth_at 0.05-0.8 m: FX.splash + spray).
- Ship._wake: driving into a swell, a sheet of spray thrown up over the bow and blown aft (chance with speed over 5 m/s and the whitecaps, 0.8-1.6 s apart).
- Render: tools/dev/seafxshot.gd (Brinehollow's beach calm and in a storm, at sea in a storm under full sail from astern and from the deck; three frames a shot). Tests: shiptest, seatest, ambiencetest, r9test, r10test.

## 2026-10-09: the island chain, step 4 (generated islands: the builder, jungle)
- Worked in the worktree `.claude/worktrees/island-builder` (branch island-builder) so main stays playable.
- GenIsland (scripts/island/gen_island.gd, extends Island): one chain node -> one island, the same on every screen. prepare(n) is numbers only (safe on a worker thread: no nodes, no servers; IslandTheme.meshes must exist first), finish() makes the nodes. build(n) does both (tests/tools).
  - Size: RADIUS 300-450 m (600-900 across), its own terrain at CELL 3 m to MARGIN 80 m past the furthest coast, SEAFLOOR -30 (under the world heightmap's -25 floor, which it overlaps near Brinehollow).
  - Coast by bearing: radius x0.8 + 1D coast noise (x0.12) + 3-6 capes/bays (8-20% of the radius, 6-18 deg wide), a 2D wobble (+-30 m); 1-2 cliff stretches (14-30 deg; beach ramp 6 m and cliff_h 7-12 m tops instead of the theme's ramp 38-62 m to base 4.4). Inland: roll noise, a summit (theme peak, sigma 18-26% of the radius, up to 30% off centre), 2-4 hills.
  - Sites planned before the heights (land kept round each, levelled ground): dock on the gentlest shore of 24 bearings (shore = where the land runs out), village 60-90 m inland half the time else 130-190, boss on the far side (50-62% out), camp/lair/ruins 90 m apart, summit = the peak. Paths (StarterIsland._catmull) from the village to each, the dock to the village.
  - Terrain: one mesh + trimesh, splat (dirt on paths with a 0.4-2.2 m blend so 3 m cells always catch a path; site disks; sand under 2.8 m). Shallows: an L8 image in prepare, a texture in shallows().
  - Pier: timber, PIER_LEN 30 m from 6 m up the beach, posts to the ground, a ladder and lantern at the head, DockingArea (Board ship; auto-anchor works). A berth dredged to BERTH_DEPTH 4.5 round its head. mooring() = where a ship lies alongside.
  - Vegetation as Brinehollow's (5 m grid trees/rocks, 2.5 m undergrowth, MultiMesh per 70 m square) by the theme's chances and `cover` noise (clearings, kept off the sites); exclusions on an 8 m grid (the flat list was O(n^2): 25 s), colliders gathered then added to their body before it joins the tree (each shape added to a body in the tree rebuilt its compound: 1.4 s -> 0.13 s), grapple crowns, forest_crowns (cover > 0.7).
  - Arrival: banner with the name, theme and level within radius + 30.
- IslandTheme (scripts/island/island_theme.gd): DEFS per theme (land: peak, hills, roll, base, ramp, cliffs; plants: tree/edge/beach_tree/fern/bush/grass/rock chances, cover) and meshes(theme). Jungle only; the chain now rolls only themes with a DEF (so every island is jungle until the next theme lands; forks still differ in seed, name and place).
- WorldGenerator: the islands the log pose points at (next_of(chain_at), plus chain_at) are built, others freed (sync every 0.5 s); prepare on the WorkerThreadPool, finish when done (_pending; waited for and freed on exit). Registers island_infos (chart, charting), EnemyShip.no_go (+30 m), the pier's Board ship, and Ocean.isle_shoals. A 310 m island: ~1.3 s on the worker, ~185 ms on the main thread; 430 m ~2.2 s.
- Ocean: isle_shoals (MAX_ISLES 2) -> ocean.gdshader shoal_isle0/1 + isle_rect0/1, checked after Brinehollow's fine map.
- Debug: Ctrl+F10 puts the ship alongside the next chain island's pier and you on it.
- Not yet: navmesh for the islands (step 6, when something walks there; a 900 m bake is a big main-thread parse), the origin shift (step 5), the chart only pins far islands to its margin.
- Tests: isletest (new, in run_tests). chaintest: forks differ by seed/place (and theme once there are two).


## 2026-10-09: ability pass, round 2 (katana)
- Zach: the next weapon after the cutlass, polish and tune its abilities, attacks and effects. Identity: pale steel and white, afterimages, thin long lines; the element (Falling Petals / Blossom Path) is petals.
- FX: petals (tumbling billboard petals from a runtime 8x8 texture, slow fall, 1.6 s) and cut_lines (seeded thin streaks flashing through a body one after another over `secs`). elem_hit has a katana branch. TechniqueState._spray throws petals for the katana tree.
- Thousand Petals (ult) rebuilt: 2.0 s, invulnerable until the click. 0-0.42 s the blade slips home and you crouch with the hand on the hilt (pose sheathes/draws/sheathes via _attach_weapon events; humanoid._katana_hands puts the hands on the scabbard while it's sheathed) with a gather, ground ring and the moment; a hilt glint; 0.46 s one wide drawing cut (stretch/smear key, blade trail, 9 m ring at chest height, afterimage, kick) and cut_lines start through every victim; petals swirl round them; 1.4 s the click: 70 each, crumple, impact, rings, petal bursts (dust without the element), the big moment. exit() draws the blade again.
- Wind Severer: gather and glint at the blade, the real blade's trail, the wave leaves on the rising key (0.34 s, was 0.3 before the blade got there), a launch ring and petals, a light kick; squash/stretch/smear keys. It now passes its element to the wave (it always flew plain); the wave kicks dust along the ground and throws petals (not spray) when awakened.
- Phantom Step: the blink leaves an afterimage and a streak in the tree's colour (_blink_behind), a glint, the blade trail, impact/ring/petals on the cut, a kick; damage 30 -> 36 and unblockable. Squash/smear keys on the pose.
- Iai Counter: the waiting glint at the hilt (the blade is sheathed); the answer on the real blade's trail with a streak through the cut, then a beat later the blade flicked clean (glint, petals off the target).
- Iai heavy (IaiState): COLORS replaced by the katana palette by level (plain, steel-blue, white); each level gathers motes into the hilt with a glint, the top level a ring round the feet (petals when awakened); the release on the blade's trail, a streak along the dash and a ring where it ends, petals behind, a kick on a full draw.
- Tiger Rush: katana colours, a glint and the blade trail, a streak along the line and a ring where you stop, impacts (and petals) on each victim.
- Tuning: katana combo 16/18/26 -> 18/20/30 (it dealt ~25% less per second than the cutlass); ActionSpecs hit windows follow the new timings.
- Renders: abilityshot (k1_*, k1plain_petal_storm, k2_petal_storm). Tests: techtest, katanatest, powertest, balancetest, stamtest, progtest, feel, nettest.


## 2026-10-09: balance: XP, pistols, sea combat
- Zach: XP comes too fast, the pistols are overpowered, sea combat is too easy (our ship too fast; pirates can't catch up, fire too seldom, never board).
- Then: the log pose sets at level 5 (GameManager.LOG_POSE_LEVEL, was 10) and Brinehollow + Redtide should end you about there. A first clear holds ~3,300 XP (smugglers 245, Grell's den 510, burrow bugs 560, spitters 225, the Brood Queen and her sacs ~750, Redtide's guards, Morrow and his crew 680, a ship or two ~300). The chain starts at Lv 6-7 (chain.gd: 4 + layer x 2, was 10 + layer x 2) and ends ~22.
- XP: xp_to_next 100 x lv^1.3 -> 200 x lv^1.5 (level 5 at 3,406 total, level 6 at 5,642; the first level 200). Respawned enemies give half (xp_k 0.5: GruntCamp gen > 0, ScuttlebugNest gen > 0 (> 1 for start_empty nests, whose first hatching is gen 1), EnemyFleet gen > 0, a ship's boarders and deck crew take hers). Ship rewards: sunk 150 -> 100, struck after a deck fight 200 -> 150, surrendered 120 -> 90.
- Pistols: damage falls off past 12 m to 55% at 45 m; dual fire 0.22 -> 0.28 s a shot, 11 -> 10 damage. A grunt flinches from a bullet at most once a second (SHOT_FLINCH_EVERY; it still takes the damage and keeps its attack turn): rapid dual fire held grunts in hitstun from 45 m.
- Our ship: MAX_SPEED 13 -> 11, FAIR_BOOST 0.3 -> 0.2 (Ship.wind_boost(heading, weather), static: the pirates sail by the same wind). Larger sail still +15%.
- Pirates: speeds sloop 10 -> 12.5, gunboat 13 -> 15, brig 8 -> 10.5, marine 11 -> 13.5 (x the wind), ACCEL 2.2 -> 2.6. Broadside orbit keeps pace (target's speed + 1.5, between 0.75x and their top). Volleys every 6.5 s (was 10), first 3.5 s into the chase (was 6), warning 1.4 s, guns bear 50 deg off the beam (was 38), fire out to 72 m (was 64), in to 20 m (was 24), and on the run in (HUNT) too. Boarding: after one volley if they can catch you (you're slower than them, or under 7 m/s), or close; grapples from 6.5 m off the alongside spot (was 4.5); again 20 s after a party is beaten or couldn't get alongside (BOARD_AGAIN) while two men besides the helmsman are left (boarders take the next men aboard, BD_<ship>_<crew index>). Rams once you're under 8 m/s (was 6).
- A volley's warning is called off once she leaves HUNT/BROADSIDE (alongside to board, ramming: it would land on her own men); the crew keep cutlasses out while ramming.
- Tests: balancetest (bullet flinch once a second, level 5 ~3,400 XP). r8test holds her ram/boarding while it sets up the crew checks and moves her hull (not just _pos) alongside before forcing the boarding (her men leapt from 30 m astern into the stern). chaintest/logposeshot use LOG_POSE_LEVEL; chaintest's first island from Lv 6; qoltest's first level 200; progtest clears the cutlass mastery the level's XP gave.

## 2026-10-09: the island chain, step 6a (a generated island's encounters and places)
- Zach's picks for step 6: a silverback ape boss (6c), the bugs as the jungle's natives for now, the full village (6b: huts and villagers, trader + food, inn, job board), the log pose's set rule with the boss (6d).
- IslandContent (scripts/island/island_content.gd, static, from the island's seed + 4049; GenIsland.finish calls populate): camp (fire, logs, 3 tents, a thatched shack, stash, rack, lanterns, lookout tower, a jolly flag; GruntCamp "Camp" of 6: 2 sitting, a patrol, 2 riflemen (the road toward the village, the tower's foot), the captain "Captain <epithet> <name>" at the shack; strongbox camp_box; respawn 300 s / 70 m; a 45 m nav zone), lair (a hive mound (burrow x2.6), 7 burrows round it every third big, up to 5 canopy spitters in forest_crowns 18-60 m off, hoard lair_hoard), ruins (pillar ring, slabs, ruins_chest), summit (lookout tower, summit_chest on its platform, a banner from the top). Loot tier = clamp((level - 8) / 4, 1, 4) via ItemDB.tiered.
- GenIsland: site_node(site) (Site_<name>, on the ground at the site: what's built there; its nav zone parses just it), place, house, strongbox (save_key "isle<id>_<key>"), terrain_faces (world faces round a point for the nav baker), reserve_area (a site's core cleared of trees/rocks/undergrowth as 3.5 m disks on a 5 m grid: one big disk sat in one 8 m cell, out of the 3 x 3 check's reach). SITE_CLEAR: village 30, boss 24, camp 18, lair 14, ruins 11, summit 8.
- NavBaker.add_zone(node, r, terrain, faces): a zone can hand over its ground (a callable) instead of parsing it; adding wakes the baker; zones of freed islands drop out.
- StarterIsland: _tent, _log, _lookout_tower, _cyl_col, _box_col are static (GenIsland uses them).
- GruntCamp.warm_start: the first crew prebuilds its bodies (Humanoid.prebuild) and spawns once Humanoid.prebuilt_for(looks) (12 bodies at once was a ~1 s hitch on a guest mid-join).
- WorldGenerator: chests opened before are removed when an island is built (it's built after the save is applied); a guest builds nothing until Net.world_synced (set by the world sync); a new chain seed (a load, the host's world) frees every island and pending build of the old one (the ids repeat: the old islands would have stood under the host's names); chain_ready() (built, wanted, crews manned).
- Tests: isletest: the camp (6, a titled captain, its strongbox), lair (7 burrows, spitters, hoard), ruins chest, summit chest on the platform, the camp's nav zone, no trees in the camp or village, an opened chest gone after a rebuild; waits for chain_ready. netclient waits for chain_ready before comparing enemies. genshot: camp, lair, ruins, tower.
- Known: a guest whose island finishes after the host's crew respawned starts on wave 0 until the host's next spawn event (step 5).

## 2026-10-09: the island chain, step 6b (the outpost village)
- IslandVillage (scripts/island/island_village.gd, a Node3D under Site_village; IslandContent.populate builds it last): a fire pit, two lantern posts with NightLights, 5-7 thatched huts on stilts round the plaza (a gap toward the dock path), the inn (8 x 6 hip roof, porch, lamp; Interactable "Rest at the inn" -> GameManager.rest), two market stalls, a job board (StarterIsland._notice_board, now static; "Read the job board").
- People (NPC): the elder (dialogue), innkeeper (barks), trader and cook (shops), 2-3 villagers (jungle barks). Looks: IslandVillage.looks(isl) from seed + 77; GenIsland.prepare builds their bodies on its worker thread and Humanoid.stock()s them; NPC.setup now takes its body from Humanoid.make (prebuilt if waiting, else built there as before). (Building them on the main thread was +400 ms.)
- Shops: Shops.extra (runtime traders) + Shops.shop(id) (ShopScreen and offer() use it). The trader (isle<id>_trader): rum, biscuit, two tiered weapons (LOOT_WEAPONS at the island's tier and one under), a pistol; buys loot 0.9, gear/weapons 0.5. The cook (isle<id>_cook): fish, stew, rum.
- Dialogue.define(id, data): conversations made in play. The board (isle<id>_board): one notice per job (hidden once taken) -> sets isle<id>_<job>_taken. The elder (isle<id>_elder): welcome, the island (and the beast on the far side), the way on (the chain's next islands by name and theme), "About the job" per job done and unpaid -> event isle_job:<key>:pay (gold + XP 60 + 30 x tier) and _paid.
- Jobs: camp (its captain dead), lair (every burrow bug dead at once); checked twice a second; "_beaten" is remembered whenever it happens, so a deed done before taking the job counts; taken + beaten -> _done and a toast. Gold 40 + 20 x tier / 30 + 15 x tier.
- GenIsland._plan_sites: camp/lair/ruins keep the try furthest from every site (40 tries; it used to keep the last, sometimes on top of another site).
- Tests: isletest: huts and inn, 6+ people with the elder, trader/cook shops at the tier, the board's and elder's nodes, take the bounty + kill the captain -> done, the pay, the inn heals. shiptest's deck height is now the mean over the 6 s moored (one frame's sample landed on a crest once the island build shifted the timing). Render: genshot.gd.


## 2026-10-09: ability pass, round 3 (axe)
- Zach: the next weapon after the katana. Identity: ember orange, rock and dust; the element (Ember Heart / Living Fire) is embers and fire. TREE_FX axe accent is now ember red-orange (was a rock brown; the plain palette covers dust and rock).
- FX: element(tree, ...) (spray / petals / embers by tree; TechniqueState._spray, Projectile._element and the heavy's strike all use it), embers (sparks cooling white-yellow -> the colour -> dull red, drifting up, a puff of flame), debris (dark rock chips, a shared unshaded box mesh, heavy gravity), ground_crack (seeded jagged line of opaque dark boxes laid on the ground by raycast, zipping out over `secs` with branches, a molten additive core when given a glow colour, closing up by scaling each piece to nothing; a transparent version never showed), vortex (seeded funnel of curved additive wind lines parented to a node, spinning, fading in and out). elem_hit has an axe branch.
- Maelstrom (ult): invulnerable until the burst; 0-0.38 s the axe drawn back two-handed (new wind key) with a gather, ground ring and the moment; then the vortex (radius 2.8, follows the model) and seven turns (pivot from 0.38 s over 2.4 s), spin trails in the tree colour (_spin_hits takes `start`, uses _col() - also Steel Tempest's), every second turn dust and rock (and flame) thrown off; 2.8 s burst: 7 m ring, rock all round, a fire ring with the element, hitstop, the big moment.
- Earthsplitter: a glint at the top of the leap; the slam tears a 9 m ground_crack (molten with the element) with rock and dust along it, a ring and a kick; damage 26 -> 32.
- Hatchet Throw: a glint, a release ring, a kick; the thrown axe carries its element in the model ("elem|<model>", so every screen knows), leaves a ring of air every 2 m and embers when awakened, and hits ring/impact/embers both ways (it was always "axe" coloured whatever the mastery).
- Berserk: a gather, then the roar: a 4.5 m ring, an upward rush of air, rock thrown out, embers, and with the element the ember power_aura (hands smoulder, embers rise) for the 8 s.
- Whirlwind heavy: "tree" axe (the glint, tier-2 colours on both turns: the second turn ignored them), each turn a ring round you, rock and (tier 2) embers. Skybreaker: the dive's trail in the axe colour (was the default blue), the landing tears a crack with rock (molten and embers at tier 2), a ring and a kick. Combo split finisher: a short crack, rock, embers at tier 2, a light kick.
- Renders: abilityshot a1_*, a1plain_*, a2*_earthsplitter (game + top). Tests: techtest, axetest, powertest, stamtest, balancetest, feat, katanatest, nettest.


## 2026-10-09: jumping attacks for every weapon
- Zach: unique jumping attacks for the weapons without one. Picks: dual swords, unarmed, single pistol and the cutlass; skill-tree moves (as Crescent Arc / Skybreaker / Gun Rain); Twin Cyclone and Meteor Kick. Each is a move node at (3, 0) in its tree (1 mastery point, Lv 3), off the (2, 0) passive: s_dive, d_cyclone, u_meteor, g_hangshot. Without it: the plain plunge.
- PlungeState runs on one `_mode` now (PlayerState.AIR_MOVES style -> move, air_move(); dual pistols' "rain" as before). Player.air_uses {move: uses, "bounce"} cleared on landing: Twin Cyclone, Hang Shot, Boarding Dive once per jump; a Meteor Kick again only after one connected (bounce), up to METEOR_CHAIN 3. Hang Shot needs a ball loaded (and uses it).
- Twin Cyclone: 0.14 s crossed blades with a little lift, then a drill down and forward (6, 8 m/s) turning 3 times; every 0.11 s everyone within 2.6 m takes 7 and a ring (the dual palette's two colours turn about); landing: 12 within 3 m, knocked flat, ring + dust. Still airborne at 0.8 s: falls.
- Meteor Kick: 0.12 s chambered, then 21 m/s at the aimed enemy (PlungeState._aimed: nearest to the camera's heading within 0.7 rad and 12 m, not above you; always at least 0.25 down) or 40 deg down ahead; contact (1.4 m ahead of the foot): 20, knocked flat, a streak/ring/impact (a punch wind with the element), bounce (back 3.5, up 9) into a backflip, then Fall (another kick allowed). A miss: the heel into the ground, 8 within 2.2 m.
- Hang Shot: hang (sinking to 0.8 m/s), a glint, at 0.3 s one shot at the reticle (assist 0.1 rad): 30, knocked flat, ranged; recoil back 5 up 3; pose aims along aim_pitch (set from the camera on entering).
- Boarding Dive: 0.16 s blade back by the ear and the off hand pointing (a glint at the tip), then 19 m/s point first: 26, severs, stagger 0.6, the blade's trail; a backflip off them (back 4.5, up 7.5). A miss lands like the plunge.
- FX follow the mastery gating: plain until the tree's element (FX.tree_col(tree or "plain")); the element adds spray (cutlass), a punch wind (unarmed), gold sparkle at the muzzle (pistol), the dual colours (cyclone rings).
- Poses (TechniquePoses): twin_cyclone, cyclone_land, meteor_kick, meteor_land, boarding_dive, vault_back (backflip; with twin_cyclone in SPIN_ACTIONS, and GAZE_FREE), hang_shot; specs in ActionSpecs.
- Tests: airtest (new, in run_tests): plain plunge without the move, then each move: played, damage, knocked flat / the bounce and a second kick / hanging / a ball used / the vault.


## 2026-10-09: the island chain, step 6c (the jungle boss: the silverback)
- JungleApe (scripts/enemies/jungle_ape.gd, extends PirateGrunt: its own brain, the grunt's body, death, ragdoll and co-op puppets): look height APE_H 2.15 (bald, bare-chested, fur-coloured skin and shorts), dressed with a brow ridge, muzzle and nostrils, a crown of fur, a silver saddle down its back; capsule r 0.85 h 3.0, hurtbox r 1.25 h 3.4, swipe hitbox 4.6 x 2.6 x 3.8; APE_HP 1500 (x Net.hp_scale); role "ape" (no guard, no guns); no weapon.
  - Brain: IDLE at its post -> alert() = the roar; CHASE at RUN 6.2 (x1.2 enraged) by the navmesh; picks by range and cooldowns (ticking x1.25 in phase 2, x1.6 in 3): swipe (< 4.4 m; 1-1.8 s), slam (up close, 35%; 5-7 s), leap (7-22 m, 60%; 7-10 s), throw (9-30 m; 6-9 s); RECOVER after each (0.2-1.0 s: the openings); RETURN to its post.
  - roar (ape_beat 2 s: chest drumming, arms flung wide) -> a 7 m shockwave at 80% (10, knockdown); at 60% and 30% (phase 2, 3). swipe (ape_swipe 0.9 s; hitbox u 0.42-0.6, 22, knockback 10; parryable -> 2.2 s stagger). slam (hold ape_slam_wind 0.6 s, a 4.5 m red ring 3 m ahead; ape_slam; 26, knockdown). leap (hold ape_crouch 0.45 s, a 5 m ring on you; 0.9 s arc 6 m high; lands into ape_slam: 30, knockdown). throw (hold ape_lift 0.9 s: a boulder appears between its fists; ape_hurl: released at 25%, leading you by 0.4 s of your velocity, flies dist/20 s (0.55-1.4) on an arc with a 3.4 m ring where it lands; 24, knockdown). Shockwaves are judged on each captain's machine (event "aoe", jump them); the boulder flies on every screen (event "rock": grab/throw/drop).
  - Hits: never knocked down or crumpled; poise (220, decays 30/s, heavies x1.6) staggers 2 s; Haki/breaker in a slam's or leap's wind-up staggers 1.8 s; mid-special otherwise it just takes the damage. Death: coins 24, XP 600; no weapon drop.
- Humanoid: stance "ape" (_ape: the knuckle-walk, pitched forward from the hips, the arms forward of the torso by about its pitch so the fists reach the ground ahead, swinging against the legs); ApePoses (scripts/npc/ape_poses.gd; actions "ape_*" go there) and their ActionSpecs.
- BeastArena (scripts/island/beast_arena.gd, under Site_boss): boulders ring (colliders), felled trees and their stumps, a nest of torn branches, bones; the ape; a 42 m nav zone. Banner within 60 m; wakes for a standing captain within WAKE_R 24 (host); the top boss bar ("The Silverback", its phase) within RESET_R + 8; reset after 6 s with nobody standing within RESET_R 48; beaten: banner, fanfare, Dialogue flag isle<id>_boss_beaten, its hoard (boss_hoard: gold, treasure, a weapon a tier up, the Silverback Pelt cape) once per character; back after RESPAWN 900 s with nobody within 70 m (net_spawner gen).
- The village's third job: "Slay the beast" (80 + 35 x tier) reads the flag. GenIsland.prepare builds the ape's body on its worker thread too.
- Tests (6c): apetest (new): asleep, not at 40 m, wakes with the roar and the bar at 15 m, comes for you, the slam / leap (in the air, lands where it aimed) / boulder (ripped up, hurled, lands on you) each hit, poise stagger, parried swipe stagger, phase 2 + roar, reset when everyone leaves, the kill: victory, flag, hoard with the pelt, the job done. genshot: the ape.

## 2026-10-09: the island chain, step 6d (the log pose's set rule, arriving, the fork pick)
- GameManager: chain_set and chain_since (world time) next to chain_at; LOG_SET_TIME 900 s. log_pose_set(): in Brinehollow's sea always (the captain's level gate stays in log_pose_targets), else chain_set or 15 min of world time since arriving; log_pose_wait(). Host calls: chain_arrive(id) (Net.everyone "_all_chain" [id, false, now]), chain_settle() ([at, true, since]); apply_chain on every machine (a toast on arriving). A banner the moment it sets ("The log pose has set").
- Arriving: WorldGenerator._check_arrival (host, every 0.5 s): a captain within 80% of the radius of an island ahead -> chain_arrive. _wanted() = the island we're at, plus what it points to only once the log pose has set. So: arriving lets the island behind and a fork's other side go (sailing to one is the fork pick); nothing ahead is built until it sets.
- The beast's fall (BeastArena._victory, host, on the island we're at) -> chain_settle.
- Saved (chain_set, chain_since; a guest keeps its own world's), in the world sync ("chain": [seed, at, set, since]).
- HUD: unset on a chain island, "N min more here, or slay its beast" under "The needle won't settle".
- Debug Ctrl+F10 sets the log pose first if it hasn't (press again once the island's built).
- Tests: isletest: standing on the island moves the chain there and lets the fork's other side go; unset, nothing ahead and the wait shown; 15 min on it sets and the next island(s) are built; arrived afresh, the beast's fall sets it; saved and loaded. shiptest's deck height is now the mean over the 6 s moored (one frame's sample landed on a crest once the island build shifted the timing). Render: genshot.gd.

## 2026-10-09: the island chain, step 5 (streaming: a step a frame, the ring, a guest's catch-up)
- A chain island goes into the world a step a frame (GenIsland.finish_steps / run_step; WorldGenerator._finishing, one step per frame; finish() still does it all at once for tests and tools): the terrain mesh, the ground's collider as GROUND x GROUND = 16 bodies (Ground0..15, faces cut per square in prepare on the worker; Jolt builds a mesh shape as it joins, ~150 ms for a whole island in one), the dock, plant meshes, plant colliders, then each site (IslandContent.steps: camp, lair, ruins, summit, boss, village; one rng through them, so the island is the same however many frames). The log line gives the main thread's total, frames and the worst frame: ~200-250 ms over 26 frames, the worst ~30-45 ms (plant colliders or the village) under test load, was ~400 ms in one frame. build_ms: prepare's "terrain" is now "land" (it clashed with the step's).
- No origin shift: Chain keeps every island 2-7.5 km from Brinehollow (RING) and a layer's islands APART 1150 m from the layer before's; _steer turns the line as little as it takes (else the in-ring turn that keeps them furthest). Fork offsets are drawn before the turn now, so every chain layout changed (a save on a chain island finds it moved). chaintest checks 300 seeds: furthest 8.3 km, closest 1,053 m (a fork's pair).
- Freed behind: arriving (6d) lets the island behind and the fork's other side go; nothing else to do.
- Co-op: a guest whose island finishes after the host's crew respawned or was killed caught up only on the next event. Now WorldGenerator (guest) waits for the island's camps to be manned, then Net.isle_catch_up -> the host answers with that island's spawners' gens and its living net_sync keys (_isle_state; nothing if the host hasn't built it: nothing has happened there). chain_ready waits for it. GruntCamp.net_set_gen drops a warm start still waiting (it would have spawned the crew twice). PROTOCOL 4.
- Tests: chaintest, isletest, apetest, shiptest, nettest.

## 2026-10-09: the island chain, step 3 (the log pose's needles, danger, the chart on the chain)
- ChainMarks (scripts/ui/chain_marks.gd, preloaded as MARKS, no class_name): NEEDLE_COLORS (red, blue: the wrist, the icon, the strip and the chart's course lines agree), THEME_COLORS + icon(ci, p, theme, s, col) (jungle palm, snow flake, desert sun, forest pine), danger(isle_lv, my_lv) by the gap: <= -2 easy, <= 2 even, <= 5 hard, else deadly; targets(gm) = log_pose_targets() only if this screen's captain has the log pose.
- Compass strip: the log pose's needles (coloured point up, dark tail) at each island's bearing, pinned to the ends past 90 deg, the theme icon under each and "1.9km even" in the danger colour (at a fork the left one's label to its left). Unset (under level 5, or waiting on a chain island): one faint needle wandering with a "?". The strip now also shows while L is held.
- L icon: the needles ease toward their bearings (lerp_angle), so they swing round and settle the moment it sets; per island the theme icon and name in the needle's colour, then "Jungle  Lv 12  1.9 km" and the danger word in its colour; at a fork "A fork: sail to the one you'd take". Lifted above the sail gauge while that's up (it overlapped at the helm).
- Sea chart (M): one view (_view: _centre, _k, _pin) for drawing and clicks. Brinehollow's sea: centred on Brinehollow at REACH 1400 as before (zooming out only while you're further), anything off it pinned to the edge; the islands the log pose points at drawn with an arrow at the edge, the distance and their reading. On the chain: fitted round the island we're at (a red ring, "(here)", its name in the title), where the log pose points (course lines in the needle colours; a dashed shore until built) and the ship and you, never closer than REACH; Brinehollow and the sea features only when on the chart. The grid stays on Brinehollow's 500 m lines. Other charted chain islands still show.
- Co-op: all read the synced chain state (chain_seed/at/set/since) and this machine's own captain (level, log pose), so a guest sees the same needles with its own danger words.
- Tests: chaintest: the strip is up with L held, danger words by level, the chart centred on Brinehollow there and fitting the chain island and its next ones out there. Render: logposeshot (unset, set at Brinehollow, its chart, then a forking city on a found seed: unset, at the helm with two needles, the chart).
- A fork's two sides could share a name (both jungle, one name list): Chain._name now gives a name not used yet in the sea (once a theme's run out, one not on this layer or the two before); chaintest checks 300 seeds.
## 2026-10-09: the island chain, step 8 (level scaling)
- Levels (scripts/enemies/levels.gd, static): the curves, all 1.0 at level 0 (unscaled: Brinehollow, Redtide, Brinehollow's waters, the Brood Queen, Morrow), linear around REF 3 (Brinehollow's enemies sit at 1-5, so 3 is where they're "right"):
  - hp_k 1 + 0.075 (L - 3), dmg_k 1 + 0.09 (L - 3), coins_k 1 + 0.08 (L - 3), hull_k 1 + 0.04 (L - 3); xp_k (L / 4)^1.5. An optional `ref` re-bases hp/dmg on another level (the ape: 6).
  - Lv 1 / 6 / 10 / 14 / 18 / 22: hp x0.85 / 1.23 / 1.52 / 1.83 / 2.13 / 2.42; dmg x0.82 / 1.27 / 1.63 / 1.99 / 2.35 / 2.71; xp x0.13 / 1.84 / 3.95 / 6.55 / 9.55 / 12.9; coins x0.84 / 1.24 / 1.56 / 1.88 / 2.20 / 2.52; hull x0.92 / 1.12 / 1.28 / 1.44 / 1.60 / 1.76.
- Why these numbers (a level-N enemy should feel to a level-N captain like Brinehollow's do at 1-5):
  - Health follows the captain's damage. Per level: +2% (damage_multiplier), then mastery nodes (+10% at 6, +12% at 10 a tree), Haki +8% at 10, King's Will +6% at 18, weapon tiers +8% a step. Roughly x1.12 at Lv 3, 1.30 at 6, 1.60 at 10, 1.75 at 14, 1.97 at 18, 2.2 at 22 (x1.16 / 1.43 / 1.56 / 1.76 / 1.96 over Lv 3). hp_k runs 5-25% ahead of that by 22; the techniques, ultimates and elements the levels unlock (not in that sum) cover the rest.
  - Damage follows the captain's staying power: 100 + 4 a level, health nodes (up to +100), gear defense (a full kit ~18 white, +25% a tier step, +8/+8 Haki skin/Weathered: ~30% reduction at Lv 3 to ~50% at 22). Effective health ~x1.3 at 6, 1.75 at 10, 2.3 at 14, 2.9 at 18, ~3 at 22 over Lv 3 if you invest in it; dmg_k stays a bit under that so a level-N grunt takes about as many hits to put you down as a Brinehollow one did.
  - XP: a kill should be the same share of a level as in Brinehollow (xp_to_next 200 x lv^1.5, so (L/4)^1.5, with 4 the level whose numbers are written on the enemies). An island's first clear at base XP is ~1,970 (camp 465, lair 460, spitters ~125, the ape 645, jobs ~270) plus ~700 for a leg's ships; at xp_k that's ~75-80% of the two levels an island is worth (L6: 4,970 of 6,643; L14: 17,700 of 22,100; L22: 34,800 of 42,700), the rest from respawns (half XP), chests and jobs.
  - Coins: gently, a bit under what the tiered stock costs more (RARITY_VALUE).
  - Ship against ship: the crew's own guns and hull don't level (only the yard's one-off refits), so an enemy hull, her balls on our hull and her ram grow by hull_k only; her balls' splash on captains by dmg_k.
- The JungleApe's 1500 health and its blows were tuned on the first chain island, so it scales from 6 (JungleApe._lv_ref: level 6 = as tuned, level 7 x1.06, 14 x1.49 health / x1.57 damage). Its XP (600) and coins (24) are Brinehollow-sized, so those take the plain curve.
- Loot tier rule: was clamp((L - 8) / 4, 1, 4) (green for Lv 6-15, blue only from 16, yellow at 24 past the chain's end: half the chain without a gear step while health doubles). Now Levels.tier clamp((L - 2) / 5, 1, 4): green 6-11, blue 12-16, purple 17-21, yellow 22+ (IslandContent.tier uses it; the beast's hoard is a tier up: Ultra only on a 22+ island's beast).
- Where it's applied (one place per class): PirateGrunt._max_hp / _dmg (every HitData it builds: cuts, lunge, peril chop, rifle butt, pistol and rifle shots) / _xp / _coins; JungleApe overrides _max_hp and _lv_ref, its swipe and every shockwave (_aoe, before the event, so guests get the host's number); Scuttlebug._max_hp / _dmg (the ram; CanopySpitter's blob and its poison through Net.fx args); EnemyShip._base_hull, cannons' hull_damage / splash_damage, the ram, _xp, the prize's gold, and the prize tiers (Levels.tier at her level, often one up, now and then two, capped at yellow; level 0 = green/blue/purple as before).
- Spawners: `level` on GruntCamp and ScuttlebugNest (passed to each man/bug they spawn, every wave), BeastArena sets the ape's, EnemyShip passes hers to the boarders and the deck crew. IslandContent sets the island's level (IslandContent.level(isl) = node["level"]) on the camp, the burrows and the roosts; the village's job XP is x xp_k too. For the sea legs (step 7): `ship.level = <the leg's level>` before add_child, the same on every machine.
- Co-op: hp_scale composes (net_rescale uses _max_hp()/_base_hull() x k); puppets' max health comes from the host's snapshot. Damage a puppet deals here (a grunt's or the ape's swing hitbox, a bug's ram, a puppet ship's cannon splash) is built on this machine from its own `level`, so a spawner must give the same level everywhere (they do: the chain's node levels and the fleet are seeded the same on every screen); shots, spit and shockwaves carry the host's number.
- Tests: leveltest (new): the curves and tiers, Brinehollow's smugglers and bugs unchanged, a level-12 grunt and captain (health, damage, XP), a level-12 big bug, the ape at 0/6/14 (health, damage, XP) and co-op x2.2 on top, level 0 vs 12 sloop (hull, balls), her deck crew at 12, her XP when struck. isletest, apetest, balancetest, grunttest, bugtest, seatest, r8test, nettest.
## 2026-10-09: the island chain, step 7 (sea legs)
- SeaLegs (scripts/world/sea_legs.gd, SeaFeatures' child "SeaLegs", group "sea_legs"; no world_generator edit). Every 0.5 s (a guest once world_synced): once log_pose_set(), a leg Vector2i(chain_at, id) for each next_of(chain_at) (from Brinehollow that's from the start); legs no longer wanted are freed (arriving moves chain_at and unsets the log pose), and all of them when the chain seed changes.
- plan(from, to) is numbers only from the destination node's seed (+ from), the chain's node positions and Brinehollow's fixed sea, so every screen lays out the same leg: spots by rejection along the line (t 0.05-0.95, a lane either side, widened by (1800 - length) / 2 on short legs, then doubled + 300 m after 30 tries), kept ISLE_CLEAR 600 m (+ the thing's size) from every chain island's centre, HOME_CLEAR 900 m from Brinehollow's, GAP 260 m from Brinehollow's sea features (SeaFeatures._spots) and its fleet zones (+150), apart from each other, on water deeper than 12 m. Content: 1 fleet zone (2 with chance 0.3 + level x 0.02), r 110-130, kinds by the next island's level (FLEETS: sloop/gunboat under 10, gunboat/sloop + brig/gunboat, brig/gunboat + marine from 14, brig/marine + marine/brig from 18); 1-3 hazards (reef, fog bank, whirlpool, storm cell) in a narrow lane on the route; a Sea King lair with chance 0.2 + level x 0.015 near the middle; 2-3 finds (wreck, bottle, at most one islet) in a wide lane. Legs are 0.8-2.9 km; a chain has 12-18.
- Built: an EnemyFleet "Fleet" per leg (its own seed_base, warm: the first ships wait for their crews' bodies from Humanoid.prebuild, no hitch), zones carrying the level; reefs and fog banks by SeaFeatures.build_reef/build_fog (now static, parent + rng); wrecks by build_wreck (static; tier-scaled chest); islets (a sand frustum 14 -> 6 m, top 1.8 m, convex collider: walkable from the water, rocks, a palm, a chest); bottles (coins + treasure straight into the bag and a castaway's note banner). Save keys "leg<from>_<to>_wreck<i>/islet<i>/bottle<i>" (GameManager.opened): opened chests and read bottles aren't built again. Reefs (+REEF_KEEP), whirlpools (+10), wrecks and islets go into EnemyShip.no_go and come out when the leg goes. Loot tier = clamp((level - 8) / 4, 1, 4) like the islands.
- SeaFeatures: its queries (local_weather, current_at, in_eye, reef_at) read legs.reefs/fogs/whirls/storms too; storm_pos(s) static; Ocean.storm_cells and Ocean.whirls are now the nearest MAX_CELLS/MAX_WHIRLS (2) to the camera each physics tick (the shader takes two of each; CPU and GPU still agree on each screen). The chart still draws only Brinehollow's sea (index-keyed "reef:<i>"; legs aren't charted).
- EnemyFleet: add_zone(..., level), seed_base, warm, and each ship a zone spawns takes its level (EnemyShip.level, step 8: hull, guns, crew, rewards; set before add_child, the same on every machine; level 0 = Brinehollow's sea). SeaKing hides its boss bar if freed while up.
- Not yet: leg Sea Kings and finds aren't level-scaled (step 8); "monsters" besides the Sea King; a guest joining late gets a leg fleet's wave 0 until the host's next spawn event (as the islands' camps).
- Tests: legtest (new, in run_tests and test_map): the leg from Brinehollow, 1-2 zones at the island's level/kinds with ships sailing, the same plan again, every leg of the chain (fleet on each, hazards/finds, Sea Kings on some, clear of islands, deep), hazards in SeaFeatures' queries and no_go, chests on wrecks/islets, a bottle's coins, opened finds stay gone, arriving frees them, the log pose setting lays out the next legs at their levels, a new chain its own.
## 2026-10-09: audio pass (the ship at speed, footsteps by surface, takes, levels)
- Zach: the ocean at full speed hurt to listen to and looped every ~4 s; audit and polish all SFX and music, footsteps by terrain. Audit: docs/audio_audit.md (every asset, where played, measured problems, gaps, proposals). Measuring: tools/texture_gen/audio_report.py (loudness, crest, band shares, resonances, loop seams, repeats inside a loop).
- The loop bug: .wav imports are QOA-compressed (compress/mode=2), and Ambience/Weather set loop_end = data.size() / 2 (a PCM byte count), so every ambience loop played its first ~20% (hull wash 1.6 s, swell 4.9 s, wind 4 s, rain 1.6 s). loop_end now = round(get_length() * mix_rate). Loops start at a random point each time they fade in.
- The hull (Ambience._hull): hull_wash_loop replaced by hull_rush_loop (37 s: dark and bright rush crossfaded on a slow random curve, slow surges, a low body; centroid 585 Hz), hull_gurgle_loop (23 s: rising-chirp bubbles in clusters, a churning bed, gloops) and hull_foam_loop (29 s: foam fizz, above 4 m/s). Keys "wash" (rush), "gurgle", "foam"; levels by speed (rush pow(spd/8, 0.7), gurgle mostly slow, foam (spd-4)/6), pitch 0.88-1.08 (was up to 1.25), each drifting slowly (_drift: three incommensurate sines per layer); a surge when the bow (HullBuilder.BOW_Z) drops faster than ~2.5 m/s. bow_spray (3 takes) plays with the ship's bow spray (ship.gd _wake, local per machine).
- Other loops longer, built circularly, levelled to -20 LU (TOP_DB re-set to keep their in-game levels): sea_swell 47 s (uneven swells: it had a strict 6 s beat), wind 41, rigging 31, creak 33, slap 19, rain 17 (Weather -6 dB), campfire 13. ocean_loop (unused) removed.
- FX.SOUNDS is a list of names; a name with takes (name_1.wav, name_2.wav...) becomes an AudioStreamRandomizer (random, no repeats). Takes: hit 4 (louder and punchier than the swings now), whoosh 3, whoosh_big 3, thud 3, block 3 (was -24.5 LU), parry 2 (no aliased 12.9 kHz partial), gunshot 3 (a crack and bark, not 96% sub-bass), cannon 2 and cannon_hit 2 (mid crump), wood_crack 2, splash 3, land 3, swim_stroke 3, bow_spray 3, step_<surface> 4 each. blip, blip_high/low, select, peril band-limited (were square waves). "blip" was missing from FX (plunge_state's call was silent).
- gen_psx_audio.py: the newer sounds are levelled by loudness (_level: K-weighted via audio_report; peaks over -1 dBFS rounded by a soft knee up to 5 dB, else turned down), helpers _shape (looping coloured noise), _filt, _noise, _thump, _modes, _grains, _churn.
- Footsteps (scripts/game/footsteps.gd, preloaded by Player): surface_under(body) rays down; terrain (terrain.gdshader) read like the shader: splat colours (bilinear on the vertex grid, cached per mesh) or the height rules, wet sand at the waterline, stone where steep; other colliders judged once by their meshes' textures (planks = wood, cobbles/stone/rock = stone...), set_meta("surface", ...) overrides. Player.ground_surface() ("water" when wading); _on_footstep plays step_<surface> at -16 + 16 x strength dB; _on_landed adds the surface's step. Puppets: each machine rays under them.
- Master bus: AudioEffectHardLimiter (ceiling -0.5 dB) added in Settings._ensure_buses. Music: calm tracks resume where they were if you return within 120 s (RESUME_WITHIN); combat/boss start over.
- Tests: ambiencetest (every loop plays its whole length, rain too; gurgle and foam under way; surfaces: Brinehollow's harbour pier is cobbles = stone, inland grass, the deck wood). Covering suites run: ambiencetest powertest r6test r8test swimtest shiptest r9test savetest feat.
- Open: a fork's two sides can share a name (both jungle, same name list until there are more themes).

## 2026-10-09: co-op: a guest sees the pirates who board (and the deck crew)
- Bug: a guest never saw the boarders on its deck. Two causes. (1) A guest turned its copies of the crew in `net_event("board")`, which plays INTERP behind; the ship's snapshot (read with Net.latest, at once) had already moved `_crew_gone` on, so `_spawn_boarders` started past the real party: wrong men (BD_<ship>_4/5 instead of 1-3), standing frozen on her deck with no snapshots, and the real ones hidden. (2) A guest who joined after a boarding never got them at all (the event had gone by; world sync only prunes).
- Fix (enemy_ship.gd): the host's snapshot carries `_men_mask()` (index 12: the crew indices whose grunt is up); a guest's `_puppet` turns each man in it it hasn't turned yet (`_net_men`): BD for 1.._crew_gone, DK otherwise (the helmsman, and whoever's left when you board her). The "board" / "deck" events are gone. `_turn_grunt(ci, tag, seed)` is the one place a crewman becomes a grunt (host and guest; records `_crew[ci]["grunt"]`). Positions, hits, deaths were already right once the nodes match (deck-relative grunt snapshots). PROTOCOL 5.
- Tests: `nettest.ps1 board` (new mode): the host is boarded before the client joins (late join: the 3 boarders on the crew's deck at the host's deck-relative spots, in the crewmen's bodies, the men still aboard her match), the client cuts one (the host's HP drops), one swings at the client, the client kills it; the client takes the wheel and she boards again (the new party shows on our deck); her deck crew turn (DK on her deck). Default nettest, r8test, seatest still pass. Old code: "all host enemies exist here (missing 3)" and no boarders for the late joiner.
- Test gotcha: right after `Ship.place()` her node still has the old transform (AnimatableBody3D sync_to_physics reverts it until the next physics step); build anything relative to her from the placed position, not `global_transform`.
## 2026-10-09: the island chain, step 9 (tests and the island render tool)
- Co-op: `nettest.ps1 chain`. nethost lands on the chain's first island in single player, fells its camp's captain, waits for the body to go, then hosts in the running world; netclient retries the join until it's up (a late joiner). nettest_node.chain_report() is the chain as a machine has it (state; per island: name, place, radius, sites, live camp crew keys + titles, village people, chests, the beast's key), compared host vs guest after joining, after the log pose sets and after the beast falls. Commands: chain, chain_skip (F7's way: the host's clock on for everyone), chest_take. Covers: the late joiner's chain state; the same island(s) built; chests per captain (the guest's emptied chest stays there for the host until it empties its own); the host's 15 minutes set the log pose on the guest and the next islands are built; the guest landing on the island ahead moves the crew for both (the one behind and the fork's other side freed); the guest felling the beast (its hit goes through the host) sets it for everyone; the host landing on the next moves the guest on; a guest save keeps its own world's chain. A `netchain` map token makes run_tests -Changed say to run it.
- It found (before step 5's guest catch-up landed): a guest's chain island is built after the world sync, so the captain the host felled before the guest joined stood alive on the guest (6 crew there, 5 on the host). With Net.isle_catch_up it passes (5 / 5). The chain check waits for the host's report to be ready too (its new island's crew can be manned after ours).
- chaintest: the set rule's state (chain_set, chain_since) in the save check; streaming: an island seen at every step of finish_steps a frame each (the count read from finish_steps, 26 now), and not charted / no-go / shallows until whole; one let go between its camp and boss steps (found by name): queued for deletion at once, then no node, chart entry, no-go zone, shallows slot or nav zone of it left, nor its villagers' bodies; one let go while still on its worker thread is never added; a new chain seed while one is half-built frees it (and everything) and builds the new chain's island. Timeout 60 -> 180 s.
- Fix: an island let go before its beast or village was made left the bodies its prepare() built for them in Humanoid's pool for good (6-8 Humanoids, more each rebuild). Humanoid.unstock(look) frees one waiting body; GenIsland's NOTIFICATION_PREDELETE unstocks the ape's (no "boss" step yet) and the villagers' (no "village" step) once prepare's "bodies" ran. isletest's "the same node builds the same island" (prepare, then free) leaked them too.
- genshot (the island render tool; islandshot stays Brinehollow's): Args <out_prefix> [seed|-] [node|-] [psx]; builds only that node (apply_chain to it, unset), 11:00; a top-down orthographic map (north up, clouds and fog off, each site a disc and its name), from high above, the ship placed off the pier bow-on sailing in, the sea off the dock, the pier, the village (and from above), camp, lair, ruins, from the summit's lookout, its tower, the beast's ground, the beast; captions (name, theme, level, view), the perf overlay off; `<out>_sheet.png` three across. Before, a GSHOT_ID that wasn't one of the first islands never built (the sync freed it as unwanted).
- Seen in the renders (seed 777 node 0, seed 31337 node 5): everything sits where the map says; the island's own terrain square shows as a hard-edged rectangle of different sea colour from the air (fog off; not seen from the sea); the summit is ringed by canopy as high as the lookout's platform, so the "vista" looks down a path between trees.
- Also seen before the rebase: the terrain step cost ~260-330 ms on the main thread in one frame; with step 5's 16 ground squares the worst step is ~30-50 ms.
- Open: chest and flag keys (GenIsland.save_key "isle<id>_*", SeaLegs._save_key "leg<x>_<y>_*") repeat across chain seeds, and a guest keeps its own opened/flags, so what it did on island N of its own world counts on the host's island N (and back). The fix is the seed in the key plus a save migration.
- Seen once in 4 chain runs (not again, nor in the run after the rebase): the guest crashed (signal 11) just after landing on the island ahead, "Attempting to initialize the wrong RID" from a MeshInstance3D.new() in PirateGrunt._ready (the ape) in a GenIsland's boss step on the main thread. Bodies are built on worker threads (GenIsland.prepare, Humanoid.prebuild) while the main thread makes render instances: a likely race. Kept in tools/dev/out/logs/netclient_crash1.log.

## 2026-10-09: the browser build (Web export) and its site
- Zach: a browser version on its own domain (Netlify, portable to Cloudflare Pages). Full audit, decisions and deploy steps: docs/web_build.md.
- Preset "Web" (export_presets.cfg preset.1): thread-less (`variant/thread_support=false`: no COOP/COEP, runs anywhere; WorkerThreadPool tasks run on the main thread at add_task, so the chain's island prepare becomes a one-frame freeze of an estimated 2-5 s), Compatibility (the web default), shell `web/shell/play.html` (loading bar, "Set sail" click starts it, unlocks audio, optional fullscreen), excludes tools/docs/web/"Claude outputs"/addons. Pack 6.87 MB. The web export templates aren't installed yet, so no .wasm/boot yet.
- Compatibility checked on desktop through ANGLE (`--rendering-method gl_compatibility --rendering-driver opengl3_angle` with weathershot/psxshot; shots in tools/dev/out/webcompat vs webfwd): every shader compiles; the sea is brighter/more cyan (alpha blending in sRGB space: the sky through the near sea), ~40 fps vs 60+ Forward+, ~2,100-2,500 draw calls.
- Web gates (all `OS.has_feature("web")`): Net.host_game/join_game refuse (WEB_NO_COOP); title Co-op disabled "(desktop only)", no Quit; pause menu without Host Co-op / Quit Game; losing the pointer lock while playing opens the pause menu (browsers eat Esc; 300 ms guard so the same Esc doesn't close it); dodge on C (Ctrl+W closes the tab), controls list and loading tip follow; a saved fullscreen setting is reset at startup (fullscreen needs a click); GameManager saves on `visibilitychange` to hidden (a closed tab sends no close request; `_save_on_exit`).
- Known web gaps: the master HardLimiter does nothing (Sample playback has no bus effects); Brinehollow at night costs extra light passes; perf.log never reaches IndexedDB.
- Site `web/site/` (plain HTML/CSS: landing page, `img/dusk.svg` redrawn from the title screen, docs/media screenshots, self-hosted fonts, `_headers` for both hosts), `netlify.toml` (publish web/site, no build command), `tools/dev/build_web.ps1` (export, copy to web/site/play, sizes vs Cloudflare's 25 MiB), `tools/dev/serve_web.ps1` (local server, -Threads for COOP/COEP). `web/.gdignore`; web/build and web/site/play gitignored.
- Desktop finding (unchanged): the Windows preset has no exclude filter, so its pack is 47.9 MB (Claude outputs, tools, docs).
- Tests: looptest ragtest savetest feat r6test r9test hairtest pass (desktop paths unchanged). Not run: nettest (network_manager's change is a web-only early return).

## 2026-10-09: Devil Fruits out of the world's chests (for now)
- Zach: the fruits aren't up to the rest of the game's polish yet, so none should turn up in chests. `DevilFruits.IN_WORLD` (false) gates the three placed ones in StarterIsland: the Ember Fruit in the smugglers' strongbox, the Wolf Fruit in the ruins chest, the Vine Fruit in the hill chest. Nothing else places fruits (no loot table, shop or drop has them). The system, the skill tree and saves are untouched: a captain who already ate one keeps it, and flipping the flag brings them back. The controls screen says "Skills" for 1-4 (was "Devil Fruit skills"). The website plays them down too.
- Tests: powertest checks no chest holds a fruit while IN_WORLD is off (it used to expect the Ember Fruit in the strongbox); r6test.
## 2026-10-09: the site's screenshots and copy for v1.8
- Zach: the site's images were out of date and flat; new cinematic shots and the copy rewritten for v1.8 (The Chain). Devil Fruits played down (not polished yet): no fruit shot, no fruit feature.
- tools/dev/siteshot.gd: stages each shot in world.tscn (chain seed 11, SITE_SEED to change; the first chain island built with GameManager.apply_chain), hour and weather forced, enemy ships stowed except one brig for the broadside, HUD and every Label3D hidden, blood splats cleared, then 1600x900 JPEGs (q 0.86) on the 640x360 PSX grid (the post pass's pixel_res and psx_snap_res set by hand). Helm takes its own camera, so the tool's camera is made current every frame. Ship cameras ride a level copy of the hull's interpolated transform. Co-op puppets are fed 12-field snapshots (Player._puppet_process ignores shorter ones, which coopshot's 11 are) with deck-relative positions keyed by Net.key_of.
- Picks (web/site/img): hero.jpg (hero_out_c: the sloop under full sail, the sun and the island behind her; also og.jpg, 1200x630), isle.jpg (isle_gold: Greenmaw Rock at golden hour, sunbeams, the sloop at the pier), fight.jpg (Kraken's Wake on the smugglers' beach), silverback.jpg (the ape with a boulder overhead against the sunset), seaking.jpg (rearing over the sloop in a storm), village.jpg (the outpost plaza at night), coop.jpg (three captains on deck). ~1.6 MB in all; sailing.jpg and dusk.svg gone.
- Tried and left out: the log pose (raised to the eye on the pier it reads as a hand at the face, the globe too small), the broadside (good, but six were enough), the Silverback's leap (red telegraph rings, no captain in frame), Brinehollow's street at night.
- Site: the hero image right of the text (from 22% in, masked into the night) and on phones the whole frame above the text; a "v1.8: The Chain" badge; og:url, absolute og:image and a summary_large_image Twitter card; nine feature headings in a grid; the helm line under the controls; phone controls rows in two even columns (the dodge cell overflowed).
- Checked in the browser pane at 1280 wide and at 375 (phone): no horizontal scroll, text readable over the hero. No game code changed.

## 2026-10-09: island fidelity, phase 0 (measure)
- docs/island_fidelity_plan.md phase 0: Brinehollow measured as the bar for generated islands. Numbers, definitions, the ranked gap list and the phase-1 kit grouping of starter_island.gd's builders: docs/island_fidelity_baseline.md.
- `tools/dev/fidelity.gd` (headless): Brinehollow (and a copy built 9 km off and freed, to time it) and chain islands built by hand with GenIsland.build, scored on settlement, props per settled ha and per 50 m of street, categories, landmarks, places and walks between them (Dijkstra on the paths), people, night lights and lit windows, paving, vegetation, cost (surfaces, triangles, MultiMesh instances, draw calls estimated from a plaza and a harbour view by frustum + visibility range, memory, build ms). Settled land = within 15 m of a building's footprint, 3 m either side of path stretches within 30 m of one, the pier. Writes tools/dev/out/fidelity/fidelity.md + .json.
- Gotcha: a second node added under the same parent with a taken name becomes `@StaticBody3D@123` (class name, not its own), so Brinehollow's second barrel, third house... can't be found by name. fidelity.gd fingerprints every named thing's meshes (texture + tint + vertex count per surface, then looser keys) and matches the unnamed ones to them; an unnamed body with a door texture is a house.
- `tools/dev/fidelityshot.gd`: the same nine recipes found by role on Brinehollow (left) and a chain island (right): approach from the sea, pier at eye height, plaza, a street, the market, the tallest landmark, the pirates' camp, the settled core from overhead at one scale, the village at 21:00. Sheets for seeds 777, 31337, 4242 in tools/dev/out/fidelity/shots/.
- `fidelitytest` (report only, in suites.txt and test_map.txt for island and props scripts): Brinehollow + those three seeds, the lowest ratio per gated metric; passes regardless until phase 3 gates at 0.8.
- Headlines (generated / Brinehollow): buildings 0.29-0.32, props in settled land 0.23 (0.59 per ha), the village district 4 props in 0.47 ha against 35 in 0.74, interiors 0, landmarks 0.44, NPCs 0.32 (no routes, 1 dialogue tree against 8), lit windows 0.21-0.23, paving 0. Vegetation is already denser (1.5-1.7x per land ha). Brinehollow has only 8.8 ha of land against 20-40 ha. A generated island already costs Brinehollow's draw calls from its plaza (~1,000-1,600, mostly vegetation cells); half of Brinehollow's are its people.

## 2026-10-13: co-op bug pass after the merge
- The non-finite transform flood (nettest chain/board host, "!v.is_finite()" in instance_set_transform): the ruins village layout put its survivors' hamlet at Vector2.INF when no path had flat open ground 55-120 m out, so the whole hamlet (campfire first) was planned at INF/NaN and the inn never placed (IslandVillage then errored on `inn["door"]`, which also stopped the guest's island build: the missing beast). `VillageLayouts._survivors_at()` finds the spot; `_pick` rolls a town instead of ruins on islands without one.
- Helm: the helmsman was pinned to the wheel a physics step behind (the hull is sync_to_physics, so its node keeps last step's transform until the step); `_pin` now applies `deck_delta()`. On the host's ship the guest's puppet went from ~0.45 m off the wheel at full sail to ~0.27; dropped from flaky.txt.
- nettest: `_calm` handles Creature (`_cool`) and JungleBeast (`_cd`); the default mode checks twin daggers on the host's puppet and a guest-opened wound bleeding the host's grunt (BleedStatus ticks routed to the host).
- Left to the islands pass: IslandLife reads `IslandVillage.huts` (gone), a SCRIPT ERROR on every generated island that fails nettest chain's host.

## 2026-10-11: the beasts rebuilt (the Silverback, the Sea King)
- Why: on the v1.8 site shots the Silverback read as a dark man a bit taller than the captain and the Sea King as a flat green plank.
- Silverback: ApeBuilder (scripts/npc/ape_builder.gd) is its own body on the Humanoid's joints. A look with "beast": "ape" builds it instead of BodyBuilder (a two-line branch in Humanoid._build), so poses, ragdoll, LOD and co-op puppets don't change. It's built in the rig's unit space: hip 0.68, thighs and shins 0.3 (foot IK needs them equal), shoulders 0.28 out, arms 0.4 + 0.38 to knuckle fists (longer than the legs), a barrel torso with a hump rising behind a small low head (heavy brow, sagittal crest, muzzle, fangs, glowing amber eyes). Rigid parts per joint, 4 materials (fur, skin, flat with vertex colours, eye glow), seeded rng 7741 so every screen builds the same body. Fur is 3-sided tufts (_shag) lying along the surface. The silver saddle is painted over the back, rump and thighs by vertex colour (_paint/_silver), and the saddle gets no tufts because a real saddle's hair is short. It has a bare scarred chest, a bone necklace with a skull, a scar through the brow and a broken harpoon behind the left shoulder. New textures fur and scales (gen_psx_textures.py `beasts` mode). JungleApe._dress is gone.
- Size: APE_H 2.15 -> 2.4: ~3.5 m reared up (1.9x the captain), ~2.3 m on its knuckles (1.25x). ApePoses.STRONG_LEGS is bow-legged with bent knees, and the keys that use it drop the hips 0.1.
- Gameplay scaled with it: capsule r 0.85 -> 1.05 (h 3.0). Hurtbox r 1.25 -> 1.45, h 3.4 -> 3.8, now 0.45 m forward over the chest (_hurt_follow turns it with the facing every tick, host and puppet). Swipe box 4.6x2.6x3.8 @ z -2.4 -> 5.2x2.8x4.2 @ z -2.7, SWIPE_RANGE 4.4 -> 4.9. Slam ring 4.5 @ 3.0 m -> SLAM_R 4.8 @ 3.2 m, leap ring 5 -> LEAP_R 5.4, roar wave 7 -> ROAR_R 7.5, boulder x0.75 -> x0.95 with ROCK_R 3.4 -> 3.6. Damage, timings and telegraph lengths are unchanged.
- Camera: CameraRig asks every boss with camera_room(from) (0..1). JungleApe returns 1 while it fights within 26-34 m. The arm draws back to at least ROOM_ZOOM 6.8 m (the combat cap is 3.8) and the view lifts ROOM_LIFT 0.7 m.
- Sea King: the body is one skinned loft on a Skeleton3D of SEGS bones (16 -> 20, SPACING 2.3 -> 3.0: 60 m long). It's round, with a flattened pale belly, and radius 1.5 -> 2.05 -> 0.2. _seg_r follows it, so struck()'s cannon areas grow with the body. Each vertex blends between the two bones around it (_weights). It has a scalloped dorsal sail (spines every 2.5 m), pectoral fins and a tail paddle. The hide is the scales texture in vertex colours (dark green back, darker dorsal stripe and bands, pale belly) on psx_wet.gdshader: psx_lit_body with PSX_WET for a GGX highlight and a cold rim. The head is a lofted skull with brow ridges over slit eyes, swept horns, jagged frills, whiskers, fangs in both jaws and a red mouth. The lower jaw is hinged at the back and opens down (it used to swing up into the skull).
- Gotcha: a skinned mesh is culled by where its rest pose was built (around the SeaKing node, not the serpent), so the body vanished from some angles. _pose_segs sets the MeshInstance's custom_aabb from the joints every tick.
- Animation: past the neck (NECK 4) the body rides the swell in humps, sin(i*1.2 - t*1.6) * HUMP_H 3. These are coils breaking the surface, rolling back along it. The jaws roar open on rising, breathe while circling, gape through the rear and strike, snap shut on the bite (_jaw_open 0 in _bite) and then growl open again. They also roar on the tail slam warning. HEAD_K, HEAD_C, the hurtbox, the bite and the tail are as before. net_pack carries 20 joints now.
- Cost (modelshot): the ape is 3,440 tris and 22 surfaces over 13 meshes (the captain is 7,630 / 25). The Sea King is 3,042 tris and 10 surfaces over 3 meshes (body 1 skinned mesh).
- Renders: kingshot.gd takes `storm` and adds circle_low, circle_wide (high overhead) and bite_head views. siteshot's ape roar is framed with the captain. web/site/img silverback.jpg and seaking.jpg are reshot.
## 2026-10-11: sword and pistol (the Corsair moveset and tree)
- Zach's to-do: a cutlass (or other one-handed blade) in the main hand and a pistol in the off hand, with its own combo, right-click, jump attack and skill tree. Worked in a worktree (agent-a91dede70f0cd2d11).
- Player.style() "sword_pistol": a sword-class main hand that isn't an axe or katana with a pistol in the off hand (_offhand_valid allows exactly that mix; a pistol picked up isn't put in the off hand by itself, right-click it in the bag). Player.offhand_kind() (sword/axe/dagger/pistol). SkillTree STYLE_TREE -> "corsair" (tab CORSAIR, between DUAL and PISTOL). Humanoid stance "sword_pistol": WieldMoves.SP_GUARD (cutlass as the cutlass guard, pistol low and forward); Humanoid.point_guns grips only the off-hand pistol along the forearm (hand_l never keyed: the arm aims). BladeTrail skips pistols.
- The pistol (scripts/player_states/corsair_gun.gd, CorsairGun): one gun, Player.ammo[0] balls (2 + Bandolier `shots_corsair`); firing the last starts a 1.4 s one-handed reload (reload_time; `reload_corsair` cuts it) that doesn't stop an attack (start_reload skips the reload pose while the body's busy); a shot with nothing loaded is a butt-strike (55%). A ball goes for the nearest enemy roughly ahead within 8 m (to its body centre, point-blank inside 1.6 m), full damage to 5 m falling to 50% at 16 m, ranged. Techniques fire free shots (`ball` false). opts: knock, stagger, down, stop, shake, unblock, elem (colours), burst (a powder burst for techniques; the basics' comes from FX.elem_hit at tier 2), size.
- Combo (LightAttackState STYLES "sword_pistol", "kinds" cut/shot/cut_shot, "shots" the ball's damage, spec "shot" u when it fires): sp_cut (0.7 s, cut 10 at 0.27-0.38 s, chain 0.46), sp_shot (0.62 s, shot 14 at 0.2 s, chain 0.4), sp_rise (0.72 s, rising cut 12, chain 0.48), and with Powder Finale (cs_finale, `powder_finale`) sp_finale (1.05 s: a full turn with the blade out, cut 11 over 0.21-0.46 s with REACH "spin", then a shot 20 at 0.62 s that knocks flat). Combo damage per second (wieldtest): 30.5 with the finale (26.9 without) against cutlass 24.4, katana 35.1, axe 36.0; a ball's falloff and the reload pull it down in a long fight, the reach pulls it up.
- Heavy: Powder Lunge (HeavyAttackState "powder_lunge", sp_lunge 0.95 s): coil, a fencing lunge (thrust 22 at 0.29-0.45 s, staggers, doesn't fell), then a ball into whoever's on the point at 0.57 s (20, knocks flat; the butt with nothing loaded). Fatigue/predictability as every heavy.
- Jump attack: Dead Man's Drop (PlungeState "deadmans_drop", cs_drop at (3, 0), Lv 3, once a jump): leaning over the aimed enemy, a ball down into them at 0.14 s (14, a 0.8 s stagger that pins them, the kick lifts you 3 m/s), a dive at 18 m/s through them from 0.26 s (20), the landing cut knocks everyone within 2.6 m flat (12). No ball loaded: just the dive.
- Techniques (TechniqueState, poses in WieldMoves): Parley (guard skill like Riposte; COUNTER_POSE sword_pistol parley_shot: the blow turned on the blade, 16, then the pistol at their chest at 0.3 s, 28, unblockable, knocks flat), Grapeshot (0.7 s; at 0.26 s one blast over a 7 m cone (cos 0.45): 22 near to 13 at the edge, ranged, thrown back reeling 0.8 s; seven tracers fan out, recoil 4 m/s), Crossfire (Lv 4; 0.95 s; blink-dash through the enemy you face within 9 m with a guard-breaking cut (24, 1 s stagger), turn round behind them over 0.28-0.46 s, a shot in the back at 0.5 s (26, unblockable, knocks flat); refunded with nobody there). Ultimate Broadside (Lv 12; 2.4 s, untouchable until it lands): the blade raised to call it (gather, ground ring, the moment), swept down at 0.56 s to point at them, a shot into each of up to six within 14 m from 0.62 s every 0.14 s, left to right as the pistol fans across (10 each, a 1.3 s stagger), cannonballs whistle in as streaks from the sky (1.45 s), then at 1.75 s the broadside lands: FX.cannon_blast under every one (40, unblockable, knocked flat), a 10 m ring, hit-stop and the big moment.
- Tree (SkillTree._build_corsair, 24 nodes with mastery): root, Dead Man's Drop, Powder Finale, Boarding Steel / Powder Monkey / Dread Captain (dmg), Dry Powder (stam), guard: Steel and Shot (parryshot), Parley, Cool Head (parry), Return Fire (deflect + return); Bandolier (+1 ball), Grapeshot, Crossfire, Broadside; Smoke and Steel (flow), Quick Loader (reload), Lucky Ball (crit), Double Charge (heavy), Plunderer (leech), Gunsmoke (cdr), No Quarter (exec). Icons: gen_psx_textures.py technique icons parley / grapeshot / crossfire / broadside.
- Colour and element (FX.TREE_FX "corsair": core warm white, edge scarlet powder flash, accent gold sparks): plain until Black Powder (cs_elem, Lv 8 after Grapeshot); with it the skills burst in powder (FX.powder_burst: flash, sparks along the shot, a ring, dark smoke FX.POWDER_SMOKE) and Broadside's cannon fire burns (FX.cannon_blast with a glow: sparks, flame, black smoke); Powder Keg (cs_elem2, Lv 16 after Dread Captain + tier 1) puts it on the combo, heavy and jump attack (scarlet trails, elem_hit's powder burst on each hit). FX.element("corsair") = gold sparks + dark smoke. FX.smoke / muzzle_sparks take an optional colour.
- Tools: abilityshot takes "combo" (clicked through), "air" (from 2.5 m up) and styles sword_pistol / sword_axe; posebench PB_OFF=pistol|axe; animsheet extras "offhand". ActionSpecs "swoosh" now draws the real blade's trail on keyed moves too (it used to need a swing path).
- Renders: tools/dev/out/abil/c2_sword_pistol_combo, c3_sword_pistol_heavy, c3_sword_pistol_air, c3_riposte_counter (Parley), c3_grapeshot, c3_crossfire, c3_broadside; animsheets out/anim/sp_*, sp2_*, sp3_*; posebench out/pb/sp_*.
- Tests: wieldtest (new), techtest (Grapeshot, Crossfire, Broadside, Parley, the Corsair tree in "every node learnable"), nettest (a guest's shot lands on the host's grunt; the host's puppet of the guest shows the stance, the shot and the pistol along its forearm). Note: netclient loads CorsairGun by path (a --script can't name a class that touches autoloads). The one full nettest run showed the stance/action/grip checks passing and the shot landing for 10 (the grunt guarded it: the check now fires an unblockable ball); later reruns didn't get past the join under machine load and weren't repeated.

## 2026-10-11: dual wield, fixed and polished (sword + sword, axe or dagger)
- Zach's to-do: make the dual-sword set the general dual-wield set for sword + sword, sword + axe and sword + dagger, polished to the cutlass/katana/axe standard. Identity confirmed: cyan and violet, paired trails, X shapes; the element (Twin Currents / Crossing Storm) adds motes in both colours and an X on every blow.
- The poses moved out of humanoid.gd into scripts/npc/wield_moves.gd (WieldMoves; TechniquePoses.pose falls through to it) and were rekeyed with every joint (hips, head countering the chest), held strike keys, squash/stretch and smear: dual_1 (0.5 s: the right blade hauled high, a diagonal forehand, the left up on guard; hit 0.16-0.24 s, chain 0.34), dual_2 (its mirror with the off hand), dual_cross (0.58 s: both thrown up, crossed down into a lunge; chain 0.42), dual_spin (Twin Spin, 0.7 s: a coil, then one turn with both out, REACH "spin" all round; chain 0.56), dual_heavy (0.88 s: raised, a hop, crashing down; hit 0.37-0.53 s). Before, the hits had no hips/head keys, chained at 0.24 s before the strike finished, and drew fixed arcs in one colour; dual_spin was a SPIN_ACTION (no blend in) and is now keyed from a coil. Damage 8/8/13/20 -> 9/9/15/22 (combo 33.1 dps against the cutlass's 24.4 and the axe's 36.0).
- Trails: FX.blade_swoosh takes the off hand's colour (BladeTrail.color_l): both blades draw their own trail, cyan and pale violet (the tree's edge and accent at tier 2). The combo, heavy, Cross Fang, Blade Dance, Tempest and Crossed Counter all draw the real blades' trails now.
- Mixed pairs (Player.offhand_kind / WieldMoves.offhand_kind from the off-hand mesh's model, so puppets agree): an off-hand axe is held low with its head out front and its hit (dual_2) is a heavier hack down in front, x1.25 damage, x1.4 knockback and hit-stop, the chain 0.06 s later; a dagger is held close, point out, and its hit is a stab from the hip, x0.85 damage, the chain 0.06 s sooner (LightAttackState.OFFHAND). There's no dagger item yet: it's keyed on a weapon model "dagger" for the dagger round.
- Heavy: "tree" dual (the glint, tier-2 colours), the strike tears an X in the ground ahead (FX.twin_cross flat) with a ring.
- Techniques: Blade Dance (a glint, both blades' trails through the six turns, a ring each turn alternating the colours, an X through them on the last with a kick); Cross Fang (both blades glint at the top, their trails, the landing tears an X in the ground and through each one caught, ring, kick); Crossed Counter (the answer on both blades' trails with an X through the target); Tempest of Steel rebuilt as an ultimate (2.4 s, untouchable until the burst): blades crossed high overhead while it gathers (0.4 s, the moment), then two whirlwinds (cyan, violet) with both trails for eight turns, then a great X across the ground and through every victim, rings, hit-stop and the big moment.
- FX: twin_cross (two light streaks in an X, upright or flat), motes (bright points thrown that hang), elem_hit and element branches for "dual".
- Renders: tools/dev/out/abil/d1_dual_sword_combo, d1_sword_axe_combo, d1_dual_sword_heavy, d1_blade_dance, d1_cross_fang, d1_steel_tempest, d1_riposte_counter; animsheets out/anim/du_*, du2_*; posebench out/pb/dax_* (an axe in the off hand).
- Tests: wieldtest (every hit lands, Twin Spin gated, the axe hits harder, the heavy), techtest, airtest.
## 2026-10-11: island fidelity, phase 1 (the kit)
- Brinehollow's builders are now kit modules in `scripts/island/kit/`, and `starter_island.gd` is Brinehollow's land (height function, terrain, paths, vegetation, bugs, loot) plus its layout: where each kit piece goes, with its own numbers and fixed seeds (`SEEDS`: port 7007, village 2626, market 51, ruins 4242, spitters 7171, Grell 97). 2,655 lines -> ~900, plus ~1,750 in the kit and 330 of cast data (`brinehollow_cast.gd`). Guide: `.claude/skills/driftwake-islands`.
- The context (`KitContext`): ground (hv, ground_max/min), reserve/excluded (with an `under` size cap: the bunting poles only dodge small things), path_dist, a seeded rng per piece (`hash([seed, salt])` or a fixed seed), the style (`KitStyle`: BRINEHOLLOW, JUNGLE overrides), a light budget (`take_light`; Brinehollow LIGHTS 12, 10 used), save_key, plan_place/build_list (placements worked out as data, made later), place/put/add/house, markers, timed. `Island` gained the interface both islands implement: hv, walk_height, reserve, excluded, path_dist, save_key.
- Modules: KitHarbour (the quay line planned in a frame from `out`; `shape`/`earth`/`on_platform` hooks for the height function, splat and walk height; pier, quay, side piers and ships, longboats, waterfront plan + build, quay dressing plan, the harbour front with `mirror`), KitVillage (tables, benches round, bunting ring/line/poles, laundry, garden, road lamps, notice board, handcart, `dress_houses`), KitMarket, KitPaving (quads as data, one mesh), KitLandmarks (lighthouse + cottage, ruins + driftstone, harbour tower, crane, chapel, lookout tower, colliders), KitCamps (campfire, tent, log seat, flag, strongbox, castaway camp, pirate camp, den, training yard), KitCave (BroodCave with `shape_seed`/`hoard_id`/`title`, the inn), KitLife (cast as data, npc, at_marker, routes, `look_for`), KitLights (post, light).
- Same island: `tools/dev/islanddump.gd` writes every node under a freshly built Brinehollow (transform to the mm, vertex-position hash per surface, material, collider, light, NPC config/route/look, loot contents, save id, prompt) plus the exclusion list, paths and story anchors. Original vs kit-built: identical except the three training dummies' sack heads, which also differ between two runs of the same code (`Props.straw_dummy_mesh` uses an unseeded `RandomNumberGenerator.new()`: pre-existing, also differs per co-op screen). Getting there: frame math in scalar floats, radii passed as literals (6.2 - 0.8 isn't the double 5.4), no -0.0 into atan2, every rng draw in its old order (pieces whose rng is drawn inside mesh building stay one build step).
- fidelity.gd: Brinehollow's numbers unchanged (buildings 31, props 93, NPCs 19, NightLights 11, landmarks 9, 180 lit windows; two live-character counts move by 1 with whoever is standing when it measures). It now lists Brinehollow's build steps. islandshot (13 day views + 3 at 21:00) and fidelityshot before/after: the same pictures.
- Build ms per piece (one run, other sessions' tests going): land 659, terrain 303, vegetation 2,528, NPCs ~1,820 (19, ~95 ms each), cave 161, village 107 + dressing 32 + market 16, pier 8, quay 16, harbour front 22, side piers 57, waterfront 58, quay dressing ~40, den 46, scuttlebugs 22, the rest < 10 each: ~5.9 s. The settlement pieces are ~0.45 s; the bill is the plants and the people (bodies, which GenIsland already builds on its worker).
- Proof the kit isn't Brinehollow-only: `KitVillage.dress_generated_village(gi)` (tools only, `FID_KIT=1` in fidelity.gd and fidelityshot) dresses a built GenIsland's village in the jungle style (dress_houses round its huts, benches, bunting, lamps from a budget of 4) under Site_village, with `ctx.own_reserves` (a GenIsland's reserves are tree clearings, so the context keeps its own occupancy; IslandVillage now records `huts` and `taken`). Seed 777: dressed share 0.10 -> 0.40, props per settled ha 33 -> 70, street props per 50 m 1.6 -> 2.3, prop categories 8 -> 11.
- Callers moved: IslandContent (KitCamps.log_seat/tent, KitLandmarks.lookout_tower), IslandVillage (KitVillage.notice_board), BeastArena (KitLandmarks.cyl_col). StarterIsland keeps `_quay_pt`, `_quay_z`, `_on_platform`, `_dock_point`, `port_x0/x1`, `place` and the anchors and nodes tests read.
- Phase 2 file claims: docs/island_fidelity_plan.md.
- Tests: storytest qoltest foresttest r6-r10 savetest swimtest grunttest yardtest apetest isletest fidelitytest chaintest looptest ambiencetest pass; nettest's only failure under load was "clock synced" (rtt 0.9 s on localhost).
## 2026-10-12: the jungle style table and the tropical jungle
- KitStyle (scripts/island/kit/kit_style.gd) is now a full style: BRINEHOLLOW has every key (its values unchanged) and a theme table replaces whole keys (`KitStyle.of(name)`, read-only; `get_style` kept). New keys: `mat` (texture per part), `house` (pools/ranges/chances for `KitStyle.house_spec`), `inn`, `stall`, `pier`, `props` (slot -> model: `KitStyle.prop`; jungle basket, pot, torch_post, totem in JungleProps), `folk` (`KitStyle.folk_look`: pools per CharacterLook key, `_fem` variants, fixed values), `music`, `ambience`, `weather`, `haze`. Table of keys and how to add a theme: driftwake-islands skill.
- Buildings.house takes `beam`, `floor`, `poles` (round posts), `lashings` (rope at joints) and `eaves`; Props.market_stall a post texture. Defaults keep Brinehollow identical (islanddump: only the three dummies' unseeded sack heads differ).
- Re-skinned through the style: the generated village's huts (bamboo/woven walls, palm-leaf thatch, steep pitch, deep eaves, round lashed stilts with cross braces), inn, stalls (thatch canopies, bamboo posts), plaza lamps (tiki torches, light at their "Flame" marker), villagers' looks; the pier (palm posts lashed at the deck, sagging rope rails, a torch); the pirate camp (baskets, pots, torches, a lashed shack).
- Textures (gen_psx_textures.py `jungle`): bamboo, woven, palm_thatch, flagstones, vines, broadleaf. Sound: jungle_loop (gen_psx_audio.py: humid bed, two cicadas, crickets, bird calls).
- By place: `KitStyle.around(tree, pos)` = [style, weight], 1 on a chain island fading over 140 m past its coast. Music plays the style's track ashore on a chain island (was "sea" anywhere far from home); Ambience mixes the style's bed (louder at night, less in storms); Weather blends the home odds into the style's (jungle: more rain) and adds its haze. Home waters keep today's odds exactly (HOME_ODDS = BRINEHOLLOW's). Gotcha: a slot's params are PARAMS' read-only row, so the blend copies.
- Jungle vegetation (IslandTheme + GenIsland._scatter_vegetation, JunglePlants): big trees on a 10 m grid (canopy trees 13-18 m with buttresses, lianas and three-tier crowns; strangler figs; kapoks with layered flat crowns; emergents 26-32 m), mid trees, palms, mangroves at the waterline, bamboo, understory shrubs, broad leaves, a second layer of ferns/grass under thick cover. Big trees are [body, detail, lean]: bodies in 140 m squares to 1100 m with shadows, detail to 130 m without. Each island grows one of six forests (IslandTheme `forests`, own rng stream): mixed, old growth, bamboo thicket, mangrove coast, palm fringe, strangler figs.
- The floor: inland trails are overgrown (`overgrown`), the dock road stays clear. `GenIsland.undergrowth_at(pos)` / `GenIsland.thicket(tree, pos)` (a 4 m grid from prepare) slow the player (MoveState) and grunts by up to 30% (THICKET_SLOW); 0 in the village, sites, arenas, on the road.
- Canopy arenas: `GenIsland.canopy_arena(c, r)` in prepare before the scatter: clear floor within r, giants ringing it at r + 4.6 turned to lean in, trunkless `canopy_roof` pieces closing the roof on an 8 m grid.
- Cost (fidelity.gd, seeds 777/31337/4242, before -> after): surfaces 1980/1265/1352 -> 3370/1993/2140; triangles 1621k/796k/867k -> 2235k/1170k/1229k; MultiMesh instances 40k/19k/21k -> 66k/30k/32k; draw calls (plaza) 1578/1032/1152 -> 1546/942/1015, (harbour) 1665/1148/1220 -> 1292/1070/939; shadow-pass draws near the plaza unchanged (~245-293). Plants now build over three frames.
- Tests: isletest checks every theme has every style key and prop slot, the lamps come from the style, thick undergrowth vs a clear village and road, and a canopy arena. Covering suites via run_tests -Changed.

## 2026-10-12: nettest's pistol and clock checks
- "our pistol shot landed (156 -> 146)" wasn't the shot doing 10. The check compared the grunt's lowest health (min_hp) before and after, but the first test hit (20, from across the map) alerts it with nobody near, so it goes home and heals to full at its post (PirateGrunt RETURN). The shot then took 176 -> 146: the full 30 (melee_hit(30) x damage_multiplier 1.0, no falloff inside NEAR 5 m, no reduction on the host). The host now sums each enemy's damage taken (`dmg_taken`, report field 5) and the check wants exactly what fire() deals, worked out the same way.
- The test also fired on the first frame of sp_shot, with the gun still behind the body, and sometimes got 0 damage: the hurtbox ray stopped on the shooter's own hurtbox (fire() then skips it as ours and loses the shot). Fixed in the game: CorsairGun.fire excludes the shooter's hurtbox from that ray. The test now fires on the pose's shot key (ActionSpecs.shot_seconds), as the combo does.
- "clock synced" read Net.rtt right after joining, while the host was still loading or building the chain. It's now judged ~3 s later from 7 asks to the host: its clock must fall inside our ask-to-reply window (median < 50 ms off) and the median round trip under 250 ms (localhost: ~25-40 ms). Net.rtt is an EMA (0.2 a ping, 1 ping/s) seeded by the first pong, which spans the client's own world load, so it can still read ~0.9 s five seconds after joining while the real round trip is ~40 ms (it settles within ~15 s; "we know our ping" later reads ~20 ms).
## 2026-10-12: island fidelity, phase 2 (harbours that vary by island)
- A generated island's bare plank pier is now a harbour district: `GenHarbour` (`scripts/island/kit/kit_harbour_gen.gd`) plans it in `GenIsland._plan_dock` (prepare, the worker: after the heights, before the vegetation so its reserves keep trees off) and builds it as finish steps (~10-24 a harbour, worst ~20-50 ms: a 60 m stretch of boardwalk with its pilings and ropes). gen_island.gd: `var harbour`, the plan call, the steps appended after "dock"; its old `_build_dock` is gone (every kind builds the pier on the same line: PIER_Z0..PIER_LEN, deck 1.7, ladder, head lamp, Board ship area, `mooring()` unchanged).
- Laid out in a frame from the dock (a bare KitHarbour: the waterline scanned per 2 m station, smoothed; `at(s, d)` = s along the shore, d in from the waterline). No height hook: walkways stand on pilings, houses on stilts, a deck that meets the rising beach runs into it, otherwise ramps down (`_landing`). Every spot validated (`_ok_land`, `_ok_water`, paths, reserves) with spare candidates.
- Kinds, rolled from the theme's `harbour_kinds` (or `harbour_wild_kinds` when the village is over 110 m from the dock): **stilts** (boardwalk along the water on palm pilings with rope rails, 4 houses out in the shallows on their own walks, a row and a half of stilt huts up the beach each with a thing or two beside it, fish stall + harbourmaster's booth at the pier root, net racks with the mender's bench, fish racks, canoes pulled up and tied along the walk, a boatwright's bench with a dugout); **cove** (rocks either side and a wall behind, a boathouse over the water with a longboat and the `cove_stash` chest, a dark-sailed sloop at her jetty with a red signal lamp, lookout tower, rough shacks, contraband under tarps, rowboats, weapon racks); **wharf** (a plank wharf along the shore on squared piles, warehouses with ramps to their doors, a crane, the merchantman at her own 26 m pier, longboats, the booth and two stalls on the deck, KitHarbour.plan_waterfront's row behind in the jungle look, crates, kegs, sacks, carts and timber); **ruins** (the patched pier, an old jetty: sound root, a gap, a bay fallen into the sea, stumps; a wreck, the harbour tower's stump, roofless huts (two big), squatters' shacks with tents, logs and debris); **landing** (wild pool only: a rough jetty, a lamp, maybe a fisher's lean-to, boats pulled up).
- Models (`kit_harbour_models.gd`, HarbourModels): deck_strip (mitred so curved walks share edges; its top goes into the walk-on trimesh), piles (palm or squared, weedy below the tide line, `lean`), rope_rail, bollard, canoe (outrigger), net_rack, fish_traps, sacks, timber, contraband, warehouse, boathouse, ruined_hut, tower_stump.

## 2026-10-12: coastlines (sandy shelves, sea cliffs)
- Zach: rocky jagged sea cliffs where the land meets the water too high to blend into a beach, and a longer walkable sandy shelf under the water. `scripts/island/coast.gd` (Coast), used by Brinehollow and GenIsland.
- Shelf (`Coast.shelf`, on the sea side of both `_height_natural`s, weight `shelf * _shelf_room(p)`): 0.5 m at the waterline, -0.35 at 9 m, -0.9 at 40 m, down to the seafloor over 30 m. The plan's -0.5 at 40 m let the swell's troughs bare the sand in big patches far out; -0.9 keeps them near the beach. Off: GenIsland's cliff bearings, the dock's fairway (45-70 m either side of the pier axis, seaward of 30 m behind its root: the merchantman/smugglers' berths and the ship's approach stay deep), the last 30 m inside the radius (isletest's sea all round); Brinehollow's harbour front (its quay 20 m past each end), round Grell's den (60-90 m) and the terrain square's edge. `_height_fn(p, 0.0)` is the ground without it.
- Cliffs (`Coast.cliffs`, a pass over the height grid after it's built, in prepare for GenIsland): a land vertex on the waterline is cliff when the land within 6.6 m tops 3.0 m (fully at 4.5). Round each: land within 7.5 m raised to its local top (the cliff stands at the water's edge), water within 24 m cut to -4.5 - d/4 (the foot), and within 45 m the shelf given back. No cliffs within 60-80 m of GenIsland's dock; at Brinehollow none at the harbour (25 m past the quay: the wake spot too), the castaway's camp or the den. The clifftop is rock in the terrain splat (g channel).
- The rock (`Coast.rocks` as arrays on any thread, `Coast.build` on the main thread): a jagged 6-7 sided column per cliff vertex on the waterline (foot -6, top at the cliff top -0.15..+0.5, 18% pinnacles 1.2-3 m higher, pushed out to sea a little), flat ledges at the foot (top 0.55-0.85 m, room to climb out for the swim ledge check), scree (no collider), sea stacks 9-17 m out on deep water (3.5%). Per 64 m square one mesh (visibility range 900 m) and one ConcavePolygonShape3D under a `CoastRocks` body. Deterministic from the island's seed (Brinehollow SEEDS["coast"]) per vertex. GenIsland builds it in the terrain step and reserves each column (2 m) from the vegetation; `coast_cols` is public (isletest compares two builds).
- Islets (sea_legs.gd): the sand cone is now a profile (`ISLET_SHELF`): a beach, a shelf to 22 m at -0.4..-0.8, a trimesh collider. Redtide Rock is unchanged (already a sea stack cliffed all round).
- Set pieces on a beach (KitSetPieces._beach, KitLandmarks' beached wreck) wanted -1 m of sea 14-16 m out, which no shelved beach has: now -0.3. The sunken village's lagoon is dug to LAGOON out of a shelf as well as raised from the deep.
- Brinehollow's coast changed on purpose: shelves all round but the harbour and the den, a rocky stretch on the south-west bay's west side; the lighthouse hill's east side doesn't reach 3 m within 6.6 m of the water, so it stays a beach. Its vegetation reshuffles (heights feed the rng).
- Build cost: GenIsland's "land" unchanged within noise (1773 -> 1763 ms, seed 3558282717).
- Tests: isletest (a rock wall with a collider along the cliffs, the columns on the land's edge, the shelf 9 m and 30 m out on the beaches, the same node builds the same coast), swimtest, shiptest, storytest, harbourtest, legtest. Renders: genshot's new `cliff`, `cliff_foot`, `shelf`, `shelf_out` shots (GSHOT_ONLY picks shots), islandshot for Brinehollow; tools/dev/out/coast/.
- Budget: 4 NightLights a harbour (its own KitContext; the cove's signal lamp is red: style `harbour_signal`). Props in batches of 8 a step with visibility_range_end 220 m. Style keys added at the end of JUNGLE: harbour_kinds, harbour_wild_kinds, harbour_pile, harbour_deck, harbour_roof, harbour_walls, harbour_tarp, harbour_floats, harbour_signal.
- `spots` ([point, facing, role]) says where harbour people would work (harbourmaster, fishmonger, net mender, boatwright, dockhands, craneman, traders, smuggler, lookout, squatter); nobody stands there yet (their bodies would have to be prebuilt on the worker with the village's).
- harbourtest (each kind forced, far out to sea): district buildings/props (stilts 12/40, cove 10/32, wharf 13/40, ruins 8/31, landing 1/6; Brinehollow's harbour 13/33), 2-4 NightLights, deep berth, Board ship, the ship's berth box clear, a captain on the pier head and on the walkways, same plan twice, seeds roll different kinds. Renders: `tools/dev/harbourshot.gd` (sheets per kind, `HSHOT_HOUR=21`). fidelity.gd: the new props/buildings/infra names, the harbour line from `GenHarbour.waterfront()`, "harbour plan" counted as worker time. Brinehollow: islanddump identical (only the dummies' sack heads, as always).

## 2026-10-12: island fidelity, phase 2 (life: villagers, named characters, quests)
- `IslandLife` (`scripts/island/island_life.gd`, GenIsland `var life`): planned in prepare from the island's seed (3 named characters from the theme's roles + 8-10 villagers, their looks, their bodies built and stocked there on the worker; every quest kind in a seeded order and how many to give, 2-3). Placed after the sites: one "life" step (spots, routines, talk, quests) then 4 people a step. ~8-10 ms main thread for all of it; the bodies add ~1.5-2 s to the worker's "bodies". An island with no village spots gets no people and no quests (the stocked bodies are let go; also when the island goes before its people are made, on IslandLife's predelete).
- Spots (`Island.life_spots`, the interface for the other kit pieces): `{"kind", "at", "face", "hub", "lane"?, "y"?}` for work and gathering (plaza, inn, home, market, nets, forage, dock, boats, stall, or any new kind), `{"kind", "at", "poi": true, "name", "r"?, "clear"?: Callable, "verb"?}` for places worth a quest. Fed spots win: any fed village spot replaces everything derived from today's IslandVillage (plaza, stall customers, the inn's door, hut fronts, GenHarbour.spots on dry land, forage points along the paths to the ruins and summit); a fed POI kind replaces the derived one of that kind (camp, lair, ruins, lookout, beast from `sites`). Each hub (a hamlet's plaza) gets its share of the people; a villager keeps to its hub's spots and falls back plaza, then anything in the hub.
- Routines (`Villager`, `scripts/island/kit/villager.gd`, an NPC; data in KitLife: `lane_in`, `to_ring`, `lane_along`, `walk`, `measure`, `sample`, `stay_at`): work ~6:00, lunch (plaza/market) ~12:00, work ~13:30, evening at the inn or the plaza ~18:00, home ~22:00 (hidden indoors, no collider or talk) unless a night owl (named ones always are: findable). A walk is the spot's lane in to its hub's ring (KitLife.HUB_R 6 m round the plaza's middle), round the ring, the other lane out; lanes turn aside from IslandVillage.taken. Where a villager is is a function of `Weather.hour()` (world time: the same on every screen, so co-op needs no messages); talking holds it and it catches up at 1.8x along its route. Beyond 70 m from the camera it's updated every 0.3 s, past 150 m hidden. Groups (plaza, inn) stand round the middle facing in and gesture; nets/forage/chores kneel. Ambient lines over the head (Label3D) near the local captain, island-wide every 8 s at most, from the theme's pool by time of day and spot kind, plus pointers to the quest givers.
- Named characters: a dialogue tree each (`isle<id>_<seed>_talk<i>`): intro and personal lines from their role, rumours about this island's POIs (by kind, `{name}` filled: the camp's captain, the beast's name), the islands ahead (the chain: one, a fork, or the sea's end), their quests. Pools: `LifePools` (`kit/life_pools.gd`), a table per theme (jungle only).
- Quests (`KitQuests`, `kit/kit_quests.gd`, the island's "Quests" node): lost (a sack to pick up near a POI, glinting while you're after it), scout (reach a point at/near a POI; the lookout's on its platform), deliver (a parcel to another named character), fetch (2 treasure / 3 rum / 3 fish), clear (a POI with a "clear" Callable: for the fauna and boss agents' roosts and roaming beasts). Each captain's own, like the job board: Dialogue flags `isle<id>_<seed>_q<n>_taken/_got/_paid` (the island's seed in the key, so they don't repeat across chain seeds), saved with the flags; rewards gold (by tier) and XP on the captain's own machine. `IslandLife.add_quest(kind, ...)` adds one later.
- fidelity (seeds 777, 31337, 4242): NPCs 6 -> 18-19 (Brinehollow 19), with dialogue trees 1 -> 4 (8), on routes 0 -> 12-13 (4), character surfaces ~160 -> ~470. fidelity.gd counts a Villager as on a route.
- lifetest (new suite): 15-20 people, unique names, routines (day vs night, the evening at the inn/plaza, home at 2:00, walking just after a stay starts, a walker moving 2.6 m in 2 s on the ground), indoors at night, named characters' trees and rumours, ambient lines, every quest kind taken/done/paid (a fake bat roost for clear), kept in the save, the same plan from the same seed, no people on an island with no village or only POIs, two hamlets sharing the people, bodies prebuilt and let go. nettest chain: the guest's villagers' routines (where at 10:00 and 21:00) and quests match the host's. Brinehollow: islanddump identical (dummies only).

## 2026-10-12: caves, small dungeons and the ruined temple (generated islands' interiors)
- Phase 2 interiors. Every generated island plans 1-3 caves (50/38/12%, no kind twice) from a pool of 7 and the ruined temple on ~40%; seeded from the island (`hash([seed, 7177])`), so guests build the same ones. Plan as data in `GenIsland.prepare` (worker, one call after `_define_paths`: `interiors = KitDungeons.plan(self)`), built in steps appended to `IslandContent.steps` (shell, dressing, population per cave; build + populate for the temple).
- Kinds (KitDungeons.SHAPES/LOOK/BOSS): bug_tunnels (egg sacs, fungus, lichen, spitters from the roof, the brood mother as boss, her hoard on victory once per character), smugglers_grotto (crew round a fire, contraband, wall torches, a named Boss and his chest + tricorn), flooded_ruin (brick vaults, cobbles, standing water, pillars, glowing glyphs, scavengers and a Digmaster, the chest on an altar), root_cavern (a giant tree on the rock, roots through the roof, bugs, an end nest of big ones), bat_roost (tall rooms, guano, dark clusters under the roof, spitters as stand-in bats), sunken_shrine (small drowned shrine, Divers), beast_den (bones, a ribcage, claw marks, a branch nest held by big bugs). 2-5 rooms (an extra middle room 35%, side rooms by kind).
- Placement: `site_clear` (KEEP distances from village 105, dock 90, camp/lair/ruins/boss/summit; relaxed to 0.62x only if nothing fits) and `land_clear` (dry land, off paths and site ground); room floors over the highest ground under them, tunnels in 4 m steps over the ground, max slope 0.6. Reserves the footprint and adds a path from the mouth to the nearest path (`path_to`). The mouth faces the village give or take.
- CaveMesher (new): rooms (domes, flat floors) and tunnel segments as distance fields hollowed out of a hull (smooth union, crag noise, extruded down into the ground), meshed by surface nets at 1.5 m: flat facets, projected UVs, floor/wall inside, turf/moss/rock outside, collider faces (trimesh), ledges for plants (MultiMesh), `ceiling` and `wall` for things hung from the roof or fixed to walls. Shapes filtered per grid column. Plan 0.3-2.3 s per island on the worker (most of it the mesh); main thread ~20-30 ms per cave step, ~50 ms for the temple's build.
- KitTemple: a platform with stairs (a ramp collider), carved door panel, guardian statues; hall of pillars with a fallen-in roof corner (bugs), two shrines each with a lever (raiders), a sanctum behind a bronze gate that sinks once both levers are pulled (the Warden, level +1, and two guards, the hoard on the altar under an oculus, tier+1 loot). Box colliders.
- Dungeon (runtime node): banner at the mouth; enemies (`Enemies` holder: PROCESS_MODE_DISABLED) and lights asleep while no captain is within radius + 70 m (only once crews have mustered); boss modes queen (BroodCave's fight logic: wakes inside the end room, resets 6 s after it empties, top boss bar, respawn 15 min), captain (camp captain; top bar while fighting in the end room) and nest; the Dialogue flag `isle<id>_<name>_cleared` on victory. Co-op: `net_spawner` with gen [boss_gen, gate_mask]; a guest's lever pull goes to the host through `Net.forward(self, "net_pull")` ("net_pull" added to Net.HOST_CALLS).
- Data for others: `isl.interiors`, `KitDungeons.poi(e)`: kind, name, title, at, radius, mouth, mouth_dir, level, reward key, flag, chambers [{role, c, y, r, h, slots {floor, roof}}] (island space), boss_slot, boss, enemies node path.
- Lights: up to 3 OmniLights per cave, 4 in the temple (KitContext budget of their own, distance-faded, asleep with the dungeon); the rest is glow materials.
- Brinehollow unchanged (islanddump: only the dummies' unseeded sack heads differ). fidelity (777/31337/4242): interiors 0 -> 2, landmarks 4 -> 6, POIs 6 -> 8 (before the pool grew).
- Tools: `tools/dev/dungeonshot.gd` (render sheets per chain seed; `list <from> <to>` prints what each seed rolls), fidelity.gd counts Dungeon/Temple as interiors and landmarks and their mouths as POIs. Test: dungeontest (new). isletest's path count is now >= 6.
## 2026-10-12: island fidelity, phase 2 (villages: a pool of layouts)
- A generated island's village is now one of a seeded pool (`scripts/island/village_layouts.gd`, VillageLayouts.POOL, weights town 3, hamlets 2, post 2, stilts 2, ruins 1): **town** (plaza with fire, well, benches, bunting; a 4-stall market off it; up to 3 lanes cut into the jungle and added to `paths`; houses along every street; a shrine at the longest lane's end), **hamlets** (a small hub with the services and a 2-stall market, then 2-3 hamlets 70-150 m out along the paths: fishers' racks and canoes, farmers' plots and granary, woodcutters' workshop and woodpiles), **post** (a walled trading post: sharpened-log palisade r 29 with a gate wherever a road comes in, three watchtowers, the market in the middle, storehouses round the wall, huts outside the main gate), **stilts** (a deck 2.6 m over the plaza with the fire on it, ramps down along the roads, walkways out to a ring of houses on tall stilts, lanes of stilt huts beyond), **ruins** (the old village roofless and overgrown, broken cobbles, scuttlebug burrows in its plaza, 1-3 caches `village_cache_N`; the survivors and every service in a hamlet nearer the shore).
- Every layout has the inn (rest), a walk-in trader's store and cookhouse (KitHouses.room; keepers behind the counter at floor height), the elder's house, the job board, the elder and villagers. Services move further out until they fit; a missing one is a loud error, never a silent skip.
- The plan is data in GenIsland.prepare (worker): its own occupancy (`occ`, a building = body + apron circle), per-item seeds (Brinehollow's bunting/laundry/garden/wares keep their shared streams; generated items each seed their own rng), reserves made at the end so the jungle stands right up to the clearing. Built in finish steps: village (inn, people), shops, houses x3 a step, walls / walks / ruins, market + bunting, dressing x20 a step, cargo (one MultiMesh per kind, one collider body), paving (cobbles + trodden earth in front of doors).
- New kit file KitHouses (rooms with interiors, workshop, shrine, storehouse, well, tiki torch, woodpile, ruin, rubble, walkway, ramp, deck, palisade, gate, cargo meshes). KitVillage gained the data planners and builders; KitPaving.build takes a texture (trodden earth). Buildings.house and rooms take `steps: false` (a walkway meets the porch). Brinehollow's islanddump is unchanged.
- For villagers (the life work): IslandVillage.layout, plaza {c, r, y}, streets, lanes, hamlets, buildings {kind, node, p, face, door, enterable, floor_y, inside}, work_spots {kind, at, face, y, taken}, seats, decks, walkways. Raised spots carry their y (NPC.ground_func would pull a wanderer off a deck).
- fidelity.gd counts the new names (Home/Shop interiors, Workshop, Shrine, Storehouse, Ruin buildings; Torch, Jar, Basket, Sack, Woodpile, Rubble props; each instance of a prop-named MultiMesh). FID_KIT and KitVillage.dress_generated_village are gone (the real village replaced them). Renders: `villageshot.gd`. Tests: `villagetest` (every layout), isletest stands its captain on the road in.
## 2026-10-12: island fidelity phase 2, landmarks and set pieces
- `KitLandmarks.plan_gen` (one call in GenIsland.prepare, after `_define_paths`) plans a generated island's places on the worker: picks ground, levels or digs it by editing `heights` in place (`level`/`shape`, before `_terrain_arrays`, so mesh, colliders and shallows agree), reserves each footprint (`keep` discs), runs a trail from the nearest path (appended after the 6 main paths, so `paths[0]` stays the road), and fills `Island.places` ({kind, role, at, r, keep (island space), door, y, yaw, k, seed} + the piece's numbers) for phase 3. Steps appended to IslandContent.steps; every place ends with `overgrow` (the theme's bushes/ferns/grass/young trees round its footprint, MultiMeshes).
- Pools: landmarks (KitLandmarks: waterfall, wreck, great_tree, temple; KitWilds: watchtower, sky_wreck, totem_grove, hermit_hut, mine, aqueduct, gorge_bridge); the chain (`KitSetPieces.assign`, its own rng from the chain seed, after `_build`) gives each node `landmarks` (order), `landmark_count` (weighted 1-6) and `setpiece` (sunken_village, volcano_vent, giant_skeleton, fallen_colossus, sea_arch, hot_springs, cenote, giant_nest, crystal_grove, old_fort): never twice down a route, the least used first across the sea.
- Canopy: `KitLandmarks.canopy(theme)` = the theme meshes' tallest top x 1.55 (the scatter's biggest scale); the great tree, temple (node scale), falls, nest spire, crystal spire and summit tower (`summit_h`, two flights over 8 m, clearing max(18, canopy x 1.2)) grow with it.
- Inland water: `Ocean.surface_at` (waves, or the highest InlandPool covering the point) replaces get_wave_height for player.water_surface, grunts' `_surface`, ragdolls, the camera and non-calm depth_at. The wave table and shader are untouched. Ladders now climb from the ground at their foot (they only worked from water or the head: the lookout towers' were unclimbable).
- Brinehollow: islanddump identical apart from the known dummy sack heads. Renders: `tools/dev/landmarkshot.gd` (env LSHOT_PIECE / LSHOT_MARKS force the set piece and landmarks), sheets in tools/dev/out/landmarks/. Suite: landmarktest.

## 2026-10-12: jungle bosses (the Silverback in the trees, the boss pool, minibosses, the roamer)
- BeastPool (scripts/enemies/beasts/beast_pool.gd): Chain._build ends with BeastPool.assign, which writes into every chain node "beast", "beast_look" (variant), "beast_name", "minis", "roamer" from its own rng (chain seed + 70411; the chain's own stream is untouched). Rule: never the boss of the nearest same-theme island behind it on any route (walking the next links back), nor its fork's other side's; else an even pick. Jungle pool: ape, serpent, stalker, mantis. A pool of one repeats. stock_looks(n): GenIsland.prepare pre-builds the ape body only when the island's beast is the ape. pois(isl): [{kind boss/miniboss/roamer, beast, name, at (island space), pos (world), radius}] for quests; roamer_of(isl) is the roamer live.
- BeastArena: generic over the kind. The floor (FLOOR_R 19) under a closed canopy: TREES 9 giants at RING_R ~25 (23-29 m tall, buttress fins, a level inward limb = the perch, two more limbs, vines; trunk cylinder colliders; a grapple point on each perch), crowns as their own MeshInstances (3 shared crown meshes reaching in over the floor, fringe cards and vines under them) so shake(i, k) can rock one; brush clumps (MultiMesh) round the floor's edge (arena.brush); roots, stones, a fallen giant; per-kind dressing (ape: boulders + nest; serpent: shed skins; stalker: claw marks, a ribcage; mantis: egg cases). A gap where the path comes in. _ground() returns the centre, floor and ring spots: the one place to swap for the theme's canopy-arena request. Its dressing uses its own rng (seed + 7701), not IslandContent's stream (so the village after it rolls differently than before). rebuild(gi, kind) for tests and tools. The hoard gets boss.trophy(t).
- Silverback (jungle_ape.gd): from phase 2 (cooldown 30 s, 22 enraged) "climb": crouch, bound onto the nearest limb (collider off, hurtbox off, hidden); "prowl": limb to limb round the ring (HOP 1.5/1.1 s), leaves and a rustle every 0.42 s where it is, the crown shaken where it lands, grunts, a 35% glimpse (ape_perch, hurtbox on); THROWS 3/4 boulders from wherever it is (shows itself, the branch thrashes, a ring where it lands); then "drop": rears up on the limb (ape_beat), roar, a DROP_R 6.2 ring on you, dives (ape_dive), 34 knockdown, 1.4 s opening. Hits while it shows itself (3.5% of its health, or Haki) knock it out of the tree: it falls, "Knocked down!", 3 s stun. Co-op: net_pack adds up + visible (puppets mirror visibility and hurtbox), events shake/say/rustle. New poses ape_perch, ape_dive (played with explicit lengths: no ActionSpecs entries).
- JungleBeast (jungle_beast.gd): base for the non-human beasts. Host brain (SLEEP/FIGHT/STAGGER/RETURN/DEAD, move + mv_t, cooldowns tick faster by phase, mv_t < 0 = the opening after a move); puppets interpolate position/yaw and read state/move/mv_t to animate. strike(shape) judged on each captain's machine (BeastShapes: ring, ball, cone, lane; a jump clears it), warn_ring/warn_lane (BeastFX.lane: a strip filling in), say() (BeastFX sounds), shower(), quake(). Poise stagger (not in armoured moves), parried() staggers in _parry_ok windows, phases at _phase_at(). Away from an arena it watches for captains itself (wake_r, leash_r). Dormant (skipped) asleep with nobody within 110 m.
- Strangler (strangler.gd, "serpent"): 18 bones x 1.45 m, a skinned body like the Sea King's following the head over the ground (3 ground rays a tick, round robin); strike (lane, parryable, twice enraged), sweep (tail ring), coil (a ring round you, closing over 2.3 s), ambush (into the brush, hidden, brush to brush, bursts out along a lane), tree (spiral up a giant, drops on a ring, stunned 1.8 s), spit (venom fan). Hurtbox: head + 5 body balls. 3 skins.
- QuadBeast (quad_beast.gd): rigid four-legged rig from a spec (hip height, length, girths, neck, head, snout, tail, coat), trot/gallop by speed, pose keys crouch/rear/head/jaw/stretch/tail; eyes_only() for hiding.
- Shade (stalker.gd, "stalker"): black panther / jaguar / clouded grey; roar (shockwave), claws (3 cones, the 3rd parryable), pounce (crouch, eyes flare, ring, leap; a miss = a stumble), lash (spin ring), stalk (phase 2+: eyes only in the brush, brush to brush, decoy thrashing enraged, out in a pounce).
- Mantis Queen (mantis_queen.gd, "mantis"): leaf / orchid / dead-leaf; display (wings flared, screech ring), scythe (2 cones, the 2nd parryable), snap (lane lunge), flit (up onto a limb, still, a dive along a lane), whirl (phase 3: 3 ring cuts while spinning).
- Minibosses and the roamer (BeastDens, IslandContent step "beasts"): the alpha boar (alpha_boar.gd: charge lane, gore cone parryable, stomp ring below half; its name over its head) at the ruins; the Thornback (behemoth.gd, extends the boar: 1800 hp, bigger numbers, bellows) grazing between its range's middle, the ruins, the lair and the summit ("Roamer" under the island). They don't respawn.
- Sounds: tools/texture_gen/gen_beast_audio.py (reuses gen_psx_audio's helpers): beast_leaves, branch, grunt, hiss, slither, snarl, catroar, screech, click, squeal, bellow.
- Tests: bosstest (new), apetest (rebuilds its arena as the ape; the canopy sequence). nettest's chain report compares the beast kind. Tool: bossshot.gd.

## 2026-10-12: the daggers (one dagger, two daggers, sword + dagger)
- Zach's to-do: a dagger item at every tier, the single- and dual-dagger movesets with their own trees, the off-hand dagger in sword + dagger made real. Feel: quick, close, evasive, crits and bleeds. Mid-round pick: **an off-hand dagger is held reversed** (blade down out of the bottom of the fist, edge out) in every set; the main hand keeps the normal grip (both reversed was rendered too, tools/dev/out/combat/daggers/grip/both_reversed_*: the dual set read as two identical fists, and the main-hand stab lost its reach, so normal + reversed).
- Item: WeaponDesigns kind "dagger" (base item resources/items/dagger.tres "Sailor's Dirk", x0.9) and five designs: Stiletto (needle, ring guard), Kris (wavy: `_blade`'s new `wave` zigzags the segments), Kukri (bent forward, wide at the tip), Main Gauche (shell guard), Sharktooth Knife (bone grip, teeth along the edge). Tiers as every weapon. A dagger hangs on its hip in a sheath (`WeaponDesigns.dagger_sheath`, made per weapon by `Humanoid._build_sockets`; it stays when the dagger's drawn). Sold at Vey's (dirk, stiletto, main gauche, kukri@1); in wreck and pirate-ship loot. (Not in `IslandContent.LOOT_WEAPONS`: that file is the island agents'; add "dagger" there when it lands.)
- Styles: Player.style() "dagger" (one), "dual_dagger" (dagger + dagger: its own set and tree), dagger + another blade stays "dual_sword" (the off-hand dagger numbers from LightAttackState.OFFHAND). `Humanoid.REVERSE_GRIP` on an off-hand dagger; `DaggerMoves.rev(arm, fore, theta)` keys its wrist.
- Wounds (PowerComponent._wounds, scripts/combat/bleed_status.gd): HitData meta "bleed" (s) opens a bleeding wound (2.5 + 15% of the hit a second, deepening up to x3 with more wounds; blood through Net.fx), or by chance (tree stat `bleed_`, always under Bleeding Edge). `backstab_`: a hit from behind the target's facing deals that share again ("Backstab!", `PowerComponent.behind`). `evade_`: slips a blow (Instinct's roll, per weapon tree). Sure crits: damage x1.5 + meta "crit".
- One dagger (DaggerMoves, tree "dagger": crimson night): combo dg_stab 7 / dg_slash 7 / dg_rise 9 (0.4-0.45 s, chain 0.26-0.3) and Gutting Strike (move, dg_gut: a heel turn into a low stab, 15, bleeds). Heavy Shadow Lunge (dg_shadow 0.75 s): sunk low, untouchable, then out from behind the one in front within 5.5 m with the blade in their back (26, bleeds; a short dash on with nobody there). Jump attack Fang Dive (move, the Boarding Dive's flight: a sure crit that bleeds). Techniques: Slip (guard: the blow slips past, you're behind them, a sure crit that bleeds; COUNTER_POSE "dagger"), Cutthroat (blink behind within 8 m, 30 sure crit, bleeds, unblockable), Knife Fan (five knives across a 10 m fan, 12 each, bleeding), ult Red Eclipse (vanish, out from behind up to six in turn with a mark each, back in sight with your back to them, then every wound opens: 38, crumple, bleeds 6 s). Root: crit 10%, bleed 15%, backstab 50%.
- Two daggers (tree "dual_dagger": venom green): dd_1 slash 6 / dd_2 reversed hammer-stab 6 / dd_3 scissor 11 (0.38-0.48 s, chain 0.24-0.32) and Fang Whirl (move, dd_4: a whirl into both driven in, 17, bleeds). Heavy Scissor Rip (dd_heavy: both in 14, ripped apart 22, bleeds). Jump attack Knife Rain (move: a fistful of knives at up to four below, 12 each, bleeding). Techniques: Viper Flurry (eight stabs on 0.09 s, the rip 14 + bleed), Scissor Leap (leap at the one you face, 28, breaks guards, bleeds), Bleeding Edge (8 s: every hit bleeds, +20% crit), ult Hundred Fangs (eight blinks round the one you pick drawing a star {8/3} of streaks, 7 to everyone close each time, then the star bursts: 38, knocked flat, bleeding). Root: crit 8%, bleed 20%, backstab 35%.
- Trees: 25 nodes each with the usual shape (moveset left, skills up the middle, crit/bleed/backstab/leech right, the mastery pair: Nightfall / Blood Moon, Viper's Kiss / Serpent's Coil). Techniques live in scripts/player_states/dagger_arts.gd (DaggerArts: TechniqueState `_arts` hands ids to it). The skill map's tabs now size to fit (11 now).
- FX: TREE_FX "dagger" / "dual_dagger", FX.TWIN_TREES (off-hand trails in the accent), FX.shadow_wisps (SHADOW_SMOKE + crimson motes), element/elem_hit branches (venom: poison bubbles + green motes). Icons: gen_psx_textures.py techniques (slip, cutthroat, knife_fan, red_eclipse, viper_flurry, scissor_leap, bleeding_edge, hundred_fangs).
- Combo damage per second (daggertest): cutlass 24.4, dagger 27.4 (4 hits 28.4), twin daggers 28.8 (30.3), axe 36.0; the daggers' crits, bleeds and backstabs come on top.
- Renders: tools/dev/out/combat/daggers/ (ws_* designs/tiers/icons, sh_* sheathed, anim_* contact sheets, grip/* the reverse grip and the comparison, ab_* Red Eclipse, Hundred Fangs, the heavy, the twin combo). Tools: weaponshot WS_KINDS, sheathshot SS_WORN (a+b pairs), handshot HS_HELD + a front-left view, abilityshot styles dagger / dual_dagger / sword_dagger, ActionSpecs dual_2 renders a dagger off-hand row.
- Tests: daggertest (new): items at every tier, sheath, styles and the reverse grip, trees and element, each combo hit, Gutting Strike's wound bleeding on, backstab vs front, Shadow Lunge out from behind, Fang Dive, the twin combo, Fang Whirl gated, Scissor Rip, Knife Rain, sword + dagger's backhand, Bleeding Edge. techtest: the six dagger techniques and Slip; each guard answer gets a fresh grunt (five answers killed the first).

## 2026-10-12: bug pass after the merge (islands)
- Village: the job board searches rings out round the way in until it fits (stilts villages ran out of room: the deck, ramps and walkways); a missing service or board errors at plan time with the island seed and layout. The `_shops` "trade" error was the board crash cascading.
- Set pieces: the giant skeleton's broken ribs (4 points) hung a vine off pts[4].
- Landmarks: `KitLandmarks.canopy` measures the canopy giants at their scatter scale (1.15) and skips the emergents and kapoks that tower over it (canopy ~26 m, canopy_k ~1.7, the summit tower ~21 m; it had read ~50 m). `clear_of(isl, ...)` also keeps places off anything reserved (`GenIsland.reserved_in`: the village's houses, hamlets, streets). The landmark temple's body is `StepPyramid` (fidelity: "step pyramid"; `Temple` is KitTemple's dungeon, "ruined temple").
- Boss arena: `GenIsland._plan_sites` asks for a canopy arena on the boss site (FLOOR_R); its ring giants (kept off paths) are recorded (`arena_ring(c)`), and BeastArena takes its trees from them (base, trunk r, crown top, a perch at 0.7 of the crown's height on the floor side) instead of building its own. Shaking a crown is leaves and a rustle now (the crowns are the vegetation's MultiMesh).
- IslandLife: `_village_spots` reads the village's layout data (plaza with its y, a plaza per hamlet as hubs, work_spots mapped to routine kinds, benches, the inn (on the deck when raised), houses' doors); a lunch break by the benches.
- isletest's lamp check counts the camp's two and the village's planned lamps.
- Tests: isletest villagetest lifetest dungeontest landmarktest bosstest harbourtest watertest r8test progtest chaintest fidelitytest foresttest apetest.

## 2026-10-13: arrow selectors step back
- Zach: the `< value >` selectors only ever went forward. The options' cycle rows (PSX resolution) and the yard's paint rows were one Button whose press always stepped +1 (the yard had a hidden right-click back); the creator had separate `<` `>` buttons that left / right on a keyboard or pad never reached.
- `UIStyle.stepper(min_width)`: one button with a "stepped"(d) user signal: its left half, right-click or ui_left step -1, its right half, ui_right or ui_accept +1 (it accepts the event, so left / right don't move focus). The listener wraps with posmod. `UIStyle.stepper_text(v)` draws `<  v  >`. Used by GameMenu._cycle_row (button named after its settings key), the yard's looks and the creator's `_cycle` rows (named after the look key).
- invtest: the PSX resolution selector clicked on its left half and sent ui_left steps back twice (wrapping at 0), then its right half returns it.

## 2026-10-13: inventory refresh
- Zach: an equipped weapon still showed in the bag (confusing); wanted a cleaner, less wordy, crisper inventory with hover feel, tooltips with stats and compare.
- Held items: the data model is unchanged (weapons in hand and quick-slot consumables stay in `InventoryComponent.items`, so saves, the grave, co-op and `check_equipped` are untouched). `InventoryComponent.in_hands` (Player keeps it in `_hands_changed()` from equip_weapon / unequip_weapon / set_offhand) plus the hotbar ids mark stacks as held: `held_mask()`, `bag_view()` (the bag positions the grid shows), `used_slots()`. Held stacks take no bag space: `has_room`, `room_for` and `add_item` count `used_slots()`. Weapons match by id, the off hand takes the second stack of the same id. Putting a weapon away (click its slot or drag it to the bag) needs room; clearing a quick slot may overflow the grid by a row (it grows).
- Crisp pixels: InventoryScreen draws into a SubViewport (`_fit_canvas`): the canvas is the window divided by k = floor(height / 360) and shown k times larger from the corner (SubViewportContainer stretch_shrink k, scaled back out of the 800x450 canvas_items stretch). 1280x720 and 1920x1080 are both a 640x360 canvas, 1600x900 is 800x450. Pixelify 12 / 16 and Silkscreen 8 render at native size, nearest-scaled by a whole number. `_layout()` places everything from the canvas size (doll columns at the captain's centre +- 0.235 H, panel 304 wide on the right); the captain's showcase x comes from it.
- Layout: name + LV/DEF/DMG over the captain; ten gear slots in two columns (empty ones show a dim tag: HEAD, BODY...), MAIN / OFF hand slots under the feet; the panel: INVENTORY / CHARACTER tabs and carried gold, the 5x4 bag, QUICK 5-7, the details card. A hint bar at the bottom shows the hovered thing's keys (LMB EQUIP, RMB OFF HAND, X DROP, F TAKE ALL, TAB CLOSE); refusals flash there for 2.5 s. The old footer and paragraphs are gone; the ship's chest counts moved to the character sheet.
- Details card = the selected item (`_sel`: focus or click, followed wherever it goes via `_locate`: IN HAND / OFF HAND / WORN / QUICK SLOT tags). Tooltip = the hovered item after 0.15 s, beside the cursor but never over the panel. Both from `_fill_info`: name in tier colour, tier + kind, DAMAGE (average light hit or a shot x power) / SPEED (hits a second as FAST/QUICK/STEADY/SLOW) / RANGE / DEFENSE / HEALS / WORTH with arrows (+diff) against the weapon in hand or the gear worn in that slot, effects (heavy move, venom, bleed, knockdown, two-handed, the fruit's curse), the description (3 lines max). `weapon_stats(it)` reads LightAttackState.STYLES / ShootState.
- Feel: slots (`InventoryScreen.Slot`) glow and lift their icon 1 px on hover, the icon pops (scale 1.4, elastic tilt) where an item lands (drop, equip, take off, take, quick slot), the drag preview pops in tilted and the source dims; panel / doll / loot window drift 1-3 px against the mouse (whole pixels); open slides the panel in with a back ease and pops the doll slots in turn; close fades in 0.09 s (GameMenu.close keeps the root up for it). GameMenu.make_slot / set_slot are gone (only the inventory used them).
- Tests: invtest (weapon in hand / quick-slot rum not in the bag grid and back when put away / cleared; held stacks take no space; the tooltip shows a katana's name, DAMAGE value, SPEED, WORTH and a compare arrow), r7test, feat, savetest. Renders: `invshot_real.gd <prefix> [WxH]` (rest, tooltip, drag, character, loot window).
## 2026-10-13: housekeeping (lambda errors, harbour placement, island build steps)
- "Lambda capture at index 0 was freed": NavBaker's async bake callback held its NavigationRegion3D; an island freed before its bake finished (harbourtest, villagetest free theirs) ran the lambda on a freed capture. It finds the region by instance id now. FX.power_aura's holder freed itself from a SceneTreeTimer lambda; a recast frees the old aura early (progtest, r6test), so it's a tween on the holder now (dies with it).
- Harbours on awkward coasts (with the coastlines' shelf and cliffs): the wharf's four warehouses had one try each at a fixed slot (a short or steep shore lost them: 6 buildings), the ruins' huts tried a 6-16 m band only and spent every try on the two big ones first (a shore with no room for those got none of the small ones), the bare landing's canoes and odds tried one spot each and lost them to the dredged fairway by the pier (3 props). Placement fixed, not the check: warehouses try 5 spots sliding toward the pier and up the beach, ruined huts 100 tries with the band growing to ~24 m and the big ones given up after 30, the landing pulls its canoes and odds up beside the jetty's root (fidelity's harbour district for a bare landing is the pier's strip) and retries each until it's on dry sand. harbourtest runs each kind on fixed chain seeds 4242 and 777 (it used the run's random seed, so a failure came and went).
- Build steps (GenIsland finish steps, a frame each): village houses one a step (were 3), shops one a step, the palisade in 120-log steps then its rails, each gate set and watchtower its own; the beasts a step each (BeastDens.steps: each miniboss, the roamer); the boss arena's ground and its beast (BeastArena.spawn_boss, no longer in _ready; rebuild spawns it); dungeons shell / rock collider / dripstone / the kind's dressing / walls / outside and lights / population (the dressing's passes share one rng and MeshBuilder in the old order: same caves); fauna zones / spots / creatures in 3 parts / ambient (one rng in order). No rng draw moved, so co-op guests build the same.
- Slowest step per name (fidelity.gd now runs the steps itself and prints each name's slowest; headless, seeds 777/31337/4242/5/1), before -> after: village walls 143 -> 29, dungeons 30-110 -> 11-57, village houses 32-73 -> 18-28, shops 46-66 -> 26-43, beasts 18-20 -> 9-12, fauna 46-75 -> 31-56, boss 18-34 -> 17-22. Left at 46-59: the temple's build step, vegetation colliders (gen_island). In a running world (test logs' "the most N ms") beasts and boss measured 150-220 ms against ~20 headless here: they compete with the next islands' prepare on the worker threads; split, each body is now its own step.
- Tests: harbourtest villagetest dungeontest bosstest apetest faunatest isletest lifetest. faunatest now loads FaunaSpawner/Creature by path (it named them, and a --script compiles before the autoloads they use: it had never run). Once it ran: a creature's drops crashed (Creature._reward handed Net.drop_items an item id where it wants a SaveGame.item_ref, ["id", id]); fixed. Its "ambient life" check failed on one chain seed (2749453084) and passed on the next (not looked into).

## 2026-10-13: smoke test, fixed seeds, physics-tick waits (dev process plan step 1)
- `smoketest` (tools/dev/smoketest.gd): the first islands of chain seeds 1, 12, 36, 9 (seven islands: every village layout and harbour kind, every beast, the temple on six, five set pieces) built the world's way (worker prepare, a step a frame), a captain a second at each village and beast. Fails on a script error (a Logger counts them per seed, and the runner stops on the line), a non-finite transform, a missing service, a beast missing from its arena, or an island not done in 60 s. `-- list <from> <to>` prints each seed's rolls (how the seeds were picked). land.ps1 runs it after its compile check, `-NoTests` too, never carried over the rebase. ~80-105 s under load (prepare is 8-16 s per seed then), not the 30-60 hoped for.
- Fixed seeds: tools/dev/test_kit.gd (no class_name, no autoloads). Every suite calls `seed_of(self)` in `_initialize` (global rng + GameManager.chain_seed, default 4242, prints `SEED n`); isletest, lifetest, harbourtest and fidelitytest loop fixed lists (`seeds_of`); dungeontest keeps its own (its checks are for those rolls). `run_tests.ps1 <suite> -Seed N` passes DRIFTWAKE_SEED (never cached, shared or ledgered); a failure prints its seed and the rerun line; the live suite has `seed`.
- `TK.wait_ticks(n)` / `wait_secs(s)` + `TK.ticking(until)`: grunttest, swimtest, seatest, techtest and vinetest (their flaky.txt checks) wait in physics ticks now, villagetest's frame waits too. flaky.txt entries kept until they've stayed quiet a while.
- The seed-dependent failures:
  - faunatest "ambient life" on 2749453084 (the island's seed, not the chain's, as printed): FaunaSpawner.roll gave 1 island in 125 no butterflies, no fireflies and no flocks. Those now get a flock (no other roll changes); faunatest checks 3000 rolls.
  - isletest "a canopy arena: nothing standing on its floor" (chain seed 36, Viper Island): a rock 11.9 m into a 12 m floor. GenIsland.reserve_area's 5 m grid starts at -r, so on some bearings its outer nodes fall past r and are dropped: gaps at the rim of every clearing (sites, arenas, market, caves, summit). A ring of disks at r - 1.5 closes them (all generated islands' vegetation shifts a little; Brinehollow doesn't use it).
  - isletest "sea cliffs ...along the land's edge" (chain seed 1, Tikal Atoll): a column where the cliff fades into a beach (raise 0.37): its own top is 0.8 m and so is the land behind. The check wanted 1 m behind every column; it now wants the ground behind no lower than the column's top (to 1 m), which still catches a rock with sea or a dip behind it.
  - lifetest "they work at the market...": it wanted a market on every island; it now wants one used when the village gives market spots (not the layout's plan: Tikal Atoll's ruins plan no market yet give market spots, and its people use them). "Day and night most are somewhere else" failed on Mosswater Atoll (chain 37): 4 of 13 keep house (JOBS' "home": home day and night, by design; an owl working the plaza would stay put too); it wanted 70% to move, now more than half ("most"). "At nine in the evening" passes 13/13 there now and prints who isn't at the inn or fire. lifetest runs the routines on chain seeds 1 and 37 too.
  - Found by fixing the seeds: villagetest forces every layout on one island, and 4242's (Mosswater Key) has no open ground 70-150 m out along its paths: "hamlets" built a hub with no hamlets (6 buildings). The game could roll that too, so VillageLayouts._pick now turns a hamlets roll with room for fewer than two hamlets into a town (as ruins without a survivors' spot already did; the hamlet search is `_hamlet_spots` / `_hamlet_picks`, shared). villagetest runs on chain seed 1 (Tikal Atoll, room for all five).
  - savetest "world loaded from the title": each load now waits (up to 60 s) for a captain who wasn't there before plus 5 frames (the save's applied two frames after he registers), not a fixed 3 s.
- Tests: on the final code smoketest (87 s in the test, 122 s wall with five suites running), isletest, lifetest, faunatest, savetest, villagetest pass; earlier in the session harbourtest, dungeontest and every other suite (all now seeded) passed, but for: guntest (an engine crash in MeshBuilder.commit paving a village, once), watertest (grunt's head 0.11 m under a wave, once) and airtest (Boarding Dive, once), each passing on the rerun; foresttest's "its spit hurt the captain" fails every run, with or without the fixed seed (seeds 4242, 777, unseeded): not this change, not looked into.

## 2026-10-13: Grell's den up on a cliff, out of sight of the beach you wake on
- Zach (playtesting): a new game woke you facing the pirate den across open sand, and new players went straight for it. Brinehollow changed on purpose (no islanddump rule).
- The ridge (`StarterIsland.RIDGE`, `_ridge_at`): a rocky spine down the point west of the harbour, 9.5-13 m over the land (only where the ground is dry, so the point's tip falls into the sea as a cliff), a 10 m flank each side, rock splat (`_crag`), Coast columns along its crest (top 0-4 m over it) and every other one on its flanks (`_plan_den`, appended to `coast_cols`, ids 20000+). The wake spot (-53, -163) is 27 m east of its crest; its sight lines to the den's tower, flag, captain's roof and sloop's masthead are all blocked, and Old Pell's on the quay too.
- The den (`DEN` (-160, -152), new land past the north-west beach): a plateau 17 m up (`DEN_TOP`), flat to `_den_r` (24 m round on the climb's side, bitten in and out toward the sea), its face to +6 m; the land kept by `_height_natural` like LAND_KEEP; its sea sides cliffed by Coast.cliffs (`_cliff_allow` no longer spares the den), the landward rim with Coast columns pushed inward (35% skipped, -2.5..+1.5 m over the top). No shelf within 60-90 m of it (deep water for the sloop).
- KitCamps.den is a clifftop hold now (opts to_sea, hoist [root, tip], top, guard): `KitCamps.hoist` (a plank deck out over the drop with rope rails, struts, a gallows with block and hook, a Ladder from its tip) down to their pier at the cliff's foot (`_plan_den` finds the rim and the water along DEN_SEA, drops the Coast columns within 6.5 m of the hoist and the pier's root), the sloop alongside; shacks, tower (`DenTower`), fire, stash, fish rack, nets, an upturned boat, flag relative to the plateau; the old pier guard now stands at the top of the climb (`den_plan["guard"]`). Still 7 crew, the captain, `den_strongbox`, `DenSloop`.
- The climb (`CLIMB`, `climb_pieces()`, `KitCamps.den_climb`): on a circle 33 m round DEN from 46 degrees, six rock slabs (Coast.slab: flat-topped pillars, r 1.3-1.5, tops 2.95 -> 6.7 m, gaps 1.3-1.7 m, 0.75 m up each), an 8 m knife edge (Coast.fin, 0.8 m wide, 6.7 -> 7.1 m), a 2 m gap to the last slab (7.6 m), then a rope ladder 9.5 m up `ClimbHoist` to the top. A stake with a red rag on each slab's outer lip. Its foot (`climb_start()`): the crew's colours, a skull on a pike, two tiki torches (one lit after dark, the 11th NightLight). A flat zone and a band under the climb keep that beach dry at 2 m whatever the coast does. The den path from the training yard goes round the ridge's south end to the foot.
- Story: `Story.target_pos` asks `StarterIsland.guide_to(place, from)`: for the den, the climb's foot, then (within 10 m of it or on a piece) the top of the climb, then (up on the plateau) the den. `place_of("den")` (and the 90 m "beaten near you") is still the den.
- storytest: the den hidden from the wake spot and from Pell (5 rays each to tower, flag, roof, masthead); the marker from Vey -> the climb's foot -> its top -> the den; with the crew dead, a captain driven up it (W, jump 0.8 m before each edge: every slab, the edge, the gap; F and W up the rope ladder onto the hoist; on into the den) and from their pier up the sea hoist's ladder. Passes on seeds 4242, 777, 31337 (Brinehollow's own seed is the world's 42 either way). storytest, foresttest, qoltest, shiptest, isletest, smoketest pass; swimtest failed once under load ("climbed aboard (on deck)" at the harbour ship's ladder, with renders running) and passed alone. Renders: tools/dev/out/den/ (after_1..10: wake to den, the ridge, village, cliff from the sea, the climb's foot, slabs, knife edge, the hoist's top, the den, top-down; before_*).
## 2026-10-13: enemy pass (poison puddles, boss gap closers, the shove's tell, smarter grunts)
- Poison puddles (scripts/combat/poison_puddle.gd, PoisonPuddle): a glob (PoisonGlob, spitters and the brood queen) that hits the ground (normal y > 0.55) leaves a lumpy green pool (bright rim, dark middle, unshaded so it reads in the cave) that spreads in 0.18 s, bubbles, lasts 4.5 s and fades/shrinks over the last 1.2. A captain standing in it (feet within -0.4..0.45 m of it, inside the radius 0.85 x glob size, hurtbox monitorable: jumping or rolling across is safe) gets a 1.2 s dose at the glob's dps, topped up (no new toast) every 0.2 s while there: dot ticks only, no flinch. Max 24 at once. Every screen lands its own glob copy and so its own puddle; each checks only its own captain. A dodging captain no longer stops a glob: it flies on and lands behind (puddle).
- The failing foresttest "its spit hurt the captain": the test's spitter hangs 0.4 m from a tree trunk (VegetationColliders) between it and the captain, and every blob splashed on the trunk. The spitter now spits only with a clear line to your chest; blocked, it swings out on its thread (up to 1 m from under the anchor, 16 spots) to one with a clear shot (the thread leans to follow). Passes on 4242 and 777.
- Gap closers (pressure on a captain who stays at range; tell = wind-up pose + sound + a ground marker, then an opening):
  - Brood Queen, burrow-and-erupt (special "burrow" then "erupt"): with you 9-28 m away and `_burrow_cd` up (7 s into the fight, then 14-17 s, 10-13 in phase 2). She rears and dives head-first (0.8 s, hiss, dust), sinks out of sight (model lowered 0.85 x size, hidden, hurtbox off: `_sunk`, run in `_process` on every screen from the special and its clock), then tunnels at you at 8 m/s (10 in phase 2) for up to 1.8 s leaving a venom-green `ground_crack` trail and rumbling dust; on reaching you (within 0.8 m) she locks: a red `telegraph` ring r 3.4 for 0.85 s (0.75 in phase 2) at your feet; then she bursts out there: 26 unblockable knockdown judged per machine (the "aoe" event: move, roll or jump it), debris, dust ring, roar, shake; 1.5 s wide open before she moves on. Locks where she is if you're over 2.5 m from her when time's up (never teleports to a captain who's left). Moves by hand under the floor (no move_and_slide). Rooting does nothing while she's under.
  - Captains (PirateGrunt `_can_rush`: `captain`; Grell, the chain's captains, wardens) and Morrow: "rush" attack from CHASE at 6.5-15 m with a clear line and a token. Wind-up tracks you for 0.35 s, then locks and lays an amber lane (`FX.lane` -> BeastFX.lane, colour RUSH_COLOR = the heavy's yellow, not red: it can be parried, blocked or dodged) from him to 2.5 m past you, filling over the rest of the wind-up, with the blade's glint; then the run down the lane (hitbox on the whole way, the mask off players so he goes through you), a skid and 0.8 s recover. Head-on into something solid (`_rushed_into_wall`: not a body), or held to under 35% of its speed (snagged on a rail or a post): 1.6 s stagger. It starts only with a clear line at chest and knee height. Hit data `_hit_rush` (kind 3 in `_hit_set()`, so puppets arm the same blow). Light hits interrupt a grunt captain's wind-up; Morrow's armour covers it ("rush" added).
  - Grell's: a shoulder charge (`shoulder_wind`, 0.85 s: left shoulder dropped, blade low behind, trembling; `shoulder_rush` upper body over the run gait) at 13 m/s, 18 x 1.35 (captain) knockdown, cooldown 9-13 s (first 2.5-4.5 s in).
  - Morrow's, Tide Rush: `dash_wind` (0.75 s, x0.8 in phase 3: sunk into a long stance, blade trailed by the hip) then `dash_cut` at 24 m/s, 22 damage no knockdown, lane 1.6 m wide, cooldown 9-12 s / 7-9 (phase 2) / 5.5-7 (phase 3).
- The rifleman's shove: it landed at 0.33 s, while the "shove" pose was still drawing back (hard to see coming). Now 0.95 s: drawn back by 0.27 s and held trembling to 0.51, the drive at 0.59; the blow at SHOVE_HIT 0.56. Tells: a "clack" and FX.arc_warn at the start (a pale warm-white 100-degree fan, 3 m, the rim at once and the fill sweeping out to it by the blow; new primitive, also the low sweep's), a glint and blip on the rifle butt at 0.28 s. Not red: it can be blocked, parried or rolled. guntest checks the arc, glint and pose are up before the blow, no damage during them, the blow past 0.5 s.
- Found filming the burrow (enemyshot): a captain knocked down by the eruption had their ragdoll spawn inside her body's capsule (r 0.92 x 4.2 m) and the depenetration flung it out through the cave roof. Her collider is now off while she's under and for 0.8 s after she bursts out (`_buried()`, on every screen: the guest's own ragdoll meets the puppet's), and she comes up on the floor, not 0.3 m above it.
- Grunts (PirateGrunt._choose_attack, weighted, the last move x0.3): combo 3, flurry 1.3 (one 0.5 s wind-up with the glint, two quick swings 0.08 s apart, 0.85 s recover), feint 1.0 (wind_r 0.42 s with no glint breaks off into a half sidestep and wind_l 0.36 s with the glint, then swing_l: a parry timed on the fake whiffs, the glint is the honest tell), sweep 1.0 (`sweep_wind` 0.62 s dropped onto the back knee with the blade low behind the hip, a glint, an arc_warn fan 2.6 m / 2.4 rad; `sweep` cuts flat at the shins: the swing hitbox drops to 0.75 m high (`_low_hitbox`, puppets too), 10 knockdown; jump, roll, block or parry it; 0.8 s recover), lunge 3.6 from 2.9 m, the peril chop as before (40% when ready). After an attack a swordsman within 3.5 m backs off for 0.7-1.2 s 35% of the time (elites backstep-dash). Waiting for a turn while crewmates are on the same captain (within 8 m), a grunt strafes (x1.35) round to 1.9 rad off the captain's facing: the side or back (`_flank_side`). Guard, parry, stagger and knockdown rules unchanged.
- Elite dash (new state DASH = 21): `elite()` = captain, cfg "elite" (Redtide's gate guards and rifleman, Morrow's crew over the wall), level >= ELITE_LEVEL 12, Morrow. From ALERT/CHASE/CIRCLE/CLOSE/BLOCK/KEEP/REPOSITION (or RECOVER after 0.25 s) it watches its captain: a HeavyAttack within 5 m facing it (reacts in 0.06 s: side 60%, else back), a charging Iai within 11 m pointed at it (0.3 s: sideways out of the line), a player Projectile/Fireball (new group "projectiles") on course within 9 m (at once: out of the line). Per threat it rolls once (`_dodge_chance` 0.7), cooldown 4-6 s. The dash is the player's: 13 m/s x (1.4 - 1.1u) for 0.3 s, `dash` pose with `dash_dir` (synced), dust, whoosh and an afterimage; hits ignored and the hurtbox off for the first 0.22 s (every screen, by state and its clock). It picks the other side or a backstep when the way is sea, fire or a wall. Out of a dodged heavy or draw it attacks again at once (cooldown 0).
- Tests: foresttest (puddle, burrow, Grell's charge), r8test (Tide Rush lands / misses), guntest (shove tell), grunttest (the crew mixes attacks; a plain grunt doesn't dash from a heavy, an elite does and the heavy whiffs, cooldown; sweep's arc and low cut; the feint's glint only on the real one); they wait in physics ticks. Render: tools/dev/enemyshot.gd (`[out] [scenes]`: shove, sweep, feint, dash, grell, morrow, queen, puddle; strips from behind the captain into tools/dev/out/enemies/).
## 2026-10-13: the site for v1.10 (key art, GIFs, news, release notes)
- Zach: livelier photos of what's new since 1.9, a few GIFs, warmer marketing copy, the Windows download first (the browser a small secondary link with its limits), a /news/ blog and a /releases/ page. Written as the v1.10 site ("The Living Isles", dated October 13: both to confirm when it's cut).
- tools/dev/siteshot.gd: `_isle(cfg)` builds the first chain island for a seed with VillageLayouts.force / GenHarbour.force / KitDungeons.force_temple set (MAIN stilts + stilts, POST post + cove, TOWN town + wharf + temple), only when the cfg changes. Gotcha: the world starts the chain's first island on load (chain_at -1 counts as set), so `_isle` waits for chain_ready before freeing it, or the forces miss it; it applies the chain with chain_since far ahead so the log pose never sets (the shots jump the clock and the islands ahead would build). Shots: hero, jungle (thickest trail spots by undergrowth_at), stilts, harbour/cove, cliffs (tallest coast column), shelf, canopy (the ape's climb), beasts (BeastArena.rebuild: Strangler, Shade, orchid Mantis Queen), fauna, daggers (Hundred Fangs, Red Eclipse, Shadow Lunge at the island's camp), post, town at night, cave, temple (levers pulled), Sea King, co-op; broadside, logpose, isle, fight, the old ape and village are gone. NPC name tags off (Settings gameplay/name_tags).
- Clips: `_clip(name, secs)` saves 15 fps frames on the 640x360 grid (nearest) plus a poster; run with `--fixed-fps 30` so game time steps evenly while frames save. `tools/dev/site_gifs.ps1` encodes them (one palette each, no added dither). combo 1.3 MB, fangs 1.8 MB, ape 0.5 MB (15 fps, 256 colours), sail 2.3 MB and walk 2.1 MB (10 fps, 128: the dither and a moving camera make big GIFs).
- Found while filming: the canopy's creatures (toucans, monkeys, bats) sit off their island. FaunaSpawner._add_group passes canopy crowns as `anchor` in island space, but Flyer and Monkey use `anchor` as a world position (fill_slots converts with to_global; _add_group doesn't). On seed 11 the toucans perch at (28, 21, 86) by Brinehollow and the monkeys at (-125, 20, -186), with Greenmaw Rock at x -450..-700. Not fixed (game code); siteshot's bats shot is left out of `all` until it is.
- Site (web/site): index (hero, the v1.10 clips, ten stills, features, download panel, controls), news/index + news/v1-10-the-living-isles/, releases/index (every version, newest first, the GitHub list linked), clips.js (poster first, the GIF once on screen, never with reduced motion, a Play/Pause button), `-640.jpg` copies for phones, absolute paths, a shared top bar. `_redirects` drops /releases. serve_web.ps1 serves .gif as image/gif. Checked in the browser pane at 1280 and 375 wide: no horizontal scroll, clips swap in. No game code changed.

## 2026-10-13: the second wardrobe (23 pieces of clothing and armour)
- New looks (BodyBuilder): hats kettle (steel skullcap, a wide brim sloping down, rivets), fez (tapered felt, a tassel on a cord off the crown), headband (a band round the brow over the hair, knotted at the back), crown (a gold circlet with points and a jewel, over the hair), coif (the hood's loft closer to the head in the mail shirt's material); tops doublet (buttons up the front, a short peplum in cloth sectors) and kimono (crossed lapels laid on the chest with `_surf_z`, the tunic's hanging hem a little longer, wide open sleeves at the wrist: the `fo` rings in _arms); vest-slot jerkin (leather, a lace zig-zag), padded (a quilted jack over the hips in stitched bands, "Padded Jack") and scale (leather with 66 tilted steel scales front and back); coats haori (`_haori`: open_body(0.4), a flat collar band down both edges, two cords in the trim colour, short tails, square sleeves, no lapels or cuffs), duster (the long coat in canvas, a 0.15 collar, tails 0.22 past the knee) and frock (closed P_BODY shell, two rows of brass buttons, trim cuffs, a six-sector skirt hemmed in the trim; belts are skipped under it, they poked through the closed shell); hands bracers (look key `bracers`: a leather loft with three darker straps, bare hands) and long_gloves (`long_gloves`: gloves whose cuff runs to the elbow); legs hakama (`_hakama`: six cloth sectors from the waist to mid-shin over trousers) and leathers (the trousers' material swapped for leather in _legs and _lower_body); feet sandals (the bare foot on a sole slab, an instep strap, an ankle band) and sabatons (boots with a steel toe cap, two lames and an ankle plate; `_boot_top` like boots); belt wide_belt (a 0.11 band from -0.04 with a dark seam and two buckles); accessories necklace (a cord band at the collar from the torso rings, five teeth laid with `_surf_z`), goggles (a strap round the brow, two brass cylinders with glowing sea-green lenses, on the head mesh) and mantle (`mantle_color`: the greatcoat's shoulder cape in the fur texture, clasped in gold).
- `BodyBuilder._surf_z(r, x, back)`: the surface z of a ring at a lateral x along its own profile (a bust or pec bulges past the centre line), for laying flat things on the body off centre. `_forearm_wear` holds everything past the hand (glove cuff / long glove, then vambrace / bracers) for both the NPC and the swappable-hand branches.
- `CharacterLook.OVER_HAIR` (headband, crown): the hair isn't pressed under these (`_hat_cut` INF, `_hair` treats them as no hat) and hairtest skips them in its "hair hides under every hat" check. Lists: HATS/TOPS/VESTS/COATS/LEGS/FEET/BELTS extended; the creator's full lists (tops, legs, belts) now offer doublet, kimono, hakama, leathers and the wide belt; CREATOR_* unchanged.
- Gear: names, descriptions, defense (scale 6, kettle/coif/padded/duster/frock 4, jerkin/leathers/sabatons 3...), STEEL_PIECES (plain names) now also kettle, coif, crown, scale, sabatons; GearIcons has a shape for each, codes `r` red and `i` ivory, the crown's main colour gold. PLUNDER adds kettle, coif, crown, scale, duster, frock, sabatons, mantle. Sela sells the cloth and leather (fez, headband, doublet, kimono, jerkin, padded jack, haori, duster, frock, bracers, long gloves, hakama, leathers, sandals, wide belt, necklace, goggles, mantle), Vey the steel (kettle, coif, scale, sabatons); the crown is plunder only. Pirate grunts' kit now rolls scale or a jerkin, and a kettle helm or coif.
- Checked: qoltest, invtest, chartest, hairtest. Render: tools/dev/wardrobeshot.gd (eight bodies, front and back, `close a b`).

## 2026-10-13: nettest's "the host rides along on its deck"
- Failed under load (aboard false, on floor true; 0.76-1.18 m off): the host captain, left by the camp after reviving the guest, is set on by the respawned wave, and the enemy pass's sweep knocks it down. When the guest's "tp" onto the deck came mid-knockdown, the Downed state pulled the root straight back to the ragdoll on the shore (FOLLOW_GAP), so the host stayed ashore while the ship sailed. nettest_node's "tp" now forces Idle first (as nethost's chain setup does). Two passes in a row with smoketest + shiptest running alongside.

## 2026-10-13: palette and ornate UI
- Zach: drop the navy + gold for cream #F5E8C8, light teal #65C9C0, deep teal #277F89, coral #F17C62, sunflower #F2C45E; menus too square: rounded, gilded pixel frames. Game and site.
- Roles (UIStyle, the site's :root mirrors them): BG #1D5E66 (panels), BG_DARK #143F46 (slots, wells, tracks), BG_LIGHT #22707A (buttons), TEXT cream (6:1 on BG), TEXT_DIM #DACCA8, INK #173338 / INK_DIM on cream (parchment: dialogue, what's new page, LineEdit, tooltips, key caps), ACCENT / BORDER sunflower (4.5:1 on BG), BORDER_DIM #B88A3A, HILITE light teal (hover faces, INK text), DANGER coral (fills; DANGER_TEXT #FFB39E as text), GOOD, DISABLED / TEXT_DISABLED, OUTLINE #0C2427. Tier colours are unchanged (outlined text reads on teal); rarity slots tint BG_DARK toward the tier.
- Frames: `UIStyle.frame_image(fill, rim, kind, glow)` builds the 9-slice pixel by pixel from the depth into a rounded rect (0 outline, rim lit top-left / shaded bottom-right, then an inner line and bevel), cached per key; `frame()` wraps it in a cached StyleBoxTexture (shared: `framed()` copies with its own margins), `panel()` is the ornate kind. KINDS: panel (r 6, 3 px rim, corner caps over the bevel, coral rivets, studs 15-17 px along each edge, a shadow ring; 9-slice margin 20, content at least 7/6 in), plank (buttons), pressed, well (slots), chip (swatches, tracks, key caps); glow = a half-alpha ring of the rim outside (focus, slot hover). Drawn one image pixel per canvas pixel with the nearest filter: crisp in the inventory's SubViewport, and on the 800x450 canvas_items stretch the same uneven-at-1.6x pixels as everything else there. Gotcha: depths below -1 must stay transparent (they fell through to the rim branch and painted gold corners).
- Screens: theme (Button planks, LineEdit, sliders with a round knob, scrollbars, HSeparator line, TooltipPanel parchment), title + loading (teal-to-coral dusk, teal sea, coral ribbon, cream sun), what's new (notes on a parchment page), save slots (Delete / Overwrite via `UIStyle.danger`), inventory (ornate panel; the square ColorRect shadow is gone), tooltip in the tier's rim, key caps cream, fruit confirm coral), creator (ornate preview and options panels, STAGE teal behind the captain, chip swatches with a glow), skill map (plank tabs, sunflower for the open tree with INK text, a coral dot for points, ornate side panel, well bar slots), sea chart (ornate parchment), dialogue (parchment panel, teal name tag), HUD (plate / slots / interact prompt / loot feed, island banner in sunflower). Everything still fits 800x450 (uishots at 1280x720).
- Site: style.css tokens and every rule recoloured; panels, buttons, the nav's download, badges and the clip button use `border-image` on the game's own frames (web/site/img/ui/*.png, written by `tools/dev/webframes.gd` from UIStyle, slice 21 / 5 shown 2x, image-rendering pixelated); images get a gilt 2 px border with 8 px rounding; favicon, theme-color and the browser shell (web/shell/play.html) recoloured. Checked at 1280 and 375 wide (no horizontal scroll).
- Tests: invtest r6test r7test savetest yardtest chartest. Renders: tools/dev/out/palette/ (before_* / after_*: ui, inv, news, yard, appearance; frames_x8.png).

## 2026-10-13: healing (v1.11 track 3)
- Zach: quick-slot food, rum and potions with a short shared cooldown, an eat/drink action you can be hit out of, the heal at its end, slower walk while it plays, mirrored in co-op; tuned so healing is a decision, not spam.
- Player.use_item: `HEAL_CD` 8 s shared, started when a use starts (refused uses emit `quick_refused`: the HUD's quick slots flash coral). The heal lands at `HEAL_AT` 0.82 of the item's use_time. Attacks, parries and jumps are off while it plays (PlayerState.combat_input / wants_jump); walking is x0.5; a roll is allowed but spills it.
- Spilled (`_spill_use`): any non-dot hit that lands (before stagger rules, so Steadfast / Tekkai too), leaving Idle/Move (roll, stagger, knockdown, swim), or another action taking the body. The item is used (taken at the start) and the heal lost, and the cooldown drops to `HEAL_RETRY` 1.5 s. Why: refunding it made a drink free to try in any gap (no read of the enemy needed); losing the item and the heal makes you pick your moment, while the short retry stops a hit from also locking you out for 8 s. "Spilled!" toast and a clack.
- Items (ItemData.use_anim, its prop via Props.provision_mesh): biscuit / sunfruit 15 in 0.6 s (bite, food), snapper / crab claw 22 in 0.7 (bite), boar haunch 32 in 0.85 (bite), rum 30 in 0.75 (swig, bottle), stew 50 in 0.95 (slurp, bowl), new Sea Tonic 55 in 0.9 (tonic, flask; uncorked by the right hand, or with the teeth when it holds a blade). Tonics are sold (Nessa 30, Ida 32, chain traders 28 + 2 x tier), never brewed: the galley restock skips them. Descriptions lost their "Restores N" (the tooltip shows HEALS and TAKES).
- Humanoid: "bite", "swig", "slurp", "tonic" keyed upper-body poses after "eat" (HEAL_ACTIONS: free to look up, the katana's grip hands stand aside, the prop is dropped when the action ends however it ends). Sounds per beat (USE_SOUNDS: crunch, a glug from splash pitched up, the cork's clack). The heal: a sparkle (sea-green for a tonic) and a blip. Co-op: play / stop mirror through net_sync, the prop through HumanoidSync's left-prop model ("food", "bottle", "bowl", "flask"), the heal's effects through Net.fx.
- HUD: quick slots 5-7 carry the shared cooldown pie (no seconds: three numbers in 22 px were clutter), a cream flash when it's up, a coral rim when refused. Inventory tooltips: TAKES 0.75 S under HEALS.
- Tests: healtest (new). Renders: tools/dev/out/v111/heal_* (animsheet of the four actions).
- looptest's "grave where you fell" (58.8 m off under load): GameManager._load_save waits two frames for the world, then loads if `SaveGame.new_game` is false; the test's bunk save in those frames set it false, so a new game loaded that save back and put the captain on the dock spawn. register_player now decides fresh vs load when the captain registers.

## 2026-10-13: crisp UI on every screen (v1.11 track 3)
- Zach: every remaining screen to the inventory's level (crisp text, clean layout, hover feel and tooltips, the new palette and frames), inside 800x450.
- `PixelCanvas` (scripts/ui/pixel_canvas.gd): the inventory's integer-scale SubViewport as a node (canvas = window / k, k = floor(h / 360), shown k times; 1280x720 and 1920x1080 are 640x360). Off screen its viewport is PROCESS_MODE_DISABLED (a hidden screen in it can't eat keys). `PixelCanvas.project(cam, pos, vs)`: a world point onto a canvas. Gotcha: inside a canvas `get_viewport().get_camera_3d()` is null: HUD markers, the objective arrow, compass strip, log pose and the yard camera use `get_tree().root.get_camera_3d()`.
- Hosts: GameMenu (one shared canvas for pause, options, controls, skill map, chart, yard, shop, save slots; hidden while the inventory, which has its own, is up), the HUD (every Control reparented into it at the end of _ready; tests reach nodes through hud fields, not paths), the dialogue box, the emote wheel, the creator. Layout now has to fit 640x360: the pause menu is two columns of planks.
- Skill map: tabs across the full width; under them the tree's name, mastery/level and points, and what the tree is for (its root node's words); hover a node for a tooltip (name, kind, cost/cooldown, what it does, LEARN: n POINTS or why not, OPENS: the nodes after it); the side panel shows the picked node and what it opens; key caps (LMB, 1-4 R, RMB, TAB, K) in the bar.
- Shops (ShopScreen rebuilt): stock and your bag as InventoryScreen slots (price on each stock slot, red when you can't afford it; what they won't buy dimmed; BUYS ... under the bag), the picked item's card (`InventoryScreen.fill_info`, now static, compares "shop" items with what you hold or wear) with PRICE / THEY PAY and Buy / Sell / Sell all, the tooltip after 0.15 s, RMB buys or sells one, results flash in the key-cap bar. API kept: shop_id, buy(entry), sell(it, n).
- Dialogue: parchment page 440 wide, the teal name tag on its edge, choices as planks (the picked one light teal with ink; hover picks, a click confirms through the manager), key caps ESC LEAVE / 1-4 CHOOSE / F GO ON (blinking while waiting). HUD: the interact prompt is a key cap (F / HOLD F) and the words; the boss bar sits in a gilt well, name in sunflower. Sea chart: ink key caps. Yard: tooltips on refits and steppers.
- UIStyle: `key_cap`, `key_hint` (cream for teal, `on_paper` for parchment), `draw_hints` for hand-drawn screens.
- Tests: uitest (new: every canvas 640x360 at 2x; pause, options, controls, skill map + a tooltip, chart, yard, Vey's stall, save slots, inventory, dialogue choice planks, HUD bars and prompt, emote wheel, creator fit), plus invtest r6test r7test progtest qoltest healtest chaintest powertest savetest yardtest storytest chartest emotetest. Renders: tools/dev/out/v111/ui/before_* / after_* (uishots at 1280x720, now with skills_tip, shop_tip, dialogue_choice; hudshot rewritten: everything up at once; creatorshot). uishots hovers through the canvas's own input (never moves the real cursor).
## 2026-10-13: v1.11 jump variations and the double jump
- JumpState.take_off picks the move by ground speed at the press (Move's exit has already cleared `sprinting`): under 1.5 m/s `jump_stand`, over the walk/sprint midpoint `jump_sprint`, else `jump_run`; an air jump plays `double_jump` (the grunts' `flip` is untouched). Poses in the new `scripts/npc/move_poses.gd` (MovePoses, called from `_action_pose` after ApePoses). Each sets `Humanoid._jkind` while it plays and ends itself on touch-down after 0.1 s (a short hop lands inside the take-off).
- Standing: a two-footed gather, everything thrown up (stretch), knees tucked together at the top. Running: a hurdle off the stride, the front knee (whichever leg was ahead in the gait, `_phase`) driving up, back leg folding, arms countering. Sprinting: a long bound, pitched forward with both arms swept back, then the front leg reaching for the ground. Double jump: legs kick down with the arms flung up (the push), then a tucked forward somersault (pivot x, a SPIN_ACTION) that opens with the feet under you; a flat ring of wind and motes under the feet, the jump sound pitched up plus a whoosh.
- Falling: `_jkind` "stand"/"double" draw both knees up together, "sprint" stays in stride; run and walk-offs keep the varied lead-knee fall. Landing: `_land_kind` takes `_jkind` at touch-down; MovePoses.LAND_SECS / `land()` give stand a square two-footed absorb (0.32 s), sprint a shallow stride-through (0.2 s), the double jump a kneeling landing with the free hand down (0.42 s); run and walk-offs keep the staggered one-foot landing. Armed, the weapon arm keeps the air pose's grip (pistols tucked, the katana trailed: the jumps are on `_katana_hands`' hands-off list).
- Co-op: the actions mirror through play(); `grounded` is in humanoid_sync, so a guest's puppet ends and lands them the same way.
- Tests: new movetest (each take-off and its landing in the village, the double jump tipped over mid-flip and upright after); feat/invtest expect `double_jump`. Renders: animsheet `jump_stand,jump_run,jump_sprint,double_jump` in tools/dev/out/v111/moves/.

## 2026-10-13: v1.11 the dash redone
- Only the pose changed: DodgeState's speed curve, 0.3 s, distance and i-frames are as they were (dash suite). The "dash" branch moved out of Humanoid._action_pose into MovePoses._dash: three keyed phases per direction (side / forward / back, summed by `dash_dir` like before, `_scale` and `_lift` averaged): a snap into the push-off ("out" by u 0.12: trail leg driving, body tipped into the move, stretched along it), the travel (u 0.42), the plant ("out" to u 0.66: the lead knee takes it and the body rocks back past upright, arms swinging on through: the follow-through), then back to the stance. Forward: a low lunge with the arms swept back, then the back foot comes under and the arms swing forward. Backstep: the rear leg reaches, arms forward, then the chest pitches on forward over the planted foot. Spec "sharp" 50 so the push lands within its 36 ms.
- Arms (MovePoses._dash_arms) as before: armed keeps the guard's weapon hand (pistols tucked, katana trailed), the free hand reaching or flung out (and swinging a little further on the plant); unarmed, the lead hand reaches out on a sidestep.
- Renders: animsheet `dash` (forward, right, back, left unarmed) in tools/dev/out/v111/moves/.

## 2026-10-13: v1.11 the log pose raised properly (L)
- Was: the shoulder yawed -1.4 with the elbow folded 1.75, so the fist sat at the right shoulder and the ball (on the back of the left wrist, -z of the forearm) faced into the chest; from behind nothing showed. Now (MovePoses._log_pose, moved out of Humanoid): the elbow out to the side and forward (arm_l 0.7, -0.7, -0.5), forearm angled up across the body (fore 1.5), so the plain elbow bend turns the ball up toward the eyes; chest turned a little into it, head tipped down and left to read it; it comes up "out" a touch past (u 0.6) and settles. From behind the left elbow pokes out: you can see they're checking it. The HUD icon and needle logic are unchanged.
- movetest: holding L plays log_pose, the ball 0.28 m in front of the chest and 0.11 m under the head, its face toward the eyes (dot 0.83). Renders: posebench `PB_KV="log_pose=1" PB_REST=1 ... sword none log_pose:0.98 chest,chestf,chests,back` (tools/dev/out/v111/moves/lp_before_* vs lp_b_*).
## 2026-10-13: sitting (v1.11)
- `Seat` (scripts/interaction/seat.gd, an Interactable, group "seats"): its origin is the top of the seat, `height` the drop to the floor the feet rest on, `face` the way the sitter faces in the parent's frame (ZERO = either way across the parent's local Z: the side you walk up from). `Seat.add(parent, at, h, face)`, `Seat.pair(parent, top, spread)` (both ends of a bench or log), `Seat.face_all` (a table's benches face it). Area monitoring off; reach 0.95 m; F says "Sit".
- Where: Props.bench (two each: villages, KitVillage benches and table sets, the tavern's tables facing them, Brinehollow's quay and inn bench), KitCamps.log_seat (camps, harbours, dungeon camps), KitHouses' home stools and cook-house benches, the crew ship (two cabin stools at the table, the crate by the storage chest, the two crates on deck), Morrow's chair at Redtide. Props/kit code reaches the script through `Props.seats()` (a load): naming the class compiles Interactable -> Player -> the autoloads into every prop tool (posebench, modelshot) and they stop compiling.
- SitState ("Sit", scenes/player/player.tscn): settles onto the seat's floor point and facing over 0.3 s (from where you stood, kept in the seat's parent frame so a ship's seat carries you), pinned each tick (no move_and_slide: the capsule overlaps the bench); any move input, jump, F, dodge or an attack stands you back up where you sat down from. No prompt while seated (InteractionComponent). Player.sit(seat) / sit_ground(); `grounded` stays true while sitting.
- Ground sit (Player.sit_ground, the emote wheel's "sit"): SitState without a seat, seat_y 0.1; Humanoid's floor-sit block (seat_y < 0.25): knees up, left forearm over its knee, leaning back on the right hand.
- Co-op: a seat is one captain's, host-arbitrated with the cannon seats (Net.request_seat / release_seat). Seats are keyed by place, not path: `Seat.seat_key()` = "seat:w:x,y,z" (world, 0.1 m) or "seat:s:..." (the crew ship's frame, composed from local transforms so it's exact on every machine); Net._seat_key / _seat_node / _seat_taken_text ("A crewmate is sitting there"); `_seat_denied` takes the key. A seat a seated NPC already has (tavern regulars, Pell) isn't offered (checked once a second). Puppets sit via HumanoidSync's seated / seat_y.
- Tests: emotetest (new; bench: prompt, sit, on the seat, hips height, facing, no prompt, co-op key, up on a move; the cabin stool facing the table, up on jump; ground sit and up). Renders: posebench PB_SEAT=0.1 / 0.47 (tools/dev/out/v111/emotes/ground_*, bench_*).

## 2026-10-13: sneaking (v1.11)
- C toggles CrouchState ("Crouch", input action `crouch`; X on the web build, where C is dodge): 3 m/s (wading slows it too), faces the move (the camera when armed); C again, sprint, jump, dodge or an attack leaves it (an attack from behind gets the dagger's backstab as before). Footsteps 10 dB quieter and no dust while crouched (Player._on_footstep, puppets too via the state name). Crouch is in SWIM_FROM_STATES.
- Humanoid `crouching` (in HumanoidSync.FIELDS): hips down 0.25 on folded knees (thighs +0.75, shins -1.45, matched to the drop so the feet stay planted), chest forward -0.5, head up; unarmed, the hands drawn in front with a small swing. Render: posebench PB_CROUCH=1 (and PB_SPEED=3).
- Stealth (scripts/combat/stealth.gd): `range_for(p, from, fwd, r)` = r x0.5 for a crouched captain, x0.3 from behind (outside the AHEAD_DOT -0.2 cone; fwd ZERO = sees all round). Grunts: the idle notice range and the "too close behind" 5 m (-> 1.5 m), the return-home re-notice. Creatures: crab, leaper and roller bugs, boars (and piglets' fright) by facing; burrowers, swarm mites and scuttlebugs all round. The host reads a guest's crouch from its puppet's state name.
- Tests: emotetest (C crouches, 3 m/s and low, C stands; behind the smugglers' sentry: turned at 4.75 m standing, 1.25 m crouched), grunttest, bugtest, faunatest.

## 2026-10-13: the emote wheel (v1.11)
- Hold T (input action `emote`): scripts/ui/emote_wheel.gd (a CanvasLayer the local Player adds as `emote_wheel`). Twelve UIStyle "plank" frames round a dark gilt ring, the pointed one light teal with a glow and a sunflower spoke, its name in an ornate plate in the middle; mouse motion while it's open moves a virtual pointer (eaten in _input, so the camera holds still; 26 px dead zone), letting go of T or a left click does it, right click / Esc puts it away. Not while a menu or dialogue is up.
- EmotePoses (scripts/npc/emote_poses.gd; Humanoid._action_pose sends "emote_*" and "gesture_*" there): ORDER wave, point, salute, laugh, cheer, dance (a hornpipe, arms folded high), sit (the ground sit), shrug, bow, flex, facepalm, shanty (swaying, mug raised). Upper-body: wave, point, shrug, facepalm (you can walk); the rest are full-body and stop the moment you move (Player._emote_tick, EmotePoses.FULL). Lengths in ActionSpecs ("emote_*"). Emotes are exempt from _keep_gaze (they look up). Gotcha: an arm folded inward (folded arms, the shrug's open hands) is the arm swung out by z and turned by y; x only tilts the elbow's plane there (Euler YXZ: z, then x, then y).
- Player.emote(id): only when free and on the ground; sheathes instantly; body_model.play (mirrored to crewmates as a Humanoid event); its sound through Net.fx at EmotePoses.SOUNDS' u if the emote is still playing then (every screen hears it).
- Sounds (gen_psx_audio.py, FX.SOUNDS): laugh, cheer, hup (the flex), heel_click (the salute), slap (the facepalm), jig (a tin-whistle hornpipe, an original tune), shanty (a hummed original tune); the bow uses whoosh.
- Tests: emotetest (each emote plays as its action, every sound loaded, T opens, pointing up waves, pointing down sits, moving ends the hornpipe).

## 2026-10-13: talk and interact gestures (v1.11)
- EmotePoses "gesture_*" (lengths in ActionSpecs): talk_a (an open hand offered), talk_b (both hands out, beating time), talk_c (hand to the chest), nod, open (down to a chest, both hands heave the lid), pickup (bend for something on the ground), lever (both hands up, hauled down), push (palms shoved out, a step in), reach (a hand out to touch), hand (something handed over at arm's length).
- Talking: TalkState listens to Dialogue.line_shown / dialogue_event while it's on: a talk gesture with each of the captain's lines, a nod on 35% of the other's, "hand" on "shop:*", "*:got" (a parcel handed over) and "*:pay" (a task turned in); NPC._on_line_shown plays a talk gesture on the speaking villager each line; a bark-only trader's "Trade with" gets "hand" too.
- Interacting: `Interactable.gesture` ("" none), played by InteractionComponent on F through Player.gesture (free or talking). Set on LootBag (chests "open", dropped loot "pickup"), the temple levers "lever", the chain inn's "Rest" (its door) "push", the job board and the Driftstone "reach", lost-item searches, dug treasure and bottles "pickup", the galley "reach". There are no openable doors in the game, so "push" is only the inn for now.
- Gestures are body actions: mirrored to crewmates like the emotes. Tests: emotetest (Odile gestures with her line, the captain with his, a trade hands over coin, F on a chest plays "open", every gesture plays). Render: posebench tools/dev/out/v111/emotes/gest_*. Renders: animsheet emote_* and posebench (tools/dev/out/v111/emotes/anim_*, pb_*), uishots' new "emotes" screen (ui_15_emotes.png).
- movetest: holding L plays log_pose, the ball 0.25 m in front of the chest and 0.11 m under the head, its face toward the eyes (dot 0.83). Renders: posebench `PB_KV="log_pose=1" PB_REST=1 ... sword none log_pose:0.98 chest,chestf,chests,back` (tools/dev/out/v111/moves/lp_before_* vs lp_b_*).

## 2026-10-13: v1.11 per-weapon draw and sheathe
- "draw" / "sheathe" keep their names and lengths (player 0.35 / 0.4, grunts 0.45 / 0.5) but the pose now comes from `scripts/npc/draw_moves.gd` (DrawMoves, via MovePoses), chosen by `DrawMoves.kind`: katana (hand on the hilt at the left hip, thumb on the guard, one flat cut out to the right while the ring hangs; sheathing: a chiburi flick, the blade laid to the scabbard's mouth, slid home on the click, a beat on the hilt), blade (cutlass and every other sword: cross-draw from the left hip, a high flourish out to the right; away: a flick, the point guided down into the scabbard), axe (off the back: a hand over the right shoulder for the haft, pulled up and over into the guard; away: raised and swung back over the shoulder), great (two-handers, `GREAT` = the war axe: both hands over the shoulder, a heave, a slight dip), dagger (a quick cross-draw snapped out ahead; two daggers cross both arms, the off hand drawing from the other hip into its reversed grip; away: a flip of the wrist, then home), pistol (cross-draw, up and cocked at the aim; away: out low to the side, spun twice round the trigger guard (`_spin` writes the gun's basis, `point_guns` stands aside during "sheathe"), dropped into the holster). Dual wielders mirror the draw with the off hand (`_off`).
- Axes are carried on the back now (`DrawMoves.back_socket`: a BackSocket on the torso, grip by the right shoulder blade, the head down by the left hip; a two-hander higher, its haft end over the shoulder, head turned flat across the back: `on_back`); an off-hand axe still hangs at the hip. Humanoid._attach_weapon picks the socket.
- Sounds (gen_psx_audio.py, `py tools/texture_gen/gen_psx_audio.py draw_katana ...`, in FX.SOUNDS): draw_katana (the habaki click, a long bright scrape, the blade ringing), sheathe_katana (a falling slide and the click home 0.14 s in), draw_blade / sheathe_blade (a quicker scrape and a short ring / a slide and a leather seat), draw_axe / sheathe_axe (the haft dragged from its strap and slapped into the palm / a swing and a thunk), draw_great / sheathe_great (a low drag, a heavy whoosh, an iron clank / a swing and a clank on the back), draw_dagger / sheathe_dagger (a high snick / a slide and a snap), draw_pistol (leather, then the hammer cocked), gun_spin (three turns of air), holster (a leather thup and a buckle). New helpers there: _scrape, _ring, _click, _leather.
- Co-op: the sounds play from the pose (`DrawMoves._event`, FX.sfx straight, not Net.fx): the action already plays on every screen, so each hears it once. Grunts get the same draws and sounds.
- Tests: movetest equips cutlass, katana, boarding axe, war axe, dagger and pistol in turn: axes hang in the BackSocket, R plays "draw" in the right style with its sound, R again puts it away with its sound (the pistol's spin heard too). Renders: `AS_WEAPON=<model> AS_STANCE=<stance>` (new in animsheet) `animsheet draw,sheathe` per kind (tools/dev/out/v111/moves/draw_*), sheathshot `SS_WORN=boarding_axe,war_axe`.

## 2026-10-13: v1.11 clothing layers that don't poke through each other
- New suite cliptest (lone bodies at rest, ~40 s): every vest under every coat with two belts each (all four belts met), four tops under a jerkin and haori / frock / jacket, the heavy vests on a fem body under a longcoat; every covering hat over long / wild / spiky / bun hair; every legwear in every shod footwear. Each layer is found by material (unique colours per slot; the extra materials a slot brings, steel, studs, trim, learnt by building it alone on a bare body; hair by its texture), and every inner vertex is cast level from the body's axis at its height (from all the part's vertices, per leg for the legs; in the head's own space for hats, hair under 0.24 being free to hang out) onto the outer layer: no more than TOL 4 mm past it. `CLIP_ALL=1` lists every offender.
- What it found and the fixes (BodyBuilder): stripped shells (`_off(.., strip)`: coats, the plain vest, mail, padded jack, belts) took P_BODY in place of the chest's P_PEC / P_BUST, so the pecs and the bust came through them (bust up to 24 mm): a stripped ring is now brought forward over its profile's bulge (depth and centre, the back kept). Coats sat at a fixed 0.03 whatever was under them (padded jack 0.031, scale 0.031, cuirass ridge 0.038, all through): `_coat_off()` = past the vest (`_vest_out(false)` + 12 mm) and past the belt (+8 mm), and the collar, greatcoat cape, lapels, captain's trim and every coat's tails (`_cloth_sectors` top_off and flare) grow with it (`thick`). Belts went through the armour at the waist (cuirass lames, hanging mail and padded hems, scales): `_belt_off()` puts belts and sashes past the vest (`_vest_out(true)` + 6 mm), buckles and the knot with them. Under a coat the belt's front arc was a circle cut inside the body's outline at its ends: now P_BODY's own front, ±0.6 instead of ±1.25, and the sash knot sits in the middle of the coat's opening (it came through the lapel). The shirt's collar points fold in under a coat (x 0.6: spread they came out through its collar). The cuirass ridge is four pieces on the chest (one straight bar stood off the waist).
- Checked: cliptest, chartest, hairtest, styletest, qoltest, invtest.

## 2026-10-13: v1.11 the third wardrobe (nine pieces)
- Hats: slouch (a soft low crown, a wide floppy brim drawn as two-sided quads, its left side pinned up to the crown by a gold brooch with a short cream plume; Sela, tier 1) and helm ("Boarding Helm", steel: a cap over a riveted band, a nose bar, cheek plates, a three-lame guard over the nape and a low comb; `_hat_cut` 0.236 so the band presses the hair; Vey tier 1, plunder). Top striped (a boat-necked sailor's shirt: six bands laid round the torso rings, navy on a light shirt or cream on a dark one, no collar points; Sela, short sleeves). Vest harness (two leather straps crossed over chest and back with an iron ring where they meet, laid with the new `BodyBuilder._strap`; Sela). Coat admiral (the captain's coat, so the gold trim, cuffs, epaulettes and trimmed tails, plus bullion fringe under each epaulette; a tricorn worn with it gets the trim like the captain's; plunder). Legs slops (wide sailors' trousers whose legs flare out in a bell below the knee down to the footwear's top; none under tall boots or greaves; Sela). Feet cavalier_boots (tall boots with a wide bucket cuff and a gilt-buckled strap over the instep; `_boot_top` as tall boots; Sela tier 1, plunder). Accessories baldric (a broad strap from the right shoulder to the left hip, a gilt buckle on the chest; Sela tier 1) and spyglass (brass, tucked slantwise in the belt at the front, in a coat's opening; plunder).
- `_strap(mb, m, tr, a, b, w, back, lift, n)`: a flat strap in pieces following the body's surface (front or back) from a to b, kept within 75% of the ring's half-width (lifted along z at the flank it sank in). The bandolier uses it now (its flat boxes had cut into a cuirass, and into a thick coat), and straps lie over whatever's under them: the coat (`_coat_off`) or the vest (`_vest_out`), + 14 mm. The necklace and fur mantle grow with a coat's `thick`. Scale vests' standoff is 37 mm (the flat scales stand off a curved body at their edges).
- Gear: names, descriptions, defense (helm 5, admiral 6, cavalier boots 3, slouch / harness / slops 2, striped / baldric / spyglass 1: every plunder piece needs some, qoltest), STEEL_PIECES + helm, ACCESSORIES + baldric, spyglass (base_look false), GearIcons shapes for each (the striped shirt in the shirt branch with stripes), PLUNDER + admiral, helm, slouch, cavalier boots, spyglass. Brinehollow's shops stay white or green (qoltest): higher tiers of these come as plunder.
- cliptest also checks the baldric and bandolier over every coat but the greatcoat (its shoulder cape is meant to hang over them) and over the scale, cuirass and harness, with no belt (it shares the straps' leather), and the striped shirt under coats; the new hats, coats, legs and boots are in its lists. Render: `WS_SET=3` wardrobeshot (tools/dev/out/v111/clothes/third_*). (wardrobeshot's cloth sims don't settle in its 40 hand-stepped frames: tails and hakama fly about in its sheets, as before.)

## 2026-10-13: Windows build production pass (icon, version info, baked shaders, boot splash)
- Emblem: `py tools/texture_gen/gen_icon.py` (pillow) writes assets/branding/icon.png (256 master; config/icon), icon.ico (16/24/32/48/64/128/256; config/windows_native_icon and the preset's application/icon + console_wrapper_icon), boot_splash.png (640x360) and web/site/favicon.svg (the 16 px drawing as rects). 16 and 24 are hand-placed grids (GRID_16 drops the gilt rim), 32 and 64 come from a shape spec sampled at pixel centres, 48/128/256 are nearest doubles. `--dump N` prints the spec at N px as a grid to start hand-tuning from; `--preview DIR` writes a zoomed contact sheet. Godot's icon.svg is gone.
- Version info: the preset's file_version / product_version stay EMPTY on purpose: Godot then fills them from config/version (1.11 -> 1.11.0.0) on every export. Product "Driftwake", company "Zilk", copyright "© 2026 Zilk". export_path build/windows/Driftwake.exe; /build/ is gitignored with a committed build/.gdignore.
- Shader baker (preset shader_baker/enabled): it only bakes when the exporting editor runs the target's renderer, so **a `--headless` export bakes nothing, silently** (118.2 MB vs 127.3 MB, 0 vs 90 .d3d12.cache files in the pck), and D3D12 can only be baked by a Windows editor. build-windows.yml runs on windows-latest and exports with an editor window (WARP on the runner; a local export forced onto WARP with `--gpu-index 2` came out the same size and ran the same), then fails if the exe has under 50 baked files (`grep -a -o 'shader_cache/.../*.d3d12.cache'`). setup-godot has a Windows branch and a `bin` output. First launch with a fresh user dir: baked 258 shader variants loaded, 1 miss; unbaked 68 misses. Exporting by hand: from the editor (Project > Export) or `& $env:GODOT --path . --export-release "Windows Desktop" build/windows/Driftwake.exe` without --headless.
- Boot splash: boot_splash.png on bg #277F89, use_filter off (an exact 2x at 1280x720).

## 2026-10-14: v1.12 music (the theme, sea, wilds, village, night arrangements, ducking)
- Zach: better, more theme-appropriate music for the main menu, ocean, background/exploring and village. Away from the Stardew-ish shanties, toward his 10-08 picks (corsair_waters, harbour_calm): late-90s JRPG field/town warmth on sampled strings, horns, harp, pizzicato, ocarina, steel pan, marimba, accordion, hand percussion.
- gen_psx_music.py: new voices ocarina, steel (pan), bassoon, tamb, clave, celesta, swellstr (strings swelling to a peak 60% through the note). New tracks, all 2:19-2:34 in real forms, seamless, levelled to -18.0 LU in mixdown (`target_lu`, measured with audio_report.loudness): title (THEME_A/B/C: the game's theme, D major 96), sea + sea_night (6/8 dq 69, E minor/G: WATERS_A/B, THEME_68 = the theme re-barred in G, a becalmed bridge), island + island_night (D dorian 100, sixteenth ticks: EX_A ocarina/steel pan, EX_B, EX_C = the theme in D minor, EX_D calls and answers), village + village_night (A dorian 88: HARBOUR_A/B, VIL_DANCE, VIL_THEME = the theme in C). A night track is the same Song (same tempo, bars, chords, melodies) arranged sparser, so Music can cross from one to the other at the same position. Melody lines can mark bars with ` | `; Song.line then raises if a bar doesn't add up. The old title/island/sea shanty functions are gone (git history).
- Music (scripts/game/music.gd): TRACKS = [file, bars]; `bar_len`. Contexts title / village / island / sea / combat / boss; `Music.in_village(tree, pos)`: Brinehollow within TOWN_R 52 m of StarterIsland.VILLAGE or on its harbour front (KitHarbour frame: the quay's stations +-6 m, from the pier's end to 20 m behind the street), a chain island near its village plan's plaza, hamlets or buildings. Night (`_night` tracks) from DUSK 19:00 to DAWN 5:30 by Weather.hour(), crossfading over NIGHT_FADE 6 s at the same playback position. Calm changes wait for the playing track's next bar line (`_cue`) and start the new track on a bar (a resumed one at the bar it was left in); fights cut in at once (FAST_FADE); leaving the title cuts at once. `_left` is keyed by context, so day and night share the resume point. Co-op: each machine's Music follows its own captain (group "player") and the host-synced clock.
- Ducking (Settings._ensure_buses): AudioEffectCompressor on Music, sidechain SFX, threshold -12 dB, 2.5:1, attack 8 ms, release 450 ms. Untuned by ear yet.
- Sizes: the seven new .ogg files are 5.2 MB (about 0.75 MB each).
- Tests: musictest (new): title, Brinehollow's square and pier = village, its wilds = island, 22:00 = island_night in step with the day track, back to the square resumes the village theme at its bar, a chain island's village vs its summit, aboard under sail = sea, then sea_night. r8test's dock check now expects "village". Gotcha in tests: a chain island's summit can be 60 m up, so drop the captain from well above (musictest's put casts from +300 m). Runs: musictest, r6test, savetest pass; r8test's music checks pass, but its Morrow sequence failed on a different check in each of three runs (the dash lane, the heal on reset, the boss bar), not touched here.
## 2026-10-14: v1.12 light (readable nights, ship lanterns, town lamps, the belt lantern)
- Zach: "if it is not daytime, then it becomes very difficult to see much". Weather.KEYS' night rows (19.6, 0, 4.8, 24): the moon (55, 66, 100%) at 0.32-0.42 (was 0.15-0.22), the ambient (0.3, 0.36, 0.56) x 0.6-0.62 (was (0.22, 0.26, 0.42) x 0.5), a slightly bluer night horizon (so the fog). `AMBIENT_FLOOR` 0.16 (luminance x energy): storms and overcast nights never go under it; a night storm's ambient leans blue-grey, not day grey. `ambient_level()` / `sky_light_level()` read it back. Measured: noon ambient 0.43 / sun 1.22; 21:00 0.21 / moon 0.23; 2:00 0.22 / 0.26; 2:00 storm 0.16. The moon now casts shadows (energy > 0.12, as before).
- NightLight.is_night() (static; reaches Weather through the tree: a static func naming an autoload breaks --script compiles).
- ShipLights (scripts/ship/ship_lights.gd; one line each in ship.gd `_ready` and enemy_ship.gd): the crew's ship gets lanterns on posts at the quarterdeck's aft corners (one light over the helm), one hung on the mast's aft side over the main deck, one on a post at the bow, two by the cabin door (one light), one on a stanchion each side of the rail amidships (z 0, between the shrouds and the stairs): 6 NightLights + the old CabinLight. A pirate ship: one on its mast and a light at the stern (2). The glass glows at any range, so ships read at night past the lights' 45-60 m fade.
- Towns: Brinehollow's budget 12 -> 22 (21 used): door lamps on six more houses (four round the plaza, two by the harbour/west lane), a lit lantern post at each pirate camp (KitCamps.pirate_camp, the first of its two) and two of the den's three. Generated villages 12 -> 16: the homes' and the elder's rooms are lit after dark too (the shops' all day, as before). Harbours 4 -> 6. All NightLights (no shadows, distance fade 45-60 m), so only the ones near the camera cost.
- The belt lantern (scripts/npc/belt_lantern.gd, BeltLantern; Humanoid.wear_lantern, hung again by apply_look): a brass lantern (BeltLantern.model, also ShipLights') at the back of the right hip (mirrors the main sheath, 0.17 m back: clear of an off-hand blade's sheath, checked with sheathshot). Pendulum: verlet in hook-relative world axes (world positions in float32 lose the per-step motion far out: it stuck at 5 km), the hook's speed changes felt at INERTIA 0.35, damp 0.03 a step, never in toward the body (local x/z >= -1.5 cm), never past 1.1 rad. Light: OmniLight 1.0, range 9, attenuation 0.7, no shadows, set 0.28 m out from the hip (inside the lantern it burnt the thigh white), a small flicker, distance fade 40-52 m.
- Player._lantern_tick: lit from dusk to dawn (NightLight's hours), out while body_model.swimming or diving; H (`lantern` action; Controls list) flips it until the next dusk/dawn or a swim; a "clack" through Net.fx. Co-op: flag NF_LANTERN (8) in net_pack's flags; a puppet's lantern follows it.
- bigshipshot takes BSHOT_HOUR.
- Tests: lighttest (new; Light & sound group): ambient and moon over the floor at 21:00, 2:00 and a night storm, below the day's; the lantern out by day, lit at night, H off and on, its snapshot bit, out swimming/diving and refusing H there, relit climbing out, kept through refresh_look; the ship's 6 lights dark by day and lit at night, every pirate ship's 2; Brinehollow within its budget and the den lit; a standalone body's lantern hangs straight, swings on a run and stop (0.98 rad), settles. villagetest, harbourtest, shiptest, ragtest, chartest pass (chartest's "player loads the saved look" failed once with other sessions' suites running, passed alone: the saved look is shared user data). Renders: tools/dev/out/light/ before_* / after_* (islandshot 21:00 and 2:00, bigshipshot 21:00, villageshot 21:00), sheath2_* (sheathshot), after_ab21_sword_combo (abilityshot at 21:00).
## 2026-10-14: v1.12 a living sea and sky (ship spray, coast surf, ocean sound layers, birds)
- Zach: more particles and ocean spray, better ocean sound, birds in the sky.
- CoastProbe (scripts/world/coast_probe.gd, owned by Ambience as `coast`): one of 16 bearings a frame, rays down every 7.5 m to 180 m; each land/sea crossing (bisected to ~1 m) is a coast "beach", "rock" (rock/driftstone textures, steep or rock terrain, or ground > 2.5 m 4 m inland = cliff) or "wall" (quays, stone work). Wooden colliders (piers, ships, huts, trunks) are seen through. Gives land fractions at 30/90 m (the old _land_near/_land_far), nearest(kind, from), all(), over_water. Reuses Footsteps' terrain/texture helpers.
- ShipSpray (scripts/ship/ship_spray.gd, made in Ship._ready; ship._wake now only lays the foam wake): bow-wave emitters each side and the stern churn by speed (duty-cycled persistent CPUParticles3D, local_coords), the stem's immersion rate `rise` = how fast the sea climbs her bow: > 1.3 m/s at speed = a hull_wave slap, > 2.2 x (1.15 - 0.35 caps) = a sheet of spray (two one-shot emitters ping-ponged with restart()) and bow_spray; in a blow a mist streams aft and downwind (gravity = the apparent wind in her space). `spray` 0..1 drives Ambience's hiss. Asleep past 180 m from the camera. Local per machine from the synced ship and sea.
- SeaSpray: waves break on CoastProbe's coasts within 75 m as each crest arrives (wave height crossing 0.28 x amp_mult upward, 2 s per spot, 0.2 s apart overall): beach white water, rock spray thrown high + mist, a quay slap, with wave_break / rock_crash / hull_wave (< 55 m). Spindrift (5 pooled emitters on crests in a gale), foam patches (MultiMesh of 40 ragged 16 px scissor blots riding the swell, tilted to the wave normal a third at a time), streaks follow Ambience.gust. The old random beach bursts are gone.
- FX.splash with size >= 0.7 and amount >= 5 at the water leaves FX.water_ring (two foam bands riding the surface): dives, bodies, grunts, cannonballs, the anchor.
- Ambience: new keys deep, lap, far, rock, spray, under (LOOPS/TOP_DB); shore = distance to a beach, rock = to rock, far = a coast 25-185 m off, lap = swimming/wading/over water on a pier/near a wall. Gusts (gust 0..1: wind level and pitch, rigging, wind_gust one-shots). Under water (camera or the captain's head under): a low-pass ("underwater") on SFX and Ambience, 20 kHz -> 480 Hz, plus underwater_loop. Ambience also makes SkyBirds.
- SkyBirds (scripts/world/sky_birds.gd, /root/Weather/Ambience/SkyBirds, shaders/sky_bird.gdshader): one MultiMesh of at most 72 (caps: gulls 24, dark 36, parrots 12), wings hinged in the shader (custom data: angle, fold, kind). Per island within 650 m of its coast (freed past 900), seeded by the island's seed (Brinehollow 8181): 1-3 high flocks (WHEEL clumps or a VEE going round), 5-8 harbour gulls circling the DockingArea, some perched on rays-found roofs/posts/pier (not terrain), parrot parties hopping forest_crowns (jungle islands and Brinehollow). The ship within 260 m of a coast draws 3 gulls (one trailing her wake, some circling the mast, landing on the masthead or a yardarm while she's under 6 m/s). Scatter: a captain within 2.5 m, or within 7 m going over 4.5 m/s (measured from positions). day = (1 - 1.3 night) x (1 - storm 0.35..0.75): birds past it fly off and hide. Not drawn or steered past 480 m.
- Sounds (gen_psx_audio.py): sea_deep_loop, sea_lap_loop, far_breakers_loop, rock_surf_loop, spray_hiss_loop, underwater_loop, wave_break x3, rock_crash x3, hull_wave x4, gull_cry x4, jungle_bird x4, wind_gust x3 (levels in docs/audio_audit.md).
- Tests: skytest (new), ambiencetest (deep bed, gusts, spray hiss, underwater low-pass, cliff top rock vs beach surf). Renders: skyshot (new), seafxshot (+ cliff in a storm, splash ring).
- Zach (renders): spray came off the anchor. ShipSpray's bow emitters sat inside the hull (x 0.55 at z -7.6, where she's 2.3 m wide at the waterline) and threw drops up past the cathead. Everything now starts at the waterline just outside her planking (ShipSpray.beam_at(z) from HullBuilder.RINGS): the bow wave low and flat off her sides at z -10, the sheet and mist from the stem (z -12.3), the churn aft of the transom. Foam patches no longer spawn under a hull. seafxshot `sea_bow` frames the anchor.
- Rain (Zach: too bright and big, falls through everything): Weather's streaks are thinner (0.012 x 1.1 m), fewer (1500) and lit by the scene (alpha 0.32). RainFX (scripts/world/rain_fx.gd, made by Weather._build_rain): a GPUParticlesCollisionHeightField3D (56 x 64 x 56 m, 256 px, redrawn every frame while it rains, round the camera) stops the drops on ground, roofs and decks, and a collision sub-emitter splashes 2 droplets each; pocks (rings) on the sea round the camera (cells judged once per 4 m); puddles in 7 m cells (45% of them, placed by the cell's hash, flat ground open to the sky, not ships) growing with `wet` (50 s to soak, 160 s to dry, like the deck). Render: rainshot.gd (street and deck at 13:00 and 21:00, the sea).

## 2026-10-14: longer days, pixelation toggle, L = lantern
- Zach: days slightly longer than nights. DayClock (scripts/world/day_clock.gd): the 24-minute day is warped,
  6:00-18:00 takes 840 s (70 s an hour) and the night 600 s (50 s an hour). Weather.hour()/day() go through it;
  `Weather.time_at(h, day)` and `skip_to(h)` replace the old `h / 24 * DAY_LEN` sums in every tool and test (that
  sum now lands at the wrong hour), F7 skips two clock hours, KitLife.stay_at measures a villager's stay on it.
  Saves keep world_time, so an old save's hour moves a little on load. r9test checks the rates.
- Pixelation is one toggle (`video.pixelate`, PSX.GRID 960x540); the 640/480/320 presets are gone (Zach: too hard
  to see). Settings v4 migrates (`psx_preset` 3 "native" -> off, anything else on). F2 toggles it.
- Keys swapped: L toggles the belt lantern, H holds up the log pose.

## 2026-10-14: v1.12 post-merge bug pass
- Common thread: three suites sampled per frame what the game decides per physics tick. While a chain island
  puts itself in the world (frames up to 100-190 ms, up to 8 ticks each) the game ran several ticks between two
  of the test's looks. No game bug in any of the three.
- swimtest "climbed aboard": W is still held when the climb ends, so Climb -> Idle -> Move inside one long frame
  (deck spot unchanged, 3.52/0.32/-2.9). Accepts Idle or Move.
- foresttest "...it shows before she comes up": the damage was a brood bug's ram (B0_1, from the shriek a few
  steps earlier, 10 -> 8 after armour) landing while she was under the floor, not her. The brood is held
  (process off) before the burrow checks.
- seatest stall: steps 5/7 waited on `near(3.0)` with no timeout. At 46 m/s the ball is inside 3 m for ~4 ticks
  before it bursts on the captain, so one long frame skipped it and the step waited forever. The ball is now
  caught in the suite's `_physics_process` (frozen in reach until hit) and steps 5/7 fail after 4 s like step 3.
  Same family: "the brig fires a double broadside" got 0 shots when the brig, still alongside after her ram,
  went to BOARD a tick later (a warning is cancelled outside HUNT/BROADSIDE); the step puts her in BROADSIDE.
- nettest "our puppet stands at the wheel": the same thing over the network. The host's reply runs after the
  frame's physics ticks but before the puppet's _process, so the puppet (placed last frame on the hull as drawn
  then) read against the hull's newest step was 0.17 m off per tick in the frame at 10 m/s: 0.46 m under prepush's
  load, 1.17 m with two suites beside it. nettest_node.on_deck reads both captains' puppets from their snapshots
  against the hull as drawn now (0.18 m alone, the swell's pitch on the helm).
- nettest "clock synced" is load, as flaky.txt has it: it is judged while both sides put chain islands in the
  world (frames to 160 ms), median 1 and 33 ms off in two solo runs, 61 under prepush, 89 with two suites beside it.
  The new systems cost about 1.3 ms a frame together (perfbench probe:dock_sea, headless: Ambience with CoastProbe
  0.64, SeaSpray 0.39, SkyBirds 0.38, ShipSpray 0.06, RainFX 0.04, BeltLantern 0.02).
- Not fixed, seen 3 times in ~10 runs (seatest twice, the nettest guest once): signal 11 in
  `add_surface_from_arrays` (MeshBuilder.commit: village dressing, a scuttlebug's model) on the main thread while
  the next chain island prepares on a worker. The 2026-10-13 race (bodies built on workers while the main thread
  makes meshes); suspected headless-only (the dummy renderer's mesh storage), unconfirmed. No new code on that path.

## 2026-10-14: the landing queue, agents landing themselves, suite times
- Why: the lead was the bottleneck, conflicts were fixed after the agent who wrote the code had gone, and two
  landings at once could trample each other.
- One land.ps1 at a time machine-wide (crew_lib `Enter-Landing`): `.git/crew/landing.lock` is held open by the
  lander (the OS frees it if it dies) with `landing.json` beside it (branch, pid, since, step: rebasing,
  compiling, smoketest, tests, fast-forward); waiters queue in `landq/` in order and print whom they wait for.
  `Get-Landing` clears a landing.json whose lock nobody holds. test_status.ps1 adds `landing` (now + queue) to
  status.json; `land.ps1 -List` and crew.ps1 print it.
- land.ps1 with no branch in a worktree lands that worktree's branch. A conflict stops a self-landing
  mid-rebase (from elsewhere it backs out) and prints the steps; land and the finish hook both recognise a
  worktree stopped mid-rebase. It refuses when the main checkout has uncommitted changes (changed, staged or
  untracked) in files the landing touches (checked before waiting, after the lock and before the
  fast-forward; the fast-forward used to just fail), or while a test run is going in the worktree. Stray
  untracked `.uid` files of the branch's scripts are committed on it ("The new scripts' .uid files"); an
  untracked `.uid` in the main checkout that the landing brings its own of (the editor's import) is deleted.
  If main moves during the tests (a commit made outside land.ps1) it stops: run land again, passes carry over.
  `-Light` is accepted and ignored. Prints one line, never pushes.
- `tools/dev/unwork.ps1 <name>`: deletes the worktree folder through `rd /s /q "\\?\<path>"` (git worktree
  remove hits "Filename too long" in .godot), prunes, deletes the branch and the claim; refuses with commits
  the target doesn't have or uncommitted work unless `-Force`. `land.ps1 <branch> -Remove` lands then calls it.
- Suite times: a job notes its first `PASS`/`FAIL` line (`Get-JobSetup`), Write-Ledger records `setup` and
  appends every result to `ledger/history/<suite>.jsonl`. `suite_times.ps1` prints median total/setup/checks
  per suite from that history, the day of live runs before it, and each suite's last result.
- Proof (scratch worktrees landtest-main/-a/-b off this branch, landed `-Onto worktree-landtest-main`, all
  removed with unwork.ps1): two landers at once (b waited "worktree-landtest-a is landing (compiling)", then
  "(smoketest)", rebased onto a's landing and landed); b's stray .uid committed and the target's untracked
  copy deleted; a conflict from another checkout backed out; the self-landing stopped mid-rebase, the finish
  hook and a second land named the rebase, the agent resolved, `rebase --continue`; a staged change to the
  file in the target refused the landing; unstaged, a landed itself (`-Light` passed, the full test step ran).
- Times (median wall seconds, passed runs, this machine with up to 5 suites at once; setup from one run of 14
  suites beside a landing, so a little high):

  | suite | runs | total | setup | checks | setup % |
  |---|---|---|---|---|---|
  | harbourtest | 3 | 258 | 66 | 192 | 26 |
  | bosstest | 1 | 174 | - | - | - |
  | dungeontest | 1 | 156 | - | - | - |
  | seatest | 5 | 143 | 36 | 107 | 25 |
  | isletest | 4 | 139 | 58 | 81 | 42 |
  | techtest | 4 | 128 | - | - | - |
  | net-chain | 1 | 113 | - | - | - |
  | villagetest | 7 | 109 | 76 | 33 | 70 |
  | faunatest | 2 | 107 | - | - | - |
  | skytest | 8 | 105 | 33 | 72 | 32 |
  | apetest | 1 | 99 | - | - | - |
  | foresttest | 6 | 98 | 33 | 65 | 34 |
  | net | 1 | 94 | - | - | - |
  | smoketest | 33 | 92 | 44 | 48 | 48 |
  | savetest | 13 | 90 | 11 | 79 | 12 |

  The light end: feat 37 (setup 34), r6test 39 (38), emotetest 44 (36), qoltest 45 (36), chartest 85 (54).
  A full run (suites.txt) is ~4530 s of machine time (75 min; 15 min of wall time at best on 5 slots); of the
  14 suites with setup timed, 43% of their time is setup.
- Recommendation: a shared lighter test world is worth it, but for the small suites, not the slow ones.
  59 of 65 suites load scenes/world/world.tscn (Brinehollow plus the chain's islands preparing), and the
  player-mechanics suites spend 80-97% of their 35-45 s there for 1-10 s of checks. A flat test stage (ground,
  water plane, the player, a grunt on demand, autoloads up) for those ~35 suites would save ~25 s each:
  ~15 min of machine time a full run, and an agent's own loop drops from ~40 s to ~10 s a suite. The slow
  suites (harbour/isle/village/sea/dungeon/boss) test the world itself and need it; smoketest keeps covering
  the real world on every landing. Migrate the fastest ten first and compare their times here.
## 2026-10-14: the test CI on GitHub (prepush.ps1 -CI)
- `.github/workflows/tests.yml` (pushes to any branch but main, and by hand): a plan job imports once (.godot in
  actions/cache, keyed on project.godot + *.import + assets/; every job still runs `--import` to catch up new
  class names) and deals the suites (`tools/dev/ci_plan.ps1`: each heavy.txt suite alone, the rest longest-first
  over 11 jobs by `suite_times.txt`), then 17 suite jobs (`run_tests.ps1 -CI -Jobs 1`), 3 co-op jobs
  (`nettest.ps1 -CI`: default, chain, board) and a verdict job, on ubuntu-24.04. ~5.5-6 minutes wall with
  -Jobs 2 (local prepush: ~20+ and the PC tied up); -Jobs 1 (fewer hitches) is untried, likely ~8-10. Each job's summary has a table (suite, time, result, the failure
  block); logs are artifacts; failures are annotations (ci.ps1 prints them).
- run_tests/nettest `-CI`: no crew (slots, pass cache, in-flight, ledger, live runs, board) and no import; the
  judging is crew_lib's as locally (FAIL/SCRIPT ERROR/RESULT, stall/flood limits, flaky.txt's one retry).
  crew_lib's Start-/Stop-GodotJob start Godot through `/bin/sh -c exec ... > log` and kill it with
  Process.Kill(tree) on Linux (cmd's redirect and taskkill on Windows). Save-LiveRun skips a run with no file.
  The CI side (in-memory run, the summary table, annotations, the ci/ branch name) is `tools/dev/ci_lib.ps1`.
- `tools/dev/ci.ps1` pushes HEAD to `ci/<branch>` (force; never main), finds that commit's new Tests run, one
  `gh run watch`, prints each job and the failures; `prepush.ps1 -CI [-NoPush]` pushes the same commit when
  green and deletes the ci/ branch (kept when red, for `gh run rerun --failed`). setup-godot's templates are
  optional now (tests need none).
- Linux vs Windows: no suite needs Windows; nothing failed for a platform reason. A runner is slower and
  hitchier than Zach's PC, which showed timing assumptions: netclient waited at most 20 s for the guest's chain
  islands (a runner builds one in ~17-20 s) -> 60 s; progtest waited in process seconds and a long frame ran
  the 0.3 s logia dodge out inside a 0.2 s wait -> physics ticks, and it looks 6 ticks in (a frame can run 8).
  Still flaky on runners with two suites each (one or two per run, never the same twice): swimtest and
  watertest "head above the water" (-0.08 / -0.06, limit -0.05), r8test "he dashes past", vinetest "aiming at
  the big bug" (listed), grunttest "the crew mixes its attacks" (12 s of only "peril"). No green full run yet.

## 2026-10-14: the light test stage + atomic tests (pilot)
- What: `TK.stage(self, opts)` (tools/dev/stage.gd, stage_islands.gd) builds a flat stage instead of world.tscn:
  ground 3 m above the sea (Ocean.depth_at reads it dry), a sun, the real player.tscn, the camera rig, the HUD,
  and only what a test asks for (dummy, a GruntCamp, a drawn weapon, an NPC, Props.bench, a chest, the ship's
  storage on GameManager.storage, the sea past x = 24 and the ship). `stage.up` once the captain is free.
  Atomic tests live in tools/dev/t/<group>/<behaviour>.gd (template t/_template.gd); run_tests.ps1 takes a path
  or a group (`t/player`, `t`), and test_map.txt names groups as tokens (`t/player`).
- What the world gave the player and HUD: nothing they need, except (a) Music reads Brinehollow and the chain
  every half second (in_village, KitStyle.around): the stage switches Music off; (b) a "world_gen" node for
  KitStyle.around and GameManager.chain(): stage_islands.gd, no islands (named NoIslands: the sea chart finds
  "Islands" by name); (c) respawning after death needs the ship (GameManager._respawn_player returns without
  one: the game always has her), so a death test asks for "ship". Weather only attaches to a scene named World
  (opt "weather"). No game code changed.
- The stage plays a fresh game in its own save folder (SaveGame.use_test_dir("user://test_stage"), begin(1,
  true)): the default captain every time. The world suites build whatever look a previous run left in
  user://look.cfg (it read "Villager", bare: styletest's "physics chains" check only held by luck).
- Ported (every check kept; suites removed from suites.txt, suite_groups.txt, test_map.txt): feat, feel,
  dash, stamtest, styletest, movetest, healtest, emotetest -> 30 tests (t/player 18, combat 3, weapons 1,
  items 5, ui 2, ship 1; README lists them). ragtest stays a world suite: on the stage the downed body creeps
  0.092 m/s against its 0.08 limit (both runs), so its port was dropped rather than loosen the check.
- Timing: stage up in 1.9-4.0 s (median ~2.3), but every Godot process first spends ~8 s compiling the
  project's scripts (the FX autoload's class references pull in world_generator, the island kit and the
  fauna: three ~2.5 s gaps in a --verbose boot). So an atomic test is 11-22 s (median ~14 s, measured with
  another agent's five suites sharing the machine) against 34-48 s for the old suites: a 3x faster loop for one
  behaviour. The 8 old suites were 318 s of machine time; the 30 atomic tests are ~430 s (30 boots), ~90 s of
  wall time at 5 slots. Cutting that boot (lazier class references from the autoloads) is the next win.

## 2026-10-14: tests keyed by what they load
- Why (Zach): passes were cached against the whole tree, so any edit anywhere (a doc, another test) made every
  suite stale, and -Changed leaned on the hand-kept test_map.txt.
- Recording: `scripts/game/dep_record.gd`, started in Settings' `_init` when `DRIFTWAKE_DEPS_OUT` is set (the
  runners set it per Godot, run_tests and each nettest process). It's a ResourceFormatLoader added first in line
  whose `_recognize_path` notes the path and returns false, so it sees every load (transient `load(...).instantiate()`
  too) and claims nothing. At exit (Settings' `_exit_tree`: the first autoload, so the last out, with the whole
  tree still allocated) it adds every project file `ResourceLoader.has_cached` (scripts the GDScript cache loads
  by class name skip the loaders) and writes the list. FileAccess reads and folder listings note themselves:
  `preload("res://scripts/game/dep_record.gd").note_dep(path)` (dialogue JSON and its folder, ItemDB's items
  folder). Gotcha: a class_name script can't name an autoload (`Settings.note_dep` failed to compile under a
  test's `--script`, which compiles before the autoloads exist; compilecheck didn't see it, it loads them first).
- Keys (crew_lib `Get-TestKey`): after a pass the run's list becomes `.git/crew/deps/<test>.txt`; the key is
  "d" + SHA-1 of "path blob" for each (plus project.godot, the autoloads, the test's script, a source's .import,
  a noted folder's file names), blobs from `git ls-tree -r` of the working tree's key. Passes are
  `results/<key>/<test>.ok` with the manifest under the first line, so test_status names what changed. Before a
  test's first recorded pass the tree is its key (and test_map its picker). In-flight sharing, the ledger
  (`key`), nettest (host + client lists merged) use the same key. `-Exact` keys by the tree (land's smoketest).
  `-CarryFrom` is gone: a pass whose loads the rebase didn't touch has the same key afterwards.
- Atomic tests: `tools/dev/t/<group>/<name>.gd` are found by themselves, named `t.<group>.<name>` (the other
  branch's convention), run as `t/player/dash`, `t/player` or `t`; status.json gets a `t/<group>` group each.
- Measured (dash, capturetest, uitest, skytest, shiptest, musictest, invtest): every suite loads 510-567 files
  and they share 509; of 621 game files (scripts, scenes, shaders, resources, assets) dash loads 504, and the
  scripts it doesn't are 6 beasts, enemy_spawner, buoyancy_component, title_screen, whats_new. The autoloads
  alone (compilecheck on test_kit.gd with the env set) load 343 files, 194 scripts, humanoid, ship_spray,
  inventory_screen, gen_island and kit_harbour among them: GDScript loads every script a loaded one names as a
  type, and the autoloads name the game. So by loads alone, any game-script edit makes every test stale,
  atomic ones on the light stage included.
- So: caching, test_status and prepush go by loads (sound: a pass holds until something it loads changes;
  editing a test, a tool, a doc or test_map no longer touches anyone's passes). `-Changed` (and landing) picks
  a test only for a changed test-side file it loads (its script, test_kit, the stage) or one test_map says
  it's about, among files it loads (`Get-MapTokens`: a suite's name; an atomic test's `t`, `t/<group>`,
  `t/<group>/<name>`, the tokens the stage branch put in the map); `-Wide`: every test that loads one. One-file
  edits, of 87 tests (57 suites, 30 atomic), picked by default / by the map alone (before) / by loads:
  ship_spray.gd 3 / 3 / 87, inventory_screen.gd 5 / 5 / 87, humanoid.gd 31 / 31 / 87, dodge_state.gd 21 / 21 /
  87 (every one of the 37 recorded tests loads all four; the 30 atomic tests load 421-433 files each). The
  default only drops a map pick that doesn't load the file. The map stays the relevance filter until the autoloads stop naming the whole game
  (lazy `load()` in GameManager/Net/GameMenu instead of class references would shrink the floor).
- Proof (8 suites recorded: dash chartest invtest uitest skytest capturetest shiptest musictest): CLAUDE.md,
  crew_lib.ps1 and this file changed after their passes and all 8 stayed ok. A comment edit to
  scripts/enemies/beasts/alpha_boar.gd, which only skytest/shiptest/musictest load: test_status called exactly
  those 3 stale, `affected -Wide` picked exactly those 3 (plus map fallbacks for unrecorded suites), the other
  5 stayed ok. A comment edit to the Story autoload: all 8 stale and picked. Reverting each: all 8 ok again
  (same contents, same key). ship_spray.gd, inventory_screen.gd, humanoid.gd: each loaded by 8 of 8.
- CI (landed first): `-CI` runs skip the deps like the rest of the crew; ci_plan.ps1 adds one job, `t`, for
  the atomic tests (the suites ported to them had left suites.txt, so CI had stopped running them).
- chartest failed twice while the atomic-tests branch's player tests ran beside it and passed alone: both write
  `user://character.cfg` (CharacterLook.SAVE_PATH, global to every checkout); tests that run at once share user://.
- watertest "grunt won't walk into the sea" failed once the swell phase became deterministic (game-time clock): the
  test picked its shore `edge` with swell-inclusive `depth_at`, and at t=1.5 s the swell is in a trough, so the "edge"
  sat 0.66 m under the calm line and the grunt placed "4 m landward" started in the sea (a crest then swam him). The
  game was fine (a grunt at calm depth 0 never reaches SWIM_ENTER_DEPTH). The test now finds edge/deep by calm depth.

## 2026-10-14: v1.13 weapon impact sounds and the UI sound set
- Why: every blow on a body played "hit", and the menus one "select" (docs/audio_audit.md gaps, proposal 7).
- Impacts: `HitData.impact` (packed at index 15 of Net.hit_pack). `Player.melee_hit` sets it from `Player.IMPACT[style]`
  (heavy/finisher kinds take the heavy take); blade-style gunfire sets "shot" at the site (corsair_gun.fire,
  grapeshot, the corsair volley, Bullet Storm, the hang shot), the pistol butt and meteor kick punch; grunts' cutlass
  hits slice, rush and rifle butt punch, shots "shot"; the ape's swipe punches; thrown fruit punches; the rest stay "".
  `CombatManager.impact_sound(hit)` ("" -> hit, shot -> shot_hit, knockdown/crumple -> heavy) and `impact(hit, at, ...)`
  (Net.fx, `last_impact` for tests) replace the "hit" sfx where bodies take blows: player, grunt (and boss, ape),
  scuttlebug, jungle_beast, creature, brood_queen; the dummy plays it locally. `CombatManager.guard(hit, steel, ...)`:
  clash for slice/chop/shot on a steel guard, else block (the captain's block and parry, the grunt's guard and its
  heavy read; `_read_heavy` takes the hit now). Parry: the guard sound plus the old ting at -6; a cut shot clashes.
  Hit timing and damage untouched.
- Sounds (gen_psx_audio.py, `py tools/texture_gen/gen_psx_audio.py slice slice_heavy chop punch punch_heavy shot_hit clash ui`):
  slice/slice_heavy/chop/punch/punch_heavy/shot_hit/clash, 3 takes each (-14 to -16.6 LU), and `ui_sounds()`:
  ui_move, ui_confirm, ui_back, ui_deny, ui_open, ui_close, equip, unequip, ui_buy, ui_sell, level_up, quest_accept,
  quest_done (-16 to -22 LU). First drafts of chop/punch/shot_hit were 83-96% under 200 Hz (inaudible on laptop
  speakers, the audit's old complaint): rebuilt with mid knocks. jig and shanty are gone (no emote plays music).
- UI: `UIStyle.SOUNDS` + `UIStyle.sfx(name)` (`played` log for tests), players made by GameMenu (`make_sound_players`,
  PROCESS_MODE_ALWAYS parent). `UIStyle.button()` hooks hover/focus "move" and a deferred press sound ("back" by its
  text, else "confirm") that's skipped if the press played its own sound; "move" within 150 ms of another sound is
  dropped. Steppers "select". GameMenu open/close/back; inventory equip/unequip/deny (`_flash`), skill map
  coin/deny/equip/unequip/select (`_deny`), shop buy/sell/deny, dialogue choices move/confirm, level up
  (Progression, local only: peers no longer hear a coin), Story and KitQuests quest_accept/quest_done
  (`show_objective_banner(goal, done)`). Title, save slots and the creator lost their own select players.
- Test: `t/combat/impact_sounds` (cutlass slice + finisher, knockdown heavy, hit_pack round trip, grunt's cutlass
  and ball on the captain, blade parry clash, axe chop, fist punch + finisher, bare-handed parry block, inventory
  open/close, a button's confirm and a Back button's back). t/combat t/ui pass except cutlass_combo "after a long
  pause, combo restarts", which already fails on main and on the duels branch (ledger), not touched here.
## 2026-10-14: the player menu and duels (v1.13)
- Zach: an interact menu with other players right next to them (trading, viewing their gear, a duel: a light fight
  with the opponent's health at the top like a boss, the loser downed not dead and back up after, a little XP).
- Menu (`scripts/ui/player_menu.gd`, a child of the local captain like the emote wheel): every other captain gets a
  "Meet" Interactable (prompt = their name, so the HUD reads "F Name"; reach_test: 2.5 m flat and facing them,
  dot >= 0.5; off while they're down or either is duelling). F opens Trade / Inspect / Duel (click, 1-3; the keys are
  eaten so skills don't fire); Esc (Inspect: back first), a click outside, the pause menu or them being 3.5 m off
  closes it. Trade is the existing trading (2026-10-05: drop, they pick up the sack): it turns you to face them and
  opens the inventory with a toast saying how. Inspect (`inspect_panel.gd`): name, LV, fighting style, fruit, main /
  off hand, the ten worn slots, quick items with counts, the inventory's Slot look and fill_info cards on hover; the
  kit is asked of their own machine (Duel.ask_kit -> _want_kit / _kit RPCs, item refs as SaveGame's).
- Duel (`scripts/game/duel.gd`, /root/Net/Duel made with the local captain by Duel.ensure, so the RPC path is the same
  everywhere; it names no game class or autoload: hitbox.gd and the tests compile it before the autoloads exist).
  The host keeps `state` = {asks, duels} and sends the whole of it to every captain in the world on each change
  (a late joiner gets the next one); each machine plays its own part from it every frame (`_play`). Timing on the
  shared clock (game time when Net is off, so the stage tests don't drift). Challenge -> the other gets
  "<name> challenges you to a duel" with Y/N and 15 s (`duel_hud.gd`, a parry clang); decline/lapse is told to the
  challenger. Accept: the ring centre is where the answerer stood; 3-2-1-Fight! banners (blips, a clang), the
  opponent's name and health on the HUD's boss bar (show_boss phase 99: no ticks); a captain within 45 m who isn't in
  it sees "A vs B" with the bar as A's share of the pair's health. Fight: on each duelist's machine the opponent's
  puppet hurtbox joins layer 32 (the enemies'), so our blades, shots, skills and enemies_in find it and only it;
  Hitbox lets that one overlap through Net.ignore_overlap (normally another machine's captain decides), route_hit
  sends it to their machine, and Player._on_hit_received takes a captain's blow only from the duel opponent
  (Duel.foes) and at x0.6 (Duel.soften). Normal co-op stays free of friendly fire (that gate is new: before, nothing
  of a captain's reached another captain anyway). A blow that would finish you (and a guard break's) calls
  Duel.beaten -> spare: HP 0, Downed with dead = true (held down), no died signal (no death, grave, bleed-out or
  respawn). The host's referee: a duelist not standing (their snapshot's HP 0) loses; one 35 m off the ring, gone,
  or 3 minutes: a draw. Result: Victory (+2% of the winner's level's XP, at least 10; GameManager.award_xp on the
  winner's machine only) / Defeated / Draw banners; 3 s later stand_up: released from Downed (like a revive) with the
  health and energy each had when the duel began. Arenas can reuse Duel.spare(p) / Duel.stand_up(p, hp, energy).
- Not done: watchers don't get a second bar (one boss bar on the HUD); a captain who joins mid-duel sees it from the
  next state change; a damage-over-time tick that doesn't name the opponent as its attacker can still really kill.
- Files touched outside the new ones: player.gd (_ready adds the menu; _on_hit_received's gate and two beaten()
  calls), hitbox.gd (one condition), hurtbox.gd (Duel.blame: a skill's blow on a duel opponent "from" our
  PowerComponent's BlastOrigin proxy is sent as ours, or their machine couldn't tell it came from the duel and it
  would land at full strength, maybe killing for real), stage.gd (opt `crew`: stand-in puppets with net ids 2, 3...), netclient.gd /
  nettest_node.gd (mode duel).
- Guests' requests are their own RPCs (_want_challenge / _want_answer, the sender is who asks); the host calls
  _challenge / _answer directly (a sender check there broke when the host answered inside another RPC's handler).
  A session starting or ending clears the state.
- Tests: t/coop meet_menu, duel_win, duel_lose, duel_decline; nettest.ps1 duel (host vs guest). Render:
  tools/dev/duelshot.gd (prompt, menu, Inspect with a card, challenge, countdown, fight bar, Victory).
- Seen on the way (not this feature, fails on main too): t/combat/cutlass_combo "after a long pause, combo restarts"
  fails since tests run --fixed-fps 60: Player.remember_combo times the 0.9 s combo memory on the wall clock, and a
  fixed-fps run outpaces it.
## 2026-10-14: instruments and the jam (v1.13)
- Zach: instruments you buy, one equipped at a time, played from an emote, a tune at random; a nearby captain playing
  makes yours pick the same tune and join at the same spot, all instruments syncing into one song (Sea of Thieves).
- Items (`scripts/items/instruments.gd`, Instruments): concertina, fiddle, tin_whistle, bodhran, hurdy_gurdy, made in
  ItemDB._load_all (like weapons) as GEAR for a new "instrument" slot (Gear.SLOTS / SLOT_KEYS: the look key
  "instrument" names the kind, so a crewmate's puppet knows it from the look; bare = "none"). Saved by id
  (SaveGame.item_ref skips the gear ref for them). Inventory: an INST slot right of MAIN/OFF; the card says how to play.
  Never in the starting kit. The Salted Gull (gus) sells whistle 35, bodhran 60, concertina 110; a chain island's
  trader has one 45% of the time, +15% (`trader_stock(trade_id)`: its own rng from the shop key, so the island's
  rng and everything after it are unchanged). Icons: `WeaponDesigns.mesh_icon(mesh, view, turn)` (the weapon icon
  rasterizer, now for any mesh and side; weapon icons unchanged).
- Models (MeshBuilder; tris/surfaces: concertina 744/6, fiddle 688/5, whistle 142/3, bodhran ~700, gurdy ~900): a
  hex concertina (button ends, a strap, red leather bellows as a unit-length loft Jam stretches), a fiddle (extruded
  body, f-holes, fingerboard, pegs, scroll) and its bow, a brass whistle with a green head, a bodhran (16 rim staves,
  tacks, a painted skin, the cross-bars inside) and tipper, a hurdy-gurdy (extruded body, keybox with keys out of the
  far side, the wheel's cover, strings, a carved head) and its crank. Carried (Jam.BACK, torso space): fiddle and
  gurdy slung diagonally on the back, the concertina and bodhran flat on it, the whistle in the belt at the front
  right; 5 cm further out over an axe on the back.
- Playing (`scripts/items/jam.gd`, Jam, the Player's child "Jam" on every machine incl. puppets): the emote wheel adds
  "Play" (or "Stop") while one is worn (`entries`, rebuilt on opening). start(): sheathes, holds "music_<kind>"
  (`scripts/npc/instrument_poses.gd`: the stance, a sway every two beats and the right foot tapping each beat from the
  body's meta "jam_beat"), places the instrument in torso space (head space for the whistle) and IKs both hands onto
  it after the pose every frame (process_priority 10, eased in over 0.3 s): bellows open and close over a bar, a
  down/up bow a beat, the tipper rocking a stroke per sub-beat, the crank 0.75 turns a beat, fingers moving on the
  keys/neck. Stops on moving, any other action (attack, dodge, draw, emote), a state other than Idle/Move, a hit,
  or taking the instrument off.
- The jam: a stem per instrument per tune, all sample-aligned and the same length, played from an
  AudioStreamPlayer3D (SFX bus, unit 8, max 55 m) at `where() = (Net.time() - t0) mod length`. Alone: a random tune,
  t0 = now. A captain playing within JOIN_R 20 m: their tune and t0, faded in over FADE_BEATS 2. Every machine plays
  every jammer's stem from the shared clock, so the band is in step everywhere; drift > 12 ms is pulled in by pitch
  (at most 1.2%), a slip > 0.15 s (a hitch) jumps to place on the next bar line. Co-op: Net.event(Jam, "jam" [kind,
  tune, t0] / "stop"), resent every 3 s so a late joiner picks it up; the pose rides the usual Humanoid hold event.
  Ducking: the local Jam adds an AudioEffectAmplify "JamDuck" to the Music bus (after Settings' compressor) and moves
  it to -12 dB while anyone within DUCK_R 30 m plays (24 dB/s down, 8 up); reset when the captain leaves.
- Tunes (gen_psx_music.py `jam`, JAM_TUNES; Instruments.TUNES mirrors them): The Brinehollow Lass (jig, 6/8 G, dq
  92, AABB 32 bars, 41.7 s), Haul Away the Morrow (hauling shanty, 4/4 D mixolydian 100, verse + chorus 16 bars,
  38.4 s), The Drowned Bell (waltz, 3/4 E minor 120, ABAB 32 bars, 48.0 s), Rum and Rigging (polka, 2/4 A 116, AABB
  32 bars, 33.1 s). Everyone plays the tune, as at a session: whistle (cuts on long notes; an octave up in the jig and
  polka), fiddle (double stops under long notes), concertina (the tune over a left-hand bass and chords), gurdy (the
  tune over a seamless drone layer and the trompette's buzz on the off-beats), bodhran (open strokes tuned to the
  chord root, rim taps, a triplet into each part's end). New voices: whistle, gurdy, trompette, bodhran, bodhran_rim.
  Each stem levelled alone to -20 LU (bodhran -22), so a full band is ~5-6 dB louder than one player. 20 files,
  3.52 MB (assets/audio/jam/<tune>_<kind>.ogg).
- Tests: t/items/instruments, t/jam/play_solo, t/jam/join (a puppet stand-in as the crewmate); nettest mode `jam`
  (net-jam, not run here: feature agents don't run nettest). Renders: `jamshot` (tools/dev/out/jam/v113_*), modelshot
  `Instruments.mesh("<kind>")` (tools/dev/out/models/i_*).

### Fixes after --fixed-fps (2026-10-15)
- Wall-clock timers moved to game time (physics ticks): the combo memory (Player.remember_combo / next_combo_index),
  PlayerState.now_s (heavy fatigue, gun reload) and the InputBuffer window. A fixed-fps run, a hitch or slow motion no
  longer skews them.
- techtest "deadeye lands": not a clock bug in Deadeye. The grunt parked 10 m out stood in ~1.1 m of water, and the
  wave phase of the game-time clock tipped it into SWIM (it swam 2.4 m/s off the line during the wind-up). The case is
  now 8 m, on the beach.
- Duels: Duel.beaten(p, dmg) no longer needs the attacker: any lethal damage to a fighting duelist (a sourceless
  bleed/burn tick, a fall) is "downed, not dead". Test: t/coop/duel_bleed.
- Test-infra fixes (with `--fixed-fps 60`, frame delta runs ahead of wall time): savetest's 60 s "world loaded" wait now
  counts wall time (the loader thread and scene build take wall seconds, 60+ under load; game itself unaffected, the
  loading screen polls the thread per frame with no timeout). progtest's second pistol shot waits for the first
  Shoot state to end before the buffered input is consumed (InputBuffer's 0.15 s window is wall time). Stop-GodotJob
  ignores a taskkill failure only if the process had already exited, otherwise throws.

## 2026-10-15: rig drift fix (arms stretching until a re-equip)
- Humanoid.reach_hand (two-bone IK: instruments, off-hand on rifle/axe/scabbard, swings) wrote the arm's global basis with a scale. Under a squashed pivot or non-uniform parent scale that left the arm a lasting local scale (the animator only sets rotations, and Ragdoll.add_part copied it as rest_scale, so knockdowns kept it). It now sets the arm's local rotation only.
- Second source: Ragdoll.restore_rig left the ragdoll processing, so one more drive() that frame wrote global transforms over the restored rig (the hips came back 1.3 cm off after a get-up). restore_rig now stops the ragdoll first. Test: t/player/rig_drift (squashed body + reach_hand, instrument, sword swing, knockdown/get-up, in water).
## 2026-10-15: stance and parry polish (v1.14)
- Zach (after playing): twin daggers lower and wider; one dagger's off hand was up and looked weird (lower, out at
  the side); dual swords too forward and upright (lower, blades down); the dual sword / dagger / twin dagger
  blocks and parries were odd and boring.
- Stances: `Humanoid.STANCE_LEGS` (stance -> standing thigh/shin offsets + hip drop, the drop worked out from the
  thigh 0.42 / shin 0.46 so the feet stay down); "" and "fist" are the old values. Twin daggers: hips 0.22 down
  (was 0.125), feet wider, chest leaning 0.28 (DUAL_GUARD). Dual swords: hips 0.165 down, `WieldMoves.dual_guard`
  elbows in, right blade a little above level, left lower and out (was both blades up ~50 deg, arms out front).
  One dagger: GUARD's off hand low and out at the side (arm_l 0.45/0.15/-0.45, fore 0.7). Speeds unchanged.
- Blade aiming: `DaggerMoves.wrist_to(arm, fore, dir)` returns the wrist that points a blade along a chest-frame
  direction (a reversed off-hand dagger takes -dir); `DaggerMoves.aim(pose)` turns a pose's "blade_r"/"blade_l"
  into wrists. Hand x alone can only tilt a blade in the forearm's plane; blocks need sideways blades.
- Blocks (`Humanoid._block_pose`, guard_block): dual swords an X in front of the face (`WieldMoves.DUAL_X`), one
  dagger a catch by the face with the blade laid down along the forearm and the off hand bracing the wrist
  (`DaggerMoves.BLOCK_ONE`), twin daggers wrists crossed low, blades flared out of the cross (`BLOCK_TWIN`).
- Parries: `ActionSpecs.PARRIES` {stance: [parry pose, flourish]}; Humanoid "parry" plays the stance's pose
  (dual: right blade slanted up across the front; one dagger: the catch snapped up; twin: twisted away, the left
  blade along the forearm before the face, the right chambered at the hip). ParryState plays the flourish when a
  parry lands (0.42 s, mirrored by play): dual sweeps the blow out to the right and drives the left blade in, one
  dagger knocks it wide with the off hand shoving in, twin untwists, sweeping it out left with the right point
  snapping in low. The parry window, recovery and block timing are unchanged.
- Previews: ActionSpecs `*_stance` (the stance itself), `*_block` (the held block), `*_parry`, `*_deflect` per
  style for animsheet. Renders: tools/dev/out/anim/v114_before_y{125,90,180,330}_* and v114_after_y*_*,
  v114_after_walk_*. Tests: t/weapons, t/combat, daggertest, wieldtest.

## 2026-10-15: v1.14 step 1, the Brinehollow benchmark (measured, nothing fixed yet)
- Zach, v1.13 on a Ryzen 5 5600G + RTX 3080: 20-30 fps in Brinehollow. His F8 on the way to Grell's den: 47.6 ms,
  PROCESS 46.6, PHYSICS 8.7, RENDER CPU 13.3, GPU 0.9, 5057 draws, 1837K prims, 17975 nodes, 129 enemies. CPU-bound.
- Tools: `tools/dev/bench_brinehollow.gd` (a real window, vsync off, 1920x1080, ~5 min), run through
  `tools/dev/bench.ps1` (holds every test slot so no other session's suites run beside it, then lets them go) and
  compared with `tools/dev/bench_compare.ps1 <a> <b>`. Chain seed 4242 (TK.use_seed), waits until the chain islands
  ahead are built and manned + 20 s: 2 chain islands, 204 enemies, 30.2k nodes (a heavier world than Zach's). Eight
  stops (wake beach, plaza, market, quay, dock, foot of the den climb, training yard, aboard the moored sloop); at each
  the gameplay camera rig pans a full turn per phase: base (5 s), probe (every processing script's node taken off the
  engine and called by the bench in the engine's order, timed per node, so per script and per distance band from the
  captain; rigs posed per frame), ablations (far: enemies, villagers, enemy ships past 120 m set PROCESS_MODE_DISABLED;
  sun shadows off; local light shadows off; local lights hidden), base2 (ablations compare with the mean of base and
  base2). Each frame is split by timeline marks (the bench script runs first in each pass, a BenchLate node last, plus
  RenderingServer frame_pre/post_draw): phys_scr (the scene's physics pass, all ticks), phys_eng (Jolt step + sync),
  proc_scr, tail (timers, tweens, transform notifications, deferred calls), draw (RenderingServer.draw), present.
  frame1t = the frame with exactly one physics tick: the stable number to compare (frame swings ~10% run to run on
  the laptop, frame1t ~5%). Also: visible geometry by piece (surfaces, without visibility range, casting shadows),
  collision by owner, an enemy census. Results: `tools/dev/out/bench/brinehollow_<label>.txt` (not committed).
- Gotcha: Godot's TIME_PROCESS / TIME_PHYSICS_PROCESS (the F8 PROCESS / PHYSICS) are the worst of the last second and
  PROCESS includes RenderingServer.draw, so PROCESS ~ frame time says little about scripts.
- v1.13 results (i7-14700HX laptop, RTX 4060, pixelated, d3d12; mean of the 8 stops):

  | run | frame | p95 | frame1t | ticks | scripts/tick | Jolt/tick | process | tail | draw (rcpu) | GPU | draws vis+shadow |
  |---|---|---|---|---|---|---|---|---|---|---|---|
  | 13:00 clear | 42.3 | 50.5 | 29.1 | 2.54 | 5.6 | 3.0 | 8.4 | 4.6 | 6.7 (2.9) | 2.5 | 1135 + 912 |
  | 21:00 clear | 35.9 | 46.6 | 26.6 | 2.16 | 5.3 | 2.8 | 7.4 | 4.0 | 6.3 (2.7) | 1.9 | 1124 + 1056 |
  | 13:00 rain | 32.1 | 47.6 | 25.5 | 1.98 | 4.8 | 2.6 | 7.4 | 3.8 | 6.2 (2.8) | 4.1 | 1147 + 913 |

  (the rain run's lower CPU numbers are the laptop's state, not the weather: RainFX itself is 0.17 ms.)
- CPU-bound, confirmed (quick runs back to back, 13:00 clear): d3d12 frame1t 21.6 ms / GPU 4.2, Vulkan 20.3 / 3.7,
  pixelation off (3D scale 1.0) 21.1 / 4.9. Neither the driver nor the pixel grid matters. The same quick run was
  37.9 ms (frame1t 27.5) a few hours earlier on the same laptop: compare before/after only from runs taken back to
  back, and look at frame1t. (One earlier Vulkan and pixelation-off pair showed repeated ~140 ms stalls inside the
  draw; not seen again on the repeat.)
- The physics spiral: at 24 fps the game runs 2.5 physics ticks a frame, so every ms per tick is paid 2.5 times (8.6 ms
  per tick = 21 ms of a 42 ms frame). Zach at 21 fps runs ~2.9 a frame. frame = (frame1t - tick) / (1 - tick / 16.7).
- Ranked costs (13:00 clear, frame1t 29.1 ms):
  1. Far actors, -13.5 ms frame1t (-26.8 ms real frame: 42 -> 15.5 ms, 24 -> 65 fps): nothing sleeps by distance but
     fauna (FaunaSpawner LOD) and beasts (dormant). Grunts 2.26 ms (2.13 of it past 120 m; physics AI + move_and_slide
     every tick), scuttlebugs 2.23 (2.06), canopy spitters 0.86 (0.84), enemy ships 0.86 (all far) + their 40 cannons
     0.16, grunt rigs 0.34, villager.gd 0.14, plus Jolt -1.7 ms/tick, tail -2.6 (moving rigs' transform
     notifications), draw -0.6. 79 of 204 enemies process physics; 27 grunts, 25 scuttlebugs, 19 spitters, 6 ships.
  2. The tick multiplier above: 8.6 ms per tick (scripts 5.6, Jolt 3.0).
  3. Jolt 3.0 ms/tick: 205 character bodies, 720 areas (394 monitoring: 215 hurtboxes, 173 interactables), 6 enemy
     ships (198 shapes) and 10 moored hulls (182 shapes) moved every tick, 13.1k shapes (9k static chain-island
     vegetation colliders).
  4. Main-thread draw 6.7 ms (rcpu 2.9) for ~1135 visible + 700-1250 shadow draws. 10,981 visible surfaces in the
     world, 7,333 with no visibility range, 8,444 casting shadows; a humanoid is ~29 surfaces (141 rigs ~ 4k), the
     scuttlebug nest 220, the spitter roosts 180. Sun shadows off: draw -0.8, rcpu -0.7, GPU -1.0..-1.4 ms.
  5. Tail 4.6 ms (2.6 of it the far actors).
  6. Near rigs: ~0.2 ms per fully posed humanoid (town NPC rigs 1.0 ms mean, 2.5 at the market; the player's 0.46;
     npc.gd 0.43 for all 32, near or not; arm_body + lower_body 0.6).
  7. Per-frame systems: Ambience + CoastProbe 0.50, SkyBirds 0.38 (0.10 at night), CloudSpawner 0.30, Weather 0.24,
     SeaSpray 0.22 (0.29 rain), RainFX 0.17 (rain), HUD 0.12, InventoryScreen 0.10 while closed, 78 NightLights 0.05.
  8. Local lights: up to 15 omni lights in view at 21:00, none with shadows; hiding them all is within noise.
- Proposed fix areas (separate files, at most 3 at once):
  A. Sleep far actors (first): pirate_grunt, scuttlebug/canopy_spitter, enemy_ship (+cannon), npc.gd, grunt_camp /
     scuttlebug_nest as the owners, island-level sleep like FaunaSpawner._update_lod, all captains (Net.all_players),
     the host only. Measured -13.5 ms frame1t.
  B. Draw calls: visibility ranges on kit pieces, fewer surfaces per humanoid (body_builder), MultiMesh / merged nest
     and roost props, cast_shadow off for small props. Estimated -2..-3 ms main-thread draw, -0.8 ms with fewer
     shadow casters.
  C. Physics + per-frame systems: hurtbox / interactable monitoring, moored hulls moved only near, NPC StaticBody
     moved per frame, max_physics_steps_per_frame to bound the spiral; Ambience / SkyBirds / CloudSpawner / Weather /
     SeaSpray throttled. Estimated -0.5..-1 ms per tick, -1 ms per frame.
  Later: near-rig animation LOD (humanoid.gd, spring chains), sun shadow distance.

## 2026-10-15: v1.14 area C, physics and per-frame systems
- `physics/common/max_physics_steps_per_frame=4` (was Godot's 8): below 15 fps the game slows instead of
  running ever more ticks a frame. Tests run `--fixed-fps 60` (one tick a frame), so they don't feel it.
- Hurtbox (`_init`: monitoring off, `_ready`: mask 0) and Interactable (`_init`: monitoring off): hitboxes,
  projectiles and the captain's InteractionComponent do the finding; nothing read a hurtbox's or an
  interactable's own overlaps. Areas monitoring in Brinehollow: 394 -> 6. Hitboxes already monitored only while active.
- MooredHull: rides the swell within NEAR 80 m of a captain (group "players") or the crew's ship, holds still past
  FAR 90 m (checked every 15 ticks, staggered by instance id): no kinematic moves, no transform notifications down
  its model. A frozen hull keeps its colliders (pirates or loot on a far deck don't fall through).
- Per-frame systems, same look and sound: CoastProbe a bearing every 0.07 s (a sweep in ~1.1 s, one reused ray
  query); Ambience sets the underwater low-pass only when it changes; SkyBirds steers birds behind the camera or
  past DRAW one frame in three (with the time they missed), the flocks' angles move in _process, the dead-bird
  filter only when one died; PuffClouds re-sorts every 0.15 s (was 0.05); Weather's blend, sun, sky/fog colours,
  ocean colours and 3D-cloud look every 0.1 s (every frame while a flash or the cloud whiteout changes), the sky's
  cloud_time and the cloud shadows' drift still every frame; SeaSpray checks the coasts for a breaking crest every
  0.06 s and filters streaks/foam in place; RainFX lays out puddles when the camera moves a metre, cells are still
  to be judged or every 0.25 s; the HUD's clock/FPS text every 0.25 s; InventoryScreen processes only while
  visible in the tree (GameMenu hides its root, not the screen, so it ran all game).
- Measured (bench.ps1, 13:00 clear, back to back: main `c_before`, this branch `c_after`; mean of the 8 stops):
  frame 24.54 -> 21.04 ms, frame1t 21.38 -> 19.50, ticks/frame 1.48 -> 1.28, scripts/tick 4.45 -> 4.13,
  Jolt/tick 2.28 -> 2.18, proc_scr 6.10 -> 5.20, tail 3.17 -> 2.98. Per script (ms): ambience 0.40 -> 0.22,
  sky_birds 0.32 -> 0.26, weather 0.18 -> 0.08, sea_spray 0.17 -> 0.14, cloud_spawner 0.14 -> 0.06, moored_hull
  0.15 -> 0.08 (most hulls are within 80 m of the town's stops), player_hud 0.08 -> 0.07. The monitoring areas
  were worth only ~0.1 ms of Jolt per tick; Jolt's cost is the far actors' character bodies (area A).
- Tests: t/items/quiet_areas (no hurtbox/interactable monitors; the chest's prompt, F and a swing still work),
  t/ship/moored_hulls (rides near, holds still far, rides again).
## 2026-10-15: v1.14 area B, draw calls and shadow casters
- Bench (13:00 clear, main then this branch back to back, mean of 8 stops): frame 24.6 -> 22.4 ms, frame1t 21.4 -> 20.1,
  main-thread draw 4.77 -> 3.70 (rcpu 2.25 -> 1.57), GPU 3.9 -> 3.6; draws visible 1137 -> 745, shadow 920 -> 489
  (total 2129 -> 1307, -39%). Brinehollow renders (islandshot plaza/market/street/aerial/far, day and 21:00,
  `tools/dev/out/drawlod/`) look the same; the F8 overlay at the plaza reads 3733 -> 2306 draws.
- Tint folding (`MeshBuilder.fold_tints`, `PSXMat.fold`): every plain `PSXMat.lit` surface moves onto its texture's
  white twin (opts + `vc_srgb`) and its tint goes into the vertex colours, sRGB-encoded (shader `vertex_srgb` decodes
  in vertex()), so a mesh is one surface per texture, not per tint, and every body shares those materials. Only the
  cached material folds: an object's own copy (scuttlebug, beasts, dummy: tint_mul flashes) stays. Not folded: glow,
  decal, no-vertex-colour materials. Gotcha: code that finds a surface by material identity (ship.gd's deck/hull) or
  reads albedo_color back (weapon icons) must not be folded; the island pass skips anything with a material or
  surface override (it would multiply the baked tints).
- Bodies (BodyBuilder): every part's builder folds; the rigid shin parts (cuffs, footwear) join LowerBody's skinned
  mesh on SHIN_L/R and the forearm parts (NPC hands, cuffs, bracers) join ArmBody's MeshL/R on FORE_L/R
  (`MeshBuilder.rebind`; the skinned setups run once every part is in, `_skin_into`/`_skinned`). A severed arm's bake
  carries its hand. 23.3 -> 14.9 surfaces per body (61 looks; worst 30 -> 18). Every body part ends at
  `BodyBuilder.RANGE` (220 m) x height. r9test's scalp check reads the vertex colours.
- `DrawLOD` (scripts/psx/draw_lod.gd), run once a place is built (end of StarterIsland.build, GenIsland's last finish
  steps in ~12 ms slices, Redtide): folds each MeshInstance's mesh (shared meshes once; only when it saves a surface),
  gives a visibility range to whatever set none (130 m per metre of size, min 45, glow x3, none past the camera's
  1200 m far: ~2 px on the 640x360 grid), and turns shadows off under 0.9 m. Humanoids and CharacterBody3Ds are
  skipped. `DrawLOD.creature` gives a nest's bugs and spitters ranges by part. Brinehollow's islanddump changes only in
  mesh surfaces, cs and vr (367 lines; transforms, colliders, everything else identical).
- Sun (world.tscn): shadows to 80 m (was 120), split 0.3, fade from 0.8. Turning sun shadows off now saves 0.35 ms of
  draw (was 0.64) and 496 shadow draws (was 929).
- Fog banks: 60 billboard puffs each as one MultiMesh (was 60 nodes).
- Not done: OccluderInstance3D in the town (occlusion culling rasterises on the CPU, the camera is high and behind,
  and the project setting is C's project.godot); MultiMesh for the nest/roosts (they're animated creatures: ranges
  instead); other repeated props as separate nodes are few (drawcount's list).
- Tool: `tools/dev/drawcount.gd` (headless): `world` = draws by piece with ranges/shadows, `bodies` = per body.
- Tests: chartest (60 looks <= 20 draws, mean <= 16.5; every part's range), isletest (the draw pass ran on a chain
  island and Brinehollow), r9test, villagetest, harbourtest, fidelitytest, lighttest, cliptest, bugtest, seatest,
  hairtest, qoltest, katanatest, foresttest, t/player. Renders: islandshot before/after, wardrobeshot, armorshot,
  goreshot.
## 2026-10-15: v1.14 A, far actors sleep (ActorSleep)
- `scripts/world/actor_sleep.gd` (ActorSleep, a node under /root made by the first actor): grunts (and Morrow, apes),
  scuttlebugs, spitters, the brood queen, enemy ships and NPCs/villagers call `ActorSleep.add(self)` in _ready and
  say when they may sleep (`sleep_ok()`: grunt idle or walking home, not a boarder, no ragdoll; bug wandering or a
  spitter up its tree; ship on patrol with nobody aboard; NPC not talking). Asleep = `PROCESS_MODE_DISABLED` on the
  actor: no AI, no move_and_slide, its body and hurtbox out of the physics space (nothing can target it), no rig,
  timers and state clocks stopped (it wakes exactly where and how it was; patrols don't fast-forward). People sleep
  past 160 m from every captain and wake within 120 (hysteresis), hidden past 230 (shown within 210); ships sleep past
  420 and wake within 340 (beyond NOTICE 150 / LOSE 240) and stay in sight. A slice of the actors each frame (15).
  Per actor, not per camp: alert_all only reaches campmates within 22 m, all well inside the wake range.
- Villagers: judged by where their routine has them now (`Villager.sleep_pos()`), so one due near you wakes there
  and its own far tick snaps it to the schedule. `set_meta("no_sleep", true)` holds an actor awake (seatest's ships,
  moved about by hand). `ActorSleep.enabled = false` wakes everyone (the bench's `nosleep` arg).
- Co-op: the host decides. Asleep = `net_idle` (no snapshots). A guest's puppet sleeps once the host has sent nothing
  for 0.6 s and it's past the wake range, and wakes on a fresh snapshot. When a captain is put in (Net.players grows)
  the host sends its sleepers for 3 s so the newcomer's copies stand where the host's dozed off (not where they were
  built); every actor gets one round awake first so a puppet takes that snapshot. A guest's copy of a sleeping pirate
  ship stops dead-reckoning once the word is 0.5 s old (it used to run ~5 m ahead before dozing off). Known gap: a
  chain island built on a newcomer after that burst shows its moved sleepers where they were built until they wake.
- ShipCannon: an enemy's gun at rest skips its per-frame aim/recoil writes.
- Bench (laptop, back to back, `A_nosleep` vs `A_sleep`, 13:00 clear): frame 25.65 -> 10.72 ms (39 -> 93 fps), frame1t
  21.94 -> 11.42, ticks/frame 1.54 -> 0.65, scripts/tick 4.56 -> 0.91, Jolt/tick 2.35 -> 0.94, tail 3.19 -> 1.48, draw
  4.86 -> 4.04, GPU 3.97 -> 2.22. The `far` ablation left after it: -0.3 ms (was -14.9). ActorSleep itself ~0.1 ms.
  (The laptop was faster than the v1.13 runs today: 25.7 ms with nothing asleep vs 42 then.)
- Tests: `t/world/actor_sleep` (stage: sleep 650 m off, frozen, hysteresis at 140 m, wake in place with the clock
  where it stopped, hurtbox out/in, net_idle, hide/show, a boarder never sleeps, enabled off); nettest checks a
  guest's puppets sleep with the host's (Brinehollow's) and stand where the host's are. lifetest picks a walker near
  the village. seatest's "water in her: she sits lower" fails on main too (0.16 m), not this.
- Test fixes (both were test measurement/isolation, the game was right): seatest's "water in her: she sits lower"
  averaged her height over 1.5 s dry and 1.5 s flooded, shorter than a swell period (the solo swell has been on
  game time since d66622a, so the phase was the same unlucky one every run: 0.16 m against the true 0.34 m of
  0.6 x flood); it now averages 15 s each and is off flaky.txt. r8test's Morrow checks ("he dashes past", "Red
  Tide", "everyone left") failed under load because the fort's three gate guards (`fort.guards`) were still alive
  and walked into the fight, hitting the captain mid-lane and keeping Morrow "in combat"; the test now clears them
  before the boss fight. (Reproduced by running r8test with five other suites at once.)
- 2026-10-15 fix pass: the bench "hang", the "weird fog" in Brinehollow and F8's ENEMIES 0 were one thing, main's
  stale import cache: .godot/global_script_class_cache.cfg was written 13:30, ActorSleep landed 13:36, and nothing
  that runs Godot outside the editor and the runners imports. So ~25 scripts failed to parse (grunts, bugs, NPCs,
  enemy ships and everything that names them, gen_island, kit pieces): no enemies or villagers, the captain started
  on the plaza, SeaFeatures had no data so Weather._update_slow errored at local_weather before it set the sun, sky
  and fog (world.tscn's default environment: the pale haze over the near houses), and the chain islands' prepare
  tasks never finished. The bench waited 240 s for them, gave up, and quitting then blocked in
  WorldGenerator._exit_tree's wait_for_task_completion on those 2 tasks: the frozen window, ~0 CPU after ~230
  CPU-seconds. Reproduced with main's own cache (twice, the hang at the same wait; screenshots match Zach's).
  With a current import the bench finishes (main, B+C before A, v1.13). Players can't hit it: an export bakes its
  class list and the editor rescans; it hits only CLI runs (bench, renders) in a checkout that missed an import.
  Fixes: bench.ps1 runs Update-ImportCache first; land.ps1 refreshes the target checkout's import after the
  fast-forward (main is current for the bench, renders and Zach's runs). The bench now prints `bench: <stop>
  <phase>`, a watchdog thread names the stop/phase/island build step of a stalled frame, it saves a screenshot per
  stop and bench.ps1 keeps the whole Godot log (`out/bench/brinehollow_<label>.log`). F8: "enemies N awake / M
  asleep" (awake = processing physics: ActorSleep's sleepers and creatures in their distance LOD count as asleep;
  the perf log line too); t/world/actor_sleep checks the counts. Windows glowing at 13:00 are as in v1.13.
  Bench after (laptop, mean of 8 stops; v1.13: 42.3 / 29.1 ms at 13:00): 13:00 clear frame 9.23 ms, frame1t 10.18,
  ticks 0.56, GPU 1.79, draws 714 + 489 shadow; 21:00 clear 9.29 / 10.29 / 0.56 / 1.80 / 715 + 588; 13:00 rain
  10.05 / 10.95 / 0.60 / 2.07 / 767 + 518. Tests: t/world, perftest, smoketest, isletest.

## 2026-10-15: flipbook particles (pilot)
- `FX.flipbook(pos, sheet, amount, size, life, cfg)`: a `_burst` whose particles each play
  `assets/textures/fx/flip_<sheet>.png` once over their life (StandardMaterial3D particles anim 4x4, no loop,
  CPUParticles3D `anim_speed` 1 = one sheet per life, `anim_offset` for a random start, `angle` for a random roll,
  a hold-then-fade colour ramp with an optional fade-in, size curve "flat" by default). NEAREST_WITH_MIPMAPS, one
  shared material per sheet. cfg "lit": smoke dimmed by Weather.night (unshaded smoke glowed white at 21:00).
- Sheets from `tools/texture_gen/gen_flipbooks.py` (16 frames of 64 px; noise-warped lobes, the noise scaled with the
  puff so it billows instead of flickering; palette-stepped colour, alpha on 4 levels with a Bayer dither): `smoke`
  (grows, then thins along the noise) and `explosion` (a star flash, a fireball cooling from the rim in with hot
  pockets inside the soot, embers thrown out, then rising smoke). Imports: mipmaps on, compress_to 0.
- The pilot swaps two effects, all behind `FX.flipbook_pilot` (true; false = exactly the old calls; renamed
  `FX.flipbooks` with the library, below):
  the ship's cannon (`FX.cannon_fire` from ShipCannon._shoot, `cannon_hit` / `cannon_splash` from Cannonball: a
  fireball and a bank of smoke at the muzzle, a bigger fireball + smoke + embers on a hull, a plume of white water on
  the sea) and a heavy blow's dust (`FX.heavy_dust` from HeavyAttackState's impact and DownedState's landing thud,
  through Net.fx: half the old dust ring plus a ring of flipbook dust puffs). Sparks, flashes, splashes and foam
  rings stay.
- Cost per effect (bursts / particles, before -> after; one burst = one draw): heavy dust 1/16 -> 2/13, cannon
  fire 3/34 -> 3/23, hull hit 5/39 -> 6/27, sea hit 2/16 -> 2/14. Two 256x256 sheets (~0.7 MB with mips).
- Renders: `tools/dev/flipshot.gd` (before/after strips at the pixel grid; compare_heavy, compare_cannon,
  compare_cannon_h21 in tools/dev/out/flipbook/). Test: `t/fx/flipbook`.
## 2026-10-15: v1.14 lessons locked in (the perf gate, performance rules, the wall-clock lint)
- **The perf gate** (`tools/dev/perf_gate.ps1`, run by `prepush.ps1 -Release` after the tests, i.e. before tagging a
  version): the Brinehollow bench in its new `gate` mode (settle, base, probe at the 8 stops: the summary and the
  scripts table, no ablations; ~2.8 min a run) against `tools/dev/perf_baseline.txt` (committed: per stop frame,
  frame1t, ticks, draws, shadow draws, the ALL row, each script's ms, the commit and the machine's calib).
  - Noise: frame swings ~10% run to run on the laptop, frame1t ~5%, and the laptop's state far more over hours
    (v1.13 measured 42 ms one morning and 25 ms at 10:38 on the same code). So each light is benched twice and
    each stop keeps its best numbers (interference only adds), and every bench prints `calib`: a fixed GDScript
    workload (best of 5), steady within ~3% across today's runs (23.6-24.4 ms).
  - Fails (exit 1): the mean of the stops' frame or frame1t >15% worse, one stop's frame1t >35% worse (a local
    regression the mean dilutes; one stop swung 22% between passing runs of the same code, best of 2 each), or the mean physics ticks a frame >0.8 (the spiral). Prints each stop (base,
    now, d%, ticks, draws) and the scripts whose ms grew most.
  - A fail, or a calib >15% off the baseline's (another power plan, heat: not comparable), is confirmed by
    benching the baseline's commit back to back in a temporary worktree (%TEMP%\driftwake_perfref_<sha>, imported
    by bench.ps1, removed after) and judging against that. `-NoConfirm` skips it; `-Update` rewrites the baseline
    (commit it; it records HEAD, so commit game changes first). `-Hours`, `-Runs`, `-BenchArgs` (to both sides).
  - Baseline (laptop i7-14700HX + RTX 4060, d3d12, best of 2): 13:00 clear mean frame 9.41 ms, frame1t 10.36,
    ticks 0.57, draws 714 + 490 shadow; 21:00 clear 9.27 / 10.20 / 0.56. Target: <= ~10 ms mean frame here keeps the
    min-spec PC (Ryzen 5 5600G + RTX 3080) at 60 fps in Brinehollow.
  - Proof: on this branch (main + the lint fixes) both lights PASS (13:00 mean frame 9.58 / frame1t 10.51, +2% /
    +1%; 21:00 9.41 / 10.35; worst stop +22% frame1t at the 21:00 plaza, hence 35% per stop; 13 min). ActorSleep
    disabled in a scratch edit: FAIL, frame 9.41 -> 21.96 ms, frame1t +98%, ticks 1.32, every stop flagged,
    scuttlebug.gd +1.64 ms, pirate_grunt.gd +1.62, canopy_spitter +0.60, enemy_ship +0.47 on top of the list;
    confirmed against the baseline's commit benched right after (9.54 ms there; 14 min with the import).
- **CLAUDE.md:** "Game time, never the wall clock" in Rules that bite, a Performance rules section (the target,
  per-frame code sleeps far and runs at the lowest rate that looks right, visibility ranges / no small shadows /
  MultiMesh / shared materials, areas monitor only if read, bench before/after, `prepush.ps1 -Release` before a
  tag); two lines of it in `.claude/agents/driftwake-feature.md`.
- **The wall-clock lint** (in `tools/dev/compilecheck.gd`, so the edit hook, run_tests' compile step, finish.ps1
  and land.ps1 all run it): `Time.get_ticks_*`, `Time.get_unix_time*`, `Time.get_*_from_system`, `OS` ticks/unix/
  system time in scripts/ or scenes/ fail as `WALL CLOCK <path>:<line> (in <func>)` unless
  `tools/dev/wallclock_allow.txt` lists the file or `file:function` with a reason. A full run names entries that
  match nothing now. tools/ is exempt (savetest's wall-clock timeout, the bench).
  - Allowed (17 entries): Net's session clock, Music.play's resume
    timer, perf_monitor's and dev_capture's dates, save_game's saved_at, save_slot_list's dates, game_menu's web
    pointer-lock Esc, UIStyle.sfx's debounce (menus run paused), Humanoid.play's 250 ms net throttle,
    DrawLOD.steps' 12 ms budget, build timing in world_generator, gen_island, starter_island, island_life,
    kit_context, kit_dungeons, kit_landmarks. (No loading-screen budget or dep_record use exists: nothing to allow.)
  - Fixed to game time: the sprint-start shake debounce and the marker cooldown (PlayerState.now_s()), the grunt's
    peril flash, the bottles' bob and glint (Ocean.clock()), villager barks' shared 8 s gap and a seat's
    NPC-sitting check (physics ticks), Ambience's hull-loop drift and the objective marker's bob (delta),
    Weather's thunder delay (a countdown in delta), ActorSleep's 3 s newcomer burst (delta). The ships' swell
    called `Ocean.clock()` with a wall-clock fallback: now Ocean.clock() only. BuoyancyComponent (unused, old
    wave constants on the wall clock) deleted. Weather's solo session clock (under world_time) is game time now,
    like Ocean's: r9test/r10test's forced storm blends over 8 s of world time but waits 9 s of game time, and with
    the v1.14 world running faster than real time under --fixed-fps they failed on the wall clock (twice in a row
    while landing). Co-op still runs on Net's shared clock.
  - Test: t/world/thunder_delay (thunder 340 m off is still due at 0.7 game s, heard by 1.2; on the wall clock a
    --fixed-fps run outpaces it). Also run: t/world, t/player/sprint, t/player/sit_bench, ambiencetest, seatest,
    lifetest, uitest, skytest, smoketest.
## 2026-10-15: v1.15 shore-aware water (the swell knows where land is)
- Zach: waves that don't make sense for the shore, water coming up through the ground (worst round the den climb).
  The sea was one global wave field: the swell's ~1 m crests rose over low sand and shelves, and on lee coasts it
  ran sideways or away from the beach (Brinehollow's NW beach by the den: the open swell ran straight off it).
- ShoreMap (`scripts/ocean/shore_map.gd`): baked from an island's height grid, a texel per vertex, RGBA half floats:
  r depth (kept under the terrain's triangles: each vertex lifted by its cells' bilinear-vs-triangle error
  |h00-h10-h01+h11|/4 + 3 cm, so filtered depth never exceeds the real depth anywhere), g the swell's phase
  distance offshore (euclidean distance transform to the waterline, box-blurred ~9 m, shortened over the last 30 m),
  b how far the swell has turned (1 inside 14 m of the shore, 0 by 56 m, 0 where the distance field folds and over
  the map's last 24 m), a exposure (open water upwind along the swell, a sweep; a lee shore keeps 0.45).
  Brinehollow bakes at load (~140 ms, main thread), chain islands in prepare on the worker (`build_ms["shore"]`,
  250-580 ms under load), islets once (shared texels, `SeaLegs.islet_shore()`). Deterministic from the heights:
  guests bake the same. A new den/cliff terrain is picked up as-is (nothing hard-coded).
- `Ocean.set_shore(key, map, at)` ("brinehollow", "isle<id>", "leg..._islet<i>"); `shore_at(x, z)` (the map nearest
  its shore where maps overlap); the shader binds the 4 nearest the camera (`shore0..3`, `shore_rect`).
  `OceanManager._height` and `scenes/ocean/ocean_waves.gdshaderinc` (shared by ocean.gdshader and shoreprobe) do the
  same: the open swell mixed toward two shore trains (`SHORE_WAVES` 11.5 m / 7.3 m, phase k*g + omega*t plus a slow
  wobble along the coast) by b, the shore trains steepen (crest pow 2 -> 3.2) and grow 25% from 5 m deep to 0.8 m,
  times a; then the envelope and crest cap as before; then everything fades with depth (1 - (1-t)^2 from 2.4 m to
  nothing at 0.05 m). Open sea, ship feel and storms unchanged (amp_mult and storm cells scale it all).
  `swell_dir()`: a train's crests travel against its WAVES heading vector (phase = k dir.p + omega t).
- Surf: the shader's foam bands ride the main shore train's crests (`shore_roll`) in 0.08-2.8 m of water; the swash
  runs up with each arriving crest; turquoise shallows from the map's depth. SeaSpray breaks on `breaker_height`
  (the swell before the depth fade), its threshold and size scaled by exposure. Rain pocks, foam patches, FX rings
  all sit on get_wave_height. F12 captures print the shore sample under you.
- Tests: `shoretest` (new): maps in the sea and identical rebakes; along Brinehollow's, both chain islands' and an
  islet's coasts the sea never over dry ground at amp 1.0 and 1.8 (5-10k points x 30 times each); the most sheltered
  beach (island (-195, -93), next to the den) where the open swell alone ran off it (-0.96) now has crests along the
  beach (slope across/along > 1000) travelling in (0.99); seamless map edge; breakers on the wake beach.
  `shoreprobe` (render tool): the shader's own wave code read back on 64x64 grids at four coast spots vs the CPU:
  worst 3.5 mm. r9test's storm sea point moved off the den (it stood on land). isletest/chaintest/yardtest read the
  new API. Renders: tools/dev/out/shorea_* (after) vs main's tools/dev/out/shoreb_* (before).
## 2026-10-15: Grell's den, a path cut into the cliff (v1.15)
- Zach (reference photo: a ledge path cut into a mossy cliff, a short tunnel, a cable railing, red earth, a drop): the
  slabs sticking out of the sand are gone; the way up is a path cut into the den's sea cliffs, longer and harder.
- `KitCliffPath` (scripts/island/kit/kit_cliff_path.gd), laid out on bearings round DEN from `StarterIsland.DEN_PATH`:
  keys [bearing, radius, floor, half width, headroom, overhang], gaps, the cave, the bridge, the cleft, rails. From the
  beach south of the den (106 deg) clockwise round the west face to a cleft up onto the top (236 deg): ~80 m of shelf
  plus the cleft. One rock mass as a distance field: the cliff band behind the path (leaning out over it where
  `overhang` > 0, its top falling back into the land), the shelf under it (a corbel under the floor, gaps cut through
  with undercut lips), a buttress round the cave room (CaveMesher's hull formula) and the cleft's walls; the room,
  the two short tunnels and the cleft hollowed out. Meshed by surface nets at 1 m on a WorkerThreadPool task started
  right after the heights (~1.4 s there; the den step waits ~0.2 s for it). Facets by kind: red-earth path, turf,
  moss, rock; the cave's walls and floor darker, no shadows. The collider is the trimesh plus a thin box under every
  ~1.2 m of floor, so the lips are exact where you jump.
- Gaps (run jump ~4.3 m flat, sprint ~6.4, double jump adds ~3): 2.3 m (+0.8, over the sand), 2.9 (+0.6), 4.4
  (level, sprint), 3.5 (+0.5), 3.8 (+0.6), then the broken bridge (9.5 m) and its chain. Every gap past 124 deg
  drops to the sea (the terrain under the shelf is cut down to -6.5); from the water swim back round to the beach,
  up a sand ramp (`landing`) cut in at the foot: the old climb's dry-beach band ended in a 4 m underwater bank a
  swimmer couldn't get up (found by the test's swim back).
  Headroom over every lip is >= 4.2 m (an overhang at a lip cut the jump short: found by the test).
- The cave: a room (r 6, 6 m high) in a buttress out over the sea, 5 small scuttlebugs, a cave brute
  (`Scuttlebug.brute`: 1.9x, 110 hp, slate shell, longer rear-up, 24 dmg ram; only a >= 30 dmg knockdown throws it;
  200 XP; no boss bar), 3 spitters on threads from the roof, stalactites (tips >= 3.4 m up) and stalagmites (off the
  way through, colliders on the big ones), lichen and fungus, one always-on light (from the budget). Nest
  `DenCaveBugs`, back after 180 s.
- The broken bridge: posts at both lips, its two chains still slung across with a crossbeam, deck planks hanging off
  the lips, a red rag on the swing chain's ring. `ChainSwing` (scripts/interaction/chain_swing.gd, a SwingRope): F
  at the lip ("Grab the chain"), or jump into it and it catches you; SwingState's rope mode swings you; let go with
  jump or ride it until your feet find the far side. Another captain's swing pulls the chain on your screen.
  Tuned with the test: the cables ride 8.6 m over the floor and the chain is 6.4 m (a low anchor swung you under
  the far lip); a chain's push-off goes all along the swing (`SwingRope.taut`: the old kick went in toward the
  anchor, the rope went slack and the snap taut threw the speed away), and letting go of any swing keeps its speed
  (`player.air_speed`: the fall capped it at a walk while you steered). F-grab and let go lands ~2.7 m past the lip.
- The sea ladder from Grell's pier (`Ladder.lock_flag`): rolled up at the hoist until world flag "den_ladder" is set
  (a `WorldLatch` on the plateau: any captain within 21 m of the fire), then it unrolls. World flags are new:
  `GameManager.world_flags`, saved ("world_flags", a guest keeps its own), set for everyone by `Net.world_flag`, in
  the world state a joining guest gets.
- Grell: `PirateGrunt.hold` [centre, radius] (KitCamps.den `hold_r`, 6.5 m round the fire): deaf to the crew's alarm
  and blind to captains until one is in the circle (any captain: the host checks Net.all_players) or he's hit; then let
  go for good. His crew fights as before.
- Brinehollow elsewhere stays the same: the plants grow from the ground as it was before the path was cut in
  (`_land_heights` during the scan, so every rng draw is what it was) and are left out where the path changed the
  land (`covers`); the old climb's reserves are kept for the same reason. islanddump diff: only the den area (terrain
  mesh, the coast rock chunks round the den, the plants and colliders there, the den's nodes).
- Story: the marker leads to the path's foot (a trail along the beach from the old one), then the cleft's top, then
  the den. storytest no longer drives the old climb (denpathtest drives the path).
- Tests: denpathtest (new: driven gaps land 0.4-1.3 m past their lips, the double-jump run 1.3 m), storytest,
  foresttest, grunttest, lifetest, smoketest, vinetest, riggingtest. Renders: tools/dev/out/denpath/final_*.png
  (sea_w, sea_sw, over, foot, ledge, cave, bridge_sea, chain_lip, cleft, camp) and night_*.

## 2026-10-15: musictest sea theme picks open sea clear of enemy ships
- musictest sailed to a sea point inside an enemy ship's NOTICE range (150 m); the ship, now awake via ActorSleep, really hunted, so Music rightly played combat. The test now picks sea 400 m from every enemy ship and prints any enemy/ship in combat at the check. No game change.

## 2026-10-15: branches sync with main by merging; a moving main doesn't restart a landing
- **Why:** long-running branches drifted far behind main and paid for it all at once at landing (a big rebase, every
  conflict resolved again per commit), and a commit on main during a landing's tests (a release note, a docs fix)
  threw the whole landing away.
- **Main-moved hook** (`tools/dev/hooks/mainmoved.ps1`, dot-sourced by guard.ps1 before each Bash/PowerShell command
  and crewcheck.ps1 after each edit): in a worktree branch, once per new main head, adds context "main moved (n new
  commits: subjects): at your next clean point, commit, `git merge main`, fix conflicts, rerun your covering tests".
  Never acts. Quiet in the main checkout, on a detached HEAD, when main is already in the branch, and on every later
  call for the same head. The quiet path reads .git, HEAD, commondir, the main ref and `.git/crew/mainseen/<branch>.txt`
  with no git (~10 ms); git (merge-base, log) runs only on a new head.
- **land.ps1:** `Sync-Branch` does nothing for a branch that already has the target in it (fast-forward), merges the
  target into a branch with merge commits of its own (a rebase would drop its conflict resolutions), rebases
  otherwise. After the tests, if the target moved, it takes the new commits in the same way, then: only docs/, *.md,
  web/site/ or files no test's recorded loads include (`Get-LiveFiles`; any test with nothing recorded makes every
  non-doc file live) go straight to the fast-forward; anything else re-runs the compile check, smoketest only if its
  loads include a changed file, and `run_tests -Changed -Light` (passes keyed by loads, so only tests whose loads
  changed run). Five moves in one landing: it gives up. A self-landing that conflicts while merging stops mid-merge
  (finish.ps1 and land refuse a worktree with MERGE_HEAD until it's committed or aborted).
- **Docs:** CLAUDE.md Parallel sessions, `.claude/agents/driftwake-feature.md` and `driftwake-fixer.md`: merge main
  when told, `git merge` over rebase mid-work.
- **Proved** with scratch worktrees under this branch's tools/dev/out and `land.ps1 -Onto` a scratch target:
  guard.ps1 fed a hook JSON from a worktree at 6880dcc said "main moved (1 new commit: v1.15 ...)" once, then nothing
  (guard again, crewcheck); `Get-MainMovedNote` against the scratch target fired once per new target head, then
  stayed quiet. A branch with the target merged in landed with "already has ... no rebase" and fast-forwarded; a docs
  commit on the target during that landing's compile step was merged in with "Only docs or files no test loads: no
  re-testing" and landed. A second landing (a plain branch, so rebased) with the target moving twice: a tool script
  committed during smoketest re-ran only the compile check (smoketest's loads don't include it), then a flaky.txt
  commit during that check went through with no re-testing, and it fast-forwarded.
- guntest 'shoves when you're too close' flaked ~half the runs: the camp's other grunts are asleep (ActorSleep) when the test disables them, and wake (back to PROCESS_MODE_INHERIT) as the captain is teleported in, so they shot and slashed the player down; a Downed body snaps the teleport back to the ragdoll. The test now keeps the other grunts disabled every frame until the pistol part. No game change.

## 2026-10-16: the cape lab (cape motion variants side by side; the default unchanged)
- **Why:** capes (and every long drape) look fine standing and janky the moment the captain moves: jitter, whipping,
  clipping. Zach wants a thick, heavy cape that reacts less, never jitters, never goes through the body, tried on the
  cape alone first. Nothing else changed: other clothing still runs today's SpringChains.
- **Switch:** `BodyBuilder.cape_mode` ("a0" default, "a", "b", "bg", "c") and `cape_thick` (static, read when a cape is
  built). Debug builds: **F1** cycles the mode, **Shift+F1** thin/thick (`BodyBuilder.cycle_cape` rebuilds every caped
  Humanoid; a toast names it). A0 thin is today's code to 5 decimals (t/cloth/cape_modes replays the anchor motion
  against numbers recorded before the lab). Every other mode gets its own SpringChains on the torso named "Cape" (A0
  shares the torso's with a sash tail).
- **Variants:** A0 today's world-space verlet at 60 Hz, frozen rigid to the anchor between steps. **A** (SpringChains
  mode "a", `use_tuned`): the shape blended between the last two steps in the anchor's space (smooth at any refresh
  rate), the anchor interpolated across sub-steps, damping 0.3, k 0.07, 4 passes (lengths, then thighs and shins
  against whole segments at three probes across the sheet, then the back's plane). **B** (CapeMotion "b"): per
  segment a damped swing (back and side angles) in the torso's space, driven by gravity, 45% of the point's
  acceleration and air drag on its speed (smoothed: interpolated transforms move in straight pieces between ticks),
  rest pull and bend coupling, hard limits (never in front of the back's plane), a 6 cm cushion off the legs then a
  bisected hard clearance. **C** (CapeMotion "c"): no physics, the same angles eased by 2.6-1.5 Hz springs toward
  targets from smoothed speed (lift), turn rate (sway, spin flare), falling (hem lift), the torso's lean (hangs
  plumb), a flutter only while moving; same limits and cushion. **BG**: Godot 4.7's SpringBoneSimulator3D on the
  cape's skeleton (exists and runs headless and on the skinned PSX mesh), centred on the Humanoid, swing locked to
  the X axis, a SpringBoneCollisionPlane3D at the back and capsules moved onto the thighs and shins every frame, the
  body's speed as `external_force`. It has **no angle limits** (only an axis lock), and after the 180 turn it flips
  the cape out horizontal and holds it there ~0.7 s whatever the stiffness/drag/gravity (2-4, 0.6-0.9, 1.5-9.8): not
  a fit. Kept in the lab for the record.
- **Thick look** (`_cape_thick`, any mode): a rigid yoke over the shoulders (open front), a gathered collar (a 14-point
  pleated ring), a doubled sheet 7 verts across on three chains (middle and +-0.62 of the width), skinned by distance
  between the middle chain and its edge chain (MeshBuilder.weight_fn), sewn side edges, a rolled hem (a tube), the
  canvas texture.
- **Lab** (`tools/dev/capelab.gd`, `--fixed-fps 144`): the captain (tunic, no coat, plain belt) runs idle 2 s, walk,
  sprint, a 180, a dead stop, a jump, draw + the cutlass combo's spin, idle, once per mode x look, twice (stills +
  metrics, then sequences). Out: `tools/dev/out/capelab/` strips, sheets, `turn_<look>.gif` / `stop_<look>.gif` (modes
  side by side a0 a b bg c, 4x slow), metrics.txt. Env CAPE_TRACE="t0,t1" prints the hem per frame.
- **Numbers** (144 fps render, 60 Hz physics; jitter = hem second difference per frame in the torso's space, walk to
  spin; pen = cape vertex-frames inside the legs/hips or in front of the back across its middle; ms = the cape's
  simulate per character per frame):

  | mode | pen (frames, worst) | jitter mean / p95 / max mm | settle | swing max | ms thin / thick |
  |---|---|---|---|---|---|
  | A0 | 207 fr, 17 cm (thick 316 fr) | 33.9 / 130.8 / 246 | 0.88 s | 38 | 0.006 / 0.013 |
  | A | 60 fr, 17 cm (thick 15 fr, 3.5 cm) | 2.4 / 10.1 / 131 | 0.55 s | 70 | 0.056 / 0.184 |
  | B | 0 (thick 1 fr, 3 mm) | 1.3 / 4.1 / 36 | 1.06 s | 41 | 0.043 / 0.177 |
  | BG | 767 fr, 19 cm | 4.1 / 13.2 / 847 | >1.9 s | 131 | engine side, not measured |
  | C | 0 (thick 1 fr, 2 mm) | 1.2 / 2.8 / 35 | 0.75 s | 34 | 0.039 / 0.117 |

  The diagnosis held: A0's jitter is the 60 Hz stepping (p95 13 cm a frame at 144 Hz), A0 clips in 11% of frames.
  B's and C's maxima (~35 mm, 3.4 s) are a sprinting heel kicking the cape (the hard clearance after the cushion),
  not stepping. Runs aren't bit-identical (the head's glances are randomized), counts move ~10% run to run.
- **Cost:** the default path adds two branch checks per SpringChains.simulate; no NPC wears a cape (gear only), so the
  Brinehollow bench doesn't exercise it (not benched). Per caped character: B/C ~0.04 ms thin, 0.12-0.18 thick
  (three chains, GDScript); the leg cushion's segment tests are most of it.
- **To extend the winner to coattails, skirts, hakama, sashes:** CapeMotion takes any SpringChains' chains; each drape
  needs its own back/front plane (a skirt: a cylinder round the hips instead of one plane, limits per chain by its
  angle round the body), the hips as anchor for skirts and tails (thigh swing drives them far more than the cape),
  the leg cushion per chain, and a pass over BodyBuilder's `_sim(...)` callers to give each a mode.
- **Tests:** t/cloth/cape_modes (every mode x look builds and steps to finite bones by hand and on the captain's
  walk/turn/stop/jump; A0 thin equals today's numbers; B and C never in front of the back's plane).
## 2026-10-15: desert and snow music, beds and footsteps (assets only)
- **What:** the audio for the desert and snow island themes (docs/desert_island_plan.md, docs/snow_island_plan.md):
  eight music tracks, four ambience/weather beds, snow and ice footsteps. No .gd changed: nothing plays them yet; the
  theme agents register them (block below).
- **gen_psx_music.py:** new voices `ney` (breathy end-blown flute), `mizmar` (nasal double reed), `oud` (two detuned
  KS courses), `dum`/`tek` (darbuka low and rim strokes), `zill` (finger cymbals), `sleigh` (sleigh bells); a `hijaz`
  mode in `scale()`; `drone_layer(hump, tilt)` and a `drone` option in `build()` (a seamless drone bus under a track;
  the desert's is G2+D3, darker than the jam's gurdy). Tracks `track_desert(night)`, `track_desert_town(night)`,
  `track_snow(night)`, `track_snow_town(night)`, in TRACKS as desert, desert_night, desert_town, desert_town_night,
  snow, snow_night, snow_town, snow_town_night (`py tools/texture_gen/gen_psx_music.py desert desert_night ...`).
  Each quotes THEME_A once, rewritten in its mode (DES_THEME, DT_THEME in Hijaz; SNOW_THEME re-barred for 3/4;
  SNT_THEME in Bb). Night = the same Song (tempo, bars, chords, melodies), arranged sparser.
  | track | bars | key, metre, tempo | length | form | LU / peak |
  |---|---|---|---|---|---|
  | desert | 48 | G Hijaz over a G-D drone / C minor, 4/4 72 | 160.0 s | intro ney call - A caravan tune (ney, oud answers) - A' mizmar - B dunes on strings (C minor) - T theme on oud - A'' mizmar + oud, zills - turn; darbuka maqsum | -18.0 / -2.6 dBFS |
  | desert_night | 48 | same | 160.0 s | same form: drone and strings carry it, lone ney, slow oud, celesta, one dum a bar | -18.0 / -3.7 |
  | desert_town | 64 | C Hijaz / F minor, 4/4 112 | 137.1 s | intro oud riff - A market dance (mizmar) - A' ney - B royal city: strings + brass fanfare - T theme (oud) - C quick dance (mizmar+oud, zills) - A'' - B' fanfare tutti - turn | -18.0 / -2.2 |
  | desert_town_night | 64 | same | 137.1 s | same form: oud picking, strings, ney, horns where the brass was, celesta | -18.0 / -2.5 |
  | snow | 56 | Eb major / C minor, 3/4 66 | 152.7 s | intro celesta call, choir, timpani roll - A glockenspiel tune - A' strings - B pines on a far horn (C minor) - T theme in 3/4 (strings, horn, choir) - A'' - B' - turn | -18.0 / -2.2 |
  | snow_night | 56 | same | 152.7 s | same form, a hush: celesta alone on the tune, soft strings and choir, far horn, dark harp, no drums | -18.0 / -2.4 |
  | snow_town | 64 | Bb major / G minor, 4/4 104 | 147.7 s | intro accordion vamp, bodhran, sleigh bells - A fiddle reel - A' accordion - B fireside song (concertina, G minor) - T theme warm (accordion, glockenspiel) - C skipping tune - A'' - B' tutti - turn | -18.0 / -3.0 |
  | snow_town_night | 64 | same | 147.7 s | same form: the inn by the fire, guitar picking, soft concertina, quiet fiddle, horn on the theme, bodhran on one | -18.0 / -3.0 |
  Today's tracks (for the keys): title D major 96, sea E minor 6/8, island D dorian 100, village A dorian 88. The
  eight files are 6.0 MB (Vorbis q3 mono, 675-805 KB each).
- **gen_psx_audio.py:** `desert_loop` (47 s: dry wind in long gusts, mostly under 1 kHz, sand hiss off the crests on
  the strong ones, 4 insect rasps, 2 far vulture cries), `snow_loop` (50 s: cold wind whistling on its gusts, pine
  hush, 3 ice groans, 3 snow slumps off branches, one far wolf howl), `sandstorm_loop` (41 s: a roar that never lets
  up, thick breath, sand hiss, grit rattle, surging), `blizzard_loop` (43 s: hard wind whistling on three edges,
  driving snow hiss, 5 howling sweeps). All built circularly (`_cband`, `_cenv`, `_place` wrapping), levelled by
  `_write_loop` to -20 (measure -20.2 like every bed: write_wav scales by 32000). Footsteps: STEP_SURFACES gains
  `snow` (soft thump, a dense squeaky crunch of grains, packing; take 2 squeaks; -21 LU like sand) and `ice` (a sharp
  click, a ringing at 1.7-4.9 kHz, a hard thump, shard ticks; -19.5 like stone), 4 takes each: step_snow_1..4,
  step_ice_1..4 (`gen_psx_audio.py step_snow step_ice`).
- **Measured** (audio_report.py): beds -20.2 LU, peaks -1.7 to -4.2 dBFS, 42-67% under 200 Hz, 1-3% at 2-5 kHz,
  repeat scores 0.17-0.24 (jungle 0.18); snow steps -21.2, ice -19.7 to -19.9. **Seams:** each loop decoded and
  joined to itself: the sample jump at the join is 0.3-2.2x a median step for the music (music_island 0.4x), and the
  high-band (>4 kHz) peak in 20 ms round the join sits inside the range of the track's own bar lines (2nd-73rd
  percentile); the beds' join is at the 40th-97th percentile of all windows (blizzard 97%, rain_loop 98%: its join
  window 0.062 against 0.049-0.075 either side and the same RMS before and after, a loud gust, not a click).
  audio_report's seam column shows +13 to +29 dB on desert, desert_town and snow_town: the downbeat of bar 1 after the
  turn's closing rest (music_island shows +18.8), not a jump.
- **Imports:** loop off at import like every track and bed (Music sets `loop`, Ambience/Weather `LOOP_FORWARD` in code).
- **Tests:** none apply (no .gd changed).
- **Registration block** for the desert and snow agents. Where a theme declares these may have moved into the theme
  file by then: the plumbing agent's recipe in .claude/skills/driftwake-islands/SKILL.md "Adding a theme" wins.
  ```gdscript
  # Music.TRACKS (scripts/game/music.gd)
  "desert": ["res://assets/audio/music_desert.ogg", 48],
  "desert_night": ["res://assets/audio/music_desert_night.ogg", 48],
  "desert_town": ["res://assets/audio/music_desert_town.ogg", 64],
  "desert_town_night": ["res://assets/audio/music_desert_town_night.ogg", 64],
  "snow": ["res://assets/audio/music_snow.ogg", 56],
  "snow_night": ["res://assets/audio/music_snow_night.ogg", 56],
  "snow_town": ["res://assets/audio/music_snow_town.ogg", 64],
  "snow_town_night": ["res://assets/audio/music_snow_town_night.ogg", 64],
  # Ambience.LOOPS / TOP_DB (scripts/world/ambience.gd); jungle is -13
  "desert": "desert_loop", "snow": "snow_loop",
  "desert": -13.0, "snow": -13.5,
  # KitStyle (the theme's table)
  DESERT: "music": "desert", "ambience": "desert"
  SNOW:   "music": "snow",   "ambience": "snow"
  ```
  - The town tracks need one more step: on main Music picks plain "village" for every village
    (`if in_village(tree, pos): return "village"`), and only the wilds read KitStyle "music". Suggested: a KitStyle
    key `"music_town"` ("village" in BRINEHOLLOW and JUNGLE, "desert_town" / "snow_town" in the themes) and that line
    returning the zone's `music_town` on a chain island. `_night` keys are found by name, as today.
  - Both beds carry their own wind, so the "wind" layer may want a few dB less ashore on these themes; judge in game.
  - Weather beds: `sandstorm_loop` / `blizzard_loop` are made like `rain_loop` and are about as loud (-20.2 LU);
    play them where Weather plays rain on desert/snow islands (rain is at -6 dB x rain amount).
  - Footsteps: add `"step_snow", "step_ice"` to FX.SOUNDS (scripts/game/fx.gd, beside "step_water"; FX finds the
    _1.._4 takes), then Footsteps returns "snow"/"ice" for the surface (the snow agent's wiring).
## 2026-10-15: the flipbook effects library (sheets, the FX blocks, one switch)
- **Why:** the pilot (above) proved sprite-sheet puffs read better than quads at the pixel grid; this makes them the
  vocabulary every effect is built from. Zach's one note on the pilot, the dust reading pale and grey, is fixed by
  baking a dark brown palette into its own sheet instead of tinting the grey smoke sheet.
- **The library** (`tools/texture_gen/gen_flipbooks.py`, `py tools/texture_gen/gen_flipbooks.py [name ...]`): 16 sheets,
  all 4x4 frames of 64 px (256x256 RGBA8, 5.6 MB in all with mips), deterministic with a seed per sheet so changing one
  never changes another, the two pilot sheets byte-identical. The puff family (`gen_puff`: a palette, `sy` squash, `rise`
  / `settle`, `speed` / `grow`, `thin` so it never saturates, `grain` speckle, `sparkle` points, a flat `ground` cut) gives
  `dust` (dark brown, kicks up fast, sinks late), `dust_low` (a wide rolling cloud cut flat on the ground), `sand`
  (speckled tan), `snow` (white-blue with sparkles), `mist` (thin, pale), `blood` (dark red, thin, fast). Columns on the
  same `Puff` with a vertical stretch and the noise scrolled up them: `splash` (white water heaving up, breaking into
  droplets, falling back on a spreading foam disc), `fire` (a lick that grows, flickers, lifts off and burns out from the
  bottom), `wisp` (thin tall chimney smoke widening at the top). Hot: `fireball` (blooms, burns from the rim in, no
  soot, embers), `muzzle` (a star flare with a hot heart, then a ring of powder puffs). Light, grey-white so the burst's
  colour tints them: `sparks`, `glint` (a four-point star, halo, a ring racing out), `magic` (a soft burst thinning to a
  ring, motes thrown out). Preview: `tools/dev/out/flipbook/sheets.png` (labelled, 2x). Imports: mipmaps on, lossless,
  detect_3d compress_to 0 (copied; Godot adds the uid on `--import`).
- **FX:** `FX.flipbooks` (default true; false = the geometry effects from before, to compare or to revert in one line;
  was `flipbook_pilot`), `FLIP_SHEETS`, `FLIP_ADD` (the light sheets: additive materials), `FLIP_LIT` (matter dimmed by
  `Weather.night`, the default for `flipbook`'s "lit"). One shared material per sheet (`_flip_mat`), NEAREST_WITH_MIPMAPS.
  The blocks, one burst (one node, one draw) each, all sendable through Net.fx: `puff(pos, sheet, amount, size, life,
  color, lift, dir)`, `puff_ring(pos, sheet, count, radius, size, life, color, speed)` (a ring racing out along the
  ground), `plume(pos, dir, sheet, count, size, life, color, speed, spread)` (pushed along a direction, growing),
  `flash(pos, size, color, sheet, life)` (a glint star or a muzzle flare), `blast(pos, normal, size, hot, smoke_col,
  speed)` (flare + fireball if hot + smoke plume: three bursts; a muzzle is size 1 at speed 6, a ball on a hull size 2 at
  speed 2), `flip_emitter(parent, sheet, amount, size, life, cfg)` (continuous, each particle plays the sheet once;
  visibility range 140) and `lick(parent, radius, amount, size, life, world)` (fire licks for good). Lit emitters are
  re-dimmed by one 2 s Timer on FX (`_dim_emitters`, `CPUParticles3D.color`), not a process on each.
- **On the blocks now:** `cannon_fire` = sparks + `blast(dir, 1, cold)`; `cannon_hit` = `blast(normal, 2, hot, dark
  smoke, slow)` + embers (the old `impact` flash is the flare now); `cannon_splash` = splash + a `splash`-sheet plume;
  `heavy_dust` = half the dust ring + a `puff_ring` of the dust sheet. Particles before -> after (bursts): heavy dust
  12 -> 10 (1 -> 2), cannon fire 34 -> 21 (3 -> 3), hull hit 39 -> 20 (5 -> 5), sea hit 16 -> 13 (2 -> 2).
- **Tests:** `t/fx/sheets` (every sheet exists with its import, 4x4 of 64 px, plays, four dithered alpha levels, one
  shared material each, additive for FLIP_ADD), `t/fx/blocks` (each block one burst that frees itself, blast three,
  the lick keeps going, lit dims 1.0 -> 0.35 at night and emitters follow the night, light doesn't dim, the switch off
  gives the old bursts and on costs no more particles), `t/fx/flipbook` on the new names. Renders: `flipshot`
  (compare_heavy / compare_cannon, and `_h21`): the slam's dust is brown now, the muzzle keeps the pilot's look with a
  star flare, the hull hit blooms big and dark with a fireball frame, the sea hit shows a column with droplets.
- **Gotchas:** flipshot's PERF lines count every burst in the world during the window (harbour life adds ~10), so the
  counts above are by code (and asserted in t/fx/blocks). A sheet's "ground" (splash's foam disc, dust_low's flat
  bottom) sits below the quad's centre, so spawn those puffs ~0.6 x half-size above the surface and give them little
  velocity: the sheet does the rising. `lobes()` push past the frame edge at high `push`, which read as a cloud
  vanishing; keep `push` under ~1.3 r.
## 2026-10-15: theme plumbing (island themes register from their own files)
- **Why:** a theme was lines keyed `"jungle"` in nine hubs (IslandTheme.DEFS, KitStyle.JUNGLE/STYLES, LifePools.POOLS,
  BeastPool's POOLS/MINIS/ROAMERS/NAMES/LOOKS/SCRIPTS/MINI_SITES/name lists, Chain.THEMES/FIRST_SEA_THEMES,
  FaunaSpawner.ROSTER/make, ChainMarks.THEME_COLORS/icon, SkyBirds' parrot rule, Ambience/Music keys), so the desert
  and snow agents would have edited every hub at once (docs/dev_process_plan.md "What went wrong"). Now **a theme is
  new files**: `scripts/island/themes/<theme>_theme.gd` (extends `ThemeDef`) plus its line in `IslandThemes.SCRIPTS`.
  Step 2 of the dev process plan, narrowed to themes (the IslandFeatures step registry and typed contracts are not in it).
- **Registry** (`scripts/island/themes/`): `ThemeDef` (RefCounted; the contract as members: name, display, blurb,
  island_names, weight, color, glyph, flocks, land, style, props, life, bosses, minis, roamers, beasts, fauna,
  creatures, and `meshes()`; `CONTRACT` lists them, `missing()` says what's unset or inconsistent - a boss without
  looks, a mini without a site, a roster kind without a creature script). `IslandThemes` (a const list of theme
  script paths in declared order, never a folder listing: the order is the chain's; `of(name)` / `all()` / `has()`
  over cached instances; `of` is not `get`, which would override Object.get). Every theme is loaded and checked
  together on the first call, on the main thread (Chain._build, IslandTheme.meshes come before any worker), and a
  theme with a gap is refused with push_error + assert. `of("nope")` pushes an error and returns null.
  `JungleTheme` (`jungle_theme.gd`): today's jungle, every value moved unchanged; its text in `jungle_life.gd`
  (`TEXT`, plus `elder_about`: the two lines IslandVillage's elder had hard-coded).
- **Hubs on it** (their public API kept): `IslandTheme.has/def/meshes` (meshes cached per theme as before, made on
  the main thread before prepare); `KitStyle.of` (BRINEHOLLOW merged with the theme's `style`; `styles()` for every
  style by name; `BASE_PROPS`; `prop` makes the base models itself and asks the themes' `props` Callables for the
  rest, first declaring theme wins, so the registry test checks no two themes share a model name); `LifePools.of`;
  `BeastPool.info(theme, kind)` (script, names, looks, site, stock) with `assign/pois/mini_name/roamer_name/
  stock_looks` reading it (the never-used "warlord" mini and its `s / 7` naming are gone; `mini_name` is
  `names[abs(seed) % n]`, `roamer_name` `names[abs(seed / 13) % n]` as the boar's and behemoth's were); BeastArena
  and BeastDens load scripts through `info`. `Chain._pick_theme` is a weighted pick (`ThemeDef.weight`, jungle 1.0)
  over `IslandThemes.all()` in declared order, the avoided themes left out unless that empties the pool: exactly one
  `rng.randi()` whatever the themes, so with the jungle alone the stream is today's. `Chain.THEMES` and
  `FIRST_SEA_THEMES` are gone (snow/desert/forest's names and blurbs with them: their agents bring their own);
  `Chain.describe`, GenIsland's banner, IslandLife's rumours, the elder's "beyond" and Gus's rumour read
  `IslandThemes.of(theme).display/blurb`.
- **Proof** (`tools/dev/islanddump.gd`, which now takes a chain seed: the whole chain's table - name, theme, place,
  seed, level, beasts, set piece, landmarks - then that seed's first island built node by node): before and after on
  the smoketest's seeds 1 (8721 nodes), 12 (7613), 36 (7048) and 9 (8235): byte-identical; two runs of seed 1 on
  the same code also identical (no noise in GenIsland). Brinehollow (2486 nodes): identical but for the three
  training dummies' sack heads (`Props.straw_dummy_mesh`, unseeded, as ever).
- **Test:** `t/island/theme_registry` (the first `t/island` atomic test, on the light stage): every registered theme
  fills every `CONTRACT` member, its beast and creature scripts exist, every style's prop slots build with a Flame on
  the lamp, no two themes make a model of the same name; the jungle's land def, style (over Brinehollow's), beasts,
  roster, text and chain words spot-checked; `_pick_theme` advances the rng by one draw; a chain is all jungle with
  jungle names; a blank ThemeDef is refused on every member (props may be empty); `of("nope")` logs its error and
  returns null. Covering suites: isletest (now over `KitStyle.styles()`), chaintest (themes ready =
  `IslandThemes.all().size()`), lifetest, bosstest, smoketest, villagetest, harbourtest and the rest `-Changed` picks.
- **Gotchas:** a theme's `props` lambdas and `stock` Callable run on the main thread (props) or the prepare worker
  (stock: JungleApe.ape_look, as before) - keep them node-free. `KitStyle.of` is called from Weather, Music and
  Ambience twice a second: it merges on every call as before (no new cost). `IslandThemes` must not be a directory
  listing: declared order feeds the chain's rng. Don't name a static `get` on a RefCounted (native override).
- **Piece 2** (the rest of the hubs): `FaunaSpawner` keeps the island's `theme` and `roster` (`ThemeDef.fauna`):
  `roll(theme, seed)` and `make(theme, kind)` (the kind's script from `ThemeDef.creatures`) - same sorted kind order,
  same draws, so every island's wildlife is as before; the cave/dungeon slots read a new contract member,
  `cave_fauna` ({"ceiling": "bat", "floor": ["mite", "burrower", "snake"]} for the jungle, was hard-coded).
  The four `"jungle"` KitContexts (IslandVillage.build, VillageLayouts.plan, KitDungeons._lights, KitTemple._lights)
  take the island's theme. `ChainMarks.theme_color/icon` read `ThemeDef.color/glyph` (the snow/desert/forest colours
  and glyphs went: those themes bring their own). `SkyBirds`' parrots: `ThemeDef.flocks` parties (jungle 2,
  Brinehollow 1 as before, 0 = none). **Music and Ambience stay as they are**: a theme's style names a track
  (`Music.TRACKS`) and a bed (`Ambience.LOOPS` + `TOP_DB`), and a theme that needs new ones adds its line to those
  tables (the one hub edit besides the registry line; it keeps both autoloads simple, and the registry test checks
  the names exist). Textures: `gen_psx_textures.py` was already importable (main() only under `__main__`); its
  docstring says how a `gen_<theme>_textures.py` imports the helpers, and `save` makes the out folder. No PNG
  regenerated. faunatest and siteshot call the new signatures with "jungle"/the node's theme.
  Proof: islanddump on seeds 1, 12, 36, 9 after piece 2 (on the main with the flipbook library in) byte-identical to
  the dumps taken before piece 1 (wildlife F-nodes, cave and temple lights, the village included); Brinehollow the
  same but for the three dummies' heads. New registry-test checks: ambience/music names exist, the jungle's
  cave_fauna, FaunaSpawner rolls and makes from the theme, ChainMarks reads its colour.
- **Open:** a theme brought up before piece 2 lands needs `cave_fauna` (the registry refuses it otherwise, naming
  the member). lifetest's "a villager walks its route" (1.5 < d < 4.0 m over 2 process-seconds) failed once at
  exactly 4.0 m with five slots busy and passed alone: a load flake in a process-seconds wait, not this change.

## 2026-10-15: theme land hooks (island size, the theme's own terrain), the village's town track
- **Why:** the desert is the largest island type and both new themes shape their own land (dunes, ridges, wadis,
  plateaus; sharp peaks, frozen rivers), so GenIsland's size and height function had to ask the theme. Desert piece 1,
  generic so the snow theme uses the same hooks.
- **Size:** `ThemeDef.radius` ([lo, hi] m, a contract member; jungle [300, 450]) replaces `GenIsland.RADIUS`: the same
  first `_rng` draw in prepare. **Chain:** legs, forks and APART were sized for 450 m islands, so `Chain.BASE_R` (450)
  and `_make_room` (no rng): a fork's two islands go out sideways by each one's excess over BASE_R (its theme's top
  end), then the layer is pushed on along the line until each island is APART + both excesses from the layer
  before's (the line's point moves with it, so later layers follow). A chain of 450 m themes is untouched. What
  else assumes the size, checked: WorldGenerator streams by the chain (next islands), not distance; Redtide's
  deep-water check, EnemyShip.no_go, the chart, KitStyle.around, FaunaSpawner, KitDungeons/KitTemple/KitLandmarks
  spots all read `isl.radius`. The cost grows with area: the terrain grid (CELL 3 m: res 354 at 450 m, ~500 at
  650 m, 2x the vertices) and the vegetation scatter's 5 m and 2.5 m grids (every point tests ground and reserves,
  plants or not), so a 1.5x island prepares ~2x as long on its worker; the finish steps are a frame each.
- **Terrain:** `ThemeDef.plan_land(isl, rng) -> Dictionary` (the island's `land_plan`; called in prepare after
  `_setup_shape`, before the sites, on its own stream `seed + 977` so the base land's draws never move) and
  `ThemeDef.shape(isl, p, h) -> float` (called at the end of `_height_natural` only when the plan isn't empty: the
  jungle pays nothing). Flats (sites, the dock's 2 m, the berth) are laid over the shaped height in `_height_fn`,
  and the sites' kept land holds: inside each `_keep` disc the shape may raise the ground but a cut is blended back
  to the base land, so a wadi can't drown a site. The site's flat level is the shaped ground there. `isl` is untyped
  in ThemeDef's signatures (naming GenIsland there pulls Ocean into anything that loads a theme early).
- **Music:** KitStyle key `music_town` (BRINEHOLLOW "village"); Music plays the zone's style's `music_town` in a
  village (Brinehollow and jungle villages unchanged), night variants by name as before. Swimming keeps whatever
  calm track was on (was: only sea/island/village kept, so a theme's track dropped to "island").
- **Proof:** islanddump before/after: chain seeds 4242 (5559 nodes) and 77 (4459): byte-identical; Brinehollow the
  same but for the three dummies' heads. **Test:** `t/island/theme_land`: the base hooks are identity, the jungle has
  no plan; a test theme (the jungle's files sinking the inland 6 m, loaded from source so the test compiles before
  the autoloads) keeps the jungle island's radius, capes and hills, sinks the land away from the sites, and every
  flat, the sites' kept land and the dock's 2 m hold. isletest's size check reads the theme's range.
- **More land hooks** (same rule: called only with a land plan, so the jungle and snow pay nothing):
  `village_at(isl, p)` (the village moved once GenIsland has placed it: the desert's capital up on its plateau),
  `cover(isl, p, c)` (how overgrown, before the sites are cleared), `growth(isl, p) -> Vector2(plants, rocks)`
  (multipliers on every scatter chance: bare dunes, stony ridges; the 5 m and 2.5 m grids), `paint(isl, p, h, splat)`
  (the terrain's dirt/rock/sand after the base's). KitStyle key `arena` ("canopy" in BRINEHOLLOW; "open" = the
  boss's floor kept clear with no ring of giants and no roof: `GenIsland.open_arena`, `canopy_arenas` entries carry
  a 4th "canopy" bool, `arena_ring` is empty for an open one). Proof: islanddump on main vs the branch, seeds 4242 and
  12 (jungle) and 77 (snow): byte-identical. theme_land's test theme also moves its village, grows nothing, paints
  sand everywhere and has an open arena: checked.

## 2026-10-16: the desert theme, foundations (docs/desert_island_plan.md phase 1)
- **Registered** after snow (`IslandThemes.SCRIPTS`: jungle, snow, desert; weight 1.0), so a third of the chain's
  islands roll desert and the fixed seeds roll differently (bosstest moved to 4246, a chain that opens on a jungle;
  musictest reads a chain island's town and wild tracks from its style). Chains that open on a desert: 2, 5, 7, 8.
- **Files:** `scripts/island/themes/desert_theme.gd` (contract, style, land, the land hooks), `desert_life.gd` (names,
  roles - water-seller, caravan guide, potter, spice merchant, storyteller, lookout, healer - barks, rumours, quests in
  a desert voice), `scripts/props/desert_plants.gd` (DesertPlants), `desert_props.gd` (DesertProps: urn, brass
  lantern post, waymarker), `tools/texture_gen/gen_desert_textures.py` (desert_sand with wind ripples, desert_beach,
  desert_hardpan, desert_rock in ochre/rust bands, adobe, sandstone, glaze, four awning stripes, rug_kilim, cactus,
  dry_grass, reeds). Music/ambience lines in Music.TRACKS and Ambience.LOOPS/TOP_DB (the music agent's files).
- **Size:** 480-640 m (jungle 300-450); Chain pushes forks and layers apart by the excess (BASE_R). Prepare on its
  worker ~10-18 s (land 2.3-3.8 s, arrays 1.6-2.1, undergrowth 1.8-3.3, bodies ~2; a jungle 418 m is ~15 s);
  on the main thread ~2.4-2.7 s over ~118 frames.
- **Land** (`plan_land` on the island's own stream, `shape` per height point; features as data in `land_plan`):
  a plateau (65%; round the middle, its far side under the summit so the town keeps 45 m off the summit's site;
  rim steep but for ramps toward every site off it) the capital moves up onto (`village_at`, 55%); mesas (flat tops,
  steep sides, dropped where a site or a way would be); rock ridges (sharp crests, tapering ends, parting where a way
  crosses); transverse dune fields (stoss slope to a sharp crest, a soft-footed slip face, crests meandering on noise,
  off the sites and the wadi beds); wadis from the plateau's rim or the highlands meandering out past the coast;
  canyons (steep, forded where a way crosses); salt pans levelled low; oasis hollows. "The ways" are straight lines
  dock-village and village-site, worked out again whenever GenIsland has placed more sites. Inland never drops under
  1.2 m (GenIsland finds the dock by walking out to the first ground under 0.4 m). Six variants (`forests`): open
  desert, sand sea, badlands, high plateau, salt pans, oasis coast.
- **Life on the land:** a zone grid (8 m, built on first use after the sites: dunes, rock, wadi beds, oases) drives
  `cover` (oases and wadi beds green, the rest a third of the base's), `growth` (bare dunes and pans, stony ridges and
  mesas, rich oases and wadis) and `paint` (hardpan on pans and wadi beds, rock on ridges and mesas; the plateau's rim
  is the shader's slope rock). Plants: date palms (clumps, a skirt of dead fronds, dates), acacias and dead trees,
  column and barrel cacti and prickly pear, scrub, saltbush, tumbleweed, dry grass, reeds at the water and in the
  oases; sandstone boulders. The boss's ground is "open" (no canopy ring). Interim until the later phases: the
  jungle's beasts and its wildlife subset (crab, snake, burrower, mite, bat), the jungle's village builders with
  desert materials.
- **Perf fixes found on the way:** `DrawLOD._fold` skips one-surface meshes (an island's terrain was copied for
  nothing: ~1 s on the main thread for a desert's); `_fit` stops sizing a MultiMesh once it is too big ever to get a
  range (exactly equivalent). genshot skips its jungle shot on an island with no forest.
- **Test:** `t/island/desert_land` (seeds 2, 7, 1999). Renders: `genshot.gd tools/dev/out/desert/g2 2` (and g7, g5).

## 2026-10-16: the desert theme, towns and wildlife (plan phases 2 and 3)
- **Towns** (`scripts/props/desert_town.gd`, DesertTown, through snow's `village_models`): flat-roofed houses in
  pastel washes (lilac, cream, salmon, mint, blue-grey, white, ochre: vertex colour over one adobe material, so a
  street is one surface) on sandstone footings 2.2 m deep, parapets (crenels now and then), arched doorways framed in
  sandstone, small deep windows (some lit), roof beams through the front, a dome (round or onion; gold, green, blue,
  rose, turquoise glaze) or a canvas roof shade, a striped awning or an outside stair to the roof; two-storey ones
  set back on the roof terrace. Rooms you walk into (home/elder, trader, cookhouse) are the same shell hollow, an
  arched wall (`add_extrude` of the wall with the arch notched out), the kit's furnishing (`KitHouses._home_inside`
  etc.) and its markers; the caravanserai (the inn: an arcade of three arches, a gallery, a dome); the potter's
  workshop (two arches, a kiln, a wheel; Worker, Bench); the domed shrine (Keeper, Pray); granaries (beehive domes);
  ruins half buried in sand (Cache); a minaret (for set pieces); a brazier (the desert's torch, "Flame") and a well.
  Paving `desert_flags` (new texture); adobe texture calmed.
- **Generic hooks** (KitStyle, BRINEHOLLOW keeps today's): `item_models` (a theme's models for a village's dressing
  items by kind, KitVillage.build_items: a lit one's light at its Flame) and `village_layouts` (the layout weights;
  BRINEHOLLOW = VillageLayouts.POOL, so jungle and snow roll as before; every key must stay - isletest's style check
  - so the desert sets post and stilts to 0: towns 4, hamlets 2, buried ruins 2).
- **Wildlife** (`scripts/enemies/fauna/`): Scorpion (claws wide and the tail quivering high is the tell; a pinch or
  the sting, which poisons; plates turn blows from the front; one pack lead in eight is an emperor), MonitorLizard
  (basks; close in and it hisses, then a lunging bite or a tail lash that knocks you down; runs when badly hurt),
  DesertFox (fennec: sits up to listen, bolts zigzagging when a captain comes near; snaps once if cornered). The
  roster: scorpion, lizard, fox, crab (shore), snake, burrower; bats in caves; cave floors scorpion/burrower/snake.
  FaunaSpawner: an island with fewer than 40 forest-floor points (no forest to speak of) samples its floor out in
  the open (240 tries, only then: a jungle's draws don't move). Vultures: SkyBirds' dark flocks already circle every
  island; a desert look for them is left for later.
- **Proof:** islanddump Brinehollow (dummies only) and 4246 (jungle) identical to main. **Tests:**
  `t/island/desert_town` (every village kind builds with a collider, a footing, its markers, an open doorway; same
  seed same house; brazier Flame, well collider; no stilt village), `t/island/desert_fauna` (scorpion strikes and
  stings with poison, foxes bolt, a lizard close by comes on, one far off basks; roster scripts). Renders:
  `tools/dev/out/desert/v7b_*` (the capital on its plateau), `v2_*` (buried ruins), `models/desert_town_*`,
  `models/desert_fauna*`.
## 2026-10-15: flipbook rollout across FX, and brief impact lights
- **Rollout** (`scripts/game/fx.gd`, all behind `FX.flipbooks`; same names and arguments, so every Net.fx caller is
  unchanged): `dust` (a puff or two of the brown dust sheet), `dust_ring` (a `puff_ring` of `dust_low`), `heavy_dust`
  (a dust_low ring + a dust puff; piece 1's half quad ring is gone), `smoke` (smoke puffs; so powder smoke, shadow
  wisps, burning props' smoke), `blood`'s mist (`blood` sheet along the spray), `splash` (a column of the `splash`
  sheet; the foam ring stays geometry), `spray`'s mist (`mist`), `flame` (`fire` tongues; so embers' puff, Ember
  Fruit hits), `fire_ring` (a ring of `fireball`), `fire_pillar` (a `fireball` plume), `flame_emitter` (`lick`: Ember
  Fruit fire zones, burning statuses, the fireball's trail, burnable props, the fort's braziers), `chimney_smoke`
  (`wisp` emitter, 6 particles), the flashes of `impact` / `parry_sparks` / `glint` (the `glint` star) and
  `powder_burst` / `cannon_blast` (the `muzzle` flare), `gather` (glints rushing in), `motes` (the `magic` sheet,
  tinted by the tree: dual / dual_dagger / dagger elements), `cannon_splash`'s cloud (`mist`). Geometry stays:
  sparks, streaks, tracers, rings, foam rings, cracks, blade trails, vines, afterimages, punch wind, petals,
  debris, bleed's droplets and streaks, splats.
- **Counts per call** (bursts / particles, geometry -> sheets; flipshot's COUNT lines, asserted in t/fx/blocks):
  dust 1/6 -> 1/2, dust_ring 1/12 -> 1/6, heavy_dust 1/12 -> 2/8, smoke 1/6 -> 1/3, blood 3/35 -> 3/32, splash
  1/6 -> 1/2, spray 2/16 -> 2/15, flame 1/10 -> 1/3, fire_ring 2/54 -> 2/14, fire_pillar 6/141 -> 6/47,
  flame_emitter 1/14 -> 1/7, chimney_smoke 1/10 -> 1/6, impact 2/11 -> 2/11, parry_sparks 4/38 -> 4/38, glint
  2/2 -> 1/1, gather 1/16 -> 1/5, elem_hit dual 1/6 -> 1/2, powder_burst 3/18 -> 3/15, cannon_blast 6/70 -> 6/49,
  cannon_fire 3/34 -> 3/21, cannon_hit 5/39 -> 5/20, cannon_splash 2/16 -> 2/5. Nothing costs more.
- **Brief impact lights** (Zach's ask): `FX.flash_light(pos, color, energy, reach, secs)`, a pool of `FLASH_CAP` = 6
  shadowless OmniLights (children of FX; made on demand, never more; all lit: the weakest is taken over), skipped
  beyond `FLASH_RANGE` = 90 m of the camera, rise <= 0.04 s then a quad ease-out to 0 over `secs` on a tween (game
  time: slows with slow motion), hidden after. Calls in the same process frame within 1.5 m merge into one light
  with the biggest energy/reach/secs (fire_pillar -> fire_ring -> flame is one light). Called inside the effects,
  so they reach every screen wherever the effect already goes through Net.fx: cannon_fire 5 / 10 m / 0.25 s,
  cannon_hit 7 / 12 m / 0.4 s, cannon_blast 4 x size / 6 x size m (the tree colour when it burns), powder_burst,
  blast, muzzle_sparks (every gunshot: 1.2 + 0.08 x sparks, ~4 m, ~0.12 s), flame (1.2 + 1.5 x size), fire_ring
  5 / 1.8 x radius / 0.45 s, fire_pillar 8 / 2.2 x radius / 0.6 s. Switch `FX.flash_lights` (independent of
  `flipbooks`). Not on flame emitters (campfires and burning props have their own lights) or plain impacts.
- **Bench** (Brinehollow, 13:00 clear, other agents' Godots running throughout, so old fx.gd (e2d808c) and new run
  back to back): ALL frame 10.61 -> 10.81 ms, p95 13.00 -> 13.97, GPU 2.08 -> 2.01, draws 1278 -> 1268; per stop
  beach 11.09 -> 10.82, plaza 10.67 -> 13.52 (physics script +57% in the same window: load, not FX), market
  11.84 -> 11.12, quay 10.85 -> 10.34, dock 10.21 -> 9.81, den 10.00 -> 10.24, yard 10.58 -> 11.42, aboard 9.92 ->
  10.02. A first after-run against the morning's before-run showed GPU +0.77 ms; the back-to-back run puts that on
  the other processes. No flash lights fire in the bench (no explosions on its route).
- **Notes:** `kit_landmarks.puffs` reskins the chimney emitter with its own quad and ramp (waterfall mist, steam);
  it still works, and now dims at night with the other lit emitters. The light merge radius was first scaled
  with reach: a broadside 3 m apart merged into one light; a fixed 1.5 m catches only nested calls.
- **Tests:** t/fx/blocks (the cost table above, each swap plays a sheet), t/fx/flash_lights (a hull hit lights one warm
  shadowless light that flares and dies, fire_pillar is one light, impacts and glints light nothing, a broadside of
  ten cannons firing and hitting keeps to 6 nodes, nothing at 200 m, the switch, a gunshot's small light).
  Renders (tools/dev/out/flipbook/): compare_ground / fire / hits / water (+ cannon, heavy), compare_cannon_h21
  and compare_fire_h21 (the hull and the ground lit at night), abil_axe_heavy / abil_kraken_wake /
  abil_point_blank (abilityshot at 21:00).

## 2026-10-16: the captain in Blender (BlenderBody, F4 / Ctrl+F4)
- **What:** a debug round trip for the player model. `BlenderBody.export_captain` (Ctrl+F4 in game, or
  `tools/dev/blender_export.gd` for the default captain) builds a fresh unposed body of the look, bakes every
  body mesh (BodyBuilder now tags them `body_part`) into one armature, writes `art/blender/captain_export.glb`
  and runs Blender headless (`tools/blender/captain_setup.py`) to make `art/blender/captain.blend` with a glTF
  collection exporter aimed at `assets/models/captain/captain.glb`. An existing captain.blend is never
  overwritten (a second export makes captain_new.blend). F4 puts that model on the live captain.
- **The rig:** one bone per joint that carries a mesh (named after the joint: Hips, ForeR, Head...) and one per
  bone of the skinned parts' skeletons, `<owner>_<bone>` (ArmBody_shoulder_r_4, LowerBody_knee_l_3,
  HeadChains_chain0_1 for SpringChains). 78 bones on the default captain. Bone rests have their scale stripped
  (the head's style scale is baked into the vertices) and Blender imports them with bone_heuristic BLENDER so
  they come back as sent.
- **In game:** the procedural body keeps animating, ragdolling and simulating hair/cloth with its meshes on
  `layers = 0`; each frame (after ArmBody/LowerBody, priority 110, only on frames the rig posed) every Blender
  bone gets `source_now * source_rest^-1 * blender_rest`, the rest coming from a fresh unposed body of the live
  look built at toggle time, so a bone Blender moved still lines up and a model with other proportions keeps
  its own. A Blender part shows when the procedural part of the same name would (the fist/mitten swap, a
  severed arm). Bones or objects added in Blender just hold their rest. Not carried over: hit flashes and
  Haki tints (per-object material copies), co-op (only your screen), other captains.
- **Materials:** psx_lit becomes a plain material for Blender (texture, tint, vertex colour, emission) and back
  to psx_lit at toggle time. What glTF can't hold rides in the name: `~a<affine %>`, `~p<depth pull mm>`, `~nv`
  (no vertex colour), `~u<n>` only for uniqueness (glTF writers number duplicate names, which garbled a tag).
  The face decal is baked over the skin colour so it paints like any texture; sRGB-stored vertex colours are
  decoded to linear for Blender. The glb imports with LODs off and textures embedded uncompressed.
- **Tests:** t/player/blender_body (on, procedural body hidden, forearm / shoulder helper / knee helper / hair
  bones within 1 cm of their sources at rest and through a cutlass draw, 13/13 parts mirror visibility, off).
## 2026-10-16: the snow island theme, piece 1 (foundations, ground, village houses)
- **What:** the snow theme (docs/snow_island_plan.md) registered after the jungle: `scripts/island/themes/snow_theme.gd`
  (land, seven forests: pine valley, deep spruce, open snowfield, crystal slopes, frozen shore, heavy firs, cedar
  ridge; the style; interim beasts and wildlife borrowed from the jungle until the snow's own: stalker / serpent /
  mantis bosses renamed, alpha boar, behemoth; boar, mite, bat, crab), `snow_life.gd` (36 names, 7 roles: ice-fisher,
  trapper, doctor, furrier, storyteller, lookout, brewer; barks, rumours, quests), `scripts/props/snow_plants.gd`
  (SnowPlants: conifers as tiers of drooping boughs, a star of tips each, snow on top from the pine_snow texture's upper
  half - spruce, fir, great pine, cedar, bough roof as [body, detail, lean]; young pines, saplings, dead trees, bent
  shore pines, frozen shrubs, junipers, frosted grass, drifts, snow-capped black rocks, ice floes, ice-crystal clusters
  that glow blue by emission), `scripts/props/snow_props.gd` (SnowProps: iron lamp post, waymark cairn, round house),
  `tools/texture_gen/gen_snow_textures.py` (snow, snow_packed, ice, black_rock, glacier_rock, snow_beach, shingle_wet,
  brick_pink, roof_green with snow on every course, pine_snow, ice_block, frost_shrub, frost_grass). Music.TRACKS
  snow / snow_night / snow_town / snow_town_night and Ambience snow_loop at -13.5 (the theme's hub lines).
- **Generic hooks added** (small; Brinehollow and the jungle unchanged): KitStyle `ground` (the terrain's layer
  textures for PSXMat.terrain and the sea cliffs' rock for Coast.build; GenIsland passes its style's), `village_models`
  (a theme's own prop models for a village's building kinds; IslandVillage places them where the kit's would go,
  never on a raised layout), `cave_look` (caves' surfaces over KitDungeons.LOOK), `KitStyle.model(name)` (prop()
  without the slot), IslandVillage's worn earth from the ground's dirt. BeastPool.assign: when every boss of a small
  pool is avoided (the islands before plus the layer's same-theme islands), only the islands before are kept.
- **Look:** the snow's round houses: pink brick drum, a tall cone of 4-6 green tiers with snow on each step, a brick
  finial with a clay cap and chimney smoke, a hooded door at +Z, lit windows, a black-stone footing; the tall kind is two
  storeys. Mostly overcast, haze 0.4 (the fog's colour is Weather's: still the home colour until the weather pass).
- **Not yet:** the terrain (peaks, drifts, lakes, river; waits for the desert's land hooks), the snow's own creatures,
  bosses and set pieces, KitHouses' workshop/storehouse/shrine and the harbour dressing are still jungle-built,
  landmarks and set pieces are the chain's (totem groves, temples), FaunaAmbient's butterflies and fireflies fly here too,
  the sea is the tropical one. Clothing has no fur hats or mittens (knit caps, hoods, coifs and leather gloves stand in).
- **Tests:** `t/island/snow_foundations`; theme_registry's chain check now "every island's theme registered and named
  from its list". Renders: genshot seed 1 node 1 (Hoarfell Atoll, snow), villageshot seed 1 node 1 town.
## 2026-10-16: the snow island theme, piece 2 (wildlife and beasts)
- **Wildlife** (`scripts/enemies/fauna/`, Creature kinds, LOD and sleep by FaunaSpawner as every kind): `wolf.gd`
  (packs of 3-5 round a bigger lead: the lead howls, the pack circles at a lunge's length, one lunge at a time per
  pack - `_pack_next`, game time - a beaten wolf limps off; grey, white, dark), `snow_hare.gd` (freezes with ears up,
  bolts in zigzag bounds), `snow_bear.gd` (a sow and often a cub: rears and roars, lopes in, two swipes, then a
  rearing slam ring if you're still in front; leaves you be at a distance), `shagback.gd` (huge placid shaggy grazers
  in herds; hit one and the herd stampedes, a big one shoving through), `walrus.gd` (shore colonies: the bull rears
  and stabs with its tusks, calves flop away). White coats on a new `fur_white` texture (the grey `fur` read dirty).
  Snow puffs (FX.puff "snow") on runs, lunges and slams.
- **FaunaSpawner** (generic): a kind its group logic doesn't know is a pack round a lead when its roster entry has
  `"pack": [lo, hi]` (and `"young"`: the chance a follower is young); args `pack` (the group), `lead`, `calf`.
  The jungle's kinds all have their own cases, so their groups and rng are unchanged.
- **Beasts** (`scripts/enemies/beasts/`, subclasses of the jungle's brains with their own bodies): bosses
  `snow_leopard.gd` (the stalker in a snow leopard's coat), `great_bear.gd` and `ice_golem.gd` (the alpha boar's
  charge / swat / stomp at a boss's scale, no overhead bar), plus the jungle's serpent so a branching chain never runs
  the pool dry; mini `frost_alpha.gd` (a horse-sized wolf at the ruins); roamer `rimeback.gd` (the behemoth as a woolly
  mammoth with ice on its back). BeastArena: a boss kind it has no banner for takes its theme's `"banner"`, the brush
  round the floor is the theme's bush and fern meshes (the jungle's are the same four), and the victory line names the
  theme ("The snow goes quiet.").
- **Tests:** `t/island/snow_wolves` (light stage: the pack notices at 9 m, circles, lunges one at a time; hares bolt and
  get away; a far shagback and walrus mind their business; walk into the colony and the bull comes), snow_foundations
  (every roster kind makes its own creature, the beasts are the snow's); bosstest's "every boss turns up" counts every
  theme's bosses. lifetest failed once on "a villager walks its route" (4.1 m in 2 s, the check's < 4.0: process
  seconds under load) and passed on its rerun.
## 2026-10-16: the snow island theme, piece 3 (terrain, village buildings, ice caves)
- **Terrain** (`scripts/island/themes/snow_land.gd` on the desert's land hooks; SnowTheme's plan_land / shape / cover /
  growth / paint / steps call it): the base summit raised into a tall peak (+68-90 m over a 215-255 m radius, concave
  flanks `PEAK_K` 1.6, a flat 13 m top for the castle or the lookout: summits 100-120 m), 5-8 pointed spire candidates
  (always under the summit; they give way within 34-72 m of a site and along the village-to-summit line: a pass),
  gentle wind drifts, 2-3 frozen lake candidates in hollows on the flanks (level from the base plus the peak), a frozen
  river from the peak's foot to the sea (a 2 m cut). Built as theme steps: the ice (a lit ice sheet 0.6 m over the cut
  ground, one trimesh collider; none over a cave's ground) and glowing crystal clusters on the high steep ground (one
  MultiMesh per kind, 700 m). cover/growth keep forest off the ice, thin it high on the peak, keep plants out of a
  cave's mouth (9 m), triple the rocks on the spires; paint glazes the ground over 70 m with glacier rock. Snow
  islands are 360-450 m.
- **Gotchas found:** the base land raises a cliff's whole bearing to its height, which tears the island's middle where
  bearings meet (8 m in 7 m at the summit): taken back out under the peak (`mid`). A site's levelled ground on a steep
  flank sits in a cut with a bank too steep to walk; fading the peak round sites made worse banks, so the peak is left
  alone and the climb test measures past the sites' flats. Caves on steep land: a mouth whose floor stands over the
  ground in it can't be walked into (dungeontest stuck at point 2): KitDungeons skips such a mouth on islands with a
  land plan (the jungle unchanged); the old 3.2 m drifts made the ground under tunnels too uneven, now 2.2 m at half the
  frequency.
- **Generic hooks:** `ThemeDef.steps(isl)` (GenIsland runs them after the plants' colliders, islands with a land plan
  only), KitStyle `cave_frost` (KitDungeons: ice icicles and spires for dripstone, crystal clusters on the floors, a
  waterfall frozen down the end room's wall into an iced pool; no extra rng draws when off, so the jungle's caves are
  unchanged).
- **Village buildings** (SnowProps through `village_models`): a log store shed on posts, the sledge-maker's open shed
  (Worker, Bench), a wayside shrine with a glowing ice-bear (Keeper, Pray); the style's crates and barrels carry snow.
- **Tests:** `t/island/snow_land` (three chain islands made snow: the summit the highest ground, 100 m+, a flat top;
  2+ spires rise 30 m; the trail up walkable past the sites' flats; the river from the peak's foot into the sea; level
  lakes; nothing on the ice; flat village ground; the same seed the same land), snow_foundations (the frozen caves, the
  buildings' work spots). On main after the desert registered, isletest (Sunscar Atoll, desert: its open arena) and
  dungeontest (seed 5 is now Qadir Rock, desert: stuck at point 3, with or without the snow's mouth check) fail on desert
  islands; the terrain piece landed with `-NoTests` for that, reported to the lead.
## 2026-10-16: the snow island theme, piece 4 (places on the desert's place hooks)
- **What:** `scripts/island/themes/snow_places.gd` through SnowTheme's place_kind / plan_places / plan_place /
  place_steps: `snow_ruins` stands in for the chain's totem grove (3-7 towers of stacked ice-stone blocks, barred
  windows, snow on the ledges, blocks tumbled off), `snow_buried` for the great tree (4-7 stone houses with broken
  gables sunk 1-2 m in drifts, free-standing arches, a strongbox kept as `snow_buried`), and on 75% of snow islands
  (their own stream) `snow_castle` round the summit's lookout: seven stretches of crenellated curtain wall at 12.5 m,
  round towers under three green tiers with snow on each, the gate (piers, lintel, the portcullis drawn up) where the
  summit trail arrives. Spots from KitWilds._spot kept off the ice. The river's distance is now a 3 m grid baked in
  the plan (the hooks asked every segment at every point).
- **Tests:** snow_land checks no jungle totem grove or great tree on a snow island and a castle only on the summit
  (2 of 3 seeds have one); landmarktest's forced island is now made jungle (its first chain island rolls snow, whose
  great tree is the buried town); snow_foundations' models from a seeded rng (an unseeded one flaked during the
  desert's landing). Render: landmarkshot seed 1 node 1 with `LSHOT_MARKS=totem_grove,great_tree`.
## 2026-10-16: the cutlass's drawn water (Kraken's Wake, the awakened blade)
- **Why:** Zach's test of Demon Slayer's Water Breathing look in Driftwake (Tanjiro key art as the
  reference). His notes as it went: animated pixel-art sprites, "not just arcs"; the first sheets "too
  jagged and solid" -> flowy, ukiyo-e water with bubbles and small swirls along the edges; a swirling
  water trail round the blade once awakened; the blade coil "too tight and circular" -> oval along
  the flat, serpentine; the big upright swirl round you at the payoff "a bit too much" (removed). This
  is the direction for most weapon effects (driftwake-fx "Drawn elements").
- **Art** (`tools/texture_gen/gen_water_fx.py`, its own generator so the 16-sheet library and
  t/fx/sheets stay as they were): `flip_water_slash` (a crescent sweeping over and curling in, claws
  of foam riding its back, pinching into gobs and bubbles), `flip_water_swirl` (two arms spiralling
  out of a dark eye, spinning then slowing, flung apart), `flip_water_curl` (a wave tongue rising and
  rolling over, breaking from the tip): 4x4 frames of 128 px, solid alpha, a 7-step navy-to-foam
  palette. `water_trail.png`: 8 looping frames of 256x64 (a foam crest with claws and bubbles, dashed
  flow lines, eddies along the inner edge). ~4.2 MB with mips in all.
- **FX** (`scripts/game/fx.gd`): `water_arc` / `water_wake` (a `WaterRibbon`, scripts/game/water_ribbon.gd:
  the strip laid camera-facing along an arc that curls in at its head, or flat along the ground; its
  UVs scroll and step through the frames on game time; a `water_curl` at the head, droplets off the
  tail as it pinches into gobs; one shared material, an ArrayMesh rebuilt each frame for its ~0.5 s),
  `water_burst` (one sheet played once, unlit), `droplets` (spray's droplets alone).
- **Kraken's Wake** (TechniqueState `_kraken`, all behind `_elem()`; the plain version is unchanged):
  two coils of water winding opposite ways round you and a swirl as you gather; per blink-cut an arc
  through them (its slant swapping), an eddy (swirl) on them and a wake of water along the ground
  between them, plus the old streak and spray; a rising arc off the blade on the flick; at the tear a
  whirl of water once round you and, under each victim, three rising curls + a swirl in place of the
  geometry tentacles (`FX.water_tentacles` stays for now, unused).
- **The awakened blade** (`BladeWater`, scripts/game/blade_water.gd): with `elem_sword` (the cutlass's
  tier-1 mastery, Call of the Tide) and the cutlass drawn (style "sword", not hybrid), two loose
  serpentine strands of the strip wind up the blade on an oval laid along its flat (the wider of the
  mesh's x/y). Built once per blade size, a child of the weapon mesh; animated only by a sway and one
  shared material's `uv1_offset` stepped once a frame. Co-op: Player's snapshot flag `NF_TIDE` (16),
  puppets call `BladeWater.keep` with it.
- **Cost:** Kraken's Wake at six victims: up to ~8 ribbons alive at once (each one node, one draw,
  <=186 vertices rebuilt a frame), one sprite per cut plus a few droplet bursts per ribbon, three
  curls and a swirl per victim at the tear; it lasts ~2 s. The aura: one node and one draw per drawn
  awakened cutlass (~530 static vertices), nothing rebuilt. No lights. The Brinehollow bench route
  fires neither (no ult, no awakened blade), so it wasn't re-benched.
- **Tools/tests:** abilityshot's `close` view (the captain's blade up close). `t/fx/water`.
  Renders: tools/dev/out/abil/ (g2/s2/g3/night/aura3).

## 2026-10-16: theme places (ThemeDef place hooks) and the desert's first places

- **The hook** (`ThemeDef`, all optional, the jungle overrides none and its islands are unchanged):
  `place_kind(kind) -> String` (the theme's own kind standing in for a chain set piece or landmark, "" keeps
  the chain's), `plan_places(isl, avoid) -> Array` (the theme's own places beyond the chain's, planned first),
  `plan_place(isl, kind, rng, avoid) -> Dictionary` (a stand-in's plan, ground shaped; {} = no ground) and
  `place_steps(isl, ctx, pl) -> Array` (its build steps). A plan is KitSetPieces' shape: `at, y, face, r,
  keep` (place-local discs), `kind` (unique on the island: it names the `Place_<kind>` node), optionally
  `door` (a trail is run to it); KitLandmarks sets `role` "theme" and `seed`. `KitLandmarks.plan_gen` calls
  them, `steps` builds role "theme" through `place_steps`, and `overgrow` now thins by the theme's `growth().x`
  (deterministic, the jungle's 1.0 skips nothing). A mapped set piece that finds no ground push_errors like
  KitSetPieces; a mapped landmark that finds none is skipped like the chain's.
- **The desert's** (`scripts/island/themes/desert_places.gd`, DesertPlaces): an oasis pool on each land-plan
  oasis with room (off sites, places, paths; skipped where the land rises steeply all round): the bed dug 1.5 m,
  the banks levelled and held over the water, InlandPool (swimmable), reeds and lily pads, date palms leaning
  in (MultiMesh, solid), a well-sweep, a camp on the lowest side of the bank (long tent, fire, water jars, a
  couched camel, a lamp, a cache). For the chain's waterfall a caravan's camp (tents round a fire, camels at the
  line, bales, a brazier, a chest), for the great tree an obelisk (13-19 m, glyph columns, gilded cap, its
  fallen twin in pieces), for the totem grove the twin guardians (two seated colossi, one maybe broken with its
  head in the sand, a processional way and a battered gate). Models stand alone in modelshot: `camel`,
  `long_tent`, `shaduf`, `obelisk`, `guardian`. Style water_tint is the oasis's turquoise.
- **Tests:** `t/island/desert_places`; landmarktest (jungle unchanged). Renders: landmarkshot on chain seed 7
  (`LSHOT_MARKS=waterfall,great_tree,totem_grove`), tools/dev/out/desert/lm7_*; models
  tools/dev/out/models/desert_places_*, desert_monuments_*, desert_guardian_*.

## 2026-10-16: the desert's set pieces; cave mouths on themed land

- **Set pieces** (DesertPlaces, standing in through `place_kind`): the **ruined skyline** for the volcano vent
  (high ground, r 28: broken plaster towers in faded washes round a square, their walls in courses of different
  heights, doorways toward the square, dark windows high up; an arcade broken in the middle; a minaret kept away
  from the great dome; the dome's drum broken and its glazed shell torn open on one side, drawn both faces;
  rubble, fallen drums, a cache in a tower). The **buried city** for the sunken village (r 26: 7-10 DesertTown
  houses sunk 1.8-4.8 m with their windows dark (house spec `lit` 0), the ground heaped in mounds between
  them so the sand is walkable terrain; a colonnade drowned to its capitals with one lintel standing, a
  pediment tipped in the sand, one or two dome tops and a minaret's top out of the dunes, a chest). The
  **tomb** for the cenote, so desert islands no longer get the jungle's green sinkhole (a rose sandstone crag
  built like the mine's rock, its front flat and cut open behind a carved temple front: podium steps over a
  ramp, four columns, entablature, pediment, a round pavilion with cone and urn between half-pediments; inside a
  pillared hall 14 m deep at the door's sill with burial niches in two rows, some sealed, a frieze, the
  sarcophagus with its lid askew, braziers and one light, jars, bones, sand blown in, the treasure). The
  guardians now use the obelisk's sandstone. Sand heaps are one untextured material (the sand texture
  pinwheels on a blob's cap).
- **Cave mouths** (KitDungeons, themed land only, the jungle unchanged): the apron in front of a mouth is
  levelled just under its floor. Dunes rolled under the floor's edge on seed 5's grotto, so a captain walked
  under the floor and stuck (dungeontest on main). dungeontest now runs ~150-320 s depending on load (the
  desert's bigger islands); the runner's 330 s limit is close when the machine is busy.
- **Tests:** `t/island/desert_places` builds the three set pieces too; dungeontest, isletest, landmarktest.
  Renders: landmarkshot on seed 7 with `LSHOT_PIECE` volcano_vent / sunken_village / cenote (tools/dev/out/desert/
  sky7_*, bur7_*, tomb7_* incl. tomb_front and tomb_hall, landmarkshot's new tomb views).
- **After the references** (tools/dev/out/refs/desert_*): the great dome's ribs stand across its hole (turned to
  the square), buried houses go down to their windows or their roofs, toppled slabs and a drowned arcade.
- **Perf:** perf_gate (13:00, 1 run) PASS against the baseline 8e7fe77 at calib 23.60 / 23.65: ALL frame 9.41 ->
  10.74 ms (+14%), frame1t 10.36 -> 11.69. Not back to back and it spans everything since the baseline; the
  bench's chain islands on seed 4242 are snow and jungle, so the route never meets a desert, and no desert script
  is among the growers (sea_spray, scuttlebug, moored_hull, ship, ambience). A desert island on its own: prepared
  in 18-30 s on the worker (jungle 11-21), 1.3-2.3 s on the main thread over ~120-130 frames (jungle 1.6-2.8),
  worst step 43-204 ms (jungle 59-389).
- **Fidelity** (fidelityshot on seed 7, tools/dev/out/desert/fid7_sheet.png): open against the royal-city ref:
  the village reads sparse next to its packed boxes and onion domes; the wooden lookout tower and the pirates'
  shacks are still the base kit's timber; the town hardly shows from the sea.

## 2026-10-16: island size sweep (how big can desert and snow islands get)

- **Tool:** `tools/dev/sizesweep.gd` (headless, ~25 min, a measuring tool only: no game code changed). Each theme's
  islands at 1.0 / 1.5 / 2.0 x its own `ThemeDef.radius` (scaled on the registry's def for the build only), chain seeds
  777 / 31337 / 4242 (each seed's first regular island of the theme), built the world's way (prepare on a worker, the
  finish steps timed one by one), then the chain's spacing over 300 chain seeds with the scaled radius[1] going through
  `Chain._make_room`. Output `tools/dev/out/sizesweep.txt` (every build, the slowest steps and prepare stages, errors).
  Timings ran beside other sessions' Godots: ms swing up to ~2x build to build (desert 4242 x1.0 prepared in 57 s,
  bodies alone 11.5 s; elsewhere desert x1.0 12-27 s); counts and memory are steady.
- **Means** (3 seeds; exp = growth over x1.0 as a power of the radius, 2 = with area; mem = static memory the build
  adds, CPU side; geo = estimated mesh + MultiMesh buffers, GPU side):

  | theme | x | r m | land ha | prep s | main s | worst ms | nodes | mm inst | geo MB | mem MB | exp prep | exp mem |
  |---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
  | jungle | 1.0 | 363 | 27 | 7.4 | 1.9 | 145 | 8.6k | 42k | 29 | 110 | - | - |
  | jungle | 1.5 | 545 | 61 | 12.7 | 2.2 | 151 | 15.5k | 101k | 38 | 164 | 1.33 | 0.99 |
  | jungle | 2.0 | 727 | 107 | 23.0 | 3.3 | 356 | 24.9k | 185k | 49 | 226 | 1.64 | 1.04 |
  | desert | 1.0 | 554 | 65 | 32.2 | 3.5 | 352 | 6.5k | 14k | 30 | 102 | - | - |
  | desert | 1.5 | 832 | 144 | 43.8 | 2.8 | 128 | 10.6k | 30k | 42 | 161 | 0.76 | 1.14 |
  | desert | 2.0 | 1109 | 257 | 71.1 | 5.6 | 273 | 16.1k | 53k | 59 | 239 | 1.14 | 1.23 |
  | snow | 1.0 | 413 | 34 | 10.3 | 1.7 | 141 | 8.2k | 41k | 32 | 114 | - | - |
  | snow | 1.5 | 619 | 76 | 21.3 | 2.3 | 168 | 15.7k | 101k | 41 | 165 | 1.80 | 0.91 |
  | snow | 2.0 | 826 | 135 | 31.1 | 2.4 | 212 | 25.9k | 189k | 54 | 243 | 1.60 | 1.09 |

  Desert's x1.0 row is pulled up by the loaded 4242 build; seeds 777 / 31337 alone go 27 / 12 s -> 51 / 23 s -> 61 / 69 s.
- **How each cost scales:**
  - Prepare (worker) = a fixed part (bodies ~2-3 s, the cave plan 0.2-1.5 s) plus stages that go with area: undergrowth
    (jungle 777: 1.3 -> 3.3 -> 5.4 s), land (1.8 -> 3.2 -> 4.9), trees, thicket, shore, arrays. Overall r^1.3-1.8 here,
    heading to r^2 as the area part takes over (the desert, the biggest, is mostly area already).
  - Main thread total barely grows (2-3.5 s at x1.0, 2.4-5.6 at x2.0, ~120-145 steps): the sites and the village are fixed
    counts. What grows is four single steps: plant colliders (one step for every trunk shape: jungle/snow ~50-80 -> 155-541
    ms), the ground's 16 collider squares (GROUND is fixed at 4x4, so each square grows with area: desert up to 572 ms),
    the terrain mesh (one mesh, up to 470 ms) and fauna (up to 640 ms). x1.0 already has 200-600 ms outliers (fauna, boss).
  - Nodes r^1.5-1.7, MultiMesh instances ~r^2 (jungle 42k -> 185k), collision shapes ~r^2 (jungle 4.4k -> 16k).
  - Static memory ~r^1 (110 -> ~240 MB an island at x2.0); geo ~r^0.7-0.9 (30 -> ~55 MB). Nothing held after freeing
    beyond noise (-21..+26 MB).
  - Content doesn't grow: places 4-7 and caves 1-3 at every size; every site and service placed at every size, no
    script errors from the bigger islands. A 2x island is 4x the land with the same things on it.
- **Chain spacing** (gaps coast to coast at full radius; the coast is mostly ~0.8 r, so the real water is wider):

  | grown | x | leg min m | leg mean m | first leg min m | loaded together min m | Brinehollow min m (islands over it) | Redtide min m (over it) |
  |---|---:|---:|---:|---:|---:|---:|---:|
  | desert+snow | 1.0 | 206 | 941 | 959 | 174 | 206 (0) | 147 (0) |
  | desert+snow | 1.5 | 249 | 747 | 639 | 174 | -332 (3) | -197 (2) |
  | desert+snow | 2.0 | 249 | 665 | 319 | 174 | -1013 (3) | -1047 (3) |
  | all themes | 2.0 | 249 | 555 | 319 | 174 | -666 (6) | -773 (3) |

  `_make_room` holds between layers and between a fork's two (islands loaded together never overlap), but nothing keeps a
  grown island off Brinehollow or Redtide Rock, which are always in the world: RING[0] (2000 m) is a centre distance, and
  fork offsets and later layers wandering back aren't held to it. 3 of 300 chains put an island over Brinehollow at 1.5x.
  (Islands of one chain on the same water, never loaded together: 246 -> 556 pairs.)
- **Which limit hits first:**
  1. **Spacing near home, at 1.5x:** islands over Brinehollow / Redtide. A Chain fix (RING and the forks kept off home and
     Redtide by radius), no streaming needed.
  2. **Worker time vs the sail, at 1.5x for the desert:** the next islands start preparing when the log pose sets. After the
     beast falls the crew still walks back to the ship (the arena is 0.5-0.62 r past the middle), which covers it; after the
     15-minute auto-set the crew may already be aboard, and then it's the leg: mean 750 m = ~50 s at the sloop's best
     15.2 m/s (the shortest 249 m = 16 s) against ~45 s (desert x1.5) and 60-85 s (x2.0) of prepare on this laptop, more on
     the min-spec 5600G and with a busy worker. Desert x1.0 (12-30 s against a 940 m mean leg) is fine.
  3. **Main-thread hitches** grow with area in those four single steps: 150-570 ms at 2x, already past a frame at 1.5x
     (colliders up to 243, ground 211). Splitting them (colliders per 70 m cell, GROUND scaled with `res`, the terrain mesh
     in chunks) is plain step work, no streaming.
  4. **Memory** is not the limit: three x2.0 islands ~720 MB static + ~170 MB of mesh buffers, on top of Brinehollow.
  5. **Not measured:** the frame cost of standing on a big island. The vegetation is already 70 m MultiMesh cells with
     visibility ranges and people/fauna sleep by distance, but the terrain is one mesh with no LOD (x2.0 desert: 880 x 880
     cells) and every plant collider and ground square is live. Bench one before deciding past 1.5x.
- **What in-island sector streaming would have to cover** (only past ~1.5x, and it doesn't cut prepare by itself): the
  terrain mesh and ground colliders by chunk (build / free by distance, LOD for far chunks); plant MultiMesh cells with
  their trunk colliders and grapple crowns (GrapplePoints) made when near; site contents (camp, lair, ruins, caves,
  landmarks, the beast's arena) built as a captain nears and kept while anyone's there, their saved state (opened chests,
  cleared camps, beast down) re-applied; fauna dens and nav zones per sector; and co-op: the host simulates enemies, so a
  sector stays live while any captain is near it, and guests stream their own visuals. Prepare would need splitting too
  (the scatter and undergrowth per cell, lazily), keeping only the heights, coast, shore map and paths whole, or limit 2
  stays.
- **Read:** desert and snow can go to ~1.5x their radius (desert ~720-960 m, snow ~540-680 m: about 2.25x the area) with
  three fixes and no streaming: Chain keeps islands off Brinehollow and Redtide, the four big steps split, and the next
  islands start preparing earlier than the log pose's set (e.g. on arrival). Past that, prepare outruns the sail and the
  islands get emptier unless their content scales too.
- **Found on the way (not size-related):** `Chain._name` divides by zero when a theme's 8 names are all given and all
  within two layers (chain seeds 74, 200, 220, 259 of 1-300: "Modulo by zero" in Chain.make). One desert x1.0 build
  logged `Parameter "m" is null` (mesh_storage.h) with two "!F" conditions, not seen in the trial run of the same island.
## 2026-10-16: weather and ground on the snow and desert islands (piece 1: fog colour, snowfall, sandstorms)
- **What:** Zach's direction (docs/snow_island_plan.md, desert_island_plan.md "Weather, sound, effects"): a snow
  island under a white haze nearly always, a light snowfall all the time and heavy spells that close the view in
  (its rain slots heavy snow, its storm a blizzard); a desert that never rains, its rain and storm slots blowing
  sand (a sandstorm), lanterns lit against it. Home and the jungle are exactly as before.
- **KitStyle keys** (BRINEHOLLOW keeps today's): `precip` ("rain" / "snow" / "sand"), `haze_color` (the colour the
  fog leans to, alpha = how far; home's alpha 0: its fog is the horizon as before), `storm_color` (the sky's and
  fog's grey in a storm: home's 0.36/0.38/0.42), `ground_prints` (piece 2). Snow: white haze 0.75, storm white,
  odds unchanged ([0.15, 0.8, 0.95]: heavy snow in ~18% of slots, a blizzard ~5% of them). Desert: a warm dust haze
  0.35, storm ochre, odds [0.6, 0.86, 0.91] (sand in ~12% of slots; was 0.93, ~7% storms).
- **Weather** (`params_in(t, style, k)`: PARAMS' six, then snow and sand): a theme whose fall isn't rain zeroes its
  rain and turns that slot's fall into `snow` (at least SNOW_LIGHT 0.22 always) or `sand`; `murk` (0..1) is a
  heavy fall or a sandstorm closing in: the fog pulls in to 2..65 m, the sky's haze rises to 1.3, the fog colour
  goes to the storm colour (`haze_here`), the sky top pales toward the haze. No lightning where the fall isn't
  rain. Beds: `sandstorm_loop` x sand, `blizzard_loop` x heavy snow (a light fall is quiet), at -6 dB like the rain,
  halved under a roof. F6's toast names them (Heavy snow, Blizzard, Blowing sand, Sandstorm: `state_name`).
  NightLight.is_night() (lamps, the belt lantern) is also true past murk 0.45.
- **PrecipFX** (`scripts/world/precip_fx.gd`, made by Weather beside the rain; GPU particles round the camera,
  each screen its own from the synced weather): flakes (1800 max, a 3x3 pixel cross, lit, drifting on the wind),
  and once murk rises streaks on the wind (sand's long, snow's short and only in a blizzard) and big drifting
  curtains of the flipbook's snow / sand sheet (36, unshaded, dimmed with the night and a storm's dusk). All three
  off (not emitting, hidden) wherever nothing falls: the per-frame cost away from those islands is one _process
  that sets three positions.
- **Co-op:** nothing sent: snow, sand and murk come from world time and the place, like the rain.
- **Tests:** `t/world/theme_weather`. Render: `themewxshot.gd <out> 1 1` (Hoarfell Atoll, snow) and `<out> 2`
  (Mirage Island, desert): tools/dev/out/wx2/snow2_sheet.png, desert3_sheet.png.

## 2026-10-16: weather and ground, piece 2 (footprints in snow and sand, the snow layer, snow and ice steps)
- **One ground system for both** (`scripts/world/ground_layer.gd`, GroundLayer, made by Weather beside the rain;
  KitStyle `ground_prints`: "" home and jungle, "sand" desert, "snow" snow). Not decals (Forward+ shares its 512
  clustered slots between lights and decals). Prints are pixels in one 512x512 RGBA8 texture wrapped over the world
  every 42.7 m (12 px a metre): r depth, g/b the clock when pressed (16 bits of quarter seconds), a which wrap of the
  world (4 bits of x and z, so prints 40 m off never alias here). A footstep paints ~10 texels (a boot, oversized to
  read at the camera's distance: 42 x 19 cm, feet 14 cm off the middle) and the texture goes up at most every 0.1 s
  when something changed; the fade (the last half of LIFE: snow 70 s, sand 45 s) is the shader's, from the global
  `ground_prints_at` (now, life), so nothing runs per pixel on the CPU. Shader side:
  `shaders/world/ground_prints.gdshaderinc` (`ground_print(xz)`: 0..1 in three pixel-stepped grades); globals
  `ground_prints` (sampler2D) and `ground_prints_at` in project.godot.
- **Who prints:** Player._on_footstep on every machine for every captain it sees (puppets too: synced positions),
  so co-op sends nothing; `GroundLayer.step` presses the print where the foot came down (left/right by step count)
  and kicks up one puff of the flipbook's `snow` / `sand` sheet (2 when sprinting; none when sneaking, which still
  prints) in place of the brown dust. A landing on soft ground throws a `puff_ring` of it (Net.fx). Only on the
  theme's own soft surface (snow on a snow island, sand on a desert); off it (rock, decks, paving) nothing.
- **Terrain** (`terrain.gdshader`): `prints` + `print_tint` (PSXMat.terrain's new `prints` argument, from GenIsland's
  style; a blue shadow in snow, darker sand) multiply the ground in a print. Home's terrain material has prints off:
  same output.
- **The snow layer** (`shaders/world/snow_layer.gdshader`, a next pass on a snow island's terrain material): the same
  triangles raised 0.24 m where the splat is the theme's grass (snow), off steep rock, paths and the shore, so boots
  sink into it; no collider, no slow (Zach's movement is input x speed: I left wading at full speed; a small slow would
  go in MoveState beside thicket). Only near the camera: it settles onto the ground from 31 to 48 m and its vertices
  past 54 m are thrown off screen (no fill for the far island; the vertex pass is ~100k trivial vertices on a snow
  island only); casts nothing. A fresh print is a hole down to the darkened ground under it, a fading one a shadow.
- **Footsteps** (`scripts/game/footsteps.gd`): the terrain's layer is now read through its texture (a snow island's
  grass, packed paths and snowy beach are `snow`, its glacier rock `stone`; a desert's dunes `sand`, hardpan `dirt`),
  textures with snow / ice in their names are `snow` / `ice` (the frozen lakes), and a GenIsland's ground collider
  (Ground<n>, a body beside its Terrain mesh) is read as its terrain. That last one changes jungle islands too: their
  steps were judged from the GenIsland's own meshes before (mostly sand); now grass, dirt, sand and stone like
  Brinehollow's. `step_snow` / `step_ice` are in FX.SOUNDS.
- **Breath:** in a snow zone every captain within 30 m of the camera breathes a little `mist` every 2.8 s (local).
- **Gotcha:** a render after editing only the .gdshaderinc drew the old shader (the cache keyed on the main file):
  touch terrain.gdshader / snow_layer.gdshader too.
- **Tests:** `t/world/footprints`, `t/world/footstep_surfaces`. Render: `themewxshot.gd <out> 1 1 steps` and
  `<out> 2 - steps` (tools/dev/out/wx2/snowsteps_steps_eye.png, desertsteps_*).
## 2026-10-16: desert polish (the medina, its own lookout and camp, the bandit chief, vultures)
- **The medina** (VillageLayouts `_medina`, a new layout; POOL and BRINEHOLLOW's `village_layouts` carry it at weight
  0, so jungle and snow roll exactly as before; the desert's weights are medina 5, town 2, hamlets 2, ruins 2): the
  town's heart, souk and services, then flat roofs packed ~0.4 m apart instead of the town's metre (`_take`,
  `_ring_fill`, `_street_houses` take a gap; their defaults are the old numbers, same rng draws): a ring round the
  plaza, rows along every street and four lanes (12 a street), 2-3 minarets (`_minarets`, 17-23 m) and rings at 27,
  36 and 44 m facing in; the great domed hall (`DesertTown.great_hall`: portal in a raised frame, arched windows,
  corner turrets under little domes, the big onion dome on a windowed drum, ~14 m) across from the road in. Seed 7
  forced medina: 88 buildings (the town had ~26). Desert garden walls (`DesertTown.mud_wall`) and agave pots
  (`planter`) through `item_models` in place of the jungle's timber fence and green bush.
- **Its own lookout and camp house** (generic KitStyle keys, BRINEHOLLOW "": the kit's timber tower and rough house):
  `lookout` (a theme model made at its platform's height; KitStyle.lookout(st, h, seed) for the camp's, the summit's,
  GenHarbour's and the trading post's towers) and `camp_shack` (IslandContent._camp). The desert's: `watchtower`
  (mud brick in two setbacks, slit windows, beam ends under a crenellated platform open where the ladder arrives on
  +Z, a domed kiosk on four posts; the timber tower's interface: platform top at h + 0.09, the summit chest and View
  area unchanged) and `bandit_hut` (an unwashed blockhouse, broken parapet, striped lean-to over a rug, hides on the
  roof, jars and sacks).
- **The bandit chief** (`scripts/enemies/bandit_chief.gd`, extends PirateBoss): the desert's second mini
  (`minis` hyena, bandit_chief: an island gets one or both). A mini whose entry has `"camp": true` leads the pirates'
  camp in its captain's place (IslandContent._camp merges his script, look and name into the captain's setup;
  GruntCamp builds a setup's `"script"`), so the bounty names him. Morrow's fight under a turban with a scimitar,
  620 hp and every blow scaled by Levels, his own barks, a miniboss's pay. PirateBoss gained overridable `_boss_look`,
  `_boss_hp`, `_barks`, `_prize` (Morrow's values unchanged).
- **Minibosses spawn on every theme**: BeastDens._mini handled only the jungle's "boar", so the desert's hyena and the
  snow's frost alpha never appeared. Now any beast mini goes to its entry's site, named `kind.to_pascal_case()`
  ("Boar" as before).
- **Vultures** (SkyBirds kind VULTURE, KitStyle `high_birds` "dark" | "vulture"; the desert's "vulture"): an island's
  high flocks become kettles of 3-6 big (2.9x) dun-brown birds wheeling slow on a thermal, soaring with a few slow
  beats, silent. Shader paint 6. Same rng draws as the dark flocks.
- **DrawLOD on generated islands** gets 64 steps (was 24): its last step does whatever is left, and the medina's
  geometry overran 24 steps into a 722 ms frame. Extra steps are no-ops once done.
- **Proof:** islanddump main vs branch: chain seed 4246 (jungle) byte-identical, Brinehollow the three dummies only.
  **Tests:** t/island/desert_town (hall, minarets, watchtower ladder and platform, hideout, planter, wall, medina in
  the pool), t/island/bandit_chief, villagetest (medina: 40+ buildings, minarets, the hall), the -Changed -Light set.
  Renders: tools/dev/out/polish/med7_sheet.png (villageshot seed 7 medina), fid7_after_*, g7_camp, models/desert_skyline_*.
## 2026-10-16: Chain._name no longer divides by zero
- When every name of a theme was already given on islands within the last two layers, both pools were empty and `rng.randi() % 0` broke Chain.make (chain seeds 74, 200, 220, 259). Now it falls back to a name not on this layer, then any of the theme's names; chains that never hit the empty case draw the same rng values as before.
- BeastPool.assign had the same hole (a theme's bosses all on the islands before): falls back to the whole pool. Test: t/world/chain_names (those four seeds: every island named, beast set).

## 2026-10-16: snow polish (fences, the tame shagback, the frozen wreck, no jungle bugs)
- **The village** (snow style): `item_models` torch -> its iron lamp (lit ones light at the Flame), fence ->
  `SnowProps.fence` (dark posts with snow caps, two rails, snow on the top rail, drifts at the foot), planter ->
  `SnowProps.planter` (a hooped tub with a snowy fir). KitStyle `yard_fences` (BRINEHOLLOW 0; snow 0.7): each side of a
  hut's, tall house's, home's or the elder's yard gets a 4.4 m fence along its side wall where there's room
  (VillageLayouts._yard_fences, its own stream per building, so a 0 draws nothing and the jungle's village is unchanged).
- **The tame shagback** (Shagback `tame`): blanket, trim, packs and a girth rope (one more cached part variant), stands
  about its post (wanders 0.6-2.5 m), struck it shies ~2.5 m and comes back, no herd stampede, worth nothing; its LOD
  from the nearest captain on a Timer (it has no FaunaSpawner, and a sleeping creature's _tick stops). SnowTheme.steps
  adds "village beast": at the market's edge (the plaza's if no market) on the first spot clear of the plan's buildings,
  items and paths, named VillageShagback under the island (same on every machine).
- **The frozen wreck** (snow_places `snow_wreck`, standing in for the chain's wreck landmark): off a beach away from the
  dock, 4-9 m out over 0.8-3.5 m of sea with open water past it; the kit's wreck hull (KitLandmarks._wreck, stove in on
  her low side) frozen in at her waterline (origin 0.95 over the place, the ice's top 0.75 over the sea) in a ragged
  slab of pack ice reaching back onto the beach (one trimesh collider), ridges of pitched ice blocks, snow on her deck
  and quarterdeck, icicles off her rails, drifts against her sides and mounds on the ice, the chest on the ice in her
  hold (`snow_wreck_chest`). The trail arrives on the beach behind her.
- **No butterflies or fireflies on snow** (KitStyle `ambient_bugs`, BRINEHOLLOW true; FaunaSpawner.roll clears them after
  its draws, so the bird flocks over the pines stay and nothing else moves).
- **Proof:** islanddump main vs branch, chain seed 4246 (jungle) identical, Brinehollow the three dummies.
  **Tests:** t/island/snow_village; snow_foundations, snow_land, villagetest, landmarktest. Renders:
  tools/dev/out/polish/snow1_before_sheet / snow1_after_sheet (villageshot seed 1 node 1), sw1_snow_wreck_close
  (landmarkshot seed 1 node 1, LSHOT_MARKS=wreck), models/snow_village_sheet (the tame shagback, fence, tub).
- **Left:** the shallows' turquoise is the ocean shader's `shallow_color`, set by Weather (a theme-tinted shallows
  wants a KitStyle key read there); the market's planter (KitMarket) and Buildings.planter elsewhere still hold a green
  bush; temples and mines from the shared landmark pool still come to snow islands (their stone takes the theme's
  temple/rock tints).
## 2026-10-17: flowing lock hairstyles (HairFlow, prototype)
- **What:** Zach asked whether we could make hair like an anime-figure reference sheet (long layered locks, ponytails, buns,
  manes, ombre). `scripts/npc/hair_flow.gd` (HairFlow) builds eight new styles from many locks: cascade (waist, centre part),
  high_tail, waves, princess (thigh length + ahoge), court_bun (blunt bangs, pinned bun, gold sticks), twin_low, half_bun,
  mane. Not in any random pool or the creator yet: set `lk["hair"]` directly. Optional `lk["hair_tip"]` = ombre tip colour.
- **The lock:** a lens-section tube (6 sides) along a path, edges curled toward the head, root_k at the root, pointed by
  `tip` (higher = later, blunter). Untextured (`PSXMat.lit("")`) with per-vertex colour: root -> tip by height (by length for
  tails), undersides 0.72, an "angel ring" sheen band at y 0.255. The textured hair speckled badly on light colours; the shell
  under these styles is untextured too (`HairFlow.shell_mat`). `MeshBuilder.add_tri` takes optional per-vertex colours (`vc`).
- **Masses:** `_mass` lays a layer of hanging locks round an arc; neighbours share the wave phase (random phases crossed
  like spaghetti). Below the jaw every lock turns to lie in front of the shoulder (fwd 1) or on the back (>= 138 deg):
  nothing hangs off the point of the shoulder. `_clear_body` pushes points out of a per-height neck/shoulder/chest ellipse
  (head space, from the arm joints and the torso collider). Gotcha: wrap angles before lerping (256 -> -138 went round the
  front and made a collar).
- **Physics:** guide chains every ~30 deg per mass (`sim.add_chain`, colliders head, torso and a new `hair_sh` capsule
  across the shoulders); each lock ring is skinned to the guide's bone at its height, rings above the guide to a never-posed
  `hair_root` bone. Tails are a centre-line chain (`_bundle`, a parallel-transported frame: a per-point frame flipped where
  the tail turned vertical and pinched it into beads). Uses SpringChains' public API only (the cape work owns that file).
- **Hats:** under a hat (not headband/crown) bangs, ahoge, buns, scalp strands and the mane's crown rows are left off;
  masses start below the brim and tails tie lower.
- **Cost:** 6.9-9.9k triangles, 31-86 bones, 1-2 surfaces per head (the old long styles: 80-560 tris, 4-28 bones). Fine
  for the player and named characters; crowds would want fewer sides/rings or a far LOD before these go in the pools.
- **Tools/tests:** `tools/dev/hairstudio.gd` (lineup, HAIR cost lines, HS_HAT); `t/player/flow_hair` (every style
  with and without a hat: chains, committed mesh, triangle/bone caps; its settle check came out, no hair physics tests).
## 2026-10-17: capes: mode A with its safety net, the cloak, trapezoid tattered capes, the lantern on the hip's side
- **Why:** Zach played the cape lab's modes and picked A on both looks; the thick look became an item; then the capes'
  shape (less square: a trapezoid with a torn hem), painted folds, and the belt lantern off the cape's back.
- **Default:** `BodyBuilder.cape_mode` "a" (`CAPE_MODES` a, a0, b, c; F1 cycles, **Shift+F1 the net on/off**,
  `cape_net`) for every cape and cloak, player, NPCs and co-op puppets (each machine builds its own). BG (Godot's
  SpringBoneSimulator3D) removed from CapeMotion: no angle limits, it flipped the cape out after a 180, Zach won't use it.
- **The net** (`SpringChains.net`, `_net_clear`, scripts/npc/spring_chains.gd): on the **drawn shape only**: the
  simulation never sees it, so where the cape is clear of the body A with the net is A to the frame (capelab: the hem
  on every untouched frame matches the same frame without the net to < 0.4 mm). Per segment: (1) a swing limit off its
  rest direction (`NET_SWING` 1.5 rad, the top segment from the shoulders `NET_SWING_TOP` 1.0: a landing threw it up
  over the shoulder and turned the sheet's top row inside out; swung far aside it carried the cloak's wrapped edge in
  over the back); (2) its sheet's probe lines (`set_probes`, offsets across the sheet, turned with the bone as the skin
  is) against the thighs and shins: inside `CUSHION` 2.5 cm the gap kept is eased (`C * exp((g - C) / C)`, never
  reaching 0, C1 at the cushion's edge), so it rides off a leg before touching; (3) out of the hips and behind the back
  plane (the chain points and the sheet over the middle of the back) hard; found by bisecting a turn back about x
  (`NET_TURN` 0.9 most); no turn clears it: left as it is (popping helps no one); (4) the turn follows its target at
  `NET_IN` 40 / `NET_OUT` 8 rad/s (an instant target jumped the cloak's hem 23 cm in a frame in the spin); (5) the
  cloak's edge chains stay on their side of the middle chain by half their spacing (`set_side`). The bones are judged
  at rest length along the drawn direction (where pose_local puts the skin). A step-level cushion (B's) was tried
  first: it changed A's trajectory in 2/3 of frames (the padded thighs are within 5 cm of the cape most of the time),
  so the net moved to the drawn shape.
- **Numbers** (capelab, 144 fps, the same scripted run; "araw" = A without the net):

  | | pen vert-frames (frames), worst | legs | back | jitter mean / p95 / max mm | swing max | ms/frame |
  |---|---|---|---|---|---|---|
  | cape A | 10 (9), 1.0 cm | 5, 1.0 cm | 5, 2 mm | 3.56 / 16.6 / 156 | 66 | 0.20-0.25 |
  | cape araw | 331 (173), 7.9 cm | 292, 7.9 cm | 37, 4.9 cm | 2.48 / 10.0 / 136 | 69 | 0.055 |
  | cloak A | 120 (51), 3.7 cm | 0 | 120, 3.7 cm | 3.70 / 18.3 / 173 | 66 | 0.38 |
  | cloak araw | 210 (74), 3.9 cm | 43, 1.6 cm | 167, 3.9 cm | 2.43 / 10.2 / 147 | 69 | 0.165 |

  The net touches ~40-50% of frames (the cushion near the thighs while walking), moving the hem up to ~22 cm on those
  frames (swing up to 6-13 deg). The cloak's remaining "back" count is its wrapped edge passing over the upper back in
  the sharp 180 (4.4 s): open. Jitter rises ~1 mm mean (the cape now rides the legs instead of passing through them).
- **Cost:** +0.15 ms per caped character, +0.2 per cloak (GDScript probe tests; the cloak has three chains). No NPC
  wears a cape or cloak (gear only), so the Brinehollow bench doesn't see it; co-op: up to 4 captains.
- **The cloak:** accessory `cloak` / `cloak_color` (Gear, GearIcons icon, CharacterLook), Sela sells it (tier 1, 110),
  saves like any gear. The old thick look: a yoke, gathered collar, doubled sheet 7 across on three chains, sewn edges,
  rolled hem. Worn with a cape, the cloak wins (one drape on the back). Not in the creator or random looks (capes
  aren't either).
- **Shape** (both, `BodyBuilder._drape_rows`): a trapezoid, `DRAPE_FLARE` 0.78 to 1.42 x the shoulders, straight sides
  to a straight hem, a row between each pair of chain points; `cape_tatter` / `cloak_tatter` (0..1, seeded by the
  piece's colour) nicks the sides (edge points between rows pulled in) and tears a ragged row of tongues and notches
  under the hem (the cloak's rolled hem only when untorn). Defaults: a cape 0.5, a cloak 0; Sela's cape 0.15, the
  plunder cape 0.85. Gear carries the key (`ACC_TATTER`).
- **Folds:** `drape_fabric` / `drape_canvas` (tools/texture_gen/gen_drape_textures.py, 64x64): vertical folds stepped
  into five levels with a 4x4 ordered dither at their edges, two uneven folds a tile, wobbling down it.
  `MeshBuilder.add_strip_grid(..., u_span)` lays the u of a sheet's columns evenly edge to edge so the folds gather at
  the collar and fan out to the hem.
- **Belt lantern:** hooked on the right hip's side, round 0.4 rad toward the back, just off the belt or the coat
  (`BodyBuilder._lantern_spot` -> `Humanoid.lantern_spot`), resting leaning out (`BeltLantern.LEAN` 0.3: its foot out,
  its top at the hip). Swing, light, toggle and co-op unchanged. Open: an off-hand blade's sheath also hangs on the
  right hip and may meet it (not checked).
- **Tests:** no cloth physics tests (Zach: they'd flake and stop runs): t/cloth/cape_modes deleted, and lighttest's
  lantern swing checks with it. qoltest wears the cloak (icon, armour); cliptest checks coats and vests under the cloak's
  yoke. Renders: `tools/dev/drapeshot.gd` (capes, cloak, coat, lantern from four sides), capelab.
- **capelab:** modes a, araw, a0, b, c x cape/cloak; penetration by legs/hips/back; each "a" frame against the same frame
  without the net; runs start from the same seed and body clocks (they still drift apart: the whip is chaotic).

## 2026-10-17: Brinehollow buildings polish, piece 1: doors and steps (Buildings.house, tavern, smithy)
- **Doors:** `Buildings.panel_door(mb, xf, w, h, leaf, frame, fan)` (scripts/props/buildings.gd): a closed leaf
  with the new `door_panel` texture (32x64, four raised panels, pale so a tint paints it; gen_psx_textures.py
  `doors` mode), jambs, a head and drip cap, a threshold, iron strap hinges and a ring pull; two leaves at 1.6 m+;
  `fan` (the window material) turns the top 0.34 m into a fanlight. `door_leaf(paint)`, `door_paint(seed, trim)`
  (its own hash of the seed, so the house's rng stream is untouched: bare wood half the time, else the trim lifted).
- **Buildings.house:** new spec keys `door_w`, `door_h`, `door_paint`, `fanlight` (defaults: 1.0 x 2.0; h >= 2.9 a
  2.4 m door with a fanlight; h >= 3.4 a 1.8 x 2.5 pair). Painted leaves get a dark timber frame, bare ones the trim.
  Front windows too close for their shutters move clear of the frame, or lose their shutters on a narrow house (no
  rng draw changes). The lantern and the bench keep clear of a wider door. A "Door" marker at the foot of the steps.
- **Steps:** `Buildings.door_steps(body, mb, mat, x, z0, top, width, land, found, timber)`: a landing (0 = the
  porch is the landing), RISE 0.16 / TREAD 0.34, stone blocks into the ground (wider going down) or timber treads
  on stringers with the landing on posts; a box under the landing and a ConvexPolygon ramp over the treads
  (25-32 deg; nothing in the game steps up by itself, NPCs walk 45). Ground houses: a stone stoop off the footing's
  edge (the old step stone z-fought the footing's top). Stilts: a timber stoop deck and a stair (they had loose
  treads with no collider, and with a porch the treads went through it). Porch houses: steps off the porch's edge.
- **Porches:** the floor starts at the footing's edge (it z-fought the footing's top), a stone plinth under it on
  the ground (it floated 0.14 m), a collider, posts up to a header beam under the roof (they poked through it).
- **Awning goods** stand on the ground either side of the steps (they floated at floor height).
- **Tavern:** stone steps with a ramp (the 0.3 m step box had no way up), its two leaves standing open inside, a
  threshold; the barrel by the door moved off the bottom step. **Smithy** (open-fronted, no door): a dressed kerb,
  a half step up onto its floor.
- fidelity.gd counts a body with `door_panel` as a house too.
- **Tests:** `t/island/house_doors` (every house kind and the tavern: the door, the marker, walkable steps by
  downward rays, nothing in the way, the tavern open inside). Brinehollow's islanddump changes only in houses,
  the tavern and the smithy (meshes, step colliders, Door markers, the warehouse's lamp 0.4 m along).
## 2026-10-17: the katana pass, piece 1 (the combo on swing paths, the drawn steel slash)
- **Why:** Zach: "the animations don't match the slash effect directions" (docs/katana_polish_plan.md). The combo was
  keyed arm angles with fixed arc meshes (`FX.slash` kesa_r / sweep_l / thrust) that only roughly agreed with the blade.
- **Animation** (`scripts/npc/katana_moves.gd`, KatanaMoves; ActionSpecs katana_r / katana_l / katana_stab / air_slash):
  the right hand rides a swing path, `_katana_hands` keeps the left on the hilt. Points are offsets from the sword
  shoulder in the chest's frame (`from_shoulder`, `follow` 1). katana_r (0.85 s): up over the right shoulder (jodan,
  the blade laid back), a beat, down through the front on a given diagonal plane (-0.8, 0.6, 0) to low left; the chest
  turns only ~0.45 rad (turned further, the hands ran off left and the blade lay flat across the body). katana_l
  (0.75 s, chains from hit 1's finish): up to the left shoulder, then level across at waist height to the right
  (plane given: level). katana_stab (0.9 s): back to the right hip with the point on the target (the wrist break lifts
  it: in the sagittal plane the trailing side is forward there), then a lunge with the blade in line. air_slash
  (one-handed, 0.6 s): up by the left shoulder, a beat, one arc down through the front, under the drawn-up knees and
  out right; its body is a small turn now (the old keyed one turned the chest ~1.8 rad and the blade never went under);
  PlungeState SLASH_HIT 0.2-0.36 s to match. quick_draw keeps its keyed pose (it gained a "swoosh").
- **Effects:** `PetalRibbon` (scripts/game/petal_ribbon.gd), made by `FX.katana_slash(body, secs, awake, width, thrust,
  seed)` over the move's "swoosh" window: it samples the real blade's tip every frame (not while the body is frozen in
  a hit-stop) and lays the drawn strip along that path (Catmull-Rom between frames), camera-facing with the crest on the
  outside, so a diagonal is diagonal and a side cut level, whatever the camera. Plain: steel_trail.png (a thin crescent of
  steel, gust hooks, dust fraying off the inner edge). Awakened (the katana tree's mastery, `Progression.elemental
  "katana"`): petal_trail.png, ~2x as wide, cloud lobes along the crest, parting into puffs from the tail, a
  katana_cloud sheet at the head and sakura shed along it. A stab is laid along the blade's line (`thrust`). Still with
  the thin additive BladeTrail on top. `KatanaFx` (scripts/game/katana_fx.gd) picks plain/awakened and sends it
  (Net.fx: every screen lays its own along its copy of the body). `FX.katana_burst` (one drawn sheet, unlit),
  `FX.sakura` (drawn petals that turn over as they fall; `FX.petals` stays for the toucan and fruit).
- **Art** (`tools/texture_gen/gen_katana_fx.py`, its own generator like gen_water_fx.py; t/fx/sheets untouched):
  flip_steel_slash, flip_katana_slash, flip_katana_cloud (4x4 of 128 px), flip_sakura (4x4 of 64 px), steel_trail and
  petal_trail (8 looping frames of 256x64). Palettes: steel and dust; sky (navy to white); sakura.
- **Tests:** t/combat/katana_slash (hit 1 high right to low left, hit 2 level left to right, hit 3 a thrust at the
  target, from the ribbon's samples in the body's frame; each lands on the dummy). Renders: tools/dev/out/anim_before_*
  (the old keyed combo), tools/dev/out/klab/ (lab sheets), tools/dev/out/kab/ (abilityshot).
## 2026-10-17: the forest island theme, piece 1 (foundations: woods, hills, rivers, falls)
- **What:** the fourth First Sea theme (docs/forest_island_plan.md), registered after the desert (`IslandThemes.SCRIPTS`,
  weight 1.0: a quarter of the chain's islands; chains that open on a forest: 5, 7, 9, 13, 14, 15...). Files:
  `scripts/island/themes/forest_theme.gd` (contract, land, style), `forest_land.gd` (the land), `forest_life.gd` (36 names,
  7 roles - woodcutter, charcoal-burner, herbalist, mushroom-seller, storyteller, raftsman, cider-presser - barks, rumours,
  quests in a lumber town's voice), `forest_places.gd` (ForestPlaces), `scripts/props/forest_plants.gd` (ForestPlants),
  `forest_props.gd` (ForestProps: lantern post, owl waymark), `forest_town.gd` (ForestTown, piece 2),
  `tools/texture_gen/gen_forest_textures.py` (forest_litter, forest_dirt, forest_rock, forest_beach; leaves_maple / oak /
  birch / beech / late; fir_needles, birch_bark, beech_bark; bracken, autumn_grass, autumn_bush cards; logs, shingles,
  plaster_wash, river_cobbles, moss_stone, wisp_glow). Islands 340-460 m.
- **The woods** (mesh slots): giant = maples (scarlet with orange, one gold), fig = oaks (one ancient, hollow at the foot),
  kapok = beeches (copper on smooth grey trunks, over the canopy), emergent = firs (dark tiers), roof = red/gold crown
  pieces; tree = birches (1-3 white stems), young maples, a young fir, a dead snag; beach_tree = shore pines and alders;
  bush = autumn shrub cards and leaf bushes; fern = bracken; grass = dry grass; shrub = saplings; broadleaf = leaf piles,
  a fallen log, toadstools; bamboo = stumps and toadstool rings; mangrove = cattails; rock = mossy granite. A broadleaf
  is a trunk forking into limbs under a crown of leaf blobs (`_broadleaf`: two leaf textures by share at most, shaded
  darker underneath); its detail is root flares, bracket fungus, a dead limb, toadstools. Woodlands (`forests`, one per
  island): autumn maple, birch and pine, ancient oak grove, misty firs (more rivers, higher hills). Canopy ~22 m.
- **The land** (`forest_land.gd`, on the land hooks): rolling hills (`roll_h` 6-10 m of noise over the base land, giving
  way round the sites), 1-2 rivers (3 in misty firs) from the summit's flanks to the sea. A river's surface is worked out
  along it in the plan from the land it crosses (the base's height + the hills): a metre under it, down at least 0.12 m
  a 12 m step, never up, never under `FLOOR` 1.4 m inland (where the land is lower its banks are raised to hold it) until
  the coast. So where the land rises it cuts in; and with falls (70%; the furthest down its first half where it can drop
  6-11 m and still run over its floor) the river runs on below the land in a gorge until the land comes down to it: the
  cross-section is a wide valley where the cut is shallow (banks 22 m) and steep walls where it's deep (4.5 m). The bed
  0.9 m under the water (wading), a 2.6 m pool at the falls' foot. The river's distance and surface are baked on a 3 m
  grid in the plan. The first river is aimed past the dock's side (`_dock_angle` replays GenIsland's dock pick from a
  copy of its stream) and the town stands beside a river (`village_at`: 47 m + its half width off the water's middle,
  down in the valley rather than on the summit's flank). Paint: rock bed, mud banks. Nothing grows in the water.
- **Steps:** `forest river` (the flowing water strip along each river where its bed is - not where a site's flat or a
  place filled it - the falls' curtain and sheet, foam, an InlandPool at the foot, mist and its rush), `forest bridges`
  (a plank footbridge with rails and a collider where a path crosses a river).
- **Style:** log and plaster walls, shingle roofs everywhere (mat thatch = shingles), steep pitch 0.95-1.15, chimneys, river
  cobbles, its lamp, the autumn ground, folk in flannel reds, mustard, forest green, knit caps and hoods, vests and
  jerkins; cloudier and wetter than the jungle with a pale haze. Interim beasts and wildlife (renamed jungle/snow kinds)
  until piece 3/4.
- **Proof:** islanddump of chain seeds 1 (jungle), 4 (snow) and 2 (desert), whose first islands still roll the same theme:
  byte-identical islands before and after (tools/dev/out/forest/dump_before_* / dump_after_*). Build: prepare ~15 s on the
  worker (land 2.0-3.0 s with the river grid), ~2-3 s on the main thread over ~165 frames, worst step ~150-230 ms.
- **Tests:** `t/island/forest_land`. Renders: `genshot.gd tools/dev/out/forest/g5 5`, `forestshot.gd tools/dev/out/forest/f5 5`
  (new tool).

## 2026-10-17: Brinehollow buildings polish, piece 2: the other buildings' doors
- `Buildings.door_steps` takes a `frame` (a stair along a side wall); stone treads flare only over the first three.
- **Chapel:** a pair of oak panelled doors in a wider stone surround, the tower on its own base course (its front
  stood 0.15 m past the hall's footing, over nothing), stone steps with a ramp, a Door marker.
- **Harbour tower:** the door sat on the shaft half buried in the battered base; now a stone porch built out past
  the base with a panelled door, a cap, a collider, steps up to its 0.3 m sill, a Door marker.
- **Lighthouse** (Props.lighthouse): its door hung 2.1 m up on the tower's corner with no way up; now a stone porch on
  that corner with a panelled door and a stone stair up the side of the base (along +X, clear of the keeper's
  cottage and stores), a collider for the base's top (r 2.6), a Door marker at the stair's foot.
- **KitHouses** (small edits; the layout agent owns the file): the room's open leaf and the granary's hatch are
  panelled (the hatch framed). **Snow:** the round house's door framed and panelled, stone steps with a ramp
  (its step slab had no collider), the hood raised to clear the frame; the log store's door framed, a timber stair
  with a landing and ramp, a Door marker. **Desert** (DOOR_PAINT): houses' leaves panelled, stone steps (the step
  block z-fought the footing), the awning centred on the door; rooms' steps with a ramp (the 0.35 m step box had
  none), their door standing open inside, the Door marker past the steps; the inn's door framed and panelled, steps
  up into its arcade; the workshop's arches get steps; the great hall's portal doors framed, steps with a ramp.
- Stalls have no doors (counters); the smithy is open-fronted (its kerb is piece 1's).
- **Tests:** t/island/house_doors also walks the chapel's, the harbour tower's, the lighthouse's and the snow
  store's steps; t/island/desert_town, snow_foundations, snow_village, theme_registry pass.

## 2026-10-17: ship upgrade lines (Tackett's yard, piece 1)
- The four one-time refits are now tiered **upgrade lines** (docs/ship_upgrades_plan.md): `ShipLines`
  (scripts/ship/ship_lines.gd) holds each line's levels as [name, what, gold, materials, effects]; effects sum
  over every level reached (`ShipLines.total(kit, key)`: hull, speed, turn, dmg, reload, range, guns). Hull
  plating 6 levels (+8% hull each), gun deck 5 (+5% damage at 1, 3, 5; the quarterdeck pair at 2; 5% faster
  reload at 3 and 4; +8% range at 5), sails 5 (+3% speed each), rudder 5 (+6% turning each).
- The kit holds each line's level as an int under the line's id. **Save migration** in `ShipKit.merged`: an old
  refit (a bool) becomes its line's `legacy` level (armour 5 = the old 40%, guns 2 = the third pair, sails 5 =
  15%, rudder 5 = 30%), so nothing bought is lost; numbers are clamped to the line's top.
- **Every level shows** (`ShipParts`, scripts/ship/ship_parts.gd, node "Upgrades" under ShipModel): the fixed
  parts are one folded mesh (UpgradeMesh, 600 m, no shadow) plus UpgradeFine (rivets, shot, pegs; 90 m), rebuilt
  only when a level changes. Plating: painted wales, iron knees, full straps and band (the old refit), an
  iron-shod stem, iron-capped rails, riveted stern quarters. Guns: shot racks, the aft pair, then
  `ShipCannon.fit(lv)` (brass bands, an iron shield on the yoke, a longer barrel; `muzzle_speed` per gun).
  Sails: reef bands, a jib (furls with the main sail: `show_sail`), a longer yard, studding sails on booms past
  the yard's ends, full canvas with a masthead truck and pennant. Rudder: a rudder on iron pintles that turns
  with the helm (`steer`), a brass-rimmed wheel, a binnacle, a balanced blade, a gilded taffrail.
- The sail grows by `Ship.rig_scale` on the yard, sail and furled canvas (not the Rig node: Jolt can't take a
  stretched scale on the swing ropes' areas, which logged an error with the old refit).
- The yard screen is a tree of lines (Refits tab: a group header and branches, pips per level, the next price on
  the button, hover/focus for what it does; Paint tab: the old looks). Gun stats come from Ship.GUN_* times the
  kit's totals.
- Tests: t/ship/upgrade_levels, t/ship/refit_migration, t/ship/yard_buy; yardtest's refit checks moved to levels.
  Render: yardshot (each line at each level, full kit side/bow/stern/far/deck/night, the two tabs).
## 2026-10-17: the forest island theme, piece 2 (the lumber town on its river)
- **Town** (`scripts/props/forest_town.gd`, ForestTown, through KitStyle `village_models` / `item_models`; no hub or
  Buildings change): `hut` a log cabin (round logs in courses notched at the corners and running past them, the front's
  broken by the door; chinking behind; a steep shingle gable roof with a ridge board and planked gables; a fieldstone
  chimney up one end with smoke; small shuttered lit windows; a porch roof on two posts now and then; a woodpile and a
  chopping block with its axe; 30% a loft with a gable window), `tall` a two-storey timber-framed house (fieldstone or
  plastered ground floor, the upper floor jettied 0.35 m on joists, plaster panels in five washes between dark posts,
  rails and braces, the gable to the street framed too, flower boxes), `workshop` the cooper's and sawyer's shed (Worker at
  the sawhorse and its half-sawn log, Bench; barrels in the making, staves and hoops, shavings), `storehouse` a timber store
  on stone pads with racked boards under a lean-to, `shrine` a carved stag post with antlers under a shingle hood, stones,
  offerings (Keeper, Pray). Dressing items: the forest lamp for torches, split-rail fences (55% of yard sides), woodpiles.
  Rooms (homes, the trader, the cookhouse, the inn) are the kit's with log walls and shingles from the style
  (`mat.thatch` = shingles). One merged mesh each, 8-13 surfaces, 500-2300 tris.
- **Places** (`ForestPlaces.plan_places`, the theme hook, planned before the chain's set piece and landmarks):
  `forest_sawmill` on the town's river 58-110 m from the town's middle (kept 40 m off it, clear of its houses, level ground
  a little over the water, facing the river): the mill house (timber frame and planks on a fieldstone footing, a steep
  shingle roof, the sash saw at its open end with a log on the carriage, a light), the water wheel on its axle out of the
  wall turning in the stream (a looping tween on game time, 9 s a turn; foam and a rush), log piles, a crossed stack of
  boards drying, sawdust, a handcart, and the log flume (a plank V-trough on trestles from the highest ground 26-40 m behind
  down to the river beside the wheel, water running in it, logs riding it and waiting at its head) when the land behind
  rises 2.5 m+. Then 1-3 places out in the woods on its own stream: `forest_charcoal` (2-3 earth kilns smoking, one
  glowing at a vent, one stacked but not covered, cordwood, the burners' bark lean-to, a fire and light, charcoal sacks)
  and `forest_lodge` (a log cabin with antlers over its door, hides on frames, a deer hung from a pole over the skinning
  bench, a fire, a cache chest `forest_lodge_cache`).
- **Tests:** `t/island/forest_town`. Renders: `tools/dev/out/forest/models_town_*` (modelshot), `t5_sheet.png` (forestshot
  seed 5: the town on its river, from above, the sawmill, the camp, the lodge).

## 2026-10-17: the katana pass, piece 2 (the awakening: cloud and sakura)
- **Awakened slashes** (`Progression.elemental("katana")`, the tree's tier-1 mastery): the combo, the air slash and the
  iai draw lay the petal_trail cloud (KatanaFx.AWAKE_W 0.72 m) and drop the thin additive BladeTrail (the cloud is the
  trail; Haki's coat keeps it). The full iai draw's dash is a `FX.katana_line` of cloud (plain: the streak); its charge
  levels throw a katana_cloud puff and sakura.
- **FX:** `katana_line(from, to, width, awake, secs, seed)` and `katana_arc(center, u, v, radius, sweep, width, awake,
  secs, seed)`: a PetalRibbon with a `fixed` path drawn on over `secs` (no blade). `elem_hit("katana")` (tier 2, on
  every combo / heavy / plunge / iai hit: "Iai" joined PowerComponent's list) is drawn: a katana_slash crescent through
  them, a cloud puff, sakura. `FX.element("katana")` throws drawn sakura (2/3 the count, bigger), so every katana
  technique's `_spray` and the Wind Severer wave's wake moved to them.
- **The awakened blade** (`BladePetals`, scripts/game/blade_petals.gd, the BladeWater pattern): two crossed sheets of the
  cloud strip rising 0.13 m off the blade's spine (its curve follows WeaponDesigns._katana's), flowing to the tip by one
  shared material's uv1_offset, and a 4-petal CPUParticles3D (world coords) letting sakura go from the tip; built once
  per blade length, hidden when sheathed (the emitter stops). Co-op: Player's snapshot flag `NF_PETALS` (32), puppets
  call `BladePetals.keep` with it. Cost: one node + one draw (~216 static vertices) and 4 particles per drawn awakened
  katana; nothing rebuilt.
- **Tests:** t/fx/petals. Renders: tools/dev/out/kab/aura_*, night_* (AB_HOUR=21: the drawn cloud is unlit, the sakura
  dim with the night).
## 2026-10-17: Brinehollow grows south, the market street and the upper town (layout pass, docs/brinehollow_polish_plan.md step 2)
- **The land** (starter_island.gd): LAND_R 305 -> 400. The terrain grid is 780 m (RES 260) centred at GRID_C (0, 75): its north and east
  edges stay put and the old grid's vertices are its own (OLD_SHIFT 25 cells in), so the old ground is the same to the bit. The southern
  lands are a lobe round LOBE (-45, 235), LOBE_R 155 with its own capes (_lobe_capes) and noise, max'd over the old ground (`_grown`):
  faded out where the old island's interior is (_old_t < -30) and round GROW_KEEP (the smugglers), the sea kept round the cove (COVE_SEA)
  and the second cove's bay and mouth (COVE2, `_cove2`, no wading shelf in it). In it: the HIGHLAND (+16 m) with a rocky spine out to the
  SE cape (CAPE_TIP: sea cliffs, the wreck's rocks), a gentle rise round FARM. NO_GO gains the lobe; world_generator's seafloor box and the
  shore map follow grid_rect()/grid_origin(); the sea chart's Brinehollow circle is 300 m at (-45, 80). Coast.cliffs and
  KitCliffPath.carve take a grid offset.
- **The old island's look kept:** its plants decide on its old ground (`_land_heights`, the old function's heights and cliffs), its old
  reserves (`_ex_old`: reserves now indexed by 8 m cell, vegetation 3.8 -> ~2 s) and its old paths as they ran (`_frozen`), so every draw
  is what it was; where the grown land, a new path or a newer piece changed things they're left out (`_veg_skip`; `_changed` per vertex,
  dilated) and the grown land's scatter (`_scatter_grown`, a seed per lattice point: a later piece changes only the plants round it) fills
  in. Coast rock keeps the old grid's indices for its seeds. The old pieces (built before `_open_grown`) see the frozen paths; the burrows
  are found on the old ground. The height grid is computed on the worker threads.
- **The upper town** (UP_*): a hill from the plaza's south edge (UP_Z0 -39) climbing 12 m to the shrine terrace (UP_Z1 6 .. UP_Z2 33),
  between the ruins and cove paths, which now skirt it (paths 3 and 4 rerouted; the old pieces and plants keep the old courses). Terraced in
  bands (UP_BANDS -30, -18, -6: each flat at its lane's height to 3 m short of the next, a 3 m stone block filling the step, KitStreet.wall
  lift 0); the long stair up its middle (UP_X 4.5, on a corridor sunk 0.7 m under it: flights between flagged landings at each lane, side
  walls down to the band). The grid's 3 m vertex lines fall on the bands' and the corridor's edges. The second row: 10 houses on the two
  lower bands facing their lanes (flagged from the block to the doors), KitVillage.plan_yard dressing (the backs blocked), steps down the
  second lane's flanks to the paths (KitStreet.ground_stairs).
- **The market street** (`_build_market_street`): the main road cobbled out to 3.7 m either side, shopfronts where a house fits back from
  it (KitStreet.shopfront: a house with its awning and sign, a counter of wares beside the door, Vendor/Customer markers), stalls,
  barrows and rugs between, shade cloths and bunting across, two lamps; the two old houses facing it got awnings (same seeds). Bram's walk
  up from the quay now keeps to the street's middle (brinehollow_cast.gd, one waypoint) and the street keeps it clear.
- **New kit file** scripts/island/kit/kit_street.gd (KitStreet): shopfront, barrow, rug_stall, shade, stairs, ground_stairs, wall, finish.
- **For the life agent:** `town_spots` {"stalls", "shops" (nodes with Vendor/Customer markers), "houses", "lanes", "stair"}. LIGHTS 22 -> 30:
  the old island takes 18, the street and the upper houses 5.
- **Checked by** islanddump diffs against main (only vegetation where the land changed, the terrain, two coast-rock chunks, the two
  awnings, Bram, a burrow 0.2 m up, the dummies' known noise) and renders (tools/dev/out/bh/). New tool `bhmapshot` (a top-down map).
  World suites not run in this batch (Zach, 2026-10-17); expected to notice: shoretest/swimtest (the south coast moved), qoltest/storytest
  if they walk the ruins or cove paths (rerouted round the hill), foresttest (plants in the changed strip), savetest (treasure X spots move:
  sea_features picks them up to LAND_R).
- **The shrine terrace** (`_build_shrine_terrace`, models in scripts/props/brinehollow_models.gd, BrinehollowModels): the gate at the long
  stair's head, the flagged way up between six stone lanterns (the far pair lit) to the shrine (a hall on a stone plinth, veranda, two
  flared roofs: `flared_roof`), a four-tier pagoda on the terrace's west side (the mark the harbour sees over the town), benches, the old
  tree roped round, a parapet along the front; the third band's teahouse (veranda, red-felt benches, paper lanterns, one lit), two hill
  shops and a house; the switchback (paths[15]) down the terrace's back to the cove path, trodden, two unlit posts. The market street's
  shopfronts are square to the street and shoulder to shoulder now (checked against the old reserves and each other), its edges dressed
  (cargo, planters, benches, carts), the two old houses on it squared to it.
- **Draws:** the new district's built pieces are folded into one mesh a material each (KitStreet.merge_meshes: TownMeshes for the street,
  the upper town and the terrace together, FarmMeshes; bodies, colliders, markers and lights stay); the grown land's trees and rocks go in 140 m squares with
  ranges (700 / 320 m). The bench before this (pieces 1-2, 5600G/3080, noisy: 6 other Godots) read ALL frame 13.15 -> 14.56 ms, draws
  1357 -> 1544 (plaza +310).
- **Hook for the town's life:** StarterIsland.LIFE (scripts/island/brinehollow_life.gd) is built last if it exists (`static func build(isl)`);
  town_spots adds "shrine", "pagoda", "gate", "teahouse" (Vendor, Customer, Seat1-3), "lanterns" (Flame markers). LIGHTS 34: old island 18,
  the new town 10 (street 2, upper houses 3, teahouse 1, shrine lanterns 2, the farmhouse and the farm yard 2), 6 for the life pass.
- Two kit fixes from the buildings pass: KitHouses.room's top plate inside its walls (under the thatch), GenHarbour's water houses
  "steps": false.
- **The windmill hamlet** (`_build_farmland`, new kit file kit_farm.gd: KitFarm field/orchard/tilled/reserve): a yard round a well at
  FARM (trodden, a lit lamp), the windmill on its rise (BrinehollowModels.windmill: its "Sails" turn by Ocean.clock() only while on
  screen, scripts/props/windmill_sails.gd), a barn, two farmhouses (one lit) and a shed, haystacks, carts, cargo; six fields (FIELDS:
  wheat, greens, vines on tilled ground in the terrain's splat, a crop MultiMesh each, fenced but for a gap, a scarecrow in the grain)
  and the orchard (ORCHARD, three fruit-tree shapes in rows). Folded into FarmMeshes but the windmill. town_spots: "windmill" (Miller,
  Door), "farm" (barn, homes), "fields", "orchard".
- **The wild places** (`_build_wilds`): the falls (KitLandmarks._waterfall at POOL off the highland, its ground levelled and basin dug in
  `_falls`; the InlandPool makes it swimmable; chest "falls_chest"), the wreck (KitLandmarks._wreck heeled over on the east coast where
  WRECK_BEARING from LOBE meets the shore, among rocks; chest "wreck_chest" with the Drowned Mate's Coat), the second cove (a fisher's
  hut, a jetty, a boat drawn up, a fish rack; chest "cove2_chest"). KitLandmarks' two dressings take a fixed chest (`items`) instead of
  rolling a chain island's loot. Paths out to the wreck and down to the cove (paths 16, 17). town_spots: "falls", "wreck", "cove2",
  "piers" (the cove's jetty).
- **Cost** (bench, the 5600G/3080 here, 13:00 clear, back to back main 201b879 vs all five pieces, calib 26.5 / 28.0, 4 other Godots
  running): ALL frame 14.83 -> 15.55 ms (+5%), draws 1363 -> 1475, nodes 30.5k -> 32.1k; plaza 16.1 -> 18.1, quay 14.8 -> 18.5 (the town
  hill and the street in view), market and yard lower (noise). No script of mine in the per-frame tables (the windmill's sails only turn
  on screen). Build: land 1.3-2 s (the old and new grids both; heights on worker threads), vegetation ~3 s, the new pieces ~0.6 s together.
- **Fidelity** (fidelity.gd 777, Brinehollow before -> after): buildings 31 -> 41, interiors (enterable / shops) 2 -> 8, settled 1.62 ->
  2.18 ha, props in it 91 -> 127, street props per 50 m 2.84 -> 4.08, landmarks 8 -> 13, NightLights 22 -> 32, lit windows 179 -> 362,
  paths 599 -> 1412 m, land 9.1 -> 15.2 ha, vegetation 592 -> 612 a ha.

## 2026-10-17: salvage (ship upgrades, piece 2)
- Four materials (resources/items/timber, iron, canvas, copper .tres; icons from tools/texture_gen/gen_ship_icons.py),
  plain stackable loot. Higher levels of every line want them as well as gold (ShipLines level [3] = {id: n});
  the yard's second line shows your bag's gold and salvage; payment comes from your bag only.
- `Salvage` (scripts/ship/salvage.gd): a floating piece (a node per piece, shared mesh per kind: spars, an
  iron-bound crate, a sailcloth bundle, a crate of copper sheet, 1.35x so it reads from a deck), bobbing on
  `Ocean.get_wave_height`, drifting apart from where she sank, a glint every 2.6 s within 90 m, gone after 600 s,
  asleep past 260 m. Taken when your captain swims within 1.8 m or is aboard while the hull sweeps over it (her
  footprint + 1.2 m); a full bag leaves it afloat (one toast). Each screen scatters its own copy from the same
  seed (each captain finds their own, like the floating plunder): no network.
- Drops: `EnemyShip._drop_chest` scatters `Salvage.HAULS[kind]` pieces (gunboat 3 .. brig 6, richness tipping
  toward iron and copper: marine most); the prize chest gets 2 pieces; every sea wreck's chest
  (`SeaFeatures.build_wreck`, so sea legs' wrecks too) 2.
- **The loot-table hook** for island chests and wrecks: `Salvage.roll(rng, pieces, rich := 0.2) -> [[item id, qty]]`
  (kinds merged), append it to a chest's picks.
- Tests: t/ship/salvage_pickup, yard_buy (salvage costs). Render: tools/dev/salvageshot.gd.
## 2026-10-17: Brinehollow buildings polish, piece 3: the roof and texture audit
Rendered every Brinehollow building and street (modelshot per kind; islandshot day and 21:00: village, plaza,
tavern, porch house, harbour house, north row, smithy, chapel, warehouse, quay, waterfront, roofs from above).
Found and fixed (Buildings unless said):
- **A dark line along every roof's slopes** (bld_houses_eye, bld_houses2_eye, day_ware, day_north): the wall plate
  (w+0.1 x d+0.1) stuck out under the slopes and its top poked through the roof along the eaves. `_plate`: proud of
  the gable walls, 1 cm inside the walls the slopes come down to (hip: all four); a shed's sits under the walls'
  top (its roof starts there). The tavern's too.
- **Posts through steep roofs** (bld_houses2_after_eye): the corner posts under a roof stop 0.15 m short, the upper
  storey's front and back posts too.
- **Chimneys swallowed by steep roofs** (smoke out of the thatch): `_roof_y` (each roof kind's height over a point);
  a chimney rises to 0.6 m over the highest roof under its footprint (never lower than before).
- **Barge boards and fascias off the eave** with eaves other than 0.5 (themes): placed at the eave's real drop
  (2 x eaves x pitch; identical at 0.5).
- **Stretched eave undersides**: the hip and shed roofs' and the porch roof's undersides had one texture tile over
  a whole face; now mapped like their tops. Same for `MeshBuilder.add_gable_roof` (every gable roof in the game).
- **The tavern's jetty was open underneath** (bld_tavern_eye: a pale band over the street between the floors): its
  underside is drawn.
- Piece 1's finds (step stone and porch floor z-fighting the footing, the porch floating and its posts through its
  roof, shutters through door frames, awning goods in the air) and piece 2's (the tower and lighthouse doors).
- Looked at and left: the harbour house's shed eave over its porch roof reads as a stepped double eave (day_harbor);
  stalls, market and quay paving are fine; KitHouses.room's plates poke slightly through its thatch (the layout agent's
  file); KitHarbourGen's water houses keep their stair under the deck (they want "steps": false there).
- **Tests:** t/island/house_roofs (the plate, posts and chimneys against `_roof_y` on every roof kind, 1-2 storeys,
  pitch 0.45 and 0.8); house_doors, desert_town, snow_foundations pass. Brinehollow's islanddump changes only in its
  buildings (houses, tavern, smithy, chapel, harbour tower, lighthouse, the waterfront and camp houses).
## 2026-10-17: Brinehollow life, piece 1: the shop moves (docs/brinehollow_polish_plan.md step 3)
- **Who sells what** (scripts/game/shops.gd): Gus (The Salted Gull) rum and stew only; Vey's Armoury armour only and buys only gear
  (no blades); new "haldor" (Haldor's Forge): the sixteen weapons Vey used to stock, buys weapons at 0.6; new "corin" (Corin's Strings
  and Skins): all five instruments (the fiddle and hurdy-gurdy were chain-only before), buys nothing.
- **Where** (scripts/island/brinehollow_cast.gd): Haldor the Smith gets the "haldor" shop (talk = trade at the anvil, new barks); Corin
  stands at the counter of a market street shopfront (Shop4 since the street's frontage pass), `BrinehollowCast.corin()`.
  Vey's menu says "Buy or sell armour" and points you to Haldor; Gus mentions Corin with his drinks.
- **Tested by** t/island/brinehollow_shops (the stock moves; on a built Brinehollow Haldor trades and Corin is at a shopfront's counter)
  and t/items/instruments (Corin sells all five, no one else on Brinehollow sells one). qoltest now sells its blue cutlass to Haldor.

## 2026-10-17: the katana pass, piece 3 (the five abilities)
- **Poses:** every katana cut rides a swing path now (KatanaMoves; the body keyed there, small chest turns so the hands
  stay in front; a last key on the follow-through's point holds it): `tiger_rush` (new: Tiger Rush with a katana runs low
  with the blade trailing by the right hip, then one drawing cut flat across to the left as the dash ends, u 0.6-0.76; a
  cutlass still lunges with "thrust"), `wind_sever` (low behind the right foot, a beat, one rising cut up across the
  front; the wave leaves on it at 0.34 s), `phantom_cut` (arrived crouched, hands low left, a flat cut round to the right
  at 0.16 s), `iai_slash` (the heavy's release and Iai Counter's answer: out of the scabbard, the blade on the target at
  contact (it lagged left before), held), `petal_storm`'s drawing cut (PETAL_SWING, u 0.195-0.36; the rest still keyed).
- **Effects** (plain steel / awakened cloud, all Net.fx): each cut lays `FX.katana_slash` along its blade (Iai Counter's
  from the answer's start, so the ribbon has the whole path). Tiger Rush: a katana_line of cloud along the dash once
  awakened (plain: the streak), a drawn crescent on each victim (katana_slash / steel_slash sheet). Wind Severer: the
  wave is a tall crescent of the drawn strip standing across its path (Projectile `_wave_mesh`, its own copy of
  PetalRibbon's material stepped through the frames by distance flown; plain steel / cloud), a dust_low puff ring and a
  cloud puff at its launch. Phantom Step: a katana_line along the blink (awakened), a crescent on the cut. Iai Counter:
  petals adrift round the hilt while it waits, a crescent on the answer, a cloud puff on the flick. Thousand Petals
  (the showpiece): a ring of cloud drawn in round the feet over the gather, the big drawing cut's ribbon, the signature
  (awakened): a crescent of cloud racing once round you at chest height (katana_arc r 3.6 m) as the blade leaves; drawn
  crescents crossing every victim every 0.16 s while the cut_lines flash; at the click a crescent and a cloud burst on
  each, and a thousand petals let go over the whole area (one 30-petal burst spread over 6 m). Plain: steel crescents,
  rings and dust.
- **Budgets** (the ult at its peak, ~0.5 s, three victims): 3 PetalRibbons alive (the blade's ~360 vertices, the big arc
  ~380, the gather ring ~190: each one node, one draw, rebuilt a frame while it lives; given paths aren't subdivided),
  ~6-9 one-shot bursts (one draw each), the old rings and cut_lines. At the click: 3 bursts per victim + 1 petal storm.
  No lights. Abilities aren't on the bench route (not re-benched); nothing per-frame was added outside them except
  BladePetals (piece 2: static, a shared material step).
- **Tests:** t/combat, t/fx (petals), t/weapons/draw_styles (atomic, per the batch's rule). World suites to run after the
  batch: katanatest (combo, iai, the air slash's hit window now 0.2-0.36 s), techtest (wind_sever, phantom_step,
  petal_storm, iai_counter), powertest (Tiger Rush), wieldtest, balancetest. Renders: tools/dev/out/kab_before/ and
  kab_after/ (a_ awakened, plain_ tier 0, night_ AB_HOUR=21), tools/dev/out/klab/ (lab sheets of every move).

## 2026-10-17: the new upgrade lines (ship upgrades, piece 3)
- Eight more lines (ShipLines; groups Hull, Guns, Rig, Helm, Deck, Cabin; 3 levels each), every level built by
  ShipParts:
  - **Copper bottom**: copper sheathing at her waterline, bow, then waist, then stern; +2% speed and 20% less
    reef / whirlpool-eye damage a level (`Ship._reef_k`).
  - **Bow chaser**: `CannonBow` (a crew ShipCannon facing ahead on a step at ShipParts.CHASER_AT; x = 0 keeps it
    out of broadsides), a shot locker and banded barrel, then a railed platform and long barrel; +15% damage at
    2 and 3, +12% range at 3 (the gun deck's damage/reload apply too).
  - **Crow's nest**: poles and a canvas hood (the flag goes 0.75 m up a new masthead staff), boards, windows and a
    roof, a brass spyglass and a lantern; the lookout (`Ship.lookout`, 150/300/500 m) puts enemy sails (red, with
    distance) and floating salvage (gold) on the compass strip while you're aboard.
  - **Lanterns**: strings of paper lanterns (three glow colours, no real lights) mast to bowsprit, mast to the
    quarterdeck corners, round the nest and along the rails; +3% speed at night a level (`Weather.night`).
  - **Railings**: iron stanchions and man-ropes, a turned balustrade, boarding nets along the waist; a ram
    throws the crew half as hard at 1 and not at all at 2 (`Ship.steady`, Net._all_rammed); the nets keep one
    boarder off (`EnemyShip._board`).
  - **Tangerine grove**: planters with trees on the quarterdeck (collision), fruit shown while ripe; F at the
    grove picks them ("tangerine": heals 25). Each tree ripens one every 150 s up to two (a Timer, game time);
    each screen grows its own (each captain picks their own).
  - **Galley & bunks**: an upper bunk, an oven, pots and a chimney through the quarterdeck, hammocks; the
    galley restocks one more of each a level (GameManager.restock).
  - **Ship's hold**: iron bands and a lock on the storage chest, sea chests, a cargo hatch and lashed crates on
    the main deck; +2 bag slots a level (`InventoryComponent.bonus_slots`, static, set by Ship.apply_kit: the ship
    this machine sees; `slots()` is max_slots + it; the storage chest itself was already unlimited).
- ShipParts `_solid` adds collision for what you'd walk into (the chaser step, planters, sea chests, crates,
  the chimney). Everything is in the two folded meshes except the jib, rudder, wheel rim, grove fruit and zone.
- The yard's rows are 16 px (prices in Silkscreen 8) so the twelve lines fit 450.
- Tests: t/ship/new_lines; upgrade_levels checks every level of all twelve shows.
## 2026-10-17: the forest island theme, piece 3 (wildlife, folklore and beasts)
- **Wildlife** (`scripts/enemies/fauna/`, Creature kinds; FaunaSpawner's packs, LOD and sleep as every kind): `deer.gd`
  (ForestDeer: herds of hinds and spotted fawns round an antlered stag - "pack" [3, 5], young 0.4; they graze, the nearest
  throws up its head and stamps, the herd bounds off flagging white tails; struck, the stag roars, lowers his antlers and
  charges for a knockdown, then bolts; morphs red, fallow, dark), `red_fox.gd` (RedFox: the fennec's wariness - DesertFox's
  brain - in a russet woodland fox with black socks, a bib and a white-tipped brush). Folklore: `wisp.gd` (Wisp: a little
  floating light, faint by day, glowing at night - a flickering core and an additive halo, no light; near a captain at
  night it draws off ahead of them, out of reach, then drifts back to its haunt; one blow puts it out), `wood_sprite.gd`
  (WoodSprite: twig and leaf, ember eyes; by day a leaf mound you might step on, at night up in twos and threes, chitters
  and crouches - the tell - then pounces and rakes, skips back out of reach and comes again), `treant.gd` (Treantling: a
  stump that walks; stands still till you're close - 4 m by day, 11 m at night - then heaves up on its roots, slow, its bark
  turning 55% of a blow from the front; a raised-arms slam that knocks you down or a wide sweep). The roster: deer, boar,
  fox, wolf (now and then), wisp, sprite, treant, bat, crab; caves get bats overhead and mites, sprites and treantlings on
  the floor.
- **Beasts** (the alpha boar's / behemoth's brains on new bodies, as snow's): bosses `stag_king.gd` (the Stag King: a pale
  stag the size of a cottage, its antlers a crown of branches hung with glowing moss and leaves; charge, antler sweep,
  hoof-stomp ring from the start; a grove of standing stones hung with antlers, offerings, a toadstool ring and a stag skull
  on a cairn for its ground), `elder_treant.gd` (the Elder Treant: an oak on four root-legs under a crown of autumn leaves,
  slow and heavy, a ring of roots; its ground the oaks it pushed over, root plates on end, splintered stumps), plus the
  jungle's serpent ("The Root Coil") and stalker ("The Grey Lynx") so a branching chain never runs the pool dry. Minis:
  `moss_golem.gd` (a boulder-beast bound in moss and roots, at the ruins), `huntsman.gd` (the Cursed Huntsman, a "camp"
  mini like the bandit chief: he leads the outlaws' camp in its captain's place, hooded with a war axe, Morrow's fight on the
  island's level, and two hounds - wolves - at his heel with their own distance LOD on a timer), the alpha boar (at the
  lair). Roamer: `wild_hunt.gd` (the Wild Hunt: a black spectral elk with antlers of pale fire and a hooded rider with a horn;
  only at night - by day it's hidden, out of the physics space and asleep, from the synced world time - the behemoth's
  roaming and temper).
- **Gotcha:** a QuadBeast's vertex colours are linear (a coat over 1.0 wraps); a big beast that walks into a standing captain
  can lift them onto its back (the test puts them down again) - the same for every big QuadBeast.
- **Tests:** `t/island/forest_fauna`, `t/island/forest_beasts`, `t/island/forest_huntsman`. Renders: `tools/dev/out/forest/
  models_fauna_*` (modelshot), `boss_stag/sheet.png`, `boss_treant/sheet.png` (bossshot seed 5).

## 2026-10-17: any captain pays for her refits (ship upgrades, piece 4)
- The yard's buttons work for guests too: `ShipwrightScreen.order(id, lv)` takes the price out of the payer's
  own bag and calls `Net.request_upgrade(id, lv)`; the host (`_grant_upgrade`) puts level lv + 1 on her
  (Net.set_ship_kit: every screen, and the join world state) only if she's still at `lv` (two captains paying
  for the same level at once: the second is refused) and saves its world; the answer (`_upgrade_done`) goes
  back to the payer's yard: done, or the whole price (gold and salvage) back in their bag. Single player and
  the host take the same path, answered at once. Paint and colours stay the host's.
- Tests: t/ship/upgrade_request (the arbitration and the refund, host side); nettest (netclient 742-744): the
  guest pays for a rudder level, it's on the guest's ship and in the host's kit.

## 2026-10-17: Seamanship (ship upgrades, piece 5)
- A mastery tree "sea" (SkillTree.TREES / TAB_ORDER: the SEA tab before FRUIT; `_build_seamanship`, 15 nodes
  in three columns: the helm, the guns, repairs, Bosun at the top), each captain's own: Progression saves it
  with the captain like weapon mastery, so a guest's is theirs. Mastery comes on the captain's own machine
  (`Seamanship`, scripts/ship/seamanship.gd): 1 xp per 25 m sailed at the helm (Ship._physics_process),
  8 a hit with her guns on a ship (Cannonball, the authoritative copy, shooter = our captain), 12 a hole
  patched or fire beaten out, 1 a pump stroke (0.25 s), 3 at the capstan, and 30-60 for a ship sunk within
  250 m (EnemyShip._sea_credit on every screen, host and puppets).
- **Station bonuses** count only while you man the station: helm_speed / helm_turn / helm_flood (Ship._helm_k
  from `Seamanship.helm_k` on the helmsman's machine, and on Ship.net_pack's new fields 15-18 for the other
  screens: PACK_SIZE 19, with whether they're steering), gun_reload (ShipCannon._process, the gun you aim),
  gun_dmg (ShipCannon._shoot, balls you fire), repair / capstan (`Ship.job_time`), pump (more bailed),
  lookout (the compass marks reach further aboard, added to the nest's). Bosun (crew 0.5): the rest count half
  again while a crewmate mans another station (another machine's helmsman: `Ship.helm_other`; a gun seat held
  by another id).
- techtest's "each weapon tree has 18+ nodes and one ultimate" now counts only the weapon trees (STYLE_TREE).
- Tests: t/ship/seamanship. Render: tools/dev/seamapshot.gd (the SEA tab fresh and learned).
## 2026-10-17: the forest island theme, piece 4 (set pieces: the waterfall gorge, the ruined castle, the hollow tree)
- **What** (`scripts/island/themes/forest_setpieces.gd`, ForestSetPieces, through ForestPlaces.KINDS on the theme place
  hooks; a set piece and a landmark never share a kind): `forest_gorge` for the chain's cenote or sunken village,
  `forest_castle` for its volcano vent or old fort, `forest_hollow_tree` for its great tree. Nothing guaranteed: the chain
  rolls which set piece and landmarks an island gets.
- **The waterfall gorge:** forest_land.gd gives the island's first river big falls (14-19 m; as big as the land allows,
  at least 5 m) when its set piece maps to the gorge (`land_plan["gorge"]`), so the river runs on in a deep gorge below
  them. The set piece takes the island's biggest falls clear of the sites: mist off the pool, ferns and moss down the
  walls, a cave dug into the gorge wall beside the curtain (the terrain cut to the pool's level there, a CaveMesher room
  meshed on the worker, its rock one trimesh, glowing fungus, a light, the `gorge_cave_hoard` chest and two of the
  island's cave fauna by FaunaSpawner.fill_slots), rope bridges (KitLandmarks.bridge) rim to rim across the gorge a few
  steps downstream, the trail to the first bridge, the falls' roar.
- **The ruined castle:** on high level ground (KitSetPieces._plan_inland, r 27): eight stretches of crenellated mossy-stone
  curtain wall at 21 m (a seeded third breached to rubble), the gatehouse toward the trail (piers, a lintel, an arch), round
  towers on every other corner (some broken low), ivy red and green down them; the keep at the back, roofless, its doorway
  toward the gate, a stair of stone blocks round its inside walls to a timber floor at 8.4 m under the broken parapet with
  the `castle_keep_chest`, arrow slits, a light; outlaws camped in the courtyard (a fire, tents, crates, a GruntCamp of five:
  two at the fire, one walking the walls' foot, a rifle at the gate, one at the keep's door) with their own nav zone.
- **The hollow giant tree:** a trunk 11 m across, hollow to 7 m (outer and inner walls, a doorway between buttress roots at
  +Z, the back open), solid and tapering on up to the fork at 22 m, seven limbs into a crown of oak, maple and beech leaves
  with grapple points; bracket fungus spiralling up its side (17 shelves, 0.82 m apart, each a box to stand on) to a planked
  perch in the fork with the `hollow_tree_perch` chest. Through the back of the hollow a root cavern of three chambers in a
  mound of earth and roots behind it (CaveMesher, the ground levelled under it; the forest's cave look), roots down through
  the roofs, glowing fungus, a light per chamber, bats overhead and sprites / treantlings / mites on the floors
  (fill_slots), the `hollow_tree_hoard` in the end chamber.
- **Build cost** (seed 5, landmarkshot): the gorge's steps ~160 ms in all, the hollow tree's ~290 ms over two steps (the
  trunk's 24 wall boxes and the cavern's trimesh), the castle ~35 ms; the cave meshes ~130 ms on the prepare worker.
- **Tests:** `t/island/forest_places`. Renders: `tools/dev/out/forest/lm5_*` (landmarkshot seed 5, LSHOT_PIECE=cenote,
  LSHOT_MARKS=great_tree: the gorge, the hollow tree, the sawmill, the camps), `c5_forest_castle.png` (forestshot seed 5).

## 2026-10-17: Brinehollow life, piece 2: townsfolk on routines
- **Who** (BrinehollowCast.townsfolk, made in that order by scripts/island/brinehollow_life.gd from StarterIsland's LIFE hook): Corin
  (now a routine: his shopfront Shop4 by day, the Salted Gull's fire in the evening, still trading there), six shopkeepers (Shop0-3,
  Shop5, StreetStall0) who drink at the Gull after closing, four customers browsing the street's shops and the old market, three
  porters hauling sacks from the quay to the shops and market stalls (a sack on the shoulder going, BrinehollowFolk `load_node`),
  three kids running the plaza, the long stair's lanes and the shopfronts until supper (home for lunch). All home (hidden) by 0:30.
- **How**: each is a BrinehollowFolk (scripts/island/brinehollow_folk.gd, a Villager): stays by hour from Weather.hour (same on every
  screen, nothing sent), seated stays (bench, tavern seat, rug stool) set `humanoid.seated`, and the walk's height follows the town's
  floors (`Town.y_at`: the long stair's treads, the Gull's boards). Spots are ids (`_spot`: vendor/front of a shop or stall, bench,
  plaza knot, tavern bar/seat/fire, home door, stair lane, quay), each with a lane out to the street.
- **The walk graph** (`BrinehollowLife.Town`): every path within REACH 140 m of the plaza, the upper lanes, the long stair and a ring round
  the well, densified to 2.5 m, lines joined within 3.2 m; an edge is kept only if rays both ways at waist height hit nothing (a lamp at a
  path's end, a stall on a path's edge); cut-off pieces are bridged at the nearest clear step (<= 9 m). A walk is the spot's lane, an
  A* route between the entries (the nearest graph point in clear sight), and the next spot's lane in.
- **Load time**: the bodies are built on the main thread, ~150 ms each (the townsfolk ~2.9 s). Prebuilding them on workers early in
  the build cut that to ~0.6 s but raced the main thread's mesh commits ("wrong RID", docs/todo.md's mesh-commit crash), so it's out.
- **Tested by** t/island/brinehollow_life (everyone made once; 10:00 keepers at their counters; 21:00 the Gull busy, Corin there
  trading; 2:00 everyone in; no stop in a doorway or on the stair; every walk's legs clear of colliders by ray).
## 2026-10-17: the axe pass, piece 1 (the combo on swing paths, the drawn iron crescent)
- **Why:** the katana's fix for the axe (docs/axe_polish_plan.md): the keyed combo's fixed arcs (kesa_r / left / overhead)
  only roughly matched the swings; hit 2's axe pointed backward and hit 3's raise held it behind the head.
- **Animation** (`scripts/npc/axe_moves.gd`, AxeMoves; ActionSpecs axe_hack / axe_hook / axe_split, lengths, hit windows
  and chain times as before: 0.62 / 0.62 / 0.9 s, chain 0.46 / 0.46 / 0.72 s): the right hand rides a swing path
  (`from_shoulder`, `follow` 1, the katana's frame), the bit leading like a sword's edge. axe_hack: up in front and over
  the right shoulder with the head laid back (the katana's jodan: the hand above and a little ahead of the shoulder; a hand
  behind it ran the wrist into its roll limit and laid the axe flat across the head), a beat, then down through the front
  at a slant to low left, a deep lunge; the off hand on a reach path (out at the target, then flung back past the hip).
  axe_hook: from hit 1's finish down to the left hip, then ripped up across the front to high right, stepping through on
  the right foot. axe_split (two-handed, `_axe_hands`): up over the head, laid back through the hop, a beat, then straight
  down into the ground ahead, held bitten in (the body bends less than before: the old pose all but lay on the ground).
- **Effects:** PetalRibbon is now every drawn weapon's: `kind` picks its strips (`LOOKS`: katana steel/petal, axe
  axe_trail/ember_trail); the axe's samples the bit's edge (`WeaponDesigns.axe_head_z`, the mesh's min y) with the crest
  away from the hand. `FX.drawn_slash(body, kind, ...)` / `drawn_burst` (katana_slash / katana_burst call them, the
  katana's look unchanged); `DrawnFx` (scripts/game/drawn_fx.gd: WIDTHS axe 0.44 plain / 0.9 awakened, katana as before;
  KatanaFx forwards to it). LightAttackState "drawn" is the kind ("katana", "axe"); the axe's finisher is 1.25x. Plain:
  a heavy iron crescent with a puff of dust off the head and one off the tail as it breaks.
- **Art** (`tools/texture_gen/gen_axe_fx.py`, on gen_katana_fx.py's strokes): axe_trail and ember_trail (8 looping frames
  of 256x64), flip_axe_slash, flip_ember_slash, flip_ember_cloud (4x4 of 128 px), flip_cinder, flip_ash (4x4 of 64 px).
  Palettes: iron and dust; fire (char, crimson, red-orange, orange, amber, yellow, white-hot); ash.
- **Tests:** t/combat/axe_slash (each hit's path in the body's frame, plain, lands). Renders: tools/dev/out/axe_pass/
  before/ (the old keyed combo, abilityshot of every axe move), after/, lab/.
- Cost (t/ship/upgrade_cost, prints the counts): a plain sloop draws no upgrade parts (both meshes empty); a
  maxed one 27 -> 61 mesh instances, 50 -> 101 draw surfaces (most are the three extra guns and every gun's
  fittings, which turn and so are their own meshes; folded, shadowless, gone past 150 m), 17.5k -> 53k
  vertices, no new lights; the parts themselves are UpgradeMesh (13 surfaces, one per texture) and
  UpgradeFine (1). Per frame: nothing while nobody steers; the helmsman's and gunner's stat lookups are cached
  by Progression.stat. Copper and gilt are flat paint (the metal texture read olive and dull).

## 2026-10-17: Brinehollow life, piece 3: smoke, lanterns, the town's sound
- **TownLife** (scripts/island/brinehollow_town.gd, made by BrinehollowLife): one node ticking every 0.5 s (local on every screen, from
  Weather.hour): the beds' gains (`day_gain`, `night_gain`), Haldor's hammer runs, the lanterns' day/night meshes, chimney smoke. Its
  players stop past FAR_R 220 m.
- **Sound** (tools/texture_gen/gen_town_audio.py, new, built on gen_psx_audio's helpers): `market_murmur_loop` (47.3 s, -20.2 LU:
  formant babble of sixteen voices, calls, laughs, coins) at two points on the market street and one in the old market; `tavern_room_loop`
  (41.7 s, -20.2 LU) in the Salted Gull; `anvil_1..4` (-17.2 LU) at the Smith marker in runs of strikes, 7:30-18:00. All 3D players.
- **Light**: paper lanterns on cords from each street shopfront to the nearest one across the street (4.3 m up, sagging; three meshes:
  cords, day paper, night glow), the two longest strings' middles lit (NightLight from the budget), and a newel lantern post at the long
  stair's middle landing (lit). 3 of the budget; LIGHTS left after: 3 (the harbour gets 2).
- **Smoke**: Buildings.house now puts a "Chimney" Marker3D where its smoke would be when a spec says `"smoke": false` (only Brinehollow's
  new town, farm and cove hut do: 5 chimneys); TownLife makes FX.chimney_smoke at one a tick once the camera's within 60 m and stops it
  emitting past 80 m.
- **Tested by** t/island/brinehollow_town. Renders: tools/dev/out/life/p3_night_street.png (the lanterns), p3_day_upper.png.
## 2026-10-17: the forest island theme, piece 5 (sound, weather, fidelity, cost)
- **Bed:** `forest_loop` (gen_psx_audio.py `forest_loop`, 53 s, -20.2 LU, 3% at 2-5 kHz, repeat 0.19@6.7 s, seam 1.2x):
  wind through the leaves in slow gusts with a dry rustle, a trunk creaking, songbirds near and far (`_songbird`), a
  woodpecker (`_woodpecker`), crows (`_crow`), a stream's murmur, a tawny owl now and then (`_owl_hoot`). Ambience
  "forest" at TOP_DB -13; the forest style's `ambience`. (One bed for day and night: Ambience has no night variant.)
- **Music, not in the game yet:** `track_forest(night)` in gen_psx_music.py (6/8, 72 bpm, A dorian / C major, 56 bars =
  140 s: a tin whistle's air over harp and guitar, the clearings' song in C on the oboe, the game's theme re-barred in A
  minor 6/8 on strings / whistle / horn, the bodhran; night: the whistle alone far off, dark harp, celesta stars, no drums;
  both -18.0 LU, seams 0.2x / 1.2x). This PC has no ffmpeg, so the generator kept .wav files, which were not committed
  (Music loads .ogg). To finish: `py tools/texture_gen/gen_psx_music.py forest forest_night` where ffmpeg is on PATH, the
  two `Music.TRACKS` lines (`"forest": ["res://assets/audio/music_forest.ogg", 56]`, `"forest_night": [..._night.ogg, 56]`)
  and the forest style's `"music": "forest"`. Until then the woods play the jungle's island track and the town the village's.
- **Weather** (the style, set in piece 1): clear 24%, cloudy 32%, rain 34%, storm 10% (the jungle 30/26/32/12), a pale grey
  haze 0.25 (alpha 0.5). "Misty mornings" are only this all-day haze: Weather has no hour-dependent fog per style.
  `falling_leaves` ({rate, colors}) is in the style as a hook for the shared weather/ground pass (nothing reads it yet).
- **Fidelity** (fidelity.gd on chain seeds 5, 7, 13, forest first islands, against Brinehollow): buildings 49-50 (1.2x),
  dressed share 2.2-2.8x, props per settled ha 0.80-1.05, street props per 50 m 0.60-0.67, prop categories 0.92-1, NPCs
  0.95, walking NPCs 3x, places 1.2-1.9x, distinct landmarks 0.62-0.92, real lights per ha 0.60-0.77, lit windows per ha
  0.37-0.52, vegetation variety 3.9x and density 2.3-2.5x per ha. fidelity.gd's building table has no "Tall" (the name a
  theme's own two-storey model gets: snow's, desert's and the forest's go uncounted).
- **Cost:** prepare on the worker 15-22 s (land 2-3 s with the river grid, undergrowth 2-3 s, bodies ~2-3 s, the set
  pieces' cave meshes ~130 ms), the main thread 1.6-3.1 s over ~165-175 frames, the worst step ~140-260 ms (draw lod ~600 ms
  over its 64 steps, the hollow tree ~290 ms over two). Static surfaces 4.6-7.6k (Brinehollow 1.8k), MultiMesh instances
  36-63k, draw calls ~430 at the plaza and 1.4-1.9k at the harbour (Brinehollow 1238 / 1670), nodes 7.6-10.9k, static
  memory 102-134 MB. Not benched: the bench's route is Brinehollow's, which nothing of the forest touches.
- **Proof:** islanddump of seeds 1 (jungle), 4 (snow), 2 (desert) before the forest and with only the forest registered:
  identical islands (piece 1). Dumped again at the end, they differ only where main's Buildings door/steps pass landed
  (Site_harbour houses' colliders, Door markers), none in forest code.
- Renders: `tools/dev/out/forest/n5_sheet.png` (forestshot seed 5 at 21:30), the falls' glow turned down after it.

## 2026-10-17: Brinehollow life, piece 4: the busier harbour
- **Smacks** (scripts/island/brinehollow_harbour.gd): five fishing smacks (a longboat with a mast, yard and furled lug sail, a net in
  the stern) moored bow-out at the quay wall at frame s -27, -9, 40, -17, 54: between the piers' hulls and the longboats, none in the
  sloop's lane (`berth_lane`: from the main pier's berth side 3 + 14 m wide out to sea). Three are MooredHulls (walkable, riding the swell).
- **Coming and going** (scripts/island/harbour_boat.gd, HarbourBoat, an AnimatableBody3D): Smack0 and Smack1 leave at 5:4 / 6:0, run
  straight out off the wall and turn away from the lane to grounds 170 m out and 45 m aside, drift there with their fisher aboard (Hob
  Tarrant, Marrin Sedge: Humanoid bodies, seated, prebuilt) and sail set, and are home by 15:8 / 17:2. Where each is is `where(hour)`
  (Weather.hour; the drift on Weather.world_time), so guests see the same; full rate within 300 m of the camera, once a second past.
- **People** (BrinehollowCast.harbourfolk, after the townsfolk): three fishers sat on pier edges, legs over the water, rods out (a rod on
  the right hand shown while sat at a "rod" stay): two on the main pier's side away from the berth, one at the merchant's pier's end on its
  open side; they fish from before dawn and after lunch, eat and drink at the Gull. Two dockers carry sacks from a stack on the quay out
  along the merchant's pier to the merchantman, 7:00-17:00.
- **Walk graph**: a line along the quay (7 m in from the wall), the main pier and each side pier (their decks are floors for `y_at`);
  walks join the graph only at its biggest piece (`Town.main`). The Gull got four more places (two at the bar's end, two by the walls).
- **Tested by** t/island/brinehollow_harbour (the smacks' places and courses clear of the lane and the other boats; out at 10:00, home at
  18:00; fishers on the piers at 7:00 and off at 12:00; dockers carrying). Renders: tools/dev/out/life/p4_*.png.

## 2026-10-17: Brinehollow life, piece 5: the shrine terrace's, the hamlet's and the cove's people
- **Who** (BrinehollowCast.outskirts, after the harbour's): Keeper Sanae before the shrine's doors by day (lunch on the teahouse's
  bench), Hana Teal behind the teahouse's counter 6:30-20:30, Old Oda praying at the shrine's foot and sitting out on the teahouse's
  benches; Miller Brann at his mill (a step off its door), two farmhands weeding among two fields' rows each (in by each field's gate)
  with lunch in the yard, Old Gannet fishing off the second cove's jetty and mending nets by his rack. Seven, so the frame stays.
- **Walks**: `Town` takes a centre, reach and ring now: `of_town` (as before, plus the way up the terrace to the shrine, the
  teahouse's and the shrine's plinth as floors), `of_farm` (the paths near the farm, a ring round its well, for each field a way round
  its fence and three spokes from the yard to its gate: straight and bent either way round what's in the yard), `of_cove` (a ring on
  the beach, the jetty, onto it straight at its shore end). A cast entry's "area" picks one. BrinehollowFolk ramps to a stay's own
  height over its last/first 2.5 m (`walk_y`: the shrine's steps, the teahouse's boards, a pier edge's seat) and only adjusts on the
  frames its routine moved it.
- **Load time** (no prebuild): the build's "life" step is ~5.6 s (29 bodies on the main thread), the cast's "npcs" ~2.2 s.
- **Tested by** t/island/brinehollow_outskirts (at 8:36 each at their place, the farmhands kneeling in the fields, the cove's fisher sat
  with his rod; walks clear of what's built, fences included; all in at 2:00). Renders tools/dev/out/life/p5_day_*.png.
## 2026-10-17: woods round Brinehollow (Zach: "too much open space still")
- **What** (starter_island.gd `_plant_woods`, `_woods`, `_woods_keep`): the same jungle trees, palms near the coasts, ferns and bushes,
  planted after everything else (after the loot, before the town's life) from their own lattice (5 m trees, 2.5 m undergrowth, a seed per
  point from SEEDS["woods"]), so every older plant keeps its draws (islanddump: only added plants, colliders, the vegetation squares'
  counts and the exclusions). `_woods(p)` 0..1 is where: the complement of the old forest's `_jungle` (the southern lands' `_jungle_south`),
  thinning to nothing round the plaza (20-30 m), the market street (10-16 m off the road), the harbour front, the upper town's built hill,
  the lighthouse's top (26-40 m), the yard, the ruins, the camps, the den and the cave. Trees keep 3.5 m off every path, 1.2 m past another
  plant's reserve and 3 m past anything bigger (`_ex_near`), and off `_woods_keep`'s segments: each door's way in and out, the chests, the
  burrows and spitters' spots, the lanes and the stair, the wake beach; and off the harbour's line to the pagoda.
- **Draws:** the plants go into a vegetation square already holding that mesh (70 m, else the grown land's 140 m; `_woods_meshes`), so
  it's more instances: 2 new squares. The MultiMeshes are made in `_commit_vegetation` after the woods (the Vegetation node itself still
  goes in where it was, so the tree's order is unchanged). Trunks have colliders and grapple crowns like the old trees.
- **Piece 1** (the eastern hill to the cove and up toward the lighthouse, the town's edges, the upper town's slopes and the terrace's back):
  ~405 trees (Brinehollow had ~1.4k tree and rock colliders), ~1k ferns and bushes. Bench (5600G/3080, 13:00 clear, calib 24.2 / 24.3, a
  life agent's test at the before's start): draws 901+623 -> 913+644 (shadow +21), prims +5%, nodes +408; frame noise both ways (ALL 16.1 ->
  14.8, frame1t 16.6 -> 15.5: the machine, not the trees).
- **Piece 2** (round the farmland: groves between the fields on the grove noise the grown land uses, none within 6 m of a field or the
  orchard nor in the hamlet's yard, the windmill kept clear; the south-east down to the coast; WOODS_RECT the whole land but the den's
  corner): 1074 trees, 2755 ferns and bushes in all, 3 new squares. The trunks' body is out of the tree from the old scatter through the
  woods (a shape added to a body in the physics world cost ~1 ms each): woods 430 ms, vegetation 2.1 -> 1.6 s.
- **Bench, both pieces** (back to back, old starter_island.gd vs new on the same main, 13:00 clear, calib 23.8 / 24.0, the life agent's
  bench just before): ALL frame 15.61 -> 15.67, frame1t 16.34 -> 16.33, draws 946+663 -> 960+684, nodes 33.2k -> 34.3k, gpu 0.73 -> 1.04;
  per stop frame1t beach 18.17 -> 15.47, plaza 20.04 -> 18.59, market 18.54 -> 19.26, quay 15.35 -> 15.68, dock 14.66 -> 15.00, den
  13.43 -> 13.76, yard 15.78 -> 17.28, aboard 14.79 -> 15.62 (noise either way; no script of mine per frame).
- **Tested by** t/island/brinehollow_woods (counts, none on a path/lane/stair/door/chest/burrow/field/orchard, the harbour sees the pagoda
  and the lighthouse past every new tree's bounds, at most 8 new squares). Expected to notice: foresttest (Brinehollow's tree counts; forest_crowns and the
  spitters are unchanged), anything counting the vegetation's MultiMesh instances.

## 2026-10-17: Brinehollow life: the cost, and a first cut
- **Bench** (min-spec PC, gate mode, 13:00 clear, same build with BrinehollowLife.build on/off back to back, calib 24.0 / 24.1, other
  Godots running): ALL frame 12.35 -> 16.07 ms (+30%), plaza 12.49 -> 19.43, market 13.02 -> 21.47, quay 11.66 -> 15.89; the folk's
  Villager routine 0.56 ms + their rigs 0.64, Jolt +0.4 (bodies dragged every frame), tail +0.6, draws +240.
- **First cut** (BrinehollowFolk): the routine every frame only within 20 m of the camera, every other frame to 45 m, every fourth
  past; walkers out of the physics (their Body disabled while walking, solid when stopped); hidden past 100 m. HarbourBoat rides the
  swell within 150 m (was 300). A quick re-bench under load wasn't conclusive; the full gate pair needs rerunning. Open: if it's still
  over budget, fewer townsfolk in the street (customers, porters, kids are the cheapest to cut).

## 2026-10-19: skills rework, piece 1: the model (families, life skills, the refund)
Spec: docs/progression_plan.md "Decided (2026-10-19)".
- **Tree kinds** (SkillTree.TREES "kind"): shared (the Captain tree, was "Base & Haki": level skill points), weapon (its own
  mastery points), life (learned by doing, perks by themselves), fruit (skill points), tab (LIFE: shows the four life skills
  side by side; `tab_of` / `tab_trees`). `is_mastery_tree` = weapon or life; `is_weapon_tree` / `is_life_tree`.
- **Families** (SkillTree.FAMILIES): blades (cutlass, katana, dual, dagger, twin daggers, Corsair), heavy (axe), guns (pistol,
  Corsair), fists (unarmed). The fruit tree isn't a weapon (no mastery). `Progression.add_mastery` gives the tree its xp and
  FAMILY_SHARE (0.25) of it to each kin tree, fractions kept in `_carry` (not saved); a carried share never carries again (no
  pistol from the cutlass through the Corsair). Carried level-ups toast "(from Cutlass)" and give that tree its points.
- **Life skills** (swim, sea = Seamanship, cook, fish): mastery in the same `mastery` dict, no points; perks are "perk" nodes
  (req {"mastery": lv}, cost 0) owned by `_sync_perks` on a level-up and on every load, so they can't be bought (can_learn
  "Comes at Swimming 2"). `add_life(skill, xp)` is the API for cooking and fishing; Seamanship.xp already calls add_mastery.
  Swimming is measured in Progression._physics_process (every SWIM_TICKS, the local captain only, while the state is Swim,
  under 15 m/s so a teleport isn't a swim): SWIM_M metres a point. Nothing in swim_state.gd. Seamanship's 15 bought nodes
  became 6 milestone perks with the same keys and numbers (Sea Hand 2, Gun Captain 4, Hard Over 7, Storm Sailing 10,
  Broadside Master 15, Bosun 20). Cooking/fishing perks carry keys their systems will read (meal_time_pct, meal_power_pct,
  fish_*). A shared-tree node can need a life skill: req {"life": tree, "life_lv": n}.
- **Refund** (Progression.FORMAT 3): an older progression block keeps level, xp, mastery levels/xp and skill uses (gold and
  gear are other save sections, untouched); skill points = (level - 1) x 2 (+1 for Vey's on a format-2 save past that step),
  each weapon's points = its mastery level - 1, nodes and tiers cleared, life perks from the kept mastery. The banner says so.
- Debug: Alt+F9 a level of every life skill (F9 still a level and the weapon's mastery).
- Tests: t/progression/ family_carry, refund_migration, life_mastery; t/ship/seamanship rewritten for perks. Expect
  progtest, techtest, savetest, wieldtest, daggertest, balancetest to need a look once the trees are trimmed (piece 2).
## 2026-10-19: sprint-jump stamina, swim exhaustion without damage, stern corners
- **Sprint jump** (jump_state.gd): the sprint bound (take-off `jump_sprint`) spends SPRINT_JUMP_COST 10 through `spend_stamina` (same idiom as dodge:
  refused below half the cost, HUD denied flash). Too winded: the jump still happens, as a plain `jump_run` with air_speed back to walk speed (no sticky
  refusal). Standing/running jumps and the double jump stay free. Tested by t/player/sprint_jump_cost.
- **Swim exhaustion** (swim_state.gd, non-fruit only): no damage any more (EXHAUST_DAMAGE/TICK gone). Stamina at 0.5 -> exhausted: float-paddle at TIRED_SPEED
  1.1 (was 2.0), no sprint/dive, no stroke drain, regen at FLOAT_REGEN 0.25 of normal moving or not; back to normal at RECOVER 30 (was 25). Toast "Exhausted!
  Float and catch your breath". Devil Fruit drowning untouched. Tested by t/player/swim_exhaust; swimtest's "losing health" check now expects none.
- **Stern corners** (hull_builder.gd): the transom was one trapezoid from the quarterdeck rail corners straight to the keel corners, but the hull side kinks at
  the deck line (vertical castle above, slanting below), so a wedge of each stern quarter was open and the transom's UVs were skewed. Now two quads (castle
  rectangle + lower trapezoid) with position-mapped UVs (`_transom_uv`) like the sides'. Checked with modelshot back3/low before and after.

## 2026-10-19: skills rework, piece 2: fewer, bigger nodes
- **Weapon trees** (skill_tree.gd) cut from 23-27 nodes to 16-19: every move, active and ultimate kept (same ids, so
  tests and saves of them hold), the small stat and passive nodes folded into a few that change how the weapon plays.
  One shape on the grid for all: the moveset either side of the root (row 0), defence or grapples up col -2 (deflect
  -> counter skill -> Return), the stat node, the skills and the top stat up the middle to the ultimate, three style
  passives up col 2 (e.g. the cutlass's Flourish: finishers and the thrust; Plunder: leech and execute; Swashbuckler:
  cooldowns and energy), the element's two mastery nodes just left of the skill / top stat they hang off. The damage
  each tree gave in total is the same (the cutlass's +6/8/10/12% became +14% and +22%).
- **Costs** (`_add`): a move 1, a stat or passive 2, an active 2, an ultimate 4, a Return / top stat / Last Stand 3
  (the Devil Fruit tree keeps 1/2/3). A weapon tree costs 31-38 points in all against the 29 its mastery gives, so
  the last few are a choice; family carry-over is how a second weapon of the family catches up.
- **The Captain tree** (was Base & Haki, 49 nodes -> 34): a ring of 8 bigger body stats (Agility, Endurance, Vitality,
  Focus with Quick Learner folded in, Toughness, Strength, Spirit, Sea Legs), Mobility 5 (Swift Step has Slip and Gale
  Step in it; Sky Walk has Featherfall), Survival 8, Armament 4, Observation 4, Conqueror 2, and the **Seafarer** (off
  Sea Legs at 180 deg): Sea Born (needs Swimming 4) and Helmsman (needs Seamanship 5): the shared tree's life-skill
  nodes, paid with level points. No cooking/fishing nodes there until their systems exist.
- Progression.FORMAT 4: piece 1's format-3 saves are refunded again (with Vey's point and their uses).
- Tests: t/progression/can_learn (the costs and gates, and the shape: links real, every node reachable, no two on one
  spot, every skill and all 19 moves still taught, no 1-point weapon filler, sizes). progtest's point sums and
  techtest's "learn everything" (life skills levelled first) and node-count check updated, not run (world suites).

## 2026-10-19: skills rework, piece 3: the skill map says what pays and what's next
- skill_map_screen.gd: tabs in four groups (Captain | weapons | Life | Fruit, TAB_GAP apart); a third header line
  (HEADER_H 55) says what pays: "Paid with skill points: 2 every level", or a weapon's own mastery points with its
  family's share and each kin tree's mastery level ("The blades share 25%: katana 4, dual 4..."), or, on Life, which
  Seafarer nodes the life skills open. A weapon's header has a mastery bar. Unlearned nodes show their cost (top right,
  green when you can pay it). Names under every node from zoom 0.5 (k 1.0), but col -1 (elements, Mind's Eye,
  Bandolier, Smoke Bomb) only from 0.7, where they'd hit the skills' names.
- The LIFE tab: four columns, each perk with its milestone level inside it and its name to its right; under each root
  its level, a bar and "next at N: <perk>". The panel shows a perk as "Comes at Swimming 7, free" and the skill's xp.
  It opens on Life when you're in the water. The Captain tree's frame was re-fit to its smaller size (Survival pulled
  in to 415).
- skill_bar.gd: the level badge shows the weapon in hand's unspent mastery points beside skill points ("+2 SP  +3
  CUTLASS [K]").
- Render: tools/dev/skillmapshot.gd (the light stage; it closes the creator and ends the story so the map opens; it
  waits in frames, as the open menu pauses the game's ticks).
- **t/ship/upgrade_cost back under its cap** (ship_parts.gd): a maxed sloop's parts had a 14th surface (a 4th glow: "glass") and drew 53 surfaces over plain
  (cap 52). "glass" is now the same cached PSXMat.glow as lamp_gold (nearly the same colour), so 13 surfaces and 52. PSXMat folds tints into vertex colour
  already, so same-texture materials were never separate surfaces; only glows (emission colour is the material) are.
## 2026-10-19: yard ropes, rope prompt in the air, shorter ropes, pirates that board
- **Ropes are an upgrade now** (ShipLines "ropes", Rig group, one level: 90 gold + 2 timber, a placeholder for the economy pass):
  the sloop has no swing ropes until bought; ShipParts `_fit_ropes` hangs `RopeS` / `RopeP` under the yard (outside `_nodes`, so
  another line's rebuild never frees a rope someone swings on) on every screen from the kit, so a guest's purchase through the
  host-arbitrated yard order (Net.request_upgrade) shows for all. Old saves: `ropes` is 0 (legacy 0). A second tier (more ropes, a
  longer reach) doesn't fit: stopped at one. upgrade_cost's surface budget 52 -> 55 (the ropes' 3 used to be on the plain sloop).
- **Airborne, the rope's prompt wins** (`Interactable.air_first`, set by SwingRope; InteractionComponent drops its score by 100 in
  Jump/Fall): a cannon, ladder or seat beside it no longer takes the F. On the ground the nearest still wins.
- **Shorter ropes:** `ShipParts.ROPE_LENGTH` = yard - deck - 3.6 = 9.88 m (was 11.28), and the swing no longer takes its length from
  where you stood (that put the low point 0.6 m over the deck, through the guns): `SwingRope.ride_cap` = length + HANG 1.5, a grab
  lower than that is hauled up to it in ~0.1 s (SwingState's existing `_max_len` reel). The feet's low point is 2.32 m over the
  keel line (2.0 m over the deck), the guns' worst top (barrel at full elevation) 1.87: 0.45 m clear (0.9 m of a gun at rest). The
  rope is made fast to the braced yard, so it moves over the guns as the sail trims: the same clearance everywhere.
- **Why pirates almost never boarded:** (1) a ship only went for a boarding when the crew was *catchable*, slower than her top speed
  less 0.5, so any crew at full sail (11 m/s x wind, +15% with sails 5) was never boarded: a brig (10.5) stayed 54 m off for the
  whole fight, and marines don't board; (2) the "close" trigger (< 26 m) can't happen, the broadside circle pushes her out at < 28-36 m;
  (3) once in BOARD she needed to be within 6.5 m of the spot and 13.5 m off, and gave up after 25 s. Now: after BOARD_AFTER 14 s
  broadsiding past the first volley she goes for a boarding whatever the crew's speed; BOARD runs at up to 1.15x her top speed
  (a crew outrunning her by more than that keeps her off), gives up after 40 s, and the range is looser (8 m / 14.5 m). **Telegraph:**
  the bosun shouts "Grapples away!" and three lines fly to your rail (`Net.fx` tracers + rope sound, every screen), and the men
  leap HOOK_TIME 1.2 s later (host-simulated as before, the leap and crew already sync to guests; the bark rides her snapshot).
  She loses the hook if she's pulled 18 m off.
- Tests: t/ship/yard_ropes (bought, saved, a swing's low point, the prompt in the air and on the ground), t/ship/enemy_boarding (a
  sloop boards a too-fast crew within 60 s, grapples first), t/ship/upgrade_* pass. riggingtest fits the ropes before its swing
  (world suite, not run here; its "swings you across the deck > 3 m" and "off your feet" checks should still hold, the swing
  is higher now). Co-op paths touched: the kit apply (every screen), `Net.fx` tracers/sfx and the existing state/bark snapshot of
  EnemyShip; no nettest run.
- Skills-rework test fallout (r6test, wieldtest, techtest): r6test's re-centre expectation follows the Captain tree's re-fit pan (-HEADER_H/2 - 45); wieldtest's Corsair size check is 16-19 nodes (17); techtest's "nobody in reach" grapple waits 4 ticks after parking the grunts (their hurtboxes were still in the old spot in the physics server, so a suplex sometimes grabbed one). The counter/dagger checks passed on current main.
- Fix (main red before v1.18): chartest, qoltest, perftest, harbourtest and daggertest stopped with "Identifier not found: FX" at buildings.gd:534. Props has named Buildings since 7bf4bdd, so a suite naming Props compiles buildings.gd before the autoloads exist, and its three static `FX.chimney_smoke` calls didn't compile. `Buildings._smoke` reaches FX through the tree (like NightLight). daggertest's tree check also wanted 20+ nodes; the skills rework cut weapon trees to 16-19, so it checks 14-19 like techtest. All five suites pass.
## 2026-10-19: island suites green before v1.18 (chaintest, lighttest, t/island/forest_fauna)
- chaintest: the treasure X check capped distance at 320 m from Brinehollow's centre; LAND_R is 400 now and one of the four spots fell at 391 m. The bound is `starter_island.LAND_R`.
- lighttest: Brinehollow had 35 NightLights for a budget of 34 (the budget also has Buildings' own lights, the tavern door, harbour office, chapel, forge, tower, outside it). The shrine gate's two stone lanterns (5.8 m apart) both took a light; only the west one does now (the other still glows as a mesh).
- t/island/forest_fauna: the stag turns on a blow 3 times in 4 from its own rng, seeded by its node name (`@CharacterBody3D@N`, a serial that moves with every node made earlier), so the check passed or failed by chance as code changed. The test seeds the stag's rng before the blow.
- **Red-main fixes for the ship/player suites (stale expectations, no game change):** riggingtest and t/ship/yard_ropes grabbed the rope from the
  ground, but the rope hangs by the second gun (x 3.6 vs 3.65) and on the ground the nearer interactable, the gun, wins by design (yard_ropes only
  passed its first check because the captain was still falling): both now jump into it (the rope wins in the air), and yard_ropes gained a grounded
  grab with the rope moved clear of the guns. bugtest stood the captain 7 m east of a nest bug, now off a ledge into the sea (the Brinehollow
  rebuild moved the ground): it picks level ground round the bug (and waits in physics ticks: under load its process-seconds waits ended before the coins' flight, a check the first failure had hidden). r10test's sprint reversal ran the captain 17 m into a house (speed 0 for 0.3 s,
  so no skid): it first finds a clear 24 m run. nettest board: the client waited 20 s (from the scene change) for the host's captain; alone it
  has it in 2-4 s, but under the crew's five test slots its world load alone took ~20 s, so the window closed as the world became ready
  (world_ready true, no puppet yet; the host's "stalled" line is only the host idling after the client quit). The wait is 60 s now, like the
  join wait above it.

## 2026-10-19: v1.18 lane D, piece 1: the crew journal (J), quests in steps, rewards that aren't XP
- **Journal** (new autoload, `scripts/quests/journal.gd`): one journal for the crew. `entries` (id -> title, giver, isle, `pos` = the island's
  middle, `src` npc/board/found, `goals` per step, `step`, `done`, `reward`, `cost`, `order`), `rumours` (40 kept), `perks` (`discount:<shop>`,
  `favour:<quest>`), `tracked` (this captain's: "story", a quest id or ""). Changes are asked of the host (`take`, `advance`, `turn_in`,
  `call_favour`, `hear`) -> `decide` (still good? nobody beat them to it) -> `Net.everyone("_all_journal")` -> `apply` on every machine. Single
  player runs the same path locally. Quest defs stay with their maker (`register(def, source)`; KitQuests is the source: `target`, `is_person`,
  `progress`); an entry carries its own texts so the journal reads the same once the island's gone (target falls back to the island's middle).
- A quest def: `steps` [{"do": reach / pickup / talk / clear / turnin, "goal", "said"?, "who"?}], the last always the turn-in to the giver;
  `reward` (QuestRewards: gold, items, `reveal` a treasure map via GameManager.maps (30 gold once all are held), `discount` [shop, fraction, name],
  `favour` {who, gift}); `cost` items handed over at the turn-in (fetch). **No XP from quests** (progression_plan.md): the old KitQuests XP is gone.
- **Everyone present gets the reward:** the turn-in's `done` op carries where and by whom; each machine pays its own captain if within
  `REWARD_REACH` (40 m, like kill XP); only the captain turning in hands over the cost; discount/favour are crew perks, applied everywhere.
  A favour is called in once at the giver ("I've come to call in that favour."), its gift to the caller.
- **KitQuests** on the model: lost (pickup -> turnin), scout (reach -> turnin), deliver (talk to the recipient -> turnin), fetch (turnin with
  cost, the goal counting "(1/3)"), clear (clear, host-checked -> turnin). Dialogue choices gate on the journal through a new `"if": Callable`
  key on choices (dialogue_manager, code-defined trees only), replacing the per-captain `_taken/_got/_paid` flags (old saves' flags are just
  ignored). IslandLife builds steps and rewards (`_reward`: its own rng `hash([seed, 5103, qi])`, so the plan's draws and nettest's comparison
  are unchanged): gold by tier, often part-swapped for items, a map, 10-15% off at the island's trader, or a favour.
- Rumours: named villagers' island and "ahead" rumours go in the Rumours tab when told (`Journal.tell(key, lines, who, isle)` + the node's
  `"event": "rumour:<key>"`).
- **Objective HUD** (`objective_hud.gd`): the tracked quest if it's live, else the story (unless tracked is ""), else nothing; head QUEST /
  OBJECTIVE, goal with progress, the marker on the step's target (a person: NPC_NEAR), a flash on a new step. Taking a quest tracks it when
  nothing is being followed. `hidden_by_menu` hides it at once (the HUD is paused under menus).
- **Screen** (`scripts/ui/journal_screen.gd`, on Journal's own CanvasLayer 29 + PixelCanvas, fits 640x360): tabs ACTIVE/DONE/RUMOURS with
  counts, list left (the story first while it's on), detail right (giver, island, steps ticked/now/later, reward, the favour still owed),
  Track. J opens/closes (KEY_J read by Journal itself, no input action: B owns input), A/D or Q/E tabs, W/S pick, T track, Esc closes. It
  pauses like GameMenu (Net.set_paused, hud set_menu_open, Settings.capture_mouse on close) and won't open over a menu, a talk or the creator.
- Co-op: `Net.journal_ask` -> `_journal_req` (host; the asker's id for done/favour) in its own block in network_manager; the journal rides
  `_world_state` / `_apply_world_sync` for a late joiner. Saves: `journal` (world state: a guest keeps their own world's) and `tracked`.
- Tests: t/quests multi_step, turnin_giver, rewards_present, journal_save, hud_tracked. lifetest's quest part moved onto the journal (not
  run in this tier). Render: `tools/dev/journalshot.gd`. Expected to affect lifetest, storytest (HUD), savetest, nettest (world sync).

## 2026-10-19: v1.18 lane D, piece 2: notice boards, givers' own lines, roles' small talk, no line said twice on an island
- **LineDeck** (`scripts/quests/line_deck.gd`, `IslandLife.deck`, seeded `hash([seed, 5104])`): every pool shuffled from the island's seed
  and dealt from the top; a line dealt once (from any pool) never again on that island; a dry pool deals nothing (that person has fewer lines;
  Villager._bark keeps quiet on an empty pool). IslandVillage's people deal first (village step: innkeeper/trader/cook from the theme's
  `service`, the plaza villagers two `day` lines each), then IslandLife (`_own_lines`, in placed order): a day/evening/night line each, one per
  kind of place their routine visits, a pointer at someone with work, and for named characters a menu greeting, a "quiet" line, three lines
  of their role's `talk` and their rumours (`_rumours`: island rumours and the way ahead dealt too, so two people never tell the same one;
  `rumour_hard` once). Quest `taken` lines and favour thanks are dealt as well. Ordinary villagers' talk = their own day + work + pointer
  lines; their bubbles = their own lines by time and place (+ a named one's small talk).
- Theme text (`<theme>_life.gd`, all four themes): barks day/evening/night 18-20 each, 6-7 per spot kind (nets forage dock boats stall market
  home plaza inn workshop field shrine well bench storehouse), pointer 12-15; `menu`, `taken`, `rumour_quiet` now arrays; `work_menu` (the
  captain's "how's the work" line -> node "work": the role's small talk); every role's `talk` (6-7); `notices` (board, bounty, lair, beast,
  posted: 5-7 each, tokens {name} {poster}); `service` (inn, trade, cook: 6-7 each).
- **Notice boards:** IslandVillage.jobs (camp, lair, beast: {name, at, check}) become notices in the journal (`IslandLife._post`, kinds
  bounty/lair/beast in KitQuests.STEPS/NOTICE_TITLE/GOLD): the bounty posted by the elder, the lair and the beast by the elder (35%) or a
  named character (seeded `hash([seed, 5105])`); each is a clear step then "Report to {poster}", turned in to that poster only
  (KitQuests.post on the board, KitQuests.report in the poster's talk). The board and elder talk are defined by
  `IslandVillage.define_talk(notices, qn)`. The old per-captain job flags, the elder paying for everything, and the job XP are gone.
- A favour-owing quest from a poster is called in at the poster too (KitQuests._favour).
- Tests: t/quests/unique_lines (four themes built whole: no line said by two people, ~20 people each with lines, small talk, notices
  reported to their posters). isletest's bounty part moved onto the journal (not run in this tier). Brinehollow islanddump identical
  (only the dummies' unseeded sack heads differ).

## 2026-10-19: v1.18 lane D, piece 3: encounters and events on generated islands
- **IslandEncounters** (`scripts/quests/island_encounters.gd`, the island's "Encounters" Node3D): `roll(seed, theme)` (data, in
  IslandLife.plan: `hash([seed, 5201])`; 0/1/2/3 kinds at 15/40/33/12%, weighted by the theme, never a kind twice; `force` for tools and
  tests), built after the people (IslandLife.steps: "encounters", a step each). A kind that finds nothing it needs leaves nothing.
- Kinds (10): traveller (by a trail at a fire: small talk, two rumours into the journal, a gift once per captain: the item its line names),
  ambush (3-4 grunts in a GruntCamp beside a trail, never respawning; a captain within 13 m springs it: banner + shout, the host alerts them),
  festival (the village plaza: four lantern posts, a host who shouts festive lines over the crowd 17:00-23:30 and wants food for the feast:
  a fetch turn-in with a favour), shipwreck (a beach: wrecked rowboat, timber, a survivor's camp; their chest washed up elsewhere on the
  shore: pickup -> turn-in, a treasure map), merchant (a tipped handcart on a trail; the strongbox at the pirates' camp: pickup -> turn-in),
  lost_child (a parent at the plaza; "Young <name>" at a wild place: talk to them -> they're home beside the parent -> turn-in, a favour),
  hermit (at a wild place by a fire: rumours; go and see another wild place: reach -> turn-in, a map), wounded (seated by a trail: a Sea
  Tonic), note (remains with a satchel by a trail: "Search" reads the note and takes the quest: the keepsake to a named villager, who
  gets a turn-in choice: things you find, `src` "found"), duelist (a swordsman on a trail: accept and he fights as a captain grunt of a
  GruntCamp of one, level +2; beaten, he stands again and pays gold and a tiered weapon).
- Text per theme: `scripts/island/themes/<theme>_encounters.gd` (`ThemeDef.encounters`, a new contract member: weights and every kind's
  lines), dealt through the island's LineDeck like everyone else's. Placement: trail spots 35-120 m along a path, 4.5 m aside; beaches
  scanned in from the coast, 70 m+ from the dock; wild places from IslandLife's POIs (not the camp); spots are dry, fairly level, off
  paths and clear of anything solid (a physics sphere 1.1-5.1 m up; people and moving bodies don't count, so guests place the same).
- Co-op: rolls and placement are the island's seed; quests through the Journal; the ambush's and duel's crews are GruntCamps (host
  simulated; the duel's camp appears on every machine once the journal says the challenge was taken); gifts are per captain (a flag).
- Tests: t/quests/encounter_rolls (every theme's pool complete, 8+ kinds weighted, feast items real; rolls the same per seed, 0-3, no
  repeats, every kind over 300 seeds; a jungle island with all ten forced builds them all, quests turned in to someone on the island, no
  unfilled tokens, the same places on a second build). unique_lines covers their lines too.
## 2026-10-19: v1.18 lane D, wiring the journal into main's contracts (map marks, recipes, charts, discounts)
- **The held map:** ObjectiveHud puts whatever it follows (the tracked quest's current step, else the story) on this screen's
  map as `MapMarks.put("quest", target, "quest", title)` every 0.25 s (its existing poll), and clears it when there's nothing
  to follow or the HUD goes. Local per machine, as MapMarks wants.
- **New rewards** (QuestRewards): `"recipe": meal id` (Food.teach on each captain present; gold MAP_GOLD if they know it),
  `"chart": true` (a place on the turn-in's island the crew hasn't found: the host picks the unfound MapIsles spot
  furthest from the turn-in in `Journal.decide` and appends [fog key, spot id, name, n, cells] to the "done" op; every
  machine marks it found and lifts the fog CHART_SEE 28 m round it through MapFog, so it's shared and saved like any find;
  none left: gold instead). The "done" op is now [id, at, by, chart]. IslandLife._reward rolls 8 ways now (items with
  lane A's ingredients and pearls, treasure map, chart, discount, favour, the Captain's Feast recipe, plain gold x2); the
  hermit's errand pays a chart instead of a treasure map.
- **Discounts are real:** shop_screen prices stock through `crew_price` (Journal.discount(shop_id) off the curve) and shows
  "-n% crew" by the shop's name (a small edit in lane A's file).
- J won't open while the chat line is up (it read the key before the LineEdit), a wheel is out, or input is locked.
- Tests: t/quests/reward_kinds (new); hud_tracked checks the map mark; rewards_present/journal_save/journalshot pass the
  4-arg "done".

## 2026-10-19: v1.18 controls, piece 1: the quick item (E), keys 1-5, the action wheel and making camp
- **Keys:** 1-5 are ability slots, R the ultimate, nothing on 6+. E is the quick item (tap: eat/drink the selected one; hold: the
  item wheel). N is the action wheel (hold). T is still emotes. Input actions `quick_item`, `action_wheel`, `skill_5`; `hotbar_1..3` are gone.
- **The quick item** (InventoryComponent): `quick` (the selected item id, saved as "quick"; old saves' "hotbar" gives its first food or
  drink), `select_quick(id) -> bool`, `quick_item()`, `quick_choices()` (every food and drink carried, bag order; the wheel's planks),
  signal `quick_changed`, `quick_ok(item)`. The first consumable you pick up fills it; when its stack runs out it moves on to the next food you
  carry (`_quick_ran_out`, from remove_item/take_at/take_all_except); with none left it's remembered. Like a weapon in hand, the selected stack is
  off the bag grid and takes no bag space; the other food lives in the bag now (the three quick slots no longer hold two extra stacks free).
  `Player.use_quick()` (the tap): refused at once on the shared heal cooldown (the bar flashes), otherwise wanted for QUICK_BUFFER 1 s: a tap
  mid-swing drinks the moment the swing's combo window opens (it ends the chain). The galley restocks the first 3 kinds on the wheel, the
  selected one first.
- **Keys 1-5** (PowerComponent): SLOTS 6, ULT 4 stays on R (saves keep it there), slot 5 is key 5 (`KEYS = [0, 1, 2, 3, 5]`, `key_of(slot)`).
  The skill map puts a skill on 1-5 / R; the bar draws [1][2][3][4][5] [R] | [E].
- **RadialWheel** (scripts/ui/radial_wheel.gd): the emote wheel's ring, planks and picking, shared by the emote (T), item (E) and action (N)
  wheels; planks can carry an icon, a second line (counts), greyed (out of stock) and a sun rim (the current choice). A `tap_ok` wheel opens
  only after HOLD 0.2 s held; a quicker press is `_tap()`. One wheel open at a time, none while input is locked (menus; the chat line later).
  Polls the key (tests drive it with `Input.action_press`).
- **ActionWheel** (scripts/game/action_wheel.gd, the registry other lanes add to):
  `ActionWheel.register(id, label, icon, available: Callable(p) -> bool, run: Callable(p), order := 100)`; label may be a Callable(p) ->
  String; icon a texture path or "". Re-registering an id replaces it; `ensure_builtins()` adds "camp" (10) and the "train" placeholder (20)
  unless a feature registered those ids first. `ActionWheel.place(p)`: "island" (ashore), "town" (Music.in_village), "ship" (aboard the owned
  ship), "" (swimming, helm, air).
- **Camp** (scripts/game/camp.gd): Make camp (ashore, out of town, no enemies fighting within 40 m) lays a campfire 1.25 m ahead on flat ground
  and sits you by it (the Sit state; "Rest by the fire" turns you to one already there). Sitting within 3 m for REST 3 s rests you
  (GameManager.rest: full health/stamina/energy and a save). It burns 240 s; one per captain (`Camp_<peer>`, the old one dies down).
  Co-op: `Net._all_camp` (the controls block at the end of network_manager.gd) builds it on every screen; a crewmate rests at anyone's fire on
  their own machine. Not in world sync (a captain joining later doesn't see a fire already burning). Respawning at the camp is for later.
  Perf: one OmniLight (distance fade 45-55 m), meshes to 90 m without shadows, particles to 60 m, a 0.25 s timer, nothing per frame.
- Tests: t/ui/item_wheel, t/ui/action_wheel, t/player/skill_slot_5, t/player/quick_mid_swing, t/items/quick_save; the hotbar's tests and
  suites (rum_quick_slot, heal_timing, heal_kinds, chest_loot, starting_kit, meet_menu, invtest, looptest, powertest, r6test, r7test,
  progtest) follow the new API.
## 2026-10-19: v1.18 economy, piece 1: scarce loot, per-captain rolls, weapon traits, one price curve
- **Loot** (`scripts/items/loot.gd`, Loot): every captain rolls their own. Kills: `Net.coins` sends the creature's own count to every
  machine and each rolls `Loot.kill_gold` (KILL_GOLD_K 0.45 x 0.6-1.4, never none); drops go through `Net.kill_loot(table, at)`
  (`[[id, chance, count]]`, each machine rolls its own into a plain local bag; a weapon lies alone), used by creature.gd's `drops` and the
  grunt's sidearm (DROP_PISTOL 0.06, DROP_BLADE 0.04; was 30-45%). Chests: a LootBag with a save id, plunder afloat, or `rolls` (the
  prize chest) is rolled the first time it's opened (`LootBag.roll()`, `Loot.chest`), seeded by its key and the captain's name, so a
  reload can't reroll and a crewmate's copy differs. Gold x0.45 (0.7-1.3), treasure kept 35% each, supplies 50% each, a generic weapon
  30% (always in a boss's hoard: put in with >= HOARD_GOLD 55 gold), rerolled to a design of its kind with a trait from blue up.
  Uniques, fruits, gear and salvage stay; Brinehollow's hand-placed chests (save ids without "isle") keep their weapons. Never empty.
  The island generators are untouched (their rng draws are unchanged, so every island builds as before): the roll is downstream.
- **Weapon traits** (`scripts/items/weapon_traits.gd` data, `trait_moves.gd` what they do): 11 traits, one per Rare+ weapon, each
  changing a move: serrated (finisher bleeds 5 s), gale (finisher throws a 9 m wind blade), bloodthirsty (finisher heals 5%),
  thundering (heavy: a 3.5 m knockdown shockwave), headsman (heavy: double on an enemy under a third), rushing (the running cut drives
  twice as far and knocks down), embered (a roll leaves fire), duellist (a parry ripostes), venomous (hits poison), hair-trigger
  (a shot within 1 s of a roll crits and knocks down), blasting (the load's last ball bursts 2.5 m). +20% a tier above blue. The trait
  rides in the id: `"<base>@<tier>+<trait>"` (`ItemDB.with_trait`), named "Serrated Cutlass", a tooltip line in the tier's colour, and
  its name floats up when it fires. Red Tide is thundering, the Queen's Fang venomous. Hooks: `Player.melee_hit` -> `TraitMoves.shape`,
  `PowerComponent.on_sword_hit` -> `landed`, Dodge/Parry/Shoot states, LightAttack's running cut (`rush_k`); all on the captain's machine
  (effects via Net.fx, Projectile/FireZone sync themselves). WeaponTraits has no autoload names (ItemDB reads it; test scripts name ItemDB
  before the autoloads exist).
- **One price curve** (`scripts/items/economy.gd`): worth = value x 1.6^tier (ItemData.RARITY_VALUE now exactly that), a trader asks
  worth x 4 (weapons, gear), x2.5 (food and drink), rounded nice (`Shops.price_of`; the numbers in stock entries aren't read any more),
  pays worth x their rate. Ship upgrades: level n = the line's "base" x 1.6^n (`ShipLines.price/entry`; the gold column is gone).
- Tests: t/economy/ (drop_rates, captain_rolls, trait_finisher, price_curve); chest_loot, quiet_areas and r7test mark their chests
  `rolled` (they test taking, not the economy); yard_buy reads the curve's 95 for armour 2. Suites likely to notice: faunatest
  (drops via kill_loot), bugtest/netclient (coins rolled per captain, never none), qoltest/uitest (prices on the curve), nettest
  (`_all_kill_loot` is new co-op traffic, the ruins chest roll).
- Finished (second agent): every trait hook is live in play (checked by trait_finisher, trait_roll_fire, trait_gale on the light
  stage). A trait weapon arriving in the bag (found, bought, given) gets the HUD's big banner once a session: its name in the tier's
  colour and its trait line under it, with the chime (`PlayerHUD._on_item_added`, `_announced`).
## 2026-10-19: v1.18 economy, piece 3: specialist shops with rotating stock, buy-back, artisans in the wilds
- **Trades** (`scripts/game/shops.gd`): every shop has a `trade` (smith Haldor, armourer Vey, tailor Sela, grocers Ida and Marlo,
  cook Gus, luthier Corin, treasure merchant Nessa; a village's Trade Goods is its treasure merchant, its Cookpot a grocer; artisans).
  `stock` is the staples, `pool` + `size` the day's picks: `Shops.stock(id)` = `stock_on(id, Weather.day())`, seeded by the shop id
  and the day, so a crew sees the same stock (Weather's clock is the host's) and it turns over each in-game day (24 min). Haldor 4
  staples + 5 of 12, Vey 2 + 4 of 9, Sela 6 + 10 of ~40, Ida 4 + 3 of 6, Marlo 1 + 2 of 4, Gus rum and stew + 1 galley meal.
- **Rare only at treasure merchants**: smiths, armourers, tailors and grocers stock white and green only. A treasure merchant
  (`trade` "treasure", `tier`) adds each day one weapon of their tier (a random design with its trait, Loot.weapon's roll written out:
  naming Loot from shops.gd breaks the tests that preload it) and on 60% of days a piece of rare gear (RARE_GEAR). Nessa's tier is 2
  (blue); a village's is the island's tier, at least 2. A village trader's tiered staples get a trait from blue up (`with_traits`,
  its own stream: the village's rng draws are unchanged). Village cookpots stock 3 a day of their theme's grocer goods (THEME_GROCER).
- **Buy-back** (`Shops.note_sold / sold_back / took_back`, ShopScreen): what a captain sells waits after the stock in a tinted row
  priced at what the shop paid ("BUY BACK n G"), until the day turns; per captain, not saved.
- **Artisans** (`scripts/island/artisans.gd`): 45% of generated islands (their seed + 7717, a stream of its own) have a fisher,
  herbalist, wandering smith, weaver or trapper camped 5 m off a trail point at least 45 m from the village and 35 m from the dock,
  22 m from every site, on gentle dry ground: `Artisans.plan` in GenIsland.prepare after the dock and before the plants (reserves
  6 m), `Artisans.steps` after the village (a fire with its crackle, a tent, a crate, a log, the NPC with a shop in Shops.extra under
  `isle<id>_artisan`: 2-3 of their goods, what they buy). Every machine builds the same camp from the seed.
- Tests: t/economy/shop_rotation, t/economy/artisan_camp; brinehollow_shops and qoltest read stock + pool (qoltest: Marlo buys
  ingredients now). Suites likely to notice: qoltest, uitest (shop screens), isletest (the village trader's stock), smoketest /
  chain suites (islands with an artisan grow their plants round its reserve, so their vegetation differs from before).
## 2026-10-19: v1.18 economy, piece 2: food takes over healing, ingredients, galley cooking, meal buffs
- **Regen** (`Player._tick_body`): out of a fight you mend REGEN_PCT 1% of max health a second once CALM_S 8 s have passed with no
  blow taken (`_since_hit`) or landed (`fought()`, from PowerComponent.on_sword_hit); `in_fight()`. Mend's regen_hp and the Vine
  Fruit's photosynthesis ride the same gate now (Mend's was 5 s). A meal's `regen_pct` multiplies the base.
- **Food and drink** (ItemData `stamina_amount`, `energy_amount`, `meal`, `ingredient`): the old heal/cooldown/spill flow is
  unchanged; drinks give back stamina (rum +35) or energy (tonic +30), and an item that does more than heal can be taken at full health.
- **Ingredients and meals** (`scripts/items/food.gd`, Food; made as items in `Food.make_items` from ItemDB, icons from
  `gen_psx_textures.py icons`/gen_food_icons): tags fish, meat, fruit, grain, spice, greens. New raw ingredients (LOOT, Economy's kind
  "ingredient", grocers buy them at half): rice, flour, salt, pepper, mushroom, seaweed, coconut, egg, oyster, sea_urchin; food that
  counts as a tag too: fish, crab_meat (fish), boar_haunch (meat), tangerine, jungle_fruit (fruit), biscuit (grain). `pearl.tres` is
  loot for lane E's dives. Sources: Ida (grains, spice, mushrooms), Marlo (fish, crab, kelp), village cookpots (rice, pepper), toucan
  eggs, treant mushrooms, monkey coconuts; fishing (later) only has to hand out fish-tagged items.
- **Meals** (Food.MEALS, 10-20 min base): Fisherman's Stew (fish+grain: +20 max hp, +50% regen, 15), Peppered Boar (meat+spice:
  +8% dmg, 12), Sailor's Porridge (2 grain+fruit: +20 stamina, +15% stamina regen, 20), Citrus Tart (2 fruit+grain: +15 energy, +20%
  energy regen, 15), Island Skewers (meat+fruit: +6% run and sprint, 15), Reef Salad (fish+greens+spice: +15% swim, +10 stamina, 15),
  Forest Curry (2 greens+spice+grain: +6% crit, +3% dmg, 12), Captain's Feast (taught: meat+fish+fruit+spice: +25 hp, +5% dmg, +4 def,
  20). One meal at a time, the newest wins: `Progression.meal / meal_left / meal_k` (saved in its dict, ticked on game time in its
  `_physics_process`, on the captain's own machine), its buff added in `Progression.stat` outside the node cache, `_recalc_stats` on
  start and end. Cooking's perks read on eating: meal_time_pct (Ship's Cook +25%), meal_power_pct (Master Chef +20%).
- **Cooking** (`scripts/ui/galley_screen.gd`, GameMenu "galley", `GameMenu.open_galley(portions)`): the ship's galley opens it
  (replacing the free restock: GameManager.restock is gone, `galley_portions()` = 1 + the Galley & bunks line's "portions", up to 4).
  `Food.cook` takes raw ingredients before edible food, the cheapest first; Cooking mastery 20 + 10 an ingredient (twice the first time
  a dish is cooked: `Progression.cooked`); taught recipes (`Food.teach(pr, id)`, saved in `Progression.recipes`) for quest rewards.
  The sizzle (`gen_psx_audio.py sizzle`, UIStyle "sizzle"). HUD: the meal's icon, name and m:ss top right under the gold, blinking in
  its last minute (`PlayerHUD.meal_text()`).
- Tests: t/food (regen_gating, meal_buff, cooking_gain); t/ship/new_lines (portions), t/items/heal_kinds and looptest lost their
  restock checks (looptest cooks instead). Suites likely to notice: looptest, qoltest/uitest (galley prompt, shop stock), faunatest
  (new drop entries), nettest (nothing new on the wire: meals are local).
## 2026-10-19: the held map, piece 1: fog of war, `?` marks, the island page (v1.18 lane C)
- **Islands** (`scripts/map/map_isles.gd`, MapIsles): Brinehollow and the chain's standing islands as dictionaries made once per
  island node: key ("brinehollow", "isle<chain id>" like GenIsland.save_key), the world origin of island space, the height grid's
  square (`rect`, the map's square), the fog grid (`n` cells a side of FOG_CELL 12 m: Brinehollow 65, a big desert island 120) and the
  spots read from the island kit's data, never changed: GenIsland.sites (camp, lair, ruins, summit, boss), Island.places (landmarks,
  set pieces, theme places; MapIsles.kind_of picks the icon) and GenIsland.interiors (caves, the temple: at the mouth); Brinehollow's
  from StarterIsland's constants (ruins, lighthouse, queen's cave, Grell's den, smugglers, castaway camp, falls, wreck, fisher's
  cove, the jungle stash, the yard). `at(tree, p)` = the island whose square holds world point p ({} at sea).
- **Fog** (`scripts/map/map_fog.gd`, MapFog): GameManager.fog (key -> PackedByteArray n*n, 255 = seen) and found spots in
  GameManager.charted as "spot:<key>:<id>". GameManager._process ticks it: every 0.5 s (game time) our captain uncovers within
  34 m + 0.9 m per m above the sea (to +60: hilltops and the lookout see far) and finds a spot within 16 m + its size. Nothing
  runs per frame. New cells and finds go through Net (its own block, "The held map"): `fog_reveal` / `spot_found` ->
  everyone("_all_fog"/"_all_spot"), so any captain's exploring uncovers it for the whole crew; the finder's name is in the toast.
  The world state carries [MapFog.pack, the found spots]; a joining guest takes the host's in place of their own. Saved as "fog"
  (deflated grids); a guest's save keeps their own world's fog and "spot:" keys.
- **The island page** (`scripts/map/map_isle_view.gd`, MapIsleView; `shaders/map_land.gdshader`): the land drawn by a canvas
  shader straight from the island's `heights` (an RF texture, no per-pixel GDScript): sea in two depths with a dotted shallows ring,
  land in height bands with 6 m contours, the shore inked; paths dashed and the town's blocks under the fog; the fog pass is blank
  paper with a hatched band and an inked edge (noise-wobbled, hard pixels); over it a red `?` near (MapIsles.rough: 8-24 m off)
  every spot not found, found spots' icons and names (a label placer keeps names apart), treasure Xs, the crew's marks, the ship and
  the captains. Layers redraw only when MapFog.version moves; the captains' layer every frame while open.
- **sea_chart.gd**: M on an island opens on its page, at sea on the chart; the mouse wheel goes between them; marks set on either.
- Tests: `t/map/` fog_reveal, spot_marks, fog_shared (the stub island `tools/dev/map_stub_isle.gd`). Render: `heldmapshot`.

## 2026-10-19: deeper swimming, piece 1: breath, diving, dive loot (v1.18 lane E)
Spec: docs/v1_18_plan.md ("Swimming", "Breath").
- **Diving** (swim_state.gd): Ctrl is a duck dive (DIVE_KICK 3.6 m/s down, DIVE_COST 6 stamina), then you swim free under water: hold Ctrl
  to go down (DESCEND 2.6), Space to kick up (ASCEND 3.4), neither drifts up (DRIFT_UP 0.9), DIVE_VACCEL 9; DIVE_SPEED 3.0 / DIVE_FAST 4.3
  (Shift) x swim_pct. Back through the surface (after DIVE_MIN 0.4 s, rising, at the float height) you surface with a splash. Exhausted: you rise.
  Strokes cost DRAIN/FAST_DRAIN under water as on top (the old DIVE_DRAIN 8/s and the 2.6 s cap are gone).
- **Breath** (`breath`, `breath_max()` = BREATH 20 s x (1 + breath_pct)): spent only on a dive with the head under (x FAST_BREATH 1.6 at a
  sprint), back at BREATH_REFILL 9/s x (1 + breath_refill_pct) otherwise. At BREATH_WARN 0.3 a toast and a blip; at 0 `gasping`: a toast, the
  peril sting and GASP_DPS 6% of max health a second (0.5 s ticks, a small shake) until the head's out ("Air!"). A wave over a swimmer's head at
  the surface never counts: plain swimming can't drown a non-fruit captain. Bubbles from the mouth (`FX.bubbles`, new, via Net.fx).
- **Breath meter** (scripts/swim/breath_meter.gd, added by player_hud.gd): ten bubbles over the skill bar while breath isn't full in the water,
  amber and pulsing under 30%, empty: red, "SURFACE!" flashing and a red pulse in from the screen's edges.
- **Perks** (skill_tree.gd): Deep Lungs +50% breath (breath_pct 0.5) besides +10 stamina; Second Wind breath back twice as fast at the surface
  (breath_refill_pct 1.0); Child of the Sea another +50% breath. Strong Strokes / Sea Born speed count under water too.
- **Under water** (the camera follows a diver whose head is 0.9 m under, back up at 0.3: `SwimState.camera_under()` read by camera_rig.gd, which
  otherwise keeps it above the waves as before). Weather.gd `under_water`: the fog closes in blue-green (UNDER_SHALLOW -> UNDER_DEEP by depth to
  UNDER_DARK 22 m; you see UNDER_SEE 34 m just under, 13 m at depth), ambient dims, the overlay tints (UNDER_TINT 0.22), re-run when the depth
  moves 0.5 m. ocean.gdshader is `cull_disabled` now: its back faces draw only with `under_sea` set (Weather), as a bright rippling window
  overhead and a mirror of the deep further off; above water they're discarded. The wave maths is untouched.
- **Dive sites** (scripts/swim/dive_sites.gd, "DiveSites" under WorldGenerator): off each island's coasts, 4-15 m down, clear of the dock by
  70 m, 26 m apart: found by marching 64 bearings out from the island (150 m / 0.6 x radius) over the seabed (the island's terrain or the world's
  under it, whichever is higher), every level point in the open-sea band a candidate. Brinehollow: a wreck, a ruin, two chests, three oyster beds,
  two reefs (HOME_KINDS; 11 spots found); a chain island: a chest or two, 2-3 oysters, 1-2 reefs, a wreck on half, ruins on a third (its seed),
  built when it stands, freed with it. The deepest spots take the wreck and the ruin. Kinds: `sunken_chest` (a LootBag with the treasure-chest
  model and barnacles, usable in water, save id `dive_chest_<i>` through the island's save_key), `oyster_bed` (F: a pearl, PEARL), `reef_garden`
  (coral and kelp, F: REEF), `sunken_wreck` (a HullBuilder wreck on her side, her chest beside her), `sunken_ruin` (a plinth, columns standing,
  broken and fallen, an arch, a stone coffer with RUIN_LOOT). Each captain loots each once (chests are world LootBags; oysters/reefs mark
  GameManager.opened). Bubbles at the surface over a chest still down there, and a glint under water (local, every 1.7 s within 70 m). All from
  the seed, so a guest builds the same; nothing synced. **Item ids:** PEARL and REEF stand in as treasure and crab meat until economy (A) publishes
  pearl / reef ingredient ids; the chests' tables move to A's loot API then.
- Tests: t/swim/ breath_dive, out_of_breath, surface_safe, dive_loot. swimtest (not run during the batch): its "bobs back up" wait is 5 s now
  (letting go drifts up at 0.9 m/s). Render: tools/dev/diveshot.gd.

## 2026-10-19: deeper swimming, piece 2: the sea pushes back (rips, surf, storm swell, cold water)
- **The drift** (swim_state.gd `_sea`): your stroke (`hv`) is kept apart from the drift the sea carries you on (`_drift`, easing to
  the sea's push at DRIFT_EASE 3/s); velocity = stroke + drift. Under water the surf and the swell count DEEP_PUSH 0.35 (a rip all of
  it). Toasts once per swim: caught in a rip, the cold, a heavy swell. Child of the Sea gains `sea_resist` 0.5 (halves push, cold, swell).
- **Rips** (scripts/swim/sea_currents.gd, "SeaCurrents" under DiveSites, built with each island's dive spots): 3 off Brinehollow, 2 off a
  chain island, on beaches (the bottom 1.5-7 m down 30 m out, the shore map's exposure >= 0.35), 80 m from the dock and each other: a
  channel RIP_WIDTH 8 m from 4 m inshore of the waterline to RIP_LEN 50 m out, RIP_SPEED 2.6 m/s full across its middle half, dying away
  over its last 45% (a plain 3.2 m/s stroke barely gains, a 4.6 sprint beats it, swimming along the shore leaves it). Telltale (each
  screen its own, within 60 m of its middle + 25): 36 flecks of foam and churned sand a rip riding out at its speed (one MultiMesh a
  rip, made when first near, moved every 3rd frame: each fleck samples the wave), and spray thrown seaward every 0.3 s.
- **Surf** (scripts/swim/sea_push.gd, read from Ocean's shore maps and shore swell: nothing changes the waves): in the surf zone (shore
  map depth 0.15-3.2 m, faded by how turned the swell is) each breaking crest shoves you toward the beach (SURF_PUSH 4.2 m/s at a full
  crest, crest = shore swell / 0.45 m x amp_mult, squared) and a LONGSHORE 0.5 m/s current runs along the beach the way the swell runs; a
  crest over you splashes, plays wave_break and shakes the camera a touch.
- **Storm swell**: storm_k = (amp_mult - 1) / 0.8 + (local_swell - 1) / 1.1 (0..1.5): you're carried with the swell (STORM_DRIFT 0.9
  m/s) and shoved down each wave's face (the wave normal x STORM_SHOVE 4), and it costs STORM_DRAIN 3 stamina/s x storm_k.
- **Cold**: COLD_THEMES {"snow": 1} x KitStyle.around's weight (fading out 140 m past a snow island's coast): COLD_DRAIN 4.5 stamina/s
  (treading water there it falls instead of coming back); worn out, the cold only slows the float's regen (x 1 - 0.7 cold), so it never
  drowns you. The breath meter shows "FREEZING".
- Tests: t/swim/rip_current (carried out treading, barely gains against it, out of it along the shore, the drift stops), cold_water
  (a stand-in snow island: stamina falls treading where at home it rose, no health lost). The surf and the storm aren't on the stage
  (no shore maps or storm cells): swimtest/seatest will exercise them once run. Render: diveshot's `_rip`.

## 2026-10-19: deeper swimming, piece 3: sea threats (sharks, morays, jellyfish)
- **SeaThreats** (scripts/swim/sea_threats.gd, "SeaThreats" under DiveSites, per island with its dive spots): a shark at the
  wreck / ruin / a chest (Brinehollow 1, a chain island 1-2, size 0.95-1.25), a moray at each reef and wreck on 60%, a jellyfish
  field or two over unused open seabed. Creatures are named and built in a fixed order from the island's seed (Threats_<key>/Shark0,
  Moray3...), so every screen has the same ones and Creature's co-op (host runs, puppets elsewhere) applies.
- **Shark** (scripts/enemies/sea/shark.gd, a Creature that swims: `flying`, held DEEP 2.8 m under the waves, 0.6 m over the
  seabed it raycasts every 0.5 s): patrols a 13 m circle round home at CRUISE 3. Only a captain in the Swim state within LEASH 48 m
  of home is fair game. Noticed within NOTICE 22 m: the **fin_sting** (new sound) and a splash, it rises to FIN 0.5 m (the dorsal fin
  out of the water, a wake), and circles the swimmer at STALK 4.4 m/s closing 10 -> 5.5 m for STALK_FIRST 4.5 s (STALK_AGAIN 2.6 after
  a bite). Then the tell: square on, a red lane on the water along its line (FX.lane) for TELL 0.85 s, jaw open; the charge at
  CHARGE 10.5 m/s for 0.7 s with the bite armed (16, knockback 6, stagger 0.45), then it swims off AWAY 3.5 s. Hurt below half, it
  breaks off once. Out of the water you're left alone. 150 hp, xp 90, drops fish. Dead: belly-up to the surface, then sinks away.
  No knockdowns. Sleep: SeaThreats sets each shark's and moray's Creature LOD by the nearest captain every 0.4 s (awake within
  120 m, asleep past 140, hidden past 220), the way FaunaSpawner does the islands' wildlife (Creature's `net_idle` is its LOD, so
  ActorSleep, which writes net_idle, isn't used for them); asleep, the host sends no snapshots for them.
- **Moray** (scripts/enemies/sea/moray.gd): in a hole in a heap of stones, head out; a swimmer within REACH 3.6 m in front: TELL 0.65
  s (draws back, gapes, eyes lit, a burst of bubbles and a hiss), then a 1.8 m lunge (11), back in; COOL 2.4 s. Struck, it hides 5 s.
- **Jellyfish fields**: 18 jellies over an 11 m field, 0.4-1.6 m under the surface, drifting and pulsing by Weather.world_time (the
  same on every screen), one MultiMesh a field (a glowing bell + tentacles, brighter at night), moved every 0.08 s within 90 m. A
  jelly within 0.95 m of a captain's body (a line feet to head) stings on that captain's machine: 7 (less armour), `stung` 2 s (the
  stroke at x0.55), jelly_zap (new sound), a toast; 1.2 s before the next.
- Sounds (gen_psx_audio.py): fin_sting (1.7 s: a low bowed cluster swelling with a quickening tremolo, a struck note at 1.08 s;
  -15.2 LU, centroid 167 Hz), jelly_zap (0.42 s fizzing crackle and a falling whine; -17.3 LU, 76% in 1-2 kHz). In FX.SOUNDS.
- Tests: t/swim/shark_telegraph (noticed, fin out, 4 s of circling with nothing landing, the 0.85 s tell, then a bite and away; a
  captain ashore is left alone), jelly_sting (clear of the field nothing, a jelly stings and slows, not again at once). Renders:
  diveshot `_shark_fin`, `_shark_tell`; modelshot of the shark and moray.

## 2026-10-19: deeper swimming, piece 4: better strokes (burst, dolphin kick and leap, climbing out, the ladder)
- **Burst** (swim_state.gd): a tap of Shift while stroking: DASH_SPEED 7.2 m/s (x swim_pct) for DASH_TIME 0.32 s, DASH_COST 12
  stamina, again after DASH_CD 0.7 s (spray on top, bubbles under); held on, it's the sprint stroke as before (4.6). Enough to step
  out of a shark's charge lane.
- **Dolphin kick**: Shift held under water is DOLPHIN_SPEED 5.0 (was a 4.3 fast dive); humanoid.gd's dive pose goes to a dolphin
  kick past 3.8 m/s (legs together, one big beat, the body rippling). **Dolphin leap**: Space at a sprint on top with nothing to
  climb: up at LEAP_VY 8.2 under LEAP_GRAVITY 20 (feet ~0.15 m clear of the water at the top), carried on at LEAP_FWD 5.5, head
  first back in with a splash; LEAP_COST 10. Landing on something mid-leap (a rock, a jetty) ends the swim there.
- **Climbing out**: LEDGE_MAX 1.5 -> 2.2 m over the water, probed 0.5-1.25 m ahead (four probes, was three to 1.05); over LEDGE_HIGH
  1.4 it's the "high" mantle (climb_state.gd: the ledge keys x1.3 longer). While a ledge or a rock is in reach the HUD prompt says
  "Space: climb out" (checked every 0.15 s; the state clears only its own prompt).
- **The ladder**: swim into one (stroking toward it, within its reach) and you take hold, no key; Ladder.in_reach a little wider
  (0.9 -> 1.1 m to the side, 1.5 -> 1.8 m out); on any ladder or the rigging, Shift held with both hands free climbs x HURRY 1.45.
- Tests: t/swim/climb_out (the prompt facing a 1.6 m rock, Space hauls you up onto it, the prompt goes), strokes (the burst and its
  cost, the sprint after, the dolphin kick, the leap clear of the water and back in, swimming into the ship's ladder takes hold).
  swimtest's ladder and ledge steps (Space at both, no stroke toward the ladder) should hold; riggingtest's climb times may shorten
  if a test holds Shift on the rigging (none does now).

## 2026-10-19: deeper swimming: dive loot on the economy's items (v1.18 lane E, after merging main)
- dive_sites.gd: an oyster bed gives a `pearl` and 1-3 `oyster` (OYSTERS), a reef garden 1-3 `seaweed`, 0-2 `sea_urchin`, 0-1 `oyster`
  (REEF), rolled for each captain with `Loot.rng_for(key)` (lane A's per-captain seed: a crewmate's take differs, a reload doesn't
  reroll). Sunken chests, the wreck's and the ruin's coffer put in pearls too (0-1, 0-2, 1-3); LootBag's first open runs them through
  `Loot.chest` like every world chest (gold thinned per captain, pearls kept). The toast names what you got. Reef Salad's swim_pct
  already reaches the stroke, dive and burst speeds through `Progression.stat("swim_pct")` with the Swimming perks.
- Test: t/swim/dive_loot (chest gold now the per-captain roll, 1-40; the bed's pearl and oysters, once).
## 2026-10-19: the held map, piece 2: the map in the captain's hands (v1.18 lane C)
- **M** (`scripts/map/map_hold.gd`, MapHold, a child of the local captain made by GameManager.register_player): on foot (Idle,
  Move, Crouch, on the ground; at the helm you let go of the wheel) it puts the captain in **MapState**
  (`scripts/player_states/map_state.gd`, node "Map" in player.tscn): the weapon sheathes, the body plays `map_open` (0.34 s;
  MapPoses, `scripts/map/map_poses.gd`, upper body only, hooked into Humanoid._action_pose by its `map_` prefix, ActionSpecs
  entries) then holds `map_hold`; walking is SPEED 2.2 m/s the way the camera faces; M again plays `map_away` (0.2 s) and goes
  to Idle/Move; a jump, a dodge, falling or a hit (Player forces Stagger) ends it at once. The old full-screen chart (GameMenu
  "chart", its pause button, its M and C keys) is gone; chaintest, qoltest, seatest, uitest and the shot tools use the page.
- **The sheet**: for every captain whose body plays a `map_*` action (group "players": puppets' come over the wire as Humanoid
  events), MapHold keeps a "MapSheet" under their body: a 0.6 x 0.34 m bowed grid (map_parchment.gdshader: PSX snap, lit with a
  little glow for night, browned edges, the page tinted to yellowed stock) and two rolls with wooden knobs, placed every frame
  between the hands (the right roll in the right hand; `open` = how far apart the hands are, so the pose unrolls it), turned up to
  the reader's eyes (ours half way to the camera). Hidden, not freed, between actions. Ours shows the page; a crewmate's a sketch.
  No shadow, visibility range 60 m.
- **The page** is sea_chart.gd (now SIZE 448x256, plain parchment and an ink frame) in MapHold's SubViewport, drawn only while
  the map's out (UPDATE_DISABLED and the viewport's processing off otherwise). The camera framing puts one page pixel on about
  one of the PS1 grid's at the default 640x360 preset, so the 8 px Silkscreen reads.
- **The camera** (camera_rig.gd, its own "held map" block): `set_map(sheet)` / `set_map(null)`; over 0.25 s the rig's pivot moves
  onto the sheet, the arm shortens to 0.92 m at pitch -0.9, FOV 31, the yaw turns 0.165 (over the right side of the head) and the
  combat shoulder offset goes; MapHold hides the captain's head while the camera's anywhere near (it comes in where the head is).
  Nearly straight on, so the page reads level: an over-the-shoulder angle of 0.75 rad tilted the text 30 deg on the pixel grid.
- **The pen**: while it's up MapHold takes the mouse in `_input` (before the camera and the input buffer): it moves a nib on the
  page (sea_chart.pen), pushed past the page's side it turns the captain; LMB sets a mark, RMB takes one off, C clears yours, the
  wheel goes between the island and the chart (sea_chart.press).
- **MapMarks** (`scripts/map/map_marks.gd`): `MapMarks.put(id, world Vector3, kind, label)` / `clear(id)` / `has(id)`, kinds
  "quest" (red ring and star), "spot", "x"; this screen only (call it on every machine that should show it); drawn on the island
  page and the chart (pinned to the chart's edge). For lane D's tracked quest.
- Tests: `t/map/` held_map (out in under a second, the camera on it, the page drawing only then, slow walking, M away fast, a hit
  knocks it away), crew_sheet (a stand-in crewmate's sheet with the sketch, between their hands), map_marks. Render: heldmapshot
  (_unroll, _isle, _chart, _front).

## 2026-10-19: the held map, piece 3: one map that zooms (v1.18 lane C)
- **Zoom** (MapIsleView.ZOOMS 1, 2, 3.5 x the island's fit; `step_zoom`): the wheel goes in round our captain (the view follows
  them, kept on the island's square), out to the whole island, then out to the sea chart; in from the chart is the island again
  (sea_chart.press). The view glides there (GLIDE 12/s); the land, paths and fog redraw only while it moves or the fog changes.
- **The chart's coasts**: each standing island (MapIsles.all) gets a "Land_<key>" control behind the chart's ink
  (show_behind_parent, after the "Paper" child that now draws the paper and frame) drawing its heights through map_land.gdshader
  with `sea_clear` (the sea left as the chart's paper, flat land by height, an inked edge), sized and placed by the chart's own
  view; shown for Brinehollow, a chain island we've charted ("island:<name>") and the one we're at. Those get no circle
  (`_landed`). The heights texture has mipmaps now (a whole island in a few dozen chart pixels was speckle without them).
- Crewmates are dots in their crew colours on the chart (they were on the island page already).
- Gotcha: `return` in a canvas_item shader's fragment() doesn't compile, and the failed shader drew the raw RF heights in red.
- Tests: `t/map/` map_zoom (in x2 round the captain, x3.5 and no further, back out to the island, out to the chart, in again),
  chart_coast (charted: the coast at the island's place and size behind the ink; not charted: none; hidden on the island page).
  Render: heldmapshot now also _zoom, _sea (from the helm, M lets go of the wheel and opens the chart on deck), _chain and
  _chain_zoom (the chain's first island, walked up from the dock).
- Not done: a paper rustle for unrolling (the menu open/close sounds play); the map at the helm lets go of the wheel rather than
  being read while steering.

## 2026-10-19: v1.18 controls, piece 2: weapon loadouts (X)
- **X** (input `loadout`; Y on the web build, where X is crouch): a tap swaps to the next loadout, held 0.2 s it opens the loadout
  wheel (RadialWheel, scripts/ui/loadout_wheel.gd): a plank per slot with its style ("Twin daggers", from inspect_panel's STYLES),
  the slot number and weapons, the main weapon's icon, the one in use with the sun rim, a slot whose weapon isn't in the bag greyed,
  the third "Locked" until the Captain tree's **Quartermaster** (c_quarter: off Focus at 0 degrees, level 3, 2 points,
  effect `loadout_slots` +1). RadialWheel now refreshes plank icons on every open (a fixed list's icons change).
- **The model** (Player): `loadouts` (3 slots, each [main id, off id] with "" = fists / none, or [] never set up), `loadout_at`,
  `loadout_slots()` (LOADOUTS_FREE 2 + the stat). The slot in use is whatever you put in your hands: equip_weapon, unequip_weapon
  and set_offhand write it (`_loadout_note`), except while a loadout is applied or check_equipped drops a weapon that left the bag
  (selling, storing, dying keep the slot's ids, for when it's back). Taking up an empty slot sets it up with the hands you have.
  `swap_loadout(i)` is buffered like the quick item (QUICK_BUFFER 1 s: mid-swing it swaps once the combo window opens, ending the
  chain); with the weapon out it replays a quick "draw" (0.22 s) so the new blades come out of their sheaths; a toast names the setup.
  `Player.style_of(main, off)` is style() without holding the weapons.
- Saves: "loadouts" and "loadout_at" (`set_loadouts`; the hands are the truth for the slot in use, so a save from before loadouts
  loads with its hands as loadout 1). Co-op: nothing new on the wire: the hands ride in the snapshot (HumanoidSync), the clack goes
  through Net.fx. Per frame: one more wheel polling its key, and `_loadout_tick` returns at once unless a swap is waiting.
- Tests: t/player/loadout_swap. Render: `uishots <out> 1 0 items,loadouts` (the item and loadout wheels held open).

## 2026-10-19: v1.18 controls, piece 3: the crew's chat (Enter)
- **ChatBox** (scripts/ui/chat_box.gd, a CanvasLayer the local Player adds; class_name for `ChatBox.typing`): co-op only (`Net.active`;
  Enter does nothing solo). Enter (input `chat`, Enter and keypad Enter; not Alt+Enter) opens a LineEdit at the bottom left above the
  toast; Enter sends, Esc or an empty line puts it away. While it's open `typing` is set and the captain's input_locked (the state
  machine stops, the wheels and MapHold stay shut) and GameMenu._input returns early (so I, K, Esc typed don't open menus). The last
  LINES 6 lines sit above it, name in the captain's crew colour (Net.crew_color) and outlined text, fading after SHOW 10 s; all come
  back while you type. A crewmate's line ticks ("select"; tool runs are muted anyway).
- **Net** (the controls block): `Net.chat(text)` -> a guest asks the host (`_chat_req`, host only), the host strips it to CHAT_MAX 120
  and sends `everyone("_all_chat", [id, text])`; `_all_chat` names the sender from the roster (solo or self: the local captain) and
  emits `chat_line(id, who, text)`. Late joiners don't get the history.
- Per frame: ChatBox._process walks its rows (at most 6) to fade them; nothing else.
- Tests: t/ui/chat_line (solo Enter opens nothing; typing locks the captain and keeps I/T/Esc from menus and wheels; a sent line comes
  back with your name, a crewmate's with theirs; empty lines dropped; fade and back; six kept). Nettest should check a guest's line
  reaching the host and a third captain with the guest's name (not run: the push gate's job). Render: `uishots <out> 1 0 chat`.

## 2026-10-19: no auto-equip on pickup, shift+click quick-move (v1.18)
- The only auto-equip path was Player._on_item_added (a second sword/pistol went straight into the off hand, which also rewrote the loadout in use). Every arrival (pickup, chest, dropped bag, shop, quest/NPC gift, co-op bag take) goes through InventoryComponent.add_item, so removing that handler stops them all: it lands in the bag, hands and loadouts untouched. Kept: the weapon-trait banner (player_hud) and the quick item filling itself with the first food picked up. The starting kit and saves still equip.
- Shift+click (InventoryScreen.quick_move): a bag stack goes whole into the open chest (ship's storage, shared drop bags, loot bags: `_container.store`, the same call a drag makes, so co-op stays host-arbitrated); with no chest open it wears/holds it (food: becomes the quick item). Shift+click the quick slot clears it. A chest slot's plain click already took the whole stack, so shift there stays "take one". Shop: shift+click on a bag stack sells it whole (ShopScreen.quick_act).
- Tests: t/items/pickup_no_equip, t/items/shop_no_equip, t/ui/shift_click. Expect invtest / r7test / qoltest to notice (none run here); progtest and the wield/dagger suites set their off hands by hand.
- duel_win and progtest were red on main, both stale expectations: duel_win set health to 80 while calm, so the out-of-combat regen (1%/s once calm; a player starts calm) healed it past 80 before its checks (now `p.fought()` after the setup); progtest expected a second pistol to dual-wield on pickup, now it checks the pistol stays in the bag and `set_offhand` makes dual pistols.
- looptest gave items by `load("res://resources/items/<id>.tres")`, but the food economy items (rice, flour, salt, ...) and meals are made in code (Food.make_items, registered by ItemDB._load_all) and have no .tres: its galley check failed on a null item. Its give() now uses ItemDB.get_item. The game itself is fine (every game path that loads a .tres by id uses ids that have one: gold, treasure, rum, weapons).
## 2026-10-19: sailing downtime, piece 1: the lashed helm, the activity frame, training (v1.18 lane F)
- **The lashed helm** (scripts/ship/lashed_helm.gd, LashedHelm; Ship `lashed`, `lash_heading`): at the wheel the action wheel
  (place "helm", "At the helm") has one entry, Lash the helm (`Downtime.lash`): `Net.lash_helm(true, _heading)` and you step off.
  `Ship._read_helm` on the ship's owner (the host while nobody steers) puts the rudder on the course with a PD on the heading error
  (GAIN 3, DAMP 2.5 on the turn rate, at most MAX_RUDDER 0.6): knocked 0.4 rad off at a third of sail she's back inside ~5 s.
  The sails stay as set. A rope from the wheel's rim to its post shows it ("HelmLashing" on ship_model, no shadow, 60 m range).
  Taking the wheel casts it off (HelmState.enter); place() (moorings, summons) does too; Weather.storm > STORM 0.55 parts it
  (LashedHelm.watch, owner only, with a word to everyone aboard). An unmanned unlashed ship still just keeps sailing as before
  (she doesn't wander); what the lash adds is holding the course after seas, shores and whirlpools, and it is what lets you do
  downtime under sail.
- **Net** (one marked block by `_ship_anchor`): `lash_helm(on, heading, why)` -> `everyone("_all_lash")` (LashedHelm.apply on every
  screen; `why` toasts to captains aboard). `_world_state` "lash" for late joiners.
- **Downtime** (scripts/game/downtime.gd): KINDS (label, where, reward interval `every`, order), `register_wheel()` (static method
  callables; ActionWheel.ensure_builtins calls it in place of B's train placeholder, same id and order 20), `start/refuse`,
  `looked_after(ship)` (lashed, anchored, a crewmate at the wheel (`helm_other`), or furled and still), `danger(p)` (aboard: a storm,
  the helm come loose; anywhere: an enemy ship within SAIL_NEAR 160 m not sinking or struck, a Sea King up within 140 m, enemies in a
  fight within 30 m), `reward`, `pose_of`. Train: TRAIN_MASTERY 5 to the style's tree every 6 s (50 a minute; a fight lands 4 a hit
  plus a share of kills), ashore or aboard; a hybrid has nothing to train.
- **DowntimeState** (scripts/player_states/downtime_state.gd, "Downtime" in player.tscn): holds the loop, earns each interval,
  checks danger every 0.5 s, a drop in health (a hit that didn't stagger), and move/jump/F/dodge/attack get you up; roused, a toast,
  a bell and `dt_startle`.
- **DowntimePoses** (scripts/npc/downtime_poses.gd, `dt_*` in Humanoid._action_pose, ActionSpecs len = the blend): loops on the
  action's own clock (`_action["t"]`, so posebench shows them at t = u x 30): dt_train_blade (suburi, 2.2 s: raised overhead, a
  stepping vertical cut stopped level, back to guard; the katana/axe IK puts the left hand on), dt_train_fist (jab, cross, a bounce),
  dt_train_gun (dry-fire at three marks across the bow, a kick each; the gun hand never keyed), dt_startle.
- Per tick: Ship._read_helm while lashed (a few float ops on the owner); DowntimeState only while in it (a danger scan of three
  groups every 0.5 s). Nothing new per frame elsewhere.
- Tests: t/downtime/lash_helm, train, interrupt. Expect shiptest/seatest/looptest (ship.gd, helm_state.gd), t/ui/action_wheel (passes)
  and nettest (the new everyone call) to be touched. Renders: posebench `katana katana dt_train_blade:0.0733,0.0983,0.1173`.

## 2026-10-19: sailing downtime, piece 2: read, tinker, fish, sleep (v1.18 lane F)
- On the action wheel aboard (Downtime.KINDS, orders 40-70 round the galley's Cook at 30), each refused unless she's looked after:
  - **Read** (every 8 s): READ_XP 6 experience (45 a minute), a line of sea lore every LORE_EVERY 3 (LORE, 12 lines, in order),
    and at RECIPE_AT 20 intervals (~2.7 min of reading in all) the Captain's Feast recipe (Food.teach). Counted in
    `Progression.downtime["read_n"]` (saved with the captain).
  - **Tinker** (every 10 s): KIT_PER 90 s of "tuned kit" up to KIT_MAX 20 min: KIT on Progression.stat while `kit_left` > 0
    (extra_shots +1, reload_pct +0.15, damage_pct +0.04): the ammo and small gear upgrades as one timed buff, like a meal and beside
    it. `kit_left` ticks in Progression._physics_process (game time, local captain), saved as "kit"; _recalc_stats on and off.
  - **Fish** (every 20 s x (1 - fish_bite_pct)): at the rail of the nearer side, facing out (spot: half_width(z) - 0.62, z clamped
    to the main deck). A bite plays dt_fish_reel and a splash where the line meets the water (Net.fx); FISH_LOST 0.3 x (1 -
    fish_reel_pct) get away (+3 Fishing), the rest land from CATCH (fish 60, crab_meat 20, oyster 12, sea_urchin 8; the two rare ones
    x (1 + fish_rare_pct)), two at once on a fish_double roll, +8 Fishing. So every fish_* perk key now has a reader. About 2 catches a
    minute: a trickle next to real fishing later.
  - **Sleep** (every 2 s): lying in the cabin's bunk (spot on the mattress, head to the pillow), SLEEP_HEAL 5% of max health an
    interval, and solo the day's clock runs SLEEP_TIME 30x (Weather.world_offset; a night in ~20 s). In co-op the clock is the
    crew's, so only the healing (two captains can share the bunk: not guarded). Getting up puts you on the floor beside it.
- **DowntimeState**: Downtime.spot() takes you somewhere (eased over 0.35 s, then pinned ship-local with the hull's deck_delta like
  the helm; Downtime is in Player.NO_RIDE_STATES and counts as grounded), seat_of() sits you on a crate (the bench sit at 0.45);
  a one-off (the reel) goes back to the loop; leave_spot() on exit.
- **DowntimeProps** (scripts/npc/downtime_props.gd): what the loop holds, made from the body's current action on every screen
  (so a crewmate's puppet holds it too) and freed the frame the action changes: the crate (on the body root), the open book (on the
  torso, BOOK_AT), the mallet and lock (hands), the rod (right hand). No shadows. One node and 1-3 meshes while active.
- **Poses**: dt_read (crate, book at the chest, a page turned each 4 s loop), dt_tinker (three mallet taps, a turn of the lock,
  2.4 s), dt_fish (rod out, tip bobbing), dt_fish_reel (played 0.8 s), dt_sleep (face up, arms slack, a knee up, breathing).
- Per tick: Downtime.tick (sleep's clock), Progression's kit countdown while tuned. Per frame: DowntimeProps._process (one check)
  while an activity runs.
- Tests: t/downtime/read (XP, the recipe at RECIPE_AT, saved, the book goes), tinker (the kit: +1 shot, quicker reload, saved,
  wears off), fish (at the starboard rail facing out, a rod; bites build Fishing and land fish-tagged items; Patient Line shortens
  the wait), sleep (in the bunk, heals, the clock runs on, up beside the bunk). Renders: posebench with PB_SEAT=0.45
  `sword none dt_read:0.1333,dt_tinker:0.0896`, `sword none dt_fish:0.1,dt_sleep:0.1`.

## 2026-10-19: sailing downtime, piece 3: the Blender clip pipeline (v1.18 lane F)
- **Note:** BlenderBody (2026-10-16 above) was reverted the same day (0ac79b6): no tools/blender scripts, F4 or export were left,
  and Blender isn't installed on this machine. The pilot rebuilds only what clips need; the how-to is docs/blender_clips.md.
- **The rig** (`tools/dev/clip_rig.gd` -> `art/clips/rig.glb`; art/ is .gdignored): a Skeleton3D of the 14 Humanoid.JOINTS, each
  bone named after its joint at its rest (ClipPlayer.rests: a default captain with every joint's rotation and the neck zeroed, as
  the animator writes them), parents the joint hierarchy, and a stick body skinned to it so Blender shows something.
- **Blender side** (`tools/blender/`): `rig_setup.py` (import the rig, 30 fps, quaternion bones, a glTF collection exporter to
  art/clips/, save art/blender/clips.blend, never overwriting), `pilot_clip.py` (key a JSON clip on the rig: each joint Euler R
  becomes the pose bone's `Mr^-1 (C R C^-1) Mr`, Mr its world rest, C Godot's axes to Blender's; export the glb with the action).
  Both **untested** (no Blender here). `pilot_read.json` is the pilot's keys: reading, 7 keys over 4 s, a page turned at 2.9 s.
  `clip_rig.gd <glb> <keys.json>` is the stand-in: it keys the same JSON on the rig in Godot and writes the same kind of glb; the
  committed `art/clips/read.glb` came from it.
- **The import** (`tools/dev/clip_import.gd` -> `ClipPlayer.from_scene`): GLTFDocument reads the glb at runtime, its
  AnimationPlayer is sampled at 30 fps; each joint's global rotation is `bone_now * bone_rest^-1 * source_rest` (the reverse of
  BlenderBody's), then its rotation against its parent joint, relative to the same at rest, as a YXZ Euler. `natural_euler` picks
  the solution with less twist (a forearm bent past 90 degrees would otherwise come back as x = PI - x with y, z = PI: a flip
  under the animator's Euler blending) and keeps each angle continuous. An "upper" clip keeps only Humanoid.UPPER tracks; a "full"
  one records the pivot bone's movement as lift (scaled by the hip heights). Saved as a **BodyClip** (scripts/npc/body_clip.gd:
  fps, length, loop, mask, tracks {joint: PackedVector3Array}, lift; `sample(t)` lerps frames). (Gotcha: a PackedVector3Array
  pulled out of a Dictionary is a copy; append to a local and put it back.)
- **The player** (`scripts/npc/clip_player.gd`, ClipPlayer): Humanoid._action_pose's one-line hook sends `clip_<name>` actions to
  `ClipPlayer.pose`, which loads `assets/clips/<name>.tres` once (static cache), samples it on the action's own clock, eases in
  over BLEND 0.4 s and returns the clip's mask. So clips blend, mask, hold, loop and go to co-op screens like keyed actions.
- **The downtime loop from a clip:** Read is `clip_read` now (the keyed dt_read is gone): sat on the crate (seated legs from
  the locomotion, the clip's upper body), the book on the torso (DowntimeProps, ensured by ClipPlayer for names it lists).
- Per frame while a clip plays: one sample (8 lerps) instead of keyed pose maths. Nothing else.
- Tests: t/downtime/clip_play (the glb imports to the saved clip frame for frame; every joint as keyed at 2.9 s a loop on, and at
  1.2 s; the forearm stays a bend; no leg tracks; the held body follows it). read checks clip_read. Render: posebench with
  PB_SEAT=0.45 `sword none clip_read:0.1333,clip_read:0.23 three`.

## 2026-10-19: fishing, piece 1: one N wheel everywhere, the equipment slot, hiding equipment (v1.18)
- **The N wheel is one list** (ActionWheel): on your feet ashore, in town or aboard it shows every entry (camp 10, train 20, cook 30,
  read 40, tinker 50, fish 60, sleep 70); one that can't be done here is greyed with its reason under it (RadialWheel's sub line).
  `available` may now return a String: "" / true = can do, a reason = greyed, false = not on this wheel here (the lash entry away
  from the helm; the on-foot list at the helm or swimming). `why_not(id, p)`, `ready_for(p)`, `on_foot(p)`, `busy(p)` ("Not now"
  unless free, sat or already at an activity). Reasons: camp "Ashore, out of town" / "Out of town"; cook "At a galley or
  campfire" (cook_camp merged into cook: aboard the galley's portions, by a fire one); read/tinker "Aboard or at camp" (they now
  work by a camp's fire too); fish "At the water's edge" (ashore: Fishing.water_ahead finds sea 2.5-9 m ahead); sleep "In a bunk or
  at camp" (Sleep by the fire lies down where you stand); aboard, read/tinker/fish/sleep "Lash the helm or drop anchor first".
- **Train aboard needs no lashing** (Downtime.refuse and danger(p, kind) skip the loose-helm check for train); storms, sails, Sea
  Kings, enemies and blows still rouse you.
- **RadialWheel**: when neighbouring planks would overlap (7 entries with reason lines), the ring widens into an ellipse (`_fit_rx`,
  once per open, 8-unit steps) and the backing ring is drawn stretched to match. The other wheels keep their circle.
- **The equipment slot** (Gear.SLOTS "equipment", was "instrument"): instruments' gear_slot is "equipment"; its look keys are
  instrument, rod, equip_hidden (Gear.EQUIP_KEYS for the carried kinds). Old saves: `worn["instrument"]` loads into "equipment".
  Inventory tag EQUIP.
- **Visibility** (EquipmentComponent.hidden, item ids; Player.show_equipment(on)): a SHOW tick box under the equipment slot in the
  inventory. Hidden, the piece isn't drawn carried (Jam._show), still usable (played, it's in the hands). Gear.compose writes
  `equip_hidden` into the look, so crewmates (the look event) hide it the same. Saved as "equip_hidden".
- Tests: t/ui/wheel_same (same list ashore and aboard with the reasons, Fish at the water's edge, Train aboard under way unlashed and
  kept going, Read after lashing), t/items/equipment_slot (old save -> equipment, the SHOW box hides it, a crewmate's screen too,
  still playable, saved). Updated: t/ui/action_wheel, t/food/cook_wheel, t/downtime/interrupt (tinker is refused unlashed, train
  isn't), t/items/instruments. Render: `uishots <out> 1 0 actions,equipment`. Suites likely to notice: invtest (Gear.compose),
  jamtest / nettest jam mode (the slot's name), looptest (cook entry).
- Per frame/tick: nothing new (the wheel works its reasons out once per open).

## 2026-10-19: fishing, piece 2: rods, the minigame, the bobber on the waves (v1.18)
- **Rods** (scripts/fishing/rods.gd, Rods): equipment-slot gear, look key "rod" = the tier: driftwood (white, 7 m reach),
  bamboo (green, 9 m, bites x0.85, window x1.15, rare x1.25), steel-tipped (blue, 11 m, x0.72 / x1.3 / x1.6), master's (purple,
  14 m, x0.6 / x1.5 / x2.2); prices on the curve (20 / 45 / 120 / 330 G). Made in code in three sections (butt with the reel,
  mid, tip: FishRod bends them), the crank, and broken down for the back (and the icon). Three materials a rod (blank, leather,
  metal). Shops: Marlo always the driftwood rod, the bamboo in his pool; a fisher artisan's camp gets `pool` Rods.fisher_pool()
  size 1 (Shops' daily stock); a treasure merchant 30% of days a steel or master's rod (drawn after their other picks, so the
  rest of each day's stock is unchanged). The master's rod is only there.
- **The minigame** (Fishing, FishState "Fish" in player.tscn): with a rod and nothing to interact with, InteractionComponent
  prompts "Cast your line" when FishRod.cast_ready (Fishing.cast_spot: the farthest water ahead within the rod's reach, Ocean
  depth_at on the calm level > 0.4 m, checked every 0.25 s while a rod is carried) and F calls Player.fish(). Cast 1.1 s (the
  float leaves at 0.52), the wait (BITE 6-15 s x rod x (1 - fish_bite_pct), 0-3 nibbles first), the bite (window 0.75 s x rod x
  (1 + fish_reel_pct)): F or a click inside it reels (1.3 s) and lands (1.2 s, bagged at 0.85); before the bite it's a strike at
  nothing and the line comes in; after the window "It got away" and the line stays in for another bite. Moving, jumping, a dodge,
  a heavy or a blow ends it. Catches still Fishing.CATCH (piece 3 brings the fish table); Fishing mastery +10 landed, +3 lost.
- **The body** (FishPoses "rod_*" + FishRod): rod_cast (loaded back over the right shoulder with the weight back, an "out" snap
  onto the front foot, the follow-through low), rod_wait (held), rod_reel (strike up and back, hunched reeling, the lift),
  rod_strike, rod_land (the catch swung in to the left hand and held up, the head turned to it). FishRod (the Player's child
  "Rod", every screen) holds the rod in torso space on the action's own clock (KEYS: grip, pitch, yaw, bend, crank hand, catch
  hand) and puts both hands on it by IK (right on the fore grip, left on the butt, on the crank while reeling, on the catch when
  landed), Jam's pattern. The bite bends the tip down and trembles it. The old idle downtime fishing (dt_fish poses, the props
  rod, Downtime._catch) is gone; the wheel's Fish starts this (aboard at the rail first; tells you to equip a rod).
- **The bobber and line** (FishRod): flies on an arc, floats at Ocean.get_wave_height with a bob, twitches on nibbles, goes
  under on the bite (splash, bubbles, water ring), skims in on the reel; cast from a deck it keeps to the ship's frame (trolling,
  no lashing needed). The line an ImmediateMesh strip of 10 segments with sag. The catch hangs on the line, then in the hand.
- **Co-op**: no new RPCs. FishRod sends Net.event (throw, nibble, bite, escape, reel, land, stop) from the captain's machine;
  the puppet's Rod plays the same; body actions mirror as usual. The catch is the local captain's.
- **Sounds** (gen_psx_audio.py, FX.SOUNDS): fish_cast (whip + spool ticks, -18), fish_plop (-20), fish_bite (bloop + bubbles,
  -15), fish_reel (ratchet + line hiss, -19), fish_catch (water off it + a two-note chime, -17), played by FishRod on every screen.
- Tests: t/fishing/ cast_land, reel_timing, rod_shops, wheel_fish (t/downtime/fish removed). Render: `fishshot <out>` (the light
  stage has no sea surface drawn: it lays a flat one; it closes the character creator a windowed run opens).
- Per frame: FishRod._process per captain carrying a rod (a look read and an action-name check; while fishing: the rod keys, 4
  part transforms, two IK reaches, the line's 11 vertices and one wave sample); the local captain's cast check every 0.25 s (up
  to 6 rays) only while a rod is carried and free. Nothing per tick.

## 2026-10-19: fishing, piece 3: bait, the fish table, rarities, Fishing's perks, the legend recipe (v1.18)
- **The fish table** (scripts/fishing/fish_table.gd, FishTable): 21 catches, common to legendary (sardine, mackerel, bream;
  snapper, flounder, sea bass, parrotfish (jungle), sand grouper (desert), ice cod (snow), sea trout (forest); tuna, swordfish,
  moonfish, lionfish (jungle); ghost ray, golden sea carp; king marlin, abyss eel), plus crab, oysters and urchins (lane A's
  items). Each from some waters under the float (shore: Ocean depth_at < 4 m; sea; deep: nothing in reach or > 30 m), some only
  off a theme's coast (KitStyle.around, loaded not named), some only by day or night (19:00-5:30). New fish are LOOT items tagged
  "fish" (any galley recipe takes them), their rarity their tier (worth x1.6 a tier), icons drawn from FishModels' meshes. The
  roll: WEIGHT [100, 40, 13, 3.5, 0.6] x rare^rarity, rare = rod x bait x (1 + fish_rare_pct), the legendary x (1 + fish_legend);
  a stream seeded off the global rng (same seed, same fish). Mastery by rarity: 10/16/26/40/80.
- **The catch shows** its name over the captain in its rarity's colour (Net.fx float_text, a glint from epic up) and a toast
  "Caught: Red Snapper (Uncommon)". A big catch (> 0.7 m) stays hanging off the rod instead of the hand.
- **Bait** (scripts/fishing/bait.gd, Bait, data only): worms (bites x0.8), cut bait (x0.75, rare x1.05), shrimp (x0.9, rare
  x1.35), glow (x0.9, rare x1.55, x1.4 more by night). InventoryComponent.bait (saved) is the pick: a click on a bait in the bag
  ("ON THE HOOK", marked B); with none picked or none left, the best carried (Bait.ORDER); none is a bare hook. One is used per
  catch landed (Bait Saver keeps it 30%). Sold: Marlo's worms (staple) and shrimp (pool), Ida's worms (pool), a fisher's camp
  (its pool now rods and baits, 2 a day). Cut bait on the action wheel (order 65; Fishing.cut_bait): an urchin and kelp -> 3
  glow, a crab -> 3 shrimp, a fish -> 4 cut bait; greyed "Needs a crab, a fish, or an urchin and kelp".
- **Fishing's perks** (skill_tree, life tree): Patient Line 2 (bites 20% sooner), Steady Hands 5 (window +25%), Bait Saver 8
  (fish_bait_save 0.3, new), Sea Lore 10 (rare +20%, was 15), Old Salt 15 (double 15%), Master Angler 20 (fish_legend 1.0:
  legendaries twice as often, window +15%, new). All read in Fishing.
- **The legend recipe**: the first legendary landed teaches Sea Legend's Platter (Food.MEALS "sea_legend": 2 fish, greens,
  spice; +30 max hp, +6% damage, +5% crit, +10% swim, 25 min; the stew's icon for now: MEALS entries may name an "icon").
- **Gotcha**: ItemDB names FishTable and Bait (make_items), and test scripts name ItemDB before the autoloads exist, so those two
  must not name a class that touches autoloads (Bait's wheel entry lives in Fishing; FishTable loads KitStyle by path).
- Tests: t/fishing/fish_table, bait_perks; cast_land/reel_timing/wheel_fish count the table's catches; rod_shops reads the
  fisher's rods and baits and Marlo's worms; t/ui/action_wheel and wheel_same list cut_bait. Render: `fishshot` writes
  `<out>_catch_icons.png`. Suites likely to notice: looptest/qoltest (Marlo's and Ida's stock), progtest/techtest (the fishing
  perks' count), the galley screen's nine recipes.
- Per frame/tick: nothing new (the roll and the bait are on the bite and the landing).
## The web roadmap timeline (2026-10-19, docs/v1_19_plan.md)
- `web/site/roadmap/` is now an interactive timeline: `index.html` + `roadmap.css` + `roadmap.js` (plain JS, no build)
  read `roadmap.json`, one entry per version (26: v0.1, v1.0-1.17, 1.18 being built, 1.19-1.22, "later", 2.0).
  `"here"` names the "you are here" version. Statuses: shipped / building / planned / goal; unbuilt cards are dashed,
  faded and stamped. Shipped entries carry `added`, planned ones `plan` (`[title, text]` pairs), plus `img`, `shots`,
  `clip`, `news`, `github`, `gap` (a label on the line before it, "Half a year later").
- Wide screens: one horizontal track (cards alternate above/below the line), an eased scroll position driven by the
  wheel (vertical wheel scrolls it sideways, handing back to the page at either end), mouse drag with a little
  momentum (a drag never opens a card), touch swipe natively, arrow keys card to card, jump buttons, a two-speed
  parallax sea behind. <= 640px: the line turns vertical and the page scrolls; it doesn't jump to the marker on load.
  A card opens a `<dialog>` (pictures, clip with Play, the list, post / release notes / GitHub links, prev/next and
  arrow keys); `#v1-10` deep-links a card. `prefers-reduced-motion` stops the bobbing, pulses and glides.
- Pictures: v0.1-v1.6 use the v1.5/v1.6-era README shots copied from docs/media into `web/site/img/early/` (+ -640),
  later ones the site's current shots; planned cards reuse current shots, faded. Text uses Driftwake's own names
  (docs/originality_plan.md); the page drops the old fan-game credit line in its footer.
- Each release: the step in docs/release_v1_18.md (move `here`, fill the card). Site-wide: a Home link before News.
## 2026-10-19: the 1.18 perf pass (short: inside the gate's allowance, hitches first)
- **Where it stood** (min-spec PC itself, 5600G + 3080, 13:00 clear): the gate confirmed back to back against the baseline's
  commit 8e7fe77 (v1.14) on this PC: ALL frame 13.59 -> 16.50 ms (+21%), frame1t 14.25 -> 16.80 (+18%), yard frame1t +35%.
  Scripts per frame were the same as v1.16's (bench_compare against v1.16's gate run here); the extra was townsfolk rigs and
  routines (BrinehollowLife), moored hulls, sea spray. Chain islands' worst build step: 240 ms (encounters), 262 ms (fauna).
- **Rigs** (humanoid.gd): a `lod` rig (villagers, grunts out of a fight, crews) poses every frame within 20 m of the camera
  (was 30), every 2nd to 40 (was 60), every 3rd to 80 (was 120), every 6th past; its hair and cloth swing within SIMS_R_LOD 20 m
  (was 30; the player's own SIMS_R 30) and its feet are set on the ground within IK_R_LOD 25 m (was 40). The spring chains run on
  a fixed step, so their cost goes with the range, not the pose rate.
- **Routines:** a plain NPC (vendors, wanderers) thinks every 4th frame past 25 m from the captain, with the time since
  (npc.gd FAR_R / FAR_EVERY); BrinehollowFolk every frame within 15 m (was 20), every 2nd to 35 (was 45), every 4th past.
- **Moored hulls** ride for a captain within NEAR, or the ship only while she's under way (speed > 0.5): moored in the
  harbour she kept every hull within 80 m of her riding with nobody near.
- **Ambience** mixed every other frame with the time since; **SkyBirds** seen past 140 m flown every 2nd frame (under a
  pixel a frame there); **SeaSpray**'s drifting foam reads its wave height every other frame, half the patches at a time.
- **Island build hitches:** an encounter's people (IslandEncounters._person) take their look from the encounter's own seed
  (`person_look(e, k, style)`: the k-th person; the duelist a crew look), so IslandLife.plan builds their bodies on the worker
  with the villagers' (Humanoid.stock); bodies nobody takes (no place found, the island let go first) are freed
  (`unstock_rest`). Encounters' main-thread time 112-183 -> 4 ms. FaunaSpawner puts the creatures in over SPAWN_STEPS 10
  steps (was 3: ~24 models built in one frame). The build log names the worst step (`the most N ms (<piece> #<step>)`,
  GenIsland.worst_step). Worst step now ~160-170 ms (Tambor: a fauna step; Whitecap: boss): the next ones to split.
- **Result** (full bench back to back with main, calib 24.63 / 24.66, no other Godots): ALL frame 16.33 -> 14.96 ms (-8%),
  frame1t 16.80 -> 15.59, p95 22.64 -> 19.21 (-15%); frame1t beach 16.98 -> 15.14, plaza 19.03 -> 18.01, market 18.60 -> 16.67,
  quay 16.07 -> 15.44, dock 15.17 -> 14.74, den 15.91 -> 14.56, yard 17.05 -> 15.55, aboard 15.60 -> 14.63; draws unchanged.
  perf_gate (13:00, 1 run, confirmed back to back against 8e7fe77): mean frame +8%, frame1t +7% (pass); plaza frame1t +35.2%
  (the line is 35; the reference's own plaza read 14.93 and 14.08 in two confirms an hour apart); ticks 0.94 over 0.8, which
  this PC can't meet at ~15 ms frames (the baseline's commit itself runs 0.87 here: the line is the laptop's).
- **CROWD stays off** (brinehollow_cast.gd): on, after these fixes, gate mode back to back: ALL frame 15.27 -> 15.86 ms (+4%),
  plaza 17.58 -> 19.65, market 17.28 -> 19.98 (+16%), draws +76; the folk's rigs and routines +0.34 ms. Against the gate's
  confirm run that's +16.7% mean frame, over the 15% line. It wants the townsfolk cheaper first (a far rig LOD for folk, or
  fewer sides on their bodies) or the gate's allowance.
- **Bench artifact** (not changed in a batch): bench_brinehollow's first base sample of each stop carries the settle phase's
  screenshot save (~60-70 ms), which is the `worst` column at every stop and ~+0.2 ms on each stop's base mean (both sides).
- **Tested by** t/ship/moored_hulls (a hull beside the moored ship holds still, rides once she's under way), t/quests/
  encounter_rolls (every encounter person's body built ahead, none left waiting), t/world/actor_sleep, perftest.

## 2026-10-19: dungeontest and harbourtest red before 1.18
- **dungeontest**: the suite re-seeds the chain mid-run, so island key `isle0` named a different-sized island while GameManager.fog still held the old island's grid; MapFog.look indexed past it (map_fog.gd:37). MapFog.grid now treats a grid of the wrong size as no fog and apply starts a fresh one instead of resizing the stale one. Its "reaches you across the floor" wait is in physics ticks now (it failed once under load, passed alone).
- **harbourtest**: not stuck, just over the runner's 330 s: 10 full island builds, then 8 more prepares for the node/kind checks (each ~8-13 s under load). Those last two checks are now `harbourkindstest` (~160 s); harbourtest is ~210 s. No budget raised, no check dropped.
- **Tested by** t/map/fog_regrown (a stale grid under the key), dungeontest, harbourtest, harbourkindstest.

## 2026-10-19: bugtest and musictest red before 1.18 (stale tests, no game change)
- **bugtest "coins fly to the player"**: the economy (Loot.kill_gold, x0.45, never none) makes a small bug drop one coin where it dropped 1-2; a coin lands up to ~3 m from the bug and the captain stood 1.5 m off, so about one coin in four sat outside CoinPickup.MAGNET_RANGE and the standing captain never walked to it. The test now lets the coins land, steps the captain up to a coin still on the ground (the range is meant to be walked into), then checks the gold.
- **musictest "carried on from the same moment"**: the night track's position (audio, real time) was compared with game time `t`; under load a clamped frame makes game time fall behind the audio clock (1.5 s of ticks, 2.8 s of audio). The in-step and bar-resume checks measure real time (`wall()`) now.
## 2026-10-19: nettest red before 1.18 (host "stalled", enemies "missing", dropped guests)
- **"all N host enemies exist here (missing 2-4)"**: a race in the test, not a sync bug. DiveSites builds a chain island's sharks and eels on its half-second poll after the island stands (0.2 s after chain_ready measured); the report was asked in between. netclient step 3 now also waits for DiveSites' sites, and the check lists the missing keys.
- **host "stalled (no output for 150 s)"**: nethost prints nothing while the client runs its steps, and the run is now longer than 150 s; it prints "HOST up N s" every 30 s. The fruit-trade check passed in every run (the item lookup and pickup are fine).
- **Guests dropped mid-run (intermittent, heavy load)**: both Godots block 20-55 s building worlds at the start; ENet's round-trip estimate balloons, a packet lost meanwhile waits a minute to retransmit and the peer is timed out (the guest only hears after its own 30-60 s timeout). Net now sends snapshots, pings, events and fx only to captains whose world is up (`_targets()`), and a peer has long ENet timeouts (60/300 s) only until its world is up (`_settled`), then 30/60 s. Left open: the startup freeze length itself, and a drop under very heavy machine load can still happen.

## 2026-10-20: site art for 1.18 "Charted Waters" (render tools only)
- **siteshot.gd** new shots: `fishing` (Brinehollow's first side pier at 17.4, a driftwood rod so the float lands ~7 m out;
  `along` = from out past the float looking back at the captain and the harbour, the bite forced via FishState._bite_at),
  `dive` (a forced duck dive in from the open sea over the reef, the dolphin kick from below; then pinned over the reef,
  chest and oysters), `shark` (Shark0 at Brinehollow's wreck noticing a swimmer, the fin out ~2.6 s into NOTICE),
  `galley` (the cabin by night, the captain's "reach" gesture), `heldmap` (MAIN island, dock-to-village charted from 24 m
  up, the game's camera on the page: `_game_cam`/`own_cam`), `camp` (Camp.place + sit_ground on a beach at 18.3),
  `snow` / `desert` (`_seed_theme`: first chain seed from 1 opening on it: snow 3, desert 2). Clips: `clip_fish` (cut to a
  close-up for the landing), `clip_dive`, `clip_map`, `clip_loadout` (the loadout wheel shows with the HUD hidden: its own
  CanvasLayer). Every still also saves `<name>-640.jpg`; `_clip` waits two frames first (the first frame showed the old
  camera / grid). Shared helpers: `_beach`, `_dive_at_sea`, `_duck_dive`, `_fish_stand`, `_fish_view`, `_line_out`.
- Gotchas: Fishing, Ship and Camp touch autoloads, so the tool loads them by path (`_fishing()`); a duck dive started by
  `Input.action_press("dodge")` from _process can miss the physics tick's just-pressed (set SwimState._diving by hand);
  the reef's kelp colliders stand ~4 m tall (dive down first, then in); seed 11's first island is snow now, not jungle.
- **site_gifs.ps1**: `-Poster name=frame`, `-Stills site=shot,...` (copies a still and its 640 into web/site/img).
- Images: web/site/img fishing, dive, heldmap, galley, shark, camp, snowvillage (+ -640), desert replaced (golden medina);
  snow.jpg kept (the v1.16 post's caption names its castle); clips fish, dive (10 fps, 80 colours), map (12 fps, 128),
  loadout. Tested: renders read one by one (no tests: tools only).
- Seen in the game, not fixed here: the campfire's flame particles (Props.campfire) render as tall pale peach blocks on
  the PS1 grid at dusk; camp.jpg shows it.

## 2026-10-20: the royal capital, piece 1: placement, name, debug jump, the shell (docs/capital_plan.md)
- **Where:** the chain's first city (layer 3, `Chain.CITY_LAYERS[0]`) is the capital: `node["capital"] = true`, role still
  "city". Every path already reached layer 3 after exactly two islands (layers 1-2 are one-then-another or a fork that
  holds for the pair and rejoins), so CITY_LAYERS is unchanged. `node["face"]` = the unit vector to the layer before's
  islands (the harbour faces the way you come in). The name (`Chain.capital_name`: Port Solenne / Highcrown / Meridian)
  is `hash([chain seed, "capital"])`, apart from the chain's rng: the base name and city word are still drawn, so every
  other island, position, theme and beast is what it was. `Chain.capital_id()`, `describe` says "The royal capital".
- **Old saves mid-chain:** the chain is the same; the layer-3 node now builds as CapitalIsland. A save made there on its
  old generated island: the last build step moves a ship left on what's land now to the berth and a captain inside the
  city's stone to the quay (`_in_stone`); opened chests and quests of that island (isle<id>_ keys) just have nothing to
  point at. Saves further on are untouched.
- **CapitalIsland extends GenIsland** (WorldGenerator picks it on `node["capital"]`), overriding prepare/finish_steps/
  hv/walk_height/mooring/undergrowth_at (0: the thicket check crashed on an empty grid); provides `sites` dock/dock_end/
  village, `dock_dir`, `village_plan` {c, plaza_r 92, buildings along the quay} for Music.in_village, `theme` "capital"
  (`KitStyle.of("capital")` = CapitalStyle.STYLE over Brinehollow's; not an IslandThemes theme, so SkyBirds now asks a
  theme's flocks only when an island has crowns). Everything is in CapitalPlan's frame (x along the harbour, +z to sea)
  under the "City" node turned by `yaw`; the terrain grid stays island-aligned (`to_city`/`from_city`).
- **CapitalPlan** (data): heights `base(z)` quay 2.0 -> plaza 5.0 -> avenue 8.0, the palace hill (42 m, plateau r 50),
  the arena flat; `terrain()` drops FLOOR_DROP under the walkable floors (FLOORS: quay, gate, market street, plaza,
  avenue, arena street, alley, yard, postern: tiling rects), the quay coast to the -8 m basin, the shore under the sea
  wall, a mound under the moles. `lots()`: blocks of 26 x 22 m with 4 m lanes out from the street, split into 6-10 m
  plots back to back (+1 storey toward the harbour), KEEP rects round the plaza/avenue/arena street are "keep" lots
  (piece 2 builds those), `openings()` = every gap a floor's edge opens onto, each closed by a wall with a shut door.
- **CapitalShell** (a worker, in prepare: PSXMat locks its cache; meshes committed there too): quay + moles + lighthouse +
  harbour fort, harbour wall + sea gate + postern + cross walls, sea wall (160 pieces, towers every 11), palace grounds wall
  + its gate (portcullis) + hill road + cypresses, the palace, the arena's outer walls (40 arched bays, two tiers,
  seating, sand, a portcullis on the street's bay), the bell tower and the temple dome, houses in 72 m chunks
  (facade texture: a 3 m bay x 3 m storey a tile, `capital_facade_a/_b` + glow masks), barriers, floors. Each piece one
  mesh after `fold_tints`. Colliders as data, made in the step: walls, towers, front and keep lots only (the backdrop is
  sealed off by them and the barriers).
- **Gotcha (Jolt):** one ConcavePolygonShape3D for all the floors (~9k triangles over 300 m) lost rays over half the quay
  (bodies still stood on it, shape queries hit it): the floors are cut into shapes of 16 columns each.
- **Windows** glow only at night: CapitalIsland sets the two facade materials' emission every 2 s from Weather.night.
- **Debug:** Alt+F10 (`Player.debug_to_capital`, host): the crew arrives at the capital, and once it stands the ship is at
  the berth and you on the quay. Ctrl+F10 also works on it (the generic dock_end).
- **Cost:** built on the worker ~3.7 s; on the main thread ~130 ms over ~50 frames, worst step 8 ms (a ground collider).
  Standing: 33 mesh instances, ~200 surfaces (houses ~5 a chunk), 230k triangles (129k of it the terrain grid, as any
  chain island), ~780 box/cylinder shapes. Nothing runs per frame except the 2 s window check.
- **Tested by** t/capital/placement (8 seeds: one capital on layer 3, every path two islands then it, the face, the name
  stable/one of three/all three over seeds), t/capital/shell (the dock, a deep clear berth, every floor solid underfoot,
  every floor's edge closed, the palace up on its hill, the pieces stand, its style), t/capital/debug_jump. Renders:
  `capitalshot.gd`.

## 2026-10-21: the royal capital, pieces 2-3: the core district and its life (docs/capital_plan.md)
- **CapitalDistrict** (built on the worker after the shell, merged a mesh an area, fold_tints): every lot that fronts a
  floor or stands on KEEP ground is a town house (`townhouse`: a taller ground floor, a shopfront with window, awning,
  wares and a hanging sign by shop kind, a recessed door up two steps, pilasters, a string course, balconies on some,
  the facade storeys and roof over; the slum's stained and shabby); the shell now leaves those lots to it. The plaza's
  own buildings (CapitalPlan.SPECIAL, no lots under them): the Crown and Compass (an arcade and loggia with tables, its
  door lanterns and sign), Quayle's Curios (a counter of rarities), the guild hall and the shut counting house
  (porticoes, steps from the plaza's level, a portcullis on the bank's door). The plaza: fountain (basin, two tiers,
  a crowned figure, spouts), eight Buildings.stall in a broken ring, a cobbled ring, plane trees, four lamps, bunting,
  the notice board. The street: barrows, wall lanterns, bunting; the sea gate's banners. The quay: cargo stacks, two
  cranes, the fish market under a tiled roof, nets, the harbourmaster's booth, lamps, boats tied up. The avenue:
  statues and cypresses, two lamps; the arena street's posters and the crier's booth. The slum: washing lines over
  the alley and the yard, five lean-to shacks, a fire in a barrel, a broken cart, junk. Existing builders' nodes (stalls,
  crates, cranes, the board, tables) are `absorb`ed: meshes merged, colliders kept as shapes, the node freed.
- **Its output** besides the pieces: `spots` (where each person stands, frame), `doors` (the town houses' doorsteps),
  `lights` (14: plaza 4, street 2, quay 3, avenue 2, the inn's door, the yard's fire, the lighthouse all day; NightLights
  made in the "lamps" step). Door paints are 4 (a door leaf keeps its picture exact, so each paint is a surface).
  The shop windows and fanlights share one window material whose glow follows Weather.night with the facades'.
- **CapitalLife** (scripts/island/capital_life.gd; a node under the island, island space): 22 named people at their
  spots with their own lines, looks from CapitalStyle's folk by name (guards in blue frock coats and cavaliers);
  shops in Shops.extra by `save_key("capital_*")`: Quayle's Curios (treasure, tier max(island +1, 3): the islands'
  merchants are maxi(t, 2)), Hesper's Greengrocery, Gilly's Fish, Lorne & Daughters (city cuts), the inn's cook. The
  inn's Rest at its door (GameManager.rest), the notice board's Read, four seat benches by the fountain. Quests on
  KitQuests: the Watch's notice "Clear out Gallows Row" (board, reported to Sergeant Brannoch; clear = the toughs'
  alive_count 0), Ambrose Pell's "Sealed with wax" (deliver the guild's ledger to Tobin Rook on the quay), Mirela's
  "My mother's locket" (lost, in the yard among the toughs). The toughs: a GruntCamp "Ruffians" (4: crew looks
  restyled, one rifle, warm start, respawn 900 s) round the fire; its nav zone from `CapitalIsland.nav_faces` (the
  floors there and every solid box as faces: the city's colliders aren't under one node to parse).
- **CapitalCrowd** (under City): 56 walkers on 11 lanes (street, gate, quay, avenue, arena street, the plaza's edges and
  a ring round the fountain), placed from Ocean.clock (no messages in co-op). Drawn as two MultiMeshes of one figure
  (the step's two strides, a hidden one scaled to nothing; tinted by instance colour, which psx_lit multiplies in;
  no shadow, 180 m range), transforms rewritten every 0.1 s. The nearest walker of each of 8 looks within 15 m of the
  camera is a real Humanoid from a pool of 8 prebuilt bodies (shown, process on; others hidden, process off). Asleep
  (nothing runs or draws) with the camera 260 m off the district.
- **Gotcha:** `(arr[i] as PackedFloat32Array).resize()` resizes a copy (packed arrays are values): the crowd's buffers
  are built as locals.
- **Cost:** district ~0.8 s and the 30 bodies ~3 s on the worker; on the main thread the new steps are a few ms each.
  City surfaces (crowd bodies apart) 363 (t/capital/district caps it at 420); 30 humanoids (22 people, 8 crowd bodies
  of which only the ones by the camera are shown). Per frame: the crowd's 8 bodies' positions; every 0.1 s 56 walkers'
  transforms (two buffers); every 0.5 s the sleep check; NPCs and grunts as everywhere (ActorSleep, Humanoid.lod).
  Not benched (the lead benches).
- **Map:** `places` for the palace gate, the arena, the lighthouse, Gallows Row and the inn; the town label is the city's
  name (map_isles).
- **Walled off for 1.20:** the palace (gate shut, guarded), the arena (portcullis), the counting house, every side lane
  (barrier walls with shut doors), the districts behind the fronts (massing).
- **Tested by** t/capital/district (doors on floors and clear, the pieces, every spot on the ground, the lights within
  budget and lit only at night but the lighthouse, surfaces under 420) and t/capital/life (everyone there, the curio
  dealer's tier and his stock steady for a day and turning over, the shops, the rest heals, three quests, taking the
  notice, the toughs muster host-side in the yard, the crowd on the floors and where the clock says, no crowd bodies
  with the camera far). Renders: capitalshot (plaza, street, crowd, inn, halls, quay, slum, yard), by day and 21:30.

## 2026-10-20: 1.18.1 fix pass
- nettest chain: the chain's third stop is the royal capital, which has no camp/boss/sites of a generated island, so the
  host's chain report threw (and the guest's reply lacked "ready"). nettest_node's chain_report has a capital_report
  (the toughs' camp, the people under CapitalLife, quests, five shops' names and stock, the crowd's places at 10:00)
  and netclient's same_isles checks the guest builds the same of each (and the toughs are puppets).
- guntest: stale, not the game. The captain's 99999 max health regenerates 1% a second once 8 s have passed since a
  blow; the shove step came after the third rifle shot's wait, so the 12 hp lost earlier was healed back (hp lost -12)
  and the shove's 4.8 was swallowed by the cap. The step now holds the captain "in a fight" (_since_hit = 0).

## 2026-10-20: controller support (Xbox pad), pieces 1-5 (branch claude/controller-support-612108)
- Layout (Zach's): A jump, B dodge, X interact, Y ready/sheathe, RB light, RT heavy (hold: charge), LT parry/block,
  L3 sprint latch, R3 sneak, d-pad up item / left loadout / down action wheel / right sea chart, View inventory, Menu
  pause. Hold LB: X/Y/B/A skills 1-4, RB skill 5, RT ultimate, d-pad lantern / summon / log pose / emotes, R3 ping,
  L3 Zoan shift, View skill map. Unbound: chat, zoom.
- Pad autoload (scripts/input/pad.gd, right after Settings): base pad events live in project.godot; LB swaps the
  InputMap (Input marks actions pressed at parse time, before any node, so a button on two actions would press both).
  A held input is let go on a swap. Pad.pressed(event, action) counts a trigger/stick once per press (their motion
  events repeat while held: the input buffer chained heavies). L3 latch ends when the stick centres 0.15 s or stamina
  runs out; player.gd's Shift-up sprint release skips it. look_* actions on the right stick; Pad.look() = radial
  deadzone + squared curve, 3.5/2.4 rad/s at sensitivity 1, real time (hit-stop doesn't slow it).
- Look in the camera rig (_process), HelmState/CannonState.update (cannon at half rate). The rig holds still while a
  wheel, the held map, the showcase or a menu has the stick. RadialWheel: the stick points (pick stays), A picks, B
  cancels, face buttons eaten while open. Dialogue choices step on the stick's edge.
- Glyphs (class_name): button names for the device in use (Pad.using_pad, Pad.device_changed). Swim, helm, cannon,
  ship jobs, revive, HUD key cap, controls page. Menu hints (LMB/RMB) wait for the menu phase.
- PadSkills (scripts/ui/pad_skills.gd, HUD bottom left): the skills by LB button as words, dim, bright with LB held.
  (A drawn pad with labels was tried first: too large and distracting, Zach.)
- Settings: controls.pad_look_sensitivity / pad_look_deadzone / pad_move_deadzone, gameplay.pad_skills.
- Tests: t/input (7). Render: padshot.
- Merged with main after v1.18.2 (2026-10-21): the round wheels keep the stick/A/B (the mouse and stick share
  _aim/_confirm/_cancel); the new skill-tree card's key is Glyphs' (LB+VIEW on a pad). The skills menu already moves
  on ui_* (d-pad, A) and its LB/RB tabs read raw buttons, which Pad's layer leaves alone; its hints stay keyboard
  (menu phase).
## 2026-10-20: the bench refreshed for the v1.19 perf session (step 1; tools only)
- What: `tools/dev/bench_brinehollow.gd` keeps v1.14's eight stops (group `old`, unchanged spots) and adds eight
  (`new`): terrace (shrine terrace, UP_X,11), farm (FARM + (4.5,-1.5)), fight (6 m inland of the smugglers' fire, its
  five grunts alerted, the captain's health topped up each frame), sea and storm (the sloop placed on open water
  found by `_deep_enough` 750+ m out from Brinehollow, away from Redtide, anchor up and full sail, the captain on deck;
  storm forces wx=storm for that stop only), village (the first generated chain island's village + (3,3)), cplaza and
  cmarket (capital frame (0,9.5) and (0,46), reached by `Player.debug_to_capital` and a wait for `chain_ready` +
  `cwarm` 10 s). Stops always run in ROUTE's order whatever `stops=` lists (groups old new town atsea capital all;
  `quick` alone = old). The village comes late: standing on a chain island makes the crew arrive there and frees the
  other island ahead (nodes 34.9k -> 21.1k), and the capital jump frees that one too (14.3k).
- `crowd`: BrinehollowCast.CROWD is a const, so the bench rewrites its source to true and `reload()`s the script on
  the first frame (autoloads up), then loads the world; it fails loudly if the line moved.
- The stop screenshot is saved after the base sample (it was ~65 ms in base's first frame: "worst" read 60-80 ms
  at every stop; now 15-29 ms, no frame over 33 ms in either run). Summary columns `h33` / `h50` (base frames over
  33 / 50 ms; ALL sums), rows ALL_OLD / ALL_NEW and a `== scripts_old` table when both groups ran.
- Gotcha: `Ship.place()` then reading the ship's `global_transform` in the same frame gave the old one (the first
  sea stop put the captain in the water by Brinehollow's dock); the deck point is built from the placed spot.
- `perf_gate.ps1` gates only the baseline's stops (ALL = their mean on both sides), prints the others as "no baseline
  yet", reads scripts from `scripts_old` when present, and benches a confirm's old commit with `stops=<the baseline's>`.
  bench_compare adds frame1t, h33/h50 and lists stops only one side ran. Exercised offline (perf_gate's functions on
  v119_bench_base vs perf_baseline.txt): it gates the eight, shows the eight new ones. The current baseline is the
  laptop's from v1.14, so against it this PC fails (+40% frame): re-baselining on the min-spec PC is the lead's step.
- Runs (min-spec PC, 13:00 clear, back to back, calib 23.48 / 23.45, no other Godots): v119_bench_base ALL frame 12.42,
  frame1t 13.13 (ALL_OLD 13.09 / 13.65, ALL_NEW 11.80 / 12.61); v119_bench_crowd ALL 12.40 / 13.16. The crowd (10 more
  townsfolk, +383 nodes) costs the market +1.25 ms frame (+9%), +1.1 frame1t, +0.8 ms scripts (brinehollow_folk and
  its rigs); elsewhere it's inside the run-to-run noise (single stops swung +-12% both ways on the same code).

## 2026-10-20: the stutter hunt (why 1.18 felt laggy in fights, at sea and in towns)
- **Measured** (min-spec PC, 13:00 clear, 1920x1080, vsync off, gate mode, no other Godots; runs stut_ed / stut_ex,
  calib 24.05 / 23.00):
  - **Export vs editor:** the same. ALL frame 12.63 -> 12.45 ms, frame1t 13.21 -> 13.07, p95 16.83 -> 16.71; the
    release build's scripts 10-15% cheaper, its draw ~11% dearer. The exported build isn't the cause.
  - **Steady fights and walks** are no worse than the panning stops: brawl 14.0 ms / p95 18.8 / worst 25, naval 12.9 /
    16.5 / 28, Brinehollow walk 14.2 / 17.5 / 25.5, capital walk 11.2 / 14.1 / 20; no base frame over 33 ms (one 36 ms at
    the fight stop). The probe's longest single calls: pirate_grunt.gd 3-5 ms in a tick in fights, everything else < 1.5.
  - **Island streaming is the stutter** (the new `isles` stop, and the village arrival): letting a chain island go was one
    150-270 ms frame (10-14k nodes freed in one queue_free, the "tail"); building one is ~180 frames of 35-45 ms (each
    step 10-25 ms on top of a 14 ms frame), 35 of them over 33 ms and 6 over 50 in the isles stop, the worst step 40-160 ms
    (boss, camp, colliders). It happens in the first ~20 s of every session in Brinehollow (the two islands ahead: the
    perf.log's first line, 26 hitches), on arriving at an island (the other one let go) and in town when the log pose
    sets (the next ones built).
  - **Cold shader cache** (a first launch: `bench.ps1 -ColdShaders`, the export, ex_cold): the first fight was a 401 ms
    frame on reaching the camp (draw 385 ms, 7 surface + 5 specialization pipelines) and an 87 ms one at the first blows;
    warm, none. The export bakes 90 shaders, only 16 of them scene shaders: the effects' StandardMaterial3Ds are made in
    code, so the baker never sees them.
  - The bench sessions' perf.log ("1-2 hitches of 60-80 ms every 30 s") was the bench itself: each stop's screenshot,
    the probe's start (its find_children over the whole tree) and the calib. Hit-stop and slow motion also hid frames:
    delta runs at Engine.time_scale (0.05 in a hit-stop), so the bench and Perf now time frames in real time.
- **Fixed:**
  - **An island let go** (WorldGenerator._let_go): processing off, hidden, renamed (`FreeingIsleN`, so one built again
    takes its name and node paths) at once, and freed FREE_US 2.5 ms a frame (_free_some): anything with a script whole
    (a scuttlebug's _exit_tree restores its ragdoll's rig: leaves first freed its parts under it, dungeontest), plain
    containers piece by piece past FREE_WHOLE 24 children. NavBaker drops a let-go island's zones at once. The isles stop:
    worst 159 -> 82 ms, no let-go frame over 33 ms; the village arrival's 273 ms frame is a 39 ms one, then ~1 s of
    frames +2-3 ms (village base 13.0 -> 16.1 ms while it's freed, worst 21).
  - Gotcha: `Perf.mark` by the autoload's name in humanoid.gd broke every suite that preloads it (a --script compiles
    before the autoloads; compilecheck has them, so it passed): project classes reach Perf by path.
  - **Build steps:** WorldGenerator._finish_step runs the small steps after the frame's step while the frame's island
    work is under SMALL_US 1.5 ms (steps with nothing left to do take no frame); DrawLOD slices at 4 ms (was 12) over
    192 steps (was 64; the last still does whatever's left). The isles stop: h33 35 -> 23, h50 6 -> 4 (isles_before /
    isles_after2, back to back, calib 24.56 / 23.53).
  - **Blood splats** pick from 24 shapes made at FX's start (a fresh SurfaceTool mesh per splat was ~1 ms of GDScript,
    2-5 a bloody hit; its own rng, so the global one isn't drawn on). Brawl: h33 2 -> 0, worst 40 -> 33, p95 20.1 -> 17.8.
  - **FX.warm_up:** every kind of effect drawn once in front of the camera in the loading screen's last moment (WARM_S
    0.8 s more under the card; the bench calls it at its setup too). Cold cache: the camp's 401 ms frame is gone; one 70 ms
    frame is left at the first blow (1 surface + 1 specialization: a trail or technique material it doesn't cover yet).
- **Tools:** bench stops `bwalk`, `cwalk`, `brawl`, `naval`, `isles` (group `act`, rows ALL_ACT), `== hitches` (every frame
  over 33 ms in any phase with its split, pipelines compiled canvas/mesh/surface/draw/specialization, nodes made and
  Perf's marks), the probe's longest single calls per stop. `export_bench.ps1` (the "Windows Bench" preset: Windows
  Desktop plus tools/dev) and `bench.ps1 -Exe` (an export ignores --script: an override.cfg beside the exe makes
  `BenchBoot` the main loop, which becomes this checkout's bench script) and `-ColdShaders`.
  Perf (scripts/game/perf_monitor.gd): `Perf.mark(what)` (island steps, islands let go, autosave, navmesh parses, bodies
  built on the main thread, ragdolls, music loaded); a line per hitch under each 30 s line (process / physics / render
  ms, pipelines, nodes, the state, where, the marks); the last five sessions kept (perf.log, perf_1..4.log); tool runs
  write none. SaveGame.enabled() is off for every tool run (the export bench's BenchBoot too: it read save_1 before).
- **Left:** the build steps themselves (village houses, dungeons, harbour, ground, plants: 10-25 ms each, the camp's
  50-75 ms of tail, the beasts' models made on the main thread when they're added: boss 23-160 ms) want moving to
  the worker (GenIsland.prepare) or splitting; the warm-up doesn't cover blade trails, technique ribbons, enemies' and
  ships' own materials; pirate_grunt's 3-5 ms ticks (map_get_path on a goal that moved, likely).
- **Tested by** t/island/free_slices, t/world/perf_log, t/fx/warm_up, perftest (the log under its own dir), chaintest
  (the let-go island), katanatest.

## 2026-10-20: island builds off the main thread (the stutter hunt, part 2)
- **Where the time went** (`stepprobe`: a chain island's steps one a frame in a window, cold then warm; `spawnprobe`: one
  enemy or creature put in the world; the build log now lists every step of 4 ms or more, slowest first):
  - **DrawLOD's fold read every mesh back from the GPU**: `MeshBuilder.from_mesh` is `surface_get_arrays`, a readback under
    d3d12 (60 ms an island headless, 800-860 ms in a window). The biggest single cost of a build.
  - **Cold script compiles**: a beast's or creature's script loaded by path compiles on first use on the main thread
    (50-130 ms each: boss #2 132, beasts 70, the snow village's shagback 65, fauna parts 45-150). Warm, a creature is
    0.5 ms, a scuttlebug or spitter 4.5, a beast 5-13 (the serpent 13, the ape 25 unstocked).
  - **Everything spawned at once**: a lair's nests hatched their dozen bugs in one deferred call (a 55-85 ms frame); a
    camp's first crew (six grunts) turned up in one frame (~40 ms).
  - Big single steps: tree colliders 33-40 ms (~2000 shapes), fauna zones 30, the market 30, village dressing 21-26 a
    chunk of 20, the plants' thirds 10-18 (and their upload), camp 18, village 16-23, terrain + coast 20-26.
- **Moved to workers:**
  - `GenIsland.warm_scripts` (prepare): the theme's creature scripts and the island's beast scripts loaded on the
    worker, kept on the island (`_warm`).
  - **Beasts' models** (`QuadBeast.prebuild`, every QuadBeast kind: 16 of the 20): the rig (plain Node3Ds) and every
    part's MeshBuilder, painted, keyed by the shared PSXMats, built on a worker while the first steps run
    (`GenIsland.start_beasts`, from WorldGenerator._finish_ready: the beast objects are made on the main thread since a
    CharacterBody3D is a physics object, after prepare loaded their scripts); the spawn (`take_beast`: the boss's first,
    each mini, the roamer) only commits the parts with the beast's own material copies (`MeshBuilder.rekey`) and makes
    its shapes. Nothing for the servers on the worker: no mesh commit, no MeshInstance3D, no shape.
  - **The fold without readback**: during a chain island's steps (`GenIsland.run_step` sets `MeshBuilder.keep`), each
    main-thread `commit()` keeps a copy of what it was built from (its arrays shared copy-on-write; skinned meshes not),
    DrawLOD folds from that (`MeshBuilder.kept`) and `forget()` drops them when the island is registered.
- **Split on the main thread** (`GenIsland.sliced(name, count, unit)`: units run until SLICE_US 3 ms a step, the last
  step finishes them; same order however many frames, so co-op and the islanddump are unchanged): tree colliders 64 a
  unit into the body before it joins (24 steps + one to add it), fauna zones 150 crowns a unit, village dressing an
  item a unit; plants 15 steps (was 3; the MultiMeshes in the same child order); coast its own step; the camp in three
  (fire/tents/shack, stores/tower/flag, chest/crew: one rng in order); the village in three (inn, rest/shops/board,
  people: "village people", which GenIsland's predelete reads now for the stocked bodies); the market in four; each shop
  and its keeper. A nest on a building island (`GenIsland.building`) hatches a bug a frame (`ScuttlebugNest._hatching`);
  a warm-start camp musters a grunt a frame and is manned once all are (`GruntCamp._muster`).
- **Measured** (min-spec PC, 13:00 clear, no other Godots): the isles stop (isb_before / isb_after2, calib 23.34 / 23.88)
  h33 26 -> 13, h50 5 -> 1, worst 87 -> 60 ms, p95 31.4 -> 28.9, frame 20.0 -> 19.1. The build log: the session start's
  islands 2372 -> 1175 ms on the main thread (Whitecap Key, worst step 120 -> 31) and 2645 -> 1418 (Tambor Key, 158 -> 32),
  the isles rebuild 1524 ms over 217 frames (worst 35) -> 1023 over 178 (worst 21). The whole route in gate mode back to
  back with main's scripts (isb_route_main / isb_route, calib 23.95 / 24.08): ALL_OLD 13.45 -> 13.36 ms, ALL_NEW 13.60 ->
  12.63, the route's h33 178 -> 17 (main's islands were still building into the first stops: bwalk's 1.3 s frame); terrace
  +15% alone (noise: no script of this branch's in it). The 60 ms frame left in the isles stop comes after the last step
  with no mark (+80 nodes; it was there before too, 58 ms): not attributed.
- Tried and dropped: MultiMesh `buffer` set in one call from prepare (a 125 ms step: the RD uploads it at once, where
  set_instance_transform batches to the frame).
- **Same island:** islanddump of Brinehollow (only the dummies' sack heads, as always) and of chain seeds 4242, 1, 12, 36
  and 9 identical before and after; t/island/beast_prebuild compares every prebuilding kind's model both ways (the dump
  doesn't walk into CharacterBody3Ds).
- **The mesh-commit crash** (docs/todo.md): nothing here commits a mesh, makes a visual node or a shape on a worker (the
  beasts' worker part is GDScript arrays and Node3Ds). A guess for its pass: it's been seen headless only, where the
  dummy renderer's RID owners aren't thread-safe while villagers' bodies are committed on prepare's worker.
- **Left** (each 10-30 ms, on the main thread): a village house (Buildings.house / KitHouses.room: 5-21 ms), dungeon
  dressing steps (15-33), the arena's dressing (13-22), landmarks' first steps (great tree 34, sky wreck, aqueduct,
  waterfall, snow castle 11-18), the harbour's longest walkway (13-15), terrain mesh commit (9-30), ground colliders
  (8-9 each x16: Jolt builds the trimesh), the camp's lookout tower (16); the serpent's, mantis', sandworm's and
  scorpion's models (own _build, not QuadBeast); a scuttlebug 4.5 ms each (hatched one a frame). These want their
  geometry as data on the worker like the beasts' (a builder's MeshBuilders and transforms, the nodes and commits after).
- **Tested by** t/island/build_slices (slices in order, the last finishes; a building island's nest hatches a bug a frame,
  a built one's all at once), t/island/beast_prebuild, t/island, isletest, chaintest, villagetest, smoketest.

## 2026-10-20: whimsical menu chrome, piece 1 (v1.18.2, menu-ui; docs/progression_plan.md "Menu chrome")
- **What:** the menus' look from the approved mock (docs/media/progression_mock/chrome.css), as pixel 9-slices painted
  in code: `scripts/ui/ui_chrome.gd` (UIChrome) paints them one image pixel per canvas pixel, `UIStyle.chrome(kind)`
  makes the StyleBoxTexture (tiled middles where there's grain or rope, stretched where there's a gradient). Kinds:
  parchment (hand-cut corners, gilt band, burnt edge, wax seal top right, coffee ring bottom left: needs >= 42 px),
  paper (small, plain), slate (rope border, brass nails), plank / plank_hover (gilded) / plank_pressed / plank_dim /
  plank_focus, sign / sign_on (tabs), ribbon / ribbon_gold (12 px swallowtails), keycap, scroll (the nameplate), beam
  (28 px top bar with knots over a rope), board (18 px key bar, rope on top), well (text fields), rope (rules).
- **Theme:** `UIStyle.panel()` with its default colours is now slate (other colours keep the old gilt frame); buttons
  are planks that gild on hover; LineEdit a paper well; separators rope; tooltips paper; keycaps wooden. `title()` is
  Jacquarda Bastarda 9 (assets/fonts, SIL OFL; a 9 px grid: sizes 9/18/27, outline 2 at most or the counters fill).
- **Helpers:** `draw_sky` (night sky, nebulae, twinkle, dashed map border), `draw_topbar` (beam, compass-rose emblem,
  hanging signs via `draw_tabs`, nameplate via `draw_plate` with `draw_coin`), `draw_board` + `draw_hints`, `ribbon()` /
  `draw_ribbon`, `rule()` / `draw_rule`, `draw_star`, `draw_title`, `parchment()`. Tab icons: `scripts/ui/ui_icons.gd`
  keeps the mock's SVGs and rasterises them with hard edges (crown, swords, compass, chest, fruit, emblem).
- **Canvas:** the menus draw in a PixelCanvas, 640x360 at 1280x720 and 1920x1080 (800x450 at 1600x900), so the mock's
  1280x720 maps at x0.5 there; the 16 px icons and 24 px skill icons stay native.
- **Tested by** t/ui/chrome_kit; looked at with tools/dev/chromeshot.gd and uishots (pause, options, inventory, shop,
  dialogue).
- **Piece 2 (the other menus, mostly swaps):** the dialogue box is a parchment page (its right margin clears the wax
  seal) with a wooden name sign and plank choices that gild; Options' sections are red ribbons with a rope rule between;
  the inventory's tabs and the journal's are wooden signs (gilt when open), the captain's name blackletter; the
  shipwright's small buttons planks; the HUD's prompt a wooden sign, the pickup feed wooden chips, the island banner
  blackletter 27 over a rope rule. New: `PlayerHUD.show_new_tree(name, line)` (through the hud group), the mock's "new
  skill tree" card (slate, gold ribbon, blackletter name, K OPEN). uishots has `banner` and `tree_banner` shots.

## 2026-10-20: the skills menu, piece 3 (v1.18.2, menu-ui; docs/media/progression_mock, the prog-core contract)
- **What:** `scripts/ui/skill_map_screen.gd` (SkillMapScreen, still K, still GameMenu's "skills") is rewritten on
  prog-core's API: night sky, the beam with a hanging sign per tab (`UIStyle.draw_topbar`; signs hang on rope stubs
  at staggered heights, the active one 4 px lower), the key board. Tabs: **Captain** (parchment legend, the level trunk
  with round `auto` nodes and split `talent` nodes from SkillTrees' captain tree, YOU on it, Will nodes beside it;
  without captain data yet it draws the trunk's level ticks), **Combat** (a weapon's tree + its parchment card + the
  weapon rail; Tab: the chart of every found weapon around the captain hub with its branches' big nodes),
  **Adventure** (found trees listed, the open one, its card with "how it grows"), **Loadout** (loadout cards, the one
  bar 1-5 + R, passive slots, the library grouped by tree with ON n / SLOT n / NEEDS A LOADOUT), **Driftfruit** once
  `visible_trees("fruit")` has one. A tree not converted yet draws its root and "still being charted".
- `scripts/ui/skill_tree_draw.gd` (SkillTreeDraw) draws a tree: SkillTrees positions fitted to the area, links lit in
  the tree colour, big nodes by kind (root circle with the weapon's item icon, technique / ultimate squares with the
  24 px skill icons, move / element circles, mechanic double ring, passive diamond), steps with x/5 chips (a coral dot:
  buyable now), variants and talents as one split node (`split`, its halves hit "v:<id>:<i>" for the mouse), branch
  titles with "n OF m". `place_labels` puts each big node's name below, right, left or above, clear of nodes, steps,
  titles and links (the menus' 640x360 canvas is half the mock's size: there's no room for the mock's tag lines, the
  card shows the inspected node's kind, level, words and what Enter does).
- **Hits:** everything clickable registers `hit(rect, id, nav)` while drawn ("n:<node>", "w:<tree>", "bar:<slot>",
  "pas:<i>", "lib:<id>"); the mouse reads last frame's hits; arrows / d-pad move the pick to the nearest hit that way
  (a 60-degree cone, distance plus 2.5x the sideways offset). Enter / F / pad A acts: buy a step (`buy_step`, else
  `step_why`), switch a version (`set_version`, refused away from the bunk: "Switch versions at the ship's bunk"), pick a
  talent (`pick_talent`), put a library skill on the first free key, a passive in the first free slot. 1-5 / R with a
  skill picked: `PowerComponent.equip`, refused with `equip_why`'s own words; 1-4 with a passive: `equip_passive`.
  Q / E or the shoulder buttons change tab, A / D weapon, W / S Adventure tree, Tab the chart, right-click clears.
- **Loadout trees** come from `PowerComponent.loadout_styles()` (the bar's own view: a loadout whose weapon left the bag
  counts as none); a bar slot or library row whose skill `equip_why` says "Needs ..." is greyed, NO LOADOUT.
- The inventory's character sheet drops "Skill points" for the weapon-in-hand's mastery.
- **Per frame:** only while the menu is open (the game is paused), the screen redraws every frame (sky twinkle, pulses):
  ~100-200 draw calls of 2D primitives; nothing runs while it's closed.
- **Tested by** t/ui/skills_tabs, skills_buy_step, skills_version_bunk, skills_loadout (each sets the root to 1280x720:
  the runner's window is 64x64), t/ui/chrome_kit; filmed with skillmapshot (every tab, 640x360 and 800x450).
  r6test's skill-map checks now ask the new screen (opens on Combat, Driftfruit shows your fruit, a weapon opens on its
  root); uishots, styleshot, seamapshot and r6shot open the new tabs.
- **Lead's pass:** steps show their names under their counters where there's room (all of them on the 800x450
  canvas; on 640x360 the ones that would overlap show on inspect); the middle branch's title sits above its top node;
  the Will column wraps "how" and "what it gives"; the library puts the Captain's and Will's skills and passives in one
  CAPTAIN AND WILL group.

## 2026-10-20: the radial wheels redrawn round (v1.18.2, menu-ui; Zach: "small labels and symbols in the wheel")
- **What:** `scripts/ui/radial_wheel.gd` (RadialWheel, the base of the emote T, item E, loadout X and action N wheels)
  no longer lays wide plank "plates" on a stretched ellipse. It draws a round wheel itself: a dark donut of N segments
  in a twisted rope ring (outer and inner) with rope dividers and brass nails, each segment the entry's 24 px icon (or
  its initial in a wooden medallion) over a short Silkscreen 8 label cut to the segment (whole, else the first word,
  else letters off the end); the pointed segment gilded, greyed ones dim, the current choice starred, a count badge
  (`_badge`, the item wheel's quantity). The hub names the wheel in blackletter (Pixelify when long), or shows the
  pointed entry's full name and its second line (`_sub`: the action wheel's reason, the loadout's weapons, "3 in your
  bag"), coral when it's greyed. The ring's radius grows with the entry count (50 px of arc each, at least 64).
- Behaviour unchanged: hold to open, tap (tap_ok), the dead zone, picking by angle (entry i at TAU*i/n clockwise from
  up), point_at, right-click / Esc. `shown_text(i)` gives [label, sub] as the wheel opened (tests read it instead of
  the old plates' labels).
- **Per frame:** only while a wheel is open or fading: one redraw of ~N*30 polygon points and a few arcs.
- **Tested by** t/ui (emote_wheel, item_wheel, action_wheel, wheel_same), t/player/loadout_swap, t/jam/play_solo,
  t/food, t/downtime; filmed with uishots emotes,items,loadouts,actions.
## 2026-10-20: perf session steps 3 and 5: occlusion culling in towns, the long tail
- **Occlusion culling** (project.godot `rendering/occlusion_culling/use_occlusion_culling=true`; `scripts/psx/occluders.gd`,
  class Occluders): boxes shrunk 0.15 m inside solid stone, kept as data in a capital piece's colliders ({"occ": size, "xf"},
  split off by `Occluders.take` on the worker) and made one OccluderInstance3D a piece in CapitalIsland._piece (no new step).
  The capital: wall runs, square towers, round towers (the square inside the shaft), gatehouse sides, the palace hall and
  wings, the temple, moles and quay blocks, barriers, the district's town houses (behind the door niche), the inn's back,
  the guild and counting house, and every massing house (493 in 23 chunks). None on the arena (open arcades), the floors,
  porches or rooms you walk into. Main-thread builders: one box per Buildings.house (Brinehollow's and every chain
  village's houses and shopfronts) and per DesertTown.house. An occluder only hides whole instances behind it, so it must
  never cover a gap you see through (an arch, a window through a wall); recesses are harmless.
- Measured (min-spec PC, quick, same build on/off, two pairs; calib 24.0-26.2): visible draws -10 to -25% at the town stops
  (cmarket 445 -> 337-356, cwalk 470 -> 365, plaza 995 -> 873, bwalk 1171 -> 946); frame within the run-to-run noise both
  ways (ALL 15.61 -> 15.42 and 15.68 -> 15.18). Shadow draws (half the total) don't change: occlusion culls the view pass
  only. Kept on as groundwork for the fuller capital (1.20). The bench screenshots match on/off (plaza, cmarket).
- **The long tail:** SkyBirds and SeaSpray write their MultiMeshes in one `buffer` call a frame (a bird's 16-float row
  made when it flies; streaks and foam rows built in the loop) instead of two server calls an instance; foam heights a
  third of the patches a frame (was half), carried on at the rate they were rising, the tilt with every other height
  (heights a frame 59 -> ~26 at 40 patches); DevCapture samples on a 0.1 s Timer (no `_physics_process`, no
  get_property_list) and makes nothing in a release build. Gotcha: the headless renderer gives back nothing from a
  MultiMesh, so both keep their last buffer (`rows`) for the test.
- Full route back to back (occ_before2 main / occ_after, calib 25.39 / 27.14, no other Godots): ALL frame 15.89 -> 14.20,
  frame1t 15.99 -> 14.37, p95 23.6 -> 19.8, h33 70 -> 18, draws 1421 -> 1370; but GPU and physics scripts fell ~25%
  at every stop, sea included, which no change here explains: treat the pair as noisy. Scripts: sea_spray 0.195 -> 0.161,
  sky_birds 0.285 -> 0.285 (the buffer didn't move it: its cost is the flying), dev_capture 0.098 -> 0.
  A rerun of main's before (occ_before3) died at the calib three times (exit 255, no trace; the branch ran fine after a
  re-import): not chased.
- Left: sky_birds' flying (dictionary-heavy, 0.28 ms), moored_hull (3 wave heights a tick per riding hull, 0.1),
  ambience 0.13, actor_sleep 0.13, weather 0.11.
- **Tested by** t/capital/occluders (every wall's and house's occluder inside its colliders, none over a street, a
  house's inside its walls), t/world/sky_long_tail (buffer layout, the foam as near the swell as before, DevCapture).
## 2026-10-20: progression redesign, piece 1: the engine, the contract, the katana (v1.18.2 prog-core)
Spec: docs/progression_plan.md "Redesign" and "Build: v1.18.2".
- **SkillTrees** (scripts/progression/skill_trees.gd, new): the redesigned trees. HEADERS has every tree's header (name,
  section captain/combat/adventure/fruit, colour, top level: Captain 40, weapons 30, Adventure and fruits 20); a converted
  tree has a root and three branches of big nodes (`_big`: kind move/tech/mech/passive/elem/ult, a level, linked up its
  branch), variants (`_variant`: versions that are nodes of their own, kind "version") and steps (`_step`: x/3 or x/5,
  effects per step, hung off a big node). Positions are computed (tree space, root at 0,0, the left/right branches lean out).
  Only the katana is converted (Guard / Iai / Blade, 30 steps against 29 points); the old ids and effect keys are kept, so
  every reader (stat, has_move, style_stat, elemental, knows) works unchanged. Folded Steel and Sword Saint became the
  Keen Edge / Whetstone / Light Feet steps. Variants whose other version is a new move (Side Step, Twin Waves, Falling
  Moon) show their one form: k_counter, k_wind and k_arc are plain nodes. SkillTree merges these nodes in its own shape
  (`_merge_new`, "new": true) so its readers and the old skill map see them.
- **Progression**: big nodes are granted by level (`_sync_tree` on every level-up and load), steps bought with
  `points_free` = level - 1 - steps, `buy_step`, `respec_steps` / `set_version` / `pick_talent` (a change) only by the
  ship's bunk (`can_respec`: within 2.5 m of Ship.BED_AT). Passive slots (`passives`, 3, 4 from level 25): a redesigned
  tree's "passive" node counts in `stat()` only while slotted; a new one fills a free slot by itself; `library()`.
  Trees show once found (`found`, saved; the Captain and the Cutlass at the start): the first xp in a tree finds it,
  `tree_found` fires and the HUD's `show_banner` says "New skill tree!". `owns_node` is the contract's has_node (Node has
  one). `master_all()` for tests and render tools.
- **Mastery**: no family carry-over (FAMILY_SHARE 0, kept for the old map). A hit counts for the first 12 hits on each
  foe (`on_hit(target)`; PowerComponent passes the target), a kill's share x3 for an elite or a boss (`_elite_at`: a dead
  "bosses" member, captain grunt or brute scuttlebug within 6 m of where the xp came from, among the bosses and the foes
  we struck). Downtime's Train: +2 every 6 s, only up to mastery 8 (TRAIN_CAP; the wheel greys it with the reason).
- **Saves** (FORMAT 5): steps, versions, passives, found, will. On every load a converted tree's old purchases are dropped
  and granted again by level, so its points come back by themselves (no per-piece format bumps); trees not converted
  keep their nodes and points. A format-4 save gets one banner.
- Tests: t/progression/ tree_shape, grant_by_level, steps_points, versions_bunk, tree_found, hit_cap, passive_slots,
  format5_migration (family_carry and can_learn gone); t/downtime/train checks the cap. techtest, abilityshot and
  siteshot call `master_all()` first. Expect progtest, techtest, balancetest, r6test, katanatest, uitest to want a look.

## 2026-10-20: progression redesign, piece 2: every weapon tree in the new shape
- The other eight weapon trees (Cutlass, Dual Wield, Axe, Dagger, Twin Daggers, Corsair, Pistol, Unarmed) are SkillTrees
  trees, drafted in docs/progression_plan.md ("The other weapon trees"): the old ids, moves, skills and effect keys kept,
  big nodes by mastery level, 30 steps each (the old stat nodes became the damage / crit / stamina steps; a few old ids
  like s_edge, g_marks, d_twin, a_heft are steps now), the element at 16 / 25 (`_elem`, SkillTrees.ELEMENTS), the
  ultimate at 30, and two of the old style passives as a variant (Pirate's Way, Rage, Dancer's Way, Killer's Way,
  Viper's Way, Corsair's Way); the rest are slotted passives.
- Gone: the weapon trees in SkillTree, SkillTree.MASTERY, FAMILIES (kin_of / families_of return [] for the old map),
  mastery "pts", weapon `_spend`. A save holding node ids that no longer exist gets the refund banner once.
- The found-tree card is menu-ui's `show_new_tree(name, line)` on the HUD ("Added to COMBAT · n points to spend").
- Tests: tree_shape now checks all nine weapon trees; refund/format5 migrations for the cutlass converted too. World
  suites' tree checks updated for the new shape (techtest, daggertest, wieldtest, balancetest, progtest), not run.

## 2026-10-20: progression redesign, piece 3: the Captain, Will, the fruits, Acrobatics and Defense
Spec: docs/progression_plan.md "Captain tree"; the Acrobatics and Defense drafts. Acrobatics, Defense and the fruits came
into this piece (not piece 4) because the old Captain tree held Geppo, Swift Step, Steadfast and Iron Hide and the
fruits were bought with skill points: the old trees went in one go, so nothing is missing on main in between.
- **Captain** (SkillTrees "captain"): growth by level (SkillTrees.GROWTH x (level - 1), folded into `stat()`: +5.5 health,
  +2% damage, +0.6 stamina, +0.6 energy, +0.5 defense; player.gd's own 4 health / 2% a level gone), milestones (kind
  "auto": Soru 8, Quartermaster 10 = a third loadout through "loadout_slots", Tekkai 14, c_slot4 25 = passive_slots 4),
  talents (kind "talent" at 5..40, two versions each; `pick_talent`: the first pick anywhere, a change at the bunk),
  Will (kind "will", the Will column, each with its Will passive linked to it, "will": id). No skill points
  (`skill_points` stays 0 for the old map/inventory), tiers rank up by use alone (`note_use` -> `rank_up`, and on load).
- **Will**: `add_xp(amount, at)` finds the foe that fell there (`_fallen_at`: bosses, Sea Kings, the fort's captain and
  the foes we struck, `is_dead()` within 6 m, 60 for a Sea King); `boss_kind` (morrow = the Redtide fort's boss, ape =
  JungleApe, queen = BroodQueen, arena = a JungleBeast in "bosses", sea_king) -> `beat` -> `beaten` (saved) ->
  `_open_wills` (SkillTrees.WILL: boss + the Wills needed first) -> `grant_will` (node, its passive, a banner).
  Assumed bosses marked in the plan. Co-op: each captain's own machine runs this from its own `_all_xp`.
- **Talent hooks**: Quick Hands (player.gd use_item: use_speed_pct), Sea Dog (stat("stamina_regen_pct") +1 while
  Downtime.ship_under), Second Wind (Progression's tick, once per in_fight), Bounty Hunter (`on_hit(target, hit)`: an
  extra dot hit on an elite; PowerComponent passes the hit), Rallying Cry (player.gd _revive_tick: revive_pct, the
  reviver heals rally x max health; the revived gets the usual share: Net.revive has no talent data), Treasure Sense
  (compass_strip.gd `_draw_treasure`: loot bags with a save id not rolled yet, within treasure_sense m), Captain's
  Presence (player.gd _on_hit_received: a non-elite foe's blow x (1 - presence)), Quick Learner (mastery_pct in
  add_mastery). Approved by the lead (player.gd hooks).
- **Driftfruit**: the fruit trees are SkillTrees trees (ember, wolf, vine; levels 1-20), granted only with that fruit
  (`_sync_tree` checks power.fruit; `grant_fruit` syncs it; after_load drops another fruit's nodes). A cast of one of its
  powers is FRUIT_PER_CAST mastery; the Wolf's claws learn like a weapon (`hand_tree()` "claw" -> "wolf"; claw_pct in
  damage_multiplier).
- **Acrobatics / Defense**: the drafts minus the new moves (Moonstep, Afterimage, Roll/Sidestep, Crash Landing,
  Disarm/Shove, Rolling Guard); Clean Parry is numbers (a wider window, 10 stamina back), the rest new numbers or
  tiny hooks: sprint_jump_pct (jump_state), climb_pct (climb_state), block_cost_pct / block_move_pct (block_state),
  parry_stamina (parry_state). XP: a jump 3, an air jump 6, a dodge 5; a parry 15, a blocked blow 5.
- Vey's story step: `drill()`, a level of mastery for the weapon in hand (vey.json says so).
- skill_bar.gd's level badge: the hand tree's free points (no "+SP").
- Tests: t/progression captain_growth, talents, will_bosses, acrobatics; refund_migration rewritten; loadout_swap's
  third slot now at Captain 10. World suites updated, not run: progtest (the Captain section rewritten), storytest
  (Vey's drill), r6test (Coat by Will; its old-map fruit/base tab checks are menu-ui's), powertest (Ember by level).

## 2026-10-20: progression redesign, piece 4: the life trees, Stealth and Tinkering; SkillTree is a reader now
Spec: docs/progression_plan.md "The other Adventure trees".
- Sailing (was Seamanship), Swimming, Cooking and Fishing are SkillTrees trees (levels 1-20, the old perks as big nodes
  at the same levels with the same ids and keys, Helmsman from the old Captain tree in Sailing, a few new numbers-only
  nodes, ~20 steps each and a point a level). A save past 20 (they went to 30) is clamped to 20.
- Stealth (new): sneak_pct (CrouchState's speed), ambush_pct (a blow struck within AMBUSH_TICKS 45 of sneaking: an
  extra dot share in `on_hit`, one per sneak), Slip Away (the dodge's keys). XP: `Progression.sneak(m)` from
  CrouchState every tick: SNEAK_XP 3 per SNEAK_M 4 m with a live foe within 20 m (the enemies group checked once per 4 m),
  AMBUSH_XP 10 for a sneak attack. Its nodes are all the sneaking captain's own (the notice ranges are left to
  Stealth.range_for), so they work for a guest.
- Tinkering (new): Downtime's tinker gives TINKER_XP 10 an interval; kit_time_pct slows the kit wearing off
  (`tick_kit`), kit_per_pct lengthens each interval's tuning; Dry Powder / Powder Horn / Field Whetstone are
  always-on numbers.
- SkillTree has no trees of its own any more: `nodes()` is SkillTrees' nodes in the old shape, `perks_of` / `kin_of`
  return [] and TREES / TAB_ORDER / REGION_* stay for the old skill map. Progression reads SkillTrees directly
  (stat, known_skills, _own, can_learn: big nodes "Comes at <tree> <level>", a Will passive "Comes with <Will>").
- Tests: t/progression/stealth; life_mastery (a point a level), refund_migration (Sailing's points), t/ship/seamanship
  (Sailing's nodes: Helmsman at 5, so 10% / 18% at the helm), t/downtime/tinker (its xp).
## 2026-10-20: one skill bar across the loadouts (v1.18.2 bar-swap, docs/progression_plan.md "Skill bar")
- **The rule** (PowerComponent): a weapon's skill (Skills.ALL `styles`, or the old `needs` "sword"/"gun") can go on the bar
  only while a weapon that fits it is in one of your loadouts; Captain, Will and fruit skills go on with anything; R takes the
  ultimate of any loadout's weapon. `loadout_styles()` gives each loadout's style (the hands' for the one in use;
  `Player.loadout_style(i)`: "" when it's not set up, locked, or its main weapon isn't in the bag), `loadout_for(sk, styles, at)`
  says HANDS (no weapon needed, or the one in hand fits), the first loadout that fits, or NO_LOADOUT.
- **Switch, then cast:** `try_cast` on a skill whose weapon is in another loadout takes that loadout up at once
  (`Player.take_loadout_now`: the same `_apply_loadout` as X, so the toast, the quick draw and the clack) and then casts as
  before. `can_cast` refuses it like any other reason when the switch can't happen now ("Busy": `Player.can_swap_now()` = on foot,
  not using an item, free or in a swing's combo window; knocked down, mid-heavy, stunned are refused) or no loadout holds the
  weapon ("Needs a pistol in a loadout", toasted). A Zoan hybrid's weapon skills stay refused ("Needs a pistol"). Nothing else
  changes: costs, cooldowns and the state are the old ones.
- **Editing:** `equip_why(skill, slot) -> String` ("" = fine): "Not during a boss fight" (`boss_fight()`: a node in group
  "bosses" in combat within BOSS_LOCK_RANGE 55 m, the boss music's range; clearing a slot is refused then too; outside boss
  fights the bar can be edited any time, the menu pausing the world), "Ultimates go on R", "Only an ultimate goes on R",
  "Not learned yet", "Needs <weapon> in a loadout"; `equip` refuses whatever it names, so auto_equip (first free slot) only
  places skills that can go on. A slot whose weapon left your loadouts (sold, stored, the loadout changed) **keeps its skill,
  shown unusable** (greyed on the HUD, the cast refused) rather than cleared: simpler, and it comes back with the weapon.
- **HUD** (skill_bar.gd): a weapon skill has a small corner flag in its tree's colour (FX.tree_col), with the loadout number
  when using it switches loadouts; grey icon and flag when no loadout holds its weapon.
- Saves: the bar is saved as before (old saves load as they were). Co-op: nothing new on the wire; the hands ride the snapshot
  (HumanoidSync) with the Technique state, both from the caster's machine. Per frame: the HUD reads `loadout_styles()` once a
  draw (3 loadouts, a bag count each) and `loadout_for` per slot; nothing in physics ticks.
- Tests: t/player/bar_switch_cast (a katana in hand, Smoke Bomb from loadout 2 switches and runs, a crewmate's snapshot shows the
  pistol with the cast, Iai Counter switches back, knocked down it's refused), t/player/bar_equip_rules (the refusals and their
  reasons, a locked loadout doesn't count, a slot whose weapon left the bag kept but refused, a stand-in boss locking the bar
  near and not far, a skill learned mid-fight left off it). progtest now puts a pistol in
  loadout 2 before its pistol skills fill the bar. Render: `barshot <out_prefix>` (the bar with a katana in hand, pistols in
  loadout 2, a greyed cutlass skill).

## 2026-10-21: the polearm (1.21 remaining weapons, kind 1 of 8; docs/weapons_plan.md)
- **Item and models** (WeaponDesigns kind "polearm", base resources/items/spear.tres "Boarding Spear"): `_polearm` builds a
  shaft from POLE_BEHIND 0.42 behind the right hand to POLE_AHEAD 1.32 ahead (x the design's "reach"), grip wraps where the
  hands go, and a head: leaf (spear), trident, naginata, bisento (broad, tassel), halberd, fork (pitchfork); ~2.0-2.5 m long.
  Design numbers read by `WeaponDesigns.pole(design, key)`: "speed" (its moves play that much faster: naginata 1.06,
  halberd 0.92, bisento 0.84), "sweep" (sweep hitboxes wider: naginata 1.12, bisento 1.35), "reach", "pierce" (trident: its
  thrusts can't be blocked), "rare" (bisento: `pick_id` keeps it RARE_KEEP 0.35 of the times it's rolled). Two-handed
  (`_offhand_valid`), slung across the back in the BackSocket head up over the right shoulder (`DrawMoves.on_back`), drawn with
  the two-hander's heave ("great"). Debug: **Shift+F10** puts one of every design in the bag.
- **The grip** (scripts/npc/pole_moves.gd, PoleMoves): every "pole_*" action keys the body as usual plus four channels in the
  chest's frame (from the shoulders' middle): `_gr` the right hand, `_gd` the shaft, `_ge` the edge (leads a sweep), `_gs` the
  left hand's slide up the shaft (< 0 one-handed). `PoleMoves.hands` (Humanoid._process, before the smear) eases toward them
  (SHARP 34 / 16 idle), reaches the right arm by IK, turns the weapon along the shaft and reaches the left hand to it, sliding it
  back to wherever the arm reaches (`_slide`). Outside pole actions it holds GUARD_GRIP, BLOCK_GRIP for the held block,
  TRAIL_GRIP sprinting (one hand, head trailing low), and through HELD actions (parry, hits, dodges, jumps); anything else
  (draw, eat...) fades it off in 0.12 s. No "lead" in pole specs (its offset samples would overwrite the grip).
- **Moveset** (style "polearm", SkillTree.STYLE_TREE -> tree "polearm"): combo pole_thrust 10 (shoves back, REACH "pole"
  3.4 m) / pole_rise 11 / pole_sweep 15 ("pole_sweep" 3.9 wide) / Wheel Sweep 20 (move, one full turn, "pole_spin");
  heavy Skewer (pole_heavy 30, "pole_long" 4.6 m, knocks down, streak down the line); Leg Sweep at a sprint (move: kneeling slide
  through the shins, breaker, knockdown, "pole_low"); Pole Vault (move: a sprint's jump x1.3 up and x1.3 carry, pole planted
  one-handed); Falling Spear (move, air: hang raised point-down, 24 m/s drop, landing ring 3.2 m knockdown); parry/deflect on a
  level shaft (ActionSpecs.PARRIES). Traits: serrated, gale, thundering, rushing, duellist roll on polearms.
- **Tree** (SkillTrees "polearm": Guard / Storm / Reach, element lightning "pl": Rolling Thunder 16 / Storm Bearer 25):
  Turn the Shot 3 · Vaulting Strike 8 · Spear Wall 20; Hundred Thrusts 5 · Dragon Sweep 10 · Raijin's Wheel 30; Wheel Sweep 2 ·
  Pole Vault 4 · Leg Sweep 6 · Falling Spear 9 · Long Reach 13 (passive) · Lancer's Way 22 (Keep Away / Skewer). Steps 30.
- **Techniques** (scripts/player_states/pole_arts.gd, PoleArts in TechniqueState._arts): Hundred Thrusts (seven thrusts on
  0.1 s at 4.2 m in a narrow cone, the last 15 and a push), Dragon Sweep (two low turns 5 m, the second knocks down), Vaulting
  Strike (leap over the aimed foe within 9 m, the point driven down at 0.4 s: 28 unblockable breaker, land behind facing them),
  Raijin's Wheel (ult, untouchable: up spinning the spear overhead, the moment, two turns of `_spin_hits` 5.5 m, the point driven
  in at 1.8 s: 40 knockdown 6.5 m, lightning on every foe with the element).
- **FX**: TREE_FX "polearm" (lemon-white edge, violet accent); `FX.bolt(from, to, color, width, life, seed)` (a jagged seeded
  bolt with forks, two shared materials, one flicker tween); element/elem_hit branches; BladeTrail samples a polearm from 0.7 of
  its length (the head, not the pole).
- **Co-op**: nothing new on the wire: the stance, actions and weapon model already sync; every screen solves the grip from the
  same pose. Hits go through the usual hurtboxes and Net.fx.
- **Per frame**: `PoleMoves.hands` only on bodies in the polearm stance (or fading out): two arm IK solves and a quaternion a
  posed frame (LOD bodies skip frames as before). Effects are one-shots.
- **Sources**: IslandContent.LOOT_WEAPONS and IslandEncounters.LOOT have "spear" (its design rolled by Loot.weapon),
  Shops.RARE_KINDS "polearm" (treasure merchants), Haldor's pool spear / pitchfork / trident / naginata / halberd@1;
  WeaponDesigns.random_item (Sea King, enemy prizes) includes the kind.
- Tests: t/weapons polearm_combo, polearm_moves, polearm_tree, polearm_loot; t/progression/tree_shape counts at least the 19
  older moves. Renders: tools/dev/out/polearm/ (rack_side, pb_* guard/thrust/sweep, anim_* sheets, ab_raijin_wheel).
  Expect daggertest/techtest/progtest/balancetest/uitest (the skill map's tabs) to want a look at the push.

## 2026-10-21: the hammer (1.21 remaining weapons, kind 2 of 8; docs/weapons_plan.md)
- **Item and models** (WeaponDesigns kind "hammer", base resources/items/warhammer.tres "Iron Warhammer"): `_hammer` holds the
  right hand at the origin near the butt (HAMMER_BUTT 0.12 behind it), the haft "haft" (0.95 warhammer) to the head's middle, the
  striking face toward -Y (as the polearm's edge), a grip wrap where both hands go. Heads: warhammer (square face, back spike, top
  spike, langets), kanabo (an octagonal club thickening to the end, 48 iron studs), shipwright's mallet (an iron-hooped oak barrel,
  cheap, quicker), iron maul (a long block, a face each end), anchor hammer (an anchor's crown and flukes on an iron shank, a ring
  at the butt, chain wound above the hands; RARE: `pick_id` keeps it 0.35 of the times). Design numbers by
  `WeaponDesigns.hammer(design, key)`: "speed" (moves play that much faster: mallet 1.1, anchor 0.82), "reach" (the hitbox),
  "weight" (x knockback and shockwave radius: maul 1.15, anchor 1.3). Two-handed; slung across the back head-up behind the right
  shoulder, turned flat (`DrawMoves.on_back`), drawn with the two-hander's heave. Debug: **Ctrl+Shift+F10** puts one of each in
  the bag (Shift+F10 is still the polearms).
- **The grip**: the same four channels as the polearm (HammerMoves keys them, `PoleMoves.take_grip` takes them off, and
  `PoleMoves.hands` solves both kinds: HammerMoves.GRIPS = guard, block, sprint carry). Gotcha: the channels are in the chest's
  frame, so a body leaning 0.4-0.75 rad into a slam already points them down: a slam's `_gd` is near level in that frame
  (`_slammed`, the smash's strike), or the head goes through the ground. A power swing slides the top hand down to meet the bottom.
- **Stance**: the guard rests the haft on the right shoulder, head behind it, both hands low in front; wide planted feet
  (HammerMoves.LEGS); the combat stance's hop is a slow sway for the hammer (2.4 Hz) with the chest rolling over each foot while
  walking (Humanoid._locomotion, `heavy`). Movement speed is untouched: the weight is in hit-stop, shake and stagger.
- **Moveset** (style "hammer", SkillTree.STYLE_TREE -> "hammer"): combo ham_smash 14 / ham_upper 15 / ham_sweep 21 (breaker:
  through a guard, a 1 s stagger) / Wrecking Spin 26 (move: one full turn, the head into the ground, knockdown, "hammer_spin");
  every blow a "knock" (7-12 x weight) and hit-stop 0.08-0.14; the head thuds into the ground on HammerMoves.THUD (smash, spin:
  `HammerArts.thud`: dust, stones, a dust ring, a crack on the spin). Heavy **Earthquake** (ham_heavy 34, breaker, knockdown, then
  0.04 s later `HammerArts.quake` 3.6 m x weight: 14 knockdown on everyone the blow missed). Rising Crush at a sprint (move:
  ham_rush, breaker, knockdown); Hammerfall in the air (move: raised overhead, 26 m/s drop, `quake` 4 m on landing); parry/deflect
  on the haft up across the front (ActionSpecs.PARRIES; the deflect shoves the head's face into them). Impact sound
  "punch_heavy" (a guard knocks, not clashes). Traits: bloodthirsty, thundering, headsman's, rushing, duellist's.
- **Tree** (SkillTrees "hammer": Iron / Quake / Weight, element earth "hm": Rumbling Earth 16 / Mountain's Weight 25): Iron Wall 3 ·
  Skullcracker 8 · Immovable 20 (armor_ + def_); Rolling Quake 5 · Cyclone Crusher 10 · Titan's Fall 30; Wrecking Spin 2 · Rising
  Crush 4 · Hammerfall 6 · Aftershock 13 (passive) · Smith's Way 22 (Bonebreaker / Anvil). Steps 30.
- **Techniques** (scripts/player_states/hammer_arts.gd, HammerArts in TechniqueState._arts): Skullcracker (a hop onto the aimed
  foe within 4 m, the head down at 0.44 s: 30 unblockable breaker), Rolling Quake (three slams stepping in at 0.36/0.76/1.16 s,
  shockwaves 2.6/3.2/4.2 m, the third knocks down), Cyclone Crusher (three turns walking, `_spin_hits` 3.4 m every 0.2 s, the head
  into the ground at 1.38 s: 18 knockdown), Titan's Fall (ult, untouchable: up 2.4 m, the moment at the top, a 32 m/s drop, a 7 m
  ring: 45 knockdown, six cracks, two aftershocks at +0.4/+0.8 s; with the element a ring of stone spikes and one under each foe).
- **FX**: TREE_FX "hammer" (cream core, sandstone edge, rock-brown accent); `FX.rock_spikes(pos, radius, count, seed, height,
  life)`: shards of rock heaving up in a ring, leaning out, sunk back (one shared mesh, no shadows, one tween; seeded); element /
  elem_hit branches (debris, a ring, dust). Before the element the shockwaves are dust-coloured (`HammerArts._ring_col`).
- **Co-op**: nothing new on the wire: the stance, actions and model sync as before; hits go through hurtboxes / `_strike`, effects
  through Net.fx (rock_spikes is seeded).
- **Per frame**: `PoleMoves.hands` on bodies in the hammer stance (two arm IK solves and a quaternion a posed frame, as the
  polearm's); the sway is a few adds in the existing locomotion. Effects are one-shots.
- **Sources**: IslandContent.LOOT_WEAPONS and IslandEncounters.LOOT have "warhammer" (this shifts the islands' chest rolls, as the
  spear did), Shops.RARE_KINDS "hammer", Haldor's pool warhammer / mallet / kanabo / maul@1; WeaponDesigns.random_item includes it.
- Tests: t/weapons hammer_combo, hammer_moves, hammer_tree, hammer_loot; t/progression/tree_shape. Renders: tools/dev/out/hammer/
  (pb_* poses, ab_titan_titans_fall, ab_heavy_hammer_heavy). Expect techtest/progtest/balancetest/uitest (a new tab),
  impact/islanddump-style chest rolls to want a look at the push.

## 2026-10-21: polearm and hammer stance poses (Zach's references; docs/weapons_plan.md "stance poses")
- **Hammer guard on the shoulder** (HammerMoves.GUARD_GRIP, TRAIL_GRIP): the haft lies ~0.1 m over the right shoulder joint
  (it went through it), angled out a little, the head up behind it; the face still looks up-forward so the blends into the
  combo's heave don't roll the head round. t/weapons/hammer_shoulder measures every design (warhammer, kanabo, mallet, maul,
  anchor): the head clear of the head sphere, chest line and upper arm, the haft on top of the joint.
- **Polearm run trail** (PoleMoves.RUN_GRIP): above 3.2 m/s (off under 2.6; not backing off) and sprinting, one hand low at the
  right side, the head out ahead and ~30 deg down (0.28 m off the ground at a jog, lower at a sprint's lean), the hand swinging a
  little with the stride (`_phase`); `locomote` hands the chest, head and free arm back to the gait's (it pumps). Walking keeps
  the guard. TRAIL_GRIP (head back) is only the vault's way down now. The left hand now lets go and takes hold over 0.1 s
  (`pole_lw`) instead of snapping, which also smooths a run's attack.
- **Emperor's Bearing** (pl_bearing, Polearm tree Guard branch, mastery 10, mech: `plant_polearm`; Player._recalc_stats sets
  `body.pole_plant_ok`): standing still 0.4 s with nothing played for 3 s (`pole_calm`, `pole_still`: game time, reset by any
  action: attacks, blocks, parries, dodges, hits), the body eases (0.3 s) into Whitebeard's pose (PoleMoves.PLANT: square, chest
  out, feet apart, free arm hanging) and the grip to PLANT_GRIP (right hand out at shoulder height, pole upright leaning out a
  little); `hands()` slides the shaft down through the hand until the butt meets the ground (weapon position along its axis),
  with a small local dust puff and a soft "thud" as it lands. Any action drops it in 0.1 s; the attack itself starts that tick.
- **Co-op**: the owner decides (`pole_planted`, now in HumanoidSync.FIELDS); a puppet shows it from that, easing on its own.
- **Per frame** (polearm bodies only, in the existing hands()): a few compares and move_towards, a 5-joint lerp while running,
  a 12-joint lerp and one weapon placement while planted. Puff and thud are one-shots.
- Tests: t/weapons/polearm_stance, hammer_shoulder (new); polearm_*/hammer_* and t/progression/tree_shape pass. posebench takes
  PB_SET="pole_planted=true". Renders: tools/dev/out/poses/ (ham1_* guards, pl_run_*, pl_sprint_*, pl_plant*_*, ham_sprint_*).

## 2026-10-21: the twin axes (1.21 remaining weapons, kind 3 of 8; docs/weapons_plan.md)
- **The style**: `Player.style_of` makes any axe + any axe "dual_axe" (an axe beside a cutlass or a dagger stays "dual_sword",
  one axe stays "axe", untouched). **The pair is two items, main + off hand**, not one "pair" item: the loadouts, the off-hand
  slot, the inventory's dual-wield rules and co-op's off-hand mesh already carry it, any two axe designs mix (a reaver's axe and a
  tomahawk), and a single axe from the pair still works on its own. Designs: every axe design pairs, and two new ones, the
  tomahawk (light, quick) and the reaver's axe (its beard swept into a hook), are "pair": true (`WeaponDesigns.comes_paired`):
  a chest that rolls one gives two (Loot.chest). Axe designs gained "speed" (x how fast the twin moves play) and "hook" (x the
  hook's reach); a pair's numbers are the two axes' average (`DualAxeArts.pair`); a blow from the off hand hits at the off axe's
  power (`DualAxeArts.off_k`). Put away, the main axe goes on the back and the off one on the left hip (as before).
- **Stance and moves** (scripts/npc/dual_axe_moves.gd, DualAxeMoves, "dx_*" from Humanoid._action_pose): a berserker's guard,
  low and wide with both heads up and forward. Combo dx_1 right chop 10 / dx_2 left chop 10 / dx_3 the hook 12 (the left axe
  flung round them and yanked back: `DualAxeArts.hook` hauls everyone it caught in via `vine_yank(to, dmg, wrap=false)` on the
  grunt / creature / scuttlebug: light foes only, bosses and big beasts just take the blow) / Reaping Whirl 24 (move: two turns,
  knockdown); chain windows 0.28 s, so the rhythm is chop-chop-hook-whirl. Heavy **Berserker Frenzy** (dx_heavy: chop, chop,
  chop stepping in, then both crashed down crossed, HeavyAttackState "chops": the hitbox off and on per blow, the last knocks
  down). Raider's Leap at a sprint (dx_rush: leap, crossed crash, breaker, knockdown); Buzzsaw in the air (dx_dive: forward flips
  with both axes out, 18 m/s drop, a 3 m ring on landing); the parry crosses the axes (dx_parry) and a landed one hooks the
  attacker in a step (ParryState). REACH "twin_axe" and "hook" (x the pair's hook).
- **Tree** (SkillTrees "dual_axe": Hook / Frenzy / Reaver, element frost "dx": Hoarfrost 16 / Winter's Bite 25): Hooked Guard 3 ·
  Gallows Hook 8 · Bloodrage 20; Hewing Frenzy 5 · Axestorm 10 · Fimbulwinter 30; Reaping Whirl 2 · Raider's Leap 4 · Buzzsaw 6 ·
  Red Rhythm 13 (passive) · Reaver's Way 22 (Berserker / Raider). Steps 30. Tab "2 AXES".
- **Techniques** (scripts/player_states/dual_axe_arts.gd, DualAxeArts in TechniqueState._arts): Gallows Hook (aimed foe within
  7 m hauled in at 0.22 s, or you hauled to a heavy one; the chop at 0.5 s: 26 unblockable breaker, stagger 1 s), Hewing Frenzy
  (eight chops 0.1 s apart walking in, cone 2.6 m, then a crossed crash 2.8 m knockdown at 0.95 s), Axestorm (everyone 2-6 m
  hooked in, four turns walking with `_spin_hits` 3.3 m, a crossed crash at 1.6 s), Fimbulwinter (ult, untouchable: a roar and
  the moment at 0.3 s, every foe within 10 m hooked in at 0.52 s, three turns, the crossed crash at 1.95 s: 45 knockdown 6.5 m,
  four cracks; with the frost, a ring of ice spikes and one under each foe).
- **FX**: TREE_FX "dual_axe" frost (white rime core, pale ice-blue edge, glacier-blue accent; in TWIN_TREES so the off hand trails
  in the accent); `FX.frost` (ice chips, rime motes, a cold mist) for element / elem_hit; `FX.rock_spikes(..., ice=true)` uses a
  second shared mesh (pale "metal" ice). Not lightning (polearm), earth (hammer) or fire (the single axe).
- **Co-op**: the stance, actions and both meshes sync as before; hits go through hurtboxes / `_strike`, effects through Net.fx;
  the hook's `vine_yank` is already a HOST_CALLS forward (its new third argument rides along).
- **Per frame**: nothing new; the stance is keyed poses like the daggers'. Effects are one-shots.
- **Sources**: chests that roll an axe (boarding_axe in the loot pools) now roll the two new designs too, paired; Haldor's pool
  tomahawk / reavers_axe@1 / ships_cleaver; shops sell one at a time (buy two). Debug: **Shift+F10** is now the new kinds' rack
  (`Player.DEBUG_RACK`: every polearm and hammer, every axe twice; what doesn't fit lands at your feet); Ctrl+Shift+F10 retired.
- Duellist's now rolls on axes too (it's a parry trait). Tests: t/weapons dual_axe_combo, dual_axe_moves, dual_axe_tree,
  dual_axe_loot; t/progression/tree_shape. Renders: tools/dev/out/dualaxe_anim_* (every dx_ pose), dualaxe_ult_fimbulwinter.png.
  Expect techtest/progtest/balancetest/uitest (a new tab), the chest-roll suites (new axe designs shift the axe rolls) and the
  vine suites (vine_yank's signature) to want a look at the push.

## 2026-10-21: the greatsword (1.21 remaining weapons, kind 4 of 8; docs/weapons_plan.md)
- **Item and models** (WeaponDesigns kind "greatsword", base resources/items/greatsword.tres): `_greatsword` holds the right hand at
  the pommel end of a long grip (the left slides up it toward the guard, GREAT_GUARD 0.36 ahead), a broad blade "len" on along -Z,
  edge -Y, a fuller down its first half (or teeth filed into the edge). Designs by `WeaponDesigns.great(design, key)`: black
  greatblade (dark steel, a long gilt cross), claymore (quillons swept to quatrefoils; "sweep" 1.12), sawtooth greatblade ("bleed"
  3 s on every cut, `GreatswordArts.shape_hit`), greatcleaver (a slab, a hanging hole; "weight" 1.25, slower), Sea King's Fang (an
  ivory tooth, curved; RARE). "speed", "reach", "sweep", "weight", "bleed". Two-handed; on the back hilt up behind the right
  shoulder, the blade flat down to the left (`DrawMoves.on_back`); drawn with the two-hander's heave.
- **The low guard** (Zach's reference photo, weapons_plan "stance poses"): both hands at the right hip, the blade a long diagonal
  down and forward across the body, its point near the ground on the left (GreatswordMoves.GUARD_GRIP, the polearm's grip
  channels solved by `PoleMoves.hands`, GRIPS = guard, block, sprint). Sprinting it's in the right hand, the point dragged
  behind, and `GreatswordMoves.scrape` throws sparks where it touches the ground every 0.07 s (each screen its own, local FX,
  FX culls far bursts). The walk is a quicker, forward-leaning version of the hammer's sway (Humanoid._locomotion `great`).
- **The momentum carry**: the combo (style "greatsword": gs_1 rising diagonal from the low guard to high right / gs_2 falling
  diagonal to low left / gs_3 flat backhand, a breaker / Gale Turn: a full turn right, knockdown, move "gale_turn") is keyed so
  each blow's follow-through pose (C2, C1, C4) is the next one's first key. Two parts: (1) the animation: ActionSpecs "carry" +
  extras "after": `Humanoid._begin_action` starts a carry move at full weight when the action it replaces is the one it follows,
  so there's no blend back toward the guard between arcs; (2) the gameplay: LightAttackState counts `_mom` (blows built in an
  unbroken flow: chained while the body is still in the last blow's follow-through); each plays MOMENTUM_SPEED 7% faster and
  lands MOMENTUM_DAMAGE 6% harder per blow built, with a growing ring of air, a rising whoosh and a camera kick
  (`GreatswordArts.swing_fx`). A right-click out of a follow-through goes straight into the cleave already a level charged.
- **The charged cleave** (HeavyAttackState "cleave", `_charge_update`): pressed, the blade's raised overhead and held
  (Humanoid.hold "gs_charge", a slight tremble), creeping at x0.25 and turning with the camera; levels at CHARGE_AT 0.45 / 1.0 s
  (gather, glint, a rising note; a ring at the top), let go or 1.8 s and gs_heavy brings it down (hit 0.1 s after release).
  CHARGE_DAMAGE 30 / 42 / 58, always a breaker, longer stagger x weight; a full charge can't be blocked, knocks down and flings a
  gale crescent (Projectile "gale": the slash crescent stood on its edge, 26 m/s, 10 m, 18 damage, in the tree's colours with the
  element). A tap gives the quick level-0 drop. The cleave's ground: a crack down its line, dust, a ring (`cleave_fx`).
- **Moves** (tree): Running Cleave at a sprint (gs_rush: the dragged blade swung flat through them, breaker, knockdown, "great_low"),
  Falling Cleave in the air (gs_dive, the hammer's drop; landing `fall_land`: a 4.5 m line ahead knocked flat), the parry and
  block stand the blade up in front, its flat to them (a landed parry: `GreatswordArts.parried`, a ring of air).
  REACH "great" / "great_wide" / "great_spin" / "great_cleave" / "great_low" (x the design's reach and sweep).
- **Tree** (SkillTrees "greatsword": Bulwark / Gale / Momentum, element wind "gs": Gale Edge 16 / Tempest Blade 25): Flat of the
  Blade 3 · Guardbreaker 8 · Unyielding 20; Crescent Gale 5 · Tempest Turns 10 · Skysplitter 30; Gale Turn 2 · Running Cleave 4 ·
  Falling Cleave 6 · Unbroken Momentum 13 (passive) · Swordmaster's Way 22 (Headsman / Tidebreaker). Steps 30. Tab "GREATSWORD".
- **Techniques** (GreatswordArts in TechniqueState._arts): Guardbreaker (a step in, a rising cut at 0.22 s that knocks the guard
  up, the blade down at 0.55 s: 30 unblockable breaker, stagger 1.3), Crescent Gale (a flat sweep at 0.3 s: 3.2 m cone and a
  flat gale crescent, "gale_flat"), Tempest Turns (three turns, each quicker: `GreatswordMoves.tempest_k`, a ring hit every half
  turn, a 4.4 m knockdown burst at 1.42 s, a vortex with the element), Skysplitter (ult, untouchable: up, the moment at 0.55 s,
  down at 30 m/s: a 12 m split line 48 knockdown, a 4 m ring, three gale crescents fanned down the line, a cyclone with the element).
- **FX**: TREE_FX "greatsword" gale (white core, pale jade edge, deep sea-green accent); `FX.gust` (fast pale streaks, jade motes,
  two rushing lines of air, a breath of mist) for element / elem_hit. Not lightning, earth, frost or fire.
- **Co-op**: the stance, actions, held charge and model sync as before (hold goes over the wire); hits through hurtboxes and
  `_strike`, effects through Net.fx, crescents through `net_power("projectile")`. The spark scrape is each screen's own.
- **Per frame**: `PoleMoves.hands` on bodies in the greatsword stance (as the polearm's and hammer's); the scrape is a timer
  check a frame while sprinting with one drawn (a transform and a compare every 0.07 s). The charge's hold is the state's tick.
- **Sources**: rarer than the others: in no island's pool; a chest that keeps a blade weapon turns it into a greatsword
  GREAT_CHANCE 0.1 of the time (a boss's hoard GREAT_HOARD 0.3), drawn from the chest's own second stream (`rng_for(key|great)`)
  so the rest of every chest rolls as before; Shops.RARE_KINDS (treasure merchants); Haldor's pool greatsword / claymore@1 /
  sawtooth_greatblade@1; WeaponDesigns.random_item (Sea King, ship prizes). Traits: serrated, gale, headsman's, rushing,
  duellist's. Debug: Shift+F10's rack has every greatsword design.
- Tests: t/weapons greatsword_combo, greatsword_moves, greatsword_tree, greatsword_loot; t/progression/tree_shape. Renders:
  tools/dev/out/gs/ (rack_side, pb_* / pb2_* poses, ab_sky_skysplitter). Expect techtest/progtest/balancetest/uitest (a new
  tab), the chest-roll suites (drop_rates: a kept blade can now be a greatsword) and inventory/card tests to want a look.

## 2026-10-21: the stance pass (docs/weapons_plan.md "the stance pass over every weapon")
- **Why every guard looked mid-stride** (posebench was right, it was the game): the combat stance's boxer hop (|sin| at 4.5
  rad/s on every guard joint, the shins and the lift) and the idle bob on top of STANCE_LEGS left the back foot 5-18 cm off the
  floor and the front one sunk, every weapon. The hop is gone; the guard's feet are **planted**: `Humanoid._foot_ik` moves each
  ankle to the floor (`foot_y`, the rig's standing ankle height, + `plant_up`) by `_plant_w`, which eases in (`_plant_k` from the
  guard, standing) and out under any full-body move. Upper-body moves (shots, blocks) keep it.
- **StanceLife** (scripts/npc/stance_life.gd): the stance's life over each guard. `breathe`: a breathing sway per weapon (BREATH:
  rate, depth; the hammer 1.5 rad/s deep, daggers 3.6-3.8 shallow; the chest rises and opens, shoulders lift, the hips sink on
  the exhale over planted feet) or the fist's light bounce (BOUNCE: the feet leave the floor 2 cm). `HIPS`: side-on hip turns
  (cutlass 0.55, Corsair 0.5, pistol 0.25) added to the guard and taken back out under a full-body move that doesn't key the hips
  (`_stance_hips`), so every move keeps the square start it was made from. `SETTLE`: an attack's last segment back to the guard
  (`_keys`: the last key at u 1, no mode, the spec has "hit") eases with `_back` instead of a smoothstep: it overshoots the guard
  a little and settles (c1 1.3 daggers .. 2.5 hammer: ~6-21% of the recovery), inside the move's own length.
- **Guards**: cutlass (SWORD_GUARD + STANCE_LEGS "sword") side on, the right foot and shoulder to the foe, the blade forward and
  low, the off hand up behind the shoulder (SwordMoves.OFF_GUARD, slash_r's reach start, moved there). Katana sunk (knees ~1.0,
  hips 0.26 down). Axe (AXE_GUARD, was the generic GUARD) hunched over wide feet, the axe hung low out by the right knee, the left
  fist up; the axe's own moves start and end on `_guard()` now (they keyed the generic GUARD). Dagger (DaggerMoves.GUARD) a low crouch,
  the knife forearm up before the chest in a **reverse grip**, the blade down out of the fist, the open hand out low. Twin daggers
  (DUAL_GUARD, now `aim`ed) wrists crossed low before the hips, the right forward, the left reversed. Pistol (PISTOL_GUARD) a low
  ready, the barrel ~40 deg down; shoot_r/shoot_l snap up (spec "snap": no blend in, "sharp" 90). Corsair (SP_GUARD) side on as
  the cutlass, the pistol back across the chest, muzzle up by the right shoulder. Fist keeps its guard, with the bounce. The
  four new kinds keep theirs (breathing and settle only).
- **The dagger's grip decision**: reversed only in the guard and the run; every dagger move was keyed for the normal grip (stabs
  along the forearm, the trails), so `StanceLife.grip` twirls the main-hand dagger (`grip_flip`, a half turn about the hand's up)
  to the normal grip in the first 0.06 s of any move (before any swoosh window opens: the trail reads the blade's transform) and
  back over 0.16 s after it. The moves are unchanged. Twin daggers: the right reversed too while running.
- **Run carries** (`StanceLife.carry`, `carry_w`): forward over 3.2 m/s (down to 2.6; not a strafe or backpedal) or sprinting,
  no move playing: cutlass (and Corsair, both of dual swords) trailed low behind the hip point back; the axe over the right
  shoulder, head behind; daggers reversed, arms pumping 1.35x; the pistol low at the side, muzzle down. The guard's chest and head
  go back to the run's. Any move takes over at once (the carry's weight only covers the no-move pose).
- **Co-op**: everything reads synced inputs (stance, armed, ground_speed, local_move, sprinting, the mirrored actions) and the
  body's own clock: a puppet breathes, plants, carries and twirls the same.
- **Per frame**: on posed frames only (LOD bodies on their pose rate): breathing a few Vector3 adds; the plant adds one transform
  and a subtraction per foot to the foot IK that already ran (inside the IK's 40 m / 25 m LOD radius); the carry weight a compare,
  the carry a dozen lerps while running; the grip one basis write on dagger bodies. No new nodes, meshes or raycasts.
- **Tool**: tools/dev/guardsheet.gd (every weapon's stance side by side, three/side/back views, FEET and HAND_L lines). Renders:
  tools/dev/out/stance/before/ (guard, run, sprint) and p1/ (guards), p2/ (run, sprint).
- **Tests**: t/weapons/pistol_low_ready (new); t/combat, t/weapons, t/player draw_sheathe / quick_mid_swing / rig_drift / sprint /
  dodge. Expect daggertest, techtest, fixtest, feat, progtest and nettest (puppets) to want a look at the push.

## 2026-10-21: black-leg (1.21 remaining weapons, kind 5 of 8, the last for now; docs/weapons_plan.md)
- **Learned, not found** (no item): `Player.kicks` - an empty main hand fights with kicks instead of fists while it's set, only
  once black-leg is known (`knows_black_leg()` = the Black Leg tree found: `progression.discover("black_leg")`, saved with the
  trees). **Taught by Gus Brannock** at the Salted Gull (a navy galley cook who fights with his legs; his menu's "You fight with
  your feet, don't you?" after Vey's training, once: Dialogue event "learn_black_leg", flag "gus_black_leg"; GameMenu calls
  `Player.learn_black_leg`). **Chosen** by clicking the empty main-hand slot in the bag (I): fists <-> kicks (the slot reads
  KICK). A loadout keeps it as main hand id `Player.BLACK_LEG` ("black_leg"), so swapping stays one gesture (X tap or the
  wheel, "Black Leg"), works the same on a pad (the bag's slot is a button) and the one skill bar sees the style
  (`loadout_style`, PowerComponent.loadout_styles). Equipping a weapon clears `kicks`; the save keeps "kicks". Why this over a
  separate radial toggle: loadouts already are the swap gesture, the bar already reasons per loadout, nothing new to learn.
  Debug: Shift+F10 also teaches it.
- **Stance** (scripts/npc/black_leg_moves.gd, BlackLegMoves; stance "black_leg"): light and upright, the left a little ahead,
  the hands open, loose and up a little (GUARD), the fist's springy bounce (StanceLife). **Nonchalance** (Black Leg tree,
  Guard, 10, mech `pockets_black_leg`; Player._recalc_stats sets `Humanoid.kick_pockets`, in HumanoidSync.FIELDS): the guard
  is hands in the pockets (POCKETS); every move starts and ends on `_guard()`, so the hands come out on the move's 0.06 s blend
  and go back in as it settles - no added delay.
- **Kicks**: the right leg's roundhouse authored once at a height k (chamber, strike, recoil) and mirrored for the left; the
  whole body yaws on the standing foot (pivot y + hips: ~1.5 rad turned over) and leans away (pivot z), the kicking side's arm
  thrown down and back, the other out ahead (t/weapons/black_leg_combo measures both). Combo (style "black_leg", REACH "kick"):
  bl_1 low left 8 / bl_2 mid right 11 / bl_3 high left 14 (breaker) / Handstand Spin 22 (move: down on both hands, legs
  split flat, two turns, knockdown, "kick_spin", then a walkover out over the front). Heavy **Guillotine Heel** (bl_heavy, axe
  kick: the leg straight up over the head, the heel down, 30, breaker, knockdown, "kick_axe"). Arrow Kick at a sprint (move:
  bl_rush, side-on flying kick, breaker, knockdown); Cyclone Heel in the air (move: bl_air turning flat with a leg out, the
  Buzzsaw's drop; `BlackLegArts.air_land`: down on a knee and a hand, a 3 m knockdown ring); the parry raises the lead shin
  (bl_parry; the held block is the same raised shin, the standing leg keeps the gait), a landed parry drops onto a hand and
  sweeps them down (bl_deflect, `BlackLegArts.parried`). Kicks don't sever.
- **Hands on the ground**: `BlackLegMoves.hands` (Humanoid._process, black-leg bodies only, after the arm solvers): PLANTS
  windows per action ([u from, u to, hands, latched]); a hand inside one is reached by IK to the floor under it (latched: kept
  where it touched down; the spins follow the posed hand along the floor). Handstand Spin (both), Mule Kick (both), Cartwheel
  Crescent (hand over hand, WHEEL_PLANTS), the deflect's sweep and Cyclone Heel's landing (one). Upside-down moves skip foot IK
  (INVERTED); `_finish_action` now also wraps the pivot's pitch (a walkover ends a turn round). Gotcha: animsheet's frames
  don't show the planted IK (the arms stay as keyed there); the in-game test and abilityshot do.
- **Tree** (SkillTrees "black_leg": Guard / Fire / Flow, element heat "bl": Searing Heel 16 / Red-Hot Leg 25): Shin Guard 3 ·
  Mule Kick 8 · Nonchalance 10 · Kick Back 20; Hailstorm Heels 5 · Cartwheel Crescent 10 · Last Course 30; Handstand Spin 2 ·
  Arrow Kick 4 · Cyclone Heel 6 · Galley Tempo 13 (passive) · Cook's Way 22 (Head Chef / Carver). Steps 30. Tab "BLACK LEG".
- **Techniques** (scripts/player_states/black_leg_arts.gd, BlackLegArts in TechniqueState._arts; their timings live in
  BlackLegMoves, which mustn't load BlackLegArts - it touches autoloads, and Humanoid loads BlackLegMoves): Mule Kick (your back
  to the aimed foe within 4.5 m, down on both hands, both heels at 0.42 s: 28 unblockable breaker, thrown clear), Hailstorm
  Heels (nine kicks off one foot at every height 0.09 s apart walking in, a full roundhouse at 1.08 s knocks down), Cartwheel
  Crescent (two cartwheels forward hand over hand, a ring hit every 0.12 s, the heel down at 1.15 s), Last Course (ult,
  untouchable: a spin on one foot heating the leg, the moment at 0.55 s, seven burning kicks driving in, a leap and the heel
  down at 1.95 s: 45 knockdown 6.5 m, a ring of crimson fire).
- **FX**: TREE_FX "black_leg" (white-hot core, cherry red edge, deep crimson accent; green 0.17 vs the axe's 0.5);
  `FX.heat` (white-hot sparks, fire licks tinted HEAT_TINT, a red flash light), `FX.hot_leg(body, right, secs)` (an additive glow
  over the shin and foot with crimson licks; on every kick once Red-Hot Leg is owned, on the techniques with the element, the
  whole ult), `FX.heat_ring` (Last Course), `FX.kick_swoosh` (BladeTrail `legs`: traces the shins). Before the element: plain
  rings and dust.
- **Co-op**: the stance and Nonchalance sync (stance, kick_pockets); actions mirror; every screen solves the planted hands from
  the same pose. Hits through hurtboxes / `_strike`, effects through Net.fx (hot_leg and kick_swoosh take the body by key).
  Learning and choosing are the captain's own (their progression and hands).
- **Per frame**: `BlackLegMoves.hands` on black-leg bodies - a dictionary lookup, and only inside a plant window one or two
  arm IK solves; `kick_pockets` is a guard lookup. Effects are one-shots (hot_leg: one capsule and one emitter for its seconds).
- Tests: t/weapons black_leg_combo, black_leg_moves, black_leg_tree, black_leg_learn; t/progression/tree_shape. Renders:
  tools/dev/out/bl/ (a_*/b_*/c_* animsheets: the kicks, heavy, handstand, mule, cartwheel; ab_last_course, ab_black_leg_heavy).
  Expect techtest/progtest/balancetest/uitest (a new tab), qoltest/storytest (Gus's dialogue), save tests (a new "kicks" key),
  nettest (a new snapshot field) and the loadout tests to want a look at the push.
## 2026-10-21: v1.18.3 shipped unstable; stable/unstable releases on GitHub and the site
- What: 1.18.3 (the five new weapon kinds, the stance pass, controller support) released as an **unstable** build after
  light testing (compile, smoketest, t/weapons, t/progression, t/input, t/combat, t/player, t/ui: 91 passed). No full
  suite run, nettest or perf gate: the next stable release owes those (docs/weapons_plan.md "Follow-ups after 1.18.3").
- How unstable works: `tools/release/UNSTABLE` present when a v* tag is pushed -> build-windows.yml publishes a GitHub
  **pre-release** (`prerelease:` / `make_latest:` from hashFiles). GitHub's releases/latest skips pre-releases, so the
  site's `/download` (`_redirects` -> releases/latest) stays on the last stable (v1.18). v1.18.1 and v1.18.2 were
  flipped by hand (`gh release edit v1.18.1 --prerelease`, `gh release edit v1.18 --latest`).
- Site: roadmap.json versions carry `"unstable": true` (roadmap.js filters them before building; `"here"` names the last
  stable); releases/index.html has an Unstable section (a download button per build, GitHub's per-tag zip URL) above a
  Stable section; home's banner and news/index.html list only stable posts (the 1.18.1 capital post is unlisted, still
  linked from the releases page). For the next stable release: delete tools/release/UNSTABLE, add its roadmap entry
  without the flag, set "here" to it, update the home banner and news list as usual.

## 2026-10-22: the skills menu's Captain tab as two pages (fork rows, Will star chart)

- Zach's picks from tools/dev/out/mock_captain (layout A and W). UI only: no tree data, save or balance change.
  scripts/ui/skill_map_screen.gd, `_draw_captain` and below. A strip under the tabs switches pages: C / W (Tab
  toggles; pad Y), a click on it too. `will_page`, `_first` (lowest fork row in view), `_rows` (rows the canvas fits).
- **Captain page:** the parchment level card (level, next fork, the per-level gains from `SkillTrees.GROWTH`, talents and
  milestones so far) and a spine with the talent forks as rows, levels rising: option 1's card left, option 2's right,
  an LV badge with OR between. Picked: gold with PICKED; its sibling dimmed; reached but unpicked: a coral dot. Milestones
  ("auto" nodes) sit as round dots in the gap below the row whose level reaches them, labels beside ("LV10
  QUARTERMASTER · GOT IT"); "YOU · LV n >" in the gap your level falls in, the spine gold below it. Selection ids
  `f:<talent node>:<option>`: up / down a fork (`_fork_nav`, scrolls in whole rows), left / right an option, Enter
  goes through the old `_act_split` (pick rules and the bunk swap unchanged); a mouse click selects, a second picks;
  the wheel scrolls. Opens on the lowest unpicked fork, scrolled to it.
- **The canvas is 640x360 at 1280x720 and 1920x1080** (PixelCanvas: whole-number scale, at least 360 tall), 800x450
  only at 1600x900: the mocks were drawn at 800x450, so card widths, heights (the longest description's lines) and the
  rows in view (4 at 640x360, 6-7 at 800x450) size to the canvas, and the Will chart's stars are fractions of its field.
- **Will page:** a diamond per Will (`WILL_AT`, dashed links `WILL_LINKS` up to Captain's Will), each passive a moon off
  it; won ones violet and glowing, unwon dim with the boss line from the desc's first sentence. The parchment card
  shows the selected star's (or moon's) Will, its effect chips (`CHIPS`: a few common effect keys, plus the skill it
  gives), its passive boxed with chips and its slot, and NEXT (the unwon Wills). Enter on a Will or its moon now puts
  the passive in the first free slot (`_slot_will`; refused before it's won); 1-5 on a moon still picks the slot.
- Tests: `t/ui/skills_captain_forks` (page switch by key and click, opening fork, fork and option nav, scrolling the
  top fork in, Enter picking a reached fork and refusing an unreached one or a change away from the bunk, Enter
  slotting a won Will's passive). Renders: skillmapshot's `_captain`, `_will`, `_captain40`, `_captain40_low`,
  `_captain1` (default 640x360; `800x450` arg for the larger canvas). Per frame: the menu only, while open.
## 2026-10-21: walk carry and guard pose fixes (1.18.4 batch, Zach's play)
- **Cutlass guard's free arm** (`Humanoid.SWORD_GUARD` arm_l y 2.3 -> 1.0, x 1.4 -> 1.15): the left fist up by the side
  at about shoulder-to-head height instead of the elbow and fist back behind the shoulder (world: 0.1 m behind the
  shoulder, 0.41 out). `SwordMoves.OFF_GUARD` (slash_r's reach start) moved to the new hand (-0.34, 0.17, -0.22).
- **Cutlass run carry** (`StanceLife.CARRIES` sword, sword_pistol, dual_sword mirrored): the arm hangs at the side (was
  swung back -0.55 behind the hip), the blade trailed back, down and out to the right with its flat rolled up to the
  camera behind. Straight forward from the game camera the old carry read as the sword dragged down behind the player;
  a diagonal showed it side on, which Zach liked; now forward shows that diagonal line too.
- **Polearm run/sprint carry** (`PoleMoves.RUN_GRIP`): port arms, both hands on the shaft (slide 0.5), slanted up across
  the front from the right hip to past the left shoulder (was one hand low at the side, head out ahead and down). The
  other option (one hand mid-shaft, slanted behind the back) needs the shaft shifted through the hand and its butt would
  sit in front of the stepping thigh; port arms reads cleaner from behind at PS1 resolution.
- Checked: hammer, greatsword and twin axes walk in their guards (no carry under a sprint), none trails behind.
- Tests: t/weapons/cutlass_carry (new: the guard's free hand, the forward carry's hand and blade), t/weapons/polearm_stance
  (the run check now wants both hands on the shaft, slanted up left, the head over the left shoulder); cutlass_combo,
  slash_dummy, polearm_moves/combo, draw_sheathe, quick_mid_swing, sprint, rig_drift pass. Expect fixtest/feat/stamtest
  (slash_r's reach start moved) and wieldtest (Corsair, twin swords' carry) to want a look at the push.
- Tool: guardsheet env GS_MOVE="x,y" (the travel direction). Renders: tools/dev/out/carry/before, it6 (guard), after.
## 2026-10-21: tooling window (after v1.18)
- crew_lib `Get-TestKey` reads the deps file's stamp with `[IO.File]::GetLastWriteTimeUtc` and its lines in a try, so a file another session deletes between the check and the read counts as "no deps recorded" instead of killing the run.
- compilecheck lints an autoload name (from project.godot `[autoload]`) used inside a `static func` in scripts/ or scenes/ ("STATIC AUTOLOAD file:line ... reach it through the tree"): a --script suite that names the class compiles without the autoloads. 30 files already did it (474 lines), so they are listed by file in `tools/dev/static_autoload_allow.txt` as a ratchet: new files fail, and an entry that matches nothing is reported. Reach the autoload with `(Engine.get_main_loop() as SceneTree).root.get_node("Net")` when a file is next reworked.
- nettest.ps1: each mode writes `net[-mode].host|client|watch.log` and `.deps` in tools/dev/out/logs, so modes can run at once (board + jam, board + chain pass together).
- forest_fauna and snow_wolves name the creatures they spawn (desert_fauna already did): a creature's rng is seeded by its node name.
- `Humanoid._rng` is seeded from the global rng (`randi()`): fixed per suite seed in tests, random in a live game (its seed is random at start-up).
- Known: r10test fails on main at "strafing (0.7071, 0.7071): the planted foot barely slides (1.64 m/s)" against a 1.6 limit, with or without the rng change (deterministic): from the stance pass (armed default stance); it stops the suite before the jump-side checks.

## 2026-10-21: the air walk, freefall tumble and air recovery (docs/v1_18_4_plan.md "Air step", "Freefall tumble", "Air recovery")
- **Air walk** (piece 1): Geppo's and Sky Walk's air jumps (action still named `double_jump`) are One Piece's air walk,
  not a somersault: `MovePoses._air_step` keys the knee driven high (held a beat), the foot stamped straight down onto
  the air while the other knee comes up, the arms pumping against the legs, upright (pivot eased in from wherever the
  body was, so a tumble rights into it). Each step takes the other foot (`Humanoid.air_foot`, flipped on the step's
  first pose; puppets flip theirs the same way). Out of SPIN_ACTIONS and GAZE_FREE; spec `sharp` 50. JumpState fires
  the ring, a mist puff ring and motes under the stamping foot at `MovePoses.STAMP_S` (0.15 s, when the foot lands in
  the pose), through Net.fx. Landing is still the kneel. Test: t/player/air_step (was double_jump: no flip, knee
  high, +1.2 m, alternating feet under Sky Walk). Render: animsheet `double_jump` at yaw 90 and 125. animsheet now
  poses the skinned arms (ArmBody._pose) per frame as well as the legs: before, every sheet showed the arms frozen.
- **Freefall tumble** (piece 2): `Player.freefall_from` (PlayerState.now_s) is set by every jump and air step
  (JumpState) and by FallState.enter unless it comes from JumpState (`{"from_jump": true}`), so an ability, attack,
  plunge or anything else that drops back into Fall restarts it. FallState: past `FREEFALL_TUMBLE` (3.5 s) with more
  than 3 m under you -> DownedState `{"tumble": true, "velocity"}`: a limp ragdoll (no muscles) with a head-over-heels
  spin (`TUMBLE_SPIN`) falling at the captain's own gravity (32 m/s^2) and top speed (`Ragdoll.fall_like`,
  `Player.MAX_FALL_SPEED` 34; knockdown ragdolls still fall at 9.8). The root rides the body vertically while it falls
  (camera follows), and the get-up waits for the landing. Landing: `Player.tumble_landed` = the usual fall damage
  (~85 from terminal speed) with no stagger (Downed's own get-up instead); in deep water the usual float-up. Jump in
  the tumble with an air step left: `Player.recover_in_air` (root to the body, its speed kept, the body eased upright
  from the sprawl over 0.25 s) and JumpState `{"air": true}` (the step's pivot keys in from the sprawl). At this
  gravity 3.5 s is a ~100 m drop (a 5 m drop takes ~0.6 s): tune `FREEFALL_TUMBLE` in play. Co-op: the ragdoll,
  recover and step mirror through Humanoid's net events like a knockdown. Per tick: one clamp loop over the 11
  ragdoll parts while a tumble is down, a ground ray in Fall only once past 3.5 s. Tests: t/player/freefall_tumble,
  freefall_reset.
- **Breakfall and Skyward Dash** (piece 3; Acrobatics Air branch, `ac_breakfall` "move" 12 and `ac_skydash` "move" 18,
  priced by kind like the rest). DownedState `_recover` on jump while the body is still in the air (not yet landed):
  a tumble with an air step left takes the step; otherwise the `breakfall` flag with the hips > 1.2 m over the
  ground (`_hips_up`, a ray from the hips: the root may already be on the ground under a flying body) rights you:
  `recover_in_air`, the `breakfall` action (MovePoses: a tuck rolling the pivot from the sprawl to level, then open,
  arms wide), a ring and a whoosh, into Fall. A knockback ragdoll without Breakfall ignores the press. Either recovery
  calls `Player.air_recovered`: with `skyward_dash`, `Player.skyward_dash` (cleared on landing) and
  `jumps_remaining += SKYWARD_STEPS` (2; JumpState treats any jump off the floor as an air step, since this can go over
  max_jumps). Fall/Jump: dodge with `skyward_dash` -> DodgeState `{"air": true}`: input's way or the camera's forward,
  level (vy 0), `AIR_DASH_DIST` 6.5 m in `AIR_DASH_DUR` 0.32 s on the dodge's burst curve, an afterimage, a ring
  and a whoosh, then Fall. With Sky Walk + Skyward Dash that's 6.5 m flat plus four air steps (~1.3 m each) to climb
  back to a deck. Tests: t/player/breakfall (no Breakfall: nothing; with it: upright in Fall, lands on its feet),
  skyward_dash (two extra steps, 6.4 m dash, level, once).
## 2026-10-21: the two points pools (1.18.4 batch, points rework piece 2)
- What: every node past a root is **bought**. Combat points (`Progression.combat_earned`: 2, then 2/1 alternating to
  Captain 10 = 16, 2 a level to 20 = 36, 3 to 30 = 66, 4 to 40 = 106) buy any weapon tree's nodes and the eaten fruit's
  (its level-1 powers still come free); Adventure points (a point a level any Adventure tree gains) buy Adventure nodes.
  A tree's level only gates (`buy_why`: "Needs Katana 12", a step needs the node it hangs on, the second element the
  first, "Needs 5 Combat points"). Prices: `SkillTrees.price` = PRICE / PRICE_ADVENTURE by kind + gate / 10, a step 1,
  or a node's own `"cost"` (so the movement/fists blocks add nodes with no price edits). The Captain's nodes (milestones,
  talents, Will) are unchanged. Numbers and why: docs/v1_18_4_plan.md "Preview: the numbers" (Zach's OK).
- Where: progression.gd (`bought`, `earned/spent/pool`, `buy/buy_why`, `can_spend` remembered per `_rev`, `respec_tree`
  for 100 + 40 x level gold at the bunk, `gift` for tests and tools, `master_all` buys everything and gifts the points);
  skill_trees.gd (`pool_of`, `price`); save_game.gd loads the power component **before** progression now (the bar
  decides what a migrated save buys back first).
- Saves: format 6 stores `bought`. Every load buys the saved purchases back in order (bar skills and slotted passives,
  then each tree's big nodes lowest gate first, the highest-level tree first, then steps) while the pool affords them;
  a format-5 save's owned big nodes go through the same path, so what doesn't fit is refunded. One banner after a
  migration, only if a pool can buy something.
- The stale prompts: the mastery toast said "+N points (K)" from the levels gained on every tree's level-up (Adventure
  trees level from jumps and dodges), and the HUD pulsed the hand weapon's own points forever. Now the mastery toast
  names what the level opens; "N Adventure/Combat points (K)" is added only to a level-up that earned points and only
  while that pool can buy something (`can_spend`); the skill bar's pulse uses the same test.
- Per frame: the skill bar asks `can_spend` (remembered until `_rev` changes; a recompute walks the found trees' nodes
  once) and, while it's true, `pool()` (a walk over the bought nodes and steps, under 100 entries).
- Tests: t/progression gate_and_buy, pools, prompts, buy_back (new or rewritten), versions_bunk (gold respec),
  refund_migration, acrobatics, stealth, life_mastery, passive_slots, tree_shape (every node priced); t/ship/seamanship;
  t/ui skills_loadout, skills_version_bunk. Suites edited, not run (prepush): progtest, balancetest, daggertest,
  wieldtest, powertest; renders skillmapshot and seamapshot buy their nodes.

- 2026-10-21 r10test strafe slide: two stance-pass causes. The run carry took the 45 deg forward diagonal (`StanceLife.carry_weight` travel < 0.9 rad), so the strafe's chest/hips went to the run's and the planted foot slid 1.64 m/s (was 0.93); it now stops at 0.6 rad (34 deg). The cutlass's side-on hips (`HIPS` 0.55) were only relaxed 60% at a walk, adding slide to the lateral strafe (2.49 m/s vs 1.85) and back-diagonal; `_stance_hips` now relaxes fully with `walk`. r10test's straight reference walks at 2.4 m/s (a carried run has its own chest). Limits unchanged.
## 2026-10-21: the skills menu slimmed (1.18.4 batch, points rework piece 3)
- What: trees show icons and names only. Gone from the tree: level numbers on nodes, the steps' "2/5" chips (now a pip
  a step under the node), the branches' "n OF m" counts. Gone from the card: the per-tree points chip and "ONE A LEVEL",
  the "Coming next" list and the always-on "How it grows" (now in the root's panel). What can be bought right now has
  a soft pulsing ring in the tree's colour. A variant is lit only once bought.
- The card (select panel) has the picked or hovered node in full: kind (a step's count), "NEEDS KATANA 12" (green when
  met, else with the level you're at), the price and what's left in its pool, what it does (a variant's two versions,
  the active one marked), and the one action (ENTER: BUY / the reason / YOURS / switch at the bunk). A hovered node
  also gets a one-line tip by the cursor (name, price, gate). Both pools are on the beam's plate
  ("COMBAT 6 · ADVENTURE 3", the coin keeps the level).
- At the ship's bunk the card shows "REFUND THIS TREE: N GOLD" for a tree with purchases: a first click asks (the price
  in the line), a second pays (Progression.respec_tree).
- Locked trees were already hidden (the rail, the chart and the Adventure list draw only found trees; the Driftfruit
  sign only with a fruit); skills_buy_node checks it.
- Per frame (only while the menu is open): `buy_why` for each drawn node, for the glow.
- Tests: t/ui skills_buy_node, skills_respec (new); the other skills_* and t/progression pass. Renders:
  tools/dev/skillmapshot.gd (its _variant shot hovers the iai upgrade for the tip and the card).

## 2026-10-21: fists redone as boxing, piece 1 (docs/v1_18_4_plan.md "Fists")
- **What:** the unarmed light combo is boxing now, each blow out of the last one's turn: jab (lead straight, the lead
  shoulder rolled over) -> cross (rear straight, the back heel turned, hips past square) -> lead hook (out of the
  cross's turn, the elbow up and out, the body swung through) -> rear uppercut (a dip, then the legs driven up; the
  tree's fourth-hit move, node id `u_round` / flag `mv_roundhouse` kept for saves, now named Uppercut; it knocks
  them down via LightAttackState cfg `"launch"`). The right-click is the **haymaker** (HeavyAttackState "haymaker",
  `fs_hay`): rocked back with the fist drawn up over the right shoulder and the left arm out measuring, then a long
  step in and the overhand over the top and down through them; breaker, knockdown, 30 damage, the unarmed ring/dust.
  The roundhouse kick and the flying kick are gone (black-leg keeps its own kicks).
- **Where:** `scripts/npc/fist_moves.gd` (FistMoves: GUARD, LEGS, every `fs_*` pose, the reach paths), reached from
  `Humanoid._action_pose` by the `fs_` prefix; `_guard()` "fist" and STANCE_LEGS "fist" point at it. ActionSpecs
  `fs_jab/fs_cross/fs_hook/fs_upper/fs_hay` (len, hit, chain, sharp 50, lead). The old jab/cross/hook/roundhouse/
  flying_kick poses and FIST_GUARD left humanoid.gd.
- **How it's built:** the body keyed (hips lead, chest turns through, head on the target, the off fist tucked to the
  chin), the punching fist on a **reach path** in the body's own frame (`follow` 0, `from_shoulder`: points are
  offsets from the punching shoulder, ~0.66 m = straight), so straights go out straight at the target ahead and the
  hook sweeps flat round the front; every path starts and ends on the guard fist's spot (AT_L / AT_R, measured from
  the keyed guard) so the hand leaves and rejoins the guard without a pop. A chest-frame (`follow` 1) try put the
  uppercut and the haymaker's fist behind the head: the bladed chest's yaw swings the frame too far.
- **Guard:** bladed orthodox, chin down, lead fist out at chin height, rear fist by the cheek; the stance pass's
  bounce kept (StanceLife.BOUNCE).
- **Tested:** `t/weapons/fist_combo` (guard shape, each blow lands on the dummy, the jab's arm reaches 0.65 m, the
  haymaker's cock over the shoulder and its damage). progtest's "unarmed light attack is a jab" check reads `fs_jab`.
  Suites expected to be touched: progtest, techtest, balancetest, stamtest (fist combo/heavy names and timings).
- Per frame: nothing new (one reach solve on the punching arm during a punch, as the cutlass's free hand).
## 2026-10-21: Sky Leap (docs/v1_18_4_plan.md "Sky Leap")
- **Nodes** (Acrobatics Air branch; **Acrobatics now goes to 30**, the other Adventure trees stay at 20, so it earns
  10 more Adventure points): `ac_skyleap` Sky Leap "move" 22 (`sky_leap`), `ac_hakilegs` Haki Legs, 3 steps hanging off
  it, gated at 23 (`sky_leap_steps`; steps have no per-step gates, so all three open at 23), `ac_heavenward`
  Heavenward "move" 28 (`heavenward`). SkillTrees.LEFT got a 7th slot for the Air branch's seventh big node.
- **SkyLeapState** (`scripts/player_states/sky_leap_state.gd`, node "SkyLeap" in player.tscn): Idle sends a jump press
  there while jump is still held and Sky Leap is owned. Released under `TAP` (0.2 s): JumpState `{"full": true}` (the
  jump fires on release, so variable-jump is off: a full standing jump). Held: the `sky_leap_charge` hold (deep
  squat, trembling), `FX.haki_legs` (a dark glossy sheen, metallic with a crimson rim, over both shins and feet: four
  MeshInstances under the shins sharing one material of their own that fades; a second call carries on from it), a
  `gather`, the haki sound, a dust puff ring every 0.3 s growing with the charge, a ring + glint at full (`CHARGE`
  1.2 s). Release: k = held / 1.2; height `reach().x * k` (25 + 5 a Haki Legs step + 20 Heavenward), forward
  `reach().y * k` at the apex (5 + 2 + 4), stamina `cost() * lerp(0.5, 1, k)` (40, Heavenward 50; refused = a plain
  jump). v0 = sqrt(2 g h) at the rise gravity (Player.gravity 20, no short-hop), the forward speed constant over the
  rise; the state rises itself (no air steps, attacks or tumble clock), and at the apex goes to Fall `from_jump` with
  `freefall_from` = now (the tumble's 3.5 s counts from the top; a 60 m fall takes ~2 s), the air steps left
  (`max_jumps - 1`) and, with Skyward Dash owned, the air dash.
- **Landing**: `Player.sky_leap_fall` (set on launch, cleared by the landing, a tumble's landing or swimming):
  `_on_landed` skips the fall damage and calls `SkyLeapState.crater` above the safe speed (puff ring, ring, debris,
  five seeded ground cracks off wood/water, rock_crash + thud, local shake); the body lands in the kneel
  (`_jkind` "leap", MovePoses.LAND_SECS 0.55); no stagger.
- **Co-op**: the holds mirror through Humanoid's net events, every effect through Net.fx (haki_legs takes the body).
- **Per tick**: nothing while not leaping; during a leap the state's own move_and_slide (as Jump/Fall). The sheen is 4
  small meshes on the leaping body only while it shows, no shadows.
- **Tests**: t/player/sky_leap (a tap is a 1.7 m jump; full charge 25.0/40.0/60.0 m up and 5/11/15 m forward with
  no nodes / Haki Legs x3 / + Heavenward; stamina 40/40/50; never Downed; no damage; lands on its feet).
  Render: animsheet `sky_leap_charge,sky_leap`. The fists' dive-punch height scaling is the fists agent's.

## 2026-10-21: fists piece 2, the Power branch (docs/v1_18_4_plan.md "Fists"; Zach's six pitches)
- **(a) Shoulder Throw is a counter, Heavy Landing extended.** The Grapple branch is **Power**. `hip_toss` (Shoulder
  Throw, node `u_hip`, ids kept for saves) is a guard skill now, like Riposte: a second with the hands open to catch
  (`fs_catch`, buff "riposte"); a blow caught in it comes to TechniqueState as `riposte_counter`, which a fist style
  turns into `shoulder_throw` (FistArts): a hitstop/slow beat, then the old carry-and-heave over the shoulder (the
  `shoulder_throw` pose) on whoever threw it; a boss or a non-light enemy gets a breaker straight right instead.
  **Heavy Landing** (`u_landing`, flag `throw_splash`, now `dmg_unarmed` +25%: all punches) also covers the haymaker:
  HeavyAttackState hands the haymaker's victims to `FistArts.haymaker_landed`, which lands each 0.45 s later where
  their body is (`landing`: ring 3.4 m, 22 damage, knocked flat, rock and a crack); without the node a throw still
  splashes 1.8 m for 10. TechniqueState's `_landing` (still used by Suplex/Giant Swing until piece b) calls it.
- **Where:** `scripts/player_states/fist_arts.gd` (FistArts, in TechniqueState `_arts`; reaches Net/CombatManager
  through the tree and FX's colours through a preload, so the static-autoload lint passes), FistMoves `fs_catch`.
- **Tested:** `t/weapons/fist_counter` (cast -> fs_catch; a grunt's blow does no harm and becomes shoulder_throw; the
  thrower and the grunt where he lands are hurt; uncaught it times out). techtest lost its hip_toss grab row.

## 2026-10-21: F9 crash report (not reproduced)

- Zach reported plain F9 crashing a debug run. t/progression/debug_level_up sends F9 to the light-stage player (unarmed, katana, fruit eaten, saving on, level 1 to the cap, every weapon tree to its top): no crash on main at 7815eeee. Kept as a guard; needs his console output or an F12 capture to go further.
## 2026-10-21: the skills menu clarity pass (1.18.4 batch, "Skill menu" row; Zach: "the skill trees are still not very clear")
- **Locked trees hidden:** visible_trees already kept unfound weapons, an uneaten fruit and an untaught black-leg off the
  rail, chart and A/D; the gap was the **Adventure sign**, shown empty before any Adventure tree was found.
  `SkillMapScreen.tabs()` now drops it (like Driftfruit) until one is found.
- **One header plate** (`_draw_header`, HEAD_H 32) across the top of every tree page, the Adventure page and the chart:
  the tree's icon, name, a "MASTERY n OF max" ribbon with its xp bar, and on the right both pools as big numbers
  (COMBAT / ADVENTURE POINTS), the pool this tree spends lit (coral with points, tan at 0). The beam's plate is back to
  "CAPTAIN · LEVEL n"; the card lost its title, ribbon and bar (it's only the picked node now); the chart lost its
  "trees found" slate (the header says how many weapons).
- **Every path drawn:** `SkillTreeDraw._link` draws an untaken path as a hollow grey channel (LINK_OFF 4 px with a dark
  2 px core) and a step's as a 2 px grey line (was 1 px DIM_LINK, invisible on the sky); taken paths are unchanged.
  `SkillMapScreen.links` records [from, to, taken] each draw for tests.
- Tests: t/ui/skills_hidden_trees, t/ui/skills_grey_links (new); skills_tabs finds Swimming first so Adventure shows.
  Renders: skillmapshot at 1600x900.
- **(b) Cannonball Fist (12) and Meteor Fist (18) replace Suplex and Giant Swing.** Nodes `u_cannon` / `u_meteor_fist`,
  skills `cannonball_fist` / `meteor_fist`. **Old saves are mapped, not refunded:** `SkillTrees.RENAMED` (u_suplex ->
  u_cannon, u_swing -> u_meteor_fist, same gates and prices) is applied as Progression.from_dict reads bought/owned,
  and `Skills.RENAMED` as PowerComponent.from_dict reads the bar. Stone Skin (`u_skin`) hangs on u_cannon. The
  suplex/giant_swing poses, specs, SPIN_ACTIONS/GAZE_FREE entries, TechniqueState's grab and the icons are gone
  (nothing else used them: no enemy or puppet plays them).
  - Cannonball Fist (`fs_cannon`, 0.8 s, reach path CANNON_REACH): drifts in on the target (aimed or nearest in 4.5 m,
    else refunded), chambered low by the hip, the straight at 0.29 s (34, breaker, unblockable, knocked flat); the body
    then flies 18 m/s down the line 9 m and everyone within 1.4 m of it is bowled over (18, knocked flat). Streak,
    punch wind, speed lines, dust along the line.
  - Meteor Fist (`fs_meteor` keyed in seconds -> `fs_meteor_land`): on the ground a hop (6 m/s), the fist raised high
    at 0.3 s, the overhand driven down at 0.42 s (18 m/s); cast in the air it hangs, then dives straight down at 26
    m/s. On landing: a 4.5 m shockwave (30, x1.25 within 2 m, unblockable, knocked flat), six cracks, rings, debris,
    a light. **Height fallen** (`Player.fall_top`: the highest y since the feet last touched ground, kept every tick in
    Player._physics_process; the dive's top is max(that, where it starts)): +2% a metre above 5 m, at most +50%
    (FistArts FALL_FREE / FALL_PER_M / METEOR_FALL_MAX). Look after Zach's reference (an honest rookie's big punch):
    orange-yellow fire on the fist (`FX.hot_fist` "fire"), dark four-point stars rimmed red (`FX.star_glint` dark),
    black-red crackle (`FX.bolt` dark), purple speed lines (`FX.speed_lines`).
  - New FX (fx.gd, by hot_leg): hot_fist (fire / galaxy, secs < 0 kept until freed), star_glint (bright or dark,
    stretchable into a flare), speed_lines, comet, light_pillar; bolt takes `dark`.
- **Tested:** `t/weapons/fist_power`, `t/progression/fist_rename`; techtest's rows now cannonball_fist/meteor_fist
  ("down") and its nobody-in-reach refund uses Cannonball Fist. Renders: tools/dev/out/fist_cannonball_fist.png,
  fist_meteor_fist.png. **techtest's "every skill has an icon" fails on main already** (the five new weapons'
  techniques have none yet: the new weapons' finish), so pieces land with `-NoTests`.
- Per frame: `fall_top` (one max a tick on the local captain); the techniques run only while cast.
- **(c) Diving Fist and Sea King Fist.** Diving Fist is the old Meteor Kick (node `u_meteor`, flag `mv_meteor_kick`
  and PlungeState mode `"meteor_kick"` kept for saves) with a punch: `fs_dive` (the fist drawn back by the ear, then
  the body pitched down behind it), landing `fs_meteor_land`; the meteor_kick/meteor_land poses and specs are gone
  (airtest reads `fs_dive`). **Sea King Fist arms the fist** (Zach's design, 2026-10-21): the ult (R) plays a 0.6 s
  charge (`sea_king_charge`), then `Player.fist_armed` = 8 s with the galaxy glow on the fist (`FistArts.keep_glow`,
  every screen through the snapshot flag `NF_GALAXY`) and a gold draining ring with the seconds on the HUD's ult slot
  (skill_bar `_draw_armed`). Attack (PlayerState.combat_input / air_attack_input / DodgeState) or R
  (PowerComponent.try_cast) lets it go: `FistArts.unleash` -> TechniqueState `sea_king_unleash`. Run out: half the
  ult back, "The fist cools". The unleash adapts: **ground** a straight (`fs_cannon` played at 0.82 s, the punch at
  0.3 s) with a huge red-orange cross flare, coloured stars, speed lines and the moment; a comet 16 m down the line
  (2.8 m wide, 60, struck as it reaches them) and the blast at its end (light pillar, orange dome, rings, debris,
  cracks, 5 m, 40); **air** (over 1.5 m up) a hang and a straight dive at 30 m/s, the blast where you land (6 m, 80,
  +2% a metre fallen over 5 m up to +80%, the radius up to +40%); **counter** within 60 ticks of a landed parry
  (`Player.parried_by/parried_tick`, set in the parry branch of _on_hit_received) the attacker takes 45 point-blank
  first; **out of a dash** the horizontal speed carries through the wind-up. Invulnerable from the unleash to the blast;
  the fist glows 3 s after (AFTERGLOW). Constants at the top of FistArts (ARMED_SECS, ARMED_REFUND, SEA_*).
- **Tested:** `t/weapons/fist_dive`, `t/weapons/fist_sea_king` (arm -> timer and glow -> run out, half back; armed ->
  in the air -> attack -> lands on the dummy; armed -> parry -> R -> the counter hits the grunt). techtest's
  sea_king_fist row went (it only arms now). Render: tools/dev/out/fist_sea_king_unleash.png (abilityshot takes
  `sea_king_unleash`).
- Per frame added: Player `fist_armed` countdown (one subtraction a tick while armed), `keep_glow` a meta check a frame
  per captain; the glow is one sphere pair and two small emitters only while armed.

## 2026-10-21: one walking pose in every direction (sword, axe); the Earthquake clears the head (Zach's play)
- **Walk:** the cutlass, corsair, twin swords and the axe walked forward in the run carry (blade trailing at the side)
  but on diagonals in the guard: jarring. `StanceLife.SPRINT_ONLY` stances now carry only at a sprint; walking at any
  speed or direction keeps the guard. Humanoid._locomotion keeps `guard_up` under a sprint for them, so the carry eases in
  from the guard over CARRY_IN (the gait's chest and head come back through `carry`), not from the run's arms (a snap).
  Daggers and the pistol keep their forward run carry.
- **Earthquake (ham_heavy):** the overhead raise put the hands at brow height right over the face with the haft
  running back through the head on the way up. The heavy now has its own grips (HammerMoves.QUAKE_GRIP: hands higher
  and further out front, haft steeper, the left hand lower on the haft to stay in reach; HEAVE_GRIP at u 0.14: the haft
  stood up in front of the face first). The air slam and the ultimate keep RAISE_GRIP. Slam and recovery unchanged.
- **Tested:** `t/weapons/cutlass_carry` (forward and diagonal walks give the same arms in the chest's frame, no carry;
  a sprint eases into it, the biggest hand step mid-blend), new `t/weapons/hammer_heavy_clear` (the haft's segment and
  the head's vertices vs the head sphere every tick of the heavy, all five designs: haft >= 0.087 m, was -0.07).
  r10test's strafe check uses a stance-less body, so it isn't affected. Renders: guardsheet `run` (cutlass, axe,
  corsair, dual_sword), animsheet `ham_heavy`.
- Per frame added: nothing (one extra `in` test on a 4-item array in carry_weight and guard_up).

## 2026-10-21: greatsword rework (Zach's play-test; 1.18.4 new weapons' finish)
- **Bigger, rounder arcs** (`scripts/npc/greatsword_moves.gd`): every gs_* move now goes through `_arc`, Humanoid._keys
  with the grip swung on arcs (the right hand round ARC_C, about the breastbone, its distance eased; the blade slerped
  the short way). The old straight blends cut chords through the body and shrank every swing. Far-apart blade
  directions get an authored mid key (`_mid`: _whip's body + its own grip) instead of a blend through zero.
- **The left hand lets go** on hit 1's follow-through (carried on over the right shoulder one-handed into C2, taken
  again on hit 2's wind-up), hit 3 (a wide one-handed backhand: the free arm points on the wind-up, flings back on
  the cut), Gale Turn and Tempest Turns (arm's length, the free arm out for balance), Running Cleave and Crescent
  Gale. Hit 2, the heavy and Guardbreaker stay two-handed. Free-arm poses FLING / OUT / POINT / PULL. The left hand
  now eases off and on over 0.1 s for the greatsword too (PoleMoves.hands' pole_lw; the hammer still snaps).
- **No blade through the body:** the guard's point a little further forward (it touched the left knee), loads out of
  the guard lift the point forward first (LIFT_GRIP, else it swept back through the left thigh), the heavy/charge/
  Guardbreaker go over the top through TOP_GRIP / an up-front key, returns from the right lower through the front
  (`_lowering`). Hit lengths 0.9/0.85/0.9 (were 0.8/0.78/0.84), chains after the follow-through (0.52/0.5/0.52).
- **Carry:** moving any way (StanceLife.ANY_WAY, over MOVE_ON 1.2 m/s) it's one-handed down at the right side, the
  point trailing low behind (CARRY_GRIP); a sprint lowers it to drag (TRAIL_GRIP). Guard <-> carry swings round
  through the front (PoleMoves._round_front: the heading never wraps through straight back), not down the legs.
- **Sparks on the point:** scrape() now runs after the grip is solved (it read last frame's blade, ~0.15 m behind at a
  sprint) on the interpolated transform, at the point (or where the blade dips under the feet), only within 0.12 m.
- **Trails:** specs' swoosh windows moved with the new keys (launch to end of follow-through); Guardbreaker draws the
  real blade's trail over its rise and its crush (it had none).
- **Tested:** new `t/weapons/greatsword_clear` (blade guard-to-point segment vs chest/head/thigh/shin capsules, every
  frame of the chained combo, charge+heavy, rush, Guardbreaker, Crescent, Tempest, deflect: closest 0.04-0.27 m, was
  down to -0.09 on 8 of 11; the hand out >= 0.5-0.6 m on the big swings, was 0.39-0.47), new `t/weapons/greatsword_carry`
  (forward/back/strafe carry the same, sprint drag, sparks within 0.15 m of the point: 0.08), greatsword_combo/moves.
  Renders: animsheet gs_1..gs_rush (`tools/dev/out/gs_before_*`, `gs_after_*`), guardsheet walk greatsword.
- Per frame added: the grip's arc (two slerps) while a gs_ move plays; an atan2/asin steer only while the blade is
  turned far round between grips at rest.

## 2026-10-21: unarmed polish (Zach's play-test of the fists and black-leg)
- **Kick and punch loadouts** already worked (taught black-leg; in the bag, I, click the empty main-hand slot to
  switch fists/kicks; that's what the loadout in use keeps; X onto the next loadout sets it up with what's in your
  hands, click the slot again there). Fixed: a swap carried the combo's place over (fists' jab, then X, the kicks
  started on bl_2): `Player._apply_loadout` resets the combo. The new-loadout toast names the hand slot once
  black-leg is known. Test `t/weapons/kick_loadouts` sets it up that way and swaps both ways.
- **Handstand Spin** (black-leg's fourth, `bl_4`; the fists' old roundhouse path is gone, their fourth is the
  uppercut): 0.95 s (was 1.1; hit, trail and chain are in u so they scale together: hit = swoosh = the spin's
  window). The legs' plane is tipped up to `BlackLegMoves.SPIN_TILT` (0.24 rad, eased in/out over the spin) with its
  direction held against the turn and wandering (`SPIN_PRECESS` -0.3 turn per turn): pivot x/z get
  `tilt * cos/sin(dir)`, the y spin stays unwrapped for the smoothing. Steerable at a creep: LightAttack's per-hit
  `"steers"` (m/s at full stick, `STEER_SPIN` 1.3) is the velocity target instead of 0 until the chain opens.
- **Fist-stance jumps:** the air pose and MovePoses' jumps/landings kept the right arm at the guard whenever
  `armed`; now only with a weapon out (`Humanoid._weapon_out()`: armed, stance not fist/black_leg), so a jump with
  the fists up is the plain jump.
- **Readying/dropping the fists** (fists and kicks): `fists_up` (0.42 s, swaps 0.3) and new `fists_down` (0.4 s;
  was the blade's hip sheathe, one arm): both arms thrown out ahead and wide a little below the shoulders
  (`Humanoid.FIST_CHAMBER`), the chest squared over the stance's turned hips (`_square`), then up together
  (`FIST_RAISE`) into the guard, or down to the sides.
- **Tested:** new `t/weapons/kick_loadouts`, `black_leg_spin` (slope of the feet's line -0.18..0.26, high-foot bearing
  0.89 rad apart between turns, 1.3 m/s held forward), `fists_ready` (chamber hands mirrored within 0.1 m; stance jump
  hands equal the plain jump's); black_leg_*, fist_combo, draw_sheathe, loadout_swap. Renders `tools/dev/out/unarmed/`
  (fists_00, jumps_00/01, spin_00). Per frame added: nothing new (a few trig calls in bl_4's pose while it plays).
## 2026-10-21: cutlass sprint and block (Zach's play-test)
- **Sprint** (`StanceLife.CUTLASS_RUN`, cutlass, corsair; twin swords mirrored): the sword arm pumps bent in front of the
  chest and the blade is held steady up and back past the right shoulder (new CARRIES flag `steady`: the wrist takes the
  shoulder's pump back out, so the blade keeps one angle to the chest; 0.03 rad over a stride). Was trailed down behind
  the hip and turned with the run ("wonky, all down behind"). A low-forward "ready" option was rendered too: from the game
  camera the blade was a stub by the hip, so up-and-back it is. Gotcha: hand_r's z is a roll about the blade (no tilt);
  the blade leans out with the wrist's y. The axe's over-the-shoulder carry is unchanged. Walk -> sprint still eases from
  the guard over CARRY_IN (largest hand step 0.065 m a tick).
- **Block/parry** (`SwordMoves.BLOCK`, `sw_parry`, `sw_deflect`, `brace`; ActionSpecs.PARRIES "sword"): the blade
  braced across the body, hand low right, point high left, edge out to the front, the free palm on the flat (both hands
  by IK each frame after the pose, in the chest's frame, weighted by the action's time: `brace_w`); the held block sinks
  over a bent front knee (Humanoid._locomotion, less while shuffling); a landed parry's deflect shoves the blade 0.16 m out
  off the front foot. Parry windows and timings unchanged. sword_pistol keeps the generic block (its off hand holds a
  gun). The boss's roar plays "parry" with a cutlass, so it now braces too.
- Tests: `t/weapons/cutlass_carry` (blade steady across 60 ticks of sprint, up and back, clear of the head), new
  `t/weapons/cutlass_block`; t/combat cutlass_combo, slash_dummy, t/fx/blocks, t/combat/impact_sounds pass. Expect
  wieldtest (twin swords' and corsair's carry) and grunttest/fixtest (parry) to want a look at prepush.
- Renders: tools/dev/out/csprint/{before_a,optA,optB}/sheet_sprint_*.png (guardsheet sprint), tools/dev/out/cblock/f2_*,
  k2_* (posebench front/back; one view per run: the tool's later views catch the camera mid-move).
- Per frame added: nothing new while sprinting (the same carry lerps); the brace (three reach_hand IKs and a slerp)
  only while a cutlass block, parry or deflect plays.
- t/weapons/fist_sea_king hardened: the stage grunt is disabled until the parry steps (it reached the airborne captain:
  Stagger), and the air unleash is polled up to 20 ticks for Technique/Plunge instead of a fixed 4.

## 2026-10-22: the weapon mastery pass, the axe (awakening resumed, the Bearded Guard)
- **Resumed** the paused axe pass (docs/axe_polish_plan.md): piece 1 (b5ecb5d: the combo on swing paths, AxeMoves, the
  drawn iron crescent, DrawnFx) back by reverting its revert; DrawnFx reaches Net through the tree (the static-autoload lint).
- **The drawn fire awakening** (Progression.elemental("axe")): `BladeEmbers` (scripts/game/blade_embers.gd, the BladePetals
  pattern: two crossed sheets of ember_trail.png off the bit's edge, one shared stepped material, 5 world-space cinders;
  Player NF_EMBERS 128 for puppets). `FX.elem_hit("axe")`: ember_slash + ember_cloud + cinders; `FX.element("axe")`: drawn
  cinders (and a gout of ember_cloud from 8 up), so the finisher's crack, Skybreaker's line, Earthsplitter's line and the
  techniques' `_spray` are drawn. The whirlwind heavy lays a drawn slash along the bit each turn (HeavyAttackState
  "drawn"; the fixed spin arc went); Skybreaker's dive is a drawn slash, its landing a fire crescent. `FX.drawn_arc(kind, ...)`
  (katana_arc for any drawn kind): Maelstrom's turns are drawn crescents round you at three heights (the geometry vortex
  went) and a flat ring of it at the burst; the thrown axe leaves a drawn crescent of its spin every 2 m; Earthsplitter's
  bite a standing crescent; Berserk's roar a ring of fire puffs (awakened).
- **The mastered guard** (every weapon gets one, docs/v1_18_4_plan.md "Mastered guard"): `Humanoid.guard2` (synced in
  HumanoidSync), `MasteredGuard` (scripts/player_states/mastered_guard.gd): the tree's node `guard2_<tree>`, a double-tap of
  block (two parry presses within 0.32 s, InputBuffer.pressed) toggles it any time on foot, the pick per tree in
  Progression.guards (saved). The axe's is the **Bearded Guard** (Zach's pick of two, 2026-10-22; Brute 15, a_guard2): square,
  choked up two-handed across the front, the head up past the left shoulder (opened so the bit shows from the game camera).
  Its grips (guard, a two-handed haft block, port-arms sprint) are held by PoleMoves.hands from AxeMoves.GRIPS2; its body
  AxeMoves.GUARD2 / LEGS2. The combo's first key already sits at its right hand, so the hack comes straight out of it.
- **Tools:** guardsheet rows `<weapon>2` (a mastered guard), env GS_AURA=1 (the awakened auras). Renders:
  tools/dev/out/axe_guard2/ (the candidates in candidates/), tools/dev/out/axe_awake/ (combo, heavy, maelstrom,
  earthsplitter, auras).
- **Tests:** t/weapons/axe_guard, t/fx/embers, t/combat/axe_slash. Per frame added: BladeEmbers steps one shared material
  once a frame while an awakened axe is drawn; nothing else per frame (MasteredGuard.on is a cached stat read).
- Open: Skyfall Smash and War Cry (the axe plan's piece 4) are the next axe piece; the aura is small when the axe hangs
  low in the brawler's guard (bigger from the Bearded Guard).
- Skill icons for the polearm, hammer, twin-axe, greatsword and black-leg techniques (20, 24 px, each tree's FX.TREE_FX
  colours) from `gen_technique_icons` (`py tools/texture_gen/gen_psx_textures.py technique_icons` regenerates only those);
  techtest's "every skill has an icon" passes again, t/ui too.

## 2026-10-22: the Adventure trees' moves, piece 1: Roll / Sidestep and Afterimage (docs/v1_18_4_plan.md "Wave 2")
- **Nodes** (Acrobatics Dodge branch): `ac_dodge` "Dodge Style", a variant at 7 (Roll `dodge_roll` / Sidestep
  `dodge_sidestep`, both owned once bought, picked at the bunk), `ac_afterimage` Afterimage "move" 18 (`afterimage`).
  Prices by kind (variant 2+0, move 1+1).
- **DodgeState** `mode`: "dash" (no node, or the air dash / a logia), "roll", "sidestep".
  Roll: turned into the roll (the one dodge that doesn't keep facing the camera), `ROLL_DIST` 4.6 m in `ROLL_DUR` 0.5 s
  (held speed, then eased off as you come up), untouchable `ROLL_IFRAMES` 0.34 s (+Swift Step/Hang Time), action
  `dodge_roll` (MovePoses: dive onto the shoulder, tucked over in one keyed turn of the pivot to -TAU, wrapped to 0 at
  the finish, up into a crouch, standing), a dust puff when the back meets the ground.
  Sidestep: facing kept, `SIDE_DIST` 2.1 m in 0.22 s, untouchable 0.18 s, 70% of the dodge's stamina
  (`Player.dodge_cost`), attacks out of it after 0.1 s, action `sidestep` (a boxer's slip: tipped and dropped off the
  line over the lead leg, hands up or the weapon at the guard). Slip: while untouchable, a foe's hitbox active within
  2.8 m = "Slipped!" (glint, float text, a 0.05 s hit-stop) and the PowerComponent buff `slipped` (1.2 s): the next
  `Player.melee_hit` is a sure crit and spends it.
- **Afterimage**: a dodge on the ground with the node, once every `DECOY_EVERY` 6 s, sends `Net.fx("decoy")`:
  `Decoy` (scripts/combat/decoy.gd, group "decoys") is a pale unshaded copy of the body's meshes standing 1.6 s (held,
  then flickering out). On the host it calls `lure(decoy)` on enemies within 7 m: a blade `PirateGrunt` fighting that
  decoy's captain (ALERT/CHASE/CIRCLE/CLOSE/WIND) aims at `decoy.spot` instead (its to_p/dist/nav; no attack token
  needed, cooldown cut to 0.1), and once its swing is 0.24 s in within reach it sends `Net.fx("decoy_break")`: the decoy
  shatters (flash, ring, sparkle) on every screen and the grunt goes back to the captain. Other enemies ignore decoys.
  Co-op: the dodge and its poses mirror as before; the decoy is made by Net.fx on every screen, so the host has the
  guest's decoy and lures its own grunts.
- **Icons**: tree nodes without a skill can carry an `icon` (`SkillTrees._icon`, also on a variant's version; read by
  `SkillTreeDraw.pic`): `skill_move_*.png` from `gen_psx_textures.py moves` (`gen_move_icons`; all twelve Adventure
  move icons of this batch).
- **Per tick**: the sidestep's slip check walks the "enemies" group while it's untouchable (0.18 s); a decoy's
  `_process` (an alpha) for its 1.6 s; a lured grunt's few vector ops. No new meshes beyond the decoy's copies (no
  shadow, visibility range 60 m).
- **Tests**: t/player/dodge_styles, sidestep_slip, afterimage. Render: animsheet `dodge_roll,sidestep`.

## 2026-10-22: the weapon mastery pass, the katana's variant moves (Side Step, Twin Waves, Falling Moon)
- **The tree** (skill_trees.gd): Iai Counter, Wind Severer and the air attack are variants now (docs/progression_plan.md's
  katana draft): k_counter (Draw Cut = iai_counter / Side Step = side_step, 8), k_wind (Towering Wave = wind_sever, 5 /
  Twin Waves = twin_waves, 18), k_arc "Air Cut" (Crescent Arc = mv_air_slash, 7 / Falling Moon = mv_falling_moon, 15). The
  node ids are kept, so an old save owns the variant with its first version active (the old node); prices stay the old
  nodes' (`_variant` returns the node, `["cost"]`). Switched at the ship's bunk like every variant.
- **Side Step** (TechniqueState: the iai guard, `_guard_id`): the caught blow meets an afterimage; you're out at the
  attacker's side (the camera's side, `_blink_side`, a streak; a line of cloud and petals awakened), then the same
  unblockable drawing cut. **Twin Waves**: Wind Severer's rising cut, then the kesa out of its top (katana_r at 0.42 s): a
  wave off each (0.3 / 0.72 s), sent from 1.2 m either side to cross 7 m ahead, 26 each (`_twin_wave`).
  **Falling Moon** (PlungeState "falling_moon", once per jump; `air_move` picks it for the katana): a spring up, the blade
  raised, one forward turn with it held out (KatanaMoves.moon; the drawn slash along the blade draws the full moon),
  a dive, then down on one knee (moon_land) and a crescent of the drawn strip run 5 m along the ground ahead
  (katana_line; cloud and petals awakened) that knocks everyone on it flat (a box like Skybreaker's line).
- Icons: skill_twin_waves, skill_side_step, skill_falling_moon (gen_psx_textures.py techniques).
- Test: t/weapons/katana_variants. The mastered guard's candidates (hasso / waki) are in KatanaMoves for Zach's pick
  (`preview`; not on a node yet).
## 2026-10-22: the Adventure trees' moves, piece 2: Moonstep and Crash Landing
- **Nodes** (Acrobatics Air branch): Featherfall became the landing variant `ac_feather` "Landing" at 15 (same id, so
  a save that bought Featherfall owns the variant with Featherfall active): versions `ac_featherfall` Featherfall
  (`featherfall`, as before) and `ac_crash` Crash Landing (`crash_landing`). `ac_moonstep` Moonstep "move" 20
  (`moonstep`), between Skyward Dash and Sky Leap; SkillTrees.LEFT got an 8th slot for the Air branch.
- **Moonstep**: dodge in mid-air (Jump or Fall; after Skyward Dash's air dash, which takes the dodge first while it's
  up) -> `PlayerState.wants_moonstep` (owned, not used this jump: `Player.air_uses["moonstep"]`, cleared on landing,
  `MOON_COST` 18 stamina) -> JumpState `_moonstep` (Fall sends Jump `{"moon": true}`): vy = sqrt(2 g 4.5 m), no
  variable jump, no air step spent, the freefall clock restarted. Action `moonstep` (MovePoses: both knees snatched up,
  both feet stamped straight down together, arms flung overhead and the body stretched, then one knee up, arms wide);
  at `MOON_STAMP` 0.13 s a pale crescent ring under the feet, a wider ring, a mist puff ring, motes and a streak down,
  the thump, a light shake.
- **Crash Landing**: `Player._on_landed` above `FallState.CRASH_SPEED` (16 m/s, a ~4 m drop) with the flag, on foot,
  not plunging/swimming/downed: `FallState.crash(speed)`: `_fall_damage(speed, 0.5, false)` (half, no stagger; the new
  k/reel arguments), action `crash_land` (snapped in: one knee and the left fist to the ground, head up, the right arm
  flung back, held, up), a puff ring, a ring, debris, an impact and four seeded ground cracks off the fist (not on wood
  or water), rock_crash + thud, shake; a knockdown wave (10-30 x damage multiplier, radius 2.6-4.6 m, knockback 6-11 by
  the drop) through the enemies' hurtboxes (Hurtbox.take_hit, so a guest's lands on the host). Sky Leap's crater
  still takes precedence.
- **Per tick**: nothing new while not doing them (one flag read in Jump/Fall when a dodge is pressed).
- **Tests**: t/player/moonstep, crash_landing (its grunt's physics process off, not the node: a disabled node's
  hurtbox leaves the physics world). Render: animsheet `moonstep,crash_land`.

## 2026-10-22: the Adventure trees' moves, piece 3: Defense (Perfect Parry, Guard Style)
- **Nodes** (skill_trees.gd): `df_clean` Clean Parry now carries `clean_parry`; variant `df_perfect` "Perfect Parry" (16,
  Parry branch): Disarm (`parry_disarm`) / Shove (`parry_shove`); variant `df_guard` "Guard Style" (7, Guard branch):
  Rolling Guard (`rolling_guard`) / Planted (`guard_planted`).
- **Perfect parry**: ParryState `PERFECT` 0.12 s after the guard goes up (needs `clean_parry`, a melee blow, an attacker
  with `perfect_parried`) -> `PirateGrunt.perfect_parried(player, how)` on the host (`Net.forward`, `HOST_CALLS`): clean =
  2.4 s stagger (a plain parry 1.5), shove = knockdown, disarm = blade gone 7 s (it can't guard, a spare after; the
  "disarm" net event shows the flung blade, `FX.flung_weapon`); blade grunts only, never bosses. Flash, ring, "Perfect!"
  text, +10 Defense life; actions `parry_disarm` (blade flicked overhead), `parry_shove` (palm shove).
- **Guard style** (BlockState): Rolling Guard, a dodge while blocking is a 0.42 s, 3 m roll inside BlockState (60% of a
  dodge's stamina; `rolling()`); frontal blows still glance off mid-roll. Planted, `body_model.planted` (HumanoidSync
  FIELDS, `guard_block` uses MovePoses.planted): blocks cost 0.7x, no push-back, half-speed shuffle.
- **Per tick**: nothing new.
- **Tests**: t/player/perfect_parry (hitstop slows the clock, so the late parry sets the state's timer instead of
  waiting), t/player/guard_styles. Render: animsheet `parry_disarm,parry_shove,guard_roll,guard_block` (the planted
  pose isn't in the sheet).
## 2026-10-22: the weapon mastery pass, the mastered guards (katana, cutlass, dagger, dual wield, twin daggers) and the drawn blades
- **Guards** (Zach's picks from posebench sheets; each at its tree's Guard branch, mastery 15, toggled by a double-tap
  of block like the axe's): katana **Waki Guard** (k_guard2), cutlass **Easy Guard** (s_guard2; the free hand on the
  sash by IK, SwordMoves.easy), dagger **Hidden Knife** (dg_guard2; the knife hand at the back of the right hip, a little out from the body, its point out
  past the right hip), twin daggers **Viper** (dd_guard2; keyed: sunk low and side on, the right dagger reared up by
  the face point down, the left low ahead; the first guard named Low Cross), dual wield **Wings** (d_guard2; keyed: chest forward over a crouch, both arms swept back, the
  blades back and a little down). One-hand guards are held by PoleMoves.hands from their GRIPS2 only standing
  (ONE_HAND_GUARDS: the weapon's own parry, block and jumps play as always); a guard with no grips (two blades) is keyed.
  `Humanoid.MASTERED` maps a stance to its moves file (guard(h), legs(h), grips2(h)); a mastered guard drops the
  side-on hip turn (StanceLife.HIPS).
- **Hangs:** the katana's scabbard hangs well down at the back of the hip (SAYA_HANG; under the Waki's turned chest,
  SAYA_HANG_WAKI by the guard's weight); a dagger's sheath is hung each frame from the hips (SHEATH_HANG) instead of the
  chest, so a crouch's lean no longer stands it out stiffly from the hip.
- **The drawn blades** (`tools/texture_gen/gen_drawn_fx.py`: one generator, a palette and a decoration per element):
  dagger shadow, dual wield twin currents, twin daggers venom, corsair powder (and gold and gale made for the pistol and
  fists). PetalRibbon LOOKS/CLOUDS for the four (steel plain), the off hand's blade (`left`); `DrawnFx.blow` picks the
  cutting hands (HANDS) and stabs (THRUSTS) by move; the combos and heavies lay them. `BladeAura` (scripts/game/
  blade_aura.gd): the tree's strip along each drawn blade, one shared material per tree; Player NF_AURA (256).
  FX.DRAWN: an awakened hit plays the element's slash and a ring (the old material with flipbooks off).
- Tests: t/weapons/katana_guard, cutlass_guard, dagger_guard, dual_guard; t/fx/drawn. Per frame: the auras step one
  material per tree once a frame; `_hang_sheaths` sets at most two sheaths' bases; MasteredGuard.on is a cached stat.
  Renders: tools/dev/out/guards2/, picked/, *_guard2/ (candidates), drawn/ (abilityshot combos), in the side worktree.

## 2026-10-22: the polearm's finish (new weapons' techniques, piece 1)
- **Thunder Javelin** (Reach 12, 4 pts; 20 energy, 7 s; PoleArts `_javelin`, pose `pole_javelin`): at 0.26 s the spear
  is hurled at the enemy you face (else the reticle) as Projectile kind **"javelin"**: 36 m/s point-first down 16 m
  (stops at a wall), pierces (breaker, ranged), a 0.18 s beat quivering, then yanked back to the right hand butt-first
  on a crackle of lightning (a bolt from hand to spear every 0.07 s) cutting the line again at 70%. With the storm
  awakened a bolt drops on each one it pierced (8 more, Net.fx from the thrower's machine). The projectile hides the
  held spear itself, so it's hidden on every screen while it flies.
- **Windmill Guard** (Guard 14, 4 pts; 18 energy, 8 s; `_windmill`, poses `pole_windmill` + `pole_lunge`): held (the
  slot's key, `TechniqueState._key_held`; tests and abilityshot force `"hold": s` / AB_HOLD) 0.3-1.5 s, the pole spun
  one-handed by its middle in the frontal plane (PoleMoves.WINDMILL_SPIN 18 rad/s, shaft slid 0.45 m through the hand)
  walking at 45%: `is_parrying` plus a "bat_shots" buff (`Player.parries_shots`) turn blows and shots from the front
  only (Player._on_hit_received skips the parry from behind while it's on); every 0.15 s anyone within 2.6 m ahead is
  clipped (4) and shoved out. Release: a 0.55 s lunge, an unblockable 26 cone at 4.8 m. exit() clears is_parrying and
  the buff for every technique.
- Polish: Hundred Thrusts' streaks start at the spearhead; Dragon Sweep in a wide horse stance, two turns from 0.2 to
  0.95 s with the hits at each turn's end (0.58, 0.95); Vaulting Strike plants the point and launches at 0.14 s (dur
  1.14, strike 0.54); Raijin's Wheel's overhead spin one turn at 21 rad/s with its own blade trail, and
  `_spin_hits(..., arc = true)` drops the flat spin disc (the blade_swoosh is the trail).
- Per frame/tick: the javelin projectile (one ray + a sphere query a step, a streak every 1.6 m, a bolt every 0.07 s on
  the way home) only while in flight; Windmill Guard's clip query every 0.15 s while held. Nothing idle.
- Tests: t/weapons/thunder_javelin, windmill_guard, polearm_tree (six techniques). Renders: tools/dev/out/pole/ in the
  new-weapons-finish worktree (jav_/javc_ abilityshot, wm_ windmill, as_/wmf_/pol_ animsheets).

## 2026-10-22: the hammer's finish (new weapons' techniques, piece 2)
- **Cannonball Swing** (Weight 12, `hm_drive`, 4 pts; 20 energy, 7 s; HammerArts `_drive`, pose `ham_drive`): a golf
  drive, contact at 0.5 s (stepping in to 1.8 m). The blow is unblockable and breaks wind-ups. A light foe
  (`FistArts.throwable`) is thrown with the new enemy call **`launched(v)`** (pirate_grunt, scuttlebug, creature; in
  `Net.HOST_CALLS`, so a guest's launch is run by the host), at DRIVE_LAUNCH (12.5 along, 6.5 up). It's a real ragdoll
  on every screen and flies about 8-10 m. A virtual ball runs down DRIVE_LINE 10 m at the along speed and knocks flat
  everyone within 1.7 m of it (14). A boss or anything heavier takes a 2.2 s stagger instead.
- **Anvil Counter** (Iron 14, `hm_anvil_c`, 4 pts; 16 energy, 6 s; `_anvil`, poses `ham_anvil` + `ham_rip`): the head
  is planted at 0.16 s and `is_parrying` stays on for 1 s. The first parried melee blow (`Player.parried_tick` from the
  cast's tick on) gets a ring-off (rings, sparks, a low parry note), and the attacker reels through their own
  `parried()`. Then a 0.62 s rip: at 0.16 s the head comes up into them (28, unblockable, knocked down) with
  `quake_fx` at your feet, which also knocks down everyone else within 3 m (10). If nothing comes, half the cost comes
  back at 1 s. exit() clears is_parrying (as for every technique).
- Polish:
  - Skullcracker hops at 4 m/s, timed to land at SKULL_AT 0.46. The blow lands on landing (or at 0.52 at the latest)
    with the impact at the real head, then the head goes into the ground at 0.6 (`thud`).
  - Rolling Quake's three blows are now: a flat sweep into the ground at the left; a backhand uppercut looped over
    the right shoulder into the right; a real hop (3.4 m/s at 0.84) and the overhead on landing.
  - Cyclone Crusher passes `arc = true` (no flat spin disc). Its head orbit tilts with the turn (rising behind,
    dipping in front), so the three turns read.
  - Head trails (`blade_swoosh`) on Skullcracker, Rolling Quake, Cannonball Swing and the rip. Titan's Fall was
    checked by code: the landing triggers on the floor and the hits fire there; unchanged.
- Earthquake for a guest (code path): `HammerArts.burst` hits through `Hurtbox.take_hit`, so `Net.route_hit` sends
  the wave to the host with the guest captain as the attacker. The blow's own target is excluded through
  `sword_hitbox.hit_targets`, which also records hits that were routed away. Nothing there needed fixing.
  t/weapons/earthquake_wave covers it offline (the wave reaches a grunt behind you once, through take_hit, by the
  captain, knockdown + breaker, and survives hit_pack). nettest runs the real guest at prepush.
- Per frame/tick: Cannonball Swing's bowl query (one sphere) per tick only for the ~0.8 s the ball flies; nothing
  idle. Anvil Counter compares an int each tick of the brace.
- Tests: t/weapons/cannonball_swing, anvil_counter, earthquake_wave, hammer_tree (six techniques). abilityshot
  `AB_STRIKE=s` lands the nearest grunt's blow on you then. Renders in the worktree: tools/dev/out/ham/ (drive_, anv_,
  cyc_ abilityshot; as_00_* animsheets).

## 2026-10-22: the twin axes' finish (new weapons' techniques, piece 3)
- **Ravens' Return** (Reaver 12, `dx_ravens`, 4 pts; 22 energy, 8 s; DualAxeArts `_ravens`, pose `dx_ravens`): both
  axes cocked back over the shoulders, thrown at 0.24 s (DualAxeMoves.RAVENS_THROW) as Projectile `raven_r` / `raven_l`
  (shown only, replicated like the javelin; the held axe in that hand is hidden while it flies). Each runs
  `Projectile.raven_offset`: a loop out on its own side RAVEN_W 4.5 m, RAVEN_L 10 m ahead where the two cross, home on
  the far side in RAVEN_T 1.2 s, eased into the moving hand over the last 30%. The cuts are the state's
  (`_raven_sweep`): everyone inside the loops' ellipse (plus 1 m) is cut once as the tips pass their depth on the way out
  (16) and again on the way home (x0.7), ranged + sever + unblockable (they come round from the side and from behind),
  pushed away from the axe on their side; frost: ice chips
  (`_spray`). Caught at 1.44 s. A blow that flinches you while the axes are away ends the technique (the axes still
  fly home, but the homeward cuts are lost), like any technique without armour; t/weapons/ravens_return turns your
  hurtbox off for that reason (it flaked under load when the cut grunt reached you first).
- **Raider's Haul** (Hook 14, `dx_haul`, 4 pts; 20 energy, 8 s; `_haul` / `_circle`, poses `dx_haul` / `dx_circle`):
  the one in front (3.5 m). Light (`FistArts.throwable` + `launched`): `grabbed` at 0.16, carried by `_carry` round you
  at HAUL_ARM 1.9 m along `DualAxeMoves.haul_turn` (the same eased angle the pose's pivot spins by, 0.3-1.0 s), its
  body battering everyone within 1.5 m flat (12); flung at 1.04 (18, unblockable, breaker) with `launched` at 9.5 / 5.5
  (about 8-9 m), and a ball down HAUL_LINE 8 m bowls over everyone within 1.7 m (14). Heavy or boss: hooked into a 1.4 s
  stagger, you run once round them at 2 m facing in (0.3-1.3 s) while the right axe chops at 0.52 / 0.84 / 1.16 (10, 10,
  20; all unblockable, the last a breaker).
- **Polish:** Gallows Hook throws the real axe (Projectile `hook`: out at 60 m/s to their chest, back at 20 m/s), the
  haul when it arrives, a swoosh on the chop. Hewing Frenzy's pose alternates real chops (one axe down while the other is
  already up, `_alt`) under one 0.8 s two-colour swoosh, impacts on the cut instead of the chest rings. Axestorm and
  Fimbulwinter pass `arc = true` and their hooks stop foes HOOK_STAND 2.3 m off along their own line (`hook(..., stand)`)
  instead of in your body. Ice spikes use the `ice` texture (faint cold emission), not metal. BladeTrail skips a hidden
  weapon (a thrown axe leaves no ribbon in the hand).
- **Co-op:** `vine_yank(to, dmg, wrap)` forwards all three args; the bool survives `_enc/_dec` (t/weapons/axe_hook_yank).
  `_carry` (Haul's swing) runs only where the foe is simulated: a guest's Haul hooks (grabbed, a host call) and flings
  (launched) but the foe isn't swung round on the guest's cast, the same as the fist throw. nettest at prepush.
- Per frame/tick: Ravens' Return: two projectiles (a few vector ops + an ImmediateMesh ribbon of ~12 points) and one
  sphere query per tick for 1.2 s; Haul: one or two sphere queries per tick for ~1 s. Nothing idle.
- Tests: t/weapons/ravens_return, raiders_haul, axe_hook_yank, dual_axe_tree (six techniques). Renders (worktree):
  tools/dev/out/abil/dx_ravens_return.png, dx_raiders_haul.png, dx_hewing_frenzy.png, dx_gallows_hook.png.
## 2026-10-22: the Adventure trees' moves, piece 4: Swimming's Surface Sprint (Dolphin Kick / Long Glide)

- **Tree:** `sw_sprint` "Surface Sprint" (variant, Stroke branch, level 12) in `_build_swimming`: `sw_dolphin` (`dolphin_kick`) and
  `sw_glide` (`long_glide`), icons `move_dolphin` / `move_glide`. Switched at the bunk like the other variants.
- **SwimState** (`fast and not _diving` only): Dolphin Kick 1.3x speed (x1.25 for SURGE_FOR 0.18 s every 0.55 s) at 1.3x FAST_DRAIN, with a
  spray per surge; Long Glide a 0.4 s stroke at 1.3x (full drain) then a glide at 1.1x for half the drain, a 1.6 s cycle. All are multipliers on
  the target speed, so velocity stays input x speed (no momentum). `_sprint_t` restarts when the sprint stops.
- **Pose:** Humanoid `swim_style` ("", "dolphin", "glide"; in HumanoidSync.FIELDS), set by SwimState (cleared on exit) and applied in
  `_swim_pose` by `MovePoses.swim_style` (butterfly: arms heaving together, hips rolling a wave; glide: flat, arms stretched ahead, slow scissor kick).
- **Test:** `t/swim/surface_sprint` (speed and drain against the plain sprint for each version, `swim_style`, switching, clearing).
  Render: posebench with `PB_SPEED=4.6 PB_SET='swimming=true;swim_style="dolphin"'` -> tools/dev/out/swim_dolphin_*.png, swim_glide_*.png.
- Per frame: a few float ops in the swim state; the spray is one Net.fx per surge / stroke. Not run: nettest with a guest (swim_style sync).
## 2026-10-22: Suggest an Idea (a QR for the companion app)

- **What:** the pause menu's "Suggest an Idea" plank opens GameMenu screen "idea" (`scripts/ui/idea_screen.gd`): a
  QR of `driftwake://idea?v=<application/config/version>&t=<int(GameManager.play_time)>`, one line to scan it and
  the link as text. The companion Android app (separate repo, `fun.zestermo.driftwake`) opens that link as its Ideas
  form with the version and hours filled in. Local only: no RPC, the same for a co-op guest. Rebuilt on every open.
- **Encoder:** `scripts/ui/qr_code.gd`, no plugins: byte mode, level M, versions 1-4 (62 bytes max; longer asserts),
  Reed-Solomon over GF(256)/0x11D, two-block interleave for v4, the spec's mask penalties (rule 3 as segno scores it,
  edges count as light). `QR.image()` draws one pixel a module with a 4-module quiet zone; the screen shows it at
  5 UI px a module with nearest filtering (37 modules for the usual v3 link: 185 px on the 640x360 menu canvas).
- **Gotcha:** segno 1.6.6 adds a stray 0x00 codeword whenever the bit stream is already byte-aligned (always, in byte
  mode) and scores masks before drawing the format bits, so its stock output differs from ours (both scan). The
  reference matrices in t/ui/qr_reference came from segno with the padding fixed, forced to our mask.
- **Tests:** t/ui/qr_reference (module-for-module against those references, v1/v3/v4), t/ui/idea_qr (the plank,
  the link from version and play_time, the QR on screen is the link's, Esc back to pause).

## 2026-10-22: ground flicker (tavern rug and floor, blood, puddles)

- The tavern's rug sat exactly on the planks' top (both fl + 0.015) and the stone footing's full top 1.5 cm under
  the planks: coplanar or near-coplanar surfaces whose triangles the PSX vertex snap tilts differently, so they
  traded places as the camera moved. The footing's top is now only the rim round the planks; the rug sits 1 cm
  over them with psx_lit's depth_pull (0.03) (`Buildings.tavern_hall` / `_tavern_inside`).
- Blood splats, rain puddles and poison puddles use `PSXMat.decal(color, opts)` (`shaders/psx/psx_decal*.gdshader`,
  body in psx_decal_body.gdshaderinc): snapped to the same grid as the ground, no depth writes (overlapping splats
  used to z-fight, they were opaque), pulled toward the camera by `pull` m at 5 m (x0.6..x5 with depth), since the
  snap's tilt grows with distance and beat the old fixed 1.5 cm / 10 cm lifts. Rain puddles now lie 5 cm up.
- Checked: modelshot through the tavern door at grazing angles (MS_PSX=1), the three decals on the ground; t/fx,
  t/island/house_doors. Renders with project.godot's threaded rendering need `--render-thread safe`.

## 2026-10-22: dither effects, piece 1 (telegraph, rain and poison puddles)

- Zach picked the "dither" direction from `gen_fx_style_samples.py` (chunky pixels, Bayer fills, a boiling 1 px
  outline), asking for it subtler: no full fills, lower opacity. Sheets by `tools/texture_gen/gen_dither_fx.py`
  (8 frames of 64 px, 4x2; no mipmaps, nearest).
- The decal shader has a sheet mode (`psx_decal_sheet*.gdshader`, `PSXMat.decal_sheet`): `frame` set by code or
  `fps` looping by itself (each MultiMesh instance its own phase), and a palette mode reading grey indices
  (0.2 outline / 0.4 deep / 0.6 body / 0.8 highlight) so one sheet takes any caller's colour.
- `FX.telegraph`: a quad with the index sheet, frame 0 -> 7 over the wind-up, coloured from its colour,
  `TELE_ALPHA` 0.6: a thin ring dark outside, sparse speckle, a dithered edge closing in, small chevrons.
  `arc_warn` and `lane` are still the old plain shapes. Rain puddles (cap 0.65) and poison puddles (0.75) loop
  their sheets; blood splats keep their spatter shapes for now.

## 2026-10-22: dither effects, piece 2 (fans and lanes)

- `FX.arc_warn` fans and `BeastFX.lane` strips are drawn by `shaders/psx/psx_ground_warn.gdshader`: the
  telegraph's look made procedurally on a world-space pixel grid (`texel` 0.09 m, the telegraph's density), since
  their sizes vary too much for a sheet. Thin rails and far end (a dark outer pixel), boiling every 1/6 s; a
  sparse Bayer speckle; a dithered front sweeping to `reveal` m over the wind-up; small chevrons marching along
  behind it. One mesh each (was a rim and a growing fill, additive). `FX.warn_mat` / `FX.warn_palette` share
  the telegraph's tones and TELE_ALPHA. Node names (ArcWarn, Lane, Telegraph) unchanged for the suites.
- Tested by t/fx/ground_warn; grunttest, guntest, foresttest and r8test check the nodes appear.

## 2026-10-22: black-leg finish (Cleaver Kick, Flambe Dash, polish)
- **Cleaver Kick** (Flow, mastery 12; 18 energy, 7 s): `bl_cleave` (0.8 s): load on the left foot 0.16, leg up the
  outside 0.24, over the top at **0.3** (CLEAVE_AT) where Projectile `"cleaver"` leaves (the slash crescent tipped across
  the line, 34 m/s, 12 m, r 1.8; plain air, or black-leg heat with `"elem"` and BurnStatus 3 s x 5/s on each cut),
  swept across and down, guard. Faces whoever's aimed at within 12 m.
- **Flambe Dash** (Fire, 14; 22 energy, 8 s): `bl_flambe` (1.0 s): sink 0.1, hop with the knee tucked 0.2 (leg heats),
  the flying side kick (`_fly()`, shared with Arrow Kick) from **0.26 to 0.51** at 36 m/s = 9 m, enemy collision
  (layer 12) off for it (TechniqueState.exit() restores it); everyone within 1.5 m kicked aside (to their side of the
  line, breaker, down), with the heat burning 3.5 s; trail of heat puffs (plain: dust) and a streak on landing.
- **Polish:** Mule Kick tips over to MULE_TIP 2.45 rad (near a handstand, heels up and back at chest height) instead of
  lying face-down at 1.5; Hailstorm Heels' rings sit on the foot (`foot()`) as it snaps out; HEAT_TINT 0.3 -> 0.16
  green (and the heat lights) so the heel kicks' flames read cherry/crimson, not orange; Cartwheel Crescent's hands
  floated 0.23-0.47 m: the plants opened ~50 deg into each turn (body still on its side; now around 157/203 deg where
  each V'd arm points down), the 0.05 u ease never fully reached in the short plants (now 30% of a short window), and
  the hips rose 0.26 m upside down (now 0.09): palms on the floor (wrist 0.10-0.12 m).
- Tests: t/weapons/black_leg_tree (six techniques; Mule Kick heels over the hips), black_leg_cleaver_flambe (blade at
  10 m + burn; the dash through the dummy, burn, collision back), black_leg_wheel_hands. Suites likely affected:
  techtest (two new techniques), nettest (the `cleaver` projectile replicates through net_power like the others).
## 2026-10-22: dither effects, piece 3 (rings and hit bursts)

- `FX.ring` (~160 callers: shockwaves, rings of air round thrusts and punches) is the dither shockwave: a quad
  on `dither_ring` (or `dither_ring_wide` for a width >= 0.2), index sheets coloured by `warn_palette(color)`,
  frame 0 -> 7 over its life while it scales out as before: a band with a bright leading pixel and a dark one
  outside, thinning and breaking into dashes. RING_ALPHA 0.7 (was an additive glow at 0.85).
- `impact` and `parry_sparks` flash `flip_dither_hit` (a 17th FLIP_SHEETS sheet, 4x4 frames): an uneven
  nine-spike impact with a white-hot core opening and dithering away (a five-point star read too cartoony).
  Their spark particles are unchanged.
- Not converted: water_ring (own bands), elem_hit / drawn bursts (already hand-drawn), muzzle and cannon blasts.

## 2026-10-22: the greatsword finish (1.19, carried from 1.18.4)
- **The low guard moved to the right** (Zach's reference photo): both hands at the right hip, the blade down and out to the
  right and a little behind, the point near the ground (`GreatswordMoves.GUARD_GRIP`, the chest turned toward it so the
  left arm reaches in front of the chest). Walking keeps the guard; only a sprint drags the point (`StanceLife.SPRINT_ONLY`
  now has "greatsword", `ANY_WAY` is empty). Running Cleave and the gate come back to it through `_ahead()` (the blade
  forward and down in front of the legs), or they cut back through the right thigh.
- **Updraft** (Momentum 12): a rising cut throws a light foe up (`launched`, a ragdoll), a boss reels; the captain leaps
  after them, cleaves at the apex (0.7 s) and crashes down (a 3.2 m ring, knockdowns). `GreatswordArts._updraft`, pose
  `gs_updraft` (+ `gs_land`).
- **Gatekeeper** (Bulwark 14): held up to 1.5 s, the blade point-down before you (`is_parrying` + `bat_shots`, like
  Windmill Guard); released, `gs_gate_rise` wrenches it up: an unblockable cone and a stood-up `gale` crescent.
- Polish: Guardbreaker's crush from standing (`BREAK_CRUSH`, no near-prone sprawl), its trail started over the top
  (0.52 s); Crescent Gale's `gale_flat` tipped up 0.55 rad and thicker, so it isn't edge-on from behind.
- Tests: t/weapons/greatsword_tree (six techniques, each lands), greatsword_clear (the new poses), greatsword_combo and
  greatsword_carry updated for the right-side guard and the walking guard.

## 2026-10-22: dither effects, piece 4 (blood splats)

- `FX._place_splat` lays a quad (`_splat_quad`, 6.4 units: the sheet's pool is 10 px of the 32 px half-frame)
  on `dither_blood` (gen_dither_fx.py, 4x4: rows 0-1 round, 2-3 directed with the spatter to +U): a landing
  over SPLAT_LAND 0.22 s on its own material (flung, spreading, pooling, settled), then the shared settled
  material of its variant (`_splat_mats`, so 120 lying splats share 4 materials). Mirrored at random for
  variety. Replaces the 24 random splat meshes and the SPLAT colour. Specular 0.3 (0.5 caught the sky pink).
- siteshot's `_clean_blood` frees `FX._splats` instead of matching the old material. Tested by t/fx/blood_splats.

## 2026-10-22: dither effects, piece 5 (water rings, muzzle and cannon flares)

- `FX.water_ring`'s two bands are the dither ring sheets (wide outer, thin inner) on `_ring_quad` in foam tones
  (sea-blue edge, pale blue, foam, white), frames over each band's life, still riding the surface. `_band` and
  `_annulus` are gone (no callers left).
- `flip_dither_muzzle` (gen_dither_fx.py, an 18th FLIP_SHEETS sheet): seven uneven flame tongues round a
  white-hot core at once, cooling to orange and then dithered powder smoke. It replaces the `muzzle` flare in
  `blast` (every gun and cannon firing), `cannon_blast` and `powder_burst`; the fireball and smoke sheets
  around it are unchanged. The `muzzle` sheet stays in the library.
- t/fx/blocks, t/fx/flipbook and t/fx/sheets updated for the new sheet name and count.

## 2026-10-22: combat perf, quick wins (grunt path spike, enemy sleep radii)
- **The fights' worst ticks were navmesh paths:** every slow grunt tick (~5-8 ms, CHASE/REPOSITION) was `_nav_dir`'s
  `map_get_path` across all of Brinehollow, re-asked each time the captain moved 1.5 m. Now a knee-height ray first
  (`_clear_walk`, 30 m): clear, walk straight with no query; blocked, `query_path` capped at 60 m / 4096 polygons
  (`NAV_SEARCH`, `NAV_POLYS`), at most ~1/s or when the goal moved 3 m (`NAV_REGOAL`). The on-mesh check reads the
  path's first point instead of `map_get_closest_point` (also a whole-mesh search).
- **Enemies sleep sooner:** `ActorSleep.ENEMY` [90, 70, 230, 210] for grunts and scuttlebugs (they notice at 8-17 m);
  people keep 160/120. The training pen had 20 idle hostiles awake 60-120 m off.
- Bench (yard, fight, brawl, back to back; the after run on a 15% busier machine): fight 20.3 -> 13.8 ms, physics
  scripts -58%, the worst grunt call 7.9 -> 4.0 ms (brawl 7.7 -> gone), scuttlebugs 0.66 -> 0.10 ms.
- Next if fights still dip: grunt AI at a lower think rate (physics scripts now ~1.5 ms in the fight), hair/cloth sims
  only on the nearest fighters, then the skinned single-mesh bodies.
- Tests: t/world/actor_sleep's pedestals moved for the enemy ranges (45 / 75 / 140 / 650 m).
- **Then (2026-10-23):** grunts think every other tick in the moving-about states (`THINK_STATES`: idle, alert, chase,
  circle, reposition, keep, return; staggered by instance id) and move every tick on the last decision (`_move_tail`);
  the thinking tick gets both ticks' delta so the states' clocks keep pace; attacks, blocks, dashes, stagger think every
  tick. Hair/cloth springs on lod rigs only for the 4 nearest the camera (`Humanoid.SIMS_N`, ranked on last frame's
  distances, 15% slack for the ones swinging). Bench (off/on back to back): grunt AI 0.90 -> 0.51 ms, grunt rigs 1.12 ->
  0.82 ms a frame in the five-grunt fight; whole-frame change within calib noise. The brawl stop plays out a real fight
  and isn't comparable run to run (one run ended in the camp's middle: +630 draws of scenery).

## 2026-10-23: Brinehollow fixes from Zach's captures (roofs, moored ships, the chapel's base)
- **Roof collision:** `Buildings.house` had colliders only to the wall tops (you stood on the wall box's flat top sunk
  in the roof). `_roof_col` adds one convex shape per roof: `_roof_y` sampled 7x7 over the eaves plus the wall-top
  corners (gable, gable_front, hip, shed are all convex). Every house on every island goes through it.
  t/island/house_roofs checks each kind, pitch and storey count; house_doors' "no steps" check skips "RoofCol".
- **Moored ships on the quay:** `KitHarbour.build_piers` put a ship's centre at pier length - 10 m whatever the quay's
  curve, so the junk's and the sloop's sides stood on the paving. Now it slides out along the pier until the footprint
  plus 1 m is past the quay edge and over water (`_hull_clear`, `past_quay(p)`: how far out past the quay a point is,
  < 0 on it). Brinehollow: junk 1.2 m clear, merchant and sloop 4.2 m.
- **The chapel's base:** its plinth went 1.4 m under the floor; on its slope the low side floated. `chapel(found)`,
  and KitLandmarks passes the footprint's drop + 0.6 (Brinehollow's: 3.45 m).

## 2026-10-23: skinned bodies, piece 1 (one skeleton per body, behind a switch)
- **What:** `BodyBuilder.one_skin` (static var, off; `DRIFTWAKE_ONE_SKIN=1` for a run; never the player's rig, the one
  with `swappable_hands`). A body's skeleton is `LowerBody`, grown: ArmBody's bones from `LowerBody.ARMS` (21; its
  TORSO bone copies the torso joint) and a follower bone per joint with rigid parts (`follow()`: neck, head...), every
  rigid part bound into "Mesh" by `BodyBuilder._skin_one` (upper-arm parts into their arm's mesh). The arms keep their
  own meshes (MeshL/MeshR: Haki's recolour, `sever`'s bake via `ArmBody.bake`); no ArmBody node. Joints carry no meshes,
  so the animator, IK, Ragdoll.restore_rig, HumanoidSync and every `hand_r`/`torso` reader are unchanged. Docs plan:
  docs/skinned_bodies_plan.md (piece 2: one texture-array material per body).
- **Found on the way:** `FX.afterimage` and `Decoy` copied skinned meshes without their skin, so skinned parts stood in
  the rest pose (legs and arms already did). `FX.still_copy` gives a skinned copy a frozen copy of its skeleton.
- **Tests:** t/world/one_skin_same (28 looks from `_skin_cmp.look_of` built both ways and posed alike: the same 662k
  vertices per material, position/normal/uv/colour; nothing left on joints; draws 17.3 -> 12.2 a body; the player's rig
  keeps the old path), t/world/one_skin_ragdoll (ragdoll, sever an arm and the head, restore = a fresh rig's pose,
  afterimage = the body), t/world/body_shadow_lod_one. Renders: modelshot `S.body_of(i, one, how, pose)` (a fixed
  frame: skinned meshes report rest bounds) old vs new = inside the old-vs-old noise floor (0.05-0.07% px vs
  0.05-0.11%); coplanar layers (cuffs, a coat edge) can z-fight differently now they share a mesh.
- **Bench** (off/on back to back, gate, plaza/market/yard/fight; calib 24.4 vs 28.7 ms): frame 16.52 -> 15.81 ms (-4%),
  draws 1,520 -> 1,427 (-6%), tail -8%, proc_scr -6%, draw -7%; per stop plaza -14%, market -18%, yard +7%, fight +4%
  (noise). lower_body + arm_body 0.47 -> 0.47 ms (one script now). Default stays off until piece 3.

## 2026-10-23: v1.19 built overnight (docs/v1_19_plan.md "Build log" has every piece, its tests and what's assumed)
- **Captain-style AI:** `Player.inp` (CaptainInput: the keyboard and camera, or a brain's BrainInput) for every held
  input; `Player.is_ai` (player.tscn with a brain: enemies' side, no HUD/camera/saves); `CaptainBrain` (spacing,
  combos, reads your attack's start and dodges/parries/blocks by skill, skills and the ultimate on openings);
  `cam_shake/cam_kick/foe_mask` per captain (never name a Player method `shake`: siblings answering
  has_method("shake") pass for the camera rig). Co-op: `Net._all_spawn_rival` (guests get a captain puppet).
- **Cutscenes:** `Cutscene` (shots, eased dollies, node-anchored shots followed every frame, letterbox subtitles with
  voice blips, a skip vote in co-op); `SpeechBubble` / `FX.speech` for lines in a fight.
- **Rival crews:** `RivalCrews` (four authored crews, bounty hunters, three Admiralty officers), `RivalEncounter`
  (meeting, duels in turn / squads at once / ambushes, retreat, plunder or arrest, records in GameManager.rivals),
  `RivalWatch` (where they turn up: placed then rolled; hunters from Notorious; officers at harbours from Infamous).
- **Bounties:** `Bounty` (the table, tiers, per-captain, saved, in the snapshot), `Net.bounty`, wanted posters on
  notice boards (`WantedPoster`), shops by trade, townsfolk lines.
- **The Admiralty:** the Marine patrols restyled grey ironclad and gated on the crew's bounty; `AdmiraltyBrig`
  (arrest and escape).
- **The intro** (`Intro`), **fighting in the water** (SwimState strikes), **the weapons' enemy pass**
  (`PirateGrunt.ROLES`).
- **Also fixed:** Ship.summon_spot (looptest red on main since the moored-ships change: she appeared on the spot);
  seatest's Marine-whites check (the restyle).
- **Not yet run:** the world suites and nettest (prepush: `rival` is a new nettest mode); the trigger of rival/hunter/
  officer meetings on a real chain island; the Admiralty hull is still wood-brown (needs a grey plank texture).

## 2026-10-23: cheaper release testing (the release tier, version out of the keys, four suites retired)
- **Why:** v1.19's prepush ran ~361 tests twice. A pass is keyed by every file a test loads, every test loads
  ~343+ files through the autoloads, so a core-file change (or the version bump: 56 tests in one estimate) made
  everything stale, and each fix after a red run did it again.
- **The release tier** (`test_status.ps1 -Carry`, used by `prepush.ps1` and `run_needed.ps1 -Carry`): a stale test
  whose newest pass is since the last `v*` tag counts as ok ("carried") when none of the files changed since that
  pass (from its .ok manifest) are tools/dev/* or tied to it by test_map.txt. smoketest and net always need their
  exact pass; a failure newer than the pass blocks the carry; `full_only.txt` (capturetest) carries from any pass.
  `-Carry` leaves status.json (the Tests pane's strict view) alone. `prepush.ps1 -Full` is the strict run. prepush
  prints the changed scripts/scenes/shaders since the tag that no map line covers.
  Estimate on HEAD 2c0cd76c with only the passes from before the v1.19 prepush: strict 361 tests / 17,400 s machine
  (~58 min wall at 5 slots) vs carry 97 tests / 5,400 s (~18 min).
- **Key exclusions:** `tools/dev/key_ignore.txt` (path | first-line regex | block-end regex): the version line in
  project.godot and the NOTES block in whats_new.gd are dropped before hashing (crew_lib `Get-KeyBlob`: "n" + the
  hash of the rest). Old manifests' raw blobs are normalised the same way when test_status compares them
  (`Get-KeyLine`), so carry sees through it; strict keys changed once with this landing.
- **Retired suites** (checks moved, setup saved): fixtest -> guntest (both hands on the rifle, a downed rifleman
  stays down, never aims once dead; plunge is airtest's, shove guntest's); r6test -> powertest (skill keys after
  closing the skills menu, Armament: Coat, block, red unblockable heavy, fall damage) + vinetest (aura, leg vines,
  dash vines); its skills-menu / menus-fit / quick-item / pixelation checks were already t/ui, uitest, invtest's;
  r7test -> invtest (drag and drop, quick slot, drop + pick up, chest window, wolf stance, PSX default);
  hairtest -> cliptest. qoltest's chart marks stay (t/map/map_marks is quest marks, not the player's waypoints).
- **r8test "...and fires a broadside":** its 14 s window (and the boss's 3 s ones) counted process seconds while
  the ship AI runs on physics ticks (max 4 a frame): under a full run's load the window ran short. Now
  `secs_since_t0()` in physics ticks. The other flaky.txt checks already wait in ticks; their flakes are something else.
- **Not done (later, Zach's call):** one Godot process per atomic group. A bare boot of the project is ~21 s
  (compiling ~438 scripts / 149k lines) of each atomic test's ~30 s: ~95 min machine per full run.

## v1.19, re-released: the waiting crew, fair matches, knockdowns, co-op dungeon bugs (2026-10-23)
Folded into v1.19 (the tag moved; the version stays 1.19) the same day, after Zach played it.
- **The waiting crew** (Zach: "I don't want them to run around in circles round the fight"): CaptainBrain's "rest" order
  replaces "watch" for a crew fight. RivalEncounter._crew_corner puts the crew in a loose arc CORNER (12) m to one side
  of the duel (either side, nearer, a little ahead or behind: the first with ground at the fight's height and 1.1 m of
  room at every spot, `_ground_ok`; none: where they stand), facing it. Each walks there and settles at an activity:
  "watch" (stands, the head on the duel: Humanoid.look_target, synced) or side work from REST_KINDS, no two the same
  (train: DowntimePoses' drill; read and tinker: seated on their crate with the downtime props; sit: Player.sit_ground;
  music: Jam with an instrument put in their look, heard by guests). Watching at WATCH_CHANCE, at most half the mates;
  their captain always watches. Side workers glance up every 3-8 s; big moments (`_crew_react`: a mate down, their
  captain's turn, an ultimate) turn every head, and a watcher facepalms or cheers. Called in, it unsettles (up, the
  pose or tune stopped) and walks in. Player._update_head_look leaves an AI's head to its brain.
- **Solo is a shorter gauntlet** (Zach): one or two mates (SOLO_MATES; one of a crew of two), the best matches for
  your style, then their captain. Co-op unchanged (a rival per standing captain).
- **A knockdown isn't a loss**: RivalEncounter._standing and the brig's "everyone down" counted Downed (also a heavy
  hit's knockdown) as beaten, so one knockdown lost a solo fight (plundered), a squad fight (arrested) or threw an
  escaping crew back in the cell, and a rival knocked down was replaced mid-duel. Both use Player.is_standing now.
  Test: t/combat/rival_rest (the corner, the activities, the heads, staying put, a knockdown, the next walking in).
- **Co-op dungeon bugs** (nettest's "all host enemies exist here" missing `Isle0/Dungeon0/Enemies/Bugs/B3_0`, `B4_0`
  in 2 of 5 runs): on a chain island being built a ScuttlebugNest hatches a bug a frame (`_hatching`), and
  `Dungeon._sleep_check` put a far dungeon's Enemies to sleep (PROCESS_MODE_DISABLED) mid-way, so the last spots
  stayed empty on whichever machine was cut off, at a different spot on each. It now waits for a hatching nest the way
  it already waited for a warming GruntCamp. Test: t/island/dungeon_nest_sleep (fails 0 of 4 hatched without it).
- **Rival pairing**: `RivalEncounter._next_up(c)` gives each captain the waiting mate in their own fighting style,
  else the first waiting, the crew's captain last. The lead's ordering compared `weapon_class()` (fist/sword/gun/claw:
  every blade is "sword"), so it never matched anything; both use `Player.style()` now (polearm, katana, dagger...).
  Test: t/combat/rival_pairing.

## v1.20 piece 1: the beasts and bosses reworked (2026-10-23, unstable 1.19.1)
docs/v1_20_beasts.md (the move lists, Zach's OK) and its "Built" section. Where: scripts/enemies/beasts/ - quad_beast.gd
(the rig's new keys, jointed legs, _slope), giant_beast.gd (new), jungle_beast.gd (pick(), _last_move, the opening
double-poise, strike()'s stun), alpha_boar.gd (the move-table runner: _table/_tbl/_run_table/_blow, hooks _table_tick and
_on_table_hit), each kind's file. Gotchas: a table must not read `spec` (it's made before _build); kinds that hang things
on feet use foot_part()/foot_y(); a two-legged kind's `_last_move` drives its recovery pose. Tests: t/island/beast_moves,
serpent_train, beast_prebuild, forest_beasts, desert_beasts; tools/dev/beastsheet.gd for looks.

## v1.20 pieces 2-3: the arenas and life between places (2026-10-23, unstable 1.19.2)
- **Arenas** (docs/v1_20_plan.md "Arenas"): `ThemeDef.arena_dress` dresses every boss's ground of a theme before a kind's
  own "dress" (BeastArena._dress). Snow: `"arena": "open"` and SnowTheme._dress_grotto (an ice grotto: rock walls sheathed
  in ice climbing to the back, an overhang hung with icicles, crystals, frozen pools; walls solid, the way in open).
  Desert: DesertTheme._ruin_court after its pillars (a flagstone courtyard drowned in drifts, broken wall arcs, a toppled
  archway; nothing across the way in). Forest: ForestTheme._dress_stones (tall mossy standing stones for every forest boss
  but the Stag King, whose grove has its own). Jungle: the canopy as before. Renders: genshot (seeds 3 snow, 2 desert,
  5 forest; `<prefix>_boss.png`).
- **Between places**: KitWayside (scripts/island/kit/kit_wayside.gd, IslandContent.steps' last): along every path, every
  26-38 m beside it a trunk, boulders or a wall stub (the desert: bones; the snow: snow caps), and about every 110 m a find
  (a wayside shrine, a lone chest keyed "wayside_<id>_<n>", a left camp); never a solid piece within PATH_CLEAR (1.8 m) of a
  path, nothing reserved, steep or wet; one mesh (visibility 200 m) and simple colliders. ~7 ms an island. FaunaSpawner CAP
  72 -> 96, MIN_KINDS 3 -> 4. IslandEncounters.COUNT 0-4 a island (about 2.2, was 1.4). Tests: t/island/wayside,
  t/quests/encounter_rolls (0-4), smoketest.

## v1.20 piece 4: the fog isle (2026-10-24, unstable 1.19.3)
- **What** (docs/v1_20_plan.md "The spooky island" .. "Its boss"): the fifth theme, `scripts/island/themes/fog_theme.gd`
  ("fog", "Fog Isle"), registered last in IslandThemes.SCRIPTS but **rolled apart** from the chain's weighted draw
  (`ThemeDef.apart`: `weight` is then its own chance, 0.18, on a regular island past the first, from a hash of the
  chain's seed, the layer and the branch, Chain._apart), so every chain that was a chain stays the same but for the islands
  that turn to fog, and no chain opens on one. Land: the forest's (forest_land.gd) on its own numbers (rolling, sparser,
  slow black rivers). Plants: `scripts/props/fog_plants.gd` (FogPlants: dead oaks hung with grey moss, drowned willows
  weeping moss curtains, dead fir spires of broken stubs, crooked snags, brambles, withered bracken, pale dead grass, pale
  caps, dark lichened stones, a roof of dead limbs). Textures: `tools/texture_gen/gen_fog_textures.py` (fog_moor, fog_mud,
  fog_rock, fog_beach, fog_grass, fog_bracken). Style: weathered grey plank cottages, black shingles, a lamp at every door,
  weather [0.1, 0.6, 0.9], haze 0.7 grey-green and KitStyle "mist" 0.8 (Weather: the fog pulled in to MIST_END 70 m and the whole sky greyed into it, both thinned round a lit lantern), the forest town's buildings (ForestTown log cabins and timber houses, shingles everywhere), no butterflies or fireflies; forest_night / village_night music for now.
  People: `fog_life.gd` (a cursed fishing village: lamplighter, net-mender, gravedigger, widow, bell-ringer, eel-catcher,
  salt-seller), `fog_encounters.gd`.
- **The dead**: `scripts/enemies/drowned.gd` (extends PirateGrunt: grey-green, rotten clothes, no guns (`_guns_free`
  false, a rifle post is a blade's), a shot does 0.3 of its damage and never knocks down, no blood (`_take_damage`: sea
  water and murk), cut down once he lies RISE_DOWN s and gets up with 45% (`_rise`, deferred: the blow's own hit-stun
  would land over the fall), the second time he stays down) and `ghost.gd` (extends Drowned: the look's "spirit" glow,
  shot passes through, fire (dot) x2, 1.35 x speed, fades out for 0.35 s every 3-6 s, burns 8/s in a lit lantern's glow,
  never rises, nothing severed). Both steer straight out of a lit lantern's glow (`_move_tail`). Camps on a fog isle are
  drowned crews with ghosts among them (KitStyle "crew_script", "ghost_script", "ghost_share"; IslandContent.undead).
  `BleedStatus.apply` skips anything `bloodless()`. A look's `"spirit"` (Humanoid._build, Humanoid.spirit_glow) makes the body pale blue-white and faintly glowing (lit, so its shape reads: a flat glow turned a body into a blob).
- **Lanterns** (`fog_places.gd`, `fog_lantern.gd`, FogTheme.steps): an iron post every 48 m along the ways (22 at most,
  nearest the village first), two at the graveyard's gate; F lights one (Net.world_flag "isle<id>_lantern_<n>": every
  machine, saved, late joiners); lit: a warm glow and a light (fades past 50 m), `FogClear` tells Weather how close the
  camera is to the nearest lit one (`Weather.lantern_clear`, the fog thinned up to LANTERN_CLEAR), the dead keep out of
  its 7 m glow (FogPlaces.away_from_light).
- **Places**: the graveyard (FogTheme.plan_places: 30-80 m out of the village, flat, off the paths, a trail to its gate;
  a low wall, rows of leaning headstones and crosses with their mounds, an iron arch, a crypt with a grilled black door);
  haunts (2-4 GruntCamps: the drowned and a ghost at the graveyard, ghosts in pairs out on the far ways).
- **Bosses**: `scripts/enemies/ghost_captain.gd`, the drowned captain on his wreck: a Node3D with the arena's boss
  interface owning a captain-style AI (RivalDuel.build: CaptainBrain skill 0.9, his look's "spirit", hp_k 6 x Levels) built
  under it on every machine (the guests a puppet of the same name). Three acts: the duel; below 60% three drowned climb
  out round the floor; below 30% he steps out of the fog behind his foe every 6.5 s. `Player` with a "spirit" look takes
  no harm from shot. The arena: FogTheme._dress_wreck (his ship broken in two round the floor: the stern rolled on her
  bilge with the quarterdeck, the cabin and a green lantern, the bow nosed up, ribs, the fallen mainmast, barrels and a
  cannon); every other fog boss's ground is FogTheme._dress_graves (a drowned graveyard ring). The other bosses are
  spectral (BeastPool "spirit": the stalker, the serpent and the treant glow and shot passes through them).
- **Tools**: genshot `GSHOT_BEAST=<kind>` swaps the island's beast (its ground dressed for it); genshot now refreshes Weather's zone at each shot (it looked the place up only twice a second, so a jump of the camera rendered the last place's fog).
- **Tests**: t/combat/undead, t/island/fog_isle (chains, the island, lanterns, graveyard, haunts, the captain), the theme
  registry. Renders: tools/dev/undeadshot.gd (the dead in a row), genshot on a fog island.

## v1.20 piece 5: the polish pass (2026-10-24, unstable 1.19.4)
From a genshot sheet of each theme (tools/dev/out/polish/, seeds 4 snow, 3 snow, 2 desert, 5 forest, 2/5 fog) and the
fidelity report:
- **Camp houses took the jungle's thatch on every theme**: `{...}.merged(st["rough"])` keeps the base dict's keys, so a
  theme's rough `wall`/`roof_tex` never applied (IslandContent's camp shack, KitCamps.pirate_camp's four houses): now
  `merged(.., true)`. Brinehollow's rough has neither key, so its den and camps are unchanged. The snow's rough gets
  `roof_tex: roof_green`.
- **Thatch hardcoded in kit pieces other themes use**: KitLandmarks.lookout_tower(h, roof) (KitStyle.lookout passes the
  style's `mat.thatch`), KitHouses.gate(width, roof), well(roof), and workshop/shrine/storehouse/ruin/room's ridge caps
  read spec `roof_tex` (IslandVillage passes `mat.thatch`). Snow towers and gates are green shingle, the forest's and fog's
  shingle, the desert's adobe.
- **The wharf's warehouses** were always planks: GenHarbour now picks their walls from the style's `harbour_walls`
  (the desert's adobe and sandstone).
- **The Admiralty's hull** (a 1.19 follow-up): `planks_grey` (gen_psx_textures.py `ships`: blue-grey painted planks),
  HullBuilder.build's `hull_tex`, the marine look's.
- **The fog isle**: its sea greys and darkens under the mist (Weather's ocean colours by `misty`); a spirit's look is
  softer (emission 0.4, so a giant's shape reads).
- **People**: IslandLife.AMBIENT 8-10 -> 12-15 (a village ~20 -> ~25 people; Brinehollow has 38). lifetest's range 19-26.
- Not changed (by design, noted): lit windows ~0.4x Brinehollow's (smaller one-storey houses), paths unpaved (Brinehollow
  paves 4%).

## 2026-10-24: 1.20 names (docs/originality_plan.md) and the campfire flame
- **Names, display text only (ids kept, no save migration):** Soru -> Squall Step, Tekkai -> Ballast, Armament: Coat ->
  Iron Will: Coat (its mastery Ryuo -> Outflow), Fire Fist -> Cinder Fist, Sea King Fist -> Leviathan Fist, Conqueror's
  Haki -> Captain's Will, Haki Legs -> Will Legs, the skill map's Devil Fruit tab -> Driftfruit. Fruit types show as
  Flux / Feral / Knack (`DevilFruits.TYPE_NAMES`; `type_name()` reads it). Sea King -> Leviathan (banners, boss bar,
  chart, tips, dialogue, Leviathan's Fang), log pose -> lodestone (banners, toasts, controls list, village and
  world lines), Marines -> the Admiralty (dialogue; the squads' mates are "Greycoat <name>", the intro's "Admiralty
  marine"). Fruit items and inventory text say Driftfruit. A jungle hermit "Haki" -> "Tama".
- **Published text:** README, documentation/gdd.html, docs/release_v1_18.md and every web/site page; the "Inspired by
  One Piece" credit footer dropped from every page. GitHub release bodies are only changelog links (nothing to edit).
- **Left as is:** internal ids, node names, comments, skill_tree.gd's unused REGION_* keys, generic words (the Warlord
  talent, the Dune Emperor). **Decided (Zach, 2026-10-24):** the rule "fruit users can't swim" stays (the item text
  says so in the new names).
- **Campfire flame (noted 2026-10-20):** Props.campfire's flames were opaque untextured quads that stacked into a tall
  pale block at dusk; now FX's flame recipe (dust.png sprite, additive, alpha ramp to 0, no shadow), one shared
  quad/material (`Props._fire_quad`). Checked with siteshot camp.
- Tests: t/combat/admiralty_hunter (checks "Greycoat"), t/progression, t/weapons/fist_sea_king.

## 2026-10-24: the fog isle's giant trees (Zach's pick)
- **What:** the fog isle's big trees replaced (Zach didn't like the bare oaks, willows and dead firs; he asked for "big
  spooky trees that can make big spooky forests" and sent a photo of a misty gnarled wood). Picked from five candidates
  rendered as single trees and 3x3 groves: **the spiral giant** (24-32 m, a 1.8-2.3 m trunk twisting like wrung rope with
  two strands wound round it, six or seven limbs ending in tightening curls) as the main tree, **the gnarled giant**
  (18-26 m, two or three twisting trunks from one mossy foot, limbs snaking 10-16 m out, some sagging to the ground and
  rising again, twig sprays, moss on trunks and limb tops) mixed in. Turned down: a hunched giant, a stilt giant on arched
  roots, a thicket giant.
- **Where:** `FogPlants.spiral_giant` / `gnarl_giant` and their helpers `_curl` (a turtle walk turning ever tighter about
  the axis across the limb), `_curl_crown`, `_snake` (a limb weaving side to side and arching or sagging), `_twigs`,
  `_shroud` (moss as two crossed fog_grass cutout cards hung upside down: dense at the limb, strands below). Dark grey-violet
  bark. FogTheme.meshes: giant/emergent spiral, fig gnarled, kapok both; canopy 0.5 -> 0.75 (the twisted wood 0.9);
  districts renamed (gnarled hollows, the twisted wood). dead_oak / dead_willow / dead_fir gone.
- **Collision:** a big tree may give its trunk radius as a 4th element ([body, detail, lean, r]); `GenIsland._add_giant`
  sizes its trunk collider and reserve by it (others keep 1.1 m: no change to the other themes).
- **Cost:** ~3.3-4.2k tris a giant (the old oak ~1.1k); the fog isle isn't in the Brinehollow bench, so watch F8 there.
  A lower-detail far version is the fix if it shows.
- **Tools:** `S.tree(parts)` and `S.grove(kinds, n, seed)` in model_samples.gd (modelshot: a big tree whole, a patch on the
  10 m giant grid). genshot seed 1 node 8 is a fog isle (Wraithholm Key).
- Tests: t/island/fog_isle, t/island/theme_registry, smoketest.

## 2026-10-24: v1.20 perf baseline (Zach: accept and release)
- prepush -Release failed the gate at 13:00: mean frame 10.33 -> 12.65 ms (+22%; confirmed back to back with the
  2026-10-15 baseline's commit). Grew most: Brinehollow's townsfolk (brinehollow_folk.gd and their rigs), harbour boats,
  moored hulls; ship, player and weather a little. Much of it predates 1.20 (the baseline was older than the
  Brinehollow life work). Zach accepted the numbers for 1.20; `perf_gate.ps1 -Update` rebenched: 12.89 ms (13:00),
  12.87 ms (21:00), 0.78 ticks a frame.
- **This baseline was taken on the min-spec PC itself** (Ryzen 5 5600G + RTX 3080), not the laptop: 12.9 ms there is
  ~77 fps, inside 60 fps. The "<= ~10 ms" target line is the laptop's; compare like with like (calib differs).
- Open: a perf pass on Brinehollow's folk and boats (lower rates far off, fewer rig updates) as its own task.

## 2026-10-24: 1.21 piece 1 (v1.20.1): the capital's docks and the noble quarter (docs/v1_21_plan.md)
- **Plan** (CapitalPlan.FLOORS 9-13): `docks` (6, 50, 120x15: a half-block row east off the market street, so the
  house rows either side front it), `wharf` (126, 38, 22x38), `e_postern` (130.5, 76: the harbour wall split at
  129.9/136.1 with an arch like the west postern), `terrace` (9.2, -65, 92.8x15: under the palace wall, ~1 m clear of
  it) and `terrace_step` (7, -60: round the palace gatehouse's corner to the avenue). SPECIAL `yardhall` (148, 44) and
  `outfitter` (46, -50); `_specials` skips them (built by the new steps). The quay stack at (132, 88) moved to (144, 88)
  out of the postern's way.
- **CapitalDistrict** `_docks`: lots fronting the docks are `warehouse()`s (plaster over a timber band, gable, cart
  doors, a loading door, a hoist beam and rope); cargo off the doors (`_door_near`), handcarts, timber stacks, the
  shipwright's hall (`_yard_hall`: an open boathouse, a hull's keel and ribs on stocks; its floor has a collider), the
  chandler's counter, the fence's corner (red tarp, crates, a lantern). `_terrace`: cypress pairs and flower planters,
  clipped hedges along both edges (gaps at doors and the outfitter's porch), a garden fountain with a figure, two lamps
  (one lit), the outfitter (a tailor's town house with a columned porch and counter). Lights 16 (the budget), surfaces
  394 (< 420).
- **CapitalLife**: 19 more people (Marta Coyle and her hand, Bram Haskett, Vesper Lark and two smugglers, three dockers,
  the foreman Gully Bracewell, Ysolde Ashgrove, four nobles, a guard). Shops: the chandler (grocer: timber, canvas,
  iron, rum; copper and more in the pool), the fence (treasure trade: rare blades with traits, buys loot at 1.15), the
  outfitter (treasure trade, tier +1: court gear). Quests 3 -> 5: "The lost manifest" (lost, on the wharf),
  "An invitation, by hand" (deliver: Lady Halloway to Odile at the inn).
- **The yard screen takes a shipwright's name**: dialogue event `shipwright:<name>` opens it as "<name>'s Yard"
  (`ShipwrightScreen.set_yard`; plain `shipwright` stays Tackett's); Coyle's yard does every line Tackett's does.
- Crowd lanes on the docks' row and the terrace; map marks (Coyle's Yard, the noble quarter). capitalshot: docks,
  wharf, terrace.
- Tests: t/capital (district: the new spots; life: five quests, the three shops, Coyle's yard by name), t/ship/yard_*.

## 2026-10-24: 1.21 piece 2 (v1.20.2): the palace (docs/v1_21_plan.md)
- **Open:** the grounds' gatehouse built open (`closed` false); the hill road walked: a collider slab under each 3 m step
  (its top the road's), its first and last steps down to the ground (no lip: the captain has no step-up), colliders on
  its parapets (off the side was a drop you couldn't step back up). The hilltop ring wall's points now even about the
  front (offset 0.11 -> 0) so a gatehouse (14 m) sits in the gap between points 3 and 4 (their towers dropped).
- **CapitalPlan:** floor 14 `palace_court` (-10, -151.8, 20x33.8: the gate to the porch steps' foot); HALL_C (0, -171),
  HALL_W 38, HALL_D 22, HALL_H 15, HALL_DOOR 4, `hall_floor()` (HILL_TOP + 0.8); `_open`: no barriers inside the grounds
  wall (open ground); `raised(q)`: the throne hall's floor (its dais +0.9), the porch's, the yard hall's plinth.
  **`CapitalIsland.hv` reads `raised` first**: people inside raised rooms stood at the hill/ground under the floor (the
  Queen was inside her dais).
- **CapitalModels.palace / _throne_hall:** the hall hollow: facade outside with the front split round an arched door,
  plaster walls inside, slab floor, dark coffered ceiling; colliders per wall (the door open), the floor, the porch
  floor and columns, a ramp under the porch steps. The keep moved back 3.5 m and the back towers 3 m (both had stood
  2 m inside the hall's back corners).
- **CapitalDistrict `_throne` / `_court`:** carpet, ten columns, a three-step dais over a ramp collider, the throne,
  banners, side windows, two chandeliers, one light lit all day (lights 17); the court's statues and potted cypresses;
  spots queen, hall_guard*, courtier*, court_guard*, chamberlain, signet (under the fence's hatch on the wharf).
- **CapitalLife:** Queen Ilsabet, Lord Chamberlain Orme, four guards, two courtiers; the gate guards' and the sergeant's
  lines now say the grounds are open. **KitQuests `"after"`:** a quest offered only once another is done. The palace
  line: "A petition to the Crown" (deliver: sealed by Ambrose Pell), "The Queen's signet" (lost, on the wharf, after),
  "An audience with the Queen" (deliver: to the Queen, after; 250 gold).
- **capitalshot:** court, throne, queen shots; its stand-in captain moved to the plaza (people hide past 230 m from
  every captain: the slum was 233 m from the throne).
- Tests: t/capital/palace (new: the gate, the road's slabs, the ring gate, the court, the porch ramp, the door, the
  walls, the hall floor, the dais), district (spots, 18 lights, two lit all day), life (8 quests, the chain waits),
  shell (floors may open into the grounds).

## 2026-10-24: 1.21 piece 3 (v1.20.3): the arena and its ladder (docs/v1_21_plan.md)
- **Walked in** (CapitalModels.arena): the west gate's arch open (its piers and the wall over it still collide), a cut
  through the stands to the sand (seat segments touching the west point dropped, walls either side, `ARENA_CUT` 2.6),
  the sand at the ground (y0 + 0.03, was 0.4 over the ground you stood on), a podium wall collider round the sand
  (`arena_inner()`), the gap at the cut. Floor 15 `arena_gate` (67.5, -2, 4x4: on the barrier code's 1 m samples, or a
  barrier stood across the gate). Shell test: floors may open into the arena.
- **ArenaBout** (scripts/game/arena_bout.gd, host-run): a RivalDuel AI on every screen (`_all_spawn_rival`) opposite the
  captain across the sand's middle; the first under END_AT (0.1) of their health or down loses; the rival held then
  gone after 3 s (`_all_rival_gone`), the captain stood up if beaten (`_all_rival_stand`); the result on every screen
  (`Net._all_arena_result` -> `ArenaBout.result`): the captain's own machine pays the purse (40/60/90/130/180/300,
  defence 80) and moves `Player.arena_rank` up (saved; `arena_defended_day` too); rank 6 = champion: the Champion's
  Sabre (resources/items/champion_sabre.tres, katana, rarity 4, rushing) and, only once DevilFruits.IN_WORLD, a 25% roll
  at a Driftfruit (the 1.23 hook). Fighters: Pip Tanner (cutlass 0.25), Big Garran (warhammer 0.4), Selene Vasquez
  (katana 0.55), Old Corran (spear 0.7), Ines Ravel (greatsword 0.82), Aurelio Quint (katana 0.95); challengers 0.85.
- **Net:** `request_arena(kind, rank)` (host: `_start_arena`; guest: `_ask_arena` RPC with its own rank); the host
  finds the capital by group `capital` and its `arena_sand()`.
- **CapitalLife:** Arena Master Corvin Bale on the sand by the cut (his choices by your own rank; "arena:<kind>:<rank>"
  events to Net.request_arena); the crier, the board, the sergeant and Odile say the arena's open. District `_arena`:
  the crowd in the stands (one mesh, ~250 figures, none over the cut), the master's spot.
- **Not done (assumed decision):** wooden practice blades are visual only and not built yet (the small fixes batch).
- Tests: t/capital/arena (new: the way in, the sand, the podium, the crowd, a ladder win, the champion's prize, a lost
  and a won defence), t/capital (all).

## 2026-10-24: Harbour vendors (1.21 piece 6)

- `HarbourVendor` (scripts/island/harbour_vendor.gd), on the Artisans pattern: about half the chain's generated
  islands (CHANCE 0.5, the island's seed + SALT 7823: its own stream, nothing else draws differently) have someone by
  the pier's root (`GenHarbour.at(s, d)`: 4-18 m along the shore, 2.5-9 m up from the water, dry, fairly flat, off
  the paths; 2.6 m reserved before the plants). Planned in `GenIsland.prepare` after the artisan (body stocked with
  the villagers'), built in its finish step "vendor" (a crate, a barrel, a glow-only lantern post, the NPC).
- Kinds: the Caulker (armour, copper), the Gunsmith (guns, chaser), the Sailmaker (sails, nest, ropes), the Joiner
  (rudder, lanterns, rails), the Carpenter (galley, chest, grove): Tackett's lines and prices, only theirs; and the
  Chandler, a shop of timber/canvas/iron/copper.
- The yard filter: dialogue event `shipwright:<name>|<line>,<line>` (GameMenu) -> `ShipwrightScreen.set_yard(who,
  lines)`: the other rows and empty group heads hidden, no Paint tab. Plain `shipwright` / `shipwright:<name>` show
  everything again. Refits go through the host like Tackett's (Net.request_upgrade); guests build the same vendor.
- Tests: t/economy/harbour_vendor (new), t/economy/artisan_camp.

## 2026-10-24: The canal city (1.21 piece 4)

- The chain's second city (Chain.CITY_LAYERS[1], names rolled from CANAL_NAMES: Saltmere, Lantern Reach, Brackwater):
  `CanalIsland` (scripts/island/canal_island.gd) extends CapitalIsland and reuses its whole pattern: a fixed plan in
  the city frame (`CanalPlan`: x along the harbour, +z to sea; QUAY_Y 1.6, FRONT_Z 110, land a disc LAND_R 215 round
  LAND_C), pieces built on a worker (`CanalShell`: quays, sea wall, coast, 11 bridges, campanile and dome, the massing;
  `CanalDistrict`: the dressed houses on every lot that fronts a calle or campo, washing lines, moored boats, the
  campi, the piazza, the market, the inn, the arsenal with a hull on the slip), people and services in `CanalLife`.
- The plan: CANALS (the grand canal, two side canals, the basin), BLOCKS with their quays, the RIVA along the front,
  the PIAZZA, the ARSENAL Rect2(128, -62, 42, 68). `lots()` cuts each block into bands between its thin E-W floors,
  rows no deeper than 12 m, spans cut round every lane, filled edge to edge, so houses line every walk (no barrier
  walls along the lanes). `openings()` closes the gaps that are left with barriers.
- Getting round: bridges, and water taxis (6 boatmen, LANDINGS: 6 stops; `CanalLife.ride(to)` fades and sets you
  down at the other landing). The crowd is CapitalCrowd on CanalLife.LANES with CanalPlan.ground.
- Services: the grocer, the fishmonger, Fiore Glass (treasure), Salt's Chandlery (the yard's materials), the inn,
  Master Ottavio Grane at the arsenal (the shipyard, below), Father Anselm, three quests.
- About 828 lots (449 fronting) and ~765k triangles in all, with visibility ranges; people hide past 230 m (ActorSleep).
- Tests: t/canal/plan (floors apart, bridges land on floors over water, landings at the water, lots off the floors),
  t/canal/city (built: standing on the riva, canal beds, bridge decks, doors on walkways, people, boatmen, shops,
  the arsenal, three quests, a taxi ride, the light and surface budgets); tools/dev/canalshot.gd renders it.

## 2026-10-24: Ship classes and the caravel (1.21 piece 5)

- `ShipClasses` (scripts/ship/ship_classes.gd): the sloop and the caravel. A class changes handling and carrying,
  not the deck (every class shares HullBuilder's layout, so every job aboard works the same); the caravel shows a
  lateen mizzen aft. Zach's numbers: 13 m/s, turn 0.68, accel 3.1, hull 340, no quarterdeck pair, a bow chaser
  fitted, +4 bag slots; 1,400 gold, 6 timber, 4 canvas, 2 iron.
- The kit carries "class" and "fleet" (laid-up ships with their own upgrades and paint), synced with Net.set_ship_kit.
  `Ship.apply_kit` applies the class (hull, `_top_k`, `_turn_k`, `_accel_k`, aft guns, chaser, slots, the mizzen).
- Bought from Master Grane at the canal city's arsenal (dialogue event `ship:buy:caravel`), switched at any city
  shipwright (`ship:switch:<class>`: Grane, Coyle): `GameMenu._ship_event`, through the host (Net.request_ship).
- Tests: t/ship/caravel (short of the price, bought, her numbers, laid-up sloop kept, switching back).

## 2026-10-25: 1.21 small fixes: practice blades, the fog giants' far versions

- Arena practice blades: `Humanoid.practice` / `set_practice(on)` shows whatever's held as `Props.practice_mesh(mesh)`
  (every surface one pale wood material, the same "model" meta, cached by model). `ArenaBout` turns it on for both
  fighters at the bell and off for the captain at the end, on every screen (`Net._all_practice(keys, on)`, which finds
  a player's rig as `body_model`, others' as `humanoid`). t/capital/arena checks it.
- The fog giants' far versions: `FogPlants.spiral_giant` / `gnarl_giant` build the tree twice from the same seed
  (`_with_far`): the far one with tubes at half their sides (`_s`) and the strands, moss and mid-limb twigs drawn into
  a throwaway builder (`_near`) so the rng runs the same and it's the same tree (the end sprays stay: they make its
  outline). A big-tree entry [body, detail, lean, r, far]: GenIsland buckets the body as "giant_near" (to GIANT_NEAR
  180 m) and the far one as "giant_far" (180-1100 m, no shadow). ~3.4k -> 1.8k and ~5.3k -> 1.9k triangles a tree.
  t/island/fog_giants_far (new).
- Dive light shafts: Weather's "DiveShafts" (shaders/world/dive_shafts.gdshader), 26 long additive quads in one
  MultiMesh built once: each beam's offset sits in a 48 m tile (SHAFT_TILE) that the vertex shader wraps round the
  camera, hung from the surface down along the sun bent steeper by the water, turned to face the camera round its own
  axis, swaying and shimmering on TIME (visual only). The CPU only sets uniforms while you're under: on by day
  (`_update_shafts`: the sun's height, less in storms and heavy cover, dimmer the deeper), fading with the water's own
  fog distance. t/swim/dive_shafts (new).
- The sky: Zach picked look C (2026-10-24), the raymarched cloud deck in psx_sky.gdshader (14 steps, 5 in the
  radiance cubemap pass; one sample toward the sun per step for its shade); the 2D cloud layer and the other looks
  are gone. The 3D puffs (PuffClouds) stay blended and sorted (a dithered try aliased, 1.10's notes; the sort is
  ~600 keys 7 times a second).

## 2026-10-25: The city detail pass (1.21, piece 1.20.5)

- Chimney smoke: `CitySmoke.make(tops, seed)`, one GPUParticles3D per city with every other chimney top as its
  emission points (an RGBF points texture), FX's dust billboard, 3 puffs a chimney, nothing on the CPU after it's
  made. The tops are gathered while the builders run: `CanalShell.smoke_tops` (the funnel chimneys) and
  `CapitalModels.smoke_tops` (new brick stacks, `CapitalModels.stack`, on two houses in three, from their own rng
  stream), cleared and read in each island's prepare; the "smoke" finish step adds the emitter under the City node.
- Pigeons: `CityPigeons` (one MultiMesh, scripts/island/city_pigeons.gd + shaders/world/city_pigeons.gdshader):
  9 birds a flock on the squares (the capital's plaza, the canal city's campi and piazza: `pigeon_flocks()`),
  pecking, hopping, and lifting off flapping over a captain who walks into them (the local captain's position as a
  uniform, 7 times a second); lit by the scene (unshaded, they glowed white at dusk). Range 90 m.
- House fronts' warmth (`CapitalDistrict.warmth`, both cities; own rng stream): a lantern on a bracket by 2 doors in
  5 (the city's glow material), ivy climbing 1 front in 5 from a corner, a geranium pot on 1 doorstep in 3. On the
  canal city's walkway houses, the capital's townhouses and warehouses (beside the loading door). Kept in the city's
  own materials: the capital's district stays under its 420-surface budget (419).
- The canal city's crowd: `CanalLife.lanes()`, LANES with twice their walkers plus a lane down every calle and quay
  walk 20 m+ long (one walker per 28 m); four more café regulars (cafe1, 2, 4, 5). The piazza's middle: a two-tier
  fountain, four benches round it, two flower barrows.
- Leftover worktrees cleaned (21 landed, clean ones removed with unwork.ps1; kept: three with uncommitted changes,
  dw_main / dw_ref_* and the app sessions' own).
- Checked: t/capital, t/canal (all), renders at eye height by day and dusk (canalshot, capitalshot).

## 2026-10-25: v1.21 released (stable), and the perf pass's findings

- Released stable v1.21 (Cities) after the unstable 1.20.1-1.20.5. prepush -Release: tests green, perf gate PASS at
  both lights (ALL 12.33 ms at 21:00, -4% on the 1.20 baseline; the capital's stops +1..6%, the detail pass).
- The planned Brinehollow perf pass came out a trim only (far birds past 300 m turn every 4th frame). The bench's
  script table (plaza, 13:00): proc_scr ~5.5 ms of a ~15 ms frame, GPU ~3.6 ms: CPU-bound. The steady costs are
  spread: humanoid rigs (NPCs 0.47, the player 0.26, the folk 0.20, the crowd 0.12 ms), sky_birds 0.28, sea_spray
  0.15, fauna_spawner 0.14, actor_sleep 0.13, ambience 0.13, weather 0.10. No single fix wins back 22%: the real win is
  moving rig animation and the flocks to the GPU (vertex-animated crowds and birds), its own task (gpu-first).
- Co-op test hardening on the way: nettest board holds its boarders on deck from boarding (under load the late guest
  found them over the side); nettest rival's blow is unblockable with up to three tries (an AI captain guards).

## 2026-10-25: the GPU pass (birds, wind streaks, foam, far townsfolk)

Frames are CPU-bound (1.21 bench: proc_scr ~5 ms, draw ~4.3 ms of main thread, GPU ~3 ms), so per-frame animation
moved into vertex shaders; the CPU now writes a row only when something is born, joins or changes.
- **High flocks** (SkyBirds WHEEL / VEE: the dark flocks and vultures): their paths were already sums of the clock
  (`_target`), so a flock bird on its path (within ON_PATH) joins a second MultiMesh ("Flocks",
  shaders/world/sky_flock.gdshader) with a 16-float row in a 4 x MAX RGBAF texture (centre, height, angle at clock 0,
  angular speed, radius, seed; a V's rank offsets; size, wingbeat, glide rule). The shader places it, heads it along
  the path, banks it by the turn rate and pitches it with the climb (the path a moment either side), and beats or
  glides the wings by `_wings`' rule. The flock and circle angles are now `a + w * (t - t0)` (`_ang`, no per-frame
  `_advance`). A GPU bird comes back to the CPU (`_off_gpu`, where its path has it, flying on) only to leave for the
  night or a storm or when its island's let go; `where(b)` is a bird's live spot (a GPU bird's "pos" refreshes once a
  second). The bird look moved to shaders/sky_bird.gdshaderinc (shared by both shaders).
- **Wind streaks** (SeaSpray): shaders/world/wind_streaks.gdshader flies a streak along the wind, turns it edge-on to
  the camera and fades it from its birth time; `_streak()` writes its slot's row once (origin, direction x length,
  width; custom: born, life, speed) and the buffer goes up only on frames with a birth.
- **Foam patches** (SeaSpray): shaders/world/sea_foam.gdshader drifts a patch downwind from its birth and rides it on
  the swell with the ocean's own wave sums (`#include ocean_waves.gdshaderinc`; SeaSpray copies the ocean material's
  wave uniforms every second, its clock and storm cells every frame), tilted to the slope, fading in and out. No more
  CPU wave samples for foam; a patch out of reach is let go twice a second (`foam_at`).
- **Far townsfolk** (FarFigures, scripts/world/far_figures.gd + shaders/world/far_figure.gdshader): a lod rig whose
  owner allows it (`Humanoid.far_figure`: NPC.setup sets it, so villagers, Brinehollow's folk, the capital's and
  canal's life, vendors, artisans) hides its body (pivot) past ON_R 40 m (back inside OFF_R 35) and is one instance
  of a shared MultiMesh of a boxy figure (UV.x = the part) in its look's colours (top/coat, legs, skin, hair/hat:
  packed 8 bits a channel into exact floats). The shader swings legs (knee bending) and arms in step with the ground
  covered, bobs it, sits it (thighs forward onto `seat_y`), and slides it on along its heading at its speed between
  rows (up to 1 s, so a sleeping owner's figure stands still). The rig writes its row only on the frames it would have
  posed, and not at all while its transform and speed are unchanged (a far villager moves its body every 0.3 s: a
  row from a stale spot would step it back). Rows go to the server once a frame on RenderingServer.frame_pre_draw,
  so a swap never blinks. A body was ~19 draws (its shadows already off past 28 m); every figure together is one.
  Freed on hide (NOTIFICATION_VISIBILITY_CHANGED), leaving the tree, a ragdoll or an action. Kneelers stay bodies.
  Cosmetic and each screen's own: co-op sends nothing (the bodies' positions are already shared).
- Tests: t/world/sky_flock_gpu (rows mirror `_target` at any time; hand back on leaving), t/world/far_figures (row,
  colours, pace, heading, seat; no posing; swap back; freed on hide), t/world/sky_long_tail (a streak's and a foam
  patch's rows at birth, the foam's uniforms copied from the ocean). Expected to touch skytest (it reads high flock
  birds' "pos", refreshed once a second), lifetest and villagetest (NPC rigs far off are figures).
- **Measured** (laptop bench = the 5600G + 3080, gate mode). Back to back on one machine state (a checkout of
  d6621f0b vs this branch, one run each, bench_compare): ALL 13.66 -> 12.71 ms at 13:00 (-7%), 13.34 -> 12.34 at
  21:00 (-7.5%); the town stops -9..-15% (proc_scr -10%, Jolt -25%: far bodies' StaticBody/skeleton work gone, GPU
  -15%); scripts: NPC rigs 0.47 -> 0.36, sky_birds 0.26 -> 0.19 (by day; 0.12 at night), sea_spray 0.16 -> 0.08,
  arm_body + lower_body 0.35 -> 0.27, folk rigs 0.21 -> 0.17. perf_gate.ps1 (best of 2 vs perf_baseline.txt): PASS,
  ALL 12.89 -> 12.38 (13:00), 12.87 -> 12.41 (21:00), -4%, with this machine's calib ~3% slower than the baseline's.
  Not yet the brief's "clearly under 12.3": the near rigs (< 30 m: NPCs, folk, the player, 0.9 ms in the plaza) and
  `draw` (~4.5 ms, ~1250 draws) are what's left. Next levers: ON_R lower (30 m; a look call for Zach), the skinned
  limbs' helper bones (ArmBody/LowerBody, 0.27 ms), fewer draws in town.

## 2026-10-25: The intro switched off

- Zach: the opening at sea is "too unpolished"; a new game wakes on Brinehollow's beach again (as before 1.19).
  `Intro.ENABLED := false` gates it in Player's first-time creator path; the code, t/ui/intro and its render stay
  (they call `Intro.play` directly), ready to switch back on once it's polished.

## 2026-10-25: 1.22 piece 1a: a crew of five

- `Net.MAX_CLIENTS` 4 (five captains); a fifth crew colour (orange); `extra_attackers` up to +3 (3-5 captains:
  +1, +2, +3), hp_scale carries on (1 + 0.6 per extra captain); the title's co-op hint says five.
- Co-op test mode **five** (`nettest.ps1 five`, by hand like three: five Godots): three watchers (netwatch.gd's third
  arg is the crew size) and the client; the client stays until it has seen all five in the roster at once
  (`most_roster`), then leaves; watchers check they see the host and that the roster reached five. Test fixes on the
  way, from five worlds loading on one machine: watchers knock again when a join times out (like netclient), print a
  line every 20 s, wait longer; the host waits up to 3 min for the last guests; the client's grunt-toughness check
  accepts a scale a step behind the roster (a captain counts once their world's loaded).
- The crew's data (1.22 piece 1b): `GameManager.crew` {"name", "members": {char id -> {"name", "seen": Weather.day()}}},
  saved with the host's world (a guest's save keeps its own), sent in `Net._world_state`. The host decides:
  `Net.crew_member(info)` (the host on hosting, a captain as they come aboard: `net_info` now carries "char",
  `SaveGame.char_id()`), `Net.crew_rename(name)` (trimmed, 28 at most; the Captain's), `Net.kick(id)` (rejected
  "The Captain sent you ashore", then disconnected); everyone applies `_all_crew`. `Net.crew_name()`: its name or
  "<Captain>'s Crew". Test: t/coop/crew_roster (new).
- The Crew screen (1.22 piece 1c): `scripts/ui/crew_screen.gd`, the pause menu's Crew: the flag (ShipKit.flag_image), the name
  (a LineEdit + Rename, and Flag opening the ship's paint: `GameMenu.open_flag`, the Captain's only), aboard now (colour,
  name, ping, the Captain's Kick), sailed with us (last seen in game days). Refreshes on `Net.roster_changed`.
  t/coop/crew_roster opens it.
- The crew's emblem on the main sail (1.22): `Ship._sail_emblem(kit)` builds a patch on the sail's own two planes
  (`_sail_corners`, 0.12-0.88 across, 0.27-1.73 down), a hair in front and mirrored behind, a child of the Sail node
  so it fills, flaps and furls with it; `ShipKit.sail_emblem_image(kit)` (30 px, the mark colour, clear elsewhere) on
  the cutout shader. Six more emblems (`EMBLEMS`): Kraken, Trident, Rose, Sun, Wave, Raven. yardshot `lines=emblems`.
- Tackett's yard (Zach: "many of the upgrades should be only seen for the first time at a city"): `ShipLines.HOME_LINES`
  (hull plating, gun deck, sails and rigging, rudder and helm, the ship's hold); plain "shipwright" opens those only
  (with paint); the cities' "shipwright:<name>" everything; a vendor's "|lines" its own without paint
  (`set_yard(who, lines, paint)`). Lines already bought stay on the ship. t/economy/harbour_vendor checks it.
- Rejoin crew (1.22): `CrewBook` (scripts/net/crew_book.gd), a guest's own list in user://crews.json ({name, address},
  newest first, 6 kept); Net notes the crew when a host's world arrives (`join_address`; never in a tool run), the
  title's co-op panel lists 4 as one-click rejoin buttons. Quest rewards go to the whole crew wherever they are
  (Journal: the REWARD_REACH check gone; t/quests/rewards_present updated).
- 1.22 loot (Zach's approved tables, scripts/items/loot.gd): 60% of kills that carry coins pay (KILL_COIN_CHANCE);
  trophy parts (is_loot: tusks, plumes, hides, chitin) at PART_K 0.3 of their table, hunting food as it was; a
  grunt's own weapon ~2% (DROP_PISTOL 0.012, DROP_BLADE 0.008). Chests: their weapon stays by kind (ARMS_BY_KIND:
  ordinary 25%, hidden (dive, buried, map, wreck, treasure in its id) 50%, hoard always), its rarity rolled round the
  island's tier (`rarity_round`, RARITY_SPREAD [-1, 0, +1, +2]), nothing past blue under tier 3; loot traits only from
  purple up (LOOT_TRAIT_TIER; vendors keep theirs). Brinehollow's hand-placed chests: always a weapon, a random pistol,
  cutlass, dagger or axe, green or 15% blue (HOME_KINDS, HOME_BLUE): no two captains the same. t/economy/drop_rates.
- The party panel (1.22): the HUD's crew rows get a fifth column, `PlayerHUD.party_where(p, down)`: "DOWN 40m NE",
  "helm" (a guest at the wheel), "guns", "swim", or the distance and bearing past 30 m. t/ui/party_where (new).
- Crew on the chart (1.22): the crew's dots named (and red with "(down)" when bleeding), the Captain's flags 1.5x,
  `Net.MAX_WAYPOINTS` 8 a captain (the oldest goes); marks were already the crew's (Net.waypoints, synced).
- Map polish (1.22): middle mouse held pans the held map (MapHold `_panning`: the mouse moves the view, not the pen;
  `SeaChart.pan_off` / `MapIsleView.pan_off`, a zoom puts it back), "MIDDLE PAN" in its hints; the chart's legend (you,
  crew, ship, mark). On-screen marks: the 4 nearest (MarkerLayer.SHOWN), the rest "+N more marks (M)", one you stand on
  fades. t/map/map_pan (new).

## 2026-10-26: 1.23 sea pursuit (docs/v1_23_plan.md, "Sea pursuit" and "Marines")

Ships at sea can catch and trap the crew's ship. All host-simulated; the crew's side rides the ship's damage
packet (`Net.ship_damage([breaches, fires, flood, torn, lines])`), so guests see it and do the jobs through
`Net.ship_work` like patching holes.

- **Chain shot** (piece 1): `ShipCannon.chain` (sent with the fire event), `Cannonball.chain` (two half-balls on a
  bar, spinning; half a ball's hull damage). Kinds with `"chain": true` (brig, marine, later hunter, frigate) load it
  for a volley when the crew is getting away or on the opening volley (`EnemyShip._wants_chain`), aimed at the
  mainsail (`CHAIN_AIM_Y`, half the scatter). The host's copy of a ball passing through the canvas box round the mast
  calls `Ship.tear_sail`: `torn` [id, mend slot, patch], up to MAX_TORN 3, each TORN_SLOW 0.18 off top speed
  (`sail_k()`); a ragged dark patch hangs on the sail node. Mend: hold F at `MEND_AT[slot]` (foot of the mast),
  MEND_TIME 3 s (Seamanship "repair" shortens it).
- **Grapples** (piece 1): when the boarders leap (`_board`), the hooks bite: `Ship.lash(by, side)` adds three
  `lines` [id, rail spot, holder key, holder-local end]. Lashed, the crew's top speed is LASHED_SPEED 2.2; the holder
  in HOLD is hauled to her alongside spot and kept to the crew's pace, sends another party PARTY_AGAIN 8 s after one's
  beaten (while men are left), and breaks off once `lines_of(self)` is 0. Cut: hold F at the rail by a line,
  CUT_TIME 1.1 s. Lines let go when the holder sinks or is gone, part after 1 s strained past LINE_SNAP 26 m, and go
  when nobody's left aboard the crew's ship (`unlash`). Hook and rope drawn on every screen (`_ropes`, world-space
  rope to the holder's interpolated transform). A banner "Grappled!" / toast "Cut free!" on every screen.
- **Hunters and the frigate** (piece 2): KINDS "hunter" (pirate: 13 m/s, hull 190, two guns a side, chain shot,
  `"downwind": 0.2` more speed running before the wind, fading out by a beam reach: ~16 m/s downwind, 13 into it)
  and "frigate" (Admiralty: 11 m/s, hull 480, four guns, double broadside, chain). `ADMIRALTY_KINDS` replaces the
  old `kind == "marine"` checks (group, crew looks, barks, the bounty gate). Sea legs: hunters from level 10, a
  frigate zone at 18 (`SeaLegs.FLEETS`). Salvage/Seamanship tables have both.
- **Fleet tactics** (piece 2): closing in (HUNT), `_tactic` (4 Hz) gives each ship on the crew a part by its place
  among them sorted by name: "chase" (her wake, as before), "cut" (where she'll be in dist/speed s, 4-18, plus 25 m),
  "gauge" (upwind of her by its far range); near land or a reef (`_land_near`: no_go circles and SeaFeatures reefs
  within PIN_REACH 170 m) the second and later "pin" her from the open-water side (PIN_OFF 45 m). `tactic_role`,
  `tactic_at`. MAX_ATTACKERS stays 2 for pirates.
- **Rams hole the hull** (piece 3): `_ram` adds a breach at the struck spot (side and z from the contact point),
  RAM_HOLES 2 for a brig or frigate, on top of the hull damage (hull_hit may add its own random one).
- **Boarding boats** (piece 3, `scripts/ship/boarding_boat.gd`, BoardingBoat): in BROADSIDE, a boarding kind that
  can't catch the crew (not `catchable`), after a volley, 28-110 m off, BOAT_EVERY 35 s, lowers a longboat on her
  side toward the crew with up to BOAT_MEN 3 of her next men (their own Humanoid bodies reparented into it, `seated`
  on the thwarts). It rows at 14 m/s on an intercept for a spot 2.2 m off the crew's side; there
  `EnemyShip.boat_landed` turns the men into boarders ("BD" grunts, `_turn_grunt`) who leap aboard. A crew ball
  splashing within 4.5 m (`Cannonball._splash` -> `BoardingBoat.near_splash`) or 40 HP of fire (siege x3) sinks it
  with the men (25 XP). Gives up after 50 s. Co-op: `Net.event(ship, "boat", [men, side, n])` builds it on every
  screen (Boat_<ship>_<n> beside her), net_sync snapshot [pos, yaw, state]; a captain joining mid-row won't see that
  boat (it's gone in a minute).
- **Group "pursuing"** (for the lead's HUD heat marker): an EnemyShip is in it while `pursuing()` (HUNT, BROADSIDE,
  BOARD, HOLD, RAM; TRACK from piece 4), on every screen from the state its snapshots carry.
- **The Admiralty at sea** (piece 4, `scripts/ship/admiralty.gd`, one node "Admiralty" under the world, made by
  the fleets (`Admiralty.ensure`), a net_spawner whose `net_gen` is the live ships' specs and booms, so guests and
  late joiners build the same ones). Everything scales by the crew's **heat tier** (`EnemyShip.crew_heat_tier`: the
  hottest captain's `Bounty.heat_tier`, which cools without deeds); the old Notorious gate on marine patrols uses it
  too.
  - **Deeds**: `Admiralty.deed(tree, at, what)` (static, host; the public hook: the island arcs call it with "arc"
    when one finishes; `Net.bounty("boss", ..., k >= 1)` calls it now, so an island boss beaten counts; a miniboss's
    0.4 share doesn't). One answer per DEED_EVERY 480 s. From Notorious (BLOCK_FROM 2) a **blockade**: two marine
    ships (role "block", state BLOCK: anchored broadside, HUNT once the crew comes within NOTICE) BLOCK_OUT 30 m past
    the island's no-go edge on the crew ship's side, BLOCK_SPREAD 46 m apart, and an **AdmiraltyBoom**
    (`admiralty_boom.gd`: chained logs on collision layer 1 across the gap; 120 HP of crew fire breaks it, or her bow
    at RAM_SPEED 7 m/s+, taking RAM_HULL 25). Then, once the crew's ship is out at sea (huntable, past the island's
    edge + STANDOFF + 20), a **ring**: RING_N [0, 2, 3, 4, 5] by heat tier at RING_R 135 m, side-on, in HUNT (a
    frigate in it from Infamous). Signal `deed_answered`.
  - **Heat patrols**: at sea with a captain aboard, every PATROL_EVERY [-, 300, 200, 140, 95] s of game time with no
    pursuer out, PATROL_KINDS (cutter; two cutters; frigate + cutter; frigate + two cutters) appear SPAWN_R 330 m back
    along her **wake** (points every WAKE_EVERY 4 s, WAKE_LIFE 150 s, half in a storm) in state TRACK: they follow
    the wake (`trail_from`) at full speed, go HUNT once she's within NOTICE x sight x 1.4, and give up past
    LOSE x sight x TRACK_LOSE 2.2. Pursuers lose her in HUNT/BROADSIDE past LOSE x `Admiralty.sight_k` (fog to 0.45,
    storm to 0.6: the weather's or a sea fog bank's/storm cell's at her position). Lost: `_lost` (PATROL, heading
    away, never re-noticing); cleared once DESPAWN 480 m from every captain. Banners on every screen: "The
    Admiralty!" when the first pursuer starts, "Escaped" when the last loses her (signals `hunt_started`, `escaped`;
    the lead's HUD counts group "pursuing").
  - EnemyShip: S gains TRACK and BLOCK (appended: snapshot ints unchanged), `pursuer`/`role`/`start_role`,
    `pursuing()`; pursuers skip MAX_ATTACKERS and the bounty gate.
- Tests: t/ship/chain_shot, t/ship/grapple_cut, t/ship/fleet_tactics, t/ship/ram_hole, t/ship/boarding_boat,
  t/ship/admiralty_ring, t/ship/admiralty_hunt; t/ship/enemy_boarding holds her boat (it tests grapples).
  Render: `pursuitshot` (tools/dev/out/pursuit_*.png).
## 2026-10-26: 1.23 perf track, piece 1: the spike logger
- Zach: the game "feels heavy at times". `Perf` (scripts/game/perf_monitor.gd) now logs every frame over
  `SPIKE_MS` 25 ms (was: hitches over 50 only) with what ran in it: physics ticks run in the frame, the process /
  physics / render split, pipelines compiled, nodes made; the **timed sections** (`Perf.add_us(Perf.ANIM, us)`: anim
  = rigs posed, ai, build, spawn, sleep, fx: ms/calls), the **slowest named steps** (`Perf.step(what, us)`: chain island
  build steps, "into the tree", freeing a let-go island), what was **spawned** (SceneTree.node_added: count and by
  script), who was **awake** (enemies awake/all, AI captains, ActorSleep's actors awake/all and hidden:
  `ActorSleep.tally()`), **co-op** (host/guest, captains, worst ping), the captain's state and place, and the marks.
- A run of slow frames writes a line every 0.25 s (every hitch over 50 ms always); 20 lines a half minute at most. The
  30 s line has `spikes N` beside `hitches`. Release builds log too (user://perf.log, last five sessions kept).
- `Perf.recent`: the last 16 spike lines; the F12 capture's .txt lists them ("## Last spikes").
- Humanoid's posing moved to `_pose(delta)`, timed in `_process` into the statics `Humanoid.anim_us` / `anim_n` that
  Perf folds into ANIM each frame (humanoid.gd can't name the Perf autoload: a --script compiles it first) (wallclock_allow:
  `scripts/npc/humanoid.gd:_process`). Cost on a normal frame: two fills of a 6-int array, a ticks read, and per posed
  rig two usec reads and a call (~0.5 us a rig); node_added a call per node added.
- Hooks for the enemy brains (lead's files): `Perf.add_us(Perf.AI, Time.get_ticks_usec() - t0)` round a brain's think.
- Tests: t/world/spike_log (new: a frame forced over 50 ms with a step timed in it and a node spawned is in
  Perf.recent, the perf log and the F12 text with its cause), t/world/perf_log (spike line), t/world/actor_sleep.

## 2026-10-26: 1.23 perf track, piece 2: island builds on a frame budget
- The lead's 1.23 bench, stop "isles" (a chain island built while you stand there): 41 frames over 33 ms, each a
  build step of 15-50 ms on top of a ~16 ms frame. Steps now keep to ~3 ms a frame where they can:
- **Breathing steps** (GenIsland): WorldGenerator runs each step budgeted (`isl.budget()`); a long step's loops
  `await GenIsland.breathe()`, which past `BUDGET_US` 3000 waits for the island's `resume` signal (emitted once a
  frame by `_finish_step` while `e[7]`, a step waiting) and goes on. Straight through (finish: tests, tools,
  islanddump) breathe returns at once. Everything between breathe and the step's Callable must `await`, or the step
  ends early (the lambdas: `func(): await build(isl)`). Let go mid-way, the island is freed and the step never
  resumes; nodes a step fills before they join the island go on `isl._unparented` (freed with it). `run_step` returns
  the step's worst slice (the hitch), build_ms keeps its main-thread total. Breathing now: KitWayside.build (a find
  or a piece of dressing at a time), KitTemple.build (between walls, roofs, hall, shrines, sanctum, vines),
  KitDungeons' dripstone and wall passes (a room at a time).
- **Ground colliders** GROUND 4 -> 8: 64 squares of ~3 ms joining the physics space (16 of 12-16 ms).
- **Beasts:** the boss and beast steps no longer wait on the worker's prebuilt models inside the frame (150-200 ms
  with the workers busy on the next islands' prepare): `GenIsland.step_ready` holds them a frame at a time until
  the task is done, and the prebuild task is high priority.
- DrawLOD.steps 3 ms slices (was 4).
- Measured (t/island/build_budget_same, headless under test load, worst slice ms): ground 3, wayside 3 (were 12-16
  and 28-61). Still whole: village shops 20, village houses 15, dungeons 15 (the shell's mesh and rock collider),
  harbour 13, boss 13, terrain 12 (one mesh upload), colliders 10 (the trees' body joining), draw lod 9 (its walk).
  Houses and shops need KitHouses.room / Buildings.house to breathe (shared with Brinehollow and the harbours: every
  caller in a budgeted step would have to await); next in line if the spike log points there.
- Brinehollow is untouched (StarterIsland uses none of these paths). Tests: t/island/build_breathe (the mechanism),
  t/island/build_budget_same (seed 4242's first island budgeted vs straight through: the same geometry, colliders
  and lights node for node; the wayside under 8 ms), t/island/wayside, build_slices, free_slices, beast_prebuild,
  forest_places, dungeon_nest_sleep, fog_isle.

## 2026-10-26: 1.23 perf track, pieces 3-5: rig LOD for AI captains, the native candidates, budgets
- **Piece 3 (AI and animation LOD).** Far rigs already pose at 30/20/10 Hz in view (Humanoid._lod_every: every frame
  within 20 m, then every 2nd, 3rd, 6th; off screen every 6th/12th) for `lod` rigs. AI captains (rivals, the arena,
  the ghost captain, the brig's gunners) were full-rate rigs: Player._setup_ai now sets `body_model.lod = true` (as
  puppets and grunts have). t/combat/rival_rig_lod. Brains: the hook for the lead's files (pirate_grunt.gd,
  captain_brain.gd), not built here: think at ~10 Hz staggered by instance,
  `if (Engine.get_physics_frames() + get_instance_id()) % 6 != 0: return` round the decision part (not movement),
  timed into the spike log with `var t0 := Time.get_ticks_usec()` ... `Perf.add_us(Perf.AI, Time.get_ticks_usec() - t0)`
  (wallclock_allow line for that function). A waiting rival (order "rest"/"watch"/"hold", settled) could drop its
  Player physics (`set_physics_process(false)` on the Player and its state machine, the rig left posing) and have
  the brain look at the order at 4 Hz until it's called in.
- **Piece 4 (native hot paths): profile, no build.** tools/dev/rigprobe.gd (headless, light stage, us a call):
  the captain's own rig 243-254 us a pose, of which spring chains (hair, coat: SpringChains._simulate_tuned /
  _step with capsule push-outs) 106 us (~60%: 16-57 us a set), foot IK 13-18 us (two physics rays), _locomotion
  16 us, _update_look 4-6 us; Ocean.get_wave_height 3.3 us a call. The lead's 1.23 bench: humanoid.gd 2.3 ms of the
  5.8 ms scripts a frame (the captain's own rig 1.5 ms: actions' swing IK on top), arm_body/lower_body 0.31.
  Candidates in order: SpringChains (step + push_out + write_pose), Humanoid's swing IK (_best_swivel, reach_hand,
  _wrist_for), the per-frame pose blend (_cur lerp, _sample_u/_action_pose keys), get_wave_height (the WAVES sum),
  foot IK (rays stay in the engine). Toolchain: MSVC 14.51 Build Tools and the Windows SDK are installed; no scons,
  no godot-cpp (nothing installed: piece stopped at the profile).
- **Piece 5 (budgets).** tools/dev/perf_budgets.txt (anim 2.0, ai 0.8, world 1.2, ui 0.4, player 0.5, other 0.6,
  draw 3.5 ms; scripts mapped to systems by regex), perf_budgets.ps1 <bench result>, and perf_gate.ps1 prints them
  per light (a warning, never a fail). The 1.23 "before" bench: anim 2.26, ai 1.10, world 1.69, draw 4.95 over.

## 2026-10-26: 1.23 combat core, pieces 1-3: poise, juggling, black-leg's juggle set
- **Why:** Zach's playtest: every captain had 2-3 knockdowns at will and they were all that mattered. Spec:
  docs/v1_23_previews.md sections 3-4 and docs/v1_23_plan.md "Preview answers" (approved starting numbers).
- **Poise** (`scripts/combat/poise.gd`, class Poise; hidden, the stagger shows it). `Poise.make(class)`: grunt 30/12 a
  second (flinches at damage 10+ or poise 14+), elite / a rival's crewman 55/15 (only heavies flinch it), captain
  (camp boss, outpost sergeant) 90/18 (never on lights), rival captain / hunter 80/20 (always flinches: the captain
  AI dodges too), miniboss 160/25 (PirateBoss: Morrow, the bandit chief, the huntsman). Refill starts 2 s after the
  last hit; empty = BREAK, then full and immune 4 s. Worked out on the hit from physics ticks (nothing per frame).
  `take(hit)` -> NONE (shrugged off: no flinch, it keeps coming), FLINCH, BREAK. `Poise.of(hit)`: `HitData.poise`
  (new; Player.melee_hit sets light 6, finisher 14, heavy 25, a technique's hit base x1.2 clamped 6-60, `_hd` with a
  knockdown 35-60, an ultimate's knockdown 120, a pistol shot 4 / 12 inside 3 m), and anything with the old
  `knockdown` flag drains at least Poise.KICK 30 (the kick moves, Arrow Kick, Handstand Spin, Cyclone Heel's ring,
  heavies that floored). A break by a finisher's weight or more knocks down (a crumpling blow crumples, a launcher
  launches), lighter ones reel hard (1.3 s). Every knockdown (`_knock_down`, `_crumple`) sets the 4 s immunity, and a
  grunt down or getting up takes the damage only (no re-knockdown loop). Grunt guard: a blow of 30+ poise goes
  through it (was: any knockdown flag). PirateBoss lost its own "no knockdown unless staggered" and wind-up armour
  rules (the miniboss class covers both); a break mid-special ends the special. AI captains: `Player.poise` (made in
  `_setup_ai`, "rival"; RivalEncounter makes the crewmen "elite"); humans have none. Drowned shots drain x SHOT_K.
  Beasts keep their own (JungleBeast._poise) until the beast pass, which can use `Poise.make("miniboss")` /
  `take(hit)` or a new class line. Other enemies (scuttlebugs, fauna, the sea king) still go by the knockdown flag.
- **Juggling** (`scripts/combat/juggle.gd`, class Juggle; `HitData.launch`, m/s up, < 0 a spike). A grunt or elite
  goes up on any launcher (`PirateGrunt.juggle`, state S.AIR, group "juggled", pose "jug_air", JugglePoses); a camp
  captain / miniboss only when the launcher breaks its poise; beasts never. Up there: gravity 15, each hit lifts
  `LIFT 4.5 x 0.75^hits` (x the hit's own launch / LIFT), none after AIR_MAX 3 s (then it falls 1.8x harder); a spike
  drives it down. Landing = a knockdown (immune 4 s). Launchers: the fists' uppercut (LightAttackState LAUNCH_UP 9),
  Updraft (grunts juggled instead of ragdoll-thrown; its apex cleave spikes), Rising Heel, Sky Chase. The air step
  toward a juggled foe chases it (JumpState._chase: 0.3 s to arm's length, the stick ignored meanwhile: player meta
  "chase_until", FallState too). An air attack within 3.4 m of one is an air combo (PlungeState "air_combo": the
  style's light blows, one a press, hanging beside it, up to 4 a jump, the 4th spikes). Co-op: the host runs the
  grunt; puppets join/leave the juggled group from the snapshot's state so a guest's air step chases too; `poise`
  and `launch` ride `Net.hit_pack`.
- **Black leg:** Rising Heel (`rising_heel`, node bl_rise, Mule Kick's slot; pose bl_rise: sunk over the left knee,
  the heel swung up the front to vertical at RISE_AT 0.24, 20 dmg, launch 10, breaker), Sky Chase (`sky_chase`, node
  bl_sky, Cartwheel Crescent's slot; up to a juggled foe within 10 m (refunded if none): a scissor kick up, launch 9,
  or with the stick held forward the spike: heel down, launch -18, you dive after it and land in a 2.6 m ring that
  floors the rest). Flambe Dash 9 m -> 4.5 m and it stops on landing (the 36 m/s it landed with bled off at 30 m/s²
  carried it ~10 m further: that was most of "far too far"). Mule Kick, Cartwheel Crescent, their poses, plants and
  icons are gone; SkillTrees.RENAMED / Skills.RENAMED give old saves the new nodes and bar slots (Heavy Heel's steps
  hang on Sky Chase). New icons (gen_psx_textures.py techniques).
- **Per frame / tick added:** none while nothing is juggled; a juggled grunt runs `_air_update` (gravity, a
  move_and_slide) instead of its brain for ~2-3 s. Poise is lazy (on hits only).
- Tests: t/combat/poise_knockdown, juggle_hold, juggle_chase, black_leg_launch; t/progression/black_leg_rename;
  t/weapons black_leg_tree / black_leg_cleaver_flambe / black_leg_learn updated, black_leg_wheel_hands removed.
  Renders: tools/dev/out/bl23_00_*.png (bl_rise, bl_sky, bl_sky_spike), tools/dev/out/jug_00_*.png.
  Expect at prepush: grunttest, r10test, ragtest, balancetest, techtest, airtest, progtest, nettest.
## 2026-10-26: 1.23 island arcs, pieces 1-2: the arc frame, two templates, replies

Spec: docs/v1_23_previews.md section 5 (the 10 templates), docs/v1_23_plan.md rows "Islands" and "Replies".
- **IslandArcs** (scripts/island/island_arcs.gd, node "Arc" under the GenIsland): `TEMPLATES` (data: villain, place,
  the elder's telling, rumours, poster, contacts, beat-2 steps, showdown, `meet` and `moment` replies with their
  outcomes, the hidden finish, thanks), `pick(facts)` (the fog isle the Cursed Festival once it's in; else the chain's
  own shuffled order from `(id * 3) % n`, skipping templates whose `needs` the island lacks: outpost, cave, fog),
  `plan` (IslandLife.plan, worker: the likely roll with `MarineOutpost.rolls`, its contacts' bodies stocked), `make`
  (the life step, after the outpost: rolled again on what's built, contacts, the Journal quest, the elder's and the
  board's hooks). `force` for tests and tools.
- **State** = the crew's Journal entry (the step) + world flags `<isle key>_arc_*` (moment/meet picks, raid, settled,
  fell, hidden): saved, sent to joiners. Every machine builds what the state asks for each 0.5 s tick (squads
  "S<n>" as warm-start GruntCamps, a night wave "W<n>" as a ScuttlebugNest, the strongbox "Item<n>", the raid, the
  "More" men); the host decides the rest (Net.arc_ask -> `decide`, Net._all_arc -> `apply`). Squads are cleared once
  all have mustered and all are down (a squad killed between ticks once never counted).
- **Steps** (beat 2): squad, pickup, talk (a contact's moment), wave (only at night: Weather.hour() 20-5; the goal says
  "it comes at nightfall"). The showdown is the villain: the camp's captain (`camp`) or the island's beast (`beast`);
  a villain already dead when the showdown begins counts at once (no reply, no hidden finish). Its fall (host): flag
  "fell", `_all_arc fell` (banner, the arc chest `arc_chest`: gold, treasure, a trait weapon a tier up; the hidden
  cache `arc_cache`), `Net.bounty("arc")` (Bounty "arc" 8000, a poster deed), `Admiralty.deed(.., "arc")`, and a
  TODO for the Will points (2) until the progression agent's API lands. The elder's thanks (Journal turn-in) pay gold.
- **Replies** (scripts/dialogue/replies.gd, reusable: the rivals can use it): `nodes` (a reply moment inside any
  conversation), `open` (a conversation of its own; walking away emits -1), `shown` (every screen: the pick and the
  answer as toasts, a bark over the speaker). The villain's meeting: the host asks the nearest standing captain within
  `MEET_R` 30 m on the showdown (re-asks after 45 s or if they were busy); the moment: a contact's talk while its step
  is on. Outcomes: fight, settle (Journal.settle: done without reward), pay:N (the picker's gold), hated (the island's
  traders' prices x1.2 via a negative Journal discount), raid (a night raid at the village's edge before he can be
  faced), more (two more men at the showdown), wounded:K (the villain starts K down once in combat), step, now
  (Journal.jump to the showdown). Journal gained `jump`, `settle` and a source's `goal_of` (the showdown told as it
  stands).
- Hooks: IslandVillage.elder_hooks / board_hooks (the elder's "Something's wrong..." telling, the turn-in; the board's
  WANTED poster), IslandLife deals one arc rumour to each named person's island news and one to every third face in
  the crowd. Fights at the village's edge stay `EDGE` 38 m past the plaza (out of an outpost's town: no alarm).
- Per tick: one 0.5 s timer per standing chain island with a taken arc (a few dictionary reads; the host's nearest
  captain check in the showdown). Squads come warm-started (bodies on a worker).
- **Hidden finishes** (host, watched from the showdown's first tick: `_watch`, judged at the fall by `_hidden_met`):
  spare_men (every man of the camp alive that was alive when the showdown began: they surrender), parts (the beast's
  `parts_broken()` >= 2 once the beast pass adds it; until then felled within `QUICK_KILL` 120 s of waking). Met: flag
  "hidden", the banner names it, and the cache `arc_cache` (gold, pearls, a trait weapon two tiers up).
- The roll is keyed by the chain's seed, which chain nodes now carry (`node["chain"]`): GameManager can't be read
  from IslandLife.plan's worker (smoketest caught it: the tests build islands on the main thread).
- Tests: t/quests/arc_roll, arc_beats, arc_reply, arc_hidden. Expected to touch: lifetest, villagetest, isletest,
  nettest (net), chaintest (the chain nodes' new key).
