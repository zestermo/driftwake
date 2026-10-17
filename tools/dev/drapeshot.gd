extends SceneTree
## Capes, the cloak and the belt lantern standing still on the light stage: each outfit (a cape at the default tatter,
## the cloak, a long coat, a torn cloak over a long coat, an untorn cape) settles 1.5 s, then is filmed from behind,
## back three-quarter, the right side (the lantern's) and front three-quarter at the PSX pixel grid (2x). The lantern
## is lit on the fourth outfit.
##   & $env:GODOT --path . --script res://tools/dev/drapeshot.gd -- res://tools/dev/out/drape before
## Writes <out_dir>/drape_<label>.png (outfits top to bottom, views left to right).
const TK := preload("res://tools/dev/test_kit.gd")
const CROP := Vector2i(130, 210)
const VIEWS := ["behind", "q3", "side", "front"]
const OUTFITS := [
	{"cape": true, "cape_color": Color(0.6, 0.12, 0.1)},
	{"cloak": true, "cloak_color": Color(0.24, 0.17, 0.12)},
	{"coat": "longcoat", "coat_color": Color(0.36, 0.12, 0.1), "trim_color": Color(0.85, 0.7, 0.3)},
	{"coat": "longcoat", "coat_color": Color(0.14, 0.18, 0.34), "trim_color": Color(0.85, 0.7, 0.3), "cloak": true, "cloak_color": Color(0.42, 0.42, 0.2), "cloak_tatter": 0.7},
	{"cape": true, "cape_color": Color(0.14, 0.18, 0.34), "cape_tatter": 0.0},
]

var stage
var p
var cam: Camera3D
var out_dir := "res://tools/dev/out/drape"
var label := "now"
var outfit := -1
var view := 0
var until := 0
var shots: Array = []
var grab := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		label = args[1]
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})
	RenderingServer.frame_post_draw.connect(_grab)


func _look(extra: Dictionary) -> Dictionary:
	var lk: Dictionary = CharacterLook.default_look()
	lk["coat"] = "none"
	lk["belt"] = "belt"
	lk.merge(extra, true)
	return lk


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	if cam == null:
		p = stage.player
		var rig := Node3D.new()
		var arm := Node3D.new()
		cam = Camera3D.new()
		cam.fov = 40.0
		cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		rig.add_child(arm)
		arm.add_child(cam)
		stage.add_child(rig)
		cam.current = true
		_next_outfit()
		return false
	if TK.ticking(until) or grab:
		return false
	if view >= VIEWS.size():
		_next_outfit()
		return false
	_place(VIEWS[view])
	until = TK.wait_ticks(2)
	grab = true
	return false


func _next_outfit() -> void:
	outfit += 1
	view = 0
	if outfit >= OUTFITS.size():
		_sheet()
		quit()
		return
	p.body_model.apply_look(_look(OUTFITS[outfit]))
	p.body_model.lantern.set_lit(outfit == 3)
	shots.append([])
	until = TK.wait_secs(1.5)


func _place(v: String) -> void:
	var at: Vector3 = p.global_position
	var f: Vector3 = -p.player_model.global_basis.z
	f.y = 0.0
	f = f.normalized()
	var yaw := {"behind": PI, "q3": PI - 0.8, "side": -PI * 0.5, "front": 0.7}[v] as float
	var dir := f.rotated(Vector3.UP, yaw)
	cam.look_at_from_position(at + dir * 5.0 + Vector3(0, 1.3, 0), at + Vector3(0, 0.9, 0), Vector3.UP)


func _grab() -> void:
	if not grab or TK.ticking(until):
		return
	grab = false
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var grid: Vector2 = root.get_node("PSX").pixel_res()
	img.resize(int(grid.x), int(grid.y), Image.INTERPOLATE_NEAREST)
	var at: Vector2 = cam.unproject_position(p.global_position + Vector3(0, 0.9, 0)) * (grid / root.get_visible_rect().size)
	var r := Rect2i(Vector2i(at) - CROP / 2, CROP)
	r.position = r.position.clamp(Vector2i.ZERO, Vector2i(grid) - CROP)
	(shots[outfit] as Array).append(img.get_region(r))
	view += 1


func _sheet() -> void:
	var sheet := Image.create(VIEWS.size() * (CROP.x + 2), OUTFITS.size() * (CROP.y + 2), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.08, 0.08, 0.08))
	for o in range(shots.size()):
		for i in range((shots[o] as Array).size()):
			sheet.blit_rect(shots[o][i], Rect2i(Vector2i.ZERO, CROP), Vector2i(i * (CROP.x + 2), o * (CROP.y + 2)))
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var path := ProjectSettings.globalize_path("%s/drape_%s.png" % [out_dir, label])
	sheet.save_png(path)
	print("SAVED ", path)
