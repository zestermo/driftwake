extends "res://scripts/enemies/beasts/alpha_boar.gd"
## The roaming beast (BeastPool "behemoth", one per island): a moss-backed grazer
## the size of a hut, thorny plates down its spine and two horns forward. It
## wanders the island's floor from one place to the next (sites, its range's
## middle) and can be met anywhere; come close or strike it and it turns on you:
## the boar's charge, horn toss and stomp, slower and far heavier, a bellow
## before each. Leave it be (or get far enough away) and it goes back to grazing.

var waypoints: Array = []
var _wp: int = 0
var _graze_t: float = 0.0
var _stuck: float = 0.0


func _init() -> void:
	boss_name = "The Thornback"
	wake_r = 18.0
	leash_r = 46.0
	charge_len = 18.0
	charge_speed = 14.0
	gore_r = 4.2
	stomp_r = 6.0


## (1.20: rebuilt on the quadruped rig, docs/v1_20_beasts.md 5: low and wide on short pillar legs, the head carried
## low with its horns forward, armour plates down the back each with a thorn, a pale soft belly, a club on its tail)
func _spec() -> Dictionary:
	return {"hip_h": 1.95, "front_h": 1.8, "len": 3.6, "chest_r": 1.4, "hip_r": 1.35, "neck": Vector3(0, -0.25, -0.65), "head": Vector3(0.8, 0.62, 0.95),
		"snout": 0.6, "tail": 2.2, "tail_r": 0.3, "coat": Color(0.42, 0.42, 0.35), "under": Color(0.72, 0.66, 0.54), "mark": Color(0.24, 0.34, 0.16),
		"tex": "leather", "ears": 0.25, "eye": Color(1.0, 0.6, 0.2), "leg_k": 1.6, "front_k": 1.1, "foot": "pad", "bend": 0.6, "gait": "lumber"}


## Horns forward (two sweeping and one on the nose), a bony brow; armour plates overlapping down the back and flanks,
## each with a thorn, moss between them; a spiked club at the tail's end.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var cr: float = spec["chest_r"]
	var hr: float = spec["hip_r"]
	var ln: float = spec["len"]
	var lift: float = float(spec["front_h"]) - float(spec["hip_h"])
	var rng := _rng_fixed()
	var horn := PSXMat.flat(Color(0.82, 0.76, 0.62))
	var plate := PSXMat.lit("rock", Color(0.8, 0.82, 0.7))
	for s in [-1.0, 1.0]:
		var h0 := Vector3(s * hd.x * 0.55, hd.y * 0.45, -hd.z * 0.4)
		mb("Head").add_tube(horn, PackedVector3Array([h0, h0 + Vector3(s * 0.5, 0.2, -0.5), h0 + Vector3(s * 0.4, 0.55, -1.3)]), 0.22, 0.02, 6, 1.0)
	mb("Head").add_cylinder(horn, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, hd.y * 0.2, -hd.z * 1.4)), 0.2, 0.0, 0.8, 5, 1.0)
	mb("Head").add_blob(plate, Transform3D(Basis(), Vector3(0, hd.y * 0.55, -hd.z * 0.2)), Vector3(hd.x * 0.9, hd.y * 0.3, hd.z * 0.6), rng, 0.15, 3, 6, 1.0)
	# the plates: three rows down the back (the middle over the spine, two lower on the flanks), each with a thorn
	for row in [0.0, -1.0, 1.0]:
		for k in range(7):
			var f := float(k) / 6.0
			var z: float = lerpf(-ln * 0.55, ln * 0.5, f)
			var w: float = lerpf(cr, hr, f)
			var top: float = lerpf(lift + cr * 0.95, hr * 0.95, f)
			var at := Vector3(row * w * 0.62, top - absf(row) * w * 0.3, z)
			var tilt := Basis(Vector3.FORWARD, -row * 0.6) * Basis(Vector3.RIGHT, 0.2)
			mb("Body").add_blob(plate, Transform3D(tilt, at), Vector3(w * 0.42, 0.16, ln * 0.09), rng, 0.15, 3, 6, 1.0)
			var spike: float = (0.75 if row == 0.0 else 0.45) * (1.0 - absf(f - 0.4) * 0.6)
			mb("Body").add_cylinder(horn, Transform3D(tilt * Basis(Vector3.RIGHT, 0.3), at + tilt * Vector3(0, 0.1, 0)), 0.18, 0.0, spike, 4, 1.0, Color(0.9, 0.9, 0.85))
			if row == 0.0 and k < 6:
				mb("Body").add_blob(spec["coat_mat"], Transform3D(Basis(), at + Vector3(0.3, -0.08, ln * 0.07)), Vector3(0.3, 0.15, 0.25), rng, 0.3, 3, 5, 1.0, Color(0.6, 0.9, 0.5))
	# the tail's club: a knot of plate with spikes
	var tl: float = float(spec["tail"]) / 4.0
	mb("Tail3").add_blob(plate, Transform3D(Basis(), Vector3(0, 0, tl * 0.9)), Vector3(0.55, 0.42, 0.6), rng, 0.2, 3, 6, 1.0)
	for k in range(5):
		var a := TAU * k / 5.0
		mb("Tail3").add_cylinder(horn, Transform3D(Basis(Vector3.BACK, a) * Basis(Vector3.RIGHT, 0.0), Vector3(0, 0, tl * 0.9) + Vector3(cos(a), sin(a), 0) * 0.35), 0.1, 0.0, 0.4, 4, 1.0)


