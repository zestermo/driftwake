class_name IslandEncounters
extends Node3D
## A generated island's encounters and events (the island's "Encounters" node): who you might meet there
## besides its villagers, rolled from the island's seed and its theme's pool (ThemeDef.encounters: each kind's
## weight and its people's text). 0-3 of them, never a kind twice, nothing guaranteed. Kinds: a traveller by a
## trail (rumours, a gift), an ambush (bandits in the brush), a festival at the village in the evening (a feast to
## help with), a shipwreck on a beach (a survivor's lost chest), a merchant robbed on the road (the strongbox at
## the pirates' camp), a lost child (found at a wild place, sent home to the parent), a hermit out at a wild place
## (go and look somewhere for them), a wounded hunter by a trail (a tonic), a dead man's note (a keepsake for a
## villager: things you find), a duelist (beat him, he pays). Their quests are the crew's (Journal, KitQuests),
## turned in to whoever gave them. Rolled in IslandLife.plan (`roll`, data), built after the people (a step each).
## Guests roll and build the same; the ambush's and the duel's crews are GruntCamps (the host runs them).

const KINDS := ["traveller", "ambush", "festival", "shipwreck", "merchant", "lost_child", "hermit", "wounded", "note", "duelist"]
## How many an island has: 0, 1, 2, 3 or 4 (chances; 1.20: more people between places, about 2.2 an island, was 1.4).
const COUNT := [0.05, 0.2, 0.35, 0.28, 0.12]
## Where each kind goes: beside a trail out of the village, on a beach, at the village's plaza, at a wild place.
const WHERE := {"traveller": "trail", "ambush": "trail", "festival": "village", "shipwreck": "beach", "merchant": "trail",
	"lost_child": "village", "hermit": "poi", "wounded": "trail", "note": "trail", "duelist": "trail"}
## A captain this close springs an ambush (m).
const SPRING := 13.0
const TICK := 0.5
const BUBBLE_R := 26.0
## What a traveller can spare, once per captain.
const GIFTS := [["tonic", 1], ["biscuit", 3], ["stew", 1], ["rum", 2], ["jungle_fruit", 3]]
## The gift their line names (the first word found), else one of GIFTS.
const GIFT_WORDS := [["tonic", ["tonic", 1]], ["tangerine", ["tangerine", 3]], ["fruit", ["jungle_fruit", 3]], ["dates", ["jungle_fruit", 3]],
	["fish", ["fish", 2]], ["snapper", ["fish", 2]], ["biscuit", ["biscuit", 3]], ["hardtack", ["biscuit", 3]], ["bread", ["biscuit", 3]],
	["pasty", ["biscuit", 3]], ["stew", ["stew", 1]], ["soup", ["stew", 1]], ["rum", ["rum", 2]], ["wine", ["rum", 2]], ["cider", ["rum", 2]],
	["venison", ["boar_haunch", 1]], ["hare", ["boar_haunch", 1]], ["meat", ["boar_haunch", 1]], ["haunch", ["boar_haunch", 1]], ["crab", ["crab_meat", 2]]]
const LOOT := ["cutlass", "dagger", "katana", "boarding_axe", "spear", "warhammer", "musket", "slingshot"]

## Tools and tests: these kinds on every island instead of the roll.
static var force: Array = []

var life: IslandLife
var isl: GenIsland
var text: Dictionary
## [{"kind", "seed"}] as rolled; built ones get "at" (island point), "node" (their Node3D) and their people.
var rolled: Array = []
var built: Array = []
var _ctx: KitContext
var _used: Array = []
var _t := 0.0
var _bubble_t := 0.0


## The kinds an island of `theme` with seed `seed_value` has (data: the same on every machine).
static func roll(seed_value: int, theme: String) -> Array:
	if not force.is_empty():
		return force.map(func(k): return {"kind": k, "seed": hash([seed_value, k])})
	var pool: Dictionary = IslandThemes.of(theme).encounters
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, 5201])
	var r := rng.randf()
	var n := 0
	var acc := 0.0
	for i in range(COUNT.size()):
		acc += float(COUNT[i])
		if r < acc:
			n = i
			break
	var left: Array = KINDS.filter(func(k): return float(pool[k]["weight"]) > 0.0)
	var out: Array = []
	for i in range(n):
		if left.is_empty():
			break
		var total := 0.0
		for k in left:
			total += float(pool[k]["weight"])
		var pick := rng.randf() * total
		for k in left:
			pick -= float(pool[k]["weight"])
			if pick <= 0.0:
				out.append({"kind": k, "seed": rng.randi()})
				left.erase(k)
				break
	return out


