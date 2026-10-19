class_name TraitMoves
extends RefCounted
## What the weapon traits (WeaponTraits) do in play. Hooks: Player.melee_hit (shape: finisher / heavy),
## PowerComponent.on_sword_hit (landed), the Dodge and Parry states, ShootState (shape_shot) and the
## running cut (LightAttack: rush_k). They all run on the captain's own machine; what others must see
## goes through Net.fx, and the hits through the hurtboxes' own routing to the host.

## Seconds before the same trait's name floats up again.
const PROC_GAP := 1.0


## The tier of the best weapon in hand carrying trait `id` (-1: none).
static func tier_of(p: Player, id: String) -> int:
	if p.hybrid:
		return -1
	var best := -1
	for w in [p.equipped_weapon, p.offhand_weapon]:
		if w and (w as ItemData).weapon_trait == id:
			best = maxi(best, int((w as ItemData).rarity))
	return best


static func _proc(p: Player, id: String, at: Vector3) -> void:
	var key := "trait_proc_" + id
	var now := PlayerState.now_s()
	if now - float(p.get_meta(key, -10.0)) < PROC_GAP:
		return
	p.set_meta(key, now)
	var t := tier_of(p, id)
	Net.fx("float_text", [at, WeaponTraits.title(id) + "!", ItemData.RARITY_COLORS[maxi(t, WeaponTraits.MIN_TIER)], 22])


static func _fwd(p: Player) -> Vector3:
	var f := -p.player_model.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


static func _k(t: int) -> float:
	return WeaponTraits.power(t)


## Player.melee_hit: a finisher or heavy shaped by the traits in hand (at the moment it strikes).
static func shape(p: Player, h: HitData, kind: String) -> void:
	if not p.is_local:
		return
	var head := p.global_position + Vector3(0, 2.2, 0)
	if kind == "finisher":
		var t := tier_of(p, "serrated")
		if t >= 0:
			h.set_meta("bleed", 5.0 * _k(t))
			_proc(p, "serrated", head)
		t = tier_of(p, "bloodthirsty")
		if t >= 0:
			h.set_meta("trait_leech", 0.05 * _k(t))
		t = tier_of(p, "gale")
		if t >= 0:
			var f := _fwd(p)
			var pr := Projectile.launch(p.get_tree(), "slash", p.global_position + Vector3(0, 1.1, 0) + f * 0.8, f, p, roundf(h.damage * 0.7 * _k(t)))
			pr.range_m = 9.0
			_proc(p, "gale", head)
	elif kind == "heavy":
		var t := tier_of(p, "headsman")
		if t >= 0:
			h.set_meta("trait_exec", _k(t))
		t = tier_of(p, "thundering")
		# (once a heavy: the whirlwind's second turn makes a second hit)
		if t >= 0 and PlayerState.now_s() - float(p.get_meta("trait_thunder", -10.0)) > 0.8:
			p.set_meta("trait_thunder", PlayerState.now_s())
			_shockwave(p, p.global_position + _fwd(p) * 1.2, 3.5, h.damage * 0.4 * _k(t))
			_proc(p, "thundering", head)


static func _shockwave(p: Player, at: Vector3, r: float, dmg: float) -> void:
	for e in p.power.enemies_in(at + Vector3(0, 0.9, 0), r):
		var hb := (e as Node).get("hurtbox") as Hurtbox
		if hb == null:
			continue
		var hd := HitData.new()
		hd.damage = roundf(dmg)
		hd.knockdown = true
		hd.knockback_force = 9.0
		hd.stagger_duration = 0.6
		hb.take_hit(hd, p)
	Net.fx("ring", [at + Vector3(0, 0.15, 0), Vector3.UP, r, Color(0.75, 0.85, 1.0), 0.32, 0.16])
	Net.fx("dust_ring", [at, 18, 1.2])
	Net.fx("sfx", ["thud", at, 0.0, 0.05, 0.6])
	CombatManager.apply_camera_shake(0.25)
	CombatManager.apply_camera_kick(0.14, 0.3)


