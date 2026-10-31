class_name PowerComponent
extends Node
## Skills and Devil Fruit power: the skill bar loadout (keys 1-5 + R for an
## ultimate), energy, cooldowns, the ultimate's charge, timed buffs (Tekkai,
## Haki, Howl...), which Devil Fruit you've eaten (if any), and the shared
## damage helpers skills use (blasts, burning, rooting, setting brush alight).
##
## One bar across the weapon loadouts: a weapon's skill goes on it while that weapon is in a loadout,
## and using it with another weapon in hand takes that loadout up first. Locked in a boss fight.
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
## Loadout slots: 0-3 on keys 1-4, the ultimate (ULT) on R, slot 5 on key 5 (it came later,
## so saves keep the ultimate where it was).
const SLOTS := 6
const ULT := 4
## The slot on each number key 1-5.
const KEYS := [0, 1, 2, 3, 5]
## Mastered Foresight (a stance): one automatic dodge every this many seconds,
## for this much energy a second.
const STANCE_EVERY := 3.0
const STANCE_DRAIN := 2.0
const REFLEX_COOLDOWN := 15.0
const SHADOW_STEP_COST := 8.0
## (1.27) Ember's Flicker: how long blows pass through.
const FLICKER_SECS := 1.5
## (1.27) A fruit's awakened state (Ember's Sunborn).
const AWAKENED_SECS := 30.0
## (1.27) Iron Guard's Active form: how long the iron skin lasts.
const IRON_GUARD_SECS := 3.0
## Buffs that are Will (an aura in the captain's Will colour when they start).
const WILL_BUFFS := ["coat", "foresight"]
## Emission (Iron Will tier 2): a coated heavy attack strikes EMIT_RANGE m ahead (a line EMIT_WIDE m across) or a
## ring EMIT_RING m round, EMIT_AFTER s into the swing, for EMIT_DAMAGE.
const EMIT_RANGE := 6.0
const EMIT_WIDE := 1.6
const EMIT_RING := 4.0
const EMIT_AFTER := 0.22
const EMIT_DAMAGE := 18.0
## Stomp (Emission's third version): the quake's reach round you.
const STOMP_RING := 3.5

var player: Player
var fruit: String = ""
var energy: float = BASE_ENERGY
var ult: float = 0.0
## Skill ids on the slots ("" = empty).
var loadout: Array[String] = ["", "", "", "", "", ""]
## (1.27) The fruit stance (V, any fruit): while it's on, `loadout` IS the fruit's loadout (its powers on the keys) and
## the weapon's waits in `other_loadout`; toggling swaps them, so everything that reads the bar follows.
var fruit_stance := false
var other_loadout: Array[String] = ["", "", "", "", "", ""]
var cooldowns: Dictionary = {}     # skill id -> seconds left
var cooldown_len: Dictionary = {}  # skill id -> full cooldown
var buffs: Dictionary = {}         # name -> seconds left
## Foresight: attacks it will still dodge while the buff lasts; mastered, the stance.
var foresight_charges: int = 0
var foresight_stance: bool = false
var _stance_ready: float = 0.0
var _reflex_cd: float = 0.0
var _ryuo_cd: float = 0.0
## Will (WillPaths): Second Sight's extra Foresight dodges left; Emission's heavy attack already struck (and its delay).
var _fore_extra: int = 0
var _emit_t: float = -1.0
var _emit_done := false
## skill id -> seconds left to cast it again for free (Soru's Double Step)
var _free_recast: Dictionary = {}
var _ult_lock: float = 0.0
var _regen_wait: float = 0.0
## The 1.24 Will paths at work (WillPowers).
var will: WillPowers


func _ready() -> void:
	player = get_parent() as Player
	will = WillPowers.new()
	will.name = "Will"
	add_child(will)


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


## The key a slot is on ("1".."5", "R").
static func key_of(slot: int) -> String:
	return "R" if slot == ULT else str(KEYS.find(slot) + 1)


