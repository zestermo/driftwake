extends Node3D
## The sea between the chain's islands (docs/island_chain_plan.md, step 7).
## Once the log pose has set, each leg from the island we're at to each one it
## points to gets pirates sailing for the next island's level (a fleet of 1-2
## zones), hazards on or across the route (reefs, fog banks, whirlpools, storm
## cells), now and then a Sea King, and a few finds (a wreck, a bottle, an islet
## with a chest). All of it comes from the chain's seeds and Brinehollow's fixed
## sea, so every screen lays out the same leg; it's let go once the crew has
## arrived (chain_at moves on) or another chain loads.
## SeaFeatures' child "SeaLegs" (group "sea_legs"); its queries read the hazards here.

const SF := preload("res://scripts/world/sea_features.gd")
const SEA_KING := preload("res://scripts/enemies/sea_king.gd")
## Content keeps this far from every chain island's centre (GenIsland's widest
## radius, 450 m, and 150 m of open water)...
const ISLE_CLEAR := 600.0
## ...and from Brinehollow's (its own sea's content: kept GAP from that too).
const HOME_CLEAR := 900.0
const GAP := 260.0
const ISLET_R := 14.0
const ISLET_TOP := 1.8
## Pirate kinds by the next island's level: [from level, [first zone, second zone]].
const FLEETS := [
	[0, [["sloop", "gunboat"], ["gunboat", "sloop"]]],
	[10, [["gunboat", "sloop"], ["brig", "gunboat"]]],
	[14, [["brig", "gunboat"], ["marine"]]],
	[18, [["brig", "marine"], ["marine", "brig"]]],
]
const NOTES := [
	"Whoever finds this: the reefs past here have taken better ships than mine.",
	"Turn back. There's something in this water bigger than any ship.",
	"My share of the last haul. Spend it better than I did.",
	"The log pose doesn't lie. The sea between does.",
	"Three days adrift. If you're reading this, I'm out of rum.",
]

var sf: Node3D
## Every standing leg's hazards (SeaFeatures and the sea read these).
var reefs: Array = []
var fogs: Array = []
var whirls: Array = []
var storms: Array = []
## Vector2i(from, to) -> the leg's node (its fleet, hazards and finds).
var built := {}
var _bottles: Array = []
var _built_seed := 0
var _sync_t := 0.0


func _ready() -> void:
	add_to_group("sea_legs")


func _process(delta: float) -> void:
	SF.bob_bottles(_bottles, delta)
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = 0.5
		sync_legs()


## The legs the log pose points along stand; the rest go.
func sync_legs() -> void:
	# (a guest lays out the host's chain: nothing until the host's world state is here)
	if Net.is_client() and not Net.world_synced:
		return
	var c: Chain = sf.gen.chain()
	if c.seed_value != _built_seed:
		_built_seed = c.seed_value
		for k in built.keys():
			_free_leg(k)
	var want := wanted()
	for k in built.keys():
		if not want.has(k):
			_free_leg(k)
	for k in want:
		if not built.has(k):
			_build_leg(k)


## Vector2i(the island we're at, each it points to), once the log pose has set.
func wanted() -> Array:
	var gm := get_node("/root/GameManager")
	if not gm.log_pose_set():
		return []
	var at := int(gm.chain_at)
	return sf.gen.chain().next_of(at).map(func(id): return Vector2i(at, int(id)))


