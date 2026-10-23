extends SceneTree
## A rival crew's meeting, rendered (GPU, opens a window): the light stage, a crew turns up in front of the captain
## and a frame of each of its cutscene's shots is saved, then one of the duel (the rest ringing it).
## `& $env:GODOT --path . --script res://tools/dev/rivalshot.gd -- <out_prefix> [crew id]`
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var out := "res://tools/dev/out/rival"
var crew := "gilded_gulls"
var e
var shot := -1
var saved := 0
var t := 0.0
var step := 0
var until := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	if a.size() > 1:
		crew = a[1]
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func _save(tag: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := "%s_%02d_%s.png" % [out, saved, tag]
	img.save_png(ProjectSettings.globalize_path(path))
	print("RS saved ", path)
	saved += 1


func _process(d: float) -> bool:
	# (a windowed first launch opens the character creator: accept the default captain)
	var cc := load("res://scripts/ui/character_creator.gd")
	for n in root.find_children("*", "", true, false):
		if n.get_script() == cc and n.is_inside_tree():
			n._finish(true)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			# (a notorious captain: a bigger crew, more of them at the side; never beaten while posed for the frames)
			stage.player.bounty = 160000
			stage.player.health_component.max_health = 99999.0
			stage.player.health_component.current_health = 99999.0
			e = load("res://scripts/ai/rival_encounter.gd").start(stage.player, crew)
			step = 1
		1:
			var c = load("res://scripts/dialogue/cutscene.gd").active
			if c == null:
				until = TK.wait_secs(3.0)
				step = 2
				return false
			# a frame most of the way into each shot (its line typed out)
			if c._i != shot:
				shot = c._i
				t = 0.0
			t += d
			if t >= c._len * 0.8 and t - d < c._len * 0.8:
				_save("shot%d" % shot)
		2:
			_save("duel")
			# (the crew walks to its corner and settles: then wide frames of the duel and the crew at their work)
			until = TK.wait_secs(7.0)
			step = 3
		3:
			var rest: Array = e.rivals.filter(func(r): return is_instance_valid(r) and r.get_node("Brain").order == "rest")
			var corner := Vector3.ZERO
			for r in rest:
				corner += r.global_position / maxf(rest.size(), 1)
			var duel: Vector3 = stage.player.global_position
			var mid := duel.lerp(corner, 0.5)
			var across: Vector3 = (corner - duel).cross(Vector3.UP).normalized()
			var cam := Camera3D.new()
			cam.fov = 55.0
			stage.add_child(cam)
			cam.current = true
			cam.global_position = mid + across * 13.0 + Vector3.UP * 4.0
			cam.look_at(mid + Vector3.UP * 0.8, Vector3.UP)
			until = TK.wait_ticks(3)
			step = 4
		4:
			_save("crew_wide")
			var rest: Array = e.rivals.filter(func(r): return is_instance_valid(r) and r.get_node("Brain").order == "rest")
			var corner := Vector3.ZERO
			for r in rest:
				corner += r.global_position / maxf(rest.size(), 1)
			var cam: Camera3D = root.get_viewport().get_camera_3d()
			var back: Vector3 = (corner - stage.player.global_position).normalized()
			cam.global_position = corner - back * 5.5 + back.cross(Vector3.UP) * 2.0 + Vector3.UP * 1.6
			cam.look_at(corner + Vector3.UP * 0.7, Vector3.UP)
			until = TK.wait_ticks(3)
			step = 5
		5:
			_save("crew_close")
			print("RS done")
			quit()
	return false
