extends Area3D
class_name Hitbox

@export var hit_data: HitData

var active: bool = false
var hit_targets: Array[Node] = []


func activate(data: HitData = null) -> void:
	if data:
		hit_data = data
	active = true
	hit_targets.clear()
	monitoring = true


func deactivate() -> void:
	active = false
	monitoring = false
	hit_targets.clear()


func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area3D) -> void:
	if not active:
		return
	if area is Hurtbox and area.owner not in hit_targets:
		hit_targets.append(area.owner)
		var hurtbox := area as Hurtbox
		hurtbox.take_hit(hit_data, owner)
