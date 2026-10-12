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

const AMBIENT := [8, 10]
const NAMED := 3
const PER_STEP := 4
const JOBS := ["nets", "forage", "market", "home", "plaza"]
const ACT := {"nets": "kneel", "forage": "kneel", "home": "kneel", "field": "kneel", "market": "talk", "plaza": "talk", "inn": "talk", "well": "talk"}
## People at these stand round the spot this far out, facing in.
const GROUP := {"plaza": 3.8, "inn": 1.9, "well": 2.2}
const SITE_KIND := {"camp": "camp", "lair": "lair", "ruins": "ruins", "summit": "lookout", "boss": "beast"}
## POI kind -> [a lost thing: m out toward the village, a scout's point: m out, its radius] (others go by the spot's "r")
const POI := {"ruins": [3.5, 0.0, 8.0], "lookout": [4.5, 0.0, 5.0], "camp": [17.0, 26.0, 9.0], "lair": [16.0, 22.0, 8.0], "beast": [30.0, 34.0, 10.0]}

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
var _blockers: Array = []
var _made := 0


static func plan(gi: GenIsland) -> IslandLife:
	var t0 := Time.get_ticks_usec()
	var L := IslandLife.new()
	L.isl = gi
	L.pools = LifePools.of(gi.theme)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(gi.node["seed"]), 5101])
	var names := _shuffled(L.pools["first"], rng)
	var roles := _shuffled(L.pools["roles"].keys(), rng)
	for i in range(NAMED):
		var r: Dictionary = L.pools["roles"][roles[i]]
		L.folk.append(L._person(rng, "%s %s" % [r["title"], names[i]], roles[i], str(r["work"]), true))
	for i in range(rng.randi_range(AMBIENT[0], AMBIENT[1])):
		L.folk.append(L._person(rng, names[NAMED + i], "", JOBS[rng.randi() % JOBS.size()], false))
	for k in _shuffled(KitQuests.KINDS, rng):
		L.quests.append({"kind": k, "pick": rng.randf(), "pick2": rng.randf()})
	L.quest_count = rng.randi_range(2, 3)
	for f in L.folk:
		var h := Humanoid.new()
		h.setup(f["look"])
		Humanoid.stock(h, f["look"])
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
	return {"name": who, "look": lk, "voice": rng.randf_range(0.82, 1.2), "role": role, "pref": pref, "wpick": rng.randf(), "named": named,
		"eve": "inn" if named or rng.randf() < 0.6 else "plaza", "owl": named or rng.randf() < 0.2, "jit": jit}


## The island's own name for something of its life in the save: its id and its seed (ids repeat across chain seeds).
func key(what: String) -> String:
	return "isle%d_%d_%s" % [int(isl.node["id"]), int(isl.node["seed"]), what]


func _notification(what: int) -> void:
	# (let go before its people were made: the bodies plan built for them would wait forever)
	if what == NOTIFICATION_PREDELETE:
		for i in range(_made, folk.size()):
			Humanoid.unstock(folk[i]["look"])


func steps() -> Array:
	var out: Array = [["life", _setup]]
	for i in range(0, folk.size(), PER_STEP):
		out.append(["life", _spawn.bind(i)])
	return out


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
		return
	quest_node = KitQuests.new()
	quest_node.name = "Quests"
	isl.add_child(quest_node)
	for q in given:
		quest_node.add(q, isl)
	for i in placed:
		var f: Dictionary = folk[i]
		if f["named"]:
			_define_talk(i)
		else:
			f["barks"] = _barks(i)


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


