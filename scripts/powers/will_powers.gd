class_name WillPowers
extends Node
## The 1.24 Will paths on a captain (PowerComponent's child "Will", docs/v1_24_previews.md section 2): what their
## nodes change while you fight, on the captain's own machine. Skills (Still Point, Berserk...) are WillArts'.
##   Tempo  Flow (will_flow): a stack per blow landed while unhit (+FLOW_STEP attack speed each, FLOW_MAX of them), gone
##          when a blow lands on you. Second Step, Cancel and Light on Your Feet are plain stats (air_jumps,
##          dash_cancel in LightAttackState, move_pct).
##   Fury   Red Mist (red_mist): +1% damage per MIST_PER of health missing. Berserk's buff "w_berserk": a heal per blow
##          landed, blows taken harder. Unbowed (unbowed): once a fight the felling blow leaves 1 health and the buff
##          "unbowed" (nothing lands). Thick Blood (thick_blood): damage over time on you shrunk by its share.

const FLOW_STEP := 0.02
const FLOW_MAX := 10
const MIST_PER := 0.04
const BERSERK_SECS := 10.0
const BERSERK_HEAL := 0.04
const BERSERK_TAKEN := 0.2
const UNBOWED_SECS := 2.0
const FURY := Color(0.95, 0.2, 0.15)
## The slow tick (fight over, auras) every this many physics ticks.
const TICK_EVERY := 10

## Helm Sense: the helmsman's machine tells every machine's ship this often (ticks), for HELM_HOLD s.
const HELM_EVERY := 60
const HELM_HOLD := 2.5
## Rally: the rallier's machine calls it this often (ticks) while fighting, to every captain within RALLY_REACH, for
## RALLY_HOLD s.
const RALLY_EVERY := 30
const RALLY_REACH := 12.0
const RALLY_HOLD := 1.0
## Mirror Guard: the parried blow sent back this much harder.
const MIRROR_K := 1.0
## Intimidate: the bounty a foe that gives up adds.
const INTIMIDATE_BOUNTY := 250

var player: Player
var flow := 0
var _unbowed_used := false
var _n := 0
## Wave Walk: the floor under you on the water (WaveWalk), and the steps left until solid ground.
var _walk: WaveWalk
var _steps := WaveWalk.STEPS
## Bond's link, gauge and shelter (WillBond).
var bond: WillBond
## Rally: the share it gives while its buff "w_rally" lasts; Weak Point's marks on the boss near (WillSight).
var _rally_k := 0.0
var _weak: WillSight
var _weak_boss: Node


func _ready() -> void:
	player = get_parent().get_parent() as Player
	bond = WillBond.new()
	bond.name = "Bond"
	add_child(bond)


func _physics_process(delta: float) -> void:
	_n += 1
	if not player.is_local:
		return
	if player.progression.has_flag("wave_walk"):
		_wave_tick(delta)
	if _n % TICK_EVERY != 0:
		return
	if not player.in_fight():
		_unbowed_used = false
		flow = 0
	if player.power.buff("w_berserk"):
		Net.fx("sparkle", [player.global_position + Vector3(0, 1.2, 0), 3, FURY])
	var helm := player.progression.stat("helm_sense")
	if helm > 0.0 and player.context == Player.Context.HELM and _n % HELM_EVERY == 0:
		Net.everyone("_all_will", ["helm", [helm, HELM_HOLD]])
	var rally := player.progression.stat("will_rally")
	if rally > 0.0 and player.in_fight() and _n % RALLY_EVERY == 0:
		Net.everyone("_all_will", ["rally", [Net.key_of(player), rally, RALLY_HOLD]])
		Net.fx("ring", [player.global_position + Vector3(0, 0.1, 0), Vector3.UP, RALLY_REACH, Color(player.progression.will_tint(), 0.5), 0.5, 0.06])
	if player.progression.has_flag("weak_point"):
		_weak_tick()
	elif _weak:
		_weak.queue_free()
		_weak = null


## Weak Point (Sense): the nearest boss with breakable parts within reach marked (WillSight), until it's gone or far.
func _weak_tick() -> void:
	var best: Node3D = null
	var bd := WillSight.WEAK_REACH
	for b in get_tree().get_nodes_in_group("bosses"):
		if b is Node3D and BurnStatus.alive(b) and _parts_of(b) != null:
			var d := (b as Node3D).global_position.distance_to(player.global_position)
			if d < bd:
				bd = d
				best = b
	if best == _weak_boss and (best == null) == (_weak == null):
		return
	if _weak:
		_weak.queue_free()
		_weak = null
	_weak_boss = best
	if best:
		_weak = WillSight.weak_points(player, best, _parts_of(best))


## A boss's breakable parts (JungleBeast's pass, the ape's own), or null.
static func _parts_of(b: Node) -> BeastParts:
	var bp = b.get("bp")
	if bp != null:
		return bp.parts
	var parts = b.get("parts")
	return parts if parts is BeastParts else null


## Wave Walk (Tide): the sea under your feet while the steps last; ground fills them again.
func _wave_tick(delta: float) -> void:
	if _walk:
		if _walk.tick(delta):
			_steps = _walk.steps
			return
		_steps = _walk.steps
		_walk.queue_free()
		_walk = null
		return
	if player.is_on_floor() and player.water_depth() < -WaveWalk.ABOVE:
		_steps = WaveWalk.STEPS
	elif _steps > 0 and WaveWalk.can_start(player):
		_walk = WaveWalk.start(player, _steps)


