class_name Progression
extends Node
## The player's level, experience, weapon mastery and skill trees.
##
## You start at level 1 with no skills: just the basics (light/heavy attacks, dodge, parry, jump). Experience comes
## from combat (defeating enemies). Fighting with a weapon builds that weapon's mastery (1-30), and only that
## weapon's: a hit counts for the first HITS_PER_FOE hits on each foe, a kill gives MASTERY_KILL_SHARE of its
## experience (ELITE_SHARE times that for elites and bosses).
## The redesigned trees (SkillTrees, docs/progression_plan.md "Redesign"): big nodes come by themselves at their
## level, small stat steps are bought with the tree's points (one a level), a variant's versions are both owned and
## one is active, and passives count only in a passive slot. Steps, versions and talents are switched only at the
## ship's bunk (can_respec). A tree shows once its first point is earned (tree_found, with a banner).
## Trees not converted yet keep SkillTree's nodes and points (the Captain's skill points: 2 a level).
## Life skills (swimming, Seamanship, cooking, fishing) build mastery by doing, their perks at milestones.
## Active skills go on the skill bar (PowerComponent.loadout) and rank up through tiers by use.
## Each captain's own (a guest's lives and saves on the guest's machine).

signal xp_gained(amount: int, total: int)
signal leveled_up(level: int)
signal mastery_up(tree: String, level: int)
signal changed
signal tree_found(tree: String)

const MAX_LEVEL := 40
const SP_PER_LEVEL := 2
const MAX_MASTERY := 30
## Mastery xp for a hit with the weapon in your hand, for the first HITS_PER_FOE hits on each foe.
const MASTERY_PER_HIT := 4
const HITS_PER_FOE := 12
## The share of a kill's experience that goes to the weapon in your hand, times ELITE_SHARE for elites and bosses.
const MASTERY_KILL_SHARE := 0.25
const ELITE_SHARE := 3.0
## No family carry-over since 1.18.2 (only the old skill map still reads it).
const FAMILY_SHARE := 0.0
## Metres swum for a point of Swimming xp, and how often (ticks) the swim is measured.
const SWIM_M := 4.0
const SWIM_TICKS := 15
const PASSIVE_SLOTS := 3
## How close to the ship's bunk (m) steps, versions and talents can be switched.
const BUNK_REACH := 2.5
## Trees a new captain sees.
const FOUND_AT_START := ["captain", "sword"]
## Save format: 2 = per-tree points, mastery, tiers; 3 = families and life skills; 4 = the trimmed trees (older
## saves are refunded once); 5 = the redesign (steps, versions, passive slots, found trees; a converted tree's
## old purchases are dropped on every load and its points come back by themselves).
const FORMAT := 5

var player: Player
var level: int = 1
var xp: int = 0
var skill_points: int = 0
var owned: Dictionary = {}
## tree -> {"lv", "xp"}
var mastery: Dictionary = {}
## skill id -> tier (2+; a known skill without an entry is tier 1)
var tiers: Dictionary = {}
## skill id -> times cast
var uses: Dictionary = {}
## step node -> steps bought
var steps: Dictionary = {}
## variant or talent node -> the active version (a variant without an entry: 0; a talent: not picked)
var versions: Dictionary = {}
## The passive slots: node ids ("" empty), PASSIVE_SLOTS of them (a fourth at level 25).
var passives: Array[String] = ["", "", ""]
## tree -> true once its first point is earned (it shows in the menu)
var found: Dictionary = {}
## Will milestones earned (id -> true)
var will: Dictionary = {}
var _refunded: bool = false
## foe instance id -> hits that taught mastery
var _foe_hits: Dictionary = {}
var _swim_m: float = 0.0
var _swim_at := Vector3.INF


func _init() -> void:
	_reset_owned()
	for t in FOUND_AT_START:
		found[t] = true


func _ready() -> void:
	player = get_parent() as Player


