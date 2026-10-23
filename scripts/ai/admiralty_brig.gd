class_name AdmiraltyBrig
extends Node3D
## Arrested (docs/v1_19_plan.md: every captain beaten by an Admiralty squad): the captains wake in the brig of an
## Admiralty ship, a share of their gold confiscated, their weapons in a chest past the guards, and break out:
##   the cell door: F picks the lock (a few seconds; anyone's opens it for everyone)
##   two marine guards in the corridor (captain-style AIs, waiting until the door opens): bare fists until the chest
##   the chest: F takes back what was taken (each captain their own)
##   the hatch: F and you're out, back at the harbour where they took you
## Every captain down in here: back in the cell, the door shut, the guards at their posts. Everyone out: it's gone.
## Built on every machine at the same place (BRIG_AT, high above the world: a sealed room, its ceiling keeps the rain
## out); the host runs the guards. Net._all_arrest / _all_brig_door / _all_brig_gone.

const BRIG_AT := Vector3(0.0, 420.0, 0.0)
const CONFISCATE := 0.3
const PICK_S := 3.0
## In brig space: the cell's middle, the door, the chest, the hatch, the guards' posts.
const CELL := Vector3(0.0, 0.2, 0.0)
const DOOR := Vector3(0.0, 0.0, 2.0)
const CHEST := Vector3(1.6, 0.0, 8.0)
const HATCH := Vector3(0.0, 0.0, 13.2)
const POSTS := [Vector3(-1.6, 0.4, 6.0), Vector3(1.4, 0.4, 10.5)]

## Where the captains go when they climb out.
var return_to := Vector3.ZERO
var officer := ""
var door_open := false
var _door: Node3D
var _door_area: Interactable
var guards: Array = []
## What was taken from our captain (this machine's): [weapon, off-hand] items.
var _taken: Array = []
var _picking := 0.0
var _picker: Player
var _check_t := 0.0


static func of(tree: SceneTree) -> AdmiraltyBrig:
	return tree.current_scene.get_node_or_null("AdmiraltyBrig") as AdmiraltyBrig


static func build(tree: SceneTree, back_to: Vector3, by: String) -> AdmiraltyBrig:
	var b := of(tree)
	if b == null:
		b = AdmiraltyBrig.new()
		b.name = "AdmiraltyBrig"
		tree.current_scene.add_child(b)
		b.global_position = BRIG_AT
		b._build_room()
	b.return_to = back_to
	b.officer = by
	return b


