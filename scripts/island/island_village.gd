class_name IslandVillage
extends Node3D
## A generated island's village (GenIsland.sites["village"]), from its seed: one of the
## layouts in VillageLayouts' pool (a town, hamlets, a walled trading post, a raised
## village on stilts, an abandoned one with its survivors nearby), each with the inn, a
## walk-in trader's store and cookhouse, the elder, a job board and villagers where its
## people are. `plan` lays it out as data in GenIsland.prepare (a worker thread); `build`
## (IslandContent's village step) makes the inn and the people; `steps` the rest a piece
## a frame.
##
## Jobs (the board offers, the elder pays): the camp's captain, the bug lair, the beast.
## Per captain, kept in Dialogue flags "isle<id>_<job>_taken / _done / _paid". A deed done
## before the job was taken counts once it's taken ("isle<id>_<job>_beaten").

const ELDERS := ["Elder Mako", "Elder Tavi", "Old Kesi", "Elder Rua", "Grandmother Ilo", "Headman Pakua"]
const COOKS := ["Nalu", "Ama", "Big Teo", "Siri"]
const TRADERS := ["Wiremu", "Lani", "Haku", "Moana"]
const INNKEEPERS := ["Keala", "Pono", "Rangi", "Ulani"]
const VILLAGER_BARKS := [
	"Keep to the paths after dark. The trees have eyes, and some of them are hungry.",
	"We trade fruit for news. You look like you've got news.",
	"Ships come, ships go. Most of them come back lighter.",
	"Don't drink from the green pools. Trust me.",
	"The bugs were never this bold before the pirates came.",
	"Something big walks the far side of the island at night. We don't go there.",
	"If you're heading on, ask the elder about the way. The needle's not the only thing that knows.",
]
const JOB_STEPS := 0.5
const Shops := preload("res://scripts/game/shops.gd")
## NightLights for the whole village (inn door, the shops' and homes' rooms, the shrine, lamps, torches).
const LIGHTS := 16
## Built with the people in the village step, then the shops (and their keepers); the other buildings come after.
const CORE := ["inn"]
const SHOPS := ["trade", "cook"]
## Palisade logs built a step.
const PALISADE_LOGS := 120
const ROOMS := ["trade", "cook", "home", "elder"]

var isl: GenIsland
var ctx: KitContext
## job id -> {"title", "line", "gold", "check": Callable}
var jobs := {}
var elder_name := ""
var _t := 0.0

# For villagers' routines (island space; filled as the village is built):
## Which of VillageLayouts.POOL this is.
var layout := ""
## The heart, where the services are: {"c": Vector2, "r": float, "y": float (INF: on the ground; the deck's height when raised)}
var plaza := {}
## The lanes the village cut (PackedVector2Array each, also in isl.paths).
var lanes: Array = []
## Every street through the village: the lanes and the paths' stretches near its houses.
var streets: Array = []
## {"c": Vector2, "kind": "hub" / "fishers" / "farmers" / "woodcutters" / "survivors"}: hamlets and survivors.
var hamlets: Array = []
## {"kind", "node", "p", "face", "door": Vector2 (outside the way in), "enterable": bool,
## "floor_y" (rooms and raised houses), "inside": Vector2 (rooms)}. Kinds: VillageLayouts.SIZE's keys.
var buildings: Array = []
## Where someone works or idles: {"kind", "at", "face", "y" (INF: on the ground), "taken": bool}.
## Kinds: market, shop, customer, workshop, shrine, pray, home, well, laundry, garden, woodpile, fishrack.
var work_spots: Array = []
## Every building's footprint as [centre, radius]: what villagers' lanes turn aside from (IslandLife).
var taken: Array = []
## Benches: {"at", "face", "y"}.
var seats: Array = []
## {"c": Vector2, "stalls": [Node3D]} (empty without a market)
var market := {}
## Raised walking surfaces: {"c", "r", "y"} (the deck), and walkways {"a", "b", "y"} (stilts layout).
var decks: Array = []
var walkways: Array = []
var _keepers := {}
var _names := {}
var _wall: StaticBody3D
var _wall_rng: RandomNumberGenerator


