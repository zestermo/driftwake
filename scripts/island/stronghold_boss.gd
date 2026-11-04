class_name StrongholdBoss
extends Node3D
## A stronghold boss in its arena (1.27, docs/v1_27_raids_fruits_plan.md "Decided: the stronghold bosses"): a captain
## -style AI (RivalDuel.build through Net._all_spawn_rival: weapons, skills, an ultimate, movement) with a boss's health
## and phases. It turns up when a captain walks into its room (StrongholdPlan.ROOMS), the room's grate drops, and when
## it's beaten its seal is the crew's ("sh_seal_<seal>") and the grate rises for good.
## Everything other machines need is a world flag: "sh_<boss>_on" (the fight's begun), "sh_<boss>_p2" (phase 2),
## the seal. Each machine works the grate and the arena's hazards out from those and the shared clock (Ocean.clock),
## and hazards hurt only its own captain (each captain takes damage on their own machine).
##
## Lieutenant Varro Kesh (the Casting Hall, seal of the Arsenal): cutlass and pistol, the full kit; at half health he
## kicks the furnace sluices open and molten iron runs down the floor's channels in turn (a glow first, then it burns).
## Captain Ilse Marrow (the prison yard, an open arena, seal of the prison): a greatsword; at half health the cell
## block opens on its berserk brutes. Commodore Aurel Vane (the Command Hall, the end): katana and pistol, three phases:
## the duel; at 65% the fortress answers (two waves of marines, the hall's quarters flaring in turn); at 30% the Verdict
## (a second blade, the sharpest brain, his ultimate charged). His fall is "sh_seal_keep": the broadcast and the
## Scouring follow.

const BOSSES := {
	"kesh": {"room": "casting", "name": "Lieutenant Varro Kesh", "epithet": "the Foundry's Hammer", "weapon": "cutlass", "offhand": "pistol", "hp": 6.0,
		"skill": 1.0, "seal": "arsenal", "p2": 0.5, "checkpoint": Vector2(62.0, -23.0),
		"sig": {"r": 4.5, "dmg": 26.0, "push": 15.0, "lines": ["Into the crucible!", "Feel the hammer!", "Melt!"]}},
	# (an open arena, no room: the yard before the prison's drum; at half health the cell block opens and the riot comes)
	"marrow": {"arena": [Vector2(-72.0, 5.0), 14.0], "district": 3, "name": "Captain Ilse Marrow", "epithet": "Warden of the Drowned Cells",
		"weapon": "greatsword", "hp": 8.0, "skill": 1.0, "seal": "prison", "p2": 0.5, "adds": [5, 6, 6], "prisoners": true,
		"checkpoint": Vector2(-55.0, -4.0),
		"sig": {"r": 6.0, "dmg": 28.0, "push": 17.0, "lines": ["The gallows drop!", "Kneel!", "Sentence passed!"]}},
	# (the end: in the Command Hall, then at 65% up onto the Verdict's roof (the balcony over the hall's door) with marines
	# coming out of the tower after him; at 30% the Verdict: a second blade, enraged, and the Scouring is ordered)
	"vane": {"room": "command", "name": "Commodore Aurel Vane", "epithet": "the Verdict of the Admiralty", "weapon": "katana", "offhand": "pistol",
		"offhand3": "cutlass", "hp": 12.0, "skill": 1.0, "seal": "keep", "p2": 0.65, "p3": 0.3, "adds": [5, 5],
		"checkpoint": Vector2(0.0, -56.0),
		"sig": {"r": 5.0, "dmg": 30.0, "push": 16.0, "lines": ["Judgement!", "The Verdict falls!", "Kneel before the Admiralty!"]}},
}
## (1.30 set pieces) The signature attack: every SIG_EVERY[phase] s the boss marks a captain's spot (a ring on the
## floor), leaps there and lands with a shockwave (BossReset's leap, untouchable only in the air): big and readable.
const SIG_EVERY := [10.0, 7.5, 5.5]
const SIG_WIND := 0.7
const SIG_AIR := 0.75
const SIG_REST := 0.45
const SIG_REACH := 24.0
## A faster, more aggressive brain than a rival's (CaptainBrain.pace under 1).
const PACE := 0.7
## Kesh's pouring foundry (phase 2 on): the crucible swings over the hall and pours on one of POURS (room-local xz) in
## turn every POUR_CYCLE s: POUR_WARN s of a glowing ring, then POUR_BURN s of molten iron in POUR_R (POUR_DPS).
const POURS := [Vector2(-7.0, -6.0), Vector2(7.0, 5.0), Vector2(6.0, -8.0), Vector2(-6.0, 7.0)]
const POUR_CYCLE := 9.0
const POUR_WARN := 2.0
const POUR_BURN := 4.5
const POUR_R := 4.0
const POUR_DPS := 30.0
## A captain who bleeds out in an arena is back at its checkpoint this long after (GameManager's respawn).
const REJOIN_SECS := 8.0
static var all: Array = []
## The molten channels (Kesh's phase 2): across the room at these offsets from its middle, each this wide; one at a
## time in turn every CYCLE s: WARN s of glow, then BURN s of burning; MOLTEN_DPS to a captain standing in it.
const CHANNELS := [-9.0, 0.0, 9.0]
const CHANNEL_W := 3.0
const CYCLE := 6.0
const WARN := 1.5
const BURN := 3.0
const MOLTEN_DPS := 18.0
## The vault's legendary (one per stronghold, picked by the chain's seed): [name, weapon kind, trait]. At LEGENDARY rarity.
const LEGENDARIES := [["Gallowsbane", "cutlass", "duellist"], ["Mourning Moon", "katana", "gale"], ["Old Thunder", "greatsword", "thundering"],
	["Saint's Knuckle", "warhammer", "headsman"], ["Bosun's Promise", "boarding_axe", "bloodthirsty"], ["Quiet Tide", "dagger", "venomous"]]
