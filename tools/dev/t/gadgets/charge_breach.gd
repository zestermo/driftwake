extends SceneTree
## (1.30) The powder charge: used facing a gate with a ChargeTarget it's knelt and planted on the gate's mark (one
## charge spent), the fuse burns (the gate still stands), then the blast breaches it (breached fires, the gate's mesh
## and collider gone) and floors and hurts a grunt beside it. In the air it's refused. A second gate needing two
## charges holds after one.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g
var gate: StaticBody3D
var gate2: StaticBody3D
var tgt
var tgt2
var said: Array = []
var hp0 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(2.2, 0, -3.6), "role": "sword", "seed": 31}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _gate(at: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4, 4, 0.5)
	cs.shape = bs
	cs.position = Vector3(0, 2, 0)
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bs.size
	mi.mesh = bm
	mi.position = cs.position
	b.add_child(mi)
	stage.add_child(b)
	b.global_position = at
	return b


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var CT = load("res://scripts/gadgets/charge_target.gd")
	match step:
		0:
			p = stage.player
			g = stage.camp.grunts[0]
			TK.calm(g, Vector3.BACK)
			hp0 = g.health.current_health
			gate = _gate(p.global_position + Vector3(0, 0, -2.0))
			tgt = CT.attach(gate, Vector3(0, 1.0, 0.25), Vector3.BACK)
			tgt.breached.connect(func(by): said.append(by))
			gate2 = _gate(p.global_position + Vector3(40, 0, -2.0))
			tgt2 = CT.attach(gate2, Vector3(0, 1.0, 0.25), Vector3.BACK, {"needs": 2})
			p.player_model.rotation.y = 0.0
			p.gadgets.give("charge", 0)
			check("a mark painted on the gate", tgt.get_child_count() > 0)
			until = TK.wait_ticks(3)
		1:
			check("used at the gate, the captain kneels to plant it", p.gadgets.fire() and p.current_state_name() == "Gadget")
			check("...one charge spent (%d)" % p.gadgets.charges("charge"), p.gadgets.charges("charge") == p.gadgets.max_charges("charge") - 1)
			until = TK.wait_secs(1.0)
		2:
			var zs: Array = load("res://scripts/gadgets/gadget_zone.gd").active.filter(func(z): return z.kind == "charge")
			check("the satchel's on the gate's mark (%d)" % zs.size(), zs.size() == 1 and (zs[0] as Node3D).global_position.distance_to(tgt.global_position) < 0.1)
			check("...and the captain's up again (%s)" % p.current_state_name(), p.current_state_name() != "Gadget")
			check("the fuse burns, the gate stands", not tgt.done and said.is_empty())
			until = TK.wait_secs(GadgetData.tier_val("charge", "fuse", 0))
		3:
			check("the blast breaches the gate", tgt.done and said.size() == 1 and said[0] == p)
			check("...its collider gone", (gate.get_child(0) as CollisionShape3D).disabled)
			check("...and its mesh", not (gate.get_child(1) as MeshInstance3D).visible)
			check("the grunt beside it is hurt (%.0f -> %.0f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
			check("...and floored (%s)" % g.state, g.state in [g.S.DOWN, g.S.DEAD, g.S.GETUP] or g.health.current_health <= 0.0)
			# the two-charge gate: one blast holds
			load("res://scripts/gadgets/gadget_zone.gd").spawn(self, "charge", 0, tgt2.global_position, p, Vector3.BACK)
			until = TK.wait_secs(GadgetData.tier_val("charge", "fuse", 0) + 0.5)
		4:
			check("a gate needing two holds after one (%d)" % tgt2.taken, not tgt2.done and tgt2.taken == 1)
			check("...and the mark's gone only from the first", CT.near(tgt2.global_position, 1.0) == tgt2 and CT.near(tgt.global_position, 1.0) == null)
			p.velocity = Vector3(0, 6, 0)
			p.state_machine.force_state("Fall", {})
			until = TK.wait_ticks(4)
		5:
			check("in the air it's refused", not p.gadgets.fire() and p.current_state_name() != "Gadget")
			return TK.done(fails)
	step += 1
	return false
