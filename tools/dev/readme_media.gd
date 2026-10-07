extends SceneTree
## Copies the chosen renders from tools/dev/out into docs/media as JPGs for the
## README. Render them first at the "960x540 (sharper)" preset:
##   readmeshot -- res://tools/dev/out/rm_scenes scenes   (and rm_steel steel)
##   polishshot / kingshot / fleetshot / yardshot / seashot -- res://tools/dev/out/px_<tool> psx
## plus armorshot (armor_) and newsshot (news_).
const PICKS := {
	"title": "news_menu",
	"island": "px_polishshot_shallows_brinehollow",
	"village": "rm_scenes_village",
	"tavern": "rm_scenes_tavern",
	"fight": "rm_scenes_fight_06",
	"haki_iai": "rm_steel_iai_charge_01",
	"air_slash": "rm_steel_airslash_01",
	"whirlwind": "rm_steel_whirl_01",
	"skybreaker": "rm_steel_skybreaker_02",
	"sailing": "px_polishshot_wake_astern",
	"fleet": "px_fleetshot_fleet",
	"seaking": "px_kingshot_bite",
	"shipwright": "px_yardshot_refit_side",
	"outfits": "armor_front",
	"whirlpool": "px_seashot_whirlpool",
}
func _initialize():
	var dir := ProjectSettings.globalize_path("res://docs/media")
	DirAccess.make_dir_recursive_absolute(dir)
	for k in PICKS:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://tools/dev/out/%s.png" % PICKS[k]))
		img.save_jpg("%s/%s.jpg" % [dir, k], 0.92)
		print("docs/media/%s.jpg  %dx%d" % [k, img.get_width(), img.get_height()])
	quit()
