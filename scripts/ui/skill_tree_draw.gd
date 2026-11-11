class_name SkillTreeDraw
extends RefCounted
## Draws the skills menu's trees (1.30, docs/v1_30_previews.md section 5, the approved SkillMap mock): every tree one
## branching map from its root (SkillTrees' map layout), drawn into the screen's map panel at its zoom and pan, clipped
## to it. Abilities (moves you press) are round, gold-rimmed, with their icon; passives (always on) diamonds, blue-rimmed;
## stat steps a row of small square pips labelled with the stat; a bridge's links dashed coral. Yours: filled and lit;
## buyable now: a pulsing glow; past your level: dashed and dim with the level it opens at. Every node registers a hit
## ("n:<id>", a variant's halves "v:<id>:<i>") on the screen.

const NODE_BG := Color("0c2427")
const ROOT_BG := Color("143f46")
const MAP_BG := Color("143f46")
const DIM_FILL := Color("1d5e66")
const OWN_FILL := Color("2a6f78")
const DIM_RIM := Color("3c5c5f")
const DIM_LINK := Color("2f4c52")
const LINK_OFF := Color("6f8a86")
const TEXT_OFF := Color("93a8a3")
const TAG_OFF := Color("5e7470")
const PASSIVE := Color("65c9c0")
const STAT_ON := Color("9be08a")
const BRIDGE := Color("f17c62")
const ELEM := Color("f0b0d0")
const SILK := preload("res://assets/fonts/Silkscreen-Regular.woff2")
## Sizes at zoom 1 (the menus' 800x450 canvas): an ability's radius (an ultimate's, the root's), a passive's half
## diagonal, a stat pip's side.
const ABILITY_R := 12.0
const ULT_R := 15.0
const ROOT_R := 16.0
const PASSIVE_R := 10.0
const PIP := 7.0
## Names show from this zoom (and always on the picked node).
const NAMES_FROM := 0.8
const KIND_NAME := {"root": "Root", "move": "Move", "tech": "Technique", "mech": "Mechanic", "passive": "Passive", "elem": "Element",
	"ult": "Ultimate", "step": "Stat step", "variant": "Variant", "auto": "Comes by itself", "talent": "Talent", "will": "Will", "version": "Version"}
## What each shape is called on the card.
const SHAPE_NAME := {"ability": "Ability", "passive": "Passive", "stat": "Stat", "root": "Root"}
## A tree's item for its icon (weapons, fruits).
const TREE_ITEM := {"sword": "cutlass", "katana": "katana", "axe": "boarding_axe", "dagger": "dagger", "dual": "cutlass",
	"dual_dagger": "dagger", "polearm": "spear", "hammer": "warhammer", "dual_axe": "tomahawk", "greatsword": "greatsword", "rapier": "rapier", "staff": "staff", "sickle": "chain_sickle", "corsair": "cutlass", "pistol": "pistol", "long_gun": "musket", "cannon": "hand_cannon", "slingshot": "slingshot", "ember": "ember_fruit", "wolf": "wolf_fruit", "vine": "vine_fruit"}


static func tree_icon(tree: String) -> Texture2D:
	return ItemDB.get_item(TREE_ITEM[tree]).icon if TREE_ITEM.has(tree) else null


static func kind_color(kind: String, col: Color) -> Color:
	return {"move": col, "tech": UIStyle.GILT, "mech": UIStyle.CREAM, "passive": PASSIVE, "elem": ELEM, "ult": UIStyle.GILT,
		"root": UIStyle.GILT, "variant": col, "step": col, "auto": UIStyle.GILT, "talent": UIStyle.GILT, "will": Color("c9a8ff")}.get(kind, col)


## A node's or version's picture: its skill's icon, or its own "icon" (the Adventure moves); "" for none.
static func pic(d: Dictionary) -> String:
	return str(d["skill"]) if str(d["skill"]) != "" else str(d.get("icon", ""))


