class_name PirateHeld
extends Node3D
## (1.25.5, docs/v1_26_plan.md "Pirate-held villages"; how often is assumed, not previewed) Now and then (CHANCE of
## the islands whose village could be the ruins layout) the old village is held by pirates: VillageLayouts builds it as
## its "ruins" (broken houses round a broken square, the survivors and the services in a hamlet nearer the shore), and
## instead of the bugs: a garrison in the streets with riflemen on roof decks over the ruins (ladders up, stacked crates
## to climb), jolly flags, a fire in the square, townsfolk tied to posts to free (each a lead against the island's arc:
## IslandArcs.freed), and their captain, a captain-style AI (Player.spawn_ai through Net._all_spawn_rival, the rival
## crews' slower pace and more health) who comes out when a captain walks into the square.
## Plan as data in VillageLayouts (the worker), built here on the main thread. Freed townsfolk and the captain's fall are
## world flags under the island's save keys (the host's word), so a guest and a late joiner see the same.

const CHANCE := 1.0 / 6.0
const ROOFS := 3
const CAPTIVES := 4
const DECK_H := 2.9
## A captain this close (m) to the square brings their captain out; everyone this far off for GONE_S sends him back in.
const WAKE_R := 26.0
const GONE_R := 90.0
const GONE_S := 20.0
const PACE := 1.6
const HP_K := 1.6 * 1.8
const SKILL := 0.6
const WEAPONS := ["cutlass", "boarding_axe", "greatsword", "katana", "warhammer"]
const CAPTAINS := ["Redhand", "Saltjaw", "Grimm", "Cutter", "Black Moll", "Hook-Eye"]
const TICK := 0.5
## Tools and tests: every island that can be is held (true), or none (false, the default: the roll).
static var force := false

var isl
var plan: Dictionary
var garrison: GruntCamp
var captives: Array = []
var captain: Player
var _t := 0.0
var _empty := 0.0


## (worker) Whether an island's village is held (its own stream).
static func rolls(gi) -> bool:
	return force or roll_seed(int(gi.node["seed"]))


static func roll_seed(seed_: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_, 5160])
	return rng.randf() < CHANCE


## (worker, VillageLayouts._ruins) The held village's pieces from its ruined houses: roof decks over the ROOFS nearest
## the square, crates stacked by two more, captives' posts by the rest, the garrison's posts round the square.
static func plan_for(L, ruins: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(L.gi.node["seed"]), 5161])
	var c: Vector2 = L.site
	var order := ruins.duplicate()
	order.sort_custom(func(a, b): return (a["p"] as Vector2).distance_to(c) < (b["p"] as Vector2).distance_to(c))
	var roofs: Array = []
	var stacks: Array = []
	var posts: Array = []
	for b in order:
		var f: Vector2 = b["face"]
		var s := Vector2(-f.y, f.x)
		if roofs.size() < ROOFS:
			roofs.append({"p": b["p"], "face": f, "w": float(b["w"]) + 0.6, "d": float(b["d"]) + 0.6, "r": maxf(float(b["w"]), float(b["d"])) * 0.6})
			if stacks.size() < 2:
				stacks.append({"p": (b["p"] as Vector2) + s * (float(b["w"]) * 0.5 + 0.95) + f * 0.6, "yaw": KitContext.face_yaw(f), "along": -f, "seed": rng.randi()})
		elif posts.size() < CAPTIVES:
			var lk := IslandVillage._villager_look(rng)
			var firsts: Array = LifePools.of(L.gi.theme)["first"]
			lk["name"] = "Captive %s" % str(firsts[rng.randi() % firsts.size()])
			# (their bodies built here on the worker, as IslandLife's people are)
			var hm := Humanoid.new()
			hm.setup(lk)
			Humanoid.stock(hm, lk)
			posts.append({"p": (b["p"] as Vector2) + f * (float(b["d"]) * 0.5 + 1.6) + s * rng.randf_range(-1.0, 1.0), "face": f, "look": lk})
	var guards: Array = []
	for k in range(5):
		var a := TAU * k / 5.0 + rng.randf_range(-0.2, 0.2)
		guards.append(c + Vector2.from_angle(a) * rng.randf_range(6.0, 10.0))
	return {"c": c, "roofs": roofs, "stacks": stacks, "captives": posts, "guards": guards, "seed": rng.randi()}


