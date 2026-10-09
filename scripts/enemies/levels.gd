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


static func _k(level: int, ref: int, per: float) -> float:
	if level <= 0:
		return 1.0
	return (1.0 + per * float(level - REF)) / (1.0 + per * float(ref - REF))
