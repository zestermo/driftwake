# tools/dev

Headless tests, co-op tests and screenshot/render tools for Driftwake. All are
`extends SceneTree` scripts run with `--script res://tools/dev/<name>.gd`. See CLAUDE.md at the repo
root for how to run them on Windows. Output goes to `tools/dev/out/` (gitignored, has a `.gdignore`
so Godot does not import the PNGs).

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
- `shiptest`: Ship: gentle swell, helm (visible captain), sailing, turning, riding the deck, shore collision.
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
- `bigtest`: (no description)
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
- `heavyshots`: Strip of frames of an action with a weapon. Args: <out.png> <anim> <weapon> <dur> <yaw_deg>
- `helmshot`: Captain at the helm. Args: <out_prefix>
- `hudshot`: (no description)
- `iconsheet`: (no description)
- `ikshot`: Foot IK shots: standing across a step and on a slope, IK off vs on. Args: <out_prefix>
- `iktest`: (no description)
- `invshot`: Inventory overlay screenshots. Args: <out_prefix>
- `invshot_real`: Inventory overlay screenshots. Args: <out_prefix>
- `islandshot`: Shots of the starter island from given local (island-space) camera positions. Args: <out_prefix> then repeated "name:cx,cy,cz:tx,ty,tz"
- `jumpshot`: Running jump, side view: lean frames. Args: <out_prefix>
- `kneelshot`: The kneel pose and a crew marker on the HUD. Args: <out_prefix>
- `lineup`: Renders a lineup of character looks. Args: <out.png> <mode: full|heads|back> [seed]
- `mapshot`: (no description)
- `mockup`: Style mockup: same cast in a given style. Args: <style> <mode: full|heads|back> <out.png>
- `moveshot`: Player: neck portrait, dash off-hand, plunge attack frames. Args: <out_prefix>
- `npcs`: (no description)
- `perf`: (no description)
- `physdemo`: Physics demo: three characters run, stop, idle, jump. Saves frames for a GIF. Args: <style> <outdir>
- `posebench`: Pose bench: a standalone Humanoid on a flat floor, actions frozen at given progress values, shot from several angles. Args: <out_prefix> <stance> <weapon|none> <action:u,action:u,...> [views: side,front,three,top]
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
- `wolfpose`: Standalone Zoan hybrid: front, 3/4 and side views. Args: <out_prefix>
- `zigzag`: (no description)
