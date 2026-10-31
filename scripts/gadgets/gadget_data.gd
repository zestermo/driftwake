class_name GadgetData
extends RefCounted
## Every gadget number in one place (1.28; docs/gadgets_plan.md is the readable copy). Per-tier arrays are
## [Mk I, Mk II, Mk III]. Data only: ItemDB names Gadgets, which reads this before the autoloads exist.

## The Tinkering level each tier needs to build (or upgrade to).
const TIER_TINKER := [1, 6, 12]
const TIER_NAMES := ["Mk I", "Mk II", "Mk III"]
const SLOTS := 3
## Tinkering xp for building a gadget at tier t, upgrading to it, and for a refill.
const BUILD_XP := [40, 90, 160]
const REFILL_XP := 5

## kind: combat (thrown, charges + cooldown), traversal (cooldown only), utility, ship (fitted to the ship).
## Each tier: charges (0 = cooldown only), cd (s), and the gadget's own effect numbers.
const GADGETS := {
	"smoke": {"name": "Smoke Pellet", "kind": "combat", "throw": true,
		"desc": "A clay pellet of blackpowder and soot. It bursts into a thick cloud: foes inside lose sight of you and stagger coughing; you can't be noticed or attacked from inside.",
		"charges": [3, 4, 5], "cd": [6.0, 5.0, 4.0], "range": [14.0, 16.0, 18.0],
		"radius": [3.5, 4.5, 5.5], "secs": [6.0, 8.0, 10.0], "blind": [1.6, 2.0, 2.6]},
	"tar": {"name": "Tar Bomb", "kind": "combat", "throw": true,
		"desc": "A stoppered jar of hot pitch. It smashes into a black pool that glues the feet of every foe in it.",
		"charges": [3, 4, 5], "cd": [7.0, 6.0, 5.0], "range": [13.0, 15.0, 17.0],
		"radius": [2.4, 3.0, 3.6], "secs": [7.0, 9.0, 11.0], "slow": [0.5, 0.38, 0.26]},
}


static func tier_val(gid: String, key: String, tier: int) -> Variant:
	return (GADGETS[gid][key] as Array)[tier]
