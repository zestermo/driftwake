class_name IslandLife
extends RefCounted
## A generated island's people beyond IslandVillage's few: villagers on routines
## (Villager: work by day, lunch, the inn or the plaza in the evening, home at
## night), named characters with dialogue trees and rumours, and their quests
## (KitQuests). Planned from the island's seed in GenIsland.prepare (who, their
## looks, their bodies built there on the worker, the quests' kinds in order);
## placed after the sites (finish_steps) on whatever the island exposes: its
## life spots (Island.life_spots as the builders fed them, else what today's
## IslandVillage and sites give). Each hamlet (a spot's "hub") gets its share of
## the people; no village spots, no people and no quests.

const AMBIENT := [12, 15]
const NAMED := 3
const PER_STEP := 4
const JOBS := ["nets", "forage", "market", "home", "plaza"]
const ACT := {"nets": "kneel", "forage": "kneel", "home": "kneel", "field": "kneel", "market": "talk", "plaza": "talk", "inn": "talk", "well": "talk", "bench": "talk"}
## People at these stand round the spot this far out, facing in.
const GROUP := {"plaza": 3.8, "inn": 1.9, "well": 2.2}
const HARBOUR_KIND := {"net mender": "nets", "fisher": "nets", "boatwright": "boats", "fishmonger": "stall", "trader": "stall"}
## IslandVillage.work_spots' kinds as the routines' (the shopkeepers' own and the rest left out).
const VILLAGE_KIND := {"market": "market", "customer": "market", "workshop": "workshop", "woodpile": "workshop", "shrine": "shrine", "pray": "shrine",
	"home": "home", "well": "well", "garden": "field", "laundry": "field", "fishrack": "nets"}
const SITE_KIND :={"camp": "camp", "lair": "lair", "ruins": "ruins", "summit": "lookout", "boss": "beast"}
## POI kind -> [a lost thing: m out toward the village, a scout's point: m out, its radius] (others go by the spot's "r")
const POI := {"ruins": [3.5, 0.0, 8.0], "lookout": [4.5, 0.0, 5.0], "camp": [17.0, 26.0, 9.0], "lair": [16.0, 22.0, 8.0], "beast": [30.0, 34.0, 10.0]}
const Shops := preload("res://scripts/game/shops.gd")
## A quest's items: [id, n] (a third entry: one more per tier).
const REWARD_ITEMS := [["tonic", 1, true], ["rum", 3], ["treasure", 1, true], ["stew", 2], ["biscuit", 4], ["pearl", 1, true], ["pepper", 3],
	["rice", 4], ["coconut", 3], ["oyster", 2, true], ["salt", 4]]
## A taught recipe a quest can pay with.
const REWARD_RECIPES := ["captains_feast"]
## What a favour called in gives.
const FAVOUR_GIFTS := [["tonic", 2], ["stew", 3], ["rum", 4], ["treasure", 2], ["fish", 5], ["pearl", 2], ["pepper", 4], ["sea_urchin", 3]]
const FAVOUR_ASK := "I've come to call in that favour."
## What one says as they repay it (a line each, dealt).
const FAVOUR_THANKS := ["A promise is a promise, Captain. Here.", "Now we're square. Don't make a habit of it.", "I pay my debts. Slowly, but I pay them.",
	"Take it before I change my mind. I won't. But take it.", "My mother said never owe a pirate. Here, we're even.", "Good timing. I was starting to forget I owed you.",
	"Call it thanks twice over. Now off with you.", "Favour for a favour. That's how the sea keeps turning."]

var isl: GenIsland
var pools: Dictionary
## {"name", "look", "voice", "role", "pref", "wpick", "named", "eve", "owl", "jit"} (+ "hub", "work", "stays", "walks" once placed)
var folk: Array = []
## Every quest kind in the order tried: {"kind", "pick", "pick2"}; the first `quest_count` the island can give are given.
var quests: Array = []
var quest_count := 0
var spots: Array = []
var hubs: Array = []
## The folk placed (all of them, or none on an island without a village) and the quests given.
var placed: Array = []
var given: Array = []
var people: Array = []
var quest_node: KitQuests
## The island's lines, dealt so no two people say the same one (IslandVillage's people deal from it first).
var deck: LineDeck
## The notice board's quests (IslandVillage.jobs posted, each by the elder or a named character).
var notices: Array = []
## The island's encounters and events as rolled in plan (IslandEncounters.roll), the node that builds them, and
## the quests found in the world that a named character is the one to receive (a dead man's note).
var encounter_kinds: Array = []
var encounters: IslandEncounters
var found: Array = []
## The island's story arc (IslandArcs: planned here, made in the life step) and what plan worked out for it.
var arc: IslandArcs
var arc_plan := {}
var _blockers: Array = []
var _made := 0
var _enc_done := 0
var _enc_style: Dictionary


