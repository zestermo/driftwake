extends SceneTree
## README screenshots at the game's "960x540 (sharper)" PSX preset (set for
## this run only, not saved), HUD off, late afternoon, clear.
## Args: <out_prefix> <set>
##   scenes  Brinehollow's street, the tavern inside, a katana fight at the camp
##   steel   Haki-coated katana iai draw, air slash, axe whirlwind + Skybreaker,
##           dual-pistol Gun Rain, Flying Slash
## Shots come in bursts (name_NN); pick the frames you like.
var t := 0.0
var out := ""
var which := ""
var p
var pc
var w
var isl
var camp
var rig: Node3D
var cam: Camera3D
var g
var queue: Array = []
var wait := 0.0
var follow := false
var yaw := 0.0
var cam_off := Vector3(3.0, 1.8, 2.0)
var look_up := 1.1


func _initialize():
	var args := OS.get_cmdline_user_args()
	out = args[0]
	which = args[1] if args.size() > 1 else "scenes"
	change_scene_to_file("res://scenes/world/world.tscn")


func shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, name])
	print("shot ", name, "  ", p.current_state_name(), " / ", p.body_model.current_action())


func burst(name: String, times: Array) -> void:
	var last := 0.0
	for i in range(times.size()):
		var k := i
		do(float(times[i]) - last, func(): shot("%s_%02d" % [name, k]))
		last = float(times[i])


func do(delay: float, fn: Callable) -> void:
	queue.append([delay, fn])


func ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at


func fwd() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## A grunt `ahead` metres in front (sideways `side`), facing us, harmless.
func target(i: int, ahead: float, side: float = 0.0):
	var x = camp.grunts[i]
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	x.humanoid.seated = false
	x.global_position = ground(p.global_position + fwd() * ahead + right * side) + Vector3.UP * 0.3
	x.velocity = Vector3.ZERO
	x.reset_physics_interpolation()
	x.health.current_health = 500.0
	var d: Vector3 = p.global_position - x.global_position
	x._yaw = atan2(-d.x, -d.z)
	x.facing.rotation.y = x._yaw
	return x


func clear_targets() -> void:
	var i := 0
	for x in camp.grunts:
		if is_instance_valid(x):
			i += 1
			x.global_position = ground(p.global_position + Vector3(60 + i * 4, 0, 60))
			x.reset_physics_interpolation()


func stand(at: Vector3, face_yaw: float) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = ground(at) + Vector3.UP * 0.2
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	yaw = face_yaw
	p.player_model.rotation.y = yaw


func lift(h: float) -> void:
	p.global_position += Vector3.UP * h
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func press(action: String) -> void:
	p.input_buffer.buffer_action(action)


func cast(id: String, slot: int) -> void:
	# (learn the skill map node that teaches it, so it can go on the bar)
	var nodes: Dictionary = load("res://scripts/progression/skill_tree.gd").nodes()
	for k in nodes:
		if str(nodes[k].get("skill", "")) == id:
			p.progression._own(k)
	pc.equip(id, slot)
	pc.cooldowns[id] = 0.0
	pc.energy = pc.max_energy()
	if slot == 4:
		pc.ult = pc.ULT_MAX
	print("cast ", id, ": ", pc.can_cast(slot), " -> ", pc.try_cast(slot))


func arm(item_path: String, offhand: String = "") -> void:
	var it = load(item_path)
	p.inventory_component.add_item(it, 1)
	p.equip_weapon(it, false)
	p.set_offhand(null)
	if offhand != "":
		var o = load(offhand)
		p.inventory_component.add_item(o, 1)
		p.set_offhand(o)
	p.draw_weapon(true)


func _process(d: float) -> bool:
	t += d
	if camp and which != "scenes":
		for x in camp.grunts:
			if is_instance_valid(x):
				x._cooldown = 99.0; x._pistol_cd = 99.0; x._shot_cd = 99.0; x._shove_cd = 99.0
	if t < 2.0: return false
	if p == null:
		_setup()
		return false
	if follow:
		rig.global_position = p.global_position
		rig.rotation.y = yaw
		cam.position = cam_off
		cam.look_at(p.global_position + Vector3.UP * look_up + fwd() * 1.5, Vector3.UP)
	else:
		rig.rotation.y = yaw
	p.stamina = p.max_stamina
	wait -= d
	while wait <= 0.0:
		if queue.is_empty():
			quit()
			return false
		var step: Array = queue.pop_front()
		(step[1] as Callable).call()
		wait += float(queue[0][0]) if not queue.is_empty() else 0.5
	return false


