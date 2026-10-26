class_name IslandArcs
extends Node3D
## A chain island's story arc (1.23, docs/v1_23_previews.md section 5): a local problem with a villain, in three beats.
## Beat 1: the elder, the folk's rumours and a poster on the board tell of it (taking it puts the arc in the crew's
## Journal). Beat 2: 2-3 story steps on the island's own places (a squad to break, a thing to take back, someone to
## talk to, a night to hold). Beat 3: the showdown with the villain (the island's camp captain, its beast, or a villain
## the arc brings). Its fall drops the arc's chest, raises the bounty and the Admiralty answers (Admiralty.deed "arc");
## the elder's thanks close it. Replies (Replies) at the villain's first meeting and one moment in beat 2 change the
## next line and sometimes the outcome; a hidden finish, met in the showdown, pays a cache besides.
##
## One template per island (TEMPLATES), rolled from what the island has (`pick`: an outpost, a cave, the fog) and the
## chain's seed, so neighbours differ. State is the crew's Journal entry (the step) and world flags under `key`
## (the island's id and seed: saved, sent to a captain who joins), so every machine builds the same squads and props
## from it. The host decides (Net.arc_ask -> decide), everyone applies (Net._all_arc -> apply).

const TICK := 0.5
## The villain's first meeting: a captain this close (m) to the villain is spoken to.
const MEET_R := 30.0
## A meeting asked of a captain who hasn't answered in this long (s) is asked again.
const ASK_WAIT := 45.0
const NIGHT_FROM := 20.0
const NIGHT_TO := 5.0
## The beast's hidden finish while beasts have no parts to break (the beast pass): felled within this long of waking.
const QUICK_KILL := 120.0
const WEAPONS := ["cutlass", "katana", "polearm", "hammer", "greatsword", "pistol"]
const CONTACT_NAMES := ["Ibo", "Maren", "Tull", "Seska", "Orrin", "Pell", "Dagny", "Kofi", "Wren", "Haldo"]
## Fights at the village's edge stay this far (m) past its plaza: out of a Marine outpost's town (MarineOutpost.TOWN_PAD).
const EDGE := 38.0
const Shops := preload("res://scripts/game/shops.gd")
## Tests and tools: every island rolls this template ("" for the roll).
static var force := ""

