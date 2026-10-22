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
##   corsair  parley (guard), grapeshot, crossfire, broadside (ult): sword and pistol;
##            their shots are free (CorsairGun with ball false)
##   pistol   deadeye, smoke_bomb, point_blank, deaths_waltz (ult)
##   dagger   slip (guard); cutthroat, knife_fan, red_eclipse (ult) in DaggerArts
##   dual_dagger  viper_flurry, scissor_leap, bleeding_edge, hundred_fangs (ult) in DaggerArts
##   polearm  hundred_thrusts, dragon_sweep, vault_strike, raijin_wheel (ult) in PoleArts
##   hammer   skullcracker, rolling_quake, cyclone_crusher, titans_fall (ult) in HammerArts
##   dual_axe gallows_hook, hewing_frenzy, axestorm, fimbulwinter (ult) in DualAxeArts
##   greatsword guardbreaker, crescent_gale, tempest_turns, skysplitter (ult) in GreatswordArts
##   black_leg mule_kick, hailstorm_heels, cartwheel_crescent, last_course (ult) in BlackLegArts
##   unarmed  hip_toss (guard -> shoulder_throw), cannonball_fist, meteor_fist in FistArts; hundred_fists,
##            rising_dragon, palm_strike, sea_king_fist (ult)
##   haki     conquerors_haki (ult)
## Shoulder Throw carries a light enemy (not bosses or big bugs) with the body; in co-op only the host moves
## it (a guest's throw throws it from where it stands).

## The guard skills (Riposte, Iai Counter, Crossed Counter): the waiting pose, and
## per fighting style the answer [pose, length, damage].
const GUARD_POSE := {"riposte": "riposte_guard", "iai_counter": "iai_ready", "cross_counter": "cross_guard", "parley": "riposte_guard",
	"slip": "dg_slip_guard", "hip_toss": "fs_catch"}
## (Parley's answer is a turning cut and then a shot: PARLEY_SHOT more at 0.3 s; Slip's
## is out from behind them, a sure crit that bleeds)
const COUNTER_POSE := {"sword": ["riposte_cut", 0.5, 35.0], "katana": ["iai_slash", 0.6, 45.0], "dual_sword": ["dual_cross", 0.5, 40.0],
	"sword_pistol": ["parley_shot", 0.6, 16.0], "dagger": ["dg_slip", 0.55, 28.0]}
## Techniques that live in their own files (enter/update return false for ids not theirs).
var _arts: Array = [DaggerArts, PoleArts, HammerArts, DualAxeArts, GreatswordArts, BlackLegArts, FistArts]
const PARLEY_SHOT := 28.0

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
	# (bare fists answer a caught blow with Shoulder Throw)
	if id == "riposte_counter" and player.style() == "fist":
		id = "shoulder_throw"
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
	for a in _arts:
		if a.enter(self, id):
			return
	match id:
		"riposte", "iai_counter", "cross_counter", "parley", "slip", "hip_toss":
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
				if player.style() == "dagger":
					_blink_behind(_target)
			player.body_model.play(str(cp[0]), dur)
			if player.style() == "katana":
				# (the drawing cut's whole path, from the scabbard on)
				KatanaFx.slash(player, 0.17, false, 1.2)
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
				# the sea coils up round you: two rings of water winding opposite ways
				var right := _dir.cross(Vector3.UP)
				var feet := player.global_position
				Net.fx("water_arc", [feet + Vector3(0, 0.35, 0), -_dir, right, 1.5, TAU * 0.85, 0.42, 0.32, KRAKEN_GATHER + 0.1, _col(), 1])
				Net.fx("water_arc", [feet + Vector3(0, 1.05, 0), _dir, right, 1.05, -TAU * 0.75, 0.32, 0.36, KRAKEN_GATHER + 0.05, _col(), 2])
				Net.fx("water_burst", [feet + Vector3(0, 0.9, 0), "water_swirl", 3.0, KRAKEN_GATHER + 0.1, 20.0])
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
			var was := _chest()
			_blink_behind(_target)
			if _elem():
				# the step itself left as a run of cloud and petals in the air you crossed
				Net.fx("katana_line", [was, _chest(), 0.55, true, 0.06, randi() % 1000])
		"petal_storm":
			dur = 2.0
			_victims = _closest(9.0, 99)
			player.hurtbox.set_deferred("monitorable", false)
			player.body_model.play("petal_storm", dur)
			Net.fx("sfx", ["whoosh", player.global_position, -6.0, 0.05, 0.6])
			if _elem():
				Net.fx("gather", [player.global_position + Vector3(0, 0.9, 0), 2.8, _col(FX.ACCENT), 0.38, 26])
				# the cloud drawn in round your feet as you crouch to the hilt
				Net.fx("katana_arc", [player.global_position + Vector3(0, 0.35, 0), -_dir, -_dir.cross(Vector3.UP), 1.7, TAU, 0.55, true, 0.38, 40])
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
			player.hurtbox.set_deferred("monitorable", false)
			player.body_model.play("maelstrom", dur)
			Net.fx("sfx", ["whoosh_big", player.global_position, 0.0, 0.05, 0.7])
			Net.fx("gather", [player.global_position + Vector3(0, 0.9, 0), 2.8, _col(FX.ACCENT) if _elem() else _col(), 0.34, 22])
			Net.fx("dust_ring", [player.global_position, 12, 0.9])
			Net.fx("ring", [player.global_position, Vector3.UP, 3.5, _col(), 0.4, 0.08])
			_moment(0.4, 0.25, 0.45, 0.2)
		"blade_dance":
			dur = 1.0
			player.body_model.play("blade_dance", dur)
			Net.fx("sfx", ["whoosh", player.global_position, -8.0, 0.05, 1.1])
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
			dur = 2.4
			_victims = _closest(4.0, 99)
			player.hurtbox.set_deferred("monitorable", false)
			player.body_model.play("steel_tempest", dur)
			Net.fx("sfx", ["parry", player.global_position, -6.0, 0.0, 1.6])
			Net.fx("gather", [player.global_position + Vector3(0, 1.8, 0), 2.4, _col(), 0.36, 14])
			Net.fx("gather", [player.global_position + Vector3(0, 1.8, 0), 2.4, _col(FX.ACCENT) if _elem() else _col(FX.CORE), 0.36, 14])
			Net.fx("ring", [player.global_position, Vector3.UP, 3.5, _col(), 0.4, 0.08])
			_moment(0.4, 0.25, 0.45, 0.2)
		"grapeshot":
			dur = 0.7
			player.body_model.play("grapeshot", dur)
			Net.fx("sfx", ["blip_low", player.global_position, -10.0, 0.0, 0.9])
		"crossfire":
			dur = 0.95
			_target = _aimed(9.0)
			if _target == null:
				_refund("Nobody close enough")
				return
			_dir = _flat_to(_target)
			face_direction(_dir, 1.0)
			player.body_model.play("crossfire", dur)
			Net.fx("sfx", ["whoosh", player.global_position, -8.0, 0.05, 1.2])
		"broadside":
			dur = 2.4
			_victims = _closest(14.0, 6)
			# (shot left to right as the pistol fans across)
			var right := _dir.cross(Vector3.UP)
			_victims.sort_custom(func(a, b): return _flat_to(a).dot(right) < _flat_to(b).dot(right))
			player.hurtbox.set_deferred("monitorable", false)
			player.body_model.play("broadside", dur)
			Net.fx("sfx", ["whoosh_big", player.global_position, -3.0, 0.05, 0.55])
			Net.fx("gather", [player.global_position + Vector3(0, 2.2, 0), 2.6, _col(FX.ACCENT) if _elem() else _col(), 0.45, 22])
			Net.fx("ring", [player.global_position, Vector3.UP, 3.5, _col(), 0.45, 0.08])
			Net.fx("dust_ring", [player.global_position, 12, 0.9])
			_moment(0.4, 0.25, 0.45, 0.2)
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
		"conquerors_haki":
			dur = 1.2
			player.body_model.play("conqueror", dur)
		_:
			dur = 0.1


