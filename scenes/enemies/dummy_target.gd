extends StaticBody3D
## Training dummy: takes hits, shows damage numbers, never dies.

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health_component: HealthComponent = $HealthComponent

var damage_number_scene: PackedScene
var flash_tween: Tween
var _wobble: float = 0.0
var _flash_mats: Array[ShaderMaterial] = []


func _ready() -> void:
	damage_number_scene = load("res://scenes/effects/damage_number.tscn")
	hurtbox.hit_received.connect(_on_hit_received)
	health_component.died.connect(_on_died)
	# PSX straw dummy look (mesh origin at the ground)
	mesh.mesh = Props.straw_dummy_mesh()
	mesh.position = Vector3.ZERO
	# own material copies so the hit flash only tints this dummy
	for i in range(mesh.mesh.get_surface_count()):
		var m := mesh.mesh.surface_get_material(i)
		if m is ShaderMaterial:
			var dup := (m as ShaderMaterial).duplicate() as ShaderMaterial
			mesh.set_surface_override_material(i, dup)
			_flash_mats.append(dup)


func _process(delta: float) -> void:
	if _wobble > 0.0:
		_wobble = maxf(_wobble - delta * 3.0, 0.0)
		mesh.rotation.z = sin(_wobble * 25.0) * 0.12 * _wobble
	else:
		mesh.rotation.z = 0.0


func _set_tint(c: Color) -> void:
	for m in _flash_mats:
		m.set_shader_parameter("tint_mul", c)


func _on_hit_received(hit_data: HitData, _attacker: Node) -> void:
	health_component.take_damage(hit_data.damage)
	_wobble = 1.0

	# Hit flash
	if flash_tween:
		flash_tween.kill()
	_set_tint(Color(2.2, 0.7, 0.6))
	flash_tween = create_tween()
	flash_tween.tween_method(_set_tint, Color(2.2, 0.7, 0.6), Color.WHITE, 0.18)

	if damage_number_scene:
		var dmg_num: Node = damage_number_scene.instantiate()
		get_tree().current_scene.add_child(dmg_num)
		dmg_num.call("setup", hit_data.damage, global_position + Vector3(0, 1.2, 0))

	# impact sparks on the side facing the attacker
	var hit_pos := global_position + Vector3(0, 1.2, 0)
	if _attacker is Node3D:
		var to_attacker := ((_attacker as Node3D).global_position - global_position)
		to_attacker.y = 0.0
		hit_pos += to_attacker.normalized() * 0.35
	FX.impact(hit_pos)
	FX.sfx("hit", global_position, -2.0, 0.1, 1.15 if hit_data.damage < 20.0 else 0.85)
	get_node("/root/CombatManager").apply_hit_effects(hit_data)


func _on_died() -> void:
	# Dummy is immortal for testing
	health_component.current_health = health_component.max_health
	health_component.health_changed.emit(health_component.current_health, health_component.max_health)
