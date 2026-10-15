extends SceneTree
## The flipbook pilot's before/after (FX.flipbook_pilot) in the real world: each shot filmed
## twice from the same camera at the game's pixel grid, the pilot off then on, frames along
## the effect's life. Effects: "heavy" (a katana's heavy slam on a patch of dirt out on the
## water, from a game camera behind the captain) and "cannon" (the crew's sloop: a cannon going
## off, a ball bursting on the hull, a ball into the sea; all on the seaward side).
## Args: <out_dir> [effects: heavy,cannon] [frames=8]. Env FLIP_HOUR (default 13; another hour
## adds "_h<hour>" to the names). Writes <out_dir>/compare_<effect>.png: two rows per shot,
## before (grey bar) over after (orange bar). Prints each run's bursts, particles and draw calls.
const TK := preload("res://tools/dev/test_kit.gd")
const SHOTS := {"heavy": ["heavy"], "cannon": ["muzzle", "hull", "sea"]}
const SPAN := {"heavy": 1.0, "muzzle": 1.8, "hull": 1.8, "sea": 1.4}
const CROP := Vector2i(360, 240)
const PAD := Vector3(150, 2.5, -96)

var t := 0.0
var p
var ship
var isle: Node3D
var out_dir := "res://tools/dev/out/flipbook"
var effects: Array = ["heavy", "cannon"]
var frames := 8
var hour := 13.0
var queue: Array = []
var rows: Dictionary = {}
var step := 0
var until := 0
var cam: Camera3D
var run: Array = []
var started := false
var since := 0.0
var imgs: Array = []
var busy := false
var focus := Vector3.ZERO
var crop := Rect2i()
var hit_at := Vector3.ZERO
var hit_n := Vector3.ZERO
var before: Dictionary = {}
var seen: Dictionary = {}
var base_draws := 0
var peak_draws := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		effects = Array(args[1].split(","))
	if args.size() > 2:
		frames = int(args[2])
	if OS.get_environment("FLIP_HOUR") != "":
		hour = float(OS.get_environment("FLIP_HOUR"))
	TK.seed_of(self)
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	if t < 1.5 or TK.ticking(until):
		return false
	match step:
		0:
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			p = root.get_tree().get_first_node_in_group("player")
			ship = root.get_tree().get_first_node_in_group("ship")
			isle = root.get_node("World/Islands/Brinehollow")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			var hud = root.get_tree().get_first_node_in_group("hud")
			if hud:
				hud.visible = false
			var st = root.get_node("Settings")
			st.set_value("video", "pixelate", true, false)
			st.set_value("video", "dither", true, false)
			var wx = root.get_node("Weather")
			wx.set_world_time(wx.time_at(hour))
			wx.force(0)
			var pad := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(30, 1, 30)
			cs.shape = box
			pad.add_child(cs)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = box.size
			mi.mesh = bm
			mi.material_override = PSXMat.lit("dirt")
			pad.add_child(mi)
			root.get_tree().current_scene.add_child(pad)
			pad.global_position = PAD - Vector3(0, 0.5, 0)
			var it = load("res://resources/items/katana.tres")
			p.inventory_component.add_item(it, 1)
			p.equip_weapon(it, false)
			p.sheathe_weapon(true)
			p.draw_weapon(true)
			cam = Camera3D.new()
			cam.fov = 70.0
			cam.far = 1200.0
			# (in a rig and an arm: the player's states read the camera's yaw off its grandparent)
			var rig := Node3D.new()
			var arm := Node3D.new()
			rig.add_child(arm)
			arm.add_child(cam)
			root.get_tree().current_scene.add_child(rig)
			cam.current = true
			for e in effects:
				rows[e] = []
				for s in SHOTS[e]:
					queue.append([e, s, false])
					queue.append([e, s, true])
			until = TK.wait_secs(1.0)
			step = 1
		1:
			if queue.is_empty():
				for e in rows.keys():
					_sheet(e)
				quit()
				return true
			run = queue.pop_front()
			_setup()
			until = TK.wait_secs(2.8)
			step = 2
		2:
			_setup()
			root.get_node("FX").flipbook_pilot = run[2]
			before.clear()
			seen.clear()
			for n in _bursts():
				before[n.get_instance_id()] = true
			base_draws = _draws()
			peak_draws = base_draws
			_trigger()
			imgs.clear()
			since = 0.0
			started = run[1] != "heavy"
			step = 3
		3:
			if not started:
				started = bool(p.state_machine.current_state.get("impact_fx"))
				return false
			if not busy and imgs.size() < frames and since >= SPAN[run[1]] * float(imgs.size()) / float(frames - 1):
				busy = true
				_grab()
			since += d
			if imgs.size() >= frames and not busy:
				var parts := 0
				for k in seen.keys():
					parts += int(seen[k])
				print("PERF %s pilot=%s bursts=%d particles=%d draws=+%d" % [run[1], run[2], seen.size(), parts, peak_draws - base_draws])
				(rows[run[0]] as Array).append([run[1], run[2], imgs.duplicate()])
				step = 1
	return false


