class_name Villager
extends NPC
## An NPC on a routine (KitLife's stays and walks): where it is follows the world
## clock (Weather.hour, the same on every screen), held up while a captain talks
## to it and caught up after. Far off it's checked a few times a second, past
## SHOW_R hidden; at home at night it's indoors (hidden, no collider). Near the
## local captain it says a line now and then from `ambient`.

const SHOW_R := 150.0
const NEAR_R := 70.0
const FAR_TICK := 0.3
const CATCH_UP := 1.8
const BARK_R := 6.5
const BUBBLE_TIME := 4.5

## [{"h": the hour it starts, "kind": the spot's kind, "at", "face", "act": stand/kneel/talk/home, "y" (optional)}], by hour
var stays: Array = []
## walks[k]: island points from stays[k - 1] to stays[k]; cums[k] the distance to each
var walks: Array = []
var cums: Array = []
var isl: Island
## "day"/"evening"/"night"/a spot kind -> lines it may say near a captain
var ambient: Dictionary = {}

var _k := -1
var _d := 0.0
var _acc := 0.0
var _home := false
var _bark_cd := 0.0
var _bubble: Label3D
var _bubble_t := 0.0
var _gesture_t := 0.0
static var _last_bark_tick := -100000


func follow(island: Island, s: Array, w: Array, lines: Dictionary) -> void:
	isl = island
	stays = s
	walks = w
	ambient = lines
	for pts in walks:
		cums.append(KitLife.measure(pts))
	_bark_cd = randf_range(5.0, 30.0)


## Where the routine has it at `hour`: [stay, metres along the walk to it].
func scheduled(hour: float) -> Array:
	var at := KitLife.stay_at(stays, hour)
	return [at[0], float(at[1]) * walk_speed]


## Island point and act the routine puts it at, `hour` (no holding up).
func spot_at(hour: float) -> Array:
	var at := scheduled(hour)
	return _where(at[0], at[1])


## ActorSleep judges a sleeping villager by where its routine has it now, not where it dozed off.
func sleep_pos() -> Vector3:
	var p: Vector2 = spot_at(Weather.hour())[0]
	return isl.to_global(Vector3(p.x, isl.walk_height(p.x, p.y), p.y))


func _where(k: int, d: float) -> Array:
	var cum: PackedFloat32Array = cums[k]
	var s: Dictionary = stays[k]
	if d >= cum[cum.size() - 1]:
		return [s["at"], s["face"], s["act"], true]
	var smp := KitLife.sample(walks[k], cums[k], d)
	return [smp[0], smp[1], "walk", false]


func _process(delta: float) -> void:
	_acc += delta
	var cam := humanoid._camera()
	var d2 := cam.global_position.distance_squared_to(global_position) if cam else 0.0
	var near := d2 < NEAR_R * NEAR_R
	if not near and _acc < FAR_TICK:
		return
	var dt := _acc
	_acc = 0.0
	var at := scheduled(Weather.hour())
	var to_player := 999.0
	if _player and is_instance_valid(_player):
		to_player = global_position.distance_to(_player.global_position)
	var hold := _in_dialogue or (to_player < 3.5 and not _home)
	var d0 := _d
	var k0 := _k
	var snapped := false
	if _k < 0 or not near or (at[0] != _k and at[0] != (_k + 1) % stays.size()):
		snapped = _k != at[0] or absf(_d - float(at[1])) > 2.0
		_k = at[0]
		_d = at[1]
	elif not hold:
		_advance(at, walk_speed * CATCH_UP * dt)
	var w := _where(_k, _d)
	var p: Vector2 = w[0]
	var arrived: bool = w[3]
	var s: Dictionary = stays[_k]
	position = Vector3(p.x, float(s["y"]) if arrived and s.has("y") else isl.walk_height(p.x, p.y), p.y)
	if snapped:
		reset_physics_interpolation()
	var home: bool = w[2] == "home"
	if home != _home:
		_home = home
		get_node("Body").collision_layer = 0 if home else 1
		interactable.collision_layer = 0 if home else INTERACT_LAYER
	var show := not home and d2 < SHOW_R * SHOW_R
	if visible != show:
		visible = show
	if not show:
		return
	humanoid.kneeling = w[2] == "kneel" and not hold
	var face: Vector2 = w[1]
	if hold and _player:
		var to := _player.global_position - global_position
		face = Vector2(to.x, to.z)
	var yaw := atan2(-face.x, -face.y)
	var speed := 0.0
	if not snapped and not arrived:
		speed = (_d - d0) / maxf(dt, 0.001) if _k == k0 else walk_speed
	if not near:
		_facing = yaw
		humanoid.rotation.y = yaw
		humanoid.ground_speed = speed
		name_tag.visible = false
		return
	_facing = lerp_angle(_facing, yaw, minf(6.0 * dt, 1.0))
	humanoid.rotation.y = _facing
	humanoid.ground_speed = lerpf(humanoid.ground_speed, speed, minf(8.0 * dt, 1.0))
	name_tag.visible = to_player < 7.0 and not _in_dialogue and Settings.get_value("gameplay", "name_tags")
	if not _in_dialogue:
		_gesture_t -= dt
		if w[2] != "talk":
			humanoid.talking = false
		elif _gesture_t <= 0.0:
			humanoid.talking = not humanoid.talking
			_gesture_t = randf_range(1.2, 4.0) if humanoid.talking else randf_range(2.0, 6.0)
	_bark(dt, to_player, str(s["kind"]) if arrived else "")


## On along the routine by up to `step` m: to the end of this walk, then into the next one.
func _advance(at: Array, step: float) -> void:
	while step > 0.0:
		var cum: PackedFloat32Array = cums[_k]
		if _k == at[0]:
			_d = maxf(_d, minf(_d + step, float(at[1])))
			return
		var left := cum[cum.size() - 1] - _d
		if left > step:
			_d += step
			return
		step -= maxf(left, 0.0)
		_k = (_k + 1) % stays.size()
		_d = 0.0


func _bark(dt: float, to_player: float, kind: String) -> void:
	if _bubble_t > 0.0:
		_bubble_t -= dt
		if _bubble_t <= 0.0 or _in_dialogue:
			_bubble.visible = false
			_bubble_t = 0.0
	_bark_cd -= dt
	if _bark_cd > 0.0 or to_player > BARK_R or _in_dialogue or Dialogue.active or Engine.get_physics_frames() - _last_bark_tick < 8 * Engine.physics_ticks_per_second:
		return
	_bark_cd = randf_range(35.0, 70.0)
	var h := Weather.hour()
	var pool: Array = ambient[("day" if h >= 6.0 and h < 18.0 else "evening" if h >= 18.0 and h < 22.0 else "night")].duplicate()
	pool.append_array(ambient.get(kind, []))
	_last_bark_tick = Engine.get_physics_frames()
	say(pool[randi() % pool.size()])


## A line over its head for a few seconds (no dialogue box).
func say(line: String) -> void:
	if _bubble == null:
		_bubble = Label3D.new()
		_bubble.name = "Bubble"
		_bubble.font = name_tag.font
		_bubble.font_size = 28
		_bubble.pixel_size = 0.005
		_bubble.outline_size = 8
		_bubble.width = 560.0
		_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_bubble.position = name_tag.position + Vector3(0, 0.35, 0)
		add_child(_bubble)
	_bubble.text = line
	_bubble.visible = true
	_bubble_t = BUBBLE_TIME
