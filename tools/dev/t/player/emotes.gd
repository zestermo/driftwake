extends SceneTree
## Every emote plays as a body action (so co-op mirrors it), every emote's sound is loaded, and none plays music.
const TK := preload("res://tools/dev/test_kit.gd")
const EMOTES := ["wave", "point", "salute", "laugh", "cheer", "dance", "shrug", "bow", "flex", "facepalm", "shanty"]
const EMOTE_SOUNDS := {"salute": ["heel_click"], "laugh": ["laugh"], "cheer": ["cheer"], "bow": ["whoosh"],
	"flex": ["hup"], "facepalm": ["slap"]}
const EmotePoses := preload("res://scripts/npc/emote_poses.gd")
var stage
var p
var i := 0
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var fx = root.get_node("FX")
			var missing := []
			for id in EMOTES:
				if EMOTE_SOUNDS.has(id) and not fx._streams.has(EMOTE_SOUNDS[id][0]):
					missing.append(id)
			check("every emote's sound is loaded (missing %s)" % str(missing), missing.is_empty())
			check("the hornpipe and the shanty play no music (the instruments do)", not EmotePoses.SOUNDS.has("dance") and not EmotePoses.SOUNDS.has("shanty"))
		1:
			p.state_machine.force_state("Idle", {})
			p.global_position = Vector3(0, stage.GROUND_Y + 0.05, 0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(20)
		2:
			p.emote(EMOTES[i])
			until = TK.wait_ticks(6)
		3:
			check("emote %s plays (%s)" % [EMOTES[i], p.body_model.current_action()], p.body_model.current_action() == "emote_" + EMOTES[i])
			p.body_model.stop_action()
			i += 1
			if i == EMOTES.size():
				return TK.done(fails)
			step = 1
			return false
	step += 1
	return false
