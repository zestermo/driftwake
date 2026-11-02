extends SceneTree
## A leviathan on the light stage beside the crew's ship: risen and fighting, an arm (or its own move) on her, seen from
## off her quarter and from her deck. Args: <out_prefix> [kind=squid]  (saves <out>_<kind>_far.png, _deck.png)
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var t := 0.0
var step := 0
var lv
var kind := "squid"
var cam: Camera3D


func _initialize() -> void:
	TK.seed_of(self)
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		kind = a[1]
	stage = TK.stage(self, {"ship": true, "weather": true})


func shot(name: String) -> void:
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	root.get_texture().get_image().save_png("%s_%s_%s.png" % [out, kind, name])


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
			var p = stage.player
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			p.global_position = stage.ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			if kind == "eel":
				root.get_node("Weather").force(3)
			lv = load("res://scripts/enemies/leviathan.gd").make(kind, Vector2(stage.ship.global_position.x + 30.0, stage.ship.global_position.z), 14)
			stage.add_child(lv)
			step = 1
			t = 0.0
		1:
			if t > (9.0 if kind == "eel" else 4.0) and lv.state == 2:
				lv.set("_next", 0.0)
				step = 2
				t = 0.0
		2:
			if t > 2.2:
				cam = Camera3D.new()
				stage.add_child(cam)
				var s: Node3D = stage.ship
				cam.global_position = s.to_global(Vector3(-14.0, 9.0, 22.0))
				cam.look_at((s.global_position + lv.core.global_position) * 0.5 + Vector3.UP * 3.0)
				cam.fov = 60.0
				cam.current = true
				step = 3
				t = 0.0
		3:
			if t > 0.4:
				shot("far")
				cam.global_position = stage.ship.to_global(Vector3(-1.0, 3.2, 4.5))
				cam.look_at(lv.core.global_position + Vector3.UP * 3.0)
				step = 4
				t = 0.0
		4:
			if t > 0.4:
				shot("deck")
				print("SAVED")
				quit()
	return false