static func plan(gi: GenIsland) -> IslandLife:
	var t0 := Time.get_ticks_usec()
	var L := IslandLife.new()
	L.isl = gi
	L.pools = LifePools.of(gi.theme)
	L.deck = LineDeck.new(hash([int(gi.node["seed"]), 5104]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(gi.node["seed"]), 5101])
	var names := _shuffled(L.pools["first"], rng)
	var roles := _shuffled(L.pools["roles"].keys(), rng)
	for i in range(NAMED):
		var r: Dictionary = L.pools["roles"][roles[i]]
		L.folk.append(L._person(rng, "%s %s" % [r["title"], names[i]], roles[i], str(r["work"]), true))
	for i in range(rng.randi_range(AMBIENT[0], AMBIENT[1])):
		L.folk.append(L._person(rng, names[NAMED + i], "", JOBS[rng.randi() % JOBS.size()], false))
	# the village's traders (VillageVendors, 1.23): named folk with a market spot and a shop, on a stream of their own
	var vrng := RandomNumberGenerator.new()
	vrng.seed = hash([int(gi.node["seed"]), 5108])
	var used := L.folk.map(func(f): return str(f["name"]).get_slice(" ", str(f["name"]).get_slice_count(" ") - 1))
	for t in VillageVendors.roll(int(gi.node["seed"]), IslandContent.tier(gi)):
		var nm: String = names[vrng.randi() % names.size()]
		for k in range(8):
			if not used.has(nm):
				break
			nm = names[vrng.randi() % names.size()]
		used.append(nm)
		var f := L._person(vrng, "%s %s" % [VillageVendors.TRADES[t]["title"], nm], "vendor:" + str(t), "market", true)
		# (a trader keeps their stall: _routine)
		L.folk.append(f)
	for k in _shuffled(KitQuests.KINDS, rng):
		L.quests.append({"kind": k, "pick": rng.randf(), "pick2": rng.randf()})
	L.quest_count = rng.randi_range(2, 3)
	L.encounter_kinds = IslandEncounters.roll(int(gi.node["seed"]), gi.theme)
	L.arc_plan = IslandArcs.plan(gi)
	L._enc_style = KitStyle.get_style(gi.theme)
	for lk in L.folk.map(func(f): return f["look"]) + IslandEncounters.people_looks(L.encounter_kinds, gi.theme):
		var h := Humanoid.new()
		h.setup(lk)
		Humanoid.stock(h, lk)
	gi.build_ms["bodies"] += int((Time.get_ticks_usec() - t0) / 1000)
	return L


static func _shuffled(a: Array, rng: RandomNumberGenerator) -> Array:
	var out := a.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out


static func _cap(s: String) -> String:
	return s[0].to_upper() + s.substr(1)


func _person(rng: RandomNumberGenerator, who: String, role: String, pref: String, named: bool) -> Dictionary:
	var lk := IslandVillage._villager_look(rng)
	if role == "storyteller":
		lk.merge({"marks": "age_lines", "hair_color": CharacterLook.HAIR_COLORS[8]}, true)
	lk["name"] = who
	var jit: Array = []
	for k in range(5):
		jit.append(rng.randf_range(-0.5, 0.5))
	# (1.26: evenings spread over the inn, the plaza and home; every named villager used to fill the tavern)
	var ev := rng.randf()
	return {"name": who, "look": lk, "voice": rng.randf_range(0.82, 1.2), "role": role, "pref": pref, "wpick": rng.randf(), "named": named,
		"eve": "inn" if ev < 0.35 else ("plaza" if ev < 0.7 else "home"), "owl": named or rng.randf() < 0.2, "jit": jit}


## The island's own name for something of its life in the save: its id and its seed (ids repeat across chain seeds).
func key(what: String) -> String:
	return "isle%d_%d_%s" % [int(isl.node["id"]), int(isl.node["seed"]), what]


func _notification(what: int) -> void:
	# (let go before its people were made: the bodies plan built for them would wait forever)
	if what == NOTIFICATION_PREDELETE:
		for i in range(_made, folk.size()):
			Humanoid.unstock(folk[i]["look"])
		for i in range(_enc_done, encounter_kinds.size()):
			IslandEncounters.unstock_rest(encounter_kinds[i], _enc_style)
		for lk in arc_plan.get("looks", []):
			Humanoid.unstock(lk)


