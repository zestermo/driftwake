class_name HammerArts
## The hammer's shared blows and its techniques (tree "hammer": earth - sandstone shockwaves, rock thrown up,
## cracks and stone spikes). thud() (the head into the ground: the combo's smash and spin), quake() (a
## shockwave: the heavy, Hammerfall's landing, the techniques). Techniques are run by TechniqueState (`s`: its
## helpers and timeline); enter() and update() return false for ids that aren't theirs. Poses in HammerMoves.


## Where the hammer's head is now.
static func head(p: Player) -> Vector3:
	var w: MeshInstance3D = p.body_model.weapon
	return w.global_transform * Vector3(0, 0, w.mesh.get_aabb().position.z * 0.9)


## The ground under the head.
static func head_ground(p: Player) -> Vector3:
	var h := head(p)
	return Vector3(h.x, p.global_position.y, h.z)


## The head into the ground (a combo blow): dust, a few stones and a ring of dust; `big` (the spin's end) cracks
## the ground. With the element on every blow (the tree's tier 2) the rock and ring take its colours.
static func thud(p: Player, big: bool) -> void:
	var at := head_ground(p)
	var elem := p.progression.elemental("hammer", 2)
	var face := -p.player_model.global_basis.z
	Net.fx("heavy_dust", [at, 10 if big else 6, 0.7 if big else 0.5])
	Net.fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP + face * 0.3, 6 if big else 3, FX.tree_col("hammer", FX.ACCENT), 4.0])
	Net.fx("ring", [at, Vector3.UP, 2.4 if big else 1.3, _ring_col(p, elem), 0.26, 0.16])
	if big:
		Net.fx("ground_crack", [at, face, 2.2, Color(0, 0, 0, 0), randi() % 10000, 0.1])
	if elem:
		Net.fx("element", ["hammer", at + Vector3(0, 0.2, 0), Vector3.UP, 8 if big else 5, 4.0])
	Net.fx("sfx", ["thud", at, -3.0 if big else -7.0, 0.06, 0.7 if big else 0.85])
	CombatManager.apply_camera_shake(0.2 if big else 0.1)


## A shockwave from `at`: everyone within `r` (not in `already`) takes `hit`; rings racing out over the ground,
## dust, rock, cracks running out, the ground shaking. `elem`: stone spikes heave up round it and the rings take
## the tree's colours.
static func quake(p: Player, at: Vector3, r: float, hit: HitData, already: Array, elem: bool) -> void:
	var col := _ring_col(p, elem)
	var face := -p.player_model.global_basis.z
	Net.fx("ring", [at, Vector3.UP, r, col, 0.32, 0.12])
	Net.fx("ring", [at, Vector3.UP, r * 0.6, FX.tree_col("hammer" if elem else "plain", FX.CORE), 0.22, 0.2])
	Net.fx("dust_ring", [at, 18, 1.1])
	Net.fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP, 8, FX.tree_col("hammer", FX.ACCENT), 5.0])
	Net.fx("impact", [at + Vector3(0, 0.2, 0), FX.tree_col("hammer" if elem else "plain", FX.CORE)])
	for k in 3:
		var d := face.rotated(Vector3.UP, (k - 1) * 0.9 + randf_range(-0.2, 0.2))
		Net.fx("ground_crack", [at, d, r * 0.8, Color(0, 0, 0, 0), randi() % 10000, 0.12])
	if elem:
		Net.fx("rock_spikes", [at, r * 0.7, 7, randi() % 10000, 1.0, 0.8])
		Net.fx("element", ["hammer", at + Vector3(0, 0.3, 0), Vector3.UP, 10, 5.0])
	Net.fx("sfx", ["thud", at, 2.0, 0.05, 0.6])
	CombatManager.apply_camera_shake(0.3)
	CombatManager.apply_camera_kick(0.14, 0.3)
	burst(p, at, r, hit, already)


## Everyone within `r` of `at` (not in `already`) takes `hit`.
static func burst(p: Player, at: Vector3, r: float, hit: HitData, already: Array) -> void:
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = r
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.6, 0))
	q.collision_mask = 32
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for res in p.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var area := res["collider"] as Hurtbox
		if area and area.owner and area.owner != p and not (area.owner in already):
			already.append(area.owner)
			area.take_hit(hit, p)


## A shockwave's ring: dust before the element, sandstone after; black with a Haki coat.
static func _ring_col(p: Player, elem: bool) -> Color:
	if p.power.buff("coat"):
		return Player.HAKI_TRAIL
	return FX.tree_col("hammer", FX.EDGE) if elem else FX.tree_col("plain", FX.ACCENT)


static func enter(_s, _id: String) -> bool:
	return false


static func update(_s, _delta: float) -> bool:
	return false