static func plan(gi: GenIsland) -> Dictionary:
	return VillageLayouts.plan(gi)


# ==========================================================================
# Building it (main thread)
# ==========================================================================
static func build(gi: GenIsland, rng: RandomNumberGenerator) -> IslandVillage:
	var v := IslandVillage.new()
	v.name = "Village"
	v.isl = gi
	var site := gi.site_node("village")
	site.add_child(v)
	v.ctx = KitContext.make(gi, int(gi.node["seed"]), gi.theme, LIGHTS, gi.build_ms).under(site)
	v._build(rng)
	return v


## The rest of the village after the inn and the people, as GenIsland finish steps
## ([name, Callable]): the shops, the other buildings a few at a time, the layout's
## own structures, the market and bunting, the dressing in batches, the cargo, the ground.
static func steps(gi: GenIsland) -> Array:
	var p: Dictionary = gi.village_plan
	var shops: Array = p["buildings"].filter(func(b): return SHOPS.has(b["kind"]))
	var out: Array = []
	for b in shops:
		out.append(["village shops", func(): _of(gi)._shops([b])])
	var rest: Array = p["buildings"].filter(func(b): return not CORE.has(b["kind"]) and not SHOPS.has(b["kind"]))
	for b in rest:
		out.append(["village houses", func(): _of(gi)._make(b)])
	var ex: Dictionary = p["extra"]
	if ex.has("palisade"):
		var logs := KitHouses.palisade_angles(ex["palisade"]["r"], ex["palisade"]["arcs"])
		for i in range(0, logs.size(), PALISADE_LOGS):
			var part := logs.slice(i, i + PALISADE_LOGS)
			out.append(["village walls", func(): _of(gi)._palisade(part)])
		out.append(["village walls", func(): _of(gi)._palisade_rails()])
		out.append(["village walls", func(): _of(gi)._gates()])
		for i in range(ex["towers"].size()):
			out.append(["village walls", func(): _of(gi)._tower(i)])
	if ex.has("deck"):
		out.append(["village walks", func(): _of(gi)._walks()])
	if ex.has("nest"):
		out.append(["village ruins", func(): _of(gi)._ruins()])
	out.append(["village market", func(): _of(gi)._market()])
	var items: Array = p["items"].filter(func(it): return it["k"] != "cargo")
	for i in range(0, items.size(), 20):
		var chunk := items.slice(i, i + 20)
		out.append(["village dressing", func(): _of(gi)._dress(chunk)])
	out.append(["village cargo", func(): KitVillage.build_cargo(_of(gi).ctx, p["items"])])
	out.append(["village paving", func(): _of(gi)._pave()])
	return out


static func _of(gi: GenIsland) -> IslandVillage:
	return gi.get_node("Site_village/Village")


func _key(s: String) -> String:
	return isl.save_key(s)


