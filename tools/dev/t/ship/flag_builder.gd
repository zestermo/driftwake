extends SceneTree
## Ship looks (1.29): an old save's kit gets the new paint channels at her old look (natural rails and spars, the pale
## deck, no stripe) and keeps its emblem and figurehead; the jolly roger builder draws a skull, what's crossed behind it
## and a headpiece into the flag in the mark colour (every pick a different flag; skull 0 is the old emblem flag
## pixel for pixel); the paint lands on her (rails, spars, deck, a stripe); all ten figureheads build. Writes the
## flags as a sheet to tools/dev/out/shipshape/flags.png.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var K = load("res://scripts/ship/ship_kit.gd")
	match step:
		0:
			var old: Dictionary = K.merged({"hull": 2, "emblem": 3, "figure": 2})
			check("an old kit: natural rails and spars, the pale deck, no stripe, no jolly roger", int(old["rail"]) == 0 and int(old["spar"]) == 0 and int(old["deck"]) == 0 and int(old["stripe"]) == 0 and int(old["skull"]) == 0)
			check("...its emblem and figurehead kept", int(old["emblem"]) == 3 and int(old["figure"]) == 2)
			var plain: Image = K.flag_image(old)
			var with0: Image = K.flag_image(old.merged({"crossed": 2, "headpiece": 1}, true))
			check("skull 0: the emblem flag, pixel for pixel", plain.get_data() == with0.get_data())
			var seen := {}
			var sheet := Image.create(K.FLAG_W * 6, K.FLAG_H * 9, false, Image.FORMAT_RGBA8)
			var k := 0
			for s in range(1, K.SKULLS.size()):
				for c in range(K.CROSSED.size()):
					for h in [0, 1, 3, 4, 5, 2]:
						var img: Image = K.flag_image(old.merged({"skull": s, "crossed": c, "headpiece": h, "field": 1, "mark": 0}, true))
						seen[img.get_data().hex_encode().sha256_text()] = true
						if c % 2 == 0 and k < 54:
							sheet.blit_rect(img, Rect2i(0, 0, K.FLAG_W, K.FLAG_H), Vector2i((k % 6) * K.FLAG_W, (k / 6) * K.FLAG_H))
							k += 1
			var total: int = (K.SKULLS.size() - 1) * K.CROSSED.size() * 6
			print("   %d jolly rogers, %d different" % [total, seen.size()])
			check("nearly every skull, crossing and headpiece a different flag (horns on the horned skull overlap)", seen.size() >= total * 0.95)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/dev/out/shipshape"))
			sheet.resize(sheet.get_width() * 4, sheet.get_height() * 4, Image.INTERPOLATE_NEAREST)
			sheet.save_png("res://tools/dev/out/shipshape/flags.png")
			check("the sail carries the jolly roger too", K.sail_emblem_image(old.merged({"emblem": 0, "skull": 2}, true)) != null)
			var ship = stage.ship
			ship.apply_kit({"rail": 3, "spar": 2, "deck": 2, "stripe": 3})
			var trims := 0
			for i in range(ship._psx_model.mesh.get_surface_count()):
				var o = ship._psx_model.get_surface_override_material(i)
				if o and o.get_shader_parameter("albedo_color").is_equal_approx(K.RAILS[3][1]):
					trims += 1
			check("painted: white rails and trim on her", trims > 0)
			check("...black spars on the yard", ship._yard_node.material_override.get_shader_parameter("albedo_color").is_equal_approx(K.SPARS[2][1]))
			check("...a dark oak deck", ship._deck_tint.is_equal_approx(K.DECKS[2][1]))
			check("...a gold stripe down her sides", ship._layout_root.get_node_or_null("Stripe") != null)
			ship.apply_kit({})
			check("...and gone with none", ship._layout_root.get_node_or_null("Stripe") == null)
			var built := 0
			for f in range(1, K.FIGURES.size()):
				var mi = K.figurehead(f)
				if mi and mi.mesh.get_surface_count() > 0:
					built += 1
				mi.free()
			check("ten figureheads, each a model (%d)" % built, K.FIGURES.size() == 11 and built == 10)
			return TK.done(fails)
	step += 1
	return false
