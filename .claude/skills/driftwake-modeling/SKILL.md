---
name: driftwake-modeling
description: >
  Make or improve 3D models in Driftwake, all of which are built in code: props, buildings and
  interiors, ships and ship parts, weapons and items, rocks/trees/vegetation, creatures and
  figureheads, caves and other structures, and dressing a location with them. Covers MeshBuilder
  (boxes, cylinders, roofs, lofts and lathes, extrusions, tubes along curves, cards, blobs),
  PSXMat materials and draw calls, UV/texel density, the procedural textures
  (gen_psx_textures.py), collision, scale against the player, seeded variation, placing models
  on the island, and the modelshot render tool (auto-framed views, contact sheet, triangle and
  surface counts). Use when Zach asks for a new model or prop, "more detail", "looks blocky",
  a new building/ship/weapon design/item/structure, a texture, or a model that looks wrong (holes,
  flicker, shimmer, floating, wrong size).
---

# Driftwake modeling

There are no imported models. Every model is a static builder function that fills a
`MeshBuilder` (`scripts/psx/mesh_builder.gd`) with triangles, one surface per `PSXMat`
material, commits one `ArrayMesh` and adds simple collision. Textures are 64x64 procedural
PNGs. The PS1 look comes from the shaders (vertex snap, dither, 640x360 grid), so a model's
job is a strong silhouette, a believable structure and the right texture at the right scale.

**Read first:** grep `docs/dev_notes.md` for the thing you're touching, then open the
closest existing builder and copy its shape. Bodies, hair and clothes are `BodyBuilder` (its
own world); this skill covers everything else.

## How Zach judges a model

- He walks up to it in game and looks from every side, close and far, by day and by night,
  and sends F12 captures. His notes name what he sees: "the bow is open at the stem",
  "bulwarks invisible from outside", "deck planks shimmer far off", "stairs are stacked
  boxes", "too small to get round the mast", "textures slide", "looks like a flat card".
- What he has asked for, consistently: closed from every angle; real scale for anything
  you walk on, climb or use; detail that tells you what a place is (the village polish:
  "every building dressed"), more variety (no two houses alike); readable PS1 shapes, not
  cartoony; existing places and NPC spots left where they are.
- "Which look?" questions: render the options side by side in one modelshot row (see
  **Tools**) and ask for a pick, like the anim lab but quick. Small asks get a direct fix.

## Where things are

| Thing | Builder | Notes |
|---|---|---|
| Primitives | `MeshBuilder` | all geometry; see the cheat sheet below |
| Materials | `PSXMat` (`scripts/psx/psx_mat.gd`) | cached by (texture, tint, opts) |
| Small props, vegetation meshes | `Props` (`scripts/props/props.gd`) | barrel, crate, lantern_post, dock, lighthouse, rowboat, palm/jungle/pine/bush meshes, rock_mesh, grave, campfire |
| Buildings | `Buildings` (`scripts/props/buildings.gd`) | `house(spec)` (many looks from one spec), `tavern_hall` (interior), `smithy`, `chapel`, `stall(kind)`; helpers `tiled_box`, `beam_between`, `add_hip_roof`, `add_shed_roof`, `dress_window`, `dress_door`, `wall_lantern` |
| Ships | `HullBuilder` (`scripts/ship/hull_builder.gd`) | layout consts + `hull()`, `build(parent, opts)`, `collide()`; shared by our ship and the pirates' |
| Ship looks | `ShipKit` | paint, sails, `flag_image`, `figurehead(kind)` |
| Weapons | `WeaponDesigns` | numbers per design in `DESIGNS` -> `build("<kind>:<design>:<tier>")`; `Props.weapon_mesh` caches by that string; icons drawn from the mesh |
| Creatures | `scripts/enemies/scuttlebug.gd`, `sea_king.gd` | blobs and segments on rigs |
| Big shells | `scripts/island/brood_cave.gd` | noise-displaced inner/outer dome, trimesh collision |
| Placing | `StarterIsland.place()`, `_house()`, `_dress_village`, `_scatter_vegetation` | ground height, footprints, exclusions, MultiMesh cells |
| Textures | `tools/texture_gen/gen_psx_textures.py` | 64x64 tileable, palette-quantized, fixed seeds |
| Worked examples | `tools/dev/model_samples.gd` | anchor, ship's lantern, naval cannon (the recipe below in code) |

## Conventions

