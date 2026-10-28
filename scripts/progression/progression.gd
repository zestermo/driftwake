class_name Progression
extends Node
## The player's level, experience, weapon mastery and skill trees.
##
## You start at level 1 with no skills: just the basics (light/heavy attacks, dodge, parry, jump). Experience comes
## from combat (defeating enemies). Fighting with a weapon builds that weapon's mastery (1-30), and only that
## weapon's: a hit counts for the first HITS_PER_FOE hits on each foe, a kill gives MASTERY_KILL_SHARE of its
## experience (ELITE_SHARE times that for elites and bosses).
## The trees (SkillTrees; points model of docs/v1_18_4_plan.md, per tree since 1.23): each weapon tree and the eaten
## fruit earn their own points as their mastery rises (tree_earned) and spend them only on themselves; Adventure
## points, one a level any Adventure tree gains, buy any Adventure tree's. Captain levels give stats and the Captain
## tree. Everything past a root is bought (buy, buy_why); a tree's level only gates it. A variant's versions are both
## owned and one is active, and passives count only in a passive slot. Versions and talents are switched at a rest
## spot (can_respec), and a tree's purchases come back there for gold (respec_tree). A tree shows once its first xp is
## earned (tree_found, with the HUD's card).
## The Captain: every level adds SkillTrees.GROWTH by itself (in stat()), milestones come at their level (a loadout,
## passive slots), a talent is picked every 5 levels. Will (WillPaths): points from big fights (will_deed) and
## meditation (meditate) buy a path's versions and passive; the captain's Will colour (will_color). A fruit's level-1
## powers come with eating it.
## Active skills go on the skill bar (PowerComponent.loadout) and rank up through tiers by use alone.
## Each captain's own (a guest's lives and saves on the guest's machine).

signal xp_gained(amount: int, total: int)
signal leveled_up(level: int)
signal mastery_up(tree: String, level: int)
signal changed
signal tree_found(tree: String)

const MAX_LEVEL := 40
const MAX_MASTERY := 30
## Mastery xp for a hit with the weapon in your hand, for the first HITS_PER_FOE hits on each foe.
const MASTERY_PER_HIT := 4
const HITS_PER_FOE := 12
## The share of a kill's experience that goes to the weapon in your hand, times ELITE_SHARE for elites and bosses.
const MASTERY_KILL_SHARE := 0.25
const ELITE_SHARE := 3.0
## Fruit mastery for each cast of one of its powers (and the Wolf's claws learn like a weapon in hand).
const FRUIT_PER_CAST := 6
## Stealth: SNEAK_XP for each SNEAK_M metres sneaked with a foe within SNEAK_NEAR m; a blow struck within
## AMBUSH_TICKS of sneaking is a sneak attack worth AMBUSH_XP.
const SNEAK_M := 4.0
const SNEAK_NEAR := 20.0
const SNEAK_XP := 3
const AMBUSH_TICKS := 45
const AMBUSH_XP := 10
## No family carry-over since 1.18.2 (only the old skill map still reads it).
const FAMILY_SHARE := 0.0
## Metres swum for a point of Swimming xp, and how often (ticks) the swim is measured.
const SWIM_M := 4.0
const SWIM_TICKS := 15
## Passive slots at the start; the Captain's milestones add one at 10, 20 and 30 (5 at most).
const PASSIVE_SLOTS := 2
## How close to the ship's bunk (m) steps, versions and talents can be switched.
const BUNK_REACH := 2.5
## How close to a rest spot (an inn's, the bunk's interactable) builds can be switched.
const REST_REACH := 3.5
## Trees a new captain sees.
const FOUND_AT_START := ["captain", "sword"]
## Save format: 2 = per-tree points, mastery, tiers; 3 = families and life skills; 4 = the trimmed trees (older
## saves are refunded once); 5 = the redesign (steps, versions, passive slots, found trees); 6 = the two pools
## (bought nodes; an older save's nodes and steps are bought back while the pools afford them, the rest refunded);
## 7 = points per weapon tree (an older save's weapon and fruit purchases refunded, Adventure's bought back); 8 = Will
## paths (an older save's Wills come back as Will points; Squall Step and Ballast to buy in Acrobatics and Defense).
const FORMAT := 8
## Respec at the bunk: RESPEC_GOLD + RESPEC_PER_LEVEL x the Captain's level, a tree.
const RESPEC_GOLD := 100
const RESPEC_PER_LEVEL := 40

var player: Player
var level: int = 1
var xp: int = 0
## Always 0 since 1.18.2 (no skill points); the old skill map, inventory and skill bar still read it.
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
## big node -> true, bought with its pool's points
var bought: Dictionary = {}
## variant or talent node -> the active version (a variant without an entry: 0; a talent: not picked)
var versions: Dictionary = {}
## The passive slots: node ids ("" empty), passive_slots() of them.
var passives: Array[String] = ["", ""]
## tree -> true once its first point is earned (it shows in the menu)
var found: Dictionary = {}
## Edy points earned (big fights, meditation; spent ones are the Will paths' nodes in `bought`), and the captain's Edy
## type (EdyTypes; "" until a master reads it).
var will_earned: int = 0
var will_color: String = ""
## An older save was bought back on load (after_load's banner), and its weapon purchases refunded (format 7).
var _migrated: bool = false
var _refunded: bool = false
## Will points an older save's Wills came back as (format 8's banner).
var _will_back := 0
## Tests and render tools (master_all): points given on top of the earned ones, so the pools read 0.
var _gift: Dictionary = {}
var _spend_rev := -1
var _spend: Dictionary = {}
var _wind_used := false
var _sneak_frame := -AMBUSH_TICKS
var _sneak_m := 0.0
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
	# (Edy: a master's questions are answered here, on the captain's own machine)
	if not Dialogue.dialogue_event.is_connected(_on_edy_event):
		Dialogue.dialogue_event.connect(_on_edy_event)
	Dialogue.register_token("edy_read", func(): return str(EdyTypes.info(_local_edy()).get("read", "")))
	Dialogue.register_token("edy_says", func(): return "Your Edy is %s. %s" % [EdyTypes.name_of(_local_edy()), EdyTypes.info(_local_edy()).get("says", "")])
	Dialogue.register_token("edy_price", func(): return str(EdyTypes.REREAD_GOLD))


