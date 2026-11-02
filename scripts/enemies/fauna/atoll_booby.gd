extends Toucan
## Boobies (the coral atoll's): the toucan's temper - perched in a palm crown, shrieking at whoever passes under its
## nest, then down at you flapping (the tell) and diving bill first, three times - in a white seabird with chocolate
## wings, a long grey dagger of a bill and bright blue feet. Its eggs and plumes fetch a little in the stilt town.


func _setup(args: Dictionary) -> void:
	super._setup(args)
	kind = "booby"
	size_k = 1.15
	max_hp = 28.0
	speed = 9.0
	dive_speed = 15.0
	drops = [["plume", 0.5, 1], ["egg", 0.4, 1]]


func _build() -> void:
	var white := Color(0.95, 0.95, 0.92)
	var brown := Color(0.32, 0.22, 0.15)
	var blue := Color(0.3, 0.7, 0.95)
	var bill := Color(0.6, 0.66, 0.72)
	var skin := _skin()
	_body = _part(model, "Body", Vector3(0, 0.12, 0), "booby_body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3.ZERO), Vector3(0.09, 0.1, 0.16), rng, 0.04, 3, 7, 2.0, white)
		mb.add_blob(skin, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, 0.05, 0.05)), Vector3(0.08, 0.06, 0.1), rng, 0.03, 3, 6, 2.0, brown)
		for s in [-1.0, 1.0]:
			Creature.seg(mb, skin, Vector3(s * 0.035, -0.08, 0.0), Vector3(s * 0.035, -0.14, -0.02), 0.016, blue)
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.035, -0.145, -0.035)), Vector3(0.05, 0.012, 0.07), 2.0, blue, false, false), true)
	_head = _part(_body, "Head", Vector3(0, 0.13, -0.1), "booby_head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D.IDENTITY, Vector3(0.055, 0.06, 0.06), rng, 0.0, 3, 6, 2.0, white)
		for s in [-1.0, 1.0]:
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.05, 0.015, -0.025)), Vector3(0.008, 0.016, 0.016), 2.0, Color(0.05, 0.05, 0.05), false, false)
		mb.add_cone(skin, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -0.005, -0.05)), 0.026, 0.17, 5, 2.0, bill), true)
	_tail = _part(_body, "Tail", Vector3(0, 0.0, 0.14), "booby_tail", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		var fan := PackedVector2Array([Vector2(-0.03, 0), Vector2(0.03, 0), Vector2(0.0, 0.16)])
		mb.add_extrude(skin, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 + 0.9), Vector3.ZERO), fan, 0.012, 2.0, brown))
	for s in [-1.0, 1.0]:
		var w := _part(_body, "Wing", Vector3(s * 0.07, 0.04, -0.03), "booby_wing_l" if s < 0.0 else "booby_wing_r", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			var pts := [Vector2(0, -0.05), Vector2(0.22, -0.06), Vector2(0.42, -0.01), Vector2(0.36, 0.05), Vector2(0.14, 0.08), Vector2(0, 0.07)]
			var outline := PackedVector2Array()
			for q in pts:
				outline.append(Vector2(q.x * s, q.y))
			mb.add_extrude(skin, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), outline, 0.012, 2.0, brown))
		_wings.append([w, s])


func _cry_death() -> void:
	Net.fx("sfx", ["squawk", global_position, -2.0, 0.1, 0.9])
	Net.fx("petals", [global_position, Vector3.UP, 8, Color(0.95, 0.95, 0.92), 2.0])