func _physics_process(delta: float) -> void:
	if meal != "" and player and player.is_local:
		_tick_meal(delta)
	if kit_left > 0.0 and player and player.is_local:
		Downtime.tick_kit(self, delta)
	if Engine.get_physics_frames() % SWIM_TICKS != 0 or player == null or not player.is_local:
		return
	if player.current_state_name() != "Swim":
		_swim_at = Vector3.INF
		return
	var at := player.global_position
	if _swim_at != Vector3.INF:
		var d := Vector2(at.x - _swim_at.x, at.z - _swim_at.z).length()
		# (a teleport or a ride isn't swimming)
		if d < 0.25 * SWIM_TICKS:
			on_swim(d)
	_swim_at = at


func _reset_owned() -> void:
	owned = {}
	for k in SkillTree.starting_nodes():
		owned[k] = true
	_stat_n = -1


## Experience needed to go from `lv` to the next level (200 x lv^1.5): level 5,
## where the log pose wakes, takes ~3,400, about all Brinehollow and Redtide give.
static func xp_to_next(lv: int) -> int:
	return int(round(200.0 * pow(float(lv), 1.5)))


static func mastery_to_next(lv: int) -> int:
	return int(round(60.0 * pow(float(lv), 1.3)))


func add_xp(amount: int, at: Vector3 = Vector3.INF) -> void:
	if amount <= 0:
		return
	amount = int(round(amount * (1.0 + stat("xp_pct"))))
	if player:
		var share := MASTERY_KILL_SHARE * (ELITE_SHARE if _elite_at(at) else 1.0)
		add_mastery(SkillTree.style_tree(player.style()), int(round(amount * share)))
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
	_fit_passives()
	if player:
		player.call("_recalc_stats")
		var hc := player.health_component
		hc.heal(hc.max_health)
		player.stamina = player.max_stamina
		player.power.energy = player.power.max_energy()
		Net.fx("sparkle", [player.global_position + Vector3(0, 1.2, 0), 24, Color(1.0, 0.92, 0.5)])
		Net.fx("dust_ring", [player.global_position, 14, 0.9])
		UIStyle.sfx("level_up")
		get_tree().call_group("hud", "show_banner", "Level %d!" % level, "+%d skill points  -  press K to open the skill map" % SP_PER_LEVEL)
		SaveGame.save(player)
	leveled_up.emit(level)


## Did the kill at `at` fell an elite or a boss (one of the foes we struck, or a boss)?
func _elite_at(at: Vector3) -> bool:
	if at == Vector3.INF or not is_inside_tree():
		return false
	var foes: Array = get_tree().get_nodes_in_group("bosses")
	for id in _foe_hits.keys():
		if is_instance_id_valid(id):
			foes.append(instance_from_id(id))
	for e in foes:
		if not (e is Node3D) or not is_elite(e):
			continue
		var hc = e.get("health")
		var p := (e as Node3D).global_position
		if hc is HealthComponent and hc.current_health <= 0.0 and Vector2(p.x - at.x, p.z - at.z).length() < 6.0:
			return true
	return false


static func is_elite(e: Node) -> bool:
	return e.is_in_group("bosses") or e.get("captain") == true or e.get("brute") == true


# --------------------------------------------------------------------------
# Mastery
# --------------------------------------------------------------------------
func mastery_of(tree: String) -> Dictionary:
	if not mastery.has(tree):
		mastery[tree] = {"lv": 1, "xp": 0}
	return mastery[tree]


func mastery_level(tree: String) -> int:
	return int(mastery_of(tree)["lv"])


## A tree with a mastery track (a weapon, a life skill, an Adventure tree).
static func is_track(tree: String) -> bool:
	return SkillTree.is_mastery_tree(tree) or (SkillTrees.has_tree(tree) and tree != "captain")


static func tree_name(tree: String) -> String:
	return str(SkillTrees.tree_def(tree)["name"]) if SkillTrees.has_tree(tree) else str(SkillTree.TREES[tree]["name"])


func max_of(tree: String) -> int:
	return SkillTrees.max_level(tree) if SkillTrees.converted(tree) else MAX_MASTERY


## Mastery xp for a weapon or a life skill (only that tree's: no carry-over).
func add_mastery(tree: String, amount: int) -> void:
	if tree == "" or amount <= 0:
		return
	_gain(tree, amount)
	changed.emit()