func physics_update(delta: float) -> void:
	t += delta
	var art := false
	for a in _arts:
		if a.update(self, delta):
			art = true
			break
	if art:
		if t >= dur:
			_finish()
		return
	match id:
		"riposte", "iai_counter", "cross_counter", "parley", "slip", "hip_toss":
			_rooted(delta, 0.15)
			# the waiting blade catches the light (the katana's waits in its scabbard: the hilt)
			if _once("glint", 0.12) or _once("glint2", 0.55):
				Net.fx("glint", [_hilt() if id == "iai_counter" else _blade_tip(), _col(FX.CORE), 0.7])
				# (the katana's waits in stillness, a petal or two adrift round the hilt)
				if id == "iai_counter" and _elem():
					Net.fx("sakura", [_hilt(), Vector3.UP, 2, 0.8])
		"riposte_counter":
			_rooted(delta, 0.0)
			if _once("cut", 0.11):
				_riposte_cut()
			# Parley: the pistol put to their chest while the blade still holds them off
			if player.style() == "sword_pistol" and _once("glint", 0.24):
				Net.fx("glint", [CorsairGun.muzzle(player), _col(FX.CORE), 0.6])
			if player.style() == "sword_pistol" and _once("shot", 0.3):
				_corsair_shot(PARLEY_SHOT, _target, {"knock": 10.0, "down": true, "stagger": 0.6, "unblock": true, "stop": 0.1, "shake": 0.2}, 1.4)
			# the katana's answer: a beat later the blade is flicked clean
			if player.style() == "katana" and _once("flick", 0.4):
				Net.fx("glint", [_blade_tip(), _col(FX.CORE), 1.0])
				Net.fx("sfx", ["parry", player.global_position, -10.0, 0.0, 2.0])
				if _target and is_instance_valid(_target):
					_spray(_target.global_position + Vector3(0, 1.3, 0), Vector3.UP, 10, 2.0)
					if _elem():
						Net.fx("katana_burst", [_target.global_position + Vector3(0, 1.0, 0), "katana_cloud", 2.0, 0.5, 40.0])
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
			if _once("swoosh", 0.3):
				KatanaFx.slash(player, 0.12, false, 1.3)
			if _once("fire", 0.34):
				var from := player.global_position + Vector3(0, 0.2, 0) + _dir * 0.8
				Projectile.launch(player.get_tree(), "wave", from, _dir, player, 34.0, "elem" if _elem() else "")
				Net.fx("sfx", ["whoosh_big", from, 0.0, 0.05, 0.8])
				Net.fx("puff_ring", [from, "dust_low", 6, 0.3, 1.0, 0.8, Color.WHITE, 5.0])
				if _elem():
					Net.fx("katana_burst", [from + Vector3(0, 0.6, 0), "katana_cloud", 1.8, 0.45, 30.0])
				Net.fx("ring", [from + Vector3(0, 0.9, 0) + _dir * 1.2, _dir, 1.2, _col(), 0.24, 0.14])
				_spray(from + Vector3(0, 0.6, 0), _dir + Vector3.UP * 0.8, 9, 4.0)
				CombatManager.apply_camera_shake(0.15)
				CombatManager.apply_camera_kick(0.15, 0.3)
				player.squash(-2.0)
		"phantom_step":
			_rooted(delta, 0.0)
			# arrived crouched behind them: the edge catches the light, then the cut (pose key 0.16 s)
			if _once("glint", 0.07):
				Net.fx("glint", [_blade_tip(), _col(FX.CORE), 0.8])
			if _once("swoosh", 0.12):
				KatanaFx.slash(player, 0.13, false, 1.15)
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
				Net.fx("katana_burst", [at, "katana_slash" if _elem() else "steel_slash", 2.0 if _elem() else 1.5, 0.35, 180.0])
				_spray(at, _dir + Vector3.UP * 0.3, 8, 4.0)
				Net.fx("sfx", ["parry", player.global_position, -8.0, 0.05, 1.7])
				CombatManager.apply_camera_kick(0.15, 0.3)
		"petal_storm":
			_petals(delta)
		"axe_throw":
			_rooted(delta, 0.0)
			if _once("glint", 0.16):
				Net.fx("glint", [_blade_tip(), _col(FX.CORE), 0.8])
			if _once("throw", 0.24):
				_throw_axe()
		"earthsplitter":
			apply_gravity(delta)
			player.velocity.x = move_toward(player.velocity.x, 0.0, 6.0 * delta)
			player.velocity.z = move_toward(player.velocity.z, 0.0, 6.0 * delta)
			player.move_and_slide()
			# the axe raised at the top of the leap catches the light
			if _once("glint", 0.28):
				Net.fx("glint", [_blade_tip(), _col(FX.CORE), 0.9])
			if not _done.has("slam") and t > 0.3 and (player.is_on_floor() or t > 0.7):
				_done["slam"] = true
				player.velocity = Vector3.ZERO
				_split(9.0, 1.9, 32.0)
		"berserk":
			_rooted(delta, 0.0)
			if _once("gather", 0.02):
				Net.fx("gather", [_chest(), 1.6, _col(FX.ACCENT) if _elem() else Color(1.0, 0.3, 0.22), 0.22, 16])
			if _once("roar", 0.25):
				_pc.add_buff("berserk", 8.0)
				var c := player.global_position
				Net.fx("sparkle", [c + Vector3(0, 1.3, 0), 20, Color(1.0, 0.25, 0.2)])
				Net.fx("dust_ring", [c, 16, 1.1])
				Net.fx("ring", [c, Vector3.UP, 4.5, Color(1.0, 0.3, 0.2), 0.4, 0.1])
				Net.fx("punch_wind", [c + Vector3.UP * 1.3, Vector3.UP, 1.2, Color(1.0, 0.6, 0.5), true])
				for k in range(4):
					var a := TAU * k / 4.0 + randf() * 0.6
					Net.fx("debris", [c + Vector3(cos(a), 0.1, sin(a)) * 1.2, Vector3(cos(a), 1.6, sin(a)), 4, Color(0.35, 0.3, 0.25), 4.5])
				_spray(c + Vector3(0, 1.0, 0), Vector3.UP, 16, 4.0)
				if _elem():
					Net.fx("power_aura", [player.body_model, "ember", 8.0])
				Net.fx("sfx", ["thud", c, 2.0, 0.05, 0.6])
				CombatManager.apply_camera_shake(0.25)
				CombatManager.apply_camera_kick(0.2, 0.4)
		"maelstrom":
			_maelstrom(delta)
		"blade_dance":
			_dance(delta)
		"cross_fang":
			apply_gravity(delta)
			player.move_and_slide()
			# both blades high at the top of the leap catch the light
			if _once("glint", 0.3):
				Net.fx("glint", [_blade_tip(), _col(FX.CORE), 0.9])
				Net.fx("glint", [_blade_tip(true), _col(FX.CORE), 0.9])
			if _once("swoosh", 0.34):
				Net.fx("blade_swoosh", [player.body_model, 0.16, _col(), _col(FX.ACCENT)])
			if not _done.has("land") and t > 0.25 and (player.is_on_floor() or t > 0.7):
				_done["land"] = true
				player.velocity = Vector3.ZERO
				_fang_land()
		"steel_tempest":
			_tempest(delta)
		"grapeshot":
			_rooted(delta, 0.0)
			if _once("glint", 0.18):
				Net.fx("glint", [CorsairGun.muzzle(player), _col(FX.CORE), 0.7])
			if _once("fire", 0.26):
				_grapeshot()
		"crossfire":
			_crossfire(delta)
		"broadside":
			_broadside(delta)
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
	if id in ["shoulder_throw", "sea_king_unleash"]:
		return "unarmed"
	if id == "riposte_counter":
		return {"katana": "katana", "dual_sword": "dual", "sword_pistol": "corsair", "dagger": "dagger"}.get(player.style(), "sword")
	var tr := str(Skills.get_skill(id).get("tree", "base"))
	return tr if FX.TREE_FX.has(tr) else "haki"


