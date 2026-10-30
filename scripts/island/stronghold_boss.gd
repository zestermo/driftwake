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

const BOSSES := {
	"kesh": {"room": "casting", "name": "Lieutenant Varro Kesh", "weapon": "cutlass", "offhand": "pistol", "hp": 6.0,
		"skill": 0.85, "seal": "arsenal", "p2": 0.5},
}
## The molten channels (Kesh's phase 2): across the room at these offsets from its middle, each this wide; one at a
## time in turn every CYCLE s: WARN s of glow, then BURN s of burning; MOLTEN_DPS to a captain standing in it.
const CHANNELS := [-9.0, 0.0, 9.0]
const CHANNEL_W := 3.0
const CYCLE := 6.0
const WARN := 1.5
const BURN := 3.0
const MOLTEN_DPS := 18.0

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


func setup(island: Node3D, boss_key: String) -> StrongholdBoss:
	isl = island
	key = boss_key
	name = "Boss_" + key
	for r in StrongholdPlan.ROOMS:
		if str(r[0]) == str(BOSSES[key]["room"]):
			rm = r
	var c: Vector2 = (rm[2] as Rect2).get_center()
	position = Vector3(c.x, float(rm[3]), c.y)
	return self


func _ready() -> void:
	_grate = StrongholdEncounter.make_grate(rm)
	add_child(_grate)
	if key == "kesh":
		_build_channels()


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


func phase() -> int:
	return 2 if _flag(flag_p2()) else 1


## The grate's down while the fight is on and the seal not yet taken.
func grate_shut() -> bool:
	return _flag(flag_on()) and not beaten()


func _process(delta: float) -> void:
	var shut := grate_shut()
	if _grate.visible != shut:
		_grate.visible = shut
		_grate.collision_layer = 1 if shut else 0
	_hazards(delta)
	if not get_node("/root/Net").is_host() or beaten():
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
	var net := get_node("/root/Net")
	if not _flag(flag_on()):
		if _anyone_inside():
			_spawn()
			net.world_flag(flag_on())
		return
	if boss == null or not is_instance_valid(boss):
		boss = isl.city.get_node_or_null("Boss%s" % key.capitalize()) as Player
		if boss == null:
			_spawn()
			return
	var hp := boss.health_component.current_health / maxf(boss.health_component.max_health, 1.0)
	if phase() == 1 and hp <= float(BOSSES[key]["p2"]):
		net.world_flag(flag_p2())
	if hp <= 0.0:
		net.world_flag(flag_seal())


func _anyone_inside() -> bool:
	var r: Rect2 = rm[2]
	for p in get_node("/root/Net").all_players():
		var l := to_local((p as Node3D).global_position)
		if absf(l.x) < r.size.x * 0.5 - 1.4 and absf(l.z) < r.size.y * 0.5 - 1.4 and l.y > -1.0 and l.y < float(rm[4]):
			return true
	return false


## The boss (host): an Admiralty officer's look under its name, at the room's back facing the door, its weapon (and
## off-hand), the full kit by skill, a boss's health, on the captains.
func _spawn() -> void:
	var b: Dictionary = BOSSES[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["boss", key])
	var lk := PirateGrunt.crew_look(rng)
	EnemyShip.marine_look(lk, rng, true)
	lk["name"] = str(b["name"])
	var door: Vector2 = rm[5]
	var r: Rect2 = rm[2]
	var back := -door * (minf(r.size.x, r.size.y) * 0.3)
	var at := to_global(Vector3(back.x, 0.5, back.y))
	var net := get_node("/root/Net")
	var bname := "Boss%s" % key.capitalize()
	net.everyone("_all_spawn_rival", [net.key_of(isl.city), bname, lk, str(b["weapon"]), at, atan2(door.x, door.y), float(b["skill"])])
	boss = isl.city.get_node_or_null(bname) as Player
	if boss == null:
		return
	if b.has("offhand"):
		boss.set_offhand(ItemDB.get_item(str(b["offhand"])))
	# (health from hp_k, as the rivals': the stats recalc would undo a max_health set by hand)
	boss.hp_k = float(b["hp"])
	boss._recalc_stats()
	boss.health_component.current_health = boss.health_component.max_health
	var brain := boss.get_node_or_null("Brain")
	if brain:
		brain.order = "fight"


# --------------------------------------------------------------------------
# Kesh's molten channels
# --------------------------------------------------------------------------
func _build_channels() -> void:
	var r: Rect2 = rm[2]
	_warn_m = PSXMat.glow(Color(1.0, 0.45, 0.1), 0.8)
	_burn_m = PSXMat.glow(Color(1.0, 0.35, 0.08), 3.5)
	for z: float in CHANNELS:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(r.size.x - 4.0, 0.06, CHANNEL_W)
		mi.mesh = bm
		mi.position = Vector3(0, 0.05, z)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_strips.append(mi)


## Which channel is live now and how ([index, "warn" / "burn" / ""]): the same on every machine (Ocean.clock).
func channel_now() -> Array:
	if key != "kesh" or phase() < 2 or beaten():
		return [-1, ""]
	var t := float(get_node("/root/Ocean").clock())
	var i := int(floor(t / CYCLE)) % CHANNELS.size()
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
	var r: Rect2 = rm[2]
	if absf(l.z - float(CHANNELS[int(now[0])])) < CHANNEL_W * 0.5 and absf(l.x) < r.size.x * 0.5 - 2.0 and l.y < 1.0:
		_hurt -= delta
		if _hurt <= 0.0:
			_hurt = 0.5
			var hd := HitData.new()
			hd.damage = MOLTEN_DPS * 0.5
			hd.dot = true
			me.hurtbox.take_hit(hd, null)
