class_name BroodCave
extends Node3D
## The brood cave in the deep forest: a hollow rock dome with its mouth to the
## east (+X) and a hole in the roof letting a shaft of daylight onto the brood
## queen's nest. Walk in and she wakes; leave and she settles back on her eggs,
## healed. Beat her and her hoard is yours (once per character); she's back
## after a long while if nobody's near. Origin: the cave floor's centre.

const R_IN := 17.0
const H_IN := 10.0
const R_OUT := 25.0
const H_OUT := 15.0
const SINK := 1.5
const N_A := 36
## Ring elevations (degrees); the mouth cuts the bands below ring MOUTH_TOP.
const RINGS := [0.0, 12.0, 26.0, 40.0, 54.0, 66.0, 76.0]
const MOUTH_TOP := 3
const MOUTH := [35, 0]
const RESET_AFTER := 6.0
const RESPAWN := 900.0
const HOARD_ID := "brood_hoard"

var queen: BroodQueen
var queen_gen: int = 0
var brood: ScuttlebugNest
var _noise := FastNoiseLite.new()
var _arrived := false
var _boss_ui := false
var _celebrated := false
var _empty_t: float = 0.0
var _dead_t: float = 0.0


func _ready() -> void:
	add_to_group("net_spawner")
	_noise.seed = 4711
	_noise.frequency = 0.05
	_build_dome()
	_build_inside()
	brood = ScuttlebugNest.new()
	brood.name = "Brood"
	brood.start_empty = true
	brood.respawn_time = INF
	for a in [2.3, 3.1, 3.9]:
		brood.add_spot(Vector3(cos(a) * 12.0, 0.0, sin(a) * 12.0))
	add_child(brood)
	_spawn_queen()


# --------------------------------------------------------------------------
# The dome
# --------------------------------------------------------------------------
func _pt(r: float, h: float, i: int, j: int) -> Vector3:
	var a := TAU * float(i % N_A) / N_A
	var phi := deg_to_rad(RINGS[j])
	var dir := Vector3(cos(a) * cos(phi), sin(phi), sin(a) * cos(phi))
	var k := 1.0 + 0.16 * _noise.get_noise_3dv(dir * 40.0)
	return Vector3(dir.x * r * k, -SINK + (h + SINK) * sin(phi), dir.z * r * k)


func _in(i: int, j: int) -> Vector3:
	return _pt(R_IN, H_IN, i, j)


func _out(i: int, j: int) -> Vector3:
	return _pt(R_OUT, H_OUT, i, j)


func _uv(p: Vector3) -> Vector2:
	return Vector2(atan2(p.z, p.x) * 6.0, p.y) * 0.3


func _quad(mb: MeshBuilder, mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color = Color.WHITE) -> void:
	mb.add_quad(mat, a, b, c, d, _uv(a), _uv(b), _uv(c), _uv(d), col, n.normalized())


func _build_dome() -> void:
	var mb := MeshBuilder.new()
	var rock := PSXMat.lit("rock", Color(0.62, 0.6, 0.55), {"affine": 0.6})
	var mossy := PSXMat.lit("rock", Color(0.55, 0.68, 0.48), {"affine": 0.6})
	var inner := PSXMat.lit("rock", Color(0.42, 0.38, 0.4), {"affine": 0.6})
	var mid := Vector3(0, H_IN * 0.3, 0)
	var top := RINGS.size() - 1
	for i in range(N_A):
		var mouth := i in MOUTH
		for j in range(top):
			if mouth and j < MOUTH_TOP:
				continue
			var a := _in(i, j)
			var b := _in(i + 1, j)
			var c := _in(i + 1, j + 1)
			var d := _in(i, j + 1)
			_quad(mb, inner, a, b, c, d, mid - (a + c) * 0.5)
			var oa := _out(i, j)
			var ob := _out(i + 1, j)
			var oc := _out(i + 1, j + 1)
			var od := _out(i, j + 1)
			_quad(mb, mossy if j >= 4 else rock, oa, ob, oc, od, (oa + oc) * 0.5 - mid)
		# the rim of the roof hole
		_quad(mb, rock, _in(i, top), _in(i + 1, top), _out(i + 1, top), _out(i, top), Vector3.UP)
		# the mouth's lintel
		if mouth:
			_quad(mb, rock, _in(i, MOUTH_TOP), _in(i + 1, MOUTH_TOP), _out(i + 1, MOUTH_TOP), _out(i, MOUTH_TOP), Vector3.DOWN)
	# the mouth's sides (facing into the opening)
	for edge in [[MOUTH[0], 1.0], [MOUTH[1] + 1, -1.0]]:
		var c: int = edge[0]
		var a := TAU * float(c % N_A) / N_A
		var n := Vector3(-sin(a), 0, cos(a)) * float(edge[1])
		for j in range(MOUTH_TOP):
			_quad(mb, rock, _in(c, j), _in(c, j + 1), _out(c, j + 1), _out(c, j), n)
	# boulders heaped round its foot (not across the mouth)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3313
	for k in range(16):
		var a := TAU * k / 16.0 + rng.randf_range(-0.12, 0.12)
		if absf(angle_difference(a, 0.0)) < 0.45:
			continue
		var r := R_OUT * rng.randf_range(0.92, 1.05)
		var s := rng.randf_range(2.0, 4.2)
		mb.add_blob(mossy if k % 3 == 0 else rock, Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * r, s * 0.25, sin(a) * r)),
			Vector3(s, s * 0.7, s * 0.85), rng, 0.25, 4, 7, 0.4, Color.WHITE, -0.5)
	var mesh := mb.commit()
	var body := StaticBody3D.new()
	body.name = "Dome"
	body.collision_layer = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)


