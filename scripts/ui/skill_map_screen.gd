class_name SkillMapScreen
extends Control
## The skills menu (K), as docs/media/progression_mock: a night sky under a wooden beam with a hanging sign per tab.
##   Captain     the level trunk (round nodes that come by themselves, split talent nodes), a legend, the Will path
##   Combat      a found weapon's tree (three branches up from its root, steps for points), or the chart of them all
##   Adventure   the found Adventure trees beside the open one
##   Loadout     the weapon loadouts, the one skill bar (1-5 + R), the passive slots, the library of what you know
##   Driftfruit  the eaten fruit's tree (once there is one)
## Keys: Q / E (shoulder buttons) change tab; arrows / d-pad move between nodes; Enter / F (pad A) buys a step,
## switches a version or picks a talent (versions and changed talents only at the ship's bunk); A / D change weapon,
## Tab the chart; W / S change Adventure tree; 1-5 / R put the picked skill on the bar, 1-4 the picked passive in
## its slot. Mouse: hover inspects, click picks, click again acts, right-click clears a bar or passive slot.
## Everything is drawn here; clickable things register a hit (id, rect) as they're drawn.

const SILK := preload("res://assets/fonts/Silkscreen-Regular.woff2")
const TABS := [["captain", "Captain", "crown"], ["combat", "Combat", "swords"], ["adventure", "Adventure", "compass"],
	["loadout", "Loadout", "chest"], ["fruit", "Driftfruit", "fruit"]]
const CARD_W := 152.0
const RAIL_H := 14.0
const WILL := Color("c9a8ff")
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
## The open tree (Combat, Adventure, Driftfruit).
var tree := ""
## The picked hit: "n:<node>", "w:<tree>", "bar:<slot>", "pas:<i>", "lib:<skill or passive>".
var sel := ""
var hover := ""
var _trees: Dictionary = {}
var _hits: Array = []
var _drawn: Array = []
var _tab_rects: Array = []
var _t := 0.0
var _msg := ""
var _msg_t := 0.0
var _font: Font


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


## The tabs that show (Driftfruit once you've eaten one).
func tabs() -> Array:
	return TABS.filter(func(t): return t[0] != "fruit" or not _pr().visible_trees("fruit").is_empty())


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
	if t in ["combat", "adventure", "fruit"]:
		var vis := _pr().visible_trees(t)
		var keep := str(_trees.get(t, ""))
		tree = which if which != "" else (keep if keep in vis else (str(vis[0]) if not vis.is_empty() else ""))
		_trees[t] = tree
		_pick_root()
	elif t == "loadout":
		sel = "bar:0"


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
		var h := _hit_at((event as InputEventMouseMotion).position)
		hover = ("n:" + h.get_slice(":", 1)) if h.begins_with("v:") else h
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		accept_event()
		if mb.button_index == MOUSE_BUTTON_LEFT:
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
			elif id.begins_with("w:"):
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
	for d in [["ui_left", Vector2.LEFT], ["ui_right", Vector2.RIGHT], ["ui_up", Vector2.UP], ["ui_down", Vector2.DOWN]]:
		if event.is_action_pressed(d[0], true) and not (event is InputEventKey and (event as InputEventKey).keycode in [KEY_A, KEY_D, KEY_W, KEY_S]):
			_nav(d[1])
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
	elif k == KEY_TAB and tab == "combat":
		chart = not chart
		if chart:
			sel = "w:" + tree
		else:
			_pick_root()
		menu._play("select")
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
		match str(n["kind"]):
			"step":
				if p.buy_step(nid):
					menu._play("coin")
					_say("%s %d/%d" % [n["name"], p.steps_of(nid), int(n["max_steps"])])
				else:
					_deny(p.step_why(nid))
			"variant", "talent":
				_act_split(nid, (maxi(p.version_of(nid), 0) + (1 if p.version_of(nid) >= 0 else 0)) % n["versions"].size())
			_:
				if str(n["skill"]) != "" and p.knows(str(n["skill"])):
					_say("1-5 or R puts it on the bar")
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
		_deny("Change talents at the ship's bunk")
	else:
		_deny("Switch versions at the ship's bunk")


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
	UIStyle.draw_board(self, bottom, size.x, _hints())
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
			return [["Q/E", "TAB"], ["A/D", "WEAPON"], ["ARROWS", "INSPECT"], ["ENTER", "BUY A STEP"], ["TAB", "CHART"], ["K", "CLOSE"]]
		"adventure":
			return [["Q/E", "TAB"], ["W/S", "TREE"], ["ARROWS", "INSPECT"], ["ENTER", "BUY A STEP"], ["K", "CLOSE"]]
		"captain":
			return [["Q/E", "TAB"], ["ARROWS", "INSPECT"], ["ENTER", "PICK A TALENT"], ["K", "CLOSE"]]
		"loadout":
			return [["Q/E", "TAB"], ["ENTER", "PUT ON BAR"], ["1-5/R", "SLOT"], ["RMB", "CLEAR"], ["K", "CLOSE"]]
	return [["Q/E", "TAB"], ["ARROWS", "INSPECT"], ["ENTER", "BUY A STEP"], ["K", "CLOSE"]]


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
	var h := body.size.y - (RAIL_H + 4.0 if rail else 0.0)
	var card := Rect2(body.end.x - CARD_W, body.position.y + 2.0, CARD_W, h - 4.0)
	var area := Rect2(body.position, Vector2(body.size.x - CARD_W - 8.0, h))
	if tree == "":
		_out(Vector2(area.position.x, area.get_center().y), "NO TREE HERE YET", UIStyle.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, area.size.x)
	else:
		SkillTreeDraw.draw_tree(self, tree, area, _pr(), _t)
		_draw_card(card)
	if rail:
		_draw_rail(Rect2(0, body.end.y - RAIL_H, size.x, RAIL_H))