func steps() -> Array:
	var out: Array = [["life", _setup]]
	for i in range(0, folk.size(), PER_STEP):
		out.append(["life", _spawn.bind(i)])
	if not encounter_kinds.is_empty():
		out.append(["encounters", _encounters_start])
		for i in range(encounter_kinds.size()):
			out.append(["encounters", _encounter.bind(i)])
	return out


## The encounters' node (none on an island without people: nobody to meet there but the wild).
func _encounters_start() -> void:
	if placed.is_empty():
		_enc_done = encounter_kinds.size()
		for e in encounter_kinds:
			IslandEncounters.unstock_rest(e, _enc_style)
		return
	encounters = IslandEncounters.new()
	encounters.setup(self, encounter_kinds)
	isl.add_child(encounters)


func _encounter(i: int) -> void:
	if encounters:
		_enc_done = i + 1
		encounters.build(encounters.rolled[i])


# --------------------------------------------------------------------------
# Spots, routines, talk and quests (one step)
# --------------------------------------------------------------------------
func _setup() -> void:
	_gather()
	arrange()
	if placed.is_empty():
		for f in folk:
			Humanoid.unstock(f["look"])
		_made = folk.size()
		for lk in arc_plan.get("looks", []):
			Humanoid.unstock(lk)
		arc_plan = {}
		return
	quest_node = KitQuests.new()
	quest_node.name = "Quests"
	isl.add_child(quest_node)
	for q in given:
		quest_node.add(q, isl)
	var v := isl.get_node_or_null("Site_village/Village") as IslandVillage
	arc = IslandArcs.make(self, v)
	if v:
		_post(v)
	for i in placed:
		_own_lines(i)
	for i in placed:
		var f: Dictionary = folk[i]
		if f["named"]:
			_define_talk(i)
		else:
			f["barks"] = _barks(i)
	if v:
		v.define_talk(notices, quest_node)


## The village's jobs as notices on its board: the bounty posted by the elder, the lair and the beast by the
## elder or a named character (seeded), each turned in to whoever posted it.
func _post(v: IslandVillage) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), 5105])
	var named := placed.filter(func(i): return folk[i]["named"])
	var N: Dictionary = pools["notices"]
	var k := 0
	for job in KitQuests.NOTICES.keys():
		if not v.jobs.has(job):
			continue
		var kind: String = KitQuests.NOTICES[job]
		var j: Dictionary = v.jobs[job]
		var by := v.elder_name if job == "camp" or rng.randf() < 0.35 else str(folk[named[rng.randi() % named.size()]]["name"])
		var nm: String = _site_name("boss") if job == "beast" else str(j["name"])
		var tok := {"name": nm, "poster": by}
		var q := {"id": key("notice_" + kind), "kind": kind, "giver": by, "isle": isl.island_name, "pos": isl.position, "src": "board",
			"title": _cap(LifePools.fill(KitQuests.NOTICE_TITLE[kind], tok)), "clear": j["check"], "poi_at": j["at"],
			"notice": LifePools.fill(deck.one("notice_" + kind, N[kind]), tok), "posted": deck.one("posted", N["posted"]), "steps": [],
			"favour_ask": FAVOUR_ASK}
		q["reward"] = _reward(q, 100 + k)
		q["favour_thanks"] = deck.deal("favour", FAVOUR_THANKS, 1) if q["reward"].has("favour") else []
		for s in KitQuests.STEPS[kind]:
			q["steps"].append({"do": s[0], "goal": _cap(LifePools.fill(s[1], tok))})
		q["steps"][0]["said"] = "%s: done. Report to %s." % [q["title"], by]
		quest_node.add(q, isl)
		notices.append(q)
		k += 1


## A placed person's own lines from the island's deck: one for the day, the evening and the night, one for
## each kind of place their day takes them, one pointing at someone with work (and a named one's small talk).
func _own_lines(i: int) -> void:
	var f: Dictionary = folk[i]
	var b: Dictionary = pools["barks"]
	var own := {}
	for t in ["day", "evening", "night"]:
		own[t] = deck.deal(t, b[t], 1)
	for st in f["stays"]:
		var kind: String = st["kind"]
		if not own.has(kind) and b.has(kind):
			own[kind] = deck.deal(kind, b[kind], 1)
	var givers := given.filter(func(q): return folk[q["giver_i"]] != f)
	own["pointer"] = []
	if not givers.is_empty():
		var g: Dictionary = folk[givers[i % givers.size()]["giver_i"]]
		own["pointer"] = deck.deal("pointer", b["pointer"], 1).map(func(l): return LifePools.fill(l, {"who": g["name"], "where": _where(g)}))
	if f["named"]:
		var role: Dictionary = _role(f)
		own["talk"] = deck.deal("role_" + str(f["role"]), role["talk"], 3)
		own["menu"] = deck.one("menu", pools["menu"])
		own["quiet"] = deck.one("quiet", pools["rumour_quiet"])
	# (the island's arc: a word of it from every third face in the crowd)
	if arc and not f["named"] and i % 3 == 0:
		own["day"] = own["day"] + deck.deal("arc", arc.rumours(), 1)
	f["own"] = own
	if f["named"]:
		_rumours(f)


