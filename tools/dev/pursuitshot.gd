extends SceneTree
## 1.23 sea pursuit renders on the light stage (opens a window): a pirate lashed alongside the crew's ship by her
## grapples (lines on the rail, boarders over it) with a chain-shot tear in the sail (_grapple, _grapple_rail,
## _torn_sail), a longboat of boarders rowing in (_boat), and an Admiralty ring closing round her from above (_ring)
## with a close look at one of them (_frigate). Args: <out_prefix> [psx]
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var out := ""
var cam: Camera3D
var ship
var es
var step := 0
var until := 0
## The shot to save once the camera has settled ("" none).
var pending := ""


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func _look(from_local: Vector3, at_local: Vector3, n: String) -> void:
	cam.global_position = ship.to_global(from_local)
	cam.look_at(ship.to_global(at_local), Vector3.UP)
	_shot(n)


func _shot(n: String) -> void:
	pending = n
	until = TK.wait_ticks(3)


func _process(_d: float) -> bool:
	# (a fresh save in a window opens the character creator: done with it)
	if not stage.up:
		for c in root.find_children("*", "CharacterCreator", true, false):
			c._finish(true)
	if not stage.up or TK.ticking(until):
		return false
	if pending != "":
		root.get_texture().get_image().save_png(out + "_" + pending + ".png")
		print("saved " + out + "_" + pending + ".png")
		pending = ""
	var ES = load("res://scripts/ship/enemy_ship.gd")
	match step:
		0:
			if OS.get_cmdline_user_args().has("psx"):
				root.get_node("Settings").set_value("video", "pixelate", true, false)
			else:
				root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			ship = stage.ship
			var p = stage.player
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			p.global_position = ship.to_global(Vector3(-1.0, 0.6, 1.0))
			p.reset_physics_interpolation()
			cam = Camera3D.new()
			cam.fov = 55
			cam.far = 1500
			cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			root.add_child(cam)
			cam.current = true
			ship.sail = 2.0 / 3.0
			ship.sail_shown = 2.0 / 3.0
			es = ES.new().setup(ship.global_position, 90.0, 0.0, 7, "sloop")
			es.name = "Raider"
			stage.add_child(es)
			es.set_meta("no_sleep", true)
			until = TK.wait_secs(4.0)
		1:
			var right: Vector3 = ship.global_basis.x
			es._pos = ship.global_position + right * es.ALONGSIDE
			es._heading = ship.global_rotation.y
			es.speed = ship.speed
			es.global_transform = Transform3D(Basis(Vector3.UP, es._heading), es._pos + Vector3(0, 1.45, 0))
			es.reset_physics_interpolation()
			es._set_state(es.S.BOARD)
			es._board(ship)
			ship.tear_sail(Vector3(-1.5, 10.0, -1.8))
			until = TK.wait_secs(1.1)
		2:
			_look(Vector3(-9.0, 9.0, 16.0), Vector3(4.0, 2.0, -1.0), "grapple")
		3:
			_look(Vector3(0.8, 2.6, 1.5), Vector3(4.2, 1.4, -1.0), "grapple_rail")
		4:
			_look(Vector3(0.0, 8.0, 9.0), Vector3(0.0, 9.0, -1.6), "torn_sail")
		5:
			for l in ship.lines.duplicate():
				ship.do_work("cut", int(l[0]), 0.0)
			for g in es.boarders:
				if is_instance_valid(g):
					g.queue_free()
			es.queue_free()
			stage.player.global_position = ship.to_global(Vector3(-1.0, 0.6, 1.0))
			stage.player.reset_physics_interpolation()
			var gb = ES.new().setup(ship.global_position, 90.0, 0.0, 12, "brig")
			gb.name = "Brig"
			stage.add_child(gb)
			gb.set_meta("no_sleep", true)
			es = gb
			gb.set_physics_process(false)
			ship.sail = 1.0
			until = TK.wait_secs(10.0)
		6:
			var right: Vector3 = ship.global_basis.x
			es._pos = ship.global_position + right * 60.0 + ship.global_basis.z * 15.0
			es._heading = ship.global_rotation.y
			es.global_transform = Transform3D(Basis(Vector3.UP, es._heading), es._pos + Vector3(0, 1.45, 0))
			es.reset_physics_interpolation()
			es.set_physics_process(true)
			es._set_state(es.S.BROADSIDE)
			es._volleys = 1
			es._volley_cd = 1000.0
			es._ram_cd = 1000.0
			es._board_cd = 1000.0
			es._boat_cd = 1000.0
			until = TK.wait_secs(1.0)
		7:
			es._lower_boat(ship)
			until = TK.wait_secs(4.0)
		8:
			var boats: Array = get_nodes_in_group("boarding_boats")
			if not boats.is_empty():
				var b: Node3D = boats[0]
				var back: Vector3 = b.global_basis.z
				cam.global_position = b.global_position + back * 8.0 + Vector3(0, 7.0, 0)
				cam.look_at(b.global_position + Vector3(0, 0.5, 0), Vector3.UP)
				_shot("boat")
		9:
			es.set_physics_process(false)
			es.visible = false
			var adm = load("res://scripts/ship/admiralty.gd").ensure(self)
			stage.player.bounty = 70000
			adm.ring_due = {"at": ship.global_position + Vector3(-500, 0, 0), "what": "boss"}
			until = TK.wait_secs(6.0)
		10:
			cam.global_position = ship.global_position + Vector3(0, 260.0, 160.0)
			cam.look_at(ship.global_position, Vector3.UP)
			_shot("ring")
		11:
			var ring: Array = get_nodes_in_group("admiralty")
			if not ring.is_empty():
				var r: Node3D = ring[0]
				cam.global_position = r.global_position + r.global_basis.x * 22.0 + r.global_basis.z * 14.0 + Vector3(0, 8.0, 0)
				cam.look_at(r.global_position + Vector3(0, 4.0, 0), Vector3.UP)
				_shot("frigate")
		12:
			quit()
			return true
	step += 1
	return false
