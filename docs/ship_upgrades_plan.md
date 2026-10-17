# Ship upgrade lines and Seamanship (plan, 2026-10-17)

## What it is
The crew's sloop grows into a ship you build up (docs/roadmap_v2.md phase 5, "Ships to work toward"): Tackett's
four one-time refits (docs/dev_notes.md 2026-10-07 "the shipwright"; `ShipKit`, `scripts/ui/shipwright_screen.gd`)
become tiered **upgrade lines**, many small steps (about +5% a level), **every level visible on the ship**, paid
in gold and **salvage** from sunk enemy ships, wrecks and chests. Each captain also gets their own **Seamanship**
tree, earned by sailing and naval fights like weapon mastery. The extra ship classes wait for the canal city.

## Decided (2026-10-17)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | The sloop's upgrade lines + the Seamanship tree; **no new ship classes** (caravel, brig, galleon, submarine wait for the canal city's shipyard) | One ship done properly first | The canal city |
| Lines | The four refits become lines (armour/plating, guns, sails and rigging, rudder) plus new ones: copper bottom, bow chaser, crow's-nest cabin, lanterns, railings, a tangerine grove (small heal/food), galley and bunks, a bigger storage chest | Roadmap's list | Play-test |
| Steps | Several levels per line, about +5% a level, each level changes the ship's look (new cloth and colours, plating, more lanterns, rails...) | "Small numbers, big visual identity" (roadmap) | Tune in play |
| Where | **Tackett's yard** at Brinehollow: his yard screen grows into the upgrade tree; shipwrights at chain harbours later | The harbour kit is another agent's this batch | After the batch |
| Cost | **Gold + salvage**: higher levels also need materials | Naval fights pay into the ship; treasure gets a use | The economy pass (prices) |
| Salvage from | **Sunk enemy ships** (floating crates and spars to sail through or swim to; bigger ship, better haul) and **wrecks and chests** (coastal and shallow-water wrecks, island chests) | Zach's picks (not from scrapping gear, not sold by traders) | - |
| Co-op | **Any captain chips in**: anyone at the yard pays for a level from their own gold and salvage, the host applies it (host-arbitrated request); one shared ship | Zach's pick (today only the host orders work) | - |
| Seamanship | **Each captain's own** tree and mastery, points earned by sailing, gunnery, repairs and sinking ships; station bonuses apply while you man that station (helm, guns, pump...), so a crew of specialists beats four of the same | Zach's pick | - |
| Tree content | Sail trim, faster turns, storm handling, reload and broadside aim, faster repairs, reading the log pose further, co-op crew-station bonuses | Roadmap's list | Play-test |

### Order (one agent, the ship's files)
1. The upgrade lines on the existing refits (data, levels, visible parts, costs in gold), the yard screen as a
   tree of lines, save migration (an old refit = its line's matching level). Lands on its own.
2. Salvage: the materials as items, drops from sunk enemy ships (floating, collectable at sea), wrecks and chests,
   and costs that need them.
3. The new lines (copper, bow chaser, crow's nest cabin, lanterns, railings, tangerine grove, galley/bunks, chest).
4. Co-op: any captain pays, the host applies.
5. The Seamanship mastery and tree.

### Open / deferred
- **assumed:** four materials: timber, iron, canvas, copper (rarer). The agent may change kinds; it says so.
- **assumed:** 3-5 levels a line; prices and amounts tuned in play, the economy pass rebalances.
- **assumed:** salvage goes into your inventory as stacks (the ship's storage chest holds it too).
- **assumed:** Seamanship is a tab in the skill map next to the weapon trees, levelled like weapon mastery.
- Shipwrights at chain-island harbours, the extra ship classes, upgrades on enemy ships: later.
