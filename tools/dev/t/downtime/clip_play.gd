extends SceneTree
## The Blender clip pipeline: the reading clip's glb (art/clips/read.glb) imports to the saved BodyClip
## (assets/clips/read.tres) frame for frame; held as "clip_read" the body takes the keyed rotation at a key's
## time (tools/blender/pilot_read.json), with the legs left to the locomotion (upper mask); it loops; the body
## follows it while held.
const TK := preload("res://tools/dev/test_kit.gd")
const GLB := "res://art/clips/read.glb"
const KEYS := "res://tools/blender/pilot_read.json"
var stage
var p
var h
var clip
var keys: Dictionary
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func key_at(t: float) -> Dictionary:
	for k in keys["keys"]:
		if is_equal_approx(float(k["t"]), t):
			return k["pose"]
	return {}


func near(a: Vector3, e: Array, tol: float) -> bool:
	return a.distance_to(Vector3(e[0], e[1], e[2])) < tol


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			h = p.body_model
			var dep = load("res://scripts/game/dep_record.gd")
			dep.note_dep(GLB)
			dep.note_dep(KEYS)
			keys = JSON.parse_string(FileAccess.get_file_as_string(KEYS))
			clip = load("res://assets/clips/read.tres")
			var fresh = load("res://tools/dev/clip_import.gd").load_clip(self, GLB, "upper", "", true)
			var worst := 0.0
			for f in range(0, clip.frames(), 7):
				for j in clip.tracks:
					worst = maxf(worst, (clip.tracks[j][f] as Vector3).distance_to(fresh.tracks[j][f]))
			check("the glb imports to the saved clip (worst %.4f rad)" % worst, worst < 0.002 and fresh.frames() == clip.frames())
			check("...4 s at 30 fps, looped, the upper body", clip.frames() == 121 and clip.loop and clip.mask == "upper")
			h.hold("clip_read", 0.4)
			h._action["t"] = 2.9 + clip.length
			var res: Array = h._action_pose("clip_read", 0.0)
			var want: Dictionary = key_at(2.9)
			var off := 0.0
			for j in want:
				off = maxf(off, (res[0][j] as Vector3).distance_to(Vector3(want[j][0], want[j][1], want[j][2])))
			check("at the page-turn key (2.9 s, a loop on) every joint is as keyed (worst %.4f rad)" % off, off < 0.01)
			check("...the forearm's bend stays a bend (%s)" % str(res[0]["fore_r"]), near(res[0]["fore_r"], want["fore_r"], 0.01))
			check("...the legs aren't the clip's", res[1] == "upper" and not (res[0] as Dictionary).has("leg_l"))
			h._action["t"] = 1.2
			res = h._action_pose("clip_read", 0.0)
			check("...and the key at 1.2 s", near(res[0]["head"], key_at(1.2)["head"], 0.01))
			h.stop_action()
			h.hold("clip_read", 0.4)
			until = TK.wait_secs(1.5)
		1:
			var now: Dictionary = clip.sample(float(h._action["t"]))
			var cur: Vector3 = h._cur["arm_l"]
			check("held, the body follows the clip (arm_l %s vs %s)" % [str(cur), str(now["arm_l"])], h.current_action() == "clip_read" and cur.distance_to(now["arm_l"]) < 0.15)
			h.stop_action()
			return TK.done(fails)
	step += 1
	return false
