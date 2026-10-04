# Driftwake

A third-person co-op action RPG built on freedom, discovery, and the thrill of becoming legendary. Navigate a living ocean world, master expressive combat, and carve your own path through danger and mystery.

Built with **Godot 4.6** | GDScript | Forward+ Renderer | Jolt Physics

---

## About

Driftwake is a systems-first pirate action RPG where gameplay emerges from the interaction between combat mechanics, environmental systems, and player decisions rather than scripted content. Players take on the role of independent pirate captains navigating a procedurally generated ocean world of islands. Through combat mastery, rare discoveries, and risk-based progression, players gradually build their legend.

The world doesn't push you forward -- you choose how far you go.

## Gameplay Pillars

| Pillar | Description |
|--------|-------------|
| **Expressive Combat** | Skill-based, fast, and deeply expressive. A flexible toolkit allowing unique playstyles through ability combinations and mechanical mastery. |
| **Player-Driven Identity** | No rigid classes. Identity emerges from your weapon archetype, ability loadout, and Devil Fruit powers. Your build is your fingerprint. |
| **Risk and Reward** | Progress made during an island run is temporary until secured. Every moment is a gamble -- push further for greater reward, or retreat and bank what you've found. |
| **Exploration & Mystery** | The world is not explained directly. Players learn through environmental clues and encounter patterns. Discovering something should feel earned. |

## Current Features

### Brinehollow (starter island)
- **Hand-designed starter island** replacing the first random island: 420 m terrain chunk with a village plateau, lighthouse hill with sea cliffs, jungle highlands and a sheltered cove
- **Fishing village**: plank dock, lantern-lit main road, a well and a signpost, with houses of different shapes and sizes (two-storey jettied townhouses, hip and lean-to roofs, porches, chimneys, a stilt shack on the beach); every building sits on a stone footing that reaches the ground
- **The Salted Gull tavern**: walk inside: fireplace, L-shaped bar with bottle shelves and kegs, tables and benches, hanging lanterns, Gus behind the bar and regulars sitting at the tables
- **Market**: a horseshoe of open-air stalls (fruit, fish, cloth, pots) with vendors you can talk to
- **Scuttlebugs**: knee-high horned beetles living in burrows along the jungle path to the ruins (three small ones and one big red one); they respawn slowly while you are away and drop a little gold that flies to you
- **Smugglers' camp** on the shore past the cove: tents, a campfire, contraband, a rowboat and a strongbox (treasure, gold and the Smuggler Captain's Tricorn), guarded by five pirate grunts (three swordsmen, two riflemen) who come back a while after you've cleared them out
- **Points of interest**: training yard with straw dummies, lighthouse with a rotating lamp, jungle ruins guarding a glowing **Driftstone**, castaway camp with a crackling campfire
- **Vegetation**: palms, jungle trees, bushes, ferns, grass and rocks scattered by biome (beach / meadow / jungle / hill) using MultiMesh, with trunk colliders
- **Hidden loot chests** around the island to test the find, carry, bank loop
- Procedural islands also get palms, trees, bushes and rocks

### Player Character
- **Character creator**: opens on first launch ("Create Your Captain") and any time from the pause menu (**Appearance**). Live rotating 3D preview (zooms to the face on the Face/Hair tabs), Randomize, and a name that villagers use in dialogue. Saved to `user://character.cfg` (delete it to see the first-launch creator again)
  - **Body**: masculine/feminine frame, build (slim / average / broad / stout), height, skin tone, head shape
  - **Face**: eyes, eye color, brows, nose, mouth, marks (freckles, scar, blush, war paint, age lines), facial hair (stubble, moustache, goatee, chops, beard, long beard)
  - **Hair**: 8 styles (crop, short, long, ponytail, bun, braids, wild, bald) + color; hats (tricorn, bicorne, bandana, cap, knit, straw, hood) + color
  - **Outfit**, each piece with its own color: shirt / tunic / blouse / bare, sleeve length, vest or corset, jacket / long coat / captain's coat (with trim color), trousers / breeches / shorts / skirt, tall boots / boots / shoes / barefoot, belt / sash
  - **Extras**: gloves, scarf, earring, eyepatch, pauldron, belt pouch, apron
