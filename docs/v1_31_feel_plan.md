# 1.31 game feel: motion, camera and screen

Zach, 2026-11-09: "do 1-10 automatically" (the animation audit's ten items) and tie them into the 1.31 screen-feel
candidate (docs/todo.md: camera shake, hit effects on the screen, speed, a vignette). Built in one pass by one
session in the main checkout; every piece has an atomic test. The looks were picked first: dithered cel shading (on by
default, Video > Cel shading) and the toon sea with it; the clouds stay as they were (both toon decks declined).

## Screen feel (the 1.31 candidate), built

All local to the captain's own screen (the camera rig, never through Net), scaled by the new **Screen effects**
slider (Settings gameplay `screen_fx`, 0..1, beside Camera shake). Drawn in the PSX post pass (psx_post.gdshader),
before the 15-bit quantize, so they step and dither like everything else.

- **Low health:** a red vignette from 35% health down, pulsing faster (3 -> 9 a second) toward death.
- **Knockout blink:** the screen dims toward black on a knockdown (0.55), a splat (0.5-0.9 by its power) and a damaging
  fall (by the damage), fading at 1.6 a second.
- **Speed:** flying fast (launched, a long fall, >11 m/s; a dash on the ground at 80%) smears the picture out from the
  middle (4 taps, edges only) and widens the view up to 9 degrees.
- **Bob and dip:** a light camera bob at a sprint (3.5 cm), a dip on landing by its force.
- **Felled foe:** a short punch-in (CombatManager.apply_camera_kick 0.22) when your blow drops one.

## The audit's ten

| # | Item | Status |
|---|------|--------|
| 1 | Attack assist | **Built.** Light attacks turn onto the foe within 6.5 m and 60 degrees of the camera's line (nearer and straighter wins; training dummies count) and the light's lunge grows to reach it (impulse sqrt(v^2 + 2 * 15 * gap), gap <= 3.2 m). Nobody in the cone: the camera's line, as before. Heavies keep the camera's line (their launchers and plus moves have their own travel), and a hook (the twin axes' third) turns without stepping in. `PlayerState.assist_target / assist_lunge`. |
| 2 | Fight framing | **Built.** Weapon out, the foe you last hit drifting more than 24 degrees off the view's centre turns the camera gently after it (within 9 m); the mouse or stick holds it off for 1.2 s; only while moving, idle, light-attacking or blocking, never for a foe closer than 1.5 m or more than 100 degrees off (a dash through a foe mustn't swing the view round). `camera_rig._frame_fight`. |
| 3 | Turns | **Built.** Running round a curve banks the body into it from the feet (yaw rate x speed, up to 0.2 rad); turning on the spot steps the feet round (a step every 0.55 rad). Starts, stops and reversal skids already existed. `Humanoid._turn_moves`. |
| 4 | Landings | **Mostly there already** (the landing pose: the lower foot first, knees and chest by fall speed). Added: a hard landing at a run (k > 0.6, > 6 m/s) rolls out of it (`dodge_roll`). |
| 5 | Light hits | **Built, as a visual layer.** Light hits still stagger you (Steadfast removes that: a balance choice kept). A blow that lands without staggering (Steadfast, armour poise, Reinforce; a grunt shrugging off a hit or a ball) jolts the upper body away from it over the pose, legs untouched, 0.2 s, mirrored in co-op. `Humanoid.jolt`. |
| 6 | Interaction moves | **Gaps filled.** The gesture system existed (Interactable.gesture, 32 uses); the galley table, the restaurant's spots, the brig, the undercity's hatch and doors, the marked ironwood and the ship's fruit grove now gesture too. Still open (1.31 todo): the ship's deck jobs (pump, patching, fires) and opening the inventory. |
| 7 | Enemy tells | **Already there** (1.28's tell language: `wind_up_glint`, `warn_ring`, `warn_lane`; grunts' glints). Nothing added. |
| 8 | Idle life | **Built.** Standing about with the weapon away, every 4-8 s the weight shifts onto the other leg (everyone); the captain, idle with the view still for 3 s, glances at the nearest person within 8 m every ~3.5 s. NPCs already glanced at captains. |
| 9 | Wind on hair and cloth | **Built.** The chains (hair, coats; native and script solvers) take the weather's wind as an acceleration (Weather.wind_now x 6 m/s/s, gusting); foliage sways by the same wind (wind_vec). |
| 10 | Dust and splashes | **Mostly there already** (footstep dust, wading splashes, skid dust). Added: breaking into a run kicks up dust, and an assisted lunge that closes a gap kicks up dust (Net.fx). |

## Costs

- Post pass: 4 extra screen taps only while the speed smear is on; the vignette and dim a few ALU. One Settings read
  and at most 3 shader parameter sets a frame (cached).
- Bank, shuffle, weight shift, jolt: a few vector ops per posed rig a frame (no allocation when no jolt plays).
- Wind on chains: one native set_gravity call per chain set a frame near the camera.
- Attack assist: one pass over the enemies group per attack. Idle glance: one pass over npcs/players every ~3.5 s idle.

## Tests

t/combat/attack_assist, t/combat/hit_jolt, t/player/screen_feel, t/player/turn_land (with t/fx/cel_switch from the
cel pass). Suites expected to notice (prepush): combat suites that aim attacks at foes off the camera's line, the
cloth/hair numbers (clothlab, coat tests) now that wind pushes the chains, any golden render.

## Known issues

- t/weapons/rapier_tree: "balestra lands on the dummy (0 damage)" fails on main before this work too (checked in a
  clean worktree of cc3224ac); not from 1.31 feel.
- t/combat/poise_knockdown and t/combat/rival_personality each failed once and passed on rerun (timing).
- Not checked in renders or in play: how the bank, the weight shift and the screen effects look. Zach plays it.