## The vault chest (from the Command Hall's middle): on the floor before the dais's front step, between two pillars.
const VAULT_AT := Vector3(-2.0, 0.0, -14.4)

var key := ""
var isl: Node3D
var rm: Array = []
var boss: Player
var _grate: StaticBody3D
var _strips: Array = []
var _warn_m: Material
var _burn_m: Material
var _check := 0.0
var _hurt := 0.0
var _vault := false
var _k := 1.0


func setup(island: Node3D, boss_key: String) -> StrongholdBoss:
	isl = island
	key = boss_key
	name = "Boss_" + key
	var b: Dictionary = BOSSES[key]
	if b.has("room"):
		for r in StrongholdPlan.ROOMS:
			if str(r[0]) == str(b["room"]):
				rm = r
		var c: Vector2 = (rm[2] as Rect2).get_center()
		position = Vector3(c.x, float(rm[3]), c.y)
	else:
		var ac: Vector2 = b["arena"][0]
		position = Vector3(ac.x, float(StrongholdPlan.DISTRICTS[int(b["district"])][2]), ac.y)
	return self


func _ready() -> void:
	all.append(self)
	if not rm.is_empty():
		_grate = StrongholdEncounter.make_grate(rm)
		add_child(_grate)
		_build_postern()
	if BOSSES[key].has("adds"):
		_build_adds()
	_build_zones()
	if key == "marrow":
		_build_catwalks()
	if key == "kesh":
		_build_pours()


func _exit_tree() -> void:
	all.erase(self)


func _flag(f: String) -> bool:
	var gm := get_node_or_null("/root/GameManager")
	return gm != null and gm.world_flags.has(f)


func flag_on() -> String:
	return "sh_%s_on" % key


func flag_p2() -> String:
	return "sh_%s_p2" % key


func flag_seal() -> String:
	return "sh_seal_" + str(BOSSES[key]["seal"])


func beaten() -> bool:
	return _flag(flag_seal())


func flag_p3() -> String:
	return "sh_%s_p3" % key


func phase() -> int:
	return 3 if _flag(flag_p3()) else (2 if _flag(flag_p2()) else 1)


## The grate's down while the fight is on and the seal not yet taken.
func grate_shut() -> bool:
	return _flag(flag_on()) and not beaten()


func _process(delta: float) -> void:
	var shut := grate_shut()
	if _grate and _grate.visible != shut:
		_grate.visible = shut
		_grate.collision_layer = 1 if shut else 0
	if _postern:
		_postern.enabled = shut
	# (every machine) the intro card as the fight starts
	var on := _flag(flag_on())
	if on and not _carded and not beaten():
		get_tree().call_group("hud", "show_name_card", str(BOSSES[key]["name"]), str(BOSSES[key]["epithet"]))
	_carded = on
	_hazards(delta)
	_pours(delta)
	# (1.30) the vault's two locks turned together first (StrongholdActs.VaultLocks)
	if key == "vane" and not _vault and beaten() and _flag("sh_vault_unlocked"):
		_vault = true
		_open_vault()
	if not get_node("/root/Net").is_host() or beaten():
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
	var net := get_node("/root/Net")
	if not on:
		if _anyone_inside():
			_spawn()
			net.world_flag(flag_on())
		return
	if boss == null or not is_instance_valid(boss):
		boss = isl.city.get_node_or_null("Boss%s" % key.capitalize()) as Player
		if boss == null:
			_spawn()
			return
	if _wiped():
		reset_fight()
		return
	if not is_equal_approx(float(net.hp_scale()), _k):
		rescale(float(net.hp_scale()))
	var hp := boss.health_component.current_health / maxf(boss.health_component.max_health, 1.0)
	if phase() == 1 and hp <= float(BOSSES[key]["p2"]):
		net.world_flag(flag_p2())
		_leap_home()
		if key == "marrow":
			_perch_in = BossReset.WIND + BossReset.AIR + BossReset.ROAR_S
	if _perch_in > 0.0:
		_perch_in -= 0.25
		if _perch_in <= 0.0:
			_perch()
	if key == "marrow":
		_marrow(0.25)
	if phase() == 2 and BOSSES[key].has("p3") and hp <= float(BOSSES[key]["p3"]):
		net.world_flag(flag_p3())
		_leap_home()
		_enrage()
		if key == "vane":
			# (the Verdict on its roof: the fleet is told to scour the rock, the sky goes dark round the duel)
			net.world_flag("sh_scouring")
	_signature(0.25)
	if hp <= 0.0:
		net.world_flag(flag_seal())
		net.bounty("commodore" if key == "vane" else "stronghold_officer", boss.global_position, 120.0)


