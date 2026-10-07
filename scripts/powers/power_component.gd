class_name PowerComponent
extends Node
## Skills and Devil Fruit power: the skill bar loadout (keys 1-4 + R for an
## ultimate), energy, cooldowns, the ultimate's charge, timed buffs (Tekkai,
## Haki, Howl...), which Devil Fruit you've eaten (if any), and the shared
## damage helpers skills use (blasts, burning, rooting, setting brush alight).
##
## Energy refills over time and with every melee hit; the ultimate charges from
## damage dealt. A Devil Fruit user's fruit skills fizzle in the sea (waist
## deep or more) and their energy stops refilling there.

signal fruit_changed(id: String)
## A cast was refused (slot, reason) - the HUD flashes the slot.
signal cast_failed(slot: int, reason: String)
signal cast(slot: int)
signal loadout_changed
## Energy just spent on a cast (the HUD orb shows a draining chip).
signal energy_spent(amount: float)

const BASE_ENERGY := 100.0
## Energy is mostly earned by fighting: it trickles back slowly (and not at
## all for a moment after a cast), and every melee hit gives a chunk.
const ENERGY_REGEN := 2.5          # per second
const REGEN_DELAY := 1.5           # seconds after a cast before it refills
const ENERGY_PER_HIT := 5.0        # per melee hit
const ULT_MAX := 100.0
const ULT_PER_DAMAGE := 0.3
## The ultimate's own damage (and its burning ground) doesn't recharge it.
const ULT_LOCK := 6.0
## Waist deep: powers fizzle.
const FIZZLE_DEPTH := 0.9
const SLOTS := 5

var player: Player
var fruit: String = ""
var energy: float = BASE_ENERGY
var ult: float = 0.0
## Skill ids on keys 1-4 and R ("" = empty).
var loadout: Array[String] = ["", "", "", "", ""]
var cooldowns: Dictionary = {}     # skill id -> seconds left
var cooldown_len: Dictionary = {}  # skill id -> full cooldown
var buffs: Dictionary = {}         # name -> seconds left
var _ult_lock: float = 0.0
var _regen_wait: float = 0.0


func _ready() -> void:
	player = get_parent() as Player


func has_fruit() -> bool:
	return fruit != ""


func fruit_data() -> Dictionary:
	return DevilFruits.get_fruit(fruit)


func fruit_type() -> String:
	return str(fruit_data().get("type", ""))


func max_energy() -> float:
	return BASE_ENERGY + (player.progression.stat("max_energy") if player else 0.0)


## The skill on a slot (with its id), or {}. Shared: read it, don't change it.
func skill(slot: int) -> Dictionary:
	if slot < 0 or slot >= SLOTS or loadout[slot] == "":
		return {}
	var id: String = loadout[slot]
	if not _skill_dicts.has(id):
		var d := Skills.get_skill(id).duplicate()
		d["id"] = id
		_skill_dicts[id] = d
	return _skill_dicts[id]


var _skill_dicts: Dictionary = {}


func cooldown_left(slot: int) -> float:
	return float(cooldowns.get(loadout[slot], 0.0)) if slot >= 0 and slot < SLOTS else 0.0


func cooldown_total(slot: int) -> float:
	return float(cooldown_len.get(loadout[slot], 1.0)) if slot >= 0 and slot < SLOTS else 1.0


## Put a skill on a slot (ultimates only go on R, others only on 1-4). A skill
## already on another slot moves.
func equip(skill_id: String, slot: int) -> bool:
	if skill_id != "" and (Skills.is_ult(skill_id) != (slot == 4)):
		return false
	if skill_id != "" and player and not player.progression.knows(skill_id):
		return false
	for i in range(SLOTS):
		if loadout[i] == skill_id:
			loadout[i] = ""
	loadout[slot] = skill_id
	loadout_changed.emit()
	return true


## A newly learned skill goes on the first free slot.
func auto_equip(skill_id: String) -> void:
	if skill_id in loadout:
		return
	if Skills.is_ult(skill_id):
		if loadout[4] == "":
			equip(skill_id, 4)
		return
	for i in range(4):
		if loadout[i] == "":
			equip(skill_id, i)
			return


## Eat a fruit: the powers are yours (and the sea is no longer your friend).
func eat(id: String) -> void:
	fruit = id
	energy = max_energy()
	ult = ULT_MAX * 0.5
	if player:
		player.progression.grant_fruit(id)
	fruit_changed.emit(id)


