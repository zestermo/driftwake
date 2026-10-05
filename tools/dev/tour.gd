extends SceneTree
## Takes a series of screenshots around Brinehollow (island-local coords + center offset).
var frames := 0
var cam: Camera3D
var shots: Array = []
var idx := 0
var wait := 0
var out_dir := "res://tools/dev/out/tour2/"
const C := Vector3(150, 0, 150)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	change_scene_to_file("res://scenes/world/world.tscn")

func _setup_shots() -> void:
	var isl = root.get_node("World/Islands/Brinehollow")
	var v: Vector2 = isl.VILLAGE
	var d: Vector2 = isl.dock_shore
	var hy = func(p: Vector2) -> float: return isl.hv(p)
	var sh = isl.get_parent().get_parent().get_node("Ship")
	var sp: Vector3 = sh.global_position - C
	shots = [
		["cove2", Vector3(isl.CAMP.x - 9, hy.call(isl.CAMP) + 3, isl.CAMP.y - 7), Vector3(isl.CAMP.x + 3, hy.call(isl.CAMP) + 0.5, isl.CAMP.y + 3)],
		["ship", sp + Vector3(12, 6, 10), sp + Vector3(0, 2, 0)],
		["ocean", Vector3(d.x - 40, 6, d.y - 40), Vector3(d.x - 80, 0, d.y - 120)],
		["hill_view", Vector3(isl.HILL.x - 6, hy.call(isl.HILL) + 3, isl.HILL.y + 4), Vector3(0, 4, -40)],
	]

func _process(_d: float) -> bool:
	frames += 1
	if frames == 4:
		_setup_shots()
		cam = Camera3D.new()
		cam.far = 4000
		root.add_child(cam)
	if frames < 30 or idx >= shots.size():
		if idx >= shots.size() and frames > 30:
			quit()
		return false
	var s: Array = shots[idx]
	cam.global_position = C + s[1]
	cam.look_at(C + s[2])
	cam.make_current()
	wait += 1
	if wait == 3:
		root.get_texture().get_image().save_png(out_dir + s[0] + ".png")
		print("SAVED ", s[0])
		wait = 0
		idx += 1
	return false
