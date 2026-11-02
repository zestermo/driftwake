# 1.29 'Shipshape' (and 1.30's ships)

## What it is
The crew's ship gets the love it's been missing: the hull's layout becomes data a ship class and its upgrades can
change, and the sloop is reworked on it (a cabin stepped down into the hull, bigger, growing with its own upgrade
line; shorter, cleaner ladders; the crow's nest flag; a new wheel that upgrades; the galley, bunks, kitchen and table
in full detail). Alongside it, new clothing: masks and face coverings, wraps, baggy pants, a jester outfit, a
backpack with loose parts that bounce, and any coat worn over the shoulders with the sleeves dangling. Plus a small
hitch-and-flake track. **1.30** builds the brig and the galleon on the same layout system, with new creatures for
the thinnest island themes.

## Decided (2026-11-02)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Headline | **Ships to work toward** (Zach), split in two: **1.29** the layout system + the sloop's detail pass + clothing; **1.30** the brig and galleon on it + creatures | Zach plays the reworked sloop before bigger hulls are built on it; lean run mode can't carry it all at once | 1.30's own grill |
| Run mode | **Lean**: this session plus at most one driftwake-feature agent at a time, landed in small pieces | Zach's rule from finishing 1.28 | - |
| Perf | **Hitches + flakes**: a hitch logger (frames over 33 ms with what ran), far grunt brains on a staggered tick, and the island-free race behind the load-only shiptest / chaintest crashes (todo.md, 2026-11-02) | Real stutter first; the full 10 ms track is its own task | The bench at prepush |
| Hull layout | **Data, not constants**: HullBuilder's consts (cabin, stairs, quarterdeck, helm, mast, ladders) become a layout per ship class and cabin tier, read by every user (51 files today). The sloop first reproduced exactly, then changed | Every later hull and the growing cabin need it; Zach chose new layouts per ship for 1.30 | - |
| The sloop's cabin | **Stepped down** into the hull (a step or two down from the main deck, so it has headroom under the quarterdeck) and **a little bigger** at its base level | Zach | Play |
| Cabin growth | **Its own upgrade line**, "Quarters" in the shipwright's Cabin group: each level makes the cabin longer and taller and furnishes it more (table below, for Zach's OK) | Zach; visible, and chosen | Play |
| Helm | A **new baseline wheel** (more detail: spokes, hub, pedestal), and the existing **Rudder & helm** line's five levels each show on the wheel itself (brass rim, binnacle, carved pedestal, gilding) | Zach | - |
| Ladders and flag | The hull ladders **shorter and cleaner** (rungs and rails that sit right on the hull, ending at the waterline); the crow's nest flag redone so it hangs and flies right | Zach: too long, janky | - |
| Galley and berths | **A full detail pass** on the galley, bunks, kitchen and table at every level of the Galley & bunks line (pots, shelves, crockery, bedding, lamps) | Zach | - |
| Shoulder coat | **A way to wear any coat or jacket**: draped over the shoulders, front open, the empty sleeves swinging behind on spring chains (Koby; Zoro's and Mihawk's coats). Toggled in the wardrobe | Works on every coat already in the game | Play |
| New clothing | Masks (on the face), small mouth coverings, head bandages, arm wraps, foot wraps, baggy parachute pants, a jester outfit (bells on spring chains), a backpack with loose parts (bedroll, pot, lantern) bouncing on spring chains | Zach | - |
| Clothing source and stats | As every piece since 1.24: the gear-stat system, sold at village tailors (and smiths for the armoured ones), some in loot; basic ones in the creator | The standing system | - |
| The brig and galleon (1.30) | **Brig + galleon**, the gun ships; **new layouts per ship** (each hull laid out on the layout system, its own decks, gun deck(s), cabins); **sold for gold + parts at the canal city's shipyard, the galleon only once far enough down the chain** | Zach | 1.30's grill |
| Creatures (1.30) | **New hostile creatures for only the thinnest themes** (2-3 themes, picked by counting each theme's wildlife then) | Zach | 1.30's grill |
| Submarine | Its own later release | A different machine (diving, underwater) | After 1.30 |

### The Quarters line (draft numbers for Zach's OK)

Prices on the economy's curve like every line (base x 1.6 a level). Materials are the yard's usual ones. The effect is
**rest**: the bunk's rested buff lasts longer (a new effect key). Tune it in play.

| Level | What you see | Gold | Materials | Effect |
|---|---|---|---|---|
| 0 (the rework) | Stepped down, a little bigger than today; bed, chest, the galley line's pieces | - | - | - |
| 1 Panelled quarters | +1 m long, panelled walls, a table with benches | 80 | timber 4 | rest +10% |
| 2 Stern windows | Lengthened aft to the stern, a row of stern windows, a chart desk | 128 | timber 6, iron 2 | rest +10% |
| 3 Captain's corner | Taller deckhead, a partition with the captain's cot, a rug and a hanging lamp | 205 | timber 6, canvas 3 | rest +10% |
| 4 Great cabin | The full width under the quarterdeck, a second step down, a long mess table for five, a stove | 328 | timber 8, iron 4, copper 2 | rest +15% |

For scale: a full sloop line costs ~950 at the yard, and the caravel 1,400.

### Order (each piece lands on its own, released as unstable 1.28.x pre-releases, then the stable 1.29)
1. **Hull layout data** (agent, driftwake-ship): HullBuilder to a layout per class/tier; the sloop identical
   (ship tests, riggingtest, a hullshot before/after).
2. **The sloop rework** (agent): the stepped-down, bigger cabin; ladders; the crow's nest flag; the new wheel.
3. **Quarters line + the wheel's upgrades** (agent).
4. **Galley, bunks, kitchen, table detail** (agent).
- **Clothing** (this session, alongside, a separate area: character_look, body_builder, spring_chains): the
  shoulder-coat mode first, then the pieces, checked with outfitgrid / armorshot.
- **Hitches + flakes** (this session or a driftwake-fixer between pieces).

### Open / deferred
- Masks and face coverings take a new face-accessory slot that stacks with hats; a full mask hides the painted face. **assumed**
- The backpack takes the back; while it's worn the gadget pouch moves to the hip. **assumed**
- The jester outfit is a set (cap with bells, motley top and pants, curled shoes), each piece its own item. **assumed**
- Old saves' sloops get Quarters level 0 (the reworked cabin) for free; nothing bought is lost. **assumed**
- Co-op: the cabin's tier and every new clothing piece are in the kit and the look, synced like today. **assumed**
- The brig's and galleon's numbers, layouts and solo crewing (NPC deckhands or not): 1.30's grill.
- Which themes get creatures: 1.30's grill.
