extends SceneTree
## The flipbook sheet library (tools/texture_gen/gen_flipbooks.py): every sheet FX names exists with its
## import (mipmaps on, lossless, kept so in 3D), is 4x4 frames of 64 px that change as they play, keeps
## its alpha on four dithered levels, and gets one shared material (additive for the light sheets,
## alpha-blended for matter).
const TK := preload("res://tools/dev/test_kit.gd")
const DEP := preload("res://scripts/game/dep_record.gd")
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## Opaque pixels in frame i of a 4x4 sheet of 64 px frames.
func _cover(img: Image, i: int) -> int:
	var n := 0
	for y in range(64):
		for x in range(64):
			if img.get_pixel((i % 4) * 64 + x, (i / 4) * 64 + y).a > 0.1:
				n += 1
	return n


func _alpha_levels(img: Image) -> int:
	var seen := {}
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			seen[img.get_pixel(x, y).a8] = true
	return seen.size()


func _process(_d: float) -> bool:
	var fx = root.get_node("FX")
	for s in fx.FLIP_SHEETS:
		var path := "res://assets/textures/fx/flip_%s.png" % s
		var imp := path + ".import"
		DEP.note_dep(imp)
		check("%s: the sheet and its import exist" % s, FileAccess.file_exists(path) and FileAccess.file_exists(imp))
		var txt := FileAccess.get_file_as_string(imp)
		check("%s: imported with mipmaps, lossless, kept so in 3D" % s, txt.contains("mipmaps/generate=true")
			and txt.contains("compress/mode=0") and txt.contains("detect_3d/compress_to=0"))
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		check("%s: 4x4 frames of 64 px" % s, img.get_size() == Vector2i(256, 256))
		var c := [_cover(img, 0), _cover(img, 5), _cover(img, 10), _cover(img, 15)]
		check("%s: it plays (frames 0, 5, 10, 15 differ: %s)" % [s, str(c)], c[0] != c[1] and c[1] != c[2] and c[2] != c[3])
		check("%s: alpha on four dithered levels" % s, _alpha_levels(img) <= 4)
		var m: StandardMaterial3D = fx._flip_mat(s)
		var add: bool = s in fx.FLIP_ADD
		check("%s: one shared 4x4 material, %s" % [s, "additive" if add else "alpha-blended"], m == fx._flip_mat(s)
			and m.particles_anim_h_frames == 4 and m.particles_anim_v_frames == 4 and not m.particles_anim_loop
			and (m.blend_mode == BaseMaterial3D.BLEND_MODE_ADD) == add
			and m.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS)
	check("the library is 18 sheets (%d)" % fx.FLIP_SHEETS.size(), fx.FLIP_SHEETS.size() == 18)
	return TK.done(fails)
