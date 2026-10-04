extends CharacterBody3D
class_name Player

enum Context { ON_FOOT, HELM }

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
var context: Context = Context.ON_FOOT
var current_ship: Ship = null
var jumps_remaining: int = 1
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


func _ready() -> void:
	equipment = EquipmentComponent.new()
	equipment.name = "EquipmentComponent"
	add_child(equipment)
	floor_snap_length = 0.1
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(50.0)
	_build_body()
	_give_starting_items()
	GameManager.register_player(self)
	hurtbox.hit_received.connect(_on_hit_received)
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
	var first_launch := not CharacterLook.has_saved()
	appearance = CharacterLook.default_look() if first_launch else CharacterLook.load_look()
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
	_recalc_stats()


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
	return equipment.defense() if equipment else 0.0


## Share of incoming damage the worn gear soaks up (diminishing returns).
func damage_reduction() -> float:
	var d := defense()
	return d / (d + 40.0)


func _recalc_stats() -> void:
	max_stamina = MAX_STAMINA + (attribute("endurance") - 5) * 8.0
	stamina = minf(stamina, max_stamina)
	var hc := health_component
	if hc:
		var mh := 100.0 + (attribute("endurance") - 5) * 10.0
		if not is_equal_approx(hc.max_health, mh):
			hc.max_health = mh
			hc.current_health = minf(hc.current_health, mh)
			hc.health_changed.emit(hc.current_health, mh)
	stamina_changed.emit(stamina, max_stamina)
	stats_changed.emit()


## Getting hit: damage (less armor), a short flinch with a little shove
## (hitstun), or a full physics knockdown for heavy hits. A parry takes no
## damage and lets the attacker know it was parried.
func _on_hit_received(hit: HitData, attacker: Node) -> void:
	if health_component.current_health <= 0.0 or current_state_name() == "Downed":
		return
	var dir := Vector3.ZERO
	if attacker is Node3D:
		dir = global_position - (attacker as Node3D).global_position
		dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else player_model.global_basis.z
	if is_parrying:
		if attacker and attacker.has_method("parried"):
			attacker.call("parried", self)
		return
	_last_hit_velocity = dir * maxf(hit.knockback_force, 3.0) + Vector3.UP * (3.5 if hit.knockdown else 2.0)
	health_component.take_damage(hit.damage * (1.0 - damage_reduction()))
	FX.impact(global_position + Vector3(0, 1.0, 0) - dir * 0.3, Color(1.0, 0.55, 0.45))
	FX.sfx("hit", global_position, -3.0, 0.08, 0.8)
	get_node("/root/CombatManager").apply_hit_effects(hit)
	if health_component.current_health <= 0.0:
		return  # _on_died ragdolls the body
	if context != Context.ON_FOOT or current_state_name() in ["Talk", "Helm"]:
		return
	if hit.knockdown:
		knock_down(_last_hit_velocity)
		return
	state_machine.force_state("Stagger", {"stagger_duration": clampf(hit.stagger_duration * 0.5, 0.12, 0.22),
		"knockback_dir": dir, "knockback_force": minf(hit.knockback_force * 0.5, 4.0), "flinch": true})


## Thrown off your feet: physics ragdoll, then get back up.
func knock_down(throw_velocity: Vector3) -> void:
	if context != Context.ON_FOOT:
		return
	state_machine.force_state("Downed", {"velocity": throw_velocity})


func _on_died() -> void:
	if context != Context.ON_FOOT:
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
	max_jumps = 2 if has_ability("double_jump") else 1
	jumps_remaining = mini(jumps_remaining, max_jumps) if not is_on_floor() else max_jumps
	abilities_changed.emit()


# --------------------------------------------------------------------------
# Per-frame: feed the animator
# --------------------------------------------------------------------------
func _process(delta: float) -> void:
	if body_model == null:
		return
	var hv := Vector3(velocity.x, 0, velocity.z)
	var local := player_model.global_basis.inverse() * hv
	body_model.ground_speed = hv.length()
	body_model.local_move = Vector2(local.x, -local.z).normalized() if hv.length() > 0.2 else Vector2(0, 1)
	body_model.grounded = is_on_floor() or context == Context.HELM
	body_model.vertical_speed = velocity.y
	body_model.armed = armed
	body_model.sprinting = sprinting
	_update_head_look()
	if _using_item:
		_use_timer -= delta
		if _use_timer <= 0.0:
			_finish_use()
	_update_lean(delta)


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
	var tilt_q := Quaternion.IDENTITY
	var ang := tilt.length()
	if ang > 0.0005:
		var axis_world := Vector3.UP.cross(tilt / ang)
		var axis_local := (player_model.global_basis.orthonormalized().inverse() * axis_world).normalized()
		tilt_q = Quaternion(axis_local, ang)
	# slope alignment
	var up := Vector3.UP
	if context == Context.HELM and current_ship:
		# at the wheel the body rides the deck's pitch and roll
		up = (player_model.global_basis.inverse() * current_ship.global_basis.y).normalized()
	elif is_on_floor():
		var n := player_model.global_basis.inverse() * get_floor_normal()
		up = Vector3.UP.slerp(n.normalized(), slope_align)
	var target := Quaternion(Vector3.UP, up) * tilt_q
	_lean_q = _lean_q.slerp(target, minf(12.0 * delta, 1.0))
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
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = coyote_time
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