func _coat_at(p: Vector3) -> Color:
	var base := (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.6, p.y / maxf(float(spec["chest_r"]), 0.1)))
	var moss := smoothstep(0.55, 0.85, sin(p.x * 3.0 + p.z * 1.7) * 0.5 + 0.5) * smoothstep(0.3, 0.8, p.y / maxf(float(spec["chest_r"]), 0.1))
	return base.lerp(spec["mark"], moss)


func _hp_base() -> float:
	return 1800.0


func _poise_max() -> float:
	return 300.0


func _xp_base() -> int:
	return 500


func _coins_base() -> int:
	return 30


func _speed() -> float:
	return 4.4


func _charge_dmg() -> float:
	return 30.0


func _gore_dmg() -> float:
	return 22.0


func _stomp_dmg() -> float:
	return 24.0



func _on_begin(m: String) -> void:
	super._on_begin(m)
	say("bellow", global_position, 6.0, 1.0 if m != "charge" else 0.9, 110.0)


func trophy(_t: int) -> ItemData:
	return null


## Grazing its way round the island: walk to a waypoint, browse a while, on to the next (unless its temper has it
## warning someone off, bolting or stalking: below).
func _idle(delta: float) -> Vector3:
	match _temper():
		"territorial":
			if _territorial(delta):
				return Vector3.ZERO
		"skittish":
			var v := _skittish(delta)
			if v != Vector3.INF:
				return v
		"stalker":
			var v := _stalker(delta)
			if v != Vector3.INF:
				return v
	if waypoints.is_empty():
		return super._idle(delta)
	if _graze_t > 0.0:
		_graze_t -= delta
		return Vector3.ZERO
	var goal: Vector3 = waypoints[_wp]
	var to := _flat(goal - global_position)
	if to.length() < 3.0:
		_wp = (_wp + 1 + _rng.randi() % maxi(waypoints.size() - 1, 1)) % waypoints.size()
		_graze_t = _rng.randf_range(6.0, 14.0)
		return Vector3.ZERO
	var nd := _nav_dir(goal, delta)
	_face(nd)
	# (walked into a trunk off the navmesh: on to another place)
	_stuck = _stuck + delta if _flat(get_real_velocity()).length() < 0.4 else 0.0
	if _stuck > 2.5:
		_stuck = 0.0
		_wp = (_wp + 1) % waypoints.size()
	# (where it settles after a fight is wherever it was grazing)
	post = global_position
	post_yaw = _yaw
	return nd * 1.6


func _pose_for(delta: float) -> void:
	super._pose_for(delta)
	if state == S.SLEEP:
		match mood:
			Mood.POSTURE:
				# (reared half up, head low and swinging, pawing the ground, jaw open)
				pose = {"rear": 0.35 + absf(sin(_tw * 5.0)) * 0.3, "head": -0.5 + sin(_tw * 2.5) * 0.15, "jaw": 0.8}
			Mood.BOLT:
				pose = {"head": 0.25, "stretch": 0.45, "tail": 1.0}
			Mood.STALK:
				pose = {"crouch": 0.45, "head": -0.3}
			_:
				pose = {"head": -0.6 if _graze_t > 0.0 else -0.15}


