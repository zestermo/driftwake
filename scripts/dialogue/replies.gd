class_name Replies
extends RefCounted
## A reply at a key moment (1.23, docs/v1_23_plan.md "Replies"): someone says their piece, the captain they spoke to
## picks one of 2-3 replies (cocky / cool / diplomatic), and the pick changes their next line and sometimes the outcome.
## A reply is {"tone", "text", "answer" (their next line), "if" (optional Callable: offered only while true)}.
## The pick comes back as Dialogue's dialogue_event "reply:<key>:<i>" ("reply:<key>:-1": walked away without one).
## Co-op: only the captain spoken to sees the choice (it's their machine's conversation); whoever decides what it
## changes puts it on every screen with `shown`.

const EVENT := "reply:"
const TONES := {"cocky": "Cocky", "cool": "Cool", "diplomatic": "Diplomatic"}

static var _open := ""
static var _key := ""
static var _picked := false


static func label(r: Dictionary) -> String:
	return "[%s] %s" % [TONES[str(r["tone"])], str(r["text"])]


## The reply's nodes for a conversation of its own or one already going: `entry` says `lines` and offers the replies;
## each pick is said ("You") and answered by the conversation's speaker, then goes to `after`.
static func nodes(key: String, entry: String, lines: Array, replies: Array, after: String = "end") -> Dictionary:
	var choices: Array = []
	var out := {entry: {"text": lines, "choices": choices}}
	for i in range(replies.size()):
		var r: Dictionary = replies[i]
		var c := {"text": label(r), "next": "%s_r%d" % [entry, i]}
		if r.has("if"):
			c["if"] = r["if"]
		choices.append(c)
		out["%s_r%d" % [entry, i]] = {"speaker": "You", "text": [str(r["text"])], "event": "%s%s:%d" % [EVENT, key, i], "next": "%s_a%d" % [entry, i]}
		out["%s_a%d" % [entry, i]] = {"text": [str(r["answer"])], "next": after}
	return out


## A conversation of its own on this machine (the captain spoken to). False if one can't open now (another's going).
static func open(dlg: Node, key: String, speaker: String, voice: float, lines: Array, replies: Array, npc: Node = null) -> bool:
	if dlg.is_blocking():
		return false
	var id := "reply_" + key.replace(":", "_")
	dlg.define(id, {"speaker": speaker, "voice": voice, "start": "say", "nodes": nodes(key, "say", lines, replies)})
	_open = id
	_key = key
	_picked = false
	if not dlg.dialogue_event.is_connected(_on_event):
		dlg.dialogue_event.connect(_on_event)
		dlg.dialogue_ended.connect(_on_end.bind(dlg))
	dlg.start(id, npc)
	return true


static func _on_event(ev: String) -> void:
	if _open != "" and ev.begins_with(EVENT):
		_picked = true


static func _on_end(id: String, dlg: Node) -> void:
	if id != _open:
		return
	_open = ""
	if not _picked:
		dlg.dialogue_event.emit("%s%s:-1" % [EVENT, _key])


## On every screen: who picked what, and the answer (toasts, and a bubble over the speaker if it can bark).
static func shown(tree: SceneTree, who: String, r: Dictionary, speaker: String, speaker_node: Node = null) -> void:
	tree.call_group("hud", "show_toast", "%s (%s): \"%s\"" % [who, TONES[str(r["tone"])].to_lower(), str(r["text"])])
	tree.call_group("hud", "show_toast", "%s: \"%s\"" % [speaker, str(r["answer"])])
	if speaker_node and is_instance_valid(speaker_node) and speaker_node.has_method("bark"):
		speaker_node.bark([str(r["answer"])])
