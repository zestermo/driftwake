class_name StoryGrove
extends Node3D
## Tackett's ironwood grove (1.30, Story step "forest"; was StoryDeadfall's fallen trunks by the path): a clearing off
## the old forest's path where COUNT standing ironwoods wear Tackett's blaze (a white band and a red rag), two old
## stumps of his earlier felling, his chopping block and a stack of seasoned lengths. While that's the step, F at a
## marked tree fells it: two chops, a crack, the tree goes over and lands with a thud and dust, a length of timber in
## the bag; a stump stays. Each captain fells their own (a Dialogue flag per tree, so the grove shows this screen's
## captain's trees felled); the trees are the island's, the same on every machine.
## Per frame: nothing; a felling runs a tween for 1.6 s.

const COUNT := 3
## Where the hinge of each trunk is (the stump's top).
const CUT := 0.75
const FALL_SECS := 1.5

var trees: Array = []
var _felled: Array = []


static func flag(i: int) -> String:
	return "ironwood_%d" % i


## How many marked trees this captain has felled.
static func felled_count(dlg: Node) -> int:
	var n := 0
	for i in range(COUNT):
		if dlg.has_flag(flag(i)):
			n += 1
	return n


## The grove at its node's origin: `spots` [Vector3 local ground point, fall yaw] per marked tree, `stumps` local
## points, `block` the chopping block's local point and yaw. Built once; flags read on ready.
static func make(spots: Array, stumps: Array, block: Array, seed_value: int) -> StoryGrove:
	var g := StoryGrove.new()
	g.name = "IronwoodGrove"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(spots.size()):
		var s: Array = spots[i]
		var t := _tree(i, rng.randi(), s[1])
		t.position = s[0]
		g.add_child(t)
		g.trees.append(t)
		g._felled.append(false)
	var mb := MeshBuilder.new()
	var body := StaticBody3D.new()
	body.name = "GroveDressing"
	for q: Vector3 in stumps:
		_old_stump(mb, body, q, rng)
	_block(mb, body, block[0], block[1], rng)
	var mi := mb.to_instance("Mesh")
	mi.visibility_range_end = 120.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	g.add_child(body)
	return g


func _ready() -> void:
	var story := get_node("/root/Story")
	story.changed.connect(refresh)
	refresh()


## Show this captain's felled trees as stumps and logs (a load, a new story).
func refresh() -> void:
	var dlg := get_node("/root/Dialogue")
	for i in range(trees.size()):
		var down: bool = dlg.has_flag(flag(i))
		if down != _felled[i]:
			_set_down(i, down, false)


