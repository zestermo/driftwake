extends Node3D
## Dive spots on the seabed off the islands' coasts, 4-15 m down (SwimState's dives): sunken chests, oyster
## beds with pearls, reef gardens to gather from, a sunken wreck and now and then the ruins of something older.
## Placed from the island's seed and its heights (the same on every screen), clear of its harbour. The loot
## is each captain's own like every world chest: chests are LootBags, oysters and reefs are remembered in
## GameManager.opened. A trickle of bubbles at the surface gives a sunken chest away; under water it glints.
## Brinehollow's are built with the world, a chain island's once it stands (freed with it).
## WorldGenerator builds it ("DiveSites", group "dive_sites").

const LOOT_BAG := preload("res://scenes/loot/loot_bag.tscn")
const SF := preload("res://scripts/world/sea_features.gd")
## Seabed depth a spot may have, and how far apart spots keep.
const DEPTH := Vector2(4.0, 15.0)
const SPACING := 26.0
## Clear of the island's harbour (its pier and the ship's berth).
const DOCK_KEEP := 70.0
const BEARINGS := 64
## Seen from this far (m): the fog closes in long before under water.
const SEE := 140.0
## What's gathered [[item id, lo, hi], ...], rolled for each captain (Loot.rng_for): an oyster bed's
## pearl and oysters, a reef's kelp and urchins (the economy's reef ingredients).
const OYSTERS := [["pearl", 1, 1], ["oyster", 1, 3]]
const REEF := [["seaweed", 1, 3], ["sea_urchin", 0, 2], ["oyster", 0, 1]]
## A chest's contents as put in (Loot.chest thins them per captain the first time it's opened).
const CHEST_LOOT := [["gold", 25, 60], ["treasure", 1, 3], ["pearl", 0, 1], ["rum", 0, 1]]
const WRECK_LOOT := [["gold", 30, 70], ["treasure", 1, 3], ["pearl", 0, 2], ["timber", 1, 3]]
const RUIN_LOOT := [["gold", 60, 120], ["treasure", 3, 5], ["pearl", 1, 3]]
## Brinehollow has one of everything, so you meet each kind at home.
const HOME_KINDS := ["wreck", "ruin", "chest", "chest", "oyster", "oyster", "oyster", "reef", "reef"]
## The bubble trail over a chest: how often, and from how far it's drawn.
const TELL_EVERY := 1.7
const TELL_RANGE := 70.0

var gen: Node3D
## island key -> its spots' holder
var _sites := {}
## [node, save id, the part that goes once taken (or null)]: oyster beds and reefs
var _pickups: Array = []
var _sync_t := 0.0
var _tell_t := 0.0
const CURRENTS := preload("res://scripts/swim/sea_currents.gd")
## The rips off the same islands' beaches.
var currents: Node3D
const THREATS := preload("res://scripts/swim/sea_threats.gd")
## The sharks, morays and jellyfish round them.
var threats: Node3D


func _ready() -> void:
	add_to_group("dive_sites")
	currents = CURRENTS.new()
	currents.name = "SeaCurrents"
	add_child(currents)
	threats = THREATS.new()
	threats.name = "SeaThreats"
	add_child(threats)
	build_island("brinehollow", gen.get("starter_island"), int(gen.get("world_seed")), HOME_KINDS)


func _process(delta: float) -> void:
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 0.5
		_sync_islands()
		_apply_taken()
	_tell_t -= delta
	if _tell_t <= 0.0:
		_tell_t = TELL_EVERY
		_tell()


## The chain islands standing now have their spots; those gone lose them.
func _sync_islands() -> void:
	var standing: Dictionary = gen.get("chain_islands")
	var keep := {"brinehollow": true}
	for id in standing:
		var key := "isle%d" % int(id)
		keep[key] = true
		if not _sites.has(key):
			var isl: Node3D = standing[id]
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([int(isl.get("node")["seed"]), "dive_kinds"])
			build_island(key, isl, int(isl.get("node")["seed"]), gen_kinds(rng))
	for key in _sites.keys():
		if not keep.has(key):
			(_sites[key] as Node).queue_free()
			_sites.erase(key)
			currents.drop_island(key)
			threats.drop_island(key)
	_pickups = _pickups.filter(func(e): return is_instance_valid(e[0]))