## The camera and the captain for this run (again just before it fires: the ship rides the swell).
func _setup() -> void:
	if run[1] == "heavy":
		p.state_machine.force_state("Idle", {})
		p.global_position = PAD + Vector3(0, 0.1, 0)
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		p.player_model.rotation.y = 0.0
		cam.look_at_from_position(PAD + Vector3(1.6, 2.5, 4.4), PAD + Vector3(0, 0.6, -1.4), Vector3.UP)
		focus = PAD + Vector3(0, 0.4, -1.3)
		return
	p.global_position = PAD + Vector3(0, 0.1, 0)
	p.velocity = Vector3.ZERO
	var c = _cannon()
	var from: Vector3 = c.muzzle()
	var dir: Vector3 = c.shot_velocity().normalized()
	_find_hull()
	var along := hit_n.cross(Vector3.UP).normalized()
	match run[1]:
		"muzzle":
			var side := dir.cross(Vector3.UP).normalized()
			cam.look_at_from_position(from - dir * 4.5 + Vector3.UP * 1.4 + side * 1.6, from + dir * 3.0, Vector3.UP)
			focus = from + dir * 1.5
		"hull":
			cam.look_at_from_position(hit_at + hit_n * 13.0 + Vector3.UP * 2.5 + along * 3.0, hit_at + Vector3.UP * 0.8, Vector3.UP)
			focus = hit_at + hit_n * 0.6 + Vector3.UP * 0.6
		"sea":
			var at := hit_at + hit_n * 7.0
			cam.look_at_from_position(hit_at + hit_n * 18.0 + Vector3.UP * 2.5 + along * 3.0, Vector3(at.x, 1.0, at.z), Vector3.UP)
			focus = Vector3(at.x, 1.0, at.z)


func _trigger() -> void:
	var fx = root.get_node("FX")
	match run[1]:
		"heavy":
			p.state_machine.force_state("HeavyAttack", {})
		"muzzle":
			var c = _cannon()
			fx.cannon_fire(c.muzzle(), c.shot_velocity().normalized())
		"hull":
			fx.cannon_hit(hit_at, hit_n)
		"sea":
			var oc = root.get_node("Ocean")
			var at := hit_at + hit_n * 7.0
			at.y = float(oc.get_wave_height(at, oc.clock()))
			fx.cannon_splash(at)


## Away from Brinehollow (flat), from the ship.
func _seaward() -> Vector3:
	var v: Vector3 = ship.global_position - isle.global_position
	return Vector3(v.x, 0.0, v.z).normalized()


## The sloop's cannon pointing most to seaward.
func _cannon():
	var best = null
	var best_d := -2.0
	for c in ship.cannons:
		var dd: float = c.shot_velocity().normalized().dot(_seaward())
		if dd > best_d:
			best_d = dd
			best = c
	return best


## Where a ball from seaward meets the hull a metre above the water, and the hull's normal there.
func _find_hull() -> void:
	var sp: Vector3 = ship.global_position
	var beam: Vector3 = ship.global_basis.x.normalized()
	if beam.dot(_seaward()) < 0.0:
		beam = -beam
	var from := Vector3(sp.x, 1.2, sp.z) + beam * 20.0
	var q := PhysicsRayQueryParameters3D.create(from, Vector3(sp.x, 1.2, sp.z))
	var h: Dictionary = ship.get_world_3d().direct_space_state.intersect_ray(q)
	hit_at = h["position"]
	hit_n = Vector3(h["normal"].x, 0.0, h["normal"].z).normalized()


func _bursts() -> Array:
	return root.get_tree().current_scene.find_children("*", "CPUParticles3D", true, false)


func _draws() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


func _grab() -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var grid: Vector2 = root.get_node("PSX").pixel_res()
	img.resize(int(grid.x), int(grid.y), Image.INTERPOLATE_NEAREST)
	if imgs.is_empty():
		var at: Vector2 = cam.unproject_position(focus) * (grid / root.get_visible_rect().size)
		crop = Rect2i(Vector2i(at) - CROP / 2, CROP)
		crop.position = crop.position.clamp(Vector2i.ZERO, Vector2i(grid) - CROP)
	imgs.append(img.get_region(crop))
	for n in _bursts():
		if not before.has(n.get_instance_id()):
			seen[n.get_instance_id()] = n.amount
	peak_draws = maxi(peak_draws, _draws())
	busy = false


func _sheet(effect: String) -> void:
	var list: Array = rows[effect]
	var bar := 8
	var sheet := Image.create(bar + frames * (CROP.x + 2), list.size() * (CROP.y + 2), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.08, 0.08, 0.08))
	for r in range(list.size()):
		var y := r * (CROP.y + 2)
		sheet.fill_rect(Rect2i(0, y, bar - 2, CROP.y), Color(1.0, 0.55, 0.15) if list[r][1] else Color(0.4, 0.4, 0.4))
		for i in range((list[r][2] as Array).size()):
			sheet.blit_rect(list[r][2][i], Rect2i(Vector2i.ZERO, CROP), Vector2i(bar + i * (CROP.x + 2), y))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var path := "%s/compare_%s%s.png" % [out_dir, effect, "" if hour == 13.0 else "_h%d" % int(hour)]
	sheet.save_png(path)
	print("SAVED ", path)
