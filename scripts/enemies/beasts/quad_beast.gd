class_name QuadBeast
extends JungleBeast
## A four-legged beast's body and gait (the stalker, the alpha boar, the roaming
## behemoth): rigid PS1 parts on a rig of joints, proportions from _spec().
## Rig (model space, -z forward): Body at the hip height; Chest and Hips under it;
## Neck -> Head -> Jaw off the chest; a leg at each corner (Upper -> Knee -> paw);
## a tail of four links. Every frame _animate trots or gallops the legs by speed
## and lays the kind's pose on top: `pose` keys crouch, rear, head (pitch), jaw,
## stretch, tail, spin (0..1 or radians), set by the kind's moves.

## kind -> its body: hip_h, len, chest_r, hip_r, neck (Vector3 from the chest),
## head (Vector3 half sizes), snout, tail, tail_r, coat, under, mark, tex.
## Optional (1.20's rig, docs/v1_20_beasts.md; each defaults to the body as it was):
##   front_h    the shoulders' height (hip_h): a bear's stand higher, a hyena's lower
##   hump       0..1 the shoulders raised and filled out (a bear's, a bison's)
##   leg_k      the legs' thickness (1); front_k the front legs' on top of that (1)
##   foot       "paw" | "pad" (a broad flat bear's) | "hoof" | "claw" (a lizard's splayed toes)
##   sprawl     0..1 the legs set out to the sides and angled (a lizard's)
##   tail_kind  "long" | "stub" (a short blob) | "tuft" (a tassel at the end)
##   gait       "trot" | "lumber" (heavy: the shoulders roll, the head sways) | "bound" (a cat's)
## Every kind pitches its body to the ground under its front and back feet (slopes: SLOPE_EVERY).
var spec := {}
var pose := {}
var rig := {}
var _parts := {}
var _legs: Array = []
var _tail: Array = []
var _gait: float = 0.0
var _last := Vector3.ZERO
var _spd: float = 0.0
var _eye_mi: MeshInstance3D
var _skin_mis: Array = []


func _spec() -> Dictionary:
	return {}


## The kind's own bits on the rig (spots, tusks, horns, a mane...): mb(node) gives a part's builder.
func _extras() -> void:
	pass


func mb(node: String) -> MeshBuilder:
	var n: Node3D = rig[node]
	if not _parts.has(n):
		_parts[n] = MeshBuilder.new()
	return _parts[n]


## The model's geometry ahead of time, off the main thread (GenIsland.prepare's worker): the rig (plain nodes) and every
## part's MeshBuilder, painted, keyed by the shared materials. Nothing for the servers: _build commits it in the world.
func prebuild() -> void:
	model = Node3D.new()
	model.name = "Model"
	_geometry()


func _build() -> void:
	if spec.is_empty():
		_geometry()
	var hh: float = spec["hip_h"]
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = maxf(float(spec["chest_r"]), 0.4)
	cap.height = maxf(hh + float(spec["chest_r"]), cap.radius * 2.0)
	col.shape = cap
	col.position = Vector3(0, cap.height * 0.5, 0)
	add_child(col)
	var shared_coat: Material = spec["coat_mat"]
	var shared_bare: Material = spec["bare_mat"]
	var coat := own(shared_coat)
	var bare := own(shared_bare)
	spec["coat_mat"] = coat
	spec["bare_mat"] = bare
	_eye_mi = _eye_mb.to_instance("Eyes")
	(rig["Head"] as Node3D).add_child(_eye_mi)
	for n in _parts.keys():
		var part: MeshBuilder = _parts[n]
		part.rekey(shared_coat, coat)
		part.rekey(shared_bare, bare)
		var mi := part.to_instance("Mesh")
		(n as Node3D).add_child(mi)
		_skin_mis.append(mi)
	_last = global_position


var _eye_mb: MeshBuilder


