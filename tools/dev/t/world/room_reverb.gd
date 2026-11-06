extends SceneTree
## A room rings (2026-11-06): with walls round you and a roof over you, Ambience's room probe says
## you're enclosed and the SFX bus's reverb comes in; out in the open it's off.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var amb
var box: StaticBody3D
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weather": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _wall(size: Vector3, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = at
	box.add_child(cs)


func _reverb_on() -> bool:
	var b := AudioServer.get_bus_index("SFX")
	for i in range(AudioServer.get_bus_effect_count(b)):
		if AudioServer.get_bus_effect(b, i).resource_name == "room":
			return AudioServer.is_bus_effect_enabled(b, i)
	return false


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			amb = root.get_node("Weather").get("_ambience")
			if amb == null:
				return false
			until = TK.wait_secs(2.0)
		1:
			check("out in the open: no room (%.2f)" % amb.room, amb.room < 0.05 and not _reverb_on())
			# a 14 x 14 m hall, 6 m high, round the captain and the camera
			box = StaticBody3D.new()
			root.add_child(box)
			var y := 3.0
			_wall(Vector3(14, 6, 0.5), Vector3(0, y + 3, -7))
			_wall(Vector3(14, 6, 0.5), Vector3(0, y + 3, 7))
			_wall(Vector3(0.5, 6, 14), Vector3(-7, y + 3, 0))
			_wall(Vector3(0.5, 6, 14), Vector3(7, y + 3, 0))
			_wall(Vector3(14, 0.5, 14), Vector3(0, y + 6.2, 0))
			until = TK.wait_secs(3.0)
		2:
			check("in a hall: the room is enclosed (%.2f, %.1f m)" % [amb.room, amb.room_size], amb.room > 0.5)
			check("the reverb is on", _reverb_on())
			box.queue_free()
			until = TK.wait_secs(3.0)
		3:
			check("out again: it fades away (%.2f)" % amb.room, amb.room < 0.05)
			return TK.done(fails)
	step += 1
	return false
