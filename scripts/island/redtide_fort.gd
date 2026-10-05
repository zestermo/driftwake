extends Node3D
class_name RedtideFort
## Redtide Rock: a sea stack north of Brinehollow with a palisade fort on
## top - Captain Morrow "Red Tide"'s hideout. A jetty to tie up at, a ramp
## up the cliff, a gate with guards, and the captain himself waiting in front
## of his tent. Two guns on the south wall shoot at the crew's ship while
## the captain still holds the rock. Pirate ships patrol these waters (see
## EnemyFleet).
##
## The fight (host decides, everyone sees): step inside the walls and Morrow
## comes for you. Phase two calls his crew over the walls. If every captain
## leaves (or falls), he heals and waits again. Beat him: a banner, a victory
## fanfare, and his hoard in front of the tent (each captain's own chest,
## once per character). He's back after a while for a rematch (gold only).
##
## Co-op: a spawner (net_spawner) - [boss wave, crew wave] names the nodes the
## same on every machine.

const TOP := 6.0
const WALL_R := 17.5
const WALL_H := 3.0
const GATE_HALF := 3.2
const ARENA := Vector3(0, TOP, -2.0)
const BOSS_POST := Vector3(0, TOP, -7.5)
const RESET_RANGE := 42.0
const RESPAWN := 600.0
const HOARD_ID := "redtide_hoard"

var boss: PirateBoss
var boss_gen: int = 0
var crew_gen: int = 0
var crew: Array = []
var guards: GruntCamp
var guns: Array = []
var _empty_t: float = 0.0
var _dead_t: float = 0.0
var _celebrated: bool = false
var _arrived: bool = false
var _gun_t: float = 6.0
var _boss_ui: bool = false


func _ready() -> void:
	add_to_group("net_spawner")
	add_to_group("forts")
	_build()
	_spawn_boss.call_deferred()


