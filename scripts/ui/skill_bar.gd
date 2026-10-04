class_name SkillBar
extends Control
## The bottom-center action bar, MMO style, drawn in one pass for the 640x360
## PSX canvas:
##
##   (HP orb) [stamina...........................................] (EN orb)
##            [1][2][3][4]  [ R ]  | [5][6][7]
##
## * Health orb (left): red liquid with a slosh, a pale "recent damage" chip
##   that drains after a hit, and the number.
## * Energy orb (right): energy for skills (blue; your Devil Fruit's color
##   once you've eaten one).
## * Level badge and experience bar along the bottom of the plate; unspent
##   skill points pulse next to the level.
## * Stamina: a thin bar across the top of the plate (amber when spent, flashes
##   red when an action is refused).
## * Skills 1-4: icon, key, energy cost, cooldown sweep + seconds, dimmed when
##   you can't afford them, a white flash when they come off cooldown, a red
##   flash when a cast is refused. In the sea they're all doused.
## * Ultimate (R): bigger slot with a charge ring that fills from damage dealt
##   and pulses when ready.
## * Quick items 5-7: consumables (rum...), with how many you carry.

const W := 352.0
const H := 70.0
const ORB_R := 25.0
const SKILL := 26.0
const ULT := 34.0
const ITEM := 22.0
const GAP := 2.0
const PLATE_Y := 20.0
const ROW_Y := 30.0
const FONT := preload("res://assets/fonts/Silkscreen-Regular.woff2")

const HP_COL := Color(0.78, 0.1, 0.08)
const HP_HI := Color(1.0, 0.42, 0.32)
const ST_COL := Color(0.36, 0.78, 0.32)
const ST_EMPTY := Color(0.85, 0.62, 0.18)
const PLATE := Color(0.05, 0.05, 0.08, 0.9)

var player: Player
var _hp_shown: float = 1.0      # fraction, eases toward the real value
var _hp_chip: float = 1.0       # trailing "recent damage" fraction
var _chip_hold: float = 0.0
var _en_shown: float = 0.0
var _en_chip: float = 0.0       # energy just spent, drains after a moment
var _en_hold: float = 0.0
var _en_flash: float = 0.0
var _t: float = 0.0
var _stamina_flash: float = 0.0
var _ready_flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _fail_flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _prev_cd: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _ult_was_full: bool = false
## Skill icons, loaded outside _draw (a texture first loaded while drawing
## comes out blank).
var _icons: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func bind(p: Player) -> void:
	player = p
	_hp_shown = _hp_frac()
	_hp_chip = _hp_shown
	player.stamina_denied.connect(func(): _stamina_flash = 0.45)
	player.power.cast_failed.connect(func(slot: int, why: String):
		_fail_flash[slot] = 0.35
		if why in ["Not enough energy", "Ultimate not charged", "Your power fizzles in the sea"]:
			get_tree().call_group("hud", "show_toast", why))
	player.power.fruit_changed.connect(func(_id):
		_load_icons()
		queue_redraw())
	player.power.loadout_changed.connect(_load_icons)
	player.power.energy_spent.connect(func(_amt: float):
		_en_chip = maxf(_en_chip, _en_shown)
		_en_shown = player.power.energy / maxf(player.power.max_energy(), 1.0)
		_en_hold = 0.5
		_en_flash = 0.25)
	_load_icons()


func _load_icons() -> void:
	_icons.clear()
	for i in range(5):
		var sk := player.power.skill(i)
		if not sk.is_empty():
			_icons[str(sk["id"])] = Skills.icon(str(sk["id"]))


