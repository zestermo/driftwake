class_name FireZone
extends Node3D
## Burning ground: flames over a disc that scorch (and ignite) enemies inside
## it every half second. Enemies steer around it; the player who made it is
## immune. Burns out after `duration`.

const TICK := 0.5

var radius: float = 3.0
var duration: float = 6.0
var dps: float = 10.0
var source: Node
var _t: float = 0.0
var _tick: float = 0.0
var _fx: Array = []
var _light: OmniLight3D
var _disc: MeshInstance3D
var _ending: bool = false


static func spawn(tree: SceneTree, pos: Vector3, r: float, dur: float, damage_per_sec: float, src: Node) -> FireZone:
	var z := FireZone.new()
	z.radius = r
	z.duration = dur
	z.dps = damage_per_sec
	z.source = src
	var root: Node = tree.current_scene if tree.current_scene else tree.root
	root.add_child(z)
	z.global_position = pos
	if src is Player:
		(src as Player).net_power("fire_zone", [pos, r, dur, damage_per_sec])
	return z


func _ready() -> void:
	add_to_group("fire_zones")
	# glowing scorched disc
	_disc = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.04
	cyl.radial_segments = 14
	cyl.rings = 1
	_disc.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.9, 0.22, 0.04, 0.2)
	_disc.material_override = m
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disc.position.y = 0.06
	add_child(_disc)
	# flames: one emitter per ~1.2 m of radius so big fields stay dense
	var n := clampi(int(radius * radius * 0.9), 1, 9)
	for i in range(n):
		var a := TAU * float(i) / float(n)
		var off := Vector3.ZERO if i == 0 else Vector3(sin(a), 0, cos(a)) * radius * 0.55
		var holder := Node3D.new()
		holder.position = off + Vector3(0, 0.2, 0)
		add_child(holder)
		var e := FX.flame_emitter(holder, minf(radius * 0.45, 1.3), int(clampf(radius * 7.0, 8, 22)), 0.7, 0.75)
		_fx.append(e)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.omni_range = radius * 2.2
	_light.light_energy = 1.6
	_light.position.y = 1.0
	add_child(_light)
	_tick = 0.1


## Is a point inside the fire?
func contains(p: Vector3, margin: float = 0.0) -> bool:
	if _ending:
		return false
	var d := Vector2(p.x - global_position.x, p.z - global_position.z).length()
	return d < radius + margin and absf(p.y - global_position.y) < 2.5


static func any_contains(tree: SceneTree, p: Vector3, margin: float = 0.0) -> bool:
	for z in tree.get_nodes_in_group("fire_zones"):
		if (z as FireZone).contains(p, margin):
			return true
	return false


func _physics_process(delta: float) -> void:
	_t += delta
	if _light:
		_light.light_energy = (1.4 + sin(_t * 23.0) * 0.25 + sin(_t * 9.0) * 0.2) * clampf((duration - _t) / 0.8, 0.0, 1.0)
	if _ending:
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		var pc := source.get("power") as PowerComponent if source and is_instance_valid(source) else null
		if pc:
			pc.burn_area(global_position + Vector3(0, 0.6, 0), radius, dps * TICK, 2.0, dps * 0.6)
			pc.ignite_burnables(global_position, radius)
	if _t >= duration:
		_end()


func _end() -> void:
	_ending = true
	remove_from_group("fire_zones")
	for e in _fx:
		(e as CPUParticles3D).emitting = false
	var tw := create_tween()
	tw.tween_property(_disc, "transparency", 1.0, 0.7)
	tw.tween_callback(queue_free).set_delay(0.3)
