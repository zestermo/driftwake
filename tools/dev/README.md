# tools/dev

Headless tests, co-op tests and screenshot/render tools for Driftwake. All are
`extends SceneTree` scripts run with `--script res://tools/dev/<name>.gd`. See CLAUDE.md at the repo
root for how to run them on Windows. Output goes to `tools/dev/out/` (gitignored, has a `.gdignore`
so Godot does not import the PNGs).

## Checks

- `compilecheck`: Compiles every project script (or just the ones named) with the autoloads loaded (Godot's own `--check-only` doesn't know Net, FX...) and prints `COMPILE OK (n scripts)` or `COMPILE FAILED <path>` under Godot's errors. Exit code = failures. `run_tests.ps1` runs it first (~6 s) and runs no suites if anything is broken (`-NoCompileCheck` skips it). Args: [paths...]
- `affected.ps1` + `test_map.txt`: which suites cover what changed (uncommitted files, or `-Base main` for a whole branch); `-Explain` shows which file pulled in which suites and lists changed scripts no map line covers. `run_tests.ps1 -Changed [-Base ref]` runs just those, and says when co-op code changed (run nettest.ps1). Add a map line with a new suite or system.
- `land.ps1`: Lands a finished parallel session's worktree branch on main: rebase onto main, compile + the covering tests (`-NoTests`: compile only), fast-forward main; a conflict backs out and changes nothing. `-List` shows every worktree and how far ahead it is. See CLAUDE.md "Parallel sessions". Args: <branch> [-Onto main] [-NoTests] [-List]
- `hooks/gdcheck.ps1`: Claude Code hook (`.claude/settings.json`, PostToolUse on Edit/Write): after Claude edits a .gd file it compiles that file (~2 s) and hands any errors straight back to Claude.

## Test suites (run_tests.ps1)

Each prints `PASS ...` / `FAIL ...` lines and a final `RESULT OK` / `RESULT fails=0` / `RESULT FAILED (n)`.