## Routines and quests from `spots` (data: no node is made).
func arrange() -> void:
	hubs = []
	for s in spots:
		if not s.get("poi", false) and not hubs.has(s["hub"]):
			hubs.append(s["hub"])
	placed = []
	given = []
	if hubs.is_empty():
		return
	for i in range(folk.size()):
		_routine(i)
		placed.append(i)
		if folk[i]["named"]:
			folk[i]["talk"] = key("talk%d" % i)
	for qi in range(quests.size()):
		if given.size() >= quest_count:
			break
		var q := _quest(qi)
		if not q.is_empty():
			given.append(q)


func _gather() -> void:
	var v := isl.get_node_or_null("Site_village/Village") as IslandVillage
	_blockers = v.taken if v else []
	var fed_village := isl.life_spots.any(func(s): return not s.get("poi", false))
	var fed := {}
	for s in isl.life_spots:
		fed[s["kind"]] = true
	var mine: Array = _village_spots(v) if v and not fed_village else []
	for site in SITE_KIND.keys():
		if isl.sites.has(site) and not fed.has(SITE_KIND[site]):
			mine.append({"kind": SITE_KIND[site], "at": isl.sites[site], "poi": true, "name": _site_name(site)})
	spots = mine + isl.life_spots
	for i in range(spots.size()):
		var s: Dictionary = spots[i]
		s["idx"] = i
		if not s.get("poi", false) and not s.has("lane"):
			s["lane"] = KitLife.lane_in(s["hub"], s["at"], _blockers)


## What the village gives (IslandVillage's layout data): a plaza at its heart and at each hamlet's fire, its work
## spots (rooms and decks keep their floor's y), its benches, the inn, the houses' doors, the harbour's work
## (GenHarbour.spots), the paths out. Each spot's hub is the nearest hamlet's (or the heart's).
func _village_spots(v: IslandVillage) -> Array:
	var c: Vector2 = v.plaza["c"]
	var to_dock: Vector2 = (isl.sites["dock"] - c).normalized()
	var out: Array = [_at_y({"kind": "plaza", "at": c, "face": to_dock}, v.plaza["y"])]
	var hubs_at: Array = [c]
	for h in v.hamlets:
		if not hubs_at.has(h["c"]):
			hubs_at.append(h["c"])
			out.append({"kind": "plaza", "at": h["c"], "face": to_dock})
	for s in v.work_spots:
		if not s["taken"] and VILLAGE_KIND.has(s["kind"]):
			out.append(_at_y({"kind": VILLAGE_KIND[s["kind"]], "at": s["at"], "face": s["face"]}, s["y"]))
	for s in v.seats:
		var f: Vector2 = s["face"]
		out.append(_at_y({"kind": "bench", "at": s["at"] + f * 0.9, "face": -f}, s["y"]))
	for b in v.buildings:
		var f: Vector2 = b["face"]
		match str(b["kind"]):
			"inn":
				if b.has("floor_y"):
					# (raised: they gather on the deck by the walkway over)
					var dk: Dictionary = v.decks[0]
					out.append({"kind": "inn", "at": dk["c"] + (b["door"] - dk["c"]).normalized() * (float(dk["r"]) - 2.5), "face": f, "y": dk["y"]})
				else:
					out.append({"kind": "inn", "at": b["door"] + f * 1.5, "face": f})
			"hut", "tall":
				out.append(_at_y({"kind": "home", "at": b["door"], "face": -f}, b.get("floor_y", INF)))
	# the harbour's work on dry land (its decks are walked by no one yet: walk_height doesn't know them)
	for e in isl.harbour.spots:
		var p: Vector2 = e[0]
		if isl.hv(p) > 0.6:
			out.append({"kind": HARBOUR_KIND.get(e[2], "dock"), "at": p, "face": e[1], "lane": KitLife.lane_along(c, p, isl.paths[0], 14.0, _blockers)})
	for site in ["ruins", "summit"]:
		var path := _path_to(isl.sites[site])
		var cum := KitLife.measure(path)
		for dist in [38.0, 55.0]:
			var smp := KitLife.sample(path, cum, dist)
			var off := Vector2(-smp[1].y, smp[1].x)
			var p: Vector2 = smp[0] + off * 3.0
			out.append({"kind": "forage", "at": p, "face": -off, "lane": KitLife.lane_along(c, p, path, 14.0, _blockers)})
	for s in out:
		var hub: Vector2 = c
		for h in hubs_at:
			if (s["at"] as Vector2).distance_to(h) < (s["at"] as Vector2).distance_to(hub):
				hub = h
		s["hub"] = hub
	return out


