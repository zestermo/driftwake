extends PlayerState
## Weapon and unarmed techniques (Skills entries with "state": "Technique"), and
## Conqueror's Haki. PowerComponent.try_cast puts you here with {"slot", "id"};
## Riposte's counter arrives with {"id": "riposte_counter", "target"}. Each one is
## a short timeline in seconds (t): pose, the moments it hits, recovery. Damage
## goes through Player.melee_hit(base, "skill"), so weapon bonuses and the tree's
## skill_ nodes apply.
##   cutlass  riposte (guard -> riposte_counter), swordfish, kraken_wake (ult)
##   katana   iai_counter (guard), wind_sever, phantom_step, petal_storm (ult)
##   axe      axe_throw, earthsplitter, berserk, maelstrom (ult)
##   dual     cross_counter (guard), blade_dance, cross_fang, steel_tempest (ult)
##   pistol   deadeye, smoke_bomb, point_blank, deaths_waltz (ult)
##   unarmed  suplex, hip_toss, giant_swing (grapples), hundred_fists,
##            rising_dragon, palm_strike, sea_king_fist (ult)
##   haki     conquerors_haki (ult)
## Grapples hold a light enemy (not bosses or big bugs) and carry it with the
## body; in co-op only the host moves it (a guest's grab throws it from where it stands).

const GRAB_REACH := 2.3
## The guard skills (Riposte, Iai Counter, Crossed Counter): the waiting pose, and
## per fighting style the answer [pose, length, damage].
const GUARD_POSE := {"riposte": "riposte_guard", "iai_counter": "iai_ready", "cross_counter": "cross_guard"}
const COUNTER_POSE := {"sword": ["riposte_cut", 0.5, 35.0], "katana": ["iai_slash", 0.6, 45.0], "dual_sword": ["dual_cross", 0.5, 40.0]}

var id: String = ""
var t: float = 0.0
var dur: float = 0.5
var _pc: PowerComponent
var _dir := Vector3.FORWARD
var _hits: int = 0
var _done: Dictionary = {}
var _target: Node3D
var _victims: Array = []
var _hit: Array = []
var _slot: int = -1
var _from := Vector3.ZERO
var _axe: Projectile


func enter(data: Dictionary) -> void:
	id = str(data.get("id", ""))
	_slot = int(data.get("slot", -1))
	_pc = player.power
	t = 0.0
	_hits = 0
	_done = {}
	_target = data.get("target") as Node3D
	_victims = []
	_hit = []
	player.sprinting = false
	player.is_parrying = false
	player.sword_hitbox.deactivate()
	player.reset_combo()
	_dir = get_camera_forward()
	_dir.y = 0.0
	_dir = _dir.normalized() if _dir.length() > 0.01 else -player.player_model.global_basis.z
	face_direction(_dir, 1.0)
	_from = player.global_position
	match id:
		"riposte", "iai_counter", "cross_counter":
			# guard up for a second; the buff outlasts it a touch so exit() can tell a
			# guard that timed out from one that was answered (the hit clears the buff)
			dur = 1.0
			_pc.add_buff("riposte", 1.05)
			player.body_model.play(GUARD_POSE[id], dur)
			Net.fx("sfx", ["blip_high", player.global_position, -10.0, 0.0, 1.2])
		"riposte_counter":
			var cp: Array = COUNTER_POSE[player.style()]
			dur = float(cp[1])
			if _target and is_instance_valid(_target):
				_dir = _flat_to(_target)
				face_direction(_dir, 1.0)
			player.body_model.play(str(cp[0]), dur)
			# the blow caught: sparks off the blade, a beat of slow time to answer in
			var clash := _chest() + Vector3(0, 0.15, 0) + _dir * 0.55
			Net.fx("sfx", ["parry", player.global_position, -2.0, 0.05, 1.1])
			Net.fx("parry_sparks", [clash, _dir])
			Net.fx("ring", [clash, _dir, 1.3, _col(), 0.2, 0.18])
			Net.fx("glint", [clash, _col(FX.CORE), 1.1])
			CombatManager.apply_hitstop(0.08, [player])
			CombatManager.apply_slowmo(0.35, 0.12, 0.12)
			CombatManager.apply_camera_kick(0.25, 0.4)
		"swordfish":
			dur = 0.95
			player.body_model.play("swordfish", dur)
		"kraken_wake":
			_victims = _closest(12.0, 6)
			dur = KRAKEN_GATHER + 0.14 * _victims.size() + 0.95
			player.hurtbox.set_deferred("monitorable", false)
			player.body_model.play("kraken_cut", dur)
			Net.fx("sfx", ["whoosh_big", player.global_position, -2.0, 0.05, 0.6])
			if _elem():
				Net.fx("gather", [player.global_position + Vector3(0, 0.9, 0), 2.6, _col(FX.ACCENT), 0.4, 26])
			else:
				Net.fx("dust_ring", [player.global_position, 12, 0.9])
			Net.fx("ring", [player.global_position, Vector3.UP, 3.5, _col(), 0.45, 0.08])
			_moment(0.4, 0.25, 0.45, 0.2)
		"wind_sever":
			dur = 0.75
			player.body_model.play("wind_sever", dur)
			Net.fx("sfx", ["whoosh", player.global_position, -9.0, 0.05, 0.7])
		"phantom_step":
			dur = 0.6
			_target = _aimed(9.0)
			if _target == null:
				_refund("Nobody close enough")
				return
			player.body_model.play("phantom_cut", dur)
			_blink_behind(_target)
		"petal_storm":
			dur = 2.0
			_victims = _closest(9.0, 99)
			player.hurtbox.set_deferred("monitorable", false)
			player.body_model.play("petal_storm", dur)
			Net.fx("sfx", ["whoosh", player.global_position, -6.0, 0.05, 0.6])
			if _elem():
				Net.fx("gather", [player.global_position + Vector3(0, 0.9, 0), 2.8, _col(FX.ACCENT), 0.38, 26])
			else:
				Net.fx("dust_ring", [player.global_position, 12, 0.9])
			Net.fx("ring", [player.global_position, Vector3.UP, 3.5, _col(), 0.45, 0.08])
			_moment(0.4, 0.25, 0.45, 0.2)
		"axe_throw":
			dur = 0.6
			player.body_model.play("axe_throw", dur)
		"earthsplitter":
			dur = 0.95
			player.velocity = _dir * 3.0 + Vector3.UP * 5.0
			player.body_model.play("earthsplitter", dur)
			Net.fx("sfx", ["whoosh_big", player.global_position, -4.0, 0.06, 0.75])
		"berserk":
			dur = 0.75
			player.body_model.play("berserk_roar", dur)
		"maelstrom":
			dur = 3.0
			player.body_model.play("maelstrom", dur)
			Net.fx("sfx", ["whoosh_big", player.global_position, 0.0, 0.05, 0.7])
		"blade_dance":
			dur = 1.0
			player.body_model.play("blade_dance", dur)
		"cross_fang":
			dur = 0.85
			# leap to land just in front of whoever you're facing (or 5 m on)
			var reach := 5.0
			var tgt := _aimed(8.0)
			if tgt:
				_dir = _flat_to(tgt)
				face_direction(_dir, 1.0)
				reach = maxf(Vector2(tgt.global_position.x - player.global_position.x, tgt.global_position.z - player.global_position.z).length() - 1.2, 0.0)
			player.velocity = _dir * reach / 0.6 + Vector3.UP * 5.5
			player.body_model.play("cross_fang", dur)
			Net.fx("sfx", ["whoosh_big", player.global_position, -4.0, 0.06, 1.2])
		"steel_tempest":
			dur = 2.2
			player.body_model.play("steel_tempest", dur)
		"deadeye":
			dur = 1.0
			player.body_model.play("deadeye", dur)
			Net.fx("sfx", ["blip_low", player.global_position, -10.0, 0.0, 0.8])
		"smoke_bomb":
			dur = 0.5
			player.body_model.play("smoke_throw", dur)
		"point_blank":
			dur = 0.6
			_target = _nearest(4.0, true)
			if _target:
				_dir = _flat_to(_target)
				face_direction(_dir, 1.0)
			player.body_model.play("point_blank", dur)
		"deaths_waltz":
			dur = 2.0
			_victims = _closest(18.0, 99)
			player.body_model.play("deaths_waltz", dur)
		"suplex", "hip_toss", "giant_swing":
			_target = _grab_target()
			if _target == null:
				_refund("Nobody to grab")
				return
			_dir = _flat_to(_target)
			face_direction(_dir, 1.0)
			dur = {"suplex": 1.1, "hip_toss": 0.95, "giant_swing": 2.1}[id]
			_target.call("grabbed", dur + 0.3)
			player.body_model.play({"suplex": "suplex", "hip_toss": "shoulder_throw", "giant_swing": "giant_swing"}[id], dur)
			Net.fx("sfx", ["hit", player.global_position, -6.0, 0.05, 0.7])
		"hundred_fists":
			dur = 1.3
			player.body_model.play("hundred_fists", dur)
		"rising_dragon":
			dur = 0.9
			player.body_model.play("rising_dragon", dur)
		"palm_strike":
			dur = 0.55
			player.body_model.play("palm_strike", dur)
		"sea_king_fist":
			dur = 1.45
			player.body_model.play("sea_king_fist", dur)
			Net.fx("sfx", ["haki", player.global_position, -4.0, 0.0, 0.6])
		"conquerors_haki":
			dur = 1.2
			player.body_model.play("conqueror", dur)
		_:
			dur = 0.1


