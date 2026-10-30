class_name CanalUndercity
extends Node3D
## The canal city's undercity (1.27, docs/v1_27_plan.md "Canal set pieces": flooded cellars, smugglers' tunnels).
## A sealed pocket like the brig (AdmiraltyBrig): built under the City node at POCKET (frame space, high above the
## city: below the quays the sea would count as deep water), its brick vaults lit by a few lanterns. Trapdoors in
## the calli (rolled from the world's seed, one per arm) take you down; the ladder at each arm's end brings you
## back up to its trapdoor.
##
## The pocket (its own space, the hall's floor at 0): a flooded cistern hall (HALL_HALF each way, pillars, water to
## the ankles) with four tunnels out to a ladder chamber each; off the east tunnel the smugglers' den with their
## stash; caches in the north and west chambers (CityCaches, saved by key). Built the same on every machine: each
## captain climbs on their own, so nothing goes over the net.

const POCKET := Vector3(0.0, 360.0, 0.0)
const HALL_HALF := 9.0
const HALL_H := 5.5
const ARM_W := 3.0
const ARM_H := 3.2
## Where each arm's chamber is (its middle, out from the hall's middle) and its half size.
const CHAMBER_R := 33.5
const CHAMBER_HALF := 2.5
const WATER_Y := 0.3
const DIRS := {"n": Vector2(0, -1), "e": Vector2(1, 0), "s": Vector2(0, 1), "w": Vector2(-1, 0)}
const OPP := {"n": "s", "s": "n", "e": "w", "w": "e"}
const DEN := Vector2(20.0, 5.0)
const DEN_HALF := Vector2(4.0, 3.5)

## Each arm's trapdoor in the city (frame point, its floor's height), by arm.
var hatches := {}
var _brick: Material
var _vault: Material
var _wood: Material
var _iron: Material
var _body: StaticBody3D
var _mb: MeshBuilder


