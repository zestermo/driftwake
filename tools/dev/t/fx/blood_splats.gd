extends SceneTree
## Blood splats in the dither style (1.19): FX._place_splat lays a quad on the dither_blood sheet, a round
## splat on rows 0-1 and a directed one on rows 2-3; it lands on its own material playing its row, then takes
## the shared settled material of its variant (the row's last frame), and is one of FX._splats.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fx
var step := 0
var until := 0
var fails := 0
var round_s: MeshInstance3D
var dir_s: MeshInstance3D


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			fx = root.get_node("FX")
			var at: Vector3 = stage.player.global_position + Vector3(0, 0, -3)
			round_s = fx._place_splat(at, Vector3.UP, 0.3)
			dir_s = fx._place_splat(at + Vector3(1.5, 0, 0), Vector3.UP, 0.3, Vector3.RIGHT)
			check("both on the splat quad and in the list", round_s.mesh == fx._splat_quad and dir_s.mesh == fx._splat_quad
				and fx._splats.has(round_s) and fx._splats.has(dir_s))
			var rm := round_s.material_override as ShaderMaterial
			check("landing on its own material, on the blood sheet", rm != null and not fx._splat_mats.has(rm)
				and (rm.get_shader_parameter("sheet") as Texture2D).resource_path.ends_with("dither_blood.png"))
			until = TK.wait_secs(0.4)
		1:
			var rv: int = fx._splat_mats.find(round_s.material_override)
			var dv: int = fx._splat_mats.find(dir_s.material_override)
			check("landed: round on a round variant (%d), directed on a directed one (%d)" % [rv, dv],
				rv in [0, 1] and dv in [2, 3])
			var f := float((dir_s.material_override as ShaderMaterial).get_shader_parameter("frame"))
			check("settled on its row's last frame (%.0f)" % f, is_equal_approx(f, dv * 4.0 + 3.0))
			return TK.done(fails)
	step += 1
	return false
