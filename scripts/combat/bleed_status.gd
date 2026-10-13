class_name BleedStatus
extends Node3D
## Bleeding (the daggers' wounds): a little damage every half second for a while,
## no flinch, blood running off the wound. Re-applying refreshes it and deepens it,
## up to MAX_DEPTH times one wound's worth. Lives on the target on the machine that
## cut it (that machine deals the damage; the blood goes through Net.fx).

const TICK := 0.5
const MAX_DEPTH := 3.0

var target: Node3D
var hurtbox: Hurtbox
var source: Node
var time_left: float = 0.0
var dps: float = 0.0
var _cap: float = 0.0
var _tick: float = 0.0


static func apply(t: Node3D, secs: float, damage_per_sec: float, src: Node) -> void:
	if t == null or not is_instance_valid(t) or not BurnStatus.alive(t):
		return
	var hb := t.get("hurtbox") as Hurtbox
	if hb == null:
		return
	var bs := t.get_node_or_null("Bleed") as BleedStatus
	if bs == null or bs.is_queued_for_deletion():
		if bs:
			bs.name = "BleedOld"
		bs = BleedStatus.new()
		bs.name = "Bleed"
		bs.target = t
		bs.hurtbox = hb
		t.add_child(bs)
		bs._tick = TICK
		Net.fx("float_text", [t.global_position + Vector3(0, 2.1, 0), "Bleeding", Color(0.95, 0.2, 0.25), 22])
	bs.source = src
	bs.time_left = maxf(bs.time_left, secs)
	bs._cap = maxf(bs._cap, damage_per_sec * MAX_DEPTH)
	bs.dps = minf(bs.dps + damage_per_sec, bs._cap)


func depth() -> float:
	return dps / maxf(_cap / MAX_DEPTH, 0.01)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or not BurnStatus.alive(target):
		queue_free()
		return
	time_left -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		var at := target.global_position + Vector3(0, 1.05, 0)
		Net.fx("bleed", [at, Vector3(randf_range(-0.4, 0.4), -1.0, randf_range(-0.4, 0.4)), 3 + int(depth() * 2.0)])
		var hd := HitData.new()
		hd.dot = true
		hd.damage = roundf(dps * TICK)
		hd.knockback_force = 0.0
		hd.hitstop_duration = 0.0
		hd.camera_shake_intensity = 0.0
		hurtbox.take_hit(hd, source)
	if time_left <= 0.0:
		queue_free()
