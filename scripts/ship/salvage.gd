class_name Salvage
extends Node3D
## Salvage: the timber, iron, canvas and copper that pay for Tackett's higher
## upgrade levels (ShipLines). Sunk ships leave it floating (scatter: crates,
## spars and bundles bobbing on the swell); wrecks and chests hold it (roll,
## the loot-table hook). Sail the ship through a piece with your captain aboard
## or swim up to it and it's yours. Each captain finds their own (every screen
## scatters its own copy from the same seed), like the floating plunder.

const KINDS := ["timber", "iron", "canvas", "copper"]
## [weight, weight per point of richness, fewest, most] per kind.
const TABLE := {"timber": [5.0, 0.0, 2, 4], "canvas": [3.0, 0.0, 1, 3], "iron": [2.0, 4.0, 1, 3], "copper": [0.6, 2.0, 1, 2]}
## A sunk ship's haul: [pieces, richness] by kind (bigger ship, better haul).
const HAULS := {"gunboat": [3, 0.1], "sloop": [4, 0.2], "marine": [5, 0.6], "brig": [6, 0.4], "hunter": [4, 0.35], "frigate": [7, 0.7]}
## Swimming: how close you take it. Sailing: how far past her side a piece is still swept up.
const SWIM_REACH := 1.8
const HULL_REACH := 1.2
const LIFE := 600.0
const GLINT_EVERY := 2.6

var item_id: String = "timber"
var qty: int = 1
var drift := Vector3.ZERO
var _t: float = 0.0
var _glint: float = 0.0
var _phase: float = 0.0

static var _meshes: Dictionary = {}


## The loot-table hook: what `pieces` finds of salvage give ([[item id, qty], ...], kinds merged).
## `rich` (0..1) tips it toward iron and copper. Island chests and wrecks call it with their own rng.
static func roll(rng: RandomNumberGenerator, pieces: int, rich: float = 0.2) -> Array:
	var got := {}
	for i in range(pieces):
		var total := 0.0
		for k in KINDS:
			total += float(TABLE[k][0]) + float(TABLE[k][1]) * rich
		var r := rng.randf() * total
		var pick: String = KINDS[0]
		for k in KINDS:
			r -= float(TABLE[k][0]) + float(TABLE[k][1]) * rich
			if r <= 0.0:
				pick = k
				break
		got[pick] = int(got.get(pick, 0)) + rng.randi_range(int(TABLE[pick][2]), int(TABLE[pick][3]))
	var out: Array = []
	for k in KINDS:
		if got.has(k):
			out.append([k, got[k]])
	return out