# --------------------------------------------------------------------------
# Inside: the nest, egg sacs, bones, glowing fungus, the light
# --------------------------------------------------------------------------
func _build_inside() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 905
	var mb := MeshBuilder.new()
	var silk := PSXMat.lit("canvas", Color(0.85, 0.88, 0.78))
	var egg := PSXMat.glow(Color(0.55, 0.9, 0.35), 0.9)
	var bone := PSXMat.lit("", Color(0.9, 0.86, 0.74))
	var fungus := PSXMat.glow(Color(0.35, 0.95, 0.85), 2.2)
	var stalk := PSXMat.lit("", Color(0.75, 0.72, 0.6))
	# the nest: a low ring of silk-bound debris at the back
	for k in range(14):
		var a := TAU * k / 14.0
		var p := Vector3(-6.0 + cos(a) * 4.2, 0.1, sin(a) * 4.2)
		mb.add_blob(silk, Transform3D(Basis(Vector3.UP, a), p), Vector3(1.0, 0.45, 0.6), rng, 0.25, 3, 6)
	# egg sacs in clusters along the wall (where the brood hatches)
	for a in [2.3, 3.1, 3.9]:
		var c := Vector3(cos(a) * 13.5, 0.0, sin(a) * 13.5)
		for e in range(5):
			var off := Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.2, 1.2))
			mb.add_blob(egg, Transform3D(Basis(), c + off + Vector3(0, 0.35, 0)), Vector3.ONE * rng.randf_range(0.35, 0.55), rng, 0.15, 3, 6)
		mb.add_blob(silk, Transform3D(Basis(), c + Vector3(0, 0.15, 0)), Vector3(2.0, 0.3, 2.0), rng, 0.3, 3, 7)
	# what's left of the queen's dinners
	for k in range(9):
		var a := rng.randf() * TAU
		var r := rng.randf_range(5.0, 14.0)
		var p := Vector3(cos(a) * r, 0.06, sin(a) * r)
		if p.x > 8.0 and absf(p.z) < 5.0:
			continue
		mb.add_box(bone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, PI * 0.5), p), Vector3(0.08, rng.randf_range(0.5, 0.9), 0.08), 1.0)
	mb.add_blob(bone, Transform3D(Basis(), Vector3(-9.0, 0.2, 7.0)), Vector3(0.25, 0.22, 0.28), rng, 0.1, 3, 6)
	# glowing fungus round the foot of the walls
	for k in range(22):
		var a := TAU * k / 22.0 + rng.randf_range(-0.1, 0.1)
		if absf(angle_difference(a, 0.0)) < 0.35:
			continue
		var r := R_IN - rng.randf_range(0.8, 1.8)
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		for f in range(3):
			var q := p + Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
			var h := rng.randf_range(0.2, 0.55)
			mb.add_cylinder(stalk, Transform3D(Basis(), q), 0.04, 0.03, h, 4, 1.0)
			mb.add_cylinder(fungus, Transform3D(Basis(), q + Vector3(0, h, 0)), 0.16, 0.02, 0.1, 6, 1.0, Color.WHITE, false, true)
	# rubble along the walls
	var rocks := MeshBuilder.new()
	var rock := PSXMat.lit("rock", Color(0.5, 0.48, 0.45), {"affine": 0.6})
	for k in range(12):
		var a := rng.randf() * TAU
		if absf(angle_difference(a, 0.0)) < 0.45:
			continue
		var r := R_IN - rng.randf_range(1.0, 3.0)
		rocks.add_blob(rock, Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * r, 0.2, sin(a) * r)), Vector3.ONE * rng.randf_range(0.6, 1.4), rng, 0.25, 3, 6)
	var inside := mb.to_instance("Inside")
	inside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inside)
	add_child(rocks.to_instance("Rubble"))
	var glow := OmniLight3D.new()
	glow.name = "FungusLight"
	glow.position = Vector3(0, 4.0, 0)
	glow.light_color = Color(0.45, 0.95, 0.8)
	glow.light_energy = 1.1
	glow.omni_range = 20.0
	glow.shadow_enabled = false
	add_child(glow)