## Each template: "title"; "needs" (what the island must have: camp, beast, outpost, cave, fog); "villain" ({"kind":
## camp / beast / squad ...}); "place" (the showdown's spot); the elder's telling ("elder"), the folk's "rumours", the
## board's "poster"; "steps" (beat 2: {"do": squad / pickup / talk / wave, "at": a spot, "goal", "said", ...});
## "showdown" (its goal); "meet" and "moment" (replies: {"lines", "replies": [{"tone", "text", "answer", "out"}],
## "default"}; a moment is at "step", spoken by "contact"); "hidden" ({"kind", "name", "said"}); "thanks", "settled".
## Tokens: {villain} {village} {elder} {place} {c0}... (the arc's contacts).
const TEMPLATES := {
	"tyrant": {
		"title": "The Tyrant's Tax",
		"needs": ["camp"],
		"villain": {"kind": "camp"},
		"place": "camp",
		"place_name": "the pirate camp",
		"elder": ["Since the rains, {villain} and his crew have bled {village} dry. A tax, he calls it.",
			"His collectors take half of every catch, and last week they took our strongbox: the whole village's savings.",
			"We can't fight him. But you look like you could."],
		"remind": ["His collectors work the road to the camp. The strongbox is at the camp's edge, under his nose."],
		"rumours": ["{villain}'s collectors came by again. Took my nets this time.",
			"They say {villain} keeps our strongbox at the edge of his camp, where he can see it from his chair.",
			"Half the village wants to pay {villain} and be done. The other half wants him gone.",
			"His men aren't all bad, you know. Half of them were fishermen here before he came."],
		"poster": "By order of the village: a reward to whoever ends {villain}'s 'tax'. Ask {elder}.",
		"contacts": [{"name": "Quartermaster {n}", "at": "camp_edge", "look": "pirate", "line": "I only keep the books, friend. Don't look at me like that."}],
		"steps": [
			{"do": "squad", "at": "road_camp", "men": 3, "look": "pirate", "goal": "Break {villain}'s tax collectors on the road to the camp",
				"said": "The collectors are broken. Now take back the strongbox."},
			{"do": "pickup", "at": "camp_edge", "goal": "Take back {village}'s strongbox from the edge of {villain}'s camp", "search": "Take the village strongbox",
				"said": "The strongbox is the village's again. {villain} won't let that stand."},
		],
		"showdown": "Face {villain} at the pirate camp",
		"moment": {"step": 1, "contact": 0,
			"lines": ["Easy, easy! I keep his books, that's all. That box isn't worth dying over.", "So what's it to be?"],
			"replies": [
				{"tone": "cocky", "text": "Run and tell your captain I'm coming.", "answer": "He'll have every man he's got waiting for you!", "out": ["more"]},
				{"tone": "cool", "text": "Walk away. I never saw you.", "answer": "Never saw you either. Good luck. You'll need it.", "out": []},
				{"tone": "diplomatic", "text": "Thirty gold says you tell me how he fights.", "cost": 30,
					"answer": "His left knee's bad from the last mutiny. Kick it and he's half the man. You didn't hear it from me.", "out": ["pay:30", "wounded:0.25"]},
			]},
		"meet": {
			"lines": ["So you're the ones stirring up my village.",
				"Here's my offer: you pay the tax like everyone else, a captain's share, and we part friends. Or you don't, and my boys visit {village} tonight."],
			"replies": [
				{"tone": "diplomatic", "text": "Fine. Take the gold and leave them be.", "cost": 150, "answer": "Smart captain. Now get off my island.", "out": ["pay:150", "settle", "hated"]},
				{"tone": "cool", "text": "Not one coin.", "answer": "Then I'll take it out of them tonight. Every house.", "out": ["raid"]},
				{"tone": "cocky", "text": "Your tax days are over, old man.", "answer": "Old?! Cut them down, lads!", "out": ["fight"]},
			],
			"default": 2},
		"hidden": {"kind": "spare_men", "name": "Mercy", "said": "With their captain down and not one of them killed, his men throw down their blades and surrender."},
		"thanks": ["{villain}... gone? Truly?", "Then {village} keeps its catch and its savings. Take this, with all our thanks."],
		"settled": ["You paid him. With our strongbox in your hands, you paid him.", "Leave us be, Captain. You've done enough."],
	},
	"beast": {
		"title": "The Beast of the Hollow",
		"needs": ["beast"],
		"villain": {"kind": "beast"},
		"place": "boss",
		"place_name": "its hollow",
		"elder": ["Something comes down from the hollow at night. {villain}, the old ones call it.",
			"It took two goats, then a fence, then a boat shed. Next it will take a child.",
			"{c0} has been tracking it. Find them, Captain, and end this."],
		"remind": ["{c0} is out on the trail toward the hollow, reading its tracks."],
		"rumours": ["I heard {villain} last night. Like a tree falling, over and over.",
			"There are tracks the size of a cart wheel on the trail to the hollow.",
			"{villain} sleeps in its hollow by day. Only a fool goes in.",
			"Old hunters say you never just kill a beast like that. You take it apart, piece by piece."],
		"poster": "DANGER: {villain}. {village} pays whoever ends it. Ask {elder}.",
		"contacts": [{"name": "Hunter {n}", "at": "tracks", "look": "villager", "line": "Quiet. It passed here an hour ago."}],
		"steps": [
			{"do": "talk", "at": "tracks", "contact": 0, "goal": "Find {c0} on {villain}'s trail", "said": "The trap is set for nightfall."},
			{"do": "wave", "at": "village_edge", "bugs": 5, "goal": "Hold {village} through the night: {villain}'s brood comes first",
				"said": "The night's quiet again. {villain} limps back to its hollow, hurt and angry."},
		],
		"showdown": "Hunt {villain} down in its hollow",
		"moment": {"step": 0, "contact": 0,
			"lines": ["You're after {villain} too? Look at these tracks: it comes down to the village every night.",
				"We can hunt it in its hollow now, while it sleeps. Or we bait a trap at the village tonight and let it come to us. It won't leave a trap whole."],
			"replies": [
				{"tone": "cocky", "text": "Now. I want it awake and angry.", "answer": "Ha! Then go. I'll tell them to bar their doors.", "out": ["now"]},
				{"tone": "cool", "text": "Set the trap. We hold the village tonight.", "answer": "Good. The bait goes out at dusk. Its brood will come first.", "out": ["step", "wounded:0.3"]},
				{"tone": "diplomatic", "text": "What does the village want?", "answer": "To sleep. A trap, then: we hold the village tonight and it limps home hurt.", "out": ["step", "wounded:0.3"]},
			]},
		"hidden": {"kind": "parts", "name": "Trophy hunter", "said": "Taken apart before it fell, just as the old hunters said. They'll sing of this one."},
		"thanks": ["It's dead? You're sure?", "Then we sleep tonight, all of us. Take this, Captain. It isn't enough."],
		"settled": ["It's gone quiet. Whatever you did, thank you."],
	},
}

