extends Area3D
class_name Hitbox

## A hurtbox was struck (target = the hurtbox's owner).
signal hit_landed(target: Node, data: HitData)

@export var hit_data: HitData

var active: bool = false
var hit_targets: Array[Node] = []
## Counts activations (co-op: other machines see each new swing).
var activations: int = 0


func activate(data: HitData = null) -> void:
	if data:
		hit_data = data
	active = true
	activations += 1
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
		# co-op: another machine's captain decides for themselves whether
		# this swing touched them (they see it too)
		var net := get_node_or_null("/root/Net")
		if net and net.active and net.ignore_overlap(area):
			hit_targets.append(area.owner)  # (it did touch them: a ram still bounces off)
			return
		hit_targets.append(area.owner)
		var hurtbox := area as Hurtbox
		hurtbox.take_hit(hit_data, owner)
		hit_landed.emit(area.owner, hit_data)
