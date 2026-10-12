class_name CorsairGun
## The sword-and-pistol style's off-hand pistol: the point-blank shots in its
## combo, heavy, jump attack and techniques. One pistol holding Player.ammo[0]
## balls (2, more with Bandolier); when it's empty it reloads by itself in 1.4 s,
## one-handed, while you keep cutting (a shot with nothing loaded is a blow with
## the butt instead). A ball does full damage out to NEAR m, falling off to
## FAR_MIN of it at RANGE.

const RANGE := 16.0
const NEAR := 5.0
const FAR_MIN := 0.5
## An enemy within this, roughly ahead, is the one the shot goes for.
const AIM_REACH := 8.0
const AIM_COS := 0.55


static func muzzle(p) -> Vector3:
	var gun: Node3D = p.body_model.offhand
	if gun != null and is_instance_valid(gun) and gun.is_inside_tree():
		return gun.global_transform * Vector3(0, 0.06, -0.24)
	return p.global_position + Vector3(0, 1.3, 0)


static func loaded(p) -> bool:
	return not p.reloading() and int(p.ammo[0]) > 0


## The middle of an enemy's body (its hurtbox shape; the Hurtbox node sits at the feet).
static func body_center(e: Node) -> Vector3:
	return ((e.get("hurtbox") as Node).get_child(0) as Node3D).global_position


## The nearest enemy roughly along `dir` within `reach` (the one a shot goes for), or null.
static func aimed(p, dir: Vector3, reach: float = AIM_REACH) -> Node3D:
	var f := Vector3(dir.x, 0.0, dir.z).normalized()
	var best: Node3D = null
	var bd := INF
	for e in p.power.enemies_in(p.global_position + Vector3(0, 0.9, 0), reach):
		var to: Vector3 = (e as Node3D).global_position - p.global_position
		to.y = 0.0
		if to.length() > 0.6 and to.normalized().dot(f) < AIM_COS:
			continue
		if to.length() < bd:
			bd = to.length()
			best = e
	return best


## Fire a ball at `target` (or the enemy aimed along `dir`, or straight along it):
## the enemy struck or null. opts: knock, stagger, down (bool), stop (hit-stop),
## shake, unblock (bool), elem (the element's colours: bool), burst (a powder burst
## where it hits, for techniques: the basics get theirs from FX.elem_hit), size (the
## flash), ball (false: a free shot that doesn't use the pistol's load).
static func fire(p, dir: Vector3, base: float, kind: String, opts: Dictionary = {}, target: Node3D = null) -> Node3D:
	var from := muzzle(p)
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	if target == null or not is_instance_valid(target):
		target = aimed(p, dir)
	var aim := from + dir.normalized() * RANGE
	if target != null:
		aim = body_center(target)
	var d := (aim - from).normalized()
	var end := from + d * RANGE
	var wq := PhysicsRayQueryParameters3D.create(from, end, 1)
	wq.exclude = [p.get_rid()]
	var wall := space.intersect_ray(wq)
	if not wall.is_empty():
		end = wall["position"]
	var eq := PhysicsRayQueryParameters3D.create(from, end, 32)
	eq.collide_with_areas = true
	eq.collide_with_bodies = false
	# (the ray stops at the first hurtbox: our own would swallow a shot fired across our body)
	eq.exclude = [(p.hurtbox as Hurtbox).get_rid()]
	var struck: Node3D = null
	var h := space.intersect_ray(eq)
	var hb: Hurtbox = null
	if not h.is_empty() and h["collider"] is Hurtbox and (h["collider"] as Hurtbox).owner != p:
		hb = h["collider"] as Hurtbox
		end = h["position"]
	elif target != null and from.distance_to(aim) < 1.6:
		# (point-blank: the barrel's already inside their body's shape)
		hb = target.get("hurtbox") as Hurtbox
		end = aim
	var elem: bool = opts.get("elem", false)
	var tree := "corsair" if elem else "plain"
	if hb != null:
		struck = hb.owner as Node3D
		var hd: HitData = p.melee_hit(base, kind)
		var far := from.distance_to(end)
		hd.damage *= lerpf(1.0, FAR_MIN, clampf((far - NEAR) / (RANGE - NEAR), 0.0, 1.0))
		hd.ranged = true
		hd.knockback_force = float(opts.get("knock", 5.0))
		hd.stagger_duration = float(opts.get("stagger", 0.4))
		hd.knockdown = bool(opts.get("down", false))
		hd.hitstop_duration = float(opts.get("stop", 0.05))
		hd.camera_shake_intensity = float(opts.get("shake", 0.08))
		hd.unblockable = hd.unblockable or bool(opts.get("unblock", false))
		hb.take_hit(hd, p)
		p.power.on_sword_hit(hb.owner, hd)
		if elem and opts.get("burst", false):
			Net.fx("powder_burst", [end, d, 0.55 * float(opts.get("size", 1.0)), FX.tree_col("corsair", FX.EDGE)])
		Net.fx("impact", [end, FX.tree_col(tree, FX.ACCENT)])
	else:
		Net.fx("dust", [end, 3, 0.35])
	var size := float(opts.get("size", 1.0))
	Net.fx("tracer", [from, end, FX.tree_col(tree, FX.CORE)])
	Net.fx("muzzle_sparks", [from, d, int(10 * size), FX.tree_col(tree, FX.ACCENT) if elem else Color(1.0, 0.75, 0.35)])
	Net.fx("smoke", [from + d * 0.2, int(3 * size) + 1, 0.45 * size + 0.15, 1.1, FX.POWDER_SMOKE if elem else Color(0.72, 0.72, 0.7, 0.75)])
	Net.fx("ring", [from + d * 0.25, d, 0.5 * size, FX.tree_col(tree, FX.EDGE), 0.16, 0.2])
	Net.fx("sfx", ["gunshot", from, -3.0, 0.08, 1.05])
	if opts.get("ball", true):
		p.ammo[0] = maxi(int(p.ammo[0]) - 1, 0)
		if int(p.ammo[0]) <= 0:
			p.call_deferred("start_reload")
			p.call("_toast", "Reloading...")
	return struck


## Nothing loaded: a short blow with the pistol's butt at whoever's in front.
static func butt(p, dir: Vector3, base: float, kind: String) -> Node3D:
	Net.fx("sfx", ["blip_low", p.global_position, -10.0, 0.05, 1.5])
	var e := aimed(p, dir, 2.3)
	if e == null:
		return null
	var hb := e.get("hurtbox") as Hurtbox
	if hb == null:
		return null
	var hd: HitData = p.melee_hit(base, kind)
	hd.knockback_force = 4.0
	hd.stagger_duration = 0.35
	hd.hitstop_duration = 0.04
	hd.camera_shake_intensity = 0.06
	hb.take_hit(hd, p)
	p.power.on_sword_hit(e, hd)
	var at := body_center(e)
	Net.fx("impact", [at, Color(1.0, 0.9, 0.7)])
	Net.fx("sfx", ["hit", at, -6.0, 0.05, 1.2])
	return e


## A ball if one's loaded, else the butt (about half the damage).
static func shoot_or_butt(p, dir: Vector3, base: float, kind: String, opts: Dictionary = {}, target: Node3D = null) -> Node3D:
	if loaded(p):
		return fire(p, dir, base, kind, opts, target)
	return butt(p, dir, base * 0.55, kind)