func _build_room() -> void:
	var body := StaticBody3D.new()
	body.name = "Room"
	add_child(body)
	var mb := MeshBuilder.new()
	var planks := PSXMat.lit("planks_dark")
	var floor_m := PSXMat.lit("planks")
	var iron := PSXMat.lit("metal", Color(0.4, 0.42, 0.45))
	var boxes := [
		[floor_m, Vector3(0, -0.1, 6.0), Vector3(6.4, 0.2, 16.4)],      # floor
		[planks, Vector3(0, 3.1, 6.0), Vector3(6.4, 0.2, 16.4)],       # ceiling
		[planks, Vector3(-3.1, 1.5, 6.0), Vector3(0.2, 3.0, 16.4)],    # walls
		[planks, Vector3(3.1, 1.5, 6.0), Vector3(0.2, 3.0, 16.4)],
		[planks, Vector3(0, 1.5, -2.1), Vector3(6.4, 3.0, 0.2)],
		[planks, Vector3(0, 1.5, 14.1), Vector3(6.4, 3.0, 0.2)],
	]
	for bx in boxes:
		mb.add_box(bx[0], Transform3D(Basis(), bx[1]), bx[2], 1.0)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = bx[2]
		cs.shape = sh
		cs.position = bx[1]
		body.add_child(cs)
	# the cell's bars either side of the door
	for x in range(-28, 29, 4):
		var fx := float(x) / 10.0
		if absf(fx) < 0.8:
			continue
		mb.add_box(iron, Transform3D(Basis(), Vector3(fx, 1.5, DOOR.z)), Vector3(0.06, 3.0, 0.06), 1.0)
	for side in [-1.0, 1.0]:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(2.4, 3.0, 0.2)
		cs.shape = sh
		cs.position = Vector3(side * 1.9, 1.5, DOOR.z)
		body.add_child(cs)
	# a cot, a bucket, the chest, a ladder up to the hatch
	mb.add_box(floor_m, Transform3D(Basis(), Vector3(-2.2, 0.35, 0.0)), Vector3(1.0, 0.1, 2.0), 1.0)
	mb.add_box(PSXMat.lit("planks_dark", Color(0.7, 0.55, 0.4)), Transform3D(Basis(), CHEST + Vector3(0, 0.3, 0)), Vector3(1.0, 0.6, 0.6), 1.0)
	mb.add_box(iron, Transform3D(Basis(), CHEST + Vector3(0, 0.62, 0)), Vector3(1.04, 0.06, 0.64), 1.0)
	for i in range(6):
		mb.add_box(planks, Transform3D(Basis(), HATCH + Vector3(0, 0.3 + i * 0.5, 0.6)), Vector3(0.8, 0.06, 0.08), 1.0)
	mb.add_box(iron, Transform3D(Basis(), HATCH + Vector3(0, 3.0, 0.4)), Vector3(1.0, 0.08, 1.0), 1.0)
	add_child(mb.to_instance("Room"))
	# the door: bars that swing away
	_door = StaticBody3D.new()
	_door.name = "Door"
	_door.position = DOOR
	var dmb := MeshBuilder.new()
	for x in [-0.5, -0.25, 0.0, 0.25, 0.5]:
		dmb.add_box(iron, Transform3D(Basis(), Vector3(x, 1.5, 0)), Vector3(0.06, 3.0, 0.06), 1.0)
	dmb.add_box(iron, Transform3D(Basis(), Vector3(0, 1.4, 0)), Vector3(1.2, 0.1, 0.08), 1.0)
	_door.add_child(dmb.to_instance("Bars"))
	var dcs := CollisionShape3D.new()
	dcs.name = "Shape"
	var dsh := BoxShape3D.new()
	dsh.size = Vector3(1.4, 3.0, 0.2)
	dcs.shape = dsh
	dcs.position = Vector3(0, 1.5, 0)
	_door.add_child(dcs)
	add_child(_door)
	# one lantern (a real light: budgeted)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.6, 5.0)
	lamp.omni_range = 12.0
	lamp.light_energy = 1.6
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.shadow_enabled = false
	add_child(lamp)
	_door_area = _interact("PickLock", DOOR + Vector3(0, 1.0, -0.5), "Pick the lock", _pick)
	_interact("Chest", CHEST + Vector3(0, 0.6, 0), "Take back your gear", _gear)
	_interact("Hatch", HATCH + Vector3(0, 1.0, 0), "Climb out", _out)


func _interact(n: String, at: Vector3, prompt: String, cb: Callable) -> Interactable:
	var a := Interactable.new()
	a.name = n
	a.prompt_text = prompt
	a.collision_layer = 512
	a.collision_mask = 0
	a.position = at
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.0
	cs.shape = sh
	a.add_child(cs)
	add_child(a)
	a.interacted.connect(cb)
	return a


## (each machine) our captain arrested: gold confiscated, weapons taken, into the cell, back on their feet.
func lock_up(p: Player) -> void:
	var gold := int(floor(p.inventory_component.count("gold") * CONFISCATE))
	if gold > 0:
		p.inventory_component.remove_item(ItemDB.get_item("gold"), gold)
	_taken = [p.equipped_weapon, p.offhand_weapon]
	if p.offhand_weapon:
		p.set_offhand(null)
	if p.equipped_weapon:
		var w := p.equipped_weapon
		p.unequip_weapon()
		p.inventory_component.remove_item(w, 1)
	if _taken[1]:
		p.inventory_component.remove_item(_taken[1], 1)
	_put_in_cell(p)
	get_tree().call_group("hud", "show_banner", "Arrested", "%s confiscated %d gold. Your weapons are in a chest past the guards. Break out." % [officer, gold], true)


func _put_in_cell(p: Player) -> void:
	var off := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-0.6, 0.6))
	if p.current_state_name() == "Downed":
		Duel.stand_up(p, p.health_component.max_health * 0.5, p.power.energy)
	p.state_machine.force_state("Idle", {})
	p.global_position = to_global(CELL + off)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _pick(p: Player) -> void:
	if door_open or _picking > 0.0:
		return
	_picker = p
	_picking = PICK_S
	p.input_locked = true
	get_tree().call_group("hud", "show_prompt", "Picking the lock...", 0.0)