var isl: GenIsland
var life: IslandLife
var village: IslandVillage
## The template's id and its table.
var arc := ""
var T: Dictionary
## Its quest's id in the Journal, and the prefix of its world flags.
var key := ""
var def: Dictionary
var spots := {}
var tok := {}
var contacts: Array = []
var villain_name := ""
var _t := 0.0
var _asking := 0
var _ask_t := 0.0
var _men0 := -1
var _woke_t := -1.0
var _fight_t := 0.0
var _wounded: Array = []


## On a GenIsland's worker (IslandLife.plan): the template it will likely roll (the outpost isn't built yet: its roll
## is), and the contacts' bodies built ahead. {"id", "looks"}.
static func plan(gi: GenIsland) -> Dictionary:
	var id := pick(facts(gi, MarineOutpost.rolls(gi)))
	if id == "":
		return {}
	var looks := _looks(gi, id)
	for lk in looks:
		var h := Humanoid.new()
		h.setup(lk)
		Humanoid.stock(h, lk)
	return {"id": id, "looks": looks}


## What the roll reads off an island.
static func facts(gi: GenIsland, outpost: bool) -> Dictionary:
	return {"id": int(gi.node["id"]), "theme": gi.theme, "outpost": outpost, "cave": not gi.interiors.is_empty(),
		"village": not gi.village_plan.is_empty() and not (gi is CapitalIsland), "chain": int((Engine.get_main_loop() as SceneTree).root.get_node("GameManager").chain_seed)}


static func fits(f: Dictionary, id: String) -> bool:
	for n in TEMPLATES[id]["needs"]:
		match str(n):
			"outpost", "cave":
				if not f[n]:
					return false
			"fog":
				if f["theme"] != "fog":
					return false
	return true


## The template an island rolls ("" for none: no village to tell of it). The fog isle rolls the Cursed Festival; any
## other its turn in the chain's own order of the templates that fit, so the islands of one sea differ.
static func pick(f: Dictionary) -> String:
	if force != "":
		return force
	if not f["village"]:
		return ""
	if TEMPLATES.has("festival") and fits(f, "festival"):
		return "festival"
	var order: Array = TEMPLATES.keys()
	order.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(f["chain"]), 5120])
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var start := (int(f["id"]) * 3) % order.size()
	for i in range(order.size()):
		var id: String = order[(start + i) % order.size()]
		if id != "festival" and fits(f, id):
			return id
	return ""


## The contacts' looks (seeded by the island and the template).
static func _looks(gi: GenIsland, id: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(gi.node["seed"]), 5121, id])
	var out: Array = []
	for c in TEMPLATES[id].get("contacts", []):
		var lk: Dictionary
		match str(c["look"]):
			"pirate":
				lk = PirateGrunt.crew_look(rng)
			"marine":
				lk = CharacterLook.random_look(rng)
				EnemyShip.marine_look(lk, rng, false)
			_:
				lk = IslandVillage._villager_look(rng)
		lk["name"] = LifePools.fill(str(c["name"]), {"n": CONTACT_NAMES[rng.randi() % CONTACT_NAMES.size()]})
		out.append(lk)
	return out


## The life step (IslandLife._setup, every machine, after every site and the outpost): the arc the island rolled, its
## contacts, its quest and its hooks on the elder and the board. null: none.
static func make(L: IslandLife, v: IslandVillage) -> IslandArcs:
	var gi := L.isl
	var id := pick(facts(gi, gi.get_node_or_null("MarineOutpost") != null))
	var planned: Dictionary = L.arc_plan
	L.arc_plan = {}
	var looks: Array = planned.get("looks", [])
	if planned.get("id", "") != id:
		for lk in looks:
			Humanoid.unstock(lk)
		looks = _looks(gi, id) if id != "" else []
	if id == "" or v == null:
		for lk in looks:
			Humanoid.unstock(lk)
		return null
	var a := IslandArcs.new()
	a.name = "Arc"
	a.isl = gi
	a.life = L
	a.village = v
	a.arc = id
	a.T = TEMPLATES[id]
	a.key = L.key("arc")
	gi.add_child(a)
	a._setup(looks)
	return a


func _setup(looks: Array) -> void:
	_spots()
	villain_name = _villain_name()
	tok = {"villain": villain_name, "village": isl.island_name, "elder": village.elder_name, "place": str(T["place_name"])}
	for i in range(looks.size()):
		tok["c%d" % i] = str(looks[i]["name"])
	for i in range(looks.size()):
		_contact(i, looks[i])
	var t := IslandContent.tier(isl)
	var steps: Array = []
	for s in T["steps"]:
		steps.append({"do": s["do"], "goal": fill(s["goal"]), "said": fill(s["said"])})
	steps.append({"do": "villain", "goal": fill(T["showdown"]), "said": "%s is finished. Tell %s." % [villain_name, village.elder_name]})
	steps.append({"do": "turnin", "goal": "Tell %s it's over" % village.elder_name})
	def = {"id": key, "title": str(T["title"]), "giver": village.elder_name, "isle": isl.island_name, "pos": isl.position, "src": "arc",
		"steps": steps, "reward": {"gold": 50 + t * 25}}
	Journal.register(def, self)
	village.elder_hooks.append(_elder_talk)
	village.board_hooks.append(_poster)
	if flag("fell"):
		_chests(flag("hidden"))


