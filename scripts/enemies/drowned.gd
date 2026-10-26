extends PirateGrunt
## A drowned sailor (the fog isles, 1.20: docs/v1_20_plan.md): a pirate crewman the sea gave back. Grey-green and
## bloated, in rotten clothes, a blade still in his hand (their powder's long wet: no guns). The dead don't bleed
## and don't feel lead: a shot does a third of its damage and never knocks him down. Cut down once, he lies there a
## while and gets back up with some of his strength; the second time he stays down. The host decides it (the rising
## is an ordinary knock-down to every other screen).

## What a shot does to him (x its damage), and how much strength he gets back up with (x his most).
const SHOT_K := 0.3
const RISE_HP := 0.45
## How long he lies there before he rises.
const RISE_DOWN := 2.6
const BARK_RISE := ["Hhhhhh...", "...not... yet...", "Glk... glk...", "The sea... sends me back..."]
const BARK_DROWNED_ALERT := ["...warm one...", "Hhhh... join us...", "...come down... to the deep...", "Glk..."]
const BARK_DROWNED_HURT := ["Hhh!", "Glk!", "Nnngh..."]

var _rose := false
## The lit lanterns' glow they keep out of (FogPlaces): the way out of it, looked for every LIGHT_EVERY s.
const PLACES := preload("res://scripts/island/themes/fog_places.gd")
const LIGHT_EVERY := 0.25
var _away := Vector3.ZERO
var _light_t := 0.0


static func drowned_look(rng: RandomNumberGenerator) -> Dictionary:
	var lk := PirateGrunt.crew_look(rng)
	lk["name"] = "Drowned"
	lk["skin"] = [Color(0.5, 0.58, 0.52), Color(0.44, 0.52, 0.5), Color(0.56, 0.6, 0.54), Color(0.4, 0.46, 0.44)][rng.randi() % 4]
	lk["hair_color"] = [Color(0.18, 0.22, 0.18), Color(0.26, 0.3, 0.24), Color(0.4, 0.42, 0.38)][rng.randi() % 3]
	lk["top_color"] = [Color(0.42, 0.44, 0.4), Color(0.34, 0.36, 0.34), Color(0.5, 0.48, 0.42)][rng.randi() % 3]
	lk["legs_color"] = [Color(0.24, 0.26, 0.24), Color(0.3, 0.3, 0.28)][rng.randi() % 2]
	lk["vest_color"] = Color(0.26, 0.28, 0.26)
	lk["coat_color"] = Color(0.28, 0.3, 0.28)
	lk["hat_color"] = Color(0.22, 0.28, 0.22)
	lk["sash_color"] = Color(0.34, 0.24, 0.22)
	lk["scarf_color"] = Color(0.3, 0.34, 0.3)
	lk["marks"] = "age_lines"
	lk["bandolier"] = false
	return lk


func setup(cfg: Dictionary) -> PirateGrunt:
	super.setup(cfg)
	if role == "rifle":
		role = "sword"
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 1))
	var lk := drowned_look(rng)
	if cfg.has("look"):
		# (a captain or a chief keeps his own clothes, drowned)
		look = (cfg["look"] as Dictionary).duplicate()
		for k in ["skin", "hair_color", "marks"]:
			look[k] = lk[k]
	else:
		look = lk
	return self


## No guns: their powder's wet through.
func _guns_free() -> bool:
	return false


func _want_pistol(_p: Node3D, _dist: float, _delta: float) -> bool:
	return false


## Lead does little to the dead: a share of its damage, no knock-down, no throw.
func _on_hit(hit: HitData, attacker: Node) -> void:
	if hit.ranged or hit.impact == "shot":
		var h := hit.duplicate() as HitData
		h.damage *= SHOT_K
		h.knockdown = false
		h.crumple = false
		h.poise = Poise.of(h) * SHOT_K
		h.knockback_force *= 0.2
		super._on_hit(h, attacker)
		return
	super._on_hit(hit, attacker)


## A blow lands: no blood, a spatter of sea water and grey murk instead.
func _take_damage(hit: HitData, dir: Vector3) -> void:
	Net.damage_number(hit.damage, global_position + Vector3(0, 1.9, 0))
	Net.fx("impact", [global_position + Vector3(0, 1.2, 0) - dir * 0.35, Color(0.62, 0.78, 0.72)])
	Net.fx("splash", [global_position + Vector3(0, 1.15, 0) - dir * 0.2, clampi(int(hit.damage * 0.15), 2, 5), 0.4])
	CombatManager.impact(hit, global_position, -2.0, 0.1, 0.8)
	_hit_feedback(hit)
	set_meta("last_dir", dir)
	_last_hit = hit
	health.take_damage(hit.damage)


## The first time he's cut down he isn't done: he lies a while, then gets back up.
func _on_died() -> void:
	if state == S.DEAD:
		return
	if _rose or net_puppet:
		super._on_died()
		return
	_rose = true
	health.heal(health.max_health * RISE_HP)
	# (after the blow that did it has finished landing: it would set its own hit-stun over the fall)
	_rise.call_deferred()


func _rise() -> void:
	if state == S.DEAD:
		return
	var dir: Vector3 = get_meta("last_dir", -_fwd())
	if humanoid.ragdoll == null:
		_knock_down(dir * 4.0 + Vector3.UP * 2.5)
	else:
		# (cut down on the ground: he stays there, longer)
		hitbox.deactivate()
		_release_token()
		_rest = 0.0
		_set_state(S.DOWN)
	_down_min = RISE_DOWN
	bark(BARK_RISE, 0.8)


## Has he got back up once already (tests).
func risen() -> bool:
	return _rose


func bark(lines: Array, chance: float = 1.0) -> void:
	if lines == BARK_ALERT:
		lines = BARK_DROWNED_ALERT
	elif lines == BARK_HURT:
		lines = BARK_DROWNED_HURT
	super.bark(lines, chance)


## The dead keep out of a lit lantern's glow: caught in one, they make straight for its edge.
func _move_tail(want: Vector3, accel: float, turn: float, running: bool, hv: Vector3, delta: float) -> void:
	_light_t -= delta
	if _light_t <= 0.0:
		_light_t = LIGHT_EVERY
		_away = PLACES.away_from_light(get_tree(), global_position)
	if _away != Vector3.ZERO:
		want = _away * RUN_SPEED
	super._move_tail(want, accel, turn, running, hv, delta)