func setup(l: IslandLife, kinds: Array) -> void:
	life = l
	isl = l.isl
	rolled = kinds.map(func(e): return (e as Dictionary).duplicate())
	text = IslandThemes.of(isl.theme).encounters
	name = "Encounters"
	_ctx = KitContext.make(isl, int(isl.node["seed"]), isl.theme, 3, isl.build_ms)
	_ctx.own_reserves = true


func build(e: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(e["seed"])
	var at := _spot(str(WHERE[e["kind"]]), rng)
	if at.is_empty():
		unstock_rest(e, _ctx.style)
		return
	var n := Node3D.new()
	n.name = "Enc_" + str(e["kind"])
	add_child(n)
	e.merge(at, true)
	e.merge({"at": at["p"], "node": n, "ctx": _ctx.under(n), "T": text[e["kind"]]}, true)
	_used.append(at["p"])
	call("_" + str(e["kind"]), e, rng)
	unstock_rest(e, _ctx.style)
	# (a kind that found nothing it needs - no second beach, no wild place, nobody to write to - leaves nothing)
	if e.get("none", false):
		n.queue_free()
		return
	built.append(e)


# --------------------------------------------------------------------------
# Where they go
# --------------------------------------------------------------------------
## {"p": island point, "face": the way they face, "y"?, "path"? (the trail's point beside it), "poi"?} or {}.
func _spot(where: String, rng: RandomNumberGenerator) -> Dictionary:
	match where:
		"trail":
			return _trail(rng)
		"beach":
			return _beach(rng)
		"village":
			var hub: Vector2 = life.hubs[0]
			var plaza: Array = life.spots.filter(func(s): return s["kind"] == "plaza" and s.get("hub") == hub)
			var f: Vector2 = Vector2.from_angle(rng.randf() * TAU)
			var out := {"p": hub + f * (KitLife.HUB_R + 2.0 + rng.randf() * 2.0), "face": -f}
			if not plaza.is_empty() and plaza[0].has("y"):
				out["y"] = plaza[0]["y"]
			return out
		"poi":
			# (not by the pirates' camp: nobody lives or wanders there but them)
			var pois: Array = life._pois().filter(func(s): return s["kind"] != "camp" and not _near_used(s["at"], 30.0))
			var first := rng.randi() % maxi(pois.size(), 1)
			for i in range(pois.size()):
				var poi: Dictionary = pois[(first + i) % pois.size()]
				var to_v: Vector2 = (life.hubs[0] - poi["at"]).normalized()
				for k in range(4):
					var p: Vector2 = poi["at"] + to_v.rotated((k - 1.5) * 0.5) * (float(poi.get("r", 6.0)) + 7.0)
					if _ok(p):
						return {"p": p, "face": (poi["at"] - p).normalized() * -1.0, "poi": poi}
	return {}


## Beside a path out of the village, 35-120 m along it, off to one side.
func _trail(rng: RandomNumberGenerator) -> Dictionary:
	var hub: Vector2 = life.hubs[0]
	for i in range(24):
		var path: PackedVector2Array = isl.paths[rng.randi() % isl.paths.size()]
		var cum := KitLife.measure(path)
		if cum[cum.size() - 1] < 45.0:
			continue
		var smp := KitLife.sample(path, cum, rng.randf_range(35.0, minf(120.0, cum[cum.size() - 1] - 5.0)))
		var side := Vector2(-smp[1].y, smp[1].x) * (1.0 if rng.randf() < 0.5 else -1.0)
		var p: Vector2 = smp[0] + side * 4.5
		if p.distance_to(hub) > 30.0 and _ok(p) and not _near_used(p, 40.0):
			return {"p": p, "face": -side, "path": smp[0]}
	return {}


## Sand above the waterline, well away from the dock.
func _beach(rng: RandomNumberGenerator) -> Dictionary:
	var dock: Vector2 = isl.sites["dock"]
	for i in range(36):
		var dir := Vector2.from_angle(rng.randf() * TAU)
		var r := isl.radius
		while r > 20.0 and isl.hv(dir * r) < 0.9:
			r -= 2.0
		var p := dir * (r - 3.0)
		if p.distance_to(dock) > 70.0 and _ok(p) and not _near_used(p, 40.0):
			return {"p": p, "face": dir}
	return {}


## Dry, fairly level, off the paths, and nothing solid there (a hut, a trunk, a rock: the island's reserves
## can't say, its sites' clearings are reserves too).
func _ok(p: Vector2) -> bool:
	var e := 2.5
	if isl.hv(p) < 0.8 or absf(isl.hv(p + Vector2(e, 0)) - isl.hv(p - Vector2(e, 0))) > 1.6 \
			or absf(isl.hv(p + Vector2(0, e)) - isl.hv(p - Vector2(0, e))) > 1.6 or isl.path_dist(p) < 1.5:
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	# (1.1-5.1 m up: trunks, walls and big rocks, never the slope itself)
	sph.radius = 2.0
	q.shape = sph
	q.transform = Transform3D(Basis(), isl.to_global(Vector3(p.x, isl.hv(p) + 3.1, p.y)))
	q.collision_mask = 1
	# (people and anything moving don't count: where they stand depends on when the island was built, and a guest's isn't the host's)
	for hit in isl.get_world_3d().direct_space_state.intersect_shape(q, 8):
		var c: Object = hit["collider"]
		if not (c is CharacterBody3D or c is RigidBody3D or (c is Node and (c as Node).get_parent() is NPC)):
			return false
	return true


func _near_used(p: Vector2, d: float) -> bool:
	return _used.any(func(u): return (u as Vector2).distance_to(p) < d)


# --------------------------------------------------------------------------
# People, their talk and their quests
# --------------------------------------------------------------------------
func _deal(e: Dictionary, k: String, n: int) -> Array:
	return life.deck.deal("enc_%s_%s" % [e["kind"], k], e["T"][k], n)


func _one(e: Dictionary, k: String) -> String:
	return life.deck.one("enc_%s_%s" % [e["kind"], k], e["T"][k])


func _short(who: String) -> String:
	var parts := who.split(" ")
	return parts[parts.size() - 1]


## How many people each kind makes (_person), whose bodies IslandLife.plan builds ahead on its worker.
const PEOPLE := {"traveller": 1, "festival": 1, "shipwreck": 1, "merchant": 1, "lost_child": 2, "hermit": 1, "wounded": 1, "duelist": 1}


## The look of the k-th person encounter `e` makes, from its own seed (data: plan builds the body ahead from it).
static func person_look(e: Dictionary, k: int, style: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(e["seed"]), "person", k])
	var lk: Dictionary
	if e["kind"] == "duelist":
		lk = PirateGrunt.crew_look(rng)
		lk.merge({"coat": "longcoat", "hat": "none", "build": "broad"}, true)
	else:
		lk = KitStyle.folk_look(style, rng)
	lk["name"] = "enc_%d_%d" % [int(e["seed"]), k]
	return lk


