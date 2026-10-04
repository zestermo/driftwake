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
- **Smugglers' camp** on the shore past the cove: tents, a campfire, contraband, a rowboat and a strongbox (treasure, gold and the Smuggler Captain's Tricorn), guarded by five pirate grunts who come back a while after you've cleared them out
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
- **Jointed skeleton** (knees, elbows, neck, hand + hip sockets) with a procedural pose animator: a speed-blended gait (a real walk at low speed, a relaxed, springy jog at normal speed with forward lean, hip sway, shoulder counter-twist and loose follow-through arms, and a long-striding, leaning sprint), the head moves on the neck with springy inertia (idle glances and tilts, a steady gaze that counters the shoulders' twist when running, leading into turns), bouncy idle, combat-stance hop, strafing, arms-up jump, double-jump flip, falling flail, landing squash, sidestep dash, parry block, stagger, three-hit slash combo, heavy leaping slam, drinking
- **Bouncy platformer feel** (Mario 64 / A Hat in Time style): squash & stretch on jumps, landings and footsteps; precise, instant control (movement follows the stick exactly, stops on a dime) with weight carried by the visuals: the body tilts to match slopes and leans in the camera's frame (forward with speed, further when starting, back when stopping, banking when you turn the camera), so weaving left/right doesn't throw it around; coyote time, jump buffering, variable jump height (tap = short hop, hold = full jump), faster falls, and sprint momentum carried through jumps
- **Effects**: sword slash trails, whooshes, hit sparks, footstep dust, landing dust rings, dodge dust trails and sparkles, all with generated sounds
- **Ready / sheathe (R)**: the weapon moves between the left hip and the right hand with draw/sheathe animations. Drawn = combat stance: you strafe facing the camera, the camera moves over your shoulder, and a reticle appears (red when an enemy is in reach). Attacking while sheathed draws first
- **Weapons**: Cutlass (start) and Boarding Axe (x1.4 damage, found in the jungle ruins). Weapon damage multiplies all attacks
- **Hotbar (1-5)**: weapons equip/draw (press again to sheathe), consumables are used (Brinehollow Black rum heals 35)
- **Inventory (Tab / I)**: an overlay on the game, not a separate menu. The world pauses and the camera swings round to face your captain, who stands on the left as the paper doll with gear slots on either side (head, torso, vest, coat, belt, hands, legs, feet, two accessories, weapon). The panel on the right has two tabs: **Inventory** (20-slot bag, item details with defense compared against what you're wearing, hotbar; click gear to wear it, click a worn slot to take it off, press 1-5 over a weapon or consumable to put it on the hotbar) and **Character** (Strength / Agility / Endurance, health, stamina, damage, defense, speeds, abilities, worn gear). Drag your captain to turn them. Banking and death only affect loot (gold/treasure); gear stays with you
- **Gear**: clothing and armor are items. Each piece changes how you look and adds defense (armor soaks damage with diminishing returns). The outfit you make in the character creator becomes your starting gear, and more is hidden in the island's chests. After creation, Appearance (pause menu) only edits body, face and hair
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
- **Light attack** 3-hit combo (forehand, backhand, spinning finisher) with exaggerated wind-ups and lunges. The combo is remembered for ~0.9 s, so you can attack, reposition, and click again to continue the chain instead of restarting it
- **Heavy attack** with windup, forward lunge, and recovery phases
- **Sidestep dash** with i-frames: bursts in the input direction while you keep facing forward (sidestep, lunge-dash or backstep; no input = backstep)
- **Parry** with timing-based active window
- **Hitstun**: light hits make the victim flinch briefly and shove it back (interrupts an enemy's attack; the player gets a short flinch)
- **Physics ragdolls**: heavy attacks throw the target into a ragdoll (rigid bodies with limited joints driving the rig); it gets back up from wherever it lands (face up: sits up; face down: pushes up). Deaths ragdoll and stay down. F10 knocks you over in debug builds
- **Parry** a scuttlebug's ram to flip it onto its back
- **Pirate grunts**: cutlass swordsmen in a varied crew (creator parts, red crew sash). They sit, stand guard or patrol until they spot you, then raise the alarm. In a fight they circle and strafe; only two attack at a time. Each attack has a held wind-up with a glint on the blade: a two-slash combo up close or a lunge from range, then a recovery window. They block light hits from the front (sparks, and sometimes a quick counter-slash), but the guard breaks on the third block. Hits from the side or behind, during their wind-up or recovery, and heavy attacks get through. Parrying a swing staggers them; heavy hits knock them down. They give up and go home if you run or swim away
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
| R | Ready / sheathe weapon |
| Left Click | Light attack (draws weapon if sheathed) |
| Right Click | Heavy attack |
| 1 - 5 | Hotbar |
| Tab / I | Inventory |
| F9 | Debug builds: toggle double jump |
| F10 | Debug builds: knock yourself down (ragdoll test) |
| Ctrl (in water) | Duck under |
| Space / F (in water) | Climb a ladder or a low ledge |
| Left Ctrl | Dodge (sidestep dash) |
| Q | Parry |
| F | Interact (talk, board ship, bank loot, pick up items) |
| F / Space / Left Click | Advance dialogue |
| W / S or 1-9 | Choose a dialogue option |
| Escape | Pause menu (options, controls, quit) |
| F2 | Cycle PSX resolution |
| F3 | Toggle dithering |
| F4 | Toggle debug state label |
| F11 / Alt+Enter | Toggle fullscreen (remembered between runs) |

## Project Structure

```
scripts/
  state_machine/       -- Generic FSM (State, StateMachine)
  player_states/       -- All player states (idle, move, combat, helm, etc.)
  combat/              -- CombatManager, HealthComponent, HitData
  ship/                -- Ship controller (sailing, swell, deck collision)
  ocean/               -- OceanManager (wave height sync)
  island/              -- IslandGenerator, WorldGenerator, EnemySpawner
  loot/                -- ItemData, ItemStack, InventoryComponent, EquipmentComponent, Gear (+ GearIcons), LootBag
  interaction/         -- Interactable, InteractionComponent
  game/                -- GameManager (death, respawn, banking)
  input/               -- InputBuffer (150ms buffered combat input)
  world/               -- CloudSpawner
  island/starter_island.gd -- Brinehollow: terrain, layout, props, NPCs, loot
  psx/                 -- PSX settings autoload, PSXMat material cache, MeshBuilder
  props/               -- Props factory (trees, buildings, dock, lighthouse, ruins...)
  npc/                 -- Humanoid (skeleton + pose animator), BodyBuilder (tapered body + clothing),
                          CharacterLook (options, palettes, save/load), NPC
  ui/                  -- GameMenu (pause/options/controls), InventoryScreen (overlay + paper doll + character sheet), CharacterCreator, UIStyle, Reticle
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
- [ ] One Devil Fruit implementation
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
