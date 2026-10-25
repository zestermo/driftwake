class_name HarbourVendor
extends RefCounted
## A vendor at the harbour (1.21 piece 6): about half the chain's generated islands (CHANCE) have someone by the
## pier with one of Brinehollow's ship services: a craftsman who does one group of the yard's refits (the hull,
## the guns, the rig, the helm and deck, or the cabin: Tackett's lines and prices, only theirs) or a chandler
## selling the yard's materials. From the island's seed on its own stream, so every crewmate's island has the
## same vendor in the same spot; the refits go through the host like Tackett's (Net.request_upgrade). Planned in
## GenIsland.prepare after the harbour (its ground reserved), built in a finish step.

const Shops := preload("res://scripts/game/shops.gd")
const CHANCE := 0.5
const SALT := 7823
## [title, the yard lines they do ([] = the chandler's shop), their line, barks]
const KINDS := {
	"hull": ["the Caulker", ["armour", "copper"], "Oakum, pitch and plate. I keep the sea outside your hull.",
		["Every hull leaks. Mine just leak less.", "Copper bottom, Captain? The worms hate it."]],
	"guns": ["the Gunsmith", ["guns", "chaser"], "Carriages, breechings, a chaser for the bow. I fit guns.",
		["Mind the powder. And the pipe.", "A gun's only as good as the crew that loads it."]],
	"rig": ["the Sailmaker", ["sails", "nest", "ropes"], "Canvas, cordage and a nest up top. She'll fly.",
		["Wind's free. Canvas isn't.", "Patched sails, patched luck."]],
	"helm": ["the Joiner", ["rudder", "lanterns", "rails"], "Rudders, rails and a lantern or two. The fine work.",
		["Measure twice. Then once more, for luck.", "A good rail's saved more drunks than any rope."]],
	"cabin": ["the Carpenter", ["galley", "chest", "grove"], "Bunks, a galley, a hold, even a tree on deck. I build in.",
		["A dry bunk's worth more than gold at sea.", "I once built a whole galley in a gale."]],
	"chandler": ["the Chandler", [], "Timber, canvas, iron and copper. What a yard needs, cheaper than a yard.",
		["Rope by the fathom, pitch by the pot.", "Nothing here's stolen. Much."]],
}
const FIRST := ["Abner", "Wenna", "Rook", "Isolde", "Garr", "Petra", "Silas", "Nell", "Oskar", "Briony", "Tobin", "Maud"]
const CHANDLER_STOCK := [["timber", 4], ["canvas", 4], ["iron", 4], ["copper", 4]]


## The island's harbour vendor (GenIsland.prepare, worker): {} on about half the islands, or {kind, at, face, seed, look}.
static func plan(gi) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(gi.node["seed"]) + SALT
	if rng.randf() >= CHANCE or gi.harbour == null:
		return {}
	var kinds: Array = KINDS.keys()
	kinds.sort()
	var kind: String = kinds[rng.randi() % kinds.size()]
	var h: GenHarbour = gi.harbour
	# by the pier's root, one side or the other, a few metres up from the water
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	for s: float in [6.0, 9.0, 12.0, 15.0, 4.0, 18.0]:
		for d: float in [4.0, 6.5, 9.0, 2.5]:
			for sd: float in [side, -side]:
				var p: Vector2 = h.at(s * sd, d)
				if _ok(gi, p):
					gi.reserve(p, 2.6)
					return {"kind": kind, "at": p, "face": h.f.out, "seed": rng.randi(), "look": KitStyle.folk_look(KitStyle.of(gi.theme), rng)}
	return {}


static func _ok(gi, p: Vector2) -> bool:
	if gi.hv(p) < 0.9 or gi.excluded(p, 2.2) or gi.path_dist(p) < 1.5:
		return false
	var e := 1.5
	return absf(gi.hv(p + Vector2(e, 0)) - gi.hv(p - Vector2(e, 0))) < 0.9 and absf(gi.hv(p + Vector2(0, e)) - gi.hv(p - Vector2(0, e))) < 0.9


## The bodies prepare makes ahead (GenIsland: with the villagers').
static func looks(gi) -> Array:
	return [] if gi.vendor.is_empty() else [gi.vendor["look"]]


static func steps(gi) -> Array:
	if gi.vendor.is_empty():
		return []
	return [["vendor", func(): build(gi)]]


## The vendor's name: a first name and their trade.
static func name_of(v: Dictionary) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(v["seed"])
	return "%s %s" % [FIRST[rng.randi() % FIRST.size()], KINDS[v["kind"]][0]]


## The dialogue event that opens their yard with only their lines: "shipwright:<name>|<line>,<line>" (GameMenu).
static func yard_event(v: Dictionary) -> String:
	return "shipwright:%s|%s" % [name_of(v).split(" ")[0], ",".join(KINDS[v["kind"]][1])]


static func build(gi) -> void:
	var v: Dictionary = gi.vendor
	var k: Array = KINDS[v["kind"]]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(v["seed"]) + 1
	var p: Vector2 = v["at"]
	var face: Vector2 = v["face"]
	var side := Vector2(-face.y, face.x)
	var site := Node3D.new()
	site.name = "HarbourVendor"
	gi.add_child(site)
	site.position = Vector3(p.x, gi.hv(p), p.y)
	var st := KitStyle.of(gi.theme)
	# their pitch: a crate of the trade's goods, a barrel, a lantern on a post
	gi.place(KitStyle.prop(st, "crate", rng, 0.8), site, p - face * 1.1 + side * 0.9, rng.randf() * TAU, 0.6)
	gi.place(Props.barrel(), site, p - face * 0.9 - side * 1.0, rng.randf() * TAU, 0.5)
	gi.place(Props.lantern_post(), site, p + side * 1.9, atan2(-face.x, -face.y), 0.3)
	var who := name_of(v)
	var cfg := {"name": who, "voice": rng.randf_range(0.85, 1.2), "look": v["look"], "barks": k[3], "yaw": atan2(-face.x, -face.y)}
	if (k[1] as Array).is_empty():
		var id: String = gi.save_key("vendor")
		Shops.extra[id] = {"name": who, "line": str(k[2]), "trade": "grocer", "stock": CHANDLER_STOCK.duplicate(true), "buys": {"loot": 0.6, "ingredient": 0.4}}
		cfg["shop"] = id
	else:
		var did: String = gi.save_key("vendor_talk")
		gi.get_node("/root/Dialogue").define(did, {"speaker": who, "voice": cfg["voice"], "start": "intro", "return": "menu", "nodes": {
			"intro": {"text": [str(k[2])], "next": "menu"},
			"menu": {"text": ["What'll it be, Captain?"], "choices": [
				{"text": "Show me your work.", "next": "yard"},
				{"text": "Goodbye.", "next": "end"}]},
			"yard": {"text": ["Let's have a look at her."], "event": yard_event(v), "next": "end"},
		}})
		cfg["dialogue"] = did
	var npc := NPC.new()
	npc.setup(cfg)
	npc.ground_func = gi.walk_height
	site.add_child(npc)
	npc.global_position = gi.to_global(Vector3(p.x, gi.hv(p), p.y))