## Where a skill is used from (loadout_for): the hands (it needs no weapon, or the one in hand fits), or
## no loadout fits; otherwise the loadout it switches to.
const HANDS := -1
const NO_LOADOUT := -2


## Does a skill work with a fighting style? (Captain, Will and fruit skills work with anything.)
static func fits(sk: Dictionary, st: String) -> bool:
	var styles: Array = sk.get("styles", [])
	if not styles.is_empty():
		return st in styles
	match str(sk.get("needs", "")):
		"sword":
			return st in ["sword", "katana", "axe", "dagger", "dual_sword", "dual_dagger", "dual_axe", "sword_pistol"]
		"gun":
			return st in ["pistol", "dual_pistol"]
	return true


static func weapon_skill(sk: Dictionary) -> bool:
	return str(sk.get("needs", "")) != "" or not (sk.get("styles", []) as Array).is_empty()


static func needs_text(sk: Dictionary) -> String:
	match str(sk.get("needs", "")):
		"sword":
			return "a sword"
		"gun":
			return "a pistol"
	return str(sk.get("needs_text", "the right weapon"))


## Each weapon loadout's fighting style ("" = it can't be taken up); the one in use is the hands'.
func loadout_styles() -> Array:
	var out: Array = []
	for i in range(Player.LOADOUTS):
		var hands := "black_leg" if player.kicks and player.equipped_weapon == null else Player.style_of(player.equipped_weapon, player.offhand_weapon)
		out.append(hands if i == player.loadout_at else player.loadout_style(i))
	return out


## HANDS, the first loadout whose weapon fits the skill (it switches to that loadout first), or NO_LOADOUT.
static func loadout_for(sk: Dictionary, styles: Array, at: int) -> int:
	if not weapon_skill(sk) or fits(sk, styles[at]):
		return HANDS
	for i in range(styles.size()):
		if styles[i] != "" and fits(sk, styles[i]):
			return i
	return NO_LOADOUT


## A boss this close in a fight locks the bar (the boss music's range).
const BOSS_LOCK_RANGE := 55.0


func boss_fight() -> bool:
	for b in player.get_tree().get_nodes_in_group("bosses"):
		if b.in_combat() and (b as Node3D).global_position.distance_to(player.global_position) < BOSS_LOCK_RANGE:
			return true
	return false


## Why a skill can't go on a slot ("" = it can; "" as the skill clears the slot). The menu shows it.
func equip_why(skill_id: String, slot: int) -> String:
	if boss_fight():
		return "Not during a boss fight"
	if skill_id == "":
		return ""
	if Skills.is_ult(skill_id) and slot != ULT:
		return "Ultimates go on R"
	if not Skills.is_ult(skill_id) and slot == ULT:
		return "Only an ultimate goes on R"
	# (1.26: one ultimate on R, swapped out of a fight)
	if slot == ULT and loadout[ULT] != "" and loadout[ULT] != skill_id and player.in_fight():
		return "Not mid-fight"
	if not player.progression.knows(skill_id):
		return "Not learned yet"
	var sk := Skills.get_skill(skill_id)
	if loadout_for(sk, loadout_styles(), player.loadout_at) == NO_LOADOUT:
		return "Needs %s in a loadout" % needs_text(sk)
	return ""


