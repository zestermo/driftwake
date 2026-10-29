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
	"admiralty_ship": 1000,  # an Admiralty ship sunk or taken (1.26: was 5000, which snowballed into patrols every 95 s)
	"officer": 4000,         # an Admiralty officer beaten
	"hunter": 12000,         # a named Admiralty hunter beaten
	"bounty_hunter": 1500,   # a civilian bounty hunter beaten
	"arc": 8000,             # an island arc's villain brought down (IslandArcs)
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


## Who supplies the Admiralty (they charge a wanted captain more, then won't serve them) and who doesn't ask.
const ADMIRALTY_TRADES := ["armourer", "smith"]
const SHADY_TRADES := ["treasure"]
const REFUSE_LINES := ["I don't sell steel to wanted pirates. Off with you.", "Your face is on the board outside. Out.",
	"The Admiralty buys from me. I'd like to keep it that way. Go."]


## What townsfolk mutter when a wanted captain walks past (by tier; villagers' barks, half the time).
const RECOGNISE := [
	[],
	["Isn't that the one from the board?", "That face... the poster by the well.", "Keep your voice down. That's a wanted captain.",
		"Five thousand gold, that one. Walking about like they own the place."],
	["Don't stare! That's the one the Admiralty's after.", "Lock the shutters, love. It's that captain.",
		"Twenty thousand on their head and they're buying apples.", "My cousin says they sank three ships in a week."],
	["Mother of tides, it's really them.", "Don't look. Don't look. Just walk.", "The Admiralty sent a hunter after that one, they say.",
		"Sixty thousand. You could buy the whole island with that bounty."],
	["They say the sea itself steers clear of that one.", "Inside. Everyone inside. Now.", "I'm not here. I didn't see anything.",
		"A hundred and fifty thousand... I didn't think a person could be worth that."],
]


## A shop's price factor for a captain with bounty `b` (by its trade); -1: it won't serve them.
static func shop_k(trade: String, b: int) -> float:
	var t := tier_of(b)
	if trade in ADMIRALTY_TRADES:
		return float(PRICE_ADMIRALTY[t])
	if trade in SHADY_TRADES:
		return float(PRICE_SHADY[t])
	return 1.0


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


## Why it rose, as a poster's line and the Wanted screen's deeds (by TABLE kind).
const WHY := {
	"rival": "for beating a rival crew",
	"boss": "for bringing down an island's master",
	"leviathan": "for facing down a Leviathan",
	"ship": "for sinking a pirate ship",
	"admiralty_ship": "for sinking an Admiralty ship",
	"officer": "for striking down an Admiralty officer",
	"hunter": "for beating an Admiralty hunter",
	"bounty_hunter": "for seeing off bounty hunters",
	"arc": "for overthrowing an island's tyrant",
}
## Deeds big enough for a new poster (the One Piece moment: WantedCard); the rest raise it with a toast.
const POSTER_DEEDS := ["rival", "boss", "leviathan", "admiralty_ship", "officer", "hunter", "arc"]
## Deeds kept per captain (Player.bounty_log, saved).
const LOG := 12


## Raise our captain's bounty by `amount` (their own machine) for deed `kind` (a TABLE key, or ""): logged, then a new
## poster (WantedCard) for a big deed or a new tier, else a toast.
static func add(p: Node, amount: int, kind: String = "") -> void:
	if p == null or amount <= 0:
		return
	var before := int(p.get("bounty"))
	var after := before + amount
	p.set("bounty", after)
	var tree: SceneTree = p.get_tree()
	var log_ = p.get("bounty_log")
	if log_ is Array:
		(log_ as Array).append([kind, amount, _day(tree)])
		while (log_ as Array).size() > LOG:
			(log_ as Array).pop_front()
	var crossed := tier_of(after) > tier_of(before)
	var settings := tree.root.get_node_or_null("Settings")
	if (crossed or kind in POSTER_DEEDS) and not (settings and settings.call("tool_run")):
		WantedCard.show_for(p, before, after, str(WHY.get(kind, "")))
	elif crossed:
		var t: Array = TIERS[tier_of(after)]
		tree.call_group("hud", "show_banner", "%s: %s gold" % [str(t[1]), fmt(after)], str(t[2]).capitalize() + ".", true)
	else:
		tree.call_group("hud", "show_toast", "Your bounty rose to %s gold" % fmt(after))


## The game day (Weather.day()), 0 without a Weather.
static func _day(tree: SceneTree) -> int:
	var w := tree.root.get_node_or_null("Weather")
	return int(w.call("day")) if w and w.has_method("day") else 0


## What tier `b` switches on next: [the next tier's name, from, what] or [] at the top.
static func next_tier(b: int) -> Array:
	var t := tier_of(b)
	return [] if t >= TIERS.size() - 1 else [str(TIERS[t + 1][1]), int(TIERS[t + 1][0]), str(TIERS[t + 1][2])]


## Heat (1.23: bounty as a counterweight): what the Admiralty and hunters go by. The bounty itself never falls, but a
## day without a deed cools the heat by COOL (at most down to HEAT_FLOOR of it), so lying low thins the pursuit.
const COOL := 0.02
const HEAT_FLOOR := 0.5


static func heat(p: Node) -> int:
	if p == null or p.get("bounty") == null:
		return 0
	var b := int(p.get("bounty"))
	var log_ = p.get("bounty_log")
	if not (log_ is Array) or (log_ as Array).is_empty():
		return b
	var days := maxi(_day(p.get_tree()) - int((log_ as Array)[-1][2]), 0)
	return roundi(b * maxf(1.0 - COOL * days, HEAT_FLOOR))


## The tier pursuit goes by (patrols, blockades, hunters): the heat's.
static func heat_tier(p: Node) -> int:
	return tier_of(heat(p))
