extends Resource
class_name HitData

@export var damage: float = 10.0
@export var knockback_force: float = 5.0
@export var hitstop_duration: float = 0.05
@export var camera_shake_intensity: float = 0.1
@export var stagger_duration: float = 0.3
## Heavy hit: throws the target off its feet (physics ragdoll, then it gets up).
@export var knockdown: bool = false
## With knockdown: cut down where it stands instead - a limp collapse in
## place, nothing thrown, back up after a moment (the katana's charged draw).
@export var crumple: bool = false
## A bullet (parrying it deflects it, but doesn't stagger the shooter).
@export var ranged: bool = false
## Damage over time (burning): the target just takes the damage - no flinch,
## no hitstop, no knockback.
@export var dot: bool = false
## Can't be blocked by a guard (fire, explosions, Armament Haki) - or, on
## an enemy's attack, parried or blocked by the player (it flashes red).
@export var unblockable: bool = false
## Struck with Armament Haki: breaks an enemy's unblockable wind-up.
@export var haki: bool = false
## Catches the target mid-move (the katana's running draw): slips past a guard,
## breaks wind-ups (the red kind too) and staggers.
@export var breaker: bool = false
## Cannon fire: the only thing that damages a ship's hull.
@export var siege: bool = false
