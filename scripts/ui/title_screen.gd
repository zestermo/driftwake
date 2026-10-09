extends Control
## Title screen (the game's main scene): a dusk sea with a ship riding the
## swell, the logo, and Continue / New Game / Load Game / Options / Quit.
## New Game and Load open the three save slots; picking one sets
## SaveGame.slot and loads the world.

const LOGO_FONT := preload("res://assets/fonts/PixelifySans-SemiBold.woff2")
const SMALL_FONT := preload("res://assets/fonts/Silkscreen-Regular.woff2")

var _t: float = 0.0
var _menu: VBoxContainer
var _slots: SaveSlotList
var _continue: Button
var _continue_slot: int = 0
var _fade: ColorRect
var _loading: bool = false
var _stars: PackedVector2Array = PackedVector2Array()
var _blip: AudioStreamPlayer
## Co-op: the Host / Join panel, and what the slot list was opened for
## ("" = single player, "host", "join").
var _coop: PanelContainer
var _coop_status: Label
var _ip_edit: LineEdit
var _slot_purpose: String = ""
var _join_slot: int = 0
const IP_FILE := "user://last_host.txt"
## The version ribbon by the logo (click: what's new) and the notes themselves.
const WHATS_NEW := preload("res://scripts/ui/whats_new.gd")
const RIBBON := Rect2(318, 58, 66, 26)
var _whats_new: PanelContainer


func _ready() -> void:
	add_to_group("title_screen")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.get_theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SaveGame.migrate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(70):
		_stars.append(Vector2(rng.randf(), rng.randf() * 0.4))
	_blip = AudioStreamPlayer.new()
	_blip.stream = load("res://assets/audio/select.wav")
	_blip.bus = "UI"
	_blip.volume_db = -8.0
	add_child(_blip)
	Net.leave()
	_build_menu()
	_build_coop()
	_slots = SaveSlotList.new()
	_slots.visible = false
	_slots.chosen.connect(_on_slot_chosen)
	_slots.cancelled.connect(_show_menu)
	add_child(_slots)
	_whats_new = WHATS_NEW.new()
	_whats_new.visible = false
	_whats_new.closed.connect(_show_menu)
	add_child(_whats_new)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.8)
	_show_menu()
	Net.accepted.connect(_on_join_accepted)
	Net.failed.connect(_on_net_failed)
	Net.status_changed.connect(func(t: String): _coop_status.text = t)
	var gm := get_node_or_null("/root/GameManager")
	if gm and str(gm.title_message) != "":
		_open_coop()
		_coop_status.text = str(gm.title_message)
		gm.title_message = ""
	elif WHATS_NEW.unseen():
		_open_whats_new()


func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 5)
	_menu.position = Vector2(44, 150)
	_menu.custom_minimum_size = Vector2(190, 0)
	add_child(_menu)
	_continue = _item("Continue", func(): _start(_continue_slot, false))
	_item("New Game", func(): _open_slots("new"))
	_item("Load Game", func(): _open_slots("load"))
	_item("Co-op", func(): _open_coop())
	_item("What's New", func(): _open_whats_new())
	_item("Options", func(): GameMenu.open("options"))
	_item("Quit", func(): get_tree().quit())


func _item(text: String, cb: Callable) -> Button:
	var b := UIStyle.button(text, 190)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		if _loading:
			return
		_blip.play()
		cb.call())
	_menu.add_child(b)
	return b


func _open_whats_new() -> void:
	_menu.visible = false
	_slots.visible = false
	_coop.visible = false
	_whats_new.show_notes()


func _show_menu() -> void:
	_slots.visible = false
	_coop.visible = false
	_whats_new.visible = false
	_slot_purpose = ""
	_menu.visible = true
	_continue_slot = SaveGame.latest_slot()
	_continue.disabled = _continue_slot == 0
	if _continue_slot > 0:
		var info := SaveGame.slot_info(_continue_slot)
		_continue.text = "Continue  (%s, Lv %d)" % [info["name"], info["level"]]
	else:
		_continue.text = "Continue"
	var any_save := _continue_slot > 0
	_menu.get_child(2).disabled = not any_save   # Load Game
	((_continue if any_save else _menu.get_child(1)) as Button).call_deferred("grab_focus")


func _open_slots(mode: String) -> void:
	_menu.visible = false
	_coop.visible = false
	_slots.visible = true
	_slots.open(mode)


func _on_slot_chosen(slot: int) -> void:
	match _slot_purpose:
		"host":
			_host(slot, _slots.mode == "new")
		"join":
			_join(slot, _slots.mode == "new")
		_:
			_start(slot, _slots.mode == "new")