## (main thread, IslandVillage.steps) The held village built from its plan, under the village, a piece a step: the
## decks and the garrison, the square's dressing, each captive.
static func steps(gi) -> Array:
	var p: Dictionary = gi.village_plan["extra"]["held"]
	var out: Array = [["village held", func():
		var v = gi.get_node("Site_village/Village")
		build(v, v.ctx, p)]]
	out.append(["village held", func():
		var v = gi.get_node("Site_village/Village")
		(v.get_node("Held") as PirateHeld)._dress(v.ctx)])
	for k in range(p["captives"].size()):
		out.append(["village held", func():
			var v = gi.get_node("Site_village/Village")
			var e: Dictionary = p["captives"][k]
			(v.get_node("Held") as PirateHeld)._captive(v.ctx, k, e["p"], e["face"], e["look"])])
	return out


static func build(v, ctx: KitContext, p: Dictionary) -> PirateHeld:
	var h := PirateHeld.new()
	h.name = "Held"
	h.isl = v.isl
	h.plan = p
	v.add_child(h)
	var st: Dictionary = ctx.style
	var lv := IslandContent.level(v.isl)
	h.garrison = GruntCamp.new()
	h.garrison.name = "Garrison"
	h.garrison.respawn_time = 1.0e9
	h.garrison.warm_start = true
	h.garrison.level = lv
	var c: Vector2 = p["c"]
	for i in range(p["roofs"].size()):
		var r: Dictionary = p["roofs"][i]
		var y := ctx.ground_max(r["p"], r["r"]) + DECK_H
		var low := ctx.ground_min(r["p"], r["r"])
		var deck := roof_deck(float(r["w"]), float(r["d"]), y - low, "RoofDeck%d" % i)
		ctx.put(deck, Vector3(r["p"].x, low, r["p"].y), KitContext.face_yaw(r["face"]))
		var post := deck.to_global(Vector3(0, y - low, -0.3))
		h.garrison.add_grunt(IslandContent.undead(v.isl, {"post": h.garrison_local(post), "yaw": KitContext.face_yaw(c - (r["p"] as Vector2)), "mode": "stand",
			"seed": hash([int(p["seed"]), "roof", i]), "role": "rifle"}, 40 + i))
	# crates stacked by the first decks' sides: a scramble up besides the ladder
	for i in range(p["stacks"].size()):
		var s: Dictionary = p["stacks"][i]
		var srng := KitVillage._seeded(int(s["seed"]))
		var along: Vector2 = s["along"]
		for k in range(3):
			var cr := KitStyle.prop(st, "crate", srng, 0.9)
			ctx.place(cr, (s["p"] as Vector2) + along * (0.0 if k == 0 else 0.95), float(s["yaw"]), 0.0, 0.9 if k == 2 else 0.0, false)
	for i in range(p["guards"].size()):
		var g: Vector2 = p["guards"][i]
		var gp := h.garrison_local(Vector3(g.x, ctx.hv(g), g.y), true)
		var mid: Vector2 = c + (g - c) * 0.4
		h.garrison.add_grunt(IslandContent.undead(v.isl, {"post": gp, "yaw": KitContext.face_yaw(c - g), "mode": "patrol" if i % 2 == 0 else "stand",
			"patrol": [gp, h.garrison_local(Vector3(mid.x, ctx.hv(mid), mid.y), true)] if i % 2 == 0 else [],
			"seed": hash([int(p["seed"]), "guard", i]), "role": "rifle" if i == 4 else "sword"}, 50 + i))
	h.add_child(h.garrison)
	return h


