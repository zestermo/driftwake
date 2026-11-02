class_name BigShip
extends EnemyShip
## The big named ships (docs/v1_28_plan.md, The sea): a pirate warlord's flagship ("flagship") and an Admiralty
## lieutenant's warship ("warship"), the sloop's hull and rig drawn K times as big (the body, its collision, guns,
## ladders and rail scale with it; her men are drawn at their own size). Cannons, board, duel: she comes for the crew
## and trades double broadsides (she never boards or rams); board her (her ladders, or "Swing aboard" from a deck
## alongside) and her crew fights across her decks; once most of them are down her captain steps out on the
## quarterdeck (a cutscene, Cutscene "sea_captain") and duels the boarders (an AI captain, RivalDuel.build). Beaten,
## the captain yields: she strikes, and the captain's chest is rich (gold, treasure, a fine weapon, gear, blueprints,
## parts, salvage) and the bounty and XP big. Sunk from afar she leaves only flotsam. Fleeing is allowed (she gives up
## past her sight like any other). Co-op: the host sails her and runs the duel; the captain and the cutscene reach
## every screen through Net.everyone.

const K := 1.5
const NAMES := {
	"flagship": ["Gorran Vesk", "Red Maelis", "Brannoc Ironwake", "Sable Huxley", "Old Thessaly Crane"],
	"warship": ["Lieutenant Corwin Hale", "Lieutenant Ada Strand", "Lieutenant Mattias Crewe", "Lieutenant Isolde Varr"],
}
const SHIP_NAMES := {
	"flagship": ["the Red Maw", "the Widowmaker", "the Iron Gull", "the Gallows Queen"],
	"warship": ["the Steadfast", "the Resolute", "the Lawbringer", "the Unbending"],
}
const LINES := {
	"flagship": ["You climbed aboard my ship. Brave. Now climb off it in pieces.",
		"My crew's on the deck at your feet. I'll make you room beside them.",
		"Every ship on this sea pays me. You'll pay in full."],
	"warship": ["By the Admiralty's warrant, you're under arrest. Resist, and I'll write 'killed resisting'.",
		"Your bounty's posted on my cabin wall. I've been looking forward to this.",
		"Strike your colours and come quietly. No? Good."],
}
const YIELD := {"flagship": "Enough! Take the chest and get off my ship!", "warship": "I yield... the warrant can wait."}
const WEAPONS := {"flagship": ["boarding_axe", "greatsword", "warhammer", "cutlass"], "warship": ["naval_sabre", "katana", "spear", "cutlass"]}
## Her captain steps out once her deck crew is down to this many, or this long after you board.
const CAPTAIN_AT := 2
const CAPTAIN_AFTER := 25.0
## The captain's health over a rival captain's, and how hard taking her raises the bounty (x Bounty.TABLE).
const CAPTAIN_HP := 3.5
const BOUNTY_K := 3.0
## "Swing aboard": from a deck alongside, within this of her rail.
const SWING_R := 7.0

var captain_name := ""
var ship_name := ""
## The captain: "" not out yet, "out" (cutscene), "duel", "beaten".
var duel := ""
var captain: Player
var _deck_t := 0.0
var _yield_t := -1.0


func setup_big(center: Vector3, seed_value: int, kind_name: String, lvl: int) -> BigShip:
	setup(center, 70.0, float(seed_value % 628) * 0.01, seed_value, kind_name)
	level = lvl
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "captain"])
	captain_name = str(NAMES[kind_name][rng.randi() % NAMES[kind_name].size()])
	ship_name = str(SHIP_NAMES[kind_name][rng.randi() % SHIP_NAMES[kind_name].size()]).capitalize()
	set_meta("title", "%s (%s)" % [ship_name, captain_name])
	return self


func _ready() -> void:
	super._ready()
	add_to_group("big_ships")
	for c in _crew:
		(c["node"] as Node3D).scale = Vector3.ONE / K
	for sgn in [-1.0, 1.0]:
		var it := Interactable.new()
		it.name = "Swing%s" % ("S" if sgn > 0.0 else "P")
		it.collision_layer = 512
		it.collision_mask = 0
		it.prompt_text = "Swing aboard"
		it.usable_in_water = true
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = SWING_R / K
		cs.shape = sph
		it.add_child(cs)
		it.position = Vector3(sgn * (HullLayout.HALF_BEAM + SWING_R / K * 0.6), HullLayout.DECK_Y, -1.0)
		add_child(it)
		it.interacted.connect(_swing_aboard.bind(sgn))
	global_transform = Transform3D(global_transform.basis.orthonormalized() * Basis.from_scale(Vector3.ONE * K), global_transform.origin)


