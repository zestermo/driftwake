extends SceneTree
## (1.30) Overkill launches (Splat): a big killing blow throws a grunt flat into the wall behind it (a mark, it
## sticks ~1 s, then drops limp); a launcher throws one up into a ceiling; with nothing near it lands and skids;
## a kill with no overkill to speak of is the plain ragdoll.
const TK := preload("res://tools/dev/test_kit.gd")
const GY := 3.0
var stage
var step := 0
var until := 0
var fails := 0
var wall_g
var sky_g
var open_g
var weak_g
var start_open := Vector3.ZERO
var SFX


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [
		{"post": Vector3(0.0, 0, -3.0), "role": "sword", "seed": 41},
		{"post": Vector3(-9.0, 0, 0.0), "role": "sword", "seed": 42},
		{"post": Vector3(9.0, 0, 0.0), "role": "sword", "seed": 43},
		{"post": Vector3(0.0, 0, 9.0), "role": "sword", "seed": 44}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func slab(at: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	b.add_child(cs)
	stage.add_child(b)
	b.global_position = at


func blow(dmg: float, launch: float = 0.0) -> HitData:
	var h := HitData.new()
	h.damage = dmg
	h.poise = 6.0
	h.knockback_force = 5.0
	h.launch = launch
	h.impact = "punch"
	return h


func strike(g, h: HitData, from: Vector3) -> void:
	var to: Vector3 = g.global_position - from
	g.facing.rotation.y = atan2(-to.x, -to.z)
	var src := Node3D.new()
	stage.add_child(src)
	src.global_position = from
	g._on_hit(h, src)
	src.queue_free()


func splat_of(g):
	var r = g.humanoid.ragdoll
	return r.get_node_or_null("Splat") if r else null


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 4:
				return false
			SFX = load("res://scripts/game/splat_fx.gd")
			wall_g = stage.camp.grunts[0]
			sky_g = stage.camp.grunts[1]
			open_g = stage.camp.grunts[2]
			weak_g = stage.camp.grunts[3]
			for g in stage.camp.grunts:
				g.set_physics_process(false)
			slab(Vector3(0, GY + 3.0, -8.5), Vector3(8, 6, 1))
			slab(Vector3(-9, GY + 4.6, 0), Vector3(4, 0.5, 4))
			until = TK.wait_ticks(5)
		1:
			strike(wall_g, blow(500.0), wall_g.global_position + Vector3(0, 0, 2))
			strike(sky_g, blow(500.0, 9.0), sky_g.global_position + Vector3(0, 0, 2))
			start_open = open_g.global_position
			strike(open_g, blow(500.0), open_g.global_position + Vector3(-2, 0, 0))
			weak_g.health.current_health = 5.0
			strike(weak_g, blow(6.0), weak_g.global_position + Vector3(0, 0, -2))
			check("all four die", wall_g.state == wall_g.S.DEAD and sky_g.state == sky_g.S.DEAD
				and open_g.state == open_g.S.DEAD and weak_g.state == weak_g.S.DEAD)
			var s = splat_of(wall_g)
			check("an overkill throws the body (a Splat)", s != null)
			check("it found the wall behind (kind %s)" % (s.kind if s else "-"), s != null and s.kind == "wall")
			var c = splat_of(sky_g)
			check("a launcher finds the ceiling over it (kind %s)" % (c.kind if c else "-"), c != null and c.kind == "ceiling")
			var o = splat_of(open_g)
			check("in the open it lands and skids (kind %s)" % (o.kind if o else "-"), o != null and o.kind == "skid")
			check("a kill with 1 hp to spare is the plain ragdoll", weak_g.humanoid.ragdoll != null and splat_of(weak_g) == null)
			until = TK.wait_secs(0.5)
		2:
			var s = splat_of(wall_g)
			check("half a second on it's stuck to the wall", s != null and s.phase == s.Phase.STICK)
			var hips: Vector3 = wall_g.humanoid.hips.global_position
			check("flat against the wall (hips z %.2f)" % hips.z, hips.z < -7.3 and hips.z > -8.3)
			check("off the ground (hips y %.2f)" % hips.y, hips.y > GY + 0.8)
			var c = splat_of(sky_g)
			var top: Vector3 = sky_g.humanoid.hips.global_position
			check("pinned under the ceiling (hips y %.2f)" % top.y, c != null and top.y > GY + 3.6)
			check("impact marks were left (%d live)" % SFX.live(), SFX.live() >= 3)
			until = TK.wait_secs(1.2)
		3:
			check("after its second it lets go", splat_of(wall_g) == null and splat_of(sky_g) == null)
			var rb: RigidBody3D = wall_g.humanoid.ragdoll.root_body()
			check("the body is loose again (not frozen)", not rb.freeze)
			var far: float = Vector2(open_g.humanoid.hips.global_position.x - start_open.x, open_g.humanoid.hips.global_position.z - start_open.z).length()
			check("the skid carried it a way off (%.1f m)" % far, far > 3.0)
			until = TK.wait_secs(1.5)
		4:
			check("the wall body dropped to the floor (hips y %.2f)" % wall_g.humanoid.hips.global_position.y,
				wall_g.humanoid.hips.global_position.y < GY + 0.8)
			check("the marks stay pooled (%d <= 16)" % SFX.pool_size(), SFX.pool_size() <= 16)
			return TK.done(fails)
	step += 1
	return false
