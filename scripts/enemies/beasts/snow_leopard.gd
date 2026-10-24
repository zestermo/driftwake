extends "res://scripts/enemies/beasts/stalker.gd"
## The White Shade (BeastPool "snow_leopard", a snow island's boss): the stalker's
## hunt in a snow leopard's coat - smoke-white with dark open rosettes, a heavy tail -
## that vanishes into the snow-laden firs round its run. Looks: white, smoke, pale gold.

const SNOW_COATS := [
	[Color(0.88, 0.88, 0.86), Color(0.97, 0.97, 0.96), Color(0.22, 0.22, 0.24)],
	[Color(0.62, 0.63, 0.66), Color(0.86, 0.86, 0.86), Color(0.16, 0.16, 0.18)],
	[Color(0.86, 0.8, 0.66), Color(0.96, 0.94, 0.88), Color(0.3, 0.24, 0.18)],
]


func _init() -> void:
	boss_name = "The White Shade"


func _spec() -> Dictionary:
	var c: Array = SNOW_COATS[variant % SNOW_COATS.size()]
	return {"hip_h": 1.3, "len": 2.0, "chest_r": 0.64, "hip_r": 0.54, "neck": Vector3(0, 0.3, -0.55), "head": Vector3(0.4, 0.33, 0.4),
		"snout": 0.26, "tail": 2.6, "tail_r": 0.2, "coat": c[0], "under": c[1], "mark": c[2], "tex": "fur_white", "ears": 0.35,
		"eye": Color(0.6, 0.95, 1.0)}


## Open rosettes, larger and sparser than a jungle cat's.
func _coat_at(p: Vector3) -> Color:
	var base := (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.6, p.y / maxf(float(spec["chest_r"]), 0.1)))
	var q := p * 3.6
	var ring := absf(sin(q.x * 1.3 + sin(q.z * 0.9) * 1.7) * sin(q.z * 1.1 + q.y * 0.8 + sin(q.x * 0.7)))
	var rim := smoothstep(0.66, 0.8, ring) * (1.0 - smoothstep(0.84, 0.95, ring))
	return base.lerp(spec["mark"], rim * 0.85)


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": spec["coat"]}, "White Shade Pelt", t)


# ==========================================================================
# 1.20's moves (docs/v1_20_beasts.md 6), with the stalker's claws and pounce
#   dive      burrows into the snow: a bump runs under it at you (1.2 s), bursts up under you (push); 1.2 s shaking off
#   leap      from afar, up high and a long way: lands on your spot (push; the pounce is its knockdown); 1.2 s
#   whiteout  (phase 2+) a roar and a burst of snow: gone for a moment, then a pounce from behind you
# ==========================================================================
const SNOW := Color(0.92, 0.96, 1.0)
const LEAP_AIR := 0.9


func _kind_moves(dist: float) -> Array:
	var out: Array = []
	if phase >= 2 and dist < 14.0:
		out.append("whiteout")
	if dist > 5.0 and dist < 14.0:
		out.append("dive")
	if dist > 9.0 and dist < 18.0:
		out.append("leap")
	return out


func _ready() -> void:
	super._ready()
	_cd.merge({"dive": 2.0, "leap": 4.0, "whiteout": 99.0}, true)
	# (no brush to stalk in on the snow: its own ways in instead)
	_cd["stalk"] = INF


func _on_phase(k: int) -> void:
	super._on_phase(k)
	_cd["stalk"] = INF
	if k >= 2:
		_cd["whiteout"] = 0.0


