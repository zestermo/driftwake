class_name FishFight
extends RefCounted
## A legendary on the line (1.28, docs/life_systems_plan.md "One legendary per theme"): instead of the plain reel,
## the line's tension (0-1) and the distance to the fish (DIST m to 0). Holding reel (F or the mouse) winds it in
## but builds tension, fast while the fish runs (a surge), slow while it rests; letting go eases the tension and the
## fish takes line back while it runs. Tension 1 snaps the line; slack (tension 0) for SLACK_LOSE s throws the hook;
## distance 0 lands it. `pull` is the fish's (FishTable.LEGEND_PULL). Logic only: FishState runs it, FishFightHud draws it.

const DIST := 16.0
const REEL_MPS := 2.2
const TENSE_RUN := 0.45
const TENSE_REST := 0.12
const EASE := 0.6
const TAKE_MPS := 1.2
const RUN_SECS := Vector2(1.2, 2.4)
const REST_SECS := Vector2(0.8, 1.8)
const SLACK_LOSE := 2.5
## Where it starts: a little tension, the fish resting.
const START_TENSION := 0.3

var pull := 1.0
var tension := START_TENSION
var dist := DIST
var running := false
## "" fighting, "landed", "snapped", "thrown".
var result := ""
var _phase_left := 0.0
var _slack := 0.0
var _rng := RandomNumberGenerator.new()


func _init(pull_ := 1.0, seed_ := 0) -> void:
	pull = pull_
	_rng.seed = seed_
	_phase_left = _rng.randf_range(REST_SECS.x, REST_SECS.y)


## One step: `reeling` while the reel button is held.
func tick(delta: float, reeling: bool) -> void:
	if result != "":
		return
	_phase_left -= delta
	if _phase_left <= 0.0:
		running = not running
		var r := RUN_SECS if running else REST_SECS
		_phase_left = _rng.randf_range(r.x, r.y)
	if reeling:
		dist -= REEL_MPS * delta
		tension += (TENSE_RUN * pull if running else TENSE_REST) * delta
	else:
		tension -= EASE * delta
		if running:
			dist += TAKE_MPS * pull * delta
	dist = clampf(dist, 0.0, DIST)
	tension = clampf(tension, 0.0, 1.0)
	_slack = _slack + delta if tension <= 0.0 else 0.0
	if tension >= 1.0:
		result = "snapped"
	elif _slack >= SLACK_LOSE:
		result = "thrown"
	elif dist <= 0.0:
		result = "landed"


## How far in it is, 0 (just hooked) to 1 (at the rod).
func progress() -> float:
	return 1.0 - dist / DIST