func _gear(p: Player) -> void:
	if _taken.is_empty() or (_taken[0] == null and _taken[1] == null):
		get_tree().call_group("hud", "show_toast", "Nothing of yours in here")
		return
	if _taken[0]:
		p.inventory_component.add_item(_taken[0], 1)
		p.equip_weapon(_taken[0], true)
	if _taken[1]:
		p.inventory_component.add_item(_taken[1], 1)
		p.set_offhand(_taken[1])
	_taken = []
	get_tree().call_group("hud", "show_toast", "Your gear, back where it belongs")


func _out(p: Player) -> void:
	if not door_open:
		return
	if not _taken.is_empty() and (_taken[0] != null or _taken[1] != null):
		_gear(p)
	p.global_position = return_to + Vector3(0, 0.5, 0)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	get_tree().call_group("hud", "show_toast", "Free. They'll want you back")


func open_door() -> void:
	door_open = true
	if _door:
		_door.rotation.y = -1.9
		_door.position = DOOR + Vector3(-0.6, 0, 0.6)
		(_door.get_node("Shape") as CollisionShape3D).disabled = true
	if _door_area:
		_door_area.enabled = false
	for g in guards:
		if is_instance_valid(g):
			g.get_node("Brain").order = "fight"


func close_door() -> void:
	door_open = false
	if _door:
		_door.rotation.y = 0.0
		_door.position = DOOR
		(_door.get_node("Shape") as CollisionShape3D).disabled = false
	if _door_area:
		_door_area.enabled = true


func _physics_process(delta: float) -> void:
	if _picking > 0.0:
		_picking -= delta
		get_tree().call_group("hud", "show_prompt", "Picking the lock...", 1.0 - _picking / PICK_S)
		if _picking <= 0.0:
			_picking = 0.0
			if _picker and is_instance_valid(_picker):
				_picker.input_locked = false
			get_tree().call_group("hud", "show_prompt", "", -1.0)
			get_node("/root/Net").everyone("_all_brig_door", [true])
	_check_t += delta
	if _check_t < 0.5:
		return
	_check_t = 0.0
	var net := get_node("/root/Net")
	if not net.is_host():
		return
	var caps := get_tree().get_nodes_in_group("players")
	var inside := caps.filter(func(c): return (c as Node3D).global_position.distance_to(global_position + Vector3(0, 0, 6)) < 30.0)
	if inside.is_empty():
		net.everyone("_all_brig_gone", [])
		return
	# everyone in here beaten (not just knocked down: Player.is_standing): back in the cell
	if inside.all(func(c): return not c.is_standing()):
		net.everyone("_all_brig_door", [false])


## (host) the guards at their posts, waiting until the door opens.
func spawn_guards(n: int) -> void:
	var net := get_node("/root/Net")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["brig", officer])
	for i in range(mini(n, POSTS.size())):
		var lk: Dictionary = CharacterLook.random_look(rng)
		EnemyShip.marine_look(lk, rng, false)
		lk["name"] = "Brig guard"
		var gname := "BrigGuard_%d" % i
		if has_node(gname):
			continue
		net.everyone("_all_spawn_rival", [net.key_of(self), gname, lk, ["cutlass", "warhammer"][i % 2], to_global(POSTS[i]), PI, 0.45])
		var g := get_node_or_null(gname) as Player
		if g:
			g.get_node("Brain").order = "hold"
			guards.append(g)


## (every machine) back in the cell: the captains here stood up in it, the door shut, the guards back at their posts.
func reset() -> void:
	close_door()
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and p.global_position.distance_to(global_position + Vector3(0, 0, 6)) < 30.0:
		_put_in_cell(p)
	for i in range(guards.size()):
		var g = guards[i]
		if is_instance_valid(g):
			if g.current_state_name() == "Downed":
				Duel.stand_up(g, g.health_component.max_health * 0.6, 0.0)
			g.global_position = to_global(POSTS[i])
			g.reset_physics_interpolation()
			g.get_node("Brain").order = "hold"
	get_tree().call_group("hud", "show_toast", "Thrown back in the cell")