func _gain(tree: String, amount: int) -> void:
	var m := mastery_of(tree)
	_find(tree)
	if int(m["lv"]) >= max_of(tree):
		return
	m["xp"] = int(m["xp"]) + amount
	var ups := 0
	while int(m["lv"]) < max_of(tree) and int(m["xp"]) >= mastery_to_next(int(m["lv"])):
		m["xp"] = int(m["xp"]) - mastery_to_next(int(m["lv"]))
		m["lv"] = int(m["lv"]) + 1
		ups += 1
	if int(m["lv"]) >= max_of(tree):
		m["xp"] = 0
	if ups == 0:
		return
	var perks := _sync_perks(tree)
	var got := _sync_tree(tree, false)
	_dirty()
	if player:
		var tname := tree_name(tree)
		if SkillTree.is_life_tree(tree) and not SkillTrees.converted(tree):
			var msg := "%s %d" % [tname, int(m["lv"])]
			for k in perks:
				var pn := SkillTree.get_node_def(k)
				msg += "  -  %s: %s" % [pn["name"], pn["desc"]]
			player.call("_toast", msg)
		else:
			var msg := "%s mastery %d" % [tname, int(m["lv"])]
			for k in got:
				msg += "  -  %s" % SkillTree.get_node_def(k)["name"]
			player.call("_toast", msg + "  -  +%d point%s (K)" % [ups, "" if ups == 1 else "s"])
		Net.fx("sparkle", [player.global_position + Vector3(0, 1.2, 0), 12, Color(0.75, 0.9, 1.0)])
	mastery_up.emit(tree, int(m["lv"]))


## Own every perk a life skill has reached; returns the ones just reached.
func _sync_perks(tree: String) -> Array:
	var got: Array = []
	if not SkillTree.is_life_tree(tree) or SkillTrees.converted(tree):
		return got
	for pk in SkillTree.perks_of(tree):
		if mastery_level(tree) >= int(pk[0]) and not owns(pk[1]):
			_own(pk[1])
			got.append(pk[1])
	return got


## A hit landed with the weapon in your hand on `target` (each foe teaches its first HITS_PER_FOE hits).
func on_hit(target: Node = null) -> void:
	if player == null:
		return
	if target:
		var id := target.get_instance_id()
		var n := int(_foe_hits.get(id, 0))
		if n >= HITS_PER_FOE:
			return
		if _foe_hits.size() > 128:
			for k in _foe_hits.keys():
				if not is_instance_id_valid(k):
					_foe_hits.erase(k)
		_foe_hits[id] = n + 1
	add_mastery(SkillTree.style_tree(player.style()), MASTERY_PER_HIT)


## Life skills learned by doing: Seamanship (Seamanship.xp), swimming (on_swim, measured
## here), and cooking and fishing (their systems call add_life).
func add_life(skill: String, amount: int) -> void:
	add_mastery(skill, amount)


func on_swim(metres: float) -> void:
	_swim_m += metres
	if _swim_m >= SWIM_M:
		var n := int(_swim_m / SWIM_M)
		_swim_m -= n * SWIM_M
		add_life("swim", n)


# --------------------------------------------------------------------------
# The redesigned trees (SkillTrees)
# --------------------------------------------------------------------------
## The trees of a section that show: found ones (the first point earned), and in "fruit" the fruit you ate.
func visible_trees(section: String) -> Array:
	return SkillTrees.trees_in(section).filter(func(t): return _visible(t))


func _visible(tree: String) -> bool:
	if SkillTrees.section_of(tree) == "fruit":
		return player != null and player.power.fruit == tree
	return found.has(tree)


func _find(tree: String) -> void:
	if found.has(tree) or not SkillTrees.has_tree(tree) or SkillTrees.section_of(tree) == "fruit":
		return
	found[tree] = true
	tree_found.emit(tree)
	if player and player.is_local and is_inside_tree():
		UIStyle.sfx("level_up")
		get_tree().call_group("hud", "show_banner", "New skill tree!", "%s  -  press K to see it" % tree_name(tree), true)


func tree_level(tree: String) -> int:
	return level if tree == "captain" else mastery_level(tree)


func tree_xp(tree: String) -> int:
	return xp if tree == "captain" else int(mastery_of(tree)["xp"])


