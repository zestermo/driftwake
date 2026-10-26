class_name GearStats
extends RefCounted
## Armour and clothing stats (1.24, docs/v1_24_previews.md section 1). Every wearable piece has a weight (light cloth,
## medium leather, heavy mail and plate) and up to two stats from its slot and weight; its tier scales the good ones
## (RARITY_SCALE; drawbacks stay as they are) and purple and up add a second stat where the piece has one. Accessories
## and belts carry one trait of their own. Everything comes from the item (its style, tier and id), so a save from
## before 1.24 and a crewmate's machine work the same numbers out. Worn, they reach the captain as one more source in
## the stat cache (Progression.gear); defence goes through ItemData.armor().

enum {LIGHT, MEDIUM, HEAVY}
const WEIGHT_NAMES := ["Light", "Medium", "Heavy"]
const WEIGHT_MATS := ["cloth", "leather", "mail and plate"]

## The look style's weight (anything not listed is light).
const WEIGHT := {
	"tricorn": MEDIUM, "cavalier": MEDIUM, "slouch": MEDIUM, "crown": MEDIUM,
	"morion": HEAVY, "kettle": HEAVY, "coif": HEAVY, "helm": HEAVY,
	"doublet": MEDIUM,
	"corset": MEDIUM, "jerkin": MEDIUM, "padded": MEDIUM, "harness": MEDIUM,
	"brigandine": HEAVY, "mail": HEAVY, "cuirass": HEAVY, "scale": HEAVY,
	"longcoat": MEDIUM, "captain": MEDIUM, "duster": MEDIUM, "frock": MEDIUM, "admiral": MEDIUM,
	"greatcoat": HEAVY,
	"bracers": MEDIUM, "long_gloves": MEDIUM, "gauntlets": HEAVY,
	"leathers": MEDIUM,
	"boots": MEDIUM, "tall_boots": MEDIUM, "cavalier_boots": MEDIUM, "greaves": HEAVY, "sabatons": HEAVY,
	"wide_belt": MEDIUM,
	"mantle": MEDIUM, "cloak": MEDIUM, "pauldron": HEAVY,
}

## Slot row -> [light, medium, heavy] stats (the approved table). Vests share the torso's row, feet the legs'.
const TABLE := {
	"head": [{"crit_all": 0.03}, {"defense": 4.0}, {"defense": 8.0, "stamina_regen_pct": -0.03}],
	"torso": [{"max_stamina": 5.0}, {"defense": 8.0, "damage_pct": 0.03}, {"defense": 16.0, "poise_pct": 0.10}],
	"coat": [{"energy_regen_pct": 0.05}, {"defense": 6.0, "swim_pct": 0.05}, {"defense": 12.0, "move_pct": -0.05}],
	"hands": [{"attack_speed_pct": 0.04}, {"damage_pct": 0.03}, {"defense": 6.0, "block_cost_pct": 0.08}],
	"legs": [{"move_pct": 0.05}, {"defense": 4.0, "dodge_dist_pct": 0.05}, {"defense": 10.0, "move_pct": -0.04}],
}
const ROW := {"head": "head", "torso": "torso", "vest": "torso", "coat": "coat", "hands": "hands", "legs": "legs", "feet": "legs"}

## Accessories' and belts' one trait each.
const TRAITS := {
	"earring": {"gold_pct": 0.05}, "eyepatch": {"crit_all": 0.03}, "scarf": {"max_stamina": 5.0},
	"pauldron": {"defense": 4.0}, "pouch": {"use_speed_pct": 0.10}, "apron": {"regen_pct": 0.10},
	"cape": {"dodge_dist_pct": 0.04}, "cloak": {"defense": 3.0}, "bandolier": {"reload_pct": 0.06},
	"necklace": {"damage_pct": 0.02}, "goggles": {"breath_pct": 0.10}, "mantle": {"stamina_regen_pct": 0.05},
	"baldric": {"attack_speed_pct": 0.03}, "spyglass": {"xp_pct": 0.03},
	"belt": {"max_stamina": 3.0}, "sash": {"max_stamina": 5.0}, "belt_sash": {"max_stamina": 4.0}, "wide_belt": {"defense": 4.0},
}

