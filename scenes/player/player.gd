extends CharacterBody3D
class_name Player

enum Context { ON_FOOT, HELM, CANNON }

signal armed_changed(armed: bool)
signal weapon_changed(item: ItemData)
signal stamina_changed(current: float, maximum: float)
## An action was refused for lack of stamina (HUD flashes the bar).
signal stamina_denied
signal abilities_changed
signal stats_changed

## Stamina: attacks and the dodge dash spend it; it refills after a short pause.
## An action needs at least half its cost left (it may take the bar to empty).
const MAX_STAMINA := 100.0
const LIGHT_COST := 12.0
const HEAVY_COST := 30.0
const DODGE_COST := 18.0
const PLUNGE_COST := 16.0
## Sprinting drains this much per second. Run the bar dry and you're winded:
## no sprinting until it's back to SPRINT_RECOVER.
const SPRINT_DRAIN := 16.0
const SPRINT_RECOVER := 30.0
const STAMINA_REGEN := 38.0       # per second
const STAMINA_REGEN_DELAY := 0.75  # seconds after spending
## Body lean is scaled against this speed (kept at the old sprint speed so the
## jog leans the same as before).
const LEAN_REF_SPEED := 12.0

@export var move_speed: float = 6.0
@export var sprint_speed: float = 9.0
## Movement speed multiplier while the weapon is drawn (combat stance).
@export var combat_speed_mult: float = 0.8
@export var jump_force: float = 8.0
@export var gravity: float = 20.0
## Stopping when you let go of the stick (very high = stop on a dime).
@export var deceleration: float = 160.0
## How quickly the body turns to face the movement direction.
@export var turn_speed: float = 20.0
## Jumps before landing: 1 until the double jump is unlocked (see abilities).
@export var max_jumps: int = 1

@export_group("Feel")
## Extra gravity while falling (snappier arcs, Mario-style).
@export var fall_gravity_mult: float = 1.6
## Extra gravity while rising with jump released (variable jump height).
@export var short_hop_gravity_mult: float = 2.6
## Grace period to still jump after running off a ledge.
@export var coyote_time: float = 0.12
## Jump pressed this long before landing still jumps.
@export var jump_buffer_time: float = 0.14
## How far the body tilts to match slopes (0 = upright, 1 = fully aligned).
@export var slope_align: float = 0.55
## Body lean, locked to the camera's frame (not the model's facing), so
## weaving between diagonals doesn't swing the body around:
## forward/back follows speed and acceleration quickly; sideways is smoothed
## heavily; turning the camera while moving banks into the turn.
@export var speed_lean: float = 0.28
## Extra lean when speeding up (forward) or braking (back).
@export var accel_lean: float = 0.0025
## Bank per (camera turn rate x speed).
@export var bank_lean: float = 0.004
@export var max_lean: float = 0.32
## Jump momentum tilt (radians): forward at take-off, back on the way down.
@export var air_lean: float = 0.16

@onready var player_model: Node3D = $PlayerModel
@onready var sword_pivot: Marker3D = $PlayerModel/SwordPivot
@onready var sword_hitbox: Hitbox = $PlayerModel/SwordPivot/SwordHitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health_component: HealthComponent = $HealthComponent
@onready var input_buffer: InputBuffer = $InputBuffer
@onready var state_machine: StateMachine = $StateMachine
@onready var interaction_component: InteractionComponent = $InteractionComponent
@onready var inventory_component: InventoryComponent = $InventoryComponent

var is_parrying: bool = false
## Holding a block (Block state): frontal hits glance off the guard.
var is_blocking: bool = false
var context: Context = Context.ON_FOOT
var current_ship: Ship = null
var jumps_remaining: int = 1
## Gun Rains fired since leaving the ground (1 per jump + the "gun_rain_uses" stat).
var gun_rains: int = 0
## Katana air slashes since leaving the ground (one per jump).
var air_slashes: int = 0
## The next light attack is the katana's running draw (attacked while sprinting).
var quick_draw: bool = false
var body_model: Humanoid

## Weapon currently equipped (sheathed on the hip or drawn).
var equipped_weapon: ItemData
## True while the weapon is drawn (combat stance).
var armed: bool = false
var sprinting: bool = false

var _use_timer: float = 0.0
var _using_item: ItemData

## Body pivot between PlayerModel and the Humanoid: slope tilt, turn lean, squash/stretch.
var lean: Node3D
var variable_jump_active: bool = false
## Horizontal speed carried through the air (keeps sprint momentum in jumps).
var air_speed: float = 0.0
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _lean_q := Quaternion.IDENTITY
## Body alignment override (Vine Swing): the body's up axis turns toward
## `align_up` (world) by `align_w`. While `align_hold` is off the weight
## eases back to 0 in the air - faster close to the ground - so a tilted
## release rights itself before you land.
var align_up := Vector3.UP
var align_w: float = 0.0
var align_hold: bool = false
var _lean_f: float = 0.0  # smoothed speed along camera forward
var _lean_r: float = 0.0  # smoothed speed along camera right (slow)
var _lean_acc_f: float = 0.0
var _lean_tilt := Vector3.ZERO  # world-space tilt (direction the head tips toward)
var _cam_yaw_prev: float = 0.0
var _cam_turn: float = 0.0  # smoothed camera yaw rate (rad/s)
var _sq: float = 1.0
var _sq_v: float = 0.0
var _was_on_floor: bool = true
var _last_air_vy: float = 0.0
var _combo_next: int = 0
var _combo_expire: float = 0.0
var _step_count: int = 0
var stamina: float = MAX_STAMINA
var max_stamina: float = MAX_STAMINA
## Body, face and hair from the character creator. The look the body shows is
## this plus the equipped gear (Gear.compose).
var appearance: Dictionary = {}
var equipment: EquipmentComponent
## Skills and Devil Fruit powers (loadout, energy, cooldowns, the ultimate).
var power: PowerComponent
## Level, experience and the skill map.
var progression: Progression
## Off-hand weapon (dual wielding: a second sword or pistol), or null.
var offhand_weapon: ItemData
## Zoan: in hybrid beast form.
var hybrid: bool = false
## Loaded shots per pistol [main, off-hand].
var ammo: Array[int] = [2, 2]
var _reload_t: float = 0.0
var _since_hit: float = 99.0
var _last_stand_cd: float = 0.0
const BASE_MOVE := 6.0
const BASE_SPRINT := 9.0
## Base attributes; the skill system will raise them later.
var attributes: Dictionary = {"strength": 5, "agility": 5, "endurance": 5}
## Unlockable movement abilities (skill system later; F9 toggles in debug builds).
var abilities: Dictionary = {"double_jump": false}
var _stamina_delay: float = 0.0
var winded: bool = false
## Water: the ocean surface this far above your feet and you start swimming
## (a little less and you stand up again). Shallower water slows you (wading).
const SWIM_ENTER_DEPTH := 1.15
const SWIM_EXIT_DEPTH := 0.95
## Stamina regen is scaled by this (the swim state slows it while treading water).
var stamina_regen_mult: float = 1.0
## Where the last hit would throw the body (death / knockdown ragdoll).
var _last_hit_velocity := Vector3.ZERO
var _looking_at_cam: bool = false

## States in which the player may draw/sheathe or use the hotbar.
const FREE_STATES := ["Idle", "Move", "Jump", "Fall"]

## Co-op. false on the other players' captains here (puppets): no brain,
## no input - they play back their owner's snapshots (see Net).
var is_local: bool = true
## The peer that controls this captain.
var net_id: int = 1
## Puppets: what the owner told us when joining (name, look).
var net_profile: Dictionary = {}
## A menu is open in co-op (the world keeps running): no control.
var input_locked: bool = false
## Knocked out in co-op: on the ground, waiting for a crewmate (see revive).
var bleeding: bool = false
var bleed_t: float = 0.0
const BLEED_TIME := 20.0
const REVIVE_TIME := 2.5
const REVIVE_RANGE := 1.9
const REVIVE_HEALTH := 0.3
var _revive_t: float = 0.0
var _revive_target: Node = null
var _net_state: String = "Idle"
var _net_flags: int = 0
var _nameplate: Label3D
const NF_COAT := 1
const NF_BLEED := 2
const NF_FLOOR := 4


func _ready() -> void:
	equipment = EquipmentComponent.new()
	equipment.name = "EquipmentComponent"
	add_child(equipment)
	progression = Progression.new()
	progression.name = "Progression"
	add_child(progression)
	power = PowerComponent.new()
	power.name = "PowerComponent"
	add_child(power)
	inventory_component.item_added.connect(_on_item_added)
	floor_snap_length = 0.1
	# leaving the ship's deck, _ride_ship carries you instead (the states set
	# the air velocity from the stick every tick, which dropped what this added)
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(50.0)
	add_to_group("players")
	if not is_local:
		_setup_puppet()
		return
	_build_body()
	_give_starting_items()
	GameManager.register_player(self)
	hurtbox.hit_received.connect(_on_hit_received)
	sword_hitbox.hit_landed.connect(func(target: Node, data: HitData): power.on_sword_hit(target, data))
	health_component.died.connect(_on_died)
	_recalc_stats()


func _build_body() -> void:
	var capsule := player_model.get_node_or_null("MeshInstance3D")
	if capsule:
		capsule.visible = false
	# The old floating sword is replaced by the weapon in the character's hand.
	var old_sword := sword_pivot.get_node_or_null("SwordMesh")
	if old_sword:
		old_sword.visible = false
	lean = Node3D.new()
	lean.name = "Lean"
	player_model.add_child(lean)
	body_model = Humanoid.new()
	body_model.name = "Body"
	body_model.swappable_hands = true
	body_model.auto_point_guns = true
	# which save slot this session plays (the title screen normally chose it)
	SaveGame.ensure_session()
	var first_launch := SaveGame.new_game if SaveGame.enabled() else not CharacterLook.has_saved()
	var saved_look := SaveGame.peek_look()
	if first_launch:
		appearance = CharacterLook.default_look()
	elif not saved_look.is_empty():
		appearance = saved_look
	else:
		appearance = CharacterLook.load_look()
	body_model.setup(appearance)
	lean.add_child(body_model)
	body_model.footstep.connect(_on_footstep)
	var dm := get_node_or_null("/root/Dialogue")
	if dm:
		dm.register_token("captain", func() -> String: return str(body_model.look.get("name", "Captain")))
	# First launch: make your captain before setting foot on the island.
	# (Skipped in headless runs so automated tests aren't blocked.)
	if first_launch and DisplayServer.get_name() != "headless":
		open_creator.call_deferred(true)