func physics_update(delta: float) -> void:
	t += delta
	match id:
		"riposte", "iai_counter", "cross_counter":
			_rooted(delta, 0.15)
			# the waiting blade catches the light (the katana's waits in its scabbard: the hilt)
			if _once("glint", 0.12) or _once("glint2", 0.55):
				Net.fx("glint", [_hilt() if id == "iai_counter" else _blade_tip(), _col(FX.CORE), 0.7])
		"riposte_counter":
			_rooted(delta, 0.0)
			if _once("cut", 0.11):
				_riposte_cut()
			# the katana's answer: a beat later the blade is flicked clean
			if player.style() == "katana" and _once("flick", 0.4):
				Net.fx("glint", [_blade_tip(), _col(FX.CORE), 1.0])
				Net.fx("sfx", ["parry", player.global_position, -10.0, 0.0, 2.0])
				if _target and is_instance_valid(_target):
					_spray(_target.global_position + Vector3(0, 1.3, 0), Vector3.UP, 10, 2.0)
		"swordfish":
			_drift(delta, 3.0)
			if _once("ready", 0.04):
				Net.fx("glint", [_blade_tip(), _col(FX.CORE), 0.8])
			if _hits < 5 and t >= 0.12 + _hits * 0.12:
				_hits += 1
				var last := _hits == 5
				_cone(2.7, 0.6, 16.0 if last else 9.0, 10.0 if last else 3.0, last, false)
				var tip := _chest() + _dir * (1.5 if last else 1.2)
				Net.fx("slash", [player.player_model, "thrust", 0.14, _col(FX.ACCENT)])
				Net.fx("ring", [tip, _dir, 1.5 if last else 0.6, _col(), 0.24 if last else 0.14, 0.18])
				_spray(tip, _dir + Vector3.UP * 0.25, 14 if last else 4, 7.0 if last else 4.5)
				Net.fx("sfx", ["whoosh", player.global_position, -7.0, 0.1, 1.3 + _hits * 0.06])
				if last:
					Net.fx("streak", [_chest() + _dir * 0.4, _chest() + _dir * 3.6, _col(), 0.12, 0.22])
					Net.fx("sfx", ["whoosh_big", player.global_position, -4.0, 0.05, 1.3])
					CombatManager.apply_camera_kick(0.2, 0.35)
					player.squash(-2.0)
		"kraken_wake":
			_kraken(delta)
		"wind_sever":
			_rooted(delta, 0.0)
			# the blade low behind you draws the wind in, catches the light, then rises (0.34 s)
			if _once("gather", 0.08):
				Net.fx("gather", [_blade_tip(), 1.4, _col(FX.ACCENT) if _elem() else _col(), 0.22, 14])
			if _once("glint", 0.24):
				Net.fx("glint", [_blade_tip(), _col(FX.CORE), 0.9])
			if _once("swoosh", 0.28):
				Net.fx("blade_swoosh", [player.body_model, 0.16, _col()])
			if _once("fire", 0.34):
				var from := player.global_position + Vector3(0, 0.2, 0) + _dir * 0.8
				Projectile.launch(player.get_tree(), "wave", from, _dir, player, 34.0, "elem" if _elem() else "")
				Net.fx("sfx", ["whoosh_big", from, 0.0, 0.05, 0.8])
				Net.fx("dust", [from, 10, 0.8])
				Net.fx("ring", [from + Vector3(0, 0.9, 0) + _dir * 1.2, _dir, 1.2, _col(), 0.24, 0.14])
				_spray(from + Vector3(0, 0.6, 0), _dir + Vector3.UP * 0.8, 12, 4.0)
				CombatManager.apply_camera_shake(0.15)
				CombatManager.apply_camera_kick(0.15, 0.3)
				player.squash(-2.0)
		"phantom_step":
			_rooted(delta, 0.0)
			# arrived crouched behind them: the edge catches the light, then the cut (pose key 0.16 s)
			if _once("glint", 0.07):
				Net.fx("glint", [_blade_tip(), _col(FX.CORE), 0.8])
			if _once("swoosh", 0.12):
				Net.fx("blade_swoosh", [player.body_model, 0.14, _col()])
			if _once("cut", 0.16) and _target and is_instance_valid(_target):
				var hd := player.melee_hit(36.0, "skill")
				hd.stagger_duration = 0.8
				hd.knockback_force = 6.0
				hd.breaker = true
				hd.unblockable = true
				hd.sever = true
				hd.hitstop_duration = 0.07
				_strike(_target, hd)
				var at := _target.global_position + Vector3(0, 1.1, 0)
				Net.fx("impact", [at, _col(FX.ACCENT)])
				Net.fx("ring", [at, _dir, 1.2, _col(), 0.2, 0.14])
				_spray(at, _dir + Vector3.UP * 0.3, 10, 4.0)
				Net.fx("sfx", ["parry", player.global_position, -8.0, 0.05, 1.7])
				CombatManager.apply_camera_kick(0.15, 0.3)
		"petal_storm":
			_petals(delta)
		"axe_throw":
			_rooted(delta, 0.0)
			if _once("throw", 0.24):
				_throw_axe()
		"earthsplitter":
			apply_gravity(delta)
			player.velocity.x = move_toward(player.velocity.x, 0.0, 6.0 * delta)
			player.velocity.z = move_toward(player.velocity.z, 0.0, 6.0 * delta)
			player.move_and_slide()
			if not _done.has("slam") and t > 0.3 and (player.is_on_floor() or t > 0.7):
				_done["slam"] = true
				player.velocity = Vector3.ZERO
				_split(9.0, 1.9, 26.0)
		"berserk":
			_rooted(delta, 0.0)
			if _once("roar", 0.25):
				_pc.add_buff("berserk", 8.0)
				Net.fx("sparkle", [player.global_position + Vector3(0, 1.3, 0), 20, Color(1.0, 0.25, 0.2)])
				Net.fx("dust_ring", [player.global_position, 16, 1.1])
				Net.fx("sfx", ["thud", player.global_position, 2.0, 0.05, 0.6])
				CombatManager.apply_camera_shake(0.2)
		"maelstrom":
			_rooted(delta, 0.6)
			_spin_hits(3.2, 0.25, 9.0, 2.8, 30.0)
		"blade_dance":
			_drift(delta, 7.0)
			if _hits < 6 and t >= 0.1 + _hits * 0.13:
				_hits += 1
				_ring(2.2, 9.0 if _hits < 6 else 14.0, 4.0, _hits == 6, false)
				Net.fx("slash", [player.player_model, "spin", 0.16, Color(0.55, 0.85, 1.0)])
				Net.fx("sfx", ["whoosh", player.global_position, -7.0, 0.1, 1.2 + _hits * 0.05])
		"cross_fang":
			apply_gravity(delta)
			player.move_and_slide()
			if not _done.has("land") and t > 0.25 and (player.is_on_floor() or t > 0.7):
				_done["land"] = true
				player.velocity = Vector3.ZERO
				_cone(3.2, 0.75, 30.0, 9.0, true, true)
				Net.fx("slash", [player.player_model, "right", 0.3, Color(0.55, 0.85, 1.0)])
				Net.fx("slash", [player.player_model, "left", 0.3, Color(0.55, 0.85, 1.0)])
				Net.fx("dust_ring", [player.global_position, 14, 1.0])
				Net.fx("sfx", ["thud", player.global_position, 0.0, 0.05, 1.0])
				CombatManager.apply_camera_shake(0.2)
		"steel_tempest":
			_rooted(delta, 0.0)
			_spin_hits(3.5, 0.18, 8.0, 1.9, 40.0)
		"deadeye":
			_rooted(delta, 0.0)
			face_camera(delta)
			if _once("fire", 0.55):
				_deadeye()
		"smoke_bomb":
			_rooted(delta, 0.0)
			if _once("pop", 0.18):
				_smoke()
		"point_blank":
			if t < 0.15 and _target and is_instance_valid(_target) and player.global_position.distance_to(_target.global_position) > 1.3:
				player.velocity.x = _dir.x * 12.0
				player.velocity.z = _dir.z * 12.0
				apply_gravity(delta)
				player.move_and_slide()
			else:
				_rooted(delta, 0.0)
			if _once("fire", 0.2):
				_point_blank()
		"deaths_waltz":
			_rooted(delta, 0.0)
			_waltz()
		"suplex":
			_rooted(delta, 0.0)
			_suplex()
		"hip_toss":
			_rooted(delta, 0.0)
			_hip_toss()
		"giant_swing":
			_rooted(delta, 0.0)
			_giant_swing()
		"hundred_fists":
			_drift(delta, 1.2)
			if t >= 0.1 and t < 1.0 and t >= 0.1 + _hits * 0.07:
				_hits += 1
				_cone(2.1, 0.65, 3.0, 1.0, false, false, 0.0)
				if _hits % 3 == 0:
					Net.fx("punch_wind", [_chest() + _dir * 0.3 + Vector3(randf_range(-0.25, 0.25), randf_range(-0.15, 0.15), 0), _dir, 1.0, Color(1.0, 0.97, 0.9), false])
					Net.fx("sfx", ["whoosh", player.global_position, -10.0, 0.15, 1.6])
			if _once("final", 1.05):
				_cone(2.4, 0.7, 22.0, 12.0, false, true)
				Net.fx("punch_wind", [_chest() + _dir * 0.3, _dir, 1.6, Color(1.0, 0.97, 0.9), true])
				CombatManager.apply_camera_shake(0.18)
		"rising_dragon":
			_dragon(delta)
		"palm_strike":
			_rooted(delta, 0.0)
			if _once("palm", 0.2):
				_palm()
		"sea_king_fist":
			_rooted(delta, 0.0)
			if t < 0.75 and int(t * 20.0) % 3 == 0:
				Net.fx("dust", [player.global_position + Vector3(randf_range(-1.2, 1.2), 0.05, randf_range(-1.2, 1.2)), 2, 0.5])
				CombatManager.apply_camera_shake(0.03 + t * 0.05)
			if _once("punch", 0.78):
				_sea_king()
		"conquerors_haki":
			_rooted(delta, 0.0)
			if _once("will", 0.38):
				_conquer()
	if t >= dur:
		_finish()


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
## The tree whose colours this technique wears (FX.TREE_FX).
func _tree() -> String:
	if id == "riposte_counter":
		return {"katana": "katana", "dual_sword": "dual"}.get(player.style(), "sword")
	var tr := str(Skills.get_skill(id).get("tree", "base"))
	return tr if FX.TREE_FX.has(tr) else "haki"