func _build(rng: RandomNumberGenerator) -> void:
	var p: Dictionary = isl.village_plan
	var c: Vector2 = p["c"]
	var hy: float = p["heart_y"]
	var site := isl.site_node("village")
	var to_dock: Vector2 = p["to_dock"]
	var side := Vector2(-to_dock.y, to_dock.x)
	var t := IslandContent.tier(isl)
	var lvl := int(isl.node["level"])
	layout = p["layout"]
	plaza = {"c": c, "r": p["plaza_r"], "y": hy}
	lanes = p["lanes"]
	streets = p["streets"]
	hamlets = p["hamlets"]
	for f in p["fires"]:
		_fire(f[0], f[1])
	var inn := {}
	for b in p["buildings"]:
		if CORE.has(b["kind"]):
			inn = _make(b)
	# resting at the inn: at its door
	var rest := Interactable.new()
	rest.name = "Rest"
	rest.collision_layer = 512
	rest.collision_mask = 0
	rest.prompt_text = "Rest at the inn"
	rest.gesture = "push"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.4
	cs.shape = sph
	rest.add_child(cs)
	site.add_child(rest)
	var inn_door: Vector2 = inn["door"]
	var door_y: float = inn.get("floor_y", isl.hv(inn_door))
	rest.global_position = isl.to_global(Vector3(inn_door.x, door_y + 1.4, inn_door.y))
	rest.interacted.connect(func(player: Player): player.call("_toast", GameManager.rest(player)))
	# the trader's store and the cookhouse
	var trade_id := _key("trader")
	var food_id := _key("cook")
	var w := IslandContent.LOOT_WEAPONS
	Shops.extra[trade_id] = {"name": "%s's Trade Goods" % TRADERS[rng.randi() % TRADERS.size()],
		"line": "Shells, steel and sea-gems. I'll take your loot at a fair price.",
		"stock": [["rum", 9], ["biscuit", 3], ["tonic", 28 + t * 2], ["%s@%d" % [w[rng.randi() % w.size()], t], 60 + t * 40],
			["%s@%d" % [w[rng.randi() % w.size()], maxi(t - 1, 0)], 40 + t * 25], ["pistol@%d" % maxi(t - 1, 0), 70 + t * 30]]
			+ Instruments.trader_stock(trade_id),
		"buys": {"loot": 0.9, "gear": 0.5, "weapon": 0.5}}
	Shops.extra[food_id] = {"name": "%s's Cookpot" % COOKS[rng.randi() % COOKS.size()],
		"line": "Fish from the reef, fruit from the trees, something in the pot. Eat.",
		"stock": [["fish", 5], ["stew", 16], ["rum", 8]], "buys": {"consumable": 0.4}}
	# the job board by the way in
	var bd: Dictionary = p["board"]
	var board := ctx.place(KitVillage.notice_board(rng), bd["p"], KitContext.face_yaw(bd["face"]), 1.0, 0.0, false)
	if bd.has("y"):
		board.global_position.y = isl.global_position.y + float(bd["y"])
	var read := Interactable.new()
	read.name = "Read"
	read.collision_layer = 512
	read.collision_mask = 0
	read.prompt_text = "Read the job board"
	read.gesture = "reach"
	var rcs := CollisionShape3D.new()
	var rsph := SphereShape3D.new()
	rsph.radius = 1.8
	rcs.shape = rsph
	rcs.position = Vector3(0, 1.2, 0.6)
	read.add_child(rcs)
	board.add_child(read)
	read.interacted.connect(func(_p): Dialogue.start(_key("board"), board))
	# the people
	var lks := looks(isl)
	elder_name = ELDERS[rng.randi() % ELDERS.size()]
	_npc({"name": elder_name, "dialogue": _key("elder"), "voice": 0.8, "look": lks[0]}, c - to_dock * 3.0 + side * 3.0, to_dock, hy)
	_npc({"name": "Innkeeper " + INNKEEPERS[rng.randi() % INNKEEPERS.size()], "voice": 1.1, "look": lks[1],
		"barks": ["A hammock, a roof and a dry night. Rest when you like.", "We don't get many ships. We get fewer that leave."]},
		inn_door + Vector2(-inn["face"].y, inn["face"].x) * 1.2, inn["face"], inn.get("floor_y", INF))
	_keepers = {"trade": {"name": str(Shops.extra[trade_id]["name"]).trim_suffix("'s Trade Goods"), "voice": 0.95, "shop": trade_id, "look": lks[2],
		"barks": ["Have a look. Everything's for sale, and most of it's for sale cheap."]},
		"cook": {"name": str(Shops.extra[food_id]["name"]).trim_suffix("'s Cookpot"), "voice": 1.15, "shop": food_id, "look": lks[3],
		"barks": ["Sit, eat. You look like a ship's biscuit with legs."]}}
	var pr: float = p["plaza_r"]
	for i in range(4, lks.size()):
		var q := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(pr * 0.4, pr * 0.85)
		_npc({"name": "Villager", "voice": rng.randf_range(0.85, 1.2), "look": lks[i],
			"barks": [VILLAGER_BARKS[rng.randi() % VILLAGER_BARKS.size()], VILLAGER_BARKS[rng.randi() % VILLAGER_BARKS.size()]]},
			q, c - q, hy)
	# the jobs and the talk
	var camp = isl.get_node("Site_camp/Camp")
	var cap_title := str(camp.specs.filter(func(s): return s.get("captain", false))[0]["title"])
	jobs["camp"] = {"title": "Bounty: %s" % cap_title, "gold": 40 + t * 20,
		"line": "WANTED: %s. Raids our gardens, burns our boats. Bring word of his end to %s." % [cap_title, elder_name],
		"check": func() -> bool: return camp.grunts.any(func(g): return is_instance_valid(g) and g.captain and g.state == PirateGrunt.S.DEAD)}
	var burrows = isl.get_node("Site_lair/Burrows")
	jobs["lair"] = {"title": "Clear the bug lair", "gold": 30 + t * 15,
		"line": "The burrows inland have spilled into the gardens. Clear every bug from the lair and see %s." % elder_name,
		"check": func() -> bool: return burrows.alive_count() == 0}
	# (by its flag, not the arena: tools rebuild the arena)
	var beast_flag := _key("boss_beaten")
	jobs["beast"] = {"title": "Slay the beast", "gold": 80 + t * 35,
		"line": "Something huge has torn up the far side of the island. It took two of our hunters. Kill it, and %s will see you paid in full." % elder_name,
		"check": func() -> bool: return Dialogue.has_flag(beast_flag)}
	_define_board()
	_define_elder(lvl)
	Dialogue.dialogue_event.connect(_on_event)