## A generated island's spots: a chest or two, oysters, a reef or two, a wreck on half, ruins on a third.
static func gen_kinds(rng: RandomNumberGenerator) -> Array:
	var kinds: Array = []
	if rng.randf() < 0.5:
		kinds.append("wreck")
	if rng.randf() < 0.35:
		kinds.append("ruin")
	for k in [["chest", 1, 2], ["oyster", 2, 3], ["reef", 1, 2]]:
		for i in range(rng.randi_range(k[1], k[2])):
			kinds.append(k[0])
	return kinds


func build_island(key: String, isl: Node3D, seed_value: int, kinds: Array) -> void:
	var holder := Node3D.new()
	holder.name = "Dive_" + key
	add_child(holder)
	_sites[key] = holder
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "dive"])
	var r_max := 450.0 if isl is StarterIsland else float(isl.get("half")) - 6.0
	# the seabed: the island's own terrain or the world's under it, whichever is higher
	var ground := func(x: float, z: float) -> float:
		var w := isl.to_global(Vector3(x, 0.0, z))
		return maxf(float(isl.call("height_at", x, z)), float(gen.call("height_at", w.x, w.z)))
	var r_min := 150.0 if isl is StarterIsland else float(isl.get("radius")) * 0.6
	var spots := find_spots(ground, rng, isl.get("dock_shore"), r_min, r_max)
	currents.build_island(key, isl, ground, seed_value, CURRENTS.HOME_RIPS if isl is StarterIsland else CURRENTS.GEN_RIPS, isl.get("dock_shore"), r_min, r_max)
	print("DiveSites: %s: %d spots for %s" % [key, spots.size(), kinds])
	# (the deepest spots for the wreck and the ruins: they stand tall)
	spots.sort_custom(func(a, b): return a.y < b.y)
	var by_kind := {}
	var open: Array = []
	for i in range(kinds.size(), spots.size()):
		open.append(isl.to_global(spots[i]))
	for i in range(mini(kinds.size(), spots.size())):
		var s: Vector3 = spots[i]
		var at := isl.to_global(s)
		if not by_kind.has(kinds[i]):
			by_kind[kinds[i]] = []
		by_kind[kinds[i]].append(at)
		var srng := RandomNumberGenerator.new()
		srng.seed = hash([seed_value, "dive", i])
		var save_key := str(isl.call("save_key", "dive_%s_%d" % [kinds[i], i]))
		var yaw := srng.randf() * TAU
		match kinds[i]:
			"chest":
				sunken_chest(holder, at, yaw, save_key, roll(CHEST_LOOT, srng), srng)
			"oyster":
				_pickups.append(oyster_bed(holder, at, save_key, srng))
			"reef":
				_pickups.append(reef_garden(holder, at, save_key, srng))
			"wreck":
				sunken_wreck(holder, at, yaw, save_key, srng)
			"ruin":
				sunken_ruin(holder, at, yaw, save_key, srng)
	threats.build_island(key, seed_value, by_kind, open, isl is StarterIsland)
	# (built after the save was applied: chests opened before are gone)
	var gm := get_node("/root/GameManager")
	for bag in holder.find_children("*", "LootBag", true, false):
		if gm.opened.has((bag as LootBag).save_id):
			bag.queue_free()
	_apply_taken()


