extends PlayerState

@export var parry_window: float = 0.26
@export var recovery_time: float = 0.4
## A parry this soon after the guard goes up is perfect (Clean Parry and its variant act on it).
const PERFECT := 0.12

var timer: float = 0.0
var parry_active: bool = false
var parry_succeeded: bool = false
var _window: float = 0.26


func enter(_data: Dictionary) -> void:
	timer = 0.0
	parry_active = true
	var pr := player.progression
	_window = parry_window + (0.05 if pr.has_flag("observation") else 0.0) + pr.stat("parry_all") + pr.style_stat("parry", player.style())
	parry_succeeded = false
	player.is_parrying = true
	player.body_model.play("parry", parry_window + recovery_time)
	player.reset_combo()

	# Connect to hurtbox for parry check
	if not player.hurtbox.hit_received.is_connected(_on_hit_during_parry):
		player.hurtbox.hit_received.connect(_on_hit_during_parry)


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 30.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, 30.0 * delta)
	player.move_and_slide()

	timer += delta

	if parry_active and timer >= _window:
		parry_active = false
		player.is_parrying = false
		# still holding parry: settle into a block
		if not parry_succeeded and player.inp.pressed("parry"):
			transitioned.emit(self, "Block", {})
			return

	if parry_succeeded:
		# Brief pause after successful parry, then return
		if timer >= parry_window + 0.15:
			transitioned.emit(self, "Idle", {})
		return

	var total_time := parry_window + recovery_time
	if timer >= total_time:
		transitioned.emit(self, "Idle", {})


func exit() -> void:
	parry_active = false
	player.is_parrying = false
	if player.hurtbox.hit_received.is_connected(_on_hit_during_parry):
		player.hurtbox.hit_received.disconnect(_on_hit_during_parry)


func _on_hit_during_parry(_hit_data: HitData, attacker: Node) -> void:
	if parry_active and not _hit_data.unblockable and (not _hit_data.ranged or player.parries_shots()):
		parry_succeeded = true
		var fl: Array = ActionSpecs.PARRIES.get(player.body_model.stance, [])
		if not fl.is_empty():
			player.body_model.play(fl[1], ActionSpecs.length(fl[1]))
		var fwd :=-player.player_model.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
		var to_att := fwd
		if attacker is Node3D:
			to_att = (attacker as Node3D).global_position - player.global_position
			to_att.y = 0.0
			to_att = to_att.normalized() if to_att.length() > 0.05 else fwd
		var at := player.global_position + Vector3(0, 1.25, 0) + to_att * 0.6
		Net.fx("parry_sparks", [at, to_att])
		if not _hit_data.ranged:
			CombatManager.guard(_hit_data, player.armed and player.weapon_class() == "sword", at, -2.0, 0.06, 1.05)
		Net.fx("sfx", ["parry", at, -6.0, 0.06, 1.0])
		var combat_mgr := get_node("/root/CombatManager")
		combat_mgr.apply_hitstop(0.1, [player, attacker])
		player.cam_shake(0.15)
		if not _hit_data.ranged:
			TraitMoves.on_parry(player, attacker)
			# (twin axes: the beards hook their weapon and haul them in a step, reeling)
			if player.style() == "dual_axe":
				DualAxeArts.hook(player, attacker)
			# (a greatsword turns it aside on the flat and shoves the blade out into them)
			elif player.style() == "greatsword":
				GreatswordArts.parried(player, attacker)
			# (black-leg drops onto a hand and sweeps their legs out)
			elif player.style() == "black_leg":
				BlackLegArts.parried(player, attacker)
		var pr := player.progression
		player.stamina = minf(player.stamina + pr.stat("parry_stamina"), player.max_stamina)
		pr.add_life("defense", 15)
		if timer <= PERFECT and not _hit_data.ranged and pr.has_flag("clean_parry") and attacker and attacker.has_method("perfect_parried"):
			_perfect(attacker, at, to_att)


## Clean Parry: caught the moment the guard went up. Disarm twists the weapon out of their hand, Shove throws them
## off their feet, otherwise they reel longer (PirateGrunt.perfect_parried, on the host). A white flash and a ring.
func _perfect(attacker: Node, at: Vector3, to_att: Vector3) -> void:
	var pr := player.progression
	var how := "disarm" if pr.has_flag("parry_disarm") else ("shove" if pr.has_flag("parry_shove") else "clean")
	attacker.call("perfect_parried", player, how)
	pr.add_life("defense", 10)
	Net.fx("flash", [at, 1.3, Color(1.0, 0.98, 0.9), "glint", 0.18])
	Net.fx("ring", [at, to_att, 0.8, Color(1.0, 0.97, 0.85, 0.9), 0.22, 0.07])
	Net.fx("float_text", [at + Vector3.UP * 0.6, {"disarm": "Disarmed!", "shove": "Shoved!"}.get(how, "Perfect!"), Color(1.0, 0.95, 0.75)])
	Net.fx("sfx", ["parry", at, -3.0, 0.04, 1.3])
	CombatManager.apply_hitstop(0.06, [player])
	player.cam_kick(0.12, 0.25)
	if how == "disarm":
		player.body_model.play("parry_disarm", ActionSpecs.length("parry_disarm"))
	elif how == "shove":
		player.body_model.play("parry_shove", ActionSpecs.length("parry_shove"))
		player.velocity += to_att * 2.0
		Net.fx("punch_wind", [at, to_att])
