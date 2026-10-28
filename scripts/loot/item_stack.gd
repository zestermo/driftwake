extends Resource
class_name ItemStack

@export var item: ItemData
@export var quantity: int = 1
## Picked up and not looked at yet (the bag shows it NEW until it's hovered); not saved.
var fresh := false
