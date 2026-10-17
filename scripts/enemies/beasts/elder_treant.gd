extends "res://scripts/enemies/beasts/alpha_boar.gd"
## The Elder Treant (BeastPool "elder_treant", a forest island's boss): an oak grown old enough to walk, on four
## great root-legs, its back a crown of autumn leaves and branches, a face in its bark with ember eyes, roots
## trailing. The alpha boar's brain, slow and very heavy: it lowers its head and lumbers down a line (the charge),
## swings a branch-horned head in front (parry it: it reels), and from the start rears and brings its forelegs down,
## a ring of roots bursting round it (jump it). No bar over its head (the arena's). Looks: oak, birch-pale, burnt.
## Its bark's grain is darkened in by _coat_at.

const BARKS := [
	[Color(1.0, 0.86, 0.7), Color(0.85, 0.72, 0.58), Color(0.6, 0.78, 0.36)],
	[Color(1.0, 1.0, 1.0), Color(0.9, 0.9, 0.88), Color(0.62, 0.74, 0.42)],
	[Color(0.45, 0.4, 0.38), Color(0.35, 0.32, 0.3), Color(1.0, 0.45, 0.15)],
]


func _init() -> void:
	boss_name = "The Elder Treant"
	wake_r = 0.0
	charge_len = 18.0
	charge_speed = 10.5
	gore_r = 4.8
	stomp_r = 8.0


func _spec() -> Dictionary:
	var c: Array = BARKS[variant % BARKS.size()]
	return {"hip_h": 2.6, "len": 3.0, "chest_r": 1.5, "hip_r": 1.3, "neck": Vector3(0, 0.1, -0.55), "head": Vector3(0.85, 0.8, 0.8),
		"snout": 0.25, "tail": 0.6, "tail_r": 0.3, "coat": c[0], "under": c[1], "mark": c[2], "tex": "bark", "ears": 0.0,
		"eye": Color(1.0, 0.6, 0.15)}


## Its crown: a canopy of autumn leaves on branches up off its back; branch-horns on its head; a hollow mouth;
## roots trailing from its belly and legs; moss on its shoulders.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var cr: float = spec["chest_r"]
	var ln: float = spec["len"]
	var bark := PSXMat.lit("bark", Color(0.85, 0.72, 0.6))
	var leaves := [PSXMat.lit("leaves_maple", Color.WHITE, {"affine": 0.5}), PSXMat.lit("leaves_beech", Color.WHITE, {"affine": 0.5}), PSXMat.lit("leaves_oak", Color.WHITE, {"affine": 0.5})]
	var moss := PSXMat.lit("leaves_late", Color(0.7, 0.9, 0.55), {"affine": 0.5})
	var rng := _rng_fixed()
	for k in range(5):
		var a := TAU * k / 5.0 + 0.3
		var at := Vector3(cos(a) * cr * 0.4, cr * 0.8, sin(a) * ln * 0.25)
		var top := at + Vector3(cos(a) * rng.randf_range(0.8, 1.6), rng.randf_range(1.8, 2.8), sin(a) * rng.randf_range(0.8, 1.6))
		mb("Body").add_tube(bark, PackedVector3Array([at, at.lerp(top, 0.5) + Vector3(0, 0.3, 0), top]), 0.3, 0.1, 6, 0.8)
		for j in range(3):
			var c := top + Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 0.8), rng.randf_range(-1.0, 1.0))
			var r := rng.randf_range(1.5, 2.1)
			var sh := rng.randf_range(0.8, 1.0)
			mb("Body").add_blob(leaves[(k + j) % 3], Transform3D(Basis(Vector3.UP, rng.randf() * TAU), c), Vector3(r, r * 0.7, r), rng, 0.22, 3, 6, 0.5, Color(sh, sh, sh))
	for s in [-1.0, 1.0]:
		var root := Vector3(s * hd.x * 0.5, hd.y * 0.6, hd.z * 0.2)
		mb("Head").add_tube(bark, MeshBuilder.curve_points(root, root + Vector3(s * 0.9, 0.6, 0.2), root + Vector3(s * 1.1, 1.6, -0.4), 5), 0.16, 0.04, 5, 1.0)
		mb("Body").add_blob(moss, Transform3D(Basis(), Vector3(s * cr * 0.65, cr * 0.6, -ln * 0.4)), Vector3(cr * 0.4, cr * 0.25, cr * 0.5), rng, 0.25, 3, 6, 0.6)
	mb("Head").add_box(PSXMat.flat(Color(0.05, 0.03, 0.02)), Transform3D(Basis(), Vector3(0, -hd.y * 0.35, -hd.z * 0.95)), Vector3(hd.x * 0.8, hd.y * 0.18, 0.1), 1.0)
	for k in range(10):
		var a := TAU * k / 10.0
		var at := Vector3(cos(a) * cr * 0.7, -cr * 0.6, sin(a) * ln * 0.45)
		mb("Body").add_tube(bark, PackedVector3Array([at, at + Vector3(cos(a) * 0.2, -0.6, sin(a) * 0.2), at + Vector3(cos(a) * 0.5, -1.1, sin(a) * 0.4)]), 0.09, 0.02, 4, 1.0)


func _coat_at(p: Vector3) -> Color:
	var base := (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.6, p.y / maxf(float(spec["chest_r"]), 0.1)))
	var moss := smoothstep(0.6, 0.9, sin(p.x * 2.4 + p.z * 1.3) * 0.5 + 0.5) * smoothstep(0.2, 0.7, p.y / maxf(float(spec["chest_r"]), 0.1))
	# (bark: grain running up it in ridges, darker in the furrows)
	var grain := absf(sin(p.x * 9.0 + p.z * 5.0 + sin(p.y * 2.0) * 1.5))
	return base.lerp(spec["mark"], moss * 0.7).darkened(0.35 * smoothstep(0.6, 1.0, grain))


func _hp_base() -> float:
	return 2000.0


func _poise_max() -> float:
	return 340.0


func _phase_at() -> Array:
	return [0.6, 0.3]


func _xp_base() -> int:
	return 780


func _coins_base() -> int:
	return 46


func _speed() -> float:
	return 3.8 if phase < 3 else 4.8


func _wake_move() -> String:
	return "stomp"


func _ready() -> void:
	super._ready()
	_cd["stomp"] = 2.5
	_overhead.queue_free()
	_overhead = null


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": Color(0.62, 0.22, 0.1)}, "Mantle of Fallen Leaves", t)
