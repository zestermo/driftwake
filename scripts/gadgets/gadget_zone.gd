class_name GadgetZone
extends Node3D
## What a thrown gadget leaves where it lands: a smoke cloud or a tar pool. Every screen makes its own (the throw
## arrives as the thrower's event); only the host's copy touches the foes, on a timer (TICK), never per frame.
##   smoke  a cloud: a foe caught in it staggers coughing once (blinded / stagger), and a captain inside can't be
##          noticed or attacked (veiled: Stealth and the grunts' target check ask it)
##   tar    a black pool: foes in it are slowed (slowed) while they stand in it
##   flash  a white burst at once: foes in reach facing it are stunned (blinded / stagger)
##   pepper a red cloud: foes in it take the tier's damage a second and break off to cough every so often
##   star   a burst at once: damage in the radius, Mk III knocks down
##   caltrops  spikes strewn on the ground: foes on them slowed and cut, Mk III's draw blood
##   lantern_bomb  a burst of light, then the lamp burning on in its own light (radius = the tier's "light"): foes in
##          it are marked on the compass (GadgetMarks) and revealed; by night the host's sends beasts off (scare)
##   charge (1.30) planted (GadgetState), not thrown: the satchel on its surface (`normal`), the fuse ticking on every
##          screen, then a big blast; the host's hurts and floors everything in the radius and breaches the
##          ChargeTargets in it
## Damage goes through the foes' hurtboxes (a query on the enemies' layer) as the thrower's (`by`).

const TICK := 0.25
const FOE_MASK := 32
## Instant gadgets' zones stay this long (their effects play out).
const BURST_SECS := 0.6
const PEPPER := Color(0.85, 0.25, 0.12, 0.85)
## How high above or below the zone's ground a captain or foe still counts as in it.
const REACH_Y := 2.5
const SMOKE_TINT := [Color(0.74, 0.73, 0.7, 0.9), Color(0.64, 0.68, 0.78, 0.92), Color(0.46, 0.42, 0.56, 0.94)]
const TAR := Color(0.035, 0.03, 0.028, 0.96)
## (1.30) The flash dazzles a screen whose camera looks within this of it (a dot), for FLASH_SECS.
const FACING_DOT := 0.5
const FLASH_SECS := 0.9
## (1.30) The powder charge: its zone stays this long after the blast (the smoke), the fuse's tick, and how far a
## camera still shakes.
const CHARGE_AFTER := 1.5
const FUSE_TICK := 0.5
const CHARGE_SHAKE := 35.0

## Every zone alive on this machine (the smoke also in GadgetVeil.clouds).
static var active: Array = []
## The lantern bomb: its light (a real one, no shadow; at most MAX_LANTERNS burning on a machine, the oldest goes out
## first), how often it looks for foes to reveal and flickers, the light's colour and strength.
const MAX_LANTERNS := 3
const LANTERN_TICK := 0.5
const LANTERN := Color(1.0, 0.72, 0.38)
const LANTERN_ENERGY := 2.4
static var lanterns: Array = []
var _light: OmniLight3D
var _age := 0.0

var kind := ""
var tier := 0
var radius := 3.0
var secs := 6.0
var _hit: Dictionary = {}
var _emit: CPUParticles3D
var _pool: MeshInstance3D
var by: Node
var _cough: Dictionary = {}
## (1.30) The charge: the surface it sits on (out of it), its fuse, the satchel, its tick.
var normal := Vector3.UP
var fuse := 0.0
var _beep := 0.0
var _satchel: MeshInstance3D
var _fuse_timer: Timer


static func spawn(tree: SceneTree, gid: String, t: int, at: Vector3, thrower: Node = null, normal := Vector3.UP) -> GadgetZone:
	var z := GadgetZone.new()
	z.kind = gid
	z.tier = t
	z.by = thrower
	z.normal = normal.normalized()
	z.radius = float(GadgetData.tier_val(gid, "radius" if GadgetData.GADGETS[gid].has("radius") else "light", t))
	z.secs = float(GadgetData.tier_val(gid, "secs", t)) if GadgetData.GADGETS[gid].has("secs") else BURST_SECS
	if GadgetData.GADGETS[gid].has("fuse"):
		z.fuse = float(GadgetData.tier_val(gid, "fuse", t))
		z.secs = z.fuse + CHARGE_AFTER
	(tree.current_scene if tree.current_scene else tree.root).add_child(z)
	z.global_position = at
	return z


