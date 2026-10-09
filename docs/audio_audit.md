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
| Music | Settings | 0.6 | none | none |

- FX.sfx: AudioStreamPlayer3D on SFX, unit_size 6, max_distance 60 (not made past
  64 m from the camera), inverse-distance falloff, pitch jitter per call (default
  +-8%). Co-op: `Net.fx("sfx", ...)` plays it on every screen. Now picks a take at
  random (AudioStreamRandomizer, never the same twice running) when name_1.wav... exist.
- Ambience (Weather/Ambience): 2D AudioStreamPlayers on Ambience, levels moved at
  24 dB/s toward a target per frame. Weather: rain loop and thunder one-shots
  (2D, Ambience bus). Campfires: AudioStreamPlayer3D loops (unit 4, max 30 m).
- Music: two players crossfading (1.8 s, 0.7 s into fights), a sting player,
  BASE_DB -5, victory ducks the music 14 dB for 5.5 s.
- UI: per-screen AudioStreamPlayers (select, blip, coin, discover_chime) on UI.

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

All ambience loops are now levelled to -20 LU and mixed by TOP_DB.

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

## Music

| Track | Length | Loop | LU | Notes |
|---|---|---|---|---|
| music_title | 57.6 s (24 bars, 100 bpm, D major) | seamless (circular render) | -18.4 | flute/accordion shanty |
| music_island | 42.7 s (16 bars, 90 bpm, G major) | seamless | -18.2 | the shortest: the island minute repeats most |
| music_sea | 52.4 s (32 bars 6/8) | seamless | -18.2 | fiddle shanty, wind bed |
| music_combat | 54.9 s (32 bars, 140 bpm, E minor) | seamless | -18.3 | |
| music_boss | 51.2 s (32 bars, 150 bpm, E phrygian) | seamless | -18.2 | 10% at 2-5k (hats, brass): brightest track, fine |
| music_victory | 5.4 s sting | | -13.9 | |

Seams measured on the decoded .ogg: 0.4-1.6x a typical sample step (no clicks).
Highs are capped by the 8 kHz master low-pass and the 22.05 kHz rate; nothing harsh.
Weak points: the length (a minute or less per loop), and the style: these are the
Stardew-ish shanties Zach wanted to move away from (10-08 notes). Changed now:
the calm tracks (title, island, sea) resume where they were if you return within
two minutes (a fight no longer restarts the island theme); fight tracks start over.

## Gaps (not done this pass)

- Snow footsteps (no snow yet), mud, shallow-reef rock vs sand underwater.
- Enemy footsteps (grunts emit Humanoid's footstep signal; nobody plays it).
  Cheap to add from pirate_grunt, but it's another agent's code and many grunts
  means many sounds: worth a distance cap.
- Cloth and gear foley (coat rustle on turns, weapon draw/sheathe, armour clink).
- Weapon-specific impacts: a sword cut, a blunt bash and a fist all play "hit".
  A blade "slice" and a metal-on-metal "clash" set would read better.
- Menus: one "select" for move, confirm and back; no open/close, deny, equip,
  level-up or quest sounds. Inventory and skill map are silent (skill buy uses coin).
- Underwater: no muffling (a low-pass on SFX/Ambience while diving would sell it).
- Reverb zones: caves, the cabin, the fort's halls play dry.
- Interior ambience (tavern murmur, the cabin's creak), jungle birds/insects on
  chain islands, night insects, rain on canvas/deck under shelter.
- Distance cues: cannon fire from far ships uses the same file at a distance;
  a far "boom" without the crack would sound right past 60 m (FX.sfx skips it).

## Proposals for Zach (need a decision)

1. **Turn the picked samples into the game's tracks**: corsair_waters as the sea
   theme, harbour_calm as the island/town theme (both exist in gen_psx_music.py as
   samples). Possibly a corsair-style combat track and storm as the boss track.
2. **Longer musical forms**: 2-3 minute tracks (A-B-A'-C with an intro and a
   bridge), or two variations per context that alternate, so a minute doesn't repeat.
3. **Layered combat music**: render each track's stems (drums, strings, brass)
   and bring layers in by intensity: exploration -> enemies near -> fighting ->
   boss, all in sync. Cleaner transitions than crossfading tracks.
4. **Day and night variants** of the island and sea themes (sparser at night).
5. **Ducking**: lower the music a few dB under big SFX (cannons, roars,
   ultimates) with a sidechain compressor on the Music bus keyed from SFX.
6. **Island identity**: a short motif per chain-island biome (jungle drums,
   ruins choir) layered over the island theme.
7. **Weapon-specific impact sets** and **UI sound set** (see gaps): small,
   self-contained, worth doing next.