var _carded := false


## (host) Every so often the signature leap at a captain within SIG_REACH (a ring where they stand, then the landing's
## shockwave), not while it's down, leaping already or perched.
var _sig_t := 6.0


func _signature(step: float) -> void:
	_sig_t -= step
	if _sig_t > 0.0 or _perched > 0.0 or boss.current_state_name() in ["Downed", "BossLeap"] or boss.health_component.current_health <= 0.0:
		return
	var best: Node3D = null
	var bd := SIG_REACH
	for p in get_node("/root/Net").all_players():
		var d := (p as Node3D).global_position.distance_to(boss.global_position)
		if d < bd and (p as Player).is_standing() and absf((p as Node3D).global_position.y - boss.global_position.y) < 3.0:
			bd = d
			best = p
	if best == null:
		_sig_t = 1.0
		return
	_sig_t = float(SIG_EVERY[phase() - 1])
	var s: Dictionary = BOSSES[key]["sig"]
	var r := BossReset.new(boss, self)
	r._run(BossReset.floor_at(boss, best.global_position), SIG_WIND, SIG_AIR, SIG_REST, false, float(s["r"]), float(s["dmg"]), float(s["push"]))
	boss.state_machine.force_state("BossLeap", {"reset": r})
	var lines: Array = s["lines"]
	FX.speech(boss, str(lines[randi() % lines.size()]))


## (1.30) Each new phase starts from the room's middle: a leap there, a shockwave, a roar it can't be hurt in (BossReset
## through its BossLeap state; the shockwave's event goes out on this node).
var _perch_in := 0.0


func _leap_home() -> void:
	if boss.current_state_name() == "Downed":
		return
	var home := global_position
	if key == "vane" and phase() >= 2:
		# (up through the roof hatch onto the Verdict's balcony: the crew follows by the hoist, or a grapple)
		home = roof()
		FX.speech(boss, "Come up and face the Verdict, if you dare the climb!")
	boss.state_machine.force_state("BossLeap", {"reset": BossReset.new(boss, self).start(BossReset.floor_at(boss, home))})


## The Verdict's roof: the balcony's middle (StrongholdActs).
func roof() -> Vector3:
	return isl.city_global(StrongholdActs.BALCONY.get_center(), StrongholdActs.ROOF_Y)


## Where the fight is now: Vane's roof from phase 2, else the arena's middle.
func centre() -> Vector3:
	return roof() if key == "vane" and phase() >= 2 else global_position


## (host) Every captain on the stronghold down while the fight's on: a wipe. The boss starts over (StrongholdBoss.reset_fight).
func _wiped() -> bool:
	var near: Array = get_node("/root/Net").all_players().filter(func(p): return (p as Node3D).global_position.distance_to(global_position) < 260.0)
	return not near.is_empty() and near.all(func(p): return not (p as Player).is_standing())


## (host) A wipe: the fight starts over. Every phase flag cleared (Net.clear_world_flag), the boss healed, back at its
## spot and waiting; its adds called off; the crew gets back up at the checkpoint (GameManager's respawn, rejoin_point).
func reset_fight() -> void:
	var net := get_node("/root/Net")
	for f in [flag_on(), flag_p2(), flag_p3()]:
		net.clear_world_flag(f)
	_perched = 0.0
	_perch_in = 0.0
	_sig_t = 6.0
	if boss and is_instance_valid(boss):
		if boss.current_state_name() == "BossLeap":
			boss.state_machine.force_state("Idle", {})
		boss.global_position = _spawn_at()
		boss.reset_physics_interpolation()
		boss.hp_k = float(BOSSES[key]["hp"]) * _k
		boss._recalc_stats()
		boss.health_component.current_health = boss.health_component.max_health
		boss.health_component.health_changed.emit(boss.health_component.current_health, boss.health_component.max_health)
		var brain := boss.get_node_or_null("Brain")
		if brain:
			brain.order = "hold"
			brain.skill = float(BOSSES[key]["skill"])
	if _adds:
		_adds.call_off()
	Net.banner(str(BOSSES[key]["name"]), "Your crew is down. Back at the checkpoint: the fight starts over.", true)


