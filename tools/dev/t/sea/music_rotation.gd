extends SceneTree
## The sea's music rotation (2026-11-06): Music picks one of SEA_DAY at random, never the same twice
## running and every one in turn; a pick that has played through gives way to another; by night only
## SEA_NIGHT's hushed ones; in a storm the storm's own track, and the rotation again once it clears.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var m
var wx
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weather": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			m = root.get_node("Music")
			wx = root.get_node("Weather")
			wx.skip_to(12.0)
			var seen := {}
			var repeats := 0
			var last := ""
			for i in 200:
				var t: String = m.next_sea(m.SEA_DAY)
				seen[t] = true
				if t == last:
					repeats += 1
				last = t
			check("eight calm sea tracks by day (%d)" % m.SEA_DAY.size(), m.SEA_DAY.size() >= 8)
			check("never the same twice running (%d repeats)" % repeats, repeats == 0)
			check("every one comes up (%d of %d)" % [seen.size(), m.SEA_DAY.size()], seen.size() == m.SEA_DAY.size())
			var bad := []
			for t in m.SEA_DAY + [m.SEA_STORM]:
				if not m.TRACKS.has(t) or not ResourceLoader.exists(m.TRACKS[t][0]):
					bad.append(t)
			check("every sea track has its file (%s)" % [bad], bad.is_empty())
			# the bosses by kind: a captain's duel, a beast's titan (an unadded node: no _ready)
			var want := {"res://scripts/enemies/pirate_boss.gd": "boss_duel", "res://scripts/enemies/pirate_grunt.gd": "boss_duel",
				"res://scripts/enemies/jungle_ape.gd": "boss_titan", "res://scripts/enemies/brood_queen.gd": "boss_titan",
				"res://scripts/enemies/beasts/jungle_beast.gd": "boss_titan"}
			for path in want:
				var nb := CharacterBody3D.new()
				nb.set_script(load(path))
				check("boss music for %s: %s" % [path.get_file(), want[path]], m.boss_track(nb) == want[path])
				nb.free()
			for t in m.BOSSES:
				check("%s has its file" % t, m.TRACKS.has(t) and ResourceLoader.exists(m.TRACKS[t][0]))
			var a: String = m.sea_track()
			check("the sea plays the pick (%s)" % a, a == m.sea_pick and a in m.SEA_DAY)
			check("...and keeps it a while", m.sea_track() == a)
			m._sea_played = 9999.0
			var b: String = m.sea_track()
			check("played through: another one (%s -> %s)" % [a, b], b != a and b in m.SEA_DAY)
			wx.skip_to(23.0)
			var n: String = m.sea_track()
			check("by night a hushed one (%s)" % n, n in m.SEA_NIGHT)
			wx.skip_to(12.0)
			wx.force(3)
			until = TK.wait_secs(8.0)
		1:
			check("a storm (%.2f): the storm's track (%s)" % [wx.storm, m.sea_track()], m.sea_track() == m.SEA_STORM)
			wx.force(0)
			until = TK.wait_secs(10.0)
		2:
			var t: String = m.sea_track()
			check("it clears (%.2f): the rotation again (%s)" % [wx.storm, t], t in m.SEA_DAY)
			return TK.done(fails)
	step += 1
	return false
