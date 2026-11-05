# 1.30.3 clothing plan (an unstable release): slots and layers, a pattern builder, cloth that's one surface

Status: plan only (2026-11-05, talked through with Zach during the 1.30.2 release). **Ships as 1.30.3, an unstable
release** (tools/release/UNSTABLE when tagging), started right after 1.30.2 is pushed (Zach, 2026-11-05). Nothing below is built. Follows
docs/cloth_plan.md (mode A and the net, 1.24 native chains); this replaces its approach for wide cloth (skirts, coat
tails, capes) and leaves hair and beasts' tails on chains.

## Why (what Zach sees)

- **Jitter, "a few bad frames from exploding":** the net corrects the drawn shape in discrete turns (NET_TURN, best of
  four, thresholds that can flip on a float: chains_native_same's 5.7 cm hem flip for 6 frames). On-off corrections read
  as jitter.
- **Slits that open:** `_cloth_sectors` (body_builder.gd) makes each skirt/coat panel 4 vertex columns weighted to one
  chain bone per row: every row of a panel is a rigid plank on its own chain. Neighbouring panels share no vertices and
  no constraint, so they part.
- **Clipping:** a plank can't bend round a thigh; the probes, the net, the slack and the seat gaps are all patches for it.
- **Pieces that don't go together:** two "Accessory" slots take any of 14 on/off flags (cape, cloak, mantle, apron,
  pauldron, bandolier, baldric...). The biggest garments are accessories nothing checks against the coat or each other;
  `pauldron` is one bool, so two pauldron items give one shoulder.
- **Missing parts:** a gap between the collar and the coat, vests with no fabric over the shoulders. Each piece is
  placed near the body on its own, not built on the piece under it.

## Decisions (Zach, 2026-11-05)

1. **Feel: the hybrid.** Heavy and grounded by default (swings a little late, settles fast, still when standing);
   flair later, only if needed (Zach, 2026-11-05): judge the heavy feel in the moves first; a whip impulse on
   abilities and sprint stops is added near the end only where the plain sim doesn't already look good.
2. **Both shape and motion get fixed**, and the slots get real rules (below).
3. **Hide what nobody can see:** cut the body's triangles under a piece that fully covers them; armour plates
   (tassets, pauldrons) hinge rigidly on the body, not simulated as cloth.
4. **NPC cloth is cheaper:** captains and bosses get the full solver; townsfolk and grunts a coarse lattice with fewer
   substeps, frozen beyond ~25 m (ActorSleep / LOD).
5. **A pattern format and one builder**, got right once, so every later garment inherits the fit and the cloth.
6. **Try a low-rate held-step look** (cloth stepped at 20-30 Hz and held, matching the PS1 vertex snap) in the lab;
   kept only if it reads as deliberate, not lag.

### Slots

| Slot | Takes | Notes |
|---|---|---|
| Head | hats, helms, hoods | |
| Face | masks, mouth coverings, bandanas (any, neck bandanas too), scarves, eyepatch? | **No neck slot** (Zach): neck wear is Face |
| Torso | shirts, tunics | layer 1 |
| Vest | vests, mail, padded jack | layer 2 |
| Coat | jackets, coats, haori, draped coats | layer 3 |
| Shoulders | **one slot**; three kinds of pauldron item: left, right, both | layer 4, rigid |
| Back | cape, cloak, mantle **or** a backpack | one item: a pack and a cape share the slot (Zach) |
| Strap | bandolier, baldric | across the body, layer 4 |
| Belt | belts, sashes; the apron and pouch hang from it | |
| Hands, Legs, Feet | as today | |
| Trinket x2 | earring, goggles, spyglass, necklace (eyepatch here or Face: decide in piece 1) | **two is enough for now**; small, never conflict |
| Equipment | as today | |

### Layers and the conflict rule

Each piece declares the **body regions** it covers (neck, shoulders, chest, back, waist, hips, thighs, shins...) and its
**layer**: 0 skin, 1 base (shirt, trousers, wraps), 2 mid (vest, sash, skirt), 3 outer (coat, a belt over the coat),
4 over (cape, cloak, mantle, pauldrons, straps). Two pieces can't claim the same region on the same layer: that is the
whole compatibility rule (plus the slot itself), shown on the doll when you try to equip. The same data tells the
builder what a piece is fitted over (below).

## The pattern format

A garment is data, not a hand-written function in body_builder.gd:

- **panels**: outlines in the body's frame (by ring height and angle, like `_sector_row`), each with its rows/columns;
- **seams**: which panel edges are sewn (a skirt's ring closes; a coat's sides sew to its back) and which stay open
  (the coat's back vent, a front opening); trim and collars are **built from an edge loop** of the panel they sit on
  (the collar's base is the coat's neckline, so no gap);
- **layer and regions** (the slot rules above); the piece is fitted outward from the surface of the layers under it,
  on the body's real shape (fem/masc, stout...), so a vest's shoulder fabric and the coat over it come from the same
  surfaces;
- **pins**: which lattice points hold to the body (waist row, shoulders) and how firmly;
- **cloth**: weight, stiffness, bend, damping; or `rigid` (plates, hard collars).

One builder turns a pattern into the mesh, its UVs and colours (PSXMat, tints in vertex colours as now) and the
lattice. The existing looks are converted family by family; the old code paths stay until a family's conversion is
signed off.

## What the cape teaches (Zach, 2026-11-05: today's most polished cloth, not the end goal)

What makes it feel better than skirts and coats (`_cape`, body_builder.gd): one sheet on **one** chain (9 columns, no
panels, so nothing parts); it hangs behind the body and only the legs push it, so the net turns it about one axis; mode
"a" (`use_tuned(back_z, k 0.07, d 0.3, 4 passes, legs)`): **damping 0.3 against the skirt/coat chains' 0.06**, a softer
rest pull, four constraint passes, a back plane, probes across its width. The cloak goes further: three chains with
the sides skinned between the middle and edge chains by distance, an early form of the lattice's blended skinning.

Lessons for the rest: one continuous sheet, enough damping, collisions from one simple direction. The cape still has
room to improve and converts to the lattice with the other capes in piece 4. Its clothlab numbers are a useful
reference point in piece 2, not the target. Before the lattice, a cheap test (piece 0): skirts and coat tails on the
cape's damping and passes, to see how much of their jitter is tuning alone.

## The cloth lattice (ChainSolver, C++)

A new solver mode in native/src/chain_solver for a 2D grid of particles per garment, XPBD:

- **links**: structural (along rows and columns), shear, bend; seams are links too, so sewn edges never part;
- **continuous skinning**: each mesh vertex follows its 2-4 nearest lattice points, blended (no planks);
- **stability**: 4-8 fixed substeps a tick; an **inertia scale** (the cloth feels part of the body's world motion, so a
  180 turn doesn't fling it); **tethers** (a hem never further from its pin than its rest length); a speed cap;
- **collisions** as smooth constraints with friction against the body's capsules and the layer below (a coat rests on
  the skirt), replacing the net's turns for converted garments;
- **flair** (only if piece 6 decides it's needed): `impulse(dir, strength)`;
- **LOD**: full / coarse (fewer columns, 2 substeps) / frozen by distance; sleeps with the body.

The GDScript solver stays as the no-DLL fallback for chains only; without the DLL lattice garments are rigid (skinned
to the hips), as cheap as it gets. Budget: about a captain's spring sets today (~24 us) per captain, a skirt (12x6, 4
substeps) estimated 10-30 us natively; measured in piece 2 before anything moves over.

## Pieces (one at a time; each landed and shown to Zach)

0. **Cape tuning on the skirts and coats** (an hour, lab and in game): mode "a"-like damping and passes on the netted
   cloth chains; kept if it calms them, whatever the lattice later does.
1. **Slots and layers.** Gear.SLOTS / SLOT_KEYS, the region/layer table per piece kind, the conflict rule on equip,
   pauldron_l / pauldron_r / pauldrons (both) as items and in BodyBuilder, the Back slot taking capes/cloaks/mantles/the
   backpack, Strap, neck wear onto Face, the trinkets; the inventory doll (960x540, judged at 1080p); a Settings VERSION
   migration for saves and items (old accessories to their new slots; a second cape or pack goes to the bag);
   sets and weights (1.24 gear stats) follow their pieces; shops' and loot tables' Gear.make calls updated. No cloth or
   shape change. Tests: atomic t/gear/* (each conflict, the pauldron kinds, the migration of an old save).
2. **The lattice in the lab.** ChainSolver's lattice mode and its API; clothlab gains jerk (frame-to-frame change of
   acceleration at the hem), peak speed and frames inside the legs; a hand-made skirt (a closed ring) and one long coat
   (sides sewn, back vent open) side by side with today's, numbers and renders **for Zach's OK** before anything else.
   The held-step look tried here too.
3. **The pattern builder**, with the skirt and the long coat as the first two patterns on it, the body cut under them,
   and the layer-below fitting. Shown in game.
4. **Families, one round each:** coats (with collars and trim from edge loops), vests (shoulder fabric) and tops,
   skirts/hakama/tunic skirts, capes/cloaks/mantles, the sash and apron, then pauldrons and plates as rigid pieces.
   Each round: cliptest and cloth_layers updated, outfit renders before/after, Zach in game.
5. **NPC cloth LOD.**
6. **Flair, if needed (near the end):** play the moves with the heavy cloth; only where they lack drama, a whip
   impulse on those abilities or sprint stops. Skipped if the plain sim already looks good.

## Tests

Per docs/cloth_plan.md (Zach, 2026-10-17) no flaky cloth-physics tests: the lattice is proved with clothlab metrics
and renders and judged in game. Deterministic checks only: slot and migration atomic tests, a synthetic lattice test
(fixed kicks, finite, seams within a millimetre, tethers held), cliptest / t/player/cloth_layers for fits at rest.
The chains_* tests stay for hair and beasts.

## Open

- Eyepatch: Face (conflicts with masks) or a trinket.
- Which garments bother Zach most: the first conversion round goes after those (F12 captures welcome).
- A draped coat (1.29, layer 3) under a cape (layer 4): the rule allows it; check it looks right in piece 4.