## In the sea, a Devil Fruit user's power drains away.
func suppressed() -> bool:
	if player == null or not has_fruit():
		return false
	return player.is_swimming() or player.water_depth() > FIZZLE_DEPTH


func buff(name_: String) -> bool:
	return float(buffs.get(name_, 0.0)) > 0.0


func add_buff(name_: String, secs: float) -> void:
	buffs[name_] = maxf(float(buffs.get(name_, 0.0)), secs)


## Why a slot can't be used right now ("" = it can).
func can_cast(slot: int) -> String:
	var sk := skill(slot)
	if sk.is_empty():
		return "Empty"
	var fr := str(sk.get("fruit", ""))
	if fr != "" and fr != fruit:
		return "Needs the %s" % str(DevilFruits.get_fruit(fr).get("name", "fruit"))
	if fr != "" and suppressed():
		return "Your power fizzles in the sea"
	if player.is_swimming():
		return "Not while swimming"
	var needs := str(sk.get("needs", ""))
	if needs == "sword" and player.weapon_class() != "sword":
		return "Needs a sword"
	if needs == "gun" and player.weapon_class() != "gun":
		return "Needs a pistol"
	if cooldown_left(slot) > 0.0:
		return "Not ready"
	if slot == 4:
		if ult < ULT_MAX:
			return "Ultimate not charged"
	elif energy < float(sk.get("cost", 0.0)):
		return "Not enough energy"
	if not player.is_free() and player.current_state_name() not in ["LightAttack", "HeavyAttack", "Dodge", "Shoot"]:
		return "Busy"
	return ""


func try_cast(slot: int) -> bool:
	var why := can_cast(slot)
	if why != "":
		cast_failed.emit(slot, why)
		return false
	var sk := skill(slot)
	var id := str(sk["id"])
	if slot == 4:
		ult = 0.0
		_ult_lock = ULT_LOCK
	else:
		var c := float(sk.get("cost", 0.0))
		energy = maxf(energy - c, 0.0)
		_regen_wait = REGEN_DELAY
		energy_spent.emit(c)
	cooldowns[id] = float(sk.get("cooldown", 1.0))
	cooldown_len[id] = cooldowns[id]
	var needs := str(sk.get("needs", ""))
	if needs != "" and not player.armed:
		player.draw_weapon(true)
	player.state_machine.force_state("Skill", {"slot": slot, "id": id})
	cast.emit(slot)
	return true


func _process(delta: float) -> void:
	_ult_lock = maxf(_ult_lock - delta, 0.0)
	for k in cooldowns.keys():
		cooldowns[k] = maxf(float(cooldowns[k]) - delta, 0.0)
	for k in buffs.keys():
		buffs[k] = maxf(float(buffs[k]) - delta, 0.0)
	_regen_wait = maxf(_regen_wait - delta, 0.0)
	if not suppressed() and player and _regen_wait <= 0.0:
		var regen := ENERGY_REGEN * (1.0 + player.progression.stat("energy_regen_pct"))
		energy = minf(energy + regen * delta, max_energy())


## A fruit power just finished: its colors linger on you for a moment.
func linger(skill_id: String) -> void:
	var fr := str(Skills.get_skill(skill_id).get("fruit", ""))
	if fr != "" and player and player.body_model:
		Net.fx("power_aura", [player.body_model, fr, 2.5])


func add_energy(amount: float) -> void:
	if player:
		energy = clampf(energy + amount, 0.0, max_energy())


func add_ult(damage: float) -> void:
	if _ult_lock <= 0.0 and player and loadout[4] != "":
		var k := 1.0 + player.progression.stat("ult_charge_pct")
		ult = minf(ult + damage * ULT_PER_DAMAGE * k, ULT_MAX)


## A melee hit landed (energy, ultimate charge, Kindled Blade sears).
func on_sword_hit(target: Node, hit: HitData) -> void:
	if target == null:
		return
	add_energy(ENERGY_PER_HIT)
	add_ult(hit.damage)
	if fruit == "ember" and player.progression.has_flag("kindled_blade") and target is Node3D and not suppressed():
		BurnStatus.apply(target as Node3D, 1.6, 5.0, player)


func to_dict() -> Dictionary:
	return {"fruit": fruit, "energy": energy, "ult": ult, "loadout": loadout.duplicate()}