## The trunk's hinge node turned over (or back up); `anim` runs the fall.
func _set_down(i: int, down: bool, anim: bool) -> void:
	_felled[i] = down
	var t: StaticBody3D = trees[i]
	var hinge := t.get_node("Hinge") as Node3D
	(t.get_node("Trunk") as CollisionShape3D).disabled = down
	(t.get_node("Log") as CollisionShape3D).disabled = not down
	(t.get_node("Fell") as Interactable).prompt_text = "A stump of Tackett's ironwood" if down else "Fell the marked ironwood"
	var lie := Vector3(0, 0, -PI * 0.5 + float(t.get_meta("rest")))
	var r := float(t.get_meta("r"))
	var butt := Vector3(r * 0.6, r * 0.95, r * 1.7)
	if not down:
		hinge.rotation = Vector3.ZERO
		hinge.position = Vector3(0, CUT, 0)
		return
	if not anim:
		hinge.rotation = lie
		hinge.position = butt
		return
	var tw := create_tween()
	tw.tween_interval(0.95)
	tw.tween_callback(func(): Net.fx("sfx", ["wood_crack", hinge.global_position + Vector3.UP * 1.5, 2.0, 0.08, 0.8]))
	tw.tween_property(hinge, "rotation", Vector3(0, 0, -0.08), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(hinge, "rotation", lie, FALL_SECS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(hinge, "position", butt, FALL_SECS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _landed(t))
	tw.tween_property(hinge, "rotation", lie + Vector3(0, 0, 0.05), 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(hinge, "rotation", lie, 0.18).set_ease(Tween.EASE_IN)


## The crash: a thud, dust along the trunk, the ground shakes a little.
func _landed(t: StaticBody3D) -> void:
	var len := float(t.get_meta("len"))
	var along := t.global_transform.basis * Vector3.RIGHT
	Net.fx("sfx", ["thud", t.global_position + along * len * 0.5, 4.0, 0.06, 0.7])
	for k in range(4):
		FX.dust_ring(t.global_position + along * (2.0 + k * len * 0.22), 8, 0.9)
	CombatManager.apply_camera_shake(0.35, 0.3)


## Fell tree `i` for the captain's story (F at it): the chops, the fall, a length of timber, the step done at COUNT.
func fell(p: Player, i: int) -> void:
	var dlg := p.get_node("/root/Dialogue")
	var story := p.get_node("/root/Story")
	var tree_ := p.get_tree()
	if dlg.has_flag(flag(i)):
		tree_.call_group("hud", "show_toast", "Only the stump's left of this one.")
		return
	if story.step != "forest":
		tree_.call_group("hud", "show_toast", "Tackett's blaze is on it: his ironwood, not yours to fell.")
		return
	dlg.set_flag(flag(i))
	p.gesture("chop")
	var at: Vector3 = (trees[i] as Node3D).global_position + Vector3.UP * 1.0
	get_tree().create_timer(0.39, false, true).timeout.connect(func(): Net.fx("sfx", ["chop", at, -2.0, 0.06, 0.85]))
	get_tree().create_timer(0.88, false, true).timeout.connect(func(): Net.fx("sfx", ["chop", at, 0.0, 0.06, 0.75]))
	_set_down(i, true, true)
	p.inventory_component.add_item(ItemDB.get_item("timber"), 1)
	var n := felled_count(dlg)
	if n >= COUNT:
		story.complete("forest")
	else:
		tree_.call_group("hud", "show_toast", "Ironwood felled: %d of %d lengths for Tackett." % [n, COUNT])


# --------------------------------------------------------------------------
# Models
# --------------------------------------------------------------------------
static func _xf(p: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


## A standing ironwood: the stump (buttress roots, the cut's height) as the body's mesh, the trunk above CUT and
## its crown on a "Hinge" that turns about local Z to fell it toward local +X; Tackett's blaze on the trunk.
## Shapes: "Trunk" (standing), "Log" (lying, off), the stump always; the Interactable "Fell".
static func _tree(i: int, seed_value: int, fall_yaw: float) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := StaticBody3D.new()
	body.name = "Ironwood%d" % i
	body.rotation.y = fall_yaw
	var bark := PSXMat.lit("bark", Color(0.6, 0.55, 0.52))
	var heart := PSXMat.lit("logs", Color(0.95, 0.72, 0.5))
	var leaves := PSXMat.lit("leaves", Color(0.72, 0.86, 0.7), {"affine": 0.5})
	var r := rng.randf_range(0.5, 0.6)
	var h := rng.randf_range(9.0, 10.5)
	body.set_meta("len", h)
	body.set_meta("rest", rng.randf_range(0.02, 0.06))
	body.set_meta("r", r)
	# the stump: flared foot, buttresses, the trunk up to the cut (its top is the heartwood, hidden while it stands)
	var smb := MeshBuilder.new()
	smb.add_cylinder(bark, _xf(Vector3(0, -0.3, 0)), r * 1.35, r, CUT + 0.3, 8, 0.8, Color.WHITE, false)
	smb.add_cylinder(heart, _xf(Vector3(0, CUT - 0.01, 0)), r * 0.98, r * 0.98, 0.02, 8, 1.0)
	for k in range(4):
		var a := TAU * k / 4.0 + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(a), 0, sin(a))
		var pts := PackedVector3Array([dir * r * 0.6 + Vector3.UP * 1.2, dir * r * 1.3 + Vector3.UP * 0.35, dir * r * 2.4 + Vector3.DOWN * 0.15])
		smb.add_tube(bark, pts, 0.24, 0.1, 5, 0.8)
	var stump := smb.to_instance("Stump")
	stump.visibility_range_end = 160.0
	stump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(stump)
	# the trunk and crown, on the hinge
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(0, CUT, 0)
	body.add_child(hinge)
	var mb := MeshBuilder.new()
	var bend := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
	var trunk := PackedVector3Array()
	for k in range(5):
		var u := k / 4.0
		trunk.append(Vector3.UP * h * 0.72 * u + bend * u * u)
	mb.add_tube(bark, trunk, r, r * 0.55, 8, 0.6)
	mb.add_cylinder(heart, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 0.01, 0)), r * 0.98, r * 0.98, 0.02, 8, 1.0)
	var top := trunk[4]
	# limbs out to the crown's lobes
	var lobes: Array = []
	for k in range(4):
		var a := TAU * k / 4.0 + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.6, 2.4)
		var from := top - Vector3.UP * rng.randf_range(0.8, 1.8)
		var to := top + out + Vector3.UP * rng.randf_range(0.9, 1.8)
		mb.add_tube(bark, PackedVector3Array([from, from.lerp(to, 0.5) + Vector3.UP * 0.4, to]), r * 0.38, r * 0.16, 5, 0.8)
		lobes.append(to)
	lobes.append(top + Vector3.UP * 2.3)
	for c: Vector3 in lobes:
		var s := rng.randf_range(1.9, 2.6)
		mb.add_blob(leaves, _xf(c, rng.randf() * TAU), Vector3(s, s * 0.62, s), rng, 0.22, 3, 7, 0.6, Color.WHITE.darkened(rng.randf_range(0.0, 0.25)))
	# Tackett's blaze: a white band of paint and a red rag round the trunk at chest height
	var paint := PSXMat.flat(Color(0.92, 0.9, 0.82))
	mb.add_cylinder(paint, _xf(Vector3(0, 0.75, 0)), r * 1.02, r * 1.0, 0.22, 8, 1.0, Color.WHITE, false)
	var rag := PSXMat.lit("cloth_red", Color(1.0, 0.85, 0.8), {"affine": 0.6})
	mb.add_cylinder(rag, _xf(Vector3(0, 1.2, 0)), r * 1.0, r * 0.98, 0.12, 8, 1.0, Color.WHITE, false)
	mb.add_box(rag, Transform3D(Basis(Vector3.BACK, 0.25), Vector3(r * 1.05, 0.95, 0.0)), Vector3(0.05, 0.5, 0.16), 1.0)
	var tm := mb.to_instance("Tree")
	tm.visibility_range_end = 260.0
	hinge.add_child(tm)
	# shapes: the stump, the standing trunk, the log lying toward +X
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r * 1.1
	cyl.height = CUT + 0.4
	cs.shape = cyl
	cs.position = Vector3(0, (CUT + 0.4) * 0.5 - 0.4, 0)
	body.add_child(cs)
	var tcs := CollisionShape3D.new()
	tcs.name = "Trunk"
	var tcyl := CylinderShape3D.new()
	tcyl.radius = r
	tcyl.height = h * 0.72
	tcs.shape = tcyl
	tcs.position = Vector3(0, CUT + h * 0.36, 0)
	body.add_child(tcs)
	var lcs := CollisionShape3D.new()
	lcs.name = "Log"
	var box := BoxShape3D.new()
	box.size = Vector3(h * 0.72, r * 1.6, r * 1.6)
	lcs.shape = box
	lcs.position = Vector3(h * 0.36 + r * 0.6, r * 0.95, r * 1.7)
	lcs.disabled = true
	body.add_child(lcs)
	var it := Interactable.new()
	it.name = "Fell"
	it.collision_layer = 512
	it.collision_mask = 0
	it.prompt_text = "Fell the marked ironwood"
	it.gesture = "push"  # (1.31)
	it.reach = 2.6
	var ics := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.4
	ics.shape = sph
	ics.position = Vector3(0, 1.0, 0)
	it.add_child(ics)
	body.add_child(it)
	it.interacted.connect(func(p: Player): (body.get_parent() as StoryGrove).fell(p, i))
	return body


