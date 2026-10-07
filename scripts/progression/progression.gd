class_name Progression
extends Node
## The player's level, experience, weapon mastery and skill trees.
##
## You start at level 1 with no skills: just the basics (light/heavy attacks,
## dodge, parry, jump). Experience comes from combat (defeating enemies); each
## level gives 2 skill points for the Base & Haki and Devil Fruit trees.
## Fighting with a weapon builds that weapon's mastery: every mastery level is a
## point for its own tree (SkillTree). Active skills go on the skill bar
## (PowerComponent.loadout) and rank up through tiers: using one opens its next
## tier, then the tier costs points from its tree.

signal xp_gained(amount: int, total: int)
signal leveled_up(level: int)
signal mastery_up(tree: String, level: int)
signal changed

const MAX_LEVEL := 40
const SP_PER_LEVEL := 2
const MAX_MASTERY := 30
## Mastery xp for every hit you land with a weapon, and the share of a kill's
## experience that goes to the weapon in your hand.
const MASTERY_PER_HIT := 4
const MASTERY_KILL_SHARE := 0.25
## Save format: 2 = per-tree points, mastery, tiers (older saves are refunded).
const FORMAT := 2

var player: Player
var level: int = 1
var xp: int = 0
var skill_points: int = 0
var owned: Dictionary = {}
## tree -> {"lv", "xp", "pts"}
var mastery: Dictionary = {}
## skill id -> tier (2+; a known skill without an entry is tier 1)
var tiers: Dictionary = {}
## skill id -> times cast
var uses: Dictionary = {}
var _refunded: bool = false


func _init() -> void:
	_reset_owned()


func _ready() -> void:
	player = get_parent() as Player


func _reset_owned() -> void:
	owned = {}
	for k in SkillTree.starting_nodes():
		owned[k] = true
	_stat_n = -1


## Experience needed to go from `lv` to the next level (100 x lv^1.3: was 50,
## which levelled twice as fast as it should).
static func xp_to_next(lv: int) -> int:
	return int(round(100.0 * pow(float(lv), 1.3)))


static func mastery_to_next(lv: int) -> int:
	return int(round(60.0 * pow(float(lv), 1.3)))


func add_xp(amount: int, at: Vector3 = Vector3.INF) -> void:
	if amount <= 0:
		return
	if player:
		add_mastery(SkillTree.style_tree(player.style()), int(round(amount * MASTERY_KILL_SHARE)))
	if level >= MAX_LEVEL:
		return
	xp += amount
	xp_gained.emit(amount, xp)
	if at != Vector3.INF:
		Net.fx("float_text", [at, "+%d XP" % amount, Color(0.75, 0.9, 1.0)])
	var ups := 0
	while level < MAX_LEVEL and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		skill_points += SP_PER_LEVEL
		ups += 1
	if level >= MAX_LEVEL:
		xp = 0
	if ups > 0:
		_on_level_up()
	changed.emit()


func _on_level_up() -> void:
	if player:
		player.call("_recalc_stats")
		var hc := player.health_component
		hc.heal(hc.max_health)
		player.stamina = player.max_stamina
		player.power.energy = player.power.max_energy()
		Net.fx("sparkle", [player.global_position + Vector3(0, 1.2, 0), 24, Color(1.0, 0.92, 0.5)])
		Net.fx("dust_ring", [player.global_position, 14, 0.9])
		Net.fx("sfx", ["coin", player.global_position, 0.0, 0.0, 0.75])
		get_tree().call_group("hud", "show_banner", "Level %d!" % level, "+%d skill points  -  press K to open the skill map" % SP_PER_LEVEL, true)
		SaveGame.save(player)
	leveled_up.emit(level)


# --------------------------------------------------------------------------
# Weapon mastery
# --------------------------------------------------------------------------
func mastery_of(tree: String) -> Dictionary:
	if not mastery.has(tree):
		mastery[tree] = {"lv": 1, "xp": 0, "pts": 0}
	return mastery[tree]


func mastery_level(tree: String) -> int:
	return int(mastery_of(tree)["lv"])


