extends SceneTree
## The weather by theme: a snow island is hazy nearly always under a light snowfall with heavy spells now and
## then, and never rains; a desert never rains and its rain and storm slots are sandstorms; home and the
## jungle are as before. The fog leans to the place's haze colour (home's is the horizon's own). On the stage:
## a blizzard and a sandstorm close the fog in, lose the lightning, play their beds, blow the flakes or
## streaks and light the lamps at noon.
const TK := preload("res://tools/dev/test_kit.gd")
var KS
var NL
var stage
var wx
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weather": true, "hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## Slot by slot (each read mid-slot, off its blend): [hazy, heavy, rained, snowed, sanded] counts over n slots.
func _survey(st: Dictionary, n: int) -> Array:
	var c := [0, 0, 0, 0, 0, 0]
	for s in range(2, 2 + n):
		var p: Array = wx.params_in(s * wx.SLOT + 20.0, st, 1.0)
		c[0] += 1 if float(p[5]) >= 0.4 else 0
		c[1] += 1 if float(p[6]) >= 0.6 else 0
		c[2] += 1 if float(p[1]) > 0.0 else 0
		c[3] += 1 if float(p[6]) >= wx.SNOW_LIGHT else 0
		c[4] += 1 if float(p[7]) > 0.5 else 0
	return c