## What today's IslandVillage gives: its plaza, the stalls' customers, the inn's door, the huts' fronts, the beach by the pier, the paths out.
func _village_spots(v: IslandVillage) -> Array:
	var c: Vector2 = isl.sites["village"]
	var to_dock: Vector2 = (isl.sites["dock"] - c).normalized()
	var out: Array = [{"kind": "plaza", "at": c, "face": to_dock}]
	for n in isl.get_children():
		if n is NPC and n.shop_id != "":
			var f := Vector2(-sin(n._home_yaw), -cos(n._home_yaw))
			out.append({"kind": "market", "at": Vector2(n.position.x, n.position.z) + f * 1.8, "face": -f})
	var door := isl.to_local((isl.get_node("Site_village/Rest") as Node3D).global_position)
	out.append({"kind": "inn", "at": Vector2(door.x, door.z) + to_dock * 3.4, "face": to_dock})
	for h in v.huts:
		var f: Vector2 = (h[2] as Vector2).normalized()
		out.append({"kind": "home", "at": h[1] + f * 4.4, "face": f})
	var dd := isl.dock_dir
	var side := Vector2(-dd.y, dd.x)
	for off in [-8.0, -5.0, 5.0, 8.0]:
		var p: Vector2 = isl.dock_shore - dd * 6.0 + side * off
		if isl.hv(p) > 0.5:
			out.append({"kind": "nets", "at": p, "face": dd, "lane": KitLife.lane_along(c, p, isl.paths[0], 14.0, _blockers)})
	for site in ["ruins", "summit"]:
		var path := _path_to(isl.sites[site])
		var cum := KitLife.measure(path)
		for dist in [38.0, 55.0]:
			var smp := KitLife.sample(path, cum, dist)
			var off := Vector2(-smp[1].y, smp[1].x)
			var p: Vector2 = smp[0] + off * 3.0
			out.append({"kind": "forage", "at": p, "face": -off, "lane": KitLife.lane_along(c, p, path, 14.0, _blockers)})
	for s in out:
		s["hub"] = c
	return out


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
		if not s.get("poi", false) and s["hub"] == hub and not s["kind"] in ["plaza", "inn", "home"] and not work.has(s["kind"]):
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
		[12.0 + j[1] * 0.6, _spot(hub, ["plaza", "market"] if i % 2 == 0 else ["market", "plaza"], i), "talk"],
		[13.4 + j[2] * 0.6, work, ACT.get(work["kind"], "stand")], [18.0 + j[3], _spot(hub, [f["eve"], "inn", "plaza"], i), "talk"]]
	if not f["owl"] and _has(hub, "home"):
		plan.append([22.2 + j[4] * 1.5, _spot(hub, ["home"], i), "home"])
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
	f["hub"] = hub
	f["work"] = work["kind"]
	f["stays"] = stays
	f["walks"] = walks


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
	var role: Dictionary = pools["roles"][f["role"]]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), 5102, i])
	var tok := {"name": _short(f)}
	var heard: Array = []
	var told: Dictionary = pools["rumour_isle"]
	for poi in _pois():
		heard.append_array(_fill_all(told.get(poi["kind"], told["any"]), {"name": poi["name"]}))
	heard = _shuffled(heard, rng).slice(0, 2)
	var menu: Array = [{"text": pools["rumour_menu"][0], "next": "isle"}, {"text": pools["rumour_menu"][1], "next": "ahead"},
		{"text": pools["self_menu"], "next": "self"}]
	var nodes := {
		"intro": {"text": _fill_all(role["intro"], tok), "next": "menu"},
		"menu": {"text": pools["menu"], "choices": menu},
		"isle": {"text": heard if not heard.is_empty() else [pools["rumour_quiet"]], "next": "menu"},
		"ahead": {"text": _ahead(rng), "next": "menu"},
		"self": {"text": _fill_all(role["self"], tok), "next": "menu"},
	}
	for q in given:
		if q["giver_i"] == i:
			quest_node.offer(q, menu, nodes)
		if q.get("recipient_i", -1) == i:
			quest_node.hand_over(q, menu, nodes)
	menu.append({"text": pools["bye"], "next": "end"})
	Dialogue.define(f["talk"], {"speaker": f["name"], "voice": f["voice"], "start": "intro", "return": "menu", "nodes": nodes})


## What they've heard of the islands the log pose points at from here.
func _ahead(rng: RandomNumberGenerator) -> Array:
	var c: Chain = isl.get_tree().get_first_node_in_group("world_gen").chain()
	var ahead: Array = c.next_of(int(isl.node["id"])).map(func(id): return c.node(id))
	if ahead.is_empty():
		return [pools["rumour_end"]]
	if ahead.size() > 1:
		return [LifePools.fill(pools["rumour_fork"], {"a": ahead[0]["name"], "b": ahead[1]["name"]})]
	var n: Dictionary = ahead[0]
	var lines: Array = pools["rumour_chain"]
	var out := [LifePools.fill(lines[rng.randi() % lines.size()], {"name": n["name"], "blurb": _cap(Chain.THEMES[n["theme"]]["blurb"])})]
	if rng.randf() < 0.5:
		out.append(pools["rumour_hard"])
	return out