func add_mastery(tree: String, amount: int) -> void:
	if tree == "" or amount <= 0:
		return
	var m := mastery_of(tree)
	if int(m["lv"]) >= MAX_MASTERY:
		return
	m["xp"] = int(m["xp"]) + amount
	var ups := 0
	while int(m["lv"]) < MAX_MASTERY and int(m["xp"]) >= mastery_to_next(int(m["lv"])):
		m["xp"] = int(m["xp"]) - mastery_to_next(int(m["lv"]))
		m["lv"] = int(m["lv"]) + 1
		m["pts"] = int(m["pts"]) + 1
		ups += 1
	if int(m["lv"]) >= MAX_MASTERY:
		m["xp"] = 0
	if ups > 0:
		if player:
			Net.fx("sparkle", [player.global_position + Vector3(0, 1.2, 0), 12, Color(0.75, 0.9, 1.0)])
			player.call("_toast", "%s mastery %d  -  +%d point%s (K)" % [SkillTree.TREES[tree]["name"], int(m["lv"]), ups, "" if ups == 1 else "s"])
		mastery_up.emit(tree, int(m["lv"]))
	changed.emit()


## A hit landed with the weapon in your hand.
func on_hit() -> void:
	if player:
		add_mastery(SkillTree.style_tree(player.style()), MASTERY_PER_HIT)


# --------------------------------------------------------------------------
# Skill trees
# --------------------------------------------------------------------------
func owns(id: String) -> bool:
	return owned.has(id)


## Points to spend in a tree: its mastery points for a weapon tree, skill
## points for the rest.
func points(tree: String) -> int:
	if SkillTree.is_mastery_tree(tree):
		return int(mastery_of(tree)["pts"])
	return skill_points


func _spend(tree: String, n: int) -> void:
	if SkillTree.is_mastery_tree(tree):
		var m := mastery_of(tree)
		m["pts"] = int(m["pts"]) - n
	else:
		skill_points -= n


func points_word(tree: String, n: int) -> String:
	var unit := "mastery point" if SkillTree.is_mastery_tree(tree) else "skill point"
	return "%d %s%s" % [n, unit, "" if n == 1 else "s"]


## Why a node can't be learned right now ("" = it can).
func can_learn(id: String) -> String:
	var n := SkillTree.get_node_def(id)
	if n.is_empty():
		return "Unknown"
	if owns(id):
		return "Learned"
	var req: Dictionary = n["req"]
	if req.has("fruit") and (player == null or player.power.fruit != str(req["fruit"])):
		return "Needs the %s" % str(DevilFruits.get_fruit(str(req["fruit"])).get("name", "fruit"))
	if req.has("level") and level < int(req["level"]):
		return "Needs level %d" % int(req["level"])
	var linked := false
	for l in SkillTree.neighbors(id):
		if owns(l):
			linked = true
			break
	if not linked:
		return "Learn a linked node first"
	var tree := str(n["tree"])
	if points(tree) < int(n["cost"]):
		return "Needs %s" % points_word(tree, int(n["cost"]))
	return ""


func learn(id: String) -> bool:
	if can_learn(id) != "":
		return false
	var n := SkillTree.get_node_def(id)
	_spend(str(n["tree"]), int(n["cost"]))
	_own(id)
	return true


func _own(id: String) -> void:
	owned[id] = true
	var n := SkillTree.get_node_def(id)
	var sk: String = n.get("skill", "")
	if sk != "" and player:
		player.power.auto_equip(sk)
	if player:
		player.call("_recalc_stats")
	changed.emit()


## A Devil Fruit's root and starting skills come free when you eat it.
func grant_fruit(fruit_id: String) -> void:
	for k in SkillTree.nodes().keys():
		var n: Dictionary = SkillTree.nodes()[k]
		if str(n["req"].get("fruit", "")) == fruit_id and (n["kind"] == "root" or int(n["cost"]) == 0):
			if not owns(k):
				_own(k)


## Sum of an effect over every owned node (asked several times a frame:
## remembered until the owned set changes).
func stat(key: String) -> float:
	if owned.size() != _stat_n:
		_stat_n = owned.size()
		_stats.clear()
	if _stats.has(key):
		return _stats[key]
	var total := 0.0
	for k in owned.keys():
		var e: Dictionary = SkillTree.get_node_def(k).get("effects", {})
		if e.has(key):
			total += float(e[key])
	_stats[key] = total
	return total


var _stats: Dictionary = {}
var _stat_n: int = -1


func has_flag(key: String) -> bool:
	return stat(key) > 0.0


## A part of a weapon's moveset unlocked on its tree ("move" nodes).
func has_move(move: String) -> bool:
	return has_flag("mv_" + move)


