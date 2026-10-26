class_name Poise
extends RefCounted
## Poise (1.23, docs/v1_23_previews.md section 3): hidden, the stagger shows it. Hits drain it (Poise.of: what a blow
## is worth), it refills REFILL_WAIT s after the last hit, and when it runs out the foe goes down (or reels hard) and
## is then immune IMMUNE s, full again. Knockdown moves no longer floor anyone on their own: they drain a lot.
## Game time only (physics ticks), worked out when a hit lands: nothing runs per frame.
## Beasts and other enemies can keep one too: Poise.make("miniboss") (or new(...)), take(hit) on every hit.

enum {NONE, FLINCH, BREAK}

const REFILL_WAIT := 2.0
const IMMUNE := 4.0
## Per class: [poise, refill a second, flinches at damage >=, flinches at poise damage >=].
const CLASSES := {
	"grunt": [30.0, 12.0, 10.0, 14.0],
	"elite": [55.0, 15.0, INF, 25.0],
	"captain": [90.0, 18.0, INF, 14.0],
	"rival": [80.0, 20.0, 0.0, 0.0],
	"miniboss": [160.0, 25.0, INF, 25.0],
}
## What a blow is worth (Player.melee_hit sets them on the captain's hits; techniques scale with their damage).
const LIGHT := 6.0
const FINISHER := 14.0
const HEAVY := 25.0
## A kick move, and the floor for anything that used to knock down (HitData.knockdown).
const KICK := 30.0
const TECH_MIN := 35.0
const TECH_MAX := 60.0
const ULT := 120.0
const SHOT := 4.0
const SHOT_CLOSE := 12.0
## A shot from this close is point-blank.
const CLOSE_M := 3.0

var full := 30.0
var refill := 12.0
var flinch_damage := 10.0
var flinch_poise := 14.0
var value := 30.0
var _last := -1000000
var _immune_until := -1


static func make(kind: String, scale: float = 1.0) -> Poise:
	var c: Array = CLASSES[kind]
	var p := Poise.new()
	p.full = float(c[0]) * scale
	p.value = p.full
	p.refill = float(c[1])
	p.flinch_damage = float(c[2])
	p.flinch_poise = float(c[3])
	return p


## A blow's poise damage: its own (HitData.poise), else by what it is; anything that used to knock down drains a kick's.
static func of(hit: HitData) -> float:
	if hit.dot:
		return 0.0
	var v := hit.poise if hit.poise >= 0.0 else (SHOT if hit.ranged else LIGHT)
	if hit.knockdown:
		v = maxf(v, KICK)
	return v


static func _now() -> int:
	return Engine.get_physics_frames()


static func _ticks(secs: float) -> int:
	return int(round(secs * Engine.physics_ticks_per_second))


## Poise now (refilled since the last hit).
func current() -> float:
	var since := float(_now() - _last) / float(Engine.physics_ticks_per_second) - REFILL_WAIT
	return minf(full, value + maxf(since, 0.0) * refill)


func immune() -> bool:
	return _now() < _immune_until


## A hit lands: BREAK (it ran out: down it goes, then immune), FLINCH (it reels) or NONE (it shrugs it off).
func take(hit: HitData) -> int:
	var dmg := Poise.of(hit)
	if dmg <= 0.0:
		return NONE
	if immune():
		return FLINCH if flinches(hit, dmg) else NONE
	value = current() - dmg
	_last = _now()
	if value <= 0.0:
		broke()
		return BREAK
	return FLINCH if flinches(hit, dmg) else NONE


## Broken (a hit, a launch landed): full again and immune for IMMUNE s.
func broke() -> void:
	value = full
	_last = -1000000
	_immune_until = _now() + _ticks(IMMUNE)


func flinches(hit: HitData, dmg: float) -> bool:
	return hit.damage >= flinch_damage or dmg >= flinch_poise or hit.breaker