## The square: a fire, flags on poles, barrels of loot.
func _dress(ctx: KitContext) -> void:
	var p := plan
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p["seed"])
	var st: Dictionary = ctx.style
	var c: Vector2 = p["c"]
	IslandContent._fire(isl, isl.site_node("village"), c + Vector2(1.5, 1.5))
	var jolly := HullBuilder.jolly_material()
	for k in range(2):
		var fp := c + Vector2.from_angle(TAU * k / 2.0 + 0.7) * 9.0
		var mb := MeshBuilder.new()
		mb.add_cylinder(PSXMat.lit("bark"), Transform3D.IDENTITY, 0.08, 0.06, 5.5, 5, 1.0)
		mb.add_card(jolly, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.01, 5.0, 0.6)), 0.9, 0.55, Rect2(0, 0, 1, 1))
		mb.add_card(jolly, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-0.01, 5.0, 0.6)), 0.9, 0.55, Rect2(0, 0, 1, 1))
		var flag := mb.to_instance("HeldFlag%d" % k)
		flag.visibility_range_end = 220.0
		ctx.place(flag, fp, 0.3)
	for k in range(3):
		var bp := c + Vector2.from_angle(1.9 + k * 0.4) * 5.0
		ctx.place(KitStyle.prop(st, "barrel", rng), bp, rng.randf() * TAU)


func _ready() -> void:
	add_to_group("pirate_held")


## A point (world, or island space when `isl_space`) as the garrison's own local post (it sits at this node's origin).
func garrison_local(q: Vector3, isl_space := false) -> Vector3:
	return to_local(isl.to_global(q) if isl_space else q)


## A timber deck on four posts over a ruin (`h` over its origin, at the lowest ground), a rail round three sides, a
## ladder up its open front (+Z).
static func roof_deck(w: float, d: float, h: float, nm: String) -> StaticBody3D:
	var body := KitHouses._body(nm)
	var mb := MeshBuilder.new()
	var deck := PSXMat.lit("planks_weathered")
	var post := PSXMat.lit("planks_dark")
	mb.add_box(deck, KitHouses._xf(Vector3(0, h - 0.08, 0)), Vector3(w, 0.16, d), 0.5, Color.WHITE, false)
	KitHouses._box(body, Vector3(w, 0.16, d), Vector3(0, h - 0.08, 0))
	for x in [-w * 0.5 + 0.1, w * 0.5 - 0.1]:
		for z in [-d * 0.5 + 0.1, d * 0.5 - 0.1]:
			mb.add_box(post, KitHouses._xf(Vector3(x, h * 0.5, z)), Vector3(0.18, h, 0.18), 0.5)
			KitHouses._box(body, Vector3(0.2, h, 0.2), Vector3(x, h * 0.5, z))
	for e in [[Vector3(0, 0, -d * 0.5), Vector3(w, 0, 0.08)], [Vector3(-w * 0.5, 0, 0), Vector3(0.08, 0, d)], [Vector3(w * 0.5, 0, 0), Vector3(0.08, 0, d)]]:
		var at: Vector3 = e[0]
		var sz: Vector3 = e[1]
		mb.add_box(post, KitHouses._xf(at + Vector3(0, h + 0.85, 0)), Vector3(sz.x, 0.08, sz.z), 0.5)
		mb.add_box(post, KitHouses._xf(at + Vector3(0, h + 0.42, 0)), Vector3(sz.x, 0.06, sz.z), 0.5)
		KitHouses._box(body, Vector3(maxf(sz.x, 0.12), 0.9, maxf(sz.z, 0.12)), at + Vector3(0, h + 0.45, 0))
	var mi := mb.to_instance()
	mi.visibility_range_end = 240.0
	body.add_child(mi)
	var lad := Ladder.new()
	lad.name = "Ladder"
	lad.length = h - 0.2
	lad.position = Vector3(w * 0.25, h, d * 0.5)
	body.add_child(lad)
	return body