- `feat`: Starting kit, quick slots, sheathe/draw, items.
- `feel`: Sword combo chain, move-cancel, combo memory, slash trails.
- `dash`: Dodge sidestep/backstep direction, distance, facing.
- `chartest`: Character builder: every option + random looks build, apply_look keeps weapons, legacy looks convert.
- `styletest`: Shonen body: permanent style, neck joint, head look layer.
- `stamtest`: Stamina gating, weapon-specific heavy attacks, sprint speed, camera look-at.
- `invtest`: Gear / paper doll / character sheet / abilities.
- `ragtest`: Player ragdoll: knockdown -> get up, death -> stays down -> respawn.
- `bugtest`: Scuttlebugs: spawned in the jungle, notice -> rear -> ram, hitstun, knockdown, death + gold.
- `storytest`: The story: off outside a new game; begin() locks the ship and the skill map; waking on the beach (lying, the gull lands, caws and flies off, standing, the objective on the HUD and its marker); each talk step starts at the NPC's story line and moves on (Tackett busy before his turn); the smugglers, Grell, the queen and Morrow count when beaten near you; Vey's free point opens the skill map, Tackett's keel gives you the ship; the end; restored mid-story.
- `foresttest`: Brinehollow's west: the bigger island, the pirate den (crew, Captain Grell's overhead name and bar, strongbox, sloop), canopy spitters (drop, spit poison, fall, climb back), the brood cave (the queen wakes, boss bar, stagger, brood, slam, venom fan, reset, death, hoard) and the Queen's Fang.
- `shiptest`: Ship: gentle swell, helm (visible captain), sails set in steps that stay set (furled canvas rolls down), turning, riding the deck, keeps sailing with nobody at the wheel, shore collision.
- `swimtest`: Swimming: fall in, float, swim, stamina, dive, exhaustion, ladder, ledge, wade out.
- `grunttest`: Pirate grunts: camp, alert, attack turns, guard/guard break, hitstun, parry stagger, knockdown, death, return home.
- `guntest`: Grunt firearms: rifle shots on a line (hit when standing on it, miss when dodging/sidestepping), reposition, shove, pistol swap, heavy-attack glow, wider parry window.
- `fixtest`: Plunge attack, rifleman ragdoll fix, shove knockdown, two-handed rifle.
- `watertest`: Water for grunts and ragdolls: grunts avoid the sea, swim back to shore when they end up in it, ragdolls plunge under then float, knocked-down swimmers (grunt and player) bob up and swim on, dead bodies float.
- `powertest`: Devil Fruit (Ember) + skill bar + bindings + braced ragdolls + foot IK + parry sound.
- `progtest`: Progression + skill map + fighting styles + fruit types + save/load.
- `savetest`: Title screen + save slots: new game, save, quit to title, continue, a second slot, loading from the pause menu, deleting.
- `vinetest`: Vine Fruit round 2: energy drain, grapple points on trees, swing body alignment + loose limbs + release tilt that rights itself, arm vines, grapple pull (light enemy) and zip (heavy enemy), fists in the fist stance, punch wind FX.
- `r6test`: Round 6: skill keys after closing the map, map tabs + framing, menus fit the screen, quick items, power auras, vine dash trail, Haki look, block, red unblockable grunt heavy, fall damage.
- `r7test`: Round 7: inventory drag and drop (move, merge, equip, quick slots, drop on the ground), chests open a loot window (take one, take all, store), pickup feed, interaction prompt clears after pickup, wolf stance poses, PSX default preset.
- `r8test`: Round 8: markers, kneeling, cannons (man, fire, reload, leave), helm broadside, cannonballs vs an enemy ship's hull, enemy ship hunting and firing, boarders, sinking + floating plunder, Captain Morrow's phases, crew call, shockwave, death + hoard, reset, music, HUD bars.
- `r9test`: Round 9: texture warp off by default, fine sea mesh + physics-ticked wave clock, swimmers on the waves, hair-coloured scalp, weather cycle + force, storm seas, rain, lightning, sun/moon by the hour, 3D cloud density and whiteout, world time saved and restored.
- `capturetest`: F12 dev capture writes the state dump (+ screenshot with a display) and last.txt/last.png.
- `seatest`: Sea round: cannonballs cut by katana/cutlass (halves fly on split 45 degrees), shot out of the air; pirates only hunt ships with a captain aboard and keep off land; boarding a pirate ship (deck fight, prize, scuttled); the fleet's kinds, ramming, double broadside, fleeing, striking colours; hull damage, hazards, wrecks/treasure, the chart, the Sea King.
- `axetest`: The axe moveset: its style, the hack/hook/splitter combo (splitter knocks down), the whirlwind heavy (hits behind you, second turn knocks down), Skybreaker (somersault, dive, ground split ahead).
- `qoltest`: Brinehollow QoL: traders (buy, sell treasure, gear to order), gold counter, the yard's live preview, the capstan (kneel, let go, chain, weigh), auto-anchor in port, compass, chart marks (set, remove, clear, reached), Gus's Sea King rumour, hull damage numbers.
- `isletest`: Generated chain islands: built where the log pose points (land, sea round, a deep berth, a pier, sites on land and apart, paths), a captain stands on the ground, colliders and grapple crowns, shallows, charted and kept clear by enemy ships, deterministic, moving on frees the fork not taken and builds the next.
- `chaintest`: The island chain map (layers, cities, sea boss, forks, levels, seeded), no placeholder islands, treasures on Brinehollow; the log pose (given, worn, unset under Lv 10, hold L raises it + HUD icon, the needle points), saved and loaded; the rumour.
- `airtest`: The learned air attacks: without the move a style plunges; Twin Cyclone (dual swords: cuts on the way down, a landing burst knocks flat), Meteor Kick (unarmed: knocks flat, bounces you up, a second kick off the bounce), Hang Shot (one pistol: hangs, one heavy shot knocks flat, uses a ball), Boarding Dive (cutlass: the point lands, a backflip off them).
- `balancetest`: Right-click spam limits: heavies in a row cost x1.5 each (a light attack resets it), the same heavy repeated grows predictable and a grunt reads it (blocks, no damage), the gun kata shoots at most 3 then reloads, a full iai draw costs 20 extra, a hit breaks the iai charge, a bullet flinches a grunt at most once a second, the XP curve; the mastery passives (tier 1 at level 8, tier 2 at 16 after tier 1).
- `yardtest`: The shipwright: Tackett's talk opens his yard; refits cost gold and change the ship (hull, guns, sail, rudder); paint, sails, flag, figurehead; saved and loaded. Plus the sea polish: shallows baked, wake under way, rain soaking and pooling on deck.
- `hairtest`: Every hair style builds for both bodies; under every hat no hair vertex reaches past the scalp (+8 mm, real head profile) or above the crown.
- `katanatest`: Katana: own style, scabbard on the hip (blade in it when sheathed), no off-hand blade, left hand on the hilt; the three-cut combo lands; holding heavy readies the drawing strike (blade back in the scabbard), creeping while charging, charge level 2, an uncharged vs a full-charge draw (dash through the grunt, much more damage, the grunt crumples in place and gets up soon), letting go stands down; the parry holds the blade point-down overhead in both hands; sprinting sheathes it (hands on it) and attacking at a sprint is the running draw, which breaks a grunt's red wind-up into a stagger; the air attack gives a lift, cuts the grunt below and is once per jump; parrying leaves the blade's size alone; hits leave blood splats, a killing full-charge cut severs a head or arm (stump), a severed arm comes off as one baked piece.
- `r10test`: Round 10: the sky melts into a long-range fog at the horizon (no seam), an irregular sea (several crossing wave trains, peaked crests, wave groups), blended + sorted 3D clouds (no screen-door dither), cloud shadows on the sea/ground (no more multiply plane over the sky), and the rig is the same after a string of knockdowns as before them.

