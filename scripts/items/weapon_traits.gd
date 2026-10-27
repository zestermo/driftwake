class_name WeaponTraits
extends RefCounted
## Named weapon traits (v1.18). From blue (Rare) up every weapon rolls one, and it changes how one of
## its moves plays. The trait rides in the item's id ("<base>@<tier>+<trait>", ItemDB), so saves and
## co-op carry it like any item; a higher tier makes its numbers stronger (power()). Uniques carry a
## fixed one (ItemData.weapon_trait in their .tres or design). What each does in play: TraitMoves.
## (No autoloads here: ItemDB reads it, and test scripts name ItemDB before the autoloads exist.)

const MIN_TIER := 2
const TRAITS := {
	"serrated": {"name": "Serrated", "move": "Finisher", "kinds": ["cutlass", "katana", "axe", "polearm", "greatsword"],
		"desc": "The combo's last blow opens a wound that bleeds for 5 s."},
	"gale": {"name": "Gale", "move": "Finisher", "kinds": ["cutlass", "katana", "dagger", "polearm", "greatsword"],
		"desc": "The combo's last blow throws a wind blade 9 m ahead that cuts everything on its line."},
	"bloodthirsty": {"name": "Bloodthirsty", "move": "Finisher", "kinds": ["cutlass", "katana", "axe", "dagger", "hammer"],
		"desc": "A finisher that lands heals you 5% of your health."},
	"thundering": {"name": "Thundering", "move": "Heavy", "kinds": ["cutlass", "katana", "axe", "polearm", "hammer", "longgun"],
		"desc": "The heavy attack lands with a shockwave that knocks down everyone within 3.5 m."},
	"headsman": {"name": "Headsman's", "move": "Heavy", "kinds": ["axe", "katana", "hammer", "greatsword"],
		"desc": "The heavy attack does double damage to an enemy under a third of its health."},
	"rushing": {"name": "Rushing", "move": "Running cut", "kinds": ["cutlass", "katana", "polearm", "hammer", "greatsword"],
		"desc": "The running cut drives twice as far and knocks them down."},
	"embered": {"name": "Embered", "move": "Roll", "kinds": ["cutlass", "katana", "axe", "dagger"],
		"desc": "Your roll leaves a trail of fire that burns for 3 s."},
	"duellist": {"name": "Duellist's", "move": "Parry", "kinds": ["cutlass", "katana", "dagger", "polearm", "hammer", "axe", "greatsword"],
		"desc": "A clean parry ripostes at once: a free cut that staggers them."},
	"venomous": {"name": "Venomous", "move": "Every hit", "kinds": ["cutlass", "dagger"],
		"desc": "Every hit poisons them for 4 s."},
	"hair_trigger": {"name": "Hair-trigger", "move": "Shot", "kinds": ["pistol", "longgun"],
		"desc": "A shot within a second of a roll always crits and knocks them down."},
	"blasting": {"name": "Blasting", "move": "Shot", "kinds": ["pistol", "longgun"],
		"desc": "The last ball of each load bursts where it hits, knocking down everyone within 2.5 m."},
}


## The traits that can roll on a weapon kind (ItemData.weapon_model).
static func pool(model: String) -> Array:
	return TRAITS.keys().filter(func(k): return model in TRAITS[k]["kinds"])


static func roll(model: String, rng: RandomNumberGenerator) -> String:
	var p := pool(model)
	return str(p[rng.randi() % p.size()]) if not p.is_empty() else ""


## How strong a trait is on a weapon of `tier` (1 at blue, +20% a tier).
static func power(tier: int) -> float:
	return 1.0 + 0.2 * float(tier - MIN_TIER)


static func title(id: String) -> String:
	return str(TRAITS[id]["name"])


## "Serrated - Finisher: ..." for the tooltip.
static func line(id: String) -> String:
	return "%s - %s: %s" % [TRAITS[id]["name"], TRAITS[id]["move"], TRAITS[id]["desc"]]