# --------------------------------------------------------------------------
# Laying out a leg (numbers only: the same on every screen)
# --------------------------------------------------------------------------
## Where everything on the leg from chain node `from` (-1 = Brinehollow) to `to` goes.
func plan(from: int, to: int) -> Dictionary:
	var gen = sf.gen
	var c: Chain = gen.chain()
	var n: Dictionary = c.node(to)
	var a: Vector2 = gen.starter_center if from < 0 else c.node(from)["pos"]
	var b: Vector2 = n["pos"]
	var lvl := int(n["level"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(n["seed"]) + (from + 2) * 1000003
	var lay := {"from": from, "to": to, "level": lvl, "seed": rng.seed, "zones": [], "reefs": [], "fogs": [],
		"whirls": [], "storms": [], "king": Vector2.INF, "wrecks": [], "bottles": [], "islets": []}
	var used: Array = []
	var kinds := _kinds(lvl)
	for i in range(2 if rng.randf() < 0.3 + lvl * 0.02 else 1):
		var r := rng.randf_range(110.0, 130.0)
		var p := _spot(rng, c, a, b, used, r, 320.0)
		if p != Vector2.INF:
			lay["zones"].append([p, r, kinds[i]])
	# hazards on the route or lying across it
	for i in range(rng.randi_range(1, 3)):
		match rng.randi() % 4:
			0:
				var r := rng.randf_range(18.0, 26.0)
				var p := _spot(rng, c, a, b, used, r + SF.REEF_KEEP, 120.0)
				if p != Vector2.INF:
					lay["reefs"].append([p, r])
			1:
				var r: float = SF.FOG_RADIUS * rng.randf_range(0.8, 1.2)
				var p := _spot(rng, c, a, b, used, r * 0.6, 180.0)
				if p != Vector2.INF:
					lay["fogs"].append([p, r])
			2:
				var r := rng.randf_range(38.0, 48.0)
				var p := _spot(rng, c, a, b, used, r + 20.0, 120.0)
				if p != Vector2.INF:
					lay["whirls"].append([p, r])
			3:
				var p := _spot(rng, c, a, b, used, 80.0, 250.0)
				if p != Vector2.INF:
					lay["storms"].append([p, rng.randf() * TAU])
	if rng.randf() < 0.2 + lvl * 0.015:
		lay["king"] = _spot(rng, c, a, b, used, 80.0, 150.0, 0.2, 0.8)
	var finds := ["wreck", "bottle", "islet"]
	for i in range(rng.randi_range(2, 3)):
		var f: String = finds[rng.randi() % finds.size()]
		if f == "islet":
			finds.erase("islet")
		var p := _spot(rng, c, a, b, used, {"wreck": 20.0, "bottle": 10.0, "islet": ISLET_R + 16.0}[f], 450.0)
		if p == Vector2.INF:
			continue
		match f:
			"wreck":
				lay["wrecks"].append([p, rng.randf() * TAU])
			"bottle":
				lay["bottles"].append(p)
			"islet":
				lay["islets"].append(p)
	return lay


func _kinds(lvl: int) -> Array:
	var out: Array = FLEETS[0][1]
	for f in FLEETS:
		if lvl >= int(f[0]):
			out = f[1]
	return out


## Open deep water somewhere along a→b (`lane` either side of the line, wider
## on a short leg: islands 1 km apart leave room only off to the side; then
## wider again if that's all taken) for something `r` across, clear of
## everything (INF if the leg's too crowded).
func _spot(rng: RandomNumberGenerator, c: Chain, a: Vector2, b: Vector2, used: Array, r: float, lane: float,
		t0: float = 0.05, t1: float = 0.95) -> Vector2:
	var d := b - a
	var side := Vector2(-d.y, d.x).normalized()
	lane += maxf(0.0, 1800.0 - d.length()) * 0.5
	for k in range(60):
		var w := lane if k < 30 else lane * 2.0 + 300.0
		var p := a + d * rng.randf_range(t0, t1) + side * rng.randf_range(-w, w)
		if _clear(c, p, r, used):
			used.append([p, r])
			return p
	return Vector2.INF


## Off every island of the chain and Brinehollow, apart from Brinehollow's own
## sea and the rest of this leg, on deep water.
func _clear(c: Chain, p: Vector2, r: float, used: Array) -> bool:
	var gen = sf.gen
	if p.distance_to(gen.starter_center) < HOME_CLEAR + r:
		return false
	for nd in c.nodes:
		if p.distance_to(nd["pos"]) < ISLE_CLEAR + r:
			return false
	for s in sf._spots:
		if p.distance_to(s) < GAP + r:
			return false
	for z in gen.fleet.zones:
		var zc: Vector3 = z["center"]
		if p.distance_to(Vector2(zc.x, zc.z)) < float(z["radius"]) + r + 150.0:
			return false
	for u in used:
		if p.distance_to(u[0]) < maxf(GAP, float(u[1]) + r + 60.0):
			return false
	for k in range(9):
		var q := p + (Vector2.from_angle(k * TAU / 8.0) * (r + 20.0) if k < 8 else Vector2.ZERO)
		if gen.height_at(q.x, q.y) > -12.0:
			return false
	return true


# --------------------------------------------------------------------------
# Building and letting go
# --------------------------------------------------------------------------
func _build_leg(key: Vector2i) -> void:
	var lay := plan(key.x, key.y)
	var lvl: int = lay["level"]
	var tier := clampi((lvl - 8) / 4, 1, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(lay["seed"]) + 1
	var leg := Node3D.new()
	leg.name = "Leg%d_%d" % [key.x, key.y]
	add_child(leg)
	built[key] = leg
	var nogo: Array = []
	var fleet := EnemyFleet.new()
	fleet.name = "Fleet"
	fleet.seed_base = 20000 + (key.y * 64 + key.x + 1) * 97
	fleet.warm = true
	for z in lay["zones"]:
		fleet.add_zone(Vector3(z[0].x, 0.0, z[0].y), z[1], z[2], lvl)
	leg.add_child(fleet)
	for i in range(lay["reefs"].size()):
		var e: Array = lay["reefs"][i]
		SF.build_reef(leg, e[0], e[1], rng, i)
		nogo.append([e[0], float(e[1]) + SF.REEF_KEEP])
	for i in range(lay["fogs"].size()):
		SF.build_fog(leg, lay["fogs"][i][0], lay["fogs"][i][1], rng, i)
	for w in lay["whirls"]:
		nogo.append([w[0], float(w[1]) + 10.0])
	if lay["king"] != Vector2.INF:
		var king := SEA_KING.new()
		king.name = "SeaKing"
		king.lair = lay["king"]
		leg.add_child(king)
	for i in range(lay["wrecks"].size()):
		var e: Array = lay["wrecks"][i]
		var picks := [["gold", rng.randi_range(20, 40) + tier * 8], ["treasure", rng.randi_range(1, 3)], ["rum", rng.randi_range(1, 2)]]
		if rng.randf() < 0.5:
			picks.append([_weapon(rng, tier), 1])
		SF.build_wreck(leg, i, e[0], e[1], _save_key(key, "wreck%d" % i), picks)
		nogo.append([e[0], 16.0])
	for i in range(lay["islets"].size()):
		var picks := [["gold", rng.randi_range(30, 50) + tier * 10], ["treasure", rng.randi_range(2, 4)], ["rum", 1]]
		if rng.randf() < 0.7:
			picks.append([_weapon(rng, tier), 1])
		_build_islet(leg, i, lay["islets"][i], rng, _save_key(key, "islet%d" % i), picks)
		nogo.append([lay["islets"][i], ISLET_R + 16.0])
	var bottles: Array = []
	var gm := get_node("/root/GameManager")
	for i in range(lay["bottles"].size()):
		var picks := [["gold", rng.randi_range(10, 20) + tier * 6], ["treasure", rng.randi_range(1, 2)]]
		var note: String = NOTES[rng.randi() % NOTES.size()]
		var id := _save_key(key, "bottle%d" % i)
		if not gm.opened.has(id):
			bottles.append(_build_bottle(leg, i, lay["bottles"][i], id, picks, note))
	# (built after the save was applied: chests opened before are gone)
	for bag in leg.find_children("*", "LootBag", true, false):
		if gm.opened.has((bag as LootBag).save_id):
			bag.queue_free()
	EnemyShip.no_go.append_array(nogo)
	leg.set_meta("plan", lay)
	leg.set_meta("no_go", nogo)
	leg.set_meta("bottles", bottles)
	_collect()


func _free_leg(key: Vector2i) -> void:
	var leg: Node3D = built[key]
	built.erase(key)
	var mine: Array = leg.get_meta("no_go")
	EnemyShip.no_go = EnemyShip.no_go.filter(func(z): return not mine.has(z))
	leg.queue_free()
	_collect()


func _collect() -> void:
	reefs = []
	fogs = []
	whirls = []
	storms = []
	_bottles = []
	for leg in built.values():
		var lay: Dictionary = leg.get_meta("plan")
		reefs += lay["reefs"]
		fogs += lay["fogs"]
		whirls += lay["whirls"]
		storms += lay["storms"]
		_bottles += leg.get_meta("bottles")


## A name in the save for something on this leg (chests opened, bottles read).
static func _save_key(key: Vector2i, what: String) -> String:
	return "leg%d_%d_%s" % [key.x, key.y, what]


static func _weapon(rng: RandomNumberGenerator, tier: int) -> ItemData:
	return ItemDB.tiered(IslandContent.LOOT_WEAPONS[rng.randi() % IslandContent.LOOT_WEAPONS.size()], tier)


## A rock of sand and stone breaking the sea, a palm on it and a chest under the palm.
func _build_islet(leg: Node3D, i: int, c: Vector2, rng: RandomNumberGenerator, save_id: String, picks: Array) -> void:
	var body := StaticBody3D.new()
	body.name = "Islet%d" % i
	body.collision_layer = 1
	body.collision_mask = 0
	leg.add_child(body)
	body.global_position = Vector3(c.x, 0.0, c.y)
	var base := -4.5
	var top_r := 6.0
	var mb := MeshBuilder.new()
	mb.add_cylinder(PSXMat.lit("sand"), Transform3D(Basis(), Vector3(0, base, 0)), ISLET_R, top_r, ISLET_TOP - base, 10, 0.5)
	var sand := mb.to_instance("Sand")
	sand.visibility_range_end = 1000.0
	body.add_child(sand)
	var pts := PackedVector3Array()
	for k in range(10):
		var d := Vector3.FORWARD.rotated(Vector3.UP, k * TAU / 10.0)
		pts.append(d * ISLET_R + Vector3(0, base, 0))
		pts.append(d * top_r + Vector3(0, ISLET_TOP, 0))
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	for k in range(5):
		var a := k * TAU / 5.0 + rng.randf_range(-0.4, 0.4)
		var d := rng.randf_range(7.0, 11.0)
		var mi := MeshInstance3D.new()
		mi.mesh = Props.rock_mesh(1300 + i * 7 + k, 1.0, true)
		mi.visibility_range_end = 1000.0
		mi.position = Vector3(cos(a) * d, ISLET_TOP - (d - top_r) / (ISLET_R - top_r) * (ISLET_TOP - base) - 0.4, sin(a) * d)
		mi.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		mi.scale = Vector3.ONE * rng.randf_range(1.2, 2.4)
		body.add_child(mi)
	var palm := MeshInstance3D.new()
	palm.mesh = Props.palm_mesh(int(c.x) * 31 + int(c.y))
	palm.visibility_range_end = 1000.0
	var pa := rng.randf() * TAU
	palm.position = Vector3(cos(pa) * 2.5, ISLET_TOP, sin(pa) * 2.5)
	palm.rotation.y = pa + PI
	body.add_child(palm)
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	bag.setup(SF.stacks(picks))
	bag.save_id = save_id
	bag.name = "Chest"
	body.add_child(bag)
	bag.position = Vector3(-cos(pa) * 1.2, ISLET_TOP, -sin(pa) * 1.2)
	bag.rotation.y = pa
	var chest := bag.get_node("MeshInstance3D") as MeshInstance3D
	chest.mesh = Props.treasure_chest_mesh()
	chest.position = Vector3.ZERO
	chest.scale = Vector3.ONE * 1.15


## A bottle bobbing on the swell: a castaway's coins and a note (each captain's own).
func _build_bottle(leg: Node3D, i: int, c: Vector2, save_id: String, picks: Array, note: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Bottle%d" % i
	leg.add_child(holder)
	holder.global_position = Vector3(c.x, 0.0, c.y)
	holder.add_child(SF.bottle_glass())
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
	holder.set_meta("save_id", save_id)
	it.interacted.connect(func(player: Player): _fish(holder, player, picks, note))
	return holder


func _fish(holder: Node3D, player: Player, picks: Array, note: String) -> void:
	var gm := get_node("/root/GameManager")
	var id: String = holder.get_meta("save_id")
	if gm.opened.has(id):
		return
	gm.mark_opened(id)
	for st in SF.stacks(picks):
		player.inventory_component.add_item(st.item, st.quantity)
	holder.visible = false
	(holder.get_node("Grab") as Interactable).enabled = false
	FX.sfx("splash", holder.global_position, -6.0, 0.1, 1.4)
	get_tree().call_group("hud", "show_banner", "A message in a bottle", "Coins rolled up in a note: \"%s\"" % note, true)