func _geometry() -> void:
	spec = _spec()
	var hh: float = spec["hip_h"]
	var ln: float = spec["len"]
	var coat := PSXMat.lit(str(spec["tex"]), Color(1.15, 1.15, 1.15))
	var bare := PSXMat.lit("leather", Color(1.0, 1.0, 1.0))
	var eye := PSXMat.glow(spec.get("eye", Color(1.0, 0.75, 0.15)), 2.6)
	spec["coat_mat"] = coat
	spec["bare_mat"] = bare
	# the shoulders' height over the hips' (front_h), the hump over them
	var lift: float = float(spec.get("front_h", hh)) - hh
	var hump: float = float(spec.get("hump", 0.0))
	var sprawl: float = float(spec.get("sprawl", 0.0))
	_node("Body", Vector3(0, hh, 0), model)
	_node("Chest", Vector3(0, lift, -ln * 0.5), rig["Body"])
	_node("Hips", Vector3(0, 0, ln * 0.5), rig["Body"])
	_node("Neck", Vector3(0, float(spec["chest_r"]) * 0.4, -float(spec["chest_r"]) * 0.6), rig["Chest"])
	_node("Head", spec["neck"], rig["Neck"])
	var hd: Vector3 = spec["head"]
	_node("Jaw", Vector3(0, -hd.y * 0.45, -hd.z * 0.1), rig["Head"])
	for c in [["FL", -1.0, "Chest"], ["FR", 1.0, "Chest"], ["BL", -1.0, "Hips"], ["BR", 1.0, "Hips"]]:
		var front: bool = c[2] == "Chest"
		# (a front leg is as long as the shoulders are high; a sprawled one reaches out and down)
		var lh: float = (hh + lift) if front else hh
		var up: float = lh * 0.52
		var lo: float = lh * 0.5
		var r: float = float(spec["chest_r"] if front else spec["hip_r"]) * 0.62 * (1.0 + sprawl * 0.8)
		var leg := _node("Leg" + c[0], Vector3(float(c[1]) * r, -0.05, 0), rig[c[2]])
		leg.rotation.z = float(c[1]) * sprawl * 0.7
		var knee := _node("Knee" + c[0], Vector3(0, -up, 0), leg)
		knee.rotation.z = -float(c[1]) * sprawl * 0.9
		_legs.append([leg, knee, front, float(c[1])])
		var thick: float = float(spec["chest_r"] if front else spec["hip_r"]) * 0.36 * float(spec.get("leg_k", 1.0)) * (float(spec.get("front_k", 1.0)) if front else 1.0)
		mb("Leg" + c[0]).add_cylinder(coat, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 0.1, 0)), thick * 1.25, thick * 0.8, up + 0.1, 6, 1.0, Color.WHITE, true, true, true)
		mb("Knee" + c[0]).add_cylinder(coat, Transform3D(Basis(Vector3.RIGHT, PI), Vector3.ZERO), thick * 0.8, thick * 0.6, lo - 0.04, 6, 1.0, Color(0.9, 0.9, 0.9), true, true, true)
		_foot("Knee" + c[0], str(spec.get("foot", "paw")), lo, thick, coat)
	# the torso: a loft from the haunches to the shoulders (the front rings up with the shoulders, fuller with a hump)
	var cr: float = spec["chest_r"]
	var hr: float = spec["hip_r"]
	var rings := [[-ln * 0.5 - cr * 0.85, cr * 0.5, cr * 0.55, -lift], [-ln * 0.5 - cr * 0.4, cr * 0.95, cr * (1.0 + hump * 0.2), 0.05 - lift - hump * cr * 0.2],
		[-ln * 0.5 + cr * 0.3, cr, cr * (1.05 + hump * 0.3), -lift * 0.8 - hump * cr * 0.3],
		[0.0, (cr + hr) * 0.42, (cr + hr) * 0.44 * (1.0 + hump * 0.15), -0.04 * ln - lift * 0.45 - hump * cr * 0.1], [ln * 0.5 - hr * 0.2, hr, hr, 0.0], [ln * 0.5 + hr * 0.55, hr * 0.85, hr * 0.8, 0.02], [ln * 0.5 + hr * 0.95, hr * 0.35, hr * 0.35, 0.0]]
	mb("Body").add_loft(coat, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), rings, MeshBuilder.profile_circle(10), 0.9, Color.WHITE, true, true)
	# neck and head
	var nk: Vector3 = spec["neck"]
	mb("Neck").add_tube(coat, PackedVector3Array([Vector3(0, -cr * 0.3, cr * 0.4), nk * 0.5, nk]), cr * 0.62, hd.x * 0.75, 7, 1.0)
	var sn: float = spec["snout"]
	mb("Head").add_blob(coat, Transform3D(Basis(), Vector3(0, 0, 0)), hd, _rng_fixed(), 0.08, 4, 8, 1.0)
	mb("Head").add_blob(coat, Transform3D(Basis(), Vector3(0, -hd.y * 0.15, -hd.z * 0.9 - sn * 0.4)), Vector3(hd.x * 0.62, hd.y * 0.55, sn * 0.6), _rng_fixed(), 0.06, 3, 7, 1.0)
	mb("Head").add_blob(bare, Transform3D(Basis(), Vector3(0, -hd.y * 0.05, -hd.z * 0.9 - sn * 0.95)), Vector3(hd.x * 0.3, hd.y * 0.22, hd.x * 0.16), _rng_fixed(), 0.05, 3, 6, 1.0, Color(0.25, 0.2, 0.2))
	mb("Jaw").add_blob(coat, Transform3D(Basis(), Vector3(0, -hd.y * 0.12, -hd.z * 0.7 - sn * 0.35)), Vector3(hd.x * 0.5, hd.y * 0.22, sn * 0.62 + hd.z * 0.25), _rng_fixed(), 0.05, 3, 7, 1.0, Color(0.9, 0.9, 0.9))
	var em := MeshBuilder.new()
	for s in [-1.0, 1.0]:
		em.add_box(eye, Transform3D(Basis(Vector3.UP, s * 0.35), Vector3(s * hd.x * 0.62, hd.y * 0.25, -hd.z * 0.72)), Vector3(hd.x * 0.16, hd.y * 0.13, hd.x * 0.1), 1.0)
		mb("Head").add_cylinder(coat, Transform3D(Basis(Vector3.FORWARD, s * 0.35), Vector3(s * hd.x * 0.55, hd.y * 0.75, hd.z * 0.15)), hd.x * 0.2, 0.02, hd.y * float(spec.get("ears", 0.6)), 4, 1.0, Color(0.85, 0.85, 0.85))
	_eye_mb = em
	# the tail: four links (a stub: one short blob; a tuft: a tassel on the last link)
	var parent: Node3D = rig["Hips"]
	var tk := str(spec.get("tail_kind", "long"))
	var links := 1 if tk == "stub" else 4
	var tl: float = float(spec["tail"]) / float(links)
	var at := Vector3(0, hr * 0.4, hr * 0.9)
	for i in range(links):
		var link := _node("Tail%d" % i, at, parent)
		_tail.append(link)
		var tr: float = float(spec["tail_r"]) * (1.0 - i * 0.18)
		if tk == "stub":
			mb("Tail%d" % i).add_blob(coat, Transform3D(Basis(), Vector3(0, 0, tl * 0.4)), Vector3(tr * 1.6, tr * 1.4, maxf(tl * 0.6, tr * 1.2)), _rng_fixed(), 0.15, 3, 6, 1.0, Color(0.95, 0.95, 0.95))
		else:
			mb("Tail%d" % i).add_cylinder(coat, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), tr, tr * 0.82, tl + 0.02, 5, 1.0, Color(0.95, 0.95, 0.95), true, true, true)
		if tk == "tuft" and i == links - 1:
			mb("Tail%d" % i).add_blob(coat, Transform3D(Basis(), Vector3(0, 0, tl + tr * 1.5)), Vector3(tr * 2.2, tr * 2.2, tr * 3.2), _rng_fixed(), 0.3, 3, 6, 1.0, Color(0.55, 0.55, 0.55))
		parent = link
		at = Vector3(0, 0, tl)
	_extras()
	for n in _parts.keys():
		_paint(_parts[n], coat)