## The tree's element awakened (its first mastery passive): until then the
## technique shows plain steel, no element.
func _elem() -> bool:
	return player.progression.elemental(_tree())


func _col(which: int = 1) -> Color:
	return FX.tree_col(_tree() if _elem() else "plain", which)


## The element thrown along `dir` (sea spray for the cutlass, petals for the
## katana, embers for the axe), if it's awakened.
func _spray(at: Vector3, dir: Vector3, amount: int, speed: float) -> void:
	if _elem():
		Net.fx("element", [_tree(), at, dir, amount, speed])


## Where the held blade's point is (FX at the tip; `left`: the off hand's).
func _blade_tip(left: bool = false) -> Vector3:
	var w: MeshInstance3D = player.body_model.offhand if left else player.body_model.weapon
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


## Spinning ultimates: a hit all round every `every` s from `start` (dragging them
## in), then a last burst at `end_t` that throws them out.
func _spin_hits(reach: float, every: float, base: float, end_t: float, final: float, start: float = 0.15) -> void:
	if t < end_t and t >= start + _hits * every:
		_hits += 1
		_ring(reach, base, 2.5, false, true)
		Net.fx("slash", [player.player_model, "spin", 0.18, _col()])
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
	if st == "dagger":
		# Slip: out from behind them, the blade in their back - a sure crit, and it bleeds
		if not hd.has_meta("crit"):
			hd.damage *= 1.5
			hd.set_meta("crit", true)
		hd.set_meta("bleed", 4.0)
		hd.knockback_force = 3.0
	if _target and is_instance_valid(_target) and _target.get("hurtbox") is Hurtbox:
		_strike(_target, hd)
		var at := _target.global_position + Vector3(0, 1.0, 0)
		Net.fx("impact", [at, _col(FX.ACCENT)])
		Net.fx("ring", [at, _dir, 1.2, _col(), 0.22, 0.2])
	else:
		_cone(2.4, 0.5, base, 9.0, false, true)
	match st:
		"katana":
			# out of the scabbard in one cut through them (its drawn slash began with the answer)
			Net.fx("afterimage", [player.body_model, _col(), 0.25])
			if _target and is_instance_valid(_target):
				Net.fx("katana_burst", [_target.global_position + Vector3(0, 1.1, 0), "katana_slash" if _elem() else "steel_slash", 1.9, 0.35, 180.0])
		"dual_sword":
			# the scissoring answer: both blades' trails, an X through them
			Net.fx("blade_swoosh", [player.body_model, 0.14, _col(), _col(FX.ACCENT)])
			if _target and is_instance_valid(_target):
				Net.fx("twin_cross", [_target.global_position + Vector3(0, 1.1, 0), _dir, 0.7, _col(), _col(FX.ACCENT), 0.28])
			_spray(_chest() + _dir * 0.8, _dir + Vector3.UP * 0.2, 10, 4.5)
		"sword_pistol":
			# the blow turned aside on the blade (the shot follows)
			Net.fx("blade_swoosh", [player.body_model, 0.1, _col()])
		"dagger":
			Net.fx("blade_swoosh", [player.body_model, 0.12, _col()])
			Net.fx("streak", [_from + Vector3(0, 1.0, 0), _chest(), _col(), 0.08, 0.25])
			_spray(_chest() + _dir * 0.8, _dir + Vector3.UP * 0.3, 10, 3.0)
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
			var feet := player.global_position
			var through := _flat_to(e)
			_place(e.global_position + through * 1.4)
			_dir = through
			face_direction(_dir, 1.0)
			_strike(e, _hd(10.0, 0.0, false))
			var at := e.global_position + Vector3(0, 1.0, 0)
			Net.fx("streak", [from, _chest(), _col(), 0.16, 0.35])
			Net.fx("blade_swoosh", [player.body_model, 0.1, _col()])
			if _elem():
				# a crescent of water through them, its slant swapping cut to cut, and the
				# run of water you leave along the ground between them
				var right := through.cross(Vector3.UP)
				var tilt := (0.6 if i % 2 == 0 else -0.6)
				var up := Vector3.UP.rotated(through, tilt)
				Net.fx("water_arc", [at, up.rotated(through, 0.5), right.rotated(through, tilt), 1.5, PI * 1.15, 0.7, 0.09, 0.75, _col(), i + 3])
				Net.fx("water_wake", [feet, player.global_position, 0.7, 0.75, _col(), i + 11])
				Net.fx("water_burst", [at, "water_swirl", 1.9, 0.5, 180.0])
				Net.fx("splash", [e.global_position, 4, 0.45])
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
		if _elem():
			# the flick of the blade: water flung up off it in one rising arc
			Net.fx("water_arc", [_chest(), -Vector3.UP, _dir, 1.25, PI * 0.95, 0.5, 0.12, 0.5, _col(), 21])
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
					# the sea heaves up under them in claws of drawn water
					var side := _dir.cross(Vector3.UP)
					for c in 3:
						var off := side * (c - 1) * 0.7 + Vector3(0, 1.6 + 0.3 * (c % 2), 0)
						Net.fx("water_burst", [at + off, "water_curl", 3.4 - 0.4 * (c % 2), 0.75, 35.0])
					Net.fx("water_burst", [at + Vector3(0, 0.5, 0), "water_swirl", 2.6, 0.6, 180.0])
					Net.fx("spray", [at + Vector3.UP * 0.2, Vector3.UP, 14, _col(FX.ACCENT), 7.0])
					Net.fx("ring", [at, Vector3.UP, 2.4, _col(), 0.4, 0.12])
				else:
					Net.fx("ring", [at, Vector3.UP, 2.2, _col(), 0.35, 0.12])
					Net.fx("dust_ring", [at, 12, 1.0])
				Net.fx("impact", [at + Vector3(0, 1.0, 0), _col(FX.ACCENT)])
				k += 1
		Net.fx("ring", [player.global_position, Vector3.UP, 9.0, _col(), 0.6, 0.06])
		if _elem():
			# the signature: a whirlpool of water whipping once round you as they tear
			var back := -_dir
			Net.fx("water_arc", [player.global_position + Vector3(0, 0.75, 0), back, back.cross(Vector3.UP), 2.6, TAU * 1.05, 0.95, 0.16, 0.8, _col(), 22])
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
	var feet := player.global_position
	if _once("glint", PETAL_DRAW - 0.1):
		Net.fx("glint", [_hilt(), _col(FX.CORE), 1.0])
	if _once("slash", PETAL_DRAW - 0.05):
		# (the drawing cut's whole path, out of the scabbard on: KatanaMoves.PETAL_SWING)
		KatanaFx.slash(player, 0.14, false, 1.6)
	if _once("draw", PETAL_DRAW):
		Net.fx("afterimage", [player.body_model, _col(), 0.3])
		if _elem():
			# the signature: a crescent of cloud racing once round you at chest height as the blade leaves
			var back := -_dir
			Net.fx("katana_arc", [feet + Vector3(0, 1.0, 0), back, back.cross(Vector3.UP), 3.6, -TAU * 0.97, 0.95, true, 0.14, 41])
		Net.fx("ring", [feet + Vector3(0, 1.0, 0), Vector3.UP, 9.0, _col(), 0.3, 0.05])
		Net.fx("sfx", ["whoosh_big", feet, -1.0, 0.05, 1.4])
		CombatManager.apply_camera_kick(0.25, 0.4)
		var k := 0
		for e in _victims:
			if is_instance_valid(e):
				Net.fx("cut_lines", [(e as Node3D).global_position, 12, _col(FX.CORE), PETAL_CLICK - PETAL_DRAW - 0.15, k * 31 + 7])
				k += 1
	# the cuts landing on them: drawn crescents crossing them (cloud and petals once awakened)
	if t > PETAL_DRAW + 0.08 and t < PETAL_CLICK - 0.1 and int(t / 0.16) != int((t - delta) / 0.16):
		for e in _victims:
			if is_instance_valid(e):
				var at := (e as Node3D).global_position + Vector3(randf_range(-0.2, 0.2), randf_range(0.7, 1.5), randf_range(-0.2, 0.2))
				Net.fx("katana_burst", [at, "katana_slash" if _elem() else "steel_slash", randf_range(1.3, 1.9), 0.3, 180.0])
				_spray(at, Vector3.UP, 3, 1.5)
	if _once("click", PETAL_CLICK):
		player.hurtbox.set_deferred("monitorable", true)
		Net.fx("sfx", ["parry", feet, 0.0, 0.0, 1.8])
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
				if _elem():
					Net.fx("katana_burst", [at + Vector3(0, 1.1, 0), "katana_slash", 3.0, 0.45, 180.0])
					Net.fx("katana_burst", [at + Vector3(0, 0.7, 0), "katana_cloud", 2.8, 0.6, 40.0])
					Net.fx("sakura", [at + Vector3(0, 1.0, 0), Vector3.UP, 12, 4.5])
				else:
					Net.fx("katana_burst", [at + Vector3(0, 1.1, 0), "steel_slash", 2.4, 0.35, 180.0])
					Net.fx("ring", [at, Vector3.UP, 2.0, _col(), 0.35, 0.1])
					Net.fx("dust_ring", [at, 10, 0.9])
		if _elem():
			# a thousand petals let go over everyone in reach, falling through the still air
			Net.fx("sakura", [feet + Vector3(0, 3.5, 0), Vector3.DOWN, 30, 0.8, 0.32, 6.0])
		Net.fx("ring", [feet, Vector3.UP, 9.0, _col(), 0.6, 0.06])
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
	_axe = Projectile.launch(player.get_tree(), "axe", from, d.normalized(), player, 24.0, ("elem|" if _elem() else "") + player.equipped_weapon.model())
	Net.fx("ring", [from + d.normalized() * 0.4, d.normalized(), 1.1, _col(), 0.2, 0.14])
	CombatManager.apply_camera_kick(0.1, 0.25)
	player.squash(-2.0)
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
	# the crack tears out ahead (molten once the element's awake), rock thrown up along it
	Net.fx("ground_crack", [start, _dir, length, _col(FX.ACCENT) if _elem() else Color(0, 0, 0, 0), randi() % 10000, 0.2])
	for i in range(6):
		var p := start + _dir * (i * length / 5.0)
		Net.fx("dust", [p + Vector3(0, 0.05, 0), 6, 0.6 + i * 0.06])
		Net.fx("debris", [p + Vector3(0, 0.1, 0), Vector3.UP + _dir * 0.3, 5, FX.tree_col("plain", FX.ACCENT).darkened(0.45), 5.5])
		_spray(p + Vector3(0, 0.2, 0), Vector3.UP, 5, 3.0)
	Net.fx("dust_ring", [start, 14, 1.0])
	Net.fx("ring", [start, Vector3.UP, 2.4, _col(), 0.3, 0.12])
	Net.fx("impact", [start + Vector3(0, 0.2, 0), _col(FX.ACCENT) if _elem() else Color(1.0, 0.85, 0.55)])
	Net.fx("sfx", ["thud", start, 3.0, 0.05, 0.65])
	Net.fx("sfx", ["crunch", start + _dir * 3.0, -1.0, 0.05, 0.55])
	CombatManager.apply_camera_shake(0.35)
	CombatManager.apply_camera_kick(0.22, 0.35)
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