## Put a skill on a slot (ultimates only go on R, others only on 1-5; a weapon's skill only while that
## weapon is in one of your loadouts). A skill already on another slot moves.
func equip(skill_id: String, slot: int) -> bool:
	if equip_why(skill_id, slot) != "":
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
		if loadout[ULT] == "":
			equip(skill_id, ULT)
		return
	for i in KEYS:
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
	if name_ in WILL_BUFFS and player and player.is_local:
		if name_ == "foresight":
			_fore_extra = int(player.progression.stat("foresight_charges"))
		EdyTypes.burst(player)
		Net.fx("dust_ring", [player.global_position, 10, 0.7])


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
	if player.hybrid and weapon_skill(sk):
		return "Needs %s" % needs_text(sk)
	var at := loadout_for(sk, loadout_styles(), player.loadout_at)
	if at == NO_LOADOUT:
		return "Needs %s in a loadout" % needs_text(sk)
	var free := float(_free_recast.get(str(sk["id"]), 0.0)) > 0.0
	var stance_off := str(sk["id"]) == "foresight" and foresight_stance
	if cooldown_left(slot) > 0.0 and not free and not stance_off:
		return "Not ready"
	if str(sk["id"]) == "will_twin" and will.bond.gauge < WillBond.GAUGE_MAX:
		return "Joint gauge not full"
	if slot == ULT:
		if ult < ULT_MAX:
			return "Ultimate not charged"
	elif energy < float(sk.get("cost", 0.0)) and not free and not stance_off:
		return "Not enough energy"
	if at != HANDS:
		if not player.can_swap_now():
			return "Busy"
	elif not player.is_free() and player.current_state_name() not in ["LightAttack", "HeavyAttack", "Dodge", "Shoot"]:
		return "Busy"
	return ""


func try_cast(slot: int) -> bool:
	# Sea King Fist armed: the ult key lets it go
	if slot == ULT and player.fist_armed > 0.0 and str(skill(slot).get("id", "")) == "sea_king_fist":
		return FistArts.unleash(player)
	var why := can_cast(slot)
	if why != "":
		cast_failed.emit(slot, why)
		return false
	var sk := skill(slot)
	var id := str(sk["id"])
	var at := loadout_for(sk, loadout_styles(), player.loadout_at)
	if at != HANDS:
		player.take_loadout_now(at)
	if id == "foresight" and foresight_stance:
		set_stance(false)
		cast.emit(slot)
		return true
	var tier := player.progression.skill_tier(id)
	if float(_free_recast.get(id, 0.0)) > 0.0:
		_free_recast.erase(id)
	else:
		if slot == ULT:
			ult = 0.0
			_ult_lock = ULT_LOCK
		else:
			var c := float(sk.get("cost", 0.0))
			energy = maxf(energy - c, 0.0)
			_regen_wait = REGEN_DELAY
			energy_spent.emit(c)
		cooldowns[id] = skill_cooldown(id, tier)
		cooldown_len[id] = cooldowns[id]
		if id == "soru" and tier >= 2:
			_free_recast[id] = 1.0
	player.progression.note_use(id)
	# (1.27) the Iron Fruit: Iron Guard (iron skin a while) and Iron Fist (a guard-breaking punch in front of you)
	if id == "iron_guard":
		add_buff("iron_guard", IRON_GUARD_SECS)
		Net.fx("ring", [player.global_position + Vector3.UP, Vector3.UP, 1.2, Color(0.7, 0.72, 0.78), 0.4, 0.15])
		cast.emit(slot)
		return true
	if id == "iron_fist":
		var fwd := -player.player_model.global_basis.z
		fwd.y = 0.0
		var hd := HitData.new()
		hd.damage = 28.0
		hd.knockback_force = 9.0
		hd.stagger_duration = 0.5
		hd.breaker = true
		hd.camera_shake_intensity = 0.3
		blast(player.global_position + Vector3(0, 1.0, 0) + fwd.normalized() * 1.6, 1.8, hd)
		Net.fx("impact", [player.global_position + Vector3(0, 1.2, 0) + fwd.normalized() * 1.4, Color(0.75, 0.78, 0.85)])
		player.body_model.play("punch_r", 0.35)
		cast.emit(slot)
		return true
	# (1.27) Ember's awakening: Sunborn, AWAKENED_SECS of it
	if id == "sunborn":
		add_buff("awakened", AWAKENED_SECS)
		FX.power_aura.call_deferred(player.body_model, "ember", 3.0)
		Net.fx("fire_pillar", [player.global_position, 6.0])
		cast.emit(slot)
		return true
	# (1.27) Ember's Flicker: no state of its own, the flame body for a moment (its forms grow from these uses)
	if id == "flicker":
		add_buff("flicker", FLICKER_SECS)
		Net.fx("flame", [player.global_position + Vector3.UP, 14, 0.7, 0.5, 0.5])
		cast.emit(slot)
		return true
	# (1.26) the Edy tree: a cast counts toward its node's next rank; with Edy Techniques on, a technique carries your Edy
	var en := EdyTree.of_skill(id)
	if en != "":
		EdyTree.use(player, en)
	if str(sk.get("state", "")) == "Technique" and edy_infuse(EDY_TECH_COST):
		add_buff("edy_tech", EDY_TECH_SECS)
		EdyTypes.aura(player, "legs" if player.style() == "black_leg" else "arms", EDY_TECH_SECS)
	var needs := str(sk.get("needs", ""))
	if (needs != "" or not (sk.get("styles", []) as Array).is_empty()) and not player.armed:
		player.draw_weapon(true)
	player.state_machine.force_state(str(sk.get("state", "Skill")), {"slot": slot, "id": id})
	cast.emit(slot)
	return true