## The foot at the end of a lower leg (`lo` long, `thick` its width): a paw (as it was), a bear's broad pad, a hoof,
## a lizard's splayed claws.
func _foot(knee: String, kind: String, lo: float, thick: float, coat: Material) -> void:
	var at := Vector3(0, -lo + thick * 0.4, -thick * 0.5)
	match kind:
		"pad":
			mb(knee).add_blob(coat, Transform3D(Basis(), at + Vector3(0, -thick * 0.1, -thick * 0.15)), Vector3(thick * 1.25, thick * 0.55, thick * 1.7), _rng_fixed(), 0.08, 3, 7, 1.0, Color(0.8, 0.8, 0.8), 0.0)
		"hoof":
			var horn := PSXMat.flat(Color(0.14, 0.11, 0.09))
			mb(knee).add_cylinder(horn, Transform3D(Basis(), Vector3(0, -lo + thick * 0.3, 0)), thick * 0.75, thick * 0.9, thick * 0.6, 6, 1.0, Color.WHITE, true, true, false)
		"claw":
			var nail := PSXMat.flat(Color(0.2, 0.17, 0.12))
			mb(knee).add_blob(coat, Transform3D(Basis(), at), Vector3(thick * 1.1, thick * 0.45, thick * 1.2), _rng_fixed(), 0.08, 3, 6, 1.0, Color(0.85, 0.85, 0.85), 0.0)
			for k in range(3):
				var a := (k - 1) * 0.5
				mb(knee).add_cylinder(nail, Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -1.45), at + Vector3(sin(a) * thick * 0.8, -thick * 0.1, -cos(a) * thick * 0.9)), thick * 0.18, 0.0, thick * 0.9, 3, 1.0, Color.WHITE, false, false, false)
		_:
			mb(knee).add_blob(coat, Transform3D(Basis(), at), Vector3(thick * 0.95, thick * 0.6, thick * 1.4), _rng_fixed(), 0.1, 3, 6, 1.0, Color(0.85, 0.85, 0.85), 0.0)