## Open the character creator (first launch, or "Appearance" in the pause menu).
func open_creator(first_time: bool = false) -> void:
	if CharacterCreator.active:
		return
	CharacterCreator.open_for(get_tree(), body_model.look, first_time, func(lk: Dictionary, ok: bool):
		if first_time:
			# the outfit you designed becomes your starting gear
			appearance = lk
			_wear_outfit_of(lk)
			# the new captain's slot exists from here on
			SaveGame.save(self)
		elif ok:
			# later visits change body / face / hair only; clothes are gear now
			for k in lk.keys():
				if not Gear.is_outfit_key(k):
					appearance[k] = lk[k]
			refresh_look())


func _give_starting_items() -> void:
	_wear_outfit_of(appearance)
	var cutlass := ItemDB.get_item("cutlass")
	var rum := ItemDB.get_item("rum")
	if cutlass:
		inventory_component.add_item(cutlass, 1)
		equip_weapon(cutlass, false)
	if rum:
		inventory_component.add_item(rum, 3)


# --------------------------------------------------------------------------
# Gear, stats and abilities
# --------------------------------------------------------------------------
## Replace whatever is worn with the outfit in a look (start / first creation).
## Extra accessories beyond the two slots go into the bag.
func _wear_outfit_of(lk: Dictionary) -> void:
	equipment.clear()
	var gear := Gear.items_from_look(lk)
	for slot in gear.keys():
		if slot == "extra":
			for it in gear["extra"]:
				inventory_component.add_item(it, 1)
		else:
			equipment.equip(gear[slot], slot)
	refresh_look()


## Rebuild the body from appearance + worn gear (and remember it).
func refresh_look() -> void:
	if body_model == null:
		return
	body_model.apply_look(Gear.compose(appearance, equipment.slots))
	CharacterLook.save_look(body_model.look)
	if hybrid:
		hybrid = false
		set_hybrid(true)
	_recalc_stats()
	_net_look()


## Wear the gear at a bag position; whatever it replaces takes its place.
func equip_gear_from_bag(idx: int) -> bool:
	if idx < 0 or idx >= inventory_component.items.size():
		return false
	var it := inventory_component.items[idx].item
	if not it.is_gear():
		return false
	inventory_component.take_at(idx)
	var prev := equipment.equip(it)
	if prev:
		inventory_component.insert_item(prev, idx)
	refresh_look()
	return true


## Take off the gear in a paper-doll slot (into the bag, if there's room).
func unequip_gear(slot: String) -> bool:
	var it := equipment.get_item(slot)
	if it == null:
		return false
	if not inventory_component.has_room():
		_toast("No room in your bag")
		return false
	equipment.unequip(slot)
	inventory_component.add_item(it, 1)
	refresh_look()
	return true


func attribute(name_: String) -> int:
	return int(attributes.get(name_, 5))


func defense() -> float:
	var d := equipment.defense() if equipment else 0.0
	if progression:
		d += progression.stat("defense") + progression.style_stat("def", style())
		if hybrid:
			d += progression.stat("hybrid_defense")
	return d


## Share of incoming damage the worn gear soaks up (diminishing returns).
func damage_reduction() -> float:
	var d := defense()
	return d / (d + 40.0)


func _recalc_stats() -> void:
	var pr := progression
	max_stamina = MAX_STAMINA + (attribute("endurance") - 5) * 8.0 + (pr.stat("max_stamina") if pr else 0.0)
	stamina = minf(stamina, max_stamina)
	var hc := health_component
	if hc:
		var mh := 100.0 + (attribute("endurance") - 5) * 10.0
		if pr:
			mh += pr.stat("max_hp") + float(pr.level - 1) * 4.0
		if not is_equal_approx(hc.max_health, mh):
			hc.max_health = mh
			hc.current_health = minf(hc.current_health, mh)
			hc.health_changed.emit(hc.current_health, mh)
	var move_k := 1.0 + (pr.stat("move_pct") if pr else 0.0)
	var sprint_k := 1.0 + (pr.stat("sprint_pct") if pr else 0.0)
	if hybrid:
		var hk := 1.15 + (pr.stat("hybrid_speed_pct") if pr else 0.0)
		move_k *= hk
		sprint_k *= hk
	if power and power.buff("howl"):
		move_k *= 1.15
		sprint_k *= 1.15
	if power and power.buff("tekkai"):
		var tk := 0.6 if pr.skill_tier("tekkai") >= 2 else 0.3
		move_k *= tk
		sprint_k *= tk
	move_speed = BASE_MOVE * move_k
	sprint_speed = BASE_SPRINT * sprint_k
	var air := int(pr.stat("air_jumps")) if pr else 0
	if has_ability("double_jump"):
		air = maxi(air, 1)
	max_jumps = 1 + air
	stamina_changed.emit(stamina, max_stamina)
	stats_changed.emit()


func dodge_cost() -> float:
	return DODGE_COST * (1.0 - progression.stat("dodge_cost_pct"))


## Stamina scale for attacks with the weapon in hand (its tree's stam_ nodes).
func attack_cost_k() -> float:
	return 1.0 - progression.style_stat("stam", style())


## Getting hit: damage (less armor), a short flinch with a little shove
## (hitstun), or a full physics knockdown for heavy hits. A parry takes no
## damage and lets the attacker know it was parried.
func _on_hit_received(hit: HitData, attacker: Node) -> void:
	if health_component.current_health <= 0.0 or current_state_name() == "Downed" or vanished():
		return
	var dir := Vector3.ZERO
	if attacker is Node3D:
		dir = global_position - (attacker as Node3D).global_position
		dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else player_model.global_basis.z
	# an unblockable attack (the enemy flashed red) gets through parries and blocks
	if is_parrying and not hit.unblockable:
		if attacker and attacker.has_method("parried"):
			attacker.call("parried", self)
		return
	if is_blocking and not hit.unblockable and not hit.dot and current_state_name() == "Block":
		var fwd := -player_model.global_basis.z
		fwd.y = 0.0
		if fwd.normalized().dot(-dir) > 0.25:
			var blk = state_machine.states.get("block")
			if blk and blk.absorb(hit, dir):
				return
			# out of stamina: the guard breaks
			Net.fx("sparkle", [global_position + Vector3(0, 1.4, 0), 10, Color(1.0, 0.8, 0.4)])
			_toast("Guard broken!")
			state_machine.force_state("Stagger", {"stagger_duration": 0.6, "knockback_dir": dir, "knockback_force": 4.0, "flinch": false})
			health_component.take_damage(hit.damage * 0.5 * (1.0 - damage_reduction()))
			return
	# Observation Haki: Foresight dodges by itself
	if not hit.dot and power.use_foresight():
		_foresight_dodge(dir)
		return
	if not hit.dot and randf() < progression.stat("evade_chance"):
		_foresight_dodge(dir, "Instinct!")
		return
	if hit.ranged and _try_deflect(hit, dir, attacker):
		return
	# Riposte: the guard is up - turn the blow aside and answer it
	if power.buff("riposte") and not hit.ranged and not hit.dot and not hit.unblockable:
		power.buffs["riposte"] = 0.0
		state_machine.force_state("Technique", {"id": "riposte_counter", "target": attacker})
		return
	if hit.knockdown and power.iron_reflex():
		_toast("Iron Reflex!")
	_since_hit = 0.0
	var dmg := hit.damage * (1.0 - damage_reduction())
	if power.buff("tekkai"):
		dmg *= 0.3
	if power.buff("berserk"):
		dmg *= 1.15
	# Last Stand: once a minute, a killing blow leaves you at 1
	if progression.has_flag("last_stand") and _last_stand_cd <= 0.0 and dmg >= health_component.current_health and health_component.current_health > 1.0:
		dmg = health_component.current_health - 1.0
		_last_stand_cd = 60.0
		Net.fx("sparkle", [global_position + Vector3(0, 1.2, 0), 18, Color(1.0, 0.85, 0.4)])
		_toast("Last Stand!")
	# Thorn Hide: melee attackers get pricked
	var thorns := progression.stat("thorn_hide")
	if thorns > 0.0 and not hit.ranged and attacker and attacker.get("hurtbox") is Hurtbox:
		var th := HitData.new()
		th.dot = true
		th.damage = thorns
		(attacker.get("hurtbox") as Hurtbox).take_hit(th, self)
		Net.fx("sparkle", [(attacker as Node3D).global_position + Vector3(0, 1.0, 0), 4, Color(0.5, 0.9, 0.3)])
	_last_hit_velocity = dir * maxf(hit.knockback_force, 3.0) + Vector3.UP * (3.5 if hit.knockdown else 2.0)
	health_component.take_damage(dmg)
	Net.fx("impact", [global_position + Vector3(0, 1.0, 0) - dir * 0.3, Color(1.0, 0.55, 0.45)])
	if not hit.dot:
		Net.fx("blood", [global_position + Vector3(0, 1.1, 0) - dir * 0.15, dir, clampi(int(hit.damage * 0.6), 6, 18)])
	Net.fx("sfx", ["hit", global_position, -3.0, 0.08, 0.8])
	get_node("/root/CombatManager").apply_hit_effects(hit, [self, attacker])
	if health_component.current_health <= 0.0:
		return  # _on_died ragdolls the body
	if context == Context.HELM or current_state_name() in ["Talk", "Helm"]:
		return
	if power.buff("tekkai") or power.buff("berserk"):
		return  # Tekkai / Berserk: nothing moves you
	# Unstoppable (axe tree): swinging the axe, blows don't stop you
	if progression.style_stat("armor", style()) > 0.0 and current_state_name() in ["LightAttack", "HeavyAttack", "Plunge", "Technique"]:
		return
	if hit.knockdown:
		knock_down(_last_hit_velocity)
		return
	if progression.has_flag("steadfast"):
		return  # Steadfast: light hits don't make you flinch
	state_machine.force_state("Stagger", {"stagger_duration": clampf(hit.stagger_duration * 0.5, 0.12, 0.22),
		"knockback_dir": dir, "knockback_force": minf(hit.knockback_force * 0.5, 4.0), "flinch": true})