## Every look `kinds` (as rolled) will want, in order.
static func people_looks(kinds: Array, theme: String) -> Array:
	var style := KitStyle.get_style(theme)
	var out: Array = []
	for e in kinds:
		for k in range(int(PEOPLE.get(e["kind"], 0))):
			out.append(person_look(e, k, style))
	return out


## Bodies built ahead for people `e` didn't make (it found no place, or the island went first): freed.
static func unstock_rest(e: Dictionary, style: Dictionary) -> void:
	for k in range(int(e.get("people", 0)), int(PEOPLE.get(e["kind"], 0))):
		Humanoid.unstock(person_look(e, k, style))
	e["people"] = int(PEOPLE.get(e["kind"], 0))


## A person at island point p (on the ground, or at y), facing `face`, in the next look of the encounter's own.
func _person(e: Dictionary, who: String, p: Vector2, face: Vector2, rng: RandomNumberGenerator, cfg := {}, y := INF) -> NPC:
	var k := int(e.get("people", 0))
	e["people"] = k + 1
	var npc := NPC.new()
	npc.setup({"name": who, "voice": rng.randf_range(0.85, 1.15), "look": person_look(e, k, _ctx.style), "yaw": atan2(-face.x, -face.y)}.merged(cfg, true))
	npc.ground_func = isl.walk_height
	e["node"].add_child(npc)
	npc.position = Vector3(p.x, isl.hv(p) if y == INF else y, p.y)
	return npc


## Someone's talk: the intro the first time, then a greeting and their topics (`choices` and `nodes` from the kind).
func _talk(e: Dictionary, id: String, who: String, voice: float, choices: Array, nodes: Dictionary) -> void:
	var T: Dictionary = e["T"]
	var menu: Array = [{"text": T["talk_menu"], "next": "talk"}] + choices
	menu.append({"text": "Goodbye.", "next": "end"})
	nodes.merge({"intro": {"text": T["intro"], "next": "menu"}, "menu": {"text": _one(e, "menu"), "choices": menu},
		"talk": {"text": _deal(e, "talk", 2), "next": "menu"}}, true)
	Dialogue.define(id, {"speaker": who, "voice": voice, "start": "intro", "return": "menu", "nodes": nodes})


