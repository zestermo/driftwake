extends PirateGrunt
class_name JungleApe
## The jungle's beast boss (BeastArena): a silverback nearly twice a man's height
## reared up, on the same rig as everyone (Humanoid, look "beast": "ape" builds
## ApeBuilder's gorilla body, height APE_H, stance "ape": the knuckle-walk;
## ApePoses for its moves). Its own brain, the grunt's body: death, ragdoll and
## co-op puppets come from PirateGrunt.
##
## Asleep at its post until the arena wakes it: a chest-beating roar (a
## shockwave: jump or dodge it), then it knuckle-runs you down and picks by
## range: the backhand swipe up close (parry it), the two-fist slam (a red
## ring in front of it), a leap onto you from afar (a ring where it lands), or
## it rips up a boulder and hurls it (a ring where it'll come down).
## Phases (1.23 beast pass, docs/v1_23_previews.md section 6): each adds moves it didn't have (MOVES), shortens its
## openings (OPEN) and chains moves (CHAIN: one at a time, then pairs, then three in a row with a long opening at the
## end). Phase 2 takes to the trees (the canopy drop, below) and throws Rock Barrages (three boulders running); phase 3
## grabs (mash out) and Berserk Pounds (four one-fist slams walking at you, cracking the floor), 15% quicker. Each
## change is a moment: it reels, rears up roaring, a ring of dust pushes everyone back, the camera punches in, and its
## look changes (eyes hotter, breath steaming, the mane bristling; in phase 3 steam off its back).
## Up in the canopy it runs the ring from limb to limb (crowns shake, leaves come down, its grunts and the
## rustle move round you, now and then a glimpse of it crouched on a branch),
## hurls boulders down from wherever it is (it shows itself to throw: the
## branch thrashes, a ring where it lands), then rears up on a limb roaring and
## crashes down onto you (a wide ring). Shoot or strike it while it shows
## itself and it's knocked out of the tree, stunned where it lands.
## Poise (Poise "beast_boss": 400, +25% a phase, refilling 30/s two seconds after the last blow; blows in an opening
## count double): broken, it reels in the stagger pose (never knocked down or juggled) and takes double damage for
## VULN_S. Parts (BeastParts): its tusks (blows to the head) break off: no more Grab, and ivory; its stone-hard
## knuckles (struck while its fists are in the ground after a slam) crack: the slams' rings shrink, and a knuckle bone.
## Armament Haki (or a guard-breaker) still knocks it out of a slam's or a leap's wind-up.
## Motion (BeastMotion, on every screen): it breathes and heaves, its head tracks you (locked on in a wind-up), blows
## shove it, its mane and necklace swing.
## Co-op: host-run; the shockwaves and the grab are judged on each captain's own machine
## (events "aoe", "grab"), the boulder flies on every screen (event "rock"), the crowns
## shake on every screen (event "shake"), up or showing itself, the phase, its broken parts ride the snapshot.

signal phase_changed(phase: int)

## The grab's wind-up (phase 3, 1.20).
const GRAB_WIND := 0.6
## How long it holds a captain it caught before it gives up on hearing how it ended (GrabbedState: 2.2 s).
const GRAB_HOLD := 2.6
const GRAB_R := 2.4

const APE_HP := 1500.0
## Look height: the rig's scale (ApeBuilder's unit body): ~3.5 m reared up, ~2.3 m on its knuckles.
const APE_H := 2.4
const HURT_FWD := 0.45
const RUN := 6.2
const SWIPE_RANGE := 4.9
const SLAM_R := 4.8
const LEAP_R := 5.4
const ROAR_R := 7.5
const ROCK_R := 3.6
const FUR := Color(0.21, 0.19, 0.18)
const SILVER := Color(0.7, 0.7, 0.68)
const ROAR_LEN := 2.0
const SLAM_WIND := 0.6
const LEAP_WIND := 0.45
const LEAP_AIR := 0.9
const LIFT_LEN := 0.9
const HURL_LEN := 0.6
## The canopy: up a limb, round the ring, boulders down, then down onto you.
const CLIMB_WIND := 0.5
const CLIMB_AIR := 1.0
const HOP := [1.5, 1.1]
const THROWS := [3, 4]
const CANOPY_CD := [30.0, 22.0]
const GLIMPSE := 0.6
const TREE_WIND := 0.75
const DROP_WARN := 1.3
const DROP_AIR := 0.7
const DROP_R := 6.2
## Taking this share of its health while it shows itself up there knocks it out of the tree.
const KNOCK_DOWN := 0.035
const FALL_STUN := 3.0

## The moves each phase adds (1.23): phase 1's, then phase 2's on top, then phase 3's.
const MOVES := [["swipe", "slam", "leap", "throw"], ["climb", "barrage"], ["grab", "pound"]]
## Its openings by phase (a move's own weight scales it: _end_special), how many moves it chains, its tempo.
const OPEN := [1.4, 1.1, 0.8]
const CHAIN := [1, 2, 3]
const CHAIN_GAP := 0.15
## (a chain of three ends on a long opening)
const CHAIN_END := 0.45
const TEMPO := [1.0, 1.0, 1.15]
const CHAINABLE := ["swipe", "slam", "leap", "throw", "pound", "grab"]
## Rock Barrage: boulders in a row; the next ripped up quicker (from this far into the lift).
const BARRAGE := 3
const BARRAGE_SKIP := 0.3
## Berserk Pound: one-fist slams walking at you, a ring and a crack in the floor each.
const POUNDS := 4
const POUND_WIND := 0.7
const POUND_EVERY := 0.62
const POUND_R := 3.0
## A poise break: the stagger pose this long, double damage until this long after the break.
const REEL_S := 2.4
const VULN_S := 3.0
const VULN_K := 2.0
## The phase change: it reels this long before it rears up roaring; its ring pushes everyone back.
const MOMENT_REEL := 0.5
const MOMENT_R := 9.5
const MOMENT_COL := Color(1.0, 0.62, 0.3)
## Parts (BeastParts): [share of its health a part takes to break, reach (m), item, colour]; broken fists shrink the
## slams' rings to FIST_K; a part breaking drains PART_POISE.
const PARTS := {"tusks": [0.08, 1.4, "ivory", Color(0.93, 0.88, 0.74)], "fists": [0.1, 1.3, "knuckle", Color(0.6, 0.57, 0.52)]}
const PART_NAMES := {"tusks": "Tusks", "fists": "Knuckles"}
const FIST_K := 0.6
const PART_POISE := 120.0
## Its eyes by phase (look change).
const EYES := [[Color(1.0, 0.55, 0.12), 1.4], [Color(1.0, 0.38, 0.08), 2.4], [Color(1.0, 0.1, 0.05), 3.2]]
## How hard its head locks on to you in each of its actions (1: fixed on you; "" its gait).
const LOOK_LOCK := {"": 0.8, "ape_crouch": 1.0, "ape_slam_wind": 1.0, "ape_lift": 0.9, "ape_air": 0.8, "ape_hurl": 0.6,
	"ape_swipe": 0.5, "ape_slam": 0.2, "ape_beat": 0.35, "ape_reel": 0.0, "ape_grab": 0.6, "ape_grab_hold": 0.3,
	"ape_pound_l": 0.6, "ape_pound_r": 0.6, "ape_dive": 0.8, "ape_perch": 0.9}