func _place_hull(xf: Transform3D) -> void:
	super._place_hull(Transform3D(xf.basis * Basis.from_scale(Vector3.ONE * K), xf.origin))


## Battered under this share of her hull, her rigging's shot through: she loses way (BATTERED_SPEED m/s) and the crew
## can come alongside to board.
const BATTERED_AT := 0.75
const BATTERED_SPEED := 2.5
var _battered := false


func _max_speed() -> float:
	return minf(super._max_speed(), BATTERED_SPEED) if hull < max_hull * BATTERED_AT else super._max_speed()


## A named ship comes for the crew whatever their bounty (the lieutenant was sent for them).
func _wants_crew() -> bool:
	return true


func _turn_grunt(ci: int, tag: String, seed_value: int) -> PirateGrunt:
	var g := super._turn_grunt(ci, tag, seed_value)
	(_crew[ci]["node"] as Node3D).scale = Vector3.ONE
	return g


## A captain on a deck alongside (or swimming by) swings across onto her main deck by the rail on their side.
func _swing_aboard(p: Player, sgn: float) -> void:
	if state == S.SINK or aboard(p.global_position):
		return
	var land := to_global(Vector3(sgn * (HullLayout.base().half_width(-1.0) - 1.2), HullLayout.DECK_Y + 0.3, -1.0))
	FX.sfx("whoosh", p.global_position, -4.0, 0.05, 0.9)
	Net.fx("tracer", [p.global_position + Vector3(0, 1.4, 0), land + Vector3(0, 1.0, 0), Color(0.75, 0.6, 0.4)])
	p.global_position = land
	p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if net_puppet or state == S.SINK:
		return
	if not _battered and hull < max_hull * BATTERED_AT:
		_battered = true
		bark("Her rigging's shot through! Stand by to repel boarders!" if kind == "flagship" else "We've lost the mainyard! All hands, prepare to be boarded!", 3.0)
	if state == S.DECK and duel == "":
		_deck_t += delta
		var up := deck_crew.filter(func(g): return is_instance_valid(g) and not g.is_dead()).size()
		if up <= CAPTAIN_AT or _deck_t > CAPTAIN_AFTER:
			_captain_out()
	if _yield_t >= 0.0:
		_yield_t += delta
		if _yield_t > 2.5:
			_yield_t = -1.0
			if is_instance_valid(captain):
				Net.everyone("_all_rival_gone", [Net.key_of(captain)])
			_strike()


## (host) Her captain on the quarterdeck, the intro on every screen, then the duel.
func _captain_out() -> void:
	duel = "out"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([look_seed, "captain_look"])
	var lk: Dictionary = CharacterLook.random_look(rng)
	lk["name"] = captain_name
	if kind == "warship":
		EnemyShip.marine_look(lk, rng, true)
		lk["name"] = captain_name
		lk["coat_color"] = Color(0.92, 0.93, 0.96)
		lk["trim_color"] = Color(0.85, 0.7, 0.3)
	else:
		lk["coat"] = "greatcoat"
		lk["coat_color"] = Color(0.4, 0.06, 0.08)
		lk["trim_color"] = Color(0.9, 0.72, 0.25)
		lk["hat"] = "tricorn"
		lk["hat_color"] = Color(0.1, 0.08, 0.08)
	lk["height"] = 1.12
	var weapons: Array = WEAPONS[kind]
	var w := str(weapons[rng.randi() % weapons.size()])
	var at := to_global(Vector3(0.0, HullLayout.base().qd_y + 0.2, HullLayout.base().helm_z - 1.2))
	var rname := "Captain_%s" % name
	var parent := get_parent()
	Net.everyone("_all_spawn_rival", [Net.key_of(parent), rname, lk, w, at, global_rotation.y, 0.85 if kind == "warship" else 0.75])
	captain = parent.get_node_or_null(rname) as Player
	if captain == null:
		duel = "beaten"
		return
	captain.hp_k = CAPTAIN_HP + level * 0.05
	captain.poise = Poise.make("elite")
	captain.call("_recalc_stats")
	captain.health_component.current_health = captain.health_component.max_health
	captain.defeated.connect(_on_captain_beaten)
	var b = captain.get_node("Brain")
	b.order = "hold"
	b.pace = 1.2
	var line: String = LINES[kind][rng.randi() % LINES[kind].size()]
	var you = get_tree().get_first_node_in_group("player")
	Net.everyone("_all_cutscene", ["sea_captain", [Net.key_of(captain), captain_name, line, Net.key_of(you), ship_name]])
	var c := Cutscene.active
	if c:
		c.finished.connect(func(_skipped): _start_duel())
	else:
		_start_duel()