## A spot with its floor's height (INF: on the ground, no "y").
static func _at_y(s: Dictionary, y: float) -> Dictionary:
	if y != INF:
		s["y"] = y
	return s


func _site_name(site: String) -> String:
	match site:
		"camp":
			return isl.get_node("Site_camp/Camp").specs.filter(func(s): return s.get("captain", false))[0]["title"]
		"boss":
			return isl.get_node("Site_boss/Arena").boss.boss_name
		"lair":
			return "the bug burrows"
		"ruins":
			return "the old stones"
	return "the lookout on the summit"


## The village's path out to `to` (the one ending nearest it).
func _path_to(to: Vector2) -> PackedVector2Array:
	var best: PackedVector2Array = isl.paths[0]
	for p in isl.paths:
		if (p as PackedVector2Array)[p.size() - 1].distance_to(to) < best[best.size() - 1].distance_to(to):
			best = p
	return best


## The first of `kinds` hamlet `hub` has (the i-th of them), else any of its spots.
func _spot(hub: Vector2, kinds: Array, i: int) -> Dictionary:
	var mine := spots.filter(func(s): return not s.get("poi", false) and s["hub"] == hub)
	for k in kinds:
		var list := mine.filter(func(s): return s["kind"] == k)
		if not list.is_empty():
			return list[i % list.size()]
	return mine[i % mine.size()]


func _has(hub: Vector2, kind: String) -> bool:
	return spots.any(func(s): return not s.get("poi", false) and s["hub"] == hub and s["kind"] == kind)


## Their own work if the hamlet has it, else one of the work it has (seeded).
func _work_kind(f: Dictionary, hub: Vector2) -> String:
	if _has(hub, f["pref"]):
		return f["pref"]
	var work: Array = []
	for s in spots:
		if not s.get("poi", false) and s["hub"] == hub and not s["kind"] in ["plaza", "inn", "home", "bench"] and not work.has(s["kind"]):
			work.append(s["kind"])
	return work[int(f["wpick"] * work.size())] if not work.is_empty() else "plaza"


## Where someone stands at spot s: round a group's middle, or along the spot's side.
func _slot(s: Dictionary) -> Array:
	var n: int = s.get("users", 0)
	s["users"] = n + 1
	var face: Vector2 = s["face"]
	if GROUP.has(s["kind"]):
		var at: Vector2 = s["at"] + Vector2.from_angle(face.angle() + PI + n * 2.4) * (float(GROUP[s["kind"]]) + float(n / 6) * 0.9)
		return [at, (s["at"] - at).normalized()]
	return [s["at"] + Vector2(-face.y, face.x) * float((n % 3) - 1) * 1.1 * (1 + n / 3), face]


func _routine(i: int) -> void:
	var f: Dictionary = folk[i]
	var j: Array = f["jit"]
	var hub: Vector2 = hubs[i % hubs.size()]
	var work := _spot(hub, [_work_kind(f, hub), "plaza"], i)
	var plan := [[5.9 + j[0], work, ACT.get(work["kind"], "stand")],
		[12.0 + j[1] * 0.6, _spot(hub, ["bench", "plaza", "market"] if i % 2 == 0 else ["market", "plaza"], i), "talk"],
		[13.4 + j[2] * 0.6, work, ACT.get(work["kind"], "stand")], [18.0 + j[3], _spot(hub, [f["eve"], "inn", "plaza"], i), "talk"]]
	if not f["owl"] and _has(hub, "home"):
		plan.append([22.2 + j[4] * 1.5, _spot(hub, ["home"], i), "home"])
	# (1.26, docs/v1_26_plan.md "Shops and vendors": the playtest never found a trader where they should be) a trader
	# keeps their stall day and night: one stay, no walks
	if str(f["role"]).begins_with("vendor:"):
		plan = [[0.0, work, ACT.get(work["kind"], "stand")]]
	var slots := {}
	var stays: Array = []
	var lanes: Array = []
	for e in plan:
		var s: Dictionary = e[1]
		if not slots.has(s["idx"]):
			slots[s["idx"]] = _slot(s)
		var sl: Array = slots[s["idx"]]
		var st := {"h": e[0], "kind": s["kind"], "at": sl[0], "face": sl[1], "act": e[2]}
		if s.has("y"):
			st["y"] = s["y"]
		stays.append(st)
		lanes.append(PackedVector2Array([sl[0]]) + s["lane"])
	var walks: Array = []
	for k in range(stays.size()):
		walks.append(KitLife.walk(hub, lanes[k - 1], lanes[k]))
	if str(f["role"]).begins_with("vendor:"):
		walks = [PackedVector2Array([stays[0]["at"]])]
	f["hub"] = hub
	f["work"] = work["kind"]
	f["stays"] = stays
	f["walks"] = walks


