class_name WantedCard
extends CanvasLayer
## The new-poster moment (1.23, docs/v1_23_plan.md "Bounty"): after a big deed or a new tier, your new wanted poster
## drops in at the top of the screen: WANTED, your face (WantedPortrait), DEAD OR ALIVE, your name, the bounty
## counting up from the old number to the new one, and why. A sting, a few seconds, and it lifts away. The local
## captain's own (each captain's bounty is theirs).

const HOLD := 5.0
const COUNT := 1.4
const RED := Color(0.62, 0.1, 0.08)
const INK := Color(0.2, 0.13, 0.08)
const PAPER := Color(0.9, 0.8, 0.6)

var _panel: PanelContainer
var _amount: Label
var _from := 0
var _to := 0
var _t := 0.0


## Show captain `p`'s new poster (bounty `before` -> `after`, for `why`).
static func show_for(p: Node, before: int, after: int, why: String) -> void:
	var tree := p.get_tree()
	for old in tree.get_nodes_in_group("wanted_card"):
		old.queue_free()
	var c := WantedCard.new()
	c.add_to_group("wanted_card")
	tree.root.add_child(c)
	c._build(p, before, after, why)


func _build(p: Node, before: int, after: int, why: String) -> void:
	layer = 45
	_from = before
	_to = after
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIStyle.framed(PAPER, Color(0.45, 0.3, 0.16), "panel", 8, 6))
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.offset_top = -260.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	_panel.add_child(vb)
	vb.add_child(_line("WANTED", 26, RED))
	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(WantedPortrait.SIZE)
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(face)
	vb.add_child(_line("DEAD OR ALIVE", 8, INK))
	var who := str(p.call("display_name")) if p.has_method("display_name") else "Captain"
	vb.add_child(_line(who, 14, INK))
	_amount = _line(Bounty.fmt(before) + " gold", 16, INK)
	vb.add_child(_amount)
	if why != "":
		vb.add_child(_line(why[0].to_upper() + why.substr(1), 8, INK))
	var t := Bounty.tier_of(after)
	if t > Bounty.tier_of(before):
		vb.add_child(_line("%s: %s" % [str(Bounty.TIERS[t][1]).to_upper(), str(Bounty.TIERS[t][2])], 8, RED, 200))
	var tw := create_tween()
	tw.tween_property(_panel, "offset_top", 24.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(HOLD)
	tw.tween_property(_panel, "offset_top", -300.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
	UIStyle.sfx("quest_done")
	var body = p.get("body_model")
	if body and "look" in body:
		var tex = await WantedPortrait.render(get_tree(), body.look)
		if is_instance_valid(face):
			face.texture = tex


func _line(text: String, size: int, col: Color, wrap_w := 0) -> Label:
	var l := UIStyle.label(text, size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if wrap_w > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap_w, 0)
	return l


func _process(delta: float) -> void:
	_t += delta
	if _amount == null:
		return
	# the number counts up once the poster's down
	var k := clampf((_t - 0.5) / COUNT, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 3.0)
	_amount.text = Bounty.fmt(roundi(lerpf(_from, _to, k))) + " gold"