## A skill's cooldown at a tier (a tier can set its own).
func skill_cooldown(id: String, tier: int) -> float:
	var sd := Skills.get_skill(id)
	var cd := float(sd.get("cooldown", 1.0))
	for t in range(2, tier + 1):
		cd = float(Skills.tier_def(id, t).get("cooldown", cd))
	if player:
		cd *= 1.0 - player.progression.stat("cdr_" + str(sd.get("tree", "")))
		cd *= 1.0 - player.progression.stat("cdr_" + id)
	return cd


func _process(delta: float) -> void:
	_ult_lock = maxf(_ult_lock - delta, 0.0)
	for k in cooldowns.keys():
		cooldowns[k] = maxf(float(cooldowns[k]) - delta, 0.0)
	for k in buffs.keys():
		buffs[k] = maxf(float(buffs[k]) - delta, 0.0)
	for k in _free_recast.keys():
		_free_recast[k] = maxf(float(_free_recast[k]) - delta, 0.0)
	_reflex_cd = maxf(_reflex_cd - delta, 0.0)
	_ryuo_cd = maxf(_ryuo_cd - delta, 0.0)
	_regen_wait = maxf(_regen_wait - delta, 0.0)
	if buff("coat") and player and player.is_local:
		_tick_emission(delta)
	_ember_aura(delta)
	if foresight_stance:
		_update_stance(delta)
	elif not suppressed() and player and _regen_wait <= 0.0:
		var regen := ENERGY_REGEN * (1.0 + player.progression.stat("energy_regen_pct"))
		energy = minf(energy + regen * delta, max_energy())


# --------------------------------------------------------------------------
# Tier effects
# --------------------------------------------------------------------------
## Mastered Foresight: switch the stance on or off.
func set_stance(on: bool) -> void:
	foresight_stance = on
	_stance_ready = 0.0
	if player:
		player.call("_toast", "Future Sight on" if on else "Future Sight off")


func _update_stance(delta: float) -> void:
	energy = maxf(energy - STANCE_DRAIN * delta, 0.0)
	if energy <= 0.0:
		set_stance(false)
		return
	if _stance_ready > 0.0:
		_stance_ready -= delta
		if _stance_ready <= 0.0 and player:
			Net.fx("sparkle", [player.global_position + Vector3(0, 1.75, 0), 5, Color(0.95, 0.5, 0.8)])


## An attack is about to land: does Foresight see it coming? (uses a charge)
func use_foresight() -> bool:
	if foresight_stance and _stance_ready <= 0.0:
		_stance_ready = STANCE_EVERY
		return true
	if buff("foresight") and foresight_charges > 0:
		foresight_charges -= 1
		if foresight_charges <= 0 and _fore_extra > 0:
			_fore_extra -= 1
			foresight_charges = 1
		if foresight_charges <= 0:
			buffs["foresight"] = 0.0
		return true
	return false