## An old stump of Tackett's earlier felling, moss on its cut, a chip or two round it (into mb and a shape on body).
static func _old_stump(mb: MeshBuilder, body: StaticBody3D, q: Vector3, rng: RandomNumberGenerator) -> void:
	var bark := PSXMat.lit("bark", Color(0.55, 0.5, 0.48))
	var r := rng.randf_range(0.45, 0.6)
	var ht := rng.randf_range(0.5, 0.8)
	mb.add_cylinder(bark, _xf(q + Vector3(0, -0.3, 0)), r * 1.3, r, ht + 0.3, 8, 0.8, Color.WHITE, false)
	mb.add_cylinder(PSXMat.lit("logs", Color(0.7, 0.62, 0.5)), _xf(q + Vector3(0, ht - 0.01, 0)), r * 0.98, r * 0.98, 0.02, 8, 1.0)
	mb.add_blob(PSXMat.lit("moss_stone"), _xf(q + Vector3(r * 0.3, ht + 0.02, 0)), Vector3(r * 0.5, 0.05, r * 0.45), rng, 0.2, 2, 6, 1.0)
	for k in range(3):
		var a := rng.randf() * TAU
		mb.add_box(PSXMat.lit("logs", Color(0.8, 0.7, 0.55)), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q + Vector3(cos(a), 0.02, sin(a)) * rng.randf_range(0.9, 1.6)), Vector3(0.18, 0.04, 0.08), 1.0)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r * 1.1
	cyl.height = ht + 0.3
	cs.shape = cyl
	cs.position = q + Vector3(0, (ht + 0.3) * 0.5 - 0.3, 0)
	body.add_child(cs)