## A fire pit at p (on the ground, or on a deck at height y), crackling.
func _fire(p: Vector2, y: float) -> void:
	if y == INF:
		IslandContent._fire(isl, isl.site_node("village"), p)
		return
	var fire := Props.campfire()
	ctx.put(fire, Vector3(p.x, y, p.y))
	var snd := AudioStreamPlayer3D.new()
	snd.stream = load("res://assets/audio/campfire_loop.wav")
	snd.unit_size = 4.0
	snd.max_distance = 30.0
	snd.volume_db = -4.0
	snd.autoplay = true
	snd.bus = "Ambience"
	fire.add_child(snd)


## One planned building, made and placed (it stands on the highest ground under it, its
## posts or footing down to the lowest; a raised one's floor at its "raised" height);
## recorded in `buildings` with its work spots.
func _make(b: Dictionary) -> Dictionary:
	var p: Vector2 = b["p"]
	var face: Vector2 = b["face"]
	var kind: String = b["kind"]
	var w: float = b["w"]
	var d: float = b["d"]
	var r := maxf(w, d) * 0.6
	var top := ctx.ground_max(p, r)
	var low := ctx.ground_min(p, r)
	var found := top - low + 0.4
	var raised: float = b.get("raised", INF)
	var rng := KitVillage._seeded(int(b["seed"]))
	var yaw := KitContext.face_yaw(face)
	var hs: Dictionary = ctx.style["house"]
	var mat: Dictionary = ctx.style["mat"]
	var walls: Array = hs["walls"]
	var frame := {"beam": hs["beam"], "floor": hs["floor"], "poles": hs["poles"], "lashings": hs["lashings"], "eaves": hs["eaves"]}
	var trim: Color = hs["trims"][0]
	var n: Node3D
	match kind:
		"inn":
			n = _house({"w": w, "d": d, "h": 2.7, "floors": 2, "h2": 2.3, "roof": "hip", "wall": ctx.style["inn"]["wall"], "wall2": mat["weave"], "roof_tex": mat["thatch"],
				"porch": 2.0, "lantern": true, "lamp_light": true, "trim": trim, "sign": "sign_tavern", "seed": rng.randi(), "name": "Inn"}.merged(frame), p, face, raised)
		"trade", "cook", "home", "elder":
			var spec := {"kind": "home" if kind == "elder" else kind, "w": w, "d": d, "found": found, "seed": rng.randi(),
				"roof": ["hip", "gable"][rng.randi() % 2], "wall": walls[rng.randi() % walls.size()], "roof_tex": mat["thatch"],
				"name": _uniq("Shop" if SHOPS.has(kind) else "Home")}
			if raised != INF:
				spec.merge({"fl": raised - top, "steps": false}, true)
			n = ctx.place(KitHouses.room(spec), p, yaw, r, 0.0, false)
			# every room's lantern lights it: the shops' all day, the homes' after dark
			var nl := KitLights.light(ctx, n, Vector3(0, float(spec.get("fl", 0.6)) + 1.7, 0.0), 0.9, 6.5)
			if nl and SHOPS.has(kind):
				nl.always = true
		"workshop":
			n = ctx.place(KitHouses.workshop({"seed": rng.randi(), "found": found}), p, yaw, r, 0.0, false)
		"shrine":
			n = ctx.place(KitHouses.shrine({"seed": rng.randi(), "found": found}), p, yaw, r, 0.0, false)
			KitLights.light(ctx, n, Vector3(0, 2.4, 2.0), 1.2, 9.0)
		"storehouse":
			n = ctx.place(KitHouses.storehouse({"seed": rng.randi(), "found": found}), p, yaw, r, 0.0, false)
		"ruin":
			n = ctx.place(KitHouses.ruin({"w": w, "d": d, "seed": rng.randi(), "found": found, "name": _uniq("Ruin")}), p, yaw, r, 0.0, false)
		"tall":
			var upper: Array = ctx.style["row_upper"]
			n = _house({"w": w, "d": d, "h": 2.4, "floors": 2, "h2": 2.2, "jetty": 0.3, "roof": ["hip", "gable", "gable_front"][rng.randi() % 3],
				"wall": walls[rng.randi() % walls.size()], "wall2": upper[rng.randi() % upper.size()], "roof_tex": mat["thatch"],
				"pitch": hs["pitch"][0], "flowers": rng.randf() < 0.5, "trim": trim, "seed": rng.randi(), "name": _uniq("House"),
				"porch": 1.2 if raised != INF else 0.0}.merged(frame), p, face, raised)
		_:
			var roofs: Array = hs["roofs"]
			n = _house({"w": w, "d": d, "h": 2.3, "roof": roofs[rng.randi() % roofs.size()],
				"wall": walls[rng.randi() % walls.size()], "roof_tex": mat["thatch"],
				"porch": 1.2 if raised != INF or rng.randf() < 0.5 else 0.0, "lean_to": ["", "", "left", "right"][rng.randi() % 4],
				"flowers": rng.randf() < 0.4, "trim": trim, "seed": rng.randi(), "name": _uniq("House"),
				"pitch": rng.randf_range(hs["pitch"][0], hs["pitch"][1])}.merged(frame), p, face, raised)
	var info := {"kind": kind, "node": n, "p": p, "face": face, "enterable": ROOMS.has(kind), "door": p + face * (d * 0.5 + float(b["ext"]))}
	if raised != INF:
		info["door"] = p + face * (d * 0.5 + VillageLayouts._deck_ext(kind))
		info["floor_y"] = raised
	if ROOMS.has(kind):
		info["door"] = ctx.marker_point(n, "Door")
		info["inside"] = ctx.marker_point(n, "Inside")
		info["floor_y"] = ctx.marker_y(n, "Inside")
	buildings.append(info)
	taken.append([p, maxf(w, d) * 0.5 + 0.5])
	var spots := {"trade": [["Vendor", "shop"], ["Customer", "customer"]], "cook": [["Vendor", "shop"], ["Customer", "customer"]],
		"home": [["Hearth", "home"], ["Table", "home"], ["Bed", "home"]], "elder": [["Hearth", "home"], ["Table", "home"]],
		"workshop": [["Worker", "workshop"], ["Bench", "workshop"]], "shrine": [["Keeper", "shrine"], ["Pray", "pray"]]}
	for e in spots.get(kind, []):
		work_spots.append({"kind": e[1], "at": ctx.marker_point(n, e[0]), "face": ctx.marker_face(n, e[0]),
			"y": ctx.marker_y(n, e[0]) if ROOMS.has(kind) else INF, "taken": false})
	return info