func _node(n: String, pos: Vector3, parent: Node3D) -> Node3D:
	var x := Node3D.new()
	x.name = n
	x.position = pos
	parent.add_child(x)
	rig[n] = x
	return x


func _rng_fixed() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 4417 + variant
	return r


## The coat's colours by height in the body: the back's, the belly's, the kind's own marks (_mark).
func _paint(part: MeshBuilder, coat: Material) -> void:
	if not part._surfaces.has(coat):
		return
	var v: PackedVector3Array = part._surfaces[coat]["v"]
	var c: PackedColorArray = part._surfaces[coat]["c"]
	for i in range(v.size()):
		c[i] = _coat_at(v[i]) * c[i].r
	part._surfaces[coat]["c"] = c


func _coat_at(p: Vector3) -> Color:
	return (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.6, p.y / maxf(float(spec["chest_r"]), 0.1)))


## Only its eyes showing (lying up in the brush), or the whole of it.
func eyes_only(on: bool) -> void:
	for mi in _skin_mis:
		(mi as MeshInstance3D).visible = not on
	_eye_mi.visible = true


func _pose(k: String) -> float:
	return float(pose.get(k, 0.0))


func _animate(delta: float) -> void:
	var moved := _flat(global_position - _last)
	_last = global_position
	_spd = lerpf(_spd, moved.length() / maxf(delta, 0.001), minf(delta * 8.0, 1.0))
	_pose_for(delta)
	_tw += delta
	_slope(delta)
	var hh: float = spec["hip_h"]
	var gait := str(spec.get("gait", "trot"))
	var lumber := gait == "lumber"
	var run := clampf(_spd / 7.0, 0.0, 1.4)
	# (a heavy beast's steps come slower and longer; a cat bounds from a lower speed)
	_gait += delta * (2.0 + _spd * 0.62) * (0.78 if lumber else 1.0)
	var amp := clampf(_spd / 3.0, 0.0, 1.0) * (0.5 + 0.25 * minf(run, 1.0))
	var gallop := run > (0.6 if gait == "bound" else 0.9)
	var crouch := _pose("crouch")
	var body: Node3D = rig["Body"]
	var by := hh * (1.0 - crouch * 0.38) + absf(sin(_gait * 2.0)) * 0.05 * hh * amp * (1.6 if lumber else 1.0)
	body.position.y = lerpf(body.position.y, by, minf(delta * 14.0, 1.0))
	body.rotation.x = lerp_angle(body.rotation.x, _pose("rear") * 0.7 - crouch * 0.05 + (sin(_gait * 2.0) * 0.05 * amp if gallop else 0.0), minf(delta * 10.0, 1.0))
	# (lumbering: the shoulders roll side to side with each step, the head swaying against them)
	body.rotation.z = lerp_angle(body.rotation.z, sin(_gait) * (0.09 if lumber else 0.03) * amp, minf(delta * 8.0, 1.0))
	(rig["Neck"] as Node3D).rotation.y = lerp_angle((rig["Neck"] as Node3D).rotation.y, -sin(_gait) * 0.14 * amp if lumber else 0.0, minf(delta * 6.0, 1.0))
	model.scale = Vector3(1, 1, 1.0 + _pose("stretch") * 0.18)
	for l in _legs:
		var leg: Node3D = l[0]
		var knee: Node3D = l[1]
		var front: bool = l[2]
		var off := 0.0 if (front == (float(l[3]) < 0.0)) else PI
		if gallop:
			off = (0.0 if front else PI) + (0.35 if float(l[3]) > 0.0 else 0.0)
		var s := sin(_gait + off)
		var swing := s * amp * 0.85
		var bend := maxf(0.0, cos(_gait + off)) * amp * 0.9
		if front:
			swing -= _pose("rear") * 0.9
			bend += crouch * 0.9
		else:
			swing += crouch * 0.5
			bend += crouch * 1.1
		leg.rotation.x = lerp_angle(leg.rotation.x, swing + (crouch * 0.4 if front else -crouch * 0.6), minf(delta * 16.0, 1.0))
		knee.rotation.x = lerp_angle(knee.rotation.x, (-bend if front else bend), minf(delta * 16.0, 1.0))
	var head: Node3D = rig["Head"]
	head.rotation.x = lerp_angle(head.rotation.x, _pose("head"), minf(delta * 10.0, 1.0))
	(rig["Jaw"] as Node3D).rotation.x = lerp_angle((rig["Jaw"] as Node3D).rotation.x, -_pose("jaw") * 0.65, minf(delta * 16.0, 1.0))
	for i in range(_tail.size()):
		var tl: Node3D = _tail[i]
		tl.rotation.y = sin(_tw * 2.1 - i * 0.7) * (0.18 + _pose("tail") * 0.5)
		tl.rotation.x = (-0.25 + _pose("tail") * 0.2) if i == 0 else 0.15


