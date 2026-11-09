extends Node
## (1.31) Melee targeting for the local captain (a child "Targeting" of the Player): the lock-on and the target
## chevron. No crosshair in melee (the HUD's reticle shows only for guns and aiming).
## - Lock-on: middle mouse locks the foe nearest the view's centre within LOCK_RANGE m (again releases it); while
##   locked the camera keeps it ahead (camera_rig), attacks, techniques and skills aim at it (PlayerState
##   .get_camera_forward / attack_aim), and a flick of the mouse or right stick sideways switches to the next foe
##   on that side (`switch`). It lets go when the foe dies, or past LOCK_KEEP m.
## - The chevron: over the locked foe (big, red) or, weapon out, the foe your next swing would hit (small, amber:
##   the attack assist's pick along attack_aim). This screen only.
const LOCK_RANGE := 25.0
const LOCK_KEEP := 32.0
const LOCK_CONE := 0.55  # cos ~57 degrees off the view's centre
const SOFT_EVERY := 4
const CHEV_UP := 2.35

var player: Node
var lock: Node3D = null
var soft: Node3D = null
var _chev: MeshInstance3D
var _mat: StandardMaterial3D
var _n := 0


func _ready() -> void:
	player = get_parent()
	_chev = MeshInstance3D.new()
	_chev.name = "TargetChevron"
	var am := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0.5, 0), Vector3(0.5, 0.5, 0), Vector3(0, -0.4, 0)])
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_chev.mesh = am
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.no_depth_test = true
	_mat.render_priority = 10
	_chev.material_override = _mat
	_chev.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chev.top_level = true
	_chev.visible = false
	add_child(_chev)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_MIDDLE:
		if player.input_locked or GameMenu.is_open():
			return
		toggle()
		get_viewport().set_input_as_handled()


func locked() -> bool:
	return lock != null and is_instance_valid(lock)


func toggle() -> void:
	if locked():
		release()
		return
	lock = pick_in_view()
	if lock:
		FX.sfx("blip_high", lock.global_position, -16.0, 0.0, 1.3)


func release() -> void:
	lock = null


## The foe nearest the view's centre (and nearer before farther) within LOCK_RANGE m; null when none.
func pick_in_view() -> Node3D:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var fwd := -cam.global_basis.z
	var best: Node3D = null
	var best_s := INF
	for n in candidates(LOCK_RANGE):
		var d := (n as Node3D).global_position + Vector3(0, 1.0, 0) - cam.global_position
		var l := d.length()
		var c := d.dot(fwd) / maxf(l, 0.01)
		if c < LOCK_CONE:
			continue
		var s := (1.0 - c) * 40.0 + l * 0.15
		if s < best_s:
			best_s = s
			best = n
	return best


## Switch the lock to the next foe to the `side` (-1 left, 1 right) of the current one on screen.
func switch(side: int) -> void:
	if not locked():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := cam.unproject_position(lock.global_position)
	var best: Node3D = null
	var best_dx := INF
	for n in candidates(LOCK_RANGE):
		if n == lock or cam.is_position_behind((n as Node3D).global_position):
			continue
		var dx := (cam.unproject_position((n as Node3D).global_position).x - at.x) * float(side)
		if dx > 4.0 and dx < best_dx:
			best_dx = dx
			best = n
	if best:
		lock = best
		FX.sfx("blip_high", lock.global_position, -18.0, 0.0, 1.5)


## Living foes (and training dummies) within `r` m of the captain.
func candidates(r: float) -> Array:
	var out: Array = []
	var at: Vector3 = player.global_position
	for e in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("training_dummies"):
		var n := e as Node3D
		if n == null or not n.is_visible_in_tree():
			continue
		if n.has_method("is_dead") and n.is_dead():
			continue
		if n.global_position.distance_to(at) <= r:
			out.append(n)
	return out


## The best foe for a swing along `aim` from `at`: within `r` m and the cone (cos) of it, nearer and straighter
## first; null when none (shared with PlayerState.assist_target).
static func best_in_cone(tree: SceneTree, at: Vector3, aim: Vector3, r: float, cone: float) -> Node3D:
	var best: Node3D = null
	var best_s := INF
	for e in tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("training_dummies"):
		var n := e as Node3D
		if n == null or not n.is_inside_tree() or not n.is_visible_in_tree():
			continue
		if n.has_method("is_dead") and n.is_dead():
			continue
		var d := n.global_position - at
		if absf(d.y) > 2.5:
			continue
		d.y = 0.0
		var l := d.length()
		if l > r or l < 0.05:
			continue
		var c := d.dot(aim) / l
		if c < cone:
			continue
		var s := l * (2.0 - c)
		if s < best_s:
			best_s = s
			best = n
	return best


func _process(_delta: float) -> void:
	if locked():
		var dead: bool = lock.has_method("is_dead") and lock.is_dead()
		if dead or not lock.is_visible_in_tree() or lock.global_position.distance_to(player.global_position) > LOCK_KEEP:
			release()
	elif lock != null:
		lock = null
	_n += 1
	if _n % SOFT_EVERY == 0:
		soft = null
		if player.armed and not locked():
			var st = player.state_machine.current_state
			if st and st.has_method("attack_aim"):
				var a: Vector3 = st.attack_aim()
				soft = best_in_cone(get_tree(), player.global_position, a, 6.5, 0.5)
	var on: Node3D = lock if locked() else (soft if soft != null and is_instance_valid(soft) else null)
	_chev.visible = on != null and player.context == player.Context.ON_FOOT
	if _chev.visible:
		var big := locked()
		var s := 0.3 if big else 0.2
		_chev.scale = Vector3(s, s, s)
		_mat.albedo_color = Color(1.0, 0.18, 0.12) if big else Color(1.0, 0.72, 0.2)
		_chev.global_position = on.global_position + Vector3(0, CHEV_UP, 0)