## The local captain's Edy type (the tokens ask whoever's talking).
func _local_edy() -> String:
	var lp := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	return str(lp.progression.will_color) if lp and lp.get("progression") else will_color


## The quiz's answers so far (type -> count) and the last answer's types.
var _edy_counts := {}
var _edy_last: Array = []


## Edy events from a master's talk (EdyTypes.quiz_nodes): "edy:reset" a fresh reading, "edy:+<types>" an answer,
## "edy:read" the type read from them; the capital's re-reading pays EdyTypes.REREAD_GOLD as it happens: "edy:reread"
## (read from the answers) or "edy:buy:<type>" (one named outright).
func _on_edy_event(ev: String) -> void:
	if not ev.begins_with("edy:") or player == null or not player.is_local:
		return
	var what := ev.substr(4)
	if what == "reset":
		_edy_counts = {}
		_edy_last = []
	elif what.begins_with("+"):
		_edy_last = Array(what.substr(1).split(","))
		for id in _edy_last:
			_edy_counts[id] = int(_edy_counts.get(id, 0)) + 1
	elif what == "read" or what == "reread":
		var t := EdyTypes.winner(_edy_counts, _edy_last)
		if t != "" and (what == "read" or _pay_reread()):
			attune(t)
	elif what.begins_with("buy:"):
		if EdyTypes.TYPES.has(what.substr(4)) and _pay_reread():
			attune(what.substr(4))


## The capital's re-reading paid (false: not enough gold, nothing taken).
func _pay_reread() -> bool:
	var inv := player.inventory_component
	var gold := ItemDB.get_item("gold")
	if gold == null or inv.count("gold") < EdyTypes.REREAD_GOLD:
		return false
	return inv.remove_item(gold, EdyTypes.REREAD_GOLD)


## Attuned to Edy type `id`: its colour on every Edy effect and its edge (a burst in it for everyone to see).
func attune(id: String) -> bool:
	if not EdyTypes.TYPES.has(id):
		return false
	will_color = id
	_dirty()
	changed.emit()
	if player and player.is_inside_tree():
		EdyTypes.burst(player, 1.4)
		get_tree().call_group("hud", "show_banner", "%s Edy" % EdyTypes.name_of(id), str(EdyTypes.info(id)["says"]), true)
	return true


func _physics_process(delta: float) -> void:
	if meal != "" and player and player.is_local:
		_tick_meal(delta)
	if kit_left > 0.0 and player and player.is_local:
		Downtime.tick_kit(self, delta)
	if Engine.get_physics_frames() % SWIM_TICKS != 0 or player == null or not player.is_local:
		return
	if has_flag("second_wind"):
		_second_wind()
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
	for t in SkillTrees.HEADERS.keys():
		if SkillTrees.section_of(t) != "fruit":
			owned[SkillTrees.tree_def(t)["root"]] = true
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
		var foe := _fallen_at(at)
		var share := MASTERY_KILL_SHARE * (ELITE_SHARE if foe and is_elite(foe) else 1.0)
		add_mastery(hand_tree(), int(round(amount * share)))
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
		ups += 1
	if level >= MAX_LEVEL:
		xp = 0
	if ups > 0:
		_on_level_up()
	changed.emit()


func _on_level_up() -> void:
	var got := _sync_tree("captain", false)
	_fit_passives()
	_dirty()
	if player:
		var hc := player.health_component
		hc.heal(hc.max_health)
		player.stamina = player.max_stamina
		player.power.energy = player.power.max_energy()
		Net.fx("sparkle", [player.global_position + Vector3(0, 1.2, 0), 24, Color(1.0, 0.92, 0.5)])
		Net.fx("dust_ring", [player.global_position, 14, 0.9])
		UIStyle.sfx("level_up")
		var sub := "Stronger: more health, damage, stamina, energy and defense"
		if not got.is_empty():
			sub = ", ".join(got.map(func(k): return str(SkillTrees.node_def(k)["name"]))) + " - yours now"
		if perk_waiting():
			sub += "  -  a perk to pick (K: Captain, Perks)"
		get_tree().call_group("hud", "show_banner", "Level %d!" % level, sub)
		SaveGame.save(player)
	leveled_up.emit(level)


## The foe that fell where the kill's xp came from (`at`): one we struck, a boss, a Sea King or the fort's
## captain; null for none.
func _fallen_at(at: Vector3) -> Node3D:
	if at == Vector3.INF or not is_inside_tree():
		return null
	var foes: Array = get_tree().get_nodes_in_group("bosses") + get_tree().get_nodes_in_group("sea_kings")
	var fort := get_tree().get_first_node_in_group("forts")
	if fort and is_instance_valid(fort.get("boss")):
		foes.append(fort.get("boss"))
	for id in _foe_hits.keys():
		if is_instance_id_valid(id):
			foes.append(instance_from_id(id))
	for e in foes:
		if not (e is Node3D) or not e.has_method("is_dead") or not e.is_dead():
			continue
		var p := (e as Node3D).global_position
		if Vector2(p.x - at.x, p.z - at.z).length() < (60.0 if e.is_in_group("sea_kings") else 6.0):
			return e
	return null


