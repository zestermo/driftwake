extends Resource
class_name ItemData

enum ItemType { LOOT, WEAPON, CONSUMABLE, GEAR }
## Tiers: a higher one hits harder (weapons), guards better (gear) and is worth
## more. A tiered copy of any item is made with ItemDB.tiered (id "<id>@<tier>").
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, ULTRA, SUPREME }
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Ultra", "Supreme"]
const RARITY_COLORS := [Color(0.92, 0.92, 0.9), Color(0.4, 0.88, 0.38), Color(0.35, 0.6, 1.0), Color(0.72, 0.4, 0.98),
	Color(1.0, 0.82, 0.22), Color(1.0, 0.22, 0.2), Color(0.04, 0.04, 0.05)]
const RARITY_DAMAGE := 0.08
const RARITY_DEFENSE := 0.25
const RARITY_VALUE := [1.0, 1.6, 2.6, 4.0, 7.0, 12.0, 20.0]

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var value: int = 1
@export var rarity: Rarity = Rarity.COMMON
@export var stackable: bool = true
@export var max_stack: int = 99
@export var item_type: ItemType = ItemType.LOOT
@export var icon: Texture2D

@export_group("Weapon")
## Model name understood by Props.weapon_mesh() ("cutlass", "axe").
@export var weapon_model: String = ""
## Which look of it (WeaponDesigns.DESIGNS; "" the plain one).
@export var design: String = ""
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


func rarity_name() -> String:
	return RARITY_NAMES[int(rarity)]


func rarity_color() -> Color:
	return RARITY_COLORS[int(rarity)]


## Text in the tier's colour needs this outline (Supreme is black: a pale edge).
func rarity_outline() -> Color:
	return Color(0.85, 0.85, 0.8) if rarity == Rarity.SUPREME else Color.BLACK


## The weapon's mesh: kind, design and tier (Props.weapon_mesh).
func model() -> String:
	return "%s:%s:%d" % [weapon_model, design, int(rarity)]


## The weapon's damage multiplier with its tier.
func power() -> float:
	return damage_mult * (1.0 + RARITY_DAMAGE * int(rarity))


## The gear's defense with its tier.
func armor() -> float:
	return defense * (1.0 + RARITY_DEFENSE * int(rarity))


## What it's worth to a trader, with its tier.
func worth() -> int:
	return int(round(value * float(RARITY_VALUE[int(rarity)])))


func type_name() -> String:
	match item_type:
		ItemType.GEAR:
			return Gear.slot_label(gear_slot)
		ItemType.WEAPON:
			return "Weapon"
		ItemType.CONSUMABLE:
			return "Consumable"
	return "Loot"