## A Buildings.house on stilts: on its posts as the ground allows, or (raised) with its
## floor at y and no steps (a walkway meets its porch).
func _house(spec: Dictionary, p: Vector2, face: Vector2, y: float) -> Node3D:
	if y == INF:
		return ctx.house(spec, p, face, true, false)
	var r := maxf(float(spec["w"]), float(spec["d"])) * 0.6
	var low := ctx.ground_min(p, r)
	spec.merge({"stilts": y - low - 0.3, "foundation": 0.6, "steps": false}, true)
	if spec.get("lamp_light", false) and not ctx.take_light():
		spec["lamp_light"] = false
	var n := Buildings.house(spec)
	ctx.put(n, Vector3(p.x, low, p.y), KitContext.face_yaw(face))
	return n


## The trader's store and the cookhouse, each keeper behind the counter.
func _shops(list: Array) -> void:
	for b in list:
		var n: Node3D = _make(b)["node"]
		_npc(_keepers[b["kind"]], ctx.marker_point(n, "Vendor"), ctx.marker_face(n, "Vendor"), ctx.marker_y(n, "Vendor"))
	for s in work_spots:
		if s["kind"] == "shop":
			s["taken"] = true


## "House", then "House2", "House3"... (a node's name is how co-op and the tools find it).
func _uniq(base: String) -> String:
	_names[base] = int(_names.get(base, 0)) + 1
	return base if _names[base] == 1 else "%s%d" % [base, _names[base]]