var phase: int = 1
var arena: Node = null
var boss_name: String = "The Silverback"
var _special: String = ""
var _sp_t: float = 0.0
var _sp_from := Vector3.ZERO
var _sp_target := Vector3.ZERO
var _sp_hit: bool = false
var _cd := {"swipe": 0.0, "slam": 3.0, "leap": 6.0, "throw": 5.0, "canopy": 0.0, "grab": 4.0, "barrage": 3.0, "pound": 4.0}
## The last move it chose: _choose() won't pick it straight again (docs/v1_20_beasts.md "Rules").
var _last_pick := ""
## Chains (1.23): moves still to come in this one, and whether the next pick is one of them.
var _chain_left := 0
var _in_chain := false
var _barrage := 0
var _pound_i := 0
var _beat_i := 0
var _grab_caught := false
## The phase change's roar (not the wake's).
var _moment := false
## Double damage until this physics frame (a poise break).
var _vuln_until := -1
var parts := BeastParts.new()
var motion := BeastMotion.new()
var _mane_c := BeastMotion.SwingChain.new(1, 70.0, 7.0, 0.0)
var _neck_c := BeastMotion.SwingChain.new(1, 30.0, 3.5, 0.0)
var _steam: Array = []
var _hit_swipe: HitData
var _rock: MeshInstance3D
var _rocks: Array = []   # [node, from, to, t, dur] flying
## Up in the canopy: the limb it's on (index into arena.trees), or -1 on the ground.
var up: bool = false
var _perch: int = -1
var _hop_to: int = -1
var _hop_len: float = 1.3
var _hop_dir: int = 1
var _throws: int = 0
var _rustle_t: float = 0.0
var _show_t: float = 0.0
var _tree_hits: float = 0.0


static func ape_look() -> Dictionary:
	var lk := CharacterLook.base_look()
	lk.merge({"name": "Silverback", "beast": "ape", "body": "masc", "build": "broad", "height": APE_H, "skin": FUR,
		"head": "square", "nose": "broad", "eyes": 1, "brows": 3, "mouth": 3, "eye_color": Color(0.55, 0.3, 0.1), "marks": "none",
		"hair": "bald", "facial_hair": "none", "hat": "none", "top": "bare", "sleeves": "none", "vest": "none", "coat": "none",
		"legs": "shorts", "legs_color": FUR, "feet": "barefoot", "belt": "none", "gloves": false, "scarf": false, "earring": false,
		"eyepatch": false, "pouch": false}, true)
	return lk


func _ready() -> void:
	look = JungleApe.ape_look()
	role = "ape"
	super._ready()
	add_to_group("bosses")
	humanoid.set_weapon(null)
	humanoid.stance = "ape"
	# a body to match (the grunt's were made for a man)
	var cap := _col.shape as CapsuleShape3D
	cap.radius = 1.05
	cap.height = 3.0
	_col.position = Vector3(0, 1.5, 0)
	var hcap := (hurtbox.get_child(0) as CollisionShape3D).shape as CapsuleShape3D
	hcap.radius = 1.45
	hcap.height = 3.8
	_hurt_follow()
	var bs := hitbox.get_child(0) as CollisionShape3D
	(bs.shape as BoxShape3D).size = Vector3(5.2, 2.8, 4.2)
	bs.position = Vector3(0, 1.4, -2.7)
	_hit_swipe = HitData.new()
	_hit_swipe.impact = "punch"
	_hit_swipe.damage = _dmg(22.0)
	_hit_swipe.knockback_force = 10.0
	_hit_swipe.stagger_duration = 0.5
	_hit_swipe.hitstop_duration = 0.1
	_hit_swipe.camera_shake_intensity = 0.3
	hitbox.hit_data = _hit_swipe
	_bark.position.y = 5.0
	var hp := health.max_health
	parts.add("tusks", hp * float(PARTS["tusks"][0]), [humanoid.head], PARTS["tusks"][1], PARTS["tusks"][2], PARTS["tusks"][3])
	parts.add("fists", hp * float(PARTS["fists"][0]), [humanoid.hand_l, humanoid.hand_r], PARTS["fists"][1], PARTS["fists"][2], PARTS["fists"][3])
	parts.opens["fists"] = _fists_down
	phase_changed.connect(func(_n: int): _apply_look())


func _poise_class() -> String:
	return "beast_boss"


## The hurtbox rides forward over the chest and arms (it knuckle-walks ahead of its feet).
func _hurt_follow() -> void:
	(hurtbox.get_child(0) as CollisionShape3D).position = facing.basis * Vector3(0, 1.9, -HURT_FWD)


## The camera draws back for this fight (CameraRig): 1 while it fights within reach of us.
func camera_room(from: Vector3) -> float:
	if state == S.DEAD or not in_combat():
		return 0.0
	return 1.0 - smoothstep(26.0, 34.0, from.distance_to(global_position))


func is_fighting() -> bool:
	return in_combat()


func asleep() -> bool:
	return state == S.IDLE


func health_frac() -> float:
	return health.current_health / maxf(health.max_health, 1.0)


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": SILVER}, "Silverback Pelt", t)


## The moves its phase allows (MOVES up to its phase; no Grab with its tusks broken).
func moves() -> Array:
	var out: Array = []
	for i in range(phase):
		out.append_array(MOVES[i])
	if parts.broken("tusks"):
		out.erase("grab")
	return out


## How many of its parts are broken (IslandArcs' hidden finish: "break both its parts before it falls").
func parts_broken() -> int:
	return parts.count_broken()


func vulnerable() -> bool:
	return Engine.get_physics_frames() < _vuln_until


func _tempo() -> float:
	return TEMPO[phase - 1]


## Woken (the arena, or a hit): it rears up and roars first.
func alert(_delay: float = 0.0) -> void:
	if state != S.IDLE and state != S.RETURN:
		return
	humanoid.seated = false
	_begin_special("roar")


