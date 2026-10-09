class_name OverheadBar
extends Node3D
## A miniboss's name over its head, with its health bar showing there for a
## while after each hit. A ship's is bigger, seen from further and can stay
## up the whole fight (`always`).

const SHOW_FOR := 5.0
const FADE := 0.6

## Show the bar all the time, not just after a hit.
var always: bool = false
var _label: Label3D
var _bar: MeshInstance3D
var _mat: ShaderMaterial
var _t := 0.0
var _hp := -1.0
var _flash := 0.0

static var _shader: Shader


## `size` scales the name and bar (1 = a person's); `far` is how far off they show.
func setup(display_name: String, height: float, size: float = 1.0, far: float = 45.0) -> OverheadBar:
	name = "OverheadBar"
	position = Vector3(0, height, 0)
	_label = Label3D.new()
	_label.font = load("res://assets/fonts/PixelifySans-Regular.woff2")
	_label.font_size = 30
	_label.pixel_size = 0.007 * size
	_label.outline_size = 10
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_label.modulate = Color(1.0, 0.72, 0.45)
	_label.text = display_name
	_label.position = Vector3(0, 0.2 * size, 0)
	_label.visibility_range_end = far
	add_child(_label)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_test_disabled;
uniform float frac = 1.0;
uniform float flash = 0.0;
uniform float alpha = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 b = vec2(0.012, 0.14);
	vec3 c = vec3(0.05, 0.03, 0.03);
	if (UV.x > b.x && UV.x < 1.0 - b.x && UV.y > b.y && UV.y < 1.0 - b.y) {
		float x = (UV.x - b.x) / (1.0 - 2.0 * b.x);
		c = x < frac ? mix(vec3(0.85, 0.16, 0.1), vec3(1.0, 0.45, 0.3), step(UV.y, 0.42)) : vec3(0.18, 0.1, 0.1);
		c = mix(c, vec3(1.0), flash);
	}
	ALBEDO = c;
	ALPHA = alpha;
}
"""
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.render_priority = 1
	var q := QuadMesh.new()
	# (the bar's shader billboards it and drops the node's scale: size it here)
	q.size = Vector2(1.2, 0.11) * size
	_bar = MeshInstance3D.new()
	_bar.mesh = q
	_bar.material_override = _mat
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.visibility_range_end = far
	_bar.visible = false
	add_child(_bar)
	return self


## Follow its health (0..1 of `max_hp`): a drop shows the bar for a while.
func track(hp: float, max_hp: float) -> void:
	if _hp >= 0.0 and hp < _hp - 0.01:
		_t = SHOW_FOR
		_flash = 0.8
	_hp = hp
	_mat.set_shader_parameter("frac", clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0))


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 4.0, 0.0)
	_mat.set_shader_parameter("flash", _flash)
	_t -= delta
	_bar.visible = always or _t > 0.0
	_mat.set_shader_parameter("alpha", 1.0 if always else clampf(_t / FADE, 0.0, 1.0))
