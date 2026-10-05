extends SceneTree
var t := 0.0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func _process(d):
	t += d
	if t > 2.0:
		var hud = root.get_node("World/PlayerHUD")
		var r = hud._reticle
		print("visible=", r.visible, " pos=", r.position, " gpos=", r.global_position, " size=", r.size, " armed=", r.armed, " vis_in_tree=", r.is_visible_in_tree(), " vp=", root.get_visible_rect())
		quit()
	return false