## Fade out and load the world in that slot.
func _start(slot: int, fresh: bool) -> void:
	if _loading or slot <= 0:
		return
	_loading = true
	_menu.visible = false
	_slots.visible = false
	SaveGame.begin(slot, fresh, get_tree())
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.5)
	tw.tween_callback(func(): LoadingScreen.go(get_tree(), SaveGame.WORLD_SCENE))


func _unhandled_input(event: InputEvent) -> void:
	# the version ribbon opens what's new
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and _menu.visible and not _loading and RIBBON.has_point(event.position):
		_blip.play()
		_open_whats_new()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and _whats_new.visible and not _loading:
		_whats_new.visible = false
		WHATS_NEW.mark_seen()
		_show_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and (_slots.visible or _coop.visible) and not _loading:
		Net.leave()
		_show_menu()
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------------------
# Co-op: host your world, or join a friend's with one of your captains
# --------------------------------------------------------------------------
func _build_coop() -> void:
	_coop = PanelContainer.new()
	_coop.custom_minimum_size = Vector2(300, 0)
	_coop.set_anchors_preset(Control.PRESET_CENTER)
	_coop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_coop.grow_vertical = Control.GROW_DIRECTION_BOTH
	_coop.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER, 10, 2))
	_coop.visible = false
	add_child(_coop)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_coop.add_child(vb)
	vb.add_child(UIStyle.title("Co-op"))
	var hint := UIStyle.label("Sail together: up to 4 captains in the host's world.", 12, UIStyle.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	var host := UIStyle.button("Host a game (pick your save)", 260)
	host.pressed.connect(func():
		_blip.play()
		_slot_purpose = "host"
		_open_slots("load" if SaveGame.latest_slot() > 0 else "new")
		_slot_purpose = "host")
	vb.add_child(host)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	vb.add_child(row)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "Host address (IP)"
	_ip_edit.custom_minimum_size = Vector2(150, 0)
	_ip_edit.text = _last_ip()
	row.add_child(_ip_edit)
	var join := UIStyle.button("Join", 100)
	join.pressed.connect(func():
		_blip.play()
		if _ip_edit.text.strip_edges() == "":
			_coop_status.text = "Type the host's address first"
			return
		_slot_purpose = "join"
		_open_slots("load" if SaveGame.latest_slot() > 0 else "new")
		_slot_purpose = "join")
	row.add_child(join)
	_coop_status = UIStyle.label("Port %d (the host may need to forward it)" % Net.DEFAULT_PORT, 12, UIStyle.TEXT_DIM)
	_coop_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coop_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_coop_status.custom_minimum_size = Vector2(280, 0)
	vb.add_child(_coop_status)
	var back := UIStyle.button("Back", 120)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func():
		_blip.play()
		Net.leave()
		_show_menu())
	vb.add_child(back)


func _open_coop() -> void:
	_menu.visible = false
	_slots.visible = false
	_coop.visible = true
	UIStyle.fit_to_screen.call_deferred(_coop)


func _last_ip() -> String:
	if FileAccess.file_exists(IP_FILE):
		var f := FileAccess.open(IP_FILE, FileAccess.READ)
		if f:
			return f.get_as_text().strip_edges()
	return "127.0.0.1"


func _captain_info(slot: int) -> Dictionary:
	var info := SaveGame.slot_info(slot)
	SaveGame.slot = slot
	SaveGame.new_game = info.is_empty()
	var look := SaveGame.peek_look()
	return {"name": str(info.get("name", "Captain")), "look": look, "level": int(info.get("level", 1))}


func _host(slot: int, fresh: bool) -> void:
	Net.my_info = _captain_info(slot)
	if Net.host_game() != OK:
		_open_coop()
		_coop_status.text = Net.last_error
		return
	_start(slot, fresh)


func _join(slot: int, fresh: bool) -> void:
	var ip := _ip_edit.text.strip_edges()
	var f := FileAccess.open(IP_FILE, FileAccess.WRITE)
	if f:
		f.store_string(ip)
	_join_slot = slot
	Net.join_slot = slot
	Net.my_info = _captain_info(slot)
	SaveGame.new_game = fresh
	_open_coop()
	if Net.join_game(ip) != OK:
		_coop_status.text = Net.last_error


func _on_join_accepted() -> void:
	if _join_slot <= 0:
		return
	var fresh := SaveGame.slot_info(_join_slot).is_empty()
	_start(_join_slot, fresh)


func _on_net_failed(reason: String) -> void:
	if _loading:
		return
	_open_coop()
	_coop_status.text = reason


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