## Two letters for a node with no icon ("Through the Guard" -> "TG").
static func glyph(name_: String) -> String:
	var words := Array(name_.replace("'", "").split(" ", false)).filter(func(w): return w.length() > 2 or w == w.to_upper())
	if words.size() >= 2:
		return (str(words[0])[0] + str(words[-1])[0]).to_upper()
	return name_.substr(0, 2).to_upper()


## What a node is on the map: "ability" (a move you press: round), "passive" (always on: a diamond), "stat" (+% steps:
## pips) or "root". A node's own "shape" wins; a variant is an ability if a version is a skill or a move.
static func shape_of(id: String) -> String:
	var n := SkillTrees.node_def(id)
	if n.has("shape"):
		return str(n["shape"])
	match str(n["kind"]):
		"root":
			return "root"
		"step":
			return "stat"
		"move", "tech", "ult":
			return "ability"
		"variant", "talent":
			for v in n["versions"]:
				if str(v["skill"]) != "" or (v["effects"] as Dictionary).keys().any(func(e): return str(e).begins_with("mv_") or str(e).begins_with("dodge_")):
					return "ability"
	return "passive"


## The branch a node grows on ("" for the root).
static func branch_name(id: String) -> String:
	var n := SkillTrees.node_def(id)
	var bs: Array = SkillTrees.tree_def(str(n["tree"]))["branches"]
	var b := int(n["branch"])
	return str(bs[b]["name"]) if b >= 0 and b < bs.size() else ""


## Where each of `tree`'s nodes (versions aside) sits on screen: `area`'s centre over map point `pan`, `k` px a unit.
static func layout(tree: String, area: Rect2, k: float, pan: Vector2) -> Dictionary:
	var at := {}
	var c := area.get_center()
	for id in SkillTrees.nodes_of(tree):
		if SkillTrees.node_def(id)["kind"] != "version":
			at[id] = (c + ((SkillTrees.node_def(id)["pos"] as Vector2) - pan) * k).round()
	return at


## The nodes' size at zoom `k` (they grow and shrink less than the map does).
static func size_k(k: float) -> float:
	return clampf(sqrt(k), 0.75, 1.25)


## The space a node takes on screen at size `z` (a stat chain's whole row of pips).
static func node_rect(id: String, c: Vector2, z: float) -> Rect2:
	var n := SkillTrees.node_def(id)
	var r: float
	match shape_of(id):
		"stat":
			var w := int(n["max_steps"]) * (PIP + 2.0) * z
			return Rect2(c - Vector2(w * 0.5, PIP * z * 0.5), Vector2(w, PIP * z))
		"passive":
			r = PASSIVE_R * z
		"root":
			r = ROOT_R * z
		_:
			r = (ULT_R if str(n["kind"]) == "ult" else ABILITY_R) * z
	return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)


## The map's map parents of a node with how they join it: [[parent id, bridge?]].
static func parents(id: String) -> Array:
	var n := SkillTrees.node_def(id)
	var bridge: bool = n.get("bridge", false) or n.has("needs_all")
	var ps: Array = n.get("needs_all", n.get("needs", n["links"]))
	return ps.map(func(p): return [p, bridge])


## The tree into `area` on screen `s` (a SkillMapScreen: hit(), inspected()): its panel, links, nodes and names, the
## branches' names, the zoom buttons. `pr` is the captain's Progression.
## (1.30.2, Zach) The map's sea: deeper towards the bottom, rows of little pixel wave crests (whole pixels, a 2 px step)
## drifting slowly, each row the other way to the one above, swelling up and down a pixel; shifted a quarter of the
## pan so it sits behind the tree. Faint: the tree reads first.
const SEA_ROW := 22.0
const SEA_GAP := 46.0
const SEA_CREST := Color("2a6670")
const SEA_FOAM := Color("4f8f93")
const SEA_DEEP := Color("0b2d33")


