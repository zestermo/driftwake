extends "res://scripts/enemies/beasts/stalker.gd"
## The Sand Lion (BeastPool "sand_lion", a desert island's boss): the stalker's hunt in a
## maned desert lion - tawny, a dark shaggy mane, a tufted tail - that melts into the scrub and
## the heat round its ground and comes out of it at a run. Looks: tawny, pale gold, dusk.

const LION_COATS := [
	[Color(0.82, 0.62, 0.36), Color(0.94, 0.84, 0.64), Color(0.32, 0.18, 0.1)],
	[Color(0.92, 0.82, 0.6), Color(0.98, 0.94, 0.84), Color(0.62, 0.44, 0.22)],
	[Color(0.62, 0.42, 0.28), Color(0.82, 0.68, 0.52), Color(0.16, 0.1, 0.08)],
]


func _init() -> void:
	boss_name = "The Sand Lion"


## (1.20: rebuilt on the quadruped rig, docs/v1_20_beasts.md 13: heavier than the stalker it hunts like - a deep chest,
## the shoulders a little high over thick forelegs and big paws, a broad head with a square muzzle, a full mane, a
## tufted tail, a cat's bound)
func _spec() -> Dictionary:
	var c: Array = LION_COATS[variant % LION_COATS.size()]
	return {"hip_h": 1.5, "front_h": 1.68, "len": 2.4, "chest_r": 0.86, "hip_r": 0.6, "neck": Vector3(0, 0.25, -0.5), "head": Vector3(0.5, 0.44, 0.5),
		"snout": 0.36, "tail": 2.0, "tail_r": 0.11, "coat": c[0], "under": c[1], "mark": c[2], "tex": "fur", "ears": 0.2,
		"eye": Color(1.0, 0.8, 0.25), "hump": 0.2, "leg_k": 1.2, "front_k": 1.15, "tail_kind": "tuft", "gait": "bound"}


## A square muzzle and a heavy brow; the mane: a ruff framing the face, heaped over the neck and shoulders and hanging
## down the chest (the Neck part, painted dark whole, with the tail's tuft).
func _extras() -> void:
	var cr: float = spec["chest_r"]
	var hd: Vector3 = spec["head"]
	var sn: float = spec["snout"]
	var coat: Material = spec["coat_mat"]
	var rng := _rng_fixed()
	mb("Head").add_blob(coat, Transform3D(Basis(), Vector3(0, -hd.y * 0.28, -hd.z * 0.85 - sn * 0.45)), Vector3(hd.x * 0.62, hd.y * 0.4, sn * 0.7), rng, 0.06, 3, 7, 1.0, Color(1.08, 1.08, 1.08))
	mb("Head").add_blob(coat, Transform3D(Basis(), Vector3(0, hd.y * 0.38, -hd.z * 0.55)), Vector3(hd.x * 0.8, hd.y * 0.22, hd.z * 0.35), rng, 0.1, 3, 6, 1.0, Color(0.92, 0.92, 0.92))
	# the ruff round the face
	for k in range(18):
		var a := TAU * k / 18.0
		mb("Neck").add_blob(coat, Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(sin(a) * cr * 0.85, cos(a) * cr * 0.8 + 0.2, 0.15 + absf(cos(a)) * 0.1)),
			Vector3(cr * 0.36, cr * 0.48, cr * 0.42), rng, 0.3, 3, 5, 1.0, Color(0.95, 0.95, 0.95))
	# heaped back over the neck and shoulders, and down the chest
	for k in range(10):
		var f := float(k) / 9.0
		var side := -1.0 if k % 2 == 0 else 1.0
		mb("Neck").add_blob(coat, Transform3D(Basis(Vector3.FORWARD, side * 0.3), Vector3(side * cr * 0.4 * (1.0 - f * 0.4), cr * (0.75 - f * 0.25), 0.35 + f * cr * 0.9)),
			Vector3(cr * 0.42, cr * 0.45, cr * 0.45), rng, 0.3, 3, 5, 1.0, Color(0.9, 0.9, 0.9))
	for k in range(5):
		mb("Neck").add_blob(coat, Transform3D(Basis(), Vector3((k - 2) * cr * 0.18, -cr * 0.35 - absf(k - 2) * 0.05, 0.25)), Vector3(cr * 0.26, cr * 0.5, cr * 0.3), rng, 0.3, 3, 5, 1.0, Color(0.85, 0.85, 0.85))


## The mane and the tuft dark; tawny elsewhere.
func _coat_at(p: Vector3) -> Color:
	var base := (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.6, p.y / maxf(float(spec["chest_r"]), 0.1)))
	return base


func _paint(part: MeshBuilder, coat: Material) -> void:
	super._paint(part, coat)
	if part._surfaces.has(coat) and (part == mb("Neck") or part == mb("Tail3")):
		var c: PackedColorArray = part._surfaces[coat]["c"]
		for i in range(c.size()):
			c[i] = (spec["mark"] as Color) * c[i].r
		part._surfaces[coat]["c"] = c


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": spec["coat"]}, "Sand Lion's Mane", t)
