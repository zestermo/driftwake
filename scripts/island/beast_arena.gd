extends Node3D
class_name BeastArena
## The beast's ground on a generated island's far side (GenIsland.sites["boss"]):
## a fight-sized floor under a closed canopy, ringed by giant trees the beasts
## use (perches on their limbs, trunks to coil up, thick brush between them to
## hide in), dressed for whichever beast the chain gave the island (BeastPool),
## and the beast asleep in the middle.
##
## The fight runs like Redtide's (the host decides, everyone sees): a banner as
## you come near, it wakes when a standing captain comes within WAKE_R, the top
## boss bar while it fights, a reset (healed, back to sleep) once everyone's
## been gone RESET_R for 6 s. Beaten: a banner, the fanfare, its hoard once per
## character (its trophy in it), Dialogue flag "isle<id>_boss_beaten" (the
## village's job and the log pose read it). It's back after RESPAWN with nobody
## near (net_spawner).

const WAKE_R := 24.0
const RESET_R := 48.0
const RESPAWN := 900.0
## The fighting floor (clear) and where the ring of giants stands.
const FLOOR_R := 19.0
const RING_R := 25.0
const TREES := 9
const BANNERS := {
	"ape": ["The Beast's Ground", "Smashed trees, gnawed bones. Something huge sleeps here."],
	"serpent": ["The Strangler's Hollow", "Shed skins as long as a ship. Something coils in the dark."],
	"stalker": ["The Shade's Run", "Claw marks high up the trunks. Something is watching you."],
	"mantis": ["The Queen's Bower", "Husks hang in the branches, sucked dry."],
}

var isl: GenIsland
var kind: String = "ape"
var boss: Node3D
var boss_gen: int = 0
## The ring's giants: {base, top, r, perch (on the inward limb), crown (Node3D), ang} (world).
var trees: Array = []
## Thick brush round the floor's edge (world): the stalker hides in it.
var brush: Array = []
var _empty_t: float = 0.0
var _dead_t: float = 0.0
var _celebrated: bool = false
var _arrived: bool = false
var _boss_ui: bool = false
var _shakes := {}