func _captive(ctx: KitContext, k: int, p: Vector2, face: Vector2, lk: Dictionary) -> void:
	var mb := MeshBuilder.new()
	mb.add_cylinder(PSXMat.lit("bark"), Transform3D.IDENTITY, 0.1, 0.09, 1.9, 6, 1.0)
	mb.add_cylinder(PSXMat.lit("rope"), Transform3D(Basis(), Vector3(0, 0.9, 0)), 0.14, 0.14, 0.2, 6, 1.0)
	var pole := mb.to_instance("CaptivePost%d" % k)
	ctx.place(pole, p - face * 0.35, 0.0)
	var npc := NPC.new()
	npc.setup({"name": lk["name"], "look": lk, "barks": ["Untie me, quick!", "Please, before they come back!", "They took everything..."], "voice": 1.0, "yaw": KitContext.face_yaw(face), "scenery": true})
	npc.name = "Captive%d" % k
	npc.ground_func = isl.walk_height
	add_child(npc)
	npc.global_position = isl.to_global(Vector3(p.x, isl.hv(p), p.y))
	var it := Interactable.new()
	it.name = "Free"
	it.collision_layer = NPC.INTERACT_LAYER
	it.collision_mask = 0
	it.prompt_text = "Free %s" % lk["name"].trim_prefix("Captive ")
	it.gesture = "pickup"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.5
	cs.shape = sph
	cs.position = Vector3(0, 0.9, 0)
	it.add_child(cs)
	npc.add_child(it)
	var kk := k
	it.interacted.connect(func(_p): Net.arc_ask(Net.key_of(self), "free", [kk]))
	captives.append(npc)


func freed_flag(k: int) -> String:
	return isl.save_key("held_freed%d" % k)


func is_freed(k: int) -> bool:
	return GameManager.world_flags.has(freed_flag(k))


func captain_down() -> bool:
	return GameManager.world_flags.has(isl.save_key("held_captain"))


## How many leads the held village has given: each captive freed, its captain down.
func leads() -> int:
	return range(captives.size()).filter(func(k): return is_freed(k)).size() + (1 if captain_down() else 0)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	for k in range(captives.size()):
		var npc := captives[k] as NPC
		if _walk.has(k):
			_walk_on(k, npc)
		elif is_freed(k) and not npc.away:
			npc.set_away(true)
			(npc.get_node("Free") as Interactable).enabled = false
	if Net.is_host():
		_host()


## (host) Their captain comes out for a captain in the square, goes back in once everyone's left.
func _host() -> void:
	if captain_down():
		return
	var c: Vector3 = isl.to_global(Vector3(plan["c"].x, isl.hv(plan["c"]), plan["c"].y))
	var near: Player = null
	var nd := INF
	for pl in Net.all_players():
		var d := (pl as Node3D).global_position.distance_to(c)
		if d < nd:
			nd = d
			near = pl
	if captain == null or not is_instance_valid(captain):
		if near and nd < WAKE_R:
			_spawn_captain(near, c)
		return
	_empty = 0.0 if nd < GONE_R else _empty + TICK
	if _empty >= GONE_S:
		Net.everyone("_all_arc", [Net.key_of(self), "gone", []])


func _captain_look() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), 5162])
	var lk := PirateGrunt.crew_look(rng)
	var C := CharacterLook.CLOTH
	lk.merge({"build": "broad", "height": 1.1, "hat": ["tricorn", "bicorne"][rng.randi() % 2], "coat": "longcoat", "coat_color": C[rng.randi() % C.size()],
		"trim_color": CharacterLook.TRIM[rng.randi() % CharacterLook.TRIM.size()], "marks": "scar"}, true)
	lk["name"] = "Captain " + CAPTAINS[rng.randi() % CAPTAINS.size()]
	return lk


func _spawn_captain(near: Player, c: Vector3) -> void:
	var lk := _captain_look()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), 5163])
	var at := c + Vector3(0, 0.5, 0)
	var yaw := atan2(near.global_position.x - at.x, near.global_position.z - at.z)
	Net.everyone("_all_spawn_rival", [Net.key_of(self), "HeldCaptain", lk, WEAPONS[rng.randi() % WEAPONS.size()], at, yaw, SKILL])
	captain = get_node_or_null("HeldCaptain") as Player
	var brain = captain.get_node("Brain")
	brain.order = "fight"
	brain.target = near
	brain.pace = PACE
	captain.hp_k = HP_K * (1.0 + 0.15 * IslandContent.tier(isl))
	captain._recalc_stats()
	captain.health_component.current_health = captain.health_component.max_health
	captain.defeated.connect(func():
		Net.world_flag(isl.save_key("held_captain"))
		Net.everyone("_all_arc", [Net.key_of(self), "captain_down", []]))
	Net.everyone("_all_arc", [Net.key_of(self), "captain_out", [str(lk["name"])]])