func _hp_frac() -> float:
	if player == null:
		return 1.0
	var hc := player.health_component
	return clampf(hc.current_health / maxf(hc.max_health, 1.0), 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	if player == null:
		return
	var hp := _hp_frac()
	if hp < _hp_shown - 0.001:
		_chip_hold = 0.6  # hold the chip a moment after each hit
		_hp_chip = maxf(_hp_chip, _hp_shown)
	_hp_shown = move_toward(_hp_shown, hp, delta * 2.5)
	if _chip_hold > 0.0:
		_chip_hold -= delta
	else:
		_hp_chip = move_toward(_hp_chip, _hp_shown, delta * 0.6)
	if _hp_chip < _hp_shown:
		_hp_chip = _hp_shown
	var pc := player.power
	var en := pc.energy / maxf(pc.max_energy(), 1.0)
	_en_shown = move_toward(_en_shown, en, delta * 2.0)
	_en_flash = maxf(_en_flash - delta, 0.0)
	if _en_hold > 0.0:
		_en_hold -= delta
	else:
		_en_chip = move_toward(_en_chip, _en_shown, delta * 0.7)
	_en_chip = maxf(_en_chip, _en_shown)
	_stamina_flash = maxf(_stamina_flash - delta, 0.0)
	for i in range(5):
		_fail_flash[i] = maxf(_fail_flash[i] - delta, 0.0)
		_ready_flash[i] = maxf(_ready_flash[i] - delta, 0.0)
		var cd := pc.cooldown_left(i)
		if _prev_cd[i] > 0.0 and cd <= 0.0 and not pc.skill(i).is_empty():
			_ready_flash[i] = 0.3
		_prev_cd[i] = cd
	var full := not pc.skill(4).is_empty() and pc.ult >= PowerComponent.ULT_MAX
	if full and not _ult_was_full:
		_ready_flash[4] = 0.5
	_ult_was_full = full
	queue_redraw()


# ==========================================================================
# Drawing
# ==========================================================================
func _draw() -> void:
	if player == null:
		return
	var pc := player.power
	var fruit_col: Color = pc.fruit_data().get("color", Color(0.35, 0.6, 1.0))
	# the plate the slots sit on
	var plate := Rect2(ORB_R, PLATE_Y, W - ORB_R * 2.0, H - PLATE_Y - 2.0)
	draw_rect(plate, PLATE)
	draw_rect(plate, UIStyle.BORDER_DIM, false, 1.0)
	draw_line(plate.position + Vector2(1, 1), Vector2(plate.end.x - 1, plate.position.y + 1), Color(1, 1, 1, 0.06))
	# stamina along the top of the plate
	var x0 := ORB_R * 2.0 + 8.0
	_draw_stamina(Rect2(x0, PLATE_Y + 3.0, W - x0 * 2.0, 4.0))
	# slots
	var x := x0
	for i in range(4):
		_draw_skill(Rect2(x, ROW_Y + (ULT - SKILL) * 0.5, SKILL, SKILL), i, fruit_col)
		x += SKILL + GAP
	x += 5.0
	_draw_ult(Rect2(x, ROW_Y, ULT, ULT), fruit_col)
	x += ULT + 6.0
	# a thin divider, then the quick items
	draw_line(Vector2(x, ROW_Y + 6.0), Vector2(x, ROW_Y + ULT - 4.0), UIStyle.BORDER_DIM, 1.0)
	x += 5.0
	for i in range(InventoryComponent.HOTBAR_SIZE):
		_draw_item(Rect2(x, ROW_Y + (ULT - ITEM) * 0.5 + 2.0, ITEM, ITEM), i)
		x += ITEM + GAP
	# orbs
	var hc := player.health_component
	_draw_orb(Vector2(ORB_R + 2.0, H - ORB_R - 3.0), _hp_shown, _hp_chip, HP_COL, HP_HI,
		"%d" % ceili(hc.current_health), "HP")
	if true:
		var doused := pc.suppressed()
		var ec := fruit_col.darkened(0.15) if not doused else Color(0.3, 0.38, 0.5)
		var ec_hi := ec.lightened(0.45) if _en_flash <= 0.0 else Color.WHITE
		_draw_orb(Vector2(W - ORB_R - 2.0, H - ORB_R - 3.0), _en_shown, _en_chip, ec, ec_hi,
			"%d" % int(pc.energy), "EN")
	_draw_xp()
	_draw_ammo()


func _text(pos: Vector2, s: String, col: Color = UIStyle.TEXT, size_px: int = 8, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	# outlined pixel text
	draw_string_outline(FONT, pos, s, align, w, size_px, 3, Color(0, 0, 0, 0.9))
	draw_string(FONT, pos, s, align, w, size_px, col)


func _draw_stamina(r: Rect2) -> void:
	draw_rect(r.grow(1.0), Color(0, 0, 0, 0.8))
	var frac := clampf(player.stamina / maxf(player.max_stamina, 1.0), 0.0, 1.0)
	var col := ST_EMPTY if (player.stamina < player.LIGHT_COST or player.winded) else ST_COL
	if _stamina_flash > 0.0 and int(_stamina_flash * 16.0) % 2 == 0:
		col = Color(0.95, 0.2, 0.15)
	draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(r.size.x * frac, 1.0)), col.lightened(0.35))