## Extra damage share now (Player.damage_multiplier).
func damage_k() -> float:
	var pr := player.progression
	var k := 0.0
	if pr.has_flag("red_mist"):
		var hc := player.health_component
		k += (1.0 - hc.current_health / hc.max_health) * 0.01 / MIST_PER
	if player.power.buff("w_rally"):
		k += _rally_k
	return k + bond.damage_k()


## Mirror Guard (Iron Will): a parried blow (Player._on_hit_received) sent back into the attacker, through its guard.
func mirror(hit: HitData, attacker: Node3D) -> void:
	if not player.progression.has_flag("mirror_guard") or not (attacker.get("hurtbox") is Hurtbox):
		return
	var back := HitData.new()
	back.damage = roundf(hit.damage * MIRROR_K * player.damage_multiplier())
	back.unblockable = true
	back.haki = true
	back.knockback_force = 6.0
	back.stagger_duration = 0.5
	(attacker.get("hurtbox") as Hurtbox).take_hit(back, player)
	var tint := player.progression.will_tint()
	var at := attacker.global_position + Vector3(0, 1.2, 0)
	Net.fx("streak", [player.global_position + Vector3(0, 1.2, 0), at, tint, 0.08, 0.2])
	Net.fx("sparkle", [at, 14, tint])
	Net.fx("float_text", [at + Vector3.UP, "Mirrored!", tint])
	Net.fx("sfx", ["clash", at, -2.0, 0.05, 1.3])


## Flow's attack speed share now (LightAttackState).
func flow_k() -> float:
	return flow * FLOW_STEP if player.progression.has_flag("will_flow") else 0.0


## A weapon blow of ours landed (PowerComponent.on_sword_hit, our own machine).
func landed(hit: HitData) -> void:
	if player.progression.has_flag("will_flow"):
		flow = mini(flow + 1, FLOW_MAX)
	if player.power.buff("w_berserk"):
		player.health_component.heal(hit.damage * BERSERK_HEAL)
	bond.landed(hit)


## Nothing lands on you (Unbowed's moment).
func untouchable() -> bool:
	return player.power.buff("unbowed")


## A blow about to land for `dmg` (Player._on_hit_received, after armour): the damage it does.
func incoming(hit: HitData, dmg: float) -> float:
	var pr := player.progression
	if hit.dot:
		dmg *= 1.0 - pr.stat("thick_blood")
	else:
		flow = 0
	if player.power.buff("w_berserk"):
		dmg *= 1.0 + BERSERK_TAKEN
	dmg = bond.incoming(hit, dmg)
	var hc := player.health_component
	if pr.has_flag("unbowed") and not _unbowed_used and dmg >= hc.current_health and hc.current_health > 1.0:
		_unbowed_used = true
		dmg = hc.current_health - 1.0
		player.power.add_buff("unbowed", UNBOWED_SECS)
		var at := player.global_position + Vector3(0, 1.1, 0)
		Net.fx("sparkle", [at, 24, FURY])
		Net.fx("ring", [player.global_position + Vector3(0, 0.1, 0), Vector3.UP, 2.4, FURY, 0.4, 0.14])
		Net.fx("float_text", [at + Vector3.UP, "Unbowed!", FURY])
		Net.fx("sfx", ["haki", player.global_position, -2.0, 0.03, 0.7])
		player.cam_shake(0.2)
	return dmg


## Berserk (WillArts): the buff and its roar.
func berserk() -> void:
	player.power.add_buff("w_berserk", BERSERK_SECS)
	var at := player.global_position
	Net.fx("sparkle", [at + Vector3(0, 1.3, 0), 26, FURY])
	Net.fx("dust_ring", [at, 16, 1.0])
	Net.fx("ring", [at + Vector3(0, 0.1, 0), Vector3.UP, 3.0, FURY, 0.35, 0.16])
	Net.fx("sfx", ["haki", at, 0.0, 0.03, 0.6])
	player.cam_shake(0.25)
	player.cam_kick(0.1, 0.3)


## Something every machine does for a Will (Net._all_will): "still" [centre, reach, secs] slows the foes there; "swell"
## (the host throws the boarders off); "wind" [secs], "helm" [share, secs] on the ship; Twin Finisher's "twin_ask" /
## "twin" (WillArts); the rest are Bond's (WillBond.all).
static func all(op: String, a: Array) -> void:
	var ship := WillBond.crew_ship(Engine.get_main_loop() as SceneTree)
	match op:
		"still":
			StillPoint.start(a[0], a[1], a[2])
		"swell":
			if ship and (Engine.get_main_loop() as SceneTree).root.get_node("Net").is_host():
				WillArts.swell_foes(ship)
		"wind":
			if ship:
				ship.will_wind = maxf(ship.will_wind, float(a[0]))
		"helm":
			if ship:
				ship.will_guard_k = float(a[0])
				ship.will_guard = float(a[1])
		"twin_ask", "twin":
			WillArts.twin_net(op, a)
		"rally":
			var me := (Engine.get_main_loop() as SceneTree).get_first_node_in_group("player") as Player
			var by := (Engine.get_main_loop() as SceneTree).root.get_node("Net").node_of(str(a[0])) as Node3D
			if me and by and me.global_position.distance_to(by.global_position) <= RALLY_REACH:
				me.power.will._rally_k = float(a[1])
				me.power.add_buff("w_rally", float(a[2]))
		"flag":
			WarFlag.plant(a[0], a[1])
		_:
			WillBond.all(op, a)