static func build(gi: GenIsland, _rng: RandomNumberGenerator) -> BeastArena:
	var site := gi.site_node("boss")
	var a := BeastArena.new()
	a.name = "Arena"
	a.isl = gi
	a.kind = str(gi.node["beast"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(gi.node["seed"]) + 7701
	a._dress(rng, site)
	site.add_child(a)
	var baker := gi.get_parent().get_node_or_null("NavBaker")
	if baker:
		baker.add_zone(site, 42.0, false, gi.terrain_faces)
	return a


## (tests and tools) The island's beast swapped for `kind` (look `variant`), its ground dressed afresh for it.
static func rebuild(gi: GenIsland, kind: String, variant: int = 0) -> BeastArena:
	gi.node["beast"] = kind
	gi.node["beast_look"] = variant
	gi.node["beast_name"] = BeastPool.NAMES[kind][0]
	var site := gi.site_node("boss")
	for c in site.get_children():
		c.free()
	var a := build(gi, null)
	# (the village's job held the old one)
	var vil := gi.get_node_or_null("Site_village/Village")
	if vil:
		vil.jobs["beast"]["check"] = func() -> bool: return Dialogue.has_flag(a._beaten_flag())
	return a


## The fight's ground: its middle (island space), the floor's radius, the spots
## for the ring of giants and the way in. The jungle theme's canopy-arena request
## takes this over (the one place to swap).
func _ground(rng: RandomNumberGenerator) -> Dictionary:
	var c: Vector2 = isl.sites["boss"]
	var entry: Vector2 = (isl.sites["village"] - c).normalized()
	for path in isl.paths:
		var pts: PackedVector2Array = path
		if pts[pts.size() - 1].distance_to(c) < 3.0:
			entry = (pts[maxi(pts.size() - 6, 0)] - c).normalized()
	var ring: Array = []
	var a0 := entry.angle()
	for i in range(TREES):
		var a := a0 + TAU * (i + 0.5) / TREES + rng.randf_range(-0.12, 0.12)
		if absf(angle_difference(a, a0)) < 0.42:
			continue
		ring.append(c + Vector2.from_angle(a) * (RING_R + rng.randf_range(-1.5, 2.5)))
	return {"c": c, "floor": FLOOR_R, "ring": ring, "entry": entry}


# ==========================================================================
# The ground
# ==========================================================================
func _dress(rng: RandomNumberGenerator, site: Node3D) -> void:
	var g := _ground(rng)
	var c: Vector2 = g["c"]
	var y0 := isl.hv(c)
	var body := StaticBody3D.new()
	body.name = "Giants"
	var bark := PSXMat.lit("bark", Color(0.82, 0.78, 0.72))
	var moss := PSXMat.lit("bark", Color(0.55, 0.75, 0.42))
	var mb := MeshBuilder.new()
	var crowns := [_crown_mesh(1), _crown_mesh(2), _crown_mesh(3)]
	for i in range((g["ring"] as Array).size()):
		var p: Vector2 = g["ring"][i]
		var at := Vector3(p.x - c.x, isl.hv(p) - y0, p.y - c.y)
		var inward := Vector3(-at.x, 0.0, -at.z).normalized()
		var t := _giant(mb, bark, moss, rng, at, inward)
		KitLandmarks.cyl_col(body, float(t["r"]) * 1.05, float(t["h"]), at + Vector3(0, float(t["h"]) * 0.5, 0))
		var crown := MeshInstance3D.new()
		crown.name = "Crown%d" % i
		crown.mesh = crowns[i % crowns.size()]
		crown.position = t["top"]
		crown.rotation.y = atan2(-inward.x, -inward.z)
		add_child(crown)
		GrapplePoints.add(self, t["perch"] + Vector3(0, 1.2, 0))
		trees.append({"base": at, "top": t["top"], "r": t["r"], "perch": t["perch"], "crown": crown, "ang": atan2(at.z, at.x)})
	_brush(rng, g)
	_floor(mb, bark, rng, g)
	match kind:
		"ape":
			_dress_ape(mb, body, rng, c, y0)
		"serpent":
			_dress_serpent(mb, rng, c, y0)
		"stalker":
			_dress_stalker(mb, rng, c, y0)
		"mantis":
			_dress_mantis(mb, rng, c, y0)
	body.add_child(mb.to_instance("Dressing"))
	site.add_child(body)
	# (the arena sits at the site's origin: world positions for the beasts)
	for t in trees:
		for k in ["base", "top", "perch"]:
			t[k] = site.to_global(t[k])
	for i in range(brush.size()):
		brush[i] = site.to_global(brush[i])


## One of the ring's giants at `at` (local), leaning a touch over the floor:
## buttress roots, a mossy foot, big limbs (one reaching in level enough to
## crouch on: the perch), vines hanging off them. Returns its h, r, top, perch.
func _giant(mb: MeshBuilder, bark: Material, moss: Material, rng: RandomNumberGenerator, at: Vector3, inward: Vector3) -> Dictionary:
	var h := rng.randf_range(23.0, 29.0)
	var r := rng.randf_range(1.25, 1.6)
	var lean := Basis(inward.cross(Vector3.UP).normalized(), -rng.randf_range(0.03, 0.07))
	mb.add_cylinder(bark, Transform3D(lean, at + Vector3(0, -0.4, 0)), r, r * 0.5, h, 9, 0.35, Color.WHITE, true, false, true)
	mb.add_cylinder(moss, Transform3D(lean, at + Vector3(0, -0.4, 0)), r * 1.06, r * 0.98, 2.2, 9, 0.35, Color.WHITE, false, false, true)
	var top := at + lean * Vector3(0, h - 0.4, 0)
	# buttress roots: fins flaring out from the foot
	for k in range(6):
		var a := TAU * k / 6.0 + rng.randf_range(-0.25, 0.25)
		var out := Vector3(cos(a), 0, sin(a))
		var fh := rng.randf_range(2.4, 3.6)
		var fl := rng.randf_range(2.2, 3.4)
		var fin := PackedVector2Array([Vector2(0, -0.3), Vector2(fl, -0.3), Vector2(fl * 0.55, fh * 0.18), Vector2(fl * 0.2, fh * 0.55), Vector2(0, fh)])
		var b := Basis(Vector3.UP, -a)
		mb.add_extrude(bark, Transform3D(b, at + out * r * 0.7 + b * Vector3(0, 0, -0.18)), fin, 0.36, 0.5, Color(0.85, 0.85, 0.8))
	# limbs: the perch reaching in, two more up and out
	var side := inward.cross(Vector3.UP).normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
	var py := rng.randf_range(12.5, 14.5)
	var root := at + lean * Vector3(0, py, 0)
	var tip := root + inward * 6.5 + side * 1.2 + Vector3(0, 1.4, 0)
	mb.add_tube(bark, MeshBuilder.curve_points(root, root + inward * 3.2 + Vector3(0, -0.4, 0), tip, 8), 0.55, 0.2, 6, 0.6)
	var perch := root + inward * 3.0 + side * 0.3 + Vector3(0, 0.15, 0)
	for k in range(2):
		var ly := rng.randf_range(0.62, 0.82) * h
		var l0 := at + lean * Vector3(0, ly, 0)
		var dir := (inward * rng.randf_range(0.2, 0.9) - side * (1.0 if k == 0 else -1.0)).normalized()
		var l1 := l0 + dir * rng.randf_range(5.0, 8.0) + Vector3(0, rng.randf_range(2.5, 4.5), 0)
		mb.add_tube(bark, MeshBuilder.curve_points(l0, l0 + dir * 2.5 + Vector3(0, 0.3, 0), l1, 7), 0.45, 0.14, 6, 0.6)
	# vines hanging off the perch limb and the trunk
	var vine := PSXMat.lit("bark", Color(0.42, 0.6, 0.3))
	for k in range(3):
		var v0 := root.lerp(tip, rng.randf_range(0.25, 0.95)) + Vector3(0, -0.3, 0)
		var v1 := v0 + Vector3(rng.randf_range(-0.6, 0.6), -rng.randf_range(6.0, 10.0), rng.randf_range(-0.6, 0.6))
		mb.add_tube(vine, MeshBuilder.sag_points(v0, v1, 0.4, 6), 0.07, 0.05, 4, 1.0)
	return {"h": h, "r": r, "top": top, "perch": perch}


## A giant's crown (its own space: -z toward the floor's middle): a broad roof of
## leaf masses reaching in over the floor, vines and fringe hanging under it.
func _crown_mesh(seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150 + seed_v
	var mb := MeshBuilder.new()
	var leaves := PSXMat.lit("leaves", Color(0.82, 0.92, 0.8), {"affine": 0.5})
	var fringe := PSXMat.cutout("bush", Color(0.8, 0.92, 0.78), 0.05, 1.0)
	var vine := PSXMat.lit("bark", Color(0.42, 0.6, 0.3))
	var blobs := [Vector3(0, 0.5, 0), Vector3(-3.0, 1.0, 1.5), Vector3(3.2, 0.6, 1.0), Vector3(0, -0.6, -4.5), Vector3(-3.5, -1.4, -7.5),
		Vector3(2.8, -1.0, -8.0), Vector3(0, -1.8, -11.0), Vector3(-1.5, 1.6, -2.5)]
	for b: Vector3 in blobs:
		var r := rng.randf_range(3.6, 5.2)
		var col := Color.WHITE.darkened(rng.randf_range(0.0, 0.25))
		mb.add_blob(leaves, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), b), Vector3(r, r * rng.randf_range(0.45, 0.6), r), rng, 0.25, 3, 7, 0.4, col)
		# fringe drooping under each mass, vines below
		for k in range(2):
			var f := b + Vector3(rng.randf_range(-r, r) * 0.6, -r * 0.45, rng.randf_range(-r, r) * 0.6)
			mb.add_cross_cards(fringe, Transform3D(Basis(Vector3.RIGHT, PI).rotated(Vector3.UP, rng.randf() * PI), f + Vector3(0, 0.2, 0)), 2.4, 1.8, 2)
		var v0 := b + Vector3(rng.randf_range(-1.5, 1.5), -r * 0.4, rng.randf_range(-1.5, 1.5))
		mb.add_tube(vine, MeshBuilder.sag_points(v0, v0 + Vector3(rng.randf_range(-0.4, 0.4), -rng.randf_range(4.0, 8.0), 0), 0.3, 5), 0.06, 0.04, 4, 1.0)
	return mb.commit()


## Thick brush in clumps round the floor's edge (between the giants), kept off the way in.
func _brush(rng: RandomNumberGenerator, g: Dictionary) -> void:
	var c: Vector2 = g["c"]
	var y0 := isl.hv(c)
	var entry: Vector2 = g["entry"]
	var meshes := [Props.bush_mesh(131), Props.bush_mesh(132), Props.fern_mesh(141), Props.fern_mesh(142)]
	var xf := [[], [], [], []]
	for i in range(11):
		var a := entry.angle() + TAU * (i + 0.3) / 11.0 + rng.randf_range(-0.1, 0.1)
		if absf(angle_difference(a, entry.angle())) < 0.5:
			continue
		var hub := c + Vector2.from_angle(a) * rng.randf_range(FLOOR_R - 1.0, FLOOR_R + 3.5)
		brush.append(Vector3(hub.x - c.x, isl.hv(hub) - y0, hub.y - c.y))
		for k in range(rng.randi_range(6, 9)):
			var q := hub + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 3.2)
			var m := rng.randi() % meshes.size()
			var s := rng.randf_range(1.3, 2.1) * (1.0 if m < 2 else 1.25)
			(xf[m] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(q.x - c.x, isl.hv(q) - y0 - 0.1, q.y - c.y)))
	for m in range(meshes.size()):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[m]
		mm.instance_count = (xf[m] as Array).size()
		for i in range(mm.instance_count):
			mm.set_instance_transform(i, xf[m][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Brush%d" % m
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 160.0
		add_child(mmi)


## The floor under the canopy: roots snaking over it from the giants, a fallen
## giant along the edge, mossy stones.
func _floor(mb: MeshBuilder, bark: Material, rng: RandomNumberGenerator, g: Dictionary) -> void:
	var c: Vector2 = g["c"]
	var y0 := isl.hv(c)
	for t in trees:
		var base: Vector3 = t["base"]
		for k in range(2):
			var dir := (Vector3(-base.x, 0, -base.z).normalized().rotated(Vector3.UP, rng.randf_range(-0.9, 0.9)))
			var a := base + dir * float(t["r"]) * 0.8
			var b := a + dir * rng.randf_range(4.0, 7.0)
			var bq := Vector2(b.x, b.z) + c
			b.y = isl.hv(bq) - y0 - 0.05
			mb.add_tube(bark, MeshBuilder.curve_points(a + Vector3(0, 0.25, 0), (a + b) * 0.5 + Vector3(0, 0.3, 0), b, 6), 0.28, 0.08, 5, 0.6, Color(0.78, 0.74, 0.68))
	var stone := PSXMat.lit("rock", Color(0.7, 0.85, 0.65))
	for i in range(7):
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(8.0, FLOOR_R - 1.0)
		var s := rng.randf_range(0.35, 0.8)
		mb.add_blob(stone, Transform3D(Basis(), Vector3(q.x, isl.hv(c + q) - y0 + s * 0.2, q.y)), Vector3(s, s * 0.6, s * 0.9), rng, 0.3, 3, 6, 0.8, Color(0.85, 0.9, 0.8), true)
	# a fallen giant along the edge, half sunk in the brush
	var a := (g["entry"] as Vector2).angle() + PI + rng.randf_range(-0.8, 0.8)
	var mid := Vector2.from_angle(a) * (FLOOR_R + 2.0)
	var along := Vector2.from_angle(a + PI * 0.5)
	var e0 := mid - along * 8.0
	var e1 := mid + along * 8.0
	var p0 := Vector3(e0.x, isl.hv(c + e0) - y0 + 0.6, e0.y)
	var p1 := Vector3(e1.x, isl.hv(c + e1) - y0 + 0.7, e1.y)
	mb.add_tube(bark, [p0, p0.lerp(p1, 0.5) + Vector3(0, 0.1, 0), p1], 1.0, 0.75, 8, 0.4, Color(0.7, 0.72, 0.62), true, true)


func _dress_ape(mb: MeshBuilder, body: StaticBody3D, rng: RandomNumberGenerator, c: Vector2, y0: float) -> void:
	# boulders it hurls, a few about the floor's edge
	var rocks := [Props.rock_mesh(8801, 1.0), Props.rock_mesh(8802, 1.0, true), Props.rock_mesh(8803, 1.0)]
	for i in range(6):
		var a := rng.randf() * TAU
		var p := Vector2.from_angle(a) * rng.randf_range(14.0, FLOOR_R - 0.5)
		var s := rng.randf_range(0.9, 1.6)
		var mi := MeshInstance3D.new()
		mi.mesh = rocks[i % rocks.size()]
		mi.position = Vector3(p.x, isl.hv(c + p) - y0 - 0.3 * s, p.y)
		mi.rotation.y = rng.randf() * TAU
		mi.scale = Vector3(s, s * rng.randf_range(0.7, 1.1), s)
		body.add_child(mi)
		KitLandmarks.cyl_col(body, s * 0.85, s * 1.5, mi.position + Vector3(0, s * 0.6, 0))
	# the nest: torn branches heaped in a ring
	var bark := PSXMat.lit("bark")
	for i in range(22):
		var a := TAU * i / 22.0
		var r := rng.randf_range(3.2, 4.4)
		var b := Basis(Vector3.UP, a + PI * 0.5 + rng.randf_range(-0.5, 0.5)) * Basis(Vector3.BACK, PI * 0.5 + rng.randf_range(-0.3, 0.3))
		mb.add_cylinder(bark, Transform3D(b, Vector3(cos(a) * r, 0.25 + (i % 3) * 0.18, sin(a) * r)), 0.1, 0.06, rng.randf_range(2.2, 3.4), 4, 1.0)
	_bones(mb, rng, c, y0, 9)


func _dress_serpent(mb: MeshBuilder, rng: RandomNumberGenerator, c: Vector2, y0: float) -> void:
	# shed skins, pale and papery, lying in long loops
	var skin := PSXMat.lit("scales", Color(1.6, 1.55, 1.3))
	for k in range(3):
		var a := rng.randf() * TAU
		var pts: Array = []
		var at := Vector2.from_angle(a) * rng.randf_range(6.0, 15.0)
		var dir := Vector2.from_angle(a + PI * 0.5)
		for i in range(9):
			pts.append(Vector3(at.x, isl.hv(c + at) - y0 + 0.12, at.y))
			dir = dir.rotated(rng.randf_range(-0.6, 0.6))
			at += dir * 1.4
		mb.add_tube(skin, pts, 0.32, 0.08, 6, 1.0, Color(0.95, 0.92, 0.8))
	_bones(mb, rng, c, y0, 12)


func _dress_stalker(mb: MeshBuilder, rng: RandomNumberGenerator, c: Vector2, y0: float) -> void:
	# claws scored deep and high into the giants' bark
	var gash := PSXMat.flat(Color(0.75, 0.55, 0.38))
	for t in trees:
		var base: Vector3 = t["base"]
		var inward := Vector3(-base.x, 0, -base.z).normalized()
		var y := rng.randf_range(2.5, 4.5)
		for k in range(4):
			var p := base + inward * float(t["r"]) * 0.92 + inward.cross(Vector3.UP) * (k - 1.5) * 0.18 + Vector3(0, y, 0)
			mb.add_box(gash, Transform3D(Basis.looking_at(inward, Vector3.UP).rotated(inward, 0.25), p), Vector3(0.05, 1.3, 0.06), 1.0, Color.WHITE, false)
	_bones(mb, rng, c, y0, 10, true)


func _dress_mantis(mb: MeshBuilder, rng: RandomNumberGenerator, c: Vector2, y0: float) -> void:
	# egg cases on the trunks: foamy ridged lumps
	var foam := PSXMat.lit("leather", Color(0.78, 0.62, 0.42))
	for t in trees:
		var base: Vector3 = t["base"]
		var inward := Vector3(-base.x, 0, -base.z).normalized()
		for k in range(2):
			var p := base + inward.rotated(Vector3.UP, rng.randf_range(-0.7, 0.7)) * float(t["r"]) * 0.95 + Vector3(0, rng.randf_range(3.0, 9.0), 0)
			mb.add_blob(foam, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), Vector3(0.45, 0.8, 0.4), rng, 0.15, 4, 6, 1.0, Color.WHITE)
	_bones(mb, rng, c, y0, 6, true)


## Bones of whatever it caught, scattered over the floor.
func _bones(mb: MeshBuilder, rng: RandomNumberGenerator, c: Vector2, y0: float, n: int, ribs: bool = false) -> void:
	var bone := PSXMat.flat(Color(0.88, 0.85, 0.74))
	for i in range(n):
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(5.0, 15.0)
		var y := isl.hv(c + p) - y0
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, PI * 0.5)
		mb.add_cylinder(bone, Transform3D(b, Vector3(p.x, y + 0.06, p.y)), 0.05, 0.05, rng.randf_range(0.6, 1.1), 5, 1.0, Color.WHITE, true, true)
		if i % 3 == 0:
			mb.add_blob(bone, Transform3D(Basis(), Vector3(p.x + 0.5, y + 0.12, p.y)), Vector3(0.16, 0.13, 0.2), rng, 0.15, 3, 5)
	if ribs:
		# a ribcage: something big, picked clean
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(8.0, 13.0)
		var y := isl.hv(c + p) - y0
		var yaw := rng.randf() * TAU
		for k in range(6):
			var z := (k - 2.5) * 0.32
			for s in [-1.0, 1.0]:
				var a := Vector3(0, 0.2, z)
				var e := Vector3(s * 0.75, 0.05, z)
				var pts := MeshBuilder.curve_points(a + Vector3(0, 0.55, 0), Vector3(s * 0.7, 0.8, z), e, 5)
				var turned: Array = []
				for q in pts:
					turned.append(Basis(Vector3.UP, yaw) * q + Vector3(p.x, y, p.y))
				mb.add_tube(bone, turned, 0.05, 0.03, 4, 1.0)


