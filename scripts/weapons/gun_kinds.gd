class_name GunKinds
## The 1.24 ranged weapon kinds (docs/weapons_plan.md, guns family): long guns (style "long_gun": an aimed shot, the
## blunderbuss's scatter, a butt stroke), the cannon ("cannon") and the slingshot ("slingshot"). Each is a weapon_model
## of class "gun" (Player.class_of), two-handed, with its own stance, tree and arts file (LongGunArts...). Shared here:
## which model makes which style, its load and reload, aiming at the reticle, the hitscan line and a blast's splash.

## weapon_model -> fighting style.
const STYLE := {"longgun": "long_gun"}
## Every style these kinds fight in (Player.style()).
const OWN := ["long_gun"]


## A design's number for any of these kinds ("reload", "range", "shots"...; `def` for the base item).
static func design(it: ItemData, key: String, def: float = 1.0) -> float:
	return float((WeaponDesigns.DESIGNS.get(it.weapon_model, {}) as Dictionary).get(it.design, {}).get(key, def))


## The arts file running a style's shots, heavy, air move and techniques.
static func art(style: String) -> Variant:
	match style:
		"long_gun":
			return LongGunArts
	return null


## Loads before a reload (Player.max_ammo for these styles).
static func shots(p: Player) -> int:
	return int(design(p.equipped_weapon, "shots", 1.0)) + int(p.progression.style_stat("shots", p.style()))


## Seconds a reload takes, before the tree and crew bonuses (Player.reload_time).
static func reload_base(p: Player) -> float:
	match p.style():
		"long_gun":
			return LongGunArts.RELOAD * design(p.equipped_weapon, "reload")
	return 1.2


## The action a reload plays.
const RELOAD_ANIM := {"long_gun": "lg_reload"}


## What the bag shows for one (InventoryScreen.weapon_stats): a shot's damage (a full scatter's), shots a second
## through a load and its reload, the range.
static func stats(it: ItemData) -> Dictionary:
	match it.weapon_model:
		"longgun":
			var n := design(it, "spread", 0.0)
			var dmg: float = LongGunArts.PELLET * n if n > 0.0 else LongGunArts.DAMAGE
			var loads := design(it, "shots")
			var rate: float = loads / (loads * LongGunArts.FIRE_LEN + LongGunArts.RELOAD * design(it, "reload"))
			return {"gun": true, "damage": dmg * it.power(), "rate": rate, "range": LongGunArts.RANGE * design(it, "range")}
	return {}


## The bag's lines on what one does.
static func notes(it: ItemData) -> Array:
	match it.weapon_model:
		"longgun":
			if design(it, "spread", 0.0) > 0.0:
				return ["Scatters a cone of shot; hold to tighten it", "Right-click: the butt stroke"]
			return ["Hold to aim: a steady shot pierces", "Right-click: the butt stroke"]
	return []


## Where the reticle points from `from` out to `reach`: the first enemy or solid on the screen-centre ray (started level
## with the captain, so nothing behind them catches it), with a little aim assist onto an enemy just off it in clear view.
static func aim_point(p: Player, from: Vector3, reach: float, assist: float = 0.06) -> Vector3:
	var space := p.get_world_3d().direct_space_state
	var target := from + (-p.player_model.global_basis.z) * reach
	var ray := p.reticle_ray()
	if ray.is_empty():
		return target
	var cd: Vector3 = ray[1]
	var o: Vector3 = ray[0]
	o += cd * maxf((p.global_position - o).dot(cd), 0.0)
	var q := PhysicsRayQueryParameters3D.create(o, o + cd * reach, 1 | 4 | 2048)
	q.exclude = [p.get_rid()]
	var h := space.intersect_ray(q)
	target = (h["position"] as Vector3) if not h.is_empty() else o + cd * reach
	if not h.is_empty() and (h["collider"] as CollisionObject3D).collision_layer & 4 != 0:
		return target
	var best_a := assist
	for e in p.power.enemies_in(p.global_position, reach):
		var hb := (e as Node).get("hurtbox") as Hurtbox
		if hb == null:
			continue
		var c := center(hb)
		var a := cd.angle_to(c - o)
		if a >= best_a:
			continue
		var los := PhysicsRayQueryParameters3D.create(from, c, 1)
		los.exclude = [p.get_rid()]
		if space.intersect_ray(los).is_empty():
			best_a = a
			target = c
	return target


## The middle of a hurtbox's body (the Hurtbox node sits at the feet; its shape is the body).
static func center(hb: Hurtbox) -> Vector3:
	return (hb.get_child(0) as Node3D).global_position


## A shot's line from `from` along `dir` out to `reach`: [end point, the hurtboxes on it in order (up to `n`)]. Walls stop
## it; each hurtbox after the first is looked for past the one before.
static func line(p: Player, from: Vector3, dir: Vector3, reach: float, n: int = 1) -> Array:
	var space := p.get_world_3d().direct_space_state
	var end := from + dir * reach
	var wq := PhysicsRayQueryParameters3D.create(from, end, 1)
	wq.exclude = [p.get_rid()]
	var wall := space.intersect_ray(wq)
	if not wall.is_empty():
		end = wall["position"]
	var hits: Array = []
	var ex: Array = []
	var at := from
	while hits.size() < n:
		var eq := PhysicsRayQueryParameters3D.create(at, end, p.foe_mask())
		eq.collide_with_areas = true
		eq.collide_with_bodies = false
		eq.exclude = ex
		var h := space.intersect_ray(eq)
		if h.is_empty() or not (h["collider"] is Hurtbox) or (h["collider"] as Hurtbox).owner == p:
			break
		hits.append(h["collider"])
		ex.append((h["collider"] as Hurtbox).get_rid())
		at = h["position"]
	# (stopped by the last one it could go through)
	if hits.size() >= n:
		end = at
	return [end, hits]


## A shot's hit for `base` damage (the weapon's bonuses, a crit), ranged.
static func shot_hit(p: Player, base: float, kind: String = "") -> HitData:
	var hd := p.melee_hit(base, kind)
	hd.ranged = true
	hd.impact = "shot"
	return hd


## Strike `hb` with `hd` (energy, the ultimate's charge, mastery).
static func strike(p: Player, hb: Hurtbox, hd: HitData) -> void:
	hb.take_hit(hd, p)
	p.power.on_sword_hit(hb.owner, hd)


## Everyone within `radius` of `at` takes `hd` (its damage falling to `edge` of it at the rim), knocked away from the
## middle. Returns those hit.
static func splash(p: Player, at: Vector3, radius: float, hd: HitData, edge: float = 0.5, exclude: Array = []) -> Array:
	var out: Array = []
	var pc := p.power
	for e in pc.enemies_in(at, radius):
		if e in exclude:
			continue
		var hb := (e as Node).get("hurtbox") as Hurtbox
		if hb == null:
			continue
		var d := (e as Node3D).global_position.distance_to(at)
		var h2 := hd.duplicate() as HitData
		h2.damage = roundf(hd.damage * lerpf(1.0, edge, clampf(d / radius, 0.0, 1.0)))
		pc._proxy.global_position = Vector3(at.x, (e as Node3D).global_position.y, at.z)
		hb.take_hit(h2, pc._proxy)
		pc.on_sword_hit(e, h2)
		out.append(e)
	return out