## A named person's role table: the theme's (pools.roles), or a trader's (VillageVendors).
func _role(f: Dictionary) -> Dictionary:
	var r := str(f["role"])
	return VillageVendors.role(r.substr(7)) if r.begins_with("vendor:") else pools["roles"][r]


func _short(f: Dictionary) -> String:
	var parts := str(f["name"]).split(" ")
	return parts[parts.size() - 1]


func _where(f: Dictionary) -> String:
	return str(pools["where"].get(f["work"], pools["where_else"]))


func _fill_all(lines: Array, tok: Dictionary) -> Array:
	return lines.map(func(l): return LifePools.fill(str(l), tok))


func _pois() -> Array:
	return spots.filter(func(s): return s.get("poi", false))


func _define_talk(i: int) -> void:
	var f: Dictionary = folk[i]
	var role: Dictionary = _role(f)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), 5102, i])
	var tok := {"name": _short(f)}
	var own: Dictionary = f["own"]
	var heard: Array = own["heard"]
	var ahead: Array = own["ahead"]
	var menu: Array = [{"text": pools["rumour_menu"][0], "next": "isle"}, {"text": pools["rumour_menu"][1], "next": "ahead"},
		{"text": pools["self_menu"], "next": "self"}, {"text": pools["work_menu"], "next": "work"}]
	var nodes := {
		"intro": {"text": _fill_all(role["intro"], tok), "next": "menu"},
		"menu": {"text": own["menu"], "choices": menu},
		"isle": {"text": heard if not heard.is_empty() else [own["quiet"]], "next": "menu"},
		"ahead": {"text": ahead if not ahead.is_empty() else [own["quiet"]], "next": "menu"},
		"self": {"text": _fill_all(role["self"], tok), "next": "menu"},
		"work": {"text": own["talk"], "next": "menu"},
	}
	# a trader: their wares first on the menu (VillageVendors; the shop is theirs, the same on every machine)
	var r := str(f["role"])
	if r.begins_with("vendor:"):
		var sid := key("shop%d" % i)
		Shops.extra[sid] = VillageVendors.shop(r.substr(7), _short(f))
		nodes["trade"] = {"text": [str(Shops.extra[sid]["line"])], "event": "shop:" + sid, "next": "end"}
		menu.insert(0, {"text": "Show me your wares.", "next": "trade"})
	for k in [["isle", heard], ["ahead", ahead]]:
		if not (k[1] as Array).is_empty():
			nodes[k[0]]["event"] = "rumour:%s_%s" % [f["talk"], k[0]]
			Journal.tell("%s_%s" % [f["talk"], k[0]], k[1], f["name"], isl.island_name)
	for q in given:
		if q["giver_i"] == i:
			quest_node.offer(q, menu, nodes)
		if q.get("recipient_i", -1) == i:
			quest_node.hand_over(q, menu, nodes)
	for q in notices:
		if q["giver"] == f["name"]:
			quest_node.report(q, menu, nodes)
	for q in found:
		if q["giver"] == f["name"]:
			quest_node.receive(q, menu, nodes)
	menu.append({"text": pools["bye"], "next": "end"})
	Dialogue.define(f["talk"], {"speaker": f["name"], "voice": f["voice"], "start": "intro", "return": "menu", "nodes": nodes})


## Everything that could be said of the islands the log pose points at from here (dealt out, a line each).
func _ahead_lines() -> Array:
	var c: Chain = isl.get_tree().get_first_node_in_group("world_gen").chain()
	var ahead: Array = c.next_of(int(isl.node["id"])).map(func(id): return c.node(id))
	if ahead.is_empty():
		return [pools["rumour_end"]]
	var out: Array = []
	if ahead.size() > 1:
		out.append(LifePools.fill(pools["rumour_fork"], {"a": ahead[0]["name"], "b": ahead[1]["name"]}))
	for n in ahead:
		for l in pools["rumour_chain"]:
			out.append(LifePools.fill(l, {"name": n["name"], "blurb": _cap(IslandThemes.of(n["theme"]).blurb)}))
	return out