func _zone(theme: String) -> void:
	wx._zone = [theme, 1.0 if theme != "brinehollow" else 0.0]
	wx._zone_style = KS.of(theme)
	# (held: the stage has no chain islands for KitStyle.around to find)
	wx._zone_t = 1e9


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			wx = root.get_node("Weather")
			KS = load("res://scripts/island/kit/kit_style.gd")
			NL = load("res://scripts/world/night_light.gd")
			var n := 400
			var sn := _survey(KS.of("snow"), n)
			print("snow over %d slots: hazy %d heavy %d rain %d snowing %d" % [n, sn[0], sn[1], sn[2], sn[3]])
			check("a snow island is hazy nearly all the time (%d of %d)" % [sn[0], n], sn[0] >= n * 0.9)
			check("...it snows lightly in every slot (%d)" % sn[3], sn[3] == n)
			check("...heavy snow comes now and then, not mostly (%d)" % sn[1], sn[1] >= n * 0.08 and sn[1] <= n * 0.4)
			check("...and it never rains (%d)" % sn[2], sn[2] == 0)
			var de := _survey(KS.of("desert"), n)
			print("desert over %d slots: rain %d sandstorm %d snow %d" % [n, de[2], de[4], de[3]])
			check("a desert never rains (%d of %d)" % [de[2], n], de[2] == 0)
			check("...its rain and storm slots are sandstorms (%d)" % de[4], de[4] >= n * 0.05 and de[4] <= n * 0.3)
			check("...and it never snows (%d)" % de[3], de[3] == 0)
			var ju := _survey(KS.of("jungle"), n)
			check("the jungle still rains (%d of %d)" % [ju[2], n], ju[2] > n * 0.2 and ju[3] == 0 and ju[4] == 0)
			var same := true
			for s in range(2, 200):
				var t: float = s * wx.SLOT + 20.0
				var home: Array = wx._params_at(t)
				var a: Array = wx.params_in(t, KS.of("snow"), 0.0)
				var b: Array = wx.params_in(t, KS.of("brinehollow"), 1.0)
				for i in range(6):
					same = same and float(a[i]) == float(home[i]) and float(b[i]) == float(home[i])
				same = same and float(a[6]) == 0.0 and float(a[7]) == 0.0
			check("home waters' weather is exactly as before", same)
			var hor := Color(0.52, 0.72, 0.9)
			wx.night = 0.0
			check("home's fog is the horizon's colour", wx.haze_here(hor, KS.of("brinehollow"), 1.0, 0.0) == hor and wx.haze_here(hor, KS.of("jungle"), 1.0, 0.0) == hor)
			var white := Color(KS.of("snow")["haze_color"])
			var full: Color = wx.haze_here(hor, KS.of("snow"), 1.0, 0.0)
			var half: Color = wx.haze_here(hor, KS.of("snow"), 0.5, 0.0)
			var d_full := Vector3(full.r - white.r, full.g - white.g, full.b - white.b).length()
			var d_half := Vector3(half.r - white.r, half.g - white.g, half.b - white.b).length()
			var d_hor := Vector3(hor.r - white.r, hor.g - white.g, hor.b - white.b).length()
			check("on a snow island the fog leans to its white haze, half way at half its reach", d_full < d_half and d_half < d_hor)
			var dusty: Color = wx.haze_here(hor, KS.of("desert"), 1.0, 1.0)
			check("...and a sandstorm's fog is its dust (%s)" % dusty, dusty.r > dusty.b + 0.15)
			_zone("snow")
			wx.force(1)
			until = TK.wait_secs(10.0)
		1:
			var fx = stage.get_node("PrecipFX")
			check("on a snow island a light snow falls (snow %.2f, flakes %s)" % [wx.snow, fx._flakes.emitting], wx.snow >= wx.SNOW_LIGHT and fx._flakes.emitting)
			check("...no rain (%.2f)" % wx.rain, wx.rain == 0.0 and not wx._rain.emitting)
			check("...no whiteout in a light fall (murk %.2f, fog to %.0f m)" % [wx.murk, wx.fog_end], wx.murk == 0.0 and wx.fog_end > 300.0)
			wx.skip_to(12.0)
			wx.force(3)
			until = TK.wait_secs(10.0)
		2:
			var fx = stage.get_node("PrecipFX")
			check("a blizzard is named one (%s)" % wx.state_name(wx.state), wx.state_name(3) == "Blizzard")
			check("...it closes the view in (murk %.2f, fog to %.0f m)" % [wx.murk, wx.fog_end], wx.murk > 0.95 and wx.fog_end < 80.0)
			check("...the streaks and curtains blow (%s %s)" % [fx._streaks.emitting, fx._curtains.emitting], fx._streaks.emitting and fx._curtains.emitting)
			check("...the blizzard bed plays (%.1f dB)" % wx._blizzard_snd.volume_db, wx._blizzard_snd.playing and wx._blizzard_snd.volume_db > -12.0)
			check("...no rain bed (%s)" % wx._rain_snd.playing, not wx._rain_snd.playing)
			check("...the lamps are lit at noon", NL.is_night())
			check("...and there's no lightning in it", wx._last_strike == -1)
			_zone("desert")
			until = TK.wait_secs(6.0)
		3:
			var fx = stage.get_node("PrecipFX")
			check("a desert's storm is a sandstorm (%s, sand %.2f, rain %.2f)" % [wx.state_name(3), wx.sand, wx.rain], wx.state_name(3) == "Sandstorm" and wx.sand > 0.95 and wx.rain == 0.0)
			check("...its fog is dust (%s)" % wx.fog_color, wx.fog_color.r > wx.fog_color.b + 0.1 and wx.fog_end < 80.0)
			check("...sand streaks, no snow (%s %s)" % [fx._streaks.emitting, fx._flakes.emitting], fx._streaks.emitting and fx._kind == "sand" and not fx._flakes.emitting)
			check("...the sandstorm bed plays and the blizzard's fades (%.1f / %.1f dB)" % [wx._sand_snd.volume_db, wx._blizzard_snd.volume_db],
				wx._sand_snd.playing and wx._sand_snd.volume_db > -12.0 and wx._blizzard_snd.volume_db < wx._sand_snd.volume_db)
			check("...and no lightning", wx._last_strike == -1)
			_zone("brinehollow")
			until = TK.wait_secs(4.0)
		4:
			check("at home a storm is rain again (rain %.2f, snow %.2f, sand %.2f)" % [wx.rain, wx.snow, wx.sand], wx.rain > 0.9 and wx.snow == 0.0 and wx.sand == 0.0 and wx.murk == 0.0)
			check("...the fog meets the horizon", wx._env.fog_light_color.is_equal_approx(wx._sky_mat.get_shader_parameter("horizon_color")))
			check("...lamps out at noon", not NL.is_night())
			wx.force(-1)
			return TK.done(fails)
	step += 1
	return false
