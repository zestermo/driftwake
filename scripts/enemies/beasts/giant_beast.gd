class_name GiantBeast
extends JungleBeast
## A two-legged giant's body and gait (1.20, docs/v1_20_beasts.md: the ice golem, the elder treant): rigid PS1 parts
## on a rig of joints, proportions from _spec(). Rig (model space, -z forward): Hips at the hip height; Torso over it
## -> Head; at each shoulder Arm -> Elbow -> Hand; at each hip Thigh -> Knee -> Foot. Every frame _animate walks the
## legs by speed (heavy steps, the torso swaying over them, the arms swinging against them) and lays the kind's pose
## on top: `pose` keys set by its moves -
##   arms_up   0..1 both arms raised overhead (a slam's wind-up)
##   wind      0..1 the right arm drawn back (a swing's wind-up); swing 0..1 it through
##   reach     0..1 both arms forward and down (hands to the ground)
##   lean      radians, the torso pitched forward (+) or back (-)
##   crouch    0..1 the knees bent, the body down
##   twist     radians, the torso turned (+ left)
##   hug       0..1 the arms wrapped round the chest
##   slump     0..1 collapsed (rubble, a dead tree)
## Fair melee (docs/v1_20_beasts.md "Rules", in JungleBeast for every beast): hits while it's getting over a move count double toward a
## stagger; a move never runs twice in a row (pick()).

## spec: hip_h, torso (half sizes), shoulder (half width), arm (upper, lower), arm_r, hand_r, leg_r, head (half sizes),
## coat, under, mark, tex, eye. A kind adds its own parts in _extras() (mb(node) gives a part's builder).
var spec := {}
var pose := {}
var rig := {}
var _parts := {}
var _gait: float = 0.0
var _last := Vector3.ZERO
var _spd: float = 0.0
var _coat: ShaderMaterial


func _spec() -> Dictionary:
	return {}


func _extras() -> void:
	pass


func mb(node: String) -> MeshBuilder:
	var n: Node3D = rig[node]
	if not _parts.has(n):
		_parts[n] = MeshBuilder.new()
	return _parts[n]


func _node(n: String, pos: Vector3, parent: Node3D) -> Node3D:
	var x := Node3D.new()
	x.name = n
	x.position = pos
	parent.add_child(x)
	rig[n] = x
	return x


func _rng_fixed() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 5113 + variant
	return r


