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

### Combat System
- **Light attack** 3-hit combo chain with timing windows and input buffering
- **Heavy attack** with windup, forward lunge, and recovery phases
- **Dodge roll** with directional input and i-frames
- **Parry** with timing-based active window
- **Stagger** state with knockback
- **Free-aim** combat (no lock-on) for fluid multi-enemy engagement
- **Hit feedback**: hitstop, camera shake, floating damage numbers
- **Hitbox/Hurtbox** component system with collision layer separation

### Ship & Sailing
- **RigidBody3D ship** with surface-locked buoyancy (follows wave height)
- **Helm control**: board the ship, steer with WASD, mouse-look camera
- **Visual wave tilt** on the ship model for natural rocking
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
- **Double jump** with air control
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
| Space | Jump (double jump) |
| Left Click | Light attack |
| Right Click | Heavy attack |
| Left Ctrl | Dodge roll |
| Q | Parry |
| F | Interact (board ship, bank loot, pick up items) |
| Escape | Toggle mouse capture |

## Project Structure

```
scripts/
  state_machine/       -- Generic FSM (State, StateMachine)
  player_states/       -- All player states (idle, move, combat, helm, etc.)
  combat/              -- CombatManager, HealthComponent, HitData
  ship/                -- Ship controller, BuoyancyComponent
  ocean/               -- OceanManager (wave height sync)
  island/              -- IslandGenerator, WorldGenerator, EnemySpawner
  loot/                -- ItemData, ItemStack, InventoryComponent, LootBag
  interaction/         -- Interactable, InteractionComponent
  game/                -- GameManager (death, respawn, banking)
  input/               -- InputBuffer (150ms buffered combat input)
  world/               -- CloudSpawner

scenes/
  player/              -- Player scene, CameraRig
  combat/              -- Hitbox/Hurtbox reusable components
  ship/                -- Ship scene with deck, helm, bank zones
  ocean/               -- Ocean mesh + water shader
  island/              -- Terrain shader, island_01 (legacy)
  enemies/             -- DummyTarget
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
- [x] Basic enemy types + one Elite enemy (framework in place, dummy targets)
- [x] Death and recovery system
- [x] Simple ship respawn system

## Development Principles

- Build the smallest playable version first
- Prioritize feel over features -- always
- Avoid premature complexity at every stage
- Test early and iterate frequently
- Expand only after the core loop is proven

## Tech Stack

- **Engine**: Godot 4.6 (Forward+ renderer)
- **Physics**: Jolt Physics
- **Language**: GDScript
- **Rendering**: D3D12

---

*Systems-first design. Build. Test. Expand.*