## A quest def for KitQuests (the crew's journal), turned in to `giver`.
func _quest(e: Dictionary, giver: String, title: String, steps: Array, tok: Dictionary, reward: Dictionary, extra := {}) -> Dictionary:
	var T: Dictionary = e["T"]
	var q := {"id": life.key("enc_" + str(e["kind"])), "kind": "enc_" + str(e["kind"]), "giver": giver, "isle": isl.island_name, "pos": isl.position,
		"src": "npc", "title": title, "reward": reward, "accept": life.pools["accept"], "decline": life.pools["decline"],
		"taken": life.deck.one("taken", life.pools["taken"]), "favour_ask": IslandLife.FAVOUR_ASK, "steps": steps}
	for k in ["ask", "plea", "decline", "remind_choice", "remind", "done", "thanks", "search"]:
		if T.has(k):
			q[k] = _fill(T[k], tok)
	q["favour_thanks"] = life.deck.deal("favour", IslandLife.FAVOUR_THANKS, 1) if reward.has("favour") else []
	q.merge(extra, true)
	return q


## Tokens filled, each line starting with a capital ({place} may open it).
func _fill(v, tok: Dictionary):
	if v is Array:
		return (v as Array).map(func(l): return _cap(LifePools.fill(str(l), tok)))
	return _cap(LifePools.fill(str(v), tok))


func _gold(base: int) -> int:
	return base + IslandContent.tier(isl) * roundi(base * 0.5)


func _fire_camp(e: Dictionary, p: Vector2, face: Vector2) -> void:
	KitCamps.castaway(e["ctx"], p, -face.rotated(0.9) * 3.4, face.rotated(-1.2) * 1.8, KitContext.face_yaw(face) + PI * 0.5)


## Where a wild place is, said as its lost things are ("in the old stones", "out by the bat roost").
func _place_of(poi: Dictionary) -> String:
	var at: Dictionary = life.pools["lost_at"]
	return LifePools.fill(at.get(poi["kind"], at["any"]), poi)


# --------------------------------------------------------------------------
# The kinds
# --------------------------------------------------------------------------
func _traveller(e: Dictionary, rng: RandomNumberGenerator) -> void:
	var p: Vector2 = e["at"]
	var f: Vector2 = e["face"]
	_fire_camp(e, p + f * 1.8, f)
	var who := _one(e, "who")
	var npc := _person(e, who, p, f, rng, {"dialogue": life.key("enc_traveller"), "seated": true})
	var id := npc.dialogue_id
	var rumours: Array = _fill(_deal(e, "rumours", 2), {"isle": isl.island_name})
	var line := _one(e, "gift")
	var gift: Array = GIFTS[rng.randi() % GIFTS.size()]
	for g in GIFT_WORDS:
		if line.to_lower().contains(g[0]):
			gift = g[1]
			break
	var flag := life.key("enc_gift")
	var choices := [{"text": e["T"]["rumour_menu"], "next": "rumours"}, {"text": e["T"]["gift_ask"], "next": "gift", "hide_if": flag},
		{"text": e["T"]["gift_ask"], "next": "gift_none", "requires": flag}]
	var nodes := {"rumours": {"text": rumours, "next": "menu", "event": "rumour:" + id},
		"gift": {"text": [line, "(%s)" % QuestRewards.text({"items": [gift]})], "set_flag": flag, "event": "enc_gift:%s:%s:%d" % [id, gift[0], int(gift[1])], "next": "menu"},
		"gift_none": {"text": _deal(e, "gift_none", 1), "next": "menu"}}
	Journal.tell(id, rumours, who, isl.island_name)
	_talk(e, id, who, npc.voice, choices, nodes)


func _ambush(e: Dictionary, rng: RandomNumberGenerator) -> void:
	var p: Vector2 = e["at"]
	var road: Vector2 = e["path"]
	var across := (p - road).normalized()
	var along := across.rotated(PI * 0.5)
	var crew := GruntCamp.new()
	crew.name = "Ambush"
	crew.respawn_time = 1e9
	crew.warm_start = true
	crew.level = IslandContent.level(isl)
	var titles: Array = e["T"]["crew"]
	var posts: Array = [p, p + along * 4.0, road - across * 4.5 - along * 3.0, road - across * 5.0 + along * 3.5]
	for i in range(3 + rng.randi() % 2):
		var q: Vector2 = posts[i]
		var cfg := {"post": Vector3(q.x, isl.hv(q), q.y), "yaw": KitCamps.look_yaw(q, road), "mode": "stand", "seed": rng.randi() % 100000,
			"title": str(titles[rng.randi() % titles.size()])}
		if i == 3:
			cfg["role"] = "rifle"
		crew.add_grunt(cfg)
	e["node"].add_child(crew)
	e["crew"] = crew
	e["sprung"] = false
	var baker := isl.get_parent().get_node_or_null("NavBaker")
	if baker:
		baker.add_zone(e["node"], 30.0, false, isl.terrain_faces)


