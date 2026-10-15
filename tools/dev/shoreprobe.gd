extends SceneTree
## CPU = GPU near the shores: the ocean shader's own wave code (ocean_waves.gdshaderinc, with the
## sea's live parameters and shore maps) evaluated on a grid round coast spots into a render
## target, read back and compared with OceanManager.get_wave_height at the same points and time.
## Spots: Brinehollow's den-side lee beach, the den climb's beach, the wake beach, the first chain
## island's dock shore. Prints max / mean difference per spot and "PROBE OK" when all are under 1 cm.
## Opens a window (GPU). Args: none.
const N := 64
const STEP := 1.3
const T := 777.3
const PROBE := """
shader_type canvas_item;
#include "res://scenes/ocean/ocean_waves.gdshaderinc"
uniform vec2 probe_origin;
uniform float probe_step;
uniform float probe_time;
uniform float probe_n;
void fragment() {
	vec2 p = probe_origin + floor(UV * probe_n) * probe_step;
	vec4 sh = shore_at(p);
	float h = wave_h(p, probe_time, 1.0, sh) + funnel(p);
	float v = clamp((h + 4.0) / 8.0, 0.0, 1.0) * 16777215.0;
	float r = floor(v / 65536.0);
	v -= r * 65536.0;
	float g = floor(v / 256.0);
	float b = v - g * 256.0;
	COLOR = vec4(r, g, b, 255.0) / 255.0;
}
"""
var t := 0.0
var spots: Array = []
var idx := 0
var wait := 0
var cam: Camera3D
var vp: SubViewport
var mat: ShaderMaterial
var oc
var worst := 0.0


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	if t < 1.5:
		return false
	if vp == null:
		var world = root.get_node("World/Islands")
		if not world.chain_ready():
			return false
		oc = root.get_node("Ocean")
		var bh = world.starter_island
		for e in [["den_lee", Vector2(-195, -99)], ["den_climb", Vector2(-137, -128)], ["wake_beach", Vector2(-53, -163)]]:
			var g: Vector3 = bh.to_global(Vector3(e[1].x, 0.0, e[1].y))
			spots.append([e[0], Vector2(g.x, g.z)])
		var isl = world.chain_islands.values()[0]
		var ds: Vector3 = isl.to_global(Vector3(isl.dock_shore.x, 0.0, isl.dock_shore.y))
		spots.append(["isle_dock", Vector2(ds.x, ds.z)])
		cam = Camera3D.new()
		root.add_child(cam)
		cam.current = true
		vp = SubViewport.new()
		vp.size = Vector2i(N, N)
		vp.disable_3d = true
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var rect := ColorRect.new()
		rect.size = Vector2(N, N)
		var sh := Shader.new()
		sh.code = PROBE
		mat = ShaderMaterial.new()
		mat.shader = sh
		rect.material = mat
		vp.add_child(rect)
		root.add_child(vp)
		_aim()
		return false
	wait += 1
	if wait == 5:
		_feed()
	if wait < 9:
		return false
	_compare()
	idx += 1
	if idx >= spots.size():
		print("PROBE %s (worst %.4f m)" % ["OK" if worst < 0.01 else "FAILED", worst])
		quit()
		return false
	_aim()
	return false


func _aim() -> void:
	var c: Vector2 = spots[idx][1]
	cam.global_position = Vector3(c.x, 30.0, c.y + 20.0)
	cam.look_at(Vector3(c.x, 0.0, c.y))
	wait = 0


## The sea's live parameters and bound shore maps into the probe.
func _feed() -> void:
	var om: ShaderMaterial = oc.ocean_material
	for u in mat.shader.get_shader_uniform_list():
		var nm: String = u["name"]
		if not nm.begins_with("probe_"):
			mat.set_shader_parameter(nm, om.get_shader_parameter(nm))
	mat.set_shader_parameter("probe_origin", _origin())
	mat.set_shader_parameter("probe_step", STEP)
	mat.set_shader_parameter("probe_time", T)
	mat.set_shader_parameter("probe_n", float(N))


func _origin() -> Vector2:
	return (spots[idx][1] as Vector2) - Vector2.ONE * (N * STEP * 0.5)


func _compare() -> void:
	var om: ShaderMaterial = oc.ocean_material
	var origin := _origin()
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var bytes := img.get_data()
	var top := 0.0
	var sum := 0.0
	var over := 0
	var shore := 0
	for y in range(N):
		for x in range(N):
			var o := (y * N + x) * 4
			var v := float(bytes[o]) * 65536.0 + float(bytes[o + 1]) * 256.0 + float(bytes[o + 2])
			var gpu := v / 16777215.0 * 8.0 - 4.0
			var p := origin + Vector2(x, y) * STEP
			var cpu: float = oc.get_wave_height(Vector3(p.x, 0.0, p.y), T)
			var dd := absf(gpu - cpu)
			top = maxf(top, dd)
			sum += dd
			if dd > 0.01:
				over += 1
			if (oc.shore_at(p.x, p.y) as Vector4).z > 0.0:
				shore += 1
	worst = maxf(worst, top)
	print("PROBE %s: %d points (%d where the swell turns to the shore), max %.4f m, mean %.5f m, %d over 1 cm; maps bound %s" % [spots[idx][0], N * N, shore, top, sum / (N * N), over,
		str(om.get_shader_parameter("shore_rect"))])
