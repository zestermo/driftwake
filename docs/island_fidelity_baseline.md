# Island fidelity baseline (phase 0)

Where generated islands stand against Brinehollow today (2026-10-09), measured, so phase 1-3 of
`docs/island_fidelity_plan.md` have a target and a gate. Tools:

- `tools/dev/fidelity.gd` (headless): the metrics, Brinehollow vs any chain seeds/nodes, table + per-district
  tables to `tools/dev/out/fidelity/fidelity.md` and `.json`.
  `& $env:GODOT --headless --path . --script res://tools/dev/fidelity.gd -- 777,31337,4242`
- `tools/dev/fidelityshot.gd` (GPU): the matched-camera sheet, Brinehollow left, a generated island right.
  `& $env:GODOT --path . --script res://tools/dev/fidelityshot.gd -- res://tools/dev/out/fidelity/shots/s777 777`
- `tools/dev/fidelitytest.gd` (suite): the same metrics on Brinehollow + seeds 777, 31337, 4242; prints the lowest
  ratio per gated metric and passes regardless. Phase 3 turns it into the >= 0.8 gate.

Render sheets (today's): `tools/dev/out/fidelity/shots/s777_sheet.png`, `s31337_sheet.png`, `s4242_sheet.png`
(frames beside them as `s<seed>_<recipe>_b.png` / `_g.png`). Out dir is gitignored: rerun the command above to get them.

## How it measures

Brinehollow is measured where it stands in the world; a second copy is built 9 km off and freed to time it
(warm caches). Each generated island is built by hand with `GenIsland.build` (all on the main thread, the
prepare part included, so the "all" time is the single-thread total), measured and freed. Only the island's own
subtree counts: Redtide Rock, the ship, the sea and the sky are not in any number.

**Finding things.** Props, buildings and landmarks are known by node name (`Barrel`, `House`, `Stall_fish`...).
A second copy added under the same parent loses its name (`@StaticBody3D@123`), so every named thing's meshes are
fingerprinted (texture + tint + vertex count per surface, then looser keys) and unnamed ones are matched to them; an
unnamed body with a door texture is a house. Today 2 of Brinehollow's planters stay unmatched (listed under
"Unclassified" in the report); everything else is classified.

**Settled land**: 2 m cells within **15 m of a building's footprint edge** (footprint = the mesh bounds' larger
half-side), plus **3 m either side of any path stretch that passes within 30 m of a building** (the streets), plus
the pier; area counts only cells on land (the quay counts). 15 m was picked because it covers a house's yard, the
lane in front and the next house's yard without reaching into the forest; Brinehollow's village and waterfront
merge into one area at that distance and the outlying keeper's hut and den shacks stay small pockets.