## A liquid-filled orb: dark glass, the fill with a sloshing surface, a chip
## of recently lost value, a highlight and a gold rim; value and label below.
func _draw_orb(c: Vector2, frac: float, chip: float, col: Color, hi: Color, value: String, label: String) -> void:
	var r := ORB_R
	var circle := PackedVector2Array()
	for i in range(28):
		var a := TAU * float(i) / 28.0
		circle.append(c + Vector2(cos(a), sin(a)) * (r - 2.0))
	draw_colored_polygon(circle, Color(0.03, 0.02, 0.03, 0.95))
	if chip > frac + 0.002:
		_fill_poly(circle, c, r, chip, Color(1.0, 0.85, 0.6, 0.85), 0.0)
	if frac > 0.0:
		_fill_poly(circle, c, r, frac, col, 1.0)
		# a brighter band just under the surface
		_fill_poly(circle, c, r, frac, hi, 1.0, 3.0)
	# glass highlight + rim
	draw_circle(c + Vector2(-r * 0.35, -r * 0.42), r * 0.22, Color(1, 1, 1, 0.12))
	draw_circle(c + Vector2(-r * 0.4, -r * 0.48), r * 0.08, Color(1, 1, 1, 0.25))
	draw_arc(c, r - 1.0, 0.0, TAU, 32, Color(0.1, 0.07, 0.03), 3.0)
	draw_arc(c, r - 1.0, 0.0, TAU, 32, UIStyle.BORDER, 1.0)
	_text(c + Vector2(-20.0, 3.0), value, Color.WHITE, 8, HORIZONTAL_ALIGNMENT_CENTER, 40.0)
	_text(c + Vector2(-20.0, -6.0), label, Color(1, 1, 1, 0.55), 8, HORIZONTAL_ALIGNMENT_CENTER, 40.0)


## The part of the orb below the liquid line (with a little wave). band > 0:
## only a strip of that thickness under the surface.
func _fill_poly(circle: PackedVector2Array, c: Vector2, r: float, frac: float, col: Color, wave: float, band: float = 0.0) -> void:
	var top := c.y + (r - 2.0) - frac * (r - 2.0) * 2.0
	var poly := PackedVector2Array()
	var n := 12
	for i in range(n + 1):
		var x := c.x - r + 2.0 * r * float(i) / float(n)
		var y := top + sin(_t * 3.0 + x * 0.35) * 1.2 * wave
		poly.append(Vector2(x, y))
	var bottom := c.y + r if band <= 0.0 else top + band
	poly.append(Vector2(c.x + r, bottom))
	poly.append(Vector2(c.x - r, bottom))
	for piece in Geometry2D.intersect_polygons(circle, poly):
		if (piece as PackedVector2Array).size() >= 3:
			draw_colored_polygon(piece, col)


func _slot_frame(r: Rect2, border: Color, bw: float = 1.0) -> void:
	draw_rect(r, Color(0.02, 0.02, 0.04, 0.95))
	draw_rect(r, border, false, bw)


## Dark pie over the icon for the remaining cooldown (clockwise from 12).
func _cooldown_pie(r: Rect2, frac: float) -> void:
	if frac <= 0.0:
		return
	var c := r.get_center()
	var rad := r.size.length() * 0.5
	var pts := PackedVector2Array([c])
	var a0 := -PI * 0.5 + TAU * (1.0 - frac)
	var steps := maxi(int(24 * frac), 2)
	for i in range(steps + 1):
		var a := a0 + TAU * frac * float(i) / float(steps)
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	var clip := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	for piece in Geometry2D.intersect_polygons(clip, pts):
		if (piece as PackedVector2Array).size() >= 3:
			draw_colored_polygon(piece, Color(0, 0, 0, 0.68))