static func is_elite(e: Node) -> bool:
	return e.is_in_group("bosses") or e.is_in_group("sea_kings") or e.is_in_group("rivals") or e.get("captain") == true or e.get("brute") == true


## A big fight won near us (Net.bounty's kind and scale, on our own machine): its Will points (WillPaths.SOURCES; a
## "boss" at under full scale is a miniboss or a roamer). Kinds that give none are ignored.
func will_deed(kind: String, k: float = 1.0) -> void:
	if kind == "boss" and k < 1.0:
		kind = "miniboss"
	if WillPaths.SOURCES.has(kind):
		will_point(int(WillPaths.SOURCES[kind]), kind)


## `n` Will points earned (`why`: the deed, or "meditation").
func will_point(n: int, why: String) -> void:
	will_earned += n
	_dirty()
	if player and player.is_local and is_inside_tree():
		if will_color == "":
			get_tree().call_group("hud", "show_toast", "+%d Edy (%s)  -  Hana at Brinehollow's teahouse can read it" % [n, why])
		else:
			get_tree().call_group("hud", "show_toast", "+%d Edy (%s)  -  %d to spend  (K: Captain)" % [n, why, pool("will")])
		Net.fx("sparkle", [player.global_position + Vector3(0, 1.2, 0), 18, will_tint()])


## Meditation (Downtime "meditate"): `secs` of game time meditated; every WillPaths.MEDITATE_SECS is a Will point.
## Returns the share of the next point done (0..1).
func meditate(secs: float) -> float:
	var s := float(downtime.get("meditate_s", 0.0)) + secs
	while s >= WillPaths.MEDITATE_SECS:
		s -= WillPaths.MEDITATE_SECS
		will_point(1, "meditation")
	downtime["meditate_s"] = s
	return s / WillPaths.MEDITATE_SECS


## The captain's Edy colour (every Edy effect, on every screen).
func will_tint() -> Color:
	return EdyTypes.color_of(will_color)


## Attuned (tests and tools; in play a master reads it: attune).
func set_will_color(id: String) -> bool:
	return attune(id)


func _second_wind() -> void:
	if not player.in_fight():
		_wind_used = false
		return
	var hc := player.health_component
	if _wind_used or hc.current_health <= 0.0 or hc.current_health >= hc.max_health * 0.3:
		return
	_wind_used = true
	player.stamina = player.max_stamina
	player.power.energy = player.power.max_energy()
	player.call("_toast", "Second Wind!")
	Net.fx("sparkle", [player.global_position + Vector3(0, 1.2, 0), 16, Color(0.6, 1.0, 0.8)])


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
	return SkillTrees.has_tree(tree) and tree != "captain"


static func tree_name(tree: String) -> String:
	return str(SkillTrees.tree_def(tree)["name"])


func max_of(tree: String) -> int:
	return SkillTrees.max_level(tree) if SkillTrees.has_tree(tree) else MAX_MASTERY


## Mastery xp for a weapon or a life skill (only that tree's: no carry-over; Quick Learner's mastery_pct on top).
func add_mastery(tree: String, amount: int) -> void:
	if tree == "" or amount <= 0:
		return
	_gain(tree, int(round(amount * (1.0 + stat("mastery_pct")))))
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
	var lv := int(m["lv"])
	_sync_tree(tree, false)
	_dirty()
	if player:
		var msg := "%s %s%d" % [tree_name(tree), "mastery " if SkillTrees.section_of(tree) == "combat" else "", lv]
		var opens: Array = SkillTrees.nodes_of(tree).filter(func(k):
			var n := SkillTrees.node_def(k)
			return SkillTrees.price(k) > 0 and n["kind"] != "step" and int(n["level"]) > lv - ups and int(n["level"]) <= lv)
		if not opens.is_empty():
			msg += "  -  opens " + ", ".join(opens.slice(0, 2).map(func(k): return str(SkillTrees.node_def(k)["name"])))
		if SkillTrees.pool_of(tree) != "" and can_spend(SkillTrees.pool_of(tree)):
			msg += "  -  " + points_line(SkillTrees.pool_of(tree))
		player.call("_toast", msg)
		Net.fx("sparkle", [player.global_position + Vector3(0, 1.2, 0), 12, Color(0.75, 0.9, 1.0)])
	mastery_up.emit(tree, int(m["lv"]))


## A hit landed with the weapon in your hand on `target` (each foe teaches its first HITS_PER_FOE hits), and
## Bounty Hunter's share of `hit` again on an elite or a boss.
func on_hit(target: Node = null, hit: HitData = null) -> void:
	if player == null:
		return
	var extra_k := stat("bounty_pct") if target and is_elite(target) else 0.0
	if player.power.buff("coat"):
		extra_k += stat("coat_dmg")
	if Engine.get_physics_frames() - _sneak_frame < AMBUSH_TICKS:
		_sneak_frame = -AMBUSH_TICKS
		extra_k += stat("ambush_pct")
		add_life("stealth", AMBUSH_XP)
	if hit and target and extra_k > 0.0 and not hit.dot:
		var hb := target.get("hurtbox") as Hurtbox
		if hb:
			var extra := HitData.new()
			extra.dot = true
			extra.damage = roundf(hit.damage * extra_k)
			hb.take_hit(extra, player)
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
	add_mastery(hand_tree(), MASTERY_PER_HIT)