## Foresight: you saw it coming - an instant sidestep with an afterimage and
## a beat of slow motion.
func _foresight_dodge(dir: Vector3, label: String = "Foresight!") -> void:
	var side := Vector3.UP.cross(dir).normalized() * (1.0 if randf() < 0.5 else -1.0)
	Net.fx("afterimage", [body_model, Color(0.95, 0.5, 0.8)])
	global_position += side * 1.6
	velocity = side * 4.0
	reset_physics_interpolation()
	Net.fx("sfx", ["whoosh", global_position, -4.0, 0.05, 1.5])
	CombatManager.apply_hitstop(0.18, [self])
	_toast(label)


## A blade out and a shot coming from the front: cut it out of the air (weapon
## tree "deflect" nodes; "return" nodes send it back at the shooter).
var _deflect_cd: float = 0.0


func _try_deflect(hit: HitData, dir: Vector3, attacker: Node) -> bool:
	var st := style()
	if not armed or _deflect_cd > 0.0 or progression.style_stat("deflect", st) <= 0.0:
		return false
	var fwd := -player_model.global_basis.z
	fwd.y = 0.0
	if fwd.normalized().dot(-dir) < 0.2:
		return false
	_deflect_cd = maxf(4.0 - progression.style_stat("deflect_cd", st), 1.0)
	body_model.play("deflect", 0.35)
	var at := global_position + Vector3(0, 1.3, 0) - dir * 0.6
	Net.fx("sparkle", [at, 12, Color(1.0, 0.85, 0.5)])
	Net.fx("impact", [at, Color(1.0, 0.9, 0.6)])
	Net.fx("sfx", ["parry", at, -4.0, 0.05, 1.6])
	Net.fx("float_text", [at + Vector3.UP * 0.5, "Deflected!", Color(1.0, 0.9, 0.6)])
	if progression.style_stat("return", st) > 0.0 and attacker is Node3D and attacker.get("hurtbox") is Hurtbox:
		var back := HitData.new()
		back.ranged = true
		back.damage = roundf(hit.damage * 2.0 * damage_multiplier())
		back.knockback_force = 4.0
		back.stagger_duration = 0.4
		(attacker.get("hurtbox") as Hurtbox).take_hit(back, self)
		Net.fx("tracer", [at, (attacker.get("hurtbox") as Node3D).global_position])
	return true


## Soru mastered (Shadow Step): gone from sight, and nothing lands on you.
func vanish(secs: float) -> void:
	_vanish_t = secs
	body_model.visible = false


func vanished() -> bool:
	return _vanish_t > 0.0


## Co-op hit-stop: our own captain stops dead for a beat (the state machine
## skips its ticks) while the rest of the world carries on.
var hitstop_left: float = 0.0


func hit_freeze(duration: float) -> void:
	if is_local:
		hitstop_left = maxf(hitstop_left, duration)
	body_model.freeze(duration)


## Thrown off your feet: physics ragdoll, then get back up.
func knock_down(throw_velocity: Vector3) -> void:
	if context == Context.HELM:
		return
	state_machine.force_state("Downed", {"velocity": throw_velocity})


func _on_died() -> void:
	if not is_local:
		return
	# co-op with a crewmate still standing: you go down instead, and they
	# have a while to get you back up
	if Net.coop() and Net.others_standing() and context != Context.HELM:
		bleeding = true
		bleed_t = BLEED_TIME
		_revive_t = 0.0
		_toast("You're down! A crewmate can get you up (hold F next to you)")
	if context == Context.HELM:
		return
	# already down (e.g. drowning, or hit while on the ground): just go limp
	if current_state_name() == "Downed" and body_model.ragdoll != null:
		var ds := state_machine.current_state
		ds.set("dead", true)
		body_model.relax_ragdoll()
		return
	state_machine.force_state("Downed", {"dead": true, "velocity": _last_hit_velocity})


## Clear the body lean / squash (after a ragdoll the body starts fresh).
func reset_lean() -> void:
	_lean_q = Quaternion.IDENTITY
	_lean_tilt = Vector3.ZERO
	_lean_f = 0.0
	_lean_r = 0.0
	_lean_acc_f = 0.0
	_sq = 1.0
	_sq_v = 0.0
	if lean:
		lean.transform = Transform3D.IDENTITY


## Stand up where the ragdoll came to rest: face the right way, then play the
## get-up from the fallen pose. Returns how long the get-up takes.
func get_up_from_ragdoll() -> float:
	var info := body_model.ragdoll_rest_info()
	var face_up: bool = info["face_up"]
	var head_dir: Vector3 = info["head_dir"]
	var f := -head_dir if face_up else head_dir
	player_model.rotation.y = atan2(-f.x, -f.z)
	reset_lean()
	var dur := 1.05 if face_up else 0.95
	body_model.begin_getup(face_up, dur, info["hips_xform"])
	return dur


func has_ability(ability: String) -> bool:
	return bool(abilities.get(ability, false))


func set_ability(ability: String, unlocked: bool) -> void:
	abilities[ability] = unlocked
	_recalc_stats()
	jumps_remaining = mini(jumps_remaining, max_jumps) if not is_on_floor() else max_jumps
	abilities_changed.emit()


# --------------------------------------------------------------------------
# Per-frame: feed the animator
# --------------------------------------------------------------------------
func _process(delta: float) -> void:
	if body_model == null:
		return
	if not is_local:
		_puppet_process(delta)
		return
	_summon_tick(delta)
	body_model.net_sync = Net.active
	var hv := Vector3(velocity.x, 0, velocity.z)
	var local := player_model.global_basis.inverse() * hv
	body_model.ground_speed = hv.length()
	body_model.local_move = Vector2(local.x, -local.z).normalized() if hv.length() > 0.2 else Vector2(0, 1)
	body_model.grounded = is_on_floor() or context != Context.ON_FOOT
	body_model.vertical_speed = velocity.y
	body_model.armed = armed
	body_model.sprinting = sprinting
	body_model.stance = style()
	_update_head_look()
	_tick_body(delta)
	if _using_item:
		_use_timer -= delta
		if _use_timer <= 0.0:
			_finish_use()
	_update_lean(delta)


func _tick_body(delta: float) -> void:
	_since_hit += delta
	_last_stand_cd = maxf(_last_stand_cd - delta, 0.0)
	_deflect_cd = maxf(_deflect_cd - delta, 0.0)
	if _vanish_t > 0.0:
		_vanish_t -= delta
		if _vanish_t <= 0.0:
			body_model.visible = true
			Net.fx("afterimage", [body_model, Color(0.6, 0.85, 1.0), 0.2])
			Net.fx("dust", [global_position + Vector3(0, 0.05, 0), 6, 0.5])
	var hc := health_component
	if hc.current_health <= 0.0 or current_state_name() == "Downed":
		return
	# Mend: heal out of combat
	var regen := progression.stat("regen_hp")
	# Vine Fruit: Photosynthesis (out of combat, on land)
	if power.fruit == "vine" and _since_hit > 4.0 and is_on_floor() and water_depth() < 0.3:
		var k := 1.0 + progression.stat("photo_mult")
		regen += 1.5 * k
		power.add_energy(3.0 * k * delta)
		if randf() < delta * 1.5:
			Net.fx("sparkle", [global_position + Vector3(randf_range(-0.4, 0.4), randf_range(0.4, 1.6), randf_range(-0.4, 0.4)), 1, Color(0.6, 1.0, 0.4)])
	if regen > 0.0 and _since_hit > 5.0 and hc.current_health < hc.max_health:
		hc.heal(regen * delta)
	# pistols reload by themselves once empty (or put away)
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0:
			ammo[0] = max_ammo()
			ammo[1] = max_ammo()
			Net.fx("sfx", ["blip_low", global_position, -14.0, 0.05, 1.6])
	if _coat_on and not power.buff("coat"):
		update_coat_visual()
	elif _coat_on:
		# purple sparks crawl over the coated arm
		_coat_fx -= delta
		if _coat_fx <= 0.0:
			_coat_fx = 0.12
			var hand: Node3D = body_model.hand_r if randf() < 0.6 or weapon_class() not in ["fist", "claw"] else body_model.hand_l
			Net.fx("sparkle", [hand.global_position + Vector3(randf_range(-0.08, 0.08), randf_range(-0.05, 0.12), randf_range(-0.08, 0.08)), 2, HAKI_SPARK])
	# buffs that change speed come and go
	var buff_key := "%s|%s" % [power.buff("howl"), power.buff("tekkai")]
	if buff_key != _buff_key:
		_buff_key = buff_key
		_recalc_stats()


var _buff_key := ""
var _vanish_t: float = 0.0
var _coat_on: bool = false
var _coat_fx: float = 0.0
## Armament Haki colors: the coated limb and blade, the slash trails.
const HAKI_BLACK := Color(0.07, 0.03, 0.11)
const HAKI_TRAIL := Color(0.62, 0.25, 1.0)
const HAKI_SPARK := Color(0.75, 0.45, 1.0)


## Armament: Coat darkens the weapons (or fists) while it lasts.
## Armament: Coat - the weapon arm (both arms when fighting bare-handed or
## with two blades) turns glossy black with a purple sheen, and so do the
## blades.
func update_coat_visual() -> void:
	var on := power.buff("coat")
	_coat_on = on
	var skin: Material = null
	var blade: Material = null
	if on:
		# PSX materials, so the coat snaps and warps exactly like the body under it
		skin = PSXMat.lit("", HAKI_BLACK, {"emission": Color(0.25, 0.06, 0.45), "emission_energy": 0.35, "vertex_color": false})
		blade = PSXMat.lit("metal", HAKI_BLACK.lightened(0.05), {"emission": Color(0.4, 0.1, 0.7), "emission_energy": 0.8})
	for w in [body_model.weapon, body_model.offhand]:
		if w and is_instance_valid(w):
			(w as MeshInstance3D).material_override = blade
	var both := weapon_class() in ["fist", "claw"] or offhand_weapon != null
	var bones: Array = [body_model.arm_r, body_model.fore_r]
	if both:
		bones.append_array([body_model.arm_l, body_model.fore_l])
	for side in [[body_model.arm_r, body_model.fore_r], [body_model.arm_l, body_model.fore_l]]:
		for bone in side:
			for c in (bone as Node3D).get_children():
				if c is MeshInstance3D and c != body_model.weapon and c != body_model.offhand:
					(c as MeshInstance3D).material_override = skin if bone in bones else null
	# the arms themselves are one skinned mesh per arm on the torso
	var ab = body_model.torso.get_node_or_null("ArmBody")
	if ab:
		ab.arm_mesh(true).material_override = skin
		ab.arm_mesh(false).material_override = skin if both else null