# --------------------------------------------------------------------------
# The queen and the fight
# --------------------------------------------------------------------------
func _spawn_queen() -> void:
	if queen and is_instance_valid(queen) and queen.state != Scuttlebug.S.DEAD:
		queen.queue_free()
	var nest := to_global(Vector3(-6.0, 0.0, 0.0))
	queen = BroodQueen.new().queen(nest)
	queen.name = "Queen_%d" % queen_gen
	queen.cave = self
	add_child(queen)
	queen.global_position = nest + Vector3.UP * 0.4
	queen.reset_physics_interpolation()
	_celebrated = false
	_dead_t = 0.0


func call_brood() -> void:
	brood.call_out()


func brood_alive() -> int:
	return brood.alive_count()


func inside(p: Vector3) -> bool:
	var l := to_local(p)
	return Vector2(l.x, l.z).length() < R_IN - 0.5 and l.y > -1.0 and l.y < H_IN


func _process(delta: float) -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me and not _arrived and me.global_position.distance_to(global_position) < 40.0:
		_arrived = true
		get_tree().call_group("hud", "show_banner", "The Brood Cave", "Something big nests in the dark", true)
	var alive := queen != null and is_instance_valid(queen) and queen.state != Scuttlebug.S.DEAD
	_boss_hud(me, alive)
	if queen != null and is_instance_valid(queen) and not alive and not _celebrated:
		_celebrated = true
		_victory(me)
	if Net.is_client():
		return
	if alive:
		var any_in := false
		for p in Net.all_players():
			if inside((p as Node3D).global_position) and p.has_method("is_standing") and p.is_standing():
				any_in = true
		if any_in:
			_empty_t = 0.0
			queen.wake()
		elif queen.in_combat():
			_empty_t += delta
			if _empty_t > RESET_AFTER:
				_empty_t = 0.0
				queen.reset_fight()
	else:
		_dead_t += delta
		if _dead_t > RESPAWN:
			for p in Net.all_players():
				if (p as Node3D).global_position.distance_to(global_position) < 70.0:
					return
			queen_gen += 1
			_spawn_queen()
			Net.spawned(self, net_gen())


func _boss_hud(me: Node3D, alive: bool) -> void:
	var show := me != null and alive and queen.in_combat() and me.global_position.distance_to(global_position) < R_OUT + 10.0
	if show:
		get_tree().call_group("hud", "show_boss", "The Brood Queen", queen.health_frac(), queen.phase)
		_boss_ui = true
	elif _boss_ui:
		_boss_ui = false
		get_tree().call_group("hud", "hide_boss")


## Beaten: banner, fanfare, and her hoard on the nest (once per character).
func _victory(me: Node3D) -> void:
	if me and me.global_position.distance_to(global_position) < 60.0:
		get_tree().call_group("hud", "show_banner", "The Brood Queen is slain!", "Her hoard lies in the nest", true)
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
	for e in [[ItemDB.tiered("queens_fang", 3), 1], [ItemDB.get_item("gold"), 60], [ItemDB.get_item("treasure"), 6], [ItemDB.get_item("rum"), 2],
			[Gear.make("accessory", "pauldron", {"pauldron": true}, "Chitin Pauldron", 3), 1]]:
		var st := ItemStack.new()
		st.item = e[0]
		st.quantity = e[1]
		items.append(st)
	bag.setup(items)
	bag.save_id = HOARD_ID
	bag.name = "Hoard"
	add_child(bag)
	bag.position = Vector3(-6.0, 0.0, 0.0)
	var cm := bag.get_node_or_null("MeshInstance3D") as MeshInstance3D
	cm.mesh = Props.treasure_chest_mesh()
	cm.position = Vector3.ZERO
	cm.scale = Vector3.ONE * 1.4
	FX.sparkle(bag.global_position + Vector3(0, 0.8, 0), 24, Color(0.7, 1.0, 0.45))


func net_gen():
	return queen_gen


func net_set_gen(g) -> void:
	if int(g) == queen_gen:
		return
	queen_gen = int(g)
	_spawn_queen()