## Mastered Tekkai: a knockdown blow hardens you on the spot instead.
func iron_reflex() -> bool:
	if player == null or _reflex_cd > 0.0 or buff("tekkai") or (player.progression.skill_tier("tekkai") < 3 and player.progression.stat("iron_reflex") <= 0.0):
		return false
	_reflex_cd = REFLEX_COOLDOWN
	add_buff("tekkai", 1.5)
	player.body_model.play("tekkai", 1.5)
	Net.fx("sparkle", [player.global_position + Vector3(0, 1.0, 0), 14, Color(0.7, 0.72, 0.8)])
	Net.fx("sfx", ["hit", player.global_position, -4.0, 0.05, 0.6])
	return true


## Mastered Soru: does this dodge vanish you? (spends the energy if so)
func shadow_step() -> bool:
	if player == null or player.progression.skill_tier("soru") < 3 or energy < SHADOW_STEP_COST:
		return false
	energy -= SHADOW_STEP_COST
	energy_spent.emit(SHADOW_STEP_COST)
	return true


## Mastered Armament: Coat (Ryuo): a coated heavy hit bursts out around the target.
func _ryuo(target: Node3D) -> void:
	_ryuo_cd = 0.3
	var hd := HitData.new()
	hd.damage = 14.0
	hd.knockback_force = 9.0
	hd.stagger_duration = 0.45
	hd.unblockable = true
	hd.haki = true
	var at := target.global_position
	blast(at, 3.2, hd, 0.0, 0.0, [target])
	Net.fx("punch_wind", [at + Vector3.UP * 1.0, Vector3.UP, 0.5, player.progression.will_tint().lightened(0.2), true])
	Net.fx("sparkle", [at + Vector3(0, 1.0, 0), 16, player.progression.will_tint().lightened(0.3)])
	Net.fx("dust_ring", [at, 12, 1.2])
	player.cam_shake(0.16)


## (1.26, the Edy tree's Infusion branch) Edy Techniques: a technique's extra energy and how long its blows carry the
## Edy; Edy Strikes: a plain blow's. Brimming: free above BRIM of your energy.
const EDY_TECH_COST := 2.0
const EDY_TECH_SECS := 2.5
const EDY_STRIKE_COST := 0.5
const BRIM := 0.8


## Pays for an infusion (Edy Techniques when `cost` is EDY_TECH_COST, else Edy Strikes): true if the captain has it on
## and it's paid (Brimming: free while energy is high). The blow then carries the Edy (Player.melee_hit).
func edy_infuse(cost: float) -> bool:
	if player == null:
		return false
	var pr = player.progression
	if pr.stat("edy_tech" if cost == EDY_TECH_COST else "edy_strikes") <= 0.0:
		return false
	if pr.stat("edy_brimming") > 0.0 and energy >= max_energy() * BRIM:
		return true
	if energy < cost:
		return false
	energy -= cost
	_regen_wait = maxf(_regen_wait, 0.5)
	return true


## Emission (Iron Will tier 2, while coated): EMIT_AFTER s into each heavy attack, the Will leaves the blade once.
func _tick_emission(delta: float) -> void:
	if player.current_state_name() != "HeavyAttack":
		_emit_t = 0.0
		_emit_done = false
		return
	var kind := int(player.progression.stat("emission"))
	if _emit_done or kind == 0:
		return
	_emit_t += delta
	if _emit_t < EMIT_AFTER:
		return
	_emit_done = true
	emission(kind)
	EdyTree.use(player, "e_iron_5")