func inside(at: Vector3) -> bool:
	var d := at - global_position
	return absf(d.y) < REACH_Y and Vector2(d.x, d.z).length() < radius


func _ready() -> void:
	active.append(self)
	add_to_group("gadget_zones")
	match kind:
		"smoke":
			GadgetVeil.clouds.append(self)
			_smoke_burst()
		"tar":
			_tar_splash()
		"flash":
			_flash_burst()
		"pepper":
			_pepper_burst()
		"star":
			_star_burst()
		"caltrops":
			_caltrops_strew()
		"lantern_bomb":
			_lantern_burst()
		"charge":
			_charge_set()
	var life := Timer.new()
	life.one_shot = true
	life.wait_time = secs
	life.timeout.connect(_end)
	add_child(life)
	life.start()
	if kind == "lantern_bomb":
		# (every screen: the marks and the flicker are its own; the host also keeps the night's beasts off)
		var t := Timer.new()
		t.wait_time = LANTERN_TICK
		t.timeout.connect(_lantern_tick)
		add_child(t)
		t.start()
		_lantern_tick.call_deferred()
		return
	if kind == "charge":
		# (every screen: the fuse's tick and the blast; the host's also hurts and breaches)
		_fuse_timer = Timer.new()
		_fuse_timer.wait_time = FUSE_TICK
		_fuse_timer.timeout.connect(_fuse_tick)
		add_child(_fuse_timer)
		_fuse_timer.start()
		return
	if Net.is_host():
		if kind in ["flash", "star"]:
			_burst_hits.call_deferred()
			return
		var t := Timer.new()
		t.wait_time = TICK
		t.timeout.connect(_tick)
		add_child(t)
		t.start()


func _exit_tree() -> void:
	active.erase(self)
	GadgetVeil.clouds.erase(self)
	lanterns.erase(self)


func _smoke_burst() -> void:
	var col: Color = SMOKE_TINT[tier]
	var c := global_position + Vector3(0, 0.4, 0)
	FX.flash(c, 1.4 + 0.4 * tier, Color.WHITE, "dither_muzzle", 0.3)
	FX.flash_light(c, Color(1.0, 0.9, 0.75), 1.6, 5.0, 0.18)
	FX.puff_ring(global_position, "dust_low", 10 + 2 * tier, 0.4, 1.6 + 0.3 * tier, 1.0, col, 7.0 + tier)
	FX.plume(c, Vector3.UP, "smoke", 5 + tier * 2, radius * 0.8, 2.2, col, 3.0, 70.0)
	FX.sfx("fire_burst", c, -6.0 + 2.0 * tier, 0.1, 0.7)
	FX.sfx("hiss", c, -8.0, 0.1, 0.6)
	_emit = FX.flip_emitter(self, "smoke", 14 + 6 * tier, radius * 0.75, 2.6, {"radius": radius * 0.55, "spread": 180.0,
		"direction": Vector3.UP, "vel_min": 0.15, "vel_max": 0.6, "gravity": Vector3(0, 0.12, 0), "damping": 0.3,
		"start": 0.2, "spin": 20.0, "curve": "grow", "fade_in": 0.18, "fade": 0.55, "color": col, "range": 120.0})
	_emit.position = Vector3(0, radius * 0.3, 0)
	if tier == 2:
		FX.sparkle(c, 12, Color(0.75, 0.55, 1.0))