## The tree's element awakened (its first mastery passive): until then the
## technique shows plain steel, no element.
func _elem() -> bool:
	return player.progression.elemental(_tree())


func _col(which: int = 1) -> Color:
	return FX.tree_col(_tree() if _elem() else "plain", which)


## The element thrown along `dir` (sea spray for the cutlass, petals for the
## katana), if it's awakened.
func _spray(at: Vector3, dir: Vector3, amount: int, speed: float) -> void:
	if _elem():
		Net.fx("petals" if _tree() == "katana" else "spray", [at, dir, amount, _col(FX.ACCENT), speed])


## Where the held blade's point is (FX at the tip).
func _blade_tip() -> Vector3:
	var w: MeshInstance3D = player.body_model.weapon
	if w == null or not is_instance_valid(w) or w.mesh == null:
		return _chest() + _dir * 0.7
	return w.global_transform * Vector3(0, 0, w.mesh.get_aabb().position.z * 0.85)


## An ultimate's moment: time slows, the camera punches in, a flash.
func _moment(slow: float, secs: float, kick: float, flash: float = 0.3) -> void:
	CombatManager.apply_slowmo(slow, secs)
	CombatManager.apply_camera_kick(kick, secs + 0.45)
	var c := _col(FX.CORE)
	Net.fx("screen_flash", [player.global_position, Color(c.r, c.g, c.b, flash), 0.3])


