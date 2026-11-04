class_name ShipGadgets
extends RefCounted
## The ship gadgets (1.28; numbers in GadgetData, kind "ship"): built and upgraded only at the bench aboard, they're
## fitted to her, not worn on the belt (GadgetBelt.owned keeps their tier and charges; they take no belt slot). The
## helmsman fires the picked one with the gadget key at the wheel (U; O picks the next):
##   burst_launcher  powder rockets under the stern fling her forward (+the tier's m/s on her speed, which the drag
##                   then bleeds off): a blast and a sheet of spray astern
##   paddle_boost    paddle wheels for the tier's secs: her speed wants the tier's share more, and at least
##                   PADDLE_FLOOR of her top speed whatever the wind or sails (Ship.paddle_t / paddle_k)
##   smoke_screen    smoke pots: a cloud bank laid astern every SMOKE_EVERY s for the tier's secs; an enemy ship can't
##                   hunt a ship inside one (EnemyShip._huntable asks hidden(): she drops the chase and her guns)
##   harpoon         the bow gun's harpoon at the enemy ship or sea beast ahead (HarpoonCannon)
## Co-op: the helmsman's call. Their machine sends Player.net_event "gadget_use" ["ship", tier, [id, target key]] and
## every machine applies it (the ship's sim runs everywhere from the helmsman's inputs, so the push and the boost must
## too); only the host's harpoon hurts and reels, and only the host's enemy ships think.

const IDS := ["burst_launcher", "paddle_boost", "smoke_screen", "harpoon"]
const PADDLE_FLOOR := 0.6
const SMOKE_EVERY := 2.0
const SMOKE_AFT := 6.0
const SMOKE := Color(0.72, 0.72, 0.7, 0.92)

## The smoke clouds alive on this machine: [cloud node, radius, until (game time)].
static var clouds: Array = []


## The ship gadgets `p` has built, in IDS order.
static func fitted(p: Node) -> Array:
	return IDS.filter(func(g): return p.gadgets.tier_of(g) >= 0)


static func selected(p: Node) -> String:
	var f := fitted(p)
	return "" if f.is_empty() else str(f[p.gadgets.ship_sel % f.size()])


static func cycle(p: Node) -> void:
	var f := fitted(p)
	if f.is_empty():
		p.call("_toast", "No ship gadgets fitted: build one at the bench aboard")
		return
	p.gadgets.ship_sel = (p.gadgets.ship_sel + 1) % f.size()
	var g := selected(p)
	p.call("_toast", "%s %s" % [GadgetData.GADGETS[g]["name"], GadgetData.TIER_NAMES[p.gadgets.tier_of(g)]])
	p.gadgets.changed.emit()


## The helmsman fires the picked ship gadget. False (and a word why) when it can't be.
static func fire(p: Node) -> bool:
	var g := selected(p)
	var ship := p.get("current_ship") as Ship
	if g == "" or ship == null:
		p.call("_toast", "No ship gadgets fitted: build one at the bench aboard")
		return false
	var b = p.gadgets
	var t: int = b.tier_of(g)
	if b.cooldown_left(g) > 0.0:
		p.call("_toast", "%s: ready in %d s" % [GadgetData.GADGETS[g]["name"], ceili(b.cooldown_left(g))])
		return false
	if b.max_charges(g) > 0 and b.charges(g) <= 0:
		p.call("_toast", "Out of %s: refill at the bench aboard" % GadgetData.GADGETS[g]["name"])
		return false
	var target: Node3D = null
	if g == "harpoon":
		target = HarpoonCannon.target_ahead(ship, float(GadgetData.tier_val("harpoon", "range", t)))
		if target == null:
			p.call("_toast", "Nothing ahead to harpoon: bring her bow onto a ship or a sea beast")
			return false
	if b.max_charges(g) > 0:
		b.owned[g]["charges"] = b.charges(g) - 1
	b.ready_at[g] = PlayerState.now_s() + b.cooldown_len(g)
	b.changed.emit()
	_net().event(p, "gadget_use", ["ship", t, [g, _net().key_of(target) if target else ""]])
	apply(ship, g, t, target, p)
	return true