func _start_duel() -> void:
	if duel != "out" or not is_instance_valid(captain):
		return
	duel = "duel"
	var b = captain.get_node("Brain")
	b.order = "fight"
	var best: Node3D = null
	for p in Net.all_players():
		if best == null or (p as Node3D).global_position.distance_to(captain.global_position) < best.global_position.distance_to(captain.global_position):
			best = p
	b.target = best


func _on_captain_beaten() -> void:
	if duel == "beaten":
		return
	duel = "beaten"
	captain.get_node("Brain").order = "hold"
	bark(YIELD[kind], 3.0)
	_yield_t = 0.0


## The cutscene's shots: her captain from the boarders' side, then close as they speak.
## args: [captain key, name, line, your key, ship name]
static func intro_shots(tree: SceneTree, args: Array) -> Array:
	var net := tree.root.get_node("Net")
	var cap := net.node_of(str(args[0])) as Player
	var you := net.node_of(str(args[3])) as Player
	if cap == null or you == null:
		return []
	return [
		{"secs": 2.0, "cam": [you.player_model, cap], "off": Vector3(1.0, 2.2, -3.6), "fov": 55.0, "to": [you.player_model, cap]},
		{"secs": 1.6, "cam": [cap.player_model, cap], "off": Vector3(-2.5, 2.6, 6.0), "fov": 50.0,
			"say": {"who": cap, "name": str(args[1]), "text": "Captain of %s." % str(args[4]), "pitch": 0.8}},
		{"cam": [cap.player_model, cap], "off": Vector3(0.8, 1.7, 2.8), "fov": 45.0,
			"say": {"who": cap, "name": str(args[1]), "text": str(args[2]), "pitch": 0.8}},
	]


## Taken: her colours come down only once her captain's beaten too.
func _strike() -> void:
	if state == S.PRIZE or duel != "beaten" or _yield_t >= 0.0:
		return
	_set_state(S.PRIZE)
	_empty_t = 0.0
	Net.award_xp(_xp(500), global_position, 200.0)
	Net.bounty(_bounty_kind(), global_position, 200.0, BOUNTY_K)
	Net.event(self, "prize", [])
	_prize()


func _prize() -> void:
	state = S.PRIZE
	if _jolly:
		_jolly.visible = false
	get_tree().call_group("hud", "show_banner", "%s is taken!" % ship_name, "%s yields. The captain's chest is yours." % captain_name, false)
	FX.sfx("bell", global_position, 0.0, 0.02, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name + "bigprize")
	var tier := mini(Levels.tier(level) + 1, 4)
	var picks := [["gold", roundi(rng.randi_range(160, 260) * Levels.coins_k(level))], ["treasure", rng.randi_range(4, 7)], ["rum", 2],
		["%s@%d" % [WeaponDesigns.random_item(rng), tier], 1], [Gear.random_piece(rng, tier).id, 1]]
	var bps := Gadgets.blueprint_ids()
	picks.append([bps[rng.randi() % bps.size()], 1])
	var parts := Gadgets.part_ids()
	for i in range(3):
		picks.append([parts[rng.randi() % parts.size()], rng.randi_range(1, 3)])
	picks.append_array(Salvage.roll(rng, 4, 0.8))
	var items: Array[ItemStack] = []
	for e in picks:
		var stk := ItemStack.new()
		stk.item = ItemDB.get_item(str(e[0]))
		stk.quantity = int(e[1])
		items.append(stk)
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	bag.setup(items, false)
	bag.rolls = true
	bag.name = "Prize_%s" % name
	get_node("Model").add_child(bag)
	bag.position = Vector3(1.6, HullLayout.base().qd_y, 7.4)
	bag.scale = Vector3.ONE / K


## Sunk from afar: her hoard goes down with her; a little flotsam and salvage.
func _drop_chest() -> void:
	var root := get_tree().current_scene
	Salvage.scatter(root, Vector3(_pos.x, 0.0, _pos.z), "frigate", hash(name + "salvage"))
