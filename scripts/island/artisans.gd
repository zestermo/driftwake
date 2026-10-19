class_name Artisans
extends RefCounted
## Artisans in the wilds (v1.18): now and then (CHANCE) a generated island has someone camped by one of its
## trails, well away from the village and the dock: a fisher, a herbalist, a wandering smith, a weaver or a
## trapper, with a fire, a tent, a crate of wares and a few simple goods to sell (and what they'll buy).
## All from the island's seed on its own stream (nothing else on the island draws differently), so every
## crewmate's island has the same artisan in the same spot; nothing is guaranteed. Planned in
## GenIsland.prepare before the plants (the camp's ground is reserved), built in a finish step.

const Shops := preload("res://scripts/game/shops.gd")
const CHANCE := 0.45
const SALT := 7717
## [title, line, goods (stock entries the wares are picked from), how many, what they buy, barks]
const KINDS := {
	"fisher": ["the Fisher", "Caught this morning. Most of it, anyway.",
		[["fish"], ["crab_meat"], ["seaweed"], ["oyster"], ["salt"], ["sea_urchin"]], 3, {"ingredient": 0.5, "consumable": 0.4},
		["Fish are biting. Not the big ones.", "Salt your catch or lose it."]],
	"herbalist": ["the Herbalist", "Roots, caps and berries. I know which ones won't kill you.",
		[["mushroom"], ["jungle_fruit"], ["pepper"], ["tonic"], ["coconut"]], 3, {"ingredient": 0.5},
		["Mind where you step. That one's poison.", "The forest feeds you, if you ask nicely."]],
	"smith": ["the Wandering Smith", "A forge on my back and a blade or two for sale.",
		[["hatchet"], ["hunting_hanger"], ["dagger"], ["stiletto"], ["cutlass"], ["main_gauche"], ["pistol"]], 2, {"weapon": 0.5},
		["Every island needs a smith. None of them want one.", "Good steel, fair price. Fair-ish."]],
	"weaver": ["the Weaver", "Spun and stitched by this fire.",
		[["accessory", "scarf", {"scarf": true, "scarf_color": Color(0.8, 0.62, 0.2)}, 0],
			["head", "bandana", {"hat": "bandana", "hat_color": Color(0.24, 0.42, 0.3)}, 0],
			["feet", "sandals", {"feet": "sandals", "feet_color": Color(0.4, 0.26, 0.14)}, 0],
			["belt", "sash", {"belt": "sash", "sash_color": Color(0.36, 0.2, 0.44)}, 0],
			["head", "headband", {"hat": "headband", "hat_color": Color(0.66, 0.14, 0.12)}, 0],
			["accessory", "necklace", {"necklace": true}, 0]], 3, {"gear": 0.5},
		["Wool from goats you'll never meet.", "Sit a while. The needle's slow."]],
	"trapper": ["the Trapper", "Meat, eggs and hides. Fresh as the morning.",
		[["boar_haunch"], ["egg"], ["plume"], ["snakeskin"], ["tusk"]], 3, {"loot": 0.6, "ingredient": 0.5},
		["Snares out all night. Something always walks in.", "Keep off the game trails after dark."]],
}
const FIRST := ["Odo", "Mira", "Hask", "Tamsin", "Brin", "Yeva", "Corm", "Lio", "Sefa", "Dunn", "Rhea", "Pell"]


## Where the island's artisan camps (GenIsland.prepare, worker): {} on most islands, or {kind, at, face, seed}.
static func plan(gi) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(gi.node["seed"]) + SALT
	if rng.randf() >= CHANCE:
		return {}
	var kinds: Array = KINDS.keys()
	kinds.sort()
	var kind: String = kinds[rng.randi() % kinds.size()]
	var v: Vector2 = gi.sites["village"]
	var cands: Array = []
	for path in gi.paths:
		for i in range(2, path.size() - 2, 3):
			var q: Vector2 = path[i]
			if q.distance_to(v) > 45.0 and q.distance_to(gi.dock_shore) > 35.0:
				cands.append([q, (path[i + 1] - path[i - 1]).normalized()])
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = cands[i]
		cands[i] = cands[j]
		cands[j] = t
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	for c in cands.slice(0, 60):
		var q: Vector2 = c[0]
		var d: Vector2 = c[1]
		var p: Vector2 = q + Vector2(-d.y, d.x) * side * 5.0
		if _ok(gi, p):
			gi.reserve(p, 6.0)
			# (their body is made in prepare with the villagers', from this look: Humanoid.stock)
			return {"kind": kind, "at": p, "face": (q - p).normalized(), "seed": rng.randi(), "look": KitStyle.folk_look(KitStyle.of(gi.theme), rng)}
	return {}


