extends SceneTree
## The hammer's heavy (Earthquake) keeps the haft and the head of every design clear of the captain's head through
## the whole move: the heave overhead, the held beat, the slam and the recovery (Zach 2026-10-21: it clipped the head).
const TK := preload("res://tools/dev/test_kit.gd")
const DESIGNS := ["hammer", "hammer:kanabo", "hammer:mallet", "hammer:maul", "hammer:anchor"]
const HEAD_R := 0.13
var stage
var p
var b
var di := 0
var got: Array = []
var haft_min := 99.0
var head_min := 99.0
var haft_u := 0.0
var head_u := 0.0
var seen := false
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "warhammer"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func sample() -> void:
	var w: MeshInstance3D = b.weapon
	var hc: Vector3 = b.head.global_transform * Vector3(0, 0.11, 0)
	var u := float(b._action.get("t", 0.0)) / maxf(float(b._action.get("dur", 1.0)), 0.01)
	var a: Vector3 = w.global_transform * Vector3(0, 0, 0.1)
	var e: Vector3 = w.global_transform * Vector3(0, 0, -0.7)
	var hd := hc.distance_to(Geometry3D.get_closest_point_to_segment(hc, a, e)) - HEAD_R
	if hd < haft_min:
		haft_min = hd
		haft_u = u
	for s in w.mesh.get_surface_count():
		for v in (w.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if v.z > -0.7:
				continue
			var d: float = (w.global_transform * v).distance_to(hc) - HEAD_R
			if d < head_min:
				head_min = d
				head_u = u


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			b = p.body_model
			if not p.armed:
				TK.act("ready_weapon")
			until = TK.wait_secs(1.2)
		1:
			if not b.weapon_in_hand:
				check("the hammer's in hand", false)
				return TK.done(fails)
			b.weapon.mesh = Props.weapon_mesh(DESIGNS[di])
			haft_min = 99.0
			head_min = 99.0
			seen = false
			until = TK.wait_secs(0.6)
		2:
			p.stamina = p.max_stamina
			TK.act("heavy_attack")
			until = TK.wait_ticks(1)
		3:
			if b.current_action() == "ham_heavy":
				seen = true
				sample()
				until = TK.wait_ticks(1)
				return false
			if not seen:
				check("%s: the Earthquake played (%s)" % [DESIGNS[di], b.current_action()], false)
				return TK.done(fails)
			got.append([DESIGNS[di], haft_min, haft_u, head_min, head_u])
			print("MEASURE %s haft %.3f (u %.2f) head %.3f (u %.2f)" % got[-1])
			di += 1
			if di < DESIGNS.size():
				step = 1
				until = TK.wait_secs(0.8)
				return false
			for g in got:
				check("%s Earthquake: the haft clear of the head by %.2f m (closest at u %.2f), the hammer's head by %.2f m (u %.2f)" % g,
					g[1] > 0.06 and g[3] > 0.12)
			return TK.done(fails)
	step += 1
	return false