## Emission's strike: 1 a line EMIT_RANGE m straight ahead, 2 a ring EMIT_RING m round you, 3 Stomp's quake. Unblockable Will; the
## effect in the captain's Will colour on every screen. Returns the foes struck.
func emission(kind: int) -> Array:
	var hd := HitData.new()
	hd.damage = EMIT_DAMAGE
	hd.knockback_force = 7.0
	hd.stagger_duration = 0.35
	hd.unblockable = true
	hd.haki = true
	var tint := player.progression.will_tint()
	var at := player.global_position
	if kind == 3:
		# Stomp: a breaker, not unblockable, so a shield or a guard takes it and is knocked aside
		hd.unblockable = false
		hd.breaker = true
		hd.knockback_force = 5.0
		hd.stagger_duration = 0.6
		Net.fx("ring", [at + Vector3(0, 0.1, 0), Vector3.UP, STOMP_RING, tint, 0.3, 0.14])
		Net.fx("heavy_dust", [at, 16, 1.0])
		Net.fx("debris", [at + Vector3(0, 0.1, 0), Vector3.UP, 8, Color(0.42, 0.36, 0.3), 5.0])
		Net.fx("sparkle", [at + Vector3(0, 0.4, 0), 20, tint])
		Net.fx("sfx", ["thud", at, 1.0, 0.05, 0.6])
		player.cam_shake(0.22)
		return blast(at, STOMP_RING, hd)
	if kind == 2:
		Net.fx("dust_ring", [at, 16, EMIT_RING / 3.0])
		Net.fx("sparkle", [at + Vector3(0, 0.8, 0), 26, tint])
		player.cam_shake(0.12)
		return blast(at, EMIT_RING, hd)
	var fwd := -player.player_model.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var struck: Array = []
	for e in enemies_in(at + fwd * EMIT_RANGE * 0.5, EMIT_RANGE * 0.5 + EMIT_WIDE):
		var to: Vector3 = (e as Node3D).global_position - at
		to.y = 0.0
		var along := to.dot(fwd)
		if along < 0.0 or along > EMIT_RANGE + 0.6 or (to - fwd * along).length() > EMIT_WIDE:
			continue
		var hb := e.get("hurtbox") as Hurtbox
		var h2 := hd.duplicate() as HitData
		h2.damage = roundf(hd.damage * power_multiplier())
		hb.take_hit(h2, player)
		add_ult(hd.damage)
		struck.append(e)
	for i in range(1, 4):
		Net.fx("sparkle", [at + fwd * (EMIT_RANGE * i / 3.0) + Vector3(0, 1.0, 0), 10, tint])
	Net.fx("punch_wind", [at + fwd * 0.6 + Vector3.UP, fwd, EMIT_RANGE, tint, true])
	player.cam_shake(0.1)
	return struck


## A fruit power just finished: its colors linger on you for a moment.
func linger(skill_id: String) -> void:
	var fr := str(Skills.get_skill(skill_id).get("fruit", ""))
	if fr != "" and player and player.body_model:
		Net.fx("power_aura", [player.body_model, fr, 2.5])


func add_energy(amount: float) -> void:
	if player:
		energy = clampf(energy + amount, 0.0, max_energy())


func add_ult(damage: float) -> void:
	if _ult_lock <= 0.0 and player and loadout[ULT] != "":
		var k := 1.0 + player.progression.stat("ult_charge_pct")
		ult = minf(ult + damage * ULT_PER_DAMAGE * k, ULT_MAX)


