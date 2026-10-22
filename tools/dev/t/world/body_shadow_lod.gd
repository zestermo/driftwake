extends SceneTree
## A lod rig (a villager) casts no shadow past Humanoid.SHADOW_R from the camera and gets its parts' own settings
## back inside SHADOW_R - 4; the captain's rig keeps its shadows wherever it is.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var h
var near := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"npc": {}})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func casting(n: Node) -> int:
	var c := 0
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			c += 1
	return c


func put(d: float) -> void:
	var cam: Camera3D = stage.get_viewport().get_camera_3d()
	var at := cam.global_position + Vector3(d, 0, 0)
	stage.npc.global_position = Vector3(at.x, stage.npc.global_position.y, cam.global_position.z)
	stage.npc.reset_physics_interpolation()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			h = stage.npc.humanoid
			check("the villager's rig is a lod rig", h.lod)
			put(8.0)
			until = TK.wait_secs(0.6)
		1:
			near = casting(h)
			check("near: its parts cast (%d)" % near, near >= 3)
			put(40.0)
			until = TK.wait_secs(0.8)
		2:
			check("past %.0f m: none cast (%d)" % [h.SHADOW_R, casting(h)], casting(h) == 0)
			check("...the captain's own rig still casts (%d)" % casting(p.body_model), casting(p.body_model) >= 3)
			put(h.SHADOW_R - 2.0)
			until = TK.wait_secs(0.8)
		3:
			check("just inside SHADOW_R: still off (the hysteresis)", casting(h) == 0)
			put(8.0)
			until = TK.wait_secs(0.8)
		4:
			check("back near: the same parts cast again (%d of %d)" % [casting(h), near], casting(h) == near)
			return TK.done(fails)
	step += 1
	return false