# --------------------------------------------------------------------------
# Zoan: hybrid form
# --------------------------------------------------------------------------
const FUR := Color(0.55, 0.5, 0.44)


func toggle_hybrid() -> void:
	if current_state_name() not in FREE_STATES and current_state_name() not in ["LightAttack", "HeavyAttack"]:
		return
	set_hybrid(not hybrid)


func set_hybrid(on: bool) -> void:
	if on == hybrid:
		return
	hybrid = on
	var lk := Gear.compose(appearance, equipment.slots)
	if on:
		lk["skin"] = FUR
		lk["hair"] = "wild"
		lk["hair_color"] = FUR.darkened(0.25)
		lk["facial_hair"] = "beard"
		lk["eye_color"] = Color(0.95, 0.75, 0.2)
		lk["hat"] = "none"
		lk["height"] = float(lk.get("height", 1.0)) * 1.1
		lk["build"] = "broad"
	body_model.apply_look(lk)
	body_model.set_beast(on, FUR)
	# weapons stay sheathed in hybrid form: you fight with claws
	if on:
		body_model._attach_weapon(false)
		if body_model.weapon:
			body_model.weapon.visible = false
		if body_model.offhand:
			body_model.offhand.visible = false
		armed = true
		armed_changed.emit(true)
	else:
		if body_model.weapon:
			body_model.weapon.visible = true
		if body_model.offhand:
			body_model.offhand.visible = true
		body_model._attach_weapon(armed and equipped_weapon != null)
	Net.fx("smoke", [global_position + Vector3(0, 1.0, 0), 10, 1.4, 1.2])
	Net.fx("dust_ring", [global_position, 14, 0.9])
	Net.fx("sfx", ["howl" if on else "whoosh_big", global_position, -4.0, 0.05, 1.15 if on else 0.8])
	if on and is_inside_tree():
		FX.power_aura.call_deferred(body_model, "wolf", 2.0)
	CombatManager.apply_camera_shake(0.12)
	_recalc_stats()
	weapon_changed.emit(equipped_weapon)
	_net_look()


## The head eases toward where the camera aims. Once the camera swings more
## than halfway around (in front of the character), the face turns to track
## the camera instead (with a little hysteresis so it doesn't flicker).
func _update_head_look() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or body_model.head == null or context != Context.ON_FOOT or current_state_name() == "Talk":
		body_model.look_weight = 0.0
		return
	var head_pos := body_model.head.global_position
	var body_back := player_model.global_basis.z
	body_back.y = 0.0
	var to_cam := cam.global_position - head_pos
	to_cam.y = 0.0
	if body_back.length_squared() < 1e-6 or to_cam.length_squared() < 1e-6:
		return
	var around := rad_to_deg(body_back.normalized().angle_to(to_cam.normalized()))  # 0 = camera behind
	if _looking_at_cam and around < 80.0:
		_looking_at_cam = false
	elif not _looking_at_cam and around > 100.0:
		_looking_at_cam = true
	if _looking_at_cam:
		body_model.look_target = cam.global_position
	else:
		var aim := -cam.global_basis.z + Vector3(0, 0.12, 0)
		body_model.look_target = head_pos + aim.normalized() * 30.0
	body_model.look_weight = 1.0


# --------------------------------------------------------------------------
# Feel: lean, slope tilt, squash & stretch
# --------------------------------------------------------------------------
## Kick the squash/stretch spring: positive = stretch tall, negative = squash.
func squash(amount: float) -> void:
	_sq_v += amount


## Settle the squash & stretch spring (e.g. when the inventory freezes you).
func reset_squash() -> void:
	_sq = 1.0
	_sq_v = 0.0
	if lean:
		lean.basis = Basis(_lean_q)


func _update_lean(delta: float) -> void:
	var tilt := _lean_tilt
	tilt = tilt.limit_length(max_lean)
	if not is_on_floor():
		tilt *= 0.4
		# jump momentum: tipped forward into the take-off, rocking back as you
		# come down to land - only when you're actually travelling
		if context == Context.ON_FOOT and current_state_name() in ["Jump", "Fall"]:
			var hv := Vector3(velocity.x, 0.0, velocity.z)
			var travel := clampf((hv.length() - 1.0) / 4.0, 0.0, 1.0)
			if travel > 0.0:
				var arc := clampf(velocity.y / jump_force, -1.0, 1.0)
				tilt += hv.normalized() * air_lean * arc * travel
	var tilt_q := Quaternion.IDENTITY
	var ang := tilt.length()
	if ang > 0.0005:
		var axis_world := Vector3.UP.cross(tilt / ang)
		var axis_local := (player_model.global_basis.orthonormalized().inverse() * axis_world).normalized()
		tilt_q = Quaternion(axis_local, ang)
	# slope alignment
	var up := Vector3.UP
	if context != Context.ON_FOOT and current_ship:
		# at the wheel (or a cannon) the body rides the deck's pitch and roll
		up = (player_model.global_basis.inverse() * current_ship.global_basis.y).normalized()
	elif is_on_floor():
		var n := player_model.global_basis.inverse() * get_floor_normal()
		up = Vector3.UP.slerp(n.normalized(), slope_align)
	var target := Quaternion(Vector3.UP, up) * tilt_q
	var lean_rate := 12.0
	if not align_hold and align_w > 0.0:
		if is_on_floor():
			align_w = 0.0
		else:
			var k := 1.0 if height_above_ground() > 2.5 else 4.5
			align_w = move_toward(align_w, 0.0, k * delta)
	if align_w > 0.001:
		var lu := (player_model.global_basis.orthonormalized().inverse() * align_up).normalized()
		# never more than ~80 degrees off upright
		var off_up := Vector3.UP.angle_to(lu)
		if off_up > 1.4:
			lu = Vector3.UP.slerp(lu, 1.4 / off_up).normalized()
		target = target.slerp(Quaternion(Vector3.UP, lu), clampf(align_w, 0.0, 1.0))
		lean_rate = 16.0
	_lean_q = _lean_q.slerp(target, minf(lean_rate * delta, 1.0))
	# damped spring for squash & stretch (bouncy, slightly under-damped).
	# Fixed substeps: one long frame (a hitch, or the first frame after a
	# pause) must not blow the spring up into a stretched-tall character.
	var steps := clampi(ceili(minf(delta, 0.1) / (1.0 / 120.0)), 1, 12)
	var h := minf(delta, 0.1) / steps
	for i in range(steps):
		var accel := -190.0 * (_sq - 1.0) - 13.0 * _sq_v
		_sq_v += accel * h
		_sq = clampf(_sq + _sq_v * h, 0.55, 1.5)
	var side := 1.0 / sqrt(_sq)
	lean.basis = Basis(_lean_q) * Basis.from_scale(Vector3(side, _sq, side))


func _physics_process(delta: float) -> void:
	if not is_local:
		return
	if bleeding:
		_bleed_tick(delta)
	elif Net.coop():
		_revive_tick(delta)
	elif _revive_target != null:
		# (a revive cut short by the session ending)
		_revive_target = null
		body_model.kneeling = false
	_ride_ship()
	# swimming in a whirlpool: dragged round and in with the water
	if current_state_name() == "Swim":
		var sf := get_tree().get_first_node_in_group("sea_features")
		if sf:
			global_position += sf.current_at(global_position) * delta * 0.7
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = coyote_time
		gun_rains = 0
		air_slashes = 0
		if not _was_on_floor:
			_on_landed(_last_air_vy)
	else:
		_coyote -= delta
		_last_air_vy = velocity.y
	_was_on_floor = on_floor
	_jump_buffer -= delta
	_update_lean_target(delta)
	_regen_stamina(delta)
	# deep enough water: swim (from walking, falling, attacking...)
	if context == Context.ON_FOOT and current_state_name() in SWIM_FROM_STATES and water_depth() > SWIM_ENTER_DEPTH:
		state_machine.force_state("Swim", {"entry_vy": velocity.y})


## In the air over the ship (a jump, a fall, a flip, knocked off your feet):
## carried along with the hull the way its deck carries you, so you come down
## where you went up from.
func _ride_ship() -> void:
	if is_on_floor() or context != Context.ON_FOOT or current_state_name() in NO_RIDE_STATES:
		return
	var ship := _deck_ship()
	if ship == null:
		return
	var d: Transform3D = ship.deck_delta()
	global_position = d * global_position
	player_model.rotation.y += d.basis.get_euler().y


## States that hold you somewhere else (water, a ladder, a vine, a ragdoll).
const NO_RIDE_STATES := ["Swim", "Climb", "Swing", "Downed", "Helm", "Cannon"]


## States that drop into swimming when the water gets deep enough.
const SWIM_FROM_STATES := ["Idle", "Move", "Jump", "Fall", "LightAttack", "HeavyAttack", "Dodge", "Parry", "Stagger", "Plunge", "Skill", "Shoot", "Swing", "Iai"]


## Distance down to the ground (or INF over nothing within 30 m).
func height_above_ground() -> float:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1, global_position + Vector3.DOWN * 30.0, 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return INF if hit.is_empty() else global_position.y - (hit["position"] as Vector3).y


## Height of the ocean surface (with the waves) at a point (default: here).
func water_surface(at: Vector3 = Vector3.INF) -> float:
	var p := global_position if at == Vector3.INF else at
	var ocean := get_node_or_null("/root/Ocean")
	if ocean == null:
		return -INF
	return float(ocean.call("get_wave_height", p))


## How far the water surface is above your feet (negative = dry).
func water_depth() -> float:
	return water_surface() - global_position.y


## Water depth under a point (surface to sea floor); see Ocean.depth_at.
func water_depth_at(at: Vector3) -> float:
	var ocean := get_node_or_null("/root/Ocean")
	if ocean == null:
		return -INF
	return float(ocean.call("depth_at", at, [get_rid()]))