## True the first frame t passes `at` (one-shot events).
func _once(key: String, at: float) -> bool:
	if _done.has(key) or t < at:
		return false
	_done[key] = true
	return true


func _flat_to(e: Node3D) -> Vector3:
	var d := e.global_position - player.global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.05 else _dir


func _chest() -> Vector3:
	return player.global_position + Vector3(0, 1.2, 0)


## Living enemies within reach, closest first (at most `n`).
func _closest(reach: float, n: int) -> Array:
	var list: Array = _pc.enemies_in(player.global_position + Vector3(0, 0.9, 0), reach)
	list.sort_custom(func(a, b): return (a as Node3D).global_position.distance_to(player.global_position) < (b as Node3D).global_position.distance_to(player.global_position))
	return list.slice(0, n)


## The nearest enemy (in front of the camera if `front`).
func _nearest(reach: float, front: bool) -> Node3D:
	for e in _closest(reach, 99):
		if not front or _flat_to(e).dot(_dir) > 0.2:
			return e
	return null


## The enemy closest to where you're looking (within reach, roughly ahead).
func _aimed(reach: float) -> Node3D:
	var best: Node3D = null
	var best_dot := 0.5
	for e in _closest(reach, 99):
		var dt := _flat_to(e).dot(_dir)
		if dt > best_dot:
			best_dot = dt
			best = e
	return best


## A light enemy right in front of you (bosses and big bugs are too heavy).
func _grab_target() -> Node3D:
	for e in _closest(GRAB_REACH, 6):
		if _flat_to(e).dot(_dir) < 0.3 or e.is_in_group("bosses"):
			continue
		if e.has_method("vine_weight") and str(e.call("vine_weight")) == "light" and e.has_method("grabbed"):
			return e
	return null


## Nothing to use it on: the cast is given back.
func _refund(why: String) -> void:
	if _slot == 4:
		_pc.ult = PowerComponent.ULT_MAX
	else:
		_pc.energy += float(Skills.get_skill(id).get("cost", 0.0))
	_pc.cooldowns[id] = 0.0
	player.call("_toast", why)
	dur = 0.0


func _strike(e: Node3D, hd: HitData) -> void:
	var hb := e.get("hurtbox") as Hurtbox
	if hb == null:
		return
	hb.take_hit(hd, player)
	_pc.add_ult(hd.damage)
	_pc.on_sword_hit(e, hd)


## Strike `e` so the knockback carries it along `push` (a stand-in attacker
## behind it decides the direction).
func _strike_toward(e: Node3D, hd: HitData, push: Vector3) -> void:
	var hb := e.get("hurtbox") as Hurtbox
	if hb == null:
		return
	_pc._proxy.global_position = e.global_position - push.normalized() * 2.0
	hb.take_hit(hd, _pc._proxy)
	_pc.add_ult(hd.damage)
	_pc.on_sword_hit(e, hd)


func _hd(base: float, knock: float, down: bool) -> HitData:
	var hd := player.melee_hit(base, "skill")
	hd.knockback_force = knock
	hd.knockdown = down
	hd.stagger_duration = 0.5 if down else 0.3
	hd.hitstop_duration = 0.07 if down else 0.03
	hd.camera_shake_intensity = 0.15 if down else 0.05
	return hd


## Everyone within `reach` in front (cos half-angle `cone`).
func _cone(reach: float, cone: float, base: float, knock: float, down: bool, unblock: bool, stagger: float = -1.0) -> Array:
	var out: Array = []
	for e in _pc.enemies_in(player.global_position + Vector3(0, 0.9, 0) + _dir * reach * 0.5, reach):
		var d := (e as Node3D).global_position - player.global_position
		d.y = 0.0
		if d.length() > reach or (d.length() > 0.6 and d.normalized().dot(_dir) < cone):
			continue
		var hd := _hd(base, knock, down)
		hd.unblockable = hd.unblockable or unblock
		if stagger >= 0.0:
			hd.stagger_duration = stagger
			hd.hitstop_duration = 0.0
			hd.camera_shake_intensity = 0.0
		_strike(e, hd)
		out.append(e)
	return out


## Everyone around you.
func _ring(reach: float, base: float, knock: float, down: bool, inward: bool) -> void:
	for e in _pc.enemies_in(player.global_position + Vector3(0, 0.9, 0), reach):
		var hd := _hd(base, knock, down)
		if inward:
			_strike_toward(e, hd, player.global_position - (e as Node3D).global_position)
		else:
			_strike(e, hd)


## Spinning ultimates: a hit all round every `every` s (dragging them in), then
## a last burst at `end_t` that throws them out.
func _spin_hits(reach: float, every: float, base: float, end_t: float, final: float) -> void:
	if t < end_t and t >= 0.15 + _hits * every:
		_hits += 1
		_ring(reach, base, 2.5, false, true)
		Net.fx("slash", [player.player_model, "spin", 0.18, Color(0.85, 0.92, 1.0)])
		Net.fx("sfx", ["whoosh", player.global_position, -6.0, 0.1, 1.0 + 0.04 * (_hits % 5)])
	if _once("burst", end_t):
		_ring(reach + 0.5, final, 11.0, true, false)
		Net.fx("dust_ring", [player.global_position, 18, 1.3])
		Net.fx("sfx", ["whoosh_big", player.global_position, 2.0, 0.05, 0.8])
		CombatManager.apply_camera_shake(0.3)


