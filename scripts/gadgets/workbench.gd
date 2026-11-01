class_name Workbench
extends Node3D
## A workbench where gadgets are built, upgraded and refilled (1.28, docs/gadgets_plan.md). F at it opens the bench
## (GameMenu "workbench": GadgetBenchScreen), and any blueprints in the bag are studied first.
## CONTRACT (lead, 2026-10-31): places that have one (the ship, camps, the volcanic isle's forge town) only call:
##   Workbench.place(parent: Node3D, at: Vector3, yaw: float, opts := {}) -> Workbench
## (`at` in parent's local space; opts "style": "ship" (tarred, lashed), "camp" (a folding field bench, dropped to the
## ground), "forge" (stone-topped, an anvil and embers), anything else the plain one; "solid": false leaves out its
## collider, for a parent that adds the shape itself, like a moving hull). Its front faces -Z.
## No per-frame work: a model, a collider and an Interactable (monitoring off).

const W := 1.5
const D := 0.7
const TOP := 0.92
const STYLES := ["plain", "ship", "camp", "forge"]

static var _meshes: Dictionary = {}

var style := "plain"


static func place(parent: Node3D, at: Vector3, yaw: float, opts := {}) -> Workbench:
	var w := Workbench.new()
	w.name = "Workbench"
	w.set_meta("opts", opts)
	w.style = str(opts.get("style", "plain"))
	parent.add_child(w)
	w.position = at
	w.rotation.y = yaw
	return w


func _ready() -> void:
	add_to_group("workbenches")
	if style == "camp":
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, global_position + Vector3.DOWN * 2.0, 1)
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		if not h.is_empty():
			global_position.y = (h["position"] as Vector3).y
	var mi := MeshInstance3D.new()
	mi.name = "Model"
	mi.mesh = mesh(style)
	mi.visibility_range_end = 70.0
	add_child(mi)
	if (get_meta("opts") as Dictionary).get("solid", true):
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0 if style == "camp" else W, TOP, D)
		cs.shape = box
		cs.position = Vector3(0, TOP * 0.5, 0)
		body.add_child(cs)
		add_child(body)
	var it := Interactable.new()
	it.name = "Use"
	it.collision_layer = 512
	it.collision_mask = 0
	it.prompt_text = "Workbench: build, upgrade, refill gadgets"
	it.gesture = "reach"
	it.reach = 1.6
	var ics := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.0
	ics.shape = sph
	it.add_child(ics)
	add_child(it)
	it.position = Vector3(0, 0.6, -D * 0.5 - 0.5)
	it.interacted.connect(use)


func use(p: Player) -> void:
	var learned := Gadgets.study(p)
	GameMenu.open_workbench(self)
	if not learned.is_empty():
		Net.fx("sfx", ["blip_high", global_position + Vector3(0, 1.0, 0), -6.0, 0.05])


