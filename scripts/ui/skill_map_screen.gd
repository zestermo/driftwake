class_name SkillMapScreen
extends Control
## The skills menu (K), as docs/media/progression_mock: a night sky under a wooden beam with a hanging sign per tab.
##   Captain     one page: your level and XP with the Perks button over the Will paths (a row of the seven paths, A/D;
##               the open one as a ladder, T1 at the foot, its versions as cards side by side, its passive under them).
##               Perks (P, Tab, pad Y) is a popup over it: every level fork in one list (up/down a fork, left/right an
##               option). Gold pips lead to anything to spend: the tab, the Perks button, a path, the fork.
##   Combat      a found weapon's tree (three branches up from its root, bought with its own points), or the chart of them all
## Trees show icons and names; the card has the picked node in full (gate, price, what it does, why not yet), the hover
## a one-line tip (its price and what Enter does or why not), one plate over the page the tree's mastery and its own
## points beside Adventure's; every path is drawn, grey and hollow until taken.
## Only found trees show anywhere (no Adventure sign before one is found). At the bunk the card refunds the tree for gold.
##   Adventure   the found Adventure trees beside the open one
##   Loadout     the weapon loadouts, the one skill bar (1-5 + R), the passive slots, the library of what you know
##   Powers      the eaten fruit's tree (once there is one)
## Keys: Q / E (shoulder buttons) change tab; arrows / d-pad move between nodes; Enter / F (pad A) buys a node,
## switches a version or picks a talent (versions and changed talents only at the ship's bunk); A / D change weapon
## (the Captain page: the Will path), Tab the chart (the Captain page: the perks); W / S change Adventure tree; 1-5 / R put the picked skill on the bar, 1-4 the picked passive in
## its slot. Mouse: hover inspects, click picks, click again acts, right-click clears a bar or passive slot.
## Everything is drawn here; clickable things register a hit (id, rect) as they're drawn.

const SILK := preload("res://assets/fonts/Silkscreen-Regular.woff2")
const TABS := [["captain", "Captain", "crown"], ["combat", "Combat", "swords"], ["adventure", "Adventure", "compass"],
	["loadout", "Loadout", "chest"], ["fruit", "Powers", "fruit"]]
const CARD_W := 152.0
const RAIL_H := 14.0
const HEAD_H := 32.0
const WILL := Color("c9a8ff")
const WILL_DIM := Color("4b3d78")
const WILL_DARK := Color("120f22")
## Chips for an effects dict's common keys: [format, scale] (scale 0: the text as it is).
const CHIPS := {"damage_pct": ["+%d%% DMG", 100], "defense": ["+%d DEF", 1], "max_hp": ["+%d HP", 1],
	"energy_regen_pct": ["+%d%% ENERGY", 100], "stamina_regen_pct": ["+%d%% STAMINA", 100], "crit_all": ["+%d%% CRIT", 100],
	"evade_chance": ["+%d%% EVADE", 100], "parry_all": ["+%d%% PARRY", 100], "dmg_unarmed": ["+%d%% UNARMED", 100],
	"xp_pct": ["+%d%% XP", 100], "armament": ["HEAVIES UNBLOCKABLE", 0], "observation": ["SENSE INTENT", 0]}
## How each Adventure tree grows (shown on its card).
const GROWS := {
	"acrobatics": "Jump, dodge and attack in the air. A dodge through a blow counts most, and a fall you live through.",
	"defense": "Block and parry real blows. Perfect parries count most, and staying on your feet when hit.",
	"sea": "Sail the ship: time at the helm and every job on deck.",
	"swim": "Swim open water: every few metres count.",
	"cook": "Cook meals at the galley or a camp fire.",
	"fish": "Fish: every catch counts, rare ones most.",
	"stealth": "Sneak past foes unseen and strike from hiding.",
	"tinker": "Tinker and train in your downtime.",
}

var menu: Node
var tab := "combat"
## Combat: the chart of every weapon instead of one tree.
var chart := false
## Captain: the perks popup (the level forks) open over the Will paths.
var perks_open := false
## Captain: the Will path shown (WillPaths.PATHS).
var will_path := "iron"
## Borrowed icons for the Will versions and passives with no skill of their own, and each path's emblem (stand-ins until
## they get their own).
const WILL_ICONS := {"w_emit_line": "flying_slash", "w_emit_ring": "fire_ring", "w_emit_stomp": "move_crash", "w_inner_v": "palm_strike",
	"w_mirror": "windmill_guard", "w_flash_long": "foresight", "w_flash_shots": "deadeye", "w_flash_boss": "guardbreaker",
	"w_flash_ambush": "smoke_bomb", "w_crowd_v": "will_glimpse", "w_weak": "pin_shot", "w_clash_v": "cross_counter", "w_rally": "howl",
	"w_breath_v": "move_dolphin", "w_wave": "move_glide", "w_step_v": "move_moonstep", "w_cancel": "side_step", "w_flow": "phantom_step",
	"w_mist_v": "red_eclipse", "w_unbowed_v": "tekkai", "w_link_v": "parley", "w_gauge": "twin_waves", "w_shelter": "move_rolling_guard",
	"h_harden": "tekkai", "h_instinct": "move_sidestep", "h_will": "conquerors_haki", "h_helm": "broadside", "h_feet": "flame_dash",
	"h_crew": "howl", "h_blood": "bleeding_edge"}
const PATH_ICONS := {"iron": "armament_coat", "sense": "will_glimpse", "conq": "conquerors_haki", "tide": "will_swell",
	"tempo": "will_still_point", "fury": "will_berserk", "bond": "will_twin"}
## The open tree (Combat, Adventure, Driftfruit).
var tree := ""
## The picked hit: "n:<node>", "w:<tree>", "bar:<slot>", "pas:<i>", "lib:<skill or passive>".
var sel := ""
var hover := ""
var _trees: Dictionary = {}
var _hits: Array = []
var _drawn: Array = []
## The open tree's paths drawn this frame: [from, to, taken].
var links: Array = []
var _tab_rects: Array = []
var _t := 0.0
var _msg := ""
var _msg_t := 0.0
var _font: Font
var _mouse := Vector2.ZERO
## The tree whose refund was clicked once (a second click pays for it).
var _respec_armed := ""


func _init(owner_menu: Node) -> void:
	menu = owner_menu
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = UIStyle.get_theme().default_font


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player if is_inside_tree() else null


func _pr() -> Progression:
	return _player().progression


## The tabs that show (Adventure once a tree of it is found, Driftfruit once you've eaten one).
func tabs() -> Array:
	return TABS.filter(func(t): return t[0] not in ["adventure", "fruit"] or not _pr().visible_trees(t[0]).is_empty())


## Opens on the tree of the weapon in your hand (Swimming in the water), else the first weapon found.
func on_open() -> void:
	grab_focus()
	var pl := _player()
	chart = false
	var hand := SkillTree.style_tree(pl.style())
	if pl.armed and hand in _pr().visible_trees("combat"):
		set_tab("combat", hand)
	elif pl.is_swimming() and "swim" in _pr().visible_trees("adventure"):
		set_tab("adventure", "swim")
	else:
		set_tab("combat")
	queue_redraw()


func set_tab(t: String, which: String = "") -> void:
	tab = t
	hover = ""
	sel = ""
	_respec_armed = ""
	if t in ["combat", "adventure", "fruit"]:
		var vis := _pr().visible_trees(t)
		var keep := str(_trees.get(t, ""))
		tree = which if which != "" else (keep if keep in vis else (str(vis[0]) if not vis.is_empty() else ""))
		_trees[t] = tree
		_pick_root()
	elif t == "loadout":
		sel = "bar:0"
	elif t == "captain":
		_captain_home()


func _forks() -> Array:
	return _captain_kind("talent")


func _captain_kind(kind: String) -> Array:
	var out := SkillTrees.nodes_of("captain").filter(func(k): return SkillTrees.node_def(k)["kind"] == kind)
	out.sort_custom(func(a, b): return int(SkillTrees.node_def(a)["level"]) < int(SkillTrees.node_def(b)["level"]))
	return out


## The Captain page's pick. Perks open: the lowest fork not picked yet (else the top one). The Will paths: a path with
## something to buy now (else the one of your first Will ability, else Iron Will), on its first card.
func _captain_home() -> void:
	var p := _pr()
	if perks_open:
		var f := _forks()
		var k := f.size() - 1
		for i in range(f.size() - 1, -1, -1):
			if p.version_of(f[i]) < 0:
				k = i
		sel = "f:%s:%d" % [f[k], maxi(p.version_of(f[k]), 0)]
		return
	var won := WillPaths.ABILITIES.keys().filter(func(k): return p.has_will(k))
	var path := str(WillPaths.ABILITIES[won[0]][0]) if not won.is_empty() else "iron"
	for k in WillPaths.PATHS:
		if path_ready(k):
			path = k
			break
	will_path = path
	sel = _path_first(path)


## The first card of a path's ladder: its lowest version to buy now, else its lowest one you carry, else its first.
func _path_first(path: String) -> String:
	var p := _pr()
	var all: Array = []
	for aid in WillPaths.abilities_of(path):
		for v in SkillTrees.node_def(aid)["versions"]:
			all.append(str(v["id"]))
	for vid in all:
		if not p.has_version(vid) and p.buy_why(vid) == "":
			return "n:" + vid
	return "n:" + str(all[0])


## The Will path shown: the pick moves to its first card.
func _set_path(path: String) -> void:
	if will_path == path:
		return
	will_path = path
	hover = ""
	sel = _path_first(path)
	menu._play("select")


## The perks popup open or shut.
func _set_perks(open: bool) -> void:
	if perks_open == open:
		return
	perks_open = open
	hover = ""
	_captain_home()
	menu._play("select")


## A level fork reached and not picked yet (the Perks button's pip).
func perk_ready() -> bool:
	var p := _pr()
	return _forks().any(func(k): return int(SkillTrees.node_def(k)["level"]) <= p.level and p.version_of(k) < 0)


## Something in a Will path you can buy now (its tab's pip).
func path_ready(path: String) -> bool:
	var p := _pr()
	if p.pool("will") <= 0:
		return false
	for aid in WillPaths.abilities_of(path):
		for v in SkillTrees.node_def(aid)["versions"]:
			if not p.has_version(str(v["id"])) and p.buy_why(str(v["id"])) == "":
				return true
	for pid in WillPaths.PASSIVES:
		if WillPaths.PASSIVES[pid][0] == path and not p.has_version(pid) and p.buy_why(pid) == "":
			return true
	return false


## Anything to spend on the Captain tab (its pip). (A path's own pip shows only once you've started it, so Will to
## spend doesn't light all seven.)
func captain_ready() -> bool:
	return perk_ready() or WillPaths.PATHS.any(func(k): return path_ready(k))


## Up / down a fork, left / right its option.
func _fork_nav(d: Vector2) -> void:
	var f := _forks()
	var k := f.find(sel.get_slice(":", 1))
	var i := int(sel.get_slice(":", 2))
	if not sel.begins_with("f:") or k < 0:
		_captain_home()
		return
	if d.y != 0.0:
		k = clampi(k - int(d.y), 0, f.size() - 1)
	else:
		i = 0 if d.x < 0.0 else 1
	var to := "f:%s:%d" % [f[k], i]
	if to != sel:
		sel = to
		hover = ""
		UIStyle.sfx("move")


func _pick_root() -> void:
	sel = ("n:" + str(SkillTrees.tree_def(tree)["root"])) if tree != "" and SkillTrees.converted(tree) else ""


func _cycle_tab(step: int) -> void:
	var ids := tabs().map(func(x): return x[0])
	set_tab(ids[posmod(ids.find(tab) + step, ids.size())])
	menu._play("select")