var _tw: float = 0.0
## The ground's pitch under it, looked at this often (two rays: under the shoulders and under the hips).
const SLOPE_EVERY := 0.12
const SLOPE_MAX := 0.6
var _slope_t := 0.0
var _slope_want := 0.0


## Pitched to the ground it stands on: up a rise nose up, down a slope nose down (not floating off a ridge).
func _slope(delta: float) -> void:
	_slope_t -= delta
	if _slope_t <= 0.0 and is_inside_tree():
		_slope_t = SLOPE_EVERY
		var half := float(spec["len"]) * 0.5 + float(spec["chest_r"]) * 0.3
		var fwd := -model.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
		var yf := _ground_y(global_position + fwd * half)
		var yb := _ground_y(global_position - fwd * half)
		_slope_want = 0.0 if is_nan(yf) or is_nan(yb) else clampf(atan2(yf - yb, half * 2.0), -SLOPE_MAX, SLOPE_MAX)
	if state == S.DEAD:
		_slope_want = 0.0
	model.rotation.x = lerp_angle(model.rotation.x, _slope_want, minf(delta * 6.0, 1.0))


func _ground_y(at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 4.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return float(hit["position"].y) if not hit.is_empty() else NAN


## The kind's pose for what it's doing (host and puppets read the same move/state/mv_t).
func _pose_for(_delta: float) -> void:
	pose = {}
	if state == S.STAGGER:
		pose = {"crouch": 0.6, "head": -0.3, "jaw": 0.5}
	elif state == S.DEAD:
		pose = {"crouch": 1.0, "head": -0.4, "jaw": 0.7}
	elif state == S.SLEEP:
		pose = {"crouch": 0.85, "head": -0.25}