# 1.20's moves (docs/v1_20_beasts.md 5), as a table (alpha_boar.gd): its one knockdown the charge; after the wallow
# it lies on its back a moment, its belly soft (hits there double).
func _table() -> Dictionary:
	return {
		"wallow": {"phase": 2, "max": 4.5, "cd": [9.0, 12.0], "tell": 0.7, "shape": "ring", "r": 4.0, "dmg": 22.0, "kb": 10.0, "rec": 1.4, "fx": "quake",
			"pose": [{"crouch": 0.8, "head": -0.3}, {"crouch": 1.0, "rear": -0.25}, {"crouch": 1.0, "head": -0.5}]},
		"thorns": {"max": 5.0, "cd": [6.0, 8.0], "tell": 0.6, "shape": "ring", "r": 5.0, "dmg": 18.0, "kb": 9.0, "rec": 1.0, "fx": "sparkle",
			"col": Color(0.9, 0.85, 0.6), "say": ["bellow", 1.1], "pose": [{"crouch": 0.35, "head": -0.2}, {"rear": 0.2, "head": 0.2}, {"crouch": 0.2}]},
		"club": {"max": 5.0, "cd": [4.0, 6.0], "tell": 0.5, "shape": "behind", "r": 5.2, "deg": 120.0, "dmg": 18.0, "kb": 10.0, "rec": 0.8,
			"pose": [{"tail": 1.0, "crouch": 0.2}, {"tail": 0.0, "rear": 0.1}, {}]},
		"gore": {"max": 4.6, "cd": [1.8, 2.6], "tell": 0.5, "shape": "cone", "r": 4.4, "deg": 60.0, "dmg": 20.0, "kb": 8.0, "parry": true, "rec": 0.8,
			"pose": [{"head": -0.5, "crouch": 0.2}, {"head": 0.55}, {"head": -0.2}]},
		"charge": {"min": 6.0, "max": 20.0, "cd": [6.0, 8.0], "tell": 0.9, "shape": "charge", "len": 18.0, "w": 1.8, "speed": 14.0, "dmg": 30.0, "knock": true,
			"rec": 1.6, "say": ["bellow", 0.9], "pose": [{"crouch": 0.3, "head": -0.35}, {"head": -0.3, "stretch": 0.5}, {"crouch": 0.4, "head": -0.4}]},
	}


func _wake_move() -> String:
	return "thorns"


func _on_hit(hit: HitData, attacker: Node) -> void:
	if move == "" and mv_t < 0.0 and _last_move == "wallow" and not hit.dot:
		hit.damage *= 2.0
	mood = Mood.GRAZE
	super._on_hit(hit, attacker)


func _process(delta: float) -> void:
	super._process(delta)
	_hear_it(delta)


# ==========================================================================
# 1.23: how it meets you (docs/v1_23_previews.md section 6 "Roamers"), by its _temper():
#   territorial  (the Thornback, the Rimeback) whoever comes within wake_r gets a warning: it rears, paws and roars
#                for WARN_S over a ring of its ground; back off out of it and it settles, stay (or come right up, or
#                strike it) and it comes for you
#   skittish     (the Dune Strider) it bolts from whoever comes within wake_r and grazes on further off; struck or
#                cornered it fights
#   stalker      (the Wild Hunt) it shadows a captain from STALK_R at their back, quiet, and when it has had their back
#                for STALK_S it charges in (turn to face it and it holds off)
# And it's an event you hear first: a captain coming within HEAR_R hears it roar across the island and sees the birds
# go up over it (each screen its own, once a roamer).
# ==========================================================================
const WARN_S := 2.0
const BOLT_S := 3.2
const BOLT_SPEED := 11.0
const STALK_SEE := 45.0
const STALK_R := 15.0
const STALK_S := 2.5
const HEAR_R := 95.0
enum Mood { GRAZE, POSTURE, BOLT, STALK }
var mood := Mood.GRAZE
var _mood_t := 0.0
var _mood_of: Node3D
var _heard := false
var _hear_t := 0.0
var _dust_t := 0.0


func _temper() -> String:
	return "territorial"


## (in the fight its leash still holds; out of it its temper says when it wakes)
func _watch(delta: float) -> void:
	if state != S.SLEEP:
		super._watch(delta)