# ==========================================================================
# What the beasts ask of it
# ==========================================================================
## Shake giant `i`'s crown (`k` 0..1: a rustle .. a branch nearly torn off): every screen runs its own.
func shake(i: int, k: float) -> void:
	var t: Dictionary = trees[i]
	_shakes[i] = [maxf(float(_shakes.get(i, [0.0])[0]), k), 0.0]
	BeastFX.leaves((t["perch"] as Vector3) + Vector3(0, 2.0, 0), int(10 + 20 * k), 2.5)
	BeastFX.sfx("leaves", t["perch"], -4.0 + 6.0 * k, 1.0, 70.0)


## The floor's middle (world).
func centre() -> Vector3:
	return global_position


func _tick_shakes(delta: float) -> void:
	for i in _shakes.keys():
		var s: Array = _shakes[i]
		s[1] = float(s[1]) + delta
		var k: float = float(s[0]) * exp(-float(s[1]) * 2.2)
		var crown: Node3D = trees[i]["crown"]
		crown.rotation.x = sin(float(s[1]) * 23.0) * 0.035 * k
		crown.rotation.z = sin(float(s[1]) * 17.0 + 1.0) * 0.03 * k
		if float(s[1]) > 2.5:
			crown.rotation.x = 0.0
			crown.rotation.z = 0.0
			_shakes.erase(i)


