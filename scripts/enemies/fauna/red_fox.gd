class_name RedFox
extends DesertFox
## Red foxes in the autumn woods: the fennec's wariness (they sit up to listen and bolt zigzagging
## when a captain comes near; cornered, one snaps once) in a woodland fox - a long russet body, black
## socks, a white bib, a big brush of a tail with a white tip. Morphs: russet, a grey fox, a dark "cross" fox.


func _setup(args: Dictionary) -> void:
	super._setup(args)
	size_k = 0.85 if bool(args.get("calf", false)) else 1.2
	max_hp = 28.0
	xp = 22


func _build() -> void:
	var coats := [[Color(0.86, 0.42, 0.16), Color(0.97, 0.94, 0.88)], [Color(0.55, 0.53, 0.5), Color(0.92, 0.9, 0.86)], [Color(0.42, 0.24, 0.14), Color(0.8, 0.72, 0.62)]]
	var c: Array = coats[morph % 3]
	var coat: Color = c[0]
	var belly: Color = c[1]
	var dark := Color(0.1, 0.08, 0.07)
	var skin := _skin()
	var v := "r%d" % (morph % 3)
	_body = _part(model, "Body", Vector3(0, BODY_Y, 0), v + "_body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
		mb.add_loft(skin, xf, [[-0.26, 0.05, 0.06, 0.0], [-0.18, 0.08, 0.1, 0.0], [0.1, 0.09, 0.1, 0.01], [0.24, 0.06, 0.07, 0.0]],
			MeshBuilder.profile_circle(7), 1.5, coat, true, true)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.04, -0.14)), Vector3(0.06, 0.06, 0.08), rng, 0.05, 2, 6, 1.5, belly), true)
	_head = _part(_body, "Head", Vector3(0, 0.08, -0.26), v + "_head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D.IDENTITY, Vector3(0.07, 0.06, 0.075), rng, 0.03, 3, 7, 1.5, coat)
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -0.02, -0.06))
		mb.add_loft(skin, xf, [[0.0, 0.04, 0.035], [0.09, 0.022, 0.02], [0.13, 0.01, 0.01]], MeshBuilder.profile_circle(6), 1.5, coat, false, true)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.035, -0.07)), Vector3(0.035, 0.02, 0.05), rng, 0.03, 2, 5, 1.5, belly)
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.012, -0.19)), Vector3(0.02, 0.018, 0.018), 1.5, dark, false, false)
		for s in [-1.0, 1.0]:
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.035, 0.015, -0.06)), Vector3(0.013, 0.013, 0.013), rng, 0.0, 2, 5, 1.5, Color(0.7, 0.55, 0.15)))
	for s in [-1.0, 1.0]:
		var ear := _part(_head, "Ear", Vector3(s * 0.04, 0.045, 0.0), v + ("_ear_l" if s < 0.0 else "_ear_r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			mb.add_extrude(skin, Transform3D(Basis(Vector3.FORWARD, s * 0.3), Vector3.ZERO), PackedVector2Array([Vector2(-0.03, 0), Vector2(0.03, 0), Vector2(0.0, 0.08)]), 0.012, 1.5, dark.lerp(coat, 0.4)))
		_ears.append([ear, s])
	_tail = _part(_body, "Tail", Vector3(0, 0.03, 0.24), v + "_tail", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var pts := MeshBuilder.curve_points(Vector3.ZERO, Vector3(0, -0.06, 0.2), Vector3(0, -0.1, 0.38), 5)
		mb.add_tube(skin, pts, 0.05, 0.075, 6, 1.0, coat)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.1, 0.42)), Vector3(0.06, 0.06, 0.07), rng, 0.1, 2, 5, 1.0, belly))
	for i in range(4):
		var front := i < 2
		var s := -1.0 if i % 2 == 0 else 1.0
		var leg := _part(_body, "Leg%d" % i, Vector3(s * 0.05, -0.05, -0.14 if front else 0.16), v + "_leg", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			mb.add_cylinder(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.21, 0)), 0.018, 0.028, 0.22, 5, 1.0, dark, false))
		_legs.append({"pivot": leg, "front": front, "pair": i % 2})