## PowerComponent.on_sword_hit: a hit with a trait's mark landed on `target`.
static func landed(p: Player, target: Node, hit: HitData) -> void:
	if not p.is_local or not (target is Node3D):
		return
	var at := (target as Node3D).global_position
	if hit.has_meta("trait_leech") and not hit.has_meta("trait_leeched"):
		hit.set_meta("trait_leeched", true)
		var hc := p.health_component
		hc.heal(hc.max_health * float(hit.get_meta("trait_leech")))
		Net.fx("sparkle", [p.global_position + Vector3(0, 1.1, 0), 10, Color(1.0, 0.3, 0.3)])
		_proc(p, "bloodthirsty", p.global_position + Vector3(0, 2.2, 0))
	if hit.has_meta("trait_exec"):
		var hc = target.get("health")
		var hb := target.get("hurtbox") as Hurtbox
		if hc is HealthComponent and hb and hc.current_health > 0.0 and hc.current_health < hc.max_health / 3.0:
			var fin := HitData.new()
			fin.dot = true
			fin.damage = roundf(hit.damage * float(hit.get_meta("trait_exec")))
			hb.take_hit(fin, p)
			_proc(p, "headsman", at + Vector3(0, 2.3, 0))
	if hit.has_meta("trait_blast"):
		for e in p.power.enemies_in(at + Vector3(0, 0.9, 0), 2.5):
			var hb2 := (e as Node).get("hurtbox") as Hurtbox
			if hb2 == null or e == target:
				continue
			var hd := HitData.new()
			hd.damage = roundf(hit.damage * 0.6 * float(hit.get_meta("trait_blast")))
			hd.knockdown = true
			hd.knockback_force = 8.0
			hd.ranged = true
			hb2.take_hit(hd, p)
		Net.fx("blast", [at + Vector3(0, 1.0, 0), Vector3.UP, 0.9])
		Net.fx("sfx", ["thud", at, -2.0, 0.05, 0.9])
		CombatManager.apply_camera_shake(0.12)
		_proc(p, "blasting", at + Vector3(0, 2.3, 0))


## ShootState: a pistol ball, shaped as it leaves (`last`: the load's last ball).
static func shape_shot(p: Player, hd: HitData, last: bool) -> void:
	var t := tier_of(p, "hair_trigger")
	if t >= 0 and PlayerState.now_s() - float(p.get_meta("trait_dodged", -10.0)) < 1.0:
		if not hd.has_meta("crit"):
			hd.damage *= 1.5 * _k(t)
			hd.set_meta("crit", true)
		hd.knockdown = true
		hd.knockback_force = 7.0
		_proc(p, "hair_trigger", p.global_position + Vector3(0, 2.2, 0))
	t = tier_of(p, "blasting")
	if t >= 0 and last:
		hd.set_meta("trait_blast", _k(t))
		hd.knockdown = true


## DodgeState: a roll began.
static func on_dodge(p: Player) -> void:
	p.set_meta("trait_dodged", PlayerState.now_s())
	var t := tier_of(p, "embered")
	if t < 0:
		return
	var dps := 8.0 * _k(t)
	FireZone.spawn(p.get_tree(), p.global_position, 1.2, 3.0, dps, p)
	p.get_tree().create_timer(0.2, false, true).timeout.connect(func():
		if is_instance_valid(p):
			FireZone.spawn(p.get_tree(), p.global_position, 1.2, 3.0, dps, p))
	_proc(p, "embered", p.global_position + Vector3(0, 2.2, 0))


## ParryState: a clean parry of `attacker`'s blow.
static func on_parry(p: Player, attacker: Node) -> void:
	var t := tier_of(p, "duellist")
	if t < 0 or not (attacker is Node3D):
		return
	var hb := attacker.get("hurtbox") as Hurtbox
	if hb == null:
		return
	var hd := p.melee_hit(16.0 * _k(t))
	hd.stagger_duration = 0.9
	hd.knockback_force = 6.0
	hd.breaker = true
	hb.take_hit(hd, p)
	Net.fx("slash", [p.player_model, "right", 0.22, Color(1.0, 0.9, 0.6)])
	Net.fx("sfx", ["whoosh", p.global_position, -4.0, 0.08, 1.3])
	_proc(p, "duellist", (attacker as Node3D).global_position + Vector3(0, 2.3, 0))


## LightAttack's running cut: how much further it drives (1: no Rushing in hand).
static func rush_k(p: Player) -> float:
	if tier_of(p, "rushing") < 0:
		return 1.0
	_proc(p, "rushing", p.global_position + Vector3(0, 2.2, 0))
	return 2.0