## Seabed spots DEPTH deep off the coast (island space, y = the seabed), SPACING apart, clear of the dock:
## marching out along bearings to where the open sea gets deep enough, then somewhere in the band.
static func find_spots(ground: Callable, rng: RandomNumberGenerator, dock: Vector2, r_min: float, r_max: float) -> Array:
	var out: Array = []
	var start := rng.randf() * TAU
	for k in range(BEARINGS):
		var a := start + TAU * float(k) / BEARINGS
		var d := Vector2(cos(a), sin(a))
		# every level enough point in the band once the open sea starts, one of them picked
		var r := r_min
		var sea := false
		var band: Array = []
		while r < r_max:
			var q := d * r
			var h := float(ground.call(q.x, q.y))
			if not sea and h < -DEPTH.x and _open_sea(ground, d, r):
				sea = true
			if sea and h < -DEPTH.y:
				break
			if sea and h <= -DEPTH.x and q.distance_to(dock) >= DOCK_KEEP and _level(ground, q):
				band.append(Vector3(q.x, h, q.y))
			r += 3.0
		if band.is_empty():
			continue
		var s: Vector3 = band[rng.randi() % band.size()]
		if out.any(func(p): return Vector2(p.x, p.z).distance_to(Vector2(s.x, s.z)) < SPACING):
			continue
		out.append(s)
	return out


## Level enough to set things on.
static func _level(ground: Callable, q: Vector2) -> bool:
	var hx := float(ground.call(q.x + 2.0, q.y)) - float(ground.call(q.x - 2.0, q.y))
	var hz := float(ground.call(q.x, q.y + 2.0)) - float(ground.call(q.x, q.y - 2.0))
	return absf(hx) < 2.2 and absf(hz) < 2.2


## Out past r along d it stays sea (not a pond inland).
static func _open_sea(ground: Callable, d: Vector2, r: float) -> bool:
	for k in [6.0, 14.0, 24.0]:
		if float(ground.call(d.x * (r + k), d.y * (r + k))) > -2.0:
			return false
	return true


## [[item id, count]] rolled from a table of [id, lo, hi] (counts of 0 left out).
static func roll(table: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for e in table:
		var n := rng.randi_range(int(e[1]), int(e[2]))
		if n > 0:
			out.append([e[0], n])
	return out


# --------------------------------------------------------------------------
# The spots
# --------------------------------------------------------------------------
## A chest gone to the bottom, barnacled, half in the sand: a LootBag you open with F while diving.
static func sunken_chest(parent: Node3D, at: Vector3, yaw: float, key: String, items: Array, rng: RandomNumberGenerator, size := 1.3) -> LootBag:
	var bag := LOOT_BAG.instantiate() as LootBag
	bag.setup(SF.stacks(items))
	bag.save_id = key
	bag.name = "Chest_" + key
	parent.add_child(bag)
	bag.global_transform = Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.18, 0.18), yaw, rng.randf_range(-0.22, 0.22))), at + Vector3(0, -0.08, 0))
	var mi := bag.get_node("MeshInstance3D") as MeshInstance3D
	mi.mesh = Props.treasure_chest_mesh()
	mi.position = Vector3.ZERO
	mi.scale = Vector3.ONE * size
	_quiet(mi)
	bag.interactable.usable_in_water = true
	bag.interactable.gesture = ""
	bag.interactable.prompt_text = "Open the sunken chest"
	bag.add_to_group("dive_chests")
	var mb := MeshBuilder.new()
	var shell := PSXMat.lit("rock", Color(0.78, 0.8, 0.74))
	for i in range(5):
		var a := rng.randf() * TAU
		mb.add_blob(shell, Transform3D(Basis(), Vector3(cos(a) * 0.55, 0.0, sin(a) * 0.4)), Vector3.ONE * rng.randf_range(0.08, 0.16), rng, 0.2, 3, 5)
	var m := mb.to_instance("Barnacles")
	_quiet(m)
	bag.add_child(m)
	return bag