## The trading post's palisade, its gates and watchtowers (a step each: the wall, the gates, every tower).
func _palisade(logs: Array) -> void:
	var pal: Dictionary = isl.village_plan["extra"]["palisade"]
	if _wall == null:
		_wall = KitHouses.palisade_body(ctx)
		_wall_rng = KitVillage._seeded(int(pal["seed"]))
	KitHouses.palisade_logs(ctx, _wall, isl.village_plan["c"], pal["r"], logs, _wall_rng)


func _palisade_rails() -> void:
	var pal: Dictionary = isl.village_plan["extra"]["palisade"]
	KitHouses.palisade_rails(ctx, _wall, isl.village_plan["c"], pal["r"], pal["arcs"])


func _gates() -> void:
	for g in isl.village_plan["extra"]["gates"]:
		var gate := KitHouses.gate()
		gate.name = _uniq("Gate")
		ctx.place(gate, g["p"], KitContext.face_yaw(g["t"]))


func _tower(i: int) -> void:
	var tw: Dictionary = isl.village_plan["extra"]["towers"][i]
	var tower := KitLandmarks.lookout_tower()
	tower.name = _uniq("LookoutTower")
	ctx.place(tower, tw["p"], KitContext.face_yaw(tw["face"]), 2.6, 0.0, false)


## The raised village's deck, its ramps down and the walkways out to the houses.
func _walks() -> void:
	var ex: Dictionary = isl.village_plan["extra"]
	var dk: Dictionary = ex["deck"]
	KitHouses.deck(ctx, dk["c"], dk["r"], dk["y"], dk["gaps"])
	decks.append({"c": dk["c"], "r": dk["r"], "y": dk["y"]})
	for rp in ex["ramps"]:
		KitHouses.ramp(ctx, rp["a"], rp["b"], rp["y"])
	for wk in ex["walks"]:
		KitHouses.walkway(ctx, wk["a"], wk["b"], wk["y"])
		walkways.append(wk)


## The abandoned village's bugs (burrows round its plaza) and the caches in its houses.
func _ruins() -> void:
	var ex: Dictionary = isl.village_plan["extra"]
	var site := isl.site_node("village")
	var nest_plan: Dictionary = ex["nest"]
	var c: Vector2 = nest_plan["c"]
	var nest := ScuttlebugNest.new()
	nest.name = "Burrows"
	nest.level = IslandContent.level(isl)
	site.add_child(nest)
	for e in nest_plan["burrows"]:
		var bp: Vector2 = e[0]
		var burrow := Props.burrow(int(absf(bp.x * 13.0 + bp.y * 7.0)))
		ctx.place(burrow, bp, KitContext.face_yaw(c - bp) + PI, 0.0, -0.08)
		nest.add_spot(IslandContent._local(isl, nest, bp + (c - bp).normalized() * 1.8), bool(e[1]))
	var t := IslandContent.tier(isl)
	for k in range(ex["caches"].size()):
		var ch: Dictionary = ex["caches"][k]
		var cp: Vector2 = ch["p"]
		var crng := KitVillage._seeded(hash([int(isl.node["seed"]), str(ch["key"])]))
		var r := 3.0
		isl.strongbox(site, cp, KitContext.face_yaw(ch["face"]), ch["key"], [["gold", crng.randi_range(8, 18) + t * 5], ["treasure", crng.randi_range(1, 2)],
			[ItemDB.tiered(IslandContent.LOOT_WEAPONS[crng.randi() % IslandContent.LOOT_WEAPONS.size()], t), 1]], 0.9, ctx.ground_max(cp, r) - isl.hv(cp) + 0.37)


