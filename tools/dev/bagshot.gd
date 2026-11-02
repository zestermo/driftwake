extends SceneTree
## The gadget bag (1.28.1) on the captain, on the light stage: each of the four colours clasped, seen from the left
## (the bag at the hip) and from the front (the strap across the chest), then the flap thrown open, and the captain
## running with it swinging. Args: <out_prefix>; writes _<colour>, _<colour>_front, _open, _run.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var cam: Camera3D
var t := 0.0
var step := 0
var ci := 0
var out := ""
const COLS := ["mustard", "olive", "oxblood", "navy"]


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(out + name + ".png")


func _aim(from: Vector3, at: Vector3) -> void:
	var b: Basis = p.player_model.global_basis
	cam.global_position = p.global_position + b * from
	cam.look_at(p.global_position + b * at)


func _process(d: float) -> bool:
	var cc := load("res://scripts/ui/character_creator.gd")
	for n in root.find_children("*", "", true, false):
		if n.get_script() == cc and n.is_inside_tree():
			n._finish(true)
	if not stage.up:
		return false
	t += d
	var inv = p.inventory_component if p else null
	match step:
		0:
			out = OS.get_cmdline_user_args()[0]
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
			p = stage.player
			cam = Camera3D.new()
			cam.fov = 40.0
			stage.add_child(cam)
			cam.current = true
			var env: Environment = stage.get_node("WorldEnvironment").environment
			env.background_color = Color(0.55, 0.72, 0.88)
			p.gadgets.give("smoke", 1)
			step = 1
			t = 0.0
		1:
			for c in COLS:
				inv.remove_item(ItemDB.get_item("gadget_bag_" + c), inv.count("gadget_bag_" + c))
			inv.add_item(ItemDB.get_item("gadget_bag_" + COLS[ci]), 1)
			step = 2
			t = 0.0
		2:
			if t > 0.8:
				_aim(Vector3(-2.4, 1.3, -0.6), Vector3(-0.2, 0.95, 0.0))
				step = 3
				t = 0.0
		3:
			if t > 0.15:
				_shot("_" + COLS[ci])
				_aim(Vector3(-0.9, 1.4, -2.6), Vector3(0.0, 1.05, 0.0))
				step = 4
				t = 0.0
		4:
			if t > 0.15:
				_shot("_%s_front" % COLS[ci])
				ci += 1
				step = 1 if ci < COLS.size() else 5
				t = 0.0
		5:
			inv.remove_item(ItemDB.get_item("gadget_bag_navy"), 1)
			inv.add_item(ItemDB.get_item("gadget_bag_mustard"), 1)
			p.gadgets.wheel_open = true
			p.gadgets._bag_look()
			step = 6
			t = 0.0
		6:
			if t > 0.8:
				_aim(Vector3(-1.9, 1.5, -1.2), Vector3(-0.25, 0.9, 0.0))
				step = 7
				t = 0.0
		7:
			if t > 0.15:
				_shot("_open")
				p.gadgets.wheel_open = false
				p.gadgets._bag_look()
				# (the run follows the stage's own camera: the captain runs across it, left, the bag side toward it)
				cam.current = false
				stage.camera_rig.rotation.y = PI
				TK.press("move_right")
				step = 8
				t = 0.0
		8:
			if t > 1.0:
				step = 9
				t = 0.0
		9:
			if t > 0.03:
				_shot("_run")
				TK.release("move_right")
				print("SAVED")
				quit()
	return false
