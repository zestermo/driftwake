class_name MarineOutpost
extends Node3D
## An Admiralty outpost by a chain village (1.23, docs/v1_23_plan.md "Marine outpost": warn, alarm, raid). A grey
## blockhouse just outside the village: two guards at its door, a barred cell with a prisoner, the Admiralty's flag,
## a locked armoury. Draw a blade in the village and a guard warns you; keep it out, or fight in the village (any swing
## or shot, a duel), and the alarm rings: a squad comes out of the blockhouse (more for a bigger bounty) on every
## screen (Net._all_outpost_alarm; the host runs them, like any camp). Beat the squad and the outpost is raided (a
## world flag, saved): the armoury opens (a weapon a tier up and its pay chest) and the prisoner can be let out for
## a reward. Seeded by the island: CHANCE of villages have one; never the cities.

const CHANCE := 0.4
## From the village's heart, how far a captain counts as "in the village" (past its plaza).
const TOWN_PAD := 34.0
## A blade out this long after the warning (seconds) rings the alarm.
const WARN_HOLD := 8.0
const CHECK := 0.5
## The squad: this many, +1 a bounty tier.
const SQUAD := 3
const ATTACK_STATES := ["LightAttack", "HeavyAttack", "Technique", "Skill", "Plunge", "Aim", "Shoot"]
const GUARD_LINES := ["Keep it sheathed in town, pirate.", "Steel away. The Admiralty keeps the peace here.",
	"Draw that again and you'll meet the whole garrison."]
const ALARM_LINES := ["To arms! A pirate in the village!", "Ring the bell! Turn out the guard!"]

## The island it stands on (any Node3D: 	own is in its space), its loot tier and enemies' level.
var isl: Node3D
var tier := 0
var level := 0
var town: Vector2
var town_r := 0.0
var key := ""
var raided := false
var alarmed := false
var _t := 0.0
var _warned := {}
var _guards: Array = []
var _cell_bars: Node3D
var _prisoner: NPC
var _chest: LootBag
var _camp: GruntCamp


## Whether island `gi` rolls an outpost (data: its spot is found as it's built, so it may still have none).
static func rolls(gi: GenIsland) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(gi.node["seed"]), 5109])
	return not (gi is CapitalIsland or gi.village_plan.is_empty()) and rng.randf() < CHANCE


## The build step (IslandContent): an outpost by the village, if this island rolls one and a spot fits.
static func build(gi: GenIsland) -> void:
	if gi is CapitalIsland or gi.village_plan.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(gi.node["seed"]), 5109])
	if rng.randf() >= CHANCE:
		return
	var p: Dictionary = gi.village_plan
	var c: Vector2 = p["c"]
	var pr: float = p["plaza_r"]
	var spot := Vector2.INF
	var face := Vector2.ZERO
	var a0 := rng.randf() * TAU
	for ring in [pr + 16.0, pr + 22.0, pr + 28.0]:
		for k in range(12):
			var q: Vector2 = c + Vector2.from_angle(a0 + k * TAU / 12.0) * float(ring)
			if _flat_ok(gi, q):
				spot = q
				face = (c - q).normalized()
				break
		if spot != Vector2.INF:
			break
	if spot == Vector2.INF:
		return
	var o := make(gi, c, pr + TOWN_PAD, gi.save_key("outpost"), IslandContent.tier(gi), IslandContent.level(gi), rng)
	o.global_position = gi.to_global(Vector3(spot.x, gi.hv(spot), spot.y))
	o.rotation.y = atan2(face.x, face.y)
	gi.reserve(spot, 8.0)


## An outpost under on (its town at 	own_ in on's space,  round it), saved as key_. Place it after.
static func make(on: Node3D, town_: Vector2, r: float, key_: String, tier_: int, level_: int, rng: RandomNumberGenerator) -> MarineOutpost:
	var o := MarineOutpost.new()
	o.name = "MarineOutpost"
	o.isl = on
	o.town = town_
	o.town_r = r
	o.key = key_
	o.tier = tier_
	o.level = level_
	on.add_child(o)
	o._make(rng)
	return o


static func _flat_ok(gi: GenIsland, q: Vector2) -> bool:
	var h := gi.hv(q)
	if h < 1.5 or gi.excluded(q, 6.0) or gi.path_dist(q) < 3.0:
		return false
	for d in [Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4)]:
		if absf(gi.hv(q + d) - h) > 1.2:
			return false
	return true