func _draw_rail(r: Rect2) -> void:
	draw_rect(r, Color(UIChrome.INK, 0.55))
	draw_style_box(UIStyle.chrome("rope", 0, 0), Rect2(r.position.x, r.position.y - 1.0, r.size.x, 3))
	var vis := _pr().visible_trees("combat")
	var labels: Array = vis.map(func(t): return "%s %d" % [Progression.tree_name(t).to_upper(), _pr().tree_level(t)])
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


## The open tree's parchment card: its name and level, points, the inspected node, what comes next.
func _draw_card(card: Rect2) -> void:
	var p := _pr()
	var td := SkillTrees.tree_def(tree)
	var col: Color = td["color"]
	draw_style_box(UIStyle.parchment(), card)
	var x := card.position.x + 10.0
	var w := card.size.x - 20.0
	var y := card.position.y + 14.0
	var limit := card.end.y - 12.0
	var ib := Rect2(x, y, 26, 26)
	draw_rect(ib.grow(1.0), UIStyle.BORDER_DIM)
	draw_rect(ib, UIStyle.INK)
	var ic := SkillTreeDraw.tree_icon(tree)
	if ic:
		draw_texture_rect(ic, Rect2(ib.position + Vector2(1, 1), Vector2(24, 24)), false)
	else:
		draw_string(SILK, Vector2(ib.position.x, ib.position.y + 17.0), SkillTreeDraw.glyph(str(td["name"])), HORIZONTAL_ALIGNMENT_CENTER, 26, 8, col)
	UIStyle.draw_title(self, Vector2(x + 31.0, y + 12.0), str(td["name"]), 18, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	var word := "MASTERY" if td["section"] == "combat" else "LEVEL"
	UIStyle.draw_ribbon(self, Vector2(x + 29.0, y + 15.0), "%s %d OF %d" % [word, p.tree_level(tree), int(td["max_level"])])
	y += 32.0
	_bar(Rect2(x, y, w, 3), _frac(tree), UIStyle.TEAL)
	y += 8.0
	if SkillTrees.converted(tree):
		var pts := p.points_free(tree)
		var chip := "%d POINT%s" % [pts, "" if pts == 1 else "S"]
		var cw := SILK.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8.0
		draw_rect(Rect2(x, y, cw, 11), UIStyle.CORAL if pts > 0 else Color("d9cdb0"))
		draw_string(SILK, Vector2(x + 4.0, y + 9.0), chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.INK if pts > 0 else UIStyle.PARCH_DIM)
		draw_string(SILK, Vector2(x + cw + 5.0, y + 9.0), "ONE A LEVEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.PARCH_DIM)
		y += 14.0
	UIStyle.draw_rule(self, Rect2(x, y, w, 7))
	y += 18.0
	var ins := inspected()
	if ins.begins_with("n:") and SkillTrees.node_def(ins.substr(2)).get("tree", "") == tree:
		y = _node_info(ins.substr(2), x, y, w, limit - 40.0, col)
		y += 2.0
		if y < limit - 40.0:
			UIStyle.draw_rule(self, Rect2(x, y, w, 7))
			y += 11.0
	if td["section"] == "adventure" and y < limit - 34.0:
		UIStyle.draw_ribbon(self, Vector2(x - 2.0, y), "How it grows")
		y = _para(Vector2(x, y + 24.0), str(GROWS.get(tree, "")), w, UIStyle.PARCH_INK, limit) + 2.0
	if y < limit - 30.0:
		var next := SkillTrees.nodes_of(tree).filter(func(k):
			var n := SkillTrees.node_def(k)
			return n["kind"] not in ["step", "version"] and not p.owns_node(k))
		next.sort_custom(func(a, b): return int(SkillTrees.node_def(a)["level"]) < int(SkillTrees.node_def(b)["level"]))
		if not next.is_empty():
			UIStyle.draw_ribbon(self, Vector2(x - 2.0, y), "Coming next")
			y += 24.0
			for k in next.slice(0, 3):
				if y > limit:
					break
				var n := SkillTrees.node_def(k)
				draw_string(SILK, Vector2(x, y), "LV %d" % int(n["level"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.PARCH_DIM)
				draw_string(_font, Vector2(x + 30.0, y + 1.0), str(n["name"]), HORIZONTAL_ALIGNMENT_LEFT, w - 30.0, 12, UIStyle.PARCH_INK)
				y += 12.0


## The inspected node on parchment: name, kind and level, what it does, what Enter does. Returns the y under it.
func _node_info(nid: String, x: float, y: float, w: float, limit: float, col: Color) -> float:
	var p := _pr()
	var n := SkillTrees.node_def(nid)
	var kind := str(n["kind"])
	draw_string(_font, Vector2(x, y), str(n["name"]), HORIZONTAL_ALIGNMENT_LEFT, w, 12, UIStyle.PARCH_INK)
	y += 10.0
	var tag := str(SkillTreeDraw.KIND_NAME.get(kind, kind)).to_upper()
	if kind != "step" and kind != "root":
		tag += " · LV %d" % int(n["level"])
	draw_string(SILK, Vector2(x, y), tag, HORIZONTAL_ALIGNMENT_LEFT, w, 8, SkillTreeDraw.kind_color(kind, col).darkened(0.5))
	y += 13.0
	var desc := str(n["desc"])
	if kind == "variant" or kind == "talent":
		var vi := maxi(p.version_of(nid), 0)
		desc = "%s: %s" % [n["versions"][vi]["name"], n["versions"][vi]["desc"]]
	y = _para(Vector2(x, y), desc, w, UIStyle.PARCH_INK, limit)
	var status := ""
	var good := false
	match kind:
		"step":
			var why := p.step_why(nid)
			status = "%d/%d  ·  %s" % [p.steps_of(nid), int(n["max_steps"]), "ENTER: BUY A STEP" if why == "" else why.to_upper()]
			good = why == ""
		"variant", "talent":
			if int(n["level"]) > p.tree_level(str(n["tree"])):
				status = "COMES AT LV %d" % int(n["level"])
			else:
				status = "BOTH YOURS. SWITCH AT THE BUNK" if kind == "variant" else ("PICK ONE: ENTER" if p.version_of(nid) < 0 else "CHANGE AT THE BUNK")
				good = p.can_respec() or (kind == "talent" and p.version_of(nid) < 0)
		_:
			if p.owns_node(nid):
				status = "YOURS" + ("  ·  1-5/R: ON THE BAR" if str(n["skill"]) != "" else "")
				good = true
			else:
				status = "COMES AT %s %d" % ["MASTERY" if SkillTrees.section_of(str(n["tree"])) == "combat" else "LV", int(n["level"])]
	for l in _wrap(status, w, SILK, 8):
		draw_string(SILK, Vector2(x, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("2f7a3a") if good else UIStyle.CORAL.darkened(0.35))
		y += 9.0
	return y


# --------------------------------------------------------------------------
# Combat: the chart of every weapon
# --------------------------------------------------------------------------
func _draw_chart(body: Rect2) -> void:
	var p := _pr()
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
		var lx := lp.x + (16.0 if side == 0 else (-6.0 if side > 0 else -94.0))
		var al := HORIZONTAL_ALIGNMENT_LEFT if side >= 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var los := _loadouts_of(t).map(func(n): return "LOADOUT %d" % (n + 1))
		if t == hand:
			los.append("IN HAND")
		_out(Vector2(lx, lp.y - 6.0), Progression.tree_name(t).to_upper(), col, al, 100.0)
		_out(Vector2(lx, lp.y + 3.0), "MASTERY %d / %d" % [p.tree_level(t), SkillTrees.max_level(t)], UIStyle.CREAM, al, 100.0)
		if not los.is_empty():
			_out(Vector2(lx, lp.y + 12.0), " · ".join(los), UIStyle.GILT, al, 100.0)
	draw_circle(c, 28.0, UIChrome.INK)
	draw_circle(c, 27.0, UIStyle.GILT)
	draw_circle(c, 25.0, SkillTreeDraw.ROOT_BG)
	draw_string(SILK, Vector2(c.x - 30.0, c.y - 6.0), "CAPTAIN", HORIZONTAL_ALIGNMENT_CENTER, 60, 8, UIStyle.TEXT_DIM)
	UIStyle.draw_title(self, Vector2(c.x - 30.0, c.y + 10.0), "Lv %d" % p.level, 18, HORIZONTAL_ALIGNMENT_CENTER, 60)
	var sl := Rect2(body.position + Vector2(0, 2), Vector2(150, 72))
	draw_style_box(UIStyle.chrome("slate"), sl)
	UIStyle.draw_ribbon(self, sl.position + Vector2(7, 7), "%d tree%s found" % [vis.size(), "" if vis.size() == 1 else "s"], true)
	_para(sl.position + Vector2(9, 32), "Every weapon you fight with branches from your captain.", sl.size.x - 18.0, UIStyle.TEXT_DIM)
	var key := Rect2(Vector2(body.end.x - 132.0, body.position.y + 2.0), Vector2(132, 66))
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
func _draw_adventure(body: Rect2) -> void:
	var p := _pr()
	var lw := 112.0
	var x := body.position.x
	var y := body.position.y + 4.0
	UIStyle.draw_ribbon(self, Vector2(x, y), "Adventure", true)
	y += 18.0
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
	_para(Vector2(x, maxf(y + 8.0, body.end.y - 26.0)), "Keep trying new things: more trees are out there." if not vis.is_empty()
		else "Swim, sail, cook, fish, sneak, jump and block: a tree shows up once you earn its first level.", lw, Color("7f9894"))
	if tree == "":
		return
	var card := Rect2(body.end.x - CARD_W, body.position.y + 2.0, CARD_W, body.size.y - 4.0)
	var area := Rect2(x + lw + 6.0, body.position.y, card.position.x - x - lw - 12.0, body.size.y)
	SkillTreeDraw.draw_tree(self, tree, area, p, _t)
	_draw_card(card)


# --------------------------------------------------------------------------
# Captain: the level trunk, the legend, Will
# --------------------------------------------------------------------------
func _draw_captain(body: Rect2) -> void:
	var p := _pr()
	var card := Rect2(body.position + Vector2(0, 2), Vector2(CARD_W, body.size.y - 4.0))
	draw_style_box(UIStyle.parchment(), card)
	var x := card.position.x + 10.0
	var w := card.size.x - 20.0
	var y := card.position.y + 22.0
	UIStyle.draw_title(self, Vector2(x, y), "Level %d" % p.level, 18, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	var lw := UIStyle.TITLE_FONT.get_string_size("Level %d" % p.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(SILK, Vector2(x + lw + 5.0, y), "OF %d" % Progression.MAX_LEVEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.PARCH_DIM)
	y += 7.0
	_bar(Rect2(x, y, w, 3), _frac("captain"), UIStyle.BORDER_DIM)
	y += 13.0
	if p.level < Progression.MAX_LEVEL:
		draw_string(SILK, Vector2(x, y), "%d / %d XP TO LV %d" % [p.xp, Progression.xp_to_next(p.level), p.level + 1], HORIZONTAL_ALIGNMENT_LEFT, w, 8, UIStyle.PARCH_DIM)
	y += 6.0
	UIStyle.draw_rule(self, Rect2(x, y, w, 7))
	y += 12.0
	UIStyle.draw_ribbon(self, Vector2(x - 2.0, y), "How it grows")
	y += 25.0
	var legend := [["1", "Every level makes your captain tougher: health, damage, stamina, energy, defense."],
		["2", "Round nodes come by themselves at their level."],
		["3", "Split nodes are talents: pick one of two. Change them at the ship's bunk."],
		["4", "Will is its own path: great foes and trials give it, not levels."]]
	for l in legend:
		draw_string(SILK, Vector2(x, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, WILL.darkened(0.3) if l[0] == "4" else UIStyle.BORDER_DIM)
		y = _para(Vector2(x + 9.0, y), l[1], w - 9.0, UIStyle.PARCH_INK, card.end.y - 14.0) + 3.0
	var rows := SkillTrees.nodes_of("captain").filter(func(k): return SkillTrees.node_def(k)["kind"] in ["auto", "talent"])
	rows.sort_custom(func(a, b): return int(SkillTrees.node_def(a)["level"]) < int(SkillTrees.node_def(b)["level"]))
	var levels: Array = rows.map(func(k): return int(SkillTrees.node_def(k)["level"]))
	if levels.is_empty():
		levels = [5, 10, 15, 20, 25, 30, 35, 40]
	var tx := card.end.x + 58.0
	var top := body.position.y + 18.0
	var bot := body.end.y - 18.0
	var step := (bot - top) / maxf(levels.size() - 1, 1)
	var you := bot + 14.0
	for i in range(levels.size()):
		if int(levels[i]) <= p.level:
			you = bot - i * step - step * 0.5
	you = clampf(you, top - 8.0, bot + 14.0)
	draw_rect(Rect2(tx - 2.0, you, 4, body.end.y - you), UIStyle.GILT)
	draw_rect(Rect2(tx - 3.0, you, 6, body.end.y - you), Color(UIStyle.GILT, 0.25))
	draw_rect(Rect2(tx, top - 10.0, 1, you - top + 10.0), SkillTreeDraw.DIM_LINK)
	draw_circle(Vector2(tx, you), 5.0, UIStyle.GILT)
	draw_circle(Vector2(tx, you), 3.0, UIStyle.CREAM)
	_out(Vector2(tx - 58.0, you + 3.0), "YOU %d" % p.level, UIStyle.GILT, HORIZONTAL_ALIGNMENT_RIGHT, 46.0)
	for i in range(levels.size()):
		var lv := int(levels[i])
		var ry := roundf(bot - i * step)
		var on := lv <= p.level
		_out(Vector2(tx - 62.0, ry + 3.0), "LV %d" % lv, UIStyle.CREAM if on else Color("7f9894"), HORIZONTAL_ALIGNMENT_RIGHT, 34.0)
		draw_rect(Rect2(tx - 24.0, ry, 14, 1), Color(UIStyle.GILT, 0.5) if on else Color(SkillTreeDraw.TAG_OFF, 0.4))
		if i < rows.size():
			_captain_row(rows[i], Vector2(tx, ry), on)
	var wx := maxf(tx + 196.0, body.end.x - 190.0)
	_draw_will(Rect2(wx, body.position.y, body.end.x - wx, body.size.y))


func _captain_row(id: String, c: Vector2, on: bool) -> void:
	var p := _pr()
	var n := SkillTrees.node_def(id)
	var r: Rect2
	var lx := c.x + 34.0
	if n["kind"] == "talent":
		r = SkillTreeDraw.split(self, id, c, UIStyle.GILT, p, on)
		var vs: Array = n["versions"]
		var pick := p.version_of(id) if on else -1
		var room := maxf(size.x - 200.0, c.x + 196.0) - lx - 8.0
		var whole := " or ".join(vs.map(func(v): return str(v["name"])))
		var small := _font.get_string_size(whole, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > room
		var ax := lx
		for i in range(vs.size()):
			if i > 0:
				draw_string(SILK, Vector2(ax, c.y - 1.0), "OR", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("7f9894"))
				ax += 16.0
			var nm := str(vs[i]["name"])
			var col := UIStyle.CREAM if i == pick else SkillTreeDraw.TEXT_OFF
			if small:
				nm = nm.to_upper()
				draw_string(SILK, Vector2(ax, c.y - 1.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
				ax += SILK.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 5.0
			else:
				draw_string(_font, Vector2(ax, c.y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
				ax += _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 5.0
		var tag := ("TALENT · PICKED %s" % str(vs[pick]["name"]).to_upper()) if pick >= 0 else ("TALENT AT LV %d · PICK ONE" % int(n["level"]))
		draw_string(SILK, Vector2(lx, c.y + 9.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.GILT if on else Color("7f9894"))
	else:
		r = SkillTreeDraw._big(self, n, c, UIStyle.GILT, on)
		draw_string(_font, Vector2(lx, c.y), str(n["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.CREAM if on else SkillTreeDraw.TEXT_OFF)
		draw_string(SILK, Vector2(lx, c.y + 9.0), ("GOT IT" if on else "COMES AT LV %d" % int(n["level"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.GILT if on else Color("7f9894"))
	hit(r.grow(2.0), "n:" + id)
	if inspected() == "n:" + id:
		draw_rect(r.grow(3.0), Color(UIStyle.CREAM, 0.6 + 0.4 * sin(_t * 5.0)), false, 1.0)


## Will: its own path of milestones beside the trunk (bosses and trials).
func _draw_will(r: Rect2) -> void:
	if r.size.x < 90.0:
		return
	var p := _pr()
	_out(r.position + Vector2(0, 8), "WILL", WILL)
	draw_string(_font, r.position + Vector2(30, 9), "bosses and trials", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.TEXT_DIM)
	var ids := SkillTrees.nodes().keys().filter(func(k): return SkillTrees.node_def(k)["kind"] == "will")
	if ids.is_empty():
		_para(r.position + Vector2(0, 26), "Beat a great foe to awaken it.", r.size.x, Color("7f9894"))
		return
	var step := minf(50.0, (r.size.y - 30.0) / ids.size())
	for i in range(ids.size()):
		var id: String = ids[ids.size() - 1 - i]
		var n := SkillTrees.node_def(id)
		var got := p.has_will(id) or p.owns_node(id)
		var c := Vector2(r.position.x + 13.0, roundf(r.position.y + 34.0 + i * step))
		var nr := SkillTreeDraw._big(self, n, c, WILL, got)
		hit(nr.grow(2.0), "n:" + id)
		draw_string(_font, Vector2(c.x + 20.0, c.y - 2.0), str(n["name"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 34.0, 12, UIStyle.CREAM if got else SkillTreeDraw.TEXT_OFF)
		var desc := str(n["desc"])
		var how := desc.get_slice(". ", 0)
		draw_string(SILK, Vector2(c.x + 20.0, c.y + 8.0), how.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 34.0, 8, WILL)
		var l: Array = _wrap(desc.substr(how.length() + 2), r.size.x - 34.0, SILK, 8)
		for j in range(mini(l.size(), int(step / 9.0) - 2)):
			draw_string(SILK, Vector2(c.x + 20.0, c.y + 17.0 + j * 9.0), l[j], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.TEXT_DIM)
		if inspected() == "n:" + id:
			draw_rect(nr.grow(3.0), Color(UIStyle.CREAM, 0.6 + 0.4 * sin(_t * 5.0)), false, 1.0)


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
		var nm := "Locked" if locked else (item.display_name if item else ("Fists" if not lo.is_empty() else "Empty"))
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
		var t := _skill_tree(sk)
		if not groups.has(t):
			groups[t] = []
		groups[t].append(sk)
	for id in lib["passives"]:
		var t := str(_node_any(id).get("tree", "base"))
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


func _group_rank(t: String) -> int:
	var los := _loadouts_of(t)
	if not los.is_empty():
		return los[0]
	if t in ["base", "captain", "will"]:
		return 10
	if t == "fruit" or SkillTrees.section_of(t) == "fruit":
		return 11
	return 20
