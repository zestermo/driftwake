class_name GadgetZone
extends Node3D
## What a thrown gadget leaves where it lands: a smoke cloud or a tar pool. Every screen makes its own (the throw
## arrives as the thrower's event); only the host's copy touches the foes, on a timer (TICK), never per frame.
##   smoke  a cloud: a foe caught in it staggers coughing once (blinded / stagger), and a captain inside can't be
##          noticed or attacked (veiled: Stealth and the grunts' target check ask it)
##   tar    a black pool: foes in it are slowed (slowed) while they stand in it

const TICK := 0.25
## How high above or below the zone's ground a captain or foe still counts as in it.
const REACH_Y := 2.5
const SMOKE_TINT := [Color(0.74, 0.73, 0.7, 0.9), Color(0.64, 0.68, 0.78, 0.92), Color(0.46, 0.42, 0.56, 0.94)]
const TAR := Color(0.035, 0.03, 0.028, 0.96)

## Every zone alive on this machine (the smoke also in GadgetVeil.clouds).
static var active: Array = []

var kind := ""
var tier := 0
var radius := 3.0
var secs := 6.0
var _hit: Dictionary = {}
var _emit: CPUParticles3D
var _pool: MeshInstance3D


static func spawn(tree: SceneTree, gid: String, t: int, at: Vector3) -> GadgetZone:
	var z := GadgetZone.new()
	z.kind = gid
	z.tier = t
	z.radius = float(GadgetData.tier_val(gid, "radius", t))
	z.secs = float(GadgetData.tier_val(gid, "secs", t))
	(tree.current_scene if tree.current_scene else tree.root).add_child(z)
	z.global_position = at
	return z


func inside(at: Vector3) -> bool:
	var d := at - global_position
	return absf(d.y) < REACH_Y and Vector2(d.x, d.z).length() < radius


func _ready() -> void:
	active.append(self)
	add_to_group("gadget_zones")
	match kind:
		"smoke":
			GadgetVeil.clouds.append(self)
			_smoke_burst()
		"tar":
			_tar_splash()
	var life := Timer.new()
	life.one_shot = true
	life.wait_time = secs
	life.timeout.connect(_end)
	add_child(life)
	life.start()
	if Net.is_host():
		var t := Timer.new()
		t.wait_time = TICK
		t.timeout.connect(_tick)
		add_child(t)
		t.start()


func _exit_tree() -> void:
	active.erase(self)
	GadgetVeil.clouds.erase(self)


func _smoke_burst() -> void:
	var col: Color = SMOKE_TINT[tier]
	var c := global_position + Vector3(0, 0.4, 0)
	FX.flash(c, 1.4 + 0.4 * tier, Color.WHITE, "dither_muzzle", 0.3)
	FX.flash_light(c, Color(1.0, 0.9, 0.75), 1.6, 5.0, 0.18)
	FX.puff_ring(global_position, "dust_low", 10 + 2 * tier, 0.4, 1.6 + 0.3 * tier, 1.0, col, 7.0 + tier)
	FX.plume(c, Vector3.UP, "smoke", 5 + tier * 2, radius * 0.8, 2.2, col, 3.0, 70.0)
	FX.sfx("fire_burst", c, -6.0 + 2.0 * tier, 0.1, 0.7)
	FX.sfx("hiss", c, -8.0, 0.1, 0.6)
	_emit = FX.flip_emitter(self, "smoke", 14 + 6 * tier, radius * 0.75, 2.6, {"radius": radius * 0.55, "spread": 180.0,
		"direction": Vector3.UP, "vel_min": 0.15, "vel_max": 0.6, "gravity": Vector3(0, 0.12, 0), "damping": 0.3,
		"start": 0.2, "spin": 20.0, "curve": "grow", "fade_in": 0.18, "fade": 0.55, "color": col, "range": 120.0})
	_emit.position = Vector3(0, radius * 0.3, 0)
	if tier == 2:
		FX.sparkle(c, 12, Color(0.75, 0.55, 1.0))


func _tar_splash() -> void:
	FX.puff_ring(global_position, "dust_low", 8, 0.3, 0.9, 0.7, Color(0.12, 0.1, 0.09, 0.9), 5.0)
	FX.debris(global_position + Vector3(0, 0.2, 0), Vector3.UP, 10 + 4 * tier, Color(0.05, 0.04, 0.04), 5.0)
	FX.sfx("splash", global_position, -6.0, 0.1, 0.6)
	FX.sfx("crunch", global_position, -4.0, 0.1, 0.8)
	_pool = MeshInstance3D.new()
	_pool.mesh = _blot(radius)
	var m := PSXMat.decal(TAR, {"roughness": 0.08, "specular": 0.9})
	_pool.material_override = m
	_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pool.visibility_range_end = 120.0
	add_child(_pool)
	_pool.position = Vector3(0, 0.03, 0)
	_pool.scale = Vector3(0.2, 1, 0.2)
	_pool.create_tween().tween_property(_pool, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# a few slow bubbles of pitch (Mk III's still smoulders)
	_emit = FX.flip_emitter(self, "smoke" if tier == 2 else "dust", 3 + tier * 2, 0.5, 1.4, {"radius": radius * 0.6, "spread": 10.0,
		"vel_min": 0.1, "vel_max": 0.3, "gravity": Vector3(0, 0.2, 0), "damping": 0.5, "fade": 0.5,
		"color": Color(0.2, 0.17, 0.15, 0.7) if tier == 2 else Color(0.08, 0.07, 0.06, 0.8), "range": 80.0})


## An uneven round blot lying flat (the tar pool).
func _blot(r: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 13.0) ^ int(global_position.z * 7.0)
	var n := 14
	var pts: Array = []
	for i in range(n):
		var a := TAU * i / n
		pts.append(Vector3(cos(a), 0, sin(a)) * r * rng.randf_range(0.82, 1.08))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in range(n):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % n]
		for v in [Vector3.ZERO, b, a]:
			st.set_uv(Vector2(v.x, v.z) / (2.0 * r) + Vector2(0.5, 0.5))
			st.add_vertex(v)
	return st.commit()


func _tick() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node3D
		if n == null or not inside(n.global_position):
			continue
		match kind:
			"smoke":
				if not _hit.has(n):
					_hit[n] = true
					var b := float(GadgetData.tier_val("smoke", "blind", tier))
					if n.has_method("blinded"):
						n.blinded(b)
					elif n.has_method("stagger"):
						n.stagger(b)
			"tar":
				if n.has_method("slowed"):
					n.slowed(TICK * 2.0, float(GadgetData.tier_val("tar", "slow", tier)))
				if not _hit.has(n):
					_hit[n] = true
					Net.fx("puff", [n.global_position + Vector3(0, 0.1, 0), "dust_low", 3, 0.5, 0.6, Color(0.08, 0.07, 0.06, 0.9), 0.3])


func _end() -> void:
	active.erase(self)
	GadgetVeil.clouds.erase(self)
	if _emit:
		_emit.emitting = false
	if _pool:
		_pool.create_tween().tween_property(_pool, "scale", Vector3(0.01, 1, 0.01), 1.0)
	get_tree().create_timer(2.8).timeout.connect(queue_free)