## A bed of oysters on a rock, one gaping on a pearl: pry them open with F (each captain once).
static func oyster_bed(parent: Node3D, at: Vector3, key: String, rng: RandomNumberGenerator) -> Array:
	var holder := Node3D.new()
	holder.name = "Oysters_" + key
	parent.add_child(holder)
	holder.global_position = at
	var mb := MeshBuilder.new()
	var rock := PSXMat.lit("rock", Color(0.5, 0.52, 0.5))
	var shell := PSXMat.lit("driftstone", Color(0.62, 0.58, 0.55))
	mb.add_blob(rock, Transform3D(Basis(), Vector3(0, -0.1, 0)), Vector3(1.1, 0.45, 0.9), rng, 0.25, 4, 7)
	var pearl_at := Vector3.ZERO
	for i in range(6):
		var a := float(i) / 6.0 * TAU + rng.randf_range(-0.3, 0.3)
		var p := Vector3(cos(a) * rng.randf_range(0.35, 0.8), 0.22, sin(a) * rng.randf_range(0.3, 0.65))
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		var open := 0.55 if i == 0 else rng.randf_range(0.05, 0.2)
		if i == 0:
			pearl_at = p + Vector3(0, 0.06, 0)
		# the bottom shell, and the top one hinged at its back edge
		mb.add_blob(shell, Transform3D(b, p), Vector3(0.2, 0.05, 0.15), rng, 0.15, 3, 6)
		var hinge := Transform3D(b, p + b * Vector3(0, 0.03, 0.12))
		mb.add_blob(shell, hinge * Transform3D(Basis(Vector3.RIGHT, -open), Vector3(0, 0, -0.12)), Vector3(0.2, 0.05, 0.15), rng, 0.15, 3, 6)
	var m := mb.to_instance("Bed")
	_quiet(m)
	holder.add_child(m)
	var pearl := MeshBuilder.new()
	pearl.add_blob(PSXMat.glow(Color(1.0, 0.96, 0.9), 0.6), Transform3D(Basis(), pearl_at), Vector3.ONE * 0.06, rng, 0.0, 3, 6)
	var pm := pearl.to_instance("Pearl")
	_quiet(pm)
	holder.add_child(pm)
	var it := _pickup_area(holder, "Pry open the oysters", 1.7)
	it.interacted.connect(func(player: Player): _take(player, key, OYSTERS, holder.global_position + Vector3(0, 0.4, 0), "A pearl!", pm))
	return [holder, key, pm]


## Coral heads in pinks, oranges and violets with kelp swaying over them: gather from the reef with F.
static func reef_garden(parent: Node3D, at: Vector3, key: String, rng: RandomNumberGenerator) -> Array:
	var holder := Node3D.new()
	holder.name = "Reef_" + key
	parent.add_child(holder)
	holder.global_position = at
	var mb := MeshBuilder.new()
	var coral := PSXMat.lit("", Color.WHITE)
	var cols := [Color(1.0, 0.35, 0.5), Color(1.0, 0.55, 0.15), Color(0.7, 0.35, 1.0), Color(1.0, 0.9, 0.45)]
	for i in range(10):
		var a := rng.randf() * TAU
		var c := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.2, 2.4)
		var col: Color = cols[rng.randi() % cols.size()]
		if rng.randf() < 0.55:
			# branching coral: tapering arms leaning out, forked at the tips
			for b in range(6):
				var tilt := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.15, 0.75))
				var l := rng.randf_range(0.8, 1.5)
				mb.add_cylinder(coral, Transform3D(tilt, c), 0.11, 0.05, l, 5, 1.0, col)
				var tip := c + tilt * Vector3(0, l, 0)
				for f in [-0.5, 0.5]:
					mb.add_cylinder(coral, Transform3D(tilt * Basis(Vector3.FORWARD, f), tip), 0.05, 0.02, l * 0.4, 4, 1.0, col)
		else:
			# a brain head
			mb.add_blob(coral, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), c + Vector3(0, 0.2, 0)), Vector3(rng.randf_range(0.45, 0.8), rng.randf_range(0.3, 0.55), rng.randf_range(0.4, 0.7)), rng, 0.25, 4, 7, 0.5, col, -0.2)
	var m := mb.to_instance("Coral")
	_quiet(m)
	holder.add_child(m)
	var kelp := MeshBuilder.new()
	var leaf := PSXMat.cutout("reeds", Color(0.35, 0.62, 0.38), 0.25, 3.0)
	for i in range(5):
		var a := rng.randf() * TAU
		var h := rng.randf_range(1.8, 3.4)
		kelp.add_cross_cards(leaf, Transform3D(Basis(Vector3.UP, a), Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.0, 2.6)), 0.7, h, 2)
	var km := kelp.to_instance("Kelp")
	_quiet(km)
	holder.add_child(km)
	var it := _pickup_area(holder, "Gather from the reef", 2.4)
	it.interacted.connect(func(player: Player): _take(player, key, REEF, holder.global_position + Vector3(0, 0.6, 0), "From the reef", null))
	return [holder, key, null]


