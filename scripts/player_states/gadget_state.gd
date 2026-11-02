extends PlayerState
## The traversal gadgets in use (1.28; GadgetBelt.fire forces it with {"id", "tier", "at"}). Added to the captain's
## state machine at runtime by GadgetBelt ("Gadget"). Numbers in GadgetData.
##   grapple       the hook flies to the point you look at (reason() found it); once it bites you're hauled up the
##                 line at the tier's pull, and pop up and over at the end (Fall)
##   spring_boots  the springs fire: straight up at the tier's speed, carrying your run (Fall)
##   glider        open in the air: a slow sink, gliding the way you face, steered with the stick; jump, landing or the
##                 tier's time folds it (Fall / Idle)
##   spike         driven into the wall in front: you hang on it up to the tier's hold, forward climbs, jump kicks off
##                 (up and away); climbing past the top hops you over it

## The grapple gives up hauling after this long, or when it's barely moving (snagged).
const PULL_MAX := 2.2
const ARRIVE := 1.3
## The hook only bites this far above your feet or higher (not the ground ahead).
const HOOK_ABOVE := 1.0
const POP := Vector3(0, 8.5, 0)
## Hauled until the chest is this far over the hook (so the pop clears a ledge).
const HAUL_OVER := 0.5
const POP_FWD := 4.0
const SPIKE_CLIMB := 1.6
const SPIKE_KICK := Vector3(0, 8.0, 0)
const SPIKE_AWAY := 3.0
## The glider turns this fraction of a normal turn (face_direction's turn_speed) a tick.
const GLIDE_TURN := 0.25
## The lockpick works on a locked chest this close, clicking every PICK_CLICK s.
const PICK_REACH := 2.6
const PICK_CLICK := 0.35
const SKIMMER := preload("res://scripts/player_states/skimmer_state.gd")

var id := ""
var tier := 0
var t := 0.0
var _at := Vector3.ZERO
var _normal := Vector3.ZERO
var _rope: GadgetRope
var _wing: MeshInstance3D
var _stuck := 0.0
var _look := 0.0
var _bag: LootBag


## (made at runtime: GadgetBelt hands it the captain instead of PlayerState waiting on the scene's owner)
func _ready() -> void:
	pass


## Why gadget `gid` can't be used by `p` now ("" it can), and where (the hook's point, the spike's wall).
static func reason(p: Player, gid: String, t: int) -> Array:
	match gid:
		"grapple":
			var at := hook_point(p, float(GadgetData.tier_val("grapple", "range", t)))
			return ["Nothing to hook there: look at a ledge, a branch or a mast", Vector3.ZERO] if at == Vector3.INF else ["", at]
		"glider":
			return ["Jump first, then open it", Vector3.ZERO] if p.is_on_floor() else ["", Vector3.ZERO]
		"spike":
			var w := wall_ahead(p)
			return ["No wall in front to drive it into", Vector3.ZERO] if w.is_empty() else ["", w["position"]]
		"lockpick":
			var b := lock_near(p)
			return ["No lock here to pick: stand at a locked chest", Vector3.ZERO] if b == null else ["", b.global_position]
		"skimmer":
			return SKIMMER.launch_point(p)
	return ["", Vector3.ZERO]


## The locked chest within PICK_REACH of the captain (null none).
static func lock_near(p: Player) -> LootBag:
	for b in p.get_tree().get_nodes_in_group("loot_bags"):
		var bag := b as LootBag
		if bag.locked != "" and bag.global_position.distance_to(p.global_position) < PICK_REACH:
			return bag
	return null


## Where the camera's line of sight meets the world within `r` of the captain (INF: nothing).
static func hook_point(p: Player, r: float) -> Vector3:
	var cam := p.get_viewport().get_camera_3d()
	var from: Vector3 = p.global_position + Vector3.UP * 1.6
	var dir: Vector3 = -p.player_model.global_basis.z + Vector3.UP * 0.6
	if cam:
		from = cam.global_position
		dir = -cam.global_basis.z
	var reach := r + from.distance_to(p.global_position)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * reach, 1, [p.get_rid()])
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		return Vector3.INF
	var at: Vector3 = h["position"]
	if at.distance_to(p.global_position) > r or at.y < p.global_position.y + HOOK_ABOVE:
		return Vector3.INF
	return at


## The wall right in front of the captain's chest ({} none): its point and normal.
static func wall_ahead(p: Player) -> Dictionary:
	var from: Vector3 = p.global_position + Vector3.UP * 1.2
	var fwd: Vector3 = -p.player_model.global_basis.z
	fwd.y = 0.0
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd.normalized() * 1.2, 1, [p.get_rid()])
	var h := p.get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty() or absf((h["normal"] as Vector3).y) > 0.5:
		return {}
	return h