func _build() -> void:
	spec = _spec()
	var hh: float = spec["hip_h"]
	var to: Vector3 = spec["torso"]
	var shared := PSXMat.lit(str(spec["tex"]), Color(1.1, 1.1, 1.1))
	_coat = own(shared)
	spec["coat_mat"] = _coat
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = maxf(to.x, to.z) * 0.9
	cap.height = hh + to.y * 2.0
	col.shape = cap
	col.position = Vector3(0, cap.height * 0.5, 0)
	add_child(col)
	_node("Hips", Vector3(0, hh, 0), model)
	_node("Torso", Vector3(0, 0.05, 0), rig["Hips"])
	var hd: Vector3 = spec["head"]
	_node("Head", Vector3(0, to.y * 2.0 + hd.y * 0.6, -to.z * 0.2), rig["Torso"])
	var sw: float = spec["shoulder"]
	var arm: Vector2 = spec["arm"]
	var ar: float = spec["arm_r"]
	for s in [["L", -1.0], ["R", 1.0]]:
		var side: float = s[1]
		var a := _node("Arm" + s[0], Vector3(side * sw, to.y * 1.75, 0), rig["Torso"])
		var e := _node("Elbow" + s[0], Vector3(0, -arm.x, 0), a)
		_node("Hand" + s[0], Vector3(0, -arm.y, 0), e)
		mb("Arm" + s[0]).add_blob(_coat, Transform3D(), Vector3.ONE * ar * 1.25, _rng_fixed(), 0.08, 3, 6, 1.0)
		mb("Arm" + s[0]).add_cylinder(_coat, Transform3D(Basis(Vector3.RIGHT, PI), Vector3.ZERO), ar, ar * 0.85, arm.x, 6, 1.0, Color.WHITE, true, true, true)
		mb("Elbow" + s[0]).add_blob(_coat, Transform3D(), Vector3.ONE * ar * 0.95, _rng_fixed(), 0.06, 3, 6, 1.0, Color(0.95, 0.95, 0.95))
		mb("Elbow" + s[0]).add_cylinder(_coat, Transform3D(Basis(Vector3.RIGHT, PI), Vector3.ZERO), ar * 0.9, ar * 0.8, arm.y, 6, 1.0, Color(0.92, 0.92, 0.92), true, true, true)
		mb("Hand" + s[0]).add_blob(_coat, Transform3D(Basis(), Vector3(0, -float(spec["hand_r"]) * 0.6, 0)), Vector3.ONE * float(spec["hand_r"]), _rng_fixed(), 0.12, 3, 7, 1.0, Color(0.9, 0.9, 0.9))
		var lr: float = spec["leg_r"]
		var th := _node("Thigh" + s[0], Vector3(side * to.x * 0.55, 0, 0), rig["Hips"])
		var kn := _node("Knee" + s[0], Vector3(0, -hh * 0.5, 0), th)
		_node("Foot" + s[0], Vector3(0, -hh * 0.5, 0), kn)
		mb("Thigh" + s[0]).add_cylinder(_coat, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 0.1, 0)), lr, lr * 0.85, hh * 0.5 + 0.1, 6, 1.0, Color.WHITE, true, true, true)
		mb("Knee" + s[0]).add_blob(_coat, Transform3D(), Vector3.ONE * lr * 0.95, _rng_fixed(), 0.06, 3, 6, 1.0, Color(0.95, 0.95, 0.95))
		mb("Knee" + s[0]).add_cylinder(_coat, Transform3D(Basis(Vector3.RIGHT, PI), Vector3.ZERO), lr * 0.85, lr * 0.75, hh * 0.5, 6, 1.0, Color(0.9, 0.9, 0.9), true, true, true)
		mb("Foot" + s[0]).add_blob(_coat, Transform3D(Basis(), Vector3(0, lr * 0.2, -lr * 0.35)), Vector3(lr * 1.05, lr * 0.5, lr * 1.5), _rng_fixed(), 0.08, 3, 6, 1.0, Color(0.85, 0.85, 0.85))
	mb("Torso").add_blob(_coat, Transform3D(Basis(), Vector3(0, to.y, 0)), to, _rng_fixed(), 0.1, 4, 8, 1.0)
	mb("Head").add_blob(_coat, Transform3D(), hd, _rng_fixed(), 0.1, 3, 7, 1.0)
	var eye := PSXMat.glow(spec.get("eye", Color(0.6, 0.9, 1.0)), 2.6)
	for s in [-1.0, 1.0]:
		mb("Head").add_box(eye, Transform3D(Basis(), Vector3(s * hd.x * 0.4, hd.y * 0.15, -hd.z * 0.9)), Vector3(hd.x * 0.2, hd.y * 0.14, 0.06), 1.0)
	_extras()
	for n in _parts.keys():
		var part: MeshBuilder = _parts[n]
		_paint(part)
		(n as Node3D).add_child(part.to_instance("Mesh"))
	_last = global_position


## The coat's colours by height (the back's, the belly's, the kind's own marks: _coat_at).
func _paint(part: MeshBuilder) -> void:
	if not part._surfaces.has(_coat):
		return
	var v: PackedVector3Array = part._surfaces[_coat]["v"]
	var c: PackedColorArray = part._surfaces[_coat]["c"]
	for i in range(v.size()):
		c[i] = _coat_at(v[i]) * c[i].r
	part._surfaces[_coat]["c"] = c