func _cycle_tree(step: int) -> void:
	var vis := _pr().visible_trees(tab)
	if vis.is_empty():
		return
	chart = false
	set_tab(tab, str(vis[posmod(vis.find(tree) + step, vis.size())]))
	menu._play("select")


func _process(delta: float) -> void:
	# (the screen stays "visible" inside the hidden menu root when closed)
	if not is_visible_in_tree():
		return
	_t += delta
	_msg_t = maxf(_msg_t - delta, 0.0)
	queue_redraw()


# --------------------------------------------------------------------------
# Hits and navigation
# --------------------------------------------------------------------------
## Register something clickable drawn this frame (`nav`: the arrow keys can land on it).
func hit(r: Rect2, id: String, nav: bool = true) -> void:
	_hits.append([r, id, nav])


## What the card describes: the hovered thing, else the picked one.
func inspected() -> String:
	return hover if hover != "" else sel


func _hit_at(p: Vector2) -> String:
	var best := ""
	for h in _drawn:
		if (h[0] as Rect2).has_point(p):
			if str(h[1]).begins_with("v:"):
				return h[1]
			best = h[1]
	return best


func _rect_of(id: String) -> Rect2:
	for h in _drawn:
		if h[1] == id:
			return h[0]
	return Rect2()


## Move the pick to the nearest hit in direction `d`.
func _nav(d: Vector2) -> void:
	var from := _rect_of(sel)
	var best := ""
	var bs := INF
	for h in _drawn:
		if not h[2] or h[1] == sel:
			continue
		if from.size == Vector2.ZERO:
			best = h[1]
			break
		var v: Vector2 = (h[0] as Rect2).get_center() - from.get_center()
		var along := v.dot(d)
		var across := absf(v.dot(Vector2(-d.y, d.x)))
		if along <= 2.0 or across > along * 2.0:
			continue
		var score := along + across * 2.5
		if score < bs:
			bs = score
			best = h[1]
	if best != "":
		sel = best
		hover = ""
		UIStyle.sfx("move")


# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position
		var h := _hit_at(_mouse)
		hover = ("n:" + h.get_slice(":", 1)) if h.begins_with("v:") else h
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		accept_event()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if tab == "captain" and perks_open and _hit_at(mb.position) == "":
				# (a click off the popup shuts it)
				_set_perks(false)
				return
			for i in range(_tab_rects.size()):
				if (_tab_rects[i] as Rect2).has_point(mb.position):
					set_tab(tabs()[i][0])
					menu._play("select")
					return
			var id := _hit_at(mb.position)
			if id.begins_with("v:"):
				sel = "n:" + id.get_slice(":", 1)
				_act_split(id.get_slice(":", 1), int(id.get_slice(":", 2)))
			elif id != "" and id == sel:
				_act(id)
			elif id.begins_with("w:") or id == "respec" or id == "perks" or id.begins_with("col:") or id.begins_with("path:"):
				_act(id)
			elif id != "":
				sel = id
				menu._play("select")
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			var id := _hit_at(mb.position)
			if id.begins_with("bar:"):
				_player().power.equip("", int(id.substr(4)))
				menu._play("unequip")
			elif id.begins_with("pas:"):
				_pr().equip_passive("", int(id.substr(4)))
				menu._play("unequip")


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventJoypadButton and event.pressed:
		var jb := event as InputEventJoypadButton
		if jb.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			_cycle_tab(-1 if jb.button_index == JOY_BUTTON_LEFT_SHOULDER else 1)
			get_viewport().set_input_as_handled()
			return
		if jb.button_index == JOY_BUTTON_Y and tab == "captain":
			_set_perks(not perks_open)
			get_viewport().set_input_as_handled()
			return
	for d in [["ui_left", Vector2.LEFT], ["ui_right", Vector2.RIGHT], ["ui_up", Vector2.UP], ["ui_down", Vector2.DOWN]]:
		if event.is_action_pressed(d[0], true) and not (event is InputEventKey and (event as InputEventKey).keycode in [KEY_A, KEY_D, KEY_W, KEY_S]):
			if tab == "captain" and perks_open:
				_fork_nav(d[1])
			else:
				_nav(d[1])
			get_viewport().set_input_as_handled()
			return
	if tab == "captain" and perks_open and event.is_action_pressed("ui_cancel"):
		_set_perks(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept") and not (event is InputEventKey and (event as InputEventKey).keycode == KEY_SPACE):
		_act(sel)
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = (event as InputEventKey).keycode
	var handled := true
	if k == KEY_Q or k == KEY_E:
		_cycle_tab(-1 if k == KEY_Q else 1)
	elif k == KEY_F:
		_act(sel)
	elif (k == KEY_P or k == KEY_TAB) and tab == "captain":
		_set_perks(not perks_open)
	elif k == KEY_TAB and tab == "combat":
		chart = not chart
		if chart:
			sel = "w:" + tree
		else:
			_pick_root()
		menu._play("select")
	elif (k == KEY_A or k == KEY_D) and tab == "captain" and not perks_open:
		_set_path(WillPaths.PATHS[wrapi(WillPaths.PATHS.find(will_path) + (-1 if k == KEY_A else 1), 0, WillPaths.PATHS.size())])
	elif (k == KEY_A or k == KEY_D) and tab == "combat":
		_cycle_tree(-1 if k == KEY_A else 1)
	elif (k == KEY_W or k == KEY_S) and tab == "adventure":
		_cycle_tree(-1 if k == KEY_W else 1)
	elif (k >= KEY_1 and k <= KEY_5) or k == KEY_R:
		_slot_key(-1 if k == KEY_R else k - KEY_1)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


## A number key (0-4, -1 for R) with something picked: a skill onto the bar, a passive into its slot.
func _slot_key(n: int) -> void:
	var id := _picked_id()
	if id == "":
		_deny("Pick a skill or a passive first")
	elif _pr().is_passive(id):
		if n < 0 or n >= _pr().passive_slots():
			_deny("%d passive slots" % _pr().passive_slots())
		elif _pr().equip_passive(id, n):
			menu._play("equip")
			_say("%s in passive slot %d" % [_node_any(id)["name"], n + 1])
	else:
		equip_skill(id, PowerComponent.ULT if n < 0 else PowerComponent.KEYS[n])


## The skill or passive the pick stands for ("" if none).
func _picked_id() -> String:
	if sel.begins_with("lib:"):
		return sel.substr(4)
	if sel.begins_with("n:"):
		var n := SkillTrees.node_def(sel.substr(2))
		if n["kind"] == "variant":
			var v: Dictionary = n["versions"][_pr().version_of(sel.substr(2))]
			return str(v["skill"]) if str(v["skill"]) != "" else str(v["id"])
		if n["kind"] == "passive":
			return sel.substr(2)
		return str(n["skill"])
	return ""


## Put a known skill on the bar (PowerComponent decides what's allowed and says why not).
func equip_skill(sk: String, slot: int) -> void:
	var pl := _player()
	var why := pl.power.equip_why(sk, slot)
	if why != "":
		_deny(why)
	elif pl.power.equip(sk, slot):
		menu._play("equip")
		_say("%s on %s" % [Skills.get_skill(sk)["name"], PowerComponent.key_of(slot)])


## Why a known skill couldn't be used from the bar now ("" = it can), asked of the slot it's on or would go on.
func _bar_why(sk: String) -> String:
	var at := _player().power.loadout.find(sk)
	return _player().power.equip_why(sk, at if at >= 0 else (PowerComponent.ULT if Skills.is_ult(sk) else PowerComponent.KEYS[0]))


func _act(id: String) -> void:
	var p := _pr()
	if id.begins_with("n:"):
		var nid := id.substr(2)
		var n := SkillTrees.node_def(nid)
		if n["kind"] == "will" or n.get("pool", "") == "will":
			_act_will(nid)
		elif n["kind"] == "talent" or (n["kind"] == "variant" and p.owns(nid)):
			_act_split(nid, (maxi(p.version_of(nid), 0) + (1 if p.version_of(nid) >= 0 else 0)) % n["versions"].size())
		elif n["kind"] == "step" or not p.owns(nid):
			_buy(nid)
		elif str(n["skill"]) != "" and p.knows(str(n["skill"])):
			_say("1-5 or R puts it on the bar")
	elif id.begins_with("f:"):
		_act_split(id.get_slice(":", 1), int(id.get_slice(":", 2)))
	elif id == "perks":
		_set_perks(not perks_open)
	elif id.begins_with("path:"):
		_set_path(id.substr(5))
	elif id.begins_with("col:"):
		if p.set_will_color(id.substr(4)):
			menu._play("equip")
			_say("Your Will: %s" % WillPaths.COLORS[id.substr(4)][0])
	elif id.begins_with("w:"):
		var t := id.substr(2)
		if tab == "combat":
			chart = false
		set_tab(tab, t)
		menu._play("select")
	elif id.begins_with("lib:"):
		var lid := id.substr(4)
		if p.is_passive(lid):
			var at := p.passives.find("")
			_slot_key(at if at >= 0 else 0)
		else:
			var free := -1
			for s in PowerComponent.KEYS:
				if free < 0 and _player().power.loadout[s] == "":
					free = s
			equip_skill(lid, PowerComponent.ULT if Skills.is_ult(lid) else (free if free >= 0 else PowerComponent.KEYS[0]))
	elif id.begins_with("bar:") or id.begins_with("pas:"):
		_say("Pick something in the library, then its key")
	elif id == "respec":
		_respec()


## The tree's refund at the bunk: a first click asks, a second pays.
func _respec() -> void:
	var p := _pr()
	if _respec_armed != tree:
		_respec_armed = tree
		_say("Refund everything bought in %s for %d gold? Click again" % [Progression.tree_name(tree), p.respec_price()])
		menu._play("select")
		return
	_respec_armed = ""
	var why := p.respec_why(tree)
	if not p.respec_tree(tree):
		_deny(why)
		return
	menu._play("coin")
	_say("%s refunded: its points are back" % Progression.tree_name(tree))


func _buy(nid: String) -> void:
	var p := _pr()
	var n := SkillTrees.node_def(nid)
	var why := p.buy_why(nid)
	if not p.buy(nid):
		_deny(why)
		return
	menu._play("coin")
	_say("%s %d/%d" % [n["name"], p.steps_of(nid), int(n["max_steps"])] if n["kind"] == "step" else "%s is yours" % n["name"])


## Make version `i` of a variant (or talent) the active one.
func _act_split(nid: String, i: int) -> void:
	var p := _pr()
	var n := SkillTrees.node_def(nid)
	var v: Dictionary = n["versions"][i]
	if p.version_of(nid) == i:
		return
	var ok := p.pick_talent(int(n["level"]), i) if n["kind"] == "talent" else p.set_version(nid, i)
	if ok:
		menu._play("equip")
		_say("%s: %s" % [n["name"], v["name"]])
	elif int(v["level"]) > p.tree_level(str(n["tree"])):
		_deny("%s comes at %s %d" % [v["name"], "level" if n["tree"] == "captain" else Progression.tree_name(str(n["tree"])), int(v["level"])])
	elif n["kind"] == "talent":
		_deny("Change talents at a rest spot: the bunk, an inn or your camp")
	else:
		_deny("Switch versions at a rest spot: the bunk, an inn or your camp")


## Enter on the Will page: a version not yours is bought, one bought made the active one (at a rest spot), an ability
## its first version you don't have; a passive bought, or once yours put in a free slot.
func _act_will(nid: String) -> void:
	var p := _pr()
	var n := SkillTrees.node_def(nid)
	if n["kind"] == "will":
		var vs: Array = n["versions"].map(func(v): return v["id"])
		var next: Array = vs.filter(func(v): return not p.has_version(v))
		_act_will(str(vs[p.version_of(nid)] if p.owns(nid) and next.is_empty() else next[0]))
		return
	sel = "n:" + nid
	if n["kind"] == "passive":
		if not p.has_version(nid):
			_buy_will(nid)
		elif nid in p.passives:
			_say("%s is in passive slot %d" % [n["name"], p.passives.find(nid) + 1])
		else:
			var at := maxi(p.passives.find(""), 0)
			if p.equip_passive(nid, at):
				menu._play("equip")
				_say("%s in passive slot %d" % [n["name"], at + 1])
		return
	if not p.has_version(nid):
		_buy_will(nid)
		return
	var par := str(n["parent"])
	var i: int = SkillTrees.node_def(par)["versions"].map(func(v): return v["id"]).find(nid)
	if p.version_of(par) == i:
		_say("%s is the one you carry" % n["name"])
	elif p.set_version(par, i):
		menu._play("equip")
		_say("%s: %s" % [SkillTrees.node_def(par)["name"], n["name"]])
	else:
		_deny("Switch versions at a rest spot: the bunk, an inn or your camp")


func _buy_will(nid: String) -> void:
	var p := _pr()
	var why := p.buy_why(nid)
	if not p.buy(nid):
		_deny(why)
		return
	menu._play("coin")
	_say("%s is yours" % SkillTrees.node_def(nid)["name"] + ("  ·  pick your Will's colour" if p.will_color == "" else ""))


func _deny(m: String) -> void:
	_say(m)
	menu._play("deny")


func _say(m: String) -> void:
	_msg = m
	_msg_t = 2.5


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------
func _draw() -> void:
	var pl := _player()
	if pl == null:
		return
	_hits = []
	links = []
	var p := _pr()
	UIStyle.draw_sky(self, Rect2(Vector2.ZERO, size), _t)
	var bottom := size.y - UIChrome.BOARD_H
	var body := Rect2(10, 36, size.x - 20, bottom - 40)
	match tab:
		"captain":
			_draw_captain(body)
		"combat":
			if chart:
				_draw_chart(body)
			else:
				_draw_tree_page(body, true)
		"adventure":
			_draw_adventure(body)
		"loadout":
			_draw_loadout(body)
		"fruit":
			_draw_tree_page(body, false)
	var tl := tabs()
	var frac := float(p.xp) / maxf(Progression.xp_to_next(p.level), 1.0) if p.level < Progression.MAX_LEVEL else 1.0
	_tab_rects = UIStyle.draw_topbar(self, size.x, tl.map(func(x): return [x[1], UIStyle.tab_icon(x[2])]), tl.map(func(x): return x[0]).find(tab), _t, p.level, frac)
	var ci := tl.map(func(x): return x[0]).find("captain")
	if ci >= 0 and ci < _tab_rects.size() and captain_ready():
		var tr: Rect2 = _tab_rects[ci]
		UIStyle.draw_pip(self, Vector2(tr.end.x - 2.0, tr.position.y + 2.0), _t)
	UIStyle.draw_board(self, bottom, size.x, _hints())
	_draw_tip()
	if _msg_t > 0.0:
		var w := SILK.get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 16.0
		var r := Rect2(roundf((size.x - w) * 0.5), bottom - 20.0, w, 15)
		draw_style_box(UIStyle.chrome("paper", 0, 0), r)
		draw_string(SILK, r.position + Vector2(8, 11), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.PARCH_INK)
	_drawn = _hits


func _hints() -> Array:
	match tab:
		"combat":
			if chart:
				return [["Q/E", "TAB"], ["ARROWS", "PICK A WEAPON"], ["ENTER", "OPEN ITS TREE"], ["TAB", "ONE TREE"], ["K", "CLOSE"]]
			return [["Q/E", "TAB"], ["A/D", "WEAPON"], ["ARROWS", "INSPECT"], ["ENTER", "BUY"], ["TAB", "CHART"], ["K", "CLOSE"]]
		"adventure":
			return [["Q/E", "TAB"], ["W/S", "TREE"], ["ARROWS", "INSPECT"], ["ENTER", "BUY"], ["K", "CLOSE"]]
		"captain":
			if perks_open:
				return [["UP/DOWN", "FORK"], ["LEFT/RIGHT", "OPTION"], ["ENTER", "PICK"], ["P/ESC", "BACK"], ["K", "CLOSE"]]
			return [["Q/E", "TAB"], ["P", "PERKS"], ["A/D", "PATH"], ["ARROWS", "PICK"], ["ENTER", "BUY / CARRY"], ["K", "CLOSE"]]
		"loadout":
			return [["Q/E", "TAB"], ["ENTER", "PUT ON BAR"], ["1-5/R", "SLOT"], ["RMB", "CLEAR"], ["K", "CLOSE"]]
	return [["Q/E", "TAB"], ["ARROWS", "INSPECT"], ["ENTER", "BUY"], ["K", "CLOSE"]]


func _out(pos: Vector2, s: String, col: Color, al := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	draw_string_outline(SILK, pos, s, al, w, 8, 2, UIStyle.OUTLINE)
	draw_string(SILK, pos, s, al, w, 8, col)


func _wrap(text: String, w: float, font: Font, sz: int) -> Array:
	var out: Array = []
	var line := ""
	for wd in text.split(" "):
		var trial := wd if line == "" else line + " " + wd
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > w and line != "":
			out.append(line)
			line = wd
		else:
			line = trial
	if line != "":
		out.append(line)
	return out


## Wrapped Pixelify 12 from `pos` (the first baseline); returns the y under it. Stops above `limit`.
func _para(pos: Vector2, text: String, w: float, col: Color, limit: float = INF, step: float = 11.0) -> float:
	var y := pos.y
	for l in _wrap(text, w, _font, 12):
		if y > limit:
			break
		draw_string(_font, Vector2(pos.x, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		y += step
	return y


func _bar(r: Rect2, frac: float, col: Color, on_paper: bool = true) -> void:
	draw_rect(r.grow(1.0), UIStyle.BORDER_DIM if on_paper else UIStyle.OUTLINE)
	draw_rect(r, Color("d9cdb0") if on_paper else SkillTreeDraw.NODE_BG)
	draw_rect(Rect2(r.position, Vector2(roundf(r.size.x * clampf(frac, 0.0, 1.0)), r.size.y)), col)


func _frac(tree_id: String) -> float:
	var p := _pr()
	return 1.0 if p.tree_xp_next(tree_id) == 0 else float(p.tree_xp(tree_id)) / float(p.tree_xp_next(tree_id))


func _node_any(id: String) -> Dictionary:
	var n := SkillTrees.node_def(id)
	return n if not n.is_empty() else SkillTree.get_node_def(id)


## The weapon tree each loadout builds, as the bar sees it ("" for a slot not set up, locked, or its weapon gone).
func _loadout_tree(i: int) -> String:
	var st: String = _player().power.loadout_styles()[i]
	return "" if st == "" else SkillTree.style_tree(st)


func _loadouts_of(tree_id: String) -> Array:
	var out: Array = []
	for i in range(Player.LOADOUTS):
		if _loadout_tree(i) == tree_id:
			out.append(i)
	return out


## A skill's tree id (the fruits' skills name theirs: "Vine" is the vine tree).
func _skill_tree(sk: String) -> String:
	return str(Skills.get_skill(sk)["tree"]).to_lower()


func _tree_color(tree_id: String) -> Color:
	return SkillTrees.tree_def(tree_id)["color"] if SkillTrees.has_tree(tree_id) else UIStyle.GILT


# --------------------------------------------------------------------------
# A tree with its card (Combat, Driftfruit) and the weapon rail
# --------------------------------------------------------------------------
func _draw_tree_page(body: Rect2, rail: bool) -> void:
	if rail:
		_draw_rail(Rect2(0, body.end.y - RAIL_H, size.x, RAIL_H))
	if tree == "":
		_out(Vector2(body.position.x, body.get_center().y), "NO TREE HERE YET", UIStyle.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, body.size.x)
		return
	var page := _draw_header(body, tree)
	var h := page.size.y - (RAIL_H + 4.0 if rail else 0.0)
	var card := Rect2(page.end.x - CARD_W, page.position.y, CARD_W, h - 2.0)
	SkillTreeDraw.draw_tree(self, tree, Rect2(page.position, Vector2(page.size.x - CARD_W - 8.0, h)), _pr(), _t)
	_draw_card(card)


## The one plate over a page: the open tree's icon, name and mastery with its bar (the chart's: how many weapons),
## and the points: a weapon's own beside the Adventure pool (the one this tree spends lit; the chart: every weapon's
## together). Returns the body under it.
func _draw_header(body: Rect2, tree_id: String) -> Rect2:
	var p := _pr()
	var r := Rect2(body.position, Vector2(body.size.x, HEAD_H))
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.3))
	draw_style_box(UIStyle.chrome("paper", 0, 0), r)
	var cy := roundf(r.get_center().y)
	var x := r.position.x + 8.0
	var mine := SkillTrees.pool_of(tree_id) if tree_id != "" else ""
	if tree_id != "":
		var td := SkillTrees.tree_def(tree_id)
		var ib := Rect2(x, cy - 13.0, 26, 26)
		draw_rect(ib.grow(1.0), UIStyle.BORDER_DIM)
		draw_rect(ib, UIStyle.INK)
		var ic := SkillTreeDraw.tree_icon(tree_id)
		if ic:
			draw_texture_rect(ic, Rect2(ib.position + Vector2(1, 1), Vector2(24, 24)), false)
		else:
			draw_string(SILK, Vector2(ib.position.x, ib.position.y + 17.0), SkillTreeDraw.glyph(str(td["name"])), HORIZONTAL_ALIGNMENT_CENTER, 26, 8, td["color"])
		x += 34.0
		UIStyle.draw_title(self, Vector2(x, cy + 6.0), str(td["name"]), 18, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		x += UIStyle.TITLE_FONT.get_string_size(str(td["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 10.0
		var word := "LEVEL" if td["section"] == "adventure" else "MASTERY"
		var rb := UIStyle.draw_ribbon(self, Vector2(x, cy - 10.0), "%s %d of %d" % [word, p.tree_level(tree_id), SkillTrees.max_level(tree_id)])
		_bar(Rect2(x + 2.0, cy + 6.0, rb.size.x - 4.0, 3), _frac(tree_id), UIStyle.TEAL)
	else:
		UIStyle.draw_title(self, Vector2(x, cy + 6.0), "Weapon chart", 18, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
		x += UIStyle.TITLE_FONT.get_string_size("Weapon chart", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 10.0
		var n := p.visible_trees("combat").size()
		UIStyle.draw_ribbon(self, Vector2(x, cy - 6.0), "%d weapon%s found" % [n, "" if n == 1 else "s"])
	var rx := r.end.x - 8.0
	var shown: Array = ["adventure", "combat"] if mine == "" else (["adventure"] if mine == "adventure" else ["adventure", mine])
	for which in shown:
		var pts := p.pool(which)
		var lit: bool = which == mine
		var num := str(pts)
		var nw := UIStyle.TITLE_FONT.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var word := Progression.pool_name(which).to_upper()
		var cw := nw + SILK.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 18.0
		var cr := Rect2(rx - cw, r.position.y + 4.0, cw, r.size.y - 8.0)
		if lit:
			draw_rect(cr, UIStyle.CORAL if pts > 0 else Color("d9cdb0"))
			draw_rect(cr, UIStyle.BORDER_DIM, false, 1.0)
		var ink := UIStyle.PARCH_INK if lit or mine == "" else UIStyle.PARCH_DIM
		draw_string(UIStyle.TITLE_FONT, Vector2(cr.position.x + 6.0, cy + 6.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
		draw_string(SILK, Vector2(cr.position.x + nw + 12.0, cy - 1.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
		draw_string(SILK, Vector2(cr.position.x + nw + 12.0, cy + 8.0), "POINTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
		rx = cr.position.x - 6.0
	return Rect2(body.position.x, r.end.y + 6.0, body.size.x, body.end.y - r.end.y - 6.0)


func _draw_rail(r: Rect2) -> void:
	draw_rect(r, Color(UIChrome.INK, 0.55))
	draw_style_box(UIStyle.chrome("rope", 0, 0), Rect2(r.position.x, r.position.y - 1.0, r.size.x, 3))
	var vis := _pr().visible_trees("combat")
	var labels: Array = vis.map(func(t): return "%s %d%s" % [Progression.tree_name(t).to_upper(), _pr().tree_level(t), " (+%d)" % _pr().pool(t) if _pr().pool(t) > 0 else ""])
	var total := 0.0
	for l in labels:
		total += SILK.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 22.0
	var x := roundf((r.size.x - total) * 0.5)
	for i in range(vis.size()):
		var w := SILK.get_string_size(labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 22.0
		var on: bool = vis[i] == tree
		var hr := Rect2(x + 3.0, r.position.y + 2.0, w - 6.0, r.size.y - 2.0)
		if on:
			draw_style_box(UIStyle.chrome("sign_on", 0, 0), hr)
			draw_string(SILK, Vector2(hr.position.x, hr.position.y + 9.0), labels[i], HORIZONTAL_ALIGNMENT_CENTER, hr.size.x, 8, UIStyle.WOOD_INK)
		else:
			_out(Vector2(hr.position.x, hr.position.y + 9.0), labels[i], SkillTreeDraw.TEXT_OFF, HORIZONTAL_ALIGNMENT_CENTER, hr.size.x)
		hit(hr, "w:" + str(vis[i]), false)
		x += w


## The open tree's parchment card: the inspected node in full, and at the bunk the tree's refund.
func _draw_card(card: Rect2) -> void:
	var p := _pr()
	var col: Color = SkillTrees.tree_def(tree)["color"]
	draw_style_box(UIStyle.parchment(), card)
	var x := card.position.x + 10.0
	var w := card.size.x - 20.0
	var y := card.position.y + 24.0
	var limit := card.end.y - 12.0
	var respec := p.can_respec() and p.respec_why(tree) != "Nothing bought"
	var ins := inspected()
	if ins.begins_with("n:") and SkillTrees.node_def(ins.substr(2)).get("tree", "") == tree:
		_node_info(ins.substr(2), x, y, w, limit - (30.0 if respec else 0.0), col)
	else:
		_para(Vector2(x, y), "Pick a node to see what it does, what it needs and what it costs.", w, UIStyle.PARCH_DIM, limit)
	if respec:
		var br := Rect2(x, limit - 16.0, w, 15)
		var armed := _respec_armed == tree
		draw_rect(br, UIStyle.CORAL if armed else Color("d9cdb0"))
		draw_rect(br, UIStyle.BORDER_DIM, false, 1.0)
		var label := ("CLICK AGAIN: %d GOLD" if armed else "REFUND THIS TREE: %d GOLD") % p.respec_price()
		draw_string(SILK, Vector2(br.position.x, br.position.y + 11.0), label, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 8, UIStyle.INK)
		hit(br, "respec", false)


## The inspected node on parchment: name and kind, its gate against your level and its price, what it does, what
## Enter does. Returns the y under it.
func _node_info(nid: String, x: float, y: float, w: float, limit: float, col: Color) -> float:
	var p := _pr()
	var n := SkillTrees.node_def(nid)
	var kind := str(n["kind"])
	draw_string(_font, Vector2(x, y), str(n["name"]), HORIZONTAL_ALIGNMENT_LEFT, w, 12, UIStyle.PARCH_INK)
	y += 10.0
	var t := str(n["tree"])
	var tag := str(SkillTreeDraw.KIND_NAME.get(kind, kind)).to_upper()
	if kind == "step":
		tag += " · %d OF %d" % [p.steps_of(nid), int(n["max_steps"])]
	draw_string(SILK, Vector2(x, y), tag, HORIZONTAL_ALIGNMENT_LEFT, w, 8, SkillTreeDraw.kind_color(kind, col).darkened(0.5))
	y += 11.0
	var price := SkillTrees.price(nid)
	if price > 0 and not (p.owns(nid) and kind != "step"):
		var met := p.tree_level(t) >= int(n["level"])
		draw_string(SILK, Vector2(x, y), "NEEDS %s %d%s" % [Progression.tree_name(t).to_upper(), int(n["level"]), "" if met else " · NOW %d" % p.tree_level(t)],
			HORIZONTAL_ALIGNMENT_LEFT, w, 8, Color("2f7a3a") if met else UIStyle.CORAL.darkened(0.35))
		y += 9.0
		var pool := SkillTrees.pool_of(t)
		draw_string(SILK, Vector2(x, y), "PRICE %d%s  ·  %d %s LEFT" % [price, " A STEP" if kind == "step" else "", p.pool(pool), Progression.pool_name(pool).to_upper()],
			HORIZONTAL_ALIGNMENT_LEFT, w, 8, UIStyle.PARCH_DIM)
		y += 9.0
	y += 4.0
	if kind == "variant" or kind == "talent":
		for i in range(n["versions"].size()):
			var v: Dictionary = n["versions"][i]
			var on: bool = (p.owns(nid) and maxi(p.version_of(nid), 0) == i) if kind == "variant" else p.version_of(nid) == i
			y = _para(Vector2(x, y), "%s%s: %s" % ["> " if on else "", v["name"], v["desc"]], w, UIStyle.PARCH_INK if on else UIStyle.PARCH_DIM, limit) + 2.0
	else:
		y = _para(Vector2(x, y), str(n["desc"]), w, UIStyle.PARCH_INK, limit)
	if kind == "root" and GROWS.has(t):
		y = _para(Vector2(x, y + 2.0), "How it grows: " + str(GROWS[t]), w, UIStyle.PARCH_DIM, limit)
	var why := p.buy_why(nid)
	var status := ""
	var good := why == ""
	if (kind == "variant" and p.owns(nid)) or kind == "talent":
		if kind == "talent" and p.version_of(nid) < 0:
			good = int(n["level"]) <= p.level
			status = "PICK ONE: ENTER" if good else "AT CAPTAIN %d" % int(n["level"])
		else:
			status = "BOTH YOURS: SWITCH AT A REST SPOT" if kind == "variant" else "CHANGE AT A REST SPOT"
			good = p.can_respec()
	elif kind != "step" and p.owns_node(nid):
		status = "YOURS" + ("  ·  1-5/R: ON THE BAR" if str(n["skill"]) != "" else "")
		good = true
	elif good:
		status = "ENTER: BUY"
	else:
		status = why.to_upper()
	for l in _wrap(status, w, SILK, 8):
		draw_string(SILK, Vector2(x, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("2f7a3a") if good else UIStyle.CORAL.darkened(0.35))
		y += 9.0
	return y


## A small note by the cursor for the hovered node: its name and, if it's not yours yet, its price and gate.
func _draw_tip() -> void:
	if not hover.begins_with("n:"):
		return
	var nid := hover.substr(2)
	var n := SkillTrees.node_def(nid)
	if n.is_empty():
		return
	var p := _pr()
	var line := str(n["name"]).to_upper()
	var price := SkillTrees.price(nid)
	if n["kind"] == "step":
		line += "  ·  %d/%d" % [p.steps_of(nid), int(n["max_steps"])]
	if p.owns(nid) and n["kind"] != "step":
		line += "  ·  YOURS"
	elif price > 0 and p.buy_why(nid) != "Full":
		var why := p.buy_why(nid)
		line += "  ·  %d PT%s  ·  %s" % [price, "" if price == 1 else "S", "ENTER: BUY" if why == "" else why.to_upper()]
	var tw := SILK.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 10.0
	var at := _mouse + Vector2(12, 14)
	var r := Rect2(minf(at.x, size.x - tw - 4.0), minf(at.y, size.y - 40.0), tw, 13)
	draw_style_box(UIStyle.chrome("paper", 0, 0), r)
	draw_string(SILK, r.position + Vector2(5, 10), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.PARCH_INK)


# --------------------------------------------------------------------------
# Combat: the chart of every weapon
# --------------------------------------------------------------------------
func _draw_chart(whole: Rect2) -> void:
	var p := _pr()
	var body := _draw_header(whole, "")
	var vis := p.visible_trees("combat")
	var c := (body.get_center() + Vector2(0, 6)).round()
	var hub := clampf(body.size.y * 0.22, 56.0, 110.0)
	var reach := hub * 0.85
	var hand := SkillTree.style_tree(_player().style()) if _player().armed else ""
	for i in range(vis.size()):
		var t: String = vis[i]
		var col := _tree_color(t)
		var deg := -90.0 + i * 360.0 / vis.size()
		var a := deg_to_rad(deg)
		var dir := Vector2(cos(a), sin(a))
		var hp := (c + dir * hub).round()
		var grown := p.tree_level(t) > 1
		SkillTreeDraw._link(self, c + dir * 29.0, hp, col, grown, false)
		var td := SkillTrees.tree_def(t)
		for b in range(td["branches"].size()):
			var ba := deg_to_rad(deg + [-24.0, 0.0, 24.0][mini(b, 2)])
			var bd := Vector2(cos(ba), sin(ba))
			var prev := hp
			var bigs: Array = td["branches"][b]["nodes"].filter(func(k): return SkillTrees.node_def(k)["kind"] != "step")
			var most := mini(bigs.size(), 5)
			for j in range(most):
				var q := (hp + bd * (24.0 + j * (reach - 24.0) / maxf(most - 1, 1))).round()
				var on := p.owns_node(bigs[j])
				SkillTreeDraw._link(self, prev, q, col, on, true)
				draw_rect(Rect2(q - Vector2(3, 3), Vector2(7, 7)), UIChrome.INK)
				draw_rect(Rect2(q - Vector2(2, 2), Vector2(5, 5)), col if on else SkillTreeDraw.DIM_RIM)
				draw_rect(Rect2(q - Vector2(1, 1), Vector2(3, 3)), SkillTreeDraw.NODE_BG)
				prev = q
		var hr := Rect2(hp - Vector2(13, 13), Vector2(26, 26))
		if t == hand:
			draw_rect(hr.grow(3.0), Color(UIStyle.GILT, 0.3))
		draw_rect(hr.grow(1.0), UIChrome.INK)
		draw_rect(hr, UIStyle.GILT if t == hand else col)
		draw_rect(hr.grow(-2.0), SkillTreeDraw.NODE_BG)
		var ic := SkillTreeDraw.tree_icon(t)
		if ic:
			draw_texture_rect(ic, Rect2(hp - Vector2(12, 12), Vector2(24, 24)), false)
		else:
			draw_string(SILK, Vector2(hr.position.x, hp.y + 3.0), SkillTreeDraw.glyph(Progression.tree_name(t)), HORIZONTAL_ALIGNMENT_CENTER, 26, 8, col)
		hit(hr, "w:" + t)
		if inspected() == "w:" + t:
			draw_rect(hr.grow(4.0), Color(UIStyle.CREAM, 0.6 + 0.4 * sin(_t * 5.0)), false, 1.0)
		var lp := (c + dir * (hub + (reach + 16.0 if not td["branches"].is_empty() else 26.0))).round()
		var side := 0 if absf(dir.x) < 0.3 else (1 if dir.x > 0.0 else -1)
		var lx := lp.x + (16.0 if side == 0 else (-6.0 if side > 0 else -134.0))
		var al := HORIZONTAL_ALIGNMENT_LEFT if side >= 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var los := _loadouts_of(t).map(func(n): return "LOADOUT %d" % (n + 1))
		if t == hand:
			los.append("IN HAND")
		_out(Vector2(lx, lp.y - 6.0), Progression.tree_name(t).to_upper(), col, al, 140.0)
		_out(Vector2(lx, lp.y + 3.0), "MASTERY %d/%d%s" % [p.tree_level(t), SkillTrees.max_level(t), " · %d PTS" % p.pool(t) if p.pool(t) > 0 else ""], UIStyle.CREAM, al, 140.0)
		if not los.is_empty():
			_out(Vector2(lx, lp.y + 12.0), " · ".join(los), UIStyle.GILT, al, 140.0)
	draw_circle(c, 28.0, UIChrome.INK)
	draw_circle(c, 27.0, UIStyle.GILT)
	draw_circle(c, 25.0, SkillTreeDraw.ROOT_BG)
	draw_string(SILK, Vector2(c.x - 30.0, c.y - 6.0), "CAPTAIN", HORIZONTAL_ALIGNMENT_CENTER, 60, 8, UIStyle.TEXT_DIM)
	UIStyle.draw_title(self, Vector2(c.x - 30.0, c.y + 10.0), "Lv %d" % p.level, 18, HORIZONTAL_ALIGNMENT_CENTER, 60)
	var key := Rect2(Vector2(body.end.x - 132.0, body.position.y), Vector2(132, 66))
	draw_style_box(UIStyle.chrome("slate"), key)
	UIStyle.draw_ribbon(self, key.position + Vector2(7, 7), "Key", true)
	var ky := key.position.y + 30.0
	for row in [[0, "A BIG NODE YOU HAVE"], [1, "STILL TO LEARN"], [2, "IN A LOADOUT"]]:
		var q := Vector2(key.position.x + 14.0, ky)
		if row[0] < 2:
			draw_rect(Rect2(q - Vector2(3, 3), Vector2(7, 7)), UIChrome.INK)
			draw_rect(Rect2(q - Vector2(2, 2), Vector2(5, 5)), Color("b3d9ff") if row[0] == 0 else SkillTreeDraw.DIM_RIM)
			draw_rect(Rect2(q - Vector2(1, 1), Vector2(3, 3)), SkillTreeDraw.NODE_BG)
		else:
			draw_rect(Rect2(q - Vector2(3, 3), Vector2(7, 7)), UIStyle.GILT)
		draw_string(SILK, Vector2(q.x + 9.0, ky + 3.0), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.TEXT_DIM)
		ky += 11.0


# --------------------------------------------------------------------------
# Adventure: the found trees beside the open one
# --------------------------------------------------------------------------
func _draw_adventure(whole: Rect2) -> void:
	var p := _pr()
	var body := _draw_header(whole, tree)
	var lw := 112.0
	var x := body.position.x
	var y := body.position.y
	var vis := p.visible_trees("adventure")
	for t in vis:
		var on: bool = t == tree
		var r := Rect2(x, y, lw, 26)
		draw_style_box(UIStyle.frame(UIStyle.BG_LIGHT if on else Color(UIStyle.BG_DARK, 0.9), UIStyle.SUN if on else UIStyle.OUTLINE, 0, "chip"), r)
		var col := _tree_color(t)
		draw_string(_font, Vector2(x + 5.0, y + 13.0), Progression.tree_name(t), HORIZONTAL_ALIGNMENT_LEFT, lw - 40.0, 12, UIStyle.CREAM)
		draw_string(SILK, Vector2(x, y + 12.0), "LV %d" % p.tree_level(t), HORIZONTAL_ALIGNMENT_RIGHT, lw - 5.0, 8, col)
		_bar(Rect2(x + 5.0, y + 19.0, lw - 10.0, 2), _frac(t), col, false)
		hit(r, "w:" + t, false)
		y += 29.0
	_para(Vector2(x, maxf(y + 8.0, body.end.y - 26.0)), "Keep trying new things: more trees are out there.", lw, Color("7f9894"))
	var card := Rect2(body.end.x - CARD_W, body.position.y, CARD_W, body.size.y - 2.0)
	var area := Rect2(x + lw + 6.0, body.position.y, card.position.x - x - lw - 12.0, body.size.y)
	SkillTreeDraw.draw_tree(self, tree, area, p, _t)
	_draw_card(card)


## The Captain page: the level strip (level, XP, the Perks button) and the Will paths' row over the open path's ladder,
## the Will card on the right; the perks popup over it all when open.
func _draw_captain(body: Rect2) -> void:
	var p := _pr()
	var pw := 236.0 if body.size.x > 700.0 else 200.0
	var top := body.position.y + 2.0
	var panel := Rect2(body.end.x - pw, top, pw, body.end.y - top)
	var field := Rect2(body.position.x, top, panel.position.x - body.position.x - 8.0, body.end.y - top)
	_draw_capbar(Rect2(field.position, Vector2(field.size.x, 16)))
	_draw_path_row(Rect2(field.position.x, top + 20.0, field.size.x, 32))
	_draw_ladder(Rect2(field.position.x, top + 58.0, field.size.x, field.end.y - top - 58.0), p.will_tint())
	_draw_will_card(panel, _will_shown())
	if perks_open:
		# (only the popup is clickable while it's open)
		_hits = []
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.62))
		var m := 44.0 if size.x < 700.0 else 90.0
		_draw_perks(Rect2(m, 34.0, size.x - m * 2.0, size.y - UIChrome.BOARD_H - 40.0))


## Level, the XP bar and the Perks button (lit, with a pip, while a fork waits to be picked).
func _draw_capbar(r: Rect2) -> void:
	var p := _pr()
	_box(r, SkillTreeDraw.NODE_BG, SkillTreeDraw.DIM_RIM)
	var lv := "Level %d" % p.level
	draw_string(_font, Vector2(r.position.x + 6.0, r.position.y + 12.0), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.CREAM)
	var x := r.position.x + 10.0 + _font.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(SILK, Vector2(x, r.position.y + 11.0), "OF %d" % Progression.MAX_LEVEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, SkillTreeDraw.TEXT_OFF)
	x += 34.0
	var ready := perk_ready()
	var label := "PERKS · %s" % ("PICK ONE" if ready else "%d / %d" % [_forks().filter(func(k): return p.version_of(k) >= 0).size(), _forks().size()])
	var bw := SILK.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 26.0
	var b := Rect2(r.end.x - bw - 3.0, r.position.y + 2.0, bw, 12)
	var xp := "%d / %d XP" % [p.xp, Progression.xp_to_next(p.level)] if p.level < Progression.MAX_LEVEL else "MAX"
	var xw := SILK.get_string_size(xp, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_bar(Rect2(x, r.position.y + 6.0, b.position.x - x - xw - 12.0, 4), _frac("captain"), UIStyle.TEAL_LIGHT, false)
	draw_string(SILK, Vector2(b.position.x - xw - 6.0, r.position.y + 11.0), xp, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, SkillTreeDraw.TEXT_OFF)
	var on := inspected() == "perks"
	if ready:
		_glow(b, UIStyle.GILT)
	_box(b, UIStyle.GILT if ready else SkillTreeDraw.ROOT_BG, Color.WHITE if on else (UIStyle.BORDER_DIM if ready else UIStyle.GILT))
	_key_cap(Vector2(b.position.x + 3.0, b.position.y + 2.0), "P", ready)
	draw_string(SILK, Vector2(b.position.x + 16.0, b.position.y + 9.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.INK if ready else UIStyle.GILT)
	if ready:
		UIStyle.draw_pip(self, b.end - Vector2(1, b.size.y - 1), _t)
	hit(b, "perks", false)


## A small key cap ("P") in a button.
func _key_cap(pos: Vector2, k: String, dark: bool) -> void:
	var w := SILK.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 4.0
	draw_rect(Rect2(pos, Vector2(w, 8)), UIStyle.INK if dark else UIStyle.CREAM)
	draw_string(SILK, pos + Vector2(2, 7), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.CREAM if dark else UIStyle.INK)


## A soft breathing glow round `r` (something to act on now).
func _glow(r: Rect2, col: Color) -> void:
	var a := 0.5 + 0.5 * sin(_t * 3.5)
	draw_rect(r.grow(3.0), Color(col, 0.10 + 0.14 * a))
	draw_rect(r.grow(1.5), Color(col, 0.18 + 0.22 * a))


## A dashed rim (a card not open yet).
func _dashed(r: Rect2, col: Color) -> void:
	for e in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end], [r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
		draw_dashed_line(e[0], e[1], col, 1.0, 3.0)


## The seven Will paths in a row: emblem, name, Will spent (or why it's shut); the open one lit with a notch under it,
## a pip on any with something to buy now.
func _draw_path_row(r: Rect2) -> void:
	var p := _pr()
	var tint := p.will_tint()
	var n := WillPaths.PATHS.size()
	var cw := floorf((r.size.x - 3.0 * (n - 1)) / n)
	for i in range(n):
		var path: String = WillPaths.PATHS[i]
		var c := Rect2(r.position.x + i * (cw + 3.0), r.position.y, cw, r.size.y)
		var open := path == will_path
		var why := WillPaths.path_why(p, path)
		var spent := WillPaths.spent_in(p, path)
		var on := inspected() == "path:" + path
		_box(c, tint.darkened(0.7) if open else SkillTreeDraw.NODE_BG, Color.WHITE if on else (tint if open else (SkillTreeDraw.DIM_RIM if why == "" else SkillTreeDraw.DIM_LINK)))
		var ic := Skills.icon(PATH_ICONS[path])
		if ic:
			draw_texture_rect(ic, Rect2(c.get_center().x - 7.0, c.position.y + 3.0, 14, 14), false, Color.WHITE if why == "" else Color(0.5, 0.5, 0.5, 0.6))
		var name_s := "CAPTAIN'S" if path == "conq" else str(WillPaths.PATH_NAMES[path]).to_upper()
		draw_string(SILK, Vector2(c.position.x, c.position.y + 22.0), name_s, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 8,
			UIStyle.CREAM if open or spent > 0 else (SkillTreeDraw.TEXT_OFF if why == "" else SkillTreeDraw.TAG_OFF))
		draw_string(SILK, Vector2(c.position.x, c.position.y + 29.5), ("%d SPENT" % spent) if why == "" else "SHUT", HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 8,
			UIStyle.TEAL_LIGHT if spent > 0 else SkillTreeDraw.TAG_OFF)
		if open:
			var cx := c.get_center().x
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 4, c.end.y), Vector2(cx + 4, c.end.y), Vector2(cx, c.end.y + 4)]), tint)
		if spent > 0 and path_ready(path):
			UIStyle.draw_pip(self, Vector2(c.end.x - 1.0, c.position.y + 1.0), _t)
		hit(c, "path:" + path, false)


## The open path as a ladder: its tiers from T1 at the foot up, each ability's versions as cards side by side, the
## spine lit up to the highest tier you have; its passive along the bottom.
func _draw_ladder(r: Rect2, tint: Color) -> void:
	var p := _pr()
	var path := will_path
	_box(r, Color(WILL_DARK, 0.85), tint.darkened(0.45))
	var why := WillPaths.path_why(p, path)
	draw_string(_font, Vector2(r.position.x + 6.0, r.position.y + 13.0), str(WillPaths.PATH_NAMES[path]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.CREAM)
	var rule := "TIERS AT 4 / 8 WILL SPENT · YOU %d" % WillPaths.spent_all(p) if path in WillPaths.OPEN else \
		("TIERS AT %s IN IT · %d IN IT" % ["4 / 8" if path != "conq" else "4", WillPaths.spent_in(p, path)])
	draw_string(SILK, Vector2(r.position.x, r.position.y + 12.0), (why if why != "" else rule).to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 6.0, 8,
		UIStyle.CORAL if why != "" else SkillTreeDraw.TEXT_OFF)
	var ids: Array = WillPaths.abilities_of(path)
	var area := Rect2(r.position.x, r.position.y + 18.0, r.size.x, r.size.y - 36.0)
	var row_h := floorf(area.size.y / maxi(ids.size(), 3))
	var sx := r.position.x + 15.0
	var lit := area.end.y
	for k in range(ids.size()):
		if p.has_will(ids[k]):
			lit = area.end.y - row_h * (k + 1) + row_h * 0.5
	draw_rect(Rect2(sx - 1.0, area.end.y - row_h * ids.size() + row_h * 0.5, 2, row_h * (ids.size() - 1) + row_h * 0.5), WILL_DIM)
	draw_rect(Rect2(sx - 1.0, lit, 2, area.end.y - lit), tint)
	for k in range(ids.size()):
		var aid: String = ids[k]
		var an := SkillTrees.node_def(aid)
		var ry := area.end.y - row_h * (k + 1)
		var tb := Rect2(sx - 10.0, roundf(ry + row_h * 0.5 - 8.0), 20, 16)
		var opened := WillPaths.why(p, str(an["versions"][0]["id"])) in ["", "Learned"] or p.has_will(aid)
		_box(tb, WILL_DARK, tint if p.has_will(aid) or opened else WILL_DIM)
		draw_string(SILK, Vector2(tb.position.x, tb.position.y + 11.0), "T%d" % int(an["tier"]), HORIZONTAL_ALIGNMENT_CENTER, tb.size.x, 8, UIStyle.CREAM if opened else WILL_DIM)
		var vs: Array = an["versions"]
		var x0 := sx + 16.0
		var w := r.end.x - 5.0 - x0
		var cw := floorf((w - 4.0 * (vs.size() - 1)) / vs.size())
		for i in range(vs.size()):
			_will_card(Rect2(x0 + i * (cw + 4.0), ry + 3.0, cw, row_h - 6.0), aid, i, tint, vs.size() >= 3)
	for pid in WillPaths.PASSIVES:
		if WillPaths.PASSIVES[pid][0] == path:
			_will_passive_row(Rect2(r.position.x + 4.0, r.end.y - 16.0, r.size.x - 8.0, 13), pid, tint)


## One version of a Will ability as a card. Carried: filled in your Will colour with a tick; yours: rimmed; to buy now:
## a gold breathing rim and its price; not open yet: dashed and grey. `compact` (3+ versions in a row): name and state only.
func _will_card(r: Rect2, aid: String, i: int, tint: Color, compact: bool) -> void:
	var p := _pr()
	var an := SkillTrees.node_def(aid)
	var v: Dictionary = an["versions"][i]
	var vid := str(v["id"])
	var mine := p.has_version(vid)
	var carried := mine and p.version_of(aid) == i
	var why := "" if mine else p.buy_why(vid)
	var can := not mine and why == ""
	var on := inspected() == "n:" + vid
	if can:
		_glow(r, UIStyle.GILT)
	_box(r, tint.darkened(0.62) if carried else (tint.darkened(0.78) if mine else WILL_DARK), tint if carried else (tint.darkened(0.2) if mine else (UIStyle.GILT if can else WILL_DARK)))
	if not mine and not can:
		_dashed(r.grow(-0.5), WILL_DIM)
	var ib := Rect2(r.position + Vector2(4, 4), Vector2(18, 18))
	_box(ib, UIStyle.OUTLINE, tint if mine else (UIStyle.GILT if can else WILL_DIM))
	var ic := Skills.icon(str(v["skill"]) if str(v["skill"]) != "" else str(WILL_ICONS.get(vid, "")))
	if ic:
		draw_texture_rect(ic, ib.grow(-1.0), false, Color.WHITE if mine or can else Color(0.55, 0.55, 0.6, 0.7))
	var name_col := UIStyle.CREAM if mine or can else Color("8b80b0")
	draw_string(_font, Vector2(r.position.x + 26.0, r.position.y + 13.0), str(v["name"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28.0, 12, name_col)
	var tag := "CARRIED" if carried else ("YOURS" if mine else ("BUY · %d" % SkillTrees.price(vid) if can else "SHUT"))
	var tag_col := tint.lightened(0.35) if mine else (UIStyle.GILT if can else WILL_DIM)
	if compact:
		draw_string(SILK, Vector2(r.position.x + 26.0, r.position.y + 22.0), tag, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28.0, 8, tag_col)
		if r.size.y >= 40.0:
			_lines(Vector2(r.position.x + 4.0, r.position.y + 33.0), str(v["desc"]), r.size.x - 8.0,
				Color("b9a9c9") if mine or can else Color("6b6890"), 9.0, int((r.size.y - 28.0) / 9.0))
	else:
		var tw := SILK.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + (14.0 if carried else 6.0)
		var tr := Rect2(r.end.x - tw - 3.0, r.position.y + 3.0, tw, 10)
		if carried or can:
			draw_rect(tr, tint if carried else UIStyle.GILT)
		if carried:
			draw_polyline(PackedVector2Array([tr.position + Vector2(3, 5), tr.position + Vector2(5, 7), tr.position + Vector2(9, 2)]), UIStyle.CREAM, 1.0)
		draw_string(SILK, Vector2(tr.end.x - SILK.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x - 3.0, tr.position.y + 8.0), tag,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.CREAM if carried else (UIStyle.INK if can else tag_col))
		if r.size.y >= 32.0:
			_lines(Vector2(r.position.x + 26.0, r.position.y + 23.0), str(v["desc"]), r.size.x - 30.0,
				Color("b9a9c9") if mine or can else Color("6b6890"), 9.0, int((r.size.y - 18.0) / 9.0))
	hit(r, "n:" + vid)
	if on:
		draw_rect(r.grow(1.0), Color(UIStyle.CREAM, 0.6 + 0.4 * sin(_t * 5.0)), false, 1.0)


## The path's passive along the ladder's foot: its icon, name and where it stands.
func _will_passive_row(r: Rect2, pid: String, tint: Color) -> void:
	var p := _pr()
	var mine := p.has_version(pid)
	var why := "" if mine else p.buy_why(pid)
	var can := not mine and why == ""
	var on := inspected() == "n:" + pid
	if can:
		_glow(r, UIStyle.GILT)
	draw_rect(Rect2(r.position.x, r.position.y - 2.0, r.size.x, 1), WILL_DIM)
	var ic := Skills.icon(str(WILL_ICONS.get(pid, "")))
	if ic:
		draw_texture_rect(ic, Rect2(r.position + Vector2(2, 0), Vector2(12, 12)), false, Color.WHITE if mine or can else Color(0.55, 0.55, 0.6, 0.7))
	draw_string(SILK, Vector2(r.position.x + 18.0, r.position.y + 9.0), "PASSIVE ·", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, SkillTreeDraw.TAG_OFF)
	draw_string(_font, Vector2(r.position.x + 70.0, r.position.y + 10.0), str(SkillTrees.node_def(pid)["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		UIStyle.CREAM if mine or can else Color("8b80b0"))
	var slot := p.passives.find(pid)
	var state := ("IN SLOT %d" % (slot + 1)) if slot >= 0 else ("YOURS · ENTER: INTO A SLOT" if mine else ("BUY · %d" % SkillTrees.price(pid) if can else why.to_upper()))
	draw_string(SILK, Vector2(r.position.x, r.position.y + 9.0), state, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 4.0, 8,
		UIStyle.GOOD if mine else (UIStyle.GILT if can else WILL_DIM))
	hit(r, "n:" + pid)
	if on:
		draw_rect(r.grow(1.0), Color(UIStyle.CREAM, 0.6 + 0.4 * sin(_t * 5.0)), false, 1.0)


## The perks popup: every level fork in one list (its level, its two options, the milestones that come with it), the
## fork to pick now lit with a pip, those ahead dashed; the inspected option in full at the foot.
func _draw_perks(r: Rect2) -> void:
	var p := _pr()
	draw_style_box(UIStyle.panel(), r)
	var x := r.position.x + 12.0
	var w := r.size.x - 24.0
	UIStyle.draw_title(self, Vector2(x, r.position.y + 22.0), "Captain's Perks", 18)
	var g := SkillTrees.GROWTH
	_lines(Vector2(x, r.position.y + 34.0), "Every 5 levels pick one of two. Change a pick at a rest spot (the bunk, an inn, your camp). Every level: +%s HP, +%d%% dmg, +%s stamina and energy, +%s def." %
		[g["max_hp"], roundi(g["damage_pct"] * 100.0), g["max_stamina"], g["defense"]], w, SkillTreeDraw.TEXT_OFF, 9.0, 2)
	var forks := _forks()
	var miles := _captain_kind("auto")
	var top := r.position.y + 54.0
	var foot := 30.0
	var rh := floorf((r.end.y - top - foot) / forks.size())
	var mw := 92.0
	var ow := floorf((w - 34.0 - mw - 8.0) * 0.5)
	var prev := 0
	for k in range(forks.size()):
		var nid: String = forks[k]
		var lv := int(SkillTrees.node_def(nid)["level"])
		var y := top + k * rh
		var reached := lv <= p.level
		var pick := p.version_of(nid)
		var ready := reached and pick < 0
		var lb := Rect2(x, y, 30, rh - 3.0)
		_box(lb, UIStyle.GILT if ready else SkillTreeDraw.NODE_BG, UIStyle.GILT if reached else SkillTreeDraw.DIM_LINK)
		draw_string(SILK, Vector2(lb.position.x, lb.position.y + lb.size.y * 0.5 + 4.0), "LV%d" % lv, HORIZONTAL_ALIGNMENT_CENTER, lb.size.x, 8,
			UIStyle.INK if ready else (UIStyle.GILT if reached else SkillTreeDraw.TAG_OFF))
		if ready:
			UIStyle.draw_pip(self, Vector2(lb.end.x - 1.0, lb.position.y + 1.0), _t)
		var vs: Array = SkillTrees.node_def(nid)["versions"]
		for i in range(2):
			_perk_card(Rect2(x + 34.0 + i * (ow + 4.0), y, ow, rh - 3.0), nid, i, vs[i], reached, pick)
		var here := miles.filter(func(m): return int(SkillTrees.node_def(m)["level"]) > prev and int(SkillTrees.node_def(m)["level"]) <= lv)
		var my := y + 8.0
		for m in here:
			var own := p.owns_node(m)
			draw_string(SILK, Vector2(x + w - mw, my), str(SkillTrees.node_def(m)["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, mw, 8,
				UIStyle.GOOD if own else SkillTreeDraw.TAG_OFF)
			my += 9.0
		if here.is_empty() and ready:
			draw_string(SILK, Vector2(x + w - mw, y + 8.0), "PICK ONE", HORIZONTAL_ALIGNMENT_LEFT, mw, 8, UIStyle.GILT)
		prev = lv
	# the inspected option in full
	var shown := inspected() if inspected().begins_with("f:") else sel
	if shown.begins_with("f:"):
		var n := SkillTrees.node_def(shown.get_slice(":", 1))
		var v: Dictionary = n["versions"][int(shown.get_slice(":", 2))]
		var fy := r.end.y - foot + 6.0
		draw_rect(Rect2(x, fy - 4.0, w, 1), SkillTreeDraw.DIM_RIM)
		draw_string(_font, Vector2(x, fy + 9.0), str(v["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.GILT)
		var nw := _font.get_string_size(str(v["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8.0
		_lines(Vector2(x + nw, fy + 8.0), str(v["desc"]), w - nw, UIStyle.CREAM, 9.0, 2)


## One option of a fork in the popup: icon, name, the first line of what it does. Picked: gold with a tick, its sibling
## faded; the fork to pick now: a gold breathing rim; ahead: dashed.
func _perk_card(r: Rect2, nid: String, i: int, v: Dictionary, reached: bool, pick: int) -> void:
	var id := "f:%s:%d" % [nid, i]
	var picked := pick == i
	var other := pick >= 0 and not picked
	var open := reached and pick < 0
	if open:
		_glow(r, UIStyle.GILT)
	_box(r, SkillTreeDraw.NODE_BG.lerp(UIStyle.GILT, 0.18) if picked else SkillTreeDraw.NODE_BG,
		UIStyle.GILT if picked or open else (SkillTreeDraw.DIM_RIM if reached else SkillTreeDraw.NODE_BG))
	if not reached:
		_dashed(r.grow(-0.5), SkillTreeDraw.DIM_RIM)
	var ib := Rect2(r.position + Vector2(3, (r.size.y - 16.0) * 0.5), Vector2(16, 16))
	_box(ib, UIStyle.OUTLINE, UIStyle.GILT if picked else SkillTreeDraw.DIM_RIM)
	var ic := Skills.icon(str(v["skill"]) if str(v["skill"]) != "" else "perk_" + str(v["id"]))
	if ic:
		draw_texture_rect(ic, ib.grow(-1.0), false, Color.WHITE if not other else Color(1, 1, 1, 0.45))
	else:
		draw_string(SILK, Vector2(ib.position.x, ib.position.y + 11.0), SkillTreeDraw.glyph(str(v["name"])), HORIZONTAL_ALIGNMENT_CENTER, 16, 8,
			UIStyle.GILT if picked else SkillTreeDraw.TEXT_OFF)
	var fade := other or not reached
	draw_string(_font, Vector2(r.position.x + 23.0, r.position.y + 11.0), str(v["name"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36.0, 12,
		UIStyle.GILT if picked else (Color("7d918d") if fade else UIStyle.CREAM))
	var ls := _wrap(str(v["desc"]).to_upper(), r.size.x - 27.0, SILK, 8)
	if r.size.y >= 22.0 and not ls.is_empty():
		draw_string(SILK, Vector2(r.position.x + 23.0, r.position.y + 20.0), str(ls[0]) + (".." if ls.size() > 1 else ""), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 27.0, 8,
			Color("6e8285") if fade else Color("a9bfc0"))
	if picked:
		var c := Vector2(r.end.x - 9.0, r.position.y + 4.0)
		draw_polyline(PackedVector2Array([c + Vector2(0, 3), c + Vector2(2, 5), c + Vector2(6, 0)]), UIStyle.GILT, 1.5)
	hit(r, id)
	if inspected() == id:
		draw_rect(r.grow(1.0), Color(UIStyle.CREAM, 0.6 + 0.4 * sin(_t * 5.0)), false, 1.0)


func _box(r: Rect2, fill: Color, rim: Color) -> void:
	draw_rect(r, rim)
	draw_rect(r.grow(-1.0), fill)


func _diamond(c: Vector2, h: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)]), col)


## Wrapped Silkscreen 8 capitals from `pos` (the first baseline), at most `most` lines; returns the y under them.
func _lines(pos: Vector2, text: String, w: float, col: Color, step: float = 9.0, most: int = 99) -> float:
	var y := pos.y
	for l in _wrap(text.to_upper(), w, SILK, 8).slice(0, most):
		draw_string(SILK, Vector2(pos.x, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		y += step
	return y


## The Will node the card shows: the inspected one, else the pick, else Coat.
func _will_shown() -> String:
	for id in [inspected(), sel]:
		var n: Dictionary = SkillTrees.node_def(str(id).substr(2)) if str(id).begins_with("n:") else {}
		if n.get("kind", "") == "will" or n.get("pool", "") == "will":
			return n["id"]
	return "w_coat"


## The Will card: points to spend and where they come from; the shown node (its path and tier, what it does, each
## version with what Enter does or why not); the colour swatches once you have a Will.
func _draw_will_card(panel: Rect2, nid: String) -> void:
	var p := _pr()
	draw_style_box(UIStyle.parchment(), panel)
	var x := panel.position.x + 12.0
	var w := panel.size.x - 24.0
	var y := panel.position.y + 22.0
	var pts := p.pool("will")
	UIStyle.draw_title(self, Vector2(x, y), "%d Will" % pts, 18, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	draw_string(SILK, Vector2(x + UIStyle.TITLE_FONT.get_string_size("%d Will" % pts, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 6.0, y), "TO SPEND", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.PARCH_DIM)
	y = _lines(Vector2(x, y + 11.0), "Big fights: a boss or villain 2, a rival captain or sergeant 1. Meditating at sea: %d%% to the next." %
		roundi(100.0 * float(p.downtime.get("meditate_s", 0.0)) / WillPaths.MEDITATE_SECS), w, UIStyle.PARCH_DIM) + 2.0
	UIStyle.draw_rule(self, Rect2(x, y, w, 7))
	y += 18.0
	var n := SkillTrees.node_def(nid)
	var aid := str(n.get("parent", nid))
	var an := SkillTrees.node_def(aid)
	var path := str(an["path"])
	var head := "%s · %s" % [WillPaths.PATH_NAMES[path], ("tier %d" % int(an["tier"])) if an["kind"] == "will" else "passive, %d Will" % WillPaths.PASSIVE_COST]
	draw_string(SILK, Vector2(x, y), head.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w, 8, WILL.darkened(0.55))
	UIStyle.draw_title(self, Vector2(x, y + 17.0), str(an["name"]), 18, HORIZONTAL_ALIGNMENT_LEFT, w, true)
	var mine_any := p.bought.keys().any(func(k): return SkillTrees.node_pool(k) == "will")
	var limit := panel.end.y - (40.0 if mine_any else 12.0)
	y = _para(Vector2(x, y + 30.0), str(an["desc"]).trim_prefix("Passive (a slot). "), w, UIStyle.PARCH_INK, limit) + 2.0
	if an["kind"] == "will":
		for i in range(an["versions"].size()):
			if y + 30.0 > limit:
				break
			var v: Dictionary = an["versions"][i]
			var vid := str(v["id"])
			var mine := p.has_version(vid)
			var why := p.buy_why(vid)
			var state := "CARRIED" if mine and p.version_of(aid) == i else ("YOURS · ENTER AT A REST SPOT" if mine else ("ENTER: %d WILL" % SkillTrees.price(vid) if why == "" else why.to_upper()))
			draw_string(_font, Vector2(x, y + 9.0), ("> " if vid == nid else "") + str(v["name"]), HORIZONTAL_ALIGNMENT_LEFT, w, 12, UIStyle.PARCH_INK if vid == nid or mine else UIStyle.PARCH_DIM)
			y = _lines(Vector2(x, y + 19.0), str(v["desc"]), w, UIStyle.PARCH_DIM, 9.0, 2)
			for l in _wrap(state, w, SILK, 8):
				draw_string(SILK, Vector2(x, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("2f7a3a") if mine or why == "" else UIStyle.CORAL.darkened(0.35))
				y += 9.0
			y += 3.0
	else:
		var why := p.buy_why(nid)
		var slot := p.passives.find(nid)
		var own := p.has_version(nid)
		var state := ("IN PASSIVE SLOT %d" % (slot + 1)) if slot >= 0 else ("YOURS · ENTER: INTO A SLOT" if own else ("ENTER: %d WILL" % SkillTrees.price(nid) if why == "" else why.to_upper()))
		for l in _wrap(state, w, SILK, 8):
			draw_string(SILK, Vector2(x, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("2f7a3a") if own or why == "" else UIStyle.CORAL.darkened(0.35))
			y += 9.0
	if mine_any:
		var cy := panel.end.y - 30.0
		draw_string(SILK, Vector2(x, cy), "YOUR WILL'S COLOUR" if p.will_color != "" else "PICK YOUR WILL'S COLOUR", HORIZONTAL_ALIGNMENT_LEFT, w, 8,
			UIStyle.PARCH_INK if p.will_color != "" else UIStyle.CORAL.darkened(0.35))
		var sw := floorf((w - 12.0) / 4.0)
		var i := 0
		for cid in WillPaths.COLORS:
			var sr := Rect2(x + i * (sw + 4.0), cy + 4.0, sw, 12)
			_box(sr, WillPaths.COLORS[cid][1], UIStyle.BORDER_DIM)
			if cid == p.will_color or inspected() == "col:" + cid:
				draw_rect(sr.grow(2.0), UIStyle.INK, false, 1.0)
			hit(sr, "col:" + cid)
			i += 1


## A node's numbers as chip texts (its effects' common keys, and the skill it gives).
func _chips_of(n: Dictionary) -> Array:
	var out: Array = []
	for k in n["effects"]:
		if CHIPS.has(k):
			var c: Array = CHIPS[k]
			out.append(str(c[0]) if int(c[1]) == 0 else str(c[0]) % roundi(float(n["effects"][k]) * int(c[1])))
	if str(n["skill"]) != "":
		out.append("SKILL: " + str(Skills.get_skill(str(n["skill"]))["name"]).to_upper())
	return out


## Chips left to right from `pos` (their top), wrapping at `w`; returns the y under them (`pos.y` if none). `paint` off: measures.
func _chips(pos: Vector2, w: float, texts: Array, fill: Color, rim: Color, paint: bool = true) -> float:
	if texts.is_empty():
		return pos.y
	var x := pos.x
	var y := pos.y
	for t in texts:
		var cw := SILK.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8.0
		if x + cw > pos.x + w and x > pos.x:
			x = pos.x
			y += 14.0
		if paint:
			_box(Rect2(x, y, cw, 12), fill, rim)
			draw_string(SILK, Vector2(x + 4.0, y + 9.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.PARCH_INK)
		x += cw + 4.0
	return y + 16.0


# --------------------------------------------------------------------------
# Loadout: loadouts, the bar, passives, the library
# --------------------------------------------------------------------------
const BAR_ORDER := [0, 1, 2, 3, 5, 4]


func _draw_loadout(body: Rect2) -> void:
	var pl := _player()
	var p := _pr()
	var libw := 190.0
	var lw := body.size.x - libw - 8.0
	var x := body.position.x
	var y := body.position.y + 2.0
	var cw := (lw - 12.0) / Player.LOADOUTS
	for i in range(Player.LOADOUTS):
		var r := Rect2(x + i * (cw + 6.0), y, cw, 32)
		var locked := i >= pl.loadout_slots()
		var t := _loadout_tree(i)
		var lo: Array = pl.loadouts[i]
		var inhand := i == pl.loadout_at and not locked
		draw_style_box(UIStyle.frame(UIStyle.BG_LIGHT if inhand else (UIStyle.DISABLED if locked else UIStyle.BG_DARK), UIStyle.SUN if inhand else UIStyle.OUTLINE, 0, "chip"), r)
		var col := SkillTreeDraw.TEXT_OFF if locked else _tree_color(t)
		var ib := Rect2(r.position + Vector2(4, 4), Vector2(24, 24))
		draw_rect(ib.grow(1.0), col)
		draw_rect(ib, SkillTreeDraw.NODE_BG)
		var item: ItemData = ItemDB.get_item(lo[0]) if not lo.is_empty() and str(lo[0]) != "" else null
		if item:
			draw_texture_rect(item.icon, ib, false)
		draw_string(SILK, r.position + Vector2(32, 10), "LOADOUT %d%s" % [i + 1, " · IN HAND" if inhand else ""], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 34.0, 8, col)
		var nm := "Locked" if locked else (item.display_name if item else (("Black Leg" if lo[0] == Player.BLACK_LEG else "Fists") if not lo.is_empty() else "Empty"))
		draw_string(_font, r.position + Vector2(32, 21), nm, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 34.0, 12, SkillTreeDraw.TEXT_OFF if locked else UIStyle.CREAM)
		draw_string(SILK, r.position + Vector2(32, 29), "WITH CAPTAIN LEVELS" if locked else ("MASTERY %d" % p.tree_level(t) if t != "" else ""), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 34.0, 8, UIStyle.TEXT_DIM)
	y += 38.0
	var bar := Rect2(x, y, lw, 96)
	draw_style_box(UIStyle.chrome("slate"), bar)
	UIStyle.draw_ribbon(self, bar.position + Vector2(7, 7), "Skill bar", true)
	draw_string(SILK, bar.position + Vector2(84, 16), "ONE BAR FOR EVERY LOADOUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.TEXT_DIM)
	var sw := (lw - 16.0 - 5.0 * 5.0) / 6.0
	for j in range(BAR_ORDER.size()):
		var slot: int = BAR_ORDER[j]
		var sr := Rect2(bar.position.x + 8.0 + j * (sw + 5.0), bar.position.y + 24.0, sw, 66)
		var sk: String = pl.power.loadout[slot]
		var st := _skill_tree(sk) if sk != "" else ""
		var col := _tree_color(st) if sk != "" else SkillTreeDraw.DIM_RIM
		draw_style_box(UIStyle.frame(Color(UIStyle.BG_DARK, 0.9), UIStyle.SUN if inspected() == "bar:%d" % slot else UIStyle.OUTLINE, 0, "chip"), sr)
		var key := PowerComponent.key_of(slot)
		draw_style_box(UIStyle.chrome("keycap", 0, 0), Rect2(sr.position.x + 3.0, sr.position.y + 3.0, 11, 12))
		draw_string(SILK, Vector2(sr.position.x + 3.0, sr.position.y + 12.0), key, HORIZONTAL_ALIGNMENT_CENTER, 11, 8, UIStyle.PARCH_INK)
		var ib := Rect2(Vector2(roundf(sr.get_center().x - 13.0), sr.position.y + 4.0), Vector2(26, 26))
		draw_rect(ib.grow(1.0), col)
		draw_rect(ib, SkillTreeDraw.NODE_BG)
		if sk != "":
			var cut := _bar_why(sk).begins_with("Needs")
			draw_texture_rect(Skills.icon(sk), ib.grow(-1.0), false, Color(0.55, 0.6, 0.62, 0.45) if cut else Color.WHITE)
			var lines := _wrap(str(Skills.get_skill(sk)["name"]).to_upper(), sw - 4.0, SILK, 8)
			for li in range(mini(lines.size(), 2)):
				draw_string(SILK, Vector2(sr.position.x, sr.position.y + 40.0 + li * 9.0), lines[li], HORIZONTAL_ALIGNMENT_CENTER, sw, 8, UIStyle.CREAM)
			draw_rect(Rect2(sr.position.x + 4.0, sr.end.y - 13.0, sw - 8.0, 2), col)
			var from := "ANY WEAPON" if st in ["base", "captain", "will"] else Progression.tree_name(st).to_upper()
			draw_string(SILK, Vector2(sr.position.x, sr.end.y - 3.0), "NO LOADOUT" if cut else from, HORIZONTAL_ALIGNMENT_CENTER, sw, 8, UIStyle.DANGER_TEXT if cut else col)
		else:
			draw_string(SILK, Vector2(sr.position.x, sr.position.y + 44.0), "EMPTY", HORIZONTAL_ALIGNMENT_CENTER, sw, 8, SkillTreeDraw.TAG_OFF)
		hit(sr, "bar:%d" % slot)
	y += 102.0
	var pas := Rect2(x, y, lw, minf(body.end.y - y - 2.0, 64.0))
	draw_style_box(UIStyle.chrome("slate"), pas)
	draw_string(SILK, pas.position + Vector2(9, 15), "PASSIVES", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, SkillTreeDraw.PASSIVE)
	draw_string(SILK, pas.position + Vector2(62, 15), "%d SLOTS. A WEAPON'S COUNTS ONLY IN HAND" % p.passive_slots(), HORIZONTAL_ALIGNMENT_LEFT, lw - 70.0, 8, UIStyle.TEXT_DIM)
	var n := p.passive_slots()
	var pw := (lw - 16.0 - (n - 1) * 5.0) / n
	for i in range(n):
		var pr_ := Rect2(pas.position.x + 8.0 + i * (pw + 5.0), pas.position.y + 22.0, pw, clampf(pas.size.y - 30.0, 1.0, 34.0))
		var id: String = p.passives[i] if i < p.passives.size() else ""
		draw_style_box(UIStyle.frame(Color(UIStyle.BG, 1.0), UIStyle.SUN if inspected() == "pas:%d" % i else (_tree_color(str(_node_any(id).get("tree", ""))) if id != "" else UIStyle.OUTLINE), 0, "chip"), pr_)
		var dc := pr_.position + Vector2(11, pr_.size.y * 0.5)
		var d := PackedVector2Array([dc + Vector2(0, -6), dc + Vector2(6, 0), dc + Vector2(0, 6), dc + Vector2(-6, 0)])
		draw_colored_polygon(d, SkillTreeDraw.PASSIVE if id != "" else SkillTreeDraw.DIM_FILL)
		d.append(d[0])
		draw_polyline(d, UIStyle.CREAM if id != "" else SkillTreeDraw.DIM_RIM, 1.0)
		if id != "":
			var nd := _node_any(id)
			draw_string(_font, pr_.position + Vector2(21, 14), str(nd["name"]), HORIZONTAL_ALIGNMENT_LEFT, pw - 24.0, 12, UIStyle.CREAM)
			draw_string(SILK, pr_.position + Vector2(21, 25), Progression.tree_name(str(nd["tree"])).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, pw - 24.0, 8, _tree_color(str(nd["tree"])))
		else:
			draw_string(SILK, pr_.position + Vector2(21, pr_.size.y * 0.5 + 3.0), "SLOT %d · EMPTY" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, pw - 24.0, 8, SkillTreeDraw.TAG_OFF)
		hit(pr_, "pas:%d" % i)
	_draw_library(Rect2(body.end.x - libw, body.position.y + 2.0, libw, body.size.y - 4.0))


## Everything known, grouped by tree (the loadouts' weapons first), with where each sits now.
func _draw_library(card: Rect2) -> void:
	var pl := _player()
	var p := _pr()
	draw_style_box(UIStyle.parchment(), card)
	var x := card.position.x + 10.0
	var w := card.size.x - 22.0
	var y := card.position.y + 9.0
	UIStyle.draw_ribbon(self, Vector2(x - 2.0, y), "Library")
	y += 20.0
	var lib := p.library()
	var groups := {}
	for sk in lib["skills"]:
		var t := _group_of(_skill_tree(sk))
		if not groups.has(t):
			groups[t] = []
		groups[t].append(sk)
	for id in lib["passives"]:
		var t := _group_of(str(_node_any(id).get("tree", "base")))
		if not groups.has(t):
			groups[t] = []
		groups[t].append(id)
	var order := groups.keys()
	order.sort_custom(func(a, b): return _group_rank(a) < _group_rank(b))
	for t in order:
		if y > card.end.y - 24.0:
			draw_string(SILK, Vector2(x, card.end.y - 10.0), "AND MORE...", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.PARCH_DIM)
			break
		var col := _tree_color(t)
		var los := _loadouts_of(t)
		var head := "CAPTAIN AND WILL" if t in ["base", "captain", "will"] else ("%s · %s" % [Progression.tree_name(t).to_upper(),
			"ANY WEAPON" if SkillTrees.section_of(t) == "fruit" else ("NO LOADOUT" if los.is_empty() else " ".join(los.map(func(n): return "LOADOUT %d" % (n + 1))))])
		y += 4.0
		draw_string(SILK, Vector2(x, y + 7.0), head, HORIZONTAL_ALIGNMENT_LEFT, w, 8, UIStyle.PARCH_INK)
		draw_rect(Rect2(x, y + 9.0, w, 1), col.darkened(0.2))
		y += 13.0
		for id in groups[t]:
			if y > card.end.y - 14.0:
				break
			var r := Rect2(x - 2.0, y, w + 4.0, 13)
			var passive: bool = p.is_passive(id)
			if inspected() == "lib:" + id:
				draw_rect(r, Color(UIStyle.GILT, 0.45))
			var ib := Rect2(x, y + 0.5, 12, 12)
			draw_rect(ib, UIStyle.INK)
			if passive:
				var dc := ib.get_center()
				draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -5), dc + Vector2(5, 0), dc + Vector2(0, 5), dc + Vector2(-5, 0)]), SkillTreeDraw.PASSIVE)
			else:
				draw_texture_rect(Skills.icon(id), ib, false)
			var nm := str(_node_any(id)["name"]) if passive else str(Skills.get_skill(id)["name"])
			draw_string(SILK, Vector2(x + 16.0, y + 9.0), nm.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w - 60.0, 8, UIStyle.PARCH_INK)
			var state := ""
			var chip := Color("e8d6ae")
			if passive:
				var at := p.passives.find(id)
				state = "SLOT %d" % (at + 1) if at >= 0 else "KNOWN"
				chip = UIStyle.TEAL if at >= 0 else chip
			else:
				var at := pl.power.loadout.find(id)
				var cut := _bar_why(id).begins_with("Needs")
				state = "NEEDS A LOADOUT" if cut else (("ON %s" % PowerComponent.key_of(at)) if at >= 0 else "KNOWN")
				chip = Color("c9a49a") if cut else (UIStyle.TEAL if at >= 0 else chip)
			var sw := SILK.get_string_size(state, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 6.0
			draw_rect(Rect2(x + w - sw, y + 2.0, sw, 9), chip)
			draw_string(SILK, Vector2(x + w - sw + 3.0, y + 10.0), state, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.CREAM if chip == UIStyle.TEAL else UIStyle.INK)
			hit(r, "lib:" + id)
			y += 14.0
	if inspected().begins_with("lib:") or inspected().begins_with("bar:") or inspected().begins_with("pas:"):
		_loadout_tip(card)


## The inspected skill or passive's words, in a paper tip under the library's title.
func _loadout_tip(card: Rect2) -> void:
	var ins := inspected()
	var id := ""
	if ins.begins_with("lib:"):
		id = ins.substr(4)
	elif ins.begins_with("bar:"):
		id = _player().power.loadout[int(ins.substr(4))]
	else:
		var i := int(ins.substr(4))
		id = _pr().passives[i] if i < _pr().passives.size() else ""
	if id == "":
		return
	var passive := _pr().is_passive(id)
	var title := str(_node_any(id)["name"]) if passive else str(Skills.get_skill(id)["name"])
	var desc := str(_node_any(id)["desc"]) if passive else str(Skills.get_skill(id)["desc"])
	var w := card.size.x + 30.0
	var lines := _wrap(desc, w - 14.0, _font, 12)
	lines.resize(mini(lines.size(), 4))
	var h := 20.0 + lines.size() * 11.0
	var r := Rect2(card.position.x - 40.0, card.end.y - h - 4.0, w, h)
	draw_style_box(UIStyle.chrome("paper", 0, 0), r)
	draw_string(_font, r.position + Vector2(7, 13), title, HORIZONTAL_ALIGNMENT_LEFT, w - 14.0, 12, UIStyle.PARCH_INK)
	for i in range(lines.size()):
		draw_string(_font, r.position + Vector2(7, 25.0 + i * 11.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.PARCH_DIM)


## The library group a tree's skills and passives go in (the Captain's and Will's together).
func _group_of(t: String) -> String:
	return "captain" if t in ["base", "captain", "will"] else t


func _group_rank(t: String) -> int:
	var los := _loadouts_of(t)
	if not los.is_empty():
		return los[0]
	if t in ["base", "captain", "will"]:
		return 10
	if t == "fruit" or SkillTrees.section_of(t) == "fruit":
		return 11
	return 20
