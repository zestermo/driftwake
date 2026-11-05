extends Control
## A generated village's notice board (1.30, docs/v1_30_plan.md round 9; GameMenu screen "notice_board", opened by
## reading the board): no jobs to take, just what the island offers at a glance, from IslandRecord.
##   ISLAND RECORD: how much the crew has explored, the main mission (the island's trouble) and its state, side
##   missions done of all, places found of all.
##   BOUNTIES, newest first: what, where (marked on the held map), the reward and the state. No taking: the fight
##   starts when you get there; you report to whoever posted it.
##   WHO NEEDS A HAND: the people with work or wanting something (materials, food...), where they are, how it stands.
## Reading it is the landing's third objective (ChainGoal): a world flag, the crew's.

const W := 780.0
const H := 420.0
const REC_W := 210.0
const BOUNTY_W := 280.0
const FOLK_W := 250.0
const FOLK_ROWS := 8
const BOLD := preload("res://assets/fonts/PixelifySans-SemiBold.woff2")
const CORK := Color("6b4a2c")
const CORK_DARK := Color("4a3220")
const PAPER := Color("e9d9b0")
const PAPER_OLD := Color("cdbb8c")
const PIN := Color("b8382a")
const STATE := {"open": ["GO THERE", UIStyle.CORAL], "on": ["UNDER WAY", UIStyle.SUN], "report": ["REPORT", UIStyle.GOOD], "done": ["PAID", UIStyle.TEXT_DISABLED],
	"ask": ["NOT STARTED", UIStyle.CORAL], "has": ["HAS WORK", UIStyle.CORAL]}

var isl: GenIsland
var _menu: Node
var _title: Label
var _line: Label
var _body: HBoxContainer


func _init(menu: Node) -> void:
	_menu = menu
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(CORK, CORK_DARK, 3, 8))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(W, H)
	panel.offset_left = -W * 0.5
	panel.offset_top = -H * 0.5
	panel.offset_right = W * 0.5
	panel.offset_bottom = H * 0.5
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	vb.add_child(head)
	var t := UIStyle.label("NOTICE BOARD", 16, UIStyle.SUN)
	t.add_theme_font_override("font", BOLD)
	head.add_child(t)
	_title = InventoryScreen.small("", UIStyle.CREAM)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_title)
	_line = InventoryScreen.small("", UIStyle.TEXT_DIM)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(W - 16.0, 0)
	vb.add_child(_line)
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 7)
	_body.custom_minimum_size = Vector2(W - 16.0, H - 64.0)
	vb.add_child(_body)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	vb.add_child(foot)
	foot.add_child(UIStyle.key_hint("ESC", "LEAVE"))
	foot.add_child(UIStyle.key_hint("M", "THE MAP: BOUNTIES MARKED X"))


