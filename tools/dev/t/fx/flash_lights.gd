extends SceneTree
## Brief impact lights (FX.flash_light): a cannon hit lights a warm shadowless OmniLight that rises and dies away;
## an effect calling others (fire_pillar -> fire_ring -> flame) is one light; a broadside of ten cannons
## firing and hitting at once never makes more than FLASH_CAP light nodes; nothing far off or with
## FX.flash_lights off; plain impacts (not fire) make none.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fx
var step := 0
var until := 0
var fails := 0
var at := Vector3.ZERO
var peak := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _lit() -> Array:
	var out: Array = []
	for l in fx._lights:
		if l.visible:
			out.append(l)
	return out


func _process(_d: float) -> bool:
	if fx and not _lit().is_empty():
		peak = maxf(peak, _lit()[0].light_energy)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			fx = root.get_node("FX")
			at = stage.player.global_position + Vector3(0, 1.0, -4.0)
			fx.cannon_hit(at, Vector3.UP)
			var lit := _lit()
			check("a cannon hit lights one light", lit.size() == 1)
			var l: OmniLight3D = lit[0]
			check("warm, shadowless, reaching %.1f m" % l.omni_range, not l.shadow_enabled and l.light_color.r > l.light_color.b
				and l.omni_range >= 8.0)
			peak = 0.0
			until = TK.wait_secs(0.1)
		1:
			check("it flared up (peak %.2f)" % peak, peak > 4.0)
			until = TK.wait_secs(0.6)
		2:
			check("and died away", _lit().is_empty())
			fx.fire_pillar(at, 7.0)
			check("fire_pillar (and the ring and flame inside it) is one light (%d)" % _lit().size(), _lit().size() == 1)
			until = TK.wait_secs(1.0)
		3:
			fx.impact(at)
			fx.glint(at)
			check("a plain impact and a glint light nothing", _lit().is_empty())
			for i in range(10):
				var p := at + Vector3(i * 4.0, 0, 0)
				fx.cannon_fire(p, Vector3.FORWARD)
				fx.cannon_hit(p + Vector3(0, 0, -20), Vector3.BACK)
			check("a broadside of ten keeps to the cap (%d nodes, %d lit)" % [fx._lights.size(), _lit().size()],
				fx._lights.size() == fx.FLASH_CAP and _lit().size() <= fx.FLASH_CAP)
			until = TK.wait_secs(1.0)
		4:
			fx.cannon_hit(at + Vector3(0, 0, -200), Vector3.UP)
			check("nothing beyond FLASH_RANGE of the camera", _lit().is_empty())
			fx.flash_lights = false
			fx.cannon_hit(at, Vector3.UP)
			fx.muzzle_sparks(at, Vector3.FORWARD, 10)
			check("FX.flash_lights off: no lights", _lit().is_empty())
			fx.flash_lights = true
			fx.muzzle_sparks(at, Vector3.FORWARD, 10)
			check("a gunshot's muzzle lights a small one (%.1f m)" % _lit()[0].omni_range, _lit().size() == 1 and _lit()[0].omni_range < 6.0)
			return TK.done(fails)
	step += 1
	return false