func _setup() -> void:
	var settings = root.get_node("Settings")
	settings.set_value("video", "psx_preset", 4, false)
	settings.set_value("video", "dither", true, false)
	for k in root.find_children("*", "CharacterCreator", true, false): k._finish(true)
	get_first_node_in_group("hud").visible = false
	p = get_first_node_in_group("player")
	# a proper captain (script runs start with whatever look a test saved last)
	var lk: Dictionary = load("res://scripts/npc/character_look.gd").default_look()
	lk.merge({"hat": "tricorn", "hat_color": Color(0.16, 0.12, 0.1), "coat": "longcoat", "coat_color": Color(0.55, 0.09, 0.08),
		"vest": "vest", "legs_color": Color(0.22, 0.18, 0.14), "hair": "long"}, true)
	p.appearance = lk
	p._wear_outfit_of(lk)
	pc = p.power
	p.health_component.max_health = 99999.0
	p.health_component.current_health = 99999.0
	w = root.get_node("Weather")
	w.forced = 0
	w.forced_at = w.world_time() - 100.0
	w.world_offset += fposmod(16.3 - float(w.hour()), 24.0) / 24.0 * float(w.DAY_LEN)
	isl = root.get_node("World/Islands/Brinehollow")
	camp = isl.get_node("SmugglersCamp")
	# (attacks aim along the current camera's grandparent: a stand-in rig)
	rig = Node3D.new()
	var a := Node3D.new()
	root.add_child(rig); rig.add_child(a)
	cam = Camera3D.new(); cam.fov = 60; cam.far = 3000
	a.add_child(cam)
	cam.current = true
	call("_plan_" + which)
	wait = float(queue[0][0])


func _fixed(from: Vector3, at: Vector3) -> void:
	follow = false
	cam.global_position = from
	cam.look_at(at, Vector3.UP)


func _plan_scenes() -> void:
	do(1.0, func(): _fixed(Vector3(149.0, 5.0, 33.0), Vector3(150.0, 4.0, 80.0)))
	do(1.5, func(): shot("village"))
	do(0.1, func():
		var tv: Node3D = isl._tavern
		var bk: Vector3 = (tv.get_node("Barkeep") as Node3D).global_position
		var mid := tv.global_position + Vector3.UP * 1.0
		_fixed(mid + (mid - bk).normalized() * 3.5 + Vector3.UP * 1.4, bk + Vector3.UP * 0.6))
	do(1.5, func(): shot("tavern"))
	do(0.1, func():
		g = camp.grunts[1]
		arm("res://resources/items/katana.tres")
		stand(g.global_position + Vector3(3.2, 0, 0), PI * 0.5))
	# (a brawl: grunts free to swing; the camera side-on to the duel)
	for i in range(30):
		do(0.12 if i > 0 else 1.0, func():
			var to: Vector3 = g.global_position - p.global_position
			yaw = atan2(-to.x, -to.z)
			var mid: Vector3 = (g.global_position + p.global_position) * 0.5
			_fixed(mid + Vector3.UP.cross(to.normalized()) * 4.2 + Vector3(0, 1.3, 0), mid + Vector3(0, 1.0, 0))
			if i % 4 == 0:
				press("light_attack")
			shot("fight_%02d" % i))


## The open sand by the smugglers' camp, the lighthouse and the sea behind.
func _beach() -> Vector3:
	return camp.grunts[1].global_position + Vector3(3.2, 0, 0)


func _plan_steel() -> void:
	# katana + Armament Haki: a level-2 iai draw
	do(0.5, func():
		stand(_beach(), PI * 0.5)
		arm("res://resources/items/katana.tres")
		follow = true
		cam_off = Vector3(2.6, 1.5, -1.6))
	do(1.2, func(): cast("armament_coat", 0))
	do(1.4, func():
		target(0, 5.0)
		Input.action_press("heavy_attack")
		press("heavy_attack"))
	burst("iai_charge", [0.6, 1.3])
	do(0.05, func(): press("light_attack"))
	burst("iai_cut", [0.06, 0.12, 0.2, 0.3, 0.45])
	do(0.3, func(): Input.action_release("heavy_attack"))
	# the katana's air slash
	do(1.0, func():
		p.state_machine.force_state("Idle", {})
		target(0, 2.5)
		cam_off = Vector3(3.2, 2.0, 1.0)
		lift(2.6))
	do(0.12, func(): press("light_attack"))
	burst("airslash", [0.1, 0.2, 0.3, 0.4])
	# the axe: whirlwind, then Skybreaker
	do(1.2, func():
		p.state_machine.force_state("Idle", {})
		arm("res://resources/items/boarding_axe.tres")
		target(0, 1.6)
		target(1, -1.6)
		cam_off = Vector3(3.5, 2.2, 2.0))
	do(0.8, func(): press("heavy_attack"))
	burst("whirl", [0.2, 0.35, 0.5, 0.7, 0.9])
	do(1.5, func():
		p.state_machine.force_state("Idle", {})
		clear_targets()
		target(0, 3.6)
		cam_off = Vector3(4.0, 2.2, 0.5)
		lift(2.6))
	do(0.12, func(): press("light_attack"))
	burst("skybreaker", [0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.1])
	# dual pistols: Gun Rain
	do(1.5, func():
		p.state_machine.force_state("Idle", {})
		arm("res://resources/items/pistol.tres", "res://resources/items/pistol.tres")
		target(0, 4.0)
		cam_off = Vector3(3.5, 1.6, 1.2)
		lift(3.0))
	do(0.12, func(): press("light_attack"))
	burst("gunrain", [0.06, 0.12, 0.2, 0.3, 0.45])
	# the cutlass: Flying Slash
	do(1.5, func():
		p.state_machine.force_state("Idle", {})
		arm("res://resources/items/cutlass.tres")
		target(0, 9.0)
		cam_off = Vector3(3.0, 1.7, 1.5))
	do(0.8, func(): cast("flying_slash", 1))
	burst("flyingslash", [0.2, 0.3, 0.4, 0.55, 0.7])
