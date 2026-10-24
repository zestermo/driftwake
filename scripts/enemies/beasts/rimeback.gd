extends "res://scripts/enemies/beasts/behemoth.gd"
## The Rimeback (BeastPool "rimeback", a snow island's roamer): the behemoth's wandering
## and temper in a woolly giant - a shaggy white coat hanging to its knees, a domed head,
## two long tusks curling up and out, ice caked along its back. It wanders the snowfields
## from one place to the next; crowd it or strike it and it charges, tosses its tusks and
## stomps, a bellow before each.


func _init() -> void:
	boss_name = "The Rimeback"


## (1.20: rebuilt on the quadruped rig, docs/v1_20_beasts.md 9: a woolly mammoth's build - a domed head held high
## over a tall shoulder hump, the back falling away to low hips, pillar legs on round feet, a trunk to the ground)
func _spec() -> Dictionary:
	return {"hip_h": 2.1, "front_h": 2.75, "len": 3.0, "chest_r": 1.35, "hip_r": 1.1, "neck": Vector3(0, 0.15, -0.5), "head": Vector3(0.78, 0.92, 0.72),
		"snout": 0.25, "tail": 0.7, "tail_r": 0.13, "coat": Color(0.86, 0.85, 0.82), "under": Color(0.72, 0.7, 0.66), "mark": Color(0.55, 0.52, 0.48),
		"tex": "fur_white", "ears": 0.0, "eye": Color(0.4, 0.8, 1.0),
		"hump": 0.8, "leg_k": 1.7, "front_k": 1.05, "foot": "pad", "bend": 0.35, "tail_kind": "tuft", "gait": "lumber"}


## The dome of its skull, small round ears, a trunk hanging to the ground, tusks sweeping down, out and up, a skirt of
## shaggy coat to the knees, a fringe at its jaw, ice caked along its back.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var cr: float = spec["chest_r"]
	var hr: float = spec["hip_r"]
	var ln: float = spec["len"]
	var lift: float = float(spec["front_h"]) - float(spec["hip_h"])
	var coat: Material = spec["coat_mat"]
	var ivory := PSXMat.flat(Color(0.93, 0.9, 0.8))
	var ice := PSXMat.lit("ice", Color(0.88, 0.95, 1.0), {"affine": 0.4})
	var rng := _rng_fixed()
	# the skull's dome and the shaggy crown on it; small ears low on the sides
	mb("Head").add_blob(coat, Transform3D(Basis(), Vector3(0, hd.y * 0.75, hd.z * 0.1)), Vector3(hd.x * 0.8, hd.y * 0.55, hd.z * 0.75), rng, 0.15, 3, 7, 1.0, Color(0.95, 0.95, 0.95))
	for s in [-1.0, 1.0]:
		mb("Head").add_blob(coat, Transform3D(Basis(Vector3.UP, s * 0.4), Vector3(s * hd.x * 0.95, hd.y * 0.15, hd.z * 0.25)), Vector3(0.14, hd.y * 0.32, hd.z * 0.32), rng, 0.15, 3, 5, 1.0, Color(0.8, 0.8, 0.8))
	# the trunk: from the face down almost to the ground, curling forward at its tip
	var down: float = float(spec["front_h"]) + hd.y * 0.2
	var t := PackedVector3Array([Vector3(0, -hd.y * 0.1, -hd.z * 0.95), Vector3(0, -hd.y * 0.9, -hd.z * 1.25), Vector3(0, -down * 0.55, -hd.z * 1.3),
		Vector3(0, -down * 0.8, -hd.z * 1.15), Vector3(0, -down * 0.92, -hd.z * 1.45)])
	mb("Head").add_tube(coat, t, 0.4, 0.16, 7, 1.0, Color(0.6, 0.57, 0.53))
	# tusks: down past the trunk's root, out, and sweeping up
	for s in [-1.0, 1.0]:
		var t0 := Vector3(s * hd.x * 0.42, -hd.y * 0.5, -hd.z * 0.85)
		mb("Head").add_tube(ivory, PackedVector3Array([t0, t0 + Vector3(s * 0.25, -0.9, -0.6), t0 + Vector3(s * 0.75, -1.25, -1.5), t0 + Vector3(s * 1.0, -0.6, -2.4),
			t0 + Vector3(s * 0.7, 0.3, -2.7)]), 0.2, 0.04, 6, 1.0)
	# the beard of coat under its jaw
	for k in range(5):
		mb("Jaw").add_blob(coat, Transform3D(Basis(), Vector3((k - 2) * hd.x * 0.3, -hd.y * 0.45, -hd.z * 0.3)), Vector3(0.22, hd.y * 0.45, 0.2), rng, 0.3, 3, 5, 1.0, Color(0.86, 0.86, 0.86))
	# the coat hanging in a skirt of shags to the knees, following the back down from the shoulders to the hips
	for side in [-1.0, 1.0]:
		for k in range(7):
			var f := float(k) / 6.0
			var z: float = lerpf(-ln * 0.55, ln * 0.55, f)
			var y: float = lerpf(lift - cr * 0.55, -hr * 0.55, f)
			var w: float = lerpf(cr, hr, f) * 0.95
			mb("Body").add_blob(coat, Transform3D(Basis(Vector3.FORWARD, side * 0.12), Vector3(side * w, y, z)), Vector3(0.3, lerpf(cr, hr, f) * 0.5, ln * 0.11), rng, 0.3, 3, 6, 1.0, Color(0.88, 0.88, 0.88))
	# under the belly too, between the legs
	for k in range(4):
		var z: float = lerpf(-ln * 0.35, ln * 0.35, float(k) / 3.0)
		mb("Body").add_blob(coat, Transform3D(Basis(), Vector3(0, lerpf(lift - cr * 0.9, -hr * 0.85, float(k) / 3.0), z)), Vector3(cr * 0.6, 0.35, ln * 0.12), rng, 0.3, 3, 5, 1.0, Color(0.8, 0.8, 0.8))
	# ice caked along the hump and back
	for k in range(7):
		var f := float(k) / 6.0
		var z: float = lerpf(-ln * 0.5, ln * 0.45, f)
		var y: float = lerpf(lift + cr * 0.95, hr * 0.9, f)
		mb("Body").add_blob(ice, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-0.3, 0.3), y, z)), Vector3(0.45, 0.2, 0.4), rng, 0.3, 3, 5, 0.6)


