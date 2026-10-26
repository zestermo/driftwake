class_name EliteTraits
extends RefCounted
## Elites (1.23, docs/v1_23_previews.md section 4): one in 6 grunts on tier 2+ islands (Levels.tier), one in 4 on
## tier 3+, each with one trait and an aura of its colour while it fights:
##   armoured - +50% poise (and a mail shirt)        berserk - quicker, never flinches under 30% health
##   quick    - dodges far more, shorter tells        burning - its blows set you alight
## Rolled from the grunt's seed and level, so every co-op machine gets the same one.

const KINDS := ["armoured", "berserk", "quick", "burning"]
const COLOR := {"armoured": Color(0.72, 0.8, 0.95), "berserk": Color(0.95, 0.18, 0.12), "quick": Color(0.45, 0.95, 1.0),
	"burning": Color(1.0, 0.55, 0.12)}
const POISE_K := {"armoured": 1.5}
const BERSERK_SPEED := 1.25
const BERSERK_BELOW := 0.3
const QUICK_DODGE := 0.95
const QUICK_TELL := 0.7
const BURN := Vector2(3.0, 4.0)


## The trait a grunt rolls ("" = none): `seed_value` and `level` as the camp set them up.
static func roll(seed_value: int, level: int) -> String:
	var tier := Levels.tier(level)
	if level <= 0 or tier < 2:
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["elite", seed_value, level])
	if rng.randf() >= (0.25 if tier >= 3 else 1.0 / 6.0):
		return ""
	return str(KINDS[rng.randi() % KINDS.size()])


## Its aura: a few wisps of the trait's colour rising off the body, on while `on` (in a fight).
static func aura(body: Node3D, kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "EliteAura"
	p.amount = 14
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.3, 0.6, 0.3)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 0.8, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var col: Color = COLOR[kind]
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	grad.colors = PackedColorArray([Color(col.r, col.g, col.b, 0.0), Color(col.r, col.g, col.b, 0.8), Color(col.r, col.g, col.b, 0.0)])
	p.color_ramp = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	quad.material = body.get_node("/root/FX").get("_spark_mat")
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_range_end = 45.0
	p.emitting = false
	body.add_child(p)
	p.position = Vector3(0, 1.0, 0)
	return p
