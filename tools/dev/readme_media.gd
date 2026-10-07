extends SceneTree
## Copies the chosen renders from tools/dev/out into docs/media as JPGs for the
## README (render them first: readmeshot, polishshot, kingshot, fleetshot,
## yardshot, armorshot, seashot, newsshot).
const PICKS := {
	"title": "news_menu",
	"island": "polish_shallows_brinehollow",
	"village": "readme_village",
	"tavern": "readme_tavern",
	"fight": "readme_fight_06",
	"sailing": "polish_wake_astern",
	"fleet": "fleet_fleet",
	"seaking": "king_bite",
	"shipwright": "yard_refit_side",
	"outfits": "armor_front",
	"whirlpool": "sea_whirlpool",
	"chart": "sea_chart",
}
func _initialize():
	var dir := ProjectSettings.globalize_path("res://docs/media")
	DirAccess.make_dir_recursive_absolute(dir)
	for k in PICKS:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://tools/dev/out/%s.png" % PICKS[k]))
		img.save_jpg("%s/%s.jpg" % [dir, k], 0.92)
		print("docs/media/%s.jpg  %dx%d" % [k, img.get_width(), img.get_height()])
	quit()