## A sloop that went down whole, lying on her side in the sand, her chest spilled out beside her.
static func sunken_wreck(parent: Node3D, at: Vector3, yaw: float, key: String, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	body.name = "Wreck_" + key
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	body.global_transform = Transform3D(Basis.from_euler(Vector3(rng.randf_range(0.1, 0.25), yaw, rng.randf_range(1.0, 1.25))), at + Vector3(0, 0.6, 0))
	var model := Node3D.new()
	body.add_child(model)
	HullBuilder.build(model, {"hull": Color(0.36, 0.42, 0.38), "deck": Color(0.45, 0.5, 0.44), "trim": Color(0.3, 0.34, 0.3), "wreck": true})
	HullBuilder.collide(body, false)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		_quiet(mi as MeshInstance3D)
	var side := body.global_basis.z.normalized()
	sunken_chest(parent, at + Vector3(side.x, 0, side.z) * 1.5 + body.global_basis.x.normalized() * 3.6, yaw + 0.6, key, roll(WRECK_LOOT, rng), rng)


## A drowned shrine: a cracked floor, columns standing, broken and fallen round it, an arch, a stone coffer
## with the best of it in the middle.
static func sunken_ruin(parent: Node3D, at: Vector3, yaw: float, key: String, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	body.name = "Ruin_" + key
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	body.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("sandstone", Color(0.7, 0.78, 0.74))
	var moss := Color(0.7, 0.85, 0.7)
	# (a deep plinth: on a sloping seabed the low side still meets the sand)
	mb.add_box(stone, Transform3D(Basis(Vector3.RIGHT, rng.randf_range(-0.04, 0.04)), Vector3(0, -1.25, 0)), Vector3(7.5, 3.0, 7.5), 0.5, moss)
	_box_col(body, Vector3(0, -1.25, 0), Vector3(7.5, 3.0, 7.5))
	for i in range(8):
		var a := float(i) / 8.0 * TAU
		var p := Vector3(cos(a) * 3.1, 0.25, sin(a) * 3.1)
		var roll_k := rng.randf()
		if i == 0 or i == 1:
			roll_k = 0.0
		if roll_k < 0.45:
			var h := 3.6 if i < 2 else rng.randf_range(2.4, 3.8)
			mb.add_cylinder(stone, Transform3D(Basis(), p), 0.36, 0.3, h, 7, 0.5, moss)
			mb.add_box(stone, Transform3D(Basis(Vector3.UP, a), p + Vector3(0, h + 0.15, 0)), Vector3(0.9, 0.3, 0.9), 0.5)
			_cyl_col(body, p + Vector3(0, h * 0.5, 0), 0.36, h)
		elif roll_k < 0.75:
			var h := rng.randf_range(0.6, 1.6)
			mb.add_cylinder(stone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), 0.36, 0.33, h, 7, 0.5, moss)
			_cyl_col(body, p + Vector3(0, h * 0.5, 0), 0.36, h)
		else:
			var fall := Basis(Vector3.UP, a + rng.randf_range(0.8, 2.2)) * Basis(Vector3.RIGHT, PI * 0.5)
			mb.add_cylinder(stone, Transform3D(fall, p + Vector3(0, 0.35, 0)), 0.34, 0.3, rng.randf_range(2.0, 3.0), 7, 0.5, moss)
	# the arch over columns 0 and 1
	var c0 := Vector3(3.1, 0.25, 0)
	var c1 := Vector3(cos(TAU / 8.0) * 3.1, 0.25, sin(TAU / 8.0) * 3.1)
	var mid := (c0 + c1) * 0.5
	mb.add_box(stone, Transform3D(Basis(Vector3.UP, -atan2(c1.z - c0.z, c1.x - c0.x)), mid + Vector3(0, 4.15, 0)), Vector3(c0.distance_to(c1) + 1.0, 0.5, 0.8), 0.5)
	var m := mb.to_instance("Stones")
	_quiet(m)
	body.add_child(m)
	var coffer := sunken_chest(parent, body.global_transform * Vector3(0, 0.3, 0), yaw, key, roll(RUIN_LOOT, rng), rng, 1.6)
	coffer.interactable.prompt_text = "Open the stone coffer"


## An F-target that works under water, round `holder`.
static func _pickup_area(holder: Node3D, prompt: String, r: float) -> Interactable:
	var it := Interactable.new()
	it.name = "Take"
	it.collision_layer = 512
	it.collision_mask = 0
	it.usable_in_water = true
	it.prompt_text = prompt
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = r
	cs.shape = sph
	it.add_child(cs)
	holder.add_child(it)
	it.position = Vector3(0, 0.5, 0)
	return it


static func _take(player: Player, key: String, what: Array, at: Vector3, line: String, gone: Node3D) -> void:
	var gm := player.get_node("/root/GameManager")
	if gm.opened.has(key):
		return
	var inv: InventoryComponent = player.inventory_component
	var got := roll(what, Loot.rng_for(key))
	for e in got:
		if inv.room_for(ItemDB.get_item(str(e[0]))) < int(e[1]):
			player.call("_toast", "Your bag is full")
			return
	var names: Array = []
	for e in got:
		var item := ItemDB.get_item(str(e[0]))
		inv.add_item(item, int(e[1]))
		names.append("%s x%d" % [item.display_name, int(e[1])])
	gm.mark_opened(key)
	player.call("_toast", "%s  %s" % [line, ", ".join(names)])
	FX.sparkle(at, 10, Color(0.85, 0.97, 1.0))
	FX.bubbles(at, 8)
	FX.sfx("clack", at, -6.0)
	if gone:
		gone.visible = false


## Taken oysters and reefs lose their F (and the pearl), whoever's save says so.
func _apply_taken() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return
	for e in _pickups:
		if not is_instance_valid(e[0]):
			continue
		var taken: bool = gm.opened.has(e[1])
		((e[0] as Node).get_node("Take") as Interactable).enabled = not taken
		if e[2]:
			(e[2] as Node3D).visible = not taken


## Bubbles rise from a chest still on the bottom to the surface; under water it catches the light.
func _tell() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for c in get_tree().get_nodes_in_group("dive_chests"):
		var bag := c as LootBag
		if bag.is_queued_for_deletion() or not bag.interactable.enabled:
			continue
		var p := bag.global_position
		var d := cam.global_position.distance_to(p)
		if d > TELL_RANGE:
			continue
		var surf := float(Ocean.surface_at(p))
		FX.bubbles(Vector3(p.x, surf - 0.3, p.z), 4)
		FX.bubbles(p + Vector3(0, 0.5, 0), 2)
		if d < 26.0 and cam.global_position.y < float(Ocean.surface_at(cam.global_position)):
			FX.sparkle(p + Vector3(0, 0.45, 0), 3, Color(1.0, 0.92, 0.6))


static func _quiet(mi: MeshInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = SEE


static func _box_col(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = at
	body.add_child(cs)


static func _cyl_col(body: StaticBody3D, at: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	cs.shape = c
	cs.position = at
	body.add_child(cs)
