# Driftwake audio audit (2026-10-09)

Every sound and music file, where it is made and played, what was wrong with it
and what this pass did. Numbers come from `tools/texture_gen/audio_report.py`
(run it any time: `py tools/texture_gen/audio_report.py [name filter]`).

Report columns: **LU** = loudness (K-weighted, LUFS-like: loudest 400 ms for
one-shots, integrated for loops), **crest** = peak over RMS (dB), **cent** =
spectral centroid (Hz), band shares of energy (%) below 200 Hz / 200-1k / 1-2k /
**2-5 kHz (where noise turns harsh)** / above 5k, **res** = sharpest resonant peak
above the smoothed spectrum, **seam** = loop-end jump against a typical sample step
(and level change across it), **repeat** = strongest repeat of the loudness envelope
inside a loop (0.7 at 6 s = an audible 6 s beat).

## The top findings

1. **Every ambience loop played only its first ~20%.** The .wav files import
   QOA-compressed (`compress/mode=2`), and `Ambience._loop_player` (and Weather's rain)
   set `loop_end = data.size() / 2`, a 16-bit PCM byte count. QOA is ~3.2 bits a
   sample, so the loop ended a fifth of the way in. The imported hull wash is
   71,791 bytes for 8 s of audio: it looped its first **1.6 s** (1.3 s at the
   full-speed pitch of 1.25). The open-sea swell (24 s) looped 4.9 s, the wind
   (20 s) 4 s, the shore surf (30 s) 6 s, the rain (8 s) 1.6 s. This is the "4 second
   loop" Zach heard. Fixed: the loop end comes from `get_length() * mix_rate`;
   ambiencetest now checks every loop plays its whole length.
2. **The hull wash itself was harsh and mechanical**: 250-3000 Hz noise with a
   steep 4th-order band edge ("noise in a box"), 42% of its energy at 1-5 kHz,
   amplitude-fluttered at 6 Hz, pitched up to 1.25 at speed, at -9 dB: about 8 LU
   louder than everything else in the mix at full speed (-23.6 LU vs the swell's
   -31). Replaced by three layers (below).
3. **Loops restarted from sample 0 every time they faded in**, so each return to
   the deck began identically. Now every loop starts at a random point.
4. **The open-sea swell was strictly periodic**: four cosine swells in its 24 s
   (repeat score 0.70 at exactly 6.0 s). Rebuilt with swells at uneven gaps (47 s).
5. **One footstep for everything**: a single 70 ms thump (92% below 200 Hz),
   played at -20 to -10 dB (about -32 LU in game: barely there), the same on sand,
   decks and stone. Wading added a pitched splash.
6. **One take per combat sound**, made distinct only by pitch jitter. Whooshes
   were louder than the hits they lead to (whoosh -13.2 LU at -6..-9 dB vs hit
   -18.9 LU at -2 dB), which undersells every impact. Gunshot (96% below 200 Hz,
   centroid 97 Hz), cannon (98%, 67 Hz), thud (100%, 65 Hz) and land (95%) were
   nearly all sub-bass: on laptop speakers or TV speakers they are a soft pop.
7. **Peak-normalised, not loudness-normalised**: one-shots ranged from -24.5 LU
   (block) to -10.3 LU (howl) in the files, so the volume_db at each call site was
   doing loudness correction as well as mixing.
8. **Aliasing and square waves**: the parry had a partial at 12.9 kHz (above the
   11 kHz Nyquist of the 22.05 kHz files: it folded back as a stray tone); UI blips,
   the text blip and the peril sting were naive square waves (odd harmonics up to
   Nyquist, aliasing fizz).
9. **No limiter anywhere**: buses were made at runtime (Settings) with no
   effects. A broadside, a roar and the music together could clip the master.
10. **Silent call**: plunge_state played `"blip"`, which wasn't in FX's sound list
    (FX.sfx returns quietly on unknown names). Added.
11. **Music is technically clean** (loops seamless, -18.2 LU each, no clipping,
    nothing harsh above 5 kHz) but **short**: 43-58 s loops, so the same minute
    repeats all session. Leaving a calm track for a fight restarted it from the top
    on return. Zach's chosen style samples (corsair_waters, harbour_calm) aren't in
    the game yet. See proposals.

## Buses and mixing

| Bus | Made by | Default | Effects (before) | Effects (now) |
|---|---|---|---|---|
| Master | engine | 0.8 | none | **HardLimiter, ceiling -0.5 dB, release 0.12 s** |
| SFX | Settings._ensure_buses | 1.0 | none | none |
| Ambience | Settings | 0.8 | none | none |
| UI | Settings | 0.8 | none | none |
| Music | Settings | 0.6 | none | **Compressor keyed from SFX (v1.12): ducks under big sounds** |

- FX.sfx: AudioStreamPlayer3D on SFX, unit_size 6, max_distance 60 (not made past
  64 m from the camera), inverse-distance falloff, pitch jitter per call (default
  +-8%). Co-op: `Net.fx("sfx", ...)` plays it on every screen. Now picks a take at
  random (AudioStreamRandomizer, never the same twice running) when name_1.wav... exist.
- Ambience (Weather/Ambience): 2D AudioStreamPlayers on Ambience, levels moved at
  24 dB/s toward a target per frame. Weather: rain loop and thunder one-shots
  (2D, Ambience bus). Campfires: AudioStreamPlayer3D loops (unit 4, max 30 m).
- Music: two players crossfading (1.8 s, 0.7 s into fights), a sting player,
  BASE_DB -5, victory ducks the music 14 dB for 5.5 s.
- UI: one AudioStreamPlayer per menu sound (UIStyle.SOUNDS, made under GameMenu so they play while
  paused) on UI, played with `UIStyle.sfx(name)`; the dialogue voice blip and the HUD's discover_chime
  keep their own players.

## Ambience loops

| Sound | Made in | Played | Before | Problem | Now |
|---|---|---|---|---|---|
| hull_wash_loop | gen_psx_audio | Ambience "wash", -9 dB x speed, pitch 0.85-1.25 | 8 s (played 1.6 s), -14.6 LU, 42% at 1-5 kHz, 6 Hz flutter | the worst sound in the game: short, bright, boxy, loudest layer | **removed**, replaced by the three below |
| hull_rush_loop | new | "wash", -9 dB, pow(spd/8, 0.7), pitch 0.88-1.08 | | | 37 s, -20 LU, centroid 585 Hz, 6% at 2-5k; dark and bright takes crossfaded on a slow random curve, slow surges, a low body |
| hull_gurgle_loop | new | "gurgle", -13 dB, most of the sound when slow | | | 23 s, bubbles as rising chirps in clusters, a churning mid bed, deeper gloops |
| hull_foam_loop | new | "foam", -17 dB, comes in above 4 m/s | | | 29 s, soft fizz of bursting foam (bright, rolled off above 6 kHz) |
| (all three) | | | | | random start points, lengths that never line up (37/23/29 s), slow level and pitch drift, surge when the bow drops into a swell |
| bow_spray (3 takes) | new | FX.sfx at the bow when the ship throws its spray (ship.gd, local per machine like the visual) | | | 1.8 s: whump, rush, spray sheet, patter on the deck |
| sea_swell_loop | gen | "sea", -11 dB | 24 s (played 4.9 s), repeat 0.70 at 6.0 s | periodic beat | 47 s, uneven swells, foam on the big crests, laps |
| shore_surf_loop | gen | "shore", -8.5 dB | 30 s (played 6 s) | the five waves never got heard | same design, levelled; now plays all 30 s |
| wind_loop | gen | "wind" | 20 s (played 4 s) | short | 41 s |
| rigging_wind_loop | gen | "rig" | 16 s (played 3.2 s) | short | 31 s |
| ship_creak_loop | gen | "creak" | 16 s (played 3.2 s, often silent: sparse events) | short | 33 s, twice the creaks |
| hull_slap_loop | gen | "slap" at rest | 12 s (played 2.4 s) | short | 19 s, 22 slaps |
| rain_loop | gen | Weather, -6 dB x rain | 8 s (played 1.6 s), end crossfade (seam 2.7x) | short, seam | 17 s, built circularly, droplet density drifts |
| campfire_loop | gen | 3D at campfires (looped by import) | 5.7 s, end crossfade, 42% above 5 kHz | short, hissy | 13 s, circular, crackles in uneven bursts, darker |
| ocean_loop | gen | **unused** (Brinehollow's ocean loop went in the 10-08 ambience pass) | | dead asset | removed |

| sea_deep_loop | new 10-14 | "deep", -9 dB, at sea / aboard / swimming, more in wind and storms | | | 53 s, -22 LU, 74% under 200 Hz: a slow low roll at uneven gaps, a hush on the big swells |
| sea_lap_loop | new 10-14 | "lap", -13 dB: swimming, wading, on a pier over water, near a quay ("wall" coast) | | | 27 s, -20 LU, centroid 1.1 kHz: slaps and slosh at uneven times, gurgles back |
| far_breakers_loop | new 10-14 | "far", -11 dB: a coast 25-185 m off (CoastProbe), louder in storms | | | 59 s, -20 LU, nothing above ~1.6 kHz: muffled booms with long hushed washes |
| rock_surf_loop | new 10-14 | "rock", -9 dB by distance to a rocky coast (cliffs, sea stacks, reefs) | | | 31 s, -20 LU: boom, crash, spray, water draining off the stones |
| shore_surf_loop | | "shore" now by distance to a beach coast (6 m full, gone at 90 m), with the swell | | | unchanged file |
| spray_hiss_loop | new 10-14 | "spray", -15 dB, aboard: follows ShipSpray.spray (+ whitecaps) | | | 23 s, -20 LU, 35% at 2-5k (softened from 46%): breathy hiss and patter |
| underwater_loop | new 10-14 | "under", -7 dB while the camera or the captain's head is under | | | 29 s, -21 LU: pressure rumble, low bubble clusters |
| wind (gusts) | | "wind" x (0.8 + 0.5 gust), pitch +7% on a gust; rigging + gust | | | gust envelope: more often and stronger with wind/storm (at most 16 x (1.4 - blow) s apart) |
| wind_gust (3 takes) | new 10-14 | 2D on Ambience at a gust's start (peak > 0.35) | | | -19 LU, 3.6-4.8 s swell and fall, a hint of whistle |
| wave_break (3) | new 10-14 | FX.sfx where SeaSpray breaks a wave on a beach in time with the crest (< 55 m) | | | -17 LU, 3.6 s: roll, crash, wash and fizz (22% at 2-5k) |
| rock_crash (3) | new 10-14 | FX.sfx where a wave breaks on rock (< 55 m) | | | -15 LU, 3.2 s |
| hull_wave (4) | new 10-14 | ShipSpray: each wave she meets at speed (the stem's water rising > 1.3 m/s), at the bow | | | -17.5 LU, 0.95 s: plank knock (150-500 Hz), slap, splash falling |
| gull_cry (4) | new 10-14 | SkyBirds: gulls by distance (< 60 m), scattering | | | -18 LU (the old gull is -10.6): kyow, kek-kek-kek, mew, long call |
| jungle_bird (4) | new 10-14 | SkyBirds: parrots hopping crowns, scattering | | | -20 LU: whistle run, hoot, squawk, parrot screech |

| desert_loop | new 10-15 | not wired yet: the desert theme's bed (suggested TOP_DB -13) | | | 47 s, -20 LU, 67% under 200 Hz: dry wind in long gusts, sand hiss off the crests, insect rasps, a far vulture |
| snow_loop | new 10-15 | not wired yet: the snow theme's bed (suggested -13.5) | | | 50 s, -20 LU: cold wind whistling on gusts, pine hush, ice groans, snow slumping off branches, one far wolf |
| forest_loop | new 10-17 | the forest theme's bed (Ambience "forest", TOP_DB -13) | | | 53 s, -20.2 LU, 3% at 2-5 kHz, repeat 0.19: wind through the leaves in slow gusts with a dry rustle, a trunk creaking, songbirds near and far, a woodpecker, crows, a stream's murmur, an owl now and then |
| sandstorm_loop | new 10-15 | not wired yet: Weather, in rain's place on desert islands | | | 41 s, -20 LU: unrelenting roar, sand hiss, grit, surging |
| blizzard_loop | new 10-15 | not wired yet: Weather, in rain's place on snow islands | | | 43 s, -20 LU: hard wind whistling on three edges, driving snow, howling sweeps |
| step_snow (4) / step_ice (4) | new 10-15 | not wired yet (FX.SOUNDS + Footsteps) | | | snow: soft thump, dense squeaky crunch, -21 LU; ice: sharp click, a ring at 1.7-4.9 kHz, -19.5 LU |

All ambience loops are now levelled to -20 LU and mixed by TOP_DB (sea_deep -22, underwater -21).

Under water (10-14): Ambience adds an AudioEffectLowPassFilter ("underwater", 12 dB/oct) to the SFX and
Ambience buses at runtime; it is off above water and closes to 480 Hz under (the music is left alone).

## Footsteps (new)

`scripts/game/footsteps.gd` finds the surface: a ray down from the feet; on terrain
it reads the splat (Brinehollow and the chain islands) or the height rules exactly
as `terrain.gdshader` paints them (wet sand at the waterline, sand, dirt paths,
rock where steep, grass), anything else is judged once per collider by the
textures on its meshes (planks = wood, cobbles/stone_brick/rock = stone, sand,
grass). A collider can say for itself with `set_meta("surface", "stone")`.
Brinehollow's harbour pier is cobbled stone, so it sounds like stone; ship decks,
the chain islands' timber docks and house floors are wood.

| Surface | Takes | LU | Design |
|---|---|---|---|
| step_sand | 4 | -21 | soft thump, granular crunch, sand sliding |
| step_grass | 4 | -22 | soft thump, rustle of blades, soil |
| step_dirt | 4 | -20 | firm thump, knock, a little grit |
| step_stone | 4 | -19.5 | heel click, boot-heel resonance, hard thump, grit |
| step_wood | 4 | -19 | hollow plank modes (135-185 Hz and up), heel click; one take creaks |
| step_water | 4 | -19 | slosh, bloop, drips (wading, from water_depth > 0.08) |

Heel then the roll onto the toe 45-75 ms later. Played from Humanoid's footstep
signal (each half stride, cadence from the gait) at -16 + 16 x strength dB
(walk about -8, sprint about -4), pitch +-6%. Landing adds the surface's step
(lower, louder with the fall) to the land thump. Puppets play their own steps on
each machine (the ray is local). swim_stroke (3 takes) replaces the pitched-up
splash for swimming strokes.

## One-shots

In-game loudness = file LU + typical call volume. Before -> now.

| Sound | Made | Played from (main) | Before | Problem | Now |
|---|---|---|---|---|---|
| hit | gen | every melee/shot impact on a body (enemies, player hurt, dummies) | 1 take, -18.9 LU, 89% sub-200 | one sample, quieter than the swing | 4 takes, -14.5 LU, punch + skin/cloth slap + crack, driven |
| whoosh | gen | light attacks, dodges, techniques (~40 calls) | 1 take, -13.2 LU, 47% above 2 kHz | louder than hits, hissy | 3 takes, -17 LU, swept band-pass peaking early, rolled off at 3.8 kHz |
| whoosh_big | gen | heavies, techniques, bosses (~40 calls) | 1 take, -13.4 LU | as above | 3 takes, -15 LU, lower sweep |
| thud | gen | slams, falls, bodies | 1 take, 100% sub-200 | inaudible on small speakers | 3 takes, -15 LU, mid knock on top |
| block | gen | blocking | 1 take, -24.5 LU, 33 dB ring at 420 Hz | far too quiet, ringy | 3 takes, -16.6 LU, damped clank + grit |
| parry | gen | parries, plunge/iai accents | 1 take, -20.6 LU, aliased 12.9 kHz partial | quiet, aliasing | 2 takes (1450/1330 Hz), -17 LU, no partial past 8 kHz |
| gunshot | gen | pistols, rifles, grunts | 1 take, 96% sub-200, centroid 97 Hz | a muffled boom, no crack | 3 takes, -15 LU, crack + bark + boom + slap-back |
| cannon | gen | broadsides | 1 take, 98% sub-200 | no mid body | 2 takes, -13.4 LU, mid crump added |
| cannon_hit | gen | ball impacts | 1 take | | 2 takes, -14.4 LU |
| wood_crack | gen | hull hits, patching | 1 take | | 2 takes, -16.4 LU |
| splash | gen | water entry, swimming, wading | 1 take, 54% above 2 kHz | hissy, used for strokes too | 3 takes, -17.3 LU, darker; strokes have their own sound |
| land | gen | landings, grunt drops, skids | 1 take, 95% sub-200 | | 3 takes, -17.3 LU, with a scuff; plus the surface step |
| step | gen | footsteps | see above | | replaced by step_<surface> |
| peril | gen | unblockable warning | square wave, 16% at 2-5k | buzzy | band-limited brassy sting, -16 LU |
| blip, blip_high, blip_low | gen | dialogue voice (UI), cue blips (FX) | squares | aliasing buzz | band-limited odd harmonics, -18 LU |
| select | gen | menus (title, save slots, game menu, creator) | 660 Hz square | harsh, the same for move/confirm/back | soft wooden tock with a fifth, -18 LU |
| jump | gen | jumps, climbs | ok | sub-heavy | unchanged |
| coin | gen | gold, skill buy, shop | ok (square-ish pings) | slightly buzzy | unchanged |
| chitter, bug_hiss | gen | scuttlebugs, spitters, queen | ok; chitter uses square clicks | | unchanged |
| fire_burst, fire_blast | gen | fire skills, burnables | ok | | unchanged |
| crunch, howl, haki, roar, horn, bell, rope, splash_big, gull | gen | various | ok (howl -10.3 and gull -10.6 LU are the loudest files) | | unchanged |
| thunder, thunder_far | gen | Weather lightning (2D, delayed by distance) | 97% sub-200 | close strikes could use more crack | unchanged |
| discover_chime | gen | HUD discoveries (UI) | ok | | unchanged |
| music_victory | music gen | boss beaten | ok | | unchanged |

## Weapon impacts (v1.13)

A blow's sound comes from what struck: `HitData.impact` ("" a plain hit, "slice", "slice_heavy",
"chop", "punch", "punch_heavy", "shot"). `Player.melee_hit` sets it from the style (`Player.IMPACT`:
blades and claws slice, the axe chops, fists punch, pistols shoot), a "heavy" or "finisher" blow takes
the heavy take, and every attack, technique and ultimate built on melee_hit gets it for free. Gunfire
from a blade style (the corsair's pistol, grapeshot, Bullet Storm, the hang shot) sets "shot"; the
pistol butt and the meteor kick set punch. Grunts: cutlass blows slice, the shoulder rush and the rifle
butt punch, their shots "shot"; the ape's swipe punches. It rides `Net.hit_pack` (index 15), so a
guest's blow routed to the host sounds the same, and the host's `Net.fx` plays one name on every screen.
`CombatManager.impact(hit, ...)` plays it where a body takes the hit (grunts and the boss, scuttlebugs,
beasts, creatures, the brood queen, the captain; the dummy locally): a blow that floors them
(knockdown/crumple) also goes heavy. `CombatManager.guard(hit, steel_guard, ...)`: a steel blow
(slice, chop, shot) on a steel guard clashes, anything else on a guard is "block" (the captain's
block and parry, a grunt's guard and its read of a repeated heavy). A parry plays the clash with the
old "parry" ting quieter on top; a shot cut out of the air clashes high.

| Sound | Takes | LU | Design |
|---|---|---|---|
| slice | 3 | -15.4 | the edge's 'shk' sweeping 2.6-3 kHz down to ~1.1 kHz, a fluttering tear of cloth, a light body knock; 19-27% at 2-5k |
| slice_heavy | 3 | -14.3 | a longer draw through, a deeper knock, a wet chunk 35 ms later |
| chop | 3 | -14.3 | a thunk from 185 Hz down, a mid knock, a crunch of grains, a short cleave; 17-20% at 2-5k |
| punch | 3 | -15.5 | a 115-140 Hz punch, the knuckles' snap, a slap of skin |
| punch_heavy | 3 | -14.5 | deeper (85-100 Hz), a whump of cloth and air |
| shot_hit | 3 | -16.6 | a dull close thwack and a short 200 Hz thump, a puff of cloth; no crack (the gun has it) |
| clash | 3 | -15.5 | a hard strike, close inharmonic partials (1.0-1.3 kHz x1.47, 2.09, 2.76, 3.9) ringing ~0.4 s, the blades' weight under it, a grate of edges |

## UI sound set (v1.13)

`UIStyle.sfx(name)`; `UIStyle.button()` (and `button_sounds(b)` for any other button) ticks "move" on
hover or focus and plays "confirm" on press ("back" for Back / Cancel / Close / Leave / Resume / Not yet /
No), unless what the button does plays a sound of its own that frame (buy, equip, deny, close...). A
"move" within 150 ms of another sound is dropped (a screen focusing its first button as it opens).
Steppers tock "select". GameMenu: "open" from the game, "close", "back" on Esc out of options.

| Sound | LU | Played | Design |
|---|---|---|---|
| ui_move | -22.2 | hover, focus, dialogue choice moves | a 1.5 kHz tick with a wooden knock, 50 ms |
| ui_confirm | -18.2 | button press, a dialogue choice | two tocks up a fifth (880, 1320) |
| ui_back | -19.7 | Back / Cancel buttons, Esc out of options | two tocks down a fourth, softer |
| ui_deny | -18.2 | can't afford, bag full, can't equip, can't learn / rank / slot a skill | two dull bonks a semitone apart (330, 311) |
| ui_open / ui_close | -19.2 / -20.2 | inventory, skill map, chart, pause, shops, yard; what's new | a page's breath and plucks up (D-A) / down |
| equip / unequip | -18.3 / -19.7 | weapons, gear, hot-bar slots, skills on the bar, taking loot / dropping | leather and a buckle's click / a slide and a thup |
| ui_buy / ui_sell | -18.2 / -18.2 | shop | four coins into a purse / seven onto a counter |
| coin | -18.4 | learning or ranking a skill (now on UI, was a positional sfx) | unchanged |
| level_up | -16.2 | levelling (was coin at 0.75, on SFX for everyone) | a bell arpeggio D-F#-A-D over a low D |
| quest_accept | -19.2 | a new story objective, a villager's task taken | a quill's scratch and two bells (A, D) |
| quest_done | -17.2 | a story step done, a villager paid, the story finished | three bells home (A, D, F#) over a low D |

## Music

v1.12 (2026-10-14) replaced the title, island and sea shanties with 2-3 minute
pieces in real forms, added the village theme and night arrangements, and levels
each calm track to -18.0 LU in the generator (`target_lu`).

| Track | Length | Key, tempo | LU | Notes |
|---|---|---|---|---|
| music_title | 140.0 s (56 bars) | D major, 4/4 96 | -18.0 | the game's theme: intro call, A horns, A' strings, B oboe, B' choir, C bridge on Bb-C-D with the gallop, A'' tutti, turn |
| music_sea | 139.1 s (80 bars) | E minor / G major, 6/8 dq 69 | -18.0 | Waters' tunes on Corsair's band (Zach's pick), the theme in G, a becalmed oboe bridge; strings swelling a bar at a time, wind |
| music_sea_night | 139.1 s (80 bars) | same | -18.0 | same form: dark harp, low flute and oboe, the theme on a far horn, celesta, no gallop or drums |
| music_island | 153.6 s (64 bars) | D dorian / F, 4/4 100 | -18.0 | the wilds: ocarina and steel pan, marimba, walking upright bass, bongos, claves; the theme in D minor on a horn; a call-and-answer breakdown with bassoon |
| music_island_night | 153.6 s (64 bars) | same | -18.0 | same form: low flute, lone ocarina, dark harp, celesta, bass on one and three, no hand drums |
| music_village | 141.8 s (52 bars) | A dorian / C, 4/4 88 | -18.0 | the harbour town: Harbour's tunes (Zach's pick) on oboe, strings, accordion; a market dance in C; the theme warm in C |
| music_village_night | 141.8 s (52 bars) | same | -18.0 | same form, harbour_calm's sound: low strings, dark harp, a tavern guitar, soft accordion |
| music_desert | 160.0 s (48 bars) | G Hijaz over a G-D drone / C minor, 4/4 72 | -18.0 | 10-15, not wired yet: the desert's wilds. A caravan tune on the ney, the oud answering, the mizmar, the dunes in C minor on strings, the theme in Hijaz on the oud; darbuka maqsum, finger cymbals |
| music_desert_night | 160.0 s (48 bars) | same | -18.0 | same form: the drone and strings, a lone ney, slow oud, celesta, one dum a bar |
| music_desert_town | 137.1 s (64 bars) | C Hijaz / F minor, 4/4 112 | -18.0 | the souk and the royal city: a market dance on the mizmar, the city in F minor with a brass fanfare for the palace, the theme on the oud, a quick dance with zills |
| music_desert_town_night | 137.1 s (64 bars) | same | -18.0 | same form: oud picking, strings, ney, horns for the brass, celesta |
| music_snow | 152.7 s (56 bars) | Eb major / C minor, 3/4 66 | -18.0 | the snowfields: a glockenspiel tune over harp and choir, the pines in C minor on a far horn, the theme re-barred in 3/4 |
| music_snow_night | 152.7 s (56 bars) | same | -18.0 | same form, a hush: the celesta alone, soft strings and choir, a far horn, no drums |
| music_forest | 140.0 s (56 bars) | A dorian / C major, 6/8 72 | -18.0 | NOT IN THE GAME YET (see the night row): the autumn woods, a tin whistle's air over harp and guitar, the clearings' song in C on the oboe, the theme in A minor in 6/8, the bodhran |
| music_forest_night | 140.0 s (56 bars) | same | -18.0 | NOT IN THE GAME YET (rendered as .wav, no ffmpeg on this PC: rerun `py tools/texture_gen/gen_psx_music.py forest forest_night` with ffmpeg, add the Music.TRACKS lines, set the forest style's music): same form, the whistle alone far off, dark harp, celesta stars, no drums |
| music_snow_town | 147.7 s (64 bars) | Bb major / G minor, 4/4 104 | -18.0 | the round-house village: a fiddle reel, accordion, a fireside song on the concertina, the theme warm in Bb; bodhran, sleigh bells |
| music_snow_town_night | 147.7 s (64 bars) | same | -18.0 | same form: the inn by the fire, guitar, soft concertina, quiet fiddle |
| music_combat | 54.9 s (32 bars, 140 bpm, E minor) | | -18.3 | unchanged |
| music_boss | 51.2 s (32 bars, 150 bpm, E phrygian) | | -18.2 | unchanged; 10% at 2-5k (hats, brass): brightest track, fine |
| music_victory | 5.4 s sting | | -13.9 | unchanged |

All loops seamless (circular render; seams 0.4-3x a typical sample step on the decoded
.ogg, no clicks). Highs capped by the 8 kHz master low-pass and the 22.05 kHz rate.
The seven new files are 5.2 MB together (about 0.75 MB each, Vorbis q3 mono).

The player (scripts/game/music.gd): contexts title, village (Music.in_village:
Brinehollow's square and harbour front, a chain island's plaza, hamlets and buildings),
island (the wilds; a chain island's KitStyle "music"), sea, combat, boss. From DUSK
(19:00) to DAWN (5:30) a calm track plays its `_night` arrangement, crossfading over
6 s at the same position. Calm changes wait for the playing track's next bar line and
come in on a bar of the new one; fights cut in at once; leaving the title cuts at once.
A calm context left less than two minutes ago resumes at the bar it was in.
The Music bus has a sidechain compressor keyed from SFX (threshold -12 dB, 2.5:1,
8 ms / 450 ms): it dips a few dB under cannons, roars and big hits.

## Gaps (not done this pass)

- Snow and ice footsteps: made 10-15 (step_snow / step_ice, 4 takes each, -21 / -19.5 LU), not wired yet (the snow
  island agent adds them to FX.SOUNDS and Footsteps). Still open: mud, shallow-reef rock vs sand underwater.
- Enemy footsteps (grunts emit Humanoid's footstep signal; nobody plays it).
  Cheap to add from pirate_grunt, but it's another agent's code and many grunts
  means many sounds: worth a distance cap.
- Cloth and gear foley (coat rustle on turns, weapon draw/sheathe, armour clink).
- Weapon-specific impacts: done in v1.13 (below).
- Menus: done in v1.13 (below).
- Monsters' impacts: claws, teeth, slams and blasts still play the plain "hit" (HitData.impact "").
  A claw rake and a bite would be the next set.
- Underwater: done 10-14 (low-pass on SFX/Ambience and an underwater bed).
- Reverb zones: caves, the cabin, the fort's halls play dry.
- Interior ambience (tavern murmur, the cabin's creak), jungle birds/insects on
  chain islands, night insects, rain on canvas/deck under shelter.
- Distance cues: cannon fire from far ships uses the same file at a distance;
  a far "boom" without the crack would sound right past 60 m (FX.sfx skips it).

## Proposals for Zach (need a decision)

1. **Turn the picked samples into the game's tracks**: done in v1.12 for the sea
   (corsair_waters) and the town (harbour, harbour_calm at night). Still open: a
   corsair-style combat track and storm as the boss track.
2. **Longer musical forms**: done in v1.12 for title, sea, island and village (2:19-2:34).
3. **Layered combat music**: render each track's stems (drums, strings, brass)
   and bring layers in by intensity: exploration -> enemies near -> fighting ->
   boss, all in sync. Cleaner transitions than crossfading tracks.
4. **Day and night variants**: done in v1.12 (sea, island, village).
5. **Ducking**: done in v1.12 (sidechain compressor on Music keyed from SFX); tune
   its threshold by ear if it pumps in long fights.
6. **Island identity**: a short motif per chain-island biome (jungle drums,
   ruins choir) layered over the island theme.
7. **Weapon-specific impact sets** and **UI sound set**: done in v1.13 (above).