func _drift(delta: float, spd: float) -> void:
	apply_gravity(delta)
	player.velocity.x = _dir.x * spd
	player.velocity.z = _dir.z * spd
	player.move_and_slide()


## Stand your ground (a little drift allowed so it doesn't feel glued).
func _rooted(delta: float, keep: float) -> void:
	apply_gravity(delta)
	var mi := get_movement_input()
	var want := get_camera_relative_direction(mi) * player.move_speed * keep if mi.length() > 0.1 else Vector3.ZERO
	player.velocity.x = move_toward(player.velocity.x, want.x, 30.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, want.z, 30.0 * delta)
	player.move_and_slide()


func _place(p: Vector3) -> void:
	player.global_position = p
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


## Blink to just behind `e` (on its far side from you), facing it.
func _blink_behind(e: Node3D) -> void:
	var d := _flat_to(e)
	var from := _chest()
	Net.fx("afterimage", [player.body_model, _col(), 0.35])
	Net.fx("sfx", ["whoosh_big", player.global_position, -3.0, 0.05, 1.6])
	_place(e.global_position + d * 1.3)
	_dir = -d
	face_direction(_dir, 1.0)
	Net.fx("streak", [from, _chest(), _col(), 0.12, 0.3])
	Net.fx("dust", [player.global_position + Vector3(0, 0.05, 0), 6, 0.5])


func _finish() -> void:
	if not player.is_on_floor():
		transitioned.emit(self, "Fall", {})
	elif get_movement_input().length() > 0.1:
		transitioned.emit(self, "Move", {})
	else:
		transitioned.emit(self, "Idle", {})


# --------------------------------------------------------------------------
# Cutlass
# --------------------------------------------------------------------------
func _riposte_cut() -> void:
	var st := player.style()
	var base := float((COUNTER_POSE[st] as Array)[2])
	var hd := _hd(base, 9.0, false)
	hd.stagger_duration = 0.9
	hd.unblockable = true
	hd.sever = true
	if _target and is_instance_valid(_target) and _target.get("hurtbox") is Hurtbox:
		_strike(_target, hd)
		var at := _target.global_position + Vector3(0, 1.0, 0)
		Net.fx("impact", [at, _col(FX.ACCENT)])
		Net.fx("ring", [at, _dir, 1.2, _col(), 0.22, 0.2])
	else:
		_cone(2.4, 0.5, base, 9.0, false, true)
	match st:
		"katana":
			# out of the scabbard in one line through them
			Net.fx("blade_swoosh", [player.body_model, 0.12, _col()])
			Net.fx("afterimage", [player.body_model, _col(), 0.25])
			var right := _dir.cross(Vector3.UP)
			Net.fx("streak", [_chest() + _dir * 0.6 - right * 1.2, _chest() + _dir * 0.9 + right * 1.6, _col(), 0.08, 0.25])
		"dual_sword":
			Net.fx("slash", [player.player_model, "right", 0.25, _col()])
			Net.fx("slash", [player.player_model, "left", 0.25, _col(FX.ACCENT)])
		_:
			# the backhand answer: the real blade's trail, spray thrown off its edge
			Net.fx("blade_swoosh", [player.body_model, 0.1, _col()])
			var right := _dir.cross(Vector3.UP)
			_spray(_chest() + _dir * 0.8, right * 0.8 + _dir * 0.6 + Vector3.UP * 0.2, 12, 6.0)
	CombatManager.apply_camera_shake(0.15)


## Kraken's Wake: the sea gathers round you, you blink from one victim to the
## next leaving a wake of light, then stand with your back to them as the sea
## tears up under every one of them.
const KRAKEN_GATHER := 0.45

func _kraken(delta: float) -> void:
	var i := int((t - KRAKEN_GATHER) / 0.14)
	if t >= KRAKEN_GATHER and i < _victims.size() and not _done.has("v%d" % i):
		_done["v%d" % i] = true
		var e: Node3D = _victims[i]
		if is_instance_valid(e):
			Net.fx("afterimage", [player.body_model, _col(), 0.3])
			var from := _chest()
			var through := _flat_to(e)
			_place(e.global_position + through * 1.4)
			_dir = through
			face_direction(_dir, 1.0)
			_strike(e, _hd(10.0, 0.0, false))
			var at := e.global_position + Vector3(0, 1.0, 0)
			Net.fx("streak", [from, _chest(), _col(), 0.16, 0.35])
			Net.fx("blade_swoosh", [player.body_model, 0.1, _col()])
			_spray(at, through + Vector3.UP * 0.4, 12, 6.0)
			Net.fx("glint", [at, _col(FX.CORE), 1.0])
			Net.fx("sfx", ["whoosh", player.global_position, -4.0, 0.1, 1.5])
	else:
		_rooted(delta, 0.0)
	# the sea draws up round you while you gather
	if t < KRAKEN_GATHER and int(t * 12.0) != int((t - delta) * 12.0):
		_spray(player.global_position + Vector3(randf_range(-1.6, 1.6), 0.1, randf_range(-1.6, 1.6)), Vector3.UP, 4, 3.0)
	# a held breath with your back to them, then it all tears open
	if _once("still", dur - 0.75):
		Net.fx("glint", [_blade_tip(), _col(FX.CORE), 1.3])
		Net.fx("sfx", ["parry", player.global_position, -6.0, 0.0, 1.9])
	if _once("tear", dur - 0.55):
		player.hurtbox.set_deferred("monitorable", true)
		var k := 0
		for e in _victims:
			if is_instance_valid(e) and BurnStatus.alive(e):
				var hd := _hd(45.0, 10.0, true)
				hd.unblockable = true
				hd.sever = true
				_strike(e, hd)
				var at := (e as Node3D).global_position
				if _elem():
					Net.fx("water_tentacles", [at, 3.2, _col(), 4, k * 17 + 3])
				else:
					Net.fx("ring", [at, Vector3.UP, 2.2, _col(), 0.35, 0.12])
					Net.fx("dust_ring", [at, 12, 1.0])
				Net.fx("impact", [at + Vector3(0, 1.0, 0), _col(FX.ACCENT)])
				k += 1
		Net.fx("ring", [player.global_position, Vector3.UP, 9.0, _col(), 0.6, 0.06])
		if _elem():
			Net.fx("sfx", ["splash_big", player.global_position, 2.0, 0.05, 0.8])
		Net.fx("sfx", ["whoosh_big", player.global_position, 3.0, 0.05, 0.6])
		CombatManager.apply_camera_shake(0.5)
		CombatManager.apply_hitstop(0.1, [player])
		_moment(0.3, 0.35, 0.7, 0.45)


