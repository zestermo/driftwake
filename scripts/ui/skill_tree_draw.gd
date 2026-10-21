class_name SkillTreeDraw
extends RefCounted
## Draws the skills menu's node trees (docs/media/progression_mock): a tree grows up from its root in three
## branches, big nodes on the branches (the game's 24 px skill icons in the technique and ultimate squares), small
## stat steps off them with x/5 counters, a variant as one split node with its active half lit. Lit links and
## nodes in the tree's colour, the rest slate-dim. Every node registers a hit ("n:<id>") on the screen it draws on.

const NODE_BG := Color("0c2427")
const ROOT_BG := Color("143f46")
const DIM_FILL := Color("16343a")
const DIM_RIM := Color("3c5c5f")
const DIM_LINK := Color("2f4c52")
const TEXT_OFF := Color("93a8a3")
const TAG_OFF := Color("5e7470")
const PASSIVE := Color("ffb39e")
const ELEM := Color("f0b0d0")
const SILK := preload("res://assets/fonts/Silkscreen-Regular.woff2")
## Node sizes on the canvas (the mock's at half: the menus' canvas is 640x360).
const SIZE := {"root": 30, "ult": 30, "tech": 28, "move": 16, "mech": 16, "passive": 14, "elem": 15, "step": 11, "auto": 26, "will": 26}
const KIND_NAME := {"root": "Root", "move": "Move", "tech": "Technique", "mech": "Mechanic", "passive": "Passive", "elem": "Element",
	"ult": "Ultimate", "step": "Stat step", "variant": "Variant", "auto": "Comes by itself", "talent": "Talent", "will": "Will", "version": "Version"}
## A tree's item for its icon (weapons, fruits).
const TREE_ITEM := {"sword": "cutlass", "katana": "katana", "axe": "boarding_axe", "dagger": "dagger", "dual": "cutlass",
	"dual_dagger": "dagger", "polearm": "spear", "hammer": "warhammer", "dual_axe": "tomahawk", "corsair": "cutlass", "pistol": "pistol", "ember": "ember_fruit", "wolf": "wolf_fruit", "vine": "vine_fruit"}


static func tree_icon(tree: String) -> Texture2D:
	return ItemDB.get_item(TREE_ITEM[tree]).icon if TREE_ITEM.has(tree) else null


static func kind_color(kind: String, col: Color) -> Color:
	return {"move": col, "tech": UIStyle.GILT, "mech": UIStyle.CREAM, "passive": PASSIVE, "elem": ELEM, "ult": UIStyle.GILT,
		"root": UIStyle.GILT, "variant": col, "step": col, "auto": UIStyle.GILT, "talent": UIStyle.GILT, "will": Color("c9a8ff")}.get(kind, col)


## Two letters for a node with no icon ("Through the Guard" -> "TG").
static func glyph(name_: String) -> String:
	var words := Array(name_.replace("'", "").split(" ", false)).filter(func(w): return w.length() > 2 or w == w.to_upper())
	if words.size() >= 2:
		return (str(words[0])[0] + str(words[-1])[0]).to_upper()
	return name_.substr(0, 2).to_upper()


## The tree's nodes (versions aside) at screen positions inside `area`: [{id: Vector2}, zoom].
static func layout(tree: String, area: Rect2) -> Array:
	var ids := SkillTrees.nodes_of(tree).filter(func(k): return SkillTrees.node_def(k)["kind"] != "version")
	if ids.is_empty():
		return [{}, 1.0]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k in ids:
		var p: Vector2 = SkillTrees.node_def(k)["pos"]
		lo = lo.min(p)
		hi = hi.max(p)
	var span := (hi - lo).max(Vector2(200, 200))
	var z := minf((area.size.x - 76.0) / span.x, (area.size.y - 64.0) / span.y)
	var mid := (lo + hi) * 0.5
	var c := area.get_center() + Vector2(0, 6)
	var at := {}
	for k in ids:
		at[k] = (c + (SkillTrees.node_def(k)["pos"] - mid) * z).round()
	return [at, z]