func _market() -> void:
	var m: Dictionary = isl.village_plan["market"]
	var rng := KitVillage._seeded(int(isl.village_plan["bunting"]["seed"]))
	var mb := MeshBuilder.new()
	KitVillage.build_bunting(ctx, mb, isl.village_plan["bunting"]["poles"], 4.0, rng)
	if not m.is_empty():
		var stalls := KitMarket.build(ctx, m["c"], m["toward"], m["kinds"], KitVillage._seeded(int(m["seed"])))
		market = {"c": m["c"], "stalls": stalls}
		for s in stalls:
			work_spots.append({"kind": "market", "at": ctx.marker_point(s, "Vendor"), "face": ctx.marker_face(s, "Vendor"), "y": INF, "taken": false})
		var poles: Array = m.get("poles", [])
		if poles.size() == 2:
			for q in poles:
				KitVillage.pole(ctx, mb, q, 3.6)
			KitVillage.bunting(ctx, mb, KitContext.v3(poles[0], ctx.hv(poles[0]) + 3.4), KitContext.v3(poles[1], ctx.hv(poles[1]) + 3.4), rng)
	if not mb.is_empty():
		ctx.add(mb.to_instance("Bunting"))


## The cobbles, and the trodden earth a little under them (where they'd meet).
func _pave() -> void:
	if not isl.village_plan["quads"].is_empty():
		KitPaving.build(ctx, isl.village_plan["quads"])
	var worn := KitPaving.build(ctx, isl.village_plan["worn"], "Worn", "dirt", Color(0.92, 0.85, 0.78))
	worn.position.y -= 0.02


func _dress(list: Array) -> void:
	for e in KitVillage.build_items(ctx, list):
		var it: Dictionary = e[0]
		if it["k"] == "bench":
			seats.append({"at": it["p"], "face": Vector2(sin(float(it["yaw"])), cos(float(it["yaw"]))), "y": it.get("y", INF)})
		if it.has("spot"):
			work_spots.append({"kind": it["k"], "at": it["spot"]["at"], "face": it["spot"]["face"], "y": INF, "taken": false})


## Everyone's looks, from their own seed (GenIsland.prepare builds the bodies
## ahead on its worker thread): elder, innkeeper, trader, cook, then villagers.
static func looks(gi: GenIsland) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(gi.node["seed"]) + 77
	var out: Array = []
	var st := KitStyle.of(gi.theme)
	for i in range(4 + rng.randi_range(2, 3)):
		out.append(KitStyle.folk_look(st, rng))
	out[0].merge({"marks": "age_lines", "hair_color": CharacterLook.HAIR_COLORS[8], "height": 0.95, "hat": "none"}, true)
	return out


static func _villager_look(rng: RandomNumberGenerator) -> Dictionary:
	var lk := CharacterLook.random_look(rng)
	lk.merge({"coat": "none", "hat": ["straw", "none", "none", "bandana"][rng.randi() % 4], "feet": "barefoot" if rng.randf() < 0.5 else "shoes",
		"top": ["tunic", "shirt", "blouse"][rng.randi() % 3], "sleeves": "short", "vest": "none", "eyepatch": false, "gloves": false}, true)
	return lk


func _npc(cfg: Dictionary, p: Vector2, face: Vector2, y := INF) -> NPC:
	var npc := NPC.new()
	cfg["yaw"] = atan2(-face.x, -face.y)
	npc.setup(cfg)
	npc.ground_func = isl.walk_height
	isl.add_child(npc)
	npc.position = Vector3(p.x, isl.hv(p) if y == INF else y, p.y)
	return npc