## States that drop into swimming when the water gets deep enough.
const SWIM_FROM_STATES := ["Idle", "Move", "Jump", "Fall", "LightAttack", "HeavyAttack", "Dodge", "Parry", "Stagger"]


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
	stamina = maxf(stamina - SPRINT_DRAIN * delta, 0.0)
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
		stamina = minf(stamina + STAMINA_REGEN * stamina_regen_mult * delta, max_stamina)
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
	_lean_r = lerpf(_lean_r, hv.dot(cam_r), minf(2.5 * delta, 1.0))
	_lean_acc_f = lerpf(_lean_acc_f, (_lean_f - prev_f) / maxf(delta, 0.0001), minf(10.0 * delta, 1.0))
	var turn := wrapf(yaw - _cam_yaw_prev, -PI, PI) / maxf(delta, 0.0001)
	_cam_yaw_prev = yaw
	_cam_turn = lerpf(_cam_turn, clampf(turn, -8.0, 8.0), minf(6.0 * delta, 1.0))
	var fwd := _lean_f / LEAN_REF_SPEED * speed_lean + _lean_acc_f * accel_lean
	var side := _lean_r / LEAN_REF_SPEED * speed_lean
	# camera yaw + = turning left -> lean left (-cam_r)
	side -= _cam_turn * hv.length() * bank_lean
	_lean_tilt = cam_f * fwd + cam_r * side


func _on_landed(impact_vy: float) -> void:
	var k := clampf(-impact_vy / 16.0, 0.0, 1.0)
	if k < 0.15:
		return
	squash(-2.0 - 5.0 * k)
	FX.dust_ring(global_position, int(6 + 14 * k), 0.6 + 0.6 * k)
	FX.sfx("land", global_position, -8.0 + 6.0 * k)


func _on_footstep(strength: float) -> void:
	if not is_on_floor():
		return
	_step_count += 1
	FX.sfx("step", global_position, -20.0 + 10.0 * strength, 0.15)
	var wet := water_depth()
	if wet > 0.08:
		# wading: splashes instead of dust
		FX.splash(Vector3(global_position.x, global_position.y + wet, global_position.z), 2 + int(strength * 3.0), 0.45)
		FX.sfx("splash", global_position, -16.0 + 6.0 * strength, 0.15, 1.3)
		return
	if sprinting:
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
	return str(state_machine.current_state.name) if state_machine and state_machine.current_state else ""


func is_free() -> bool:
	return context == Context.ON_FOOT and current_state_name() in FREE_STATES


# --------------------------------------------------------------------------
# Input: ready weapon + hotbar
# --------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		buffer_jump()
	# debug builds: F9 toggles the double jump until the skill system exists
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		set_ability("double_jump", not has_ability("double_jump"))
		_toast("Debug: double jump %s" % ("unlocked" if has_ability("double_jump") else "locked"))
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
	if item.is_weapon():
		if equipped_weapon == item:
			toggle_weapon()
		else:
			equip_weapon(item, true)
	elif item.is_consumable():
		use_item(item)


# --------------------------------------------------------------------------
# Weapons
# --------------------------------------------------------------------------
func equip_weapon(item: ItemData, draw: bool = true) -> void:
	if item == null or not item.is_weapon():
		return
	equipped_weapon = item
	body_model.set_weapon(Props.weapon_mesh(item.weapon_model))
	weapon_changed.emit(item)
	if draw and not armed:
		draw_weapon()


func toggle_weapon() -> void:
	if armed:
		sheathe_weapon()
	else:
		draw_weapon()


func draw_weapon() -> void:
	if armed:
		return
	if equipped_weapon == null:
		# pick the first weapon we carry
		for stack in inventory_component.items:
			if stack.item.is_weapon():
				equip_weapon(stack.item, false)
				break
	if equipped_weapon == null:
		_toast("No weapon")
		return
	armed = true
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


func damage_multiplier() -> float:
	var w := equipped_weapon.damage_mult if equipped_weapon else 1.0
	return w * (1.0 + (attribute("strength") - 5) * 0.05)


# --------------------------------------------------------------------------
# Consumables
# --------------------------------------------------------------------------
func use_item(item: ItemData) -> void:
	if _using_item or not item.is_consumable():
		return
	if not current_state_name() in ["Idle", "Move"]:
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


func _finish_use() -> void:
	var item := _using_item
	_using_item = null
	if item.heal_amount > 0.0:
		health_component.heal(item.heal_amount)
		_toast("+%d health" % int(item.heal_amount))


func is_using_item() -> bool:
	return _using_item != null


func _toast(text: String) -> void:
	get_tree().call_group("hud", "show_toast", text)