static func draw_sea(s: CanvasItem, area: Rect2, t: float, pan_px: Vector2) -> void:
	var bands := 6
	for b in bands:
		var h := area.size.y / bands
		s.draw_rect(Rect2(area.position.x, area.position.y + h * b, area.size.x, ceilf(h)), Color(SEA_DEEP, 0.07 * b))
	var off := -pan_px * 0.25
	var rows := int(area.size.y / SEA_ROW) + 2
	for r in rows:
		var dir := 1.0 if r % 2 == 0 else -1.0
		var y0 := area.position.y + fposmod(off.y + r * SEA_ROW, rows * SEA_ROW) - SEA_ROW * 0.5
		var drift := fposmod(off.x + dir * t * (6.0 + 2.0 * (r % 3)) + r * 17.0, SEA_GAP)
		var n := int(area.size.x / SEA_GAP) + 2
		for i in n:
			var x := floorf(area.position.x + drift + (i - 1) * SEA_GAP)
			var bob := 2.0 if sin(t * 1.6 + i * 1.3 + r * 0.7) > 0.4 else 0.0
			var y := floorf(y0 + bob)
			if x < area.position.x + 2.0 or x + 12.0 > area.end.x - 2.0 or y < area.position.y + 2.0 or y + 4.0 > area.end.y - 2.0:
				continue
			# a crest: a 6 px top with a foamy middle, shoulders dropping either side
			s.draw_rect(Rect2(x + 4.0, y, 4.0, 2.0), Color(SEA_FOAM, 0.35))
			s.draw_rect(Rect2(x + 2.0, y + 2.0, 2.0, 2.0), Color(SEA_CREST, 0.5))
			s.draw_rect(Rect2(x + 8.0, y + 2.0, 2.0, 2.0), Color(SEA_CREST, 0.5))
			s.draw_rect(Rect2(x, y + 4.0, 2.0, 2.0), Color(SEA_CREST, 0.3))
			s.draw_rect(Rect2(x + 10.0, y + 4.0, 2.0, 2.0), Color(SEA_CREST, 0.3))