# ==========================================================================
# The rock and the fort
# ==========================================================================
func _build() -> void:
	var body := StaticBody3D.new()
	body.name = "Rock"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var rock := PSXMat.lit("rock", Color(0.78, 0.74, 0.7), {"affine": 0.5})
	var top := PSXMat.lit("dirt", Color(0.9, 0.85, 0.78), {"affine": 0.5})
	var rings := [[-26.0, 31.0], [-6.0, 26.0], [0.3, 23.5], [2.5, 22.4], [5.3, 21.4], [TOP, 20.6]]
	var n := 18
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var pts: Array = []
	for r in rings:
		var row: Array = []
		for k in range(n):
			var a := TAU * k / n
			var j := 1.0 if r[0] >= TOP else rng.randf_range(0.9, 1.1)
			row.append(Vector3(cos(a) * float(r[1]) * j, float(r[0]) + (0.0 if r[0] >= TOP else rng.randf_range(-0.4, 0.4)), sin(a) * float(r[1]) * j))
		pts.append(row)
	var mb := MeshBuilder.new()
	for i in range(pts.size() - 1):
		for k in range(n):
			var a: Vector3 = pts[i][k]
			var b: Vector3 = pts[i][(k + 1) % n]
			var c: Vector3 = pts[i + 1][(k + 1) % n]
			var d: Vector3 = pts[i + 1][k]
			var nrm := ((a + b + c + d) * 0.25 * Vector3(1, 0, 1)).normalized()
			var u0 := float(k) * 2.0
			mb.add_quad(rock, a, b, c, d, Vector2(u0, a.y * 0.25), Vector2(u0 + 2.0, b.y * 0.25), Vector2(u0 + 2.0, c.y * 0.25), Vector2(u0, d.y * 0.25), Color.WHITE, nrm)
	var top_row: Array = pts[pts.size() - 1]
	for k in range(n):
		var a: Vector3 = top_row[k]
		var b: Vector3 = top_row[(k + 1) % n]
		mb.add_tri(top, Vector3(0, TOP, 0), b, a, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(0, 0), Vector2(b.x, b.z) * 0.2, Vector2(a.x, a.z) * 0.2, Color.WHITE, Vector3.UP)
	var rock_mi := mb.to_instance("RockMesh")
	body.add_child(rock_mi)
	var cs := CollisionShape3D.new()
	cs.shape = rock_mi.mesh.create_trimesh_shape()
	body.add_child(cs)
	# a few boulders at the waterline
	for k in range(9):
		var a := TAU * (k + 0.37) / 9.0
		var rr := Props.rock_mesh(900 + k, rng.randf_range(1.6, 3.2))
		var mi := MeshInstance3D.new()
		mi.mesh = rr
		mi.position = Vector3(cos(a) * 24.5, rng.randf_range(-0.6, 0.6), sin(a) * 24.5)
		add_child(mi)

	# the jetty and the ramp up the cliff (south, toward Brinehollow)
	var jetty := Props.dock(16.0, 3.6, 1.7, -8.0)
	jetty.position = Vector3(0, 0, 34.0)
	add_child(jetty)
	var planks := PSXMat.lit("planks_weathered", Color.WHITE, {"affine": 0.5})
	var dark := PSXMat.lit("planks_dark")
	var r0 := Vector3(0, 1.7, 34.2)
	var r1 := Vector3(0, TOP, 19.8)
	var dir := r1 - r0
	var ramp_b := Basis.looking_at(dir.normalized(), Vector3.UP)
	var ramp := MeshBuilder.new()
	ramp.add_box(planks, Transform3D(ramp_b, (r0 + r1) * 0.5 + Vector3(0, -0.12, 0)), Vector3(3.2, 0.24, dir.length()), 0.5)
	var steps := 12
	for s in range(steps):
		var p := r0.lerp(r1, (s + 0.5) / steps)
		ramp.add_box(dark, Transform3D(ramp_b, p + Vector3(0, 0.02, 0)), Vector3(3.3, 0.06, 0.12), 1.0)
	for s in range(5):
		for sx in [-1.7, 1.7]:
			var p := r0.lerp(r1, s / 4.0)
			ramp.add_box(dark, Transform3D(Basis(), p + Vector3(sx, -1.2, 0)), Vector3(0.18, 3.0, 0.18), 1.0)
			ramp.add_box(dark, Transform3D(Basis(), p + Vector3(sx, 0.5, 0)), Vector3(0.12, 1.0, 0.12), 1.0)
	for sx in [-1.7, 1.7]:
		ramp.add_box(dark, Transform3D(ramp_b, (r0 + r1) * 0.5 + Vector3(sx, 0.95, 0)), Vector3(0.08, 0.1, dir.length()), 1.0)
	var ramp_body := StaticBody3D.new()
	ramp_body.name = "Ramp"
	ramp_body.collision_layer = 1
	add_child(ramp_body)
	ramp_body.add_child(ramp.to_instance("RampMesh"))
	var rc := CollisionShape3D.new()
	var rbox := BoxShape3D.new()
	rbox.size = Vector3(3.2, 0.3, dir.length() + 0.6)
	rc.shape = rbox
	rc.transform = Transform3D(ramp_b, (r0 + r1) * 0.5 + Vector3(0, -0.15, 0))
	ramp_body.add_child(rc)
	for sx in [-1.75, 1.75]:
		var railc := CollisionShape3D.new()
		var rb := BoxShape3D.new()
		rb.size = Vector3(0.15, 1.1, dir.length())
		railc.shape = rb
		railc.transform = Transform3D(ramp_b, (r0 + r1) * 0.5 + Vector3(sx, 0.5, 0))
		ramp_body.add_child(railc)

	_build_palisade()
	_build_camp()


