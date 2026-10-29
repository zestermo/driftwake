class_name ShrineTerrace
extends RefCounted
## The shrine terrace's 1.25.4 pieces (the Edy reading and Tomo's spar moved up here): Master Isao's reading hall, a
## walk-in room on a stone plinth with the five Edy colours hung along its back wall; the sparring ground's straw-
## wrapped striking posts; a stone water basin. Built like BrinehollowModels: round their own origin, the front toward
## +Z, one merged mesh, box colliders, markers.

const M := preload("res://scripts/props/brinehollow_models.gd")


## Isao's hall: open across its front between red posts, plastered walls on three sides, a raised plank floor with
## cushions, a low table with incense, five banners in the Edy types' colours, under a flared roof. Markers "Master"
## (at the back, facing the door), "Door" (at the foot of the steps).
static func reading_hall(seed_value: int) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := M._body("ReadingHall")
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick")
	var flag := PSXMat.lit("flagstones", Color(0.95, 0.92, 0.86))
	var post := PSXMat.lit("planks_dark")
	var red := PSXMat.lit("planks", Color(0.78, 0.26, 0.18))
	var board := PSXMat.lit("planks", Color(0.95, 0.85, 0.7))
	var plaster := PSXMat.lit("plaster", Color(0.96, 0.93, 0.86))
	var roof := PSXMat.lit("roof_tiles", Color(0.5, 0.56, 0.62), {"affine": 0.8})
	var under := PSXMat.lit("planks_dark", Color(0.8, 0.75, 0.7))
	var cloth := PSXMat.lit("fabric")
	var w := 6.0
	var d := 4.6
	var base := 0.5
	var h := 2.8
	# the plinth, two steps up its front (a ramp under them), the plank floor
	mb.add_box(stone, M._xf(Vector3(0, base * 0.5 - 0.3, 0)), Vector3(w + 0.6, base + 0.6, d + 0.6), 0.6, Color(0.85, 0.85, 0.85))
	M._box(body, Vector3(w + 0.6, base + 0.6, d + 0.6), Vector3(0, base * 0.5 - 0.3, 0))
	for i in range(2):
		var z := (d + 0.6) * 0.5 + 0.18 + i * 0.34
		var y := base - (i + 1) * base / 3.0
		mb.add_box(stone, M._xf(Vector3(0, (y - 0.3) * 0.5, z)), Vector3(2.4, y + 0.3, 0.34), 0.6, Color(0.8, 0.8, 0.8))
		mb.add_box(flag, M._xf(Vector3(0, y + 0.02, z)), Vector3(2.44, 0.04, 0.36), 0.6)
	var run := 0.75
	var cs := CollisionShape3D.new()
	var sb := BoxShape3D.new()
	sb.size = Vector3(2.4, 0.16, Vector2(run, base).length() + 0.2)
	cs.shape = sb
	cs.transform = Transform3D(Basis(Vector3.RIGHT, atan2(base, run)), Vector3(0, base * 0.5 - 0.05, (d + 0.6) * 0.5 + run * 0.5))
	body.add_child(cs)
	var fl := base + 0.04
	mb.add_box(board, M._xf(Vector3(0, fl - 0.02, 0)), Vector3(w + 0.4, 0.06, d + 0.4), 0.5)
	# the walls: back and sides, plaster in a dark frame; the front open between the posts
	for s: float in [-1.0, 1.0]:
		mb.add_box(plaster, M._xf(Vector3(s * (w * 0.5 - 0.08), fl + h * 0.5, -0.2)), Vector3(0.14, h, d - 0.4), 0.5)
		M._box(body, Vector3(0.2, h, d - 0.4), Vector3(s * (w * 0.5 - 0.08), fl + h * 0.5, -0.2))
	mb.add_box(plaster, M._xf(Vector3(0, fl + h * 0.5, -d * 0.5 + 0.1)), Vector3(w, h, 0.14), 0.5)
	M._box(body, Vector3(w, h, 0.2), Vector3(0, fl + h * 0.5, -d * 0.5 + 0.1))
	for x: float in [-w * 0.5, -w * 0.17, w * 0.17, w * 0.5]:
		mb.add_cylinder(red, M._xf(Vector3(x, fl, d * 0.5)), 0.13, 0.12, h + 0.15, 8, 0.6)
		if absf(x) > w * 0.4:
			mb.add_box(post, M._xf(Vector3(x, fl + h * 0.5, -d * 0.5 + 0.1)), Vector3(0.22, h, 0.22), 0.6)
	mb.add_box(post, M._xf(Vector3(0, fl + h - 0.08, 0)), Vector3(w + 0.5, 0.2, d + 0.5), 0.6)
	mb.add_box(red, M._xf(Vector3(0, fl + h - 0.35, d * 0.5 + 0.04)), Vector3(w + 0.3, 0.14, 0.12), 0.6)
	M.flared_roof(mb, roof, under, Vector3(0, fl + h + 0.05, 0), w + 0.6, d + 0.6, 1.5, 0.9, 0.45)
	# the five banners, one per Edy type, along the back wall
	for i in range(EdyTypes.ORDER.size()):
		var col := EdyTypes.color_of(str(EdyTypes.ORDER[i]))
		var x := -2.2 + i * 1.1
		mb.add_box(post, M._xf(Vector3(x, fl + h - 0.55, -d * 0.5 + 0.22)), Vector3(0.8, 0.05, 0.05), 1.0)
		mb.add_box(cloth, M._xf(Vector3(x, fl + h - 1.25, -d * 0.5 + 0.2)), Vector3(0.66, 1.35, 0.02), 1.0, col)
		mb.add_box(PSXMat.flat(Color(0.97, 0.95, 0.9)), M._xf(Vector3(x, fl + h - 1.0, -d * 0.5 + 0.22)), Vector3(0.28, 0.28, 0.01), 1.0)
	# cushions in a half ring before the master's place, the low table, incense smoking on it
	mb.add_box(cloth, M._xf(Vector3(0, fl + 0.06, -d * 0.5 + 0.9)), Vector3(0.7, 0.12, 0.7), 1.0, Color(0.55, 0.2, 0.25))
	for k in range(5):
		var a := PI * (0.15 + 0.175 * k)
		var p := Vector3(cos(a) * 1.7, fl + 0.05, -d * 0.5 + 0.9 + sin(a) * 1.7)
		mb.add_box(cloth, M._xf(p, a), Vector3(0.55, 0.1, 0.55), 1.0, Color(0.3, 0.32, 0.45).lerp(Color(0.45, 0.3, 0.25), rng.randf()))
	mb.add_box(post, M._xf(Vector3(0, fl + 0.18, -d * 0.5 + 1.75)), Vector3(1.1, 0.06, 0.5), 1.0)
	for x: float in [-0.48, 0.48]:
		mb.add_box(post, M._xf(Vector3(x, fl + 0.08, -d * 0.5 + 1.75)), Vector3(0.06, 0.16, 0.44), 1.0)
	mb.add_cylinder(PSXMat.lit("metal", Color(0.85, 0.65, 0.3)), M._xf(Vector3(0.25, fl + 0.21, -d * 0.5 + 1.75)), 0.09, 0.07, 0.1, 6, 1.0)
	mb.add_box(PSXMat.glow(Color(1.0, 0.55, 0.2), 2.5), M._xf(Vector3(0.25, fl + 0.33, -d * 0.5 + 1.75)), Vector3(0.015, 0.16, 0.015), 1.0)
	mb.add_box(plaster, M._xf(Vector3(-0.25, fl + 0.23, -d * 0.5 + 1.75)), Vector3(0.22, 0.04, 0.3), 1.0)
	M._marker(body, "Master", Vector3(0, fl, -d * 0.5 + 0.9), 0.0)
	M._marker(body, "Door", Vector3(0, 0, (d + 0.6) * 0.5 + run + 0.8), PI)
	return M._done(body, mb, 260.0)