## CrouchState's tick: sneaking, `metres` moved. Every SNEAK_M metres with a foe within SNEAK_NEAR teaches Stealth,
## and a blow struck within AMBUSH_TICKS of it is a sneak attack (on_hit: Ambush's damage and more Stealth).
func sneak(metres: float) -> void:
	_sneak_frame = Engine.get_physics_frames()
	_sneak_m += metres
	if _sneak_m < SNEAK_M:
		return
	_sneak_m = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_dead() and (e as Node3D).global_position.distance_to(player.global_position) < SNEAK_NEAR:
			add_life("stealth", SNEAK_XP)
			return


## Sergeant Vey's drill (his story step): a level of mastery for the weapon in hand.
func drill() -> void:
	var t := hand_tree()
	if t != "":
		add_mastery(t, mastery_to_next(mastery_level(t)) - int(mastery_of(t)["xp"]))


## The tree the weapon in hand learns in (the Wolf Fruit's claws in hybrid form; "" for none).
func hand_tree() -> String:
	var st := player.style()
	return "wolf" if st == "claw" else SkillTree.style_tree(st)


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


## A tree taught outright (black-leg, from its trainer): found now, with the HUD's card.
func discover(tree: String) -> void:
	_find(tree)


func _find(tree: String) -> void:
	if found.has(tree) or not SkillTrees.has_tree(tree) or SkillTrees.section_of(tree) == "fruit":
		return
	found[tree] = true
	_rev += 1
	tree_found.emit(tree)
	if player and player.is_local and is_inside_tree():
		get_tree().call_group("hud", "show_new_tree", tree_name(tree), "Added to %s" % SkillTrees.section_of(tree).to_upper())


func tree_level(tree: String) -> int:
	return level if tree == "captain" else mastery_level(tree)


func tree_xp(tree: String) -> int:
	return xp if tree == "captain" else int(mastery_of(tree)["xp"])


## Xp from this level to the next (0 at the top).
func tree_xp_next(tree: String) -> int:
	if tree == "captain":
		return xp_to_next(level) if level < MAX_LEVEL else 0
	return mastery_to_next(tree_level(tree)) if tree_level(tree) < max_of(tree) else 0


## A weapon's (or the fruit's) own points at mastery `lv` (1.23, docs/v1_23_previews.md option A): 2 a level, and a
## bonus point every 5 levels (2 when found, 39 at 18, 66 at 30).
static func tree_earned(lv: int) -> int:
	return 2 * lv + lv / 5


## Points earned into `pool` (a weapon's or fruit's id: its mastery; "adventure": a point a level any Adventure tree
## gains; "combat": every found weapon's and the eaten fruit's together).
func earned(pool: String) -> int:
	var n := int(_gift.get(pool, 0))
	if pool == "combat":
		for t in _point_trees():
			n += earned(t)
		return n
	if pool == "will":
		return n + will_earned
	if pool != "adventure":
		return n + tree_earned(int(mastery.get(pool, {"lv": 1})["lv"]))
	for t in SkillTrees.trees_in("adventure"):
		if mastery.has(t):
			n += int(mastery[t]["lv"]) - 1
	return n


## The trees whose own points count in "combat": the found weapons and the eaten fruit.
func _point_trees() -> Array:
	return visible_trees("combat") + visible_trees("fruit")


func spent(pool: String) -> int:
	var n := 0
	if pool == "combat":
		for t in _point_trees():
			n += spent(t)
		return n
	for k in bought.keys():
		if SkillTrees.node_pool(k) == pool:
			n += SkillTrees.price(k)
	for k in steps.keys():
		if SkillTrees.pool_of(str(SkillTrees.node_def(k)["tree"])) == pool:
			n += SkillTrees.price(k) * int(steps[k])
	return n


## Tests and render tools: `n` points into a pool (a tree's id or "adventure") on top of the earned ones (not saved).
func gift(which: String, n: int) -> void:
	_gift[which] = int(_gift.get(which, 0)) + n
	_dirty()


## Unspent points in a weapon's or fruit's own pool (its id), "adventure", or "combat" (the weapons' and fruit's
## together, each tree's only spendable in it).
func pool(which: String) -> int:
	return earned(which) - spent(which)


## The unspent points `tree`'s nodes are bought with (0 for the Captain).
func points_free(tree: String) -> int:
	var p := SkillTrees.pool_of(tree)
	return pool(p) if p != "" else 0


static func pool_name(which: String) -> String:
	if which == "will":
		return "Edy"
	if which in ["combat", "adventure"]:
		return which.capitalize()
	return tree_name(which)


## The one short prompt: "5 Katana points (K)".
func points_line(which: String) -> String:
	var n := pool(which)
	return "%d %s point%s (K)" % [n, pool_name(which), "" if n == 1 else "s"]


## Something in a found tree of `which` (a pool) can be bought right now (remembered until something changes).
## A level fork reached and not picked yet (the HUD's badge and the Captain page's Perks button call for it).
func perk_waiting() -> bool:
	for lv in range(5, level + 1, 5):
		if talent_at(lv) < 0:
			return true
	return false


func can_spend(which: String) -> bool:
	if _spend_rev != _rev:
		_spend_rev = _rev
		_spend.clear()
	if not _spend.has(which):
		_spend[which] = false
		if pool(which) > 0:
			var trees: Array = visible_trees("adventure") if which == "adventure" else (_point_trees() if which == "combat" else ["captain" if which == "will" else which])
			for t in trees:
				var pl: String = which if which in ["adventure", "will"] else t
				if SkillTrees.nodes_of(t).any(func(k): return SkillTrees.node_pool(k) == pl and buy_why(k) == ""):
					_spend[which] = true
					break
	return _spend[which]


func steps_of(node: String) -> int:
	return int(steps.get(node, 0))