func enter(data: Dictionary) -> void:
	id = str(data["id"])
	tier = int(data["tier"])
	_at = data.get("at", Vector3.ZERO)
	t = 0.0
	_stuck = 0.0
	var h := player.body_model
	match id:
		"grapple":
			var hand := _hand()
			_rope = GadgetRope.make(player.get_tree().current_scene, hand, _at, tier)
			_rope.shoot_time = clampf(hand.distance_to(_at) / 70.0, 0.08, 0.3)
			h.play("gd_grapple", 10.0)
			_face(_at - player.global_position)
			Net.fx("sfx", ["rope", hand, -4.0, 0.08, 1.3])
			Net.fx("sfx", ["whoosh", hand, -8.0, 0.1, 1.4])
		"spring_boots":
			var v := float(GadgetData.tier_val("spring_boots", "jump", tier))
			player.velocity.y = v
			Net.fx("puff_ring", [player.global_position + Vector3(0, 0.05, 0), "dust_low", 8 + 2 * tier, 0.3, 0.9 + 0.2 * tier, 0.7, Color(0.85, 0.8, 0.7, 0.9), 5.0 + tier])
			Net.fx("ring", [player.global_position + Vector3(0, 0.08, 0), Vector3.UP, 1.4 + 0.3 * tier, Color(1.0, 0.95, 0.8, 0.8), 0.25, 0.1])
			Net.fx("sfx", ["jump", player.global_position, -2.0, 0.05, 0.7])
			Net.fx("sfx", ["clack", player.global_position, -6.0, 0.05, 1.6])
			player.squash(6.0)
			player.cam_kick(0.15, 0.3)
		"glider":
			_wing = MeshInstance3D.new()
			_wing.name = "GliderWing"
			_wing.mesh = GadgetModels.glider_wing(tier)
			_wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			h.torso.add_child(_wing)
			_wing.scale = Vector3(0.1, 1, 1)
			_wing.create_tween().tween_property(_wing, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			h.play("gd_glide", 30.0)
			Net.fx("sfx", ["flap", player.global_position + Vector3.UP * 2.0, -2.0, 0.05, 0.8])
			Net.fx("puff", [player.global_position + Vector3.UP * 2.0, "dust", 3, 0.6, 0.5, Color(1, 1, 1, 0.6), 0.6])
		"spike":
			var w := wall_ahead(player)
			_normal = (w["normal"] as Vector3) if not w.is_empty() else player.player_model.global_basis.z
			_normal.y = 0.0
			_normal = _normal.normalized()
			_face(-_normal)
			player.velocity = Vector3.ZERO
			h.play("gd_hang", 30.0)
			Net.fx("parry_sparks", [_at, _normal])
			Net.fx("sfx", ["clash", _at, -4.0, 0.08, 1.4])
			player.cam_shake(0.08, 0.12)
		"lockpick":
			_bag = lock_near(player)
			_face(_bag.global_position - player.global_position)
			player.velocity = Vector3.ZERO
			player.sheathe_weapon(true)
			h.hold("dt_tinker")
			_look = 0.0


func exit() -> void:
	if _rope and is_instance_valid(_rope):
		_rope.retract()
	_rope = null
	if _wing and is_instance_valid(_wing):
		_wing.queue_free()
	_wing = null
	if player.body_model.current_action().begins_with("gd_") or (id == "lockpick" and player.body_model.current_action() == "dt_tinker"):
		player.body_model.stop_action()
	if id == "lockpick":
		player.get_tree().call_group("hud", "show_prompt", "")
	_bag = null


func physics_update(delta: float) -> void:
	t += delta
	match id:
		"grapple":
			_grapple(delta)
		"spring_boots":
			_to_air()
		"glider":
			_glide(delta)
		"spike":
			_hang(delta)
		"lockpick":
			_pick(delta)


## Picking the lock: the picks click at it for the tier's time, then it springs open and the chest opens. Moving,
## jumping or a dodge gives up (the charge back).
func _pick(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.move_and_slide()
	if not is_instance_valid(_bag) or _bag.locked == "":
		transitioned.emit(self, "Idle", {})
		return
	if get_movement_input().length() > 0.3 or player.inp.just_pressed("jump") or input_buffer.has_action("dodge"):
		player.gadgets.owned["lockpick"]["charges"] = player.gadgets.charges("lockpick") + 1
		player.gadgets.changed.emit()
		player.call("_toast", "You stop picking the lock")
		transitioned.emit(self, "Idle", {})
		return
	_look -= delta
	if _look <= 0.0:
		_look = PICK_CLICK
		Net.fx("sfx", ["clack", _bag.global_position + Vector3(0, 0.5, 0), -10.0, 0.2, 1.8])
	var secs := float(GadgetData.tier_val("lockpick", "pick_secs", tier))
	player.get_tree().call_group("hud", "show_prompt", "Picking the lock...", t / secs)
	if t >= secs:
		_bag.locked = ""
		Net.fx("sparkle", [_bag.global_position + Vector3(0, 0.6, 0), 10, GadgetModels.BRASS])
		Net.fx("sfx", ["clack", _bag.global_position + Vector3(0, 0.5, 0), -2.0, 0.05, 0.7])
		Net.fx("sfx", ["blip_high", _bag.global_position + Vector3(0, 0.5, 0), -8.0, 0.02, 1.2])
		var bag := _bag
		transitioned.emit(self, "Idle", {})
		bag.interactable.interacted.emit(player)


func _grapple(delta: float) -> void:
	_rope.set_ends(_hand(), _at)
	if not _rope.arrived():
		player.velocity = player.velocity.lerp(Vector3.ZERO, clampf(10.0 * delta, 0.0, 1.0))
		player.move_and_slide()
		return
	var to := _at + Vector3.UP * HAUL_OVER - (player.global_position + Vector3.UP * 1.0)
	if to.length() < ARRIVE or t > PULL_MAX or _stuck > 0.25:
		var flat := Vector3(to.x, 0.0, to.z)
		player.velocity = POP + (flat.normalized() * POP_FWD if flat.length() > 0.05 else Vector3.ZERO)
		Net.fx("puff", [player.global_position + Vector3.UP, "dust", 2, 0.5, 0.4, Color.WHITE, 0.5])
		_to_air()
		return
	player.velocity = to.normalized() * float(GadgetData.tier_val("grapple", "pull", tier))
	_face(to)
	player.move_and_slide()
	_stuck = _stuck + delta if player.get_real_velocity().length() < 2.0 else 0.0
	if Engine.get_physics_frames() % 6 == 0:
		Net.fx("speed_lines", [player.global_position + Vector3.UP, -to.normalized(), Color(1, 1, 1, 0.7), 4, 1.6, 0.18])


func _glide(delta: float) -> void:
	var input := get_movement_input()
	if input.length() > 0.1:
		face_direction(get_camera_relative_direction(input), delta * GLIDE_TURN)
	var fwd: Vector3 = -player.player_model.global_basis.z
	fwd.y = 0.0
	var spd := float(GadgetData.tier_val("glider", "speed", tier))
	player.velocity.x = fwd.x * spd
	player.velocity.z = fwd.z * spd
	player.velocity.y = move_toward(player.velocity.y, -float(GadgetData.tier_val("glider", "fall", tier)), 18.0 * delta)
	player.move_and_slide()
	player.freefall_from = now_s()
	if player.is_on_floor():
		transitioned.emit(self, "Idle", {})
	elif t > float(GadgetData.tier_val("glider", "secs", tier)) or player.inp.just_pressed("jump"):
		_to_air()


func _hang(delta: float) -> void:
	player.freefall_from = now_s()
	if player.inp.just_pressed("jump"):
		player.velocity = SPIKE_KICK + _normal * SPIKE_AWAY
		player.jumps_remaining = player.max_jumps - 1
		Net.fx("puff", [player.global_position + Vector3.UP, "dust", 2, 0.5, 0.4, Color.WHITE, 0.5])
		_to_air()
		return
	var climbing := get_movement_input().y < -0.3
	player.velocity = Vector3.UP * (SPIKE_CLIMB if climbing else 0.0) - _normal * 0.6
	player.move_and_slide()
	_look -= delta
	if climbing and _look <= 0.0:
		_look = 0.15
		if wall_ahead(player).is_empty():
			# over the top: a hop onto it
			player.velocity = Vector3.UP * 5.0 - _normal * 2.5
			_to_air()
			return
	if t > float(GadgetData.tier_val("spike", "hold", tier)):
		_to_air()


func _to_air() -> void:
	player.variable_jump_active = false
	transitioned.emit(self, "Fall", {})


func _hand() -> Vector3:
	return player.global_position + Vector3.UP * 1.5 - player.player_model.global_basis.z * 0.3


func _face(d: Vector3) -> void:
	d.y = 0.0
	if d.length() > 0.05:
		player.player_model.rotation.y = atan2(-d.x, -d.z)