## Tackett's chopping block (an axe bitten into it) and a stack of seasoned lengths under a bark roof beside it.
static func _block(mb: MeshBuilder, body: StaticBody3D, q: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, yaw)
	var bark := PSXMat.lit("bark", Color(0.6, 0.55, 0.5))
	var logs := PSXMat.lit("logs", Color(0.95, 0.75, 0.55))
	var dark := PSXMat.lit("planks_dark")
	mb.add_cylinder(bark, _xf(q), 0.42, 0.38, 0.6, 8, 0.8)
	mb.add_cylinder(logs, _xf(q + Vector3(0, 0.6, 0)), 0.37, 0.37, 0.02, 8, 1.0)
	var haft := q + b * Vector3(0.05, 0.62, 0.0)
	Buildings.beam_between(mb, dark, haft, haft + b * Vector3(0.55, 0.45, 0.15), 0.035)
	mb.add_box(PSXMat.lit("metal", Color(0.7, 0.7, 0.72)), Transform3D(b * Basis(Vector3.BACK, -0.6), haft + Vector3(0, 0.02, 0)), Vector3(0.22, 0.14, 0.03), 1.0)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.42
	cyl.height = 0.62
	cs.shape = cyl
	cs.position = q + Vector3(0, 0.31, 0)
	body.add_child(cs)
	# the stack: seasoned lengths between two pairs of stakes, a bark-shingle lid
	var sq := q + b * Vector3(0, 0, -2.2)
	for row in range(3):
		for k in range(4 - row):
			var lp := sq + b * Vector3(-0.66 + (k + row * 0.5) * 0.44, 0.22 + row * 0.38, 0)
			mb.add_cylinder(logs if row == 2 else bark, Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), lp + b * Vector3(0, 0, -1.1)), 0.21, 0.2, 2.2, 7, 0.8, Color.WHITE, true, true)
	for sx in [-1.05, 1.05]:
		for sz in [-0.9, 0.9]:
			mb.add_box(dark, _xf(sq + b * Vector3(sx, 0.75, sz), yaw), Vector3(0.1, 1.5, 0.1), 1.0)
	mb.add_box(PSXMat.lit("bark", Color(0.45, 0.4, 0.38)), Transform3D(b * Basis(Vector3.BACK, 0.12), sq + b * Vector3(0, 1.6, 0)), Vector3(2.6, 0.06, 2.4), 0.8)
	var scs := CollisionShape3D.new()
	var sbox := BoxShape3D.new()
	sbox.size = Vector3(2.2, 1.6, 2.2)
	scs.shape = sbox
	scs.transform = Transform3D(b, sq + Vector3(0, 0.8, 0))
	body.add_child(scs)
	mb.add_box(logs, _xf(q + b * Vector3(0.9, 0.05, 0.6), 0.4 + rng.randf()), Vector3(0.5, 0.1, 0.16), 1.0)
