extends SceneTree
## The hull layout as data (1.29 piece 1): the pirates' hull (HullBuilder.build / collide on HullLayout.base()) and a
## wreck build exactly what they built from the old constants (a fingerprint of every vertex and collision shape,
## recorded before the change), and base()'s numbers are the old constants'. The crew's sloop's collision fingerprint is
## WANT_SHIP (her Quarters 0 shapes since the 1.29 rework; her meshes change with every look pass, so they aren't kept).
const TK := preload("res://tools/dev/test_kit.gd")
## Fingerprints from the constants (before 1.29): the pirates' model, its collision, a wreck's model.
const WANT := {"pirate": "af3fe69081a72339dedda874e72df152a7a49e53606758c85acdc7714f3279c7",
	"pirate_col": "62b3335487bcceee44c2e307f582663ed0c7b3986e848df8e2b815e0e05de06d",
	"wreck": "b9a01b15f661e15bc5b3233aaab05ccd52bb37769ed83ac18f2d4fda3553171d"}
const WANT_SHIP := {
	"ship_col": "051b2b2c6f5b019a98c6aafd81b66affa477a2560427d90b0386d89a54bb5b87"}
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


static func meshes_print(n: Node) -> String:
	var out := PackedStringArray()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		var xf := (mi as Node3D).transform
		var a := 0.0
		var b := 0.0
		var c := 0
		for s in range(m.get_surface_count()):
			var v: PackedVector3Array = m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			c += v.size()
			for p in v:
				var q: Vector3 = xf * p
				a += q.x + q.y * 3.0 + q.z * 7.0
				b += absf(q.x) + absf(q.y) + absf(q.z)
		out.append("%s:%d:%d:%.2f:%.2f" % [mi.name, m.get_surface_count(), c, a, b])
	return ",".join(out)


static func shapes_print(n: Node) -> String:
	var out := PackedStringArray()
	for cs in n.find_children("*", "CollisionShape3D", true, false):
		var s := (cs as CollisionShape3D).shape
		var xf := (cs as Node3D).transform
		var d := ""
		if s is BoxShape3D:
			d = "b%s" % str((s as BoxShape3D).size.snappedf(0.001))
		elif s is CylinderShape3D:
			d = "c%.3f/%.3f" % [(s as CylinderShape3D).radius, (s as CylinderShape3D).height]
		elif s is ConvexPolygonShape3D:
			var t := 0.0
			for p in (s as ConvexPolygonShape3D).points:
				t += p.x + p.y * 3.0 + p.z * 7.0
			d = "p%d/%.3f" % [(s as ConvexPolygonShape3D).points.size(), t]
		out.append("%s@%s,%s" % [d, str(xf.origin.snappedf(0.001)), str(xf.basis.get_euler().snappedf(0.001))])
	return ";".join(out)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var HB = load("res://scripts/ship/hull_builder.gd")
			var got := {}
			var pm := Node3D.new()
			HB.build(pm, {"emblem": "jolly"})
			got["pirate"] = meshes_print(pm)
			var body := StaticBody3D.new()
			HB.collide(body)
			got["pirate_col"] = shapes_print(body)
			var wm := Node3D.new()
			HB.build(wm, {"wreck": true})
			got["wreck"] = meshes_print(wm)
			got["ship_col"] = shapes_print(stage.ship)
			var want := WANT.merged(WANT_SHIP)
			for k in want.keys():
				print("   %s %s" % [k, str(got[k]).sha256_text()])
				check("%s as before" % k, str(got[k]).sha256_text() == want[k])
			pm.free()
			body.free()
			wm.free()
			var L = load("res://scripts/ship/hull_layout.gd").base()
			check("base: the decks (0.32, 2.72) and freeboard 1.45", is_equal_approx(L.deck_y, 0.32) and is_equal_approx(L.qd_y, 2.72) and is_equal_approx(L.freeboard, 1.45))
			check("base: the quarterdeck 5.0..9.9, the cabin 3.95 wide a side, its floor on the deck", is_equal_approx(L.qd_front, 5.0) and is_equal_approx(L.qd_back, 9.9) and is_equal_approx(L.cabin_hw, 3.95) and is_equal_approx(L.cabin_y, 0.32))
			check("base: the stairs 2.75 / 1.4, the wheel 6.6, the helm 7.4", is_equal_approx(L.stair_x0, 2.75) and is_equal_approx(L.stair_z0, 1.4) and is_equal_approx(L.wheel_z, 6.6) and is_equal_approx(L.helm_z, 7.4))
			check("base: the mast -1.8 to 16.8, the yard 13.8, the nest 15.0 r 1.6", is_equal_approx(L.mast_z, -1.8) and is_equal_approx(L.mast_top, 16.8) and is_equal_approx(L.yard_y, 13.8) and is_equal_approx(L.nest_y, 15.0) and is_equal_approx(L.nest_r, 1.6))
			check("base: the ladders at -2.9, 3.0 long", is_equal_approx(L.ladder_z, -2.9) and is_equal_approx(L.ladder_len, 3.0))
			return TK.done(fails)
	step += 1
	return false
