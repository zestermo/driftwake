extends SceneTree
## Unstable updates (1.26, docs/v1_26_plan.md "Beta updates"): off by default; with them on, the updater takes the newest
## release of the list, a pre-release included and a draft never (Updater.newest), and a full update opens that
## release's own page.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var U = load("res://scripts/game/updater.gd")
	check("off by default", root.get_node("Settings").DEFAULTS["gameplay"]["beta_updates"] == false)
	var list := [
		{"tag_name": "v1.25", "draft": false, "prerelease": false, "html_url": "https://x/v1.25"},
		{"tag_name": "v1.27", "draft": true, "prerelease": false, "html_url": "https://x/v1.27"},
		{"tag_name": "v1.26.2", "draft": false, "prerelease": true, "html_url": "https://x/v1.26.2"},
		{"tag_name": "v1.26.1", "draft": false, "prerelease": true, "html_url": "https://x/v1.26.1"},
	]
	var best = U.newest(list)
	check("the newest release, unstable included, never a draft (%s)" % (best.get("tag_name") if best else "none"), best != null and best["tag_name"] == "v1.26.2")
	var u = U.new()
	root.add_child(u)
	u._use(best)
	check("...and a full update opens its own page (%s)" % U.page, U.page == "https://x/v1.26.2" and u.latest == "1.26.2")
	U.page = U.PAGE
	return TK.done(fails)
