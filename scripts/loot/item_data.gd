extends Resource
class_name ItemData

enum ItemType { LOOT, WEAPON, CONSUMABLE, GEAR }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var value: int = 1
@export var stackable: bool = true
@export var max_stack: int = 99
@export var item_type: ItemType = ItemType.LOOT
@export var icon: Texture2D

@export_group("Weapon")
## Model name understood by Props.weapon_mesh() ("cutlass", "axe").
@export var weapon_model: String = ""
@export var damage_mult: float = 1.0

@export_group("Gear")
## Equipment slot kind: head, torso, vest, coat, hands, legs, feet, belt, accessory.
@export var gear_slot: String = ""
## CharacterLook keys this piece sets when worn (e.g. {"coat": "longcoat", "coat_color": ...}).
@export var look: Dictionary = {}
@export var defense: float = 0.0
## Icon shape for runtime gear icons (see GearIcons).
@export var icon_kind: String = ""

@export_group("Consumable")
@export var heal_amount: float = 0.0
@export var use_time: float = 1.0
## A Devil Fruit (fruit id, see DevilFruits): eating it is permanent.
@export var devil_fruit: String = ""


## Loot is what gets dropped on death and stored when banking.
func is_loot() -> bool:
	return item_type == ItemType.LOOT


func is_weapon() -> bool:
	return item_type == ItemType.WEAPON


func is_consumable() -> bool:
	return item_type == ItemType.CONSUMABLE


func is_gear() -> bool:
	return item_type == ItemType.GEAR


func type_name() -> String:
	match item_type:
		ItemType.GEAR:
			return Gear.slot_label(gear_slot)
		ItemType.WEAPON:
			return "Weapon"
		ItemType.CONSUMABLE:
			return "Consumable"
	return "Loot"