func _festival(e: Dictionary, rng: RandomNumberGenerator) -> void:
	var p: Vector2 = e["at"]
	var f: Vector2 = e["face"]
	var fest := _one(e, "name")
	var tok := {"festival": fest}
	var hub: Vector2 = life.hubs[0]
	for k in range(4):
		var lp := hub + Vector2.from_angle(TAU * (k + 0.5) / 4.0 + rng.randf() * 0.4) * (KitLife.HUB_R + 4.5)
		if _ok(lp):
			KitLights.post(e["ctx"], lp, KitContext.face_yaw(hub - lp))
	var who := _one(e, "who")
	var npc := _person(e, who, p, f, rng, {"dialogue": life.key("enc_festival")}, e.get("y", INF))
	e["host"] = npc
	e["barks"] = _fill(_deal(e, "barks", 4), tok)
	var want: Dictionary = e["T"]["wants"][rng.randi() % (e["T"]["wants"] as Array).size()]
	tok.merge({"what": want["what"], "who": _short(who)})
	var q := _quest(e, who, _cap("%s: %s" % [fest, want["what"]]), [{"do": "turnin", "goal": _cap("Bring %s to %s for %s" % [want["what"], _short(who), fest])}], tok,
		{"gold": _gold(20), "items": [["stew", 2]], "favour": {"who": _short(who), "gift": [["rum", 3]]}}, {"cost": [[want["item"], int(want["count"])]]})
	life.quest_node.add(q, isl)
	var choices: Array = []
	var nodes := {}
	life.quest_node.offer(q, choices, nodes)
	_talk(e, npc.dialogue_id, who, npc.voice, choices, nodes)


func _shipwreck(e: Dictionary, rng: RandomNumberGenerator) -> void:
	var p: Vector2 = e["at"]
	var f: Vector2 = e["face"]
	var lost := _spot("beach", rng)
	if lost.is_empty():
		e["none"] = true
		return
	_used.append(lost["p"])
	var boat := Props.rowboat()
	e["ctx"].place(boat, p + f * 5.0 + f.rotated(PI * 0.5) * 2.0, KitContext.face_yaw(f) + 1.2, 2.5, -0.25)
	boat.rotation.z = 0.5
	e["ctx"].place(HarbourModels.timber(rng.randi()), p + f * 3.0 - f.rotated(PI * 0.5) * 3.0, rng.randf() * TAU)
	_fire_camp(e, p - f * 1.6, -f)
	_lost_quest(e, rng, lost, "shipwreck", {"gold": _gold(25), "reveal": true}, {"place": "along the shore to the %s" % _bearing(lost["p"] - p)})


func _merchant(e: Dictionary, rng: RandomNumberGenerator) -> void:
	var v := isl.get_node_or_null("Site_village/Village") as IslandVillage
	if v == null or not v.jobs.has("camp"):
		e["none"] = true
		return
	var p: Vector2 = e["at"]
	var f: Vector2 = e["face"]
	var cart := KitVillage.handcart()
	e["ctx"].place(cart, p + f.rotated(PI * 0.5) * 2.2, KitContext.face_yaw(f) + 0.4, 1.5)
	cart.rotation.z = 1.2
	e["ctx"].place(KitStyle.prop(_ctx.style, "crate", rng, 0.8), p + f * 1.5 + f.rotated(-1.0) * 1.8, rng.randf() * TAU)
	var camp: Vector2 = isl.sites["camp"]
	var c: Vector2 = camp + (p - camp).normalized().rotated(0.6) * 6.0
	_lost_quest(e, rng, {"p": c, "face": (p - c).normalized()}, "merchant", {"gold": _gold(30), "items": [["treasure", 1 + IslandContent.tier(isl)]]},
		{"camp": str(v.jobs["camp"]["name"]), "place": "at the pirates' camp"})