# --------------------------------------------------------------------------
# Katana
# --------------------------------------------------------------------------
## Thousand Petals: crouched with the hand on the hilt while it gathers, one wide
## drawing cut, then cuts flash through everyone in reach as the blade slides
## home; on the click it's sheathed and they all fall.
const PETAL_DRAW := 0.46
const PETAL_CLICK := 1.4

func _petals(delta: float) -> void:
	_rooted(delta, 0.0)
	if _once("glint", PETAL_DRAW - 0.1):
		Net.fx("glint", [_hilt(), _col(FX.CORE), 1.0])
	if _once("draw", PETAL_DRAW):
		Net.fx("blade_swoosh", [player.body_model, 0.2, _col()])
		Net.fx("afterimage", [player.body_model, _col(), 0.3])
		Net.fx("ring", [player.global_position + Vector3(0, 1.0, 0), Vector3.UP, 9.0, _col(), 0.3, 0.05])
		Net.fx("sfx", ["whoosh_big", player.global_position, -1.0, 0.05, 1.4])
		CombatManager.apply_camera_kick(0.25, 0.4)
		var k := 0
		for e in _victims:
			if is_instance_valid(e):
				Net.fx("cut_lines", [(e as Node3D).global_position, 12, _col(FX.CORE), PETAL_CLICK - PETAL_DRAW - 0.15, k * 31 + 7])
				k += 1
	# petals swirl round them while the cuts land
	if t > PETAL_DRAW + 0.1 and t < PETAL_CLICK and int(t / 0.15) != int((t - delta) / 0.15):
		for e in _victims:
			if is_instance_valid(e):
				_spray((e as Node3D).global_position + Vector3(0, 1.0, 0), Vector3.UP, 3, 1.5)
	if _once("click", PETAL_CLICK):
		player.hurtbox.set_deferred("monitorable", true)
		Net.fx("sfx", ["parry", player.global_position, 0.0, 0.0, 1.8])
		Net.fx("glint", [_hilt(), _col(FX.CORE), 1.4])
		for e in _victims:
			if is_instance_valid(e) and BurnStatus.alive(e):
				var hd := _hd(70.0, 6.0, true)
				hd.crumple = true
				hd.sever = true
				hd.unblockable = true
				_strike(e, hd)
				var at := (e as Node3D).global_position
				Net.fx("impact", [at + Vector3(0, 1.1, 0), _col(FX.ACCENT)])
				Net.fx("ring", [at, Vector3.UP, 2.0, _col(), 0.35, 0.1])
				if _elem():
					Net.fx("petals", [at + Vector3(0, 1.0, 0), Vector3.UP, 26, _col(FX.ACCENT), 5.0])
				else:
					Net.fx("dust_ring", [at, 10, 0.9])
		Net.fx("ring", [player.global_position, Vector3.UP, 9.0, _col(), 0.6, 0.06])
		CombatManager.apply_camera_shake(0.4)
		CombatManager.apply_hitstop(0.12, [player])
		_moment(0.3, 0.35, 0.7, 0.45)


## The katana's hilt (where the hand waits on it while it's sheathed).
func _hilt() -> Vector3:
	return (player.body_model.weapon as Node3D).global_position


# --------------------------------------------------------------------------
# Axe
# --------------------------------------------------------------------------
func _throw_axe() -> void:
	var from := player.global_position + Vector3(0, 1.3, 0) + _dir * 0.6
	# thrown where you aim (snapping onto an enemy near the reticle), never steeply
	var d := (_reticle_target(14.0) - from).normalized()
	d.y = clampf(d.y, -0.4, 0.3)
	_axe = Projectile.launch(player.get_tree(), "axe", from, d.normalized(), player, 24.0, player.equipped_weapon.model())
	var held: Node3D = player.body_model.weapon
	if held:
		held.visible = false
		_axe.returned.connect(func():
			if is_instance_valid(held):
				held.visible = true
			Net.fx("sfx", ["blip_low", player.global_position, -8.0, 0.05, 0.9]))
	Net.fx("sfx", ["whoosh_big", from, -2.0, 0.05, 0.9])


## A crack splitting the ground ahead: everyone on the line is knocked flat.
func _split(length: float, width: float, base: float) -> void:
	var start := player.global_position + _dir * 0.8
	for i in range(8):
		var p := start + _dir * (i * length / 7.0)
		Net.fx("dust", [p + Vector3(0, 0.05, 0), 6, 0.6 + i * 0.06])
	Net.fx("dust_ring", [start, 14, 1.0])
	Net.fx("impact", [start + Vector3(0, 0.2, 0), Color(1.0, 0.85, 0.55)])
	Net.fx("sfx", ["thud", start, 3.0, 0.05, 0.65])
	Net.fx("sfx", ["crunch", start + _dir * 3.0, -1.0, 0.05, 0.55])
	CombatManager.apply_camera_shake(0.35)
	player.squash(-4.5)
	for e in _pc.enemies_in(start + _dir * length * 0.5 + Vector3(0, 0.8, 0), length * 0.6):
		var rel := (e as Node3D).global_position - start
		rel.y = 0.0
		var along := rel.dot(_dir)
		if along < -0.5 or along > length or (rel - _dir * along).length() > width:
			continue
		var hd := _hd(base, 9.0, true)
		hd.unblockable = true
		_strike(e, hd)


# --------------------------------------------------------------------------
# Pistol
# --------------------------------------------------------------------------
func _muzzle() -> Vector3:
	return player.global_position + Vector3(0, 1.35, 0) + _dir * 0.7


## The middle of an enemy's body: its hurtbox shape (the Hurtbox node itself sits
## at the feet).
func _body_center(e: Node) -> Vector3:
	return ((e.get("hurtbox") as Node).get_child(0) as Node3D).global_position


## Where the reticle points, snapped onto an enemy's chest within a few degrees of it.
func _reticle_target(reach: float) -> Vector3:
	var ray: Array = player.reticle_ray()
	var o: Vector3 = ray[0]
	var cd: Vector3 = ray[1]
	var best_a := 0.12
	var best := Vector3.INF
	for e in _pc.enemies_in(player.global_position, reach):
		var c := _body_center(e)
		var a := cd.angle_to(c - o)
		if a < best_a:
			best_a = a
			best = c
	if best != Vector3.INF:
		return best
	var q := PhysicsRayQueryParameters3D.create(o, o + cd * reach, 1 | 4)
	q.exclude = [player.get_rid()]
	var h := player.get_world_3d().direct_space_state.intersect_ray(q)
	return (h["position"] as Vector3) if not h.is_empty() else o + cd * reach


