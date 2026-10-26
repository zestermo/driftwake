extends SceneTree
## 1.23 sea pursuit renders on the light stage (opens a window): a pirate lashed alongside the crew's ship by her
## grapples with her boarders over the rail and a chain-shot tear in the sail (_grapple), a longboat of boarders rowing
## in (_boat), and an Admiralty ring closing round her from above (_ring). Args: <out_prefix> [psx]
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var out := ""
var cam: Camera3D
var ship
var es
var step := 0
var until := 0
var busy := false


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func _shoot(n: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out + "_" + n + ".png")
	print("saved " + out + "_" + n + ".png")


func _look(from_local: Vector3, at_local: Vector3) -> void:
	cam.global_position = ship.to_global(from_local)
	cam.look_at(ship.to_global(at_local), Vector3.UP)


func _process(_d: float) -> bool:
	if busy or not stage.up or TK.ticking(until):
		return false
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
			busy = true
			_look(Vector3(-9.0, 9.0, 16.0), Vector3(4.0, 2.0, -1.0))
			await _shoot("grapple")
			_look(Vector3(1.5, 3.2, 9.0), Vector3(4.5, 1.6, -2.0))
			await _shoot("grapple_rail")
			_look(Vector3(-2.0, 4.0, 8.0), Vector3(0.0, 9.0, -2.0))
			await _shoot("torn_sail")
			for l in ship.lines.duplicate():
				ship.do_work("cut", int(l[0]), 0.0)
			es.queue_free()
			var gb = ES.new().setup(ship.global_position, 90.0, 0.0, 12, "gunboat")
			gb.name = "Gunboat"
			stage.add_child(gb)
			gb.set_meta("no_sleep", true)
			es = gb
			until = TK.wait_secs(2.0)
		3:
			var right: Vector3 = ship.global_basis.x
			es._pos = ship.global_position + right * 60.0 + ship.global_basis.z * 15.0
			es._heading = ship.global_rotation.y
			es.global_transform = Transform3D(Basis(Vector3.UP, es._heading), es._pos + Vector3(0, 1.45, 0))
			es.reset_physics_interpolation()
			es._set_state(es.S.BROADSIDE)
			es._volleys = 1
			es._volley_cd = 1000.0
			es._ram_cd = 1000.0
			es._board_cd = 1000.0
			es._boat_cd = 0.0
			until = TK.wait_secs(6.0)
		4:
			busy = true
			var boats: Array = get_nodes_in_group("boarding_boats")
			if not boats.is_empty():
				var b: Node3D = boats[0]
				cam.global_position = b.global_position + Vector3(-7.0, 4.0, 9.0)
				cam.look_at(b.global_position + Vector3(0, 0.8, 0), Vector3.UP)
				await _shoot("boat")
			es.queue_free()
			ship.sail = 1.0
			var adm = load("res://scripts/ship/admiralty.gd").ensure(self)
			stage.player.bounty = 70000
			adm.ring_due = {"at": ship.global_position + Vector3(-500, 0, 0), "what": "boss"}
			until = TK.wait_secs(5.0)
		5:
			busy = true
			cam.global_position = ship.global_position + Vector3(0, 150.0, 110.0)
			cam.look_at(ship.global_position, Vector3.UP)
			await _shoot("ring")
			var ring: Array = get_nodes_in_group("admiralty")
			if not ring.is_empty():
				var r: Node3D = ring[0]
				cam.global_position = r.global_position + Vector3(-14.0, 9.0, 22.0)
				cam.look_at(r.global_position + Vector3(0, 4.0, 0), Vector3.UP)
				await _shoot("frigate")
			quit()
			return true
	busy = false
	step += 1
	return false