## Maelstrom: the axe drawn back while the power gathers, then seven turns inside
## a whirlwind (it moves with you), dust and rock (fire once awakened) thrown off
## it, and a last turn that throws everyone down.
const MAEL_GATHER := 0.38
const MAEL_BURST := 2.8

func _maelstrom(delta: float) -> void:
	_rooted(delta, 0.6 if t >= MAEL_GATHER else 0.0)
	if _once("go", MAEL_GATHER):
		Net.fx("vortex", [player.player_model, MAEL_BURST - MAEL_GATHER, 2.8, 2.6, _col(), randi() % 10000])
		Net.fx("sfx", ["whoosh_big", player.global_position, -2.0, 0.05, 0.9])
		CombatManager.apply_camera_kick(0.2, 0.4)
	if t < MAEL_GATHER:
		return
	var before := _hits
	_spin_hits(3.2, 0.25, 9.0, MAEL_BURST, 30.0, MAEL_GATHER)
	if _hits != before and _hits % 2 == 0:
		var a := randf() * TAU
		var out := Vector3(cos(a), 0.0, sin(a))
		var at := player.global_position + out * 2.6 + Vector3(0, 0.3, 0)
		Net.fx("dust", [at, 4, 0.7])
		Net.fx("debris", [at, out + Vector3.UP * 1.2, 4, Color(0.35, 0.3, 0.25), 4.0])
		if _elem():
			Net.fx("flame", [at + Vector3.UP * 0.5, 6, 0.7, 0.5, 0.3])
	if _once("burst_fx", MAEL_BURST):
		player.hurtbox.set_deferred("monitorable", true)
		var c := player.global_position
		Net.fx("ring", [c, Vector3.UP, 7.0, _col(), 0.5, 0.08])
		for k in range(6):
			var b := TAU * k / 6.0
			Net.fx("debris", [c + Vector3(cos(b), 0.2, sin(b)) * 1.5, Vector3(cos(b), 1.0, sin(b)), 6, Color(0.35, 0.3, 0.25), 7.0])
		if _elem():
			Net.fx("fire_ring", [c, 6.0, 50])
		CombatManager.apply_hitstop(0.1, [player])
		_moment(0.3, 0.35, 0.7, 0.45)


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
# Dual wield
# --------------------------------------------------------------------------
## Blade Dance: six spinning cuts dancing forward, both blades' trails crossing; a
## ring each turn (the two colours turn about), an X through them on the last.
func _dance(delta: float) -> void:
	_drift(delta, 7.0)
	if _once("glint", 0.04):
		Net.fx("glint", [_blade_tip(), _col(FX.CORE), 0.7])
	if _once("swoosh", 0.08):
		Net.fx("blade_swoosh", [player.body_model, 0.82, _col(), _col(FX.ACCENT)])
	if _hits < 6 and t >= 0.1 + _hits * 0.13:
		_hits += 1
		var last := _hits == 6
		_ring(2.2, 14.0 if last else 9.0, 4.0, last, false)
		Net.fx("ring", [_chest(), Vector3.UP, 2.0 if last else 1.5, _col(FX.EDGE if _hits % 2 == 0 else FX.ACCENT), 0.18, 0.1])
		Net.fx("sfx", ["whoosh", player.global_position, -7.0, 0.1, 1.2 + _hits * 0.05])
		if _hits % 2 == 0:
			_spray(_chest(), _dir + Vector3.UP * 0.3, 6, 3.5)
		if last:
			Net.fx("twin_cross", [_chest() + _dir * 1.4, _dir, 0.9, _col(), _col(FX.ACCENT), 0.3])
			CombatManager.apply_camera_kick(0.15, 0.3)
			player.squash(-2.0)


