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
	"kesh": {"room": "casting", "name": "Lieutenant Varro Kesh", "weapon": "cutlass", "offhand": "pistol", "hp": 6.0,
		"skill": 0.85, "seal": "arsenal", "p2": 0.5},
	# (an open arena, no room: the yard before the prison's drum; at half health the cell block opens on its brutes)
	"marrow": {"arena": [Vector2(-72.0, 5.0), 14.0], "district": 3, "name": "Captain Ilse Marrow", "weapon": "greatsword", "hp": 8.0,
		"skill": 0.9, "seal": "prison", "p2": 0.5, "adds": [4], "prisoners": true},
	# (the end: three phases; at 65% the fortress answers (two waves of marines, the hall's quarters flaring), at 30% the
	# Verdict (a second blade, enraged))
	"vane": {"room": "command", "name": "Commodore Aurel Vane", "weapon": "katana", "offhand": "pistol", "offhand3": "cutlass",
		"hp": 12.0, "skill": 0.9, "seal": "keep", "p2": 0.65, "p3": 0.3, "adds": [5, 5]},
}
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
	["Saint's Knuckle", "hammer", "headsman"], ["Bosun's Promise", "axe", "bloodthirsty"], ["Quiet Tide", "dagger", "venomous"]]

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
	if not rm.is_empty():
		_grate = StrongholdEncounter.make_grate(rm)
		add_child(_grate)
	if BOSSES[key].has("adds"):
		_build_adds()
	_build_zones()
	if key == "marrow":
		_build_catwalks()


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
	_hazards(delta)
	if key == "vane" and not _vault and beaten():
		_vault = true
		_open_vault()
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
		if key == "marrow":
			_perch()
	if key == "marrow":
		_marrow(0.25)
	if phase() == 2 and BOSSES[key].has("p3") and hp <= float(BOSSES[key]["p3"]):
		net.world_flag(flag_p3())
		_enrage()
	if hp <= 0.0:
		net.world_flag(flag_seal())
		net.bounty("commodore" if key == "vane" else "stronghold_officer", boss.global_position, 120.0)


func _anyone_inside() -> bool:
	if rm.is_empty():
		var reach: float = BOSSES[key]["arena"][1]
		for p in get_node("/root/Net").all_players():
			var d := to_local((p as Node3D).global_position)
			if Vector2(d.x, d.z).length() < reach and absf(d.y) < 6.0:
				return true
		return false
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
	var door: Vector2 = rm[5] if not rm.is_empty() else Vector2(1, 0)
	var back := -door * (minf((rm[2] as Rect2).size.x, (rm[2] as Rect2).size.y) * 0.3 if not rm.is_empty() else 4.0)
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


## Which zone is live now and how ([index, "warn" / "burn" / ""]): the same on every machine (Ocean.clock).
func channel_now() -> Array:
	if _strips.is_empty() or phase() < 2 or beaten():
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


## The phase-2 adds: a sealed-room fight with no grate, armed by this boss's phase 2 flag. Marrow's cell block (one
## wave of berserk prisoners beside the yard); the Commodore's marines pouring into his hall (two waves).
func _build_adds() -> void:
	var b: Dictionary = BOSSES[key]
	var room: Array
	if rm.is_empty():
		var c := Vector2(position.x, position.z) + Vector2(-16.0, 0.0)
		room = ["cells_" + key, "The Cell Block", Rect2(c - Vector2(6, 5), Vector2(12, 10)), position.y, 6.0, Vector2(1, 0), 4.0]
	else:
		room = ["adds_" + key, str(rm[1]), rm[2], rm[3], rm[4], rm[5], rm[6]]
	var enc := StrongholdEncounter.new()
	enc.arm_flag = flag_p2()
	enc.sizes = b["adds"]
	enc.waves = (b["adds"] as Array).size()
	enc.prisoners = bool(b.get("prisoners", false))
	enc.setup(isl, room)
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


## The vault behind the Commodore's dais, open once he's beaten (every machine; saved like any chest): the stronghold's
## named legendary (LEGENDARIES by the chain's seed: its kind at LEGENDARY rarity with its trait), gold and treasure.
func _open_vault() -> void:
	var gm := get_node("/root/GameManager")
	var l: Array = LEGENDARIES[posmod(hash([int(gm.chain_seed), "legendary"]), LEGENDARIES.size())]
	var it := ItemDB.with_trait("%s@%d" % [str(l[1]), ItemData.Rarity.LEGENDARY], str(l[2]))
	if it:
		it.display_name = str(l[0])
	var items: Array = [["gold", 2500], ["treasure", 6]]
	if it:
		items.push_front([it.id, 1])
	CityCaches.place(self, [{"xf": Transform3D(Basis(), Vector3(6.0, 0.0, -17.0)), "key": "sh_vault_%d" % int(gm.chain_seed), "items": items}])
	get_tree().call_group("hud", "show_banner", "The vault", "%s lies in the Commodore's vault." % str(l[0]), true)


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
