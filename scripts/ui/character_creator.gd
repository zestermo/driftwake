class_name CharacterCreator
extends CanvasLayer
## Character creator: tabs of options (Body, Face, Hair, Outfit, Extras) with a
## live, rotatable 3D preview. Opens on first launch before play, and from the
## pause menu ("Appearance"). Pauses the game while open.
##
##   CharacterCreator.open_for(tree, look, first_time, func(look): ...)

signal finished(look: Dictionary, accepted: bool)

static var active: bool = false

const TABS := ["Body", "Face", "Hair", "Outfit", "Extras"]
const ROW_FONT := 12

var look: Dictionary = {}
var first_time := false
var _original: Dictionary = {}
var _tab := "Body"
var _list: VBoxContainer
var _tab_buttons: Dictionary = {}
var _name_edit: LineEdit
var _preview: Humanoid
var _cam: Camera3D
var _yaw := 0.0
var _zoom := 0.0  # 0 = full body, 1 = head
var _dragging := false
var _blip: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


static func open_for(tree: SceneTree, start_look: Dictionary, is_first: bool, on_done: Callable) -> CharacterCreator:
	var cc := CharacterCreator.new()
	cc.look = CharacterLook.normalize(start_look)
	cc.first_time = is_first
	cc.finished.connect(func(lk: Dictionary, ok: bool): on_done.call(lk, ok))
	tree.root.add_child(cc)
	return cc


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	active = true
	_original = look.duplicate(true)
	_rng.randomize()
	_set_paused(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_blip = AudioStreamPlayer.new()
	_blip.stream = load("res://assets/audio/select.wav")
	_blip.bus = "UI"
	_blip.volume_db = -10.0
	add_child(_blip)
	_build_ui()
	_show_tab("Body")


func _exit_tree() -> void:
	active = false


func _play() -> void:
	_blip.play()


# --------------------------------------------------------------------------
# layout
# --------------------------------------------------------------------------
func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.get_theme()
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.07, 1.0 if first_time else 0.86)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	root.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	margin.add_child(outer)
	var title := UIStyle.title("Create Your Captain" if first_time else "Appearance")
	title.add_theme_font_size_override("font_size", 24)
	outer.add_child(title)

	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 8)
	outer.add_child(hb)

	# ---- preview
	var pv_panel := PanelContainer.new()
	pv_panel.custom_minimum_size = Vector2(250, 0)
	pv_panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.12, 0.16, 0.22, 1.0), UIStyle.BORDER_DIM, 0, 2))
	hb.add_child(pv_panel)
	var pv_box := VBoxContainer.new()
	pv_panel.add_child(pv_box)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.gui_input.connect(_on_preview_input)
	pv_box.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = false
	sv.process_mode = Node.PROCESS_MODE_ALWAYS
	svc.add_child(sv)
	_build_stage(sv)
	var rot := HBoxContainer.new()
	rot.alignment = BoxContainer.ALIGNMENT_CENTER
	pv_box.add_child(rot)
	for spec in [["<", -0.6], ["Drag to turn", 0.0], [">", 0.6]]:
		if spec[1] == 0.0:
			var l := UIStyle.label(spec[0], 10, UIStyle.TEXT_DIM)
			rot.add_child(l)
			continue
		var b := UIStyle.button(spec[0], 22)
		b.add_theme_font_size_override("font_size", ROW_FONT)
		var amt: float = spec[1]
		b.pressed.connect(func(): _yaw += amt)
		rot.add_child(b)

	# ---- options
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	hb.add_child(right)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	right.add_child(tabs)
	for t in TABS:
		# after the first creation, clothes are gear (changed in the inventory)
		if not first_time and t in ["Outfit", "Extras"]:
			continue
		var b := UIStyle.button(t)
		b.add_theme_font_size_override("font_size", ROW_FONT + 1)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.pressed.connect(func(): _play(); _show_tab(t))
		tabs.add_child(b)
		_tab_buttons[t] = b
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER_DIM, 6, 1))
	right.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_list)

	# ---- bottom bar
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	outer.add_child(bar)
	bar.add_child(_small_label("Name"))
	_name_edit = LineEdit.new()
	_name_edit.text = str(look.get("name", "Captain"))
	_name_edit.max_length = 18
	_name_edit.custom_minimum_size = Vector2(130, 0)
	_name_edit.add_theme_font_size_override("font_size", ROW_FONT + 1)
	_name_edit.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.BG_LIGHT, UIStyle.BORDER_DIM, 4, 1))
	_name_edit.add_theme_stylebox_override("focus", UIStyle.box(UIStyle.BG_LIGHT, UIStyle.ACCENT, 4, 1))
	_name_edit.text_changed.connect(func(t: String): look["name"] = t.strip_edges() if t.strip_edges() != "" else "Captain")
	bar.add_child(_name_edit)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var rnd := UIStyle.button("Randomize", 90)
	rnd.add_theme_font_size_override("font_size", ROW_FONT + 1)
	rnd.pressed.connect(_randomize)
	bar.add_child(rnd)
	if not first_time:
		var cancel := UIStyle.button("Cancel", 70)
		cancel.add_theme_font_size_override("font_size", ROW_FONT + 1)
		cancel.pressed.connect(func(): _finish(false))
		bar.add_child(cancel)
	var done := UIStyle.button("Set Sail" if first_time else "Done", 90)
	done.add_theme_font_size_override("font_size", ROW_FONT + 1)
	done.pressed.connect(func(): _finish(true))
	bar.add_child(done)


