class_name Levels
extends RefCounted
## Enemy scaling by level: a chain island's (chain.gd), or the sea leg's toward
## one. Level 0 is unscaled: Brinehollow's enemies, tuned for captains of level
## 1-5 (REF 3 is where the curves are 1). Spawners set an enemy's `level` before
## it enters the tree. The reasoning: docs/dev_notes.md, "level scaling".

const REF := 3
## A level-4 enemy gives the XP written on it (Brinehollow's economy).
const XP_REF := 4


## Health: a little ahead of a captain's damage (+2% a level, mastery and Haki
## nodes, weapon tiers); the new skills and ultimates make up the rest.
static func hp_k(level: int, ref: int = REF) -> float:
	return _k(level, ref, 0.075)


## Damage dealt to captains: tracks their health and defence (+4 a level, health
## nodes, tiered gear).
static func dmg_k(level: int, ref: int = REF) -> float:
	return _k(level, ref, 0.09)


## Ship against ship (hulls, and balls and rams on a hull): gentler, since our
## own ship's guns don't level.
static func hull_k(level: int) -> float:
	return _k(level, REF, 0.04)


static func coins_k(level: int) -> float:
	return _k(level, REF, 0.08)


## As the XP curve (200 x lv^1.5): a kill is the same share of a level as it was in Brinehollow.
static func xp_k(level: int) -> float:
	if level <= 0:
		return 1.0
	return pow(float(level) / XP_REF, 1.5)


## Loot tier (ItemData.Rarity) by level: green 6-11, blue 12-16, purple 17-21, yellow 22+.
static func tier(level: int) -> int:
	return clampi((level - 2) / 5, 1, 4)


# ==========================================================================
# The level gap (1.30, docs/v1_30_plan.md "round 5"): g = the foe's level minus the captain's, per captain, on top of
# the curves above; 0 is the curves' balance. HitData.gap carries it (Hurtbox sets it on the captain's machine).
# ==========================================================================
const NO_GAP := -1000
const BADGE_GREY := Color("8a8f8c")
const BADGE_WHITE := Color("f5e8c8")
const BADGE_RED := Color("f14a3c")


## The captain's damage to a foe `g` levels above them.
static func gap_dmg_out(g: int) -> float:
	return clampf(1.0 - 0.06 * g, 0.7, 1.5)


## A foe's damage to a captain `g` levels below it.
static func gap_dmg_in(g: int) -> float:
	return clampf(1.0 + 0.12 * g, 0.4, 2.0)


## A foe's poise against the captain hitting it (Poise.take divides the blow's poise damage by it).
static func gap_poise(g: int) -> float:
	return clampf(1.0 + 0.12 * g, 0.3, 1.8)


## The overkill a throw needs (Splat's shares), times this.
static func gap_splat(g: int) -> float:
	return clampf(1.0 + 0.15 * g, 0.1, 2.0)


## The level badge beside a foe's health bar: grey far below you, red 3+ above.
static func badge(g: int) -> Color:
	if g <= -5:
		return BADGE_GREY
	return BADGE_RED if g >= 3 else BADGE_WHITE


## A human captain (an AI captain is a foe).
static func captain(n: Node) -> bool:
	return n != null and n.is_in_group("players") and not n.get("is_ai")


## A foe's level for the gap; -1 when `n` isn't one. A level-0 foe (Brinehollow's, unscaled) and an AI captain have no
## level of their own: the island's they stand under (a ghost captain's, an island's), else REF (its _lv_ref is only
## where its numbers were tuned, not what it's called).
static func foe_level(n: Node) -> int:
	if n == null:
		return -1
	if n.is_in_group("players"):
		return _served_level(n) if n.get("is_ai") else -1
	if not n.is_in_group("enemies") or not (n.get("level") is int):
		return -1
	var lv: int = n.get("level")
	if lv > 0:
		return lv
	return _served_level(n)


static func _served_level(n: Node) -> int:
	var a := n.get_parent()
	while a != null:
		var lv = a.get("level")
		if lv is int and lv > 0:
			return lv
		var nd = a.get("node")
		if nd is Dictionary and nd.has("level"):
			return int(nd["level"])
		a = a.get_parent()
	return REF


static func captain_level(n: Node) -> int:
	return int(n.get("progression").get("level"))


## The gap a blow between a captain and a foe carries, worked out on that captain's own machine (a guest's blow on a
## host-run foe arrives with it packed; a foe's blow on a guest is worked out when it reaches the guest). NO_GAP when
## it's not such a blow, or another machine's to work out.
static func hit_gap(target: Node, attacker: Node) -> int:
	if target == null or attacker == null:
		return NO_GAP
	if captain(attacker):
		var lv := foe_level(target)
		return lv - captain_level(attacker) if lv >= 0 and attacker.get("is_local") else NO_GAP
	if captain(target):
		var lv := foe_level(attacker)
		return lv - captain_level(target) if lv >= 0 and target.get("is_local") else NO_GAP
	return NO_GAP


## The gap between this screen's captain and `foe` (the badge), 0 when there's no telling.
static func gap_to(foe: Node, me: Node) -> int:
	var lv := foe_level(foe)
	return lv - captain_level(me) if lv >= 0 and me != null and me.get("progression") != null else 0


static func _k(level: int, ref: int, per: float) -> float:
	if level <= 0:
		return 1.0
	return (1.0 + per * float(level - REF)) / (1.0 + per * float(ref - REF))