# ==========================================================================
# The fight
# ==========================================================================
func _ready() -> void:
	add_to_group("net_spawner")
	_spawn_boss()


func _spawn_boss() -> void:
	if boss and is_instance_valid(boss):
		boss.queue_free()
	_celebrated = false
	_dead_t = 0.0
	var away: Vector2 = (isl.sites["village"] - isl.sites["boss"]).normalized()
	var yaw := atan2(-away.x, -away.y)
	if kind == "ape":
		var ape := JungleApe.new()
		ape.setup({"post": global_position, "yaw": yaw, "mode": "stand", "seed": int(isl.node["seed"]) + boss_gen})
		ape.level = IslandContent.level(isl)
		boss = ape
	else:
		var b: JungleBeast = load(BeastPool.SCRIPTS[kind]).new()
		b.setup({"post": global_position, "yaw": yaw, "level": IslandContent.level(isl), "variant": int(isl.node["beast_look"]),
			"name": str(isl.node["beast_name"])})
		boss = b
	boss.name = "Beast%d" % boss_gen
	boss.set("arena", self)
	add_child(boss)
	boss.add_to_group("bosses")
	boss.global_position = global_position + Vector3.UP * 0.3
	boss.reset_physics_interpolation()


func net_gen():
	return boss_gen


func net_set_gen(g) -> void:
	if int(g) != boss_gen:
		boss_gen = int(g)
		_spawn_boss()