## Xp from this level to the next (0 at the top).
func tree_xp_next(tree: String) -> int:
	if tree == "captain":
		return xp_to_next(level) if level < MAX_LEVEL else 0
	return mastery_to_next(tree_level(tree)) if tree_level(tree) < max_of(tree) else 0


## Points to buy steps with: one a level past the first, less the steps bought (old trees: their stored points).
func points_free(tree: String) -> int:
	if not SkillTrees.converted(tree):
		return points(tree)
	if tree == "captain":
		return 0
	var spent := 0
	for k in steps.keys():
		if SkillTrees.node_def(k)["tree"] == tree:
			spent += int(steps[k])
	return tree_level(tree) - 1 - spent


func steps_of(node: String) -> int:
	return int(steps.get(node, 0))


## Why a step can't be bought now ("" = it can).
func step_why(node: String) -> String:
	var n := SkillTrees.node_def(node)
	if n.is_empty() or n["kind"] != "step":
		return "Not a step"
	if steps_of(node) >= int(n["max_steps"]):
		return "Full"
	if points_free(str(n["tree"])) < 1:
		return "Needs a point (one every %s level)" % tree_name(str(n["tree"]))
	return ""


func buy_step(node: String) -> bool:
	if step_why(node) != "":
		return false
	steps[node] = steps_of(node) + 1
	_dirty()
	return true


## At the ship's bunk: every step of `tree` back as points.
func respec_steps(tree: String) -> bool:
	if not can_respec():
		return false
	for k in steps.keys():
		if SkillTrees.node_def(k)["tree"] == tree:
			steps.erase(k)
	_dirty()
	return true


## (the contract's has_node: Node already has one)
func owns_node(node: String) -> bool:
	if SkillTrees.node_def(node).get("kind", "") == "step":
		return steps_of(node) > 0
	return owns(node)


func version_of(node: String) -> int:
	return int(versions.get(node, -1 if SkillTrees.node_def(node).get("kind", "") == "talent" else 0))


## Make version `i` of an owned variant the active one (only at the ship's bunk).
func set_version(node: String, i: int) -> bool:
	var n := SkillTrees.node_def(node)
	if n.is_empty() or n["kind"] != "variant" or not owns(node) or i < 0 or i >= n["versions"].size():
		return false
	if int(n["versions"][i]["level"]) > tree_level(str(n["tree"])):
		return false
	if i == version_of(node):
		return true
	if not can_respec():
		return false
	_switch(node, i)
	return true


func _switch(node: String, i: int) -> void:
	var vs: Array = SkillTrees.node_def(node)["versions"]
	var was := version_of(node)
	var slot := -1
	if was >= 0:
		var old_sk := str(vs[was]["skill"])
		if old_sk != "" and player:
			slot = player.power.loadout.find(old_sk)
		owned.erase(vs[was]["id"])
		var at := passives.find(str(vs[was]["id"]))
		if at >= 0:
			passives[at] = ""
	versions[node] = i
	owned[node] = true
	_own(vs[i]["id"])
	if slot >= 0 and str(vs[i]["skill"]) != "":
		player.power.equip(str(vs[i]["skill"]), slot)
	_dirty()


## The Captain's talent at `lv` (5, 10 ... 40): the first pick anywhere once you're that level, a change only at the bunk.
func pick_talent(lv: int, i: int) -> bool:
	var node := talent_node(lv)
	if node == "" or lv > level or i < 0 or i >= SkillTrees.node_def(node)["versions"].size():
		return false
	var was := version_of(node)
	if was == i:
		return true
	if was >= 0 and not can_respec():
		return false
	_switch(node, i)
	return true


func talent_at(lv: int) -> int:
	var node := talent_node(lv)
	return -1 if node == "" else version_of(node)


func talent_node(lv: int) -> String:
	for k in SkillTrees.nodes_of("captain"):
		var n := SkillTrees.node_def(k)
		if n["kind"] == "talent" and int(n["level"]) == lv:
			return k
	return ""


func has_will(id: String) -> bool:
	return will.has(id)


## Standing by the ship's bunk: where steps, versions and talents are switched.
func can_respec() -> bool:
	if player == null or not player.is_inside_tree():
		return false
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	return ship != null and player.global_position.distance_to(ship.global_transform * Ship.BED_AT) < BUNK_REACH


