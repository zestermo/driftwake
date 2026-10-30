class_name StrongholdScouring
extends Node3D
## The end of a stronghold raid (1.27, docs/v1_27_raids_fruits_plan.md: the broadcast and the Scouring; Zach on the
## Admiral). When the Commodore falls ("sh_seal_keep") every machine, from the moment it sees that flag:
## - the emergency broadcast (a banner), and the garrison stops refilling (no more respawns, no more officers);
## - GRACE s to loot, then COUNT s of countdown (banners), then the Scouring: a shell every SHELL_EVERY s somewhere on
##   the island (every third at our own captain), each telegraphed WARN s ahead, a blast that hurts our captain within
##   SHELL_R and leaves a burning patch (FIRE_LIFE s) behind;
## - the crew's ship past ESCAPE_R from the island ends it ("sh_escaped": the host sees it, a bounty).
## The shells are worked out from the shared clock on every machine and hurt only its own captain, so nothing about
## them goes over the net.
## The Admiral (at a top captain's level ADMIRAL_LEVEL+ or a Dreaded bounty): comes ashore when it starts, very tanky
## and deliberate; every BLINK_EVERY s he blinks in front of whoever is nearest the ship (within SHIP_REACH of it) and
## goes for them; worn down to LEAVE_AT of his health he says his piece and leaves ("sh_admiral_gone"); then you go.

const GRACE := 120.0
const COUNT := 120.0
const SHELL_EVERY := 1.2
const WARN := 2.0
const SHELL_R := 6.0
const SHELL_DMG := 20.0
const FIRE_LIFE := 8.0
const FIRE_R := 3.5
const FIRE_DPS := 8.0
const ESCAPE_R := 500.0
const ISLAND_R := 150.0
const ADMIRAL_LEVEL := 32
const ADMIRAL_HP := 30.0
const BLINK_EVERY := 6.0
const SHIP_REACH := 90.0
const LEAVE_AT := 0.66

var isl: Node3D
var camps: Array = []
## (tests shorten these)
var grace := GRACE
var count := COUNT
var force_admiral := false
var state := ""
var t0 := -1.0
var admiral: Player
var _next := 0
var _pending: Array = []
var fires: Array = []
var _hurt := 0.0
var _said := {}
var _blink := 0.0
var _check := 0.0


func setup(island: Node3D, watched: Array) -> StrongholdScouring:
	isl = island
	camps = watched
	name = "Scouring"
	return self


func _flag(f: String) -> bool:
	var gm := get_node_or_null("/root/GameManager")
	return gm != null and gm.world_flags.has(f)


func _clock() -> float:
	return float(get_node("/root/Ocean").clock())


func _banner(key: String, title: String, sub: String) -> void:
	if _said.has(key):
		return
	_said[key] = true
	get_tree().call_group("hud", "show_banner", title, sub, true)


func _process(delta: float) -> void:
	# (a wipe counts from the first fight on, not only once the Scouring's begun)
	if get_node("/root/Net").is_host():
		_wipe(delta)
	if _flag("sh_escaped"):
		state = "escaped"
		_banner("escaped", "Survived the Scouring", "%s burns behind you." % isl.island_name)
		return
	if t0 < 0.0:
		if not _flag("sh_seal_keep"):
			return
		t0 = _clock()
		_banner("broadcast", "All ships. %s has fallen." % isl.island_name, "The Scouring is ordered.")
		_stand_down()
	var t := _clock() - t0
	if t < grace:
		state = "grace"
	elif t < grace + count:
		state = "count"
		var left := grace + count - t
		for mark: float in [count, 60.0, 30.0, 10.0]:
			if left <= mark and left > mark - 1.0:
				_banner("count%d" % int(mark), "The Scouring", "Shells in %d seconds. Get to your ship." % int(mark))
	else:
		state = "barrage"
		var k := int(floor((t - grace - count) / SHELL_EVERY))
		while _next <= k:
			_shell(_next)
			_next += 1
	_land(delta)
	_burn(delta)
	if get_node("/root/Net").is_host():
		_host(delta)