## Purple and up: the second stat, rolled from these (one the piece hasn't got).
const BONUS := [["crit_all", 0.03], ["damage_pct", 0.03], ["max_stamina", 5.0], ["energy_regen_pct", 0.05],
	["stamina_regen_pct", 0.05], ["move_pct", 0.03], ["attack_speed_pct", 0.03], ["dodge_dist_pct", 0.05],
	["swim_pct", 0.05], ["defense", 4.0], ["gold_pct", 0.05]]
const BONUS_TIER := 3
## White, green, blue, purple, gold (red and black past them).
const RARITY_SCALE := [1.0, 1.15, 1.3, 1.5, 1.75, 2.0, 2.3]

## Named sets: three pieces (look styles) and what wearing all three gives.
const SETS := {
	"admiralty": {"name": "Admiralty set", "pieces": ["bicorne", "admiral", "cavalier_boots"], "bonus": {"vs_admiralty_pct": 0.10}},
	"corsair": {"name": "Corsair set", "pieces": ["tricorn", "captain", "tall_boots"], "bonus": {"air_jumps": 1.0}},
}

## Flat stats (the rest are fractions shown as percentages).
const FLAT := ["defense", "max_stamina", "air_jumps"]
const LABELS := {
	"crit_all": "crit", "defense": "defence", "stamina_regen_pct": "stamina regen", "max_stamina": "max stamina",
	"damage_pct": "damage", "poise_pct": "poise", "energy_regen_pct": "energy regen", "swim_pct": "swim speed",
	"move_pct": "move speed", "attack_speed_pct": "attack speed", "block_cost_pct": "block", "dodge_dist_pct": "dodge distance",
	"gold_pct": "gold", "use_speed_pct": "item use speed", "regen_pct": "health regen", "reload_pct": "reload speed",
	"breath_pct": "breath", "xp_pct": "experience", "vs_admiralty_pct": "damage vs the Admiralty", "air_jumps": "air step",
}

static var _cache := {}


static func is_wearable(item: ItemData) -> bool:
	return item != null and item.is_gear() and item.gear_slot != "equipment"


static func weight(item: ItemData) -> int:
	return int(WEIGHT.get(item.icon_kind, LIGHT))


static func scale(tier: int) -> float:
	return float(RARITY_SCALE[clampi(tier, 0, RARITY_SCALE.size() - 1)])


## The piece's untiered stats: its slot and weight's row, or its trait (no bonus, no tier).
static func base(item: ItemData) -> Dictionary:
	if item.gear_slot in ["accessory", "belt"]:
		return (TRAITS.get(item.icon_kind, {}) as Dictionary).duplicate()
	return (TABLE[ROW[item.gear_slot]][weight(item)] as Dictionary).duplicate()


## The piece's stats with its tier and bonus: key -> value (defence included). Remembered by id.
static func of(item: ItemData) -> Dictionary:
	if not is_wearable(item):
		return {}
	if _cache.has(item.id):
		return _cache[item.id]
	var b := base(item)
	var tier := int(item.rarity)
	var goods := 0
	for k in b.keys():
		if float(b[k]) > 0.0:
			goods += 1
	if tier >= BONUS_TIER and goods < 2:
		var pool: Array = BONUS.filter(func(e): return not b.has(e[0]))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(item.id.get_slice("@", 0))
		var e: Array = pool[rng.randi() % pool.size()]
		b[e[0]] = e[1]
	var out := {}
	var k := scale(tier)
	for key in b.keys():
		var v := float(b[key])
		out[key] = _snap(key, v * k if v > 0.0 else v)
	_cache[item.id] = out
	return out


static func _snap(key: String, v: float) -> float:
	return roundf(v) if key in FLAT else snappedf(v, 0.005)