func passive_slots() -> int:
	return PASSIVE_SLOTS + (1 if level >= 25 else 0)


func is_passive(id: String) -> bool:
	var n := SkillTree.get_node_def(id)
	return n.get("new", false) and n["kind"] == "passive"


## Put an owned passive in a slot ("" empties it; one already slotted moves).
func equip_passive(id: String, slot: int) -> bool:
	if slot < 0 or slot >= passives.size() or (id != "" and not (owns(id) and is_passive(id))):
		return false
	if id != "":
		var at := passives.find(id)
		if at >= 0:
			passives[at] = ""
	passives[slot] = id
	_dirty()
	return true


## Everything known: the active skills (for the bar) and the passives (for the slots).
func library() -> Dictionary:
	return {"skills": known_skills(), "passives": owned.keys().filter(func(k): return is_passive(k))}


func _fit_passives() -> void:
	var keep: Array[String] = []
	for p in passives:
		keep.append(p if owns(p) else "")
	keep.resize(passive_slots())
	passives = keep


## A converted tree's big nodes up to its level (a variant with its active version); returns the ones just granted.
func _sync_tree(tree: String, quiet: bool) -> Array:
	var got: Array = []
	if not SkillTrees.converted(tree):
		return got
	var lv := tree_level(tree)
	for k in SkillTrees.nodes_of(tree):
		var n := SkillTrees.node_def(k)
		if n["kind"] in ["step", "version", "talent", "will"] or int(n["level"]) > lv or owns(k):
			continue
		var id: String = k
		if n["kind"] == "variant":
			owned[k] = true
			id = str(n["versions"][version_of(k)]["id"])
		if quiet:
			owned[id] = true
		else:
			_own(id)
		got.append(id)
	return got


## Tests and render tools: every converted tree at its top level with every big node and every step.
func master_all() -> void:
	for t in SkillTrees.HEADERS.keys():
		if SkillTrees.converted(t) and t != "captain":
			mastery_of(t)["lv"] = max_of(t)
			mastery_of(t)["xp"] = 0
			_sync_tree(t, false)
			for k in SkillTrees.nodes_of(t):
				if SkillTrees.node_def(k)["kind"] == "step":
					steps[k] = int(SkillTrees.node_def(k)["max_steps"])
	_dirty()


func _dirty() -> void:
	_rev += 1
	if player:
		player.call("_recalc_stats")
	changed.emit()


# --------------------------------------------------------------------------
# Skill trees
# --------------------------------------------------------------------------
func owns(id: String) -> bool:
	return owned.has(id)


## Points to spend in a tree: a converted tree's free points, none for a life skill (its perks come by
## themselves), skill points for the rest.
func points(tree: String) -> int:
	if SkillTrees.converted(tree):
		return points_free(tree)
	if SkillTree.kind_of(tree) in ["life", "tab"]:
		return 0
	return skill_points


func _spend(n: int) -> void:
	skill_points -= n


func points_word(tree: String, n: int) -> String:
	var unit := "mastery point" if SkillTree.is_weapon_tree(tree) else "skill point"
	return "%d %s%s" % [n, unit, "" if n == 1 else "s"]


## Why a node can't be learned right now ("" = it can). A converted tree's big nodes come at their level, its
## steps are bought (learn buys one).
func can_learn(id: String) -> String:
	var n := SkillTree.get_node_def(id)
	if n.is_empty():
		return "Unknown"
	if n.get("new", false):
		if n["kind"] == "step":
			return step_why(id)
		return "Learned" if owns(id) else "Comes at %s %d" % [tree_name(str(n["tree"])), int(n["level"])]
	if owns(id):
		return "Learned"
	var req: Dictionary = n["req"]
	if n["kind"] == "perk":
		return "Comes at %s %d" % [SkillTree.TREES[n["tree"]]["name"], int(req["mastery"])]
	if req.has("fruit") and (player == null or player.power.fruit != str(req["fruit"])):
		return "Needs the %s" % str(DevilFruits.get_fruit(str(req["fruit"])).get("name", "fruit"))
	if req.has("level") and level < int(req["level"]):
		return "Needs level %d" % int(req["level"])
	if req.has("life") and mastery_level(str(req["life"])) < int(req["life_lv"]):
		return "Needs %s %d" % [SkillTree.TREES[req["life"]]["name"], int(req["life_lv"])]
	if req.has("node") and not owns(str(req["node"])):
		return "Needs %s" % str(SkillTree.get_node_def(str(req["node"]))["name"])
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
	if n.get("new", false):
		return buy_step(id)
	_spend(int(n["cost"]))
	_own(id)
	return true


