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

var player: Player
var flow := 0
var _unbowed_used := false
var _n := 0


func _ready() -> void:
	player = get_parent().get_parent() as Player


func _physics_process(_delta: float) -> void:
	_n += 1
	if _n % TICK_EVERY != 0 or not player.is_local:
		return
	if not player.in_fight():
		_unbowed_used = false
		flow = 0
	if player.power.buff("w_berserk"):
		Net.fx("sparkle", [player.global_position + Vector3(0, 1.2, 0), 3, FURY])


## Extra damage share now (Player.damage_multiplier).
func damage_k() -> float:
	var pr := player.progression
	var k := 0.0
	if pr.has_flag("red_mist"):
		var hc := player.health_component
		k += (1.0 - hc.current_health / hc.max_health) * 0.01 / MIST_PER
	return k


## Flow's attack speed share now (LightAttackState).
func flow_k() -> float:
	return flow * FLOW_STEP if player.progression.has_flag("will_flow") else 0.0


## A weapon blow of ours landed (PowerComponent.on_sword_hit, our own machine).
func landed(hit: HitData) -> void:
	if player.progression.has_flag("will_flow"):
		flow = mini(flow + 1, FLOW_MAX)
	if player.power.buff("w_berserk"):
		player.health_component.heal(hit.damage * BERSERK_HEAL)


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


## Something every machine does for a Will (Net._all_will): "still" [centre, reach, secs] slows the foes there.
static func all(op: String, a: Array) -> void:
	match op:
		"still":
			StillPoint.start(a[0], a[1], a[2])
