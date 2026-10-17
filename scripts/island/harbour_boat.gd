extends AnimatableBody3D
## A Brinehollow fishing smack that goes out (BrinehollowHarbour): moored bow-out at the quay wall until its
## hour, then out along its course (straight off the wall, turning away from the sloop's lane) to its ground off
## the coast, drifting there while its fisher works, and home in the afternoon. Where it is follows Weather.hour
## (the same on every screen); it rides the swell near a camera and checks in once a second far off.

## [leave the wall, reach the ground, leave the ground, back at the wall] by hour, per boat
const SCHEDULE := [[5.4, 6.4, 14.6, 15.8], [6.0, 7.0, 16.0, 17.2]]
const CREW := ["Hob Tarrant", "Marrin Sedge"]
const OUT := 170.0
const FREEBOARD := 0.15
const HALF_LEN := 2.4
const HEAVE := 0.7
const NEAR := 150.0
const DRIFT_R := 5.0

var isl: StarterIsland
var home: Vector2
var face: Vector2
var route := PackedVector2Array()
var cum := PackedFloat32Array()
var times: Array = []
var index := 0
var sail: Node3D
var furled: Node3D
var crew: Humanoid
var _far_t := 0.0


## The crew's looks (BrinehollowCast builds their bodies ahead).
static func crew_look(i: int) -> Dictionary:
	return KitLife.look_for(CREW[i])


func setup(island: StarterIsland, at: Vector2, out_dir: Vector2, i: int) -> void:
	isl = island
	home = at
	face = out_dir
	index = i
	times = SCHEDULE[i]
	var h := isl.harbour
	var away := signf(h.s_of(at) - h.s_of(h.dock))
	route = PackedVector2Array([at, at + out_dir * 14.0, at + out_dir * 60.0 + h.along * away * 15.0, at + out_dir * OUT + h.along * away * 45.0])
	cum = KitLife.measure(route)
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	TraderShips.longboat(self)
	furled = rig(false)
	sail = rig(true)
	add_child(furled)
	add_child(sail)
	crew = Humanoid.make(crew_look(i))
	crew.lod = true
	crew.seated = true
	crew.seat_y = 0.3
	crew.position = Vector3(0, -0.05, 1.6)
	add_child(crew)
	position = Vector3(at.x, FREEBOARD, at.y)
	rotation.y = KitContext.face_yaw(-out_dir)


## [point, heading, out at sea] at `hour`.
func where(hour: float) -> Array:
	var t: Array = times
	var total := cum[cum.size() - 1]
	if hour >= t[0] and hour < t[1]:
		var smp := KitLife.sample(route, cum, total * smoothstep(0.0, 1.0, (hour - t[0]) / (t[1] - t[0])))
		return [smp[0], smp[1], true]
	if hour >= t[1] and hour < t[2]:
		var a := float(Weather.world_time()) * 0.012 + index * 2.0
		var ground := route[route.size() - 1]
		return [ground + Vector2(cos(a), sin(a)) * DRIFT_R, Vector2(-sin(a), cos(a)), true]
	if hour >= t[2] and hour < t[3]:
		var smp := KitLife.sample(route, cum, total * (1.0 - smoothstep(0.0, 1.0, (hour - t[2]) / (t[3] - t[2]))))
		return [smp[0], -smp[1], true]
	return [home, face, false]


func _physics_process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var near := cam != null and cam.global_position.distance_to(global_position) < NEAR
	if not near:
		_far_t -= delta
		if _far_t > 0.0:
			return
		_far_t = 1.0
	var w := where(Weather.hour())
	var p: Vector2 = w[0]
	var fwd := Vector3(w[1].x, 0, w[1].y).normalized()
	var at := Vector3(p.x, 0, p.y)
	var y := FREEBOARD
	var pitch := 0.0
	if near:
		var g := isl.to_global(at)
		var gf := isl.global_basis * fwd
		var hb := Ocean.get_wave_height(g + gf * HALF_LEN)
		var hs := Ocean.get_wave_height(g - gf * HALF_LEN)
		y += (hb + hs + Ocean.get_wave_height(g)) / 3.0 * HEAVE
		pitch = atan2(hb - hs, HALF_LEN * 2.0) * 0.6
	transform = Transform3D(Basis(Vector3.UP, atan2(-fwd.x, -fwd.z)) * Basis(Vector3.RIGHT, pitch), at + Vector3(0, y, 0))
	if not near:
		reset_physics_interpolation()
	if sail.visible != w[2]:
		sail.visible = w[2]
		furled.visible = not w[2]
		crew.visible = w[2]


## A smack's rig on a longboat (bow -Z): a mast forward with its yard, the lug sail set or furled on the yard, a
## heap of net in the stern.
static func rig(set_sail: bool) -> MeshInstance3D:
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("bark")
	var canvas := PSXMat.lit("fabric", Color(0.86, 0.78, 0.6), {"affine": 0.6})
	var top := 4.2
	mb.add_cylinder(wood, Transform3D(Basis(), Vector3(0, 0.25, -1.0)), 0.07, 0.05, top - 0.25, 6, 1.0)
	var yard_y := top - 0.3
	if set_sail:
		mb.add_tube(wood, PackedVector3Array([Vector3(-1.1, yard_y + 0.35, -1.1), Vector3(1.0, yard_y - 0.2, -1.1)]), 0.04, -1.0, 4)
		var a := Vector3(-1.1, yard_y + 0.35, -1.05)
		var b := Vector3(1.0, yard_y - 0.2, -1.05)
		var c := Vector3(1.2, 0.9, -0.95)
		var d := Vector3(-1.0, 0.9, -0.95)
		mb.add_quad(canvas, a, b, c, d, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, Vector3.BACK)
		mb.add_quad(canvas, a, d, c, b, Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Color(0.75, 0.75, 0.75), Vector3.FORWARD)
	else:
		mb.add_cylinder(canvas, Transform3D(Basis(Vector3.BACK, PI * 0.5 - 0.25), Vector3(0.97, yard_y - 0.12, -1.05)), 0.12, 0.12, 2.0, 6, 1.0, Color.WHITE, true, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	mb.add_blob(PSXMat.lit("rope", Color(0.7, 0.75, 0.65)), Transform3D(Basis(), Vector3(0, 0.15, 2.0)), Vector3(0.5, 0.18, 0.4), rng, 0.2, 2, 6, 1.0)
	var mi := mb.to_instance("Sail" if set_sail else "Furled")
	mi.visibility_range_end = 700.0
	return mi