## The rumours a named character tells: up to two of the island's (by its POIs) and one or two of the way
## ahead, none that anyone else on the island tells.
func _rumours(f: Dictionary) -> void:
	var own: Dictionary = f["own"]
	var told: Dictionary = pools["rumour_isle"]
	var isle: Array = []
	for poi in _pois():
		isle.append_array(_fill_all(told.get(poi["kind"], told["any"]), {"name": poi["name"]}))
	own["heard"] = (deck.deal("arc", arc.rumours(), 1) if arc else []) + deck.deal("rumour_isle", isle, 2)
	own["ahead"] = deck.deal("rumour_ahead", _ahead_lines(), 1)
	if not own["ahead"].is_empty() and not deck.used(pools["rumour_hard"]):
		own["ahead"].append_array(deck.deal("rumour_hard", [pools["rumour_hard"]], 1))


## An ordinary villager's lines when talked to: their own day line, their work's, and who has a problem.
func _barks(i: int) -> Array:
	var own: Dictionary = folk[i]["own"]
	return own["day"] + own.get(folk[i]["work"], own["evening"]) + own["pointer"]


## Quest qi of the plan as the island can give it ({} if it can't: no POI to send you to, no one to deliver to).
func _quest(qi: int) -> Dictionary:
	var pl: Dictionary = quests[qi]
	var kind: String = pl["kind"]
	var named := placed.filter(func(i): return folk[i]["named"])
	var pois := _pois().filter(func(s): return s.has("clear")) if kind == "clear" else _pois()
	if named.is_empty() or (kind in ["lost", "scout", "clear"] and pois.is_empty()) or (kind == "deliver" and named.size() < 2):
		return {}
	var gi: int = named[given.size() % named.size()]
	var T: Dictionary = pools["quests"][kind]
	var q := {"id": key("q%d" % qi), "kind": kind, "giver_i": gi, "giver": folk[gi]["name"], "isle": isl.island_name, "pos": isl.position, "src": "npc",
		"accept": pools["accept"], "decline": pools["decline"], "taken": deck.one("taken", pools["taken"])}
	q["reward"] = _reward(q, qi)
	var tok := {"who": _short(folk[gi])}
	var poi: Dictionary = pois[int(pl["pick"] * pois.size())] if not pois.is_empty() else {}
	var at: Vector2 = poi.get("at", Vector2.ZERO)
	var away: Vector2 = (folk[gi]["hub"] - at).normalized()
	var r: Array = POI.get(poi.get("kind", ""), [float(poi.get("r", 6.0)) * 0.5 + 2.0, 0.0, float(poi.get("r", 6.0)) + 6.0])
	match kind:
		"lost":
			var item: Array = T["items"][int(pl["pick2"] * T["items"].size())]
			tok.merge({"item": item[0], "thing": item[1], "place": LifePools.fill(pools["lost_at"].get(poi["kind"], pools["lost_at"]["any"]), poi)})
			q["at"] = at + away.rotated(pl["pick2"] * 1.2 - 0.6) * float(r[0])
			q["yaw"] = pl["pick"] * TAU
		"scout":
			var sc: Dictionary = pools["scout_at"].get(poi["kind"], pools["scout_at"]["any"])
			var look := LifePools.fill(sc["look"], poi)
			q["at"] = at + away * float(r[1])
			q["y"] = isl.hv(q["at"]) + (7.0 if poi["kind"] == "lookout" else 1.0)
			q["r"] = r[2]
			q["title"] = _cap(LifePools.fill(sc["title"], poi))
			tok.merge({"look": look, "Look": q["title"]})
			q["plea"] = [look + "."]
			q["found"] = LifePools.fill(LifePools.fill(sc["seen"], poi), tok)
		"deliver":
			var ri: int = named[(named.find(gi) + 1) % named.size()]
			q["recipient_i"] = ri
			q["recipient"] = folk[ri]["name"]
			tok.merge({"recipient": _short(folk[ri]), "where": _where(folk[ri]), "parcel": T["parcels"][int(pl["pick2"] * T["parcels"].size())]})
		"fetch":
			var want: Dictionary = T["wants"][int(pl["pick2"] * T["wants"].size())]
			q["cost"] = [[want["item"], int(want["count"])]]
			q["plea"] = want["plea"]
			tok.merge({"what": want["what"], "What": _cap(want["what"])})
		"clear":
			var verb: String = poi.get("verb", "Clear")
			tok.merge({"name": poi["name"], "verb": verb.to_lower(), "Verb": verb})
			q["clear"] = poi["clear"]
			q["poi_at"] = at
	for k in ["title", "ask", "plea", "remind_choice", "remind", "search", "found", "done", "thanks", "hand", "got", "short"]:
		if not T.has(k) or q.has(k):
			continue
		q[k] = _fill_all(T[k], tok) if T[k] is Array else _cap(LifePools.fill(T[k], tok))
	q["favour_ask"] = FAVOUR_ASK
	q["favour_thanks"] = deck.deal("favour", FAVOUR_THANKS, 1) if q["reward"].has("favour") else []
	q["steps"] = []
	for s in KitQuests.STEPS[kind]:
		var st := {"do": s[0], "goal": _cap(LifePools.fill(s[1], tok))}
		if s[0] == "talk":
			st["who"] = q["recipient"]
		if s[0] != "turnin":
			st["said"] = q["found"]
		q["steps"].append(st)
	return q