static func draw_map(s: SkillMapScreen, tree: String, area: Rect2, k: float, pan: Vector2, pr: Progression, t: float) -> void:
	var td := SkillTrees.tree_def(tree)
	var col: Color = td["color"]
	s.draw_rect(area, MAP_BG)
	draw_sea(s, area, t, pan * k)
	s.draw_rect(area, DIM_RIM, false, 2.0)
	var at := layout(tree, area, k, pan)
	var z := size_k(k)
	var inner := area.grow(-2.0)
	for id in at.keys():
		var home := SkillTrees.map_parent(id)
		for pb in parents(id):
			if not at.has(pb[0]):
				continue
			var seg := clip(at[pb[0]], at[id], inner)
			if seg.is_empty():
				continue
			var on: bool = pr.owns_node(id) and pr.owns_node(pb[0])
			# (a bridge, or another way in than the branch the node hangs from: dashed and faint unless it's the
			# picked node's, so the tree's own branches read first)
			var lit: bool = s.inspected() in ["n:" + id, "n:" + str(pb[0])]
			if pb[1] or pb[0] != home:
				var dc := BRIDGE if pb[1] else LINK_OFF
				s.draw_dashed_line(seg[0], seg[1], dc if on or lit else Color(dc, 0.3), 2.0 if lit else 1.0, 5.0)
			elif on:
				s.draw_line(seg[0], seg[1], Color(col, 0.3), 5.0)
				s.draw_line(seg[0], seg[1], col, 3.0)
			else:
				s.draw_line(seg[0], seg[1], LINK_OFF if pr.parent_why(id) == "" else DIM_LINK, 2.0)
			s.links.append([pb[0], id, on])
	# the branches' names past their furthest node, out from the root
	for b in range(td["branches"].size()):
		var ids: Array = (td["branches"][b]["nodes"] as Array).filter(func(i): return at.has(i))
		if ids.is_empty():
			continue
		# (out along the middle of the branch's lane, past its furthest ring)
		var far := 0.0
		var sum := Vector2.ZERO
		for i in ids:
			var p: Vector2 = SkillTrees.node_def(i)["pos"]
			far = maxf(far, p.length())
			sum += p.normalized()
		var dir := sum.normalized()
		var lp := (area.get_center() + (dir * (far + 34.0) - pan) * k).round()
		var nm := str(td["branches"][b]["name"]).to_upper()
		var tw := SILK.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		if inner.grow(-6.0).has_point(lp):
			_outlined(s, lp + Vector2(-tw * 0.5, 3.0), nm, PASSIVE)
	for id in at.keys():
		var c: Vector2 = at[id]
		var r := node_rect(id, c, z)
		if not inner.encloses(r):
			continue
		draw_node(s, id, c, z, col, pr, t)
		var n := SkillTrees.node_def(id)
		var picked: bool = s.inspected() == "n:" + id
		if k < NAMES_FROM and not picked:
			continue
		var nm := str(n["name"])
		if str(n["kind"]) == "step":
			nm += " %d/%d" % [pr.steps_of(id), int(n["max_steps"])]
		# (the level it opens at on a line of its own under the name, so names stay narrow)
		var lv := _locked_at(id, pr)
		var lit: bool = pr.owns_node(id) or picked or pr.buy_why(id) == ""
		var lr := Rect2(c.x - 60.0, r.end.y + 2.0, 120.0, 18.0 if lv > 0 else 9.0)
		if inner.encloses(lr):
			# (a backing the map's colour under the name: a link running past doesn't scribble through it)
			var tw := minf(SILK.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, 120.0)
			s.draw_rect(Rect2(c.x - tw * 0.5 - 2.0, lr.position.y, tw + 4.0, lr.size.y + 1.0), Color(MAP_BG, 0.9))
			_outlined(s, lr.position + Vector2(0, 8), nm, Color.WHITE if picked else (UIStyle.CREAM if lit else TEXT_OFF), HORIZONTAL_ALIGNMENT_CENTER, 120.0)
			if lv > 0:
				_outlined(s, lr.position + Vector2(0, 17), "LV %d" % lv, TAG_OFF, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	# zoom in, zoom out, and back to what you can buy next
	var bx := area.end.x - 24.0
	for i in range(3):
		var br := Rect2(bx, area.position.y + 6.0 + i * 24.0, 18, 20)
		var hid: String = ["map:in", "map:out", "map:next"][i]
		var lit: bool = s.inspected() == hid
		s.draw_rect(br, DIM_FILL)
		s.draw_rect(br, UIStyle.GILT if i < 2 or lit else DIM_RIM, false, 1.0)
		s.draw_string(SILK, Vector2(br.position.x, br.position.y + 13.0), ["+", "-", "N"][i], HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 8, UIStyle.CREAM)
		s.hit(br, hid, false)
	_outlined(s, Vector2(area.position.x + 6.0, area.end.y - 5.0), "WHEEL / TRIGGERS: ZOOM   DRAG / RIGHT STICK: MOVE   N: NEXT", Color(UIStyle.CREAM, 0.6))


## The level a node (its next step) opens at, if you're not there yet; 0 once reached.
static func _locked_at(id: String, pr: Progression) -> int:
	var n := SkillTrees.node_def(id)
	var lv := int(n["level"])
	if str(n["kind"]) == "step" and n.has("step_levels") and pr.steps_of(id) < int(n["max_steps"]):
		lv = int(n["step_levels"][pr.steps_of(id)])
	if pr.tree_level(str(n["tree"])) >= lv or (str(n["kind"]) != "step" and pr.owns_node(id)):
		return 0
	return lv


## A segment clipped to `r` (Liang-Barsky): [a, b], or [] when it's all outside.
static func clip(a: Vector2, b: Vector2, r: Rect2) -> Array:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for pq in [[-d.x, a.x - r.position.x], [d.x, r.end.x - a.x], [-d.y, a.y - r.position.y], [d.y, r.end.y - a.y]]:
		var p: float = pq[0]
		var q: float = pq[1]
		if is_zero_approx(p):
			if q < 0.0:
				return []
			continue
		var u := q / p
		if p < 0.0:
			if u > t1:
				return []
			t0 = maxf(t0, u)
		else:
			if u < t0:
				return []
			t1 = minf(t1, u)
	return [a + d * t0, a + d * t1]


## A path for the chart page: filled in the tree's colour once taken, else a hollow grey channel (a step's thin and grey).
static func _link(s: Control, a: Vector2, b: Vector2, col: Color, on: bool, thin: bool) -> void:
	if thin:
		s.draw_line(a, b, col if on else Color(LINK_OFF, 0.75), 2.0)
	elif on:
		s.draw_line(a, b, Color(col, 0.28), 4.0)
		s.draw_line(a, b, col, 2.0)
	else:
		s.draw_line(a, b, LINK_OFF, 4.0)
		s.draw_line(a, b, NODE_BG, 2.0)


static func _outlined(s: Control, p: Vector2, text: String, col: Color, al := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	s.draw_string_outline(SILK, p, text, al, w, 8, 2, UIStyle.OUTLINE)
	s.draw_string(SILK, p, text, al, w, 8, col)


## One node centred on `c` at size `z`, by its shape; registers its hit.
static func draw_node(s: SkillMapScreen, id: String, c: Vector2, z: float, col: Color, pr: Progression, t: float) -> void:
	var n := SkillTrees.node_def(id)
	var shape := shape_of(id)
	var r := node_rect(id, c, z)
	var on := pr.owns_node(id)
	var can := pr.buy_why(id) == ""
	var locked := _locked_at(id, pr) > 0
	if can:
		var a := 0.5 + 0.5 * sin(t * 4.0)
		var gr := maxf(r.size.x, r.size.y) * 0.5 + 5.0 * z
		s.draw_circle(r.get_center(), gr, Color(UIStyle.GILT, 0.1 + 0.12 * a))
	match shape:
		"stat":
			_pips(s, id, n, r, z, pr, can, t)
		"passive":
			_diamond(s, c, PASSIVE_R * z, on, locked, _icon(n, PASSIVE_R * z * 1.1))
		"root":
			s.draw_circle(c, ROOT_R * z + 1.0, UIChrome.INK)
			s.draw_circle(c, ROOT_R * z, UIStyle.GILT)
			s.draw_circle(c, ROOT_R * z - 3.0, ROOT_BG)
			var ic := tree_icon(str(n["tree"]))
			if ic:
				s.draw_texture_rect(ic, Rect2(c - Vector2(12, 12) * z, Vector2(24, 24) * z), false)
			else:
				s.draw_string(SILK, Vector2(c.x - 15.0, c.y + 3.0), glyph(str(n["name"])), HORIZONTAL_ALIGNMENT_CENTER, 30.0, 8, col)
		_:
			var rr := (ULT_R if str(n["kind"]) == "ult" else ABILITY_R) * z
			_round(s, c, rr, on, locked, _icon(n, rr * 1.34), str(n["name"]), str(n["kind"]) == "ult")
	if str(n["kind"]) in ["variant", "talent"]:
		# (each half its own click: the version on that side)
		var vs: Array = n["versions"]
		var pick := pr.version_of(id) if on else -1
		for i in range(vs.size()):
			var hr := Rect2(r.position + Vector2(r.size.x * i / vs.size(), 0), Vector2(r.size.x / vs.size(), r.size.y))
			s.hit(hr, "v:%s:%d" % [id, i], false)
			var dot := Vector2(r.get_center().x + (i - (vs.size() - 1) * 0.5) * 6.0, r.end.y + 3.0)
			s.draw_rect(Rect2(dot - Vector2(2, 2), Vector2(4, 4)), UIStyle.GILT if i == pick else DIM_RIM)
	s.hit(r.grow(2.0), "n:" + id)
	if s.inspected() == "n:" + id:
		var pulse := 0.6 + 0.4 * sin(t * 5.0)
		s.draw_rect(r.grow(4.0), Color(Color.WHITE, pulse), false, 1.0)


## A node's picture to draw `px` across: its own, or for a variant its active (else first) version's.
static func _icon(n: Dictionary, px: float = 16.0) -> Texture2D:
	var p := pic(n)
	if p == "" and not (n["versions"] as Array).is_empty():
		p = pic(n["versions"][0])
	return Skills.icon(p, px) if p != "" else null


## An ability: a round node, gold-rimmed, its icon inside (an ultimate a double rim).
static func _round(s: Control, c: Vector2, r: float, on: bool, locked: bool, ic: Texture2D, name_: String, ult: bool) -> void:
	s.draw_circle(c, r + 1.5, UIChrome.INK)
	s.draw_circle(c, r, OWN_FILL if on else DIM_FILL)
	if locked:
		_dashed_ring(s, c, r, Color(UIStyle.GILT, 0.55))
	else:
		s.draw_arc(c, r - 1.0, 0.0, TAU, 28, UIStyle.GILT if on or not locked else DIM_RIM, 2.5 if on else 1.5)
		if ult:
			s.draw_arc(c, r - 4.0, 0.0, TAU, 28, Color(UIStyle.GILT, 0.7), 1.0)
	var isz := roundf(r * 1.34)
	if ic:
		s.draw_texture_rect(ic, Rect2((c - Vector2(isz, isz) * 0.5).round(), Vector2(isz, isz)), false, Color.WHITE if on else Color(0.75, 0.82, 0.82, 0.4 if locked else 0.75))
	else:
		s.draw_string(SILK, Vector2(c.x - r, c.y + 3.0), glyph(name_), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 8, UIStyle.CREAM if on else TAG_OFF)


## A passive: a diamond, blue-rimmed (its icon small inside when it has one).
static func _diamond(s: Control, c: Vector2, h: float, on: bool, locked: bool, ic: Texture2D) -> void:
	var outer := PackedVector2Array([c + Vector2(0, -h - 1.5), c + Vector2(h + 1.5, 0), c + Vector2(0, h + 1.5), c + Vector2(-h - 1.5, 0)])
	var body := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)])
	s.draw_colored_polygon(outer, UIChrome.INK)
	s.draw_colored_polygon(body, OWN_FILL if on else DIM_FILL)
	var loop := body.duplicate()
	loop.append(body[0])
	if locked:
		for i in range(4):
			s.draw_dashed_line(loop[i], loop[i + 1], Color(PASSIVE, 0.55), 1.5, 3.0)
	else:
		s.draw_polyline(loop, PASSIVE if not on else Color.WHITE.lerp(PASSIVE, 0.4), 2.0 if on else 1.5)
	if ic:
		var isz := h * 1.1
		s.draw_texture_rect(ic, Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false, Color.WHITE if on else Color(0.75, 0.82, 0.82, 0.5))
	elif on:
		s.draw_circle(c, h * 0.3, PASSIVE)


## A stat chain: a row of small square pips, the bought ones lit, the next one pulsing while it can be bought.
static func _pips(s: Control, id: String, n: Dictionary, r: Rect2, z: float, pr: Progression, can: bool, t: float) -> void:
	var have := pr.steps_of(id)
	var p := PIP * z
	for i in range(int(n["max_steps"])):
		var q := Rect2(r.position.x + i * (p + 2.0 * z), r.position.y, p, p)
		s.draw_rect(q.grow(1.0), UIChrome.INK)
		var lit := i < have
		var next := i == have and can
		s.draw_rect(q, STAT_ON if lit else (Color(STAT_ON, 0.35 + 0.3 * sin(t * 4.0)) if next else DIM_RIM))


static func _dashed_ring(s: Control, c: Vector2, r: float, col: Color) -> void:
	for i in range(12):
		var a := TAU * i / 12.0
		s.draw_arc(c, r - 1.0, a, a + TAU / 24.0, 3, col, 2.0)