func _draw_skill(r: Rect2, i: int, fruit_col: Color) -> void:
	var pc := player.power
	var sk := pc.skill(i)
	var key := str(i + 1)
	if sk.is_empty():
		_slot_frame(r, Color(0.25, 0.24, 0.22))
		_text(r.position + Vector2(2, 8), key, Color(0.5, 0.5, 0.5))
		return
	var doused := pc.suppressed() and str(sk.get("fruit", "")) != ""
	var cost := float(sk.get("cost", 0.0))
	var afford := pc.energy >= cost
	var border := fruit_col.darkened(0.2)
	if _fail_flash[i] > 0.0:
		border = Color(1.0, 0.2, 0.15)
	elif _ready_flash[i] > 0.0:
		border = Color.WHITE
	_slot_frame(r, border, 2.0 if (_fail_flash[i] > 0.0 or _ready_flash[i] > 0.0) else 1.0)
	var tex: Texture2D = _icons.get(str(sk["id"]))
	var tint := Color.WHITE
	if doused:
		tint = Color(0.35, 0.45, 0.6, 0.8)
	elif not afford:
		tint = Color(0.45, 0.45, 0.7)
	var needs := str(sk.get("needs", ""))
	if needs != "" and player.weapon_class() != needs:
		tint = Color(0.5, 0.45, 0.45, 0.7)
	if tex:
		draw_texture_rect(tex, r.grow(-1.0), false, tint)
	var cd := pc.cooldown_left(i)
	if cd > 0.0:
		_cooldown_pie(r.grow(-1.0), cd / maxf(pc.cooldown_total(i), 0.01))
		_text(Vector2(r.position.x, r.get_center().y + 4.0), str(ceili(cd)), Color.WHITE, 8, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if _ready_flash[i] > 0.0:
		draw_rect(r.grow(-1.0), Color(1, 1, 1, _ready_flash[i] * 1.2))
	_text(r.position + Vector2(2, 8), key, UIStyle.ACCENT)
	_text(Vector2(r.position.x, r.end.y - 1.0), str(int(cost)), Color(1.0, 0.75, 0.4) if afford else Color(1.0, 0.35, 0.3), 8, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 1.0)


func _draw_ult(r: Rect2, fruit_col: Color) -> void:
	var pc := player.power
	var sk := pc.skill(4)
	var c := r.get_center()
	var rad := r.size.x * 0.5 + 3.0
	# charge ring
	draw_arc(c, rad, 0.0, TAU, 32, Color(0, 0, 0, 0.8), 4.0)
	if sk.is_empty():
		_slot_frame(r, Color(0.25, 0.24, 0.22))
		_text(r.position + Vector2(2, 9), "R", Color(0.5, 0.5, 0.5))
		return
	var frac := pc.ult / PowerComponent.ULT_MAX
	var full := frac >= 1.0
	var ring_col := fruit_col if not full else fruit_col.lerp(Color(1.0, 0.95, 0.6), 0.5 + 0.5 * sin(_t * 8.0))
	if frac > 0.0:
		draw_arc(c, rad, -PI * 0.5, -PI * 0.5 + TAU * frac, maxi(int(32 * frac), 2), ring_col, 3.0)
	if full:
		draw_arc(c, rad + 2.5, 0.0, TAU, 32, Color(ring_col.r, ring_col.g, ring_col.b, 0.35 + 0.25 * sin(_t * 8.0)), 2.0)
	var border := UIStyle.BORDER
	if _fail_flash[4] > 0.0:
		border = Color(1.0, 0.2, 0.15)
	_slot_frame(r, border, 2.0)
	var tex: Texture2D = _icons.get(str(sk["id"]))
	var doused := pc.suppressed() and str(sk.get("fruit", "")) != ""
	var tint := Color.WHITE if full and not doused else (Color(0.35, 0.45, 0.6, 0.8) if doused else Color(0.5, 0.42, 0.38))
	if tex:
		draw_texture_rect(tex, r.grow(-2.0), false, tint)
	var cd := pc.cooldown_left(4)
	if cd > 0.0:
		_cooldown_pie(r.grow(-2.0), cd / maxf(pc.cooldown_total(4), 0.01))
	if not full:
		_text(Vector2(r.position.x, c.y + 4.0), "%d%%" % int(frac * 100.0), Color(1, 1, 1, 0.85), 8, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if _ready_flash[4] > 0.0:
		draw_rect(r.grow(-2.0), Color(1, 0.9, 0.6, _ready_flash[4]))
	_text(r.position + Vector2(2, 9), "R", UIStyle.ACCENT)


func _draw_item(r: Rect2, i: int) -> void:
	var inv := player.inventory_component
	var item: ItemData = ItemDB.get_item(inv.hotbar[i]) if inv.hotbar[i] != "" else null
	_slot_frame(r, UIStyle.BORDER_DIM, 1.0)
	if item:
		var qty := inv.count(item.id)
		if item.icon:
			draw_texture_rect(item.icon, r.grow(-1.0), false, Color(1, 1, 1, 1.0 if qty > 0 else 0.3))
		_text(Vector2(r.position.x, r.end.y - 1.0), str(qty), Color.WHITE if qty > 0 else Color(1, 0.4, 0.35), 8, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 1.0)
	_text(r.position + Vector2(2, 8), str(i + 5), Color(0.75, 0.72, 0.65))


## Level badge (over the health orb) and the experience bar along the bottom
## of the plate; unspent skill points pulse beside the level.
func _draw_xp() -> void:
	var pr := player.progression
	if pr == null:
		return
	var x0 := ORB_R * 2.0 + 8.0
	var r := Rect2(x0, H - 6.0, W - x0 * 2.0, 3.0)
	draw_rect(r.grow(1.0), Color(0, 0, 0, 0.8))
	var frac := clampf(float(pr.xp) / float(Progression.xp_to_next(pr.level)), 0.0, 1.0)
	draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), Color(0.55, 0.45, 1.0))
	draw_rect(Rect2(r.position, Vector2(r.size.x * frac, 1.0)), Color(0.8, 0.75, 1.0))
	var badge := Vector2(ORB_R + 2.0, 6.0)
	draw_circle(badge, 8.0, Color(0.06, 0.05, 0.1, 0.95))
	draw_arc(badge, 8.0, 0.0, TAU, 20, UIStyle.BORDER, 1.0)
	_text(badge + Vector2(-10.0, 3.0), str(pr.level), UIStyle.ACCENT, 8, HORIZONTAL_ALIGNMENT_CENTER, 20.0)
	if pr.skill_points > 0:
		var a := 0.6 + 0.4 * sin(_t * 5.0)
		_text(badge + Vector2(11.0, 3.0), "+%d SP [K]" % pr.skill_points, Color(0.75, 0.95, 0.55, a))


## Pistols: loaded shots per gun over the middle of the plate.
func _draw_ammo() -> void:
	if player.weapon_class() != "gun":
		return
	var c := Vector2(W * 0.5, PLATE_Y - 6.0)
	if player.reloading():
		_text(c + Vector2(-40, 3), "RELOADING", Color(1.0, 0.85, 0.5, 0.6 + 0.4 * sin(_t * 10.0)), 8, HORIZONTAL_ALIGNMENT_CENTER, 80)
		return
	var guns := 2 if player.offhand_weapon else 1
	var mx := player.max_ammo()
	var x := c.x - float(guns * mx) * 3.5 - (4.0 if guns == 2 else 0.0)
	for g in range(guns):
		for i in range(mx):
			var full := i < player.ammo[g]
			draw_rect(Rect2(x, c.y - 4.0, 4.0, 7.0), Color(1.0, 0.82, 0.4) if full else Color(0.25, 0.22, 0.2))
			draw_rect(Rect2(x, c.y - 4.0, 4.0, 7.0), Color(0, 0, 0, 0.8), false, 1.0)
			x += 7.0
		x += 8.0
