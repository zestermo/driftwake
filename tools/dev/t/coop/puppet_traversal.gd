extends SceneTree
## (1.31) Co-op visibility: a crewmate's glider shows on their back while it's open (NF_GLIDE), and a ship's rope
## they swing on follows their hand on our screen (the snapshot's rope key), hanging again when they let go;
## our own snapshot carries both.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var rope
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"ship": true, "crew": [{"name": "Mate", "at": Vector3(1.5, 0, 0)}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			mate = stage.crew[0]
			stage.ship.apply_kit(stage.ship.kit.merged({"ropes": 1}, true))
			var sr = load("res://scripts/ship/swing_rope.gd")
			var ropes: Array = stage.ship.find_children("*", "", true, false).filter(func(n): return n.get_script() == sr)
			check("the ship has a swing rope", not ropes.is_empty())
			if ropes.is_empty():
				return TK.done(fails)
			rope = ropes[0]
			mate._puppet_glider(1)
			until = TK.wait_ticks(2)
		1:
			check("a crewmate's open glider shows on their back", mate.body_model.torso.get_node_or_null("GliderWing") != null)
			mate._puppet_glider(-1)
			mate._puppet_swing_rope(root.get_node("Net").key_of(rope))
			until = TK.wait_ticks(2)
		2:
			check("...and folds away", mate._net_wing == null)
			var to: Vector3 = (mate.body_model.hand_r.global_position - rope.global_position).normalized()
			var down: Vector3 = -(rope._mesh.global_basis.y.normalized())
			print("  rope toward the hand: %.3f" % down.dot(to))
			check("the rope they swing on points at their hand", down.dot(to) > 0.95)
			mate._puppet_swing_rope("")
			until = TK.wait_ticks(2)
		3:
			var down: Vector3 = -(rope._mesh.global_basis.y.normalized())
			check("let go: it hangs again", down.dot(Vector3.DOWN) > 0.98)
			# our own snapshot: swinging on it carries its key, gliding carries the flag
			p.state_machine.force_state("Swing", {"rope": rope})
			until = TK.wait_ticks(2)
		4:
			var snap: Array = p.net_pack()
			check("our snapshot names the rope we swing on", snap.size() > 13 and str(snap[13]) == root.get_node("Net").key_of(rope))
			return TK.done(fails)
	step += 1
	return false
