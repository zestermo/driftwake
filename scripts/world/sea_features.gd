extends Node3D
## What's out on the open sea besides the islands, placed from the world seed
## (the same on every screen): reefs that scrape and hole a hull that runs
## over them, fog banks, whirlpools that drag ships round and in, and storm
## cells - heavy weather with a bigger swell - drifting before the wind.
## Group "sea_features"; WorldGenerator builds it.

const WHIRL_PULL := 4.5
const WHIRL_EYE := 8.0
const STORM_SWELL := 1.1
const STORM_RADIUS := 170.0
const FOG_RADIUS := 150.0
## Ships keep this far off reefs and whirlpools (EnemyShip.no_go).
const REEF_KEEP := 30.0

var gen: Node3D
## [centre (x, z), radius]
var reefs: Array = []
var fogs: Array = []
var whirls: Array = []
## [home (x, z), wander phase]: where a cell is now comes from world time
var storms: Array = []
## [centre (x, z), yaw]: hulks to pick over, a chest aboard ("wreck_<i>")
var wrecks: Array = []
## [centre (x, z), treasure index]: a message in a bottle ("bottle_<i>"),
## bobbing; reading it puts treasure <index> on your chart (GameManager.maps)
var bottles: Array = []
## [spot (world), island name]: an X on a beach, dug up ("treasure_<i>")
var treasures: Array = []
var _bottle_nodes: Array = []
var _treasure_nodes: Array = []
var _state_t: float = 0.0
const BOTTLE_LOOT := [["gold", 40, 70], ["treasure", 3, 6]]
var _spots: Array = []
var _rng := RandomNumberGenerator.new()
var _foam_t: float = 0.0
const WHIRL_DEPTH := 2.6
const SEA_KING := preload("res://scripts/enemies/sea_king.gd")
const SEA_LEGS := preload("res://scripts/world/sea_legs.gd")
## Lurks at its lair (SeaKing.lair), rising for a manned ship that comes near.
var sea_king: Node3D
## The sea between the chain's islands (its hazards count in every query here).
var legs: SEA_LEGS


func _ready() -> void:
	add_to_group("sea_features")
	_rng.seed = int(gen.get("world_seed")) * 17 + 5
	for i in range(4):
		var c := _open_spot(26.0)
		if c != Vector2.INF:
			reefs.append([c, _rng.randf_range(18.0, 26.0)])
			build_reef(self, c, float(reefs[-1][1]), _rng, reefs.size() - 1)
	for i in range(3):
		var c := _open_spot(FOG_RADIUS * 0.6)
		if c != Vector2.INF:
			fogs.append([c, FOG_RADIUS * _rng.randf_range(0.8, 1.2)])
			build_fog(self, c, float(fogs[-1][1]), _rng, fogs.size() - 1)
	for i in range(2):
		var c := _open_spot(60.0)
		if c != Vector2.INF:
			whirls.append([c, _rng.randf_range(38.0, 48.0)])
	for i in range(2):
		var c := _open_spot(80.0)
		if c != Vector2.INF:
			storms.append([c, _rng.randf() * TAU])
	for i in range(3):
		var c := _open_spot(20.0)
		if c != Vector2.INF:
			wrecks.append([c, _rng.randf() * TAU])
			_build_wreck(wrecks.size() - 1)
	_place_treasures()
	for i in range(treasures.size()):
		var c := _open_spot(10.0)
		if c != Vector2.INF:
			bottles.append([c, i])
			_build_bottle(bottles.size() - 1)
	for r in reefs:
		EnemyShip.no_go.append([r[0], float(r[1]) + REEF_KEEP])
	for wr in wrecks:
		EnemyShip.no_go.append([wr[0], 16.0])
	for w in whirls:
		EnemyShip.no_go.append([w[0], float(w[1]) + 10.0])
	# (placed last so the seed puts everything above where it always was)
	var lc := _open_spot(80.0)
	if lc != Vector2.INF:
		sea_king = SEA_KING.new()
		sea_king.name = "SeaKing"
		sea_king.lair = lc
		add_child(sea_king)
	legs = SEA_LEGS.new()
	legs.name = "SeaLegs"
	legs.sf = self
	add_child(legs)


func _exit_tree() -> void:
	# (the title screen's sea has none of this)
	Ocean.whirls = []
	Ocean.storm_cells = []