static func box(fill: Color, rim: Color, w: int, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = rim
	sb.set_border_width_all(w)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = maxi(pad - 2, 2)
	sb.content_margin_bottom = maxi(pad - 2, 2)
	return sb


func on_open() -> void:
	refresh()


func refresh() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	if isl == null or not is_instance_valid(isl):
		return
	var r := IslandRecord.of(isl)
	_title.text = "%s  -  WHAT THE ISLAND OFFERS" % isl.island_name.to_upper()
	_line.text = str(isl.get_node("Site_village/Village").board_line)
	_body.add_child(_record(r))
	_body.add_child(_bounties(r))
	_body.add_child(_folk(r))


func _record(r: Dictionary) -> Control:
	var pc := _panel(UIStyle.BG_DARK, UIStyle.BORDER_DIM, REC_W)
	var vb: VBoxContainer = pc.get_child(0)
	vb.add_child(_small("ISLAND RECORD", UIStyle.SUN))
	vb.add_child(_small("THE CREW'S, SHARED", UIStyle.TEXT_DIM))
	var e := float(r["explored"])
	vb.add_child(_stat("EXPLORED", "%d%%" % roundi(e * 100.0), e, UIStyle.TEAL_LIGHT))
	vb.add_child(InventoryScreen._rule())
	vb.add_child(_small("MAIN MISSION", UIStyle.TEXT_DIM))
	var m: Dictionary = r["main"]
	if m.is_empty():
		vb.add_child(_wrap("No trouble here that anyone speaks of.", UIStyle.TEXT_DIM, REC_W - 14.0))
	else:
		vb.add_child(_wrap(str(m["title"]), UIStyle.TEXT, REC_W - 14.0, BOLD))
		if m["state"] == "ask":
			vb.add_child(_wrap(str(m["poster"]), UIStyle.CREAM, REC_W - 14.0))
		vb.add_child(_wrap(str(m["goal"]) if m["state"] != "done" else "Done: %s thanks you." % m["giver"], UIStyle.TEXT_DIM, REC_W - 14.0))
		vb.add_child(_chip(m["state"]))
	vb.add_child(InventoryScreen._rule())
	var side: Array = r["side"]
	vb.add_child(_stat("SIDE MISSIONS", "%d / %d" % [side[0], side[1]], float(side[0]) / maxf(float(side[1]), 1.0), UIStyle.GOOD))
	var po: Array = r["pois"]
	vb.add_child(_stat("PLACES FOUND", "%d / %d" % [po[0], po[1]], float(po[0]) / maxf(float(po[1]), 1.0), UIStyle.SUN))
	var names: Array = r["found"]
	for n in names.slice(0, 3):
		vb.add_child(_small("+ " + str(n), UIStyle.TEXT_DIM))
	if int(po[1]) > int(po[0]):
		vb.add_child(_small("%d still to find" % (int(po[1]) - int(po[0])), UIStyle.TEXT_DISABLED))
	return pc


func _bounties(r: Dictionary) -> Control:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(BOUNTY_W, 0)
	vb.add_theme_constant_override("separation", 4)
	vb.add_child(_small("BOUNTIES  -  NEWEST FIRST", UIStyle.SUN))
	var list: Array = r["bounties"]
	if list.is_empty():
		vb.add_child(_wrap("No bounties posted.", UIStyle.CREAM, BOUNTY_W))
	for b in list:
		vb.add_child(_note(b))
	vb.add_child(_small_wrap("NOTHING TO TAKE: GO THERE AND THE FIGHT STARTS. THE ONE WHO POSTED IT PAYS.", UIStyle.CREAM, BOUNTY_W))
	return vb


func _note(b: Dictionary) -> Control:
	var done: bool = b["state"] == "done"
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", box(PAPER_OLD if done else PAPER, CORK_DARK, 1, 5))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	pc.add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	var pin := ColorRect.new()
	pin.color = PIN
	pin.custom_minimum_size = Vector2(5, 5)
	pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(pin)
	var t := _wrap(str(b["title"]), UIStyle.INK, BOUNTY_W - 92.0, BOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(_chip(b["state"], "REPORT TO " + str(b["poster"]).get_slice(" ", str(b["poster"]).get_slice_count(" ") - 1).to_upper() if b["state"] == "report" else ""))
	vb.add_child(_small_wrap("X %s  -  BY %s" % [str(b["place"]).to_upper(), str(b["poster"]).to_upper()], UIStyle.PARCH_DIM, BOUNTY_W - 12.0))
	vb.add_child(_small_wrap("REWARD  %s" % str(b["reward"]).to_upper(), UIStyle.PARCH_INK, BOUNTY_W - 12.0))
	return pc


func _small_wrap(text: String, col: Color, w: float) -> Label:
	var l := _small(text, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_constant_override("line_spacing", -3)
	l.custom_minimum_size = Vector2(w, 0)
	return l


func _folk(r: Dictionary) -> Control:
	var pc := _panel(UIStyle.BG_DARK, UIStyle.BORDER_DIM, FOLK_W)
	var vb: VBoxContainer = pc.get_child(0)
	vb.add_child(_small("WHO NEEDS A HAND", UIStyle.SUN))
	var list: Array = (r["folk"] as Array).filter(func(f): return f["state"] != "done") + (r["folk"] as Array).filter(func(f): return f["state"] == "done")
	if list.is_empty():
		vb.add_child(_wrap("Nobody's asking for anything.", UIStyle.TEXT_DIM, FOLK_W - 14.0))
	if list.size() > FOLK_ROWS:
		list = list.slice(0, FOLK_ROWS)
	for f in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		vb.add_child(row)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var dim: bool = f["state"] == "done"
		var cw := FOLK_W - 84.0
		col.add_child(_wrap(str(f["who"]), UIStyle.TEXT_DISABLED if dim else UIStyle.TEXT, cw, BOLD))
		var what := str(f["wants"]) if str(f["wants"]) != "" else str(f["what"])
		col.add_child(_small_wrap(what, UIStyle.TEXT_DISABLED if dim else (UIStyle.SUN if str(f["wants"]) != "" else UIStyle.TEXT_DIM), cw))
		if str(f["where"]) != "" and not dim:
			col.add_child(_small_wrap(str(f["where"]), UIStyle.TEXT_DISABLED, cw))
		row.add_child(_chip(f["state"]))
	return pc


## A label, a value and a bar under them.
func _stat(name_: String, value: String, k: float, col: Color) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	var l := _small(name_, UIStyle.TEXT_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(l)
	var v := UIStyle.label(value, 16, col)
	v.add_theme_font_override("font", BOLD)
	hb.add_child(v)
	var bar := ColorRect.new()
	bar.color = UIStyle.OUTLINE
	bar.custom_minimum_size = Vector2(0, 4)
	vb.add_child(bar)
	var fill := ColorRect.new()
	fill.color = col
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(k, 0.0, 1.0)
	bar.add_child(fill)
	return vb


func _chip(state: String, text := "") -> Control:
	var s: Array = STATE[state]
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", box(UIStyle.OUTLINE, s[1], 1, 3))
	pc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(_small(text if text != "" else s[0], s[1]))
	return pc


func _panel(fill: Color, rim: Color, w: float) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", box(fill, rim, 1, 6))
	pc.custom_minimum_size = Vector2(w, 0)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	pc.add_child(vb)
	return pc


func _small(text: String, col: Color) -> Label:
	var l := InventoryScreen.small(text, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _wrap(text: String, col: Color, w: float, font: Font = null) -> Label:
	var l := InventoryScreen._text(text, col, font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