## (every machine) What gadget `g` at tier `t` does to `ship`.
static func apply(ship: Ship, g: String, t: int, target: Node3D, by: Node) -> void:
	var fx := _fx()
	var stern: Vector3 = ship.global_transform * Vector3(0, 1.2, ship.layout.stern_z)
	var aft: Vector3 = ship.global_basis.z
	aft.y = 0.0
	aft = aft.normalized()
	var aboard := _local_aboard(ship)
	match g:
		"burst_launcher":
			ship.speed += float(GadgetData.tier_val(g, "impulse", t))
			fx.blast(stern, aft, 1.2 + 0.3 * t)
			fx.plume(stern, aft + Vector3.UP * 0.3, "smoke", 8 + 3 * t, 3.5, 2.2, Color(0.55, 0.52, 0.5, 0.85), 5.0, 50.0)
			var sea := Vector3(stern.x, 0.2, stern.z)
			fx.puff_ring(sea, "dust_low", 18 + 4 * t, 0.8, 3.5 + t, 1.4, Color(0.92, 0.96, 1.0, 0.9), 14.0)
			fx.debris(sea, Vector3.UP + aft, 14, Color(0.85, 0.93, 1.0), 9.0)
			fx.splash(sea, 24, 2.2 + 0.4 * t)
			fx.sfx("cannon", stern, 6.0, 0.05, 0.7)
			fx.sfx("splash", sea, 2.0, 0.1, 0.6)
			if aboard:
				_root().get_node("CombatManager").apply_camera_shake(0.45, 0.5)
		"paddle_boost":
			ship.paddle_t = float(GadgetData.tier_val(g, "secs", t))
			ship.paddle_k = float(GadgetData.tier_val(g, "boost", t))
			var right: Vector3 = ship.global_basis.x
			for s in [-1.0, 1.0]:
				var at: Vector3 = ship.global_position + right * s * (ship.layout.half_beam + 0.4)
				fx.puff_ring(Vector3(at.x, 0.2, at.z), "dust_low", 8, 0.4, 1.4, 0.8, Color(0.92, 0.96, 1.0, 0.85), 6.0)
			fx.sfx("clack", ship.global_position + Vector3.UP * 2.0, -2.0, 0.05, 0.6)
			fx.sfx("splash", ship.global_position, -2.0, 0.1, 1.2)
		"smoke_screen":
			_smoke_screen(ship, t)
		"harpoon":
			if target and is_instance_valid(target):
				HarpoonCannon.harpoon(ship, target, t, by)


## (Ship._physics_process while the paddles turn) the speed she wants with them.
static func paddle(ship: Ship, want: float, delta: float) -> float:
	ship.paddle_t = maxf(ship.paddle_t - delta, 0.0)
	return maxf(want, Ship.MAX_SPEED * ship._top_k * PADDLE_FLOOR) * (1.0 + ship.paddle_k)


## Is `n` (a ship) inside a smoke screen's cloud right now?
static func hidden(n: Node3D) -> bool:
	if clouds.is_empty():
		return false
	var now := PlayerState.now_s()
	clouds = clouds.filter(func(c): return is_instance_valid(c[0]) and now < float(c[2]))
	for c in clouds:
		var d: Vector3 = (c[0] as Node3D).global_position - n.global_position
		if Vector2(d.x, d.z).length() < float(c[1]):
			return true
	return false


## The smoke pots lit: a cloud astern now and every SMOKE_EVERY s for the tier's secs (each lasts the screen's time
## and thins after).
static func _smoke_screen(ship: Ship, t: int) -> void:
	var secs := float(GadgetData.tier_val("smoke_screen", "secs", t))
	var r := float(GadgetData.tier_val("smoke_screen", "radius", t))
	var until := PlayerState.now_s() + secs
	_fx().sfx("hiss", ship.global_position, 2.0, 0.1, 0.6)
	_fx().sfx("fire_burst", ship.global_position, -2.0, 0.1, 0.5)
	_cloud(ship, r, until)
	var timer := Timer.new()
	timer.wait_time = SMOKE_EVERY
	ship.add_child(timer)
	timer.timeout.connect(func():
		if PlayerState.now_s() >= until - 0.5:
			timer.queue_free()
			return
		_cloud(ship, r, until))
	timer.start()


static func _cloud(ship: Ship, r: float, until: float) -> void:
	var c := Node3D.new()
	c.name = "SmokeScreen"
	var tree := ship.get_tree()
	(tree.current_scene if tree.current_scene else tree.root).add_child(c)
	var aft: Vector3 = ship.global_basis.z
	aft.y = 0.0
	c.global_position = Vector3(ship.global_position.x, 0.5, ship.global_position.z) + aft.normalized() * SMOKE_AFT
	var em: CPUParticles3D = _fx().flip_emitter(c, "smoke", 16, r * 0.55, 4.0, {"radius": r * 0.7, "spread": 180.0,
		"direction": Vector3.UP, "vel_min": 0.2, "vel_max": 0.8, "gravity": Vector3(0, 0.15, 0), "damping": 0.3,
		"start": 0.3, "spin": 15.0, "curve": "grow", "fade_in": 0.2, "fade": 0.5, "color": SMOKE, "range": 300.0})
	em.position = Vector3(0, r * 0.25, 0)
	clouds.append([c, r, until])
	var left := maxf(until - PlayerState.now_s(), 0.5)
	tree.create_timer(left, false).timeout.connect(func():
		if is_instance_valid(em):
			em.emitting = false)
	tree.create_timer(left + 4.5, false).timeout.connect(func():
		if is_instance_valid(c):
			c.queue_free())


static func _local_aboard(ship: Ship) -> bool:
	var me := ship.get_tree().get_first_node_in_group("player") as Node3D
	return me != null and ship.aboard(me.global_position)


static func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


static func _fx() -> Node:
	return _root().get_node("FX")


static func _net() -> Node:
	return _root().get_node("Net")