## Nodes that come by themselves: the roots, the Captain's (not the Will's), a fruit's level-1 powers.
func _free(n: Dictionary) -> bool:
	if n.get("pool", "") == "will" or n["kind"] == "will":
		return false
	return n["kind"] in ["root", "version"] or SkillTrees.pool_of(str(n["tree"])) == "" or (SkillTrees.section_of(str(n["tree"])) == "fruit" and int(n["level"]) <= 1 and n["kind"] != "step")


## Why a node can't be bought now ("" = it can): its tree's level gates it, a step needs the node it hangs on, the
## second element the first, and its price must be in the pool.
func buy_why(id: String) -> String:
	var n := SkillTrees.node_def(id)
	if n.is_empty():
		return "Unknown"
	var tree := str(n["tree"])
	var kind := str(n["kind"])
	if n.get("pool", "") == "will":
		return WillPaths.why(self, id)
	if kind == "will":
		return "Buy one of its versions"
	if _free(n):
		if owns(id):
			return "Learned"
		if kind == "talent":
			return "Pick it at Captain %d" % int(n["level"])
		return "Comes at %s %d" % [tree_name(tree), int(n["level"])]
	if kind == "step":
		if steps_of(id) >= int(n["max_steps"]):
			return "Full"
	elif owns(id):
		return "Learned"
	if tree_level(tree) < int(n["level"]):
		return "Needs %s %d" % [tree_name(tree), int(n["level"])]
	if not _visible(tree):
		return "Eat the fruit first" if SkillTrees.section_of(tree) == "fruit" else "Not found yet"
	var on := str(n["links"][0]) if not n["links"].is_empty() else ""
	if kind == "step" and SkillTrees.node_def(on)["kind"] != "root" and not owns(on):
		return "Needs %s first" % SkillTrees.node_def(on)["name"]
	if kind == "elem":
		for k in SkillTrees.nodes_of(tree):
			var e := SkillTrees.node_def(k)
			if e["kind"] == "elem" and int(e["level"]) < int(n["level"]) and not owns(k):
				return "Needs %s first" % e["name"]
	var p := SkillTrees.pool_of(tree)
	if SkillTrees.price(id) > pool(p):
		return "Needs %d %s point%s" % [SkillTrees.price(id), pool_name(p), "" if SkillTrees.price(id) == 1 else "s"]
	return ""


## Buy a node with its pool's points (a step: one step).
func buy(id: String) -> bool:
	if buy_why(id) != "":
		return false
	_take(id)
	_dirty()
	return true


## (`quiet`: a load, nothing put on the bar or in a passive slot)
func _take(id: String, quiet: bool = false) -> void:
	var n := SkillTrees.node_def(id)
	if n["kind"] == "step":
		steps[id] = steps_of(id) + 1
		return
	bought[id] = true
	if n.has("parent") and n.get("pool", "") == "will":
		_take_will(id, quiet)
		return
	var own_id := id
	if n["kind"] == "variant":
		owned[id] = true
		own_id = str(n["versions"][version_of(id)]["id"])
	if quiet:
		owned[own_id] = true
	else:
		_own(own_id)


## A Will purchase: a passive is owned (and slotted if there's room); a version owns its ability, and the first one
## bought (or the save's active one) is the active version.
func _take_will(id: String, quiet: bool) -> void:
	var n := SkillTrees.node_def(id)
	if n["kind"] == "passive":
		if quiet:
			owned[id] = true
		else:
			_own(id)
		return
	var par := str(n["parent"])
	var i: int = SkillTrees.node_def(par)["versions"].map(func(v): return v["id"]).find(id)
	if not versions.has(par):
		versions[par] = i
	owned[par] = true
	if version_of(par) != i:
		return
	if quiet:
		owned[id] = true
	else:
		_own(id)


## A Will version you've bought (switched to at a rest spot).
func has_version(id: String) -> bool:
	return bought.has(id)


func step_why(node: String) -> String:
	return buy_why(node)


func buy_step(node: String) -> bool:
	return SkillTrees.node_def(node).get("kind", "") == "step" and buy(node)


## What a tree's respec costs at the bunk (gold).
func respec_price() -> int:
	return RESPEC_GOLD + RESPEC_PER_LEVEL * level


## Why `tree` can't be refunded now ("" = it can).
func respec_why(tree: String) -> String:
	if not bought.keys().any(func(k): return SkillTrees.node_def(k)["tree"] == tree) and not steps.keys().any(func(k): return SkillTrees.node_def(k)["tree"] == tree):
		return "Nothing bought"
	if not can_respec():
		return "Only at a rest spot"
	if player.inventory_component.count("gold") < respec_price():
		return "Needs %d gold" % respec_price()
	return ""


## At the ship's bunk, for respec_price() gold: everything bought in `tree` back into its pool.
func respec_tree(tree: String) -> bool:
	if respec_why(tree) != "":
		return false
	player.inventory_component.remove_item(ItemDB.get_item("gold"), respec_price())
	_drop_tree(tree)
	return true


func _drop_tree(tree: String) -> void:
	for k in bought.keys():
		var n := SkillTrees.node_def(k)
		if n["tree"] != tree:
			continue
		bought.erase(k)
		owned.erase(k)
		for v in n["versions"]:
			owned.erase(v["id"])
	for k in steps.keys():
		if SkillTrees.node_def(k)["tree"] == tree:
			steps.erase(k)
	_fit_passives()
	if player:
		for i in range(PowerComponent.SLOTS):
			if player.power.loadout[i] != "" and not knows(player.power.loadout[i]):
				player.power.equip("", i)
	_dirty()