## Co-op (nettest.ps1)

- `nethost`: Co-op test, host side: hosts a world and runs the client's commands (see nettest_node.gd). Args: <port>
- `netclient`: Co-op test, client side: joins the host (nethost.gd, same port) and checks the session: puppets both ways, enemies in sync, hits each way (client hits an enemy, an enemy hits the client), gunshots, kills (coins + XP), knocked out + revive, actions mirrored, fruit claims, the helm, spawner waves, burning brush, leaving. Args: <port>
- `netwatch`: Co-op test, a second client: joins alongside netclient.gd and checks it sees the host AND the other client (snapshots relayed by the host). Args: <port> <start_delay>
- `nettest_node`: Co-op test helper: the same node (/root/NetTest) on the host and the client. The client sends commands, the host runs them and replies.

## Render / debug tools

Run without `--headless` (they need the GPU). Most take an output prefix as the first
user arg, e.g. `& $env:GODOT --path . --script res://tools/dev/weathershot.gd -- res://tools/dev/out/wx`.
Many are one-off probes from earlier rounds; the ones used most recently are weathershot, waveshot,
wavegrid, cloudshot, strafeview, hairdist, gaitview, gaitpose, coopshot, invshot_real.

- `airshot`: (no description)
- `animsheet`: Contact sheets of every action in ActionSpecs (scripts/npc/action_specs.gd) at its length, 8 frames each (u 0 -> 0.98), three rows to a sheet, a red bar under frames inside the hitbox window; holds via Humanoid.hold, reactions via react (one row per push variant); in place (no root motion). Lab mode (`lab:<action>` as the 2nd arg): live + each AnimLab variant as tagged rows, 12 frames, a sheet per view (front3/side/back3/top) and each row's range of motion per axis printed, plus a BLADE line of swing checks; env AS_TRACE=<live|a|b|c> prints that row frame by frame (sword hand and blade tip height and speed, elbow bend: wobbles and pops), AS_DEBUG=<live|a|b|c> the swing/reach solver per frame, AS_MOVE="x,y" starts it mid-walk; see docs/anim_lab.md. Args: <out_prefix> [only: action names or stances, comma separated] [yaw_deg = 125; 90 = side]
- `bigtest`: (no description)
- `abilityshot`: A skill filmed on a clean stage against three staggered grunts, effects and all: one row per view, frames along game time. Args: <out_prefix> <skill_id | heavy | riposte_counter> [style] [views: game,side,front3,top] [frames] [span s] [start s]. Env AB_HOUR=21 at night.
- `bugshot`: Scuttlebug shots. Args: <out_prefix> <mode: pose|fight|down|die>
- `cannonshot`: Cannons on the sloop: overview, manning pose, gun camera with the arc, a shot in flight. Args: <out_prefix>
- `cloudshot`: Close look at the 3D clouds at a pixelated PSX preset. Args: <out_png> [preset]
- `coopshot`: Co-op renders: a crewmate's puppet (nameplate, crew list), knocked out with the revive prompt. Args: <out_prefix>
- `count`: (no description)
- `covemap`: (no description)
- `creator_shot`: (no description)
- `creatorshot`: (no description)
- `dashpose`: Standalone dash poses (armed): forward, left, right, back.
- `dashpose_dbg`: Standalone dash poses (armed): forward, left, right, back.
- `dlg`: (no description)
- `dockpos`: (no description)
- `faces`: (no description)
- `fs`: (no description)
- `fxdbg`: (no description)
- `fxiso`: (no description)
- `fxshot`: (no description)
- `gaitnum`: Foot paths in body space for several move directions (armed): swing axis vs travel, crossing.
- `gaitpose`: Armed gait frames for a given local_move. Args: <out_prefix> <mx> <my> [armed 1/0]
- `gaitview`: Treadmill gait viewer: three bodies at walk (1.3), jog (6) and sprint (12) seen from the side (or 3/4). Saves frames. Args: <outdir> <view: side|three>
- `gruntshot`: Smugglers' camp shots. Args: <out_prefix>
- `gunshot_r`: Firearm / heavy glow shots. Args: <out_prefix>
- `hairdist`: Hair at a distance (scalp poking through?). Args: <out_prefix>
- `hairshots`: Close head shots of every hair style. Args: <out.png> <yaw_deg>
- `heavyshots`: Strip of frames of an action with a weapon. Args: <out.png> <anim> <weapon> <dur> <yaw_deg>. Superseded by animsheet: its frames show the pose a sample late and the skinned legs stale (boots come loose from the shins in lunges).
- `heightshot`: The character creator at every Height option (what the player sees). Args: <out_prefix>
- `helmshot`: Captain at the helm. Args: <out_prefix>
- `hudshot`: (no description)
- `iconsheet`: (no description)
- `ikshot`: Foot IK shots: standing across a step and on a slope, IK off vs on. Args: <out_prefix>
- `iktest`: (no description)
- `invshot`: Inventory overlay screenshots. Args: <out_prefix>
- `invshot_real`: Inventory overlay screenshots. Args: <out_prefix>
- `seafxshot`: Sea and wind effects: Brinehollow's beach in calm and in a storm (surf rolling in, swash, surf bursts), and at sea in a storm under full sail from astern and from the deck (whitecaps, wind streaks, crest and bow spray); three frames a shot. Args: <out_prefix> [psx]
- `islandshot`: Shots of the starter island from given local (island-space) camera positions. Args: <out_prefix> then repeated "name:cx,cy,cz:tx,ty,tz" (a y of "~3" is 3 m above the ground there). Env ISHOT_HOUR=21 renders at that hour; ISHOT_AT=<node name> (e.g. RedtideRock) frames another place, positions in its space.
- `jumpshot`: Running jump, side view: lean frames. Args: <out_prefix>
- `kneelshot`: The kneel pose and a crew marker on the HUD. Args: <out_prefix>
- `lineup`: Renders a lineup of character looks. Args: <out.png> <mode: full|heads|back> [seed]
- `mapshot`: (no description)
- `mockup`: Style mockup: same cast in a given style. Args: <style> <mode: full|heads|back> <out.png>
- `modelshot`: Any procedural model (a GDScript expression returning a Node3D, Mesh or MeshBuilder; several split by " | " stand in a row) auto-framed from a few views in the game's light, a contact sheet (`<out>_sheet.png`) and "MS" lines: size, tris, surfaces (draw calls), triangles per material, colliders, lights. Views front/front3/side/back/back3/top/low/far/eye/wire or "yaw:pitch:zoom". Env MS_GROUND (texture or none), MS_HOUR, MS_PSX (preset), MS_ZOOM, MS_FOCUS (a point in the model's coordinates), MS_ROW (y/z). `S.` is model_samples.gd, `S.body()` the captain for scale. Args: <out_prefix> "<expr>[ | <expr>]" [views]
- `storyshot`: The story's start through the real loading screen: the loading card, waking on the beach (eyelids, the gull, the get-up), the first objective and marker, Old Pell's line, the next objective. Args: <out_prefix>
- `model_samples`: Not a tool: worked examples for the modeling skill (anchor, ship's lantern, naval cannon) built with add_extrude, add_tube, lathed lofts; `body()` for scale in modelshot rows.
- `moveshot`: Player: neck portrait, dash off-hand, plunge attack frames. Args: <out_prefix>
- `npcs`: (no description)
- `perf`: (no description)
- `physdemo`: Physics demo: three characters run, stop, idle, jump. Saves frames for a GIF. Args: <style> <outdir>
- `posebench`: Pose bench: a standalone Humanoid on a flat floor, actions frozen at given progress values, shot from several angles. Args: <out_prefix> <stance> <weapon|none> <action:u,action:u,...> [views: side,front,back,three,top,hipsb,hipss,hips3,hipsf,hipsu]. Env: PB_BASE=1 plain look, PB_REST=1 weapon away, PB_FEM=1 female, PB_SPEED=6 mid-stride, PB_KV="legs=shorts;build=stout" look overrides. Use "guard" as the action for no action. The first view of each pose waits 20 frames (the joints ease toward it); later views 5. Stance/weapon "katana" for the katana.
- `lbprobe`: Lower body mesh probe: lists triangles drawn inside-out or degenerate. Args: [fem 1/0]
- `poses`: Renders a lineup of player poses for animation tuning.
- `poses_angle`: Renders a lineup of player poses for animation tuning.
- `powershot`: Ember Fruit + skill bar shots. Args: <out_prefix>
- `probe`: (no description)
- `probe2`: (no description)
- `probe3`: (no description)
- `psxshot`: PSX renderer comparison: a far view of the village from the beach. Args: <out_prefix>
- `r6shot`: Round 6 renders. Args: <out_prefix>
- `r7shot`: Round 7 renders: loot window, pickup feed, wolf stance + claw rake. Args: <out_prefix>
- `r8shot`: Round 8 renders: Redtide Rock, an enemy ship, Captain Morrow, the boss bar. Args: <out_prefix>
- `r8show`: Round 8 showcase: a broadside, boarders, a sinking pirate ship, Morrow's slam and Red Tide whirl, a crew marker, the kneel. Args: <out_prefix>
- `ragshot`: Frames of the player's knockdown ragdoll + get-up (or a death with "dead"). Args: <out_prefix> [dead|front]
- `ragsign`: (no description)
- `resp`: (no description)
- `ret`: (no description)
- `shippos`: (no description)
- `shipprobe`: (no description)
- `shot`: (no description)
- `skidshot`: Out-of-combat start / stop / skid filmstrip, side view. Args: <out_prefix> <skid|stop|start>
- `strafeview`: Combat-stance strafing: bodies facing -Z, moving in different directions at combat speed (6 x 0.8). Prints how much the planted foot slides, and saves a filmstrip of one of them. Args: <out_prefix> [dir index for frames, -1 = none]
- `styleshot`: Fighting styles, fruit forms and the skill map. Args: <out_prefix>
- `styleshot2`: Fighting styles, fruit forms and the skill map. Args: <out_prefix>
- `swimshot`: Swimming shots. Args: <out_prefix>
- `thornshot`: Thornbrush around the jungle stash: before / burning / after. Args: <out_prefix>
- `titleshot`: (no description)
- `topview`: High-angle and close views of a few looks to find holes. Args: <out.png> <cam: top|front|side>
- `tour`: Takes a series of screenshots around Brinehollow (island-local coords + center offset).
- `ui_shots`: (no description)
- `uishots`: Screenshots of every menu at the current window size. Args: <out_prefix> [psx_preset_index]
- `village`: (no description)
- `vineshot`: Renders: vine swing from a tree (+ release), grapple pull on a grunt, punches with wind, flying kick. Args: <out_prefix>
- `watershot`: Water shots: a grunt shoved off the beach into the sea (plunge, float, swim back), then the player knocked under while swimming. Args: <out_prefix>
- `wavegrid`: Debug: balls placed on the computed wave surface should sit on the rendered sea. Args: <out_prefix>
- `waveshot`: Swimmer vs waves, side view, several moments. Args: <out_prefix>
- `weathershot`: Sky + weather renders. Args: <out_prefix>
- `outfitgrid`: Combination sheets to find clipping: `hats` (each hat over every hair style, 4 heads a sheet), `hair` (every style, no hat), `clothes` (each coat over every top x vest), `extras` (belts, apron, scarf, pauldron, pouch over coats). Args: <out_prefix> <mode> [yaw_deg] [fem]
- `goreshot`: A camp grunt cut down by a severing killing blow (head or arm off, blood, splats) and a second losing an arm, frames at 0.15-2.5 s. Args: <out_prefix>
- `horizonshot`: The Redtide fort and ships on the horizon from the starter dock (rain at dawn like the capture, plus zoomed clear/rain/storm), to check distant things sit on the sea instead of floating on haze; also the sea from the dock (sun glare at 9-11 h). Args: <out_prefix>
- `fleetshot`: The enemy ship kinds side by side at sea (sloop, gunboat, brig, Marines). Args: <out_prefix>
- `newsshot`: The title screen's version ribbon and what's-new pop-up (as on the version's first launch), then the menu. Args: <out_prefix>
- `armorshot`: The new clothing and armour on a lineup of bodies, front and back; `close <a> <b>` frames two of them up close. Args: <out_prefix> [close a b]
- `capeshot`: Two outfits of the new pieces worn by the captain through the equipment slots in the world, front and back. Args: <out_prefix>
- `weaponshot`: Every weapon design laid out per kind, the four kinds across all seven tiers, and a sheet of every weapon icon. Args: <out_prefix>
- `handshot`: A few weapon designs held by the captain (nodachi, broadsword, war axe, dragon pistol, rapier). Args: <out_prefix>
- `sheathshot`: Weapons put away on the hip (cutlasses, katanas in their scabbards, axes, pistol): side, front, back and a close front-left quarter each. Args: <out_prefix>
- `tiershot`: A cutlass at every item tier (white to black) in the bag with an epic one described, and Vey's stall. Args: <out_prefix>
- `qolshot`: Nessa's and Sela's stalls, the yard's live preview, the helm with the compass and chart marks, the chart, the capstan and anchor chain, a hull hit's number. Args: <out_prefix>
- `polishshot`: Sea polish: the foam wake behind the ship (astern, from above), turquoise shallows round Brinehollow, rain pooling on deck. Args: <out_prefix>
- `genshot`: A generated chain island: from high above (fog off), from the sea off its dock, on the pier, at the village's, the boss's ground and the summit; prints its build times. Env GSHOT_SEED (the chain), GSHOT_ID (a node). Args: <out_prefix>
- `logposeshot`: The log pose held up (L): unset under level 5 (icon and compass strip), set in Brinehollow's sea (icon, strip, the chart with the first island pinned at its edge), then at a forking city on a found seed: unset (the wait), set at the helm (two needles, theme, danger) and the chart fitted round the fork. Args: <out_prefix>
- `yardshot`: The ship plain, then refitted in a few colour schemes (side, bow, masthead flag, each figurehead), Tackett at his timber, and the yard screen. Args: <out_prefix>
- `perfbench`: Frame/process/physics/render CPU/GPU ms, draws, prims, worst frame at five fixed views (1920x1080, vsync off, sharper preset). `probe` / `probe:<view>` instead times every script's _process/_physics_process. Args: [label|probe] [WxH]
- `hitchprobe`: Times one-off jobs that can stall a frame (autosave, camp and ship respawns cold vs prebuilt, a rig, weapon meshes, navmesh parses).
- `buildprobe`: Body build time by stage (headless).
- `riggingtest`: The bigger ship's decks: stairs to the quarterdeck, the helm up there, prompts only right next to things (wheel, cannon), the cabin door, storage chest, respawn by the bunk, climbing the rigging by hand (W up to the crow's nest, room round the mast, S down), jumping off, climbing armed with a chop, letting go, a rope swing, down a ladder from the deck into the sea and back up.
- `techtest`: Skill trees round 2: every node of every tree can be learned (the webs are connected), each weapon/unarmed technique and ultimate lands on a grunt with the right weapon in hand, grapples carry their target, a blade deflects a shot (and sends it back), Riposte answers a blow, Berserk and Smoke Bomb, a grab with nobody in reach is refunded, Quick Learner and Adrenaline, Conqueror's Haki fells a weakened grunt.
- `ambiencetest`: The ambience: surf at the end of Brinehollow's dock, quieter surf inland, and aboard under way out at sea the open swell, the hull's wash rising in volume and pitch, her timbers creaking, the wind on deck.
- `looptest`: The gameplay loop: storing in and taking from the ship's storage chest, resting in the bunk, restocking at the galley, dying (your bag on a grave, weapon in hand and worn gear kept, waking in the cabin), the storage and grave saved and loaded, dying again (the old grave sinks), recovering your things, summoning the ship (refused inland; from the dock it fades in, sails up and anchors).
- `bigshipshot`: The bigger ship: outside (side, stern, bow), the main deck, inside the cabin, the quarterdeck, the crow's nest, the rigging, an enemy alongside, the bow from the deck, the stairs, climbing a ladder, the rigging, and the rigging armed. Args: <out_prefix> [psx]
- `decktest`: Knocked down on a ship under way: the body keeps the ship's speed and stays aboard, the root never lags the body, thrown over the rail you come up in the sea where you landed.
- `perftest`: Performance round checks: swimmers drown, boarders left behind go, drops expire, one boss crew per fight, stuck-sprint release, rig LOD, 3D render scale, prebuilt bodies, shared weapon meshes, far FX skipped, perf log, orb slivers, chunked terrain.
- `readmeshot`: README screenshots at the sharper PSX preset (not saved), captain in a red long coat. Sets: `scenes` (street, tavern, a katana brawl at the camp) and `steel` (Haki iai draw, air slash, axe whirlwind + Skybreaker, Gun Rain, Flying Slash), in frame bursts. Args: <out_prefix> <set>
- `readme_media`: Copies the chosen renders from tools/dev/out into docs/media as JPGs for the README (headless; PICKS lists them and the commands that render them).
- The `psx` arg on fleetshot, kingshot, yardshot, seashot and polishshot renders at the sharper preset instead of native resolution.
- `seahourshot`: The sea from Brinehollow's dock at a run of hours in clear weather. Args: <out_prefix> [WxH window]
- `seasoak`: The sea from the dock through F6's weathers and back to clear, printing what the sea and haze are fed. Args: <out_prefix>
- `kingshot`: The Sea King fighting our ship at its lair: circling, rearing over the deck (bite ring), head down on deck, tail up. Args: <out_prefix>
- `guestshot`: A rendered co-op guest: start `nethost.gd -- <port>` headless, then `guestshot.gd -- <port> <out_prefix>` joins it and shoots fixed views (dock, open sea) as a guest sees them; prints the guest's hour, sun and ocean state.
- `wolfpose`: Standalone Zoan hybrid: front, 3/4 and side views. Args: <out_prefix>
- `zigzag`: (no description)
