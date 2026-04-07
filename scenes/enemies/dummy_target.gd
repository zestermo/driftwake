extends StaticBody3D

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health_component: HealthComponent = $HealthComponent

var damage_number_scene: PackedScene
var flash_tween: Tween


var _original_color: Color


func _ready() -> void:
	damage_number_scene = load("res://scenes/effects/damage_number.tscn")
	hurtbox.hit_received.connect(_on_hit_received)
	health_component.died.connect(_on_died)
	# Create a unique material for hit flashing
	var src_mat := mesh.mesh.material as StandardMaterial3D
	if src_mat:
		var mat := src_mat.duplicate() as StandardMaterial3D
		mesh.set_surface_override_material(0, mat)
		_original_color = mat.albedo_color


func _on_hit_received(hit_data: HitData, _attacker: Node) -> void:
	health_component.take_damage(hit_data.damage)

	# Hit flash
	if flash_tween:
		flash_tween.kill()
	var mat := mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat:
		mat.albedo_color = Color(1.0, 0.3, 0.3)
		flash_tween = create_tween()
		flash_tween.tween_property(mat, "albedo_color", _original_color, 0.15)

	# Spawn damage number
	if damage_number_scene:
		var dmg_num: Node = damage_number_scene.instantiate()
		get_tree().current_scene.add_child(dmg_num)
		dmg_num.call("setup", hit_data.damage, global_position)

	# Combat feel effects
	get_node("/root/CombatManager").apply_hit_effects(hit_data)


func _on_died() -> void:
	# Reset health for now (dummy is immortal for testing)
	health_component.current_health = health_component.max_health
	health_component.health_changed.emit(health_component.current_health, health_component.max_health)