## (the contract's has_node: Node already has one)
func owns_node(node: String) -> bool:
	if SkillTrees.node_def(node).get("kind", "") == "step":
		return steps_of(node) > 0
	return owns(node)


func version_of(node: String) -> int:
	return int(versions.get(node, -1 if SkillTrees.node_def(node).get("kind", "") == "talent" else 0))


## Make version `i` of an owned variant (or a Will ability's bought version) the active one (only at a rest spot).
func set_version(node: String, i: int) -> bool:
	var n := SkillTrees.node_def(node)
	if n.is_empty() or n["kind"] not in ["variant", "will"] or not owns(node) or i < 0 or i >= n["versions"].size():
		return false
	if n["kind"] == "will" and not has_version(str(n["versions"][i]["id"])):
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


## A Will ability (one of its versions bought) or passive is yours.
func has_will(id: String) -> bool:
	return owns(id)


## At a rest spot: where steps, versions, talents and passives are switched (1.23: the ship's bunk, an inn's bed in any
## village or city, or a camp's fire you're beside; group "rest_spots" + Camp.near).
func can_respec() -> bool:
	if player == null or not player.is_inside_tree():
		return false
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship != null and player.global_position.distance_to(ship.global_transform * Ship.BED_AT) < BUNK_REACH:
		return true
	for r in get_tree().get_nodes_in_group("rest_spots"):
		if r is Node3D and (r as Node3D).global_position.distance_to(player.global_position) < REST_REACH:
			return true
	return Camp.near(player) != null


func passive_slots() -> int:
	return PASSIVE_SLOTS + int(stat("passive_slots"))


func is_passive(id: String) -> bool:
	return SkillTrees.node_def(id).get("kind", "") == "passive"


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


## The nodes of a tree that come by themselves up to its level (the Captain's: a picked talent with its pick, an
## earned Will with its passive; a fruit's level-1 powers); returns the ones just granted.
func _sync_tree(tree: String, quiet: bool) -> Array:
	var got: Array = []
	if not SkillTrees.converted(tree) or (SkillTrees.section_of(tree) == "fruit" and (player == null or player.power.fruit != tree)):
		return got
	var lv := tree_level(tree)
	for k in SkillTrees.nodes_of(tree):
		var n := SkillTrees.node_def(k)
		if n["kind"] in ["step", "version"] or int(n["level"]) > lv or owns(k) or not _free(n):
			continue
		if n["kind"] == "talent" and version_of(k) < 0:
			continue
		var id: String = k
		if n["kind"] in ["variant", "talent"]:
			owned[k] = true
			id = str(n["versions"][version_of(k)]["id"])
		if quiet:
			owned[id] = true
		else:
			_own(id)
		got.append(id)
	return got


## Tests and render tools: every tree at its top level with everything bought (the points given, so the pools read 0).
## The Captain at the top level with every talent's first pick and every Will version and passive (the first
## version active); the fruit you ate at its top.
func master_all() -> void:
	level = MAX_LEVEL
	xp = 0
	for lv in range(5, MAX_LEVEL + 1, 5):
		if talent_at(lv) < 0:
			pick_talent(lv, 0)
	for k in SkillTrees.nodes_of("captain"):
		if SkillTrees.node_def(k).get("pool", "") == "will" and not has_version(k):
			_take(k)
	for t in SkillTrees.HEADERS.keys():
		if not SkillTrees.converted(t) or t == "captain":
			continue
		mastery_of(t)["lv"] = max_of(t)
		mastery_of(t)["xp"] = 0
		_sync_tree(t, false)
		if SkillTrees.section_of(t) == "fruit" and (player == null or player.power.fruit != t):
			continue
		for k in SkillTrees.nodes_of(t):
			var n := SkillTrees.node_def(k)
			if n["kind"] == "step":
				steps[k] = int(n["max_steps"])
			elif SkillTrees.price(k) > 0 and not _free(n) and not owns(k):
				_take(k)
	_sync_tree("captain", false)
	_gift = {}
	for t in SkillTrees.HEADERS.keys():
		var p := SkillTrees.pool_of(t)
		if p != "" and not _gift.has(p):
			_gift[p] = maxi(spent(p) - earned(p), 0)
	_gift["will"] = maxi(spent("will") - earned("will"), 0)
	_fit_passives()
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


## (the old skill map's names for buy_why and buy)
func can_learn(id: String) -> String:
	return buy_why(id)


func learn(id: String) -> bool:
	return buy(id)


func _own(id: String) -> void:
	owned[id] = true
	var sk: String = SkillTrees.node_def(id).get("skill", "")
	if sk != "" and player:
		player.power.auto_equip(sk)
	if is_passive(id) and not (id in passives) and passives.has(""):
		passives[passives.find("")] = id
	if player:
		player.call("_recalc_stats")
	changed.emit()


## A Devil Fruit's tree opens when you eat it: its root and first powers (the rest is bought as its level grows);
## another fruit's purchases go back into the pool.
func grant_fruit(fruit_id: String) -> void:
	for t in SkillTrees.trees_in("fruit"):
		if t != fruit_id:
			for k in SkillTrees.nodes_of(t):
				owned.erase(k)
				bought.erase(k)
				steps.erase(k)
	_sync_tree(fruit_id, false)
	_dirty()