## Its defence with its tier: the table's (or its trait's), else the piece's own (Gear.DEFENSE: a hat's felt, a
## glove's leather), plus a bonus's.
static func defense(item: ItemData) -> float:
	var d := float(of(item).get("defense", 0.0))
	if not base(item).has("defense"):
		d += float(Gear.DEFENSE.get(item.icon_kind, 0.0)) * scale(int(item.rarity))
	return d


## The set a piece belongs to ("" none).
static func set_of(item: ItemData) -> String:
	for id in SETS.keys():
		if item.icon_kind in (SETS[id]["pieces"] as Array):
			return id
	return ""


## How many of set `id`'s pieces are worn.
static func set_count(slots: Dictionary, id: String) -> int:
	var n := 0
	for it in slots.values():
		if it and is_wearable(it) and set_of(it) == id:
			n += 1
	return n


## Everything worn, summed (defence left out: EquipmentComponent.defense), with the full sets' bonuses.
static func totals(slots: Dictionary) -> Dictionary:
	var out := {}
	for it in slots.values():
		if it == null or not is_wearable(it):
			continue
		var s := of(it)
		for key in s.keys():
			if key != "defense":
				out[key] = float(out.get(key, 0.0)) + float(s[key])
	for id in SETS.keys():
		if set_count(slots, id) >= 3:
			var b: Dictionary = SETS[id]["bonus"]
			for key in b.keys():
				out[key] = float(out.get(key, 0.0)) + float(b[key])
	return out


## A captain's blow on `target`: x(1 + the Admiralty set's bonus) on anyone in the Admiralty's grey (their look's
## "admiralty", EnemyShip.marine_look), else 1. Worked out on the striker's machine, before the hit is routed.
static func versus(attacker: Node, target: Node) -> float:
	# (untyped: Player names the autoloads, and items load before them under --script)
	if attacker == null or target == null or not attacker.is_in_group("players") or attacker.get("is_ai"):
		return 1.0
	var k: float = attacker.get("progression").stat("vs_admiralty_pct")
	if k <= 0.0:
		return 1.0
	var lk = target.get("look")
	if not (lk is Dictionary):
		lk = target.get("appearance")
	return 1.0 + k if lk is Dictionary and lk.get("admiralty", false) else 1.0


static func label(key: String, v: float) -> String:
	var nm := str(LABELS.get(key, key))
	if key == "air_jumps":
		return "+%d %s" % [int(v), nm + ("s" if absf(v) > 1.0 else "")]
	if key in FLAT:
		return "%+d %s" % [int(v), nm]
	var pct := v * 100.0
	return ("%+d%% %s" if is_equal_approx(pct, roundf(pct)) else "%+.1f%% %s") % [pct, nm]


## The tooltip's stat lines (defence has its own row) against `cur`, the piece it would replace (null: none):
## [text, 1 good / -1 bad]. What `cur` has and this lacks shows as lost.
static func compare_lines(item: ItemData, cur: ItemData) -> Array:
	var out: Array = []
	var s := of(item)
	var c := of(cur) if cur and cur != item else {}
	for key in s.keys():
		if key == "defense":
			continue
		var v := float(s[key])
		var t := label(key, v)
		if c.has(key) and not is_equal_approx(float(c[key]), v):
			t += " (%s)" % label(key, v - float(c[key])).get_slice(" ", 0)
		elif not c.is_empty() and not c.has(key):
			t += " (new)"
		out.append([t, 1 if v > 0.0 else -1])
	for key in c.keys():
		if key != "defense" and not s.has(key):
			out.append(["lose " + label(key, float(c[key])).trim_prefix("+"), -1 if float(c[key]) > 0.0 else 1])
	return out


## Set `id`'s bonus as words.
static func bonus_text(id: String) -> String:
	var b: Dictionary = SETS[id]["bonus"]
	var parts: Array = []
	for key in b.keys():
		parts.append(label(key, float(b[key])))
	return ", ".join(parts)
