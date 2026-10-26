extends SceneTree
## 1.23 enemies render: the shield grunt and the four elite traits' auras on the light stage, in a fight (their
## guard up). Args: <out_prefix>. Shots: <out>_line.png (all five, front three-quarter), <out>_shield.png (close),
## <out>_juggle.png (a grunt launched).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var out := ""
var cam: Camera3D
var step := 0
var until := 0


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	stage = TK.stage(self, {"hud": false, "grunts": [
		{"post": Vector3(-4.0, 0, -6.0), "role": "sword", "seed": 1, "shield": true},
		{"post": Vector3(-2.0, 0, -6.0), "role": "sword", "seed": 2, "trait": "armoured"},
		{"post": Vector3(0.0, 0, -6.0), "role": "sword", "seed": 3, "trait": "berserk"},
		{"post": Vector3(2.0, 0, -6.0), "role": "sword", "seed": 4, "trait": "quick"},
		{"post": Vector3(4.0, 0, -6.0), "role": "sword", "seed": 5, "trait": "burning"},
		{"post": Vector3(0.0, 0, -12.0), "role": "sword", "seed": 6}]})


func shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("SAVED %s_%s.png" % [out, n])


func _process(_d: float) -> bool:
	# (with a window a new game opens the creator first)
	for n in root.find_children("*", "CharacterCreator", true, false):
		n._finish(true)
	if not stage.up or TK.ticking(until):
		return false
	var gs: Array = stage.camp.grunts
	match step:
		0:
			if gs.size() < 6:
				return false
			stage.player.hurtbox.monitorable = false
			stage.player.process_mode = Node.PROCESS_MODE_DISABLED
			for i in 5:
				gs[i].alert()
			cam = Camera3D.new()
			cam.fov = 45.0
			root.add_child(cam)
			cam.current = true
			until = TK.wait_secs(1.2)
		1:
			for i in 5:
				gs[i].process_mode = Node.PROCESS_MODE_DISABLED
			var c: Vector3 = gs[2].global_position
			cam.global_position = c + Vector3(3.0, 2.2, 7.5)
			cam.look_at(c + Vector3(0, 1.0, 0), Vector3.UP)
			until = TK.wait_ticks(3)
		2:
			shot("line")
			var s: Vector3 = gs[0].global_position
			cam.global_position = s + Vector3(1.6, 1.6, 2.6)
			cam.look_at(s + Vector3(0, 1.1, 0), Vector3.UP)
			until = TK.wait_ticks(3)
		3:
			shot("shield")
			var h := HitData.new()
			h.damage = 1.0
			h.launch = 9.0
			gs[5].alert()
			gs[5]._on_hit(h, stage.player)
			until = TK.wait_secs(0.45)
		4:
			var j: Vector3 = gs[5].global_position
			cam.global_position = j + Vector3(4.0, 0.5, 4.0)
			cam.look_at(j + Vector3(0, 0.8, 0), Vector3.UP)
			until = TK.wait_ticks(2)
		5:
			shot("juggle")
			quit()
	step += 1
	return false
