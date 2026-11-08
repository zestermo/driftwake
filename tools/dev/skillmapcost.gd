extends SceneTree
## What the open skills menu (K) costs a frame (GPU, a real window at 1920x1080, vsync off): on the light stage, a
## level-12 captain, each page (captain, the katana map, the chart) held for `frames` frames; prints the mean frame ms
## redrawn every frame as shipped, with the screen's own redraws stopped (still), and on the Captain page each of its
## two canvases redrawn alone (the screen, the Edy tree's view). Args: [frames]
const TK := preload("res://tools/dev/test_kit.gd")
## [label, tab, chart, what redraws: "all" (as shipped), "still", "screen", "edy"]
const RUNS := [["captain", "captain", false, "all"], ["captain", "captain", false, "still"], ["captain", "captain", false, "screen"],
	["captain", "captain", false, "edy"], ["katana map", "katana", false, "all"], ["katana map", "katana", false, "still"],
	["chart", "katana", true, "all"], ["chart", "katana", true, "still"]]
var stage
var step := 0
var until := 0
var sm
var frames := 180
var ri := 0
var n := 0
var acc := 0.0
var last_us := 0
var rows: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		frames = int(args[0])
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": true, "weapon": "katana"})


func _process(_d: float) -> bool:
	until -= 1
	for c in root.find_children("*", "CharacterCreator", true, false):
		c._finish(true)
	if not stage.up or until > 0:
		last_us = Time.get_ticks_usec()
		return false
	var now := Time.get_ticks_usec()
	match step:
		0:
			var pr = stage.player.progression
			var xp := 0
			for lv in range(1, 12):
				xp += pr.xp_to_next(lv)
			pr.add_xp(xp)
			root.get_node("Story").step = "done"
			var gm = root.get_node("GameMenu")
			gm.open("skills")
			sm = gm._skills
			_run()
			step = 1
		1:
			var how: String = RUNS[ri][3]
			if how == "screen":
				sm.queue_redraw()
			elif how == "edy":
				sm._edy_view.queue_redraw()
			if n > 0:
				acc += (now - last_us) / 1000.0
			n += 1
			if n > frames:
				rows.append("%-12s %-7s frame %6.2f ms" % [RUNS[ri][0], how, acc / frames])
				print(rows[-1])
				ri += 1
				if ri >= RUNS.size():
					print("== skills menu cost a frame (1920x1080)")
					for r in rows:
						print(r)
					quit()
					return false
				_run()
	last_us = Time.get_ticks_usec()
	return false


func _run() -> void:
	var r: Array = RUNS[ri]
	sm.set_process(true)
	sm.chart = false
	sm.set_tab(r[1])
	if r[2]:
		sm.chart = true
	n = 0
	acc = 0.0
	until = 30
	if r[3] != "all":
		# (a frame first with the screen's own _process, so the page is laid out, then it stops)
		sm.set_process.call_deferred(false)
