class_name Burnable
extends StaticBody3D
## Dry thornbrush: blocks the way until fire burns it away (Ember Fruit's
## world interaction). ignite() sets it burning; a couple of seconds later it
## crumbles and stops blocking. Built from a size (box footprint).

var size := Vector3(3.0, 2.6, 1.2)
var burned: bool = false
var _burning: bool = false
var _mesh: MeshInstance3D


func setup(s: Vector3) -> Burnable:
	size = s
	return self


func _ready() -> void:
	add_to_group("burnable")
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position.y = size.y * 0.5
	add_child(cs)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _build_mesh()
	add_child(_mesh)


## Dry, tangled thornbrush: clumps of withered bush cards over a few
## crossed bare stems.
func _build_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(size.x * 1000.0 + size.z * 77.0))
	var dry := [PSXMat.cutout("thornbrush", Color.WHITE, 0.08, 1.0), PSXMat.cutout("thornbrush", Color(0.85, 0.8, 0.7), 0.08, 1.0),
		PSXMat.cutout("bush", Color(0.75, 0.62, 0.38), 0.06, 1.4)]
	var stem := PSXMat.lit("bark", Color(0.45, 0.36, 0.26))
	var n := int(size.x * size.z * 2.2) + 4
	for i in range(n):
		var p := Vector3(rng.randf_range(-0.45, 0.45) * size.x, 0.0, rng.randf_range(-0.4, 0.4) * size.z)
		var h := rng.randf_range(0.6, 1.0) * size.y
		mb.add_cross_cards(dry[0 if i % 4 != 3 else (1 if i % 8 == 3 else 2)], Transform3D(Basis(Vector3.UP, rng.randf() * PI), p), h * 0.9, h, 3)
	for i in range(int(size.x * 2.0) + 2):
		var p := Vector3(rng.randf_range(-0.45, 0.45) * size.x, 0.0, rng.randf_range(-0.3, 0.3) * size.z)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.7, 0.7))
		mb.add_cylinder(stem, Transform3D(b, p), 0.05, 0.015, size.y * rng.randf_range(0.7, 1.05), 4, 1.0)
	return mb.commit()


## Already burned (a loaded save): gone, no fire.
func burn_away_instantly() -> void:
	burned = true
	_burning = true
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	if _mesh:
		_mesh.visible = false


func ignite() -> void:
	if _burning or burned:
		return
	_burning = true
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.mark_burned(str(name))
	var net := get_node_or_null("/root/Net")
	if net:
		net.burned(str(name))  # co-op: it burns for everyone
	FX.sfx("fire_burst", global_position + Vector3(0, 1, 0), -2.0, 0.1, 0.8)
	var holders: Array = []
	var nx := maxi(int(size.x / 1.0), 1)
	for i in range(nx):
		var h := Node3D.new()
		h.position = Vector3((float(i) + 0.5) / float(nx) * size.x - size.x * 0.5, size.y * 0.4, 0)
		add_child(h)
		FX.flame_emitter(h, maxf(size.z * 0.5, 0.4), 18, 0.9, 0.8)
		holders.append(h)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.omni_range = size.x * 1.6 + 2.0
	light.light_energy = 2.0
	light.position.y = size.y * 0.6
	add_child(light)
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3(1.0, 0.25, 1.0), 2.4).set_delay(0.6)
	tw.tween_callback(func():
		burned = true
		for c in get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).set_deferred("disabled", true)
		FX.smoke(global_position + Vector3(0, 0.8, 0), 10, 1.6, 2.4)
		for h in holders:
			for e in (h as Node3D).get_children():
				if e is CPUParticles3D:
					(e as CPUParticles3D).emitting = false)
	tw.tween_property(light, "light_energy", 0.0, 1.0)
	tw.tween_property(_mesh, "scale", Vector3(1.0, 0.04, 1.0), 1.0)
	tw.tween_callback(func(): _mesh.visible = false)
	# (the last embers have fallen by now)
	tw.tween_callback(func():
		light.queue_free()
		for h in holders:
			(h as Node).queue_free()).set_delay(2.0)