## The garrison stands down: no squad comes back, no more officers.
func _stand_down() -> void:
	for c in camps:
		if is_instance_valid(c) and c is GruntCamp:
			(c as GruntCamp).respawn_time = 1.0e9
		elif is_instance_valid(c) and c is StrongholdOfficers:
			(c as Node).set_process(false)


## Shell k: where it falls (every third at our own captain), telegraphed now, landing WARN s later.
func _shell(k: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), k])
	var at: Vector3
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if k % 3 == 2 and me:
		at = me.global_position + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
	else:
		var q: Vector2 = StrongholdPlan.LAND_C + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * ISLAND_R
		var g := StrongholdPlan.ground(q)
		at = isl.city_global(q, g if g > -INF else maxf(StrongholdPlan.terrain(q), 0.0))
	FX.telegraph(at, SHELL_R, WARN, Color(1.0, 0.25, 0.08))
	_pending.append([at, _clock() + WARN])


func _land(_delta: float) -> void:
	var now := _clock()
	var me := get_tree().get_first_node_in_group("player") as Player
	while not _pending.is_empty() and float(_pending[0][1]) <= now:
		var at: Vector3 = _pending.pop_front()[0]
		FX.blast(at, Vector3.UP, 2.6)
		FX.flash_light(at + Vector3.UP * 2.0, FX.FIRE_LIGHT, 4.0, 14.0, 0.4)
		FX.fire_ring(at, FIRE_R, 30)
		fires.append([at, now + FIRE_LIFE])
		if me and me.global_position.distance_to(at) < SHELL_R:
			var hd := HitData.new()
			hd.damage = SHELL_DMG
			hd.knockback_force = 9.0
			hd.unblockable = true
			hd.camera_shake_intensity = 0.5
			me.hurtbox.take_hit(hd, null)


## The burning patches: flames over each now and then, our captain hurt standing in one.
func _burn(delta: float) -> void:
	var now := _clock()
	fires = fires.filter(func(f): return float(f[1]) > now)
	var me := get_tree().get_first_node_in_group("player") as Player
	_hurt -= delta
	if _hurt > 0.0:
		return
	_hurt = 0.5
	for f in fires:
		var at: Vector3 = f[0]
		FX.flame(at, 4, 0.8, 0.6, FIRE_R * 0.6)
		if me and me.global_position.distance_to(at) < FIRE_R:
			var hd := HitData.new()
			hd.damage = FIRE_DPS * 0.5
			hd.dot = true
			me.hurtbox.take_hit(hd, null)
			# (one burn a tick, however many patches overlap)
			me = null


# --------------------------------------------------------------------------
# The host: the escape and the Admiral
# --------------------------------------------------------------------------
func _host(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
	var net := get_node("/root/Net")
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	var centre: Vector3 = isl.city_global(StrongholdPlan.LAND_C, 0.0)
	if state == "barrage" and ship:
		var d := Vector2(ship.global_position.x - centre.x, ship.global_position.z - centre.z).length()
		if d > ESCAPE_R:
			net.world_flag("sh_escaped")
			net.bounty("scouring", ship.global_position, 200.0)
			return
	if state != "barrage" or _flag("sh_admiral_gone"):
		return
	if admiral == null:
		if admiral_due():
			_spawn_admiral()
		return
	_drive_admiral(0.25, ship)


## At a top captain's level ADMIRAL_LEVEL+ or a Dreaded bounty (or a test's say-so).
func admiral_due() -> bool:
	if force_admiral:
		return true
	for p in get_node("/root/Net").all_players():
		var pl := p as Player
		if pl.progression and int(pl.progression.level) >= ADMIRAL_LEVEL:
			return true
		if Bounty.tier_of(int(pl.bounty)) >= 4:
			return true
	return false


func _spawn_admiral() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["admiral", int(isl.node["seed"])])
	var lk := PirateGrunt.crew_look(rng)
	EnemyShip.marine_look(lk, rng, true)
	lk["name"] = "Admiral Thorne Halvard"
	lk["coat_color"] = Color(0.9, 0.9, 0.92)
	var at: Vector3 = isl.city_global(Vector2(StrongholdPlan.BERTH.x, StrongholdPlan.FRONT_Z - 8.0), StrongholdPlan.QUAY_Y + 0.5)
	var net := get_node("/root/Net")
	net.everyone("_all_spawn_rival", [net.key_of(isl.city), "Admiral", lk, "greatsword", at, 0.0, 1.0])
	admiral = isl.city.get_node_or_null("Admiral") as Player
	if admiral == null:
		return
	admiral.hp_k = ADMIRAL_HP
	admiral._recalc_stats()
	admiral.health_component.current_health = admiral.health_component.max_health
	FX.speech(admiral, "Going somewhere, pirates?")