func _tar_splash() -> void:
	FX.puff_ring(global_position, "dust_low", 8, 0.3, 0.9, 0.7, Color(0.12, 0.1, 0.09, 0.9), 5.0)
	FX.debris(global_position + Vector3(0, 0.2, 0), Vector3.UP, 10 + 4 * tier, Color(0.05, 0.04, 0.04), 5.0)
	FX.sfx("splash", global_position, -6.0, 0.1, 0.6)
	FX.sfx("crunch", global_position, -4.0, 0.1, 0.8)
	_pool = MeshInstance3D.new()
	_pool.mesh = _blot(radius)
	var m := PSXMat.decal(TAR, {"roughness": 0.08, "specular": 0.9})
	_pool.material_override = m
	_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pool.visibility_range_end = 120.0
	add_child(_pool)
	_pool.position = Vector3(0, 0.03, 0)
	_pool.scale = Vector3(0.2, 1, 0.2)
	_pool.create_tween().tween_property(_pool, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# a few slow bubbles of pitch (Mk III's still smoulders)
	_emit = FX.flip_emitter(self, "smoke" if tier == 2 else "dust", 3 + tier * 2, 0.5, 1.4, {"radius": radius * 0.6, "spread": 10.0,
		"vel_min": 0.1, "vel_max": 0.3, "gravity": Vector3(0, 0.2, 0), "damping": 0.5, "fade": 0.5,
		"color": Color(0.2, 0.17, 0.15, 0.7) if tier == 2 else Color(0.08, 0.07, 0.06, 0.8), "range": 80.0})


func _flash_burst() -> void:
	var c := global_position + Vector3(0, 0.8, 0)
	FX.flash(c, 3.0 + 0.8 * tier, Color.WHITE, "glint", 0.35)
	FX.flash(c, 2.0 + 0.5 * tier, Color(1.0, 0.95, 0.8), "dither_muzzle", 0.25)
	FX.flash_light(c, Color(1.0, 0.98, 0.9), 6.0 + 2.0 * tier, radius * 2.5, 0.3)
	FX.ring(global_position + Vector3(0, 0.1, 0), Vector3.UP, radius, Color(1, 1, 1, 0.9), 0.3, 0.16)
	FX.sparkle(c, 16 + 6 * tier, Color(1.0, 1.0, 0.9))
	FX.sfx("fire_burst", c, -4.0, 0.1, 1.6)
	FX.sfx("edy_flash", c, -6.0, 0.05, 1.2)
	# (1.30) a captain looking into it is dazzled white a moment; looking away, only the glare
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(c) < radius * 3.0:
		var facing := (-cam.global_basis.z).dot((c - cam.global_position).normalized()) > FACING_DOT
		FX.screen_flash(c, Color(1, 1, 1, 0.92 if facing else 0.35), FLASH_SECS if facing else 0.3)


func _pepper_burst() -> void:
	var c := global_position + Vector3(0, 0.4, 0)
	FX.flash(c, 1.2, Color(1.0, 0.6, 0.4), "dither_muzzle", 0.25)
	FX.puff_ring(global_position, "dust_low", 10, 0.4, 1.4, 0.9, PEPPER, 7.0)
	FX.embers(c, Vector3.UP, 10 + 4 * tier, Color(1.0, 0.35, 0.1), 3.0)
	FX.sfx("hiss", c, -4.0, 0.1, 0.9)
	_emit = FX.flip_emitter(self, "smoke", 12 + 4 * tier, radius * 0.7, 2.2, {"radius": radius * 0.55, "spread": 180.0,
		"vel_min": 0.15, "vel_max": 0.5, "gravity": Vector3(0, 0.1, 0), "damping": 0.3, "start": 0.2, "spin": 25.0,
		"curve": "grow", "fade_in": 0.15, "fade": 0.55, "color": PEPPER, "range": 120.0})
	_emit.position = Vector3(0, radius * 0.25, 0)


func _star_burst() -> void:
	var c := global_position + Vector3(0, 0.3, 0)
	FX.blast(c, Vector3.UP, 0.8 + 0.3 * tier)
	FX.debris(c, Vector3.UP, 8 + 4 * tier, Color(0.4, 0.35, 0.3), 6.0)
	FX.ring(global_position + Vector3(0, 0.1, 0), Vector3.UP, radius, Color(1.0, 0.75, 0.4, 0.9), 0.28, 0.14)
	FX.sfx("cannon_hit", c, -4.0 + 2.0 * tier, 0.08, 1.3)
	if tier == 2:
		FX.ground_crack(global_position, Vector3.FORWARD, radius, Color(1.0, 0.45, 0.15), randi(), 0.12)
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(c) < 25.0:
		CombatManager.apply_camera_shake(0.15 + 0.1 * tier, 0.25)


func _caltrops_strew() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _spikes(radius, 14 + 6 * tier)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 60.0
	add_child(mi)
	_pool = mi
	FX.sfx("clack", global_position, -4.0, 0.15, 1.5)
	FX.sfx("clack", global_position, -6.0, 0.15, 1.1)
	FX.puff_ring(global_position, "dust_low", 6, 0.3, 0.7, 0.5, Color(0.8, 0.75, 0.65, 0.7), 4.0)


## (1.30) The powder charge set down: the satchel against its surface, the fuse sputtering.
func _charge_set() -> void:
	_satchel = MeshInstance3D.new()
	_satchel.mesh = GadgetModels.mesh("charge", tier)
	var x := (Vector3.FORWARD if absf(normal.y) > 0.95 else Vector3.UP).cross(normal).normalized()
	_satchel.basis = Basis(x, normal, x.cross(normal)).scaled(Vector3.ONE * 2.4)
	_satchel.position = normal * 0.05
	_satchel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_satchel.visibility_range_end = 90.0
	add_child(_satchel)
	_emit = FX.flip_emitter(self, "dust", 6, 0.12, 0.35, {"radius": 0.03, "spread": 40.0, "direction": normal,
		"vel_min": 0.6, "vel_max": 1.4, "gravity": Vector3(0, -2.0, 0), "fade": 0.4, "color": Color(1.0, 0.7, 0.25, 1.0), "range": 60.0})
	_emit.position = normal * 0.32
	FX.sfx("hiss", global_position, -6.0, 0.1, 1.3)


## The fuse burns down (every screen): a tick and a spit of sparks, then the blast.
func _fuse_tick() -> void:
	_beep += FUSE_TICK
	if _beep < fuse - 0.01:
		var near_end := fuse - _beep <= 1.0
		FX.sfx("blip_high" if near_end else "clack", global_position, -8.0, 0.02, 1.6 if near_end else 1.2)
		FX.puff(global_position + normal * 0.35, "dust", 1, 0.15, 0.3, Color(1.0, 0.75, 0.35, 0.9), 0.25)
		return
	_fuse_timer.stop()
	_charge_blow()


func _charge_blow() -> void:
	var c := global_position + normal * 0.4
	_satchel.visible = false
	_emit.emitting = false
	FX.blast(c, normal, 2.4 + 0.4 * tier, true, Color(0.35, 0.33, 0.3, 0.9), 9.0)
	FX.blast(c + normal * 0.9 + Vector3.UP * 0.5, normal, 1.5 + 0.3 * tier, true, Color(0.3, 0.28, 0.26, 0.9), 6.0)
	FX.debris(c, normal, 20 + 6 * tier, Color(0.38, 0.33, 0.28), 10.0)
	FX.ring(global_position + normal * 0.1, normal, radius, Color(1.0, 0.7, 0.35, 0.9), 0.35, 0.2)
	FX.puff_ring(global_position, "dust_low", 14, 0.6, 2.2, 1.4, Color(0.5, 0.45, 0.4, 0.85), 10.0)
	FX.plume(c, Vector3.UP, "smoke", 8, radius * 0.7, 3.0, Color(0.25, 0.23, 0.22, 0.9), 4.0, 25.0)
	FX.flash_light(c, Color(1.0, 0.7, 0.4), 8.0, radius * 3.0, 0.35)
	if normal.y > 0.7:
		FX.ground_crack(global_position, Vector3.FORWARD, radius, Color(1.0, 0.45, 0.15), randi(), 0.15)
	FX.sfx("cannon_hit", c, 2.0, 0.08, 0.8)
	FX.sfx("fire_burst", c, 0.0, 0.1, 0.6)
	var cam := get_viewport().get_camera_3d()
	if cam:
		var d := cam.global_position.distance_to(c)
		if d < CHARGE_SHAKE:
			CombatManager.apply_camera_shake(0.1 + 0.5 * (1.0 - d / CHARGE_SHAKE), 0.45)
		if d < radius * 2.0:
			FX.screen_flash(c, Color(1.0, 0.85, 0.6, 0.4), 0.2)
	if not Net.is_host():
		return
	var hd := HitData.new()
	hd.damage = float(GadgetData.tier_val("charge", "damage", tier))
	hd.knockdown = true
	hd.poise = 999.0
	hd.knockback_force = 12.0
	hd.stagger_duration = 0.6
	hd.hitstop_duration = 0.06
	hd.camera_shake_intensity = 0.0
	hd.impact = "punch_heavy"
	_hurt(hd)
	ChargeTarget.blast(global_position, radius + 0.5, by if by and is_instance_valid(by) else null)


## The lantern bomb lands: a burst of light (a flash, sparks), then the lamp lying lit in a pool of warm light.
func _lantern_burst() -> void:
	var c := global_position + Vector3(0, 0.5, 0)
	FX.flash(c, 2.2 + 0.5 * tier, Color(1.0, 0.85, 0.55), "glint", 0.3)
	FX.flash_light(c, Color(1.0, 0.85, 0.6), 5.0 + tier, radius * 1.6, 0.35)
	FX.ring(global_position + Vector3(0, 0.1, 0), Vector3.UP, radius * 0.6, Color(1.0, 0.85, 0.5, 0.8), 0.35, 0.12)
	FX.embers(c, Vector3.UP, 12 + 4 * tier, Color(1.0, 0.6, 0.2), 3.5)
	FX.sfx("fire_burst", c, -6.0, 0.1, 1.2)
	FX.sfx("clack", c, -6.0, 0.1, 1.5)
	var lamp := MeshInstance3D.new()
	lamp.mesh = GadgetModels.mesh("lantern_bomb", tier)
	lamp.scale = Vector3.ONE * 2.2
	lamp.position = Vector3(0, 0.1, 0)
	lamp.rotation = Vector3(0.0, 0.0, 1.2)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.visibility_range_end = 120.0
	add_child(lamp)
	_pool = lamp
	_light = OmniLight3D.new()
	_light.light_color = LANTERN
	_light.light_energy = LANTERN_ENERGY
	_light.omni_range = radius
	_light.omni_attenuation = 1.2
	_light.shadow_enabled = false
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 70.0
	_light.distance_fade_length = 20.0
	_light.position = Vector3(0, 0.9, 0)
	add_child(_light)
	_emit = FX.flip_emitter(self, "dust", 3 + tier, 0.18, 1.0, {"radius": 0.15, "spread": 15.0, "vel_min": 0.3, "vel_max": 0.7,
		"gravity": Vector3(0, 0.5, 0), "fade": 0.5, "color": Color(1.0, 0.6, 0.25, 0.9), "range": 60.0})
	_emit.position = Vector3(0, 0.3, 0)
	lanterns.append(self)
	while lanterns.size() > MAX_LANTERNS:
		(lanterns.pop_front() as GadgetZone)._end()


## The lantern's beat: its flame flickers, every foe its light falls on is marked on the compass (and revealed, if it
## hides: `revealed(secs)`) for as long as it burns; the host's sends the night's beasts and wildlife off (`scare`).
func _lantern_tick() -> void:
	if _light == null or not is_inside_tree():
		return
	_light.light_energy = LANTERN_ENERGY * randf_range(0.85, 1.1)
	var left := maxf(secs - _age, 1.0)
	_age += LANTERN_TICK
	var night: bool = float(Weather.night) > 0.5
	var fresh: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node3D
		if n == null or n.global_position.distance_to(global_position) > radius:
			continue
		if not _hit.has(n):
			_hit[n] = true
			fresh.append(n)
			if n.has_method("revealed"):
				n.call("revealed", left)
		if night and Net.is_host() and n.has_method("scare"):
			n.call("scare")
	if not fresh.is_empty():
		GadgetMarks.mark(fresh, left)


## The caltrops: `n` little four-pointed spikes scattered over radius `r` (one mesh).
func _spikes(r: float, n: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 7.0) ^ int(global_position.z * 13.0)
	var iron := PSXMat.lit("metal", Color(0.35, 0.33, 0.32) if tier < 2 else Color(0.5, 0.2, 0.16))
	for i in range(n):
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r * 0.9
		var at := Vector3(cos(a) * d, 0.03, sin(a) * d)
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		mb.add_cone(iron, Transform3D(b, at), 0.03, 0.09, 3)
		for k in range(3):
			var dir := b * Vector3(cos(k * TAU / 3.0), -0.35, sin(k * TAU / 3.0)).normalized()
			mb.add_cone(iron, Transform3D(Basis(Vector3.UP.cross(dir).normalized(), Vector3.UP.angle_to(dir)), at), 0.02, 0.07, 3)
	return mb.commit()


## (host) The burst gadgets' one moment: the flash stuns foes facing it, the star hits everything in reach.
func _burst_hits() -> void:
	match kind:
		"flash":
			var stun := float(GadgetData.tier_val("flash", "stun", tier))
			for e in get_tree().get_nodes_in_group("enemies"):
				var n := e as Node3D
				if n == null or n.global_position.distance_to(global_position) > radius:
					continue
				var to := global_position - n.global_position
				to.y = 0.0
				var fwd := -n.global_basis.z
				if n.get("facing") is Node3D:
					fwd = -(n.get("facing") as Node3D).global_basis.z
				if to.length() < 1.0 or fwd.dot(to.normalized()) > 0.0:
					_stun(n, stun)
		"star":
			var hd := HitData.new()
			hd.damage = float(GadgetData.tier_val("star", "damage", tier))
			hd.knockdown = bool(GadgetData.tier_val("star", "knockdown", tier))
			if hd.knockdown:
				# (poise or not: Mk III's blast floors them, like the grunts' red-glow blows)
				hd.poise = 999.0
			hd.knockback_force = 6.0 + 3.0 * tier
			hd.stagger_duration = 0.5
			hd.hitstop_duration = 0.05
			hd.camera_shake_intensity = 0.0
			hd.impact = "punch_heavy"
			_hurt(hd)


func _stun(n: Node, secs: float) -> void:
	if n.has_method("blinded"):
		n.blinded(secs)
	elif n.has_method("stagger"):
		n.stagger(secs)


## Hit every foe whose hurtbox is in the zone with `hd` (as the thrower's).
func _hurt(hd: HitData) -> void:
	hurt_at(self, global_position, radius, hd, by if by and is_instance_valid(by) else self)


## Hit every foe whose hurtbox is within `r` of `at` with `hd`, as `from`'s (`n` any node in the world).
static func hurt_at(n: Node3D, at: Vector3, r: float, hd: HitData, from: Node) -> void:
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = r
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.6, 0))
	q.collision_mask = FOE_MASK
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var struck: Array = []
	for res in n.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var area := res["collider"] as Hurtbox
		if area and area.owner and not (area.owner in struck) and not area.owner.is_in_group("players"):
			struck.append(area.owner)
			area.take_hit(hd, from)