func _make(rng: RandomNumberGenerator) -> void:
	add_to_group("outposts")
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick", Color(0.72, 0.74, 0.78))
	var wood := PSXMat.lit("planks_dark")
	var iron := PSXMat.lit("metal", Color(0.45, 0.47, 0.5))
	# the blockhouse (+Z faces the village): walls, a flat roof with merlons, a door
	mb.add_box(stone, Transform3D(Basis(), Vector3(0, 1.7, 0)), Vector3(6.0, 3.4, 5.0))
	for i in range(5):
		for side in [-1.0, 1.0]:
			mb.add_box(stone, Transform3D(Basis(), Vector3(-2.4 + i * 1.2, 3.65, side * 2.35)), Vector3(0.6, 0.5, 0.3))
	mb.add_box(wood, Transform3D(Basis(), Vector3(0.0, 1.1, 2.52)), Vector3(1.2, 2.2, 0.08))
	# the cell, on its side: a stone floor and back, iron bars
	mb.add_box(stone, Transform3D(Basis(), Vector3(4.3, 0.1, 0.0)), Vector3(2.6, 0.2, 3.0))
	mb.add_box(stone, Transform3D(Basis(), Vector3(4.3, 2.5, 0.0)), Vector3(2.6, 0.25, 3.0))
	mb.add_box(stone, Transform3D(Basis(), Vector3(4.3, 1.3, -1.4)), Vector3(2.6, 2.4, 0.25))
	mb.add_box(stone, Transform3D(Basis(), Vector3(5.5, 1.3, 0.0)), Vector3(0.25, 2.4, 3.0))
	var house := mb.to_instance("Blockhouse")
	house.visibility_range_end = 260.0
	add_child(house)
	var body := StaticBody3D.new()
	body.name = "Walls"
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(6.0, 3.4, 5.0)
	cs.shape = bx
	cs.position = Vector3(0, 1.7, 0)
	body.add_child(cs)
	add_child(body)
	var bars := MeshBuilder.new()
	for i in range(9):
		bars.add_cylinder(iron, Transform3D(Basis(), Vector3(3.1 + i * 0.3, 0.2, 1.45)), 0.04, 0.04, 2.2, 5, 1.0)
	_cell_bars = bars.to_instance("CellBars")
	_cell_bars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cell_bars)
	# the Admiralty's flag
	var pole := MeshBuilder.new()
	pole.add_cylinder(iron, Transform3D(Basis(), Vector3(-2.6, 3.4, 2.0)), 0.06, 0.05, 4.0, 5, 1.0)
	pole.add_box(PSXMat.flat(Color(0.34, 0.38, 0.44)), Transform3D(Basis(), Vector3(-2.15, 6.9, 2.0)), Vector3(0.9, 0.55, 0.02))
	pole.add_box(PSXMat.flat(Color(0.75, 0.77, 0.8)), Transform3D(Basis(), Vector3(-2.15, 6.9, 2.0)), Vector3(0.3, 0.3, 0.03))
	var flag := pole.to_instance("Flag")
	flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flag)
	# the guards at the door
	for i in range(2):
		var lk: Dictionary = CharacterLook.random_look(rng)
		EnemyShip.marine_look(lk, rng, false)
		lk["name"] = "Admiralty guard"
		var g := NPC.new().setup({"name": "Admiralty guard", "look": lk, "barks": GUARD_LINES, "voice": 0.9})
		add_child(g)
		g.position = Vector3(-1.3 + i * 2.6, 0.0, 3.4)
		_guards.append(g)
	# the prisoner
	var plk: Dictionary = IslandVillage._villager_look(rng)
	plk["name"] = "Prisoner"
	_prisoner = NPC.new().setup({"name": "Prisoner", "look": plk, "voice": 1.05, "yaw": PI * 0.5,
		"barks": ["They took me for 'harbouring pirates'. I sold a man some rope!", "Get me out of here and I'll make it worth your while."]})
	add_child(_prisoner)
	_prisoner.position = Vector3(4.3, 0.2, 0.0)
	_prisoner.interactable.interacted.connect(_free_prisoner)
	# the armoury: locked until the outpost's raided
	_chest = (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	_chest.name = "Armoury"
	_chest.save_id = key + "_armoury"
	_chest.rolled = true
	_chest.label = "Admiralty armoury"
	var t := tier
	var crng := RandomNumberGenerator.new()
	crng.seed = hash([key, "armoury"])
	var kinds := ["cutlass", "katana", "polearm", "hammer", "greatsword", "pistol"]
	var w := Loot.weapon(str(kinds[crng.randi() % kinds.size()]), mini(t + 1, 4), crng)
	var loot: Array[ItemStack] = []
	for e in [[w, 1], [ItemDB.get_item("gold"), 60 + t * 50]]:
		var st := ItemStack.new()
		st.item = e[0]
		st.quantity = int(e[1])
		loot.append(st)
	_chest.contents = loot
	add_child(_chest)
	_chest.position = Vector3(-2.0, 0.0, 3.0)
	(_chest.get_node("MeshInstance3D") as MeshInstance3D).mesh = Props.treasure_chest_mesh()
	_apply_raided(get_node("/root/GameManager").world_flags.has(key))


func _ready() -> void:
	ActorSleep.add(self)


## ActorSleep: far from every captain it sleeps (its guards and cell with it), never while its squad is out.
func sleep_ok() -> bool:
	return not alarmed or raided


## (every machine) raided: the armoury and the cell open, the guards are gone.
func _apply_raided(on: bool) -> void:
	raided = on
	if _chest:
		_chest.interactable.enabled = on
		_chest.interactable.prompt_text = "Open the armoury" if on else "Locked (the garrison holds the key)"
	if _cell_bars:
		_cell_bars.visible = not on
	if on:
		for g in _guards:
			if is_instance_valid(g):
				g.queue_free()
		_guards.clear()


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < CHECK:
		return
	var dt := _t
	_t = 0.0
	if not raided and get_node("/root/GameManager").world_flags.has(key):
		_apply_raided(true)
	var net := get_node("/root/Net")
	if not net.is_host() or raided:
		return
	if alarmed:
		# the squad beaten: raided, for everyone (saved)
		if _camp and is_instance_valid(_camp) and _camp.alive_count() == 0 and not _camp.grunts.is_empty():
			net.world_flag(key)
			# the sergeant's fall: an Admiralty officer beaten (bounty, and a Will point, for every captain near)
			net.bounty("officer", global_position)
			_apply_raided(true)
			get_tree().call_group("hud", "show_banner", "Outpost raided", "The armoury's open and the cell's unguarded.", true)
		return
	for c in net.all_players():
		var p := c as Player
		if p == null or not is_instance_valid(p) or not _in_town(p):
			continue
		var id := p.get_instance_id()
		if p.armed and not _warned.has(id):
			_warned[id] = 0.0
			_say(GUARD_LINES[randi() % GUARD_LINES.size()])
			continue
		if p.armed:
			_warned[id] = float(_warned[id]) + dt
		var swinging := p.armed and p.current_state_name() in ATTACK_STATES
		if swinging or (p.armed and float(_warned.get(id, 0.0)) >= WARN_HOLD):
			_raise(p)
			return
		if not p.armed and _warned.has(id):
			_warned[id] = 0.0


func _in_town(p: Node3D) -> bool:
	var lp := isl.to_local(p.global_position)
	return Vector2(lp.x, lp.z).distance_to(town) < town_r or p.global_position.distance_to(global_position) < 16.0


## (host) A guard's warning, on every screen (Net._all_outpost_say -> say).
func _say(line: String) -> void:
	var net := get_node("/root/Net")
	net.everyone("_all_outpost_say", [net.key_of(self), line])


## (every machine) a guard calls out: over his head and as a toast.
func say(line: String) -> void:
	get_tree().call_group("hud", "show_toast", "Admiralty guard: \"%s\"" % line)
	if not _guards.is_empty() and is_instance_valid(_guards[0]):
		(_guards[0] as NPC).humanoid.talking = true


## (host) The alarm: a squad for captain `p`'s bounty, on every screen.
func _raise(p: Player) -> void:
	var net := get_node("/root/Net")
	var n := SQUAD + Bounty.heat_tier(p)
	net.everyone("_all_outpost_alarm", [net.key_of(self), n, level, net.key_of(p)])


## (every machine, Net._all_outpost_alarm) the bell: the guards turn out with the squad, the host's grunts after `who`.
func alarm(n: int, level: int, who: Node3D) -> void:
	if alarmed or raided:
		return
	alarmed = true
	get_tree().call_group("hud", "show_toast", "Admiralty guard: \"%s\"" % ALARM_LINES[randi() % ALARM_LINES.size()])
	for g in _guards:
		if is_instance_valid(g):
			g.queue_free()
	_guards.clear()
	var camp := GruntCamp.new()
	camp.name = "Garrison"
	camp.level = level
	camp.respawn_time = 1.0e9
	camp.max_attackers = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([key, "garrison"])
	for i in range(n):
		var lk: Dictionary = CharacterLook.random_look(rng)
		EnemyShip.marine_look(lk, rng, i == 0)
		var cfg := {"post": Vector3(-2.0 + (i % 4) * 1.4, 0.0, 4.0 + (i / 4) * 1.4), "role": "rifle" if i % 3 == 2 else "sword",
			"seed": hash([key, i]), "look": lk, "mode": "stand", "yaw": 0.0}
		if i == 0:
			cfg["captain"] = true
			cfg["title"] = "Outpost Sergeant"
		camp.add_grunt(cfg)
	add_child(camp)
	_camp = camp
	if get_node("/root/Net").is_host():
		_rouse.call_deferred(who)


func _rouse(who: Node3D) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _camp and is_instance_valid(_camp):
		for g in _camp.grunts:
			if is_instance_valid(g):
				g.alert(randf_range(0.0, 0.4))


func _free_prisoner(by: Player) -> void:
	if not raided or by == null:
		return
	var flag := key + "_freed"
	if get_node("/root/GameManager").world_flags.has(flag):
		return
	get_node("/root/Net").world_flag(flag)
	var gold := 40 + tier * 30
	by.inventory_component.add_item(ItemDB.get_item("gold"), gold)
	get_node("/root/Dialogue").say("Prisoner", ["Free! You're a strange sort of pirate. Here, it's all I had hidden: %d gold." % gold], _prisoner, 1.05)
	_prisoner.interactable.enabled = false