## Leave the ragdoll straight into swimming: the body is floating in deep
## water, so instead of a get-up it rights itself and starts treading water.
func recover_into_swim() -> void:
	var info := body_model.ragdoll_rest_info()
	var face_up: bool = info["face_up"]
	var head_dir: Vector3 = info["head_dir"]
	var f := -head_dir if face_up else head_dir
	player_model.rotation.y = atan2(-f.x, -f.z)
	reset_lean()
	var hip := body_model.hip_y * body_model.scale.y
	var y := water_surface() - 0.42 * body_model.scale.y - hip
	if power.has_fruit():
		y = minf(y, body_model.hips.global_position.y - hip)  # cursed: no bobbing up
	var space := get_world_3d().direct_space_state
	# don't put the feet into the sea floor
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 2.0, global_position + Vector3.DOWN * 20.0, 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		y = maxf(y, (hit["position"] as Vector3).y + 0.02)
	global_position.y = y
	velocity = Vector3.ZERO
	body_model.recover_from_ragdoll(face_up, info["hips_xform"], 0.7)
	state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})


func is_swimming() -> bool:
	return current_state_name() == "Swim"


## Wading slows you down: 1 on dry land, down to 0.65 at chest depth.
func wade_mult() -> float:
	var d := water_depth()
	return 1.0 - 0.35 * clampf((d - 0.3) / (SWIM_ENTER_DEPTH - 0.3), 0.0, 1.0)


## Climb a ladder (from the water) or pull yourself up onto a low ledge.
func start_climb(data: Dictionary) -> void:
	state_machine.force_state("Climb", data)


## Spend stamina for an action. Needs at least half the cost in the bar (the
## action may then drain it to empty); otherwise it's refused.
func spend_stamina(cost: float) -> bool:
	if stamina < cost * 0.5:
		stamina_denied.emit()
		return false
	stamina = maxf(stamina - cost, 0.0)
	_stamina_delay = STAMINA_REGEN_DELAY
	stamina_changed.emit(stamina, max_stamina)
	return true


## Kick of camera shake when a sprint begins (not when it carries on through
## a landing or a quick re-press).
const SPRINT_SHAKE := 0.045
const DASH_SHAKE := 0.06
var _sprint_seen_ms: int = -100000


func on_sprint_start() -> void:
	var now := Time.get_ticks_msec()
	if now - _sprint_seen_ms > 600:
		CombatManager.apply_camera_shake(SPRINT_SHAKE)
		squash(-1.2)
	_sprint_seen_ms = now


## Whether a sprint can start / continue right now.
func can_sprint() -> bool:
	return not winded and stamina > 0.0


## Called every physics tick while sprinting.
func drain_sprint(delta: float) -> void:
	_sprint_seen_ms = Time.get_ticks_msec()
	stamina = maxf(stamina - SPRINT_DRAIN * (1.0 - progression.stat("sprint_cost_pct")) * delta, 0.0)
	_stamina_delay = STAMINA_REGEN_DELAY * 0.6
	if stamina <= 0.0:
		winded = true
		stamina_denied.emit()
	stamina_changed.emit(stamina, max_stamina)


## Continuous stamina use (swimming): no regen while it's being spent.
func drain_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_stamina_delay = STAMINA_REGEN_DELAY * 0.5
	stamina_changed.emit(stamina, max_stamina)


func _regen_stamina(delta: float) -> void:
	if winded and stamina >= SPRINT_RECOVER:
		winded = false
	if _stamina_delay > 0.0:
		_stamina_delay -= delta
		return
	if stamina < max_stamina and stamina_regen_mult > 0.0:
		var k := 1.0 + progression.stat("stamina_regen_pct")
		stamina = minf(stamina + STAMINA_REGEN * stamina_regen_mult * k * delta, max_stamina)
		stamina_changed.emit(stamina, max_stamina)