# --------------------------------------------------------------------------
# Backdrop: dusk sky, setting sun, layered swell, a ship and an island
# --------------------------------------------------------------------------
func _draw() -> void:
	var w := size.x
	var h := size.y
	var horizon := h * 0.62
	# sky
	var sky_top := Color(0.05, 0.06, 0.16)
	var sky_mid := Color(0.32, 0.17, 0.3)
	var sky_low := Color(0.95, 0.5, 0.25)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, horizon * 0.6), Vector2(0, horizon * 0.6)]),
		PackedColorArray([sky_top, sky_top, sky_mid, sky_mid]))
	draw_polygon(PackedVector2Array([Vector2(0, horizon * 0.6), Vector2(w, horizon * 0.6), Vector2(w, horizon), Vector2(0, horizon)]),
		PackedColorArray([sky_mid, sky_mid, sky_low, sky_low]))
	for st in _stars:
		var a := 0.35 + 0.3 * sin(_t * 1.7 + st.x * 50.0)
		draw_rect(Rect2(Vector2(st.x * w, st.y * h), Vector2(1, 1)), Color(1, 0.95, 0.85, a))
	# sun, sliced by dusk haze bands
	var sun := Vector2(w * 0.68, horizon - 10.0)
	draw_circle(sun, 34.0, Color(1.0, 0.72, 0.35))
	draw_circle(sun, 27.0, Color(1.0, 0.85, 0.55))
	for i in range(4):
		var y := sun.y + 2.0 + i * 6.0
		draw_rect(Rect2(sun.x - 40, y, 80, 1.0 + i * 0.6), sky_low.lerp(sky_mid, 0.15))
	# a far island, hazy
	var isl := PackedVector2Array([Vector2(w * 0.04, horizon), Vector2(w * 0.1, horizon - 14), Vector2(w * 0.16, horizon - 22),
		Vector2(w * 0.2, horizon - 18), Vector2(w * 0.26, horizon - 8), Vector2(w * 0.31, horizon)])
	draw_colored_polygon(isl, Color(0.22, 0.12, 0.2))
	# sea: bands getting darker toward the viewer, with moving crests
	var sea_far := Color(0.55, 0.3, 0.32)
	var sea_near := Color(0.04, 0.06, 0.14)
	draw_polygon(PackedVector2Array([Vector2(0, horizon), Vector2(w, horizon), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([sea_far, sea_far, sea_near, sea_near]))
	# sun glitter
	for i in range(18):
		var y := horizon + 3.0 + pow(float(i) / 18.0, 1.4) * (h - horizon - 6.0)
		var spread := 6.0 + float(i) * 3.0
		var x := sun.x + sin(_t * 2.0 + i * 1.3) * spread * 0.4
		var a := (1.0 - float(i) / 18.0) * (0.5 + 0.5 * sin(_t * 3.0 + i))
		draw_rect(Rect2(x - spread * 0.5, y, spread, 1.0), Color(1.0, 0.8, 0.5, a * 0.7))
	for row in range(9):
		var k := float(row) / 8.0
		var y := horizon + 6.0 + pow(k, 1.6) * (h - horizon - 4.0)
		var amp := 1.0 + k * 3.0
		var col := sea_far.lerp(sea_near, k).lightened(0.18)
		var step := 10.0 + k * 22.0
		var x := fposmod(_t * (6.0 + k * 14.0) + row * 37.0, step) - step
		while x < w:
			var y2 := y + sin(x * 0.05 + _t * 1.5 + row) * amp
			draw_line(Vector2(x, y2), Vector2(x + step * 0.45, y2 - amp * 0.5), Color(col.r, col.g, col.b, 0.55), 1.0)
			x += step
	_draw_ship(Vector2(w * 0.5, horizon + 18.0))
	# logo
	var logo := "DRIFTWAKE"
	var lp := Vector2(44, 98)
	draw_string_outline(LOGO_FONT, lp + Vector2(0, 3), logo, HORIZONTAL_ALIGNMENT_LEFT, -1, 48, 10, Color(0.08, 0.03, 0.02))
	draw_string(LOGO_FONT, lp + Vector2(0, 3), logo, HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(0.55, 0.25, 0.1))
	draw_string(LOGO_FONT, lp, logo, HORIZONTAL_ALIGNMENT_LEFT, -1, 48, UIStyle.ACCENT)
	draw_string_outline(SMALL_FONT, lp + Vector2(2, 18), "THE SEA REMEMBERS EVERY WAKE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0, 0, 0, 0.8))
	draw_string(SMALL_FONT, lp + Vector2(2, 18), "THE SEA REMEMBERS EVERY WAKE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.9, 0.75, 0.8))
	_draw_ribbon()
	if _loading:
		var a := clampf(_fade.color.a * 2.0, 0.0, 1.0)
		draw_string(SMALL_FONT, Vector2(w - 90, h - 12), "SETTING SAIL...", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.9, 0.7, a))


## The version on a red ribbon with forked tails, beside the logo, glinting now
## and then (and brighter under the mouse: it opens what's new).
func _draw_ribbon() -> void:
	var r := RIBBON
	var hot := r.has_point(get_local_mouse_position()) and _menu.visible
	var red := Color(0.62, 0.1, 0.08) if not hot else Color(0.78, 0.16, 0.1)
	var dark := red.darkened(0.45)
	var y0 := r.position.y
	var y1 := r.end.y
	var ym := (y0 + y1) * 0.5
	# the forked tails, a step back behind the band
	draw_colored_polygon(PackedVector2Array([Vector2(r.position.x - 9, y0 + 4), Vector2(r.position.x + 6, y0 + 4),
		Vector2(r.position.x + 6, y1 + 4), Vector2(r.position.x - 9, y1 + 4), Vector2(r.position.x - 4, ym + 4)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(r.end.x - 6, y0 + 4), Vector2(r.end.x + 9, y0 + 4),
		Vector2(r.end.x + 4, ym + 4), Vector2(r.end.x + 9, y1 + 4), Vector2(r.end.x - 6, y1 + 4)]), dark)
	draw_rect(r, red)
	draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, 1)), Color(1.0, 0.8, 0.45, 0.6))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 1)), Color(1.0, 0.8, 0.45, 0.6))
	# a glint sweeping across every few seconds (under the lettering)
	var g := fposmod(_t * 0.4, 1.6)
	if g < 1.0:
		var gx := r.position.x + 4.0 + g * (r.size.x - 8.0)
		draw_line(Vector2(gx + 3, y0 + 3), Vector2(gx - 3, y1 - 3), Color(1, 0.9, 0.7, 0.35), 3.0)
	var txt := "v%s" % WHATS_NEW.version()
	var tw := LOGO_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var tp := Vector2(r.position.x + (r.size.x - tw) * 0.5, y1 - 7)
	draw_string_outline(LOGO_FONT, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0.15, 0.02, 0.02))
	draw_string(LOGO_FONT, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIStyle.ACCENT)


