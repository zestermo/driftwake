class_name BurnStatus
extends Node3D
## Burning: a target set ablaze takes a little damage every half second
## (damage over time, no flinch) with flames licking off it. Re-applying
## refreshes the burn rather than stacking it.

const TICK := 0.5

var target: Node3D
var hurtbox: Hurtbox
var source: Node
var time_left: float = 0.0
var dps: float = 0.0
var _tick: float = 0.0
var _fx: CPUParticles3D
var _ending: bool = false


static func apply(t: Node3D, secs: float, damage_per_sec: float, src: Node) -> void:
	if t == null or not is_instance_valid(t) or not BurnStatus.alive(t):
		return
	var hb := t.get("hurtbox") as Hurtbox
	if hb == null:
		return
	var b := t.get_node_or_null("Burn") as BurnStatus
	if b == null or b._ending:
		if b:
			b.name = "BurnOld"
		b = BurnStatus.new()
		b.name = "Burn"
		b.target = t
		b.hurtbox = hb
		t.add_child(b)
		b._tick = TICK * 0.5
	b.source = src
	b.time_left = maxf(b.time_left, secs)
	b.dps = maxf(b.dps, damage_per_sec)
	# co-op: everyone sees it burn (only this machine deals the damage)
	if damage_per_sec > 0.0 and src is Player and (src as Player).is_local:
		var net := t.get_node_or_null("/root/Net")
		if net and net.active:
			net.event(t, "burn_fx", [secs])


static func alive(t: Node) -> bool:
	var hc := t.get("health") as HealthComponent
	if hc == null:
		hc = t.get_node_or_null("HealthComponent") as HealthComponent
	return hc == null or hc.current_health > 0.0


func _ready() -> void:
	top_level = true
	_place()
	var r := 0.25
	if target.has_method("get") and target.get("size_k") != null:
		r = 0.2 * float(target.get("size_k"))
	_fx = FX.flame_emitter(self, r, 12, 0.42, 0.55, true)


func _place() -> void:
	if hurtbox and is_instance_valid(hurtbox):
		global_position = hurtbox.global_position


func _physics_process(delta: float) -> void:
	if _ending:
		return
	if target == null or not is_instance_valid(target) or not BurnStatus.alive(target):
		_end()
		return
	_place()
	time_left -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		if dps <= 0.0:
			if time_left <= 0.0:
				_end()
			return  # (just the flames: someone else's burn)
		var hd := HitData.new()
		hd.dot = true
		hd.damage = roundf(dps * TICK)
		hd.knockback_force = 0.0
		hd.hitstop_duration = 0.0
		hd.camera_shake_intensity = 0.0
		hurtbox.take_hit(hd, source)
		if source and is_instance_valid(source) and source.get("power") is PowerComponent:
			(source.get("power") as PowerComponent).add_ult(hd.damage)
	if time_left <= 0.0:
		_end()


func _end() -> void:
	_ending = true
	if _fx:
		_fx.emitting = false
	get_tree().create_timer(0.7).timeout.connect(queue_free)
