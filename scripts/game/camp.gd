class_name Camp
extends Node3D
## A captain's camp (the action wheel's "Make camp", ashore): a campfire laid in front of you as you sit
## down by it. Sit by any camp's fire for REST s and you rest (GameManager.rest: health, stamina and
## energy back, and the game saved). A fire burns LIFE s, then dies down. A captain has one camp (a new
## one puts the old out); every screen sees it (Net._all_camp), a captain joining later doesn't.
## (Later: the camp as a respawn point.)

const LIFE := 240.0
const REST := 3.0
const NEAR := 3.0
const AHEAD := 1.25
const TICK := 0.25
## Enemies fighting this close: no camp.
const QUIET := 40.0

var by: int = 1
var _left := LIFE
var _sat := 0.0
var _rested := false
var _dying := false
var _fire: Node3D


## The camp whose fire `p` is beside (null: none).
static func near(p: Node3D) -> Camp:
	for c in p.get_tree().get_nodes_in_group("camps"):
		if not c._dying and (c as Node3D).global_position.distance_to(p.global_position) < NEAR + 1.0:
			return c
	return null


## The action: lay a fire in front of you (or turn to the one beside you) and sit down by it.
static func make(p: Node) -> void:
	for e in p.get_tree().get_nodes_in_group("enemies"):
		if e.has_method("in_combat") and e.in_combat() and (e as Node3D).global_position.distance_to(p.global_position) < QUIET:
			p.get_tree().call_group("hud", "show_toast", "You can't make camp with enemies about")
			return
	var camp := near(p)
	if camp:
		var to: Vector3 = camp.global_position - p.global_position
		p.player_model.rotation.y = atan2(-to.x, -to.z)
	else:
		var fwd: Vector3 = -p.player_model.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var at: Vector3 = p.global_position + fwd * AHEAD
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.2, at + Vector3.DOWN * 1.5, 1)
		var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or (hit["normal"] as Vector3).y < 0.75 or absf((hit["position"] as Vector3).y - p.global_position.y) > 0.6:
			p.get_tree().call_group("hud", "show_toast", "There's no flat ground for a fire here")
			return
		Net.everyone("_all_camp", [Net.my_id(), hit["position"], atan2(fwd.x, fwd.z)])
	p.sit_ground()


## (every machine, Net._all_camp) captain `who`'s camp, at `pos`; their old one dies down.
static func place(tree: SceneTree, who: int, pos: Vector3, yaw: float) -> Camp:
	var scene := tree.current_scene
	var old := scene.get_node_or_null("Camp_%d" % who) as Camp
	if old:
		old.name = "Camp_%d_out" % who
		old.burn_out()
	var c := Camp.new()
	c.name = "Camp_%d" % who
	c.by = who
	scene.add_child(c)
	c.global_position = pos
	c.rotation.y = yaw
	return c


func _ready() -> void:
	add_to_group("camps")
	_fire = Props.campfire()
	add_child(_fire)
	for n in _fire.get_children():
		if n is MeshInstance3D:
			(n as MeshInstance3D).visibility_range_end = 90.0
			(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif n is CPUParticles3D:
			(n as CPUParticles3D).visibility_range_end = 60.0
		elif n is OmniLight3D:
			(n as OmniLight3D).distance_fade_enabled = true
			(n as OmniLight3D).distance_fade_begin = 45.0
			(n as OmniLight3D).distance_fade_length = 10.0
	var snd := AudioStreamPlayer3D.new()
	snd.name = "Crackle"
	snd.stream = load("res://assets/audio/campfire_loop.wav")
	snd.unit_size = 4.0
	snd.max_distance = 30.0
	snd.volume_db = -4.0
	snd.autoplay = true
	snd.bus = "Ambience"
	add_child(snd)
	var t := Timer.new()
	t.name = "Tick"
	t.wait_time = TICK
	t.timeout.connect(_tick)
	add_child(t)
	t.start()
	FX.dust(global_position + Vector3.UP * 0.1, 5, 0.4)


func _tick() -> void:
	_left -= TICK
	if _left <= 0.0:
		burn_out()
		return
	var me := get_tree().get_first_node_in_group("player") as Player
	if me and me.current_state_name() == "Sit" and me.global_position.distance_to(global_position) < NEAR:
		_sat += TICK
		if _sat >= REST and not _rested:
			_rested = true
			get_tree().call_group("hud", "show_toast", GameManager.rest(me))
	else:
		_sat = 0.0
		_rested = false


## The fire dies down and the camp goes.
func burn_out() -> void:
	if _dying:
		return
	_dying = true
	remove_from_group("camps")
	($Tick as Timer).stop()
	($Crackle as AudioStreamPlayer3D).stop()
	(_fire.get_node("Flames") as CPUParticles3D).emitting = false
	_fire.get_node("FireLight").queue_free()
	get_tree().create_timer(1.5).timeout.connect(queue_free)