## A weapon hit landed (energy, ultimate charge, mastery, Kindled Blade sears).
func on_sword_hit(target: Node, hit: HitData) -> void:
	# (a crate or barrel struck (Breakable): no energy, ultimate or mastery from the furniture)
	if target == null or target.is_in_group("breakables"):
		return
	var st := player.style()
	var pr := player.progression
	add_energy(ENERGY_PER_HIT * (1.0 + pr.style_stat("flow", st)))
	add_ult(hit.damage)
	player.fought()
	TraitMoves.landed(player, target, hit)
	player.crew_tech.on_hit(target, hit)
	if player.is_local:
		pr.on_hit(target, hit)
		will.landed(hit)
		var leech := pr.style_stat("leech", st)
		if leech > 0.0:
			player.health_component.heal(hit.damage * leech)
		if hit.has_meta("crit") and target is Node3D:
			Net.fx("float_text", [(target as Node3D).global_position + Vector3(0, 2.0, 0), "Crit!", Color(1.0, 0.85, 0.3)])
		# finishing blows: a target left reeling takes extra
		var ex := pr.style_stat("exec", st)
		var hc = target.get("health")
		if ex > 0.0 and hc is HealthComponent and hc.current_health > 0.0 and hc.current_health < hc.max_health * 0.3:
			var hb := target.get("hurtbox") as Hurtbox
			if hb:
				var fin := HitData.new()
				fin.dot = true
				fin.damage = roundf(hit.damage * ex)
				hb.take_hit(fin, player)
	if hit.haki and buff("coat") and _ryuo_cd <= 0.0 and target is Node3D and player.is_local \
			and player.current_state_name() in ["HeavyAttack", "Iai", "Plunge"] and (player.progression.skill_tier("armament_coat") >= 3 or player.progression.has_flag("coat_burst")):
		_ryuo(target as Node3D)
	# an infused heavy blow leaves a burst of the captain's Edy on what it hits
	if buff("coat") and player.is_local and target is Node3D and not hit.dot and player.current_state_name() in ["HeavyAttack", "Iai", "Plunge"]:
		EdyTypes.burst(player, 0.6, (target as Node3D).global_position + Vector3(0, 1.1, 0))
	# the element on every blow (the tree's second mastery passive): combo and heavy hits throw it
	var tree := SkillTree.style_tree(st)
	if player.is_local and tree != "" and target is Node3D and player.progression.elemental(tree, 2) \
			and player.current_state_name() in ["LightAttack", "HeavyAttack", "Plunge", "Iai"]:
		var hit_at := (target as Node3D).global_position + Vector3(0, 1.0, 0)
		var away := hit_at - player.global_position
		away.y = 0.0
		Net.fx("elem_hit", [tree, hit_at, away.normalized() if away.length() > 0.05 else Vector3.FORWARD])
	if player.is_local and target is Node3D and not hit.dot:
		_wounds(target as Node3D, hit, st)
	if fruit == "ember" and (player.progression.has_flag("kindled_blade") or FruitForms.form(player.progression, "fire_fist", "ember") == FruitForms.NATURE) and target is Node3D and not suppressed():
		BurnStatus.apply(target as Node3D, 1.6, 5.0, player)
	if player.is_local and player.armed and target is Node3D:
		var venom := 0.0
		for w in [player.equipped_weapon, player.offhand_weapon]:
			if w:
				venom = maxf(venom, (w as ItemData).poison)
		if venom > 0.0:
			PoisonStatus.apply(target as Node3D, 4.0, venom, player)


## The daggers' wounds: a hit that opens one (HitData meta "bleed": seconds), or by
## chance (the tree's bleed_ nodes; always under Bleeding Edge), makes them bleed;
## a blade in the back (backstab_) deals that share again on top.
func _wounds(target: Node3D, hit: HitData, st: String) -> void:
	var pr := player.progression
	var secs := float(hit.get_meta("bleed", 0.0))
	if secs <= 0.0 and (buff("bleeding_edge") or randf() < pr.style_stat("bleed", st)):
		secs = 3.0
	# (1.27) the Wolf's Rending Fang by its form (FruitForms), claws in hybrid form: Reflex, a crit bleeds; Nature, every claw
	# (1.27) Vine Snare at Nature: every blow slows its target a moment (a brief snare)
	if fruit == "vine" and FruitForms.form(pr, "vine_snare", "vine") == FruitForms.NATURE:
		root_enemy(target, 0.35)
	if fruit == "wolf" and player.hybrid and secs <= 0.0:
		var wf := FruitForms.form(pr, "rending_fang", "wolf")
		if wf == FruitForms.NATURE or (wf == FruitForms.REFLEX and hit.has_meta("crit")):
			secs = 3.0
	if secs > 0.0:
		BleedStatus.apply(target, secs, 2.5 + hit.damage * 0.15, player)
	var bs := pr.style_stat("backstab", st)
	if bs > 0.0 and behind(target):
		var hb := target.get("hurtbox") as Hurtbox
		if hb:
			var extra := HitData.new()
			extra.dot = true
			extra.damage = roundf(hit.damage * bs)
			hb.take_hit(extra, player)
			Net.fx("float_text", [target.global_position + Vector3(0, 2.3, 0), "Backstab!", FX.tree_col("dagger", FX.EDGE)])