# ==========================================================================
# Brain
# ==========================================================================
func _physics_process(delta: float) -> void:
	_fly_rocks(delta)
	_hurt_follow()
	if net_puppet or state in [S.DEAD, S.DOWN] or humanoid.ragdoll != null:
		super._physics_process(delta)
		_rock_follow()
		return
	st_t += delta
	_bark_t -= delta
	if _bark_t <= 0.0:
		_bark.visible = false
	for k in _cd.keys():
		_cd[k] -= delta * (1.6 if phase >= 3 else (1.25 if phase == 2 else 1.0))
	_phase_check()
	_rock_follow()
	if _special != "":
		_special_update(delta)
		return
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	var p := _target()
	var to_p := _flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	var want := Vector3.ZERO
	var running := false
	match state:
		S.IDLE:
			_yaw = post_yaw
		S.CHASE:
			if p == null or not _player_ok(p):
				pass
			else:
				var nd := _nav_dir(p.global_position, delta)
				_face(to_p)
				var pick := _choose(dist)
				if pick != "":
					_begin_special(pick)
					return
				if _in_chain:
					# (nothing in reach to carry the chain on with: it's over, the opening comes now)
					_in_chain = false
					_chain_left = 0
					_recover(OPEN[phase - 1])
					return
				if dist > SWIPE_RANGE - 0.6:
					want = nd * RUN * (1.2 if phase >= 3 else 1.0)
					running = true
		S.RECOVER:
			if st_t > float(get_meta("recover", 0.5)):
				_set_state(S.CHASE)
		S.STAGGER:
			if st_t > _stagger_len:
				humanoid.stop_action()
				_set_state(S.CHASE)
		S.RETURN:
			var home := _flat(post - global_position)
			if home.length() < 1.5:
				_set_state(S.IDLE)
			else:
				_face(home)
				want = home.normalized() * RUN * 0.6
		_:
			_set_state(S.CHASE)
	var hv := _flat(velocity).move_toward(want, 24.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	move_and_slide()
	facing.rotation.y = lerp_angle(facing.rotation.y, _yaw, minf(7.0 * delta, 1.0))
	_feed_body(hv, running)


func _choose(dist: float) -> String:
	var m := _choose_any(dist)
	if m != "":
		if not _in_chain:
			_chain_left = CHAIN[phase - 1] - 1
		_in_chain = false
		_last_pick = m
	return m


## (a chain's next move goes whatever its cooldown)
func _ready_to(m: String) -> bool:
	return m in moves() and (float(_cd.get(m, 99.0)) <= 0.0 or (_in_chain and m in ["swipe", "slam", "leap", "throw"]))


func _choose_any(dist: float) -> String:
	if "climb" in moves() and not _in_chain and float(_cd.get("canopy", 99.0)) <= 0.0 and arena != null and not (arena.trees as Array).is_empty():
		return "climb"
	if _ready_to("grab") and dist < 6.0 and _last_pick != "grab":
		_cd["grab"] = _rng.randf_range(9.0, 12.0)
		return "grab"
	if _ready_to("pound") and dist < 11.0 and _last_pick != "pound":
		_cd["pound"] = _rng.randf_range(12.0, 15.0)
		return "pound"
	if dist < SWIPE_RANGE and _ready_to("swipe"):
		if dist < 5.5 and _ready_to("slam") and _last_pick != "slam" and (_rng.randf() < 0.35 or _last_pick == "swipe"):
			_cd["slam"] = _rng.randf_range(5.0, 7.0)
			return "slam"
		if _last_pick != "swipe":
			_cd["swipe"] = _rng.randf_range(1.0, 1.8)
			return "swipe"
	if dist > (5.0 if _in_chain else 7.0) and dist < 22.0 and _ready_to("leap") and _last_pick != "leap" and (_in_chain or _rng.randf() < 0.6):
		_cd["leap"] = _rng.randf_range(7.0, 10.0)
		return "leap"
	if dist > 8.0 and dist < 30.0 and _ready_to("barrage") and _last_pick not in ["barrage", "throw"]:
		_cd["barrage"] = _rng.randf_range(11.0, 14.0)
		return "barrage"
	if dist > 9.0 and dist < 30.0 and _ready_to("throw") and _last_pick != "throw":
		_cd["throw"] = _rng.randf_range(6.0, 9.0)
		return "throw"
	return ""


func _phase_check() -> void:
	var f := health_frac()
	var was := phase
	if phase == 1 and f < 0.6:
		phase = 2
		_cd["canopy"] = 0.0
	if phase == 2 and f < 0.3:
		phase = 3
	if phase == was:
		return
	poise = Poise.make("beast_boss", pow(1.25, phase - 1))
	_chain_left = 0
	_in_chain = false
	phase_changed.emit(phase)
	if up:
		_moment_fx()
	else:
		_drop_held()
		_moment = true
		_begin_special("roar")


# ==========================================================================
# Specials
# ==========================================================================
func _begin_special(what: String) -> void:
	hitbox.deactivate()
	_barrage = 0
	if what == "barrage":
		_barrage = BARRAGE - 1
		what = "throw"
	_special = what
	_sp_t = 0.0
	_sp_hit = false
	_set_state(S.WIND)
	_attack = what
	var p := _target()
	match what:
		"roar":
			_beat_i = 0
			remove_meta("beating")
			if _moment:
				_stagger_fx()
				humanoid.hold("ape_reel", 0.12)
			else:
				humanoid.play("ape_beat", ROAR_LEN)
				Net.fx("sfx", ["roar", global_position, 6.0, 0.03, 0.7])
		"swipe":
			humanoid.play("ape_swipe", ActionSpecs.length("ape_swipe"))
			Net.fx("sfx", ["whoosh_big", global_position, -2.0, 0.05, 0.7])
		"grab":
			# (phase 3: a low lunge that catches you, shakes you and throws you down; mash to break free)
			_grab_caught = false
			humanoid.hold("ape_crouch", GRAB_WIND / _tempo())
			Net.fx("sfx", ["peril", global_position, -1.0, 0.03, 0.8])
		"slam":
			humanoid.hold("ape_slam_wind", SLAM_WIND / _tempo())
			_sp_target = _ground_at(global_position + _fwd() * 3.2)
			Net.fx("telegraph", [_sp_target, _slam_r(), SLAM_WIND / _tempo() + 0.18, Color(1.0, 0.18, 0.12)])
			Net.fx("sfx", ["peril", global_position, -1.0, 0.03, 0.7])
		"pound":
			_pound_i = 0
			humanoid.hold("ape_slam_wind", POUND_WIND / _tempo())
			Net.fx("sfx", ["roar", global_position, 5.0, 0.03, 1.05])
			Net.fx("sfx", ["peril", global_position, -1.0, 0.03, 0.6])
		"leap":
			_sp_from = global_position
			_sp_target = _ground_at(p.global_position if p else global_position + _fwd() * 10.0)
			_face(_flat(_sp_target - global_position))
			humanoid.hold("ape_crouch", LEAP_WIND / _tempo())
			Net.fx("telegraph", [_sp_target, LEAP_R, LEAP_WIND / _tempo() + LEAP_AIR, Color(1.0, 0.18, 0.12)])
			Net.fx("sfx", ["peril", global_position, -1.0, 0.03, 0.65])
		"throw":
			humanoid.hold("ape_lift", LIFT_LEN / _tempo())
		"climb":
			_cd["canopy"] = CANOPY_CD[0 if phase < 3 else 1] + _rng.randf_range(-3.0, 3.0)
			_throws = THROWS[0 if phase < 3 else 1]
			_perch = _nearest_perch()
			_hop_dir = 1 if _rng.randf() < 0.5 else -1
			_sp_from = global_position
			_sp_target = _perch_at(_perch)
			_face(_flat(_sp_target - global_position))
			humanoid.hold("ape_crouch", CLIMB_WIND)
			_say("grunt", global_position, 4.0, 0.9)


func _ground_at(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 14.0, 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


## The slams' ring: smaller once its knuckles are broken.
func _slam_r() -> float:
	return SLAM_R * (FIST_K if parts.broken("fists") else 1.0)


func _special_update(delta: float) -> void:
	_sp_t += delta
	st_t += delta
	var want := Vector3.ZERO
	var grounded := true
	var p := _target()
	match _special:
		"roar":
			_roar_update()
		"swipe":
			var len := ActionSpecs.length("ape_swipe")
			var u := _sp_t / len
			if u < 0.4 and p:
				_face(_flat(p.global_position - global_position))
			if u > 0.36 and u < 0.52:
				want = _fwd() * 5.0
			if u > 0.42 and not _sp_hit:
				_sp_hit = true
				hitbox.hit_data = _hit_swipe
				hitbox.activate()
			if u > 0.6:
				hitbox.deactivate()
			if u >= 1.0:
				_end_special(0.4)
		"grab":
			want = _grab_update(p)
		"slam":
			var wind := SLAM_WIND / _tempo()
			if _sp_t > wind and not has_meta("slam_down"):
				set_meta("slam_down", true)
				humanoid.play("ape_slam", ActionSpecs.length("ape_slam"))
			if _sp_t > wind + 0.18 and not _sp_hit:
				_sp_hit = true
				_aoe(_sp_target, _slam_r(), 26.0, true)
				Net.fx("dust_ring", [_sp_target, 28, 1.8 * _slam_r() / SLAM_R])
				Net.fx("ring", [_sp_target, Vector3.UP, _slam_r(), Color(1.0, 0.85, 0.6), 0.35, 0.25])
				Net.fx("impact", [_sp_target + Vector3(0, 0.4, 0), Color(1.0, 0.55, 0.3)])
				Net.fx("sfx", ["thud", _sp_target, 6.0, 0.05, 0.5])
				_leaves(_sp_target, 22)
				get_node("/root/CombatManager").apply_camera_shake(0.4)
			if _sp_t > wind + 0.8:
				remove_meta("slam_down")
				_end_special(1.0)
		"pound":
			want = _pound_update(p)
		"leap":
			var wind := LEAP_WIND / _tempo()
			if _sp_t < wind:
				_face(_flat(_sp_target - global_position))
			elif not _sp_hit:
				var u := clampf((_sp_t - wind) / LEAP_AIR, 0.0, 1.0)
				if humanoid.current_action() != "ape_air":
					humanoid.hold("ape_air")
				var flat := _sp_from.lerp(_sp_target, u)
				global_position = Vector3(flat.x, lerpf(_sp_from.y, _sp_target.y, u) + sin(u * PI) * 6.0, flat.z)
				velocity = Vector3.ZERO
				grounded = false
				if u >= 1.0:
					_sp_hit = true
					humanoid.play("ape_slam", ActionSpecs.length("ape_slam"))
					_aoe(global_position, LEAP_R, 30.0, false)
					Net.fx("dust_ring", [global_position, 32, 2.0])
					Net.fx("impact", [global_position + Vector3(0, 0.5, 0), Color(1.0, 0.5, 0.3)])
					Net.fx("sfx", ["thud", global_position, 7.0, 0.05, 0.45])
					_leaves(global_position, 18)
					get_node("/root/CombatManager").apply_camera_shake(0.45)
			elif _sp_t > wind + LEAP_AIR + 0.8:
				_end_special(0.85)
		"throw":
			_throw_update(p)
		"climb":
			grounded = false
			_climb_update()
		"prowl":
			grounded = false
			_prowl_update(delta)
		"tree_throw":
			grounded = false
			_tree_throw_update(p)
		"drop":
			grounded = false
			_drop_update()
		"fall":
			grounded = false
			_fall_update(delta)
	if _special == "":
		return
	if grounded:
		if is_on_floor() and velocity.y < 0.0:
			velocity.y = -0.5
		else:
			velocity.y -= GRAVITY * delta
		var hv := _flat(velocity).move_toward(want, 30.0 * delta)
		velocity.x = hv.x
		velocity.z = hv.z
		move_and_slide()
		facing.rotation.y = lerp_angle(facing.rotation.y, _yaw, minf(8.0 * delta, 1.0))
		_feed_body(hv, false)
	else:
		facing.rotation.y = lerp_angle(facing.rotation.y, _yaw, minf(8.0 * delta, 1.0))
		_feed_body(Vector3.ZERO, false)
		humanoid.grounded = false


## The wake's roar, or a phase change's moment (it reels first, then rears up): each chest beat a ring off its chest,
## then the roar's ring of dust that pushes everyone back.
func _roar_update() -> void:
	var t0 := MOMENT_REEL if _moment else 0.0
	if _sp_t < t0:
		return
	if _moment and not has_meta("beating"):
		set_meta("beating", true)
		humanoid.play("ape_beat", ROAR_LEN)
		Net.fx("sfx", ["roar", global_position, 8.0, 0.03, 0.62])
	var rt := _sp_t - t0
	var beats := [0.28, 0.48, 0.68]
	if _beat_i < beats.size() and rt > float(beats[_beat_i]) * ROAR_LEN:
		_beat_i += 1
		Net.fx("ring", [global_position + Vector3.UP * 2.6 + _fwd() * 0.9, _fwd(), 1.4 + 0.5 * _beat_i, Color(1.0, 0.92, 0.8), 0.3, 0.14])
		Net.fx("sfx", ["punch_heavy", global_position + Vector3.UP * 2.5, 2.0, 0.05, 0.55])
	if rt > ROAR_LEN * 0.8 and not _sp_hit:
		_sp_hit = true
		if _moment:
			_aoe(global_position, MOMENT_R, 6.0, false, 0.6)
			_moment_fx()
		else:
			_aoe(global_position, ROAR_R, 10.0, false)
			Net.fx("dust_ring", [global_position, 30, 2.2])
			get_node("/root/CombatManager").apply_camera_shake(0.35)
	if rt > ROAR_LEN:
		remove_meta("beating")
		_moment = false
		_special = ""
		_recover(0.2)


## The phase change's moment on every screen (BeastFX.moment: rings, dust, the camera punching in for whoever's near).
func _moment_fx() -> void:
	BeastFX.moment(global_position, 1.0, MOMENT_COL)
	Net.event(self, "moment", [global_position])
	_leaves(global_position, 40)


## A low lunge, then whoever's in its arms is held (GrabbedState on their machine) until they mash free or it throws.
func _grab_update(p: Node3D) -> Vector3:
	var wind := GRAB_WIND / _tempo()
	var want := Vector3.ZERO
	if p and _sp_t < wind * 0.6:
		_face(_flat(p.global_position - global_position))
	if _sp_t > wind and _sp_t < wind + 0.25:
		want = _fwd() * 9.0
		if humanoid.current_action() != "ape_grab":
			humanoid.play("ape_grab", 0.5)
			Net.fx("sfx", ["whoosh_big", global_position, 0.0, 0.05, 0.6])
	if _sp_t > wind + 0.2 and not _sp_hit:
		_sp_hit = true
		var at := global_position + _fwd() * 2.2
		_grab_caught = false
		for c in Net.all_players():
			if _flat((c as Node3D).global_position - at).length() < GRAB_R and _player_ok(c):
				_grab_caught = true
		_grab_local(at)
		Net.event(self, "grab", [at])
		if _grab_caught:
			humanoid.hold("ape_grab_hold", 0.15)
			Net.fx("sfx", ["punch_heavy", at, 2.0, 0.05, 0.7])
			_say("grunt", global_position, 6.0, 0.8)
		else:
			_end_special(1.1)
			return want
	if _grab_caught and _sp_t > wind + 0.2 + GRAB_HOLD:
		grab_ended(false)
	return want


## The grab, judged on this machine for its own captain: caught if they're in its arms.
func _grab_local(at: Vector3) -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me == null or not me.has_node("Hurtbox"):
		return
	var hb := me.get_node("Hurtbox") as Hurtbox
	if not hb.monitorable or _flat(me.global_position - at).length() > GRAB_R or me.global_position.y > at.y + 1.6:
		return
	var hd := HitData.new()
	hd.grab = true
	hd.damage = 0.0
	hd.impact = "punch"
	hb.take_hit(hd, self)


## Where a captain it holds is kept (GrabbedState), and what its throw does to them.
func grab_spot() -> Vector3:
	return global_position + _fwd() * 2.0


func grab_damage() -> float:
	return _dmg(30.0)


## The grab is over (the captain's machine says): mashed free, it reels; held to the end, it hurls them down.
func grab_ended(broke: bool) -> void:
	if Net.forward(self, "grab_ended", [broke]):
		return
	if _special != "grab" or not _grab_caught:
		return
	_grab_caught = false
	if broke:
		_stagger(-_fwd(), 1.6)
	else:
		humanoid.play("ape_hurl", HURL_LEN)
		Net.fx("sfx", ["thud", global_position + _fwd() * 2.0, 6.0, 0.05, 0.6])
		Net.fx("dust_ring", [global_position + _fwd() * 2.0, 16, 1.2])
		_end_special(0.85)


## Berserk Pound: four one-fist slams walking at you (the last two-fisted), each a ring and a crack in the floor.
func _pound_update(p: Node3D) -> Vector3:
	var wind := POUND_WIND / _tempo()
	var every := POUND_EVERY / _tempo()
	if _sp_t < wind:
		if p:
			_face(_flat(p.global_position - global_position))
		return Vector3.ZERO
	var i := int((_sp_t - wind) / every)
	if i >= POUNDS:
		if _sp_t > wind + POUNDS * every + 0.5:
			_end_special(1.1)
		return Vector3.ZERO
	var bu := fmod(_sp_t - wind, every) / every
	if i >= _pound_i:
		_pound_i = i + 1
		_sp_hit = false
		if p:
			_face(_flat(p.global_position - global_position))
		humanoid.play("ape_slam" if i == POUNDS - 1 else ("ape_pound_r" if i % 2 == 0 else "ape_pound_l"), every)
		Net.fx("telegraph", [_pound_at(i), _pound_r(i), every * 0.5, Color(1.0, 0.18, 0.12)])
	if bu > 0.5 and not _sp_hit:
		_sp_hit = true
		var at := _pound_at(i)
		var last := i == POUNDS - 1
		_aoe(at, _pound_r(i), 26.0 if last else 18.0, false, 0.5)
		Net.fx("ground_crack", [at, _fwd(), 5.5 if last else 4.0, Color(0, 0, 0, 0), _rng.randi() % 1000, 0.18])
		Net.fx("dust_ring", [at, 18, 1.3])
		Net.fx("debris", [at, Vector3.UP, 8, Color(0.42, 0.36, 0.3), 5.0])
		Net.fx("sfx", ["thud", at, 6.0, 0.05, 0.55 if last else 0.65])
		_leaves(at, 10)
		get_node("/root/CombatManager").apply_camera_shake(0.42 if last else 0.28)
	return _fwd() * 3.6 if bu < 0.45 else Vector3.ZERO


func _pound_at(i: int) -> Vector3:
	var side := 0.0 if i == POUNDS - 1 else (0.7 if i % 2 == 0 else -0.7)
	return _ground_at(global_position + _fwd() * 2.6 + _fwd().cross(Vector3.UP) * side)


func _pound_r(i: int) -> float:
	return POUND_R * (FIST_K if parts.broken("fists") else 1.0) * (1.4 if i == POUNDS - 1 else 1.0)


## A boulder ripped up and hurled; a Rock Barrage rips the next one up straight after.
func _throw_update(p: Node3D) -> void:
	var lift := LIFT_LEN / _tempo()
	if p and _sp_t < lift + HURL_LEN * 0.25:
		_face(_flat(p.global_position - global_position))
	if _sp_t > lift * 0.35 and _rock == null and not _sp_hit:
		_grab_rock()
		Net.event(self, "rock", ["grab"])
	if _sp_t > lift and not has_meta("hurling"):
		set_meta("hurling", true)
		humanoid.play("ape_hurl", HURL_LEN)
	if _sp_t > lift + HURL_LEN * 0.25 and not _sp_hit and _rock:
		_sp_hit = true
		_hurl_at(p, 20.0, 0.55)
	if _sp_t > lift + HURL_LEN:
		remove_meta("hurling")
		if _barrage > 0:
			_barrage -= 1
			_sp_t = lift * BARRAGE_SKIP
			_sp_hit = false
			humanoid.hold("ape_lift", 0.12)
			Net.fx("sfx", ["punch_heavy", global_position + _fwd() * 1.5, 0.0, 0.05, 0.6])
			return
		_end_special(0.55)


## The boulder in its fists flies at `p` (where it's heading), a ring where it'll come down.
func _hurl_at(p: Node3D, speed: float, min_t: float) -> void:
	var from := _rock.global_position
	var to := _ground_at((p.global_position + _flat((p as CharacterBody3D).velocity) * 0.4) if p else global_position + _fwd() * 12.0)
	var dur := clampf(from.distance_to(to) / speed, min_t, 1.5)
	Net.fx("telegraph", [to, ROCK_R, dur, Color(1.0, 0.18, 0.12)])
	_throw_rock(from, to, dur)
	Net.event(self, "rock", ["throw", from, to, dur])
	get_tree().create_timer(dur).timeout.connect(func():
		if is_instance_valid(self):
			_aoe(to, ROCK_R, 24.0, false))


## A move's over: the opening after it (OPEN by phase times `k`, the move's weight), or straight into the chain's next.
func _end_special(k: float) -> void:
	hitbox.deactivate()
	var was := _special
	_special = ""
	var rec: float = OPEN[phase - 1] * k
	if _chain_left > 0 and was in CHAINABLE:
		_chain_left -= 1
		_in_chain = true
		rec = CHAIN_GAP
	elif CHAIN[phase - 1] >= 3 and was in CHAINABLE:
		rec += CHAIN_END
	_recover(rec)


func _recover(secs: float) -> void:
	set_meta("recover", secs)
	_set_state(S.RECOVER)


## Leaves shaken down out of the canopy over `at` (its slams), every screen.
func _leaves(at: Vector3, amount: int) -> void:
	if arena == null:
		return
	BeastFX.leaves(at + Vector3(0, 9.0, 0), amount, 5.0)
	Net.event(self, "leaves", [at + Vector3(0, 9.0, 0), amount, 5.0])


# ==========================================================================
# The canopy
# ==========================================================================
func _perch_at(i: int) -> Vector3:
	return arena.trees[i]["perch"]


func _nearest_perch() -> int:
	var best := 0
	var bd := INF
	for i in range((arena.trees as Array).size()):
		var d := _flat(_perch_at(i) - global_position).length()
		if d < bd:
			bd = d
			best = i
	return best


## Facing the floor's middle from up on limb `i`.
func _face_in() -> void:
	_face(_flat(arena.centre() - global_position))


func _shake(i: int, k: float) -> void:
	arena.shake(i, k)
	Net.event(self, "shake", [i, k])


func _say(n: String, at: Vector3, vol: float, pitch: float) -> void:
	BeastFX.sfx(n, at, vol, pitch, 90.0)
	Net.event(self, "say", [n, at, vol, pitch])


## Hidden in the leaves (`on` false) or showing itself on its limb.
func _show(on: bool) -> void:
	humanoid.visible = on
	hurtbox.monitorable = on


func _go_up(on: bool) -> void:
	up = on
	_col.disabled = on
	_tree_hits = 0.0
	if not on:
		_perch = -1
		_show(true)


## A crouch, then one great bound up onto the limb; into the leaves.
func _climb_update() -> void:
	if _sp_t < CLIMB_WIND:
		_face(_flat(_sp_target - global_position))
		return
	var u := clampf((_sp_t - CLIMB_WIND) / CLIMB_AIR, 0.0, 1.0)
	if humanoid.current_action() != "ape_air":
		humanoid.hold("ape_air", 0.2)
		_go_up(true)
		_show(true)
		Net.fx("dust_ring", [_sp_from, 20, 1.4])
		Net.fx("sfx", ["whoosh_big", _sp_from, 2.0, 0.05, 0.6])
	var flat := _sp_from.lerp(_sp_target, u)
	global_position = Vector3(flat.x, lerpf(_sp_from.y, _sp_target.y, u * u * (3.0 - 2.0 * u)) + sin(u * PI) * 3.0, flat.z)
	velocity = Vector3.ZERO
	if u >= 1.0:
		_shake(_perch, 1.0)
		_say("branch", global_position, 2.0, 0.9)
		_show(false)
		_next_hop()
		_special = "prowl"
		_sp_t = 0.0


## Off along the ring to another limb (on round the way it's going, now and then doubling back).
func _next_hop() -> void:
	var n: int = (arena.trees as Array).size()
	if _rng.randf() < 0.25:
		_hop_dir = -_hop_dir
	_hop_to = posmod(_perch + _hop_dir * (1 + (1 if _rng.randf() < 0.35 else 0)), n)
	_hop_len = HOP[0 if phase < 3 else 1] * _rng.randf_range(0.85, 1.2)
	_sp_from = global_position
	_sp_target = _perch_at(_hop_to)
	_show_t = 0.0


## Running the canopy: limb to limb along the ring, the leaves thrashing where it goes.
func _prowl_update(delta: float) -> void:
	var u := clampf(_sp_t / _hop_len, 0.0, 1.0)
	var c: Vector3 = arena.centre()
	var a0 := atan2(_sp_from.z - c.z, _sp_from.x - c.x)
	var a1 := atan2(_sp_target.z - c.z, _sp_target.x - c.x)
	var a := a0 + angle_difference(a0, a1) * u
	var r := lerpf(_flat(_sp_from - c).length(), _flat(_sp_target - c).length(), u) + sin(u * PI) * 2.5
	global_position = Vector3(c.x + cos(a) * r, lerpf(_sp_from.y, _sp_target.y, u) + sin(u * PI) * 1.6, c.z + sin(a) * r)
	_face(Vector3(-sin(a), 0.0, cos(a)) * float(signf(angle_difference(a0, a1))))
	velocity = Vector3.ZERO
	_rustle_t -= delta
	if _rustle_t <= 0.0 and u < 0.95:
		_rustle_t = 0.42
		BeastFX.leaves(global_position + Vector3(0, 3.0, 0), 8, 2.0)
		BeastFX.sfx("leaves", global_position, -6.0, 1.1, 80.0)
		Net.event(self, "rustle", [global_position])
	if _show_t > 0.0:
		_show_t -= delta
		if _show_t <= 0.0:
			_show(false)
	if u < 1.0:
		return
	_perch = _hop_to
	_shake(_perch, 0.55)
	_face_in()
	if _rng.randf() < 0.3:
		_say("grunt", global_position, 2.0, _rng.randf_range(0.85, 1.05))
	if _throws > 0 and _rng.randf() < 0.6:
		_throws -= 1
		_special = "tree_throw"
		_sp_t = 0.0
		_sp_hit = false
		_show(true)
		humanoid.hold("ape_lift", TREE_WIND * 0.6)
		_shake(_perch, 1.0)
		_say("grunt", global_position, 4.0, 0.95)
		return
	if _throws <= 0:
		_special = "drop"
		_sp_t = 0.0
		_sp_hit = false
		var p := _target()
		_sp_from = global_position
		_sp_target = _ground_at(p.global_position if p else arena.centre())
		_show(true)
		humanoid.play("ape_beat", DROP_WARN)
		Net.fx("telegraph", [_sp_target, DROP_R, DROP_WARN + DROP_AIR, Color(1.0, 0.18, 0.12)])
		Net.fx("sfx", ["roar", global_position, 8.0, 0.03, 0.62])
		_shake(_perch, 1.0)
		return
	_next_hop()
	_sp_t = 0.0
	# a glimpse now and then: crouched on the limb, eyes in the dark
	if _rng.randf() < 0.35:
		_show(true)
		humanoid.hold("ape_perch", 0.15)
		_show_t = GLIMPSE


## Showing itself on the limb, a boulder hauled up and hurled down.
func _tree_throw_update(p: Node3D) -> void:
	if p:
		_face(_flat(p.global_position - global_position))
	if _sp_t > TREE_WIND * 0.4 and _rock == null and not _sp_hit:
		_grab_rock()
		Net.event(self, "rock", ["grab"])
	if _sp_t > TREE_WIND and not has_meta("hurling"):
		set_meta("hurling", true)
		humanoid.play("ape_hurl", HURL_LEN)
	if _sp_t > TREE_WIND + HURL_LEN * 0.25 and not _sp_hit and _rock:
		_sp_hit = true
		_hurl_at(p, 22.0, 0.8)
	if _sp_t > TREE_WIND + HURL_LEN + 0.15:
		remove_meta("hurling")
		_show(false)
		_special = "prowl"
		_next_hop()
		_sp_t = 0.0


## Reared up on the limb roaring, then down out of the canopy onto you.
func _drop_update() -> void:
	if _sp_t < DROP_WARN:
		_face(_flat(_sp_target - global_position))
		return
	var u := clampf((_sp_t - DROP_WARN) / DROP_AIR, 0.0, 1.0)
	if humanoid.current_action() != "ape_dive":
		humanoid.hold("ape_dive", 0.15)
		_hurt_off_for_dive()
		BeastFX.leaves(global_position + Vector3(0, 2.0, 0), 30, 3.0)
		Net.event(self, "rustle", [global_position])
		Net.fx("sfx", ["whoosh_big", global_position, 4.0, 0.05, 0.55])
	var flat := _sp_from.lerp(_sp_target, u)
	global_position = Vector3(flat.x, lerpf(_sp_from.y, _sp_target.y, u * u) + sin(u * PI) * 2.0, flat.z)
	velocity = Vector3.ZERO
	if u >= 1.0 and not _sp_hit:
		_sp_hit = true
		_go_up(false)
		humanoid.play("ape_slam", ActionSpecs.length("ape_slam"))
		_aoe(global_position, DROP_R, 34.0, false)
		Net.fx("dust_ring", [global_position, 40, 2.6])
		Net.fx("impact", [global_position + Vector3(0, 0.5, 0), Color(1.0, 0.5, 0.3)])
		Net.fx("sfx", ["thud", global_position, 8.0, 0.05, 0.4])
		get_node("/root/CombatManager").apply_camera_shake(0.55)
		_end_special(1.15)


## (it can't be struck mid-dive: the blow lands as it does)
func _hurt_off_for_dive() -> void:
	hurtbox.monitorable = false


## Knocked out of the tree: down it comes, stunned where it lands.
func _fall_update(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	global_position += velocity * delta
	if _sp_t > 0.2 and global_position.y <= _sp_target.y:
		global_position.y = _sp_target.y
		_go_up(false)
		Net.fx("dust_ring", [global_position, 30, 2.0])
		Net.fx("sfx", ["thud", global_position, 6.0, 0.05, 0.5])
		Net.fx("float_text", [global_position + Vector3(0, 4.0, 0), "Knocked down!", Color(1.0, 0.85, 0.4), 30])
		get_node("/root/CombatManager").apply_camera_shake(0.35)
		_special = ""
		_stagger(-_fwd(), FALL_STUN)


func _knock_out_of_tree() -> void:
	if _rock:
		_rock.queue_free()
		_rock = null
		Net.event(self, "rock", ["drop"])
	remove_meta("hurling")
	_special = "fall"
	_sp_t = 0.0
	_sp_target = _ground_at(global_position)
	velocity = _flat(arena.centre() - global_position).normalized() * 3.0
	_show(true)
	humanoid.hold("ape_air", 0.15)
	_shake(_perch, 1.0)
	Net.fx("sfx", ["roar", global_position, 4.0, 0.05, 1.15])


## Everyone left while it was up: down it comes, back to its post.
func _come_down() -> void:
	if not up:
		return
	_go_up(false)
	global_position = post + Vector3.UP * 0.3
	reset_physics_interpolation()


## A shockwave: every machine checks its own captain (jump it or dodge through).
## (1.20: only the slam knocks you down; the rest push, docs/v1_20_beasts.md 1. `stun`: the stagger, the grab's long)
func _aoe(center: Vector3, radius: float, dmg: float, knock: bool, stun: float = 0.4) -> void:
	dmg = _dmg(dmg)
	_aoe_local(center, radius, dmg, knock, stun)
	Net.event(self, "aoe", [center, radius, dmg, knock, stun])


func _aoe_local(center: Vector3, radius: float, dmg: float, knock: bool, stun: float = 0.4) -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me == null or not me.has_node("Hurtbox"):
		return
	var hb := me.get_node("Hurtbox") as Hurtbox
	if not hb.monitorable:
		return
	if _flat(me.global_position - center).length() > radius or me.global_position.y > center.y + 1.1:
		return
	var hd := HitData.new()
	hd.damage = dmg
	hd.knockdown = knock
	hd.unblockable = true
	hd.knockback_force = 12.0 if stun > 1.0 else 9.0
	hd.stagger_duration = stun
	hd.hitstop_duration = 0.07
	hd.camera_shake_intensity = 0.25
	hb.take_hit(hd, self)


# ==========================================================================
# The boulder
# ==========================================================================
func _grab_rock() -> void:
	if _rock:
		return
	_rock = MeshInstance3D.new()
	_rock.name = "Boulder"
	_rock.mesh = Props.rock_mesh(9911, 1.0, true)
	_rock.scale = Vector3.ONE * 0.95
	_rock.top_level = true
	add_child(_rock)
	if not up:
		Net.fx("dust", [global_position + _fwd() * 1.5, 10, 1.0])
	_rock_follow()


## Held between its fists.
func _rock_follow() -> void:
	if _rock == null:
		return
	var mid := (humanoid.hand_l.global_position + humanoid.hand_r.global_position) * 0.5
	_rock.global_position = mid + Vector3(0, 0.35, 0)


func _throw_rock(from: Vector3, to: Vector3, dur: float) -> void:
	if _rock == null:
		_grab_rock()
	_rocks.append([_rock, from, to, 0.0, dur])
	_rock = null


func _fly_rocks(delta: float) -> void:
	for r in _rocks.duplicate():
		var n: MeshInstance3D = r[0]
		r[3] = float(r[3]) + delta
		var u := clampf(float(r[3]) / float(r[4]), 0.0, 1.0)
		var from: Vector3 = r[1]
		var to: Vector3 = r[2]
		# (thrown down from the canopy it barely arcs)
		var arc := 0.22 if from.y - to.y < 5.0 else 0.06
		n.global_position = from.lerp(to, u) + Vector3.UP * sin(u * PI) * from.distance_to(to) * arc
		n.rotation += Vector3(4.0, 2.5, 0) * delta
		if u >= 1.0:
			FX.dust_ring(to, 22, 1.6)
			FX.dust(to + Vector3.UP * 0.5, 18, 1.4)
			FX.sfx("thud", to, 5.0, 0.05, 0.6)
			n.queue_free()
			_rocks.erase(r)


# ==========================================================================
# Getting hit
# ==========================================================================
func _on_hit(hit: HitData, attacker: Node) -> void:
	if state == S.DEAD:
		return
	_hit_by = attacker
	var dir := _flat(global_position - (attacker as Node3D).global_position).normalized() if attacker is Node3D else -_fwd()
	# far too big to throw down or juggle: the blow lands all the same (double while its poise is broken)
	var h := hit.duplicate() as HitData
	h.knockdown = false
	h.crumple = false
	h.launch = 0.0
	if vulnerable():
		h.damage *= VULN_K
	_take_damage(h, dir)
	_react(dir, h.damage)
	if state == S.DEAD:
		return
	if state == S.IDLE:
		alert()
		return
	if up:
		_tree_hits += h.damage
		if (_tree_hits >= health.max_health * KNOCK_DOWN or hit.haki) and _special in ["prowl", "tree_throw", "drop"] and not (_special == "drop" and _sp_t >= DROP_WARN):
			_knock_out_of_tree()
		return
	if attacker is Node3D and not hit.ranged:
		_part_hit(parts.near(BeastParts.blow_at(attacker, global_position)), h.damage, dir)
	if state == S.STAGGER or _special in ["climb", "fall"] or (_special == "leap" and _sp_t >= LEAP_WIND / _tempo()):
		return
	# Haki (or a guard-breaker) knocks it out of a slam's or a leap's wind-up
	if (_special == "slam" and _sp_t < SLAM_WIND / _tempo()) or (_special == "leap" and _sp_t < LEAP_WIND / _tempo()):
		if hit.haki or hit.breaker:
			_stagger(dir, 1.8)
			return
	# (blows while it's getting over a move - an opening - count double toward a break)
	var ph := hit.duplicate() as HitData
	if state == S.RECOVER and not _in_chain:
		ph.poise = Poise.of(hit) * 2.0
	if poise.take(ph) == Poise.BREAK:
		_poise_break(dir)


## A blow's shove on its body (BeastMotion), every screen.
func _react(dir: Vector3, dmg: float) -> void:
	var k := clampf(dmg / 30.0, 0.25, 1.5)
	motion.hit(facing.global_basis.inverse() * dir, k)
	Net.event(self, "react", [dir, k])


## A blow landed on part `n` ("" none): broken, it drops its material, changes its look and drains a lot of poise.
func _part_hit(n: String, dmg: float, dir: Vector3 = Vector3.ZERO) -> void:
	if not parts.hurt(n, dmg):
		return
	var at := parts.where(n)
	BeastFX.part_break(at, parts.color(n))
	Net.event(self, "part", [n, at])
	Net.fx("float_text", [at + Vector3.UP * 1.2, "%s broken!" % PART_NAMES[n], Color(1.0, 0.85, 0.4), 28])
	Net.kill_loot([[parts.item(n), 1.0 / Loot.PART_K, 1]], _ground_at(at) + Vector3.UP * 0.3)
	_apply_look()
	var ph := HitData.new()
	ph.damage = 0.0
	ph.poise = PART_POISE
	if poise.take(ph) == Poise.BREAK:
		_poise_break(dir if dir != Vector3.ZERO else -_fwd())
	elif _special == "" and state != S.STAGGER:
		_stagger(dir if dir != Vector3.ZERO else -_fwd(), 0.9)


## Its knuckles are in reach only while its fists are down in the ground: a slam's or a pound's blow and the
## opening after it.
func _fists_down() -> bool:
	return humanoid.current_action() in ["ape_slam", "ape_pound_l", "ape_pound_r"] or (state == S.RECOVER and _last_pick in ["slam", "pound"])


## Its poise ran out: the stagger pose (never off its feet), double damage for VULN_S.
func _poise_break(dir: Vector3) -> void:
	_vuln_until = Engine.get_physics_frames() + int(VULN_S * Engine.physics_ticks_per_second)
	_chain_left = 0
	_in_chain = false
	Net.fx("float_text", [global_position + Vector3(0, 4.2, 0), "Staggered!", Color(1.0, 0.9, 0.4), 32])
	_stagger(dir, REEL_S)


func _stagger(dir: Vector3, length: float) -> void:
	_special = ""
	_moment = false
	_drop_held()
	_stagger_len = length
	velocity = dir * 3.0
	humanoid.hold("ape_reel", 0.15)
	_stagger_fx()
	_set_state(S.STAGGER)


## Whatever a move left in its hands or half-done (cut off by a stagger or a phase change).
func _drop_held() -> void:
	hitbox.deactivate()
	if _rock:
		_rock.queue_free()
		_rock = null
		Net.event(self, "rock", ["drop"])
	remove_meta("slam_down")
	remove_meta("hurling")
	remove_meta("beating")
	_grab_caught = false


func _stagger_fx() -> void:
	Net.fx("sfx", ["roar", global_position, -2.0, 0.05, 1.2])
	Net.fx("sparkle", [global_position + Vector3(0, 3.4, 0), 14, Color(1.0, 0.95, 0.55)])


## A parried swipe staggers it, wide open.
func parried(by: Node) -> void:
	if Net.forward(self, "parried", [by]):
		return
	if _special != "swipe":
		return
	var dir := -_fwd()
	if by is Node3D:
		dir = _flat(global_position - (by as Node3D).global_position).normalized()
	_stagger(dir, 2.2)


## (bosses never go up in the air: a launcher's blow lands, it's its poise that pays)
func juggle(_up: float, _dir: Vector3) -> void:
	pass


func launched(_v: Vector3) -> void:
	pass


func _on_died() -> void:
	if state == S.DEAD:
		return
	_special = ""
	_set_peril(false)
	if up:
		_go_up(false)
	if _rock:
		_rock.queue_free()
		_rock = null
	_steam_off()
	super._on_died()
	Net.coins(global_position + Vector3(0, 1.5, 0), _coins(24))
	Net.award_xp(_xp(600), global_position + Vector3(0, 3.0, 0), INF)
	Net.bounty("boss", global_position, 70.0)


func _drop_weapon() -> void:
	pass


func _max_hp() -> float:
	return APE_HP * Levels.hp_k(level, _lv_ref())


## Its health and blows were tuned on the first chain island (its XP and coins are Brinehollow's sort).
func _lv_ref() -> int:
	return 6


## Everyone left (or fell): back to its post, healed, asleep, from the top.
func reset_fight() -> void:
	if state == S.DEAD:
		return
	_come_down()
	_special = ""
	_moment = false
	hitbox.deactivate()
	_set_peril(false)
	phase = 1
	poise = Poise.make("beast_boss")
	_vuln_until = -1
	_chain_left = 0
	_in_chain = false
	parts.restore()
	_cd["canopy"] = 0.0
	health.current_health = health.max_health
	humanoid.stop_action()
	_apply_look()
	_set_state(S.RETURN)


# ==========================================================================
# How it looks and moves (every screen)
# ==========================================================================
func _process(delta: float) -> void:
	super._process(delta)
	_post_pose(delta)


## On top of the rig's pose this frame (the Humanoid posed it already: PirateGrunt runs after it): the head tracks the
## nearest captain, breathing, a blow's shove, the mane and the necklace swinging.
func _post_pose(delta: float) -> void:
	if state in [S.DEAD, S.IDLE] or humanoid.ragdoll != null or not humanoid.visible:
		return
	var h := humanoid
	var act := h.current_action()
	motion.tick(delta, act == "ape_reel", clampf([0.2, 0.5, 0.85][phase - 1] + (0.3 if state == S.RECOVER else 0.0), 0.0, 1.0))
	var tgt := Net.nearest_player(global_position) as Node3D
	var w: float = LOOK_LOCK.get(act, 0.7) if tgt and in_combat() else 0.0
	motion.track(delta, h.neck.global_basis, h.head.global_position, tgt.global_position + Vector3.UP * 1.3 if tgt else Vector3.ZERO,
		w * (1.0 - motion.reel), 10.0 if w >= 1.0 else 4.0)
	var lk := motion.look
	var r := motion.react
	h.neck.rotation += Vector3(lk.y * 0.45, lk.x * 0.45, 0.0)
	h.head.rotation += Vector3(lk.y * 0.55 + r.x * 0.4, lk.x * 0.55, -lk.x * 0.08 + r.y * 0.3)
	h.torso.rotation += Vector3(r.x * 0.3 + motion.breath * 0.035, 0.0, r.y * 0.25)
	var mane := h.torso.get_node("Mane") as Node3D
	var ma: Vector2 = BeastMotion.swing(_mane_c, delta, h.torso.global_transform, 1.0)[0]
	mane.rotation = Vector3(clampf(ma.x * 0.6, -0.5, 0.5) - motion.breath * 0.04, 0.0, clampf(ma.y * 0.4, -0.4, 0.4))
	var na: Vector2 = BeastMotion.swing(_neck_c, delta, h.torso.global_transform, 1.5)[0]
	(h.torso.get_node("Necklace") as Node3D).rotation = Vector3(clampf(na.x, -0.6, 0.6), 0.0, clampf(na.y, -0.5, 0.5))


## Its look for its phase and broken parts: tusks snapped to stumps, knuckles split raw, eyes hotter each phase, the
## mane bristling, breath steaming from phase 2 and steam off its back in phase 3.
func _apply_look() -> void:
	var head := humanoid.head
	head.get_node("Tusks").visible = not parts.broken("tusks")
	head.get_node("TusksBroken").visible = parts.broken("tusks")
	for hand in [humanoid.hand_l, humanoid.hand_r]:
		(hand as Node3D).get_node("Knuckles").visible = not parts.broken("fists")
		(hand as Node3D).get_node("KnucklesBroken").visible = parts.broken("fists")
	var e: Array = EYES[phase - 1]
	(head.get_node("Eyes") as MeshInstance3D).material_override = PSXMat.glow(e[0], e[1])
	var bristle := 1.0 + 0.15 * float(phase - 1)
	(humanoid.torso.get_node("Mane") as Node3D).scale = Vector3(1.0, bristle, bristle)
	_steam_off()
	if phase >= 2 and state != S.DEAD:
		var breath := FX.flip_emitter(head, "mist", 3 * phase, 0.16, 0.9, {"direction": Vector3(0, -0.4, -1), "spread": 25.0,
			"vel_min": 0.25, "vel_max": 0.5, "radius": 0.02, "gravity": Vector3(0, 0.1, 0), "color": Color(1, 1, 1, 0.45), "fade": 0.5})
		breath.position = Vector3(0, -0.01, -0.2)
		_steam.append(breath)
	if phase >= 3 and state != S.DEAD:
		var back := FX.flip_emitter(humanoid.torso, "wisp", 8, 0.22, 1.5, {"direction": Vector3.UP, "vel_min": 0.15, "vel_max": 0.35,
			"radius": 0.16, "color": Color(1.0, 0.85, 0.8, 0.4), "fade": 0.5})
		back.position = Vector3(0, 0.55, 0.15)
		_steam.append(back)


func _steam_off() -> void:
	for s in _steam:
		if is_instance_valid(s):
			(s as Node).queue_free()
	_steam.clear()


# ==========================================================================
# Co-op extras
# ==========================================================================
func net_pack() -> Array:
	var a := super.net_pack()
	a.append(phase)
	a.append(up)
	a.append(humanoid.visible)
	a.append(parts.mask())
	return a


func _net_update(delta: float) -> void:
	super._net_update(delta)
	var smp := Net.sample(self)
	if smp.is_empty():
		return
	var a: Array = smp[0]
	var b: Array = smp[1]
	if b.size() >= 22 and int(b[21]) != phase:
		phase = int(b[21])
		phase_changed.emit(phase)
	if a.size() >= 24 and state != S.DEAD:
		up = bool(a[22])
		humanoid.visible = bool(a[23])
		hurtbox.monitorable = bool(a[23])
	if b.size() >= 25 and not parts.set_mask(int(b[24])).is_empty():
		_apply_look()


func net_event(what: String, args: Array) -> void:
	match what:
		"aoe":
			_aoe_local(args[0], float(args[1]), float(args[2]), bool(args[3]), float(args[4]) if args.size() > 4 else 0.4)
			return
		"grab":
			_grab_local(args[0])
			return
		"react":
			motion.hit(facing.global_basis.inverse() * (args[0] as Vector3), float(args[1]))
			return
		"moment":
			BeastFX.moment(args[0], 1.0, MOMENT_COL)
			return
		"part":
			BeastFX.part_break(args[1], parts.color(str(args[0])))
			return
		"leaves":
			BeastFX.leaves(args[0], int(args[1]), float(args[2]))
			return
		"rock":
			match str(args[0]):
				"grab":
					_grab_rock()
				"throw":
					_throw_rock(args[1], args[2], float(args[3]))
				"drop":
					if _rock:
						_rock.queue_free()
						_rock = null
			return
		"shake":
			arena.shake(int(args[0]), float(args[1]))
			return
		"say":
			BeastFX.sfx(str(args[0]), args[1], float(args[2]), float(args[3]), 90.0)
			return
		"rustle":
			BeastFX.leaves(args[0] + Vector3(0, 3.0, 0), 8, 2.0)
			BeastFX.sfx("leaves", args[0], -6.0, 1.1, 80.0)
			return
	super.net_event(what, args)