var _adds: StrongholdEncounter


## (1.30, "revive, else rejoin") Where a captain who falls at `at` gets back up: just outside the arena of a stronghold
## boss not yet beaten whose arena `at` is in (its fight on or just reset by a wipe); Vector3.INF elsewhere.
static func rejoin_point(at: Vector3) -> Vector3:
	for b in all:
		if is_instance_valid(b) and not (b as StrongholdBoss).beaten() and (b as StrongholdBoss).contains(at):
			return (b as StrongholdBoss).checkpoint()
	return Vector3.INF


## (host) A stronghold boss's fight is on (the Scouring's wipe leaves a wipe here to the boss).
static func fighting() -> bool:
	return all.any(func(b): return is_instance_valid(b) and b._flag(b.flag_on()) and not b.beaten())


func checkpoint() -> Vector3:
	var q: Vector2 = BOSSES[key]["checkpoint"]
	var g := StrongholdPlan.ground(q)
	return isl.city_global(q, (g if g > -INF else position.y) + 0.4)


## Is `at` in the arena (the room, the yard, Vane's roof), with a margin?
func contains(at: Vector3) -> bool:
	var l := to_local(at)
	if key == "vane":
		var rl: Vector3 = isl.city.to_local(at)
		if StrongholdActs.BALCONY.grow(6.0).has_point(Vector2(rl.x, rl.z)) and absf(rl.y - StrongholdActs.ROOF_Y) < 6.0:
			return true
	if rm.is_empty():
		return Vector2(l.x, l.z).length() < float(BOSSES[key]["arena"][1]) + 4.0 and absf(l.y) < 10.0
	var r: Rect2 = rm[2]
	return absf(l.x) < r.size.x * 0.5 + 1.0 and absf(l.z) < r.size.y * 0.5 + 1.0 and l.y > -2.0 and l.y < float(rm[4]) + 1.0


## Back on your feet at the boss's checkpoint (each captain on their own machine), full health, to walk back in.
static func rejoin(p: Player, at: Vector3) -> void:
	p.spared_up()
	p.global_position = at
	p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO
	var hc := p.health_component
	hc.current_health = hc.max_health
	hc.health_changed.emit(hc.current_health, hc.max_health)
	p.state_machine.force_state("Idle", {})
	p.get_tree().call_group("hud", "show_toast", "Back at the checkpoint: get back in there")


## A sealed room's postern: F at the grate (while the fight's on) slips a captain back in (a rejoin, a latecomer).
var _postern: Interactable


func _build_postern() -> void:
	var door: Vector2 = rm[5]
	var half := ((rm[2] as Rect2).size.x if absf(door.x) > 0.5 else (rm[2] as Rect2).size.y) * 0.5
	_postern = Interactable.new()
	_postern.name = "Postern"
	_postern.collision_layer = 512
	_postern.collision_mask = 0
	_postern.prompt_text = "Slip in through the grate's postern"
	_postern.gesture = "open"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.8
	cs.shape = sph
	_postern.add_child(cs)
	_postern.position = Vector3(door.x * (half + 1.2), 1.2, door.y * (half + 1.2))
	_postern.enabled = false
	add_child(_postern)
	_postern.interacted.connect(func(p: Player):
		var inside := to_global(Vector3(door.x * (half - 3.0), 0.4, door.y * (half - 3.0)))
		p.global_position = inside
		p.reset_physics_interpolation()
		Net.fx("sfx", ["rope", inside, -6.0, 0.05]))


func net_event(what: String, args: Array) -> void:
	if what == "reset_shock":
		BossReset.shock_local(self, args[0], float(args[1]), float(args[2]), float(args[3]))


## A captain on their feet in the arena (the downed of a wipe don't start it again where they lie).
func _anyone_inside() -> bool:
	var up: Array = get_node("/root/Net").all_players().filter(func(p): return (p as Player).is_standing())
	if rm.is_empty():
		var reach: float = BOSSES[key]["arena"][1]
		for p in up:
			var d := to_local((p as Node3D).global_position)
			if Vector2(d.x, d.z).length() < reach and absf(d.y) < 6.0:
				return true
		return false
	var r: Rect2 = rm[2]
	for p in up:
		var l := to_local((p as Node3D).global_position)
		if absf(l.x) < r.size.x * 0.5 - 1.4 and absf(l.z) < r.size.y * 0.5 - 1.4 and l.y > -1.0 and l.y < float(rm[4]):
			return true
	return false


## The crew changed mid-fight (host): the boss's health to `k` x its own, keeping the share it has left.
func rescale(k: float) -> void:
	var hc := boss.health_component
	var frac := hc.current_health / maxf(hc.max_health, 1.0)
	_k = k
	boss.hp_k = float(BOSSES[key]["hp"]) * k
	boss._recalc_stats()
	hc.current_health = maxf(frac * hc.max_health, 1.0)