## Somewhere out on deep water, clear of land, the patrol lanes and the
## other features (INF if the sea's too crowded).
func _open_spot(r: float) -> Vector2:
	var sc: Vector2 = gen.get("starter_center")
	for k in range(60):
		var a := _rng.randf() * TAU
		var c := sc + Vector2(cos(a), sin(a)) * _rng.randf_range(450.0, 1500.0)
		if not gen.call("_deep_enough", c, r + 20.0) or not EnemyShip.huntable_at(Vector3(c.x, 0, c.y)):
			continue
		var clear := true
		for s in _spots:
			if c.distance_to(s) < 260.0:
				clear = false
		if clear:
			_spots.append(c)
			return c
	return Vector2.INF


# --------------------------------------------------------------------------
# What they do (every screen: all of it comes from the seed and world time)
# --------------------------------------------------------------------------
## Where storm cell `i` is now: wandering slowly about its home.
func storm_at(i: int) -> Vector2:
	return storm_pos(storms[i])


## Where a storm cell ([home, phase]) is now.
static func storm_pos(s: Array) -> Vector2:
	var t: float = Weather.world_time()
	var ph: float = s[1]
	return (s[0] as Vector2) + Vector2(sin(t / 700.0 + ph), cos(t / 910.0 + ph * 1.7)) * 180.0


## The weather out here at `p`: x = storm (0..1), y = fog (0..1).
func local_weather(p: Vector3) -> Vector2:
	var q := Vector2(p.x, p.z)
	var s := 0.0
	for st in storms + legs.storms:
		s = maxf(s, 1.0 - smoothstep(STORM_RADIUS * 0.4, STORM_RADIUS, q.distance_to(storm_pos(st))))
	var f := 0.0
	for fb in fogs + legs.fogs:
		f = maxf(f, (1.0 - smoothstep(float(fb[1]) * 0.45, float(fb[1]), q.distance_to(fb[0]))) * 0.95)
	return Vector2(s, f)


## The pull of any whirlpool at `p` (m/s, x/z): round and in, harder near the eye.
func current_at(p: Vector3) -> Vector3:
	var out := Vector3.ZERO
	for w in whirls + legs.whirls:
		var c: Vector2 = w[0]
		var r: float = w[1]
		var d := Vector2(c.x - p.x, c.y - p.z)
		var l := d.length()
		if l > r or l < 0.01:
			continue
		var k := 1.0 - l / r
		var inward := d / l
		var round := Vector2(-inward.y, inward.x)
		var v := (inward * 0.55 + round) * WHIRL_PULL * (0.35 + k * 1.3)
		out += Vector3(v.x, 0.0, v.y)
	return out


## Within a whirlpool's eye (it grinds a hull).
func in_eye(p: Vector3) -> bool:
	for w in whirls + legs.whirls:
		if Vector2(p.x, p.z).distance_to(w[0]) < WHIRL_EYE:
			return true
	return false


## Over a reef's shoals (the rocks show; the shallows around them don't).
func reef_at(p: Vector3) -> bool:
	for r in reefs + legs.reefs:
		if Vector2(p.x, p.z).distance_to(r[0]) < float(r[1]):
			return true
	return false


func _physics_process(_delta: float) -> void:
	# the storm cells' swell and the whirlpools' funnels go to the sea (shader and
	# floating things alike): the ones nearest the camera, as many as the shader takes
	var cam := get_viewport().get_camera_3d()
	var at := Vector2(cam.global_position.x, cam.global_position.z) if cam else Vector2.ZERO
	var cells: Array = []
	for s in storms + legs.storms:
		var c := storm_pos(s)
		cells.append(Vector4(c.x, c.y, STORM_RADIUS, STORM_SWELL))
	Ocean.storm_cells = _nearest(cells, at, Ocean.MAX_CELLS)
	var wv: Array = []
	for w in whirls + legs.whirls:
		wv.append(Vector4(w[0].x, w[0].y, float(w[1]), WHIRL_DEPTH))
	Ocean.whirls = _nearest(wv, at, Ocean.MAX_WHIRLS)


static func _nearest(list: Array, at: Vector2, n: int) -> Array:
	if list.size() <= n:
		return list
	list.sort_custom(func(a, b): return Vector2(a.x, a.y).distance_squared_to(at) < Vector2(b.x, b.y).distance_squared_to(at))
	return list.slice(0, n)