func _build_palisade() -> void:
	var body := StaticBody3D.new()
	body.name = "Palisade"
	body.collision_layer = 1
	add_child(body)
	var logs := PSXMat.lit("bark", Color(0.85, 0.75, 0.62))
	var mb := MeshBuilder.new()
	var circ := TAU * WALL_R
	var count := int(circ / 0.55)
	var gate_a := atan2(GATE_HALF, WALL_R)
	for k in range(count):
		var a := TAU * k / count
		# gate at +Z (a = PI/2)
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < gate_a:
			continue
		var h := WALL_H + (0.25 if k % 3 == 0 else 0.0)
		var p := Vector3(cos(a) * WALL_R, TOP - 0.4, sin(a) * WALL_R)
		mb.add_cylinder(logs, Transform3D(Basis(), p), 0.26, 0.24, h + 0.4, 5, 0.8)
		mb.add_cone(logs, Transform3D(Basis(), p + Vector3(0, h + 0.4, 0)), 0.24, 0.35, 5)
	# gate posts and a lintel with a skull board
	for sx in [-1.0, 1.0]:
		var gp := Vector3(sx * GATE_HALF, TOP - 0.4, sqrt(WALL_R * WALL_R - GATE_HALF * GATE_HALF))
		mb.add_cylinder(logs, Transform3D(Basis(), gp), 0.34, 0.32, WALL_H + 1.6, 6, 0.8)
	var gz := sqrt(WALL_R * WALL_R - GATE_HALF * GATE_HALF)
	mb.add_box(PSXMat.lit("planks_dark"), Transform3D(Basis(), Vector3(0, TOP + WALL_H + 0.9, gz)), Vector3(GATE_HALF * 2.0 + 0.8, 0.35, 0.4), 1.0)
	body.add_child(mb.to_instance("Logs"))
	var sk := MeshBuilder.new()
	sk.add_card(HullBuilder.jolly_material(), Transform3D(Basis.IDENTITY, Vector3(0, TOP + WALL_H + 1.6, gz + 0.22)), 1.4, 1.4)
	sk.add_card(HullBuilder.jolly_material(), Transform3D(Basis(Vector3.UP, PI), Vector3(0, TOP + WALL_H + 1.6, gz - 0.22)), 1.4, 1.4)
	add_child(sk.to_instance("GateSkull"))
	# wall collision: straight segments around the ring
	var segs := 36
	for k in range(segs):
		var a0 := TAU * k / segs
		var a1 := TAU * (k + 1) / segs
		var mid := (a0 + a1) * 0.5
		if absf(wrapf(mid - PI * 0.5, -PI, PI)) < gate_a + 0.02:
			continue
		var p0 := Vector3(cos(a0), 0, sin(a0)) * WALL_R
		var p1 := Vector3(cos(a1), 0, sin(a1)) * WALL_R
		var c := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(0.6, WALL_H + 1.0, p0.distance_to(p1) + 0.3)
		c.shape = b
		c.transform = Transform3D(Basis.looking_at((p1 - p0).normalized(), Vector3.UP), (p0 + p1) * 0.5 + Vector3(0, TOP + (WALL_H + 1.0) * 0.5 - 0.4, 0))
		body.add_child(c)


func _place(n: Node3D, p: Vector3, yaw: float = 0.0) -> Node3D:
	add_child(n)
	n.position = p
	n.rotation.y = yaw
	return n