func _ready() -> void:
	Dialogue.dialogue_event.connect(_on_event)


func fill(s) -> String:
	return LifePools.fill(str(s), tok)


func fill_all(a: Array) -> Array:
	return a.map(func(l): return fill(l))


## The island's places the arc uses (island space).
func _spots() -> void:
	var c: Vector2 = village.plaza["c"]
	spots["village"] = c
	for s in ["camp", "lair", "ruins", "summit", "boss", "dock"]:
		spots[s] = isl.sites[s]
	var camp: Vector2 = isl.sites["camp"]
	var to_v: Vector2 = (c - camp).normalized()
	spots["camp_edge"] = camp + to_v * 15.0 + Vector2(-to_v.y, to_v.x) * 4.0
	spots["road_camp"] = _along(camp, 0.5, 3.0)
	spots["tracks"] = _along(isl.sites["boss"], 0.45, 3.5)
	var path: PackedVector2Array = life._path_to(isl.sites["boss"])
	var cum := KitLife.measure(path)
	spots["village_edge"] = KitLife.sample(path, cum, minf(float(village.plaza["r"]) + EDGE, cum[cum.size() - 1] * 0.6))[0]


## A point `k` of the way along the village's path to `to`, `off` m to its side.
func _along(to: Vector2, k: float, off: float) -> Vector2:
	var path: PackedVector2Array = life._path_to(to)
	var cum := KitLife.measure(path)
	var smp := KitLife.sample(path, cum, cum[cum.size() - 1] * k)
	var d: Vector2 = smp[1]
	return smp[0] + Vector2(-d.y, d.x) * off


func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, isl.hv(p), p.y)


func _villain_name() -> String:
	match str(T["villain"]["kind"]):
		"camp":
			return life._site_name("camp")
		"beast":
			return str(isl.node["beast_name"])
	return str(T["villain"].get("title", "the villain"))


func _contact(i: int, lk: Dictionary) -> void:
	var c: Dictionary = T["contacts"][i]
	var p: Vector2 = spots[c["at"]]
	var face: Vector2 = (spots["village"] - p).normalized()
	var npc := NPC.new()
	npc.name = "Contact%d" % i
	npc.setup({"name": lk["name"], "look": lk, "dialogue": "%s_c%d" % [key, i], "voice": 0.95, "yaw": atan2(-face.x, -face.y)})
	npc.ground_func = isl.walk_height
	add_child(npc)
	npc.position = _v3(p)
	contacts.append(npc)
	var nodes := {"start": {"text": [fill(c["line"])], "choices": []}}
	var choices: Array = nodes["start"]["choices"]
	var m: Dictionary = T.get("moment", {})
	if not m.is_empty() and int(m["contact"]) == i:
		choices.append({"text": "About %s..." % villain_name, "next": "m", "if": func(): return Journal.step_of(key) == int(m["step"]) and not flag("moment")})
		nodes.merge(Replies.nodes(key + ":moment", "m", fill_all(m["lines"]), _replies(m)))
	choices.append({"text": "Goodbye.", "next": "end"})
	Dialogue.define("%s_c%d" % [key, i], {"speaker": lk["name"], "voice": 0.95, "start": "start", "nodes": nodes})


## A moment's replies with their texts filled and any with a price offered only to a captain who has it.
func _replies(m: Dictionary) -> Array:
	var out: Array = []
	for r in m["replies"]:
		var e := {"tone": r["tone"], "text": fill(r["text"]), "answer": fill(r["answer"]), "out": r["out"]}
		if r.has("cost"):
			var cost := int(r["cost"])
			e["if"] = func(): return _gold() >= cost
		out.append(e)
	return out


func _gold() -> int:
	var me := get_tree().get_first_node_in_group("player") as Player
	return me.inventory_component.count("gold") if me else 0


