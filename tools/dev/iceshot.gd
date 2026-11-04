extends SceneTree
## (1.30) The snow's frozen river and lake with a captain stood on them, for before/after: a snow island (chain 4242's
## first, made snow) on the light stage; the captain is dropped on the river a third of the way down and on a lake
## near its shore, and each is shot from the bank at eye height and from above. Prints where the captain came to rest
## against the ice's level ("CAPTAIN ... feet y, ice y"). Opens a window.
## Args: <out_prefix>   e.g. & $env:GODOT --path . --script res://tools/dev/iceshot.gd -- res://tools/dev/out/review/collision_ice
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var gi
var out := ""
var step := 0
var until := 0
var cam: Camera3D
var spots: Array = []
var k := 0


func _initialize() -> void:
	TK.seed_of(self)
	out = OS.get_cmdline_user_args()[0]
	stage = TK.stage(self, {"hud": false})


func _process(_d: float) -> bool:
	# (a windowed first launch opens the character creator: accept the default captain)
	var cc := load("res://scripts/ui/character_creator.gd")
	for n in root.find_children("*", "", true, false):
		if n.get_script() == cc and n.is_inside_tree():
			n._finish(true)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			load("res://scripts/island/island_theme.gd").meshes("snow")
			var c = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242).c
			var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
			n.merge({"theme": "snow", "beast": "snow_leopard", "beast_look": 0, "minis": ["frost_alpha"], "roamer": "rimeback"}, true)
			gi = load("res://scripts/island/gen_island.gd").new()
			gi.position = Vector3(0, 0, -3000)
			stage.add_child(gi)
			gi.build(n)
			var lp: Dictionary = gi.land_plan
			var pts: PackedVector2Array = lp["river"]
			# (the first stretch down from the peak where the river runs in its bed, banks both sides)
			var hw := float(lp["river_w"]) * 0.5
			for j in range(1, pts.size() - 1):
				var along: Vector2 = (pts[j + 1] - pts[j]).normalized()
				var p: Vector2 = pts[j].lerp(pts[j + 1], 0.5)
				var g: float = gi.hv(p)
				if g > 3.0 and gi.hv(p + along.orthogonal() * (hw + 6.0)) > g + 1.0 and gi.hv(p - along.orthogonal() * (hw + 6.0)) > g + 1.0:
					spots.append(["river", p, along.orthogonal() * (hw + 7.0)])
					break
			if not (lp["lakes"] as Array).is_empty():
				var lk: Dictionary = lp["lakes"][0]
				var out_dir := Vector2(1, 0)
				spots.append(["lake", (lk["c"] as Vector2) + out_dir * (float(lk["r"]) - 2.5), out_dir * 8.0])
			cam = Camera3D.new()
			cam.fov = 60
			cam.far = 1500
			root.add_child(cam)
			until = TK.wait_ticks(10)
		1:
			var s: Array = spots[k]
			var p: Vector2 = s[1]
			var pl = stage.player
			pl.global_position = gi.to_global(Vector3(p.x, float(gi.hv(p)) + 2.0, p.y))
			pl.velocity = Vector3.ZERO
			pl.reset_physics_interpolation()
			until = TK.wait_ticks(90)
		2:
			var s: Array = spots[k]
			var pl = stage.player
			var feet: Vector3 = gi.to_local(pl.global_position)
			var p: Vector2 = s[1]
			print("CAPTAIN on the %s: feet y %.2f, ground (bed) %.2f" % [s[0], feet.y, gi.hv(p)])
			var side: Vector2 = s[2]
			var eye: Vector3 = gi.to_global(Vector3(p.x + side.x, float(gi.hv(p + side)) + 1.7, p.y + side.y))
			cam.global_position = eye
			cam.look_at(pl.global_position + Vector3.UP * 0.6)
			cam.make_current()
			until = TK.wait_ticks(20)
		3:
			_shot("%s_%s_bank.png" % [out, spots[k][0]])
			var pl = stage.player
			cam.global_position = pl.global_position + Vector3(-9, 14, 9)
			cam.look_at(pl.global_position)
			until = TK.wait_ticks(20)
		4:
			_shot("%s_%s_above.png" % [out, spots[k][0]])
			k += 1
			if k < spots.size():
				step = 1
				return false
			quit(0)
			return true
	step += 1
	return false


func _shot(path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path)
	print("SHOT %s" % path)
