extends CharacterBody3D
class_name Player

enum Context { ON_FOOT, HELM }

@export var move_speed: float = 6.0
@export var sprint_speed: float = 14.0
@export var jump_force: float = 8.0
@export var gravity: float = 20.0
@export var deceleration: float = 30.0
@export var max_jumps: int = 2

@onready var player_model: Node3D = $PlayerModel
@onready var sword_pivot: Marker3D = $PlayerModel/SwordPivot
@onready var sword_hitbox: Hitbox = $PlayerModel/SwordPivot/SwordHitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health_component: HealthComponent = $HealthComponent
@onready var input_buffer: InputBuffer = $InputBuffer
@onready var state_machine: StateMachine = $StateMachine
@onready var interaction_component: InteractionComponent = $InteractionComponent
@onready var inventory_component: InventoryComponent = $InventoryComponent

var is_parrying: bool = false
var context: Context = Context.ON_FOOT
var current_ship: Ship = null
var jumps_remaining: int = 2


func _ready() -> void:
	floor_snap_length = 0.1
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(50.0)
