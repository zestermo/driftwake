class_name StrongholdAlarm
extends Node3D
## The stronghold's alarm (1.30, docs/v1_30_plan.md round 3: "a raised alarm brings visible reinforcements; a cleared
## district stays clear"; "cut or guard alarm bells to slow reinforcements"). Each district's alarm is its own world flag
## ("sh_alarm_<district>"), raised by the host when a marine rings one of its bells (StrongholdBell): once its garrison
## is in a fight, the fodder marine nearest a working bell runs for it (FodderMarine.run_to_bell) and rings it RING_SECS;
## cut him down first and another goes RUNNER_GAP s later. With every bell's rope cut the alarm only goes up when a
## fight runs LONG_FIGHT s (word spreads), and its waves come SLOW_K times slower; a fight the runners keep losing
## raises it after LONG_FIGHT x 2 all the same. Then its bells ring, every man of its garrison goes hunting the captains,
## and its reinforcements (StrongholdReinforce) muster a wave every WAVE_EVERY s while fewer than PRESS of the district's
## men are in the fight and fewer than PEAK in the whole fortress, until its POOL of waves is spent. A district whose
## garrison is all down (and its pool spent, or never called on: a quiet clearing keeps the pool from ever coming) is
## cleared for good ("sh_clear_<district>"). The Commodore's fall stands the whole garrison down.

const LONG_FIGHT := 14.0
const RUNNER_GAP := 3.0
const SLOW_K := 2.0
const WAVE_EVERY := 7.0
const FIRST_WAVE := 2.0
const PRESS := 18
const PEAK := 30
## Each district's reinforcement waves (StrongholdReinforce.SIZE men each).
const POOL := {"landing": 3, "ward": 6, "arsenal": 5, "prison": 5, "keep": 5}
const CHECK := 0.25
const RINGS := 3
const RING_EVERY := 1.1

var isl: Node3D
var squads := {}
var sources := {}
## (host) waves left, how long each district's garrison has been fighting, the time to its next wave, the bells to ring.
var pool := {}
var _fight_t := {}
var _wave_t := {}
var _src_i := {}
var _rings: Array = []
var _check := 0.0
## (host) each district's bell runner and the time till another may go; (every machine) the alarms already rung here.
var runner := {}
var _gap := {}
var _seen := {}


func setup(island: Node3D, sq: Dictionary, src: Dictionary) -> StrongholdAlarm:
	isl = island
	squads = sq
	sources = src
	name = "Alarm"
	for d in squads:
		pool[d] = int(POOL[d])
		_fight_t[d] = 0.0
		_wave_t[d] = FIRST_WAVE
		_src_i[d] = 0
		_gap[d] = 0.0
	return self


func _flag(f: String) -> bool:
	return get_node("/root/GameManager").world_flags.has(f)


func alarmed(d: String) -> bool:
	return _flag("sh_alarm_" + d)


func cleared(d: String) -> bool:
	return _flag("sh_clear_" + d)


## A district's men in the fight: its garrison's fighting now, and every reinforcement still up.
func up(d: String) -> int:
	var n := 0
	for g in (squads[d] as GruntCamp).grunts:
		if is_instance_valid(g) and (g as PirateGrunt).in_combat():
			n += 1
	for s in sources[d]:
		n += (s as GruntCamp).alive_count()
	return n


func fortress_up() -> int:
	var n := 0
	for d in squads:
		n += up(d)
	return n


## (host) The district's bells: its flag, every man of its garrison on the captains, the first wave soon.
func raise(d: String) -> void:
	if alarmed(d):
		return
	Net.world_flag("sh_alarm_" + d)
	_wave_t[d] = FIRST_WAVE
	for g in (squads[d] as GruntCamp).grunts:
		if is_instance_valid(g) and g is FodderMarine and not (g as PirateGrunt).is_dead():
			(g as FodderMarine).hunt = true
			(g as FodderMarine).bell = null
			(g as PirateGrunt).alert(randf_range(0.1, 0.8))
	var at := (squads[d] as Node3D).global_position + Vector3(0, 6, 0)
	for k in range(RINGS):
		_rings.append([float(k) * RING_EVERY, at])
	Net.banner("The alarm!", "%s: the bells are ringing. Reinforcements are coming." % title(d), true)


