class_name GadgetDecoy
extends Decoy
## The Decoy gadget (1.28): a spring-loaded straw captain in the thrower's colours, standing where it lands for the
## tier's secs. Every screen makes its own (from the throw). On the host, every RETHINK s each foe within the tier's
## lure reach that can be lured (PirateGrunt.lure) goes for it: idle ones are roused, fighting ones turn on it and
## swing at it (each blow a puff of straw: struck) instead of the crew. Its time up, it falls apart in straw; Mk III
## goes off for its burst damage (the host's, through the foes' hurtboxes as the thrower's).

const RETHINK := 0.4
const HIT_GAP := 0.35
const BURST_R := 3.0
## The last stretch of its life it shakes (the tell that it's about to go).
const TELL := 1.2

var tier := 0
var by: Node
var _fig: MeshInstance3D
var _wobble := 0.0
var _last_hit := -1.0


static func landed(tree: SceneTree, t: int, at: Vector3, thrower: Node) -> GadgetDecoy:
	var d := GadgetDecoy.new()
	d.name = "GadgetDecoy"
	d.sturdy = true
	d.tier = t
	d.by = thrower
	d.captain = thrower as Node3D
	d.life = float(GadgetData.tier_val("decoy", "secs", t))
	d.spot = at
	(tree.current_scene if tree.current_scene else tree.root).add_child(d)
	d.global_position = at
	return d


func _ready() -> void:
	add_to_group("decoys")
	var coat := Color(0.55, 0.2, 0.15)
	var body = by.get("body_model") if by and is_instance_valid(by) else null
	if body:
		var lk: Dictionary = body.look
		coat = lk.get("coat_color", lk.get("top_color", coat)) if str(lk.get("coat", "")) != "" else lk.get("top_color", coat)
	_fig = MeshInstance3D.new()
	_fig.mesh = GadgetModels.decoy_figure(tier, coat)
	_fig.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fig.visibility_range_end = 90.0
	add_child(_fig)
	if by is Node3D:
		var d := (by as Node3D).global_position - global_position
		d.y = 0.0
		if d.length() > 0.1:
			rotation.y = atan2(d.x, d.z)
	_fig.scale = Vector3(0.6, 0.05, 0.6)
	_fig.create_tween().tween_property(_fig, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	FX.puff_ring(global_position + Vector3(0, 0.05, 0), "dust_low", 8, 0.3, 0.8, 0.6, Color(0.85, 0.78, 0.6, 0.9), 4.0)
	FX.debris(global_position + Vector3(0, 0.6, 0), Vector3.UP, 8, GadgetModels.STRAW, 3.0)
	FX.sfx("jump", global_position, -6.0, 0.05, 1.5)
	FX.sfx("clack", global_position, -4.0, 0.05, 0.8)
	reset_physics_interpolation()
	if Net.is_host():
		var t := Timer.new()
		t.wait_time = RETHINK
		t.timeout.connect(_lure_all)
		add_child(t)
		t.start()
		_lure_all.call_deferred()


## (host) Every foe in reach that can be lured goes for it.
func _lure_all() -> void:
	var r := float(GadgetData.tier_val("decoy", "lure", tier))
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("lure") and (e as Node3D).global_position.distance_to(spot) < r:
			e.call("lure", self)


func struck(_by: Node) -> void:
	var now := PlayerState.now_s()
	if now - _last_hit < HIT_GAP:
		return
	_last_hit = now
	_wobble = 0.35
	Net.fx("puff", [spot + Vector3(0, 1.2, 0), "dust", 4, 0.4, 0.5, Color(0.9, 0.78, 0.45, 0.9), 0.5])
	Net.fx("sfx", ["punch", spot + Vector3(0, 1.2, 0), -6.0, 0.1, 1.2])


func _process(delta: float) -> void:
	_t += delta
	var shake := 0.05 if life - _t < TELL else 0.0
	_wobble = move_toward(_wobble, 0.0, delta * 0.8)
	_fig.rotation = Vector3(sin(_t * 9.0) * _wobble * 0.5, 0.0, sin(_t * 23.0) * (_wobble + shake))
	if _t >= life:
		_pop()


## Its time's up: it comes apart in straw (Mk III: its powder keg goes off).
func _pop() -> void:
	remove_from_group("decoys")
	var c := global_position + Vector3(0, 1.1, 0)
	FX.debris(c, Vector3.UP, 16, GadgetModels.STRAW, 5.0)
	FX.puff(c, "dust", 6, 0.6, 0.7, Color(0.9, 0.8, 0.55, 0.8), 0.6)
	FX.sfx("crunch", c, -4.0, 0.1, 1.1)
	var dmg := float(GadgetData.tier_val("decoy", "burst", tier))
	if dmg > 0.0:
		FX.blast(c, Vector3.UP, 0.9)
		FX.sfx("cannon_hit", c, -2.0, 0.08, 1.2)
		var cam := get_viewport().get_camera_3d()
		if cam and cam.global_position.distance_to(c) < 25.0:
			CombatManager.apply_camera_shake(0.25, 0.25)
		if Net.is_host():
			var hd := HitData.new()
			hd.damage = dmg
			hd.knockback_force = 7.0
			hd.stagger_duration = 0.5
			hd.hitstop_duration = 0.05
			hd.camera_shake_intensity = 0.0
			hd.impact = "punch_heavy"
			GadgetZone.hurt_at(self, global_position, BURST_R, hd, by if by and is_instance_valid(by) else self)
	queue_free()
	set_process(false)
