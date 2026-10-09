class_name NPC
extends Node3D
## A talkable villager. Builds a Humanoid, a solid collider, an interaction
## zone and a floating name tag. Optionally wanders between waypoints.
##
## Configure with setup() before adding to the tree:
##   npc.setup({
##       "name": "Harbormaster Odile",
##       "dialogue": "odile",            # res://data/dialogue/odile.json
##       "look": {...},                  # see Humanoid
##       "barks": ["Fine day."],         # used when there is no dialogue file
##       "waypoints": [Vector3...],      # local positions (same space as the NPC's parent)
##       "voice": 1.0,                   # blip pitch
##   })
## `ground_func` (Callable(x, z) -> y) keeps wanderers glued to the terrain.

const INTERACT_LAYER := 512

var npc_name: String = "Villager"
var dialogue_id: String = ""
## A trader's stall (Shops): talking opens it after their line.
var shop_id: String = ""
var barks: Array = []
var voice: float = 1.0
var waypoints: Array = []
var walk_speed: float = 1.3
var ground_func: Callable

var humanoid: Humanoid
var interactable: Interactable
var name_tag: Label3D

var _wp_index: int = 0
var _pause: float = 0.0
var _facing: float = 0.0
var _in_dialogue: bool = false
var _player: Node3D
var _home_yaw: float = 0.0


func setup(cfg: Dictionary) -> NPC:
	npc_name = str(cfg.get("name", "Villager"))
	name = npc_name.validate_node_name().replace(" ", "")
	add_to_group("npcs")
	dialogue_id = str(cfg.get("dialogue", ""))
	shop_id = str(cfg.get("shop", ""))
	barks = cfg.get("barks", [])
	voice = float(cfg.get("voice", 1.0))
	waypoints = cfg.get("waypoints", [])
	walk_speed = float(cfg.get("walk_speed", 1.3))
	_facing = float(cfg.get("yaw", 0.0))
	_home_yaw = _facing

	# (one built ahead on a worker thread if there is one: a chain island's villagers)
	humanoid = Humanoid.make(cfg.get("look", {}))
	humanoid.name = "Model"
	humanoid.lod = true
	humanoid.seated = bool(cfg.get("seated", false))
	add_child(humanoid)
	humanoid.rotation.y = _facing

	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	body.add_child(cs)
	add_child(body)

	interactable = Interactable.new()
	interactable.name = "Talk"
	interactable.collision_layer = INTERACT_LAYER
	interactable.collision_mask = 0
	interactable.prompt_text = ("Trade with %s" if shop_id != "" and dialogue_id == "" else "Talk to %s") % _short_name()
	var ics := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.6
	ics.shape = sph
	ics.position = Vector3(0, 1.0, 0)
	interactable.add_child(ics)
	interactable.position = Vector3.ZERO
	add_child(interactable)
	interactable.interacted.connect(_on_interacted)

	name_tag = Label3D.new()
	name_tag.name = "NameTag"
	name_tag.text = npc_name
	name_tag.font = load("res://assets/fonts/PixelifySans-Regular.woff2")
	name_tag.font_size = 32
	name_tag.pixel_size = 0.006
	name_tag.outline_size = 8
	name_tag.modulate = Color(1.0, 0.92, 0.7)
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	name_tag.position = Vector3(0, 2.25 * float(cfg.get("look", {}).get("height", 1.0)), 0)
	name_tag.visible = false
	add_child(name_tag)
	return self


func _short_name() -> String:
	var parts := npc_name.split(" ")
	return parts[parts.size() - 1] if parts.size() > 0 else npc_name


func _ready() -> void:
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if Engine.has_singleton("Dialogue") or has_node("/root/Dialogue"):
		var dm := get_node("/root/Dialogue")
		dm.dialogue_ended.connect(_on_dialogue_ended)
		dm.line_shown.connect(_on_line_shown)


func _on_interacted(_by: Node) -> void:
	var dm := get_node_or_null("/root/Dialogue")
	if dm == null:
		return
	_in_dialogue = true
	if dialogue_id != "":
		dm.start(dialogue_id, self)
	elif barks.size() > 0:
		if shop_id != "":
			get_node("/root/GameMenu").shop_after_talk(shop_id)
		dm.say(npc_name, [barks[randi() % barks.size()]], self, voice)


func _on_dialogue_ended(_id: String) -> void:
	_in_dialogue = false
	humanoid.talking = false


func _on_line_shown(speaker: String, _text: String) -> void:
	if _in_dialogue:
		humanoid.talking = (speaker == npc_name)


## Called by the dialogue manager while text is typing for this speaker.
func set_talking(v: bool) -> void:
	humanoid.talking = v and _in_dialogue


func _process(delta: float) -> void:
	var dist_to_player := 999.0
	if _player and is_instance_valid(_player):
		dist_to_player = global_position.distance_to(_player.global_position)
	name_tag.visible = dist_to_player < 7.0 and not _in_dialogue and Settings.get_value("gameplay", "name_tags")

	var want_face_player := _in_dialogue or dist_to_player < 3.5
	var moving := false

	if not want_face_player and waypoints.size() > 0:
		moving = _wander(delta)
	elif want_face_player and _player:
		var to := _player.global_position - global_position
		_facing = lerp_angle(_facing, atan2(-to.x, -to.z), minf(6.0 * delta, 1.0))
	elif waypoints.is_empty():
		_facing = lerp_angle(_facing, _home_yaw, minf(2.0 * delta, 1.0))

	humanoid.rotation.y = _facing
	humanoid.ground_speed = lerpf(humanoid.ground_speed, walk_speed if moving else 0.0, minf(8.0 * delta, 1.0))


func _wander(delta: float) -> bool:
	if _pause > 0.0:
		_pause -= delta
		return false
	var target: Vector3 = waypoints[_wp_index]
	var flat := Vector3(target.x - position.x, 0, target.z - position.z)
	if flat.length() < 0.4:
		_wp_index = (_wp_index + 1) % waypoints.size()
		_pause = randf_range(1.5, 5.0)
		return false
	var step := flat.normalized() * walk_speed * delta
	position.x += step.x
	position.z += step.z
	if ground_func.is_valid():
		position.y = ground_func.call(position.x, position.z)
	_facing = lerp_angle(_facing, atan2(-flat.x, -flat.z), minf(6.0 * delta, 1.0))
	return true