func _deadeye() -> void:
	var from := _muzzle()
	var cf := (_reticle_target(50.0) - from).normalized()
	var end := from + cf * 50.0
	var wq := PhysicsRayQueryParameters3D.create(from, end, 1)
	wq.exclude = [player.get_rid()]
	var wall := player.get_world_3d().direct_space_state.intersect_ray(wq)
	if not wall.is_empty():
		end = wall["position"]
	var length := from.distance_to(end)
	for e in _pc.enemies_in(from.lerp(end, 0.5), length * 0.5 + 1.0):
		var c := _body_center(e)
		var along := (c - from).dot(cf)
		if along < 0.0 or along > length or (c - (from + cf * along)).length() > 0.9:
			continue
		var hd := _hd(60.0, 8.0, false)
		hd.ranged = true
		hd.stagger_duration = 0.6
		_strike(e, hd)
		Net.fx("impact", [c, Color(1.0, 0.75, 0.45)])
	Net.fx("tracer", [from, end])
	Net.fx("muzzle_sparks", [from, cf, 14])
	Net.fx("smoke", [from + cf * 0.3, 8, 0.9, 1.6])
	Net.fx("sfx", ["gunshot", from, 3.0, 0.03, 0.8])
	CombatManager.apply_camera_shake(0.2)


func _smoke() -> void:
	var at := player.global_position + _dir * 0.6
	for i in range(10):
		Net.fx("smoke", [at + Vector3(randf_range(-1.8, 1.8), randf_range(0.2, 1.4), randf_range(-1.8, 1.8)), 6, 1.6, 2.5])
	Net.fx("sfx", ["thud", at, -2.0, 0.05, 1.4])
	for e in _pc.enemies_in(at + Vector3(0, 0.9, 0), 4.5):
		var hd := HitData.new()
		hd.damage = 2.0
		hd.stagger_duration = 1.3
		hd.knockback_force = 1.5
		hd.unblockable = true
		(e.get("hurtbox") as Hurtbox).take_hit(hd, player)
	player.vanish(1.5)


func _point_blank() -> void:
	var from := _muzzle()
	var hits := _cone(3.2, 0.6, 32.0, 13.0, true, true)
	for e in hits:
		Net.fx("impact", [(e as Node3D).global_position + Vector3(0, 1.0, 0), Color(1.0, 0.75, 0.45)])
	Net.fx("muzzle_sparks", [from, _dir, 18])
	Net.fx("smoke", [from + _dir * 0.4, 6, 0.8, 1.2])
	Net.fx("sfx", ["gunshot", from, 2.0, 0.05, 0.75])
	CombatManager.apply_camera_shake(0.22)


func _waltz() -> void:
	if _victims.is_empty():
		return
	var total := _victims.size() * 3
	var due := int((t - 0.2) / (1.5 / float(total))) + 1
	while _hits < mini(due, total) and t >= 0.2:
		var e: Node3D = _victims[_hits % _victims.size()]
		var final := _hits >= total - _victims.size()
		_hits += 1
		if not is_instance_valid(e) or not BurnStatus.alive(e):
			continue
		var c := e.global_position + Vector3(0, 1.0, 0)
		var hd := _hd(20.0 if final else 12.0, 6.0 if final else 2.0, final)
		hd.ranged = true
		_strike(e, hd)
		var from := player.global_position + Vector3(0, 1.35, 0) + (c - player.global_position).normalized() * 0.6
		Net.fx("tracer", [from, c])
		Net.fx("muzzle_sparks", [from, (c - from).normalized(), 6])
		Net.fx("sfx", ["gunshot", from, -5.0, 0.1, 1.2])


# --------------------------------------------------------------------------
# Unarmed: grapples
# --------------------------------------------------------------------------
## Carry the grabbed enemy (the host moves it; a guest's stays where it stood).
func _carry(p: Vector3) -> void:
	if _target == null or not is_instance_valid(_target) or Net.is_client():
		return
	_target.global_position = p
	if _target is CharacterBody3D:
		(_target as CharacterBody3D).velocity = Vector3.ZERO
	_target.reset_physics_interpolation()


## Where a thrown body lands: everyone close goes down too (more with Heavy Landing).
func _landing(at: Vector3) -> void:
	var big := player.progression.has_flag("throw_splash")
	var r := 3.2 if big else 1.8
	Net.fx("dust_ring", [at, 14 if big else 8, 1.2 if big else 0.8])
	Net.fx("sfx", ["thud", at, 0.0, 0.05, 0.8])
	for e in _pc.enemies_in(at + Vector3(0, 0.8, 0), r):
		if e == _target:
			continue
		var hd := _hd(20.0 if big else 10.0, 7.0, true)
		_strike_toward(e, hd, (e as Node3D).global_position - at)


func _suplex() -> void:
	var fwd := _dir
	if t < 0.3:
		_carry(player.global_position + fwd * 0.75 + Vector3.UP * 0.15)
	elif t < 0.66:
		# over your head in an arch and down behind you
		var k := clampf((t - 0.3) / 0.36, 0.0, 1.0)
		var a := PI * k
		_carry(player.global_position + fwd * cos(a) * 0.8 + Vector3.UP * (0.15 + 1.5 * sin(a)))
	if _once("slam", 0.66) and _target and is_instance_valid(_target):
		var behind := player.global_position - fwd * 1.0
		var hd := _hd(40.0, 5.0, true)
		hd.unblockable = true
		hd.hitstop_duration = 0.12
		_strike_toward(_target, hd, -fwd)
		_landing(behind)
		player.squash(-4.0)
		CombatManager.apply_camera_shake(0.3)


func _hip_toss() -> void:
	var fwd := _dir
	if t < 0.25:
		_carry(player.global_position + fwd * 0.7 + Vector3.UP * 0.1)
	elif t < 0.5:
		var k := clampf((t - 0.25) / 0.25, 0.0, 1.0)
		_carry(player.global_position + fwd * (0.4 + 1.6 * k) + Vector3.UP * (0.1 + 1.6 * sin(k * PI * 0.8)))
	if _once("throw", 0.5) and _target and is_instance_valid(_target):
		var hd := _hd(28.0, 12.0, true)
		hd.unblockable = true
		_strike_toward(_target, hd, fwd)
		Net.fx("sfx", ["whoosh_big", player.global_position, -2.0, 0.05, 1.1])
	if _once("land", 0.82):
		_landing(player.global_position + fwd * 4.5)


