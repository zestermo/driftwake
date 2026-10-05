extends SceneTree
func _initialize():
	var C = CharacterLook.CLOTH
	var specs := [["head","tricorn",{"hat":"tricorn","hat_color":C[5]}],["head","bicorne",{"hat":"bicorne","hat_color":C[8]}],["head","straw",{"hat":"straw","hat_color":C[15]}],["head","cap",{"hat":"cap","hat_color":C[9]}],["head","knit",{"hat":"knit","hat_color":C[13]}],["head","bandana",{"hat":"bandana","hat_color":C[13]}],["head","hood",{"hat":"hood","hat_color":C[6]}],
		["torso","shirt",{"top":"shirt","sleeves":"long","top_color":C[0]}],["torso","tunic",{"top":"tunic","sleeves":"short","top_color":C[11]}],["torso","blouse",{"top":"blouse","sleeves":"long","top_color":C[16]}],["vest","vest",{"vest":"vest","vest_color":C[3]}],["vest","corset",{"vest":"corset","vest_color":C[14]}],
		["coat","jacket",{"coat":"jacket","coat_color":C[12]}],["coat","longcoat",{"coat":"longcoat","coat_color":C[8]}],["coat","captain",{"coat":"captain","coat_color":C[13],"trim_color":CharacterLook.TRIM[0]}],["hands","gloves",{"gloves":true,"gloves_color":CharacterLook.LEATHER[2]}],
		["legs","trousers",{"legs":"trousers","legs_color":C[4]}],["legs","breeches",{"legs":"breeches","legs_color":C[9]}],["legs","shorts",{"legs":"shorts","legs_color":C[2]}],["legs","skirt",{"legs":"skirt","legs_color":C[10]}],
		["feet","boots",{"feet":"boots","feet_color":CharacterLook.LEATHER[1]}],["feet","tall_boots",{"feet":"tall_boots","feet_color":CharacterLook.LEATHER[0]}],["feet","shoes",{"feet":"shoes","feet_color":CharacterLook.LEATHER[2]}],
		["belt","belt",{"belt":"belt","belt_color":CharacterLook.LEATHER[1]}],["belt","sash",{"belt":"sash","sash_color":C[13]}],["belt","belt_sash",{"belt":"belt_sash","belt_color":CharacterLook.LEATHER[1],"sash_color":C[13]}],
		["accessory","scarf",{"scarf":true,"scarf_color":C[9]}],["accessory","pauldron",{"pauldron":true}],["accessory","earring",{"earring":true}],["accessory","eyepatch",{"eyepatch":true}],["accessory","pouch",{"pouch":true}],["accessory","apron",{"apron":true,"apron_color":C[0]}]]
	var cols := 8
	var sheet := Image.create(cols * 28 * 3, ((specs.size() + cols - 1) / cols) * 28 * 3, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.11, 0.16))
	for i in range(specs.size()):
		var sp: Array = specs[i]
		var it = Gear.make(sp[0], sp[1], sp[2])
		var img: Image = it.icon.get_image()
		img.resize(72, 72, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(0, 0, 72, 72), Vector2i((i % cols) * 84 + 6, (i / cols) * 84 + 6))
		print(it.display_name, "  def ", it.defense)
	sheet.save_png(OS.get_cmdline_user_args()[0])
	quit()