- **Shonen-style low-poly bodies** (the game's art style: One Piece-inspired proportions, ~6 heads tall, PS1 shading): lofted limbs that run up into the hips and shoulders with no open seams, shaped chest/bust and hips, mitten hands, shaped boots, a short-crowned anime head with nose and ears and a procedurally painted face wrapped around it, and anime hair built from a natural hairline (temples, sideburns, around the ears, nape) plus pointed clumps: bangs, side locks, nape tufts and cowlicks. Clothes are separate layers; hair strands, ponytails, braids, coat tails, skirts, sashes and aprons are physics-simulated
- **Shoulders**: the arm joints sit just inside the torso under a sloped deltoid cap, so the top of each arm is buried in the shoulder instead of sitting on it like an action figure's ball joint. Bare-handed, the hands close into fists (the thumb tucked across the fingers)
- **Jointed skeleton** (knees, elbows, neck, hand + hip sockets) with a procedural pose animator: a speed-blended gait (a real walk at low speed, a relaxed, springy jog at normal speed with forward lean, hip sway, shoulder counter-twist and loose follow-through arms, and a long-striding, leaning sprint), the head moves on the neck with springy inertia (idle glances and tilts, a steady gaze that counters the shoulders' twist when running, leading into turns), bouncy idle, combat-stance hop, strafing, arms-up jump, double-jump flip, falling flail, landing squash, sidestep dash, parry block, stagger, three-hit slash combo, heavy leaping slam, drinking
- **Bouncy platformer feel** (Mario 64 / A Hat in Time style): squash & stretch on jumps, landings and footsteps; precise, instant control (movement follows the stick exactly, stops on a dime) with weight carried by the visuals: the body tilts to match slopes and leans in the camera's frame (forward with speed, further when starting, back when stopping, banking when you turn the camera), so weaving left/right doesn't throw it around; coyote time, jump buffering, variable jump height (tap = short hop, hold = full jump), faster falls, and sprint momentum carried through jumps
- **Effects**: sword slash trails, whooshes, hit sparks, footstep dust, landing dust rings, dodge dust trails and sparkles, all with generated sounds
- **Ready / sheathe (Z)**: the weapon moves between the left hip and the right hand with draw/sheathe animations. Drawn = combat stance: you strafe facing the camera, the camera moves over your shoulder, and a reticle appears (red when an enemy is in reach). Attacking while sheathed draws first
- **Weapons**: Cutlass (start) and Boarding Axe (x1.4 damage, found in the jungle ruins). Weapon damage multiplies all attacks
- **Skill bar** (bottom center, MMO style): a health orb on the left (with a pale chip that drains after each hit), an energy orb on the right (blue, or your Devil Fruit's color), stamina across the top, your level badge and experience bar, then four skill slots (1-4: icon, energy cost, cooldown sweep and seconds, dimmed when you can't afford them or don't have the right weapon out, a flash when they're ready, red when refused, fruit skills doused in the sea), the ultimate (R) with a charge ring that pulses when full, three quick-item slots (5-7) for consumables with how many you carry, and loaded shots over the bar when you're holding pistols
- **Quick items (5-7)**: consumables only (Brinehollow Black rum heals 35). They fill themselves as you pick consumables up, and a slot remembers its item when you run out; select a consumable in the bag and press 5-7 to move it. Weapons are equipped from the inventory (Z readies / sheathes)
- **Foot IK**: feet plant on stairs, slopes, rocks and the deck. Each foot probes the ground under it, the hips drop to reach the lower one and each leg re-bends (two-bone IK) so its foot lands on the real ground; on flat ground nothing changes. Off while airborne, swimming, climbing or seated
- **Inventory (Tab / I)**: an overlay on the game, not a separate menu. The world pauses and the camera swings round to face your captain, who stands on the left as the paper doll with gear slots on either side (head, torso, vest, coat, belt, hands, legs, feet, two accessories, weapon). The panel on the right has two tabs: **Inventory** (20-slot bag and item details with defense compared against what you're wearing; click gear or a weapon to equip it, click a worn slot to take it off, press 5-7 over a consumable for a quick slot) and **Character** (Strength / Agility / Endurance, health, stamina, damage, defense, speeds, abilities, your Devil Fruit's passives and skills, worn gear). Drag your captain to turn them. Banking and death only affect loot (gold/treasure); gear stays with you
- **Gear**: clothing and armor are items. Each piece changes how you look and adds defense (armor soaks damage with diminishing returns). The outfit you make in the character creator becomes your starting gear, and more is hidden in the island's chests. After creation, Appearance (pause menu) only edits body, face and hair
- **Menus fit any window**: everything is laid out on a 640x360 canvas (wider or taller windows just get more room), compact pixel fonts, and panels shrink themselves if they ever wouldn't fit. The PSX resolution presets (480x270, 320x180) now pixelate only the 3D view, so the menus stay crisp and on screen at every preset
- **Pause menu (Esc)** with Options (fullscreen, PSX resolution, dithering, vertex wobble, texture warp, FOV, FPS counter, master/effects/ambience/interface volume, mouse sensitivity, invert Y, camera shake, name tags, reticle) and a Controls page. Settings persist in `user://settings.cfg`

### NPCs & Dialogue
- **9 villagers** using the same body and clothing system as the player, each with their own outfit, and code-driven walk/idle/talk animation; two of them wander the village
- **Dialogue system** (`Dialogue` autoload): typewriter text with voice blips, branching choices, flags, and `{tokens}` that pull in live world data (e.g. Gus's rumors name real islands from the current seed)
- Conversations are plain JSON in `data/dialogue/` (format documented in `scripts/dialogue/dialogue_manager.gd`)

### PSX Presentation
- **Low internal resolution** (640x360 default, upscaled with nearest filtering). **F2** cycles 640x360 / 480x270 / 320x180 / native
- **Vertex snapping** (wobbly polygons) and **affine texture warping** via global shader uniforms
- **15-bit color with 4x4 ordered dithering** post pass (**F3** toggles)
- Nearest-filtered 64x64 pixel textures, hard shadows, distance fog, pixel fonts (Pixelify Sans / Silkscreen, OFL)
- Generated assets: `tools/texture_gen/gen_psx_textures.py` and `gen_psx_audio.py` regenerate every texture and sound (`pip install numpy pillow`)

### Combat System
- **Fighting styles** (by what's in your hands):
  - **Sword**: 3-hit combo (forehand, backhand, spinning finisher); heavy = lunging thrust (cutlass) or overhead chop (axe)
  - **Dual swords** (a second sword in the off hand): 4-hit combo (forehand, backhand, X-cross with both blades, twin spin), wider reach; heavy = both blades raised and crashed down together
  - **Unarmed** (no weapon, click the weapon slot in the inventory): a proper boxing guard (left side leading, fists closed, chin tucked), then a big stepping jab, a cross that whips the hips round, a looping lead hook and a pivoting roundhouse kick; heavy = a jumping flying kick. Every punch and kick shoots a short, straight rush of air (speed lines and a ring where it lands) so you can see what it reaches
  - **Pistol**: shoot where the reticle points (with a little aim assist toward the nearest enemy near your heading); each pistol holds 2 shots, then reloads by itself; heavy = pistol-whip
  - **Dual pistols**: alternate hands, faster; heavy = gun kata (spin and put a shot into everyone close)
  - **Claws** (Wolf Fruit hybrid form): rake, rake, double rake; heavy = pouncing maul
- Combos are remembered for ~0.9 s, so you can attack, reposition, and click again to continue the chain instead of restarting it. Bullets go through a swordsman's guard
- **Off hand**: picking up a second sword or pistol puts it in your off hand automatically; in the inventory, right-click a weapon for the off hand, click the off-hand slot to take it out
- **Sidestep dash** with i-frames: bursts in the input direction while you keep facing forward (sidestep, lunge-dash or backstep; no input = backstep)
- **Parry** with timing-based active window; **hold it to block**: frontal blows glance off your guard (sword level across, or forearms up when bare-handed) at a stamina cost, you can shuffle around while blocking, and dodge or attack straight out of it. Run out of stamina and the guard breaks. Hits from behind get through
- **Unblockable attacks**: grunts sometimes wind up a huge overhead chop while flashing red, with a warning sting. It can't be parried or blocked, only dodged, and ordinary hits bounce off the wind-up; a hit with Armament Haki breaks it and staggers them
- **Fall damage**: drops up to about 5 m are free (double and triple jumps never hurt); higher falls hurt (about 25 damage from 8 m, 50 from 12 m) and a long drop leaves you reeling
- **Hitstun**: light hits make the victim flinch briefly and shove it back (interrupts an enemy's attack; the player gets a short flinch)
- **Physics ragdolls**: heavy attacks throw the target into a ragdoll (rigid bodies with limited joints driving the rig); it gets back up from wherever it lands (face up: sits up; face down: pushes up). A living body braces as it flies: muscle springs on every joint pull the arms out and the knees up, with a little flailing, while it still tumbles freely. Deaths go fully limp and stay down. F10 knocks you over in debug builds
- **Parry feedback**: a successful parry rings out with a metallic ting, a white flash where the blades meet and a hot spray of sparks thrown back at the attacker
- **Parry** a scuttlebug's ram to flip it onto its back
- **Pirate grunts**: cutlass swordsmen in a varied crew (creator parts, red crew sash). They sit, stand guard or patrol until they spot you, then raise the alarm. In a fight they circle and strafe; only two attack at a time. Each attack has a held wind-up with a glint on the blade: a two-slash combo up close or a lunge from range, then a recovery window. They block light hits from the front (sparks, and sometimes a quick counter-slash), but the guard breaks on the third block. Hits from the side or behind, during their wind-up or recovery, and heavy attacks get through. Parrying a swing staggers them; heavy hits knock them down. They give up and go home if you run or swim away
- **Heavy attack tell**: a grunt's lunge is its heavy attack (16 damage): the blade glows yellow for about a second as it winds up
- **Firearms**: stay more than ~10 yards from a swordsman and he may pull a flintlock pistol (at most every 10 s, 10 damage). Two of the smugglers are riflemen: they keep 10-16 m away, shoot about every 8 s (15 damage), then run to a new firing spot, and knock you down with the rifle butt if you get close (5 s cooldown). They hold the rifle with both hands. Every shot shows a very faint grey aim line that darkens a little just before the shot, once it stops tracking. Firing throws sparks and a cloud of powder smoke, with a smoke trail along the shot, so you can read it from a distance. Only what's on the line gets hit, so sidestep, dodge through it, or parry it to deflect the bullet
- Parry window widened slightly (0.26 s)
- **Plunging jump attack**: attack in the air (weapon drawn, a little height under you): a beat with the sword raised, then a fast overhead plunge that hits on the way down and slams into the ground with a small shockwave (22 + 8 damage)
- **Free-aim** combat (no lock-on) for fluid multi-enemy engagement
- **Hit feedback**: hitstop, camera shake, floating damage numbers
- **Hitbox/Hurtbox** component system with collision layer separation

### Water & Swimming
- **Wading** slows you down as the water gets deeper (splashes instead of footstep dust)
- **Swimming** at chest depth: breaststroke when moving (Shift swims faster), treading water when still, head kept above the waves; weapons are sheathed
- **Duck under** with Ctrl for a few seconds (head-first dive), then bob back up
- **Stamina**: strokes drain it slowly, fast swimming and diving more, treading water lets it creep back. Run dry and you're exhausted: you lose a little health every second until you recover or get out
- **Climbing out**: rope ladders down both sides of the ship and at the end of the dock (F or Space), or pull yourself up onto any low ledge just above the water (Space); walk out at a beach
- The camera stays above the waves
- **Bodies float**: anyone knocked into the water (player, grunts, beetles) plunges under as a ragdoll, slows in the water, then bobs back up. In deep water you right yourself and start treading water instead of getting up; in the shallows you get up as normal. Dead bodies float
- **Grunts and water**: they keep out of the sea (they'll walk the waterline but won't wade in past it). If they end up in it anyway (knocked in, shoved off the beach), they swim like you do, head above the waves, and make for the nearest walkable bit of beach, then rejoin the fight or head home. No attacks from the water; hits still land, and a heavy hit sends them under

### Ship & Sailing
- **Kinematic sloop** with its own boat model: W/S work the sails (speed builds and bleeds off slowly), A/D the rudder (turns harder with speed); it slides along and stops against shores and docks
- **Gentle swell**: the hull samples the waves under bow, stern and both sides and eases into a slow heave, pitch and roll (plus a heel in turns) instead of following every wave
- **Walkable deck**: collision matches the visible deck, waist-high bulwarks, cabin (with a roof you can stand on), mast and helm; the deck carries you while under way
- **Captain at the wheel**: you stay visible at the helm, hands on the spokes; the wheel turns with the rudder and you lean with it. F steps away from the wheel onto the deck
- **Bow spray and wake** while sailing
- **Ship compass** HUD indicator showing direction and distance

### Ocean
- **Animated ocean** with dual sine-wave vertex displacement shader
- **Fresnel water** coloring with foam on wave peaks
- **Infinite ocean** illusion via grid-snapped camera following
- **Synchronized** wave math between shader and GDScript for buoyancy

### Procedural World
- **Continuous terrain** mesh covering the entire play area (no floating island squares)
- **Plateau-style islands** with steep coastlines and flat playable interiors
- **Multi-layer noise**: seafloor, island shape, terrain features (hills/valleys), and surface detail
- **Height-based terrain shader**: seafloor, sand beaches, grass, rock, snow with slope detection
- **6 procedurally placed islands** with configurable seed, size, type, and spacing
- **Island types**: Wild, Military, Pirate, Town (each with different size/height/enemy configs)
- **Dock generation** at each island shoreline with ship placement

### Atmosphere
- **Tropical sky** with procedural sky material
- **3D cloud system** with billboard cloud meshes, FBM noise shapes, and drift animation
- **Cloud shadow plane** casting moving shadows across the terrain and ocean
- **Volumetric fog** with sun scatter for atmospheric haze
- **ACES tonemapping**, SSAO, SSIL, and glow for cinematic visuals

### Player
- **Third-person camera** with SpringArm3D, mouse orbit, scroll wheel zoom
- **Double jump** with air control, locked until the skill system arrives (F9 toggles it in debug builds)
- **Sprint** at increased speed
- **State machine** architecture (Idle, Move, Jump, Fall, LightAttack, HeavyAttack, Dodge, Parry, Stagger, Helm)
- **Interaction system** (F key) for boarding ship, banking loot, picking up items

### Progression & the Skill Map
- You start at **level 1** with only the basics: light and heavy attacks, dodge, parry, jump, the plunge attack. **Experience** comes from combat (a grunt 45, a rifleman 55, a scuttlebug 25, the big one 120); each level gives **2 skill points**, a little health and damage, and refills you. A banner tells you to open the map
- **Skill map (K)**: two tabs (click them or press Tab), **Skill Map** and **Devil Fruit** (your fruit's own tree). It frames the whole cluster every time it opens. The map is one pannable, zoomable constellation (drag / WASD to pan, wheel / Q E to zoom). Click a node to see it, click again (or Enter) to learn it; you can learn any node linked to one you own. Learned active skills go on the bar automatically; select one and press 1-4 (R for an ultimate) to move it, right-click a bar slot to clear it. Every skill shows its icon and name on the map (icons load straight from disk if the editor hasn't imported them yet)
  - **Center**: stats (health, damage, stamina, energy, defense, regen, ultimate charge)
  - **Mobility**: Geppo (air jump), Soru (instant untouchable step, works in the air), Swift Step (cheaper dodge), Sky Walk (a third jump), Fleet Foot, Shadow Step (longer, safer dodge)
  - **Survival**: Hardy, Tekkai (iron body: 70% less damage, no flinch or knockdown, barely moving), Steadfast (light hits don't flinch you), Iron Hide, Mend (heal out of combat), Last Stand (survive a killing blow once a minute)
  - **Sword**: Blade Mastery, Flying Slash (a piercing crescent of wind), Twin Blades (dual wield bonus), Tiger Rush (dash through the line with one cut)
  - **Gun**: Marksman, Quick Hands (faster reload), Bullet Storm (seven shots fanned across the front), Extra Powder (+1 shot per pistol)
  - **Armament Haki** (level 10+): +8% damage and unblockable heavy attacks that break red wind-ups; Armament: Coat (8 s: your weapon arm, or both arms bare-handed, turns glossy black with a purple sheen and crawling purple sparks, the blade goes black, swings leave purple trails, nothing can block you and every hit breaks red wind-ups; it comes on with a deep haki boom)
  - **Observation Haki** (level 10+): enemy wind-ups flash, a wider parry window; Foresight (the next hit is dodged automatically, with a beat of slow motion)
  - **Devil Fruit** tab: your fruit's tree, once you've eaten one
- The character sheet (inventory, Character tab) shows level, XP, points, your fruit and your skill bar. F9 in debug builds grants a level

### Devil Fruits
Three are hidden on Brinehollow, one of each type. You can only ever eat one (a second would kill you), and every one carries **the sea's curse**: you can never swim again. Deep water drags you under, you trudge along the bottom and drown unless you reach shallow water or a ladder, fruit powers fizzle waist-deep, and your body sinks if you're knocked into the sea. Eating one asks first.
- **Ember Fruit (Logia)**, the smugglers' strongbox. *Flame Body*: your dodge turns you to fire, fully untouchable for the whole dash and passing straight through enemies and gunfire. Starts with **Fire Fist** (fireball) and **Blazing Ring** (knockdown ring). Tree: Kindled Blade (melee hits sear), Smoldering Body (the dodge leaves embers), Flame Dash, Ember Field (burning ground enemies avoid), Searing Heat, and the **Great Inferno** ultimate (level 8). Fire burns away dry thornbrush (the jungle stash is walled in by it); burning is damage over time that doesn't make enemies flinch, and fire can't be blocked
- **Wolf Fruit (Zoan)**, in the jungle ruins. *Hybrid Form* (V): a wolf-man with fur, muzzle, ears, claws and a tail; claws replace weapons, 25% more damage, 15% faster. Starts with **Rending Fang** (lunge and rake three times) and **Pounce** (a bounding leap that slams down). Tree: Thick Pelt, Predator, **Alpha Howl** (8 s of +25% damage and speed, nearby enemies flinch)
- **Vine Fruit (Paramecia)**, up on the hill. *Photosynthesis*: out of combat, on land, you slowly heal and regain energy. Starts with **Vine Snare** (a seed that roots enemies in place) and **Vine Swing** (aim at a tree, cliff, roof or wall: the vine shoots from your raised hand, which is wrapped in vines, and you swing with your body lined up along the vine and your legs and free arm hanging loose; steer and push with the swing to build speed, jump to let go and fly out tilted, righting yourself before you land). Aim it at an **enemy** to grapple: grunts and small bugs are yanked to your feet, while big scuttlebugs (and bosses later) haul you to them and you crash in feet first. Vine Snare wraps both arms in vines as you throw. Tree: Deep Roots, Thorn Hide (melee attackers get pricked), **Thorn Whip** (lash a line of enemies and drag them in)
- **Afterglow**: every fruit power leaves its color on you for a couple of seconds - Vine: vines stay coiled round all four limbs and leaves drift off you; Ember: smouldering hands and rising embers; Wolf: dark wisps and amber motes (also when you shift form). With the Vine Fruit, dashing sprouts little vines along the ground that wither away
- Energy (100, more from the skill map) is mostly earned by fighting: every melee hit gives 5, and it only trickles back on its own (2.5 a second, not at all for 1.5 s after a cast). The orb shows a draining chip when you spend it. The ultimate charges from damage you deal (not from its own)

### Title Screen & Saving
- The game opens on a **title screen** (a dusk sea with a ship riding the swell): **Continue** (your most recent save), **New Game**, **Load Game**, Options and Quit
- **Three save slots**, each showing your captain's name, level, Devil Fruit, play time and when it was saved. New Game asks before overwriting a slot, and any slot can be deleted. A new game opens the character creator
- Each slot holds your captain's look, level, XP, skill points, the skill map, the skill bar, your Devil Fruit (and hybrid form), inventory, worn gear, both weapons, banked loot, chests you've opened, thornbrush you've burned, conversations you've had, play time, and where you and the ship are. Autosaves on level up, eating a fruit, banking at the ship, every two minutes, and on quit
- Pause menu: **Save Game**, **Load Game** (asks first, since anything since your last save is lost), **Quit to Title** (saves first) and Quit Game
- An old single save (savegame.dat) becomes slot 1. Running the world scene straight from the editor continues your latest save (or starts a new game in slot 1)

### Systems
- **Inventory** component with item stacking
- **Loot bags** that drop on death with recovery mechanic
- **Resource banking** at the ship (temporary loot becomes permanent)
- **Death & respawn** at ship with loot drop at death location
- **Health component** with damage/heal signals
- **Enemy spawner** framework with configurable scenes and spawn points
- **Game manager** autoload for death handling and banking

## Island Gameplay Loop

1. **Arrival & Observation** -- Read the island from the ship
2. **Player-Driven Decision Making** -- No waypoints, no quests
3. **Engagement** -- Combat, exploration, environmental interaction
4. **Reward Acquisition** -- Find loot (temporary until banked)
5. **Risk Evaluation** -- Keep pushing or extract back to ship?

## Controls

| Input | Action |
|-------|--------|
| WASD | Move / Steer ship |
| Mouse | Look / Aim |
| Scroll Wheel | Zoom camera in/out |
| Shift | Sprint |
| Space | Jump (double jump once unlocked) |
| Z | Ready / sheathe weapon |
| 1 - 4 | Skills (learned on the skill map) |
| R | Ultimate |
| K | Skill map |
| V | Zoan: shift between human and hybrid form |
| Left Click | Light attack (draws weapon if sheathed) |
| Right Click | Heavy attack |
| 5 - 7 | Quick items (consumables) |
| Q (hold) | Block |
| Tab / I | Inventory |
| F9 | Debug builds: gain a level |
| F10 | Debug builds: knock yourself down (ragdoll test) |
| Ctrl (in water) | Duck under |
| Space / F (in water) | Climb a ladder or a low ledge |
| Left Ctrl | Dodge (sidestep dash) |
| Q | Parry |
| F | Interact (talk, board ship, bank loot, pick up items) |
| F / Space / Left Click | Advance dialogue |
| W / S or 1-9 | Choose a dialogue option |
| Escape | Pause menu (save, load, options, controls, quit to title) |
| F2 | Cycle PSX resolution |
| F3 | Toggle dithering |
| F4 | Toggle debug state label |
| F11 / Alt+Enter | Toggle fullscreen (remembered between runs) |

## Project Structure

```
scripts/
  state_machine/       -- Generic FSM (State, StateMachine)
  player_states/       -- All player states (idle, move, combat, helm, etc.)
  combat/              -- CombatManager, HealthComponent, HitData, Ragdoll (with muscles + buoyancy)
  powers/              -- DevilFruits (fruit types), PowerComponent (skill bar loadout, energy,
                          cooldowns, buffs, ultimate, blasts), Fireball, Projectile, FireZone, BurnStatus, VineRope
  progression/         -- Progression (level, XP, skill points), SkillTree (the skill map's nodes),
                          Skills (every active skill)
  ship/                -- Ship controller (sailing, swell, deck collision)
  ocean/               -- OceanManager (wave height sync)
  island/              -- IslandGenerator, WorldGenerator, EnemySpawner
  loot/                -- ItemData, ItemStack, InventoryComponent, EquipmentComponent, Gear (+ GearIcons), LootBag
  interaction/         -- Interactable, InteractionComponent
  game/                -- GameManager (death, respawn, banking, XP, world state), SaveGame
  input/               -- InputBuffer (150ms buffered combat input)
  world/               -- CloudSpawner, Burnable (thornbrush that fire clears), GrapplePoints (tree crowns a vine can latch onto)
  island/starter_island.gd -- Brinehollow: terrain, layout, props, NPCs, loot
  psx/                 -- PSX settings autoload, PSXMat material cache, MeshBuilder
  props/               -- Props factory (trees, buildings, dock, lighthouse, ruins...)
  npc/                 -- Humanoid (skeleton + pose animator), BodyBuilder (tapered body + clothing),
                          CharacterLook (options, palettes, save/load), NPC
  ui/                  -- GameMenu (pause/options/controls), InventoryScreen (overlay + paper doll + character sheet), CharacterCreator, UIStyle, Reticle, SkillBar (HUD), SkillMapScreen (K), TitleScreen (main scene), SaveSlotList
  game/settings.gd     -- Settings autoload (all options, audio buses)
  loot/item_db.gd      -- item lookup by id (resources/items/*.tres)
  dialogue/            -- Dialogue autoload + dialogue box UI

shaders/psx/           -- psx_lit, psx_cutout, psx_post (+ shared include)
data/dialogue/         -- NPC conversations (JSON)
assets/                -- generated textures, audio, pixel fonts
tools/texture_gen/     -- Python generators for textures and sounds

scenes/
  player/              -- Player scene, CameraRig
  combat/              -- Hitbox/Hurtbox reusable components
  ship/                -- Ship scene with deck, helm, bank zones
  ocean/               -- Ocean mesh + water shader
  island/              -- Terrain shader, island_01 (legacy)
  enemies/             -- DummyTarget (scuttlebugs and pirate grunts are built in code: scripts/enemies)
  effects/             -- Damage numbers
  loot/                -- LootBag scene
  ui/                  -- PlayerHUD
  world/               -- World scene, cloud shaders
```

## MVP Goals

From the [Game Design Document](documentation/gdd.html):

- [x] One fully realized island (procedural generation with multiple islands)
- [x] Sword-based combat system
- [x] One Devil Fruit implementation (Ember Fruit; plus the Wolf and Vine fruits)
- [x] Basic enemy types + one Elite enemy (scuttlebug + big scuttlebug)
- [x] Death and recovery system
- [x] Simple ship respawn system

## Development Principles

- Build the smallest playable version first
- Prioritize feel over features -- always
- Avoid premature complexity at every stage
- Test early and iterate frequently
- Expand only after the core loop is proven

## Notes

- **Fullscreen from the editor**: Godot 4.4+ runs the game embedded in the editor's *Game* tab by default, where fullscreen isn't possible. Untick *Embed Game on Next Play* in the Game tab (or run an exported build) to get a real window you can resize or make fullscreen.
- Physics interpolation is on (smooth motion on high-refresh monitors). If you teleport something, call `reset_physics_interpolation()` on it afterwards; nodes moved every frame in `_process` (camera rig, ocean) have interpolation turned off.

- **Exporting**: the dialogue JSON files aren't Godot resources, so add `data/dialogue/*.json` to *Export > Resources > Filters to export non-resource files* or the NPCs will be silent in exported builds.
- Characters and textures are procedural placeholders in a PS1 style. Dropping in a rigged low-poly character pack or hand-painted textures is a straightforward upgrade: `Humanoid` and `PSXMat` are the swap points.

## Tech Stack

- **Engine**: Godot 4.6 (Forward+ renderer)
- **Physics**: Jolt Physics
- **Language**: GDScript
- **Rendering**: D3D12

---

*Systems-first design. Build. Test. Expand.*
