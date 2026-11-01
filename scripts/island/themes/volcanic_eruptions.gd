extends Node3D
## The volcano's rumbles and bursts (docs/volcanic_island_plan.md "The set piece"; VolcanicLand.steps). While a captain
## is on the island, every few minutes the host sets one off (erupt(n), sent to every guest with Net.event: n is all
## it needs). Each machine then plays the same thing from the island's seed and n: the ground shakes with a deep rumble,
## smoke and embers burst from the caldera, and after RUMBLE_LEAD s lava bombs rain on one part of the island (a seeded
## sector, never the town or the harbour): each bomb's red circle on the ground TELL s before it lands, the bomb falling
## in a glowing arc onto it, then a burst of embers. A bomb hurts only inside its circle, and each machine only its own
## captain. Game time throughout (physics ticks); asleep while nobody's near.

const FIRST := [45.0, 70.0]
const GAP := [150.0, 260.0]
const RUMBLE_LEAD := 2.2
const BOMBS := [10, 16]
const SPAN := 6.0
const SPREAD := 40.0
const TELL := 1.6
const FALL := 0.8
const R := 3.0
const DAMAGE := 22.0
## A bomb's sector keeps this far off the village and the dock (m), and every bomb this far off them.
const SAFE := 90.0
const BOMB_SAFE := 60.0
## A captain this far past the island's radius still feels it.
const NEAR := 120.0
const LAND := preload("res://scripts/island/themes/volcanic_land.gd")

var isl
## The next eruption's number and the seconds to it (host).
var n := 0
var _wait := -1.0
var _check := 0.0
## Things to do: [seconds left, Callable] (every machine).
var _queue: Array = []
static var _bomb_mesh: Mesh


func _ready() -> void:
	_wait = _gap(-1)


func _gap(k: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "eruption gap", k])
	return rng.randf_range(FIRST[0], FIRST[1]) if k < 0 else rng.randf_range(GAP[0], GAP[1])


func _physics_process(delta: float) -> void:
	for i in range(_queue.size() - 1, -1, -1):
		_queue[i][0] -= delta
		if _queue[i][0] <= 0.0:
			var f: Callable = _queue[i][1]
			_queue.remove_at(i)
			f.call()
	if not Net.is_host():
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	if not _captain_near():
		return
	_wait -= 1.0
	if _wait <= 0.0:
		erupt_now()


func _captain_near() -> bool:
	var c: Vector3 = isl.global_position
	for p in get_tree().get_nodes_in_group("players"):
		if (p as Node3D).global_position.distance_to(c) < float(isl.radius) + NEAR:
			return true
	return false


## (host) Sets the next eruption off now, on every screen.
func erupt_now() -> void:
	var k := n
	n += 1
	_wait = _gap(k)
	erupt(k)
	Net.event(self, "erupt", [k])


func net_event(what: String, args: Array) -> void:
	if what == "erupt":
		n = int(args[0]) + 1
		erupt(int(args[0]))


## The bursts of eruption k: [the sector's middle, [[seconds after the rumble it lands, island point]...]] (the same on
## every machine).
func plan(k: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "eruption", k])
	var cone: Dictionary = isl.land_plan["cone"]
	var cc: Vector2 = cone["c"]
	var safe := func(q: Vector2, d: float) -> bool:
		for s in ["village", "dock"]:
			if isl.sites.has(s) and q.distance_to(isl.sites[s]) < d:
				return false
		return true
	var mid := cc + Vector2.from_angle(rng.randf() * TAU) * float(cone["foot"]) * 0.6
	for t in range(12):
		var q := cc + Vector2.from_angle(rng.randf() * TAU) * float(isl.radius) * rng.randf_range(0.3, 0.7)
		if isl.hv(q) > 1.0 and safe.call(q, SAFE):
			mid = q
			break
	var bombs: Array = []
	for i in range(rng.randi_range(BOMBS[0], BOMBS[1])):
		var q := mid + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * SPREAD
		var at := RUMBLE_LEAD + rng.randf() * SPAN
		if isl.hv(q) > 0.3 and safe.call(q, BOMB_SAFE):
			bombs.append([at, q])
	return [mid, bombs]


