extends SceneTree
var f := 0
var t := 0.0
var cc
var shots := [["Body", 0.0], ["Face", 0.0], ["Hair", 0.0], ["Outfit", 0.0], ["Extras", 0.0]]
var i := 0
var wait := 0.0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
		return false
	if cc == null:
		if t < 1.5: return false
		for n in root.get_children():
			if n is CharacterCreator: cc = n
		if cc == null:
			print("NO CREATOR (paused=%s)" % paused); quit(); return false
		print("creator open, paused=", paused)
		wait = 0.5
		return false
	if i < shots.size():
		if i > 0 and f == 0:
			pass
		if f == 0:
			cc._show_tab(shots[i][0]); f = 1; wait = 1.2
			return false
		root.get_texture().get_image().save_png("res://tools/dev/out/creator_%s.png" % shots[i][0])
		f = 0; i += 1
		return false
	# randomize, then finish and confirm the body applied + saved
	cc._randomize(); cc._show_tab("Body")
	var lk: Dictionary = cc.look.duplicate()
	cc._finish(true)
	var p = root.get_tree().get_first_node_in_group("player")
	print("applied hair=", p.body_model.look["hair"], " wanted=", lk["hair"], " build=", p.body_model.look["build"], "/", lk["build"], " saved=", CharacterLook.has_saved(), " paused=", paused, " active=", CharacterCreator.active)
	var re := CharacterLook.load_look()
	print("reloaded matches: ", re["hair"] == lk["hair"] and re["coat"] == lk["coat"] and (re["top_color"] as Color).is_equal_approx(lk["top_color"]))
	quit()
	return false
