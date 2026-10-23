# Skinned single-mesh bodies (Zach, 2026-10-23)

## Why
After the 2026-10-22/23 combat perf work the frame is flat: draw submission ~5-6 ms, transforms ~2-2.5 ms, many small
scripts. A body is ~15 draws (chartest: mean 14.8, worst 18) plus as many in the shadow pass, and ~15 rigid meshes on
~25 animated joint nodes. Bodies are the biggest structural cost left wherever there are people (towns, fights, the
capital's crowds).

## Decided (2026-10-23)

| Decision | Choice | Why |
|---|---|---|
| Approach | **Extend today's skinned parts, keep the joints.** One `Skeleton3D` per body (today's `LowerBody` and `ArmBody` grown to the whole body); torso, head, hands, feet, hat merged into the skinned mesh bound to bones (the builder's `_skin_into` already does it for shins and forearms). The joint `Node3D`s stay as invisible data: the animator, IK, ragdolls, co-op sync and the 111 call sites outside the rig keep working. | Lower risk; most of the transform saving comes from the joints no longer carrying meshes. |
| Material | **One material per body:** a body-only variant of `psx_lit` reading the body's textures from a `Texture2DArray` by a per-vertex layer. ~15 draws to 1-2 (the body, the weapon). The shared `psx_lit` is untouched. | Draws are the biggest column. |
| Order | **Townsfolk and grunts first, behind a switch,** benched against the old bodies; the player's own rig last. | Prove it on background rigs before the one you watch. |
| Blender | **No.** Bodies are generated (looks, builds, outfits, creator, seeded villagers); the gain is structural and built in code. | Fixed models would lose the variety for no extra speed. |
| Hair and coat springs | Stay separate chain meshes for now; may fold into the skeleton as bones later. | Keeps the first pieces small. |

**Expected (estimated, not measured):** ~40 bodies in view in Brinehollow's town: ~1000 fewer draws (visible + shadow),
~1.5 ms of draw submission, ~1 ms of transforms, the two copy scripts merged into one: **~2-3 ms in towns and fights**,
more in crowds. The town to ~11-12 ms.

## Pieces (each lands on its own)
1. **One skeleton per body, behind a switch** (`BodyBuilder.ONE_SKIN` or a setting): every rigid part merged into the
   skinned mesh by bone; joints carry no meshes. Same look pixel for pixel: chartest (draws, winding, clearances),
   a creator/look contact sheet old vs new, fidelity renders. Bench old vs new (back to back).
2. **The texture array material** for bodies: the layers built once per texture set (cached like `PSXMat`), the
   per-vertex layer in a custom channel; flashes (`tint_mul` copies) still work; the face painter's face as a layer.
3. **Background rigs on by default** (townsfolk, grunts, capital crowd), the bench and the tests green; co-op puppets
   checked (nettest).
4. **The player's rig** (and crew), then the old path removed.

## Checks every piece
- No visible change: chartest, a look contact sheet (old/new side by side), the creator's options, hats and outfits,
  weapons in hand and sheathed, ragdolls, flashes (hit, peril), hair and coats swinging.
- Perf: the bench (town and fight stops) before/after back to back; chartest's draws per body.