**Districts** (settled cells only): harbour = within 30 m of the waterfront line (Brinehollow's quay, a generated
island's pier) or nearer it than the village and within 60 m; village = within 60 m of the village's middle;
outskirts = the rest of the settled land; wilds = everything else.

| Metric | Definition |
|---|---|
| Buildings | houses (any `Buildings.house`), the inn/tavern, smithy, harbour booth, chapel, market stalls |
| Dressed share | buildings with 3+ props within 5 m of their footprint; a house's own built-in clutter (rain barrel, woodpile, awning basket, read off its textures) counts |
| Interiors | places you walk into: Brinehollow's tavern and brood cave |
| Props per settled ha | props (crates, barrels, rope, nets, timber, wares, carts, benches, tables, logs, wells, fences, lantern posts, campfires, boats, signs, notice boards, planters, gardens, bunting, washing, flags, racks, crane, dummies, tents, chests, burrows) standing in settled land / its area. A merged dressing mesh (the market's wares, a run of bunting) counts as one |
| Street props per 50 m | props within 4 m of a street's edge per 50 m of street |
| Prop categories | distinct categories among settled props (cargo, carts, furniture, fences, lights, boats, signs, gardens, textiles, work, camp, chests, wild) |
| Landmarks | lighthouse, harbour tower, chapel, crane, lookout towers, ruins, standing stone, cave, well, beast's ground; the same kind within 30 m is one |
| Places (POIs) | Brinehollow: village, market, training yard, lighthouse, ruins, cove camp, smugglers' camp, pirate den, brood cave, jungle stash. Generated: village, camp, lair, ruins, summit, beast's ground |
| Walks | shortest walk along the paths (cutting across within 20 m of another path point at x1.2; a place joins paths within 40 m at x1.2) from the dock to each place, and from each place to its nearest other place |
| NPCs | NPC nodes; "talk" = a dialogue tree, a shop or barks; "routes" = they walk waypoints |
| Night | NightLights; real lights (any Light3D) in settled land per ha; lit windows = window-textured emissive triangles / 10 (one window box) |
| Paths | total path length; paved share = path length over cobble triangles (paving, quay, harbour pier); street length per settled ha |
| Ground | vegetation meshes (distinct MultiMesh meshes) and instances per land hectare |
| Cost | surfaces and instanced triangles of the static world (characters apart), MultiMesh instances, nodes; draw calls estimated from a plaza view (14 m out from the village's middle toward the dock, 3 m up) and a harbour view (on the pier looking in): every visible surface whose bounds are in a 70 deg 16:9 frustum (far 1200 m) and its visibility range, plus shadow casters within the sun's 120 m; geometry memory (each mesh once, 32 B a vertex) and the build's static memory; build time (all, and main thread: a generated island's finish steps, all of Brinehollow, which builds during the loading screen) |

Gated metrics (marked * below) are what phase 3 holds at >= 0.8 of Brinehollow; the rest are context.

## Today's numbers

Each generated island is its chain's first island (node 0). Ratio = generated / Brinehollow.

| Metric | Brinehollow | Verdant Island (777) | ratio | Tambor Rock (31337) | ratio | Mosswater Key (4242) | ratio |
|---|---:|---:|---:|---:|---:|---:|---:|
| Buildings * | 31 | 10 | 0.32 | 9 | 0.29 | 9 | 0.29 |
| Buildings dressed, share * | 0.23 | 0.10 | 0.44 | 0.11 | 0.49 | 0.11 | 0.49 |
| Interiors * | 2 | 0 | 0.00 | 0 | 0.00 | 0 | 0.00 |
| Settled land (ha) | 1.63 | 0.63 | 0.39 | 0.61 | 0.37 | 0.62 | 0.38 |
| Props in settled land | 93 | 21 | 0.23 | 21 | 0.23 | 21 | 0.23 |
| Props per settled ha * | 56.9 | 33.4 | 0.59 | 34.3 | 0.60 | 33.8 | 0.59 |
| Street props per 50 m * | 2.53 | 1.60 | 0.63 | 1.93 | 0.77 | 1.71 | 0.68 |
| Prop categories in settled land * | 11 | 8 | 0.73 | 8 | 0.73 | 8 | 0.73 |
| Distinct landmarks * | 9 | 4 | 0.44 | 4 | 0.44 | 4 | 0.44 |
| Places (POIs) * | 10 | 6 | 0.60 | 6 | 0.60 | 6 | 0.60 |
| Walk dock -> place, mean (m) | 199 | 441 | 2.21 | 254 | 1.27 | 265 | 1.33 |
| Walk place -> nearest place, mean (m) | 74 | 311 | 4.18 | 168 | 2.25 | 142 | 1.91 |
| NPCs * | 19 | 6 | 0.32 | 6 | 0.32 | 6 | 0.32 |
| NPCs who talk * | 19 | 6 | 0.32 | 6 | 0.32 | 6 | 0.32 |
| NPCs with a dialogue tree | 8 | 1 | 0.13 | 1 | 0.13 | 1 | 0.13 |
| NPCs walking a route * | 4 | 0 | 0.00 | 0 | 0.00 | 0 | 0.00 |
| NPCs per settled ha | 11.6 | 9.5 | 0.82 | 9.8 | 0.84 | 9.7 | 0.83 |
| Hostiles | 32 | 19 | 0.59 | 19 | 0.59 | 19 | 0.59 |
| NightLights | 11 | 3 | 0.27 | 3 | 0.27 | 3 | 0.27 |
| Real lights in settled land per ha * | 9.8 | 8.0 | 0.81 | 8.2 | 0.83 | 8.0 | 0.82 |
| Lit windows | 180 | 42 | 0.23 | 37 | 0.21 | 37 | 0.21 |
| Lit windows per settled ha * | 110 | 67 | 0.61 | 60 | 0.55 | 60 | 0.54 |
| Other glowing surfaces | 66 | 19 | 0.29 | 18 | 0.27 | 18 | 0.27 |
| Path length (m) | 554 | 1979 | 3.58 | 1073 | 1.94 | 1275 | 2.30 |
| Path length paved, share * | 0.09 | 0 | 0.00 | 0 | 0.00 | 0 | 0.00 |
| Street length per settled ha (m) | 206 | 545 | 2.65 | 549 | 2.66 | 564 | 2.74 |
| Vegetation meshes * | 14 | 15 | 1.07 | 15 | 1.07 | 15 | 1.07 |
| Vegetation per land ha * | 599 | 1004 | 1.68 | 932 | 1.56 | 902 | 1.51 |
| Land (ha) | 8.8 | 39.9 | 4.55 | 20.3 | 2.31 | 22.8 | 2.60 |
| Surfaces, static | 1465 | 1980 | 1.35 | 1265 | 0.86 | 1352 | 0.92 |
| Triangles, static (k) | 328 | 1621 | 4.95 | 796 | 2.43 | 867 | 2.65 |
| MultiMesh instances | 5249 | 40063 | 7.63 | 18904 | 3.60 | 20541 | 3.91 |
| Draw calls, plaza view (est.) | 1489 | 1572 | 1.06 | 1026 | 0.69 | 1146 | 0.77 |
| Draw calls, harbour view (est.) | 2172 | 1659 | 0.76 | 1142 | 0.53 | 1214 | 0.56 |
| Shadow-pass draws near the plaza (est.) | 1678 | 240 | 0.14 | 289 | 0.17 | 258 | 0.15 |
| Character surfaces | 1236 | 161 | 0.13 | 152 | 0.12 | 160 | 0.13 |
| Nodes | 4351 | 8402 | 1.93 | 4408 | 1.01 | 4837 | 1.11 |
| Geometry memory, est. (MB) | 28.7 | 13.3 | 0.46 | 9.2 | 0.32 | 9.8 | 0.34 |
| Static memory of the build (MB) | 55.7 | 72.7 | 1.30 | 46.1 | 0.83 | 46.8 | 0.84 |
| Build, all (ms) | 6633 | 5573 | 0.84 | 3258 | 0.49 | 3496 | 0.53 |
| Build, main thread (ms) | 6633 | 512 | 0.08 | 312 | 0.05 | 356 | 0.05 |

The three seeds are nearly identical in everything placed (the content is a fixed recipe; only the land, the
village's distance from the dock and the hut count vary), so three seeds is enough for the report.

### By district

| | Area (ha) | Buildings | Dressed | Props | Props/ha | Street (m) | Street props | Lights | Windows | NPCs | What the props are |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| **Brinehollow** harbour | 0.48 | 13 | 3 | 33 | 69 | 28 | 2 | 3 | 94 | 6 | cargo 21, boats 4, furniture 3, lights 3, work 2 |
| **Brinehollow** village | 0.74 | 13 | 2 | 35 | 47 | 233 | 14 | 10 | 61 | 10 | furniture 11, fences 7, lights 7, gardens 4, cargo 3, signs 2, carts 1 |
| **Brinehollow** outskirts | 0.42 | 5 | 2 | 25 | 60 | 74 | 0 | 3 | 25 | 1 | cargo 13, lights 4, furniture 2, work 2, chests 2, boats 1, textiles 1 |
| **Brinehollow** wilds | - | - | - | 83 | - | - | - | 6 | - | 2 | cargo 20, fences 15, wild 15, boats 6, textiles 5, work 5, chests 5, furniture 4, lights 4, camp 4 |
| **Generated** harbour (pier) | 0.02 | 0 | 0 | 1 | - | 0 | 0 | 0 | 0 | 0 | the pier's lantern |
| **Generated** village | 0.47 | 8-9 | 0 | 4 | 8.5 | ~315 | 3-4 | 4 | 32-37 | 6 | lights 3 (fire pit, 2 lamps), the job board |
| **Generated** outskirts (= the camp) | 0.12 | 1 | 1 | 16 | 130 | 22 | 8-9 | 1 | 5 | 0 | cargo 5, camp 3, lights 3, furniture 2, work 1, textiles 1, chests 1 |
| **Generated** wilds | - | - | - | 12 | - | - | - | 0 | - | 0 | burrows 9, chests 3 |

Brinehollow's "Props in settled land" counts the market's wares, every run of bunting and each washing line as
one prop each, and its houses' window boxes and flowers not at all, so its lead is understated.

## The ranked gap list

From the numbers and the sheets (worst first). "Generated" = all three seeds; they don't differ.

1. **No harbour at all.** Brinehollow's harbour district is 0.48 ha with 13 buildings, 33 props (21 cargo: crate
   stacks, barrels, rope coils, nets, timber, floats), 3 lamps, 94 lit windows, 6 people, a stone quay with
   bollards and ladders, three side piers with moored ships, longboats, the harbour tower, a crane, the booth and
   Tackett's boat on the stocks. A generated island has a bare 4 m plank pier with one lantern ending on a beach
   and the forest (sheet row 2: the pier walks straight into the trees). Settled harbour area 0.02 ha, ratio ~0.
2. **The village is a ring of huts with nothing between them.** 4 props in 0.47 ha (8.5/ha) against
   Brinehollow's village at 47/ha and harbour at 69/ha: the fire pit, two lamps and the job board. No benches, no
   tables, no planters, no well, no fences, no carts, no washing, no bunting, no notice board apart from the job
   board, no paving (sheet rows 3-5: a dirt disc with huts round the edge). Stilt huts get none of
   `Buildings.house`'s own clutter (it skips stilts), so 0 of 8-9 village buildings are dressed against 2/13 in
   Brinehollow's village and 3/13 on its harbour.
3. **No streets.** The huts ring one plaza at 16-21 m; nothing lines a lane, so the "street" recipe lands back on
   the plaza (sheet row 4). Brinehollow's lanes (the dock road between the waterfront rows, the plaza edge, the
   market) carry ~3 props per 50 m in the village (14 along 233 m: lamps on the main road, benches, the signpost,
   fences, the notice board, a cart), and the harbour district, whose quay isn't a path, carries 21 cargo props of
   its own. The generated paths are long dirt trails (1.1-2.0 km against 0.55 km) with 1.6-1.9 props per 50 m where
   they pass a building and none anywhere else.
4. **People: 6 against 19, nobody walks a route, one dialogue tree.** Brinehollow has 8 NPCs with full dialogue
   (Odile, Tackett, Gus, Pell, Vey, Nessa, Ambrose, Wren), 3 shopkeepers with barks, 3 seated tavern patrons, a
   smith at his anvil, 4 walking routes (Tilly round the plaza, Bram dock-to-village, two dockhands on the quay),
   barks that change with the story. A generated village has the elder (tree), innkeeper, two stall keepers and
   two "Villager"s standing in the plaza with two barks each.
5. **Buildings: 9-10 against 31, all one kind.** 6-7 stilt huts, an inn that is just a bigger hut (no interior:
   resting is an Interactable on its porch), two stalls, the camp shack. No workshop (smithy, booth), no civic
   building (chapel), no warehouse, no two-storey houses, no market of 4 stalls, no waterfront row.
6. **No interiors.** Brinehollow: the tavern (bar, kegs, tables, patrons, fireplace, room light) and the brood
   cave (chamber, dripstone, lichen, a boss). Generated: none. Ratio 0.
7. **Landmarks: 4 against 9, and the one it has is hidden.** The summit lookout is the same tower as the camp's and
   is buried in canopy as high as its platform (sheet row 6: from 40 m off you see a roof among treetops, where
   Brinehollow's lighthouse stands clear on its hill). Missing: anything tall at the harbour (tower, crane), a
   chapel or shrine, a well, a standing stone, a cave mouth.
8. **Night: 3 NightLights against 11, 37-42 lit windows against 180.** Per settled hectare lights are already at
   0.8 (the village is small), but the village at night (sheet row 9) is a fire and two lamps; Brinehollow has 4
   plaza lamps, 3 quay lamps, the pier head, lit doorways (`lamp_light`), the tavern's room light, the lighthouse.
   Windows per settled ha 0.54-0.61: huts are small (4-5 m wide: 2-3 windows) and single storey.
9. **Places further apart and fewer.** 6 places against 10, a mean of 254-441 m from the dock to a place against
   199 m, 142-311 m from a place to the next against 74 m (the islands are 2.3-4.5x Brinehollow's 8.8 ha of land,
   and only 6 things are on them). Brinehollow packs a training yard, cove camp, jungle stash, ruins, lighthouse
   and market within 200 m walks.
10. **No paving or path wear beyond dirt.** Brinehollow paves 9% of its path length (the dock road, the plaza,
    the market) plus the quay and harbour pier; generated islands pave nothing. The splat dirt on paths is the same
    on both.

Not gaps: vegetation variety (15 meshes against 14) and density (1.5-1.7x Brinehollow per land hectare: the
generated cover is thicker); real lights per settled ha (0.81-0.83); NPCs per settled ha (0.82-0.84, because the
settled land is small); the camp, which is a near copy of Brinehollow's smugglers' camp with a lookout tower
(sheet row 7: the generated one reads as busy as the original).

## Performance

| | Brinehollow | Generated (3 seeds) |
|---|---|---|
| Build | 6.6-7.1 s, all on the main thread in one go (warm; it builds during the loading screen) | 3.3-5.9 s in all; 0.31-0.55 s on the main thread over ~26 frames (worst step ~90-100 ms: the 16 ground colliders), the rest (land 1-1.6 s, undergrowth 0.8-1.9 s, bodies 0.6-0.9 s) on a worker |
| Static memory of the build | 56 MB | 46-73 MB (most of it vegetation: 19-40k MultiMesh instances, tree colliders, the ground's 16 trimesh shapes) |
| Geometry, est. | 29 MB (unique house, quay and humanoid meshes) | 9-13 MB |
| Surfaces (static) / triangles | 1,465 / 328k | 1,265-1,980 / 0.8-1.6M (instanced vegetation) |
| Characters | 1,236 surfaces (19 NPCs plus the grunts and bugs standing at the time) | 152-161 |
| Draw calls, plaza view | ~1,490 (684 of them characters) | ~1,030-1,570 (~110 characters; the rest mostly vegetation cells: one MultiMesh per mesh per 70 m square) |
| Draw calls, harbour view | ~2,170 (984 characters) | ~1,140-1,660 |
| Shadow casters near the plaza | ~1,680 | ~240-290 |

Read: a generated island already costs about as many draw calls as Brinehollow from its village, with a quarter of
the settlement, because its vegetation buckets are many and fine. Brinehollow's cost is mostly its people: half its
draw calls in view and most of its shadow casters are humanoids.

**Three islands at Brinehollow density at once** (the one you're on plus the next one or two): a generated island
with Brinehollow's settlement and life would be roughly today's island plus Brinehollow's non-vegetation share: about
+30-40 MB static memory, +~1,200 character surfaces and +~700 static surfaces each, i.e. ~90-110 MB and ~3,000+
surfaces per island, ~300 MB for three. Draw calls only matter for what's in view: the next islands are 1.1-2.6 km
away, inside the camera's 1,200 m far plane on short legs (fog ends at 820 m in clear weather, but fogged surfaces
still draw), and nothing on a generated island has a visibility range except grass, ferns and bushes. So phase 3's
far-LOD (props and NPCs culled or asleep, buildings merged or ranged) is needed before three dense islands stand
together. Build time: Brinehollow's 6.6 s on one thread would be a hard stall; its content has to come in as
finish steps of a few ms each (NPC bodies on the worker, as now). Where Brinehollow's 6.6 s goes isn't split
yet (no per-builder timing without a hook in starter_island.gd): phase 1's kit modules should each report their ms
like GenIsland's `build_ms`.

## For phase 1: Brinehollow's builders, grouped into kit modules

`starter_island.gd` (2,655 lines) by the plan's kit modules. "Deps" is what each would have to take from an island
context instead of Brinehollow's own constants. Shared by almost everything: `place(node, p, yaw, footprint,
y_off)` (puts it on `_ground_max`, appends `[p, footprint + 1.5]` to the linear `exclusions` list), `reserve(p, r)`,
`hv(p)` (quay-aware height), `_ground_max/_ground_min`, `face_yaw`, `_v3`, `_house(spec, p, face, stilts)`, `paths`
/ `_path_dist`, `_marker_point/_marker_face/_marker_y` (NPC spots from markers in placed buildings), `_npc(cfg, p,
face, y)`. GenIsland has its own `place(node, parent, p, ...)`, `reserve` (a cell grid), `house()`, `site_node()`,
`strongbox()`: the kit context is the union. Several builders use fixed seeds (7007 port, 2626 village dressing, 51
market, 4242 ruins, 7171 spitters, 97 Grell's look, `_rng` = world_seed + 1337 for vegetation and loot yaws): in
the kit they become the island seed plus a salt.

| Kit module | Builders (starter_island.gd unless noted) | Deps to parameterise |
|---|---|---|
| **Harbour, quay, waterfront** | `_setup_port` (finds the shoreline by scanning `_height_fn` along x, smooths it), `_quay_z`, `_on_platform`, `_port_x_weight`, `_quay_pt`; `_build_dock` (stone pier: shell + trimesh, coping, bollards, fender, ladders, 2 lamps, cargo, DockingArea); `_build_port` (side piers via `Props.dock`, `MooredHull` + `TraderShips` junk/merchant/sloop, longboats, `Buildings.harbor_tower`, `Buildings.dock_crane`); `_build_quay` (paved platform + sea wall shell, coping, bollards, ladders); `_build_waterfront` (two rows of `_house` shoulder to shoulder, awnings on row 0); `_dress_quay` (cargo groups, `_handcart`, 3 lamps + NightLights, 2 quay stalls, the dockhand NPCs); `_build_harbour_front` (Odile's booth `_harbour_booth`, `_boat_on_stocks`, timber, sawhorses, workbench, Pell's corner, net loft, floats); the harbour bits of `_height_fn` (ground under the quay lowered, waterfront levelled to `QUAY_Y`) and `_build_terrain` (packed earth behind the quay) | assumes the coast runs along x with the sea at -z (`dock_dir` (0,-1)) and the quay between z -96 and -200: needs a local frame (origin, along-shore, out-to-sea); `QUAY_Y`, `QUAY_W`, `STREET_W`, `PLAT_D`, `PIER_HW`, `DOCK_LENGTH`, `DOCK_DECK_Y`, `SEAFLOOR`; hard-coded x offsets (piers at -32/30/46, longboats -13/-21, cargo spots, crane 25.5, bollard gaps); `port_x0/x1`; `_height_fn` hook (the height function must know about the quay before heights are generated); `hv` quay-aware; sets `odile_at`, `tackett_at`, `pell_at`, `player_spawn_local`, `dock_shore` |
| **Village houses + dressing passes** | `_build_village` (well, `Buildings.tavern_hall`, outdoor tables/benches/barrels, 6 hand-specced houses, smithy, chapel, warehouse + crates, 2 more houses, main-road lanterns every 5th point of `paths[0]`); `_house`; `_dress_village` (benches round the well, planters, 4 plaza lamps + NightLights, bunting poles and `_bunting`, the notice board, 3 `_laundry` lines at fixed points, `_garden`, a handcart); `_bunting`, `_laundry`, `_garden`, `_notice_board` (static), `_handcart`; `Buildings.house(spec)` itself (window boxes, rain barrel, woodpile, porch bench; skipped on stilts) | `VILLAGE`, fixed offsets for every house and the laundry/garden points; `paths[0]` as "the main road"; `_dress_village` reads `exclusions` directly to clear bunting poles; seed 2626; house specs are Brinehollow's style (plaster, roof tiles, timber) where the theme wants thatch and stilts |
| **Market** | `_build_market` (4 `Buildings.stall` kinds in a horseshoe, a planter, the merged `Wares` mesh: rugs, baskets of goods, sacks; crates/barrels round it; reserve 9 m); `Buildings.stall(kind)`, `Buildings.planter` | `MARKET` (= VILLAGE + (13,13)), seed 51, the stall kinds; sets `_stall_a/_fish/_cloth/_pots` for the vendors |
| **Paving** | `_pave_disk`, `_pave_path`, `_pave_quad` (cobbles 5 cm over the ground, skips the quay); path wear is the terrain splat (`_path_weight` in `_build_terrain`; GenIsland's `_terrain_arrays` has its own) | `hv`, `_on_platform`; which disks and paths get paved (plaza r 12.5, market r 7, `paths[0]`) |
| **Landmarks** | `_build_lighthouse` (`Props.lighthouse` on `HILL` + the keeper's hut + barrel/crate); `_build_ruins` (pillar ring, slabs, `Props.driftstone` with its Examine dialogue); the harbour tower, crane (harbour) and chapel (village); `_lookout_tower` (static, already reused by GenIsland) | `HILL`, `RUINS` and their flat zones in `_setup_flat_zones`; seed 4242; the driftstone dialogue id and `driftstone_read` event (`_on_dialogue_event`) |
| **Camps, den, yard** | `_build_beach_camp` + `_build_cove` (Wren's castaway camp: fire + sound, `_tent`, `_log`, rowboat, crate, barrel); `_build_smugglers_camp` (fire, logs, tents, stash, rowboat, rack, lanterns, crew flag, the strongbox, `GruntCamp` posts); `_build_den` (shore search, `Props.dock` pier, `MooredHull` + `HullBuilder` sloop, shacks via `_house` + net shed on stilts, lookout tower, fire, stash, fish rack, nets, rowboat, flag with the jolly, `_strongbox`, the `GruntCamp` with Captain Grell); `_build_training_yard` (fence ring, dummies, rack, bench, barrel); `_tent`, `_log`, `_strongbox`, `_cyl_col`, `_box_col` (static). `IslandContent._camp` is already a near copy of the smugglers' camp | `SMUGGLERS`, `DEN`, `CAMP`, `COVE`, `TRAINING` and their flat zones; `_height_fn` (den shore search); story-facing names and save ids (`SmugglersCamp`, `PirateDen`, `smugglers_strongbox`, `den_strongbox`) must stay for Brinehollow; grunt seeds 11-97 |
| **Cave + interior** | `_build_cave` (a `BroodCave` at `CAVE`, reserve 32 m) and `brood_cave.gd` (self-contained: `_build_rock` polar-grid crag + chamber, `_build_dripstone`, `_build_floor`, `_build_lichen`, `_dress_outside`, `_build_inside`, `_spawn_queen`, the fight in `_process`); `Buildings.tavern_hall` (markers Barkeep, Patron1-3, Door) | BroodCave needs a flat clearing (`CAVE` flat zone 30-44 m) and its parent's position only; its constants (`R_IN`, `R_OUT`...) and the queen/hoard ids (`brood_hoard`) are Brinehollow's boss: a kit cave needs a size, a theme palette and an optional boss; the tavern's interior is the inn interior for every theme |
| **NPCs + life** | `_npc`; `_spawn_npcs` (hand-made looks; dialogue ids odile, tackett, gus, pell, vey, nessa, ambrose, wren; shops marlo, sela, ida; patrons seated at tavern markers; the smith at his marker; Tilly's ring route, Bram's fish route; barks with `before`/`after` story flags); the dockhands in `_dress_quay`; `IslandVillage` (generated: elder, innkeeper, stall keepers, villagers, jobs) | spots from `odile_at`/`tackett_at`/`pell_at` and building markers; `data/dialogue/*` ids; looks are literal dictionaries (a kit wants `CharacterLook` from the theme + seed, as `IslandVillage.looks` does, prebuilt on the worker) |
| **Night lights** | no module of its own: `NightLight.make(color, energy, range)` on the pier head, 3 quay lamps, 4 plaza/market lamps, `lamp_light` houses (Harbor, Warehouse), the tavern's `RoomLight`, campfire `FireLight`s, the lighthouse lamp | a kit helper "lamp post here, lit after dark" with a per-island light budget |
| (enemies, loot, ground) | `_build_scuttlebugs` (`_find_burrow_spot`, `_nearest_path_dir`), `_build_spitters` (`forest_crowns`, `FOREST`, `CAVE`), `_spawn_loot` (chests at constants, the thornbrush stash), `_scatter_vegetation` (`_jungle`, `_add_tree`, `_add_rock`, `_bucket`), the height function and `_build_terrain` | GenIsland already has its own versions; Brinehollow keeps these |

## Caveats

- Fingerprinting identifies props by their meshes; a new builder or a new spec value is picked up only if at least
  one copy keeps its name (the first under each parent always does). Check the report's "Unclassified" line after
  adding props.
- Draw calls are an estimate from the scene tree (headless), not a rendered frame: no culling by occlusion, one
  shadow pass (not cascades), Label3D name tags counted. Use `perfbench` for real frame numbers.
- Brinehollow's build time is a warm rebuild (materials, textures and Props meshes cached); its first build at
  startup is slower. Generated islands are timed single-threaded here; in the game the prepare part runs on a worker.
- Brinehollow is measured on its own; Redtide Rock is a separate island and not counted.