# --------------------------------------------------------------------------
# Beat 1: the elder, the board, the folk
# --------------------------------------------------------------------------
func _elder_talk(choices: Array, nodes: Dictionary) -> void:
	choices.append({"text": "Something's wrong on this island. What is it?", "next": "arc_tell", "if": func(): return not Journal.has(key)})
	nodes["arc_tell"] = {"text": fill_all(T["elder"]), "choices": [
		{"text": "We'll deal with %s." % villain_name, "next": "arc_take"}, {"text": "Not our fight.", "next": "menu"}]}
	nodes["arc_take"] = {"text": ["Thank you, Captain. %s" % fill(T["remind"][0])], "event": "arc:%s:take" % key, "next": "menu"}
	choices.append({"text": "About %s..." % villain_name, "next": "arc_remind",
		"if": func(): return Journal.has(key) and not Journal.is_done(key) and not Journal.at_turnin(key)})
	nodes["arc_remind"] = {"text": fill_all(T["remind"]), "next": "menu"}
	choices.append({"text": "It's over. %s won't trouble you again." % villain_name, "next": "arc_pay", "if": func(): return Journal.at_turnin(key)})
	nodes["arc_pay"] = {"text": fill_all(T["thanks"]) + ["(%s)" % QuestRewards.text(def["reward"])], "event": "arc:%s:pay" % key, "next": "menu"}


func _poster(choices: Array, nodes: Dictionary) -> void:
	choices.append({"text": "WANTED: %s" % villain_name, "next": "arc_poster", "if": func(): return not Journal.has(key)})
	nodes["arc_poster"] = {"text": [fill(T["poster"]), "You tear the poster down and pocket it."], "event": "arc:%s:take" % key, "next": "end"}


## What the island's folk say of it (IslandLife deals them out).
func rumours() -> Array:
	return fill_all(T["rumours"])


# --------------------------------------------------------------------------
# State
# --------------------------------------------------------------------------
func flag(f: String) -> bool:
	return GameManager.world_flags.has("%s_%s" % [key, f])


func set_flag(f: String) -> void:
	Net.world_flag("%s_%s" % [key, f])


## The reply picked at moment `m` (-1: not yet).
func picked(m: String) -> int:
	var n: int = (T[m]["replies"] as Array).size()
	for i in range(n):
		if flag("%s_%d" % [m, i]):
			return i
	return -1


## Every outcome of the replies picked so far.
func outs() -> Array:
	var out: Array = []
	for m in ["meet", "moment"]:
		if T.has(m) and picked(m) >= 0:
			out.append_array(T[m]["replies"][picked(m)]["out"])
	return out


func _out_k(name_: String) -> float:
	var k := 0.0
	for o in outs():
		if str(o).begins_with(name_ + ":"):
			k += float(str(o).get_slice(":", 1))
	return k


func showdown() -> int:
	return (T["steps"] as Array).size()


func _night() -> bool:
	var h: float = Weather.hour()
	return h >= NIGHT_FROM or h < NIGHT_TO


# --------------------------------------------------------------------------
# The villain
# --------------------------------------------------------------------------
func villain() -> Node3D:
	match str(T["villain"]["kind"]):
		"camp":
			var camp := isl.site_node("camp").get_node_or_null("Camp") as GruntCamp
			if camp:
				for g in camp.grunts:
					if is_instance_valid(g) and (g as PirateGrunt).captain:
						return g
		"beast":
			var a := BeastArena.of(isl)
			if a.boss and is_instance_valid(a.boss):
				return a.boss
	return null


## The villain's men (a camp villain's crew, its captain left out).
func men() -> Array:
	if str(T["villain"]["kind"]) != "camp":
		return []
	var camp := isl.site_node("camp").get_node_or_null("Camp") as GruntCamp
	return camp.grunts.filter(func(g): return is_instance_valid(g) and not (g as PirateGrunt).captain) if camp else []


func _alive(n) -> bool:
	return n != null and is_instance_valid(n) and not n.is_dead()


func villain_at() -> Vector3:
	var v := villain()
	return v.global_position if v else to_global(_v3(spots[T["place"]]))


# --------------------------------------------------------------------------
# The world for the state it's in (every machine): squads, waves, things to take
# --------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t -= delta
	_fight_t += delta
	_ask_t += delta
	if _t > 0.0:
		return
	_t = TICK
	if not Journal.has(key) or Journal.is_done(key):
		return
	var step := Journal.step_of(key)
	var n := showdown()
	if step < n:
		var s: Dictionary = T["steps"][step]
		match str(s["do"]):
			"squad":
				_ensure_squad("S%d" % step, spots[s["at"]], int(s["men"]), str(s["look"]))
			"wave":
				if _night() or flag("w%d" % step):
					_ensure_wave("W%d" % step, spots[s["at"]], int(s["bugs"]))
			"pickup":
				_ensure_item(step, s)
	elif step == n:
		if outs().has("raid") and not flag("raid_done") and (_night() or flag("raid_on")):
			_ensure_squad("Raid", spots["village_edge"], 4, "pirate")
		if outs().has("more") and not flag("fell"):
			_ensure_squad("More", spots[T["place"]] + (spots["village"] - spots[T["place"]]).normalized() * 6.0, 2, "pirate")
	for i in range(get_child_count()):
		var it := get_child(i) as Node3D
		if it and it.name.begins_with("Item"):
			it.visible = step == int(str(it.name).substr(4))
			(it.get_node("Take") as Interactable).enabled = it.visible
	if Net.is_host():
		_host(step)