func _own(id: String) -> void:
	owned[id] = true
	var n := SkillTree.get_node_def(id)
	var sk: String = n.get("skill", "")
	if sk != "" and player:
		player.power.auto_equip(sk)
	if is_passive(id) and not (id in passives) and passives.has(""):
		passives[passives.find("")] = id
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


## Sum of an effect over every owned node and bought step (asked several times a frame: remembered until
## something changes), and the meal you ate (Food). A redesigned tree's passive counts only in a passive slot.
func stat(key: String) -> float:
	if owned.size() != _stat_n or _rev != _stat_rev:
		_stat_n = owned.size()
		_stat_rev = _rev
		_stats.clear()
	if not _stats.has(key):
		var total := 0.0
		for k in owned.keys():
			var n := SkillTree.get_node_def(k)
			if n.get("new", false) and (n["kind"] == "step" or (n["kind"] == "passive" and not (k in passives))):
				continue
			var e: Dictionary = n.get("effects", {})
			if e.has(key):
				total += float(e[key])
		for k in steps.keys():
			var e: Dictionary = SkillTrees.node_def(k)["effects"]
			if e.has(key):
				total += float(e[key]) * int(steps[k])
		_stats[key] = total
	return _stats[key] + (Food.bonus(meal, key, meal_k) if meal != "" else 0.0) + (float(Downtime.KIT.get(key, 0.0)) if kit_left > 0.0 else 0.0)


# --------------------------------------------------------------------------
# Meals (Food): one buff at a time, on the captain's own machine
# --------------------------------------------------------------------------
signal meal_changed
var meal := ""
## Seconds of it left (game time), and its strength (Cooking's meal_power_pct when eaten).
var meal_left := 0.0
var meal_k := 1.0
## Recipes taught (Food.teach) and how often each dish was cooked.
var recipes: Dictionary = {}
var cooked: Dictionary = {}
## Sailing downtime (Downtime): the tinkered kit's seconds left (game time) and the activities' counts.
var kit_left := 0.0
var downtime: Dictionary = {}


func eat_meal(id: String) -> void:
	meal = ""
	var k := Food.strength(self)
	meal_left = Food.seconds(self, id)
	meal = id
	meal_k = k
	player.call("_recalc_stats")
	meal_changed.emit()


func _tick_meal(delta: float) -> void:
	meal_left -= delta
	if meal_left > 0.0:
		return
	meal = ""
	meal_left = 0.0
	player.call("_recalc_stats")
	meal_changed.emit()
	get_tree().call_group("hud", "show_toast", "Your meal's worn off")


var _stats: Dictionary = {}
var _stat_n: int = -1
var _rev: int = 0
var _stat_rev: int = -1


func has_flag(key: String) -> bool:
	return stat(key) > 0.0


## The weapon's element awakened (its tree's element nodes): tier 1 shows it on the tree's skills and ultimate,
## tier 2 on every blow as well.
func elemental(tree: String, tier: int = 1) -> bool:
	return has_flag(("elem_" if tier == 1 else "elem2_") + tree)


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
	if not SkillTrees.converted(tree):
		_spend(int(Skills.tier_def(skill_id, t)["cost"]))
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
		"mastery": mastery.duplicate(true), "tiers": tiers.duplicate(), "uses": uses.duplicate(),
		"steps": steps.duplicate(), "versions": versions.duplicate(), "passives": Array(passives), "found": found.keys(),
		"will": will.keys(), "meal": [meal, meal_left, meal_k], "recipes": recipes.keys(), "cooked": cooked.duplicate(),
		"kit": kit_left, "downtime": downtime.duplicate()}