## Cross Fang's landing: both blades crash down crossed, an X torn in the ground
## ahead and through everyone caught; they're knocked flat.
func _fang_land() -> void:
	var hits := _cone(3.2, 0.75, 30.0, 9.0, true, true)
	var at := player.global_position + _dir * 1.2
	Net.fx("twin_cross", [at + Vector3(0, 0.12, 0), _dir, 1.5, _col(), _col(FX.ACCENT), 0.4, true])
	Net.fx("ring", [at, Vector3.UP, 2.6, _col(), 0.3, 0.12])
	for e in hits:
		var c := (e as Node3D).global_position + Vector3(0, 1.1, 0)
		Net.fx("twin_cross", [c, _dir, 0.6, _col(), _col(FX.ACCENT), 0.25])
		Net.fx("impact", [c, _col(FX.ACCENT)])
	_spray(at + Vector3(0, 0.3, 0), Vector3.UP + _dir * 0.3, 12, 4.0)
	Net.fx("dust_ring", [player.global_position, 14, 1.0])
	Net.fx("sfx", ["thud", player.global_position, 0.0, 0.05, 1.0])
	Net.fx("sfx", ["parry", player.global_position, -8.0, 0.05, 1.4])
	CombatManager.apply_camera_shake(0.2)
	CombatManager.apply_camera_kick(0.18, 0.3)
	player.squash(-4.0)


