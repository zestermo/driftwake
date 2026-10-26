extends PanelContainer
## Wanted (GameMenu screen "wanted", the pause menu's Wanted; 1.23 "Bounty"): your poster (your face, your bounty, its
## tier), what that tier means for you (the Admiralty, shops, hunters), how far to the next and what it brings, the
## deeds that raised it, the crew's bounties beside yours, and the rival crews you've met with theirs (1.23: the rivalry
## you can see; a crew's bounty grows each time it meets you, more when it beats you).

var _menu: Node
var _face: TextureRect
var _name: Label
var _amount: Label
var _tier: Label
var _means: Label
var _next: Label
var _deeds: VBoxContainer
var _crew: VBoxContainer
var _rivals: VBoxContainer


func _init(menu: Node) -> void:
	_menu = menu
	custom_minimum_size = Vector2(460, 0)
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BG, UIStyle.BORDER, 12))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)
	vb.add_child(UIStyle.title("Wanted"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	# your poster
	var poster := PanelContainer.new()
	poster.add_theme_stylebox_override("panel", UIStyle.framed(WantedCard.PAPER, Color(0.45, 0.3, 0.16), "panel", 6, 5))
	row.add_child(poster)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	poster.add_child(pv)
	pv.add_child(_center(UIStyle.label("WANTED", 16, WantedCard.RED)))
	_face = TextureRect.new()
	_face.custom_minimum_size = Vector2(WantedPortrait.SIZE)
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pv.add_child(_face)
	_name = _center(UIStyle.label("", 12, WantedCard.INK))
	pv.add_child(_name)
	_amount = _center(UIStyle.label("", 12, WantedCard.INK))
	pv.add_child(_amount)
	# what it means
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 3)
	row.add_child(right)
	_tier = UIStyle.label("", 14, UIStyle.ACCENT)
	right.add_child(_tier)
	_means = _wrap(UIStyle.label("", 8, UIStyle.TEXT))
	right.add_child(_means)
	_next = _wrap(UIStyle.label("", 8, UIStyle.TEXT_DIM))
	right.add_child(_next)
	right.add_child(UIStyle.label("What raised it", 8, UIStyle.ACCENT))
	_deeds = VBoxContainer.new()
	right.add_child(_deeds)
	right.add_child(UIStyle.label("The crew", 8, UIStyle.ACCENT))
	_crew = VBoxContainer.new()
	right.add_child(_crew)
	right.add_child(UIStyle.label("Rival crews", 8, UIStyle.ACCENT))
	_rivals = VBoxContainer.new()
	right.add_child(_rivals)
	var done := UIStyle.button("Done", 64)
	done.size_flags_horizontal = Control.SIZE_SHRINK_END
	done.pressed.connect(func(): _menu.call("open", "pause"))
	vb.add_child(done)


func _center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(270, 0)
	return l


func on_open() -> void:
	refresh()


func refresh() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var b := int(p.get("bounty"))
	var t := Bounty.tier_of(b)
	_name.text = str(p.call("display_name")) if p.has_method("display_name") else "Captain"
	_amount.text = "%s gold" % Bounty.fmt(b)
	_tier.text = str(Bounty.TIERS[t][1]) if t > 0 else "Not wanted (yet)"
	_means.text = (str(Bounty.TIERS[t][2]).capitalize() + ".") if t > 0 else "Nobody's put a price on you. Beat bosses, rival crews and the Admiralty and they will."
	var nx := Bounty.next_tier(b)
	_next.text = "Next: %s at %s gold (%s to go): %s." % [nx[0], Bounty.fmt(int(nx[1])), Bounty.fmt(int(nx[1]) - b), nx[2]] if not nx.is_empty() else "There's no higher price than yours."
	for c in _deeds.get_children() + _crew.get_children() + _rivals.get_children():
		c.queue_free()
	var log_: Array = p.get("bounty_log") if p.get("bounty_log") is Array else []
	if log_.is_empty():
		_deeds.add_child(UIStyle.label("Nothing yet.", 8, UIStyle.TEXT_DIM))
	for i in range(log_.size() - 1, maxi(log_.size() - 6, 0) - 1, -1):
		var e: Array = log_[i]
		var why := str(Bounty.WHY.get(str(e[0]), "for trouble"))
		_deeds.add_child(UIStyle.label("+%s  %s  (day %d)" % [Bounty.fmt(int(e[1])), why, int(e[2])], 8, UIStyle.TEXT))
	var others := 0
	for c in get_tree().get_nodes_in_group("players"):
		if c == p:
			continue
		var cb := int(c.get("bounty")) if c.get("bounty") != null else 0
		var nm := str(c.call("display_name")) if c.has_method("display_name") else "A captain"
		var ttl := Bounty.title(cb)
		_crew.add_child(UIStyle.label("%s: %s gold%s" % [nm, Bounty.fmt(cb), ("  -  " + ttl) if ttl != "" else ""], 8, UIStyle.TEXT))
		others += 1
	if others == 0:
		_crew.add_child(UIStyle.label("Sailing alone.", 8, UIStyle.TEXT_DIM))
	var gm := get_node_or_null("/root/GameManager")
	var met := 0
	if gm:
		for id in gm.rivals.keys():
			if str(id).begins_with("_") or RivalCrews.crew(str(id)).is_empty():
				continue
			var r: Dictionary = gm.rivals[id]
			var c := RivalCrews.crew(str(id))
			_rivals.add_child(UIStyle.label("%s (%s): %s gold  -  you %d, them %d" % [str(c.get("name", id)).capitalize(), str(c.get("captain", "?")),
				Bounty.fmt(rival_bounty(r)), int(r.get("won", 0)), int(r.get("lost", 0))], 8, UIStyle.TEXT))
			met += 1
	if met == 0:
		_rivals.add_child(UIStyle.label("None met yet. They're out there.", 8, UIStyle.TEXT_DIM))
	var body = p.get("body_model")
	if body and "look" in body:
		var tex = await WantedPortrait.render(get_tree(), body.look)
		if is_instance_valid(_face):
			_face.texture = tex


## A rival crew's bounty (what the board says of them): grows each meeting, more when they won.
static func rival_bounty(r: Dictionary) -> int:
	return 8000 + 5000 * int(r.get("met", 1)) + 9000 * int(r.get("lost", 0))