## Are you behind `t` (it's facing away from you)?
func behind(t: Node3D) -> bool:
	var fc = t.get("facing")
	if not (fc is Node3D):
		return false
	var yaw := (fc as Node3D).global_rotation.y
	var to_me := player.global_position - t.global_position
	to_me.y = 0.0
	return to_me.length() > 0.01 and Vector3(-sin(yaw), 0.0, -cos(yaw)).dot(to_me.normalized()) < -0.25


func to_dict() -> Dictionary:
	# (saved by what each is, whichever is showing: the weapon's as "loadout", the fruit's as "fruit_loadout")
	var weapon_lo := other_loadout if fruit_stance else loadout
	var fruit_lo := loadout if fruit_stance else other_loadout
	return {"fruit": fruit, "energy": energy, "ult": ult, "loadout": weapon_lo.duplicate(), "fruit_loadout": fruit_lo.duplicate()}


func from_dict(d: Dictionary) -> void:
	fruit = str(d.get("fruit", ""))
	energy = float(d.get("energy", BASE_ENERGY))
	ult = float(d.get("ult", 0.0))
	var lo: Array = d.get("loadout", [])
	for i in range(SLOTS):
		loadout[i] = str(Skills.RENAMED.get(str(lo[i]), lo[i])) if i < lo.size() else ""
	var fl: Array = d.get("fruit_loadout", [])
	for i in range(SLOTS):
		other_loadout[i] = str(fl[i]) if i < fl.size() else ""
	fruit_stance = false
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
	sq.collision_mask = player.foe_mask()
	sq.collide_with_areas = true
	sq.collide_with_bodies = false
	for r in space.intersect_shape(sq, 32):
		var hb := r["collider"] as Hurtbox
		if hb == null or hb.owner == null or not (hb.owner is Node3D):
			continue
		if hb.owner in out or hb.owner.get("hurtbox") == null or not BurnStatus.alive(hb.owner):
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


## (1.27) Into or out of the fruit stance (V with a fruit eaten): the bar swaps to the fruit's powers and back.
func set_fruit_stance(on: bool) -> void:
	if on == fruit_stance or (on and fruit == ""):
		return
	fruit_stance = on
	var keep := loadout.duplicate()
	for i in range(SLOTS):
		loadout[i] = other_loadout[i]
		other_loadout[i] = str(keep[i])
	loadout_changed.emit()


## (1.27) Ember's Blazing Ring at Nature (FruitForms on its uses): an ember aura, burning anyone who stays within
## AURA_R, a little every AURA_EVERY s (our own captain's blows: their machine's).
const AURA_R := 2.4
const AURA_EVERY := 1.0
var _aura_t := 0.0


func _ember_aura(delta: float) -> void:
	if fruit != "ember" or player == null or not player.is_local or suppressed():
		return
	_aura_t -= delta
	if _aura_t > 0.0:
		return
	_aura_t = AURA_EVERY
	if FruitForms.form(player.progression, "fire_ring", "ember") < FruitForms.NATURE and not buff("awakened"):
		return
	var hd := HitData.new()
	hd.damage = 3.0
	hd.knockback_force = 0.0
	hd.stagger_duration = 0.0
	hd.dot = true
	if not blast(player.global_position + Vector3(0, 0.8, 0), AURA_R, hd, 1.0, 2.0).is_empty():
		Net.fx("flame", [player.global_position + Vector3(0, 0.6, 0), 6, 0.6, 0.4, AURA_R * 0.5])
