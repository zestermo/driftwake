extends SceneTree
## The log pose held up (L) in the game view: unset under level 5 (the
## needle wandering), then set on the first island(s). The wrist itself:
## posebench with PB_KV="log_pose=1" (guard, log_pose:0.98).
## Args: <out_prefix>
var t := 0.0
var out := ""
var p
var step := 0
var t0 := 0.0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func snap(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n)
func _process(d: float) -> bool:
	t += d
	if t < 2.5: return false
	if t - t0 < 1.0 and step > 0: return false
	t0 = t
	match step:
		0:
			for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
			p = get_first_node_in_group("player")
			p.state_machine.force_state("Idle", {})
			p.give_log_pose()
			Input.action_press("log_pose")
		1:
			snap("unset")
			var PR = load("res://scripts/progression/progression.gd")
			while p.progression.level < root.get_node("GameManager").LOG_POSE_LEVEL:
				p.progression.add_xp(PR.xp_to_next(p.progression.level) - p.progression.xp)
		2:
			snap("set_game_view")
			Input.action_release("log_pose")
			quit()
	step += 1
	return false