## A survivor / a merchant whose thing is somewhere else (`lost`: its spot): a pickup there, then back to them.
func _lost_quest(e: Dictionary, rng: RandomNumberGenerator, lost: Dictionary, kind: String, reward: Dictionary, tok: Dictionary) -> void:
	var who := _one(e, "who")
	var npc := _person(e, who, e["at"], e["face"], rng, {"dialogue": life.key("enc_" + kind), "seated": kind == "shipwreck"})
	var thing := _one(e, "thing")
	var the := thing.replace("my ", "the ").replace("our ", "the ")
	tok.merge({"thing": thing, "who": _short(who)}, true)
	var q := _quest(e, who, "%s's %s" % [_short(who), the.trim_prefix("the ").trim_prefix("a ")],
		[{"do": "pickup", "goal": _cap("Find %s %s" % [the, tok["place"]]), "said": _fill(e["T"]["said"], tok.merged({"thing": the}, true))},
		{"do": "turnin", "goal": "Bring it back to %s" % _short(who)}], tok, reward, {"at": lost["p"], "yaw": rng.randf() * TAU})
	q["search"] = _fill(e["T"]["search"], tok.merged({"thing": the}, true))
	life.quest_node.add(q, isl)
	var choices: Array = []
	var nodes := {}
	life.quest_node.offer(q, choices, nodes)
	_talk(e, npc.dialogue_id, who, npc.voice, choices, nodes)


func _bearing(d: Vector2) -> String:
	var a := fposmod(atan2(d.x, -d.y), TAU)
	return ["north", "east", "south", "west"][int(round(a / (PI * 0.5))) % 4]


func _lost_child(e: Dictionary, rng: RandomNumberGenerator) -> void:
	var where := _spot("poi", rng)
	if where.is_empty():
		e["none"] = true
		return
	_used.append(where["p"])
	var T: Dictionary = e["T"]
	var parent := _one(e, "parent")
	var child := str(T["child"][rng.randi() % (T["child"] as Array).size()])
	var kid_name := "Young " + child
	var place := _place_of(where["poi"])
	var tok := {"child": child, "place": place, "parent": _short(parent), "who": _short(parent)}
	var mom := _person(e, parent, e["at"], e["face"], rng, {"dialogue": life.key("enc_lost_child")}, e.get("y", INF))
	var kid := _person(e, kid_name, where["p"], where["face"], rng, {"dialogue": life.key("enc_child")})
	kid.humanoid.scale = Vector3.ONE * 0.66
	kid.name_tag.position.y *= 0.66
	e.merge({"kid": kid, "home": e["at"] + (e["face"] as Vector2).rotated(PI * 0.5) * 1.2}, true)
	var q := _quest(e, parent, "%s, lost %s" % [child, place], [{"do": "talk", "goal": "Find %s %s" % [child, place], "who": kid_name, "said": _fill(T["said"], tok)},
		{"do": "turnin", "goal": "Tell %s that %s is safe" % [_short(parent), child]}], tok,
		{"gold": _gold(20), "favour": {"who": _short(parent), "gift": [["stew", 2], ["tonic", 1]]}},
		{"hand": _fill(T["child_hand"], tok), "got": _fill(_deal(e, "child_got", 1), tok)})
	life.quest_node.add(q, isl)
	e["quest"] = q
	var choices: Array = []
	var nodes := {}
	life.quest_node.offer(q, choices, nodes)
	_talk(e, mom.dialogue_id, parent, mom.voice, choices, nodes)
	var kc: Array = []
	var kn := {}
	life.quest_node.hand_over(q, kc, kn)
	kc.append({"text": "Goodbye.", "next": "end"})
	kn.merge({"intro": {"text": _fill(_deal(e, "child_intro", 2), tok), "next": "menu"}, "menu": {"text": "...", "choices": kc}}, true)
	Dialogue.define(kid.dialogue_id, {"speaker": kid_name, "voice": 1.35, "start": "intro", "return": "menu", "nodes": kn})


func _hermit(e: Dictionary, rng: RandomNumberGenerator) -> void:
	var p: Vector2 = e["at"]
	var f: Vector2 = e["face"]
	var here: Dictionary = e.get("poi", {})
	var far: Array = life._pois().filter(func(s): return s != here and (s["at"] as Vector2).distance_to(p) > 40.0)
	_fire_camp(e, p + f * 1.8, f)
	var who := _one(e, "who")
	var npc := _person(e, who, p, f, rng, {"dialogue": life.key("enc_hermit"), "seated": true})
	var choices: Array = [{"text": e["T"]["rumour_menu"], "next": "rumours"}]
	var rumours := _deal(e, "rumours", 2)
	var nodes := {"rumours": {"text": rumours, "next": "menu", "event": "rumour:" + npc.dialogue_id}}
	Journal.tell(npc.dialogue_id, rumours, who, isl.island_name)
	if not far.is_empty():
		var poi: Dictionary = far[rng.randi() % far.size()]
		var tok := {"place": _place_of(poi), "who": _short(who)}
		var at: Vector2 = poi["at"]
		var q := _quest(e, who, "%s's errand: %s" % [_short(who), poi["name"]], [{"do": "reach", "goal": _cap("Go and see %s for %s" % [poi["name"], _short(who)]),
			"said": _fill(e["T"]["said"], tok)}, {"do": "turnin", "goal": "Tell %s what you saw" % _short(who)}], tok,
			{"gold": _gold(15), "chart": true}, {"point": isl.to_global(Vector3(at.x, isl.hv(at) + 1.0, at.y)), "r": float(poi.get("r", 6.0)) + 8.0})
		life.quest_node.add(q, isl)
		life.quest_node.offer(q, choices, nodes)
	_talk(e, npc.dialogue_id, who, npc.voice, choices, nodes)