func _build_stage(sv: SubViewport) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.13, 0.17, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.64, 0.72)
	e.ambient_light_energy = 0.8
	env.environment = e
	sv.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-35), deg_to_rad(-30), 0)
	sun.light_energy = 1.05
	sv.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var mb := MeshBuilder.new()
	mb.add_cylinder(PSXMat.lit("planks_dark", Color(0.9, 0.9, 0.9)), Transform3D(Basis(), Vector3(0, -0.06, 0)), 0.75, 0.75, 0.06, 10, 2.0)
	floor_mi.mesh = mb.commit()
	sv.add_child(floor_mi)
	_preview = Humanoid.new()
	_preview.process_mode = Node.PROCESS_MODE_ALWAYS
	_preview.setup(look)
	sv.add_child(_preview)
	_preview.set_weapon(Props.weapon_mesh("cutlass"))
	_cam = Camera3D.new()
	_cam.fov = 32.0
	sv.add_child(_cam)
	_cam.current = true
	_update_camera(1.0)


func _process(delta: float) -> void:
	if _preview:
		_preview.rotation.y = lerp_angle(_preview.rotation.y, PI + _yaw, minf(10.0 * delta, 1.0))
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	if _cam == null:
		return
	var want := 1.0 if _tab in ["Face", "Hair"] else 0.0
	_zoom = move_toward(_zoom, want, delta * 3.0)
	var z := _zoom * _zoom * (3.0 - 2.0 * _zoom)
	# frame from the character's actual size (art styles change proportions)
	var head_y := 1.7
	var head_s := 0.75
	var s := 1.0
	if _preview and _preview.head:
		head_s = _preview.head.global_basis.get_scale().y
		head_y = _preview.head.global_position.y + 0.16 * head_s
		s = maxf(_preview.scale.y, 0.01)
	# the full-body view is framed for the tallest height, not this body's, so the
	# Height option shows (framed to the body, every height looked the same);
	# the face/hair close-up still follows the actual head
	var tall: float = CharacterLook.HEIGHTS.max()
	var top := (head_y + 0.25 * head_s) / s * tall
	var target := Vector3(0, lerpf(top * 0.52, head_y, z), 0)
	var dist := lerpf(top * 2.35, 0.9 + head_s * 1.1, z)
	_cam.look_at_from_position(target + Vector3(0, lerpf(0.35, 0.05, z), dist), target)


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_yaw += event.relative.x * 0.02


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not first_time:
		_finish(false)
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------------------
# tabs and rows
# --------------------------------------------------------------------------
func _show_tab(t: String) -> void:
	_tab = t
	for k in _tab_buttons.keys():
		(_tab_buttons[k] as Button).button_pressed = (k == t)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	match t:
		"Body":
			_cycle("Frame", "body", CharacterLook.BODIES, ["Masculine", "Feminine"])
			_cycle("Build", "build", CharacterLook.BUILDS)
			_cycle("Height", "height", CharacterLook.HEIGHTS, ["Short", "Below average", "Average", "Tall", "Very tall"])
			_colors("Skin", "skin")
			_cycle("Head", "head", CharacterLook.HEADS)
		"Face":
			_cycle("Eyes", "eyes", range(CharacterLook.EYE_STYLES), ["Plain", "Narrow", "Wide", "Hooded", "Sharp", "Round"])
			_colors("Eye color", "eye_color")
			_cycle("Brows", "brows", range(CharacterLook.BROW_STYLES), ["Natural", "Thick", "Arched", "Stern", "Worried"])
			_cycle("Nose", "nose", CharacterLook.NOSES)
			_cycle("Mouth", "mouth", range(CharacterLook.MOUTH_STYLES), ["Neutral", "Smile", "Grin", "Frown", "Smirk", "Open"])
			_cycle("Marks", "marks", CharacterLook.MARKS)
			_cycle("Facial hair", "facial_hair", CharacterLook.FACIAL_HAIR)
		"Hair":
			_cycle("Hair", "hair", CharacterLook.HAIR)
			_colors("Hair color", "hair_color")
			if first_time:
				_cycle("Hat", "hat", CharacterLook.CREATOR_HATS)
				_colors("Hat color", "hat_color")
		"Outfit":
			_cycle("Top", "top", CharacterLook.TOPS)
			_cycle("Sleeves", "sleeves", CharacterLook.SLEEVES)
			_colors("Top color", "top_color")
			_cycle("Vest", "vest", CharacterLook.CREATOR_VESTS)
			_colors("Vest color", "vest_color")
			_cycle("Coat", "coat", CharacterLook.CREATOR_COATS, ["None", "Jacket"])
			_colors("Coat color", "coat_color")
			_colors("Trim", "trim_color")
			_cycle("Legs", "legs", CharacterLook.LEGS)
			_colors("Legs color", "legs_color")
			_cycle("Feet", "feet", CharacterLook.CREATOR_FEET)
			_colors("Feet color", "feet_color")
			_cycle("Belt", "belt", CharacterLook.BELTS, ["None", "Belt", "Sash", "Belt + sash"])
			_colors("Belt color", "belt_color")
			_colors("Sash color", "sash_color")
		"Extras":
			_toggle("Gloves", "gloves")
			_colors("Glove color", "gloves_color")
			_toggle("Scarf", "scarf")
			_colors("Scarf color", "scarf_color")
			_toggle("Earring", "earring")
			_toggle("Eyepatch", "eyepatch")
			_toggle("Belt pouch", "pouch")
			_toggle("Apron", "apron")
			_colors("Apron color", "apron_color")