func _build_camp() -> void:
	# Morrow's big tent at the north end, his chair in front of it
	var tent := MeshBuilder.new()
	var canvas := PSXMat.lit("canvas", Color(0.62, 0.22, 0.18), {"affine": 0.6})
	var pole := PSXMat.lit("bark")
	var tp := Vector3(0, TOP, -12.5)
	tent.add_gable_roof(canvas, Transform3D(Basis(), tp + Vector3(0, 0.0, 0)), 6.0, 5.0, 3.4)
	tent.add_cylinder(pole, Transform3D(Basis(), tp + Vector3(0, 0, 2.5)), 0.1, 0.08, 3.6, 5, 1.0)
	tent.add_cylinder(pole, Transform3D(Basis(), tp + Vector3(0, 0, -2.5)), 0.1, 0.08, 3.6, 5, 1.0)
	add_child(tent.to_instance("Tent"))
	var tent_body := StaticBody3D.new()
	tent_body.collision_layer = 1
	tent_body.position = tp + Vector3(0, 1.4, 0)
	var tcs := CollisionShape3D.new()
	var tb := BoxShape3D.new()
	tb.size = Vector3(5.2, 2.8, 4.6)
	tcs.shape = tb
	tent_body.add_child(tcs)
	add_child(tent_body)
	var chair := MeshBuilder.new()
	var red := PSXMat.lit("cloth_red", Color(0.8, 0.3, 0.25))
	var dk := PSXMat.lit("planks_dark")
	var cp := Vector3(0, TOP, -9.3)
	chair.add_box(dk, Transform3D(Basis(), cp + Vector3(0, 0.25, 0)), Vector3(1.2, 0.5, 1.0), 1.0)
	chair.add_box(red, Transform3D(Basis(), cp + Vector3(0, 0.53, 0.05)), Vector3(1.0, 0.08, 0.8), 1.0)
	chair.add_box(dk, Transform3D(Basis(), cp + Vector3(0, 1.2, -0.45)), Vector3(1.2, 1.9, 0.14), 1.0)
	chair.add_box(red, Transform3D(Basis(), cp + Vector3(0, 1.15, -0.37)), Vector3(0.9, 1.4, 0.04), 1.0)
	for sx in [-0.6, 0.6]:
		chair.add_box(dk, Transform3D(Basis(), cp + Vector3(sx, 0.75, 0.0)), Vector3(0.14, 0.5, 0.9), 1.0)
	add_child(chair.to_instance("Chair"))
	# braziers (fire you can see from the sea), lanterns, the crew flag
	for bp in [Vector3(-4.5, TOP, -9.5), Vector3(4.5, TOP, -9.5), Vector3(-6.5, TOP, 13.5), Vector3(6.5, TOP, 13.5)]:
		var br := MeshBuilder.new()
		br.add_cylinder(PSXMat.lit("metal", Color(0.3, 0.28, 0.26)), Transform3D(Basis(), bp), 0.12, 0.1, 1.3, 5, 1.0)
		br.add_cylinder(PSXMat.lit("metal", Color(0.3, 0.28, 0.26)), Transform3D(Basis(), bp + Vector3(0, 1.3, 0)), 0.32, 0.5, 0.3, 6, 1.0)
		add_child(br.to_instance("Brazier"))
		var fire := Node3D.new()
		add_child(fire)
		fire.position = bp + Vector3(0, 1.65, 0)
		FX.flame_emitter(fire, 0.3, 14, 0.55, 0.6)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.3)
		light.light_energy = 1.4
		light.omni_range = 7.0
		fire.add_child(light)
	var flag := MeshBuilder.new()
	var fp := Vector3(9.5, TOP, -11.0)
	flag.add_cylinder(pole, Transform3D(Basis(), fp), 0.1, 0.07, 9.0, 5, 1.0)
	var cloth := PSXMat.lit("cloth_red", Color(0.25, 0.22, 0.22))
	flag.add_card(cloth, Transform3D(Basis.IDENTITY, fp + Vector3(1.1, 8.2, 0)), 2.2, 1.4, Rect2(0, 0, 0.5, 0.5))
	add_child(flag.to_instance("FlagPole"))
	var fj := MeshBuilder.new()
	fj.add_card(HullBuilder.jolly_material(), Transform3D(Basis.IDENTITY, fp + Vector3(1.1, 8.2, 0.02)), 1.3, 1.2)
	fj.add_card(HullBuilder.jolly_material(), Transform3D(Basis(Vector3.UP, PI), fp + Vector3(1.1, 8.2, -0.02)), 1.3, 1.2)
	add_child(fj.to_instance("FlagSkull"))
	# stores along the walls
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in range(10):
		var a := PI * 0.5 + PI * 0.25 + (PI * 1.5) * k / 9.0
		var p := Vector3(cos(a) * (WALL_R - 1.4), TOP, sin(a) * (WALL_R - 1.4))
		var pr: Node3D = Props.barrel() if k % 3 != 0 else Props.crate(rng.randf_range(0.7, 1.0))
		_place(pr, p, rng.randf() * TAU)
	_place(Props.weapon_rack(), Vector3(-8.0, TOP, -4.0), PI * 0.5)
	_place(Props.weapon_rack(), Vector3(8.0, TOP, -4.0), -PI * 0.5)
	# the fort's guns: on the south wall, covering the jetty
	for sx in [-1.0, 1.0]:
		var a: float = PI * 0.5 + float(sx) * 0.55
		var gp := Vector3(cos(a) * (WALL_R - 0.6), TOP + 1.1, sin(a) * (WALL_R - 0.6))
		var plat := MeshBuilder.new()
		plat.add_box(PSXMat.lit("planks_dark"), Transform3D(Basis(), gp + Vector3(0, -0.6, 0)), Vector3(2.0, 1.2, 2.0), 1.0)
		var pb := StaticBody3D.new()
		pb.collision_layer = 1
		add_child(pb)
		pb.add_child(plat.to_instance("GunPlatform"))
		var pcs := CollisionShape3D.new()
		var pbx := BoxShape3D.new()
		pbx.size = Vector3(2.0, 1.2, 2.0)
		pcs.shape = pbx
		pcs.position = gp + Vector3(0, -0.6, 0)
		pb.add_child(pcs)
		var g := ShipCannon.new()
		g.name = "FortGun%d" % guns.size()
		g.team = "enemy"
		g.mannable = false
		g.reload_time = 9.0
		g.hull_damage = 22.0
		g.splash_damage = 16.0
		g.ship = pb
		add_child(g)
		g.position = gp
		var out := Vector3(cos(a), 0, sin(a))
		g.rotation.y = atan2(-out.x, -out.z)
		guns.append(g)
	# the gate guards
	guards = GruntCamp.new()
	guards.name = "Guards"
	guards.respawn_time = 180.0
	add_child(guards)
	# (yaws are world-space: facing out of the gate is the fort's +Z)
	var out_yaw := global_rotation.y + PI
	guards.add_grunt({"post": Vector3(-2.4, TOP, 14.0), "yaw": out_yaw, "mode": "stand", "seed": 301})
	guards.add_grunt({"post": Vector3(2.4, TOP, 14.0), "yaw": out_yaw, "mode": "stand", "seed": 302})
	guards.add_grunt({"post": Vector3(-9.0, TOP, -6.0), "yaw": out_yaw - 0.6, "mode": "stand", "role": "rifle", "seed": 303})


