extends Node3D
## One of the fog isle's old lantern posts (FogPlaces): an iron post with an arm and a caged lantern, cold and black
## till a captain lights it (F: "Light the lantern"). Its lit state is the world's (Net.world_flag `key`: every
## machine, saved, a late joiner's too), read back twice a second. Lit, it burns warm (its glass glows, a light the
## camera fades out far off) and FogPlaces counts it: the fog thins round it and the dead keep out of its glow.

const LAMP := Color(1.0, 0.76, 0.42)
const POST_H := 2.7

var key := ""
var lit := false
var _head: MeshInstance3D
var _light: OmniLight3D
var _use: Interactable
var _t := 0.0

static var _post_mesh: ArrayMesh
static var _cold: Material
static var _warm: Material


static func _meshes() -> void:
	if _post_mesh:
		return
	var iron := PSXMat.flat(Color(0.12, 0.12, 0.13))
	var mb := MeshBuilder.new()
	mb.add_box(iron, Transform3D(Basis(), Vector3(0, POST_H * 0.5, 0)), Vector3(0.12, POST_H, 0.12))
	mb.add_box(iron, Transform3D(Basis(), Vector3(0, 0.08, 0)), Vector3(0.36, 0.16, 0.36))
	mb.add_box(iron, Transform3D(Basis(), Vector3(0.32, POST_H - 0.12, 0)), Vector3(0.7, 0.06, 0.06))
	mb.add_box(iron, Transform3D(Basis(), Vector3(0.6, POST_H - 0.3, 0)), Vector3(0.28, 0.06, 0.28))
	mb.add_cone(iron, Transform3D(Basis(), Vector3(0.6, POST_H - 0.75, 0)), 0.2, 0.18, 4)
	_post_mesh = mb.commit()
	_cold = PSXMat.flat(Color(0.1, 0.12, 0.12))
	_warm = PSXMat.glow(LAMP, 2.2)


func _ready() -> void:
	add_to_group("fog_lanterns")
	_meshes()
	var post := MeshInstance3D.new()
	post.name = "Post"
	post.mesh = _post_mesh
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	post.visibility_range_end = 220.0
	add_child(post)
	_head = MeshInstance3D.new()
	_head.name = "Glass"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.34, 0.24)
	_head.mesh = bm
	_head.position = Vector3(0.6, POST_H - 0.55, 0)
	_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.visibility_range_end = 400.0
	add_child(_head)
	var col := StaticBody3D.new()
	col.name = "Body"
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.2, POST_H, 0.2)
	cs.shape = sh
	cs.position = Vector3(0, POST_H * 0.5, 0)
	col.add_child(cs)
	add_child(col)
	_use = Interactable.new()
	_use.name = "Light"
	_use.prompt_text = "Light the lantern"
	_use.gesture = "reach"
	_use.collision_layer = 512
	_use.collision_mask = 0
	_use.reach = 2.4
	var us := CollisionShape3D.new()
	var ush := SphereShape3D.new()
	ush.radius = 1.4
	us.shape = ush
	us.position = Vector3(0.3, 1.2, 0)
	_use.add_child(us)
	add_child(_use)
	_use.interacted.connect(_on_light)
	_set_lit(_flagged())


func _flagged() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	return gm != null and key != "" and gm.world_flags.has(key)


func _on_light(_p: Player) -> void:
	if lit:
		return
	Net.world_flag(key)
	var at := global_position + Vector3(0.6, POST_H - 0.55, 0).rotated(Vector3.UP, rotation.y)
	Net.fx("sparkle", [at, 18, LAMP])
	Net.fx("sfx", ["fire_start" if FX.SOUNDS.has("fire_start") else "whoosh", at, -6.0, 0.05, 1.2])
	_set_lit(true)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var f := _flagged()
	if f != lit:
		_set_lit(f)


func _set_lit(on: bool) -> void:
	lit = on
	_head.material_override = _warm if on else _cold
	_use.enabled = not on
	_use.prompt_text = "Light the lantern"
	if on and _light == null:
		_light = OmniLight3D.new()
		_light.name = "Flame"
		_light.light_color = LAMP
		_light.light_energy = 1.4
		_light.omni_range = 9.0
		_light.shadow_enabled = false
		_light.distance_fade_enabled = true
		_light.distance_fade_begin = 50.0
		_light.distance_fade_length = 20.0
		_light.position = _head.position
		add_child(_light)
	elif not on and _light:
		_light.queue_free()
		_light = null
