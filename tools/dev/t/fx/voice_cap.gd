extends SceneTree
## Human voice one-shots never stack: a cooldown between them, and at most fx.VOICE_MAX near the listener.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var fx


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})
	fx = root.get_node("FX")


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _voices() -> int:
	return fx._voices.filter(func(v): return is_instance_valid(v) and v.playing).size()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var at: Vector3 = stage.player.global_position + Vector3(0, 0, -5)
	match step:
		0:
			fx.sfx("laugh", at)
			fx.sfx("cheer", at)
			check("a second voice in the same instant is dropped", _voices() == 1)
			until = TK.wait_ticks(fx.VOICE_GAP + 2)
		1:
			fx.sfx("cheer", at)
			check("after the gap a second plays", _voices() == 2)
			until = TK.wait_ticks(fx.VOICE_GAP + 2)
		2:
			fx.sfx("hup", at)
			check("a third near the listener is dropped", _voices() == 2)
			fx.sfx("blip", at)
			return TK.done(fails)
	step += 1
	return false