## An ordinary villager's lines when talked to: the day, their work, and who has a problem.
func _barks(i: int) -> Array:
	var f: Dictionary = folk[i]
	var b: Dictionary = pools["barks"]
	var day: Array = b["day"]
	var out := [day[i % day.size()], day[(i + 3) % day.size()]]
	var work: Array = b.get(f["work"], [])
	if not work.is_empty():
		out[1] = work[i % work.size()]
	if not given.is_empty():
		var g: Dictionary = folk[given[i % given.size()]["giver_i"]]
		var p: Array = b["pointer"]
		out.append(LifePools.fill(p[i % p.size()], {"who": g["name"], "where": _where(g)}))
	return out


## Quest qi of the plan as the island can give it ({} if it can't: no POI to send you to, no one to deliver to).
func _quest(qi: int) -> Dictionary:
	var pl: Dictionary = quests[qi]
	var kind: String = pl["kind"]
	var named := placed.filter(func(i): return folk[i]["named"])
	var pois := _pois().filter(func(s): return s.has("clear")) if kind == "clear" else _pois()
	if named.is_empty() or (kind in ["lost", "scout", "clear"] and pois.is_empty()) or (kind == "deliver" and named.size() < 2):
		return {}
	var gi: int = named[given.size() % named.size()]
	var t := IslandContent.tier(isl)
	var T: Dictionary = pools["quests"][kind]
	var gold: Array = KitQuests.GOLD[kind]
	var q := {"id": key("q%d" % qi), "kind": kind, "giver_i": gi, "gold": int(gold[0]) + t * int(gold[1]),
		"xp": roundi((40 + t * 20) * Levels.xp_k(IslandContent.level(isl))), "accept": pools["accept"], "decline": pools["decline"], "taken": pools["taken"]}
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
			tok.merge({"look": look})
			q["at"] = at + away * float(r[1])
			q["y"] = isl.hv(q["at"]) + (7.0 if poi["kind"] == "lookout" else 1.0)
			q["r"] = r[2]
			q["title"] = _cap(LifePools.fill(sc["title"], poi))
			q["plea"] = [look + "."]
			q["found"] = LifePools.fill(LifePools.fill(sc["seen"], poi), tok)
		"deliver":
			var ri: int = named[(named.find(gi) + 1) % named.size()]
			q["recipient_i"] = ri
			tok.merge({"recipient": _short(folk[ri]), "where": _where(folk[ri]), "parcel": T["parcels"][int(pl["pick2"] * T["parcels"].size())]})
		"fetch":
			var want: Dictionary = T["wants"][int(pl["pick2"] * T["wants"].size())]
			q["item"] = want["item"]
			q["count"] = want["count"]
			q["plea"] = want["plea"]
			tok.merge({"what": want["what"], "What": _cap(want["what"])})
		"clear":
			var verb: String = poi.get("verb", "Clear")
			tok.merge({"name": poi["name"], "verb": verb.to_lower(), "Verb": verb})
			q["clear"] = poi["clear"]
	for k in ["title", "ask", "plea", "remind_choice", "remind", "search", "found", "done", "thanks", "hand", "got", "short"]:
		if not T.has(k) or q.has(k):
			continue
		q[k] = _fill_all(T[k], tok) if T[k] is Array else _cap(LifePools.fill(T[k], tok))
	return q


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
		var v := Villager.new()
		v.setup(cfg)
		v.follow(isl, f["stays"], f["walks"], _ambient(f))
		isl.add_child(v)
		people.append(v)
		_made = i + 1


func _ambient(f: Dictionary) -> Dictionary:
	var b: Dictionary = pools["barks"]
	var out := {"day": b["day"].duplicate(), "evening": b["evening"], "night": b["night"]}
	for k in b.keys():
		if not k in ["day", "evening", "night", "pointer"]:
			out[k] = b[k]
	for q in given:
		var g: Dictionary = folk[q["giver_i"]]
		if g != f:
			out["day"].append(LifePools.fill(b["pointer"][0], {"who": g["name"], "where": _where(g)}))
	return out