func _coat_at(p: Vector3) -> Color:
	return (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.7, p.y / maxf(float(spec["chest_r"]), 0.1)))


# 1.20's moves (docs/v1_20_beasts.md 9), as a table: its one knockdown the trample. (Its calves answering a herd call
# wait for a co-op spawn: for now the call sends a stampede of snow down two lanes.)
func _table() -> Dictionary:
	var snow := Color(0.92, 0.96, 1.0)
	return {
		"stampede": {"phase": 2, "max": 16.0, "cd": [11.0, 14.0], "tell": 1.0, "shape": "lanes", "n": 2, "len": 20.0, "w": 1.5, "dmg": 18.0, "kb": 10.0,
			"rec": 1.0, "col": snow, "fx": "quake", "say": ["bellow", 0.7], "pose": [{"rear": 0.7, "head": 0.5, "jaw": 1.0}, {"head": 0.3}, {}]},
		"sweep": {"max": 5.5, "cd": [2.0, 3.0], "tell": 0.6, "shape": "cone", "r": 5.5, "deg": 110.0, "dmg": 20.0, "kb": 9.0, "parry": true, "rec": 0.8,
			"pose": [{"head": -0.4, "crouch": 0.15}, {"head": 0.45}, {"head": -0.1}]},
		"toss": {"min": 5.0, "max": 14.0, "cd": [5.0, 7.0], "tell": 0.5, "shape": "lane", "len": 14.0, "w": 0.8, "dmg": 14.0, "kb": 6.0, "rec": 0.8,
			"fx": "sparkle", "col": snow, "pose": [{"head": -0.6, "crouch": 0.3}, {"head": 0.5}, {}]},
		"trample": {"min": 6.0, "max": 20.0, "cd": [7.0, 9.0], "tell": 0.9, "shape": "charge", "len": 18.0, "w": 2.0, "speed": 12.0, "dmg": 30.0, "knock": true,
			"rec": 1.6, "say": ["bellow", 0.8], "pose": [{"rear": 0.8, "head": 0.4}, {"head": -0.2, "stretch": 0.4}, {"crouch": 0.4, "head": -0.3}]},
	}


func _wake_move() -> String:
	return "sweep"