func _wounded(e: Dictionary, rng: RandomNumberGenerator) -> void:
	var who := _one(e, "who")
	var npc := _person(e, who, e["at"], e["face"], rng, {"dialogue": life.key("enc_wounded"), "seated": true})
	var tok := {"who": _short(who)}
	var q := _quest(e, who, "A tonic for %s" % _short(who), [{"do": "turnin", "goal": "Bring a Sea Tonic to %s" % _short(who)}], tok,
		{"gold": _gold(15), "favour": {"who": _short(who), "gift": [["boar_haunch", 2]]}}, {"cost": [["tonic", 1]]})
	life.quest_node.add(q, isl)
	var choices: Array = []
	var nodes := {}
	life.quest_node.offer(q, choices, nodes)
	_talk(e, npc.dialogue_id, who, npc.voice, choices, nodes)


func _note(e: Dictionary, rng: RandomNumberGenerator) -> void:
	var named: Array = life.placed.filter(func(i): return life.folk[i]["named"])
	if named.is_empty():
		e["none"] = true
		return
	var fi: int = named[rng.randi() % named.size()]
	var f: Dictionary = life.folk[fi]
	var thing := _one(e, "things")
	var tok := {"who": _short(f["name"]), "thing": thing}
	var note: String = _fill(_one(e, "notes"), tok)
	var remains := Node3D.new()
	remains.name = "Remains"
	var mi := MeshInstance3D.new()
	mi.mesh = Props.sack_mesh()
	mi.scale = Vector3.ONE * 0.45
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 120.0
	remains.add_child(mi)
	e["ctx"].place(remains, e["at"], rng.randf() * TAU)
	var q := _quest(e, str(f["name"]), _cap("%s for %s" % [thing, _short(f["name"])]), [{"do": "turnin", "goal": _cap("Bring %s to %s" % [thing, f["name"]])}], tok,
		{"gold": _gold(15), "items": [["treasure", 1]]}, {"src": "found", "thanks": [_fill(_one(e, "thanks"), tok)]})
	life.quest_node.add(q, isl)
	life.found.append(q)
	life._define_talk(fi)
	var it := Interactable.new()
	it.name = "Search"
	it.collision_layer = NPC.INTERACT_LAYER
	it.collision_mask = 0
	it.prompt_text = str(e["T"]["search"])
	it.gesture = "pickup"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.5
	cs.shape = sph
	cs.position = Vector3(0, 0.4, 0)
	it.add_child(cs)
	remains.add_child(it)
	it.interacted.connect(func(_pl):
		if not Journal.has(q["id"]):
			Dialogue.say("A note", [note])
			Journal.take(q["id"]))


func _duelist(e: Dictionary, rng: RandomNumberGenerator) -> void:
	var who := _one(e, "who")
	var lk := person_look(e, 0, _ctx.style)
	var npc := _person(e, who, e["at"], e["face"], rng, {"dialogue": life.key("enc_duelist")})
	var tok := {"who": _short(who)}
	e.merge({"duelist": npc, "spec": {"post": Vector3.ZERO, "yaw": KitCamps.look_yaw(e["at"], e["at"] + e["face"]), "mode": "stand", "seed": rng.randi() % 100000,
		"look": lk, "captain": true, "title": who}}, true)
	var t := IslandContent.tier(isl)
	var q := _quest(e, who, "A duel with %s" % _short(who), [{"do": "clear", "goal": "Beat %s in a duel" % _short(who), "said": "%s yields." % _short(who)},
		{"do": "turnin", "goal": "Collect what %s promised" % _short(who)}], tok,
		{"gold": _gold(40), "items": [["%s@%d" % [LOOT[rng.randi() % LOOT.size()], t], 1]]},
		{"clear": func() -> bool: return e.has("crew") and (e["crew"] as GruntCamp).grunts.any(func(g): return is_instance_valid(g) and g.state == PirateGrunt.S.DEAD),
		"poi_at": e["at"], "thanks": _deal(e, "beaten", 2), "remind": _one(e, "taunts")})
	life.quest_node.add(q, isl)
	e["quest"] = q
	var choices: Array = []
	var nodes := {}
	life.quest_node.offer(q, choices, nodes)
	_talk(e, npc.dialogue_id, who, npc.voice, choices, nodes)