## Lean target in the camera's frame. Control stays instant (velocity follows
## the stick exactly); only the visual lean has inertia.
func _update_lean_target(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var yaw := player_model.global_rotation.y
	if cam and cam.get_parent() and cam.get_parent().get_parent() is Node3D:
		yaw = (cam.get_parent().get_parent() as Node3D).global_rotation.y
	var cam_f := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var cam_r := Vector3(cos(yaw), 0.0, -sin(yaw))
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var prev_f := _lean_f
	_lean_f = lerpf(_lean_f, hv.dot(cam_f), minf(6.0 * delta, 1.0))
	# (side lean eases at nearly the forward rate, so on a diagonal the lean
	# points along the move instead of swinging round over half a second)
	_lean_r = lerpf(_lean_r, hv.dot(cam_r), minf(5.0 * delta, 1.0))
	_lean_acc_f = lerpf(_lean_acc_f, (_lean_f - prev_f) / maxf(delta, 0.0001), minf(10.0 * delta, 1.0))
	var turn := wrapf(yaw - _cam_yaw_prev, -PI, PI) / maxf(delta, 0.0001)
	_cam_yaw_prev = yaw
	_cam_turn = lerpf(_cam_turn, clampf(turn, -8.0, 8.0), minf(6.0 * delta, 1.0))
	var fwd := _lean_f / LEAN_REF_SPEED * speed_lean
	# backpedalling (combat stance) keeps the weight over the feet: only a
	# slight lean back
	if fwd < 0.0:
		fwd *= 0.4
	fwd += _lean_acc_f * accel_lean
	var side := _lean_r / LEAN_REF_SPEED * speed_lean * 0.8
	# camera yaw + = turning left -> lean left (-cam_r)
	side -= _cam_turn * hv.length() * bank_lean
	_lean_tilt = cam_f * fwd + cam_r * side


## Falls up to ~5 m are free (a double or triple jump never hurts); past
## that the landing hurts - about 25 damage from 8 m, 50 from 12 m, 85 from
## 20 m or more - and a long drop leaves you reeling. A plunge attack's dive
## doesn't count. (Falling is 1.6x gravity, so a 5 m drop lands at ~18 m/s.)
const SAFE_FALL_SPEED := 18.0
const FALL_DAMAGE_PER_MS := 5.3


func _on_landed(impact_vy: float) -> void:
	var k := clampf(-impact_vy / 16.0, 0.0, 1.0)
	var speed := -impact_vy
	if speed > SAFE_FALL_SPEED and context == Context.ON_FOOT and current_state_name() not in ["Plunge", "Swim", "Downed"]:
		_fall_damage(speed)
	if k < 0.15:
		return
	squash(-2.0 - 5.0 * k)
	Net.fx("dust_ring", [global_position, int(6 + 14 * k), 0.6 + 0.6 * k])
	Net.fx("sfx", ["land", global_position, -8.0 + 6.0 * k])


func _fall_damage(speed: float) -> void:
	var dmg := (speed - SAFE_FALL_SPEED) * FALL_DAMAGE_PER_MS
	if power.buff("tekkai"):
		dmg *= 0.3
	if progression.has_flag("featherfall"):
		dmg *= 0.25
		speed = minf(speed, SAFE_FALL_SPEED + 4.0)
	_since_hit = 0.0
	health_component.take_damage(dmg)
	Net.fx("sfx", ["thud", global_position, -2.0, 0.05, 0.8])
	Net.fx("dust_ring", [global_position, 18, 1.2])
	CombatManager.apply_camera_shake(clampf(dmg / 60.0, 0.1, 0.4))
	Net.damage_number(roundf(dmg), global_position + Vector3(0, 1.9, 0))
	if health_component.current_health > 0.0 and speed > SAFE_FALL_SPEED + 4.0 and not power.buff("tekkai"):
		state_machine.force_state("Stagger", {"stagger_duration": 0.55, "knockback_dir": Vector3.ZERO, "knockback_force": 0.0, "flinch": false})


func _on_footstep(strength: float) -> void:
	# (a puppet isn't moved by physics here: its owner says if it's grounded)
	if not (is_on_floor() if is_local else bool(_net_flags & NF_FLOOR)):
		return
	_step_count += 1
	FX.sfx("step", global_position, -20.0 + 10.0 * strength, 0.15)
	var wet := water_depth()
	if wet > 0.08:
		# wading: splashes instead of dust
		FX.splash(Vector3(global_position.x, global_position.y + wet, global_position.z), 2 + int(strength * 3.0), 0.45)
		FX.sfx("splash", global_position, -16.0 + 6.0 * strength, 0.15, 1.3)
		return
	if sprinting or (not is_local and body_model.sprinting):
		squash(-0.9)
		FX.dust(global_position + Vector3(0, 0.05, 0), 4, 0.5)
	elif strength > 0.4 and _step_count % 2 == 0:
		FX.dust(global_position + Vector3(0, 0.05, 0), 2, 0.35)


## Coyote time: jump still allowed shortly after leaving a ledge.
func can_coyote_jump() -> bool:
	return _coyote > 0.0 and jumps_remaining == max_jumps


func buffer_jump() -> void:
	_jump_buffer = jump_buffer_time


func consume_jump_buffer() -> bool:
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		return true
	return false


# Combo memory: the next light attack continues the chain for a short while,
# even if you moved in between.
const COMBO_MEMORY := 0.9

func remember_combo(next_index: int) -> void:
	_combo_next = next_index
	_combo_expire = Time.get_ticks_msec() / 1000.0 + COMBO_MEMORY


func next_combo_index() -> int:
	if Time.get_ticks_msec() / 1000.0 <= _combo_expire:
		return _combo_next
	return 0


func reset_combo() -> void:
	_combo_next = 0
	_combo_expire = 0.0


func current_state_name() -> String:
	if not is_local:
		return _net_state
	return str(state_machine.current_state.name) if state_machine and state_machine.current_state else ""


func is_free() -> bool:
	return context == Context.ON_FOOT and current_state_name() in FREE_STATES


# --------------------------------------------------------------------------
# Input: ready weapon + quick items
# --------------------------------------------------------------------------
## Windows can swallow Shift's key-up (Ctrl+Shift is its keyboard-layout hotkey,
## and sprint + dodge is exactly that), leaving sprint held. Every mouse/key event
## carries the OS's real Shift state: when it says Shift is up, let go of sprint.
## (Godot's own key state can be stuck as well, so it isn't asked.)
func _input(event: InputEvent) -> void:
	if is_local and event is InputEventWithModifiers and not event.shift_pressed \
			and Input.is_action_pressed("sprint") \
			and not (event is InputEventKey and event.physical_keycode == KEY_SHIFT):
		Input.action_release("sprint")


## Summon the ship: hold B somewhere near water; a cooldown after.
const SUMMON_HOLD := 1.0
const SUMMON_COOLDOWN := 60.0
var _summon_hold: float = 0.0
var _summon_cd: float = 0.0


func _summon_tick(delta: float) -> void:
	_summon_cd = maxf(_summon_cd - delta, 0.0)
	if input_locked or not Input.is_action_pressed("summon_ship"):
		if _summon_hold != 0.0:
			_summon_hold = 0.0
			get_tree().call_group("hud", "show_prompt", "", -1.0)
		return
	if _summon_hold < 0.0:
		return  # (done: let go of the key first)
	_summon_hold += delta
	get_tree().call_group("hud", "show_prompt", "Summoning your ship...", _summon_hold / SUMMON_HOLD)
	if _summon_hold >= SUMMON_HOLD:
		_summon_hold = -1.0
		get_tree().call_group("hud", "show_prompt", "", -1.0)
		_toast(try_summon())


## Call the ship to the nearest water deep enough for her. Returns what to tell you.
func try_summon() -> String:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship == null:
		return "You have no ship"
	if context != Context.ON_FOOT:
		return "Not now"
	if ship.aboard(global_position):
		return "You're aboard her already"
	if _summon_cd > 0.0:
		return "The ship can't be called again yet (%d s)" % ceili(_summon_cd)
	for c in Net.all_players():
		if c != self and ship.aboard((c as Node3D).global_position):
			return "Not with the crew aboard her"
	var spot := ship.summon_spot(global_position)
	if spot.is_empty():
		return "Cannot summon ship: no water deep enough nearby"
	_summon_cd = SUMMON_COOLDOWN
	Net.summon_ship(spot[0], spot[1])
	return "Your ship is coming"


func _unhandled_input(event: InputEvent) -> void:
	if not is_local or input_locked:
		return
	if event.is_action_pressed("jump"):
		buffer_jump()
	# debug builds: F9 grants a level (try the skill map)
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		if (event as InputEventKey).shift_pressed:
			# every known skill gets the uses its next tier asks for
			for sk in progression.known_skills():
				var nt := Skills.tier_def(sk, progression.skill_tier(sk) + 1)
				if not nt.is_empty():
					progression.uses[sk] = maxi(progression.uses_of(sk), int(nt["uses"]))
			_toast("Debug: next tiers opened")
		else:
			var mt := SkillTree.style_tree(style())
			if mt != "":
				var m := progression.mastery_of(mt)
				progression.add_mastery(mt, Progression.mastery_to_next(int(m["lv"])) - int(m["xp"]))
			progression.add_xp(Progression.xp_to_next(progression.level) - progression.xp)
		get_viewport().set_input_as_handled()
		return
	# Zoan: shift between human and hybrid form
	if event.is_action_pressed("transform"):
		if power.fruit_type() == "zoan":
			toggle_hybrid()
		get_viewport().set_input_as_handled()
		return
	# debug builds: F10 knocks you over (try the ragdoll + get-up)
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		if is_free():
			knock_down(player_model.global_basis.z * 6.0 + Vector3.UP * 3.5)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ready_weapon"):
		if is_free():
			toggle_weapon()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ping_marker"):
		place_marker()
		get_viewport().set_input_as_handled()
		return
	# Devil Fruit skills (1-4) and the ultimate (R)
	for i in range(5):
		var act := "ultimate" if i == 4 else "skill_%d" % (i + 1)
		if event.is_action_pressed(act):
			if context == Context.ON_FOOT and current_state_name() not in ["Talk", "Downed", "Skill"]:
				power.try_cast(i)
			get_viewport().set_input_as_handled()
			return
	for i in range(InventoryComponent.HOTBAR_SIZE):
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			activate_hotbar(i)
			get_viewport().set_input_as_handled()
			return


func activate_hotbar(slot: int) -> void:
	if not is_free():
		return
	var item := inventory_component.get_hotbar_item(slot)
	if item == null:
		return
	if inventory_component.count(item.id) <= 0:
		_toast("Out of %s" % item.display_name)
		return
	if item.is_consumable() and item.devil_fruit == "":
		use_item(item)


# --------------------------------------------------------------------------
# Weapons
# --------------------------------------------------------------------------
func equip_weapon(item: ItemData, draw: bool = true) -> void:
	if item == null or not item.is_weapon():
		return
	equipped_weapon = item
	body_model.set_weapon(Props.weapon_mesh(item.model()))
	if offhand_weapon and not _offhand_valid(offhand_weapon):
		set_offhand(null)
	_reset_ammo()
	weapon_changed.emit(item)
	if draw and not armed:
		draw_weapon()


## Fight with your fists (no weapon in the main hand).
func unequip_weapon() -> void:
	equipped_weapon = null
	set_offhand(null)
	body_model.set_weapon(null)
	weapon_changed.emit(null)


## Weapon class of an item: "sword" or "gun".
static func class_of(item: ItemData) -> String:
	if item == null:
		return "fist"
	return "gun" if item.weapon_model in ["pistol", "rifle"] else "sword"


## What you're fighting with: fist / sword / gun / claw (Zoan hybrid).
func weapon_class() -> String:
	if hybrid:
		return "claw"
	return class_of(equipped_weapon)


## Fighting style: fist, sword, axe, katana, dual_sword, pistol, dual_pistol or claw.
func style() -> String:
	var c := weapon_class()
	var dual := offhand_weapon != null and not hybrid
	match c:
		"sword":
			if equipped_weapon.weapon_model == "katana":
				return "katana"
			if dual:
				return "dual_sword"
			return "axe" if equipped_weapon.weapon_model == "axe" else "sword"
		"gun":
			return "dual_pistol" if dual else "pistol"
	return c


func _offhand_valid(item: ItemData) -> bool:
	if item == null or equipped_weapon == null:
		return false
	if class_of(item) != class_of(equipped_weapon):
		return false
	# (the katana takes both hands)
	if "katana" in [item.weapon_model, equipped_weapon.weapon_model]:
		return false
	if item == equipped_weapon and inventory_component.count(item.id) < 2:
		return false
	return inventory_component.count(item.id) > 0


## Hold a second sword or pistol in the off hand (dual wielding). null clears it.
func set_offhand(item: ItemData) -> bool:
	if item != null and not _offhand_valid(item):
		return false
	offhand_weapon = item
	body_model.set_offhand(Props.weapon_mesh(item.model()) if item else null)
	_reset_ammo()
	weapon_changed.emit(equipped_weapon)
	return true


## Something left the bag (dropped, stored in a chest): stop holding a
## weapon you no longer carry.
func check_equipped() -> void:
	if equipped_weapon and inventory_component.count(equipped_weapon.id) <= 0:
		if armed:
			sheathe_weapon(true)
		unequip_weapon()
	if offhand_weapon and not _offhand_valid(offhand_weapon):
		set_offhand(null)


## Put a bag stack on the ground at your feet (in co-op everyone sees it and
## anyone can pick it up: that's how you trade).
func drop_from_bag(idx: int, qty: int = -1) -> bool:
	var st := inventory_component.take_amount(idx, qty)
	if st == null:
		return false
	check_equipped()
	var fwd := -player_model.global_basis.z
	fwd.y = 0.0
	var at := global_position + fwd.normalized() * 0.9
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.DOWN * 4.0, 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		at = hit["position"]
	Net.drop_items([[SaveGame.item_ref(st.item), st.quantity]], at)
	Net.fx("sfx", ["whoosh", at, -14.0, 0.1, 1.4])
	_toast("Dropped %s%s" % [st.item.display_name, " x%d" % st.quantity if st.quantity > 1 else ""])
	return true


## Picking up a second sword or pistol: dual wield it right away.
func _on_item_added(item: ItemData, _qty: int) -> void:
	if not item.is_weapon() or equipped_weapon == null or offhand_weapon != null:
		return
	if class_of(item) == class_of(equipped_weapon) and _offhand_valid(item):
		set_offhand(item)
		_toast("Dual wielding: %s + %s" % [equipped_weapon.display_name, item.display_name])


# --------------------------------------------------------------------------
# Pistols
# --------------------------------------------------------------------------
func max_ammo() -> int:
	return 2 + int(progression.stat("extra_shots"))


func _reset_ammo() -> void:
	ammo = [max_ammo(), max_ammo()]
	_reload_t = 0.0


func reloading() -> bool:
	return _reload_t > 0.0


func reload_time() -> float:
	var t := 1.5 if offhand_weapon else 1.1
	return t * (1.0 - progression.stat("reload_pct"))


func start_reload() -> void:
	if _reload_t > 0.0:
		return
	_reload_t = reload_time()
	body_model.play("reload", _reload_t)
	Net.fx("sfx", ["blip_low", global_position, -12.0, 0.05, 1.1])


func toggle_weapon() -> void:
	if armed:
		sheathe_weapon()
	else:
		draw_weapon()


## Ready your weapon (or raise your fists when you have none). quick: no draw
## animation (skills that need the weapon out).
func draw_weapon(quick: bool = false) -> void:
	if armed:
		return
	armed = true
	if equipped_weapon == null or hybrid:
		body_model.play("fists_up", 0.25)
	elif quick:
		body_model._attach_weapon(true)
	else:
		body_model.play("draw", 0.35)
	armed_changed.emit(true)


## Put the weapon away. `instant` skips the animation (boarding the helm, respawn).
func sheathe_weapon(instant: bool = false) -> void:
	if not armed:
		return
	armed = false
	if instant:
		body_model.stop_action()
		body_model._attach_weapon(false)
	else:
		body_model.play("sheathe", 0.4)
	armed_changed.emit(false)


## Weapon is out and not mid draw/sheathe/drink.
func can_attack() -> bool:
	return armed and not (body_model.current_action() in ["draw", "sheathe", "drink"])


## A melee hit for `base` damage with your bonuses (and Haki coating). `kind`
## ("heavy", "finisher", "skill") adds that weapon tree's bonus for it; any hit
## can crit (x1.5).
func melee_hit(base: float, kind: String = "") -> HitData:
	var h := HitData.new()
	var st := style()
	var pr := progression
	var k := 1.0 + (pr.style_stat(kind, st) if kind != "" else 0.0)
	h.damage = base * damage_multiplier() * k
	if randf() < pr.style_stat("crit", st) + pr.stat("crit_all"):
		h.damage *= 1.5
		h.set_meta("crit", true)
	if kind == "heavy" and pr.style_stat("unblock", st) > 0.0:
		h.unblockable = true
	if power.buff("coat"):
		# Armament: Coat - nothing can block it, and it breaks red wind-ups
		h.unblockable = true
		h.haki = true
	return h


## Size the melee hitbox for the style: sword, wide (dual blades), fist, claw.
const REACH := {
	"sword": [Vector3(1.8, 1.2, 1.6), Vector3(-0.3, 0.2, -0.9)],
	"wide": [Vector3(2.4, 1.2, 1.7), Vector3(-0.3, 0.2, -0.95)],
	"fist": [Vector3(1.3, 1.2, 1.15), Vector3(-0.3, 0.2, -0.7)],
	"claw": [Vector3(1.7, 1.2, 1.35), Vector3(-0.3, 0.2, -0.78)],
	"katana": [Vector3(2.5, 1.3, 2.2), Vector3(-0.3, 0.2, -1.2)],
	"iai": [Vector3(3.0, 1.3, 2.4), Vector3(-0.3, 0.2, -1.1)],
	"under": [Vector3(3.2, 3.6, 3.4), Vector3(-0.3, -1.3, -0.9)],
	# the axe's whirlwind: all the way round
	"whirl": [Vector3(4.4, 1.5, 4.4), Vector3(0.0, 0.2, 0.0)],
}


func set_reach(kind: String) -> void:
	var cs := sword_hitbox.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs == null or not (cs.shape is BoxShape3D):
		return
	var r: Array = REACH.get(kind, REACH["sword"])
	(cs.shape as BoxShape3D).size = r[0]
	cs.position = r[1]


func damage_multiplier() -> float:
	var w := equipped_weapon.power() if (equipped_weapon and not hybrid) else 1.0
	var pr := progression
	var st := style()
	var k := 1.0 + (attribute("strength") - 5) * 0.05 + pr.stat("damage_pct") + float(pr.level - 1) * 0.02
	k += pr.style_stat("dmg", st)
	if st == "claw":
		k += 0.25
	if power.buff("berserk"):
		k += 0.25
	# Adrenaline: hurt badly, you hit harder
	if health_component.current_health < health_component.max_health * 0.35:
		k += pr.stat("adrenaline")
	if power.buff("coat"):
		k += 0.3
	if power.buff("howl"):
		k += 0.25
	return w * k


# --------------------------------------------------------------------------
# Consumables
# --------------------------------------------------------------------------
func use_item(item: ItemData) -> void:
	if _using_item or not item.is_consumable():
		return
	if not current_state_name() in ["Idle", "Move"]:
		return
	if item.devil_fruit != "":
		eat_devil_fruit(item)
		return
	if item.heal_amount > 0.0 and health_component.current_health >= health_component.max_health:
		_toast("Already at full health")
		return
	if not inventory_component.remove_item(item, 1):
		return
	_using_item = item
	_use_timer = item.use_time * 0.6
	body_model.show_left_prop(Props.bottle_mesh())
	body_model.play("drink", item.use_time)


## Eat a Devil Fruit (the inventory asks first: it can't be undone).
func eat_devil_fruit(item: ItemData) -> void:
	if power.has_fruit():
		_toast("A second Devil Fruit would kill you")
		return
	if not inventory_component.remove_item(item, 1):
		return
	for i in range(InventoryComponent.HOTBAR_SIZE):
		if inventory_component.hotbar[i] == item.id:
			inventory_component.clear_hotbar_slot(i)
	_using_item = item
	_use_timer = item.use_time
	body_model.show_left_prop(Props.devil_fruit_mesh("devil_fruit_" + item.devil_fruit))
	body_model.play("eat", item.use_time)
	for k in range(3):
		get_tree().create_timer(0.3 + k * 0.38).timeout.connect(func(): Net.fx("sfx", ["crunch", global_position + Vector3(0, 1.5, 0), -4.0, 0.1]))


func _finish_use() -> void:
	var item := _using_item
	_using_item = null
	if item.devil_fruit != "":
		body_model.hide_left_prop()
		power.eat(item.devil_fruit)
		var fd := DevilFruits.get_fruit(item.devil_fruit)
		var col: Color = fd.get("color", Color.WHITE)
		match item.devil_fruit:
			"ember":
				Net.fx("flame", [global_position + Vector3(0, 0.9, 0), 26, 1.0, 0.8, 0.7])
				Net.fx("fire_ring", [global_position, 2.5, 30])
				Net.fx("sfx", ["fire_blast", global_position, -4.0, 0.05, 1.1])
			"wolf":
				Net.fx("smoke", [global_position + Vector3(0, 1.0, 0), 10, 1.4, 1.2])
				Net.fx("sfx", ["howl", global_position, -2.0, 0.03])
			_:
				Net.fx("sparkle", [global_position + Vector3(0, 1.0, 0), 30, col])
				Net.fx("dust_ring", [global_position, 14, 1.0])
				Net.fx("sfx", ["whoosh_big", global_position, -4.0, 0.05, 0.8])
		CombatManager.apply_camera_shake(0.25)
		var line: String = {"logia": "Your body is %s now... but the sea will never hold you again." % ("fire" if item.devil_fruit == "ember" else "an element"),
			"zoan": "The beast is in you now (press V)... but the sea will never hold you again.",
			"paramecia": "Plants answer to you now... but the sea will never hold you again."}.get(power.fruit_type(), "")
		get_tree().call_group("hud", "show_banner", "%s (%s)" % [fd.get("name", "Devil Fruit"), DevilFruits.type_name(item.devil_fruit)], line, true)
		SaveGame.save(self)
		return
	if item.heal_amount > 0.0:
		var amt := item.heal_amount * (1.0 + progression.stat("potion_pct"))
		health_component.heal(amt)
		_toast("+%d health" % int(amt))


func is_using_item() -> bool:
	return _using_item != null


func _toast(text: String) -> void:
	get_tree().call_group("hud", "show_toast", text)


# ==========================================================================
# Co-op: puppets of the other players' captains
# ==========================================================================
## A puppet's setup: the same body and parts, but no brain, input or camera.
func _setup_puppet() -> void:
	remove_from_group("player")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	collision_mask = 0
	for n in [state_machine, input_buffer, interaction_component, power, progression, inventory_component, equipment]:
		(n as Node).process_mode = Node.PROCESS_MODE_DISABLED
	interaction_component.set_deferred("monitoring", false)
	interaction_component.set_deferred("monitorable", false)
	sword_hitbox.deactivate()
	var capsule := player_model.get_node_or_null("MeshInstance3D")
	if capsule:
		capsule.visible = false
	var old_sword := sword_pivot.get_node_or_null("SwordMesh")
	if old_sword:
		old_sword.visible = false
	lean = Node3D.new()
	lean.name = "Lean"
	player_model.add_child(lean)
	body_model = Humanoid.new()
	body_model.name = "Body"
	body_model.lod = true
	body_model.swappable_hands = true
	body_model.auto_point_guns = true
	var lk: Dictionary = net_profile.get("look", {})
	appearance = lk if not lk.is_empty() else CharacterLook.default_look()
	body_model.setup(appearance)
	lean.add_child(body_model)
	body_model.footstep.connect(_on_footstep)
	_nameplate = Label3D.new()
	_nameplate.name = "Nameplate"
	_nameplate.font = load("res://assets/fonts/PixelifySans-Regular.woff2")
	_nameplate.font_size = 34
	_nameplate.pixel_size = 0.007
	_nameplate.outline_size = 10
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_nameplate.no_depth_test = true
	_nameplate.fixed_size = false
	_nameplate.position = Vector3(0, 2.25, 0)
	_nameplate.modulate = Color(0.85, 0.95, 1.0)
	add_child(_nameplate)
	_update_nameplate()
	visible = false  # until the first snapshot


func _update_nameplate() -> void:
	if _nameplate == null:
		return
	var nm := str(net_profile.get("name", body_model.look.get("name", "Captain") if body_model else "Captain"))
	if _net_flags & NF_BLEED:
		_nameplate.text = "%s\n[DOWN]" % nm
		_nameplate.modulate = Color(1.0, 0.45, 0.35)
	else:
		_nameplate.text = nm
		_nameplate.modulate = Color(0.85, 0.95, 1.0)


func display_name() -> String:
	if not is_local:
		var lk: Dictionary = net_profile.get("look", {})
		return str(net_profile.get("name", lk.get("name", "Captain")))
	return str(body_model.look.get("name", appearance.get("name", "Captain"))) if body_model else "Captain"


## Who we are, for the other players (sent when joining).
func net_info() -> Dictionary:
	return {"name": display_name(), "look": body_model.look.duplicate(true) if body_model else appearance,
		"level": progression.level if progression else 1}


## On our feet (not knocked out, not dead).
func is_standing() -> bool:
	if not is_local:
		return health_component.current_health > 0.0 and not (_net_flags & NF_BLEED)
	return health_component.current_health > 0.0 and not bleeding


func is_bleeding() -> bool:
	return bleeding if is_local else bool(_net_flags & NF_BLEED)


## The ship we're aboard (ours or a pirate's: on deck, mid-jump, in the
## rigging, on a ladder), or null.
func _deck_ship() -> Node3D:
	if context == Context.HELM and current_ship:
		return current_ship
	for d in get_tree().get_nodes_in_group("decks"):
		if d.aboard(global_position):
			return d
	return null


## Our snapshot (~20 times a second): where, how, and the body's state.
func net_pack() -> Array:
	var pos := global_position
	var yaw := player_model.rotation.y
	var ship := _deck_ship()
	if ship:
		# aboard: relative to the ship, so we ride it on every screen
		pos = ship.global_transform.affine_inverse() * pos
		yaw -= ship.global_rotation.y
	var flags := 0
	if _coat_on:
		flags |= NF_COAT
	if bleeding:
		flags |= NF_BLEED
	if is_on_floor() or context == Context.HELM:
		flags |= NF_FLOOR
	return [pos, Net.key_of(ship) if ship else "", velocity, yaw, lean.transform.basis if lean else Basis(), current_state_name(),
		health_component.current_health, health_component.max_health, flags, HumanoidSync.pack(body_model), _rope_end(),
		body_model.ragdoll.net_pack() if body_model.ragdoll else []]


## Where our vine (swing / grapple) is stretched to, or INF.
func _rope_end() -> Vector3:
	for key in ["swing", "skill"]:
		var st = state_machine.states.get(key)
		if st == null or st != state_machine.current_state:
			continue
		var r = st.get("_vine") if key == "swing" else st.get("_rope")
		if r != null and is_instance_valid(r) and not bool(r.get("_retracting")):
			return r.get("_b")
	return Vector3.INF


var _net_rope: Node3D


func _exit_tree() -> void:
	if _net_rope and is_instance_valid(_net_rope):
		_net_rope.queue_free()


## (against the hull as it's drawn this frame: its physics-tick transform is
## up to a tick behind, which shook deck puppets back and forth under way)
func _net_pos(snap: Array) -> Vector3:
	return Net.deck_unpack(snap[0], str(snap[1]))


func _net_yaw(snap: Array) -> float:
	var yaw := float(snap[3])
	var ship := Net.node_of(str(snap[1])) as Node3D
	if ship:
		yaw += ship.get_global_transform_interpolated().basis.get_euler().y
	return yaw


func _puppet_process(delta: float) -> void:
	var smp := Net.sample(self)
	if smp.is_empty():
		return
	var a: Array = smp[0]
	var b: Array = smp[1]
	var f: float = smp[2]
	if a.size() < 12 or b.size() < 12:
		return
	visible = true
	global_position = _net_pos(a).lerp(_net_pos(b), f)
	velocity = b[2]
	player_model.rotation.y = lerp_angle(_net_yaw(a), _net_yaw(b), f)
	lean.transform.basis = b[4]
	_net_state = str(a[5])
	context = Context.HELM if _net_state == "Helm" else Context.ON_FOOT
	var hc := health_component
	if hc.max_health != float(b[7]) or hc.current_health != float(b[6]):
		hc.max_health = float(b[7])
		hc.current_health = float(b[6])
		hc.health_changed.emit(hc.current_health, hc.max_health)
	var flags := int(a[8])
	if flags != _net_flags:
		var changed := flags ^ _net_flags
		_net_flags = flags
		if changed & NF_COAT:
			power.buffs["coat"] = 9999.0 if flags & NF_COAT else 0.0
			update_coat_visual()
		_update_nameplate()
	HumanoidSync.apply(body_model, a[9], b[9], f)
	# knocked down: the body lies (or floats) exactly where theirs does
	if body_model.ragdoll and (b[11] as Array).size() > 0:
		body_model.ragdoll.net_follow(a[11], b[11], f)
	# hybrid form fights with claws: weapons stay hidden
	for w in [body_model.weapon, body_model.offhand]:
		if w and is_instance_valid(w):
			(w as Node3D).visible = not hybrid
	# their vine, from the hand to wherever it's stretched
	var rope_end: Vector3 = b[10]
	if rope_end != Vector3.INF:
		if _net_rope == null or not is_instance_valid(_net_rope):
			_net_rope = VineRope.make(get_tree().current_scene, body_model.hand_r.global_position, rope_end, 0.1)
		_net_rope.set_ends(body_model.hand_r.global_position, rope_end)
	elif _net_rope != null:
		if is_instance_valid(_net_rope):
			_net_rope.call("retract")
		_net_rope = null
	if _coat_on:
		_coat_fx -= delta
		if _coat_fx <= 0.0:
			_coat_fx = 0.12
			FX.sparkle(body_model.hand_r.global_position + Vector3(randf_range(-0.08, 0.08), randf_range(-0.05, 0.12), randf_range(-0.08, 0.08)), 2, HAKI_SPARK)


## Tell the other machines our captain changed clothes / shape.
func _net_look() -> void:
	if is_local and Net.active and body_model:
		Net.event(self, "look", [body_model.look, hybrid])


## A power object we launched (fireball, flying slash, burning ground):
## the other machines get a harmless copy fired by our puppet there.
func net_power(kind: String, args: Array) -> void:
	if is_local and Net.active:
		Net.event(self, "power", [kind, args])


func net_event(what: String, args: Array) -> void:
	match what:
		"power":
			var a: Array = args[1]
			match str(args[0]):
				"projectile":
					Projectile.launch(get_tree(), str(a[0]), a[1], a[2], self, float(a[3]), str(a[4]))
				"fireball":
					Fireball.launch(get_tree(), a[0], a[1], self)
				"fire_zone":
					FireZone.spawn(get_tree(), a[0], float(a[1]), float(a[2]), float(a[3]), self)
		"look":
			if body_model and args.size() >= 2:
				body_model.apply_look(args[0])
				body_model.set_beast(bool(args[1]), FUR)
				if bool(args[1]) and not hybrid and is_inside_tree():
					FX.power_aura.call_deferred(body_model, "wolf", 2.0)
				hybrid = bool(args[1])
				net_profile["look"] = args[0]
				# a new captain names themselves in the creator after joining
				var nm := str((args[0] as Dictionary).get("name", ""))
				if nm != "":
					net_profile["name"] = nm
					if Net.roster.has(net_id):
						Net.roster[net_id]["name"] = nm
					Net.roster_changed.emit()
				# apply_look rebuilds the body: put the gear back on next snapshot
				for k in ["net_w", "net_o", "net_ih", "net_lp"]:
					if body_model.has_meta(k):
						body_model.remove_meta(k)
				_update_nameplate()


# --------------------------------------------------------------------------
# Knocked out (co-op)
# --------------------------------------------------------------------------
func _bleed_tick(delta: float) -> void:
	bleed_t -= delta
	get_tree().call_group("hud", "show_prompt", "DOWN - hold on! %ds" % ceili(maxf(bleed_t, 0.0)), clampf(bleed_t / BLEED_TIME, 0.0, 1.0))
	if bleed_t <= 0.0 or not Net.others_standing():
		# nobody came (or nobody's left standing): the usual death
		bleeding = false
		get_tree().call_group("hud", "show_prompt", "", -1.0)
		GameManager.bleed_out()


## A crewmate got you back on your feet.
func revive() -> void:
	if not bleeding:
		return
	bleeding = false
	get_tree().call_group("hud", "show_prompt", "", -1.0)
	var hc := health_component
	hc.current_health = maxf(hc.max_health * REVIVE_HEALTH, 1.0)
	hc.health_changed.emit(hc.current_health, hc.max_health)
	var ds = state_machine.current_state
	if current_state_name() == "Downed" and ds:
		ds.set("dead", false)
		ds.set("timer", maxf(float(ds.get("timer")), 1.0))
	Net.fx("sparkle", [global_position + Vector3(0, 1.0, 0), 20, Color(1.0, 0.9, 0.5)])
	Net.fx("sfx", ["blip_high", global_position, -6.0, 0.05, 1.2])


var _mark_cd: float = 0.0


## The ray through the reticle: [origin, direction], or [] without a camera.
## (The combat camera sits over the shoulder via h/v_offset, which the camera's
## own global transform doesn't include; project_ray_* does.)
func reticle_ray() -> Array:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return []
	var c := get_viewport().get_visible_rect().size * 0.5
	return [cam.project_ray_origin(c), cam.project_ray_normal(c)]

## G / middle mouse: mark where the camera points (an enemy, if one is under
## the crosshair) for the whole crew.
func place_marker() -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now < _mark_cd:
		return
	_mark_cd = now + 0.35
	var ray := reticle_ray()
	if ray.is_empty():
		return
	var from: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 250.0, 1 | 4 | 2048)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var pos := Vector3.INF
	var target: Node = null
	if not hit.is_empty():
		pos = hit["position"]
		var col := hit["collider"] as Node
		while col and not col.has_method("is_dead") and col != get_tree().current_scene:
			col = col.get_parent()
		if col and col.has_method("is_dead") and col != self and not col.is_dead():
			target = col
	# the sea: where the ray meets the water
	if dir.y < -0.01:
		var t := (0.0 - from.y) / dir.y
		if t > 0.0 and (pos == Vector3.INF or t < from.distance_to(pos)):
			pos = from + dir * t
			target = null
	if pos == Vector3.INF:
		pos = from + dir * 120.0
	Net.mark(pos, target)