## The boss (host): an Admiralty officer's look under its name, at the room's back facing the door, its weapon (and
## off-hand), the full kit by skill, a boss's health, on the captains.
## Where it stands waiting: the room's back facing the door (the yard's middle for an arena).
func _spawn_at() -> Vector3:
	var door: Vector2 = rm[5] if not rm.is_empty() else Vector2(1, 0)
	var back := -door * (minf((rm[2] as Rect2).size.x, (rm[2] as Rect2).size.y) * 0.3 if not rm.is_empty() else 4.0)
	return to_global(Vector3(back.x, 0.5, back.y))


func _spawn() -> void:
	var b: Dictionary = BOSSES[key]
	var bname := "Boss%s" % key.capitalize()
	var net := get_node("/root/Net")
	boss = isl.city.get_node_or_null(bname) as Player
	if boss and is_instance_valid(boss):
		# (a fight started over after a wipe: the same body, back on the captains)
		var br := boss.get_node_or_null("Brain")
		if br:
			br.order = "fight"
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["boss", key])
	var lk := PirateGrunt.crew_look(rng)
	EnemyShip.marine_look(lk, rng, true)
	lk["name"] = str(b["name"])
	var door: Vector2 = rm[5] if not rm.is_empty() else Vector2(1, 0)
	net.everyone("_all_spawn_rival", [net.key_of(isl.city), bname, lk, str(b["weapon"]), _spawn_at(), atan2(door.x, door.y), float(b["skill"])])
	boss = isl.city.get_node_or_null(bname) as Player
	if boss == null:
		return
	if b.has("offhand"):
		boss.set_offhand(ItemDB.get_item(str(b["offhand"])))
	# (health from hp_k, as the rivals': the stats recalc would undo a max_health set by hand; x the crew's hp_scale)
	_k = float(net.hp_scale())
	boss.hp_k = float(b["hp"]) * _k
	boss._recalc_stats()
	boss.health_component.current_health = boss.health_component.max_health
	var brain := boss.get_node_or_null("Brain")
	if brain:
		brain.order = "fight"
		brain.pace = PACE


# --------------------------------------------------------------------------
# The arena's hazards (phase 2 on): Kesh's molten channels, the Commodore's flaring quarters
# --------------------------------------------------------------------------
## The hazard zones (local xz rects, from the boss's node), one live at a time in turn: Kesh's three channels across
## the Casting Hall, the Commodore's four quarters of the Command Hall. None for a boss without them.
func zones() -> Array:
	var out: Array = []
	if rm.is_empty():
		return out
	var r: Rect2 = rm[2]
	match key:
		"kesh":
			for z: float in CHANNELS:
				out.append(Rect2(-(r.size.x * 0.5 - 2.0), z - CHANNEL_W * 0.5, r.size.x - 4.0, CHANNEL_W))
		"vane":
			var h := r.size.x * 0.5 - 1.6
			for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				out.append(Rect2(Vector2(minf(q.x * h, q.x * 2.0), minf(q.y * h, q.y * 2.0)), Vector2(h - 2.0, h - 2.0)))
	return out