## Tempest of Steel: both blades crossed overhead while it gathers (untouchable
## until the burst), then a storm of turns inside two whirlwinds, one in each of
## the twin colours, dragging them in; then a great X torn across the ground and
## through everyone, and they're thrown away.
const TEMPEST_GATHER := 0.4
const TEMPEST_BURST := 2.0

func _tempest(delta: float) -> void:
	_rooted(delta, 0.0)
	if _once("glint", TEMPEST_GATHER - 0.1):
		Net.fx("glint", [_blade_tip(), _col(FX.CORE), 1.1])
		Net.fx("glint", [_blade_tip(true), _col(FX.CORE), 1.1])
	if _once("go", TEMPEST_GATHER):
		var secs := TEMPEST_BURST - TEMPEST_GATHER
		Net.fx("vortex", [player.player_model, secs, 2.6, 2.4, _col(), randi() % 10000])
		Net.fx("vortex", [player.player_model, secs, 3.1, 2.0, _col(FX.ACCENT) if _elem() else _col(FX.CORE), randi() % 10000])
		Net.fx("blade_swoosh", [player.body_model, secs, _col(), _col(FX.ACCENT)])
		Net.fx("sfx", ["whoosh_big", player.global_position, -2.0, 0.05, 1.1])
		CombatManager.apply_camera_kick(0.2, 0.4)
	if t < TEMPEST_GATHER:
		return
	var before := _hits
	_spin_hits(3.5, 0.18, 8.0, TEMPEST_BURST, 40.0, TEMPEST_GATHER)
	if _hits != before and _hits % 2 == 0:
		var a := randf() * TAU
		_spray(_chest() + Vector3(cos(a), 0.0, sin(a)) * 1.6, Vector3(cos(a), 0.3, sin(a)), 6, 4.0)
	if _once("burst_fx", TEMPEST_BURST):
		player.hurtbox.set_deferred("monitorable", true)
		Net.fx("twin_cross", [player.global_position + Vector3(0, 0.12, 0), _dir, 3.6, _col(), _col(FX.ACCENT), 0.5, true])
		for e in _pc.enemies_in(_chest(), 4.5):
			Net.fx("twin_cross", [(e as Node3D).global_position + Vector3(0, 1.1, 0), _flat_to(e), 0.8, _col(), _col(FX.ACCENT), 0.35])
		Net.fx("ring", [player.global_position, Vector3.UP, 7.0, _col(), 0.5, 0.08])
		Net.fx("ring", [player.global_position + Vector3(0, 1.0, 0), Vector3.UP, 5.0, _col(FX.ACCENT) if _elem() else _col(FX.CORE), 0.4, 0.06])
		_spray(_chest(), Vector3.UP, 20, 5.0)
		Net.fx("sfx", ["parry", player.global_position, 0.0, 0.0, 1.3])
		CombatManager.apply_hitstop(0.1, [player])
		_moment(0.3, 0.35, 0.7, 0.45)