# ==========================================================================
# The captain
# ==========================================================================
func _spawn_boss() -> void:
	if boss and is_instance_valid(boss) and boss.state != PirateGrunt.S.DEAD:
		boss.queue_free()
	boss = PirateBoss.new()
	boss.name = "Morrow_%d" % boss_gen
	# (facing the gate)
	boss.setup({"post": to_global(BOSS_POST), "yaw": global_rotation.y + PI, "mode": "stand", "seed": 999, "look": PirateBoss.morrow_look()})
	boss.arena = self
	boss.camp = null
	add_child(boss)
	boss.global_position = to_global(BOSS_POST) + Vector3.UP * 0.2
	boss.reset_physics_interpolation()
	_celebrated = false
	_dead_t = 0.0


## Phase two: over the walls they come.
func call_crew() -> void:
	if Net.is_client():
		return
	crew_gen += 1
	_spawn_crew(true)
	Net.spawned(self, net_gen())
	Net.fx("sfx", ["horn", to_global(ARENA), 2.0, 0.03, 1.1])


func _spawn_crew(leap: bool) -> void:
	var n := 3 + clampi(Net.crew_size() - 2, 0, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + crew_gen
	for i in range(n):
		var a := PI * 0.5 + PI * 0.4 + (PI * 1.2) * float(i) / maxf(n - 1, 1)
		var wall := Vector3(cos(a) * (WALL_R - 0.2), TOP + WALL_H + 0.3, sin(a) * (WALL_R - 0.2))
		var land := Vector3(cos(a) * 10.0, TOP + 0.1, sin(a) * 10.0)
		var g := PirateGrunt.new()
		g.name = "MC%d_%d" % [crew_gen, i]
		g.setup({"post": to_global(land), "yaw": 0.0, "mode": "stand", "role": "sword", "seed": rng.randi()})
		g.boarder = true
		add_child(g)
		g.global_position = to_global(wall)
		g.reset_physics_interpolation()
		crew.append(g)
		if leap and not Net.is_client():
			g.leap(to_global(land), 0.9 + 0.1 * i)


func net_gen():
	return [boss_gen, crew_gen]


func net_set_gen(g) -> void:
	var arr: Array = g
	if arr.size() < 2:
		return
	if int(arr[0]) != boss_gen:
		boss_gen = int(arr[0])
		_spawn_boss()
	if int(arr[1]) != crew_gen:
		crew_gen = int(arr[1])
		_spawn_crew(false)


func _process(delta: float) -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	var center := to_global(ARENA)
	if me and not _arrived and me.global_position.distance_to(global_position) < 75.0:
		_arrived = true
		get_tree().call_group("hud", "show_banner", "Redtide Rock", "Captain Morrow's hideout", true)
	_boss_hud(me)
	var alive: bool = boss != null and is_instance_valid(boss) and boss.state != PirateGrunt.S.DEAD
	if boss != null and is_instance_valid(boss) and not alive and not _celebrated:
		_celebrated = true
		_victory()
	if Net.is_client():
		return
	# the walls' guns at the crew's ship (only while a captain's aboard)
	if alive:
		_fort_guns(delta)
	# step inside the walls and he comes for you
	if alive and boss.state == PirateGrunt.S.IDLE:
		for p in Net.all_players():
			var lp := to_local((p as Node3D).global_position)
			if Vector2(lp.x, lp.z).length() < WALL_R - 0.5 and lp.y > TOP - 1.0 and p.has_method("is_standing") and p.is_standing():
				boss.alert()
				break
	if alive and boss.in_combat():
		var near := false
		for p in Net.all_players():
			var pp := p as Node3D
			if pp.global_position.distance_to(center) < RESET_RANGE and p.has_method("is_standing") and p.is_standing():
				near = true
		_empty_t = 0.0 if near else _empty_t + delta
		if _empty_t > 5.0:
			_empty_t = 0.0
			boss.reset_fight()
	elif not alive:
		_dead_t += delta
		if _dead_t > RESPAWN:
			for p in Net.all_players():
				if (p as Node3D).global_position.distance_to(center) < 70.0:
					return
			boss_gen += 1
			_spawn_boss()
			Net.spawned(self, net_gen())


func _boss_hud(me: Node3D) -> void:
	var show := me != null and boss != null and is_instance_valid(boss) and boss.state != PirateGrunt.S.DEAD \
		and boss.in_combat() and me.global_position.distance_to(to_global(ARENA)) < RESET_RANGE + 8.0
	if show:
		get_tree().call_group("hud", "show_boss", "Captain Morrow \"Red Tide\"", boss.health_frac(), boss.phase)
		_boss_ui = true
	elif _boss_ui:
		_boss_ui = false
		get_tree().call_group("hud", "hide_boss")


## Beaten: banner, fanfare, and his hoard for each captain (once per character).
func _victory() -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me and me.global_position.distance_to(to_global(ARENA)) < 70.0:
		get_tree().call_group("hud", "show_banner", "Captain Morrow defeated!", "The Red Tide recedes", true)
		var music := get_node_or_null("/root/Music")
		if music:
			music.victory()
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.get("opened") != null and (gm.opened as Dictionary).has(HOARD_ID):
		return
	if get_node_or_null("Hoard"):
		return
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	var items: Array[ItemStack] = []
	var add := func(it: ItemData, q: int) -> void:
		if it == null:
			return
		var st := ItemStack.new()
		st.item = it
		st.quantity = q
		items.append(st)
	add.call(load("res://resources/items/morrow_cutlass.tres"), 1)
	add.call(Gear.make("coat", "captain", {"coat": "captain", "coat_color": CharacterLook.CLOTH[13], "trim_color": CharacterLook.TRIM[0]}, "Red Tide Coat"), 1)
	add.call(load("res://resources/items/gold.tres"), 40)
	add.call(load("res://resources/items/treasure.tres"), 4)
	add.call(load("res://resources/items/rum.tres"), 2)
	bag.setup(items)
	bag.save_id = HOARD_ID
	bag.name = "Hoard"
	add_child(bag)
	bag.position = Vector3(0, TOP, -9.0 + 1.6)
	var cm := bag.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if cm:
		cm.mesh = Props.treasure_chest_mesh()
		cm.position = Vector3.ZERO
		cm.scale = Vector3.ONE * 1.3
	FX.sparkle(bag.global_position + Vector3(0, 0.8, 0), 20, Color(1.0, 0.85, 0.4))


func _fort_guns(delta: float) -> void:
	_gun_t -= delta
	if _gun_t > 0.0:
		return
	_gun_t = 4.5
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	if ship == null:
		return
	var aboard := false
	for p in Net.all_players():
		if (p as Node3D).global_position.distance_to(ship.global_position) < 9.0:
			aboard = true
	if not aboard:
		return
	for g in guns:
		var c := g as ShipCannon
		var d := c.global_position.distance_to(ship.global_position)
		if d > 85.0 or d < 12.0 or not c.loaded():
			continue
		var spot := ship.global_position + (ship.call("hull_velocity") as Vector3) * (d / ShipCannon.MUZZLE_SPEED)
		spot += Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
		spot.y = 1.0
		if c.aim_at(spot):
			Net.fx("sparkle", [c.muzzle(), 6, Color(1.0, 0.5, 0.2)])
			var gun := c
			get_tree().create_timer(0.9).timeout.connect(func():
				if is_instance_valid(gun):
					gun.fire(self))
			return  # one gun at a time