func _small_label(text: String, w: float = 0.0) -> Label:
	var l := UIStyle.label(text, ROW_FONT, UIStyle.TEXT_DIM)
	l.custom_minimum_size = Vector2(w, 0)
	return l


static func pretty(v: Variant) -> String:
	var s := str(v).replace("_", " ")
	return s.substr(0, 1).to_upper() + s.substr(1)


func _row(text: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	r.add_child(_small_label(text, 78))
	_list.add_child(r)
	return r


func _cycle(text: String, key: String, values: Array, names: Array = []) -> void:
	var r := _row(text)
	var left := UIStyle.button("<", 20)
	var right := UIStyle.button(">", 20)
	var val := UIStyle.label("", ROW_FONT, UIStyle.TEXT)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.custom_minimum_size = Vector2(118, 0)
	for b in [left, right]:
		(b as Button).add_theme_font_size_override("font_size", ROW_FONT)
	var refresh := func():
		var i := values.find(look.get(key))
		if i < 0:
			i = 0
		val.text = names[i] if i < names.size() else pretty(values[i])
	var step := func(d: int):
		var i := values.find(look.get(key))
		i = (maxi(i, 0) + d + values.size()) % values.size()
		look[key] = values[i]
		refresh.call()
		_play()
		_rebuild()
	left.pressed.connect(func(): step.call(-1))
	right.pressed.connect(func(): step.call(1))
	r.add_child(left)
	r.add_child(val)
	r.add_child(right)
	refresh.call()


func _toggle(text: String, key: String) -> void:
	var r := _row(text)
	var b := UIStyle.button("", 60)
	b.add_theme_font_size_override("font_size", ROW_FONT)
	var refresh := func(): b.text = "On" if look.get(key, false) else "Off"
	b.pressed.connect(func():
		look[key] = not look.get(key, false)
		refresh.call()
		_play()
		_rebuild())
	r.add_child(b)
	refresh.call()


func _colors(text: String, key: String) -> void:
	var r := _row(text)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 2)
	r.add_child(flow)
	var swatches: Array = []
	var pal := CharacterLook.palette(key)
	var refresh := func():
		var cur: Color = look.get(key, Color.WHITE)
		for i in range(swatches.size()):
			var c: Color = pal[i]
			var sel := c.is_equal_approx(cur)
			var sb := UIStyle.box(c, UIStyle.ACCENT if sel else Color(0, 0, 0, 0.6), 0, 2 if sel else 1)
			for st in ["normal", "hover", "pressed", "focus"]:
				(swatches[i] as Button).add_theme_stylebox_override(st, sb if st != "hover" else UIStyle.box(c, UIStyle.TEXT, 0, 2))
	for i in range(pal.size()):
		var b := Button.new()
		b.custom_minimum_size = Vector2(13, 13)
		b.focus_mode = Control.FOCUS_NONE
		var c: Color = pal[i]
		b.pressed.connect(func():
			look[key] = c
			refresh.call()
			_play()
			_rebuild())
		flow.add_child(b)
		swatches.append(b)
	refresh.call()


# --------------------------------------------------------------------------
# actions
# --------------------------------------------------------------------------
func _rebuild() -> void:
	if _preview:
		_preview.apply_look(look)


func _randomize() -> void:
	_play()
	var nm := str(look.get("name", "Captain"))
	var rnd := CharacterLook.random_look(_rng)
	if first_time:
		look = rnd
	else:
		# keep the worn gear; randomize body, face and hair only
		for k in rnd.keys():
			if not Gear.is_outfit_key(k):
				look[k] = rnd[k]
	look["name"] = nm
	_rebuild()
	_show_tab(_tab)


func _finish(accepted: bool) -> void:
	_play()
	var result := look if accepted else _original
	_set_paused(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	active = false
	finished.emit(result.duplicate(true), accepted)
	queue_free()


## (co-op: the world keeps running while you're in the creator)
func _set_paused(on: bool) -> void:
	var net := get_node_or_null("/root/Net")
	if net:
		net.set_paused(on)
	else:
		get_tree().paused = on
