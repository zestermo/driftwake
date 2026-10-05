extends SceneTree
var frames := 0
func _initialize() -> void:
	change_scene_to_file("res://scenes/world/world.tscn")
func _physics_process(_d: float) -> bool:
	frames += 1
	if frames == 120:
		var cam = root.get_viewport().get_camera_3d()
		var fwd = -cam.global_basis.z
		print("cam pos ", cam.global_position, " fwd ", fwd, " near ", cam.near, " far ", cam.far, " fov ", cam.fov, " path ", cam.get_path())
		print("cam basis ", cam.global_basis)
		var space = cam.get_world_3d().direct_space_state
		var q = PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + fwd * 500.0)
		var hit = space.intersect_ray(q)
		print("ray hit: ", hit.get("collider"), " at ", hit.get("position"))
		var rig = cam.get_parent().get_parent()
		print("rig ", rig.name, " rot ", rig.rotation, " spring rot ", cam.get_parent().rotation, " scale ", rig.scale)
		quit()
	return false