func _on_begin(m: String) -> void:
	var p := _target()
	match m:
		"dive":
			_n = 0
			_cd["dive"] = _rng.randf_range(6.0, 8.0)
			_hide(true)
			_fly = true
			Net.fx("sparkle", [global_position + Vector3.UP * 0.5, 20, SNOW])
			say("snarl", global_position, 0.0, 0.9)
		"leap":
			_n = 0
			_cd["leap"] = _rng.randf_range(7.0, 9.0)
			_from = global_position
			_to = ground_at(p.global_position if p else global_position + _fwd() * 10.0)
			_face(_flat(_to - _from))
			warn_ring(_to, POUNCE_R, 0.5 + LEAP_AIR)
			say("snarl", global_position, 4.0, 1.0)
		"whiteout":
			_n = 0
			_cd["whiteout"] = _rng.randf_range(11.0, 14.0)
			say("catroar", global_position, 5.0, 1.1)
			Net.fx("sparkle", [global_position + Vector3.UP * 1.0, 60, SNOW])
			Net.fx("dust_ring", [global_position, 30, 2.4])
		_:
			super._on_begin(m)


func _move_tick(delta: float, p: Node3D) -> Vector3:
	match move:
		"dive":
			if p == null:
				end_move(0.4)
				return Vector3.ZERO
			if mv_t < 1.2:
				# (under the snow: a bump moving at you)
				var to := _flat(p.global_position - global_position)
				global_position = global_position.move_toward(ground_at(global_position + to), delta * 9.0)
				_fx_t -= delta
				if _fx_t <= 0.0:
					_fx_t = 0.15
					Net.fx("dust", [global_position, 4, 0.7])
				if mv_t > 0.8 and _n == 0:
					_n = 1
					warn_ring(global_position, 2.6, 0.4, SNOW)
				return Vector3.ZERO
			if not _hit:
				_hit = true
				_fly = false
				_hide(false)
				strike("ring", [global_position, 2.6], 18.0, false, false, 1.1, 9.0)
				Net.fx("sparkle", [global_position + Vector3.UP * 0.8, 30, SNOW])
				quake(global_position, 0.4)
			if mv_t > 1.5:
				end_move(1.2)
			return Vector3.ZERO
		"leap":
			if mv_t < 0.5:
				return Vector3.ZERO
			var u := clampf((mv_t - 0.5) / LEAP_AIR, 0.0, 1.0)
			if u < 1.0:
				_fly = true
				var flat := _from.lerp(_to, u)
				global_position = Vector3(flat.x, lerpf(_from.y, _to.y, u) + sin(u * PI) * 5.0, flat.z)
				return Vector3.ZERO
			if not _hit:
				_hit = true
				_fly = false
				strike("ring", [_to, POUNCE_R], 20.0, false, false, 1.1, 9.0)
				quake(_to, 0.5)
				Net.fx("sparkle", [_to + Vector3.UP * 0.5, 18, SNOW])
			if mv_t > 0.5 + LEAP_AIR + 0.3:
				end_move(1.2)
			return Vector3.ZERO
		"whiteout":
			if p == null:
				end_move(0.4)
				return Vector3.ZERO
			if _n == 0 and mv_t > 0.5:
				_n = 1
				_hide(true)
				_fly = true
			if _n == 1 and mv_t > 1.6:
				# (behind you: on the far side from where it went)
				_n = 2
				var away := _flat(p.global_position - global_position).normalized()
				global_position = ground_at(p.global_position + away * 6.0)
				reset_physics_interpolation()
				_fly = false
				_hide(false)
				move = "pounce"
				mv_t = 0.0
				_n = 0
				_hit = false
				_pounce_at(p.global_position)
			return Vector3.ZERO
	return super._move_tick(delta, p)


func _pose_for(delta: float) -> void:
	super._pose_for(delta)
	if state != S.FIGHT:
		return
	match move:
		"dive":
			pose = {"crouch": 1.0, "head": -0.3}
		"leap":
			pose = {"crouch": 0.9, "tail": 1.0} if mv_t < 0.5 else {"stretch": 1.0, "rear": 0.2, "jaw": 1.0}
		"whiteout":
			pose = {"rear": 0.5, "head": 0.45, "jaw": 1.0, "tail": 1.0}