## Every BLINK_EVERY s: in front of whoever is nearest the ship (within SHIP_REACH of it), on them. Worn to LEAVE_AT:
## his piece said, he leaves.
func _drive_admiral(step: float, ship: Node3D) -> void:
	if not is_instance_valid(admiral):
		return
	var hc := admiral.health_component
	if hc.current_health <= hc.max_health * LEAVE_AT:
		FX.speech(admiral, "Enough. Run, then. The sea is wide, and I am patient.")
		get_node("/root/Net").world_flag("sh_admiral_gone")
		admiral.get_node("Brain").order = "hold"
		FX.blast(admiral.global_position, Vector3.UP, 1.6)
		admiral.global_position += Vector3(0, -400.0, 0)
		admiral.reset_physics_interpolation()
		return
	_blink -= step
	if _blink > 0.0 or ship == null:
		return
	var runner: Player = null
	var best := SHIP_REACH
	for p in get_node("/root/Net").all_players():
		var d := (p as Node3D).global_position.distance_to(ship.global_position)
		if d < best:
			best = d
			runner = p
	if runner == null:
		return
	_blink = BLINK_EVERY
	var to_ship := ship.global_position - runner.global_position
	to_ship.y = 0.0
	var at := runner.global_position + to_ship.normalized() * 3.0
	FX.blast(admiral.global_position, Vector3.UP, 1.0, false)
	admiral.global_position = at
	admiral.reset_physics_interpolation()
	FX.blast(at, Vector3.UP, 1.2, false)
	var brain := admiral.get_node_or_null("Brain")
	if brain:
		brain.order = "fight"
		brain.target = runner


## A wipe (decided: the brig, kit kept): every captain on the stronghold down at once -> the Admiralty's brig
## (AdmiraltyBrig via Net._all_arrest); breaking out brings the crew back to the Lower Ward. Not once they've escaped.
var _wiped_t := 0.0


func _wipe(step: float) -> void:
	_wiped_t -= step
	if _wiped_t > 0.0 or state == "escaped" or AdmiraltyBrig.of(get_tree()) != null:
		return
	var centre: Vector3 = isl.city_global(StrongholdPlan.LAND_C, 0.0)
	var here: Array = []
	for p in get_node("/root/Net").all_players():
		var pl := p as Player
		if Vector2(pl.global_position.x - centre.x, pl.global_position.z - centre.z).length() < ISLAND_R + 30.0:
			here.append(pl)
	if here.is_empty() or here.any(func(pl): return pl.is_standing()):
		return
	_wiped_t = 15.0
	var ward: Rect2 = StrongholdPlan.DISTRICTS[1][1]
	var back: Vector3 = isl.city_global(ward.get_center(), float(StrongholdPlan.DISTRICTS[1][2]) + 0.5)
	get_node("/root/Net").everyone("_all_arrest", [back, "Commodore Aurel Vane"])