func _beaten_flag() -> String:
	return isl.save_key("boss_beaten")


func _process(delta: float) -> void:
	_tick_shakes(delta)
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me and not _arrived and me.global_position.distance_to(global_position) < 60.0:
		_arrived = true
		var bn: Array = BANNERS[kind]
		get_tree().call_group("hud", "show_banner", bn[0], bn[1], true)
	var alive: bool = boss != null and is_instance_valid(boss) and not boss.is_dead()
	_boss_hud(me, alive)
	if boss != null and is_instance_valid(boss) and not alive and not _celebrated:
		_celebrated = true
		_victory(me)
	if Net.is_client():
		return
	if alive and boss.asleep():
		for p in Net.all_players():
			var pp := p as Node3D
			if pp.global_position.distance_to(global_position) < WAKE_R and p.has_method("is_standing") and p.is_standing():
				boss.alert()
				break
	elif alive and boss.in_combat():
		var near := false
		for p in Net.all_players():
			if (p as Node3D).global_position.distance_to(global_position) < RESET_R and p.has_method("is_standing") and p.is_standing():
				near = true
		_empty_t = 0.0 if near else _empty_t + delta
		if _empty_t > 6.0:
			_empty_t = 0.0
			boss.reset_fight()
	elif not alive:
		_dead_t += delta
		if _dead_t > RESPAWN:
			for p in Net.all_players():
				if (p as Node3D).global_position.distance_to(global_position) < 70.0:
					return
			boss_gen += 1
			_spawn_boss()
			Net.spawned(self, net_gen())


