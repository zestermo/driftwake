extends SceneTree
## The captain's body is the shonen build (long legs, physics chains, a neck joint under the head); the old art style
## option is gone, though an explicit style still builds and the body comes back from it.
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
	var b = stage.player.body_model
	check("shonen hip height %.2f" % b.hip_y, b.hip_y > 0.95)
	check("player has physics chains (%d sims)" % b._sims.size(), b._sims.size() >= 1)
	check("neck joint drives the head", b.neck != null and b.head.get_parent() == b.neck)
	check("art style option removed", root.get_node("Settings").get_value("gameplay", "art_style") == null)
	var lk: Dictionary = b.look.duplicate()
	lk["style"] = "chibi"
	b.apply_look(lk)
	check("explicit style still builds (chibi hips %.2f)" % b.hip_y, b.hip_y < 0.5)
	lk.erase("style")
	b.apply_look(lk)
	check("back to shonen", b.hip_y > 0.95 and b.weapon != null and b.weapon.get_parent() != null)
	return TK.done(fails)
