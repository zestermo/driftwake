extends SceneTree
## Fishing on the light stage, at the water's edge: the cast (loaded back, the snap, the follow-through), the wait
## with the bobber on the waves, the bite, the reel, the landing (the lift, the catch held up), then carried on
## the back; from the front-left quarter, the left side and from behind and above (the game camera's side); and
## the rods' icons. Args: <out_prefix>. Env FS_TIER=bamboo (default driftwood); FS_VIEWS=quarter,behind (default
## quarter,side,behind).
const TK := preload("res://tools/dev/test_kit.gd")
var out := ""
var stage
var p
var cam: Camera3D
var tier := "driftwood"
var views: Array = ["quarter", "side", "behind"]
## [label, seconds after the shot before, what to do first]
var shots: Array = [["cast_back", 0.36, "cast"], ["cast_snap", 0.24, ""], ["cast_follow", 0.2, ""], ["wait", 2.2, ""],
	["bite", 0.25, "bite"], ["reel", 0.6, "reel"], ["land_lift", 0.75, ""], ["land_hold", 0.85, ""], ["carried", 1.2, ""]]
var si := 0
var vi := 0
var step := 0
var until := 0


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	if OS.get_environment("FS_TIER") != "":
		tier = OS.get_environment("FS_TIER")
	if OS.get_environment("FS_VIEWS") != "":
		views = Array(OS.get_environment("FS_VIEWS").split(","))
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "water": true})
	var sheet := Image.create(24 * 8 * Rods.TIERS.size(), 24 * 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.16, 0.12, 0.1))
	for i in range(Rods.TIERS.size()):
		var img: Image = Rods.icon(Rods.TIERS[i]).get_image()
		img.resize(24 * 8, 24 * 8, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(0, 0, 24 * 8, 24 * 8), Vector2i(i * 24 * 8, 0))
	sheet.save_png("%s_icons.png" % out)


func _state():
	return p.state_machine.get_node("Fish")


func _process(_d: float) -> bool:
	# (a windowed run opens the character creator over the stage)
	for n in root.find_children("*", "CharacterCreator", true, false):
		n._finish(true)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			p = stage.player
			cam = Camera3D.new()
			cam.fov = 40
			root.add_child(cam)
			cam.current = true
			var it = ItemDB.get_item(Rods.item_id(tier))
			p.inventory_component.add_item(it, 1)
			p.equip_gear_from_bag(p.inventory_component.find_index(it.id))
			# (the light stage's sea has no surface drawn: a flat one at sea level to see the float on)
			var sea := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(240, 240)
			sea.mesh = pm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.12, 0.3, 0.4)
			sea.material_override = mat
			stage.add_child(sea)
			sea.global_position = Vector3(stage.SHORE_X + 120.5, -0.05, 0.0)
			p.global_position = Vector3(stage.SHORE_X - 1.2, stage.GROUND_Y + 0.1, 0.0)
			p.player_model.rotation.y = -PI * 0.5
			p.reset_physics_interpolation()
			until = TK.wait_secs(0.8)
			step = 1
		1:
			# each run through the shots is one view, so every view sees the same moments
			var sh: Array = shots[si]
			match str(sh[2]):
				"cast":
					p.fish()
				"bite":
					_state()._bite_at = _state()._t
				"reel":
					TK.press("interact")
			_view(views[vi])
			until = TK.wait_secs(float(sh[1]))
			step = 2
		2:
			TK.release("interact")
			root.get_texture().get_image().save_png("%s_%s_%s.png" % [out, shots[si][0], views[vi]])
			si += 1
			if si >= shots.size():
				si = 0
				vi += 1
				if vi >= views.size():
					quit()
					return false
				p.state_machine.force_state("Idle", {})
				until = TK.wait_secs(0.6)
			step = 1
	return false


func _view(v: String) -> void:
	var b: Basis = p.player_model.global_basis
	var face := -b.z
	var right := b.x
	var at: Vector3 = p.global_position + Vector3(0, 1.2, 0)
	match v:
		"quarter":
			cam.global_position = at + (face * 0.9 - right).normalized() * 3.4 + Vector3(0, 0.3, 0)
			at += face * 0.5 + Vector3(0, 0.3, 0)
		"side":
			cam.global_position = at - right * 5.5 + Vector3(0, 0.6, 0)
			at += face * 1.2 + Vector3(0, 0.6, 0)
		"behind":
			cam.global_position = at - face * 4.5 + right * 0.8 + Vector3(0, 2.0, 0)
			at += face * 3.0
	cam.look_at(at, Vector3.UP)
	cam.reset_physics_interpolation()