## Build it under `city` (the canal island's City node, CanalPlan's frame): `calli` are the floors to put the
## trapdoors in, `seed` the world's.
func build(city: Node3D, calli: Array, seed: int) -> void:
	name = "Undercity"
	position = POCKET
	city.add_child(self)
	_brick = PSXMat.lit("stone_brick", Color(0.72, 0.62, 0.55))
	_vault = PSXMat.lit("stone_brick", Color(0.5, 0.45, 0.42))
	_wood = PSXMat.lit("planks_dark")
	_iron = PSXMat.lit("metal", Color(0.35, 0.36, 0.38))
	_body = StaticBody3D.new()
	_body.name = "Vaults"
	add_child(_body)
	_mb = MeshBuilder.new()
	_space(Vector2.ZERO, Vector2(HALL_HALF, HALL_HALF), HALL_H, {"n": ARM_W, "e": ARM_W, "s": ARM_W, "w": ARM_W})
	for p in [Vector2(-4.5, -4.5), Vector2(4.5, -4.5), Vector2(-4.5, 4.5), Vector2(4.5, 4.5)]:
		_box(_brick, Vector3(p.x, HALL_H * 0.5, p.y), Vector3(1.2, HALL_H, 1.2))
	var span := (CHAMBER_R - CHAMBER_HALF - HALL_HALF) * 0.5
	for k in DIRS:
		var d: Vector2 = DIRS[k]
		var mid: Vector2 = d * (HALL_HALF + span)
		var half := Vector2(span, ARM_W * 0.5) if d.y == 0.0 else Vector2(ARM_W * 0.5, span)
		var gaps := {k: ARM_W, OPP[k]: ARM_W}
		if k == "e":
			gaps["s"] = 2.4
		_space(mid, half, ARM_H, gaps, [k, OPP[k]])
		# brick ribs across the tunnel every few metres, so it reads as a vault
		var t := Vector2(-d.y, d.x)
		var n := int(span * 2.0 / 3.5)
		for i in range(1, n):
			var rp: Vector2 = d * (HALL_HALF + i * span * 2.0 / n)
			_mb.add_box(_brick, Transform3D(Basis(), Vector3(rp.x, ARM_H - 0.2, rp.y)), _sz(t, ARM_W * 0.5, 0.4) + Vector3(0.1, 0, 0.1) * Vector3(absf(d.x), 0, absf(d.y)), 0.5, Color.WHITE, false)
		_space(d * CHAMBER_R, Vector2(CHAMBER_HALF, CHAMBER_HALF), ARM_H + 0.3, {OPP[k]: ARM_W})
		_ladder(k)
	# the smugglers' den, off the east tunnel: crates, a table, their lantern and the stash
	_space(DEN, DEN_HALF, ARM_H, {"n": 2.4})
	for c in [Vector3(16.8, 0.45, 7.5), Vector3(17.8, 0.45, 7.7), Vector3(17.2, 1.3, 7.6), Vector3(23.2, 0.45, 2.7)]:
		_box(_wood, c, Vector3(0.9, 0.9, 0.9))
	_box(_wood, Vector3(21.0, 0.8, 6.0), Vector3(2.0, 0.1, 1.1))
	for lx in [20.2, 21.8]:
		_box(_wood, Vector3(lx, 0.4, 6.0), Vector3(0.12, 0.8, 0.9))
	# the cistern's water, to the ankles
	var water := MeshInstance3D.new()
	water.name = "Water"
	var wm := PlaneMesh.new()
	wm.size = Vector2(HALL_HALF * 2.0, HALL_HALF * 2.0)
	water.mesh = wm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.2, 0.18, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.2
	water.material_override = mat
	water.position = Vector3(0, WATER_Y, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	add_child(_mb.to_instance("Brick"))
	for at in [Vector3(0, HALL_H - 0.8, 0), Vector3(DEN.x, ARM_H - 0.6, DEN.y), Vector3(0, ARM_H - 0.6, 22.0)]:
		var lamp := OmniLight3D.new()
		lamp.position = at
		lamp.omni_range = 13.0
		lamp.light_energy = 1.4
		lamp.light_color = Color(1.0, 0.75, 0.5)
		lamp.shadow_enabled = false
		add_child(lamp)
	CityCaches.place(self, [
		CityCaches.entry(Transform3D(Basis(), Vector3(DEN.x + 2.6, 0.0, DEN.y + 2.2)), "canal_under_stash"),
		CityCaches.entry(Transform3D(Basis(), Vector3(1.6, 0.0, -CHAMBER_R - 1.6)), "canal_under_north"),
		CityCaches.entry(Transform3D(Basis(), Vector3(-CHAMBER_R - 1.6, 0.0, 1.6)), "canal_under_west")])
	_hatches(city, calli, seed)


## A room: floor, vault and walls round `c` (frame xz, half size), `h` high, each side with a gap of its width in
## the middle; `open` sides get no wall at all (a tunnel's ends).
func _space(c: Vector2, half: Vector2, h: float, gaps: Dictionary, open: Array = []) -> void:
	_box(_vault, Vector3(c.x, -0.15, c.y), Vector3(half.x * 2.0, 0.3, half.y * 2.0))
	_box(_vault, Vector3(c.x, h + 0.15, c.y), Vector3(half.x * 2.0 + 0.6, 0.3, half.y * 2.0 + 0.6))
	for k in DIRS:
		if k in open:
			continue
		var d: Vector2 = DIRS[k]
		var along := half.y if d.y == 0.0 else half.x
		var at: Vector2 = c + Vector2(d.x * half.x, d.y * half.y) + d * 0.15
		var g: float = gaps.get(k, 0.0)
		var t := Vector2(-d.y, d.x)
		if g <= 0.0:
			_wall(at, t, along, h)
			continue
		var piece := (along * 2.0 - g) * 0.5
		for s in [-1.0, 1.0]:
			_wall(at + t * s * (g * 0.5 + piece * 0.5), t, piece * 0.5, h)
		# the lintel over the gap, down to a tunnel's ceiling where the room is taller (no sky between them)
		var lh := maxf(0.6, h - ARM_H)
		_box(_brick, Vector3(at.x, h - lh * 0.5, at.y), _sz(t, g * 0.5, lh))


func _wall(at: Vector2, t: Vector2, half_len: float, h: float) -> void:
	if half_len <= 0.01:
		return
	_box(_brick, Vector3(at.x, h * 0.5, at.y), _sz(t, half_len + 0.15, h))


## A box `h` high, `half_len` each way along t, 0.3 thick.
func _sz(t: Vector2, half_len: float, h: float) -> Vector3:
	return Vector3(half_len * 2.0, h, 0.3) if absf(t.x) > 0.5 else Vector3(0.3, h, half_len * 2.0)


func _box(m: Material, at: Vector3, size: Vector3) -> void:
	_mb.add_box(m, Transform3D(Basis(), at), size, 0.5, Color.WHITE, false)  # (its underside drawn: the vaults are seen from below)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = at
	_body.add_child(cs)


## The ladder up out of an arm's chamber (on its far wall) and the hatch over it.
func _ladder(k: String) -> void:
	var d: Vector2 = DIRS[k]
	var foot: Vector2 = d * (CHAMBER_R + CHAMBER_HALF - 0.5)
	var t := Vector2(-d.y, d.x)
	for s in [-0.35, 0.35]:
		var r: Vector2 = foot + t * s
		_mb.add_box(_wood, Transform3D(Basis(), Vector3(r.x, ARM_H * 0.5, r.y)), Vector3(0.08, ARM_H, 0.08), 0.5)
	for i in range(7):
		_mb.add_box(_wood, Transform3D(Basis(), Vector3(foot.x, 0.35 + i * 0.42, foot.y)), _sz(t, 0.38, 0.06) * Vector3(1, 1, 1), 0.5)
	_mb.add_box(_iron, Transform3D(Basis(), Vector3(foot.x, ARM_H + 0.25, foot.y)), Vector3(1.1, 0.08, 1.1), 0.5)
	var up := _interact("Up_" + k, Vector3(foot.x, 1.0, foot.y) - Vector3(d.x, 0, d.y) * 0.6, "Climb up")
	up.interacted.connect(func(p: Player): _climb_up(p, k))


## A trapdoor per arm in a calle (rolled), each with its prompt to climb down.
func _hatches(city: Node3D, calli: Array, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "undercity"])
	var pool := calli.duplicate()
	pool.sort_custom(func(a, b): return str(a[0]) < str(b[0]))
	for k in DIRS:
		if pool.is_empty():
			break
		var f: Array = pool.pop_at(rng.randi() % pool.size())
		var r: Rect2 = f[1]
		var at := r.get_center()
		var y := CanalPlan.QUAY_Y
		hatches[k] = [at, y]
		var hatch := Node3D.new()
		hatch.name = "Hatch_" + k
		hatch.position = Vector3(at.x, y, at.y)
		city.add_child(hatch)
		var hm := MeshBuilder.new()
		hm.add_box(_wood, Transform3D(Basis(), Vector3(0, 0.03, 0)), Vector3(1.3, 0.06, 1.3), 0.5)
		for z in [-0.4, 0.4]:
			hm.add_box(_iron, Transform3D(Basis(), Vector3(0, 0.07, z)), Vector3(1.34, 0.03, 0.1), 0.5)
		hm.add_box(_iron, Transform3D(Basis(), Vector3(0.45, 0.1, 0)), Vector3(0.08, 0.06, 0.22), 0.5)
		hatch.add_child(hm.to_instance("Trapdoor"))
		var down := Interactable.new()
		down.name = "Down"
		down.prompt_text = "Climb down into the cellars"
		down.collision_layer = 512
		down.collision_mask = 0
		down.position = Vector3(0, 0.8, 0)
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 1.0
		cs.shape = sh
		down.add_child(cs)
		hatch.add_child(down)
		down.interacted.connect(func(p: Player): _climb_down(p, k))


func _interact(n: String, at: Vector3, prompt: String) -> Interactable:
	var a := Interactable.new()
	a.name = n
	a.prompt_text = prompt
	a.collision_layer = 512
	a.collision_mask = 0
	a.position = at
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.0
	cs.shape = sh
	a.add_child(cs)
	add_child(a)
	return a


## Down through arm k's trapdoor: into its chamber, facing the hall.
func _climb_down(p: Player, k: String) -> void:
	var d: Vector2 = DIRS[k]
	var at: Vector2 = d * (CHAMBER_R - 0.5)
	p.global_position = to_global(Vector3(at.x, 0.2, at.y))
	p.reset_physics_interpolation()


## Up arm k's ladder: out beside its trapdoor.
func _climb_up(p: Player, k: String) -> void:
	if not hatches.has(k):
		return
	var h: Array = hatches[k]
	var city := get_parent() as Node3D
	p.global_position = city.to_global(Vector3((h[0] as Vector2).x + 1.2, float(h[1]) + 0.3, (h[0] as Vector2).y))
	p.reset_physics_interpolation()