## What quest qi pays (its own stream: the plan's draws stay as they were): gold by the island's tier, and
## often something else instead of some of it: things to eat, cook, drink or sell, a treasure map, a hidden
## place on the island marked on the map, a recipe, a discount at the island's trader, a favour the giver owes.
func _reward(q: Dictionary, qi: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), 5103, qi])
	var t := IslandContent.tier(isl)
	var gold: Array = KitQuests.GOLD[q["kind"]]
	var g := int(gold[0]) + t * int(gold[1])
	var shop := isl.save_key("trader")
	var r := {"gold": g}
	match rng.randi() % 8:
		0:
			var e: Array = REWARD_ITEMS[rng.randi() % REWARD_ITEMS.size()]
			r = {"gold": roundi(g * 0.6), "items": [[e[0], int(e[1]) + (t if e.size() > 2 else 0)]]}
		1:
			r = {"gold": roundi(g * 0.5), "reveal": true}
		2:
			if Shops.extra.has(shop):
				r = {"gold": roundi(g * 0.6), "discount": [shop, 0.1 + 0.05 * (rng.randi() % 2), str(Shops.extra[shop]["name"])]}
		3:
			r = {"gold": roundi(g * 0.6), "favour": {"who": _short({"name": q["giver"]}), "gift": [FAVOUR_GIFTS[rng.randi() % FAVOUR_GIFTS.size()]]}}
		4:
			r = {"gold": roundi(g * 0.6), "chart": true}
		5:
			r = {"gold": roundi(g * 0.4), "recipe": REWARD_RECIPES[rng.randi() % REWARD_RECIPES.size()]}
	return r


## One more quest of `kind` (given and told to its giver): a POI built later, and tests.
func add_quest(kind: String, pick: float, pick2: float) -> Dictionary:
	quests.append({"kind": kind, "pick": pick, "pick2": pick2})
	var q := _quest(quests.size() - 1)
	given.append(q)
	quest_node.add(q, isl)
	for i in [int(q["giver_i"]), int(q.get("recipient_i", q["giver_i"]))]:
		_define_talk(i)
	return q


# --------------------------------------------------------------------------
# The people (PER_STEP a step: bodies built on the worker, the rest here)
# --------------------------------------------------------------------------
func _spawn(i0: int) -> void:
	for i in range(i0, mini(i0 + PER_STEP, folk.size())):
		if not placed.has(i):
			continue
		var f: Dictionary = folk[i]
		var cfg := {"name": f["name"], "voice": f["voice"], "look": f["look"]}
		if f["named"]:
			cfg["dialogue"] = f["talk"]
		else:
			cfg["barks"] = f["barks"]
			# (1.23: the crowd is scenery: their lines over their heads, no talk prompt)
			cfg["scenery"] = true
		var v := Villager.new()
		v.setup(cfg)
		v.follow(isl, f["stays"], f["walks"], _ambient(f))
		isl.add_child(v)
		people.append(v)
		_made = i + 1


## What they say over their heads: their own lines (_own_lines), by the time of day and the kind of place.
func _ambient(f: Dictionary) -> Dictionary:
	var own: Dictionary = f["own"]
	var out := {"day": own["day"] + own["pointer"] + own.get("talk", []).slice(0, 1), "evening": own["evening"], "night": own["night"]}
	for k in own.keys():
		if not k in ["day", "evening", "night", "pointer", "talk", "menu", "quiet", "heard", "ahead"]:
			out[k] = own[k]
	return out
