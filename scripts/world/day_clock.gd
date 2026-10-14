class_name DayClock
## The world's clock: a 24-minute day whose daylight hours run slower than the
## night's (6:00-18:00 takes DAY_SECS, the night the rest), so days feel longer.

const LEN := 1440.0
const DAY_SECS := 840.0
const DAWN := 6.0
const DUSK := 18.0


static func _night_rate() -> float:
	return (LEN - DAY_SECS) / (24.0 - (DUSK - DAWN))


static func _day_rate() -> float:
	return DAY_SECS / (DUSK - DAWN)


## Seconds from midnight to hour `h`.
static func secs_of(h: float) -> float:
	h = fposmod(h, 24.0)
	if h < DAWN:
		return h * _night_rate()
	if h < DUSK:
		return DAWN * _night_rate() + (h - DAWN) * _day_rate()
	return DAWN * _night_rate() + DAY_SECS + (h - DUSK) * _night_rate()


## The hour `s` seconds after midnight.
static func hour_of(s: float) -> float:
	s = fposmod(s, LEN)
	var dawn_s := DAWN * _night_rate()
	if s < dawn_s:
		return s / _night_rate()
	if s < dawn_s + DAY_SECS:
		return DAWN + (s - dawn_s) / _day_rate()
	return DUSK + (s - dawn_s - DAY_SECS) / _night_rate()


## Seconds from hour `h0` forward to hour `h1`.
static func secs_between(h0: float, h1: float) -> float:
	return fposmod(secs_of(h1) - secs_of(h0), LEN)
