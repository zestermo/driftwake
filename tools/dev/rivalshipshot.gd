extends SceneTree
## A rival crew's ship arriving (1.30, RivalArrival / RivalShip), rendered (GPU, opens a window): the light stage with
## its sea, a "dock" at the shore; frames from the dock as she sails in from the horizon, nears, and lies at anchor,
## then the captain's own view when they come ashore.
## `& $env:GODOT --path . --script res://tools/dev/rivalshipshot.gd -- <out_prefix> [crew id]`
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var out := "res://tools/dev/out/rivalship"
var crew := "gilded_gulls"
var cam: Camera3D
var ship
var dock := Vector3.ZERO
var saved := 0
var step := 0
var until := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	if a.size() > 1:
		crew = a[1]
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true, "weather": true})


func _save(tag: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := "%s_%02d_%s.png" % [out, saved, tag]
	img.save_png(ProjectSettings.globalize_path(path))
	print("RSS saved ", path)
	saved += 1


func _look() -> void:
	cam.look_at(ship.global_position + Vector3.UP * 5.0, Vector3.UP)


func _process(_d: float) -> bool:
	var cc := load("res://scripts/ui/character_creator.gd")
	for n in root.find_children("*", "", true, false):
		if n.get_script() == cc and n.is_inside_tree():
			n._finish(true)
	if not stage.up or TK.ticking(until):
		return false
	var RS = load("res://scripts/ai/rival_ship.gd")
	match step:
		0:
			var wx = root.get_node("Weather")
			wx.set_world_time(wx.time_at(10.0, 2))
			var p = stage.player
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			root.get_node("GameManager").rivals.clear()
			dock = Vector3(stage.SHORE_X + 4.0, 0.0, 0.0)
			load("res://scripts/ai/rival_arrival.gd").start(self, crew, dock, Vector3.RIGHT, func(): return p)
			cam = Camera3D.new()
			cam.fov = 50.0
			stage.add_child(cam)
			cam.current = true
			cam.global_position = Vector3(stage.SHORE_X - 2.0, stage.GROUND_Y + 2.2, 6.0)
			until = TK.wait_ticks(3)
		1:
			ship = RS.of(self)
			_look()
			until = TK.wait_secs(4.0)
		2:
			_look()
			_save("horizon")
			until = TK.wait_secs(RS.leg_secs() * 0.55 - 4.0)
		3:
			_look()
			_save("sailing_in")
			until = TK.wait_secs(RS.leg_secs() * 0.45 + 1.5)
		4:
			_look()
			_save("anchored")
			cam.global_position = ship.global_position + Vector3(-30.0, 9.0, 34.0)
			_look()
			until = TK.wait_ticks(3)
		5:
			_save("anchored_close")
			cam.current = false
			until = TK.wait_secs(load("res://scripts/ai/rival_arrival.gd").ROW_S + 0.5)
		6:
			_save("ashore")
			print("RSS done")
			quit()
	step += 1
	return false