func _process(delta: float) -> void:
	_bob_bottles()
	_state_t -= delta
	if _state_t <= 0.0:
		_state_t = 0.5
		_apply_found()
		_chart_near()
	# surf breaks on the reefs near the camera
	_foam_t -= delta
	if _foam_t > 0.0:
		return
	_foam_t = 0.35
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for r in reefs:
		var c: Vector2 = r[0]
		if cam.global_position.distance_to(Vector3(c.x, 0, c.y)) > 220.0:
			continue
		var a := randf() * TAU
		var at := Vector3(c.x + cos(a) * float(r[1]) * 0.5, 0.0, c.y + sin(a) * float(r[1]) * 0.5)
		at.y = float(Ocean.get_wave_height(at)) + 0.1
		FX.splash(at, 4, 0.9)


# --------------------------------------------------------------------------
# Wrecks, bottles and buried treasure
# --------------------------------------------------------------------------
## A sunken hulk heeled over in the water, her deck half awash: a chest
## still aboard (each captain's own; remembered once emptied).
func _build_wreck(i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(gen.get("world_seed")) * 31 + i
	var picks := [["gold", rng.randi_range(20, 40)], ["treasure", rng.randi_range(1, 3)], ["rum", rng.randi_range(1, 2)]]
	if rng.randf() < 0.5:
		picks.append([["pistol", "cutlass", "boarding_axe", "katana"][rng.randi() % 4], 1])
	build_wreck(self, i, wrecks[i][0], float(wrecks[i][1]), "wreck_%d" % i, picks)


## A wreck at `c` under `parent` ("Wreck<i>"), her chest `save_id` holding
## `picks` ([item id or ItemData, quantity]).
static func build_wreck(parent: Node3D, i: int, c: Vector2, yaw: float, save_id: String, picks: Array) -> void:
	var body := StaticBody3D.new()
	body.name = "Wreck%d" % i
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	body.global_transform = Transform3D(Basis.from_euler(Vector3(0.12, yaw, 0.32)), Vector3(c.x, -0.95, c.y))
	var model := Node3D.new()
	body.add_child(model)
	HullBuilder.build(model, {"hull": Color(0.42, 0.45, 0.4), "deck": Color(0.55, 0.58, 0.5), "trim": Color(0.35, 0.36, 0.32), "wreck": true})
	HullBuilder.collide(body, false)
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	bag.setup(stacks(picks), false)
	bag.save_id = save_id
	bag.name = "WreckChest%d" % i
	body.add_child(bag)
	bag.position = Vector3(-1.6, HullBuilder.DECK_Y, 2.1)


## [item id or ItemData, quantity] -> stacks.
static func stacks(picks: Array) -> Array[ItemStack]:
	var items: Array[ItemStack] = []
	for e in picks:
		var st := ItemStack.new()
		st.item = e[0] if e[0] is ItemData else ItemDB.get_item(str(e[0]))
		st.quantity = int(e[1])
		items.append(st)
	return items


## An X on one of Brinehollow's beaches for each treasure (only shown, and
## diggable, once its map's been found), clear of its places and each other.
func _place_treasures() -> void:
	var si: StarterIsland = gen.get("starter_island")
	var keep := [StarterIsland.VILLAGE, StarterIsland.TRAINING, StarterIsland.HILL, StarterIsland.RUINS, StarterIsland.COVE,
		StarterIsland.CAMP, StarterIsland.SMUGGLERS, StarterIsland.CAVE, StarterIsland.DEN, si.dock_shore]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(gen.get("world_seed")) * 53 + 7
	var picked: Array = []
	for k in range(600):
		if picked.size() >= TREASURES:
			break
		var a := rng.randf() * TAU
		var q := Vector2(cos(a), sin(a)) * rng.randf_range(90.0, StarterIsland.LAND_R)
		var h := si.height_at(q.x, q.y)
		if h < 1.2 or h > 4.0:
			continue
		if keep.any(func(p): return q.distance_to(p) < 45.0) or picked.any(func(p): return q.distance_to(p) < 120.0):
			continue
		picked.append(q)
		treasures.append([si.to_global(Vector3(q.x, h, q.y)), "Brinehollow"])
		_build_treasure(treasures.size() - 1)


const TREASURES := 4


func _build_treasure(i: int) -> void:
	var at: Vector3 = treasures[i][0]
	var holder := Node3D.new()
	holder.name = "Treasure%d" % i
	add_child(holder)
	holder.global_position = at
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("bark", Color(0.6, 0.45, 0.3))
	for s in [-1.0, 1.0]:
		mb.add_box(wood, Transform3D(Basis(Vector3.UP, s * PI * 0.25), Vector3(0, 0.04, 0)), Vector3(0.18, 0.08, 1.6), 1.0)
	holder.add_child(mb.to_instance("X"))
	var it := Interactable.new()
	it.name = "Dig"
	it.collision_layer = 512
	it.collision_mask = 0
	it.prompt_text = "Dig up the treasure"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.4
	cs.shape = sph
	it.add_child(cs)
	holder.add_child(it)
	it.interacted.connect(func(player: Player): _dig(i, player))
	holder.visible = false
	it.enabled = false
	_treasure_nodes.append(holder)


func _dig(i: int, player: Player) -> void:
	var gm := get_node("/root/GameManager")
	var id := "treasure_%d" % i
	if gm.opened.has(id) or not gm.maps.has(i):
		return
	gm.mark_opened(id)
	var at: Vector3 = treasures[i][0]
	FX.dust(at, 18, 1.0)
	FX.sfx("thud", at, -2.0, 0.08, 0.8)
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	var items: Array[ItemStack] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(gen.get("world_seed")) * 53 + i
	for e in BOTTLE_LOOT:
		var item := load("res://resources/items/%s.tres" % e[0]) as ItemData
		var st := ItemStack.new()
		st.item = item
		st.quantity = rng.randi_range(int(e[1]), int(e[2]))
		items.append(st)
	bag.setup(items, false)
	bag.name = "DugChest%d" % i
	get_tree().current_scene.add_child(bag)
	bag.global_position = at + Vector3(0, 0.1, 0)
	player.call("_toast", "X marks the spot!")
	Net.award_xp(60, at, 30.0)


## A green glass bottle with a paper rolled up inside, bobbing on the swell.
func _build_bottle(i: int) -> void:
	var c: Vector2 = bottles[i][0]
	var holder := Node3D.new()
	holder.name = "Bottle%d" % i
	add_child(holder)
	holder.global_position = Vector3(c.x, 0.0, c.y)
	holder.add_child(bottle_glass())
	var it := Interactable.new()
	it.name = "Grab"
	it.collision_layer = 512
	it.collision_mask = 0
	it.usable_in_water = true
	it.prompt_text = "Fish out the bottle"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.6
	cs.shape = sph
	it.add_child(cs)
	holder.add_child(it)
	it.interacted.connect(func(player: Player): _read_bottle(i, player))
	_bottle_nodes.append(holder)


func _read_bottle(i: int, _player: Player) -> void:
	var gm := get_node("/root/GameManager")
	var id := "bottle_%d" % i
	if gm.opened.has(id):
		return
	gm.mark_opened(id)
	var t := int(bottles[i][1])
	gm.maps[t] = true
	FX.sfx("splash", (_bottle_nodes[i] as Node3D).global_position, -6.0, 0.1, 1.4)
	get_tree().call_group("hud", "show_banner", "A message in a bottle", "A treasure map! X marks a spot on %s (on your sea chart)." % treasures[t][1], true)
	_apply_found()


## Green glass with a paper rolled up inside (lying along x).
static func bottle_glass() -> MeshInstance3D:
	var mb := MeshBuilder.new()
	var glass := PSXMat.lit("metal", Color(0.35, 0.7, 0.45))
	mb.add_cylinder(glass, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-0.22, 0, 0)), 0.11, 0.11, 0.34, 6, 1.0)
	mb.add_cylinder(glass, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.12, 0, 0)), 0.05, 0.05, 0.16, 6, 1.0)
	mb.add_box(PSXMat.lit("bark", Color(0.6, 0.45, 0.3)), Transform3D(Basis(), Vector3(0.3, 0, 0)), Vector3(0.05, 0.08, 0.08), 1.0)
	return mb.to_instance("Glass")


