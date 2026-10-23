class_name Bounty
extends RefCounted
## A captain's bounty (docs/v1_19_plan.md: each captain's own, saved with the captain; the ship draws patrols by the
## crew's total). Raised by what they did in a fight they were in (Net.bounty: everyone within its reach), shown in
## gold. Its tier switches the world's reactions on: posters and townsfolk, shop prices, Admiralty heat, bounty
## hunters, named hunters. Every number is here (assumed, for Zach's OK: the table is in docs/v1_19_plan.md).

## What raises it (gold each), scaled by the thing's level where it has one (Net.bounty's `k`).
const TABLE := {
	"rival": 3000,           # a rival crew beaten (x (1 + their tier): they come back stronger)
	"boss": 6000,            # a camp's or fort's captain, a beast boss
	"leviathan": 4000,       # a Leviathan driven off or slain
	"ship": 1500,            # a pirate ship sunk or taken
	"admiralty_ship": 5000,  # an Admiralty ship sunk or taken
	"officer": 4000,         # an Admiralty officer beaten
	"hunter": 12000,         # a named Admiralty hunter beaten
	"bounty_hunter": 1500,   # a civilian bounty hunter beaten
}

## The tiers: [from, name, what it switches on].
const TIERS := [
	[0, "", ""],
	[5000, "Wanted", "posters go up; townsfolk know your face; Admiralty-minded shops charge more, shady ones less"],
	[20000, "Notorious", "Admiralty patrols come about for you; bounty hunters try their luck"],
	[60000, "Infamous", "a named Admiralty hunter takes your trail; Admiralty-minded shops won't serve you"],
	[150000, "Dreaded", "the hunters come tougher and in pairs; the strongest rival crews seek you out"],
]

## Shop price factors by tier (index = tier): an Admiralty-minded shop, a shady one (-1: won't serve you).
const PRICE_ADMIRALTY := [1.0, 1.15, 1.25, -1.0, -1.0]
const PRICE_SHADY := [1.0, 0.92, 0.88, 0.85, 0.8]


static func tier_of(b: int) -> int:
	var t := 0
	for i in range(TIERS.size()):
		if b >= int(TIERS[i][0]):
			t = i
	return t


static func title(b: int) -> String:
	return str(TIERS[tier_of(b)][1])


## "12,500" (thousands with commas).
static func fmt(b: int) -> String:
	var s := str(absi(b))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


## Raise our captain's bounty by `amount` (their own machine): a toast, and a banner when it crosses a tier.
static func add(p: Node, amount: int) -> void:
	if p == null or amount <= 0:
		return
	var before := int(p.get("bounty"))
	var after := before + amount
	p.set("bounty", after)
	var tree: SceneTree = p.get_tree()
	if tier_of(after) > tier_of(before):
		var t: Array = TIERS[tier_of(after)]
		tree.call_group("hud", "show_banner", "%s: %s gold" % [str(t[1]), fmt(after)], str(t[2]).capitalize() + ".", true)
	else:
		tree.call_group("hud", "show_toast", "Your bounty rose to %s gold" % fmt(after))
