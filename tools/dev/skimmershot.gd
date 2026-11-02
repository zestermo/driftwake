extends SceneTree
## The skimmer (1.28.1) ridden on the light stage's sea, each tier in turn: launched from swimming, steered across
## the wind for a while, then shot from the side and from ahead. Args: <out_prefix>; writes _mk1.._mk3 (side) and
## _mk1f.._mk3f (front three-quarter).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var cam: Camera3D
var t := 0.0
var step := 0
var tier := 0
var out := ""


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "water": true, "weather": true})


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out + name + ".png")


func _process(d: float) -> bool:
	var cc := load("res://scripts/ui/character_creator.gd")
	for n in root.find_children("*", "", true, false):
		if n.get_script() == cc and n.is_inside_tree():
			n._finish(true)
	if not stage.up:
		return false
	t += d
	match step:
		0:
			out = OS.get_cmdline_user_args()[0]
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
			p = stage.player
			cam = Camera3D.new()
			cam.fov = 50.0
			stage.add_child(cam)
			stage.add_child((load("res://scenes/ocean/ocean.tscn") as PackedScene).instantiate())
			var env: Environment = stage.get_node("WorldEnvironment").environment
			env.background_color = Color(0.55, 0.72, 0.88)
			step = 1
			t = 0.0
		1:
			p.gadgets.give("skimmer", tier)
			p.gadgets.ready_at.clear()
			p.global_position = Vector3(stage.SHORE_X + 20.0, 0.0, -20.0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			step = 2
			t = 0.0
		2:
			if t > 0.6:
				p.player_model.rotation.y = 0.0
				p.gadgets.fire()
				stage.camera_rig.rotation.y = -PI * 0.35
				TK.press("move_forward")
				step = 3
				t = 0.0
		3:
			if t > 2.2:
				TK.release("move_forward")
				var st = p.get_node("StateMachine/Skimmer")
				var fwd := Vector3(-sin(st.heading), 0, -cos(st.heading))
				var side := fwd.cross(Vector3.UP)
				cam.current = true
				cam.global_position = p.global_position + side * 6.5 + Vector3.UP * 2.2 + fwd * 1.0
				cam.look_at(p.global_position + Vector3.UP * 1.3 + fwd * 0.5)
				step = 4
				t = 0.0
		4:
			if t > 0.25:
				_shot("_mk%d" % (tier + 1))
				var st = p.get_node("StateMachine/Skimmer")
				var fwd := Vector3(-sin(st.heading), 0, -cos(st.heading))
				var side := fwd.cross(Vector3.UP)
				cam.global_position = p.global_position + fwd * 6.0 - side * 3.5 + Vector3.UP * 2.0
				cam.look_at(p.global_position + Vector3.UP * 1.3)
				step = 5
				t = 0.0
		5:
			if t > 0.25:
				_shot("_mk%df" % (tier + 1))
				var back: Vector3 = p.player_model.global_basis.z
				cam.global_position = p.global_position + back * 4.5 + Vector3.UP * 3.2
				cam.look_at(p.global_position + Vector3.UP * 1.0 - back * 0.8)
				step = 7
				t = 0.0
		7:
			if t > 0.25:
				_shot("_mk%db" % (tier + 1))
				cam.current = false
				TK.act("interact")
				tier += 1
				step = 1 if tier < 3 else 6
				t = 0.0
		6:
			print("SAVED")
			quit()
	return false