func from_dict(d: Dictionary) -> void:
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	var ml: Array = d.get("meal", ["", 0.0, 1.0])
	meal = str(ml[0]) if Food.MEALS.has(str(ml[0])) else ""
	meal_left = float(ml[1])
	meal_k = float(ml[2])
	recipes = {}
	for k in d.get("recipes", []):
		recipes[str(k)] = true
	cooked = (d.get("cooked", {}) as Dictionary).duplicate()
	kit_left = float(d.get("kit", 0.0))
	downtime = (d.get("downtime", {}) as Dictionary).duplicate()
	_reset_owned()
	mastery = {}
	tiers = {}
	uses = {}
	steps = {}
	versions = {}
	will = {}
	_foe_hits = {}
	var fmt := int(d.get("format", 1))
	var ms: Dictionary = d.get("mastery", {})
	var gone := 0
	if fmt < 4:
		# the trees were reworked: every skill point and every weapon's mastery point
		# comes back once (mastery levels, uses, gold and gear stay)
		skill_points = (level - 1) * SP_PER_LEVEL + (1 if fmt >= 2 and level > 1 and Story.passed("vey_skills") else 0)
		for t in ms.keys():
			if is_track(str(t)):
				var lv := int(ms[t].get("lv", 1))
				mastery[str(t)] = {"lv": lv, "xp": int(ms[t].get("xp", 0))}
		if fmt >= 2:
			uses = (d.get("uses", {}) as Dictionary).duplicate()
	else:
		skill_points = int(d.get("sp", 0))
		for k in d.get("owned", []):
			if not SkillTree.get_node_def(str(k)).is_empty():
				owned[str(k)] = true
			else:
				gone += 1
		for t in ms.keys():
			if is_track(str(t)):
				mastery[str(t)] = (ms[t] as Dictionary).duplicate()
		tiers = (d.get("tiers", {}) as Dictionary).duplicate()
		uses = (d.get("uses", {}) as Dictionary).duplicate()
	var sd: Dictionary = d.get("steps", {})
	for k in sd.keys():
		var n := SkillTrees.node_def(str(k))
		if n.get("kind", "") == "step":
			steps[str(k)] = clampi(int(sd[k]), 0, int(n["max_steps"]))
	var vd: Dictionary = d.get("versions", {})
	for k in vd.keys():
		var n := SkillTrees.node_def(str(k))
		if n.get("kind", "") in ["variant", "talent"] and int(vd[k]) >= 0 and int(vd[k]) < n["versions"].size():
			versions[str(k)] = int(vd[k])
	for k in d.get("will", []):
		will[str(k)] = true
	found = {}
	for t in FOUND_AT_START + Array(d.get("found", [])):
		found[str(t)] = true
	for t in mastery.keys():
		if SkillTrees.has_tree(t) and (mastery_level(t) > 1 or int(mastery[t]["xp"]) > 0):
			found[t] = true
	passives.clear()
	for p in d.get("passives", []):
		passives.append(str(p))
	_refit_converted()
	for t in SkillTree.LIFE_SKILLS:
		for pk in SkillTree.perks_of(t):
			if mastery_level(t) >= int(pk[0]):
				owned[pk[1]] = true
	_fit_passives()
	_refunded = (fmt < FORMAT and (level > 1 or not ms.is_empty())) or gone > 0
	_rev += 1
	changed.emit()


## A converted tree's nodes come from its level: what an older save bought there is dropped and granted again
## by level, and its points (the level less the steps) come back by themselves.
func _refit_converted() -> void:
	for k in owned.keys():
		var n := SkillTrees.node_def(k)
		if not n.is_empty() and n["kind"] != "root":
			owned.erase(k)
	for t in SkillTrees.HEADERS.keys():
		_sync_tree(t, true)
		if SkillTrees.converted(t) and points_free(t) < 0:
			for k in steps.keys():
				if SkillTrees.node_def(k)["tree"] == t:
					steps.erase(k)


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
		for p in library()["passives"]:
			if passives.has("") and not (p in passives):
				passives[passives.find("")] = p
		_rev += 1
		get_tree().call_group("hud", "show_banner", "The skill trees are new!",
			"Every reworked tree's points are back, and its moves come with mastery - press K to see", true)
