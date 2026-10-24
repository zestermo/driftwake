extends SceneTree
## The fog isles' dead side by side for a look (docs/v1_20_plan.md "ghosts' and the drowned's looks shown on a sheet
## first"): a living crewman for scale, two drowned, two ghosts and the Drowned Captain's body (his look, glowing as
## the boss does), in a row on the light stage, standing still (their brains off). Out: <dir>/undead.png and
## <dir>/undead_close.png.
## `& $env:GODOT --path . --script res://tools/dev/undeadshot.gd -- res://tools/dev/out/undead`
const TK := preload("res://tools/dev/test_kit.gd")
const W := 1280
const H := 720

var stage
var out := "res://tools/dev/out/undead"
var cam: Camera3D
var step := 0
var t := 0.0
var row: Array = []


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})
	DisplayServer.window_set_size(Vector2i(W, H))


func _grunt(path: String, s: int, at: Vector3) -> Node3D:
	var g = load(path).new().setup({"post": at, "seed": s, "role": "sword"})
	g.level = 6
	stage.add_child(g)
	g.global_position = at
	g.process_mode = Node.PROCESS_MODE_DISABLED
	return g


func _process(d: float) -> bool:
	# (a windowed first launch opens the character creator: accept the default captain)
	var cc := load("res://scripts/ui/character_creator.gd")
	for n in root.find_children("*", "", true, false):
		if n.get_script() == cc and n.is_inside_tree():
			n._finish(true)
	if not stage.up:
		return false
	var base: Vector3 = stage.player.global_position + Vector3(0, 0, -8)
	match step:
		0:
			stage.player.visible = false
			row.append(_grunt("res://scripts/enemies/pirate_grunt.gd", 3, base + Vector3(-6, 0, 0)))
			row.append(_grunt("res://scripts/enemies/drowned.gd", 11, base + Vector3(-3.6, 0, 0)))
			row.append(_grunt("res://scripts/enemies/drowned.gd", 14, base + Vector3(-1.2, 0, 0)))
			row.append(_grunt("res://scripts/enemies/ghost.gd", 21, base + Vector3(1.2, 0, 0)))
			row.append(_grunt("res://scripts/enemies/ghost.gd", 24, base + Vector3(3.6, 0, 0)))
			var GC = load("res://scripts/enemies/ghost_captain.gd")
			var hm = load("res://scripts/npc/humanoid.gd").new()
			hm.setup(GC.captain_look(0))
			stage.add_child(hm)
			hm.global_position = base + Vector3(6.2, 0, 0)
			row.append(hm)
			for n in row:
				(n as Node3D).rotation.y = 0.0
			cam = Camera3D.new()
			stage.add_child(cam)
			cam.fov = 40.0
			cam.global_position = base + Vector3(0, 2.0, 15.0)
			cam.look_at(base + Vector3(0, 1.0, 0))
			cam.current = true
			step = 1
		1:
			t += d
			# (the ghosts' fade: keep them shown for the shot)
			for n in row:
				var hm = n.get("humanoid")
				if hm:
					hm.visible = true
			if t > 1.5:
				root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/undead.png"))
				cam.fov = 30.0
				cam.global_position = base + Vector3(2.4, 1.7, 7.0)
				cam.look_at(base + Vector3(2.4, 1.1, 0))
				t = 0.0
				step = 2
		2:
			t += d
			for n in row:
				var hm = n.get("humanoid")
				if hm:
					hm.visible = true
			if t > 0.6:
				root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(out + "/undead_close.png"))
				print("UNDEADSHOT done")
				quit()
	return false
