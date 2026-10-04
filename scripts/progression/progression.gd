class_name Progression
extends Node
## The player's level, experience and skill map.
##
## You start at level 1 with no skills: just the basics (light/heavy attacks,
## dodge, parry, jump). Experience comes from combat (defeating enemies); each
## level gives 2 skill points to spend on the skill map (SkillTree), where
## stat nodes, passives and active skills live. Learned active skills go on the
## skill bar (PowerComponent.loadout).

signal xp_gained(amount: int, total: int)
signal leveled_up(level: int)
signal changed

const MAX_LEVEL := 40
const SP_PER_LEVEL := 2

var player: Player
var level: int = 1
var xp: int = 0
var skill_points: int = 0
var owned: Dictionary = {"origin": true}


func _ready() -> void:
	player = get_parent() as Player


## Experience needed to go from `lv` to the next level.
static func xp_to_next(lv: int) -> int:
	return int(round(50.0 * pow(float(lv), 1.3)))


func add_xp(amount: int, at: Vector3 = Vector3.INF) -> void:
	if amount <= 0 or level >= MAX_LEVEL:
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
# Skill map
# --------------------------------------------------------------------------
func owns(id: String) -> bool:
	return owned.has(id)


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
	if skill_points < int(n["cost"]):
		return "Needs %d skill point%s" % [int(n["cost"]), "" if int(n["cost"]) == 1 else "s"]
	return ""


func learn(id: String) -> bool:
	if can_learn(id) != "":
		return false
	var n := SkillTree.get_node_def(id)
	skill_points -= int(n["cost"])
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


## Sum of an effect over every owned node.
func stat(key: String) -> float:
	var total := 0.0
	for k in owned.keys():
		var e: Dictionary = SkillTree.get_node_def(k).get("effects", {})
		if e.has(key):
			total += float(e[key])
	return total


func has_flag(key: String) -> bool:
	return stat(key) > 0.0


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
# Save / load
# --------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {"level": level, "xp": xp, "sp": skill_points, "owned": owned.keys()}


func from_dict(d: Dictionary) -> void:
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	skill_points = int(d.get("sp", 0))
	owned = {"origin": true}
	for k in d.get("owned", []):
		if not SkillTree.get_node_def(str(k)).is_empty():
			owned[str(k)] = true
	changed.emit()