## The nearest standing captain within `r`, else null.
func _captain_within(r: float) -> Node3D:
	var best: Node3D = null
	for p in Net.all_players():
		var pp := p as Node3D
		if pp.global_position.distance_to(global_position) < r and p.has_method("is_standing") and p.is_standing() \
				and (best == null or pp.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = pp
	return best


func _set_mood(m: Mood) -> void:
	mood = m
	_mood_t = 0.0


func _territorial(delta: float) -> bool:
	var p := _captain_within(wake_r)
	if mood != Mood.POSTURE:
		if p == null:
			return false
		_set_mood(Mood.POSTURE)
		_mood_of = p
		warn_ring(global_position, wake_r, WARN_S, Color(1.0, 0.55, 0.12))
		say("bellow", global_position, 8.0, 0.8, 140.0)
	_mood_t += delta
	if is_instance_valid(_mood_of):
		_face(_flat(_mood_of.global_position - global_position))
		# (right up to it: no more warning)
		if _flat(_mood_of.global_position - global_position).length() < wake_r * 0.4:
			_set_mood(Mood.GRAZE)
			alert()
			return true
	if _mood_t >= WARN_S:
		_set_mood(Mood.GRAZE)
		if _captain_within(wake_r + 1.0):
			alert()
		else:
			say("snarl", global_position, -2.0, 0.6)
	return true


func _skittish(delta: float) -> Vector3:
	if mood != Mood.BOLT:
		var p := _captain_within(wake_r)
		if p == null:
			return Vector3.INF
		_set_mood(Mood.BOLT)
		_mood_of = p
		say("bellow", global_position, 4.0, 1.25, 120.0)
	_mood_t += delta
	if _mood_t > BOLT_S or not is_instance_valid(_mood_of):
		_set_mood(Mood.GRAZE)
		_graze_t = _rng.randf_range(4.0, 8.0)
		post = global_position
		return Vector3.ZERO
	var away := _flat(global_position - _mood_of.global_position).normalized()
	var nd := _nav_dir(global_position + away * 20.0, delta)
	_face(nd)
	_dust_t -= delta
	if _dust_t <= 0.0:
		_dust_t = 0.3
		Net.fx("dust", [global_position, 4, 1.0])
	# (cornered: it turns and fights)
	if _mood_t > 1.0 and _flat(get_real_velocity()).length() < 1.0:
		_set_mood(Mood.GRAZE)
		alert()
		return Vector3.ZERO
	return nd * BOLT_SPEED


func _stalker(delta: float) -> Vector3:
	var p := _captain_within(STALK_SEE)
	if p == null:
		if mood == Mood.STALK:
			_set_mood(Mood.GRAZE)
		return Vector3.INF
	if mood != Mood.STALK:
		_set_mood(Mood.STALK)
		_mood_of = p
	var to := _flat(p.global_position - global_position)
	var faces := Vector3.FORWARD
	var pm = p.get("player_model")
	if pm is Node3D:
		faces = _flat((pm as Node3D).global_basis.z).normalized()
	# its back to us: the ambush builds; facing us: it holds off, out at the edge
	if faces.dot(-to.normalized()) < 0.2:
		_mood_t += delta
	else:
		_mood_t = maxf(_mood_t - delta * 2.0, 0.0)
	_face(to)
	if _mood_t >= STALK_S:
		_set_mood(Mood.GRAZE)
		alert()
		end_move()
		begin("charge")
		return Vector3.ZERO
	var spot := p.global_position - faces * STALK_R
	return Vector3.ZERO if _flat(spot - global_position).length() < 2.0 else _nav_dir(spot, delta) * 3.4


## The roamer heard before it's seen: its roar across the island, birds put up over it (this screen, once).
func _hear_it(delta: float) -> void:
	_hear_t -= delta
	if _heard or _hear_t > 0.0 or state == S.DEAD:
		return
	_hear_t = 1.0
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me and me.global_position.distance_to(global_position) < HEAR_R:
		_heard = true
		BeastFX.sfx("bellow", global_position, 14.0, 0.7, 260.0)
		BeastFX.birds(global_position, 16)
		if me.has_method("_toast"):
			me.call("_toast", "Something huge roars, out across the island")


func _pack_extra() -> Array:
	return [int(mood)]


func _unpack_extra(a: Array, _b: Array, _f: float) -> void:
	if a.size() > 0:
		mood = int(a[0]) as Mood
