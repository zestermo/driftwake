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
	if monitoring:
		# (still on from a swing ended this frame, its off deferred: a hurtbox already inside won't enter again, so
		# this swing looks for what it overlaps itself, after the frame's signals)
		_hit_overlaps.call_deferred(activations)
	monitoring = true


func _hit_overlaps(act: int) -> void:
	if active and act == activations and monitoring:
		for a in get_overlapping_areas():
			_on_area_entered(a)


## (monitoring off at the frame's end, as `active` stands then: a hit's own signal can end the swing, where setting it
## errors "blocked during in/out signal"; `active` already stops hits now, and a swing started again first keeps it on)
func deactivate() -> void:
	active = false
	hit_targets.clear()
	_sync_monitoring.call_deferred()


func _sync_monitoring() -> void:
	monitoring = active


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
		# (an AI captain's swing is the host's to judge: the guests' copies of it don't swing)
		if net and net.active and net.ignore_overlap(area) and not Duel.foes(owner, area.owner) and not (owner is Player and owner.is_ai):
			hit_targets.append(area.owner)  # (it did touch them: a ram still bounces off)
			return
		hit_targets.append(area.owner)
		var hurtbox := area as Hurtbox
		hurtbox.take_hit(hit_data, owner)
		hit_landed.emit(area.owner, hit_data)