func from_dict(d: Dictionary) -> void:
	fruit = str(d.get("fruit", ""))
	energy = float(d.get("energy", BASE_ENERGY))
	ult = float(d.get("ult", 0.0))
	var lo: Array = d.get("loadout", [])
	for i in range(SLOTS):
		loadout[i] = str(lo[i]) if i < lo.size() else ""
	fruit_changed.emit(fruit)
	loadout_changed.emit()


# --------------------------------------------------------------------------
# Damage helpers
# --------------------------------------------------------------------------
## Living enemies whose hurtboxes are within `radius` of `center`.
func enemies_in(center: Vector3, radius: float) -> Array:
	var out: Array = []
	if player == null or not player.is_inside_tree():
		return out
	# co-op: another player's fireballs and slashes here are only for show
	# (their own machine deals the damage)
	if not player.is_local:
		return out
	var space := player.get_world_3d().direct_space_state
	var sq := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	sq.shape = sph
	sq.transform = Transform3D(Basis.IDENTITY, center)
	sq.collision_mask = 32
	sq.collide_with_areas = true
	sq.collide_with_bodies = false
	for r in space.intersect_shape(sq, 32):
		var hb := r["collider"] as Hurtbox
		if hb == null or hb.owner == null or not (hb.owner is Node3D):
			continue
		if hb.owner in out or not BurnStatus.alive(hb.owner):
			continue
		out.append(hb.owner)
	return out


## Hit everything in range with `hd` (knockback pushes away from the center)
## and set it burning. Returns the enemies hit.
func blast(center: Vector3, radius: float, hd: HitData, burn_secs: float = 0.0, burn_dps: float = 0.0, exclude: Array = []) -> Array:
	var hit_list: Array = []
	for e in enemies_in(center, radius):
		if e in exclude:
			continue
		var hb := e.get("hurtbox") as Hurtbox
		if hb == null:
			continue
		# the hit's attacker position decides the push direction: use a proxy
		# at the blast center so everything flies outward
		_proxy.global_position = Vector3(center.x, (e as Node3D).global_position.y, center.z)
		var h2 := hd.duplicate() as HitData
		h2.damage = roundf(hd.damage * power_multiplier())
		hb.take_hit(h2, _proxy)
		add_ult(hd.damage)
		if burn_secs > 0.0:
			BurnStatus.apply(e as Node3D, burn_secs, burn_dps, player)
		hit_list.append(e)
	return hit_list


## Burning ground: damage-over-time to everyone inside (no flinch).
func burn_area(center: Vector3, radius: float, damage: float, burn_secs: float, burn_dps: float) -> void:
	for e in enemies_in(center, radius):
		var hb := e.get("hurtbox") as Hurtbox
		if hb == null:
			continue
		var hd := HitData.new()
		hd.dot = true
		hd.damage = roundf(damage * power_multiplier())
		hd.knockback_force = 0.0
		hb.take_hit(hd, player)
		add_ult(hd.damage)
		BurnStatus.apply(e as Node3D, burn_secs, burn_dps, player)


## Damage scaling for powers (fruit skills, blasts, burning ground).
func power_multiplier() -> float:
	if player == null:
		return 1.0
	var pr := player.progression
	var m := 1.0 + pr.stat("damage_pct") + float(pr.level - 1) * 0.02
	if fruit == "ember":
		m += pr.stat("fire_pct")
	if buff("coat"):
		m += 0.3
	if buff("howl"):
		m += 0.25
	return m


## Tie an enemy in place (Vine Snare).
func root_enemy(e: Node3D, secs: float) -> void:
	if e and e.has_method("rooted"):
		e.call("rooted", secs)


func ignite_burnables(center: Vector3, radius: float) -> void:
	if player == null or not player.is_local:
		return
	for b in player.get_tree().get_nodes_in_group("burnable"):
		var bn := b as Burnable
		if bn == null or bn.burned:
			continue
		# distance to the brush's footprint box
		var local := bn.global_transform.affine_inverse() * center
		var half := bn.size * 0.5
		var c := Vector3(clampf(local.x, -half.x, half.x), clampf(local.y, 0.0, bn.size.y), clampf(local.z, -half.z, half.z))
		if c.distance_to(local) <= radius:
			bn.ignite()


var _proxy_node: Node3D
var _proxy: Node3D:
	get:
		if _proxy_node == null or not is_instance_valid(_proxy_node):
			_proxy_node = Node3D.new()
			_proxy_node.name = "BlastOrigin"
			player.get_tree().current_scene.add_child(_proxy_node)
		return _proxy_node