## Draw `tree` into `area` on screen `s` (a SkillMapScreen: hit(), inspected()). `pr` is the captain's Progression.
static func draw_tree(s: SkillMapScreen, tree: String, area: Rect2, pr: Progression, t: float) -> void:
	var td := SkillTrees.tree_def(tree)
	var col: Color = td["color"]
	var lay := layout(tree, area)
	var at: Dictionary = lay[0]
	if at.is_empty():
		_uncharted(s, tree, area, pr, col)
		return
	for k in at.keys():
		var n := SkillTrees.node_def(k)
		for l in n["links"]:
			if at.has(l):
				_link(s, at[l], at[k], col, pr.owns_node(k), n["kind"] == "step")
	var taken: Array = at.keys().map(func(k): return node_rect(k, at[k]).grow(1.0))
	for b in range(td["branches"].size()):
		var bigs: Array = td["branches"][b]["nodes"].filter(func(k): return SkillTrees.node_def(k)["kind"] != "step")
		if bigs.is_empty():
			continue
		var top: Vector2 = at[bigs[-1]]
		var got := bigs.filter(func(k): return pr.owns_node(k)).size()
		var name_s := str(td["branches"][b]["name"]).to_upper()
		var sub := "%d OF %d" % [got, bigs.size()]
		var tw := maxf(SILK.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, SILK.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
		var nr := node_rect(bigs[-1], top)
		var tr := Rect2(top.x - 22.0 - tw, top.y - 32.0, tw, 17)
		if b == 1:
			tr = Rect2(roundf(top.x - tw * 0.5), nr.position.y - 21.0, tw, 17)
		elif b == 2:
			tr = Rect2(top.x + 8.0, top.y - 32.0, tw, 17)
		var al: HorizontalAlignment = [HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_LEFT][mini(b, 2)]
		_outlined(s, tr.position + Vector2(0, 8), name_s, col.lightened(0.25), al, tw)
		_outlined(s, tr.position + Vector2(0, 17), sub, UIStyle.TEXT_DIM, al, tw)
		taken.append(tr)
	var labels := place_labels(at, area, taken)
	for k in at.keys():
		draw_node(s, k, at[k], col, pr, t)
		var nm := str(SkillTrees.node_def(k)["name"])
		var lit: bool = pr.owns_node(k) or s.inspected() == "n:" + k
		if labels.has(k):
			var lr: Rect2 = labels[k]
			_outlined(s, lr.position + Vector2(0, 8), nm, UIStyle.CREAM if lit else TEXT_OFF)
		elif s.inspected() == "n:" + k:
			_outlined(s, Vector2(at[k].x - 50.0, at[k].y + 25.0), nm, UIStyle.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 100.0)


## The space a node takes (a step's counter included).
static func node_rect(id: String, c: Vector2) -> Rect2:
	var n := SkillTrees.node_def(id)
	match str(n["kind"]):
		"step":
			return Rect2(c - Vector2(12, 6), Vector2(24, 22))
		"variant", "talent":
			var icons: bool = n["versions"].any(func(v): return str(v["skill"]) != "")
			var w: float = (26.0 if icons else 17.0) * n["versions"].size()
			var h := 26.0 if icons else 16.0
			return Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h)).grow(2.0)
	var sz := float(SIZE.get(str(n["kind"]), 16))
	return Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz))