## A striking post at the sparring ground's edge: a squared timber, straw bound round its head with rope.
static func striking_post(seed_value: int) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := M._body("StrikingPost")
	var mb := MeshBuilder.new()
	var hgt := rng.randf_range(1.5, 1.75)
	mb.add_box(PSXMat.lit("planks_dark"), M._xf(Vector3(0, hgt * 0.5, 0), rng.randf_range(-0.2, 0.2)), Vector3(0.18, hgt, 0.18), 1.0)
	mb.add_cylinder(PSXMat.lit("thatch", Color(0.95, 0.85, 0.6)), M._xf(Vector3(0, hgt - 0.55, 0)), 0.17, 0.16, 0.45, 7, 1.0)
	var rope := PSXMat.lit("rope", Color(0.85, 0.7, 0.5))
	for y: float in [hgt - 0.5, hgt - 0.3, hgt - 0.14]:
		mb.add_cylinder(rope, M._xf(Vector3(0, y, 0)), 0.18, 0.18, 0.04, 7, 1.0)
	mb.add_box(PSXMat.lit("stone_brick"), M._xf(Vector3(0, 0.08, 0)), Vector3(0.45, 0.16, 0.45), 0.6)
	M._box(body, Vector3(0.3, hgt, 0.3), Vector3(0, hgt * 0.5, 0))
	var out := M._done(body, mb, 160.0)
	(out.get_node("Mesh") as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return out


## A stone water basin with a bamboo ladle laid across it (where you rinse before the shrine).
static func basin() -> StaticBody3D:
	var body := M._body("Basin")
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick", Color(0.8, 0.82, 0.8))
	mb.add_box(stone, M._xf(Vector3(0, 0.38, 0)), Vector3(1.1, 0.76, 0.7), 0.6)
	mb.add_box(PSXMat.flat(Color(0.25, 0.42, 0.5)), M._xf(Vector3(0, 0.765, 0)), Vector3(0.9, 0.02, 0.5), 1.0)
	mb.add_cylinder(PSXMat.lit("planks", Color(0.75, 0.8, 0.45)), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.1, 0.8, 0.12)), 0.025, 0.025, 1.0, 5, 1.0)
	mb.add_cylinder(PSXMat.lit("planks", Color(0.75, 0.8, 0.45)), M._xf(Vector3(0.55, 0.8, 0.12)), 0.07, 0.07, 0.12, 6, 1.0)
	M._box(body, Vector3(1.1, 0.8, 0.7), Vector3(0, 0.4, 0))
	var out := M._done(body, mb, 160.0)
	(out.get_node("Mesh") as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return out