## A brig in silhouette, pitching on the swell.
func _draw_ship(base: Vector2) -> void:
	var bob := sin(_t * 1.1) * 2.0
	var roll := sin(_t * 0.8 + 0.6) * 0.05
	var xf := Transform2D(roll, base + Vector2(0, bob))
	var col := Color(0.07, 0.04, 0.07)
	var sail := Color(0.2, 0.12, 0.16)
	var hull := PackedVector2Array([Vector2(-46, -8), Vector2(40, -8), Vector2(52, -16), Vector2(48, -6), Vector2(34, 6), Vector2(-38, 6), Vector2(-50, -12)])
	draw_colored_polygon(xf * hull, col)
	draw_line(xf * Vector2(-6, -8), xf * Vector2(-6, -70), col, 2.0)
	draw_line(xf * Vector2(20, -8), xf * Vector2(20, -56), col, 2.0)
	draw_line(xf * Vector2(52, -16), xf * Vector2(70, -26), col, 1.0)
	draw_colored_polygon(xf * PackedVector2Array([Vector2(-28, -64), Vector2(14, -64), Vector2(10, -40), Vector2(-24, -40)]), sail)
	draw_colored_polygon(xf * PackedVector2Array([Vector2(-24, -36), Vector2(12, -36), Vector2(8, -14), Vector2(-20, -14)]), sail)
	draw_colored_polygon(xf * PackedVector2Array([Vector2(8, -52), Vector2(32, -52), Vector2(30, -30), Vector2(10, -30)]), sail)
	draw_colored_polygon(xf * PackedVector2Array([Vector2(22, -54), Vector2(66, -26), Vector2(24, -22)]), sail.lightened(0.05))
	# flag
	var fl := xf * Vector2(-6, -70)
	draw_colored_polygon(PackedVector2Array([fl, fl + Vector2(-12, 2 + sin(_t * 6.0)), fl + Vector2(0, 6)]), Color(0.1, 0.03, 0.03))
	# reflection
	draw_rect(Rect2(base.x - 42, base.y + 8.0 + bob, 84, 1), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(base.x - 30, base.y + 12.0 + bob, 60, 1), Color(0, 0, 0, 0.18))