## Bobbing on the swell; now and then the glass catches the light (a bottle
## is small: the glint is how you spot one).
func _bob_bottles() -> void:
	bob_bottles(_bottle_nodes, get_process_delta_time())


static func bob_bottles(nodes: Array, delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var glint := fmod(t, 1.4) < delta
	var cam: Camera3D = null
	for i in range(nodes.size()):
		var n := nodes[i] as Node3D
		if not n.visible:
			continue
		if cam == null:
			cam = n.get_viewport().get_camera_3d()
		n.global_position.y = float(Ocean.get_wave_height(n.global_position)) + 0.02
		n.rotation = Vector3(sin(t * 1.4 + i) * 0.25, t * 0.2 + i, cos(t * 1.1 + i) * 0.2)
		if glint and cam and cam.global_position.distance_to(n.global_position) < 160.0:
			FX.sparkle(n.global_position + Vector3.UP * 0.3, 4, Color(0.8, 1.0, 0.85))


## Our captain comes near a place: it goes on the sea chart (islands get a
## toast, the rest go on quietly).
func _chart_near() -> void:
	var gm := get_node_or_null("/root/GameManager")
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if gm == null or me == null:
		return
	var p := Vector2(me.global_position.x, me.global_position.z)
	for info in gen.get("island_infos"):
		var key := "island:" + str(info["name"])
		if not gm.charted.has(key) and p.distance_to(info["pos"]) < float(info["radius"]) + 250.0:
			gm.charted[key] = true
			get_tree().call_group("hud", "show_toast", "Charted %s" % info["name"])
	var rt = gen.get("redtide")
	if rt and not gm.charted.has("island:Redtide Rock") and p.distance_to(Vector2(rt.position.x, rt.position.z)) < 350.0:
		gm.charted["island:Redtide Rock"] = true
		get_tree().call_group("hud", "show_toast", "Charted Redtide Rock")
	for pair in [["reef", reefs, 0.0], ["whirl", whirls, 0.0], ["fog", fogs, 100.0], ["wreck", wrecks, 0.0]]:
		var arr: Array = pair[1]
		for i in range(arr.size()):
			var key := "%s:%d" % [pair[0], i]
			var reach: float = 220.0 + float(pair[2]) + (float(arr[i][1]) if pair[0] == "fog" else 0.0)
			if not gm.charted.has(key) and p.distance_to(arr[i][0]) < reach:
				gm.charted[key] = true


## Bottles already read are gone; treasures whose map you hold (and haven't
## dug) show their X.
func _apply_found() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return
	for i in range(_bottle_nodes.size()):
		var gone: bool = gm.opened.has("bottle_%d" % i)
		var n := _bottle_nodes[i] as Node3D
		n.visible = not gone
		(n.get_node("Grab") as Interactable).enabled = not gone
	for i in range(_treasure_nodes.size()):
		var live: bool = gm.maps.has(i) and not gm.opened.has("treasure_%d" % i)
		var n := _treasure_nodes[i] as Node3D
		n.visible = live
		(n.get_node("Dig") as Interactable).enabled = live


# --------------------------------------------------------------------------
# Building them
# --------------------------------------------------------------------------
## Jagged black rocks breaking the surface; the big ones stop a hull.
static func build_reef(parent: Node3D, c: Vector2, r: float, rng: RandomNumberGenerator, idx: int) -> void:
	var holder := Node3D.new()
	holder.name = "Reef%d" % idx
	parent.add_child(holder)
	holder.global_position = Vector3(c.x, 0.0, c.y)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	holder.add_child(body)
	var mesh: Mesh = Props.rock_mesh(900 + idx, 1.0, true)
	for i in range(9):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, r * 0.75)
		var s := rng.randf_range(1.2, 3.4)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = PSXMat.lit("rock", Color(0.32, 0.31, 0.3))
		mi.visibility_range_end = 1000.0
		mi.position = Vector3(cos(a) * d, -1.2 + s * 0.35, sin(a) * d)
		mi.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		mi.scale = Vector3.ONE * s
		holder.add_child(mi)
		if s > 2.0:
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = s * 0.55
			cyl.height = 6.0
			cs.shape = cyl
			cs.position = mi.position + Vector3(0, -1.5, 0)
			body.add_child(cs)


## A bank of low cloud sitting on the water: soft grey puffs (inside it, the
## weather closes in - Weather reads local_weather).
static func build_fog(parent: Node3D, c: Vector2, r: float, rng: RandomNumberGenerator, idx: int) -> void:
	var holder := Node3D.new()
	holder.name = "FogBank%d" % idx
	parent.add_child(holder)
	holder.global_position = Vector3(c.x, 0.0, c.y)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = load("res://assets/textures/fx/dust.png")
	mat.albedo_color = Color(0.86, 0.88, 0.9, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = false
	var q := QuadMesh.new()
	q.size = Vector2(80, 40)
	q.material = mat
	for i in range(60):
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r * 0.9
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 1000.0
		mi.position = Vector3(cos(a) * d, rng.randf_range(6.0, 26.0), sin(a) * d)
		mi.scale = Vector3.ONE * rng.randf_range(0.9, 1.8)
		holder.add_child(mi)