func _coat_at(_p: Vector3) -> Color:
	return spec["coat"]


func _pose(k: String) -> float:
	return float(pose.get(k, 0.0))


## The kind's pose for what it's doing (host and puppets read the same move/state/mv_t).
func _pose_for(_delta: float) -> void:
	pose = {}
	if state == S.STAGGER:
		pose = {"crouch": 0.5, "lean": 0.3, "reach": 0.3}
	elif state == S.DEAD:
		pose = {"slump": 1.0}
	elif state == S.SLEEP:
		pose = {"crouch": 0.15, "lean": 0.1}


func _animate(delta: float) -> void:
	var moved := _flat(global_position - _last)
	_last = global_position
	_spd = lerpf(_spd, moved.length() / maxf(delta, 0.001), minf(delta * 8.0, 1.0))
	_pose_for(delta)
	var k := minf(delta * 9.0, 1.0)
	var hh: float = spec["hip_h"]
	_gait += delta * (1.4 + _spd * 0.5)
	var amp := clampf(_spd / 3.0, 0.0, 1.0)
	var crouch := _pose("crouch")
	var slump := _pose("slump")
	var hips: Node3D = rig["Hips"]
	hips.position.y = lerpf(hips.position.y, hh * (1.0 - crouch * 0.25 - slump * 0.55) + absf(sin(_gait)) * 0.08 * hh * amp, k)
	hips.rotation.z = lerp_angle(hips.rotation.z, sin(_gait) * 0.06 * amp, k)
	var torso: Node3D = rig["Torso"]
	torso.rotation.x = lerp_angle(torso.rotation.x, -_pose("lean") - slump * 0.8 - 0.06 * amp, k)
	torso.rotation.y = lerp_angle(torso.rotation.y, _pose("twist") - sin(_gait) * 0.08 * amp, k)
	(rig["Head"] as Node3D).rotation.x = lerp_angle((rig["Head"] as Node3D).rotation.x, _pose("lean") * 0.5 - slump * 0.5, k)
	for s in [["L", -1.0], ["R", 1.0]]:
		var side: float = s[1]
		var step := sin(_gait + (0.0 if side < 0.0 else PI))
		var th: Node3D = rig["Thigh" + s[0]]
		var kn: Node3D = rig["Knee" + s[0]]
		th.rotation.x = lerp_angle(th.rotation.x, step * 0.55 * amp + crouch * 0.7 + slump * 1.2, k)
		kn.rotation.x = lerp_angle(kn.rotation.x, -maxf(0.0, -cos(_gait + (0.0 if side < 0.0 else PI))) * 0.9 * amp - crouch * 1.2 - slump * 1.6, k)
		var a: Node3D = rig["Arm" + s[0]]
		var e: Node3D = rig["Elbow" + s[0]]
		var right := side > 0.0
		var up := _pose("arms_up")
		var wind := _pose("wind") if right else 0.0
		var swing := _pose("swing") if right else 0.0
		var reach := _pose("reach")
		var hug := _pose("hug")
		# (the arms swing against the legs; a pose lifts, winds, reaches or wraps them)
		var ax := -step * 0.45 * amp + up * 2.9 + wind * 2.2 - swing * 1.2 + reach * 1.1 + hug * 1.2 - slump * 0.3
		var az := side * (0.12 + up * 0.25 + wind * 0.5 - hug * 0.45 + _pose("spread") * 1.1)
		a.rotation.x = lerp_angle(a.rotation.x, ax, k)
		a.rotation.z = lerp_angle(a.rotation.z, az, k)
		e.rotation.x = lerp_angle(e.rotation.x, 0.25 + up * 0.4 + wind * 1.1 + hug * 1.4 + reach * 0.3, k)


func _hit_point() -> Vector3:
	return global_position + Vector3(0, float(spec.get("hip_h", 2.0)) + (spec.get("torso", Vector3.ONE) as Vector3).y, 0)