func _boss_hud(me: Node3D, alive: bool) -> void:
	var show: bool = me != null and alive and boss.in_combat() and me.global_position.distance_to(global_position) < RESET_R + 8.0
	if show:
		get_tree().call_group("hud", "show_boss", boss.boss_name, boss.health_frac(), boss.phase)
		_boss_ui = true
	elif _boss_ui:
		_boss_ui = false
		get_tree().call_group("hud", "hide_boss")


## Beaten: banner and fanfare for whoever's here, the flag, its hoard once per character.
func _victory(me: Node3D) -> void:
	Dialogue.set_flag(_beaten_flag())
	# (the host's word goes) its fall sets the log pose on the next island(s)
	if not Net.is_client() and GameManager.chain_at == int(isl.node["id"]) and not GameManager.chain_set:
		GameManager.chain_settle()
	if me and me.global_position.distance_to(global_position) < RESET_R + 20.0:
		get_tree().call_group("hud", "show_banner", "%s falls!" % boss.boss_name, "The jungle goes quiet.", true)
		var music := get_node_or_null("/root/Music")
		if music:
			music.victory()
	var key := isl.save_key("boss_hoard")
	if GameManager.opened.has(key) or get_node_or_null("Hoard"):
		return
	var t := IslandContent.tier(isl)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(isl.node["seed"]) + 31
	var c: Vector2 = isl.sites["boss"]
	var bag := isl.strongbox(self, c + Vector2(0, 0.5), 0.0, "boss_hoard", [
		["gold", 60 + t * 25], ["treasure", 4 + t], ["rum", 2],
		[ItemDB.tiered(IslandContent.LOOT_WEAPONS[rng.randi() % IslandContent.LOOT_WEAPONS.size()], mini(t + 1, 5)), 1],
		[boss.trophy(t), 1]], 1.35)
	bag.name = "Hoard"
	FX.sparkle(bag.global_position + Vector3(0, 0.9, 0), 24, Color(1.0, 0.85, 0.4))