## The bodies prepare makes ahead (GenIsland: with the villagers').
static func looks(gi) -> Array:
	return [] if gi.artisan.is_empty() else [gi.artisan["look"]]


static func _ok(gi, p: Vector2) -> bool:
	if gi.hv(p) < 1.5 or gi.excluded(p, 5.0) or gi.path_dist(p) < 2.0:
		return false
	for s in gi.sites.values():
		if (s as Vector2).distance_to(p) < 22.0:
			return false
	var e := 2.5
	return absf(gi.hv(p + Vector2(e, 0)) - gi.hv(p - Vector2(e, 0))) < 1.2 and absf(gi.hv(p + Vector2(0, e)) - gi.hv(p - Vector2(0, e))) < 1.2


static func steps(gi) -> Array:
	if gi.artisan.is_empty():
		return []
	return [["artisan", func(): build(gi)]]


## The shop's id in Shops.extra (the island's).
static func shop_id(gi) -> String:
	return gi.save_key("artisan")


## Their wares: `n` of the kind's goods, picked from the camp's seed.
static func stock_of(kind: String, rng: RandomNumberGenerator) -> Array:
	var goods: Array = (KINDS[kind][2] as Array).duplicate()
	var out: Array = []
	for i in range(int(KINDS[kind][3])):
		out.append(goods.pop_at(rng.randi() % goods.size()))
	return out


static func build(gi) -> void:
	var a: Dictionary = gi.artisan
	var kind: String = a["kind"]
	var k: Array = KINDS[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(a["seed"])
	var p: Vector2 = a["at"]
	var face: Vector2 = a["face"]
	var side := Vector2(-face.y, face.x)
	var site := Node3D.new()
	site.name = "Artisan"
	gi.add_child(site)
	site.position = Vector3(p.x, gi.hv(p), p.y)
	var fire_p := p + face * 1.9
	var fire := Props.campfire()
	gi.place(fire, site, fire_p, 0.0, 1.2)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = load("res://assets/audio/campfire_loop.wav")
	snd.unit_size = 4.0
	snd.max_distance = 30.0
	snd.volume_db = -6.0
	snd.autoplay = true
	snd.bus = "Ambience"
	fire.add_child(snd)
	var st := KitStyle.of(gi.theme)
	var tent_p := p - face * 2.8 + side * 0.6
	gi.place(KitCamps.tent(st["tent"]), site, tent_p, atan2(-(fire_p - tent_p).x, -(fire_p - tent_p).y), 2.0)
	var crate := KitStyle.prop(st, "crate", rng, 0.8)
	gi.place(crate, site, p + side * 1.4, rng.randf() * TAU, 0.6)
	var seat := KitCamps.log_seat()
	gi.place(seat, site, fire_p - side * 1.6, atan2(-face.x, -face.y) + PI * 0.5)
	var who := "%s %s" % [FIRST[rng.randi() % FIRST.size()], k[0]]
	var id := shop_id(gi)
	Shops.extra[id] = {"name": who, "line": str(k[1]), "trade": "artisan", "stock": stock_of(kind, rng), "buys": k[4]}
	var npc := NPC.new()
	npc.setup({"name": who, "voice": rng.randf_range(0.85, 1.2), "shop": id, "look": a["look"],
		"barks": k[5], "yaw": atan2(-face.x, -face.y)})
	npc.ground_func = gi.walk_height
	site.add_child(npc)
	npc.global_position = gi.to_global(Vector3(p.x, gi.hv(p), p.y))