## Sum of an effect over every owned node and bought step (asked several times a frame: remembered until
## something changes), and the meal you ate (Food). A redesigned tree's passive counts only in a passive slot.
func stat(key: String) -> float:
	if owned.size() != _stat_n or _rev != _stat_rev or level != _stat_lv:
		_stat_n = owned.size()
		_stat_rev = _rev
		_stat_lv = level
		_stats.clear()
	if not _stats.has(key):
		var total := float(SkillTrees.GROWTH.get(key, 0.0)) * (level - 1)
		for k in owned.keys():
			var n := SkillTrees.node_def(k)
			if n.get("kind", "") == "step" or (n.get("kind", "") == "passive" and not (k in passives)):
				continue
			var e: Dictionary = n.get("effects", {})
			if e.has(key):
				total += float(e[key])
		for k in steps.keys():
			var e: Dictionary = SkillTrees.node_def(k)["effects"]
			if e.has(key):
				total += float(e[key]) * int(steps[k])
		_stats[key] = total
	var v: float = _stats[key] + EdyTypes.bonus(will_color, key) + (Food.bonus(meal, key, meal_k) if meal != "" else 0.0) + (float(Downtime.KIT.get(key, 0.0)) if kit_left > 0.0 else 0.0) + float(gear.get(key, 0.0))
	# Sea Dog: stamina twice as fast aboard
	if key == "stamina_regen_pct" and stat("sea_dog") > 0.0 and player and Downtime.ship_under(player) != null:
		v += 1.0
	return v


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
## Weapon trees whose mastered guard (the "guard2_<tree>" node) is the one up (MasteredGuard): tree -> true.
var guards: Dictionary = {}


## Eat meal id: at your own Cooking's strength and length, or (k >= 0) a cook's (a portion off the galley table).
func eat_meal(id: String, k_: float = -1.0, secs: float = -1.0) -> void:
	meal = ""
	var k := Food.strength(self) if k_ < 0.0 else k_
	meal_left = Food.seconds(self, id) if secs < 0.0 else secs
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
## What the captain wears (GearStats.totals: key -> value), one more source stat() adds; the captain sets it when
## their gear changes.
var gear: Dictionary = {}
var _stat_n: int = -1
var _rev: int = 0
var _stat_rev: int = -1
var _stat_lv: int = -1


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
		var sk: String = SkillTrees.node_def(k).get("skill", "")
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


## A cast counted: enough of them and the skill ranks up by itself (no points).
func note_use(skill_id: String) -> void:
	uses[skill_id] = uses_of(skill_id) + 1
	var fruit := str(Skills.get_skill(skill_id).get("fruit", ""))
	if fruit != "":
		add_mastery(fruit, FRUIT_PER_CAST)
	if rank_up(skill_id) and player:
		player.call("_toast", "%s ranks up: %s" % [Skills.get_skill(skill_id)["name"], Skills.tier_def(skill_id, skill_tier(skill_id))["name"]])
	changed.emit()


## Why a skill can't go up a tier right now ("" = it can: it will on its next use or load).
func can_rank_up(skill_id: String) -> String:
	var t := skill_tier(skill_id)
	if t == 0:
		return "Learn it first"
	if t >= Skills.max_tier(skill_id):
		return "Mastered"
	var nt := Skills.tier_def(skill_id, t + 1)
	if uses_of(skill_id) < int(nt["uses"]):
		return "Use it %d more time%s" % [int(nt["uses"]) - uses_of(skill_id), "" if int(nt["uses"]) - uses_of(skill_id) == 1 else "s"]
	return ""


func rank_up(skill_id: String) -> bool:
	if can_rank_up(skill_id) != "":
		return false
	tiers[skill_id] = skill_tier(skill_id) + 1
	if player:
		player.call("_recalc_stats")
	changed.emit()
	return true