## The bench's model at `style` (cached, one mesh each): top, legs, a back board of tools, a vise, a half-built
## gadget and its makings.
static func mesh(st: String) -> ArrayMesh:
	if _meshes.has(st):
		return _meshes[st]
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(st)
	var wood := PSXMat.lit("planks", Color(0.78, 0.6, 0.42))
	var dark := PSXMat.lit("planks", Color(0.42, 0.3, 0.22))
	var iron := PSXMat.lit("metal", Color(0.32, 0.31, 0.3))
	var brass := PSXMat.lit("metal", GadgetModels.BRASS)
	var rope := PSXMat.lit("rope")
	var w := W
	match st:
		"camp":
			w = 1.0
			# two crates and a plank across them, a roll of tools
			for sx in [-0.34, 0.34]:
				mb.add_box(PSXMat.lit("planks", Color(0.8, 0.65, 0.45)), Transform3D(Basis(Vector3.UP, rng.randf_range(-0.08, 0.08)), Vector3(sx, 0.36, 0)), Vector3(0.36, 0.72, 0.56), 1.0)
			mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.75, 0)), Vector3(w, 0.06, D), 1.0, Color.WHITE, false)
			mb.add_box(PSXMat.lit("fabric", Color(0.45, 0.32, 0.2)), Transform3D(Basis(), Vector3(-0.25, 0.8, 0.12)), Vector3(0.42, 0.04, 0.26), 2.0)
		_:
			var top_mat := PSXMat.lit("flagstones", Color(0.55, 0.52, 0.5)) if st == "forge" else (dark if st == "ship" else wood)
			mb.add_box(top_mat, Transform3D(Basis(), Vector3(0, TOP - 0.05, 0)), Vector3(w, 0.1, D), 1.0, Color.WHITE, false)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					mb.add_box(dark, Transform3D(Basis(), Vector3(sx * (w * 0.5 - 0.07), (TOP - 0.1) * 0.5, sz * (D * 0.5 - 0.07))), Vector3(0.1, TOP - 0.1, 0.1), 1.0)
			# a shelf low down with a crate of parts, the back board of tools
			mb.add_box(dark, Transform3D(Basis(), Vector3(0, 0.18, 0)), Vector3(w - 0.12, 0.04, D - 0.12), 1.0)
			mb.add_box(PSXMat.lit("planks", Color(0.8, 0.65, 0.45)), Transform3D(Basis(Vector3.UP, 0.15), Vector3(-0.35, 0.36, 0.02)), Vector3(0.4, 0.32, 0.36), 1.0)
			mb.add_box(dark, Transform3D(Basis(), Vector3(0, TOP + 0.45, D * 0.5 - 0.03)), Vector3(w, 0.8, 0.05), 1.0)
			# the tools hung on it: a saw, a mallet, pliers, a coil of rope
			mb.add_box(iron, Transform3D(Basis(Vector3.BACK, 0.1), Vector3(-0.45, TOP + 0.55, D * 0.5 - 0.07)), Vector3(0.35, 0.12, 0.01), 2.0)
			mb.add_box(wood, Transform3D(Basis(), Vector3(-0.1, TOP + 0.5, D * 0.5 - 0.08)), Vector3(0.04, 0.3, 0.04), 2.0)
			mb.add_box(dark, Transform3D(Basis(), Vector3(-0.1, TOP + 0.67, D * 0.5 - 0.08)), Vector3(0.14, 0.07, 0.07), 2.0)
			for k in range(2):
				mb.add_box(iron, Transform3D(Basis(Vector3.BACK, -0.25 + k * 0.5), Vector3(0.18 + k * 0.04, TOP + 0.5, D * 0.5 - 0.07)), Vector3(0.025, 0.22, 0.02), 2.0)
			var coil := PackedVector3Array()
			for i in range(15):
				var a := i * TAU / 7.0
				coil.append(Vector3(0.48 + cos(a) * 0.1, TOP + 0.55 + sin(a) * 0.1, D * 0.5 - 0.08 - i * 0.002))
			mb.add_tube(rope, coil, 0.018, 0.018, 4)
			# the vise at the right end
			mb.add_box(iron, Transform3D(Basis(), Vector3(w * 0.5 - 0.15, TOP + 0.08, -D * 0.5 + 0.12)), Vector3(0.16, 0.12, 0.1), 2.0)
			mb.add_box(iron, Transform3D(Basis(), Vector3(w * 0.5 - 0.15, TOP + 0.08, -D * 0.5 + 0.0)), Vector3(0.16, 0.12, 0.04), 2.0)
			mb.add_cylinder(iron, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(w * 0.5 - 0.15, TOP + 0.06, -D * 0.5 - 0.02)), 0.012, 0.012, 0.16, 4, 2.0)
			match st:
				"ship":
					# lashed to the bulwark with tarred rope, a lamp hook
					for sx in [-0.5, 0.5]:
						var lash := PackedVector3Array([Vector3(sx, TOP + 0.85, D * 0.5 + 0.02), Vector3(sx, TOP + 0.85, D * 0.5 - 0.05), Vector3(sx, TOP - 0.1, D * 0.5 - 0.05), Vector3(sx, TOP - 0.1, D * 0.5 + 0.02)])
						mb.add_tube(rope, lash, 0.015, 0.015, 4)
				"forge":
					# an anvil on a stump beside it, a pan of embers on the top
					mb.add_cylinder(dark, Transform3D(Basis(), Vector3(w * 0.5 + 0.45, 0.0, -0.05)), 0.24, 0.26, 0.55, 8, 1.0)
					mb.add_box(iron, Transform3D(Basis(), Vector3(w * 0.5 + 0.45, 0.65, -0.05)), Vector3(0.22, 0.2, 0.42), 2.0)
					mb.add_box(iron, Transform3D(Basis(), Vector3(w * 0.5 + 0.45, 0.8, -0.05)), Vector3(0.3, 0.1, 0.5), 2.0)
					mb.add_cylinder(iron, Transform3D(Basis(), Vector3(-0.45, TOP, -0.12)), 0.17, 0.2, 0.08, 8, 2.0, Color.WHITE, false)
					mb.add_blob(PSXMat.glow(Color(1.0, 0.42, 0.12), 2.0), Transform3D(Basis(), Vector3(-0.45, TOP + 0.06, -0.12)), Vector3(0.15, 0.04, 0.15), rng, 0.3, 3, 6, 4.0)
	# on top: a half-built gadget, springs, a lens, a blueprint pinned flat (every style)
	var y := 0.78 if st == "camp" else TOP
	mb.add_box(PSXMat.flat(Color(0.32, 0.5, 0.85)), Transform3D(Basis(Vector3.UP, 0.12), Vector3(-0.05, y + 0.005, -0.05)), Vector3(0.42, 0.006, 0.3), 2.0, Color.WHITE, true)
	mb.add_box(PSXMat.flat(Color(0.85, 0.9, 1.0)), Transform3D(Basis(Vector3.UP, 0.12), Vector3(-0.05, y + 0.01, -0.05)), Vector3(0.3, 0.003, 0.02), 2.0)
	mb.add_blob(PSXMat.flat(GadgetModels.CLAY), Transform3D(Basis(), Vector3(0.12, y + 0.045, -0.1)), Vector3(0.045, 0.042, 0.045), rng, 0.08, 4, 6, 4.0)
	mb.add_cylinder(brass, Transform3D(Basis(), Vector3(0.12, y + 0.035, -0.1)), 0.047, 0.047, 0.016, 8, 4.0, Color.WHITE, false)
	for k in range(3):
		mb.add_cylinder(iron, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.3 + k * 0.05, y + 0.015, -0.18)), 0.012, 0.012, 0.05, 5, 4.0)
	mb.add_cylinder(brass, Transform3D(Basis(), Vector3(0.32 if st != "camp" else 0.3, y, 0.05)), 0.05, 0.05, 0.03, 8, 4.0)
	_meshes[st] = mb.commit()
	return _meshes[st]