func _ensure_squad(tag: String, at: Vector2, n: int, look: String) -> void:
	if has_node(tag):
		return
	var camp := GruntCamp.new()
	camp.name = tag
	camp.level = IslandContent.level(isl)
	camp.respawn_time = 1.0e9
	camp.warm_start = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([key, tag])
	var face: Vector2 = (spots["village"] - at).normalized() if at.distance_to(spots["village"]) > 1.0 else Vector2(0, 1)
	for i in range(n):
		var q: Vector2 = at + Vector2.from_angle(TAU * i / n + 0.4) * (2.2 + (i % 2) * 1.2)
		var cfg := {"post": _v3(q), "yaw": atan2(-face.x, -face.y), "mode": "stand", "seed": hash([key, tag, i]),
			"role": "rifle" if n > 2 and i == n - 1 else "sword"}
		if look == "marine":
			var lk: Dictionary = CharacterLook.random_look(rng)
			EnemyShip.marine_look(lk, rng, false)
			cfg["look"] = lk
		camp.add_grunt(IslandContent.undead(isl, cfg, i) if look == "pirate" else cfg)
	add_child(camp)


func _ensure_wave(tag: String, at: Vector2, n: int) -> void:
	if has_node(tag):
		return
	var nest := ScuttlebugNest.new()
	nest.name = tag
	nest.level = IslandContent.level(isl)
	nest.respawn_time = 1.0e9
	for i in range(n):
		nest.add_spot(_v3(at + Vector2.from_angle(TAU * i / n) * 5.0), i == 0)
	add_child(nest)


func _ensure_item(step: int, s: Dictionary) -> void:
	if has_node("Item%d" % step):
		return
	var n := Node3D.new()
	n.name = "Item%d" % step
	var mi := MeshInstance3D.new()
	mi.mesh = Props.treasure_chest_mesh()
	mi.scale = Vector3.ONE * 0.8
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 120.0
	n.add_child(mi)
	var it := Interactable.new()
	it.name = "Take"
	it.collision_layer = NPC.INTERACT_LAYER
	it.collision_mask = 0
	it.prompt_text = str(s["search"])
	it.gesture = "pickup"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.4
	cs.shape = sph
	cs.position = Vector3(0, 0.5, 0)
	it.add_child(cs)
	n.add_child(it)
	it.interacted.connect(func(_p): Journal.advance(key, step))
	add_child(n)
	var p: Vector2 = spots[s["at"]]
	n.position = _v3(p)
	n.rotation.y = atan2(p.x - spots["village"].x, p.y - spots["village"].y)


## Cleared once all of it has turned up (a warm-started squad musters over a few frames) and all of it is down.
func _cleared(tag: String) -> bool:
	var n := get_node_or_null(tag)
	if n is GruntCamp:
		return (n as GruntCamp).grunts.size() == (n as GruntCamp).specs.size() and (n as GruntCamp).alive_count() == 0
	if n is ScuttlebugNest:
		return (n as ScuttlebugNest).spots.all(func(s): return s["bug"] != null) and (n as ScuttlebugNest).alive_count() == 0
	return false


# --------------------------------------------------------------------------
# The host's decisions
# --------------------------------------------------------------------------
func _host(step: int) -> void:
	var n := showdown()
	if step < n:
		var s: Dictionary = T["steps"][step]
		match str(s["do"]):
			"squad":
				if _cleared("S%d" % step):
					Journal.advance(key, step)
			"wave":
				if _night() and not flag("w%d" % step):
					set_flag("w%d" % step)
				if _cleared("W%d" % step):
					Journal.advance(key, step)
		return
	if step != n:
		return
	if outs().has("raid") and not flag("raid_done"):
		if _night() and not flag("raid_on"):
			set_flag("raid_on")
		if _cleared("Raid"):
			set_flag("raid_done")
	var v := villain()
	if v == null:
		return
	if not _alive(v):
		if not flag("fell"):
			_fall(v)
		return
	_watch(v)
	if T.has("meet") and not flag("meet"):
		_meet(v)


## The villain's first meeting: the nearest standing captain is spoken to (their machine shows the replies).
func _meet(v: Node3D) -> void:
	if _asking != 0 and _ask_t < ASK_WAIT:
		return
	var best: Node3D = null
	for p in Net.all_players():
		var pp := p as Node3D
		if pp.global_position.distance_to(v.global_position) < MEET_R and p.is_standing() \
				and (best == null or pp.global_position.distance_to(v.global_position) < best.global_position.distance_to(v.global_position)):
			best = pp
	if best == null:
		return
	_asking = _peer_of(best)
	_ask_t = 0.0
	Net.everyone("_all_arc", [Net.key_of(self), "ask", ["meet", _asking]])