# --------------------------------------------------------------------------
# Sword and pistol (Corsair)
# --------------------------------------------------------------------------
## A free shot from the off-hand pistol (techniques don't use its load) at `target`
## or whoever's in front: the element's colours and a powder burst once awakened.
func _corsair_shot(base: float, target: Node3D, opts: Dictionary, size: float) -> Node3D:
	var o := opts.merged({"elem": _elem(), "burst": _elem(), "ball": false, "size": size}, true)
	var hit := CorsairGun.fire(player, _dir, base, "skill", o, target)
	CombatManager.apply_camera_kick(0.18, 0.3)
	player.squash(-1.5)
	return hit


## Grapeshot: one blast across a wide cone; everyone in it is hit (less further
## out) and thrown back reeling, and the recoil rocks you back.
const GRAPE_REACH := 7.0
const GRAPE_COS := 0.45

func _grapeshot() -> void:
	var from := CorsairGun.muzzle(player)
	for e in _pc.enemies_in(player.global_position + Vector3(0, 0.9, 0) + _dir * GRAPE_REACH * 0.5, GRAPE_REACH):
		var d := (e as Node3D).global_position - player.global_position
		d.y = 0.0
		if d.length() > GRAPE_REACH or (d.length() > 0.6 and d.normalized().dot(_dir) < GRAPE_COS):
			continue
		var c := CorsairGun.body_center(e)
		var hd := _hd(22.0 * lerpf(1.0, 0.6, clampf((d.length() - 3.0) / 4.0, 0.0, 1.0)), 10.0, false)
		hd.ranged = true
		hd.impact = "shot"
		hd.stagger_duration = 0.8
		_strike_toward(e, hd, _flat_to(e))
		Net.fx("tracer", [from, c, _col(FX.CORE)])
		Net.fx("impact", [c, _col(FX.ACCENT)])
		if _elem():
			Net.fx("powder_burst", [c, _flat_to(e), 0.5, _col()])
	# the shot spreading across the cone
	for i in range(7):
		var a := lerpf(-0.95, 0.95, float(i) / 6.0) + randf_range(-0.08, 0.08)
		var end := from + _dir.rotated(Vector3.UP, a) * randf_range(5.0, 7.5) + Vector3(0, randf_range(-0.7, 0.1), 0)
		Net.fx("tracer", [from, end, _col(FX.CORE)])
	Net.fx("muzzle_sparks", [from, _dir, 26, _col(FX.ACCENT) if _elem() else Color(1.0, 0.75, 0.35)])
	Net.fx("ring", [from + _dir * 0.4, _dir, 1.8, _col(), 0.25, 0.16])
	if _elem():
		Net.fx("powder_burst", [from + _dir * 0.5, _dir, 1.6, _col()])
	else:
		Net.fx("smoke", [from + _dir * 0.5, 10, 1.0, 1.8])
	Net.fx("dust", [player.global_position + _dir * 2.0, 10, 0.8])
	Net.fx("sfx", ["gunshot", from, 3.0, 0.05, 0.6])
	Net.fx("sfx", ["whoosh_big", from, -4.0, 0.05, 0.8])
	CombatManager.apply_camera_shake(0.25)
	CombatManager.apply_camera_kick(0.22, 0.3)
	player.velocity = -_dir * 4.0
	player.squash(-2.5)


## Crossfire: a dash through them with a guard-breaking cut, a turn round behind
## them, and a shot into their back that can't be blocked and knocks them flat.
func _crossfire(delta: float) -> void:
	_rooted(delta, 0.0)
	if _target == null or not is_instance_valid(_target):
		return
	if _once("dash", 0.12):
		var d := _flat_to(_target)
		var from := _chest()
		Net.fx("afterimage", [player.body_model, _col(), 0.3])
		Net.fx("dust", [player.global_position + Vector3(0, 0.05, 0), 6, 0.5])
		_place(_target.global_position + d * 1.8)
		_dir = d
		face_direction(_dir, 1.0)
		Net.fx("streak", [from, _chest(), _col(), 0.12, 0.28])
		Net.fx("blade_swoosh", [player.body_model, 0.16, _col()])
		Net.fx("sfx", ["whoosh_big", player.global_position, -3.0, 0.05, 1.4])
	if _once("cut", 0.16):
		var hd := player.melee_hit(24.0, "skill")
		hd.stagger_duration = 1.0
		hd.knockback_force = 2.0
		hd.breaker = true
		hd.sever = true
		hd.hitstop_duration = 0.07
		hd.camera_shake_intensity = 0.12
		_strike(_target, hd)
		var at := _target.global_position + Vector3(0, 1.1, 0)
		Net.fx("impact", [at, _col(FX.ACCENT)])
		Net.fx("ring", [at, _dir, 1.1, _col(), 0.2, 0.14])
		_spray(at, _dir + Vector3.UP * 0.3, 8, 4.0)
		CombatManager.apply_camera_kick(0.12, 0.25)
	# turning round behind them
	if t >= 0.28 and t <= 0.46:
		var k := Humanoid._ease((t - 0.28) / 0.16)
		player.player_model.rotation.y = lerp_angle(atan2(-_dir.x, -_dir.z), atan2(_dir.x, _dir.z), k)
	if _once("turned", 0.46):
		_dir = _flat_to(_target)
		face_direction(_dir, 1.0)
		Net.fx("glint", [CorsairGun.muzzle(player), _col(FX.CORE), 0.6])
	if _once("shot", 0.5):
		_corsair_shot(26.0, _target, {"knock": 11.0, "down": true, "stagger": 0.6, "unblock": true, "stop": 0.09, "shake": 0.2}, 1.3)