## An uneven round blot lying flat (the tar pool).
func _blot(r: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 13.0) ^ int(global_position.z * 7.0)
	var n := 14
	var pts: Array = []
	for i in range(n):
		var a := TAU * i / n
		pts.append(Vector3(cos(a), 0, sin(a)) * r * rng.randf_range(0.82, 1.08))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in range(n):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % n]
		for v in [Vector3.ZERO, b, a]:
			st.set_uv(Vector2(v.x, v.z) / (2.0 * r) + Vector2(0.5, 0.5))
			st.add_vertex(v)
	return st.commit()


func _tick() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node3D
		if n == null or not inside(n.global_position):
			continue
		match kind:
			"smoke":
				if not _hit.has(n):
					_hit[n] = true
					var b := float(GadgetData.tier_val("smoke", "blind", tier))
					if n.has_method("blinded"):
						n.blinded(b)
					elif n.has_method("stagger"):
						n.stagger(b)
			"tar":
				if n.has_method("slowed"):
					n.slowed(TICK * 2.0, float(GadgetData.tier_val("tar", "slow", tier)))
				if not _hit.has(n):
					_hit[n] = true
					Net.fx("puff", [n.global_position + Vector3(0, 0.1, 0), "dust_low", 3, 0.5, 0.6, Color(0.08, 0.07, 0.06, 0.9), 0.3])
			"pepper":
				var now := PlayerState.now_s()
				if now >= float(_cough.get(n, 0.0)):
					_cough[n] = now + float(GadgetData.tier_val("pepper", "cough_every", tier))
					_stun(n, 0.6)
					Net.fx("puff", [n.global_position + Vector3(0, 1.6, 0), "dust", 2, 0.4, 0.5, PEPPER, 0.6])
			"caltrops":
				if n.has_method("slowed"):
					n.slowed(TICK * 2.0, float(GadgetData.tier_val("caltrops", "slow", tier)))
	# the damage over time: one query a tick for every foe's hurtbox in it
	if kind in ["pepper", "caltrops"]:
		var hd := HitData.new()
		hd.damage = float(GadgetData.tier_val(kind, "dps", tier)) * TICK
		hd.knockback_force = 0.0
		hd.stagger_duration = 0.0
		hd.hitstop_duration = 0.0
		hd.camera_shake_intensity = 0.0
		if kind == "caltrops" and float(GadgetData.tier_val("caltrops", "bleed", tier)) > 0.0:
			hd.set_meta("bleed", float(GadgetData.tier_val("caltrops", "bleed", tier)))
		_hurt(hd)


func _end() -> void:
	if not active.has(self):
		return
	active.erase(self)
	GadgetVeil.clouds.erase(self)
	lanterns.erase(self)
	for c in get_children():
		if c is Timer:
			(c as Timer).stop()
	if _emit:
		_emit.emitting = false
	if _light:
		_light.create_tween().tween_property(_light, "light_energy", 0.0, 1.2)
		FX.puff(global_position + Vector3(0, 0.4, 0), "smoke", 2, 0.4, 1.0, Color(0.4, 0.38, 0.36, 0.7), 0.3)
	elif _pool:
		_pool.create_tween().tween_property(_pool, "scale", Vector3(0.01, 1, 0.01), 1.0)
	get_tree().create_timer(2.8).timeout.connect(queue_free)