func _build_zones() -> void:
	_warn_m = PSXMat.glow(Color(1.0, 0.45, 0.1), 0.8)
	_burn_m = PSXMat.glow(Color(1.0, 0.35, 0.08), 3.5)
	for z: Rect2 in zones():
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(z.size.x, 0.06, z.size.y)
		mi.mesh = bm
		mi.position = Vector3(z.get_center().x, 0.05, z.get_center().y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_strips.append(mi)


## Vane up on his roof, out of the hall: its quarters rest until he's back down (any machine: the boss is on each).
func away() -> bool:
	if key != "vane" or rm.is_empty():
		return false
	var b := isl.city.get_node_or_null("Boss%s" % key.capitalize()) as Node3D
	return b != null and b.global_position.y > global_position.y + float(rm[4])


## Which zone is live now and how ([index, "warn" / "burn" / ""]): the same on every machine (Ocean.clock).
func channel_now() -> Array:
	if _strips.is_empty() or phase() < 2 or beaten() or away():
		return [-1, ""]
	var t := float(get_node("/root/Ocean").clock())
	var i := int(floor(t / CYCLE)) % _strips.size()
	var u := fmod(t, CYCLE)
	if u < WARN:
		return [i, "warn"]
	if u < WARN + BURN:
		return [i, "burn"]
	return [i, ""]


func _hazards(delta: float) -> void:
	if _strips.is_empty():
		return
	var now := channel_now()
	for k in range(_strips.size()):
		var mi: MeshInstance3D = _strips[k]
		var on: bool = k == int(now[0]) and str(now[1]) != ""
		mi.visible = on
		if on:
			mi.material_override = _burn_m if str(now[1]) == "burn" else _warn_m
	if str(now[1]) != "burn":
		return
	# (our own captain only: each takes their damage on their own machine)
	var me := get_tree().get_first_node_in_group("player") as Player
	if me == null:
		return
	var l := to_local(me.global_position)
	if (zones()[int(now[0])] as Rect2).has_point(Vector2(l.x, l.z)) and l.y < 1.0:
		_hurt -= delta
		if _hurt <= 0.0:
			_hurt = 0.5
			var hd := HitData.new()
			hd.damage = MOLTEN_DPS * 0.5
			hd.dot = true
			me.hurtbox.take_hit(hd, null)


## Kesh's crucible pours: which spot now and how ([index, "warn" / "burn" / ""]), from Ocean.clock (every machine the same).
func pour_now() -> Array:
	if _pour_discs.is_empty() or phase() < 2 or beaten() or not _flag(flag_on()):
		return [-1, ""]
	var t := float(get_node("/root/Ocean").clock())
	var i := int(floor(t / POUR_CYCLE)) % POURS.size()
	var u := fmod(t, POUR_CYCLE)
	if u < POUR_WARN:
		return [i, "warn"]
	if u < POUR_WARN + POUR_BURN:
		return [i, "burn"]
	return [i, ""]


var _pour_discs: Array = []
var _pour_streams: Array = []
var _pour_hurt := 0.0
var _pour_was := ""


## The pours' marks: a glowing disc on the floor at each spot (a warning glow, then the molten pool), and the stream of
## iron falling into it from the crucible's lip (only while it burns).
func _build_pours() -> void:
	for q: Vector2 in POURS:
		var d := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = POUR_R
		cm.bottom_radius = POUR_R
		cm.height = 0.08
		cm.radial_segments = 16
		d.mesh = cm
		d.position = Vector3(q.x, 0.06, q.y)
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.visible = false
		add_child(d)
		_pour_discs.append(d)
		var s := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.5
		sm.bottom_radius = 0.9
		sm.height = float(rm[4]) - 1.0
		sm.radial_segments = 8
		s.mesh = sm
		s.material_override = _burn_m
		s.position = Vector3(q.x, (float(rm[4]) - 1.0) * 0.5, q.y)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.visible = false
		add_child(s)
		_pour_streams.append(s)


func _pours(delta: float) -> void:
	if _pour_discs.is_empty():
		return
	var now := pour_now()
	var i := int(now[0])
	var how := str(now[1])
	for k in range(_pour_discs.size()):
		var on: bool = k == i and how != ""
		(_pour_discs[k] as MeshInstance3D).visible = on
		(_pour_streams[k] as MeshInstance3D).visible = on and how == "burn"
		if on:
			(_pour_discs[k] as MeshInstance3D).material_override = _burn_m if how == "burn" else _warn_m
	if how != _pour_was and i >= 0:
		var at := to_global(Vector3((POURS[i] as Vector2).x, 0.3, (POURS[i] as Vector2).y))
		if how == "warn":
			FX.telegraph(at, POUR_R, POUR_WARN, Color(1.0, 0.45, 0.1))
			FX.sfx("peril", at, 2.0, 0.05, 0.6)
		elif how == "burn":
			FX.splash(at, 12, 1.2)
			FX.sfx("thud", at, 6.0, 0.05, 0.5)
	_pour_was = how
	if how != "burn":
		return
	var me := get_tree().get_first_node_in_group("player") as Player
	if me == null:
		return
	var l := to_local(me.global_position)
	if Vector2(l.x, l.z).distance_to(POURS[i]) < POUR_R and l.y < 1.2:
		_pour_hurt -= delta
		if _pour_hurt <= 0.0:
			_pour_hurt = 0.5
			var hd := HitData.new()
			hd.damage = POUR_DPS * 0.5
			hd.dot = true
			me.hurtbox.take_hit(hd, null)
			BurnStatus.apply(me, 2.0, 0.0, null)


## The phase-2 adds: a sealed-room fight with no grate, armed by this boss's phase 2 flag. Marrow's cell block (one
## wave of berserk prisoners beside the yard); the Commodore's marines pouring into his hall (two waves).
func _build_adds() -> void:
	var b: Dictionary = BOSSES[key]
	var room: Array
	if rm.is_empty():
		room = ["cells_" + key, "The Cell Block", StrongholdActs.CELLS, position.y, 6.0, Vector2(1, 0), 4.0]
	elif key == "vane":
		# (out of the tower's door onto the roof after him, facing the balcony's front)
		room = ["adds_" + key, "The Verdict's roof", StrongholdActs.BALCONY, StrongholdActs.ROOF_Y, 6.0, Vector2(0, 1), 4.0]
	else:
		room = ["adds_" + key, str(rm[1]), rm[2], rm[3], rm[4], rm[5], rm[6]]
	var enc := StrongholdEncounter.new()
	enc.arm_flag = flag_p2()
	enc.sizes = b["adds"]
	enc.waves = (b["adds"] as Array).size()
	enc.prisoners = bool(b.get("prisoners", false))
	enc.setup(isl, room)
	_adds = enc
	isl.city.add_child.call_deferred(enc)


## (the Commodore, phase 3) the Verdict: a second blade, the sharpest of brains, his ultimate charged.
func _enrage() -> void:
	if boss == null:
		return
	var b: Dictionary = BOSSES[key]
	if b.has("offhand3"):
		boss.set_offhand(ItemDB.get_item(str(b["offhand3"])))
	var brain := boss.get_node_or_null("Brain")
	if brain:
		brain.skill = 1.0
	boss.power.ult = PowerComponent.ULT_MAX


## The keep's gate at the Bridge of Judgement's end: its grate down until both seals are the crew's (the Arsenal's and
## the prison's: Kesh and Marrow, in either order). Worked out from the world flags on every machine.
class SealGate extends Node3D:
	const SEALS := ["sh_seal_arsenal", "sh_seal_prison"]
	var _grate: StaticBody3D

	func _ready() -> void:
		name = "SealGate"
		var ky: float = StrongholdPlan.DISTRICTS[4][2]
		position = Vector3(0.0, ky, -49.4)
		var hw: float = StrongholdPlan.WAYS[3][3]
		_grate = StrongholdEncounter.make_grate(["keep_gate", "", Rect2(-hw - 1.0, -0.6, hw * 2.0 + 2.0, 1.2), ky, 15.0, Vector2(0, 1), hw * 2.0 + 1.0])
		_grate.position = Vector3.ZERO
		add_child(_grate)

	func open() -> bool:
		var gm := get_node_or_null("/root/GameManager")
		return gm != null and SEALS.all(func(s): return gm.world_flags.has(s))

	func _process(_d: float) -> void:
		var shut := not open()
		if _grate.visible != shut:
			_grate.visible = shut
			_grate.collision_layer = 1 if shut else 0


## The vault before the Commodore's dais, open once he's beaten (every machine; saved like any chest; an X on the map):
## the stronghold's named legendary (LEGENDARIES by the chain's seed: its kind at LEGENDARY rarity with its trait), the
## vault's Driftfruit (FruitPool.vault; taken once, through the chest's fruit claim), gold and treasure.
func _open_vault() -> void:
	var gm := get_node("/root/GameManager")
	var l: Array = LEGENDARIES[posmod(hash([int(gm.chain_seed), "legendary"]), LEGENDARIES.size())]
	var it := ItemDB.with_trait("%s@%d" % [str(l[1]), ItemData.Rarity.LEGENDARY], str(l[2]))
	it.display_name = str(l[0])
	var vkey := "sh_vault_%d" % int(gm.chain_seed)
	if gm.opened.has(vkey):
		return
	var items: Array = [["gold", 2500], ["treasure", 6]]
	items.push_front([it.id, 1])
	var fruit := FruitPool.vault(get_tree(), int(gm.chain_seed))
	if fruit != "":
		items.push_front([str(DevilFruits.FRUITS[fruit]["item"]), 1])
	CityCaches.place(self, [{"xf": Transform3D(Basis(), VAULT_AT), "key": vkey, "items": items}])
	var bag := get_node("Cache_" + vkey) as Node3D
	MapMarks.put("cache_" + vkey, bag.global_position, "x", "The Commodore's vault")
	bag.tree_exited.connect(func(): MapMarks.clear("cache_" + vkey))
	var what := "%s lies" % str(l[0]) if fruit == "" else "%s and the %s lie" % [str(l[0]), str(DevilFruits.FRUITS[fruit]["name"])]
	get_tree().call_group("hud", "show_banner", "The vault", "%s in the Commodore's vault, before his dais." % what, true)


# --------------------------------------------------------------------------
# Captain Marrow: the seastone net and the catwalks over her yard (1.27, the plan's Prison Tower)
# --------------------------------------------------------------------------
## Her net: every NET_EVERY s (NET_PERCHED from the catwalk) at the nearest captain within NET_REACH; it lands NET_WARN
## s after the throw (Net._all_seastone_net: every captain checks their own); a fruit user caught is powerless
## SEASTONE_SECS.
const NET_EVERY := 9.0
const NET_PERCHED := 4.5
const NET_REACH := 14.0
## The catwalks: a square walk CATWALK_H up round the yard, CATWALK_W wide, two stairs up to it; at half health she leaps
## up onto it for PERCH_SECS and holds it, then drops back into the fight.
const CATWALK_H := 5.5
const CATWALK_W := 1.8
const PERCH_SECS := 12.0
var _net_t := 3.0
var _perched := 0.0


func _marrow(step: float) -> void:
	if boss == null or not is_instance_valid(boss) or not _flag(flag_on()):
		return
	if _perched > 0.0:
		_perched -= step
		if _perched <= 0.0:
			# back down into the yard
			Net.fx("blast", [boss.global_position, Vector3.UP, 1.0, false])
			boss.global_position = global_position + Vector3(0, 0.3, 0)
			boss.reset_physics_interpolation()
			Net.fx("heavy_dust", [boss.global_position, 18, 1.1])
			var br := boss.get_node_or_null("Brain")
			if br:
				br.order = "fight"
	_net_t -= step
	if _net_t > 0.0:
		return
	_net_t = NET_PERCHED if _perched > 0.0 else NET_EVERY
	var best: Node3D = null
	var bd := NET_REACH * (1.6 if _perched > 0.0 else 1.0)
	for p in get_node("/root/Net").all_players():
		var d := (p as Node3D).global_position.distance_to(boss.global_position)
		if d < bd and (p as Player).is_standing():
			bd = d
			best = p
	if best == null:
		return
	FX.speech(boss, ["Seastone. Let's see your tricks now.", "Hold still.", "Into the net!"][randi() % 3])
	get_node("/root/Net").everyone("_all_seastone_net", [best.global_position, boss.global_position + Vector3(0, 1.6, 0)])


## Half health: up onto the catwalk (a leap), holding the high ground a while.
func _perch() -> void:
	var r := float(BOSSES["marrow"]["arena"][1]) * 0.8
	var at := global_position + Vector3(r, CATWALK_H + 0.3, 0)
	Net.fx("heavy_dust", [boss.global_position, 18, 1.1])
	Net.fx("speed_lines", [boss.global_position + Vector3.UP * 2.0, Vector3.UP, Color(0.85, 0.8, 0.7), 12])
	boss.global_position = at
	boss.reset_physics_interpolation()
	_perched = PERCH_SECS
	_net_t = 1.0
	var br := boss.get_node_or_null("Brain")
	if br:
		br.order = "hold"
	FX.speech(boss, "Come up and get me, if you can climb.")


## The catwalks: four walks in a square round the yard on posts, rails, and two stairs up from the yard floor.
func _build_catwalks() -> void:
	var r := float(BOSSES["marrow"]["arena"][1]) * 0.8
	var wood := PSXMat.lit("planks", Color(0.5, 0.42, 0.32))
	var iron := PSXMat.lit("metal", Color(0.4, 0.42, 0.45))
	var mb := MeshBuilder.new()
	var body := StaticBody3D.new()
	body.name = "Catwalks"
	add_child(body)
	var boxes: Array = []
	for s in range(4):
		var a := s * PI * 0.5
		var c := Vector3(cos(a), 0, sin(a)) * r + Vector3(0, CATWALK_H, 0)
		var along := Vector3(-sin(a), 0, cos(a))
		var bas := Basis(Vector3.UP, -a)
		var size := Vector3(CATWALK_W, 0.18, r * 2.0 + CATWALK_W)
		boxes.append([Transform3D(bas, c), size])
		# the rails on both edges, posts down to the floor at the ends and the middle
		for side in [-1.0, 1.0]:
			var off: Vector3 = Vector3(cos(a), 0, sin(a)) * float(side) * CATWALK_W * 0.5
			mb.add_box(iron, Transform3D(bas, c + off + Vector3(0, 0.55, 0)), Vector3(0.06, 0.06, r * 2.0 + CATWALK_W))
		for k in [-1.0, 0.0, 1.0]:
			var post: Vector3 = c + along * float(k) * r
			mb.add_box(wood, Transform3D(Basis(), Vector3(post.x, CATWALK_H * 0.5, post.z)), Vector3(0.22, CATWALK_H, 0.22))
	# two stairs up, from the yard floor to the walks (opposite corners)
	for s in [0, 2]:
		var a: float = float(s) * PI * 0.5 + PI * 0.25
		var foot := Vector3(cos(a), 0, sin(a)) * (r - 4.5)
		var top := Vector3(cos(a), 0, sin(a)) * (r * 1.15)
		var mid := (foot + top) * 0.5 + Vector3(0, CATWALK_H * 0.5, 0)
		var len := Vector2(top.x - foot.x, top.z - foot.z).length()
		var slope := atan2(CATWALK_H, len)
		var bas := Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3.RIGHT, slope)
		boxes.append([Transform3D(bas, mid), Vector3(1.6, 0.2, sqrt(len * len + CATWALK_H * CATWALK_H))])
	for bx in boxes:
		mb.add_box(wood, bx[0], bx[1])
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = bx[1]
		cs.shape = sh
		cs.transform = bx[0]
		body.add_child(cs)
	var mi := mb.to_instance("CatwalksMesh")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