func _flag(job: String, state: String) -> String:
	return "%s_%s" % [_key(job), state]


func _define_board() -> void:
	var nodes := {"start": {"text": "Notices, nailed up and curling in the damp.", "choices": []}}
	for job in jobs.keys():
		var j: Dictionary = jobs[job]
		nodes["start"]["choices"].append({"text": "%s  (%d gold)" % [j["title"], j["gold"]], "next": job, "hide_if": _flag(job, "taken")})
		nodes[job] = {"text": [j["line"], "You tear the notice down and pocket it."], "event": "isle_job:%s:take" % _key(job), "set_flag": _flag(job, "taken"), "next": "end"}
	nodes["start"]["choices"].append({"text": "Leave it.", "next": "end"})
	Dialogue.define(_key("board"), {"speaker": "Job board", "voice": 1.0, "start": "start", "nodes": nodes})


func _define_elder(lvl: int) -> void:
	var c: Chain = get_tree().get_first_node_in_group("world_gen").chain()
	var ahead: Array = c.next_of(int(isl.node["id"])).map(func(id): return c.node(id))
	var beyond := "Past us? %s." % " or ".join(ahead.map(func(n): return "%s, %s" % [n["name"], IslandThemes.of(n["theme"]).blurb])) if not ahead.is_empty() else "Past us? The end of this sea, they say."
	var menu := {"text": "What do you need, Captain?", "choices": [
		{"text": "Tell me about this island.", "next": "about"},
		{"text": "Where does the log pose point from here?", "next": "beyond"},
	]}
	var nodes := {
		"intro": {"text": ["Visitors! It's been a long season. Welcome to %s." % isl.island_name,
			"I'm %s. The board by the path has work, if you're the sort who takes it." % elder_name], "next": "menu"},
		"menu": menu,
		"about": {"text": LifePools.of(isl.theme)["elder_about"], "next": "menu"},
		"beyond": {"text": [beyond, "Your needle needs time on an island before it sets on the next, or something to happen here worth remembering."], "next": "menu"},
	}
	for job in jobs.keys():
		var j: Dictionary = jobs[job]
		menu["choices"].append({"text": "About the job: %s" % j["title"], "next": "pay_" + job, "requires": _flag(job, "done"), "hide_if": _flag(job, "paid")})
		nodes["pay_" + job] = {"text": ["It's done? Truly? The whole village owes you, Captain.", "Here: %d gold, as promised." % j["gold"]],
			"event": "isle_job:%s:pay" % _key(job), "set_flag": _flag(job, "paid"), "next": "menu"}
	menu["choices"].append({"text": "Goodbye.", "next": "end"})
	Dialogue.define(_key("elder"), {"speaker": elder_name, "voice": 0.8, "start": "intro", "return": "menu", "nodes": nodes})


func _on_event(ev: String) -> void:
	if not ev.begins_with("isle_job:"):
		return
	var parts := ev.split(":")
	for job in jobs.keys():
		if parts[1] != _key(job):
			continue
		match parts[2]:
			"take":
				_t = 0.0
			"pay":
				var me := get_tree().get_first_node_in_group("player") as Player
				me.inventory_component.add_item(ItemDB.get_item("gold"), int(jobs[job]["gold"]))
				GameManager.award_xp(roundi((60 + IslandContent.tier(isl) * 30) * Levels.xp_k(IslandContent.level(isl))), me.global_position)


## Twice a second: a deed done is remembered; a job taken and done says so.
func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = JOB_STEPS
	for job in jobs.keys():
		if not Dialogue.has_flag(_flag(job, "beaten")) and (jobs[job]["check"] as Callable).call():
			Dialogue.set_flag(_flag(job, "beaten"))
		if Dialogue.has_flag(_flag(job, "taken")) and Dialogue.has_flag(_flag(job, "beaten")) and not Dialogue.has_flag(_flag(job, "done")):
			Dialogue.set_flag(_flag(job, "done"))
			get_tree().call_group("hud", "show_toast", "Job done: %s. %s will pay." % [jobs[job]["title"], elder_name])
