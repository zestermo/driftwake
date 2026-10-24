extends "res://scripts/enemies/drowned.gd"
## A ghost (the fog isles, 1.20: docs/v1_20_plan.md): a dead pirate's shade, pale and glowing through the fog,
## the cold blue-white of the Wild Hunt. A spirit: shot and shell pass straight through it (no harm at all, a
## few sparks of cold light where it went), and it bleeds nothing. A blade, a fist or a power still find it.
## Cut down, it stays down (no rising: that's the drowned's), whole (nothing to sever from a shade). Glows the
## same on every screen (its body's look is all of it).

const GHOST := Color(0.55, 0.95, 1.0)
const BARK_GHOST_ALERT := ["...living...", "Whooo... are you...", "...cold... so cold...", "Stay... stay with us..."]
const BARK_GHOST_HURT := ["Hhhaaa!", "...ahh...", "Nnnhh!"]
## Fast (x its moves), fire burns it this much harder, and it fades out for a moment now and then.
const SPEED_K := 1.35
const FIRE_K := 2.0
const FADE_EVERY := Vector2(3.0, 6.0)
const FADE_LEN := 0.35

var _fade_t := 0.0
var _burn_t := 0.0
## What a lantern's glow does to it a second.
const LIGHT_DPS := 8.0
var _fade_rng := RandomNumberGenerator.new()


func setup(cfg: Dictionary) -> PirateGrunt:
	super.setup(cfg)
	_rose = true
	look["name"] = "Ghost"
	look["spirit"] = true
	_fade_rng.seed = hash(["ghost", int(cfg.get("seed", 1))])
	_fade_t = _fade_rng.randf_range(FADE_EVERY.x, FADE_EVERY.y)
	return self


func _ready() -> void:
	super._ready()
	_haunt(humanoid)


## The body glows the ghost's cold blue-white all over (one shared material: every ghost the same).
static func _haunt(n: Node) -> void:
	var m := PSXMat.lit("", Color(0.66, 0.84, 0.9), {"emission": Color(0.2, 0.45, 0.52), "emission_energy": 0.4, "affine": 0.4})
	for c in n.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).material_override = m
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A spirit: shot and shell pass through it; fire burns it the harder.
func _on_hit(hit: HitData, attacker: Node) -> void:
	if hit.ranged or hit.impact == "shot":
		Net.fx("sparkle", [global_position + Vector3.UP * 1.4, 6, GHOST])
		return
	if hit.dot:
		var h := hit.duplicate() as HitData
		h.damage *= FIRE_K
		super._on_hit(h, attacker)
		return
	super._on_hit(hit, attacker)


## A blow lands: cold light spills out of it, no blood.
func _take_damage(hit: HitData, dir: Vector3) -> void:
	Net.damage_number(hit.damage, global_position + Vector3(0, 1.9, 0))
	Net.fx("impact", [global_position + Vector3(0, 1.2, 0) - dir * 0.35, GHOST])
	Net.fx("sparkle", [global_position + Vector3(0, 1.2, 0) - dir * 0.2, clampi(int(hit.damage * 0.4), 6, 16), GHOST])
	CombatManager.impact(hit, global_position, -4.0, 0.1, 1.3)
	_hit_feedback(hit)
	set_meta("last_dir", dir)
	_last_hit = hit
	health.take_damage(hit.damage)


func _on_died() -> void:
	_last_hit = null
	super._on_died()


func bark(lines: Array, chance: float = 1.0) -> void:
	if lines == BARK_ALERT:
		lines = BARK_GHOST_ALERT
	elif lines == BARK_HURT:
		lines = BARK_GHOST_HURT
	super.bark(lines, chance)


## Quick on its feet.
func _move_tail(want: Vector3, accel: float, turn: float, running: bool, hv: Vector3, delta: float) -> void:
	super._move_tail(want * SPEED_K, accel * SPEED_K, turn, running, hv, delta)


## Now and then it fades out for a moment (every screen its own: only the look).
func _process(delta: float) -> void:
	super._process(delta)
	if humanoid == null or state == S.DEAD:
		if humanoid:
			humanoid.visible = true
		return
	# (the host's) caught in a lit lantern's glow it burns
	if not net_puppet and _away != Vector3.ZERO:
		_burn_t -= delta
		if _burn_t <= 0.0:
			_burn_t = 0.5
			Net.fx("sparkle", [global_position + Vector3.UP * 1.2, 8, Color(1.0, 0.8, 0.5)])
			health.take_damage(LIGHT_DPS * 0.5)
	_fade_t -= delta
	if _fade_t <= 0.0:
		_fade_t = _fade_rng.randf_range(FADE_EVERY.x, FADE_EVERY.y)
	humanoid.visible = _fade_t > FADE_LEN