## A name for every big node where it fits best: under it, else right, left or above, clear of the other nodes and
## names (bottom of the tree first); then each step's name where there's room. Returns {id: the name's rect}.
static func place_labels(at: Dictionary, area: Rect2, taken: Array) -> Dictionary:
	var out := {}
	var segs: Array = []
	for k in at.keys():
		for l in SkillTrees.node_def(k)["links"]:
			if at.has(l):
				segs.append([at[k], at[l]])
	var order := at.keys().filter(func(k): return SkillTrees.node_def(k)["kind"] != "step")
	order.sort_custom(func(a, b): return at[a].y > at[b].y)
	for k in order:
		var tw := SILK.get_string_size(str(SkillTrees.node_def(k)["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var r := node_rect(k, at[k])
		var c: Vector2 = at[k]
		var xs := [roundf(c.x - tw * 0.5), roundf(c.x + 10.0 - tw), roundf(c.x - 10.0)]
		var cands: Array = xs.map(func(x): return Rect2(x, r.end.y + 2.0, tw, 9))
		cands.append(Rect2(r.end.x + 4.0, c.y - 4.0, tw, 9))
		cands.append(Rect2(r.position.x - 4.0 - tw, c.y - 4.0, tw, 9))
		cands.append_array(xs.map(func(x): return Rect2(x, r.position.y - 11.0, tw, 9)))
		var free := cands.filter(func(cand): return area.encloses(cand) and not taken.any(func(o): return (o as Rect2).intersects(cand)))
		var clear := free.filter(func(cand): return not segs.any(func(sg): return _seg_hits(sg[0], sg[1], cand)))
		var pick: Rect2 = clear[0] if not clear.is_empty() else (free[0] if not free.is_empty() else cands[0])
		taken.append(pick)
		out[k] = pick
	# then the steps' names under their counters (or over their circles), only where there's room
	var steps := at.keys().filter(func(k): return SkillTrees.node_def(k)["kind"] == "step")
	steps.sort_custom(func(a, b): return at[a].y > at[b].y)
	for k in steps:
		var tw := SILK.get_string_size(str(SkillTrees.node_def(k)["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var c: Vector2 = at[k]
		for cand in [Rect2(roundf(c.x - tw * 0.5), c.y + 17.0, tw, 9), Rect2(roundf(c.x - tw * 0.5), c.y - 17.0, tw, 9)]:
			if area.encloses(cand) and not taken.any(func(o): return (o as Rect2).intersects(cand)):
				taken.append(cand)
				out[k] = cand
				break
	return out


static func _seg_hits(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var p := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in range(4):
		if Geometry2D.segment_intersects_segment(a, b, p[i], p[(i + 1) % 4]) != null:
			return true
	return false


## A tree whose paths aren't drawn yet: its root and a note.
static func _uncharted(s: SkillMapScreen, tree: String, area: Rect2, pr: Progression, col: Color) -> void:
	var c := (area.get_center() + Vector2(0, area.size.y * 0.25)).round()
	var r := Rect2(c - Vector2(15, 15), Vector2(30, 30))
	s.draw_circle(c, 16.0, UIChrome.INK)
	s.draw_circle(c, 15.0, UIStyle.GILT)
	s.draw_circle(c, 13.0, ROOT_BG)
	var ic := tree_icon(tree)
	if ic:
		s.draw_texture_rect(ic, Rect2(c - Vector2(12, 12), Vector2(24, 24)), false)
	else:
		s.draw_string(SILK, Vector2(c.x - 15.0, c.y + 3.0), glyph(Progression.tree_name(tree)), HORIZONTAL_ALIGNMENT_CENTER, 30.0, 8, col)
	s.hit(r, "root:" + tree)
	_outlined(s, Vector2(area.position.x, c.y - 40.0), "THIS TREE'S PATHS ARE STILL BEING CHARTED", UIStyle.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, area.size.x)
	_outlined(s, Vector2(area.position.x, c.y - 30.0), "%s %d  -  YOUR PROGRESS IS KEPT" % [Progression.tree_name(tree).to_upper(), pr.tree_level(tree)], col, HORIZONTAL_ALIGNMENT_CENTER, area.size.x)


static func _link(s: Control, a: Vector2, b: Vector2, col: Color, on: bool, thin: bool) -> void:
	if thin:
		s.draw_line(a, b, col if on else DIM_LINK, 1.0)
	elif on:
		s.draw_line(a, b, Color(col, 0.28), 4.0)
		s.draw_line(a, b, col, 2.0)
	else:
		s.draw_line(a, b, DIM_LINK, 1.0)


static func _outlined(s: Control, p: Vector2, text: String, col: Color, al := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	s.draw_string_outline(SILK, p, text, al, w, 8, 2, UIStyle.OUTLINE)
	s.draw_string(SILK, p, text, al, w, 8, col)


## One node centred on `c`; registers its hit (its name is placed by draw_tree; a step shows its name when inspected).
static func draw_node(s: SkillMapScreen, id: String, c: Vector2, col: Color, pr: Progression, t: float) -> void:
	var n := SkillTrees.node_def(id)
	var kind := str(n["kind"])
	var on := pr.owns_node(id)
	var r: Rect2
	if kind == "step":
		r = _step(s, id, n, c, col, pr)
	elif kind in ["variant", "talent"]:
		r = split(s, id, c, col, pr, int(n["level"]) <= pr.tree_level(str(n["tree"])))
	else:
		r = _big(s, n, c, col, on)
	s.hit(r.grow(2.0), "n:" + id)
	if s.inspected() == "n:" + id:
		var pulse := 0.6 + 0.4 * sin(t * 5.0)
		s.draw_rect(r.grow(3.0), Color(UIStyle.CREAM, pulse), false, 1.0)


## A big node: the root, a move, technique, mechanic, passive, element or ultimate.
static func _big(s: Control, n: Dictionary, c: Vector2, col: Color, on: bool) -> Rect2:
	var kind := str(n["kind"])
	var sz := float(SIZE.get(kind, 16))
	var h := sz * 0.5
	var r := Rect2(c - Vector2(h, h), Vector2(sz, sz))
	var rim := col if on else DIM_RIM
	var ic: Texture2D = Skills.icon(str(n["skill"])) if str(n["skill"]) != "" else null
	if kind == "root":
		ic = tree_icon(str(n["tree"]))
	if on and kind in ["move", "mech", "elem", "root"]:
		s.draw_circle(c, h + 3.0, Color(col, 0.18))
	elif on:
		s.draw_rect(r.grow(2.0), Color(col, 0.2))
	match kind:
		"root":
			s.draw_circle(c, h + 1.0, UIChrome.INK)
			s.draw_circle(c, h, UIStyle.GILT)
			s.draw_circle(c, h - 2.0, ROOT_BG)
		"tech", "ult", "auto", "will":
			s.draw_rect(r.grow(1.0), UIChrome.INK)
			s.draw_rect(r, rim if kind != "ult" or not on else UIStyle.GILT)
			s.draw_rect(r.grow(-2.0), NODE_BG)
			if kind == "ult":
				s.draw_rect(r.grow(-3.0), rim if not on else UIStyle.GILT)
				s.draw_rect(r.grow(-4.0), NODE_BG)
		"passive":
			var d := PackedVector2Array([c + Vector2(0, -h - 1), c + Vector2(h + 1, 0), c + Vector2(0, h + 1), c + Vector2(-h - 1, 0)])
			s.draw_colored_polygon(d, UIChrome.INK)
			var d2 := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)])
			s.draw_colored_polygon(d2, UIStyle.CREAM if on else rim)
			var d3 := PackedVector2Array([c + Vector2(0, -h + 2), c + Vector2(h - 2, 0), c + Vector2(0, h - 2), c + Vector2(-h + 2, 0)])
			s.draw_colored_polygon(d3, PASSIVE if on else DIM_FILL)
		"mech":
			s.draw_circle(c, h + 1.0, UIChrome.INK)
			s.draw_circle(c, h, rim)
			s.draw_circle(c, h - 1.0, NODE_BG)
			s.draw_circle(c, h - 2.5, rim)
			s.draw_circle(c, h - 3.5, NODE_BG)
		_:
			var fill: Color = (ELEM if kind == "elem" else col) if on else DIM_FILL
			s.draw_circle(c, h + 1.0, UIChrome.INK)
			s.draw_circle(c, h, UIStyle.CREAM if on else rim)
			s.draw_circle(c, h - 1.5, fill)
	if ic and sz >= 26.0:
		s.draw_texture_rect(ic, Rect2(c - Vector2(12, 12), Vector2(24, 24)), false, Color.WHITE if on else Color(0.55, 0.6, 0.62, 0.45))
	elif sz >= 26.0:
		s.draw_string(SILK, Vector2(c.x - h, c.y + 3.0), glyph(str(n["name"])), HORIZONTAL_ALIGNMENT_CENTER, sz, 8, col if on else TAG_OFF)
	if not on and kind not in ["root", "will"]:
		var lv := str(int(n["level"]))
		if ic and sz >= 26.0:
			_outlined(s, Vector2(r.end.x - 1.0 - SILK.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, r.end.y - 1.0), lv, UIStyle.TEXT_DIM)
		elif sz >= 14.0:
			s.draw_string(SILK, Vector2(c.x - 10.0, c.y + 3.0), lv, HORIZONTAL_ALIGNMENT_CENTER, 20.0, 8, TAG_OFF)
	return r


## A stat step: a small round node, its x/5 counter under it.
static func _step(s: Control, id: String, n: Dictionary, c: Vector2, col: Color, pr: Progression) -> Rect2:
	var have := pr.steps_of(id)
	var most := int(n["max_steps"])
	var full := have >= most
	var some := have > 0
	if some:
		s.draw_circle(c, 7.5, Color(col, 0.22))
	s.draw_circle(c, 6.0, UIChrome.INK)
	s.draw_circle(c, 5.0, UIStyle.CREAM if full else (col if some else DIM_RIM))
	s.draw_circle(c, 3.5, col if some else DIM_FILL)
	var chip := "%d/%d" % [have, most]
	var cw := SILK.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 4.0
	var cr := Rect2(roundf(c.x - cw * 0.5), c.y + 7.0, cw, 9.0)
	s.draw_rect(cr, UIStyle.GILT if full else (UIStyle.TEAL if some else DIM_FILL))
	s.draw_string(SILK, cr.position + Vector2(2, 8), chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.INK if full else (UIStyle.CREAM if some else TEXT_OFF))
	if not full and pr.step_why(id) == "":
		s.draw_circle(c + Vector2(5, -5), 1.5, UIStyle.CORAL)
	return Rect2(c - Vector2(6, 6), Vector2(12, 12))


## A variant or talent: one node split in two, the active half lit (`reached`: its level is reached).
## Each half registers "v:<id>:<i>" for the mouse.
static func split(s: SkillMapScreen, id: String, c: Vector2, col: Color, pr: Progression, reached: bool) -> Rect2:
	var n := SkillTrees.node_def(id)
	var vs: Array = n["versions"]
	var icons := vs.any(func(v): return str(v["skill"]) != "")
	var hw := 26.0 if icons else 17.0
	var hh := 26.0 if icons else 16.0
	var w := hw * vs.size()
	var r := Rect2((c - Vector2(w, hh) * 0.5).round(), Vector2(w, hh))
	var pick := pr.version_of(id) if reached else -1
	var rim := col if reached else DIM_RIM
	if reached:
		s.draw_rect(r.grow(3.0), Color(col, 0.2))
	s.draw_rect(r.grow(2.0), UIChrome.INK)
	s.draw_rect(r.grow(1.0), rim)
	for i in range(vs.size()):
		var v: Dictionary = vs[i]
		var hr := Rect2(r.position + Vector2(hw * i, 0), Vector2(hw, hh))
		var owned := int(v["level"]) <= pr.tree_level(str(n["tree"]))
		var lit := i == pick
		s.draw_rect(hr, (UIStyle.TEAL if icons else col) if lit else (ROOT_BG if owned else NODE_BG))
		if i > 0:
			s.draw_rect(Rect2(hr.position.x, hr.position.y, 1, hh), rim)
		var sk := str(v["skill"])
		if sk != "":
			s.draw_texture_rect(Skills.icon(sk), Rect2(hr.get_center() - Vector2(12, 12), Vector2(24, 24)), false,
				Color.WHITE if lit else (Color(1, 1, 1, 0.55) if owned else Color(0.55, 0.6, 0.62, 0.3)))
		else:
			s.draw_string(SILK, Vector2(hr.position.x, hr.position.y + hh * 0.5 + 3.0), glyph(str(v["name"])), HORIZONTAL_ALIGNMENT_CENTER, hw, 8,
				UIStyle.INK if lit else (UIStyle.TEXT_DIM if owned else TAG_OFF))
		s.hit(hr, "v:%s:%d" % [id, i], false)
	return r
