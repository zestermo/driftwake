class_name CookTiming
extends RefCounted
## The cooking game's logic alone (1.28, docs/life_systems_plan.md "The timing game"): three beats, each
## scored 0-1 by how close a press lands to its mark. Stir (3 presses as the spoon passes the mark), Flip
## (the heat rises then falls; press in the gold band), Plate (the plate sweeps back and forth; press when
## it's centred). Quality is the beats' mean; the grade sets the meal's strength (MULT). CookGameScreen
## draws it (first person, CookScene); the restaurant's cook-off reuses it with opts.

const BEATS := ["stir", "flip", "plate"]
## Burnt, Fair, Good, Perfect: the meal's buff and minutes x this.
const MULT := [0.8, 1.0, 1.15, 1.3]
const GRADE_NAMES := ["Burnt", "Fair", "Good", "Perfect"]
const GRADE_FROM := [0.0, 0.35, 0.65, 0.88]

## Stir: turns a second; full marks within FULL degrees of the mark, nothing past ZERO.
const STIR_TURNS := 1.1
const STIR_PRESSES := 3
const STIR_FULL := 12.0
const STIR_ZERO := 60.0
## Where the mark sits on the rim (radians, from the spoon's start), a fresh spot after each press.
const STIR_MARKS := [2.4, 4.6, 1.3]
## Flip: the heat rises 0 to 1 in RISE seconds, then falls; the gold band; nothing below COLD.
const FLIP_RISE := 1.6
const FLIP_BAND := Vector2(0.72, 0.86)
const FLIP_COLD := 0.4
## Plate: seconds a sweep (one side to the other); full within FULL of centre, nothing past ZERO (of the half-width).
const PLATE_SWEEP := 1.4
const PLATE_FULL := 0.06
const PLATE_ZERO := 0.35
## A beat with no press for this many of its cycles scores 0 and moves on.
const MISS_CYCLES := 3.0

var beats: Array = BEATS.duplicate()
var speed := 1.0
## The beat on now (an index into beats; beats.size() when it's over), seconds into it.
var beat := 0
var t := 0.0
## Each beat's score once done; the stir's presses so far.
var scores: Array = []
var stir_hits: Array = []
## The last press: [beat name, score] (the screen reads it for its call-out).
var last: Array = []


func _init(opts: Dictionary = {}) -> void:
	speed = float(opts.get("speed", 1.0))
	if opts.has("beats"):
		beats = (opts["beats"] as Array).filter(func(b): return b in BEATS)
		if beats.is_empty():
			beats = BEATS.duplicate()


func done() -> bool:
	return beat >= beats.size()


func current() -> String:
	return "" if done() else str(beats[beat])


func tick(delta: float) -> void:
	if done():
		return
	t += delta
	match current():
		"stir":
			if t * STIR_TURNS * speed > MISS_CYCLES:
				_stir_score(0.0)
		"flip":
			# risen and fallen back past the cold line: burnt or cold, nothing
			if t > rise_secs() and heat() < FLIP_COLD:
				_end(0.0)
		"plate":
			if t > PLATE_SWEEP / speed * MISS_CYCLES * 2.0:
				_end(0.0)


## A press (F, Space or a click): that beat's score for it (0-1), or -1 when there's nothing to press.
func press() -> float:
	if done():
		return -1.0
	var s := 0.0
	match current():
		"stir":
			s = stir_score()
			_stir_score(s)
			return s
		"flip":
			s = flip_score()
		"plate":
			s = plate_score()
	_end(s)
	return s


# ---- the beats' state, for drawing ----

## The spoon's angle round the pot (radians).
func spoon_angle() -> float:
	return TAU * STIR_TURNS * speed * t


## Where the stir's mark is now (radians).
func mark_angle() -> float:
	return float(STIR_MARKS[mini(stir_hits.size(), STIR_MARKS.size() - 1)])


func stir_score() -> float:
	var d := rad_to_deg(absf(angle_difference(spoon_angle(), mark_angle())))
	return clampf(1.0 - (d - STIR_FULL) / (STIR_ZERO - STIR_FULL), 0.0, 1.0)


func rise_secs() -> float:
	return FLIP_RISE / speed


## The pan's heat (0-1): up to 1 then back down.
func heat() -> float:
	var r := rise_secs()
	return t / r if t <= r else maxf(2.0 - t / r, 0.0)


func flip_score() -> float:
	var h := heat()
	if h >= FLIP_BAND.x and h <= FLIP_BAND.y:
		return 1.0
	if h < FLIP_BAND.x:
		return clampf((h - FLIP_COLD) / (FLIP_BAND.x - FLIP_COLD), 0.0, 1.0)
	# over the band: scorched a little
	return clampf(1.0 - (h - FLIP_BAND.y) / (FLIP_BAND.x - FLIP_COLD), 0.0, 1.0)


## The plate across the counter: -1 (left) to 1 (right), a triangle wave starting from the left.
func plate_x() -> float:
	var u := fmod(t * speed / PLATE_SWEEP, 2.0)
	return -1.0 + 2.0 * (u if u <= 1.0 else 2.0 - u)


func plate_score() -> float:
	var d := absf(plate_x())
	return clampf(1.0 - (d - PLATE_FULL) / (PLATE_ZERO - PLATE_FULL), 0.0, 1.0)


# ---- the result ----

## The beats' mean (the stir's presses averaged as one beat).
func quality() -> float:
	if scores.is_empty():
		return 0.0
	var sum := 0.0
	for s in scores:
		sum += float(s)
	return sum / float(beats.size())


static func grade_of(q: float) -> int:
	for g in range(GRADE_FROM.size() - 1, -1, -1):
		if q >= float(GRADE_FROM[g]):
			return g
	return 0


## How a press reads: "Perfect!", "Good", "Off", "Missed".
static func call_out(s: float) -> String:
	if s >= 0.95:
		return "Perfect!"
	if s >= 0.6:
		return "Good"
	if s > 0.0:
		return "Off"
	return "Missed"


func _stir_score(s: float) -> void:
	stir_hits.append(s)
	last = ["stir", s]
	if stir_hits.size() >= STIR_PRESSES:
		var sum := 0.0
		for h in stir_hits:
			sum += float(h)
		_end(sum / float(STIR_PRESSES), false)
	else:
		# the spoon keeps going round; the miss clock starts again for the next press
		t = fmod(t, 1.0 / (STIR_TURNS * speed))


func _end(s: float, note := true) -> void:
	if note:
		last = [current(), s]
	scores.append(s)
	beat += 1
	t = 0.0
