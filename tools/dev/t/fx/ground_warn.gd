extends SceneTree
## The dither ground warnings (1.19): FX.telegraph, FX.arc_warn and FX.lane each make one decal mesh on the
## dither materials (the telegraph's sheet, the fans' and lanes' psx_ground_warn) at TELE_ALPHA, coloured from
## the caller's colour; the telegraph's frame and the fan's and lane's front sweep to the end over the wind-up,
## and all three are gone after it.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fx
var step := 0
var until := 0
var fails := 0
var tele: Node3D
var arc: Node3D
var lane: Node3D


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _mat(holder: Node3D) -> ShaderMaterial:
	var mis := holder.find_children("*", "MeshInstance3D", true, false)
	return (mis[0] as MeshInstance3D).material_override as ShaderMaterial if mis.size() == 1 else null


func _newest(n: String) -> Node3D:
	var all := root.find_children(n, "Node3D", true, false)
	return all[-1] if not all.is_empty() else null


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			fx = root.get_node("FX")
			var at: Vector3 = stage.player.global_position + Vector3(0, 0, -5)
			fx.telegraph(at, 3.0, 1.0, Color(1.0, 0.18, 0.12))
			fx.arc_warn(at, Vector3.FORWARD, 2.0, 1.6, 1.0)
			fx.lane(at, at + Vector3(6, 0, 0), 1.5, 1.0, Color(1.0, 0.6, 0.1))
			tele = _newest("Telegraph")
			arc = _newest("ArcWarn")
			lane = _newest("Lane")
			check("each warning is there", tele != null and arc != null and lane != null)
			var tm := _mat(tele)
			var am := _mat(arc)
			var lm := _mat(lane)
			check("one decal mesh each, on shader materials", tm != null and am != null and lm != null)
			check("the telegraph reads the dither sheet in palette mode", tm.get_shader_parameter("palette_mode") == true
				and (tm.get_shader_parameter("sheet") as Texture2D).resource_path.ends_with("dither_telegraph.png"))
			check("the fan and the lane are psx_ground_warn (shapes 1 and 0)", am.shader == fx.WARN_SHADER and lm.shader == fx.WARN_SHADER
				and int(am.get_shader_parameter("shape")) == 1 and int(lm.get_shader_parameter("shape")) == 0)
			var body: Color = lm.get_shader_parameter("pal_body")
			check("coloured from the caller's colour", body.is_equal_approx(Color(1.0, 0.6, 0.1)))
			check("kept quiet (opacity %.2f)" % float(am.get_shader_parameter("opacity")),
				is_equal_approx(float(am.get_shader_parameter("opacity")), fx.TELE_ALPHA))
			until = TK.wait_secs(0.5)
		1:
			var f := float(_mat(tele).get_shader_parameter("frame"))
			var r := float(_mat(arc).get_shader_parameter("reveal"))
			var l := float(_mat(lane).get_shader_parameter("reveal"))
			check("halfway: frame %.1f, the fan's front %.2f m, the lane's %.2f m" % [f, r, l],
				f > 2.0 and f < 6.5 and r > 0.4 and r < 1.7 and l > 1.2 and l < 5.0)
			until = TK.wait_secs(0.7)
		2:
			check("all three gone after the wind-up", not is_instance_valid(tele) and not is_instance_valid(arc) and not is_instance_valid(lane))
			return TK.done(fails)
	step += 1
	return false