## (every machine, 1.26) A freed captive thanks you over their head and hurries off towards the survivors' hamlet:
## across the square and on until they're past its edge (WALK_OFF m), then they're gone for good
## (the world flag keeps them gone on a reload or for a late joiner).
const THANKS := ["Thank you! I won't forget this!", "Bless you, captain. I'm going home!", "Free... I'm free! Thank you!",
	"I owe you my life. The others are by the shore, I'll tell them!"]
const WALK_OFF := 30.0
const WALK_SPEED := 2.2
const WALK_MAX_S := 40.0
var _walk := {}


func _go_home(k: int, npc: NPC) -> void:
	if _walk.has(k):
		return
	# (a guest's world flag can land a tick before this: they were put away unseen)
	npc.set_away(false)
	(npc.get_node("Free") as Interactable).enabled = false
	FX.speech(npc, THANKS[k % THANKS.size()], npc.voice)
	var v = get_parent()
	var c: Vector2 = plan["c"]
	var home: Vector2 = c + Vector2(0, 1)
	for hm in v.hamlets:
		if hm["kind"] == "survivors":
			home = hm["c"]
	var dir := (home - c).normalized()
	npc.reparent(isl)
	var route: Array = [c + dir * 8.0, c + dir * WALK_OFF]
	npc.walk_speed = WALK_SPEED
	npc.set("_player", null)
	_walk[k] = {"route": route.map(func(p: Vector2): return Vector3(p.x, isl.hv(p), p.y)), "t": 0.0}
	_next_leg(npc, _walk[k])


func _next_leg(npc: NPC, w: Dictionary) -> void:
	npc.waypoints = [w["route"].pop_front()]
	npc.set("_wp_index", 0)
	npc.set("_pause", 0.0)


func _walk_on(k: int, npc: NPC) -> void:
	var w: Dictionary = _walk[k]
	w["t"] += TICK
	npc.set("_player", null)
	var to: Vector3 = npc.waypoints[0]
	if Vector2(to.x - npc.position.x, to.z - npc.position.z).length() > 0.6 and w["t"] < WALK_MAX_S:
		return
	if not (w["route"] as Array).is_empty() and w["t"] < WALK_MAX_S:
		_next_leg(npc, w)
		return
	_walk.erase(k)
	npc.waypoints = []
	npc.set_away(true)


## (host) A captive's freeing asked for.
func decide(op: String, args: Array, _by: int) -> void:
	if op == "free" and not is_freed(int(args[0])):
		Net.world_flag(freed_flag(int(args[0])))
		Net.everyone("_all_arc", [Net.key_of(self), "freed", [int(args[0])]])


## (every machine)
func apply(op: String, args: Array) -> void:
	match op:
		"freed":
			var npc := captives[int(args[0])] as NPC
			get_tree().call_group("hud", "show_toast", "%s is free! (%d of %d)" % [npc.npc_name.trim_prefix("Captive "),
				range(captives.size()).filter(func(k): return is_freed(k)).size(), captives.size()])
			_go_home(int(args[0]), npc)
		"captain_out":
			get_tree().call_group("hud", "show_banner", str(args[0]), "\"Who let you into MY village?\"", true)
		"captain_down":
			get_tree().call_group("hud", "show_banner", "The village is free", "Its pirate captain is beaten. The rest of them won't hold it long.", true)
			for g in garrison.grunts:
				if is_instance_valid(g) and not g.is_dead():
					(g as Node).queue_free()
			var cap := get_node_or_null("HeldCaptain")
			if cap:
				cap.queue_free()
		"gone":
			var cap := get_node_or_null("HeldCaptain")
			if cap:
				cap.queue_free()
			captain = null
			_empty = 0.0
