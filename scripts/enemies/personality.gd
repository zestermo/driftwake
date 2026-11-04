class_name Personality
## (1.30 round 6, docs/v1_30_plan.md) How a foe fights, rolled per foe from its seed (the same on every machine):
##   berserker   - closes at once, a longer combo, short breathers, never steps back, chases further
##   opportunist - hangs wide and waits until a couple of the others are on the captain (or the captain is busy or
##                 reeling), then goes in, usually from the side; still takes its turn from the crew (the attacker cap)
##   duelist     - reads a captain's swing (the blade comes up, a blue glint), parries a light inside that window and
##                 ripostes; a heavy or a kick into the raised guard breaks it
##   bulwark     - blocks most blows from the front and walks in behind the guard, punishes a missed swing; a heavy,
##                 a kick or enough blows on the guard break it
## The tells: a stance held while it circles (FoePoses "fo_*", sword grunts) and its own shout when it spots you.
## The numbers in K are first guesses (the plan's "assumed weights"): tune by play.

const ALL := ["berserker", "opportunist", "duelist", "bulwark"]
## Need a blade's guard (a sword grunt): the others roll only from the first two.
const GUARDED := ["duelist", "bulwark"]
## Weights by kind, in ALL's order.
const WEIGHTS := {
	"fodder": [5.0, 4.0, 0.6, 0.6],
	"grunt": [3.0, 3.0, 2.0, 2.0],
	"officer": [1.0, 1.0, 1.0, 1.0],
}
## block: share of front blows guarded; cool: the breather after an attack (s); hits: extra swings in a combo;
## wind: x the wind-ups; chase: x the run in; give_up: x how far it follows; ring: m on the circling distance.
const K := {
	"berserker": {"block": 0.08, "cool": Vector2(0.35, 0.8), "hits": 1, "wind": 0.9, "chase": 1.15, "give_up": 1.5, "ring": -0.5},
	"opportunist": {"block": 0.2, "cool": Vector2(1.6, 2.8), "hits": 0, "wind": 1.0, "chase": 1.0, "give_up": 1.0, "ring": 1.6},
	"duelist": {"block": 0.12, "cool": Vector2(1.2, 2.2), "hits": 0, "wind": 1.0, "chase": 1.0, "give_up": 1.0, "ring": 0.2},
	"bulwark": {"block": 0.6, "cool": Vector2(1.4, 2.6), "hits": 0, "wind": 1.05, "chase": 0.85, "give_up": 1.0, "ring": -0.6},
}
## Its shouts' colour (the bark label): a third tell, read at a glance in a crowd.
const COLOR := {"berserker": Color(1.0, 0.55, 0.45), "opportunist": Color(0.9, 0.9, 0.55), "duelist": Color(0.65, 0.85, 1.0),
	"bulwark": Color(0.8, 0.82, 0.88)}
const STANCE :={"berserker": "fo_frenzy", "opportunist": "fo_lurk", "duelist": "fo_en_garde", "bulwark": "fo_guard_walk"}
const BARK_SPOT := {
	"berserker": ["Blood! BLOOD!", "Hahaha! Come here!", "I'll tear you apart!", "Fresh meat!"],
	"opportunist": ["After you, lads...", "You first.", "I'll wait my turn...", "Wear 'em down, boys."],
	"duelist": ["En garde.", "Show me your blade.", "Let's dance.", "Draw, then."],
	"bulwark": ["You won't get through.", "Hold the line!", "Come on. Hit me.", "Not one step."],
}
const BARK_PARRY := ["Too slow.", "Predictable.", "Hah! Again?", "Clumsy."]
const BARK_BLOCK := ["Is that all?", "Harder!", "Not getting through."]
const BARK_STRIKE := ["Now!", "Got an opening!", "Your back's mine!"]
const BARK_FRENZY := ["RAAAGH!", "More! MORE!", "Hahaha!"]

## Opportunist: goes in once this many others are on the same captain (or as many as there are), on an opening,
## or after waiting OPP_WAIT s; alone, after OPP_ALONE s.
const OPP_ENGAGED := 2
const OPP_WAIT := 6.0
const OPP_ALONE := 1.5
## Duelist: the chance it raises the parry on a swing it sees, how long the window stays open (s), the cooldown.
const PARRY_ODDS := 0.7
const PARRY_WINDOW := 0.6
const PARRY_CD := Vector2(2.2, 3.2)
## The captain parried reels back this hard (Player.shoved: about a quarter second).
const PARRY_PUSH := 5.0
const PARRY_TELL := Color(0.6, 0.82, 1.0)
## Bulwark: blows' poise on the guard break it at GUARD_BREAK (a heavy or kick at once), draining GUARD_DRAIN a second.
const GUARD_BREAK := 40.0
const GUARD_DRAIN := 8.0
const GUARD_BROKEN := 1.4


## The personality a foe of `kind` ("fodder", "grunt", "officer") rolls from its seed; `guarded`: it has a blade's
## guard (else only berserker or opportunist).
static func roll(seed_v: int, kind: String, guarded: bool) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["personality", seed_v, kind])
	var w: Array = (WEIGHTS[kind] as Array).duplicate()
	if not guarded:
		for i in range(ALL.size()):
			if ALL[i] in GUARDED:
				w[i] = 0.0
	var total := 0.0
	for x in w:
		total += float(x)
	var r := rng.randf() * total
	for i in range(ALL.size()):
		r -= float(w[i])
		if r <= 0.0:
			return ALL[i]
	return ALL[0]


static func k(p: String, what: String, base):
	return (K[p] as Dictionary).get(what, base) if p != "" else base
