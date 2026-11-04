extends SceneTree
## (1.30) The brig and galleon on the layout system leave the crew's sloop and caravel as they were: HullBuilder's
## hull and collision for the sloop at Quarters 0 and 4 fingerprint the same as before the brig and galleon (recorded
## before HullBuilder learned their masts, gun deck and poop), and her layout's 1.30 numbers are the identity map.
const TK := preload("res://tools/dev/test_kit.gd")
const LP := preload("res://tools/dev/t/ship/layout_parity.gd")
const WANT := {"q0": "2087d614ec7f96b65ec5bc08cdfeb455182efcda902845d5b3c08897c034c214",
	"q0_col": "d06f6fa367ea198201f93c5968010c995bf5fa36937196cfdfea3574d6b05fa8",
	"q4": "8f779017efc552d886449f3ca505042ebd9542513d951518851ab6508ccde044",
	"q4_col": "43f23cd7ad2161fe9940d4a26bfe0b5f48a2d248b333f370b6a0fed45830b7c9"}
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var HB = load("res://scripts/ship/hull_builder.gd")
			var HL = load("res://scripts/ship/hull_layout.gd")
			var mats := {"hull": PSXMat.lit("planks_dark"), "deck": PSXMat.lit("planks"), "trim": PSXMat.lit("planks", Color(0.85, 0.65, 0.35)),
				"wood": PSXMat.lit("bark"), "rope": PSXMat.lit("rope")}
			for q in [0, 4]:
				var L = HL.of("sloop", q)
				var mb := MeshBuilder.new()
				HB.hull(mb, mats, true, L)
				var n := Node3D.new()
				n.add_child(mb.to_instance("Hull"))
				var body := StaticBody3D.new()
				HB.collide(body, true, L)
				for k in [["q%d" % q, LP.meshes_print(n)], ["q%d_col" % q, LP.shapes_print(body)]]:
					var h := str(k[1]).sha256_text()
					print("   %s %s" % [k[0], h])
					check("sloop %s as before" % k[0], h == WANT[k[0]])
				n.free()
				body.free()
			var L = HL.of("sloop", 0)
			check("the sloop's map is the identity", L.map(Vector3(1.5, 2.0, -7.0)) == Vector3(1.5, 2.0, -7.0) and not L.rooms and L.masts.is_empty() and not L.has_lower() and not L.has_poop())
			check("the caravel shares her layout", HL.of("caravel", 0).rings == L.rings and is_equal_approx(HL.of("caravel", 0).qd_front, L.qd_front))
			return TK.done(fails)
	step += 1
	return false