## Seconds between a district's waves: slower with its bells all cut.
func wave_every(d: String) -> float:
	return WAVE_EVERY * (SLOW_K if StrongholdBell.working(d).is_empty() else 1.0)


## (host, a district not yet alarmed) Its garrison in a fight: a runner for the nearest working bell (another if he's cut
## down), the alarm when he's rung it, or when the fight runs long.
func _watch(d: String, sq: GruntCamp) -> void:
	var fighting := sq.grunts.any(func(g): return is_instance_valid(g) and (g as PirateGrunt).in_combat())
	_fight_t[d] = float(_fight_t[d]) + CHECK if fighting else 0.0
	_gap[d] = float(_gap[d]) - CHECK
	var bells := StrongholdBell.working(d)
	if float(_fight_t[d]) >= LONG_FIGHT * (2.0 if not bells.is_empty() else 1.0):
		raise(d)
		return
	var r = runner.get(d)
	if r != null and is_instance_valid(r) and not (r as PirateGrunt).is_dead():
		if (r as FodderMarine).rang:
			raise(d)
			return
		if (r as FodderMarine).bell != null:
			return
	runner.erase(d)
	if not fighting or bells.is_empty() or float(_gap[d]) > 0.0:
		return
	var best: FodderMarine = null
	var best_b: Node3D = null
	var bd := INF
	for g in sq.grunts:
		if not (is_instance_valid(g) and g is FodderMarine) or (g as PirateGrunt).is_dead() or (g as PirateGrunt).state in [PirateGrunt.S.DOWN, PirateGrunt.S.GETUP, PirateGrunt.S.AIR]:
			continue
		for b in bells:
			var dd := (g as Node3D).global_position.distance_to((b as Node3D).global_position)
			if dd < bd:
				bd = dd
				best = g
				best_b = b
	if best:
		runner[d] = best
		_gap[d] = RUNNER_GAP
		best.run_to_bell(best_b)


static func title(d: String) -> String:
	return {"landing": "The Landing", "ward": "The Lower Ward", "arsenal": "The Arsenal", "prison": "The Prison Tower", "keep": "The Keep"}[d]


func _process(delta: float) -> void:
	for d in squads:
		if not _seen.has(d) and alarmed(d):
			_seen[d] = true
			for b in StrongholdBell.of(d):
				b.ring()
	if not get_node("/root/Net").is_host():
		return
	for r in _rings.duplicate():
		r[0] -= delta
		if r[0] <= 0.0:
			_rings.erase(r)
			Net.fx("sfx", ["bell", r[1], 6.0, 0.02, 0.85])
	_check -= delta
	if _check > 0.0:
		return
	_check = CHECK
	if _flag("sh_seal_keep"):
		return
	# (the Landing's gate winch heard: StrongholdActs.Gate)
	if _flag("sh_winching") and not alarmed("landing") and not cleared("landing"):
		raise("landing")
	var total := fortress_up()
	for d in squads:
		if cleared(d):
			continue
		var sq: GruntCamp = squads[d]
		if sq.grunts.size() < sq.specs.size():
			continue
		if not alarmed(d):
			_watch(d, sq)
		elif int(pool[d]) > 0:
			_wave_t[d] = float(_wave_t[d]) - CHECK
			if float(_wave_t[d]) <= 0.0 and up(d) < PRESS and total < PEAK:
				var srcs: Array = sources[d]
				var s: StrongholdReinforce = srcs[int(_src_i[d]) % srcs.size()]
				_src_i[d] = int(_src_i[d]) + 1
				if not s.busy():
					s.muster()
					pool[d] = int(pool[d]) - 1
					total += s.size()
				_wave_t[d] = wave_every(d)
		if sq.alive_count() == 0 and (int(pool[d]) == 0 or not alarmed(d)) and sources[d].all(func(s): return s.alive_count() == 0 and not s.busy()):
			pool[d] = 0
			Net.world_flag("sh_clear_" + d)
			Net.banner(title(d), "Cleared. Nothing more will come here.")