## Broadside: the blade raised high to call it (untouchable until it lands), swept
## down to point at them as the pistol fans across, a shot into each, left to
## right; a held beat with the blade raised again while cannonballs whistle in,
## then the broadside lands on every one of them and throws them down.
const BROAD_SHOTS := 0.62
const BROAD_EVERY := 0.14
const BROAD_LAND := 1.75

func _broadside(delta: float) -> void:
	_rooted(delta, 0.0)
	if t < 0.5 and int(t * 12.0) != int((t - delta) * 12.0):
		var p := player.global_position + Vector3(randf_range(-1.6, 1.6), 0.1, randf_range(-1.6, 1.6))
		if _elem():
			Net.fx("element", ["corsair", p, Vector3.UP, 4, 2.5])
		else:
			Net.fx("dust", [p, 2, 0.4])
	if _once("glint", 0.42):
		Net.fx("glint", [_blade_tip(), _col(FX.CORE), 1.3])
		Net.fx("sfx", ["parry", player.global_position, -6.0, 0.0, 1.9])
	if _once("order", 0.56):
		Net.fx("blade_swoosh", [player.body_model, 0.12, _col()])
		Net.fx("sfx", ["whoosh", player.global_position, -5.0, 0.05, 1.0])
		CombatManager.apply_camera_kick(0.15, 0.3)
	while _hits < _victims.size() and t >= BROAD_SHOTS + _hits * BROAD_EVERY:
		var e: Node3D = _victims[_hits]
		_hits += 1
		if not is_instance_valid(e) or not BurnStatus.alive(e):
			continue
		var from := CorsairGun.muzzle(player)
		var c := CorsairGun.body_center(e)
		var hd := _hd(10.0, 1.0, false)
		hd.ranged = true
		hd.impact = "shot"
		hd.stagger_duration = 1.3
		hd.hitstop_duration = 0.02
		_strike(e, hd)
		Net.fx("tracer", [from, c, _col(FX.CORE)])
		Net.fx("muzzle_sparks", [from, (c - from).normalized(), 10, _col(FX.ACCENT) if _elem() else Color(1.0, 0.75, 0.35)])
		Net.fx("smoke", [from, 3, 0.5, 1.2, FX.POWDER_SMOKE if _elem() else Color(0.72, 0.72, 0.7, 0.75)])
		Net.fx("impact", [c, _col(FX.ACCENT)])
		if _elem():
			Net.fx("powder_burst", [c, (c - from).normalized(), 0.45, _col()])
		Net.fx("sfx", ["gunshot", from, -4.0, 0.1, 1.15])
	# the cannonballs coming in
	if _once("whistle", BROAD_LAND - 0.3):
		Net.fx("sfx", ["whoosh_big", player.global_position, 0.0, 0.05, 0.45])
		for e in _victims:
			if is_instance_valid(e):
				var at := (e as Node3D).global_position
				var a := randf() * TAU
				Net.fx("streak", [at + Vector3(cos(a) * 5.0, 14.0, sin(a) * 5.0), at + Vector3(0, 0.5, 0), _col(FX.CORE), 0.18, 0.32])
	if _once("land", BROAD_LAND):
		player.hurtbox.set_deferred("monitorable", true)
		for e in _victims:
			if is_instance_valid(e) and BurnStatus.alive(e):
				var hd := _hd(40.0, 10.0, true)
				hd.unblockable = true
				_strike_toward(e, hd, _flat_to(e))
				Net.fx("cannon_blast", [(e as Node3D).global_position, 1.5, _col() if _elem() else Color(0, 0, 0, 0)])
		Net.fx("ring", [player.global_position, Vector3.UP, 10.0, _col(), 0.6, 0.06])
		Net.fx("sfx", ["thud", player.global_position, 4.0, 0.03, 0.5])
		Net.fx("sfx", ["gunshot", player.global_position, 4.0, 0.05, 0.45])
		CombatManager.apply_camera_shake(0.5)
		CombatManager.apply_hitstop(0.1, [player])
		_moment(0.3, 0.35, 0.7, 0.45)


# --------------------------------------------------------------------------
# Unarmed: Shoulder Throw's carry (FistArts)
# --------------------------------------------------------------------------
## Carry the grabbed enemy (the host moves it; a guest's stays where it stood).
func _carry(p: Vector3) -> void:
	if _target == null or not is_instance_valid(_target) or Net.is_client():
		return
	_target.global_position = p
	if _target is CharacterBody3D:
		(_target as CharacterBody3D).velocity = Vector3.ZERO
	_target.reset_physics_interpolation()




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