# --------------------------------------------------------------------------
# Save / load
# --------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {"format": FORMAT, "level": level, "xp": xp, "owned": owned.keys(), "bought": bought.keys(),
		"mastery": mastery.duplicate(true), "tiers": tiers.duplicate(), "uses": uses.duplicate(),
		"steps": steps.duplicate(), "versions": versions.duplicate(), "passives": Array(passives), "found": found.keys(),
		"will_pts": will_earned, "will_color": will_color, "meal": [meal, meal_left, meal_k], "recipes": recipes.keys(), "cooked": cooked.duplicate(),
		"kit": kit_left, "downtime": downtime.duplicate(), "guards": guards.keys()}


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
	guards = {}
	for k in d.get("guards", []):
		guards[str(k)] = true
	_reset_owned()
	mastery = {}
	tiers = {}
	uses = {}
	steps = {}
	versions = {}
	_foe_hits = {}
	skill_points = 0
	bought = {}
	_gift = {}
	_refunded = false
	_will_back = 0
	var fmt := int(d.get("format", 1))
	var ms: Dictionary = d.get("mastery", {})
	var want: Array = []
	if fmt < 4:
		# older trees: mastery levels and uses kept (gold and gear are other sections), every node refunded
		for t in ms.keys():
			if is_track(str(t)):
				var lv := int(ms[t].get("lv", 1))
				mastery[str(t)] = {"lv": lv, "xp": int(ms[t].get("xp", 0))}
		if fmt >= 2:
			uses = (d.get("uses", {}) as Dictionary).duplicate()
	else:
		# (format 5 owned its big nodes by level: they're bought back below like a format 6 save's)
		for k0 in d.get("bought" if fmt >= 6 else "owned", []):
			var k := str(SkillTrees.RENAMED.get(str(k0), k0))
			var n := SkillTrees.node_def(k)
			if not n.is_empty() and n["kind"] != "step" and SkillTrees.price(k) > 0 and not (k in want):
				want.append(k)
		for t in ms.keys():
			if is_track(str(t)):
				mastery[str(t)] = (ms[t] as Dictionary).duplicate()
		tiers = (d.get("tiers", {}) as Dictionary).duplicate()
		uses = (d.get("uses", {}) as Dictionary).duplicate()
	var want_steps := {}
	var sd: Dictionary = d.get("steps", {})
	for k in sd.keys():
		var n := SkillTrees.node_def(str(k))
		if n.get("kind", "") == "step":
			want_steps[str(k)] = clampi(int(sd[k]), 0, int(n["max_steps"]))
	var is_will := func(k): return SkillTrees.node_pool(k) == "will"
	var wills: Array = want.filter(is_will)
	want = want.filter(func(k): return not is_will.call(k))
	will_earned = int(d.get("will_pts", 0))
	will_color = str(d.get("will_color", ""))
	# (1.24.1: the colours picked before became Edy types)
	will_color = str(EdyTypes.OLD.get(will_color, will_color))
	if not EdyTypes.TYPES.has(will_color):
		will_color = ""
	if fmt < 8:
		# (1.23: Will came free from set bosses; each one awakened comes back as a boss's Will points, to spend on a path)
		wills = []
		var old: Array = d.get("will", [])
		will_earned = old.filter(func(k): return str(k) in WillPaths.OLD).size() * int(WillPaths.SOURCES["boss"])
		_will_back = will_earned
	if fmt < 7:
		# (1.23: the weapons' and fruit's nodes were bought from the one Combat pool; every point of it comes back once
		# into the trees' own pools, nothing bought again)
		var shared := func(k): return SkillTrees.pool_of(str(SkillTrees.node_def(k)["tree"])) == "adventure"
		_refunded = want.any(func(k): return not shared.call(k)) or want_steps.keys().any(func(k): return not shared.call(k))
		want = want.filter(shared)
		for k in want_steps.keys():
			if not shared.call(k):
				want_steps.erase(k)
	var vd: Dictionary = d.get("versions", {})
	for k in vd.keys():
		var n := SkillTrees.node_def(str(k))
		if n.get("kind", "") in ["variant", "talent", "will"] and int(vd[k]) >= 0 and int(vd[k]) < n["versions"].size():
			versions[str(k)] = int(vd[k])
	for k in wills:
		_take(k, true)
	found = {}
	for t in FOUND_AT_START + Array(d.get("found", [])):
		found[str(t)] = true
	for t in mastery.keys():
		if SkillTrees.has_tree(t) and (mastery_level(t) > 1 or int(mastery[t]["xp"]) > 0):
			found[t] = true
	passives.clear()
	for p in d.get("passives", []):
		passives.append(str(p))
	# (the life skills went to 30 before they became 20-level Adventure trees)
	for t in mastery.keys():
		if mastery_level(t) >= max_of(t):
			mastery[t] = {"lv": max_of(t), "xp": 0}
	for t in SkillTrees.HEADERS.keys():
		_sync_tree(t, true)
	_buy_back(want, want_steps)
	for sk in known_skills():
		while rank_up(sk):
			pass
	_fit_passives()
	_migrated = fmt < FORMAT and (level > 1 or not ms.is_empty())
	_rev += 1
	changed.emit()


## A save's purchases bought again while the pools afford them, the rest left in the pools: first what's on the bar
## (the power component loads before us) or in a passive slot, then each tree's big nodes lowest gate first (the
## highest-level trees first), then the steps.
func _buy_back(want: Array, want_steps: Dictionary) -> void:
	var bar: Array = Array(player.power.loadout) if player else []
	var in_use := func(k: String) -> bool:
		var n := SkillTrees.node_def(k)
		var ids: Array = [k]
		var sks: Array = [str(n["skill"])]
		for v in n["versions"]:
			ids.append(str(v["id"]))
			sks.append(str(v["skill"]))
		return ids.any(func(i): return i in passives) or sks.any(func(s): return s != "" and s in bar)
	var first := want.filter(in_use)
	var rest := want.filter(func(k): return not (k in first))
	var by_tree := func(a: String, b: String) -> bool:
		var na := SkillTrees.node_def(a)
		var nb := SkillTrees.node_def(b)
		var la := tree_level(str(na["tree"]))
		var lb := tree_level(str(nb["tree"]))
		if la != lb:
			return la > lb
		if na["tree"] != nb["tree"]:
			return str(na["tree"]) < str(nb["tree"])
		return int(na["level"]) < int(nb["level"])
	rest.sort_custom(by_tree)
	for k in first + rest:
		if buy_why(k) == "":
			_take(k, true)
	var ks: Array = want_steps.keys()
	ks.sort_custom(by_tree)
	for k in ks:
		for i in range(int(want_steps[k])):
			if buy_why(k) != "":
				break
			_take(k, true)


## After the power component has loaded too: the fruit's free nodes, and clear bar slots holding skills you no
## longer know (a refunded save).
func after_load() -> void:
	if player.power.has_fruit():
		grant_fruit(player.power.fruit)
	for i in range(PowerComponent.SLOTS):
		var sk := player.power.loadout[i]
		if sk != "" and not knows(sk):
			player.power.equip("", i)
	player.call("_recalc_stats")
	if _migrated:
		_migrated = false
		for p in library()["passives"]:
			if passives.has("") and not (p in passives):
				passives[passives.find("")] = p
		_rev += 1
		var subs: Array = []
		if _refunded:
			var trees: Array = _point_trees().filter(func(t): return can_spend(t))
			subs.append("What you'd bought came back: " + ", ".join(trees.map(func(t): return points_line(t).trim_suffix(" (K)"))) + ".")
		if _will_back > 0:
			subs.append("Your Wills came back as %d Will points: pick a path (K, Captain: W)." % _will_back)
		subs.append("Squall Step and Ballast are bought in Acrobatics and Defense.")
		get_tree().call_group("hud", "show_banner", "Every weapon has its own points now" if _refunded else "The skill trees changed", " ".join(subs), true)
