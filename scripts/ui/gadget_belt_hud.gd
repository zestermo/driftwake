extends Control
## The gadget belt on the HUD (1.28), right of the skill bar: its slots (one, six with a gadget bag), each its gadget's icon, its tier (I-III),
## the charges left and the cooldown sweeping down; the selected one framed in gold with its key over it. Hidden
## with nothing on the belt or off foot. Looks at the belt every LOOK_EVERY (real time) and redraws on a change.

const FONT := preload("res://assets/fonts/Silkscreen-Regular.woff2")
const FS := 8
const SLOT := 36.0
const GAP := 3.0
const W := SLOT * GadgetData.BAG_SLOTS + GAP * (GadgetData.BAG_SLOTS - 1)
const H := SLOT + 12.0
const LOOK_EVERY := 0.1
const ROMAN := ["I", "II", "III"]

var _look := 0.0
var _last := 0
var _p: Node


func _ready() -> void:
	name = "GadgetBelt"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = SkillBar.W * 0.5 + 10.0
	offset_right = offset_left + W
	offset_bottom = -6.0
	offset_top = offset_bottom - H
	visible = false


func _process(delta: float) -> void:
	_look -= delta / maxf(Engine.time_scale, 0.05)
	if _look > 0.0:
		return
	_look = LOOK_EVERY
	if _p == null or not is_instance_valid(_p):
		_p = get_tree().get_first_node_in_group("player")
	var belt: GadgetBelt = _p.gadgets if _p else null
	visible = belt != null and belt.best_tier() >= 0 and _p.context == Player.Context.ON_FOOT
	if not visible:
		return
	var s := hash([belt.slots, belt.sel, belt.owned, Glyphs.of("gadget_fire")])
	for g in belt.slots:
		if g != "":
			s ^= hash(ceili(belt.cooldown_left(g) * 4.0)) + hash(g) + belt.packs(g) * 7919
	if s != _last:
		_last = s
		queue_redraw()


func _draw() -> void:
	var belt: GadgetBelt = _p.gadgets
	for i in range(belt.slots.size()):
		var r := Rect2(Vector2(i * (SLOT + GAP), 10.0), Vector2(SLOT, SLOT))
		var on: bool = i == belt.sel
		draw_rect(r, UIStyle.BG_DARK)
		var gid := str(belt.slots[i])
		if gid != "":
			var t := belt.tier_of(gid)
			draw_texture_rect(GadgetModels.icon(gid, t), r.grow(-2.0), false)
			var cd := belt.cooldown_left(gid)
			if cd > 0.0:
				var k := clampf(cd / belt.cooldown_len(gid), 0.0, 1.0)
				draw_rect(Rect2(r.position, Vector2(SLOT, SLOT * k)), Color(0, 0, 0, 0.6))
				_text(r.position + Vector2(SLOT * 0.5 - 6.0, SLOT * 0.5 + 3.0), "%d" % ceili(cd), UIStyle.CREAM)
			_text(r.position + Vector2(2.0, 8.0), ROMAN[t], UIStyle.SUN if t == 2 else UIStyle.TEXT_DIM)
			if belt.max_charges(gid) > 0:
				var n := belt.charges(gid)
				_text(r.position + Vector2(SLOT - 8.0, SLOT - 2.0), str(n), UIStyle.CORAL if n == 0 else UIStyle.CREAM)
				# (1.30) ready-made packs in the bag, the refills after these
				if belt.packs(gid) > 0:
					_text(r.position + Vector2(2.0, SLOT - 2.0), "+%d" % belt.packs(gid), UIStyle.TEXT_DIM)
		draw_rect(r, UIStyle.SUN if on else UIStyle.BORDER_DIM, false, 2.0 if on else 1.0)
		if on:
			var key := Glyphs.of("gadget_fire").to_upper()
			_text(Vector2(r.position.x + (SLOT - FONT.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x) * 0.5, 8.0), key, UIStyle.SUN)


func _text(at: Vector2, s: String, c: Color) -> void:
	draw_string_outline(FONT, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, 2, UIStyle.OUTLINE)
	draw_string(FONT, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, c)
