# 1.30.3 piece 1: slots, layers and conflicts (draft for Zach's OK)

Status: draft (2026-11-05). Decided already (docs/v1_30_3_clothing_plan.md): one Shoulders slot with three pauldron
items (left, right, both); Back takes a cape, cloak, mantle or backpack; no Neck slot (neck wear is Face); two
Trinkets. Marked **?** below: Zach's call.

## The slots and what goes in each

Layers: 0 skin, 1 base, 2 mid, 3 outer, 4 over, 5 plates (armour that rides on top of everything).

| Slot | Pieces (today's look values) | Layer | Body regions |
|---|---|---|---|
| Head | tricorn, bicorne, bandana, cap, knit, straw, hood, cavalier, morion, turban, kettle, fez, headband, crown, coif, slouch, helm (+ Bulwark), jester | 3 (hood, coif: 3 over the neck) | head; hood/coif + neck |
| Face | mask, oni, half_mask, iron_mask, kerchief, mouth_guard, bandage, eye_wrap, **scarf (moves here)**, bandanas worn at the neck | 2 (scarf, kerchief: 3) | eyes and/or mouth; scarf + neck |
| Torso | shirt, tunic, blouse, doublet, kimono, striped, bare, motley | 1 | chest, back, arms (sleeves) |
| Vest | vest, corset, cuirass, brigandine (+ Bulwark), mail, jerkin, padded, scale, harness | 2 | chest, back (no arms) |
| Coat | jacket, longcoat (+ Bosun's), captain, greatcoat, haori, duster, frock, admiral; draped (over the shoulders) | 3 | chest, back, arms, hips (tails); draped: shoulders, back |
| Shoulders | **pauldron (left), pauldron (right), pauldrons (pair)** | 5 | left / right / both shoulders |
| Back | cape, cloak, **mantle**, backpack | 4 | back; cloak + shoulders; mantle shoulders |
| Strap | bandolier, baldric | 4 | across chest and back |
| Belt | belt, sash, belt_sash, wide_belt (+ Powder Belt); **apron ?** | 3 | waist; apron + front of the thighs |
| Hands | gloves, gauntlets (+ Bulwark), bracers, long_gloves, arm_wraps | 1-2 | hands, forearms |
| Legs | trousers, breeches, shorts, skirt, hakama, leathers, slops, parachute, motley_hose | 1 | hips, thighs, shins |
| Feet | tall_boots, boots, shoes, barefoot, greaves, sandals, sabatons, cavalier_boots, foot_wraps, curled | 2 | feet, shins (tall ones) |
| Trinket x2 | earring, eyepatch **?**, goggles, spyglass, necklace (Shark's Tooth), pouch | - | none: never blocked |
| Equipment | instrument, rod | - | - |

## What the layers actually decide

Laid out like this, almost every slot sits on its own layer, so **two pieces in different slots rarely compete**:
the slot itself already stops two coats or two capes. The region rule matters for the few pieces that reach outside
their slot's usual place, and that's a short list:

### Blocked (can't equip together; the doll says why)

| Pair | Why | Proposal |
|---|---|---|
| Cloak + pauldrons | the cloak's yoke covers the shoulders | blocked **?** (or pauldrons over the cloak) |
| Mantle + greatcoat | both are a cape over the shoulders | blocked |
| Mantle + draped coat | both sit over the shoulders | blocked **?** |
| Helm (and Bulwark, kettle, morion) + oni / iron_mask / mask | the helm's nose bar and cheek plates go through a mask | blocked **?** (bandage, kerchief, mouth_guard still fit) |
| Apron + frock | the frock is buttoned closed to the knee | blocked (if the apron stays a Belt piece) |

### Hidden, not blocked (worn, kept, not drawn while covered)

- Goggles under a covering helm or hood (shown on a hat brim otherwise, as now).
- Eyepatch under a mask that covers the eyes (oni, iron_mask, mask, eye_wrap), if the eyepatch is a trinket.
- Earring under a hood, coif or helm with cheek plates.
- Necklace under a scarf or a high collar.

### Fitted, not blocked (the builder stacks them; already handled in places today)

- A pauldron over a greatcoat's shoulder cape, a mantle or a draped coat (it lifts, as now).
- A backpack under a draped coat or a cape (the cape hangs out over the pack, as now: a traveller's cloak).
- A strap over any vest and coat but the greatcoat's shoulder cape (it goes under that).

## Moving old saves and items (a Settings VERSION migration)

| Today (accessory flag) | Goes to | If that slot is already taken |
|---|---|---|
| cape, cloak, mantle | Back | a backpack already there wins (it's a real slot today); the cape goes to the bag |
| pauldron | Shoulders, as **pauldron (left)** (today's is on the left arm) | - |
| scarf | Face | a face piece already there wins; the scarf goes to the bag |
| bandolier, baldric | Strap | the first one equipped wins; the other to the bag |
| apron | Belt **?** | the belt wins; the apron to the bag |
| earring, eyepatch, goggles, spyglass, necklace, pouch | Trinkets | the first two; the rest to the bag |

Items already in bags, chests and storage change kind (accessory -> back, shoulders, strap, trinket...) on load. Shops,
loot tables and boss drops (`Gear.make("accessory", "cape", ...)`, ~20 call sites) get their new kinds. Set bonuses
and weights (GearStats) follow the item, not the slot.

## Zach's calls

1. **Cloak + pauldrons:** blocked, or pauldrons ride over the cloak?
2. **Mantle + draped coat:** blocked?
3. **Helms + full masks:** blocked (light face pieces still fit)?
4. **Eyepatch:** a trinket (hidden under eye-covering masks) or Face (one or the other)? Proposal: trinket.
5. **Apron:** a Belt piece with its own waist tie (replaces the belt), or a trinket-like extra that hangs over any
   belt? Proposal: Belt, since an apron over a sash looks crowded and the apron's tie is a belt already.
6. **A second set of pauldrons in old saves:** today two pauldron items equip as one; the second goes to the bag.