func _giant_swing() -> void:
	var fwd := _dir
	if t < 0.3:
		_carry(player.global_position + fwd * 0.75 + Vector3.UP * 0.1)
		return
	if t < 1.6:
		# matches the pose: three turns, the body swung out at arm's length
		var k := clampf((t - 0.3) / 1.3, 0.0, 1.0)
		var ang := TAU * 3.0 * (1.0 - pow(1.0 - k, 1.6))
		var out := fwd.rotated(Vector3.UP, -ang)
		_carry(player.global_position + out * 1.7 + Vector3.UP * 0.75)
		if t >= 0.4 + _hits * 0.15:
			_hits += 1
			for e in _pc.enemies_in(player.global_position + Vector3(0, 0.9, 0), 2.8):
				if e != _target and not (e in _hit):
					_hit.append(e)
					_strike_toward(e, _hd(14.0, 8.0, true), (e as Node3D).global_position - player.global_position)
			Net.fx("sfx", ["whoosh", player.global_position, -5.0, 0.1, 0.9])
	if _once("let_go", 1.6) and _target and is_instance_valid(_target):
		var hd := _hd(30.0, 14.0, true)
		hd.unblockable = true
		_strike_toward(_target, hd, fwd.rotated(Vector3.UP, -TAU * 3.0 - 0.6))
		Net.fx("sfx", ["whoosh_big", player.global_position, 0.0, 0.05, 0.8])
		CombatManager.apply_camera_shake(0.25)


# --------------------------------------------------------------------------
# Unarmed: martial arts
# --------------------------------------------------------------------------
func _dragon(delta: float) -> void:
	if _once("launch", 0.16):
		player.velocity = _dir * 3.0 + Vector3.UP * 9.0
		var hits := _cone(2.4, 0.5, 26.0, 4.0, true, false)
		Net.fx("punch_wind", [_chest() + _dir * 0.4, Vector3.UP, 1.6, Color(1.0, 0.97, 0.9), true])
		Net.fx("dust_ring", [player.global_position, 12, 0.9])
		Net.fx("sfx", ["whoosh_big", player.global_position, -2.0, 0.05, 1.2])
		CombatManager.apply_camera_shake(0.2 if hits.size() > 0 else 0.1)
	if t < 0.16:
		_rooted(delta, 0.0)
	else:
		apply_gravity(delta)
		player.move_and_slide()


## Everyone in the cone is blown back; those close enough are thrown off their feet.
func _palm() -> void:
	for e in _pc.enemies_in(player.global_position + Vector3(0, 0.9, 0) + _dir * 2.5, 5.0):
		var d := (e as Node3D).global_position - player.global_position
		d.y = 0.0
		if d.length() > 5.0 or (d.length() > 0.6 and d.normalized().dot(_dir) < 0.6):
			continue
		var hd := _hd(18.0, 15.0, d.length() < 3.0)
		hd.unblockable = true
		_strike_toward(e, hd, _flat_to(e))
	Net.fx("punch_wind", [_chest() + _dir * 0.3, _dir, 2.2, Color(1.0, 0.97, 0.9), true])
	Net.fx("dust", [player.global_position + _dir * 1.5, 10, 0.8])
	Net.fx("sfx", ["whoosh_big", player.global_position, -1.0, 0.05, 1.3])
	CombatManager.apply_camera_shake(0.2)


func _sea_king() -> void:
	var start := player.global_position
	var length := 14.0
	for e in _pc.enemies_in(start + _dir * length * 0.5 + Vector3(0, 0.9, 0), length * 0.6):
		var rel := (e as Node3D).global_position - start
		rel.y = 0.0
		var along := rel.dot(_dir)
		if along < -0.5 or along > length or (rel - _dir * along).length() > 2.6:
			continue
		var hd := _hd(60.0, 16.0, true)
		hd.unblockable = true
		_strike_toward(e, hd, _dir)
	for i in range(7):
		var p := start + _dir * (1.0 + i * 2.0)
		Net.fx("dust", [p + Vector3(0, 0.05, 0), 8, 0.9])
		Net.fx("punch_wind", [p + Vector3(0, 1.1, 0), _dir, 2.0, Color(1.0, 0.97, 0.9), true])
	Net.fx("dust_ring", [start, 18, 1.4])
	Net.fx("sfx", ["thud", start, 4.0, 0.03, 0.55])
	Net.fx("sfx", ["whoosh_big", start, 2.0, 0.05, 0.6])
	CombatManager.apply_camera_shake(0.5)
	CombatManager.apply_hitstop(0.1, [player])
	player.squash(-3.5)


# --------------------------------------------------------------------------
# Conqueror's Haki
# --------------------------------------------------------------------------
func _conquer() -> void:
	var c := player.global_position
	Net.fx("dust_ring", [c, 24, 1.6])
	Net.fx("sparkle", [c + Vector3(0, 1.4, 0), 30, Color(0.95, 0.2, 0.25)])
	Net.fx("punch_wind", [c + Vector3.UP * 1.2, Vector3.UP, 0.8, Color(0.2, 0.05, 0.08), true])
	Net.fx("sfx", ["haki", c, 3.0, 0.0, 0.55])
	Net.fx("sfx", ["thud", c, 2.0, 0.0, 0.5])
	CombatManager.apply_camera_shake(0.45)
	for e in _pc.enemies_in(c + Vector3(0, 0.9, 0), 14.0):
		var hb := e.get("hurtbox") as Hurtbox
		var hc = e.get("health")
		if hb == null:
			continue
		var weak: bool = hc is HealthComponent and not e.is_in_group("bosses") and hc.current_health < hc.max_health * 0.4
		var hd := HitData.new()
		hd.unblockable = true
		hd.haki = true
		if weak:
			# fainted where they stand
			hd.damage = hc.current_health + 1.0
			hd.knockdown = true
			hd.crumple = true
			hd.knockback_force = 1.0
			Net.fx("float_text", [(e as Node3D).global_position + Vector3(0, 2.0, 0), "Fainted", Color(0.95, 0.3, 0.3)])
		else:
			hd.damage = 6.0
			hd.knockback_force = 9.0
			hd.stagger_duration = 1.2
		hb.take_hit(hd, player)


func exit() -> void:
	player.hurtbox.set_deferred("monitorable", true)
	# Thousand Petals ends sheathed
	if id == "petal_storm" and not player.body_model.weapon_in_hand:
		player.body_model.play("draw", 0.3)
	if GUARD_POSE.has(id):
		# Iai Counter sheathed the blade to wait: nobody came, so draw it again
		if id == "iai_counter" and _pc.buff("riposte"):
			player.body_model.play("draw", 0.3)
		_pc.buffs["riposte"] = 0.0