- Metres. Origin on the ground. Props and buildings face **+Z** (door, customer side).
  Ships: stern +Z, bow -Z, deck at `HullBuilder.DECK_Y`. Weapons: grip at the origin, blade
  along -Z, knuckles -Y. Characters and creatures face -Z.
- A builder is `static func thing(spec := {}) -> Node3D` returning a `StaticBody3D`
  (`collision_layer = 1`, `collision_mask = 0`) with the mesh as a child, or `-> ArrayMesh`
  for things that are instanced (vegetation, weapons, shared props). Name the nodes.
- NPC spots, doors and anything code needs to find are `Marker3D` children ("Barkeep",
  "Smith", "Vendor", "Door"). Numbers gameplay reads (deck heights, door widths, stair runs)
  are consts at the top, used by the model and the collision alike (HullBuilder does this).
- **Deterministic.** Co-op guests build the world themselves from the same seed, so any
  variation comes from a seeded `RandomNumberGenerator` (a spec "seed", or a hash of the
  spec), never global `randf()`.

## Scale (build against these)

| | |
|---|---|
| Player | capsule r 0.35, 1.8 m tall; the captain stands 1.86 m; walk 6 m/s, sprint 9 |
| Jump | ~1.6 m high; ledges you should not get onto: over 1.7 m |
| Slopes | walkable up to 50 deg; **stairs need a ramp/wedge collider** (no step-up), ~34 deg on the ship |
| Doors | 1.0 x 2.0 (house), ship cabin 1.3 x 2.05; walk-through gaps >= 1.0 m, >= 1.3 m where people fight |
| Heights | rails 0.8-0.9, bulwark (waist) 0.75-0.8, bench seat 0.45, table 0.78, ceiling >= 2.6 (tavern 3.6) |
| Room to move | ~1.3 m clear round anything you walk round (the crow's nest radius went 1.05 -> 1.6 because nobody fit round the mast) |

Put a body next to the model in the render to check: `S.body() | Buildings.smithy()`.

## Materials and draw calls

- `PSXMat.lit(tex, tint, opts)`; `flat(color)` (no texture); `glow(color, energy)`
  (windows, lanterns, coals); `cutout(tex, tint, wind, sway_height)` (foliage cards,
  double sided). Opts: `"emission"`, `"emission_energy"`, `"emission_tex"` (lit windows use
  the window texture as their own glow mask), `"emission_pulse"`, `"vertex_color": false`
  (signs, doors: keep the picture exact), `"affine"`, `"pull"`.
- **Every distinct (texture, tint, opts) is another surface: one more draw call, and
  another in the shadow pass.** Same arguments give the same cached material, so they share
  a surface. Shade with the vertex colour `col` argument instead of a new tint: undersides
  and eaves 0.55-0.8, trims and inner faces 0.8, a little rng shade per plank or stone. Tint
  only for a different colour family (paint, gold, iron vs steel).
- `psx_lit` has no instance uniforms: hit flashes use per-object material copies (`tint_mul`).
- Textures (`assets/textures/psx/`): grass, sand, wet_sand, dirt, rock, seafloor, water,
  planks, planks_dark, planks_weathered, bark, palm_bark, thatch, stone_brick, cobbles,
  plaster, roof_tiles, cloth_red, cloth_blue, canvas, fabric, metal, straw, leather, rope,
  leaves, palm_frond, bush, fern, grass_tuft, thornbrush, driftstone, window, door, signs.
  Grey ones (metal, leather, canvas) are made to be tinted.
- New texture: a `gen_*` in `gen_psx_textures.py` with its own fixed seed, a 4-6 colour
  palette through `ramp()`, `periodic_noise`/`fbm` so it tiles, 64x64; call it from `main()`
  and give it a mode (like `village`) so `py tools/texture_gen/gen_psx_textures.py <mode>`
  makes just it. Copy an existing `.png.import` (mipmaps on, compress_to 0), then
  `& $env:GODOT --headless --import`. Emblems and decals can be painted at runtime into an
  `Image` (`HullBuilder.jolly_material`, `ShipKit.flag_image`).

## UVs and texel density

- `uv_scale` is texture tiles per metre: a 64 px texture at 0.5 = 32 px/m. Walls and decks
  0.5, beams and trims 0.6-1.0, small props 1.0-2.0, weapons 2.0. Neighbouring parts at
  wildly different densities look like different worlds.
- Map by **real size**: planks at board width (`HullBuilder._plank_uv`: 0.25 m boards
  running fore and aft). Planks running across at 12 cm shimmered at distance.
- Big continuous surfaces (hulls, caves, terrain) map UVs from **position**, so the seams
  between parts line up (`_side_uv`, `brood_cave._uv`).
- One-picture things (door, window, sign, crate face) use `add_box_unit_uv` or a card.
- Split big walls into pieces with `Buildings.tiled_box` (<= 2.4-3.2 m): it keeps the texture
  warp small for players who turn that setting on.

## MeshBuilder cheat sheet

Every primitive takes the material, a `Transform3D` (or points), sizes, `uv_scale`, `col`.
Winding is automatic from the normal you give, so **give the outward normal right** and
never think about winding.

| Call | For | Watch out |
|---|---|---|
| `add_box(mat, xf, size, uv, col, skip_bottom=true, skip_top=false)` | almost everything | **skips the bottom face by default**: pass `false` for anything seen from below (overhangs, beams, shelves, treads, anything in the air) |
| `add_box_unit_uv` | doors, windows, signs, crates | whole texture on every face |
| `add_cylinder(mat, xf, r_bot, r_top, h, sides, uv, col, cap_top, cap_bottom, smooth, cap_mat)` | posts, logs, barrels, wheels, masts | grows along local +Y from its base; along X use `Basis(Vector3.BACK, PI/2)` (+Y -> -X), along Z `Basis(Vector3.RIGHT, PI/2)` (+Y -> +Z) |
| `add_cone`, `add_pyramid_roof`, `add_gable_roof` (ridge along local Z), `Buildings.add_hip_roof`, `add_shed_roof` | roofs, spikes | gable and hip roofs draw their eave undersides; the pyramid roof doesn't |
| `add_blob(mat, xf, radii, rng, jitter, rings, segs, uv, col, flatten_bottom)` | rocks, canopies, coals, mounds; `jitter 0` = a low-poly ball | flat shaded |
| `add_loft(mat, xf, rings, profile, ...)` | anything with a changing cross-section: hulls, bodies, bottles, blades | rings `[y, half_w, half_d, z_off, x_off, per-ring profile]`; profiles `profile_oct`, `profile_mirror`, `profile_circle` |
| **lathe** = `add_loft` with `profile_circle(n)` and rings `[y, r, r]` | barrels, bells, pots, lantern glass, cannon barrels, columns, bottles | start and end on r > 0; two rings 1 cm apart for a hard step, or `flat` |
| `add_extrude(mat, xf, outline, depth, uv, col, side_mat)` | **silhouettes boxes can't make**: axe heads, guards, anchors, flukes, shaped signs, gravestones, stepped gun-carriage cheeks, arches without holes | outline in local x/y (concave fine, no holes), extruded along local Z |
| `add_tube(mat, points, r0, r1, sides, uv, col, cap_start, cap_end, flat)` | rope and rigging, chains of curves, branches, vines, roots, tentacles, tails, horns, rails, handles, rings | points from `sag_points(a, b, droop)` (hanging rope) or `curve_points(a, ctrl, b)` (Bezier); a closed ring: repeat the first point at the end |
| `add_card`, `add_cross_cards` | foliage, flags, emblems, distant fakes | one-sided unless the material is cutout |
| `add_strip_grid`, `add_rings`, `add_profile_disc` | cloth sheets, tubes through absolute rings, brims | |
| `Buildings.beam_between(mb, mat, a, b, t, t2)` | a beam/brace/strut from a to b | |
| `merge`, `map_vertices`, `weld_normals`, `commit`, `to_instance` | combine, deform, smooth across parts, finish | |

Other gotchas:
- A single quad is one-sided (cull back). A wall made of one face vanishes from behind:
  add the inner face (the bulwarks' were missing), or use a box.
- Coplanar faces z-fight (flickering stripes): set trims, frames and panels 2-4 cm proud.
- `Basis(a) * Basis(b)` applies `b` first (in `a`'s frame): yaw * tilt tilts, then turns.
- Smooth normals average across a hard edge and round it off; flat shading is the PS1 look
  for anything man-made, smooth for organic and round things.

## Building a detailed model (the recipe)

1. **Scale and gameplay first.** Real dimensions from the table above; consts for every
   spot code or the player uses (doors, stairs, seats, markers, how high a deck is).
2. **Silhouette.** The 3-6 biggest shapes, checked from far off at the game's pixel grid
   (`far` view, `MS_PSX=0`). On PS1, detail lives in the silhouette and the texture, not in
   triangle counts. Break the box: overhangs (eaves 0.4-0.5), jetties, setbacks, a lean-to,
   a chimney, a stepped or curved outline (`add_extrude`), a slight lean or tilt.
3. **Structure that gives scale.** How it's built: corner posts, beams at floor and eaves,
   braces, ridge caps, barge boards, fascias, bands on barrels, rails and stanchions,
   frames round openings. This layer is what made the village read.
4. **Dressing that tells a story.** What the place is for and who uses it: the smithy's
   tools and quench trough, the tavern's swordfish and kegs, flower boxes, a rain barrel, a
   woodpile, a lantern by the door, nets at the dock. Seeded rng for placement and choice.
5. **Variety through a spec, not copies.** One builder, many looks
   (`Buildings.house(spec)`, `WeaponDesigns.DESIGNS`): sizes, roof kind, trim colour,
   options. New looks are new spec values; new shapes are new `match` branches.
6. **Collision follows what you touch, simply.** A box per solid part, a cylinder for
   round ones, one convex for a hull, `mesh.create_trimesh_shape()` only for big irregular
   walk-on shells (the cave). Ramps under stairs. Small dressing gets one box or nothing.
   Colliders never bigger than the mesh where people walk past.
7. **Lights and effects, on a budget.** `NightLight.make(color, energy, range, always)`,
   no shadows; the village has 9 real lights in total. Glow materials are free; real lights
   are not. `FX.chimney_smoke(body, at)` for smoke.
8. **Render, read, fix, then place it and look at it in place** (see **Tools**).

## Budgets (measured with modelshot)

| Model | Tris | Surfaces |
|---|---|---|
| ship's lantern (sample) | 304 | 2 |
| anchor (sample) | 671 | 3 |
| naval cannon (sample) | 976 | 4 |
| war axe | 120 | 4 |
| smithy (whole building, furnished) | 731 | 14 |
| enemy sloop (888 of it rope boxes) | 2066 | 11 |

Triangles are cheap at this scale; **surfaces, nodes and lights cost**. Aim for props under
~1000 tris and ~5 surfaces, buildings under ~3000 tris and ~12 surfaces. Many copies of one
thing: build the mesh once and reuse it (`Props.weapon_mesh` caches by model string), or a
`MultiMesh` in cells with a `visibility_range_end` and no shadows for small scatter (grass
90 m, bushes 160 m: `StarterIsland._scatter_vegetation`). A box rope is 12 tris a segment,
`add_tube` with 4-5 sides 8-10.

## Kinds of model

- **Buildings:** copy `Buildings.house`. A stone footing reaching below the origin (the
  island's `_house()` sets `foundation` from the ground under it so nothing floats on a
  slope). Lit windows with the window texture as their emission mask. Interiors: walls
  0.3 thick, markers for NPCs, `tiled_box` walls, the doorway wide enough to fight in.
- **Ships:** `HullBuilder.RINGS` are the cross-sections `[z, top half-width, bottom
  half-width, top y, bottom y]`; change consts, not literals, and `collide()` together with
  `hull()`. Outside faces run up to the rail, the bow is closed, planks are position-mapped.
  Both our ship and the pirates' use it, so check both (`bigshipshot`, `fleetshot`).
- **Weapons and items:** a design is numbers in `WeaponDesigns.DESIGNS`; a new guard, head
  or pommel is a `match` branch. Tiers recolour fittings, so keep fittings on the `fit`
  material. Boxes stacked into an axe head or a guard are the obvious upgrade: an
  `add_extrude` silhouette. Held things must sit in the hand (`handshot`, `sheathshot`) and
  icons are drawn from the mesh (`weaponshot`).
- **Organic** (rocks, trees, creatures, figureheads): `add_blob` for lumps, `add_loft` for
  bodies and trunks, `add_tube` on `curve_points` for tails, tentacles, horns, branches,
  vines and roots, noise-displaced shells for cliffs and caves (`brood_cave._pt` with
  FastNoiseLite). The figureheads (`ShipKit.figurehead`) are still box-built: a good
  candidate.
- **Vegetation:** returns an `ArrayMesh` for MultiMesh; cutout cards with wind for leaves;
  keep it tiny.
- **Locations:** `place(node, p, yaw, footprint)` puts it on the ground and reserves its
  footprint; dress with paths (`_pave_path`), clutter, lights from the budget; never move an
  existing place or NPC spot without asking.

## Tools

All from PowerShell (`$env:GODOT`, the console build). Renders open a window (GPU). Make the
output folder first (`tools/dev/out/models`).

```powershell
# any builder: auto-framed views + a contact sheet + its numbers ("MS" lines)
& $env:GODOT --path . --script res://tools/dev/modelshot.gd -- res://tools/dev/out/models/smithy 'Buildings.smithy()'
# options side by side for a pick, a body first for scale; views of your choice
& $env:GODOT --path . --script res://tools/dev/modelshot.gd -- res://tools/dev/out/models/houses 'S.body() | Buildings.house({"roof": "hip", "seed": 3}) | Buildings.house({"roof": "gable_front", "porch": 1.6})' 'front3,back3,eye'
# statements ending in return (ships build into a parent)
& $env:GODOT --path . --script res://tools/dev/modelshot.gd -- res://tools/dev/out/models/ship 'var n = Node3D.new(); HullBuilder.build(n, {"emblem": "jolly"}); return n' 'front3,side,top,low'
# a close-up of one part (in the builder's coordinates), at night
$env:MS_FOCUS='0.6,0.9,0.4'; $env:MS_ZOOM='0.3'; $env:MS_HOUR='21'; & $env:GODOT --path . --script res://tools/dev/modelshot.gd -- res://tools/dev/out/models/anvil 'Buildings.smithy()' front3
# weapons: no ground, stacked along y, side on, at the game's 640x360 grid
$env:MS_GROUND='none'; $env:MS_ROW='y'; $env:MS_PSX='0'; & $env:GODOT --path . --script res://tools/dev/modelshot.gd -- res://tools/dev/out/models/axes 'WeaponDesigns.build("axe:war:4") | WeaponDesigns.build("axe:bearded:0")' side
```

- Views: `front`, `front3`, `side`, `back`, `back3`, `top`, `low` (from knee height: holes
  underneath), `far` (silhouette at distance), `eye` (eye height, 6 m from the front face: what
  you see walking up), `wire` (wireframe: density and stray faces), or `yaw:pitch:zoom`.
  Env vars stay set in that shell: `Remove-Item Env:MS_*` afterwards.
- Read the `_sheet.png` first (one image, every view), then single views.
- **Read the MS lines:** surfaces = draw calls; a list with several tints of one texture is
  a merge waiting to happen (use `col`); the top lines are where the triangles went.
- Check every model for: holes from any side (`back3`, `low`, `top`), flicker where parts
  meet, scale against the body, the silhouette at `far` with `MS_PSX=0`, glow at night.
- In place: `islandshot.gd` (island-local cameras, `ISHOT_HOUR=21`), `bigshipshot`,
  `yardshot`, `fleetshot`, `weaponshot`, `handshot`, `sheathshot`, `armorshot`.
  `perfbench.gd` for frame cost when something big or numerous goes in.

## Symptom -> cause

| Zach sees | Cause | Fix |
|---|---|---|
| a face missing from one side | one-sided quad, or the normal given points in | give the outward normal; add the inner face; use a box |
| a hole seen from below | `add_box` skips the bottom by default | `skip_bottom = false` |
| flickering stripes where parts meet | coplanar faces | set the part 2-4 cm proud |
| texture shimmers far off | texels too fine, boards across the view | map by real board size; lower `uv_scale` |
| textures slide on big faces | affine warp on large triangles | `tiled_box` / split big quads |
| blocky, boxy | right-angled boxes everywhere | extrude silhouettes, tubes, lathes, overhangs, a lean |
| flat, all one colour | one tint and no shade | `col` per part (undersides darker), rng shade |
| frame rate drops near it | many materials or lights, many separate nodes | `col` not tints; fewer lights; one mesh; MultiMesh |
| floats or sinks on a slope | nothing reaches below the origin | a footing below ground (`foundation`) |
| can't get up / through / round | scale off; stepped stair collision; collider bigger than the mesh | the scale table; a ramp under stairs; trim colliders |
| looks different for a guest | unseeded randomness | seeded rng |
| hard edge looks soft / blob looks faceted | smooth vs flat normals | `flat` for made things, smooth for organic |

## Finishing

Render with modelshot (sheet + MS lines) and in place (day, and 21:00 if it has lights),
run the suites that touch where it lives (village: `qoltest`, `r7test`, `perftest`; forest
and den: `foresttest`; ships: `riggingtest`, `seatest`, `yardtest`; weapons: `qoltest`,
`katanatest`, `axetest`), tell Zach where to go in game to see it, add a dated
`docs/dev_notes.md` entry for anything substantial, commit. A shape or technique that
worked (or a mistake Zach caught) goes back into this file.