## Eruption k on this screen: the rumble, then its bombs.
func erupt(k: int) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null or p.global_position.distance_to(isl.global_position) > float(isl.radius) + NEAR:
		return
	var pl := plan(k)
	var cone: Dictionary = isl.land_plan["cone"]
	var cc: Vector2 = cone["c"]
	var top: Vector3 = isl.to_global(Vector3(cc.x, isl.hv(cc) + float(cone["depth"]) + 4.0, cc.y))
	CombatManager.apply_camera_shake(0.45, 2.4)
	var snd := AudioStreamPlayer.new()
	snd.stream = load("res://assets/audio/volcano_rumble.wav")
	snd.bus = "SFX"
	snd.volume_db = -2.0
	add_child(snd)
	snd.play()
	snd.finished.connect(snd.queue_free)
	FX.embers(top, Vector3.UP, 40, Color(1.0, 0.45, 0.12), 14.0)
	FX.dust_ring(top, 30, 6.0)
	for b in pl[1]:
		var q: Vector2 = b[1]
		var land: float = b[0]
		_queue.append([land - TELL, func(): _warn(q)])
		_queue.append([land - FALL, func(): _fall(top, q)])
		_queue.append([land, func(): _land(q)])


func _ground(q: Vector2) -> Vector3:
	return isl.to_global(Vector3(q.x, isl.hv(q), q.y))


## A bomb's warning: the shared telegraph, and under it a red circle laid on the ground (it follows a slope, where the
## flat telegraph sinks in) with a bright rim and a fill growing from its middle to the rim as the bomb comes.
func _warn(q: Vector2) -> void:
	FX.telegraph(_ground(q), R, TELL, Color(1.0, 0.2, 0.08))
	var node := Node3D.new()
	add_child(node)
	node.global_position = _ground(q)
	var rim := MeshInstance3D.new()
	rim.mesh = _disc(q, R, R - 0.35)
	rim.material_override = _warn_mat(Color(1.0, 0.22, 0.06, 0.95))
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(rim)
	var fill := MeshInstance3D.new()
	fill.mesh = _disc(q, R - 0.35, 0.0)
	fill.material_override = _warn_mat(Color(1.0, 0.3, 0.1, 0.4))
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(fill)
	fill.scale = Vector3(0.05, 1.0, 0.05)
	var tw := node.create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(fill, "scale", Vector3.ONE, TELL)
	tw.tween_callback(node.queue_free)


## A ring (or a disc, r0 = 0) round island point q laid on the ground, in a node at the ground there (the fill's
## scaling about its middle keeps it on the ground near enough for a moment's warning).
func _disc(q: Vector2, r1: float, r0: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y0: float = isl.hv(q)
	var n := 20
	var y := func(a: float, r: float) -> Vector3:
		var p := q + Vector2.from_angle(a) * r
		return Vector3(cos(a) * r, float(isl.hv(p)) - y0 + 0.15, sin(a) * r)
	for i in range(n):
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var o0: Vector3 = y.call(a0, r1)
		var o1: Vector3 = y.call(a1, r1)
		var i0: Vector3 = y.call(a0, r0)
		var i1: Vector3 = y.call(a1, r0)
		for v in [i0, o1, o0, i0, i1, o1]:
			st.add_vertex(v)
	return st.commit()


static var _warn_mats := {}


func _warn_mat(c: Color) -> StandardMaterial3D:
	if not _warn_mats.has(c):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = c
		_warn_mats[c] = m
	return _warn_mats[c]


## The bomb on its way down: a glowing lump falling in an arc from over the cone onto its spot.
func _fall(from: Vector3, q: Vector2) -> void:
	if _bomb_mesh == null:
		var mb := MeshBuilder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		mb.add_blob(PSXMat.glow(Color(1.0, 0.45, 0.1), 3.0, "volcanic_lava"), Transform3D.IDENTITY, Vector3(1.1, 0.95, 1.1), rng, 0.3, 3, 6)
		_bomb_mesh = mb.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _bomb_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var to := _ground(q)
	var start := to.lerp(from, 0.35) + Vector3.UP * 30.0
	mi.global_position = start
	var tw := mi.create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_method(func(u: float): mi.global_position = start.lerp(to, u) + Vector3.UP * sin(u * PI) * 6.0, 0.0, 1.0, FALL)
	tw.tween_callback(mi.queue_free)


func _land(q: Vector2) -> void:
	var at := _ground(q)
	FX.embers(at + Vector3.UP * 0.3, Vector3.UP, 20, Color(1.0, 0.5, 0.12), 8.0)
	FX.dust_ring(at, 14, 1.4)
	FX.sfx("lava_bomb", at, 2.0, 0.1)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or not p.is_local:
		return
	var d := Vector2(p.global_position.x - at.x, p.global_position.z - at.z)
	if d.length() < R and p.global_position.y < at.y + 2.5:
		p.health_component.take_damage(DAMAGE)
		p.velocity = Vector3(d.x, 0, d.y).normalized() * 6.0 + Vector3.UP * 8.0 if d.length() > 0.1 else Vector3.UP * 8.0
		CombatManager.apply_camera_shake(0.3, 0.3)