func _peer_of(p: Node) -> int:
	for id in Net.players.keys():
		if Net.players[id] == p:
			return int(id)
	return Net.my_id()


func _name_of(peer: int) -> String:
	var p = Net.players.get(peer) if Net.active else get_tree().get_first_node_in_group("player")
	return p.display_name() if p and is_instance_valid(p) else "A captain"


## What the host watches in the showdown for the hidden finish, and the wound a reply dealt (once per villain body).
func _watch(v: Node3D) -> void:
	if _men0 < 0:
		_men0 = men().filter(func(g): return _alive(g)).size()
	if v.in_combat():
		if _woke_t < 0.0:
			_woke_t = _fight_t
		var k := _out_k("wounded")
		if k > 0.0 and not _wounded.has(v.get_instance_id()):
			_wounded.append(v.get_instance_id())
			var h = v.get("health")
			if h is HealthComponent:
				(h as HealthComponent).take_damage((h as HealthComponent).max_health * k)


func _hidden_met(v: Node3D) -> bool:
	match str(T["hidden"]["kind"]):
		"spare_men":
			return _men0 > 0 and men().filter(func(g): return _alive(g)).size() >= _men0
		"parts":
			if v.has_method("parts_broken"):
				return int(v.parts_broken()) >= 2
			return _woke_t >= 0.0 and _fight_t - _woke_t <= QUICK_KILL
	return false


## (host) The villain is down: the arc's chest (and the hidden cache) on every screen, the bounty, the Admiralty.
func _fall(v: Node3D) -> void:
	var hidden := Journal.step_of(key) == showdown() and _men0 >= 0 and _hidden_met(v)
	set_flag("fell")
	if hidden:
		set_flag("hidden")
	var at := villain_at()
	Net.everyone("_all_arc", [Net.key_of(self), "fell", [hidden]])
	Net.bounty("arc", at, 400.0)
	Admiralty.deed(get_tree(), at, "arc")
	# TODO(will): an arc villain is worth 2 Will points (docs/v1_23_previews.md section 2) once the progression agent's Will API lands
	Journal.advance(key, showdown())


# --------------------------------------------------------------------------
# This captain's own part: their dialogue's events, a meeting asked of them
# --------------------------------------------------------------------------
func _on_event(ev: String) -> void:
	if ev.begins_with("arc:%s:" % key):
		match ev.get_slice(":", 2):
			"take":
				Journal.take(key)
			"pay":
				Journal.turn_in(key, (get_tree().get_first_node_in_group("player") as Node3D).global_position)
	elif ev.begins_with("%s%s:" % [Replies.EVENT, key]):
		var parts := ev.split(":")
		Net.arc_ask(Net.key_of(self), "reply", [parts[2], int(parts[3])])


## (host) A captain's word: their reply at a moment ([moment, index]; -1 walked away), or that they couldn't be asked.
func decide(op: String, args: Array, by: int) -> void:
	match op:
		"busy":
			_asking = 0
		"reply":
			var m := str(args[0])
			if not T.has(m) or flag(m):
				return
			var i := int(args[1])
			if i < 0:
				i = int(T[m].get("default", 0))
			if Journal.step_of(key) != (showdown() if m == "meet" else int(T["moment"]["step"])):
				return
			set_flag(m)
			set_flag("%s_%d" % [m, i])
			_asking = 0
			Net.everyone("_all_arc", [Net.key_of(self), "replied", [m, i, _name_of(by)]])
			_outcome(T[m]["replies"][i]["out"], by)


## (host) What a reply does at once (the lasting effects are read from the flags: outs()).
func _outcome(out: Array, by: int) -> void:
	var step := Journal.step_of(key)
	for o in out:
		var s := str(o)
		match s.get_slice(":", 0):
			"pay":
				Net.everyone("_all_arc", [Net.key_of(self), "pay", [by, int(s.get_slice(":", 1))]])
			"settle":
				set_flag("settled")
				Journal.settle(key)
			"hated":
				Net.everyone("_all_arc", [Net.key_of(self), "hated", []])
			"step":
				Journal.advance(key, step)
			"now":
				Journal.jump(key, step, showdown())
			"fight":
				var v := villain()
				if _alive(v):
					v.alert(0.0)