## Hold F next to a knocked-out crewmate to get them up.
func _revive_tick(delta: float) -> void:
	var target: Node = null
	if is_free() and not input_locked:
		var best := REVIVE_RANGE
		for p in Net.all_players():
			if p == self or not p.is_bleeding():
				continue
			var d := (p as Node3D).global_position.distance_to(global_position)
			if d < best:
				best = d
				target = p
	if target == null:
		# (only our own kneel ends here: the ship's jobs kneel too)
		if _revive_target != null:
			get_tree().call_group("hud", "show_prompt", "", -1.0)
			body_model.kneeling = false
		_revive_target = null
		_revive_t = 0.0
		return
	if target != _revive_target:
		_revive_t = 0.0
	_revive_target = target
	var holding := Input.is_action_pressed("interact")
	if holding:
		_revive_t += delta
		velocity.x = 0.0
		velocity.z = 0.0
		# kneel down facing them
		var to := (target as Node3D).global_position - global_position
		if Vector2(to.x, to.z).length() > 0.2:
			var want := atan2(-to.x, -to.z)
			player_model.rotation.y = lerp_angle(player_model.rotation.y, want, clampf(delta * 12.0, 0.0, 1.0))
	else:
		_revive_t = maxf(_revive_t - delta * 2.0, 0.0)
	body_model.kneeling = holding and is_on_floor()
	var nm := str(target.display_name())
	get_tree().call_group("hud", "show_prompt", "Hold F: get %s up" % nm, _revive_t / REVIVE_TIME)
	if _revive_t >= REVIVE_TIME:
		_revive_t = 0.0
		body_model.kneeling = false
		Net.revive(int(target.net_id))
		get_tree().call_group("hud", "show_prompt", "", -1.0)
		_toast("%s is back on their feet" % nm)


## While a menu is open in co-op (the world keeps going): stand still.
## Returns true when it handled the frame (the state machine skips it).
func locked_physics(delta: float) -> bool:
	if current_state_name() not in FREE_STATES:
		return false
	if not is_on_floor():
		velocity.y = maxf(velocity.y - gravity * fall_gravity_mult * delta, -34.0)
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	move_and_slide()
	if is_on_floor() and current_state_name() != "Idle":
		state_machine.force_state("Idle", {})
	return true


## Step up to a ship's cannon (the seat is ours).
func man_cannon(c: Node) -> void:
	if not is_free():
		Net.release_seat(c)
		return
	state_machine.force_state("Cannon", {"cannon": c})


## Co-op client: the host gave us a seat (a cannon).
func take_seat(n: Node) -> void:
	if n is ShipCannon:
		man_cannon(n)


## Co-op client: the host gave us the wheel.
func take_helm() -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship == null or not is_free():
		Net.release_helm()
		return
	current_ship = ship
	state_machine.force_state("Helm", {})