## A weapon tree's stat for the style you're fighting with (dmg / stam / flow).
func style_stat(prefix: String, style: String) -> float:
	var tree := SkillTree.style_tree(style)
	return stat(prefix + "_" + tree) if tree != "" else 0.0


## Active skills you've learned (for the loadout).
func known_skills() -> Array:
	var out: Array = []
	for k in owned.keys():
		var sk: String = SkillTree.get_node_def(k).get("skill", "")
		if sk != "":
			out.append(sk)
	return out


func knows(skill_id: String) -> bool:
	return skill_id in known_skills()


# --------------------------------------------------------------------------
# Ability tiers
# --------------------------------------------------------------------------
func skill_tier(skill_id: String) -> int:
	if not knows(skill_id):
		return 0
	return int(tiers.get(skill_id, 1))


func uses_of(skill_id: String) -> int:
	return int(uses.get(skill_id, 0))


func note_use(skill_id: String) -> void:
	uses[skill_id] = uses_of(skill_id) + 1
	var nt := Skills.tier_def(skill_id, skill_tier(skill_id) + 1)
	if not nt.is_empty() and uses_of(skill_id) == int(nt["uses"]) and player:
		player.call("_toast", "%s can rank up: %s (K)" % [Skills.get_skill(skill_id)["name"], nt["name"]])
	changed.emit()


## Why a skill can't go up a tier right now ("" = it can).
func can_rank_up(skill_id: String) -> String:
	var t := skill_tier(skill_id)
	if t == 0:
		return "Learn it first"
	if t >= Skills.max_tier(skill_id):
		return "Mastered"
	var nt := Skills.tier_def(skill_id, t + 1)
	if uses_of(skill_id) < int(nt["uses"]):
		return "Use it %d more time%s" % [int(nt["uses"]) - uses_of(skill_id), "" if int(nt["uses"]) - uses_of(skill_id) == 1 else "s"]
	var tree := str(SkillTree.get_node_def(SkillTree.node_for_skill(skill_id))["tree"])
	if points(tree) < int(nt["cost"]):
		return "Needs %s" % points_word(tree, int(nt["cost"]))
	return ""


func rank_up(skill_id: String) -> bool:
	if can_rank_up(skill_id) != "":
		return false
	var t := skill_tier(skill_id) + 1
	var tree := str(SkillTree.get_node_def(SkillTree.node_for_skill(skill_id))["tree"])
	_spend(tree, int(Skills.tier_def(skill_id, t)["cost"]))
	tiers[skill_id] = t
	if player:
		player.call("_recalc_stats")
	changed.emit()
	return true


# --------------------------------------------------------------------------
# Save / load
# --------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {"format": FORMAT, "level": level, "xp": xp, "sp": skill_points, "owned": owned.keys(),
		"mastery": mastery.duplicate(true), "tiers": tiers.duplicate(), "uses": uses.duplicate()}


func from_dict(d: Dictionary) -> void:
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	_reset_owned()
	mastery = {}
	tiers = {}
	uses = {}
	_refunded = int(d.get("format", 1)) < FORMAT and level > 1
	if int(d.get("format", 1)) < FORMAT:
		# the skill map was reworked into separate trees: every point comes back
		skill_points = (level - 1) * SP_PER_LEVEL
	else:
		skill_points = int(d.get("sp", 0))
		for k in d.get("owned", []):
			if not SkillTree.get_node_def(str(k)).is_empty():
				owned[str(k)] = true
		var ms: Dictionary = d.get("mastery", {})
		for t in ms.keys():
			if SkillTree.is_mastery_tree(str(t)):
				mastery[str(t)] = (ms[t] as Dictionary).duplicate()
		tiers = (d.get("tiers", {}) as Dictionary).duplicate()
		uses = (d.get("uses", {}) as Dictionary).duplicate()
	_stat_n = -1
	changed.emit()


## After the power component has loaded too: give back the fruit's free nodes
## and clear bar slots holding skills you no longer know (a refunded save).
func after_load() -> void:
	if player.power.has_fruit():
		grant_fruit(player.power.fruit)
	for i in range(PowerComponent.SLOTS):
		var sk := player.power.loadout[i]
		if sk != "" and not knows(sk):
			player.power.equip("", i)
	player.call("_recalc_stats")
	if _refunded:
		_refunded = false
		get_tree().call_group("hud", "show_banner", "New skill trees!",
			"Your %d skill points are back - press K to spend them" % skill_points, true)