## (every machine) What the host decided.
func apply(op: String, args: Array) -> void:
	match op:
		"ask":
			if int(args[1]) == Net.my_id():
				var v := villain()
				var m: Dictionary = T[str(args[0])]
				if not Replies.open(Dialogue, "%s:%s" % [key, args[0]], villain_name, 0.85, fill_all(m["lines"]), _replies(m), v):
					Net.arc_ask(Net.key_of(self), "busy", [])
		"replied":
			var m := str(args[0])
			var r: Dictionary = _replies(T[m])[int(args[1])]
			var speaker := villain_name if m == "meet" else str(contacts[int(T[m]["contact"])].npc_name)
			var who: Node = villain() if m == "meet" else contacts[int(T[m]["contact"])]
			Replies.shown(get_tree(), str(args[2]), r, speaker, who)
		"pay":
			var me := get_tree().get_first_node_in_group("player") as Player
			if int(args[0]) == Net.my_id() and me:
				me.inventory_component.remove_item(ItemDB.get_item("gold"), int(args[1]))
		"hated":
			for sid in Shops.extra.keys():
				if str(sid).begins_with(life.key("shop")) or sid == isl.save_key("trader"):
					Journal.perks["discount:" + str(sid)] = -0.2
			get_tree().call_group("hud", "show_toast", "%s won't forget that you paid %s. Prices here just went up." % [isl.island_name, villain_name])
		"fell":
			var hidden: bool = args[0]
			get_tree().call_group("hud", "show_banner", "%s: %s falls!" % [T["title"], villain_name],
				("Hidden finish: %s. %s" % [T["hidden"]["name"], T["hidden"]["said"]]) if hidden else "Tell %s it's over." % village.elder_name, true)
			if hidden and str(T["hidden"]["kind"]) == "spare_men":
				for g in men():
					if _alive(g):
						(g as Node).queue_free()
			_chests(hidden)


## The arc's chest by the showdown's place (and the hidden finish's cache), each once per character.
func _chests(hidden: bool) -> void:
	var t := IslandContent.tier(isl)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([key, "chest"])
	var at: Vector2 = spots[T["place"]] + (spots["village"] - spots[T["place"]]).normalized() * 4.0
	if not GameManager.opened.has(isl.save_key("arc_chest")) and not has_node("ArcChest"):
		var bag := isl.strongbox(self, at, 0.0, "arc_chest", [["gold", 80 + t * 40], ["treasure", 3 + t], ["rum", 2],
			[Loot.weapon(WEAPONS[rng.randi() % WEAPONS.size()], mini(t + 1, 5), rng), 1]], 1.3)
		bag.name = "ArcChest"
		FX.sparkle(bag.global_position + Vector3(0, 0.9, 0), 24, Color(1.0, 0.85, 0.4))
	if hidden and not GameManager.opened.has(isl.save_key("arc_cache")) and not has_node("ArcCache"):
		var cache := isl.strongbox(self, at + Vector2(2.2, 0.0), 0.0, "arc_cache", [["gold", 120 + t * 60], ["pearl", 2 + t],
			[Loot.weapon(WEAPONS[rng.randi() % WEAPONS.size()], mini(t + 2, 5), rng), 1]], 1.0)
		cache.name = "ArcCache"
		FX.sparkle(cache.global_position + Vector3(0, 0.9, 0), 30, Color(0.7, 0.9, 1.0))


# --------------------------------------------------------------------------
# The Journal's source: where each step is, and the showdown told as it stands
# --------------------------------------------------------------------------
func target(_q: Dictionary, step: int) -> Vector3:
	var n := showdown()
	if step < n:
		var s: Dictionary = T["steps"][step]
		if str(s["do"]) == "talk":
			return contacts[int(s["contact"])].global_position + Vector3.UP * KitQuests.HEAD
		return to_global(_v3(spots[s["at"]]) + Vector3.UP * 1.5)
	if step == n:
		if outs().has("raid") and not flag("raid_done"):
			return to_global(_v3(spots["village_edge"]) + Vector3.UP * 1.5)
		return villain_at() + Vector3.UP * 2.0
	for p in get_tree().get_nodes_in_group("npcs"):
		if (p as NPC).npc_name == village.elder_name:
			return (p as Node3D).global_position + Vector3.UP * KitQuests.HEAD
	return Vector3.INF


func is_person(q: Dictionary, step: int) -> bool:
	return q["steps"][step]["do"] in ["talk", "turnin"]


func progress(_q: Dictionary, _step: int) -> String:
	return ""


func goal_of(_q: Dictionary, step: int, g: String) -> String:
	var n := showdown()
	if step < n and str(T["steps"][step]["do"]) == "wave" and not _night() and not flag("w%d" % step):
		return g + " (it comes at nightfall)"
	if step == n and outs().has("raid") and not flag("raid_done"):
		return "Hold %s against %s's raid%s, then %s" % [isl.island_name, villain_name, "" if _night() or flag("raid_on") else " tonight", g.to_lower()]
	return g