## A sunk ship of `kind` at `at` leaves its haul floating round it (seeded: the same pieces on every screen).
static func scatter(parent: Node, at: Vector3, kind: String, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var haul: Array = HAULS.get(kind, HAULS["sloop"])
	var out: Array = []
	var n := int(haul[0])
	for i in range(n):
		var s := Salvage.new()
		var e: Array = roll(rng, 1, float(haul[1]))[0]
		s.item_id = e[0]
		s.qty = int(e[1])
		s.name = "Salvage_%d_%d" % [seed_value & 0xffff, i]
		var a := TAU * (i + rng.randf() * 0.6) / n
		var dir := Vector3(cos(a), 0.0, sin(a))
		s.drift = dir * rng.randf_range(1.2, 2.4)
		parent.add_child(s)
		s.global_position = Vector3(at.x, 0.0, at.z) + dir * rng.randf_range(2.0, 6.0)
		s.rotation.y = rng.randf() * TAU
		out.append(s)
	return out


func _ready() -> void:
	add_to_group("salvage")
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh_of(item_id)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 220.0
	# (a little over life size: it has to read from a deck under way)
	mi.scale = Vector3.ONE * 1.35
	add_child(mi)
	_phase = randf() * TAU
	_glint = randf() * GLINT_EVERY


func item() -> ItemData:
	return ItemDB.get_item(item_id)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		queue_free()
		return
	var me := get_tree().get_first_node_in_group("player") as Player
	if me == null or me.global_position.distance_to(global_position) > 260.0:
		return
	# drifting apart from where she went down, bobbing on the swell
	drift *= exp(-0.35 * delta)
	var p := global_position + drift * delta
	p.y = float(Ocean.get_wave_height(p)) - 0.12
	global_position = p
	rotation.x = sin(_t * 1.3 + _phase) * 0.14
	rotation.z = cos(_t * 1.1 + _phase) * 0.12
	_glint -= delta
	if _glint <= 0.0:
		_glint = GLINT_EVERY
		if me.global_position.distance_to(global_position) < 90.0:
			FX.glint(global_position + Vector3.UP * 0.45, Color(1.0, 0.92, 0.6), 0.6)
	if Engine.get_physics_frames() % 4 == 0 and _reached(me):
		collect(me)


## Our captain swims up to it, or sails the ship over it from aboard.
func _reached(me: Player) -> bool:
	if me.global_position.distance_to(global_position) < SWIM_REACH:
		return true
	var ship := me.get_tree().get_first_node_in_group("ship") as Ship
	if ship == null or not ship.aboard(me.global_position):
		return false
	var l := ship.global_transform.affine_inverse() * global_position
	return l.z > HullBuilder.RINGS[HullBuilder.RINGS.size() - 1][0] - 1.0 and l.z < HullBuilder.QD_BACK + 1.0 \
		and absf(l.x) < HullBuilder.half_width(l.z) + HULL_REACH


## Into our captain's bag (all of it or nothing: a full bag leaves it floating).
func collect(me: Player) -> bool:
	var it := item()
	if me.inventory_component.room_for(it) < qty:
		if _t - _full_said > 8.0:
			_full_said = _t
			me.call("_toast", "Your bag is full: no room for the %s" % it.display_name.to_lower())
		return false
	me.inventory_component.add_item(it, qty)
	var at := global_position + Vector3.UP * 0.4
	FX.splash(global_position, 6, 0.7)
	FX.sparkle(at, 12, Color(1.0, 0.9, 0.55))
	FX.float_text(at + Vector3.UP * 0.6, "+%d %s" % [qty, it.display_name.to_lower()], Color(1.0, 0.86, 0.5), 26)
	FX.sfx("coin", at, -2.0, 0.1, 0.8)
	FX.sfx("wood_crack", at, -12.0, 0.1, 1.4)
	queue_free()
	return true


var _full_said: float = -99.0


## What a piece looks like afloat (shared per kind): spars, an iron-bound crate,
## a bundle of sailcloth, a crate of copper sheet.
static func mesh_of(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark", Color(0.85, 0.72, 0.55))
	var plank := PSXMat.lit("planks", Color(0.9, 0.75, 0.5))
	var iron := PSXMat.lit("metal", Color(0.3, 0.3, 0.33))
	var rope := PSXMat.lit("rope")
	match kind:
		"timber":
			mb.add_box(plank, Transform3D(Basis(Vector3.UP, 0.25), Vector3(0, 0.05, 0)), Vector3(0.4, 0.12, 1.7), 1.0, Color.WHITE, false)
			mb.add_box(plank, Transform3D(Basis(Vector3.UP, -0.35), Vector3(0.15, 0.15, 0.1)), Vector3(0.35, 0.1, 1.5), 1.0, Color(0.85, 0.85, 0.85), false)
			mb.add_cylinder(wood, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.35, 0.08, -1.0)), 0.13, 0.11, 2.0, 6, 0.8)
			for z in [-0.4, 0.4]:
				mb.add_box(rope, Transform3D(Basis(), Vector3(-0.05, 0.12, z)), Vector3(0.75, 0.06, 0.08), 1.0)
		"iron":
			mb.add_box(plank, Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(0.75, 0.6, 0.75), 1.0, Color.WHITE, false)
			for x in [-0.25, 0.25]:
				mb.add_box(iron, Transform3D(Basis(), Vector3(x, 0.1, 0)), Vector3(0.08, 0.62, 0.77), 1.0, Color.WHITE, false)
			mb.add_box(iron, Transform3D(Basis(), Vector3(0, 0.42, 0.1)), Vector3(0.5, 0.06, 0.3), 1.0)
			mb.add_box(iron, Transform3D(Basis(Vector3.UP, 0.4), Vector3(-0.05, 0.47, -0.15)), Vector3(0.35, 0.05, 0.2), 1.0)
		"canvas":
			mb.add_cylinder(PSXMat.lit("canvas", Color(0.95, 0.92, 0.82)), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.1, -0.65)), 0.3, 0.3, 1.3, 7, 0.8)
			mb.add_cylinder(wood, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.3, 0.05, -1.0)), 0.08, 0.08, 2.0, 6, 0.8)
			for z in [-0.4, 0.0, 0.4]:
				mb.add_cylinder(rope, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.1, z - 0.04)), 0.32, 0.32, 0.08, 7, 1.0)
		"copper":
			mb.add_box(plank, Transform3D(Basis(), Vector3(0, 0.05, 0)), Vector3(0.7, 0.45, 0.6), 1.0, Color(0.8, 0.8, 0.8), false)
			var cu := PSXMat.lit("metal", Color(1.25, 0.62, 0.32), {"emission": Color(0.5, 0.22, 0.08), "emission_energy": 0.5})
			for k in range(3):
				mb.add_box(cu, Transform3D(Basis(Vector3.UP, k * 0.35 - 0.3), Vector3(0, 0.3 + k * 0.035, 0)), Vector3(0.6, 0.03, 0.45), 1.0)
	mb.fold_tints()
	_meshes[kind] = mb.commit()
	return _meshes[kind]
