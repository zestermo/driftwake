class_name PoisonStatus
extends Node3D
## Poisoned: a little damage every half second for a while (no flinch), with
## green bubbles rising off the target. Re-applying refreshes it rather than
## stacking it.

const TICK := 0.5
const GREEN := Color(0.45, 0.95, 0.25, 0.9)

var target: Node3D
var hurtbox: Hurtbox
var source: Node
var time_left: float = 0.0
var dps: float = 0.0
var _tick: float = 0.0


static func apply(t: Node3D, secs: float, damage_per_sec: float, src: Node) -> void:
	if t == null or not is_instance_valid(t) or not BurnStatus.alive(t):
		return
	var hb := t.get("hurtbox") as Hurtbox
	if hb == null:
		return
	var ps := t.get_node_or_null("Poison") as PoisonStatus
	if ps == null or ps.is_queued_for_deletion():
		if ps:
			ps.name = "PoisonOld"
		ps = PoisonStatus.new()
		ps.name = "Poison"
		ps.target = t
		ps.hurtbox = hb
		t.add_child(ps)
		ps._tick = TICK * 0.5
	ps.source = src
	ps.time_left = maxf(ps.time_left, secs)
	ps.dps = maxf(ps.dps, damage_per_sec)
	if damage_per_sec > 0.0 and t.has_method("_toast") and t.get("is_local"):
		t.call("_toast", "Poisoned!")
	# co-op: everyone sees the bubbles (only this machine deals the damage)
	if damage_per_sec > 0.0 and src is Player and (src as Player).is_local:
		var net := t.get_node_or_null("/root/Net")
		if net and net.active:
			net.event(t, "poison_fx", [secs])


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or not BurnStatus.alive(target):
		queue_free()
		return
	time_left -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		var k := float(target.get("size_k")) if target.get("size_k") != null else 1.0
		FX.poison(target.global_position + Vector3(0, 0.9 * k, 0), 3, 0.3 * k)
		if dps > 0.0:
			var hd := HitData.new()
			hd.dot = true
			hd.damage = roundf(dps * TICK)
			hd.knockback_force = 0.0
			hd.hitstop_duration = 0.0
			hd.camera_shake_intensity = 0.0
			hurtbox.take_hit(hd, source)
	if time_left <= 0.0:
		queue_free()