# --------------------------------------------------------------------------
# What happens (twice a second, every machine)
# --------------------------------------------------------------------------
func _ready() -> void:
	Dialogue.dialogue_event.connect(_on_event)


## A traveller's gift, to whoever asked (once per captain: their own flag).
func _on_event(ev: String) -> void:
	if not ev.begins_with("enc_gift:"):
		return
	var parts := ev.split(":")
	# (every standing island hears every island's events)
	if parts[1] != life.key("enc_traveller"):
		return
	var me := get_tree().get_first_node_in_group("player") as Player
	me.inventory_component.add_item(ItemDB.get_item(parts[2]), int(parts[3]))


func _process(delta: float) -> void:
	_t -= delta
	_bubble_t -= delta
	if _t > 0.0 or built.is_empty():
		return
	_t = TICK
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me == null:
		return
	for e in built:
		match str(e["kind"]):
			"ambush":
				_ambush_tick(e, me)
			"festival":
				_festival_tick(e, me)
			"lost_child":
				_child_tick(e)
			"duelist":
				_duel_tick(e)


func _ambush_tick(e: Dictionary, me: Node3D) -> void:
	if e["sprung"]:
		return
	var crew: GruntCamp = e["crew"]
	for g in crew.grunts:
		if is_instance_valid(g) and (g as Node3D).global_position.distance_to(me.global_position) < SPRING:
			e["sprung"] = true
			get_tree().call_group("hud", "show_banner", _one(e, "banner"), _one(e, "shouts"), true)
			if Net.is_host():
				crew.alert_all((g as Node3D).global_position)
			return


## The host shouts over the crowd in the evening, when a captain is near.
func _festival_tick(e: Dictionary, me: Node3D) -> void:
	var host: NPC = e["host"]
	var h := Weather.hour()
	if _bubble_t > 0.0 or h < 17.0 or h > 23.5 or host.global_position.distance_to(me.global_position) > BUBBLE_R or Dialogue.active:
		return
	_bubble_t = 14.0
	var lines: Array = e["barks"]
	var b := host.get_node_or_null("Bubble") as Label3D
	if b == null:
		b = Label3D.new()
		b.name = "Bubble"
		b.font = load("res://assets/fonts/PixelifySans-Regular.woff2")
		b.font_size = 30
		b.pixel_size = 0.006
		b.outline_size = 8
		b.width = 900.0
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		b.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		b.position = Vector3(0, 2.55, 0)
		host.add_child(b)
	b.text = lines[int(h * 7.0) % lines.size()]
	b.visible = true
	get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(b):
			b.visible = false)


## Found and talked round, the child heads home: beside the parent from then on.
func _child_tick(e: Dictionary) -> void:
	var kid: NPC = e["kid"]
	var id: String = e["quest"]["id"]
	if Journal.step_of(id) >= 1 or Journal.is_done(id):
		var h: Vector2 = e["home"]
		var at := Vector3(h.x, isl.hv(h) if not e.has("y") else float(e["y"]), h.y)
		if kid.position.distance_to(at) > 0.5:
			kid.position = at
			kid.reset_physics_interpolation()


## Challenge taken: he fights (a GruntCamp of one, the host runs him); beaten, or not yet asked, he stands to talk.
func _duel_tick(e: Dictionary) -> void:
	var id: String = e["quest"]["id"]
	var npc: NPC = e["duelist"]
	var fighting := Journal.step_of(id) == 0 and not Journal.is_done(id)
	if fighting and not e.has("crew"):
		var crew := GruntCamp.new()
		crew.name = "Duel"
		crew.respawn_time = 1e9
		crew.level = IslandContent.level(isl) + 2
		crew.max_attackers = 1
		crew.add_grunt(e["spec"])
		e["node"].add_child(crew)
		crew.position = npc.position
		e["crew"] = crew
		get_tree().call_group("hud", "show_banner", "A duel!", _one(e, "taunts"), true)
	npc.visible = not fighting
	npc.interactable.collision_layer = 0 if fighting else NPC.INTERACT_LAYER
	(npc.get_node("Body") as StaticBody3D).collision_layer = 0 if fighting else 1


static func _cap(s: String) -> String:
	return s if s == "" else s[0].to_upper() + s.substr(1)
