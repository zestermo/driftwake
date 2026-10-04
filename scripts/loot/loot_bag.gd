extends StaticBody3D
class_name LootBag

var contents: Array[ItemStack] = []
var is_recovery_bag: bool = false
## Placed chests have an id so the save remembers they've been opened.
var save_id: String = ""

@onready var interactable: Interactable = $Interactable
@onready var mesh: MeshInstance3D = $MeshInstance3D

var _glow_tween: Tween


func _ready() -> void:
	interactable.interacted.connect(_on_picked_up)
	interactable.prompt_text = "Pick up loot" if not is_recovery_bag else "Recover lost loot"
	if is_recovery_bag:
		_start_glow()


func setup(loot: Array[ItemStack], recovery: bool = false) -> void:
	contents = loot
	is_recovery_bag = recovery


func _on_picked_up(player: Player) -> void:
	var inventory := player.get_node("InventoryComponent") as InventoryComponent
	var net := get_node_or_null("/root/Net")
	if inventory:
		for stack in contents:
			# one of each Devil Fruit per world: in co-op every captain opens
			# their own copy of a chest, but only the first finds the fruit
			if stack.item.devil_fruit != "" and net:
				if not net.claim_fruit(stack.item.id):
					player.call("_toast", "The %s is gone - a crewmate got here first" % stack.item.display_name)
					continue
			inventory.add_item(stack.item, stack.quantity)
	var gm := get_node_or_null("/root/GameManager")
	if gm and save_id != "":
		gm.mark_opened(save_id)
	queue_free()


func _start_glow() -> void:
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(mesh, "scale", Vector3(1.2, 1.2, 1.2), 0.5)
	_glow_tween.tween_property(mesh, "scale", Vector3(1.0, 1.0, 1.0), 0.5)
