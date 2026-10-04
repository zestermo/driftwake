extends Node
## Dialogue system (autoload "Dialogue").
##
## Conversations live in res://data/dialogue/<id>.json:
## {
##   "speaker": "Harbormaster Odile",   // default speaker for every node
##   "voice": 0.9,                      // blip pitch
##   "start": "intro",                  // first-time entry node
##   "return": "menu",                  // entry node on later visits (optional)
##   "nodes": {
##     "intro": { "text": ["Page one.", "Page two."], "next": "menu", "set_flag": "met_odile" },
##     "menu":  { "text": "Anything else?", "choices": [
##                  { "text": "Tell me about the ship.", "next": "ship" },
##                  { "text": "Secret option", "next": "x", "requires": "some_flag" },
##                  { "text": "Goodbye.", "next": "end" } ] },
##     "ship":  { "speaker": "You", "text": "...", "next": "menu" }
##   }
## }
## Text may contain {tokens} filled by providers registered with register_token().
## "event": "<name>" on a node emits dialogue_event(name) when the node is shown.

signal dialogue_started(id: String)
signal dialogue_ended(id: String)
signal line_shown(speaker: String, text: String)
signal dialogue_event(event_name: String)

const DIALOGUE_DIR := "res://data/dialogue/"
const PLAYER_SPEAKER := "You"

var active: bool = false
var flags: Dictionary = {}

var _cache: Dictionary = {}
var _tokens: Dictionary = {}
var _talked: Dictionary = {}
var _data: Dictionary = {}
var _id: String = ""
var _node: Dictionary = {}
var _pages: Array = []
var _page: int = 0
var _npc: Node = null
var _voice: float = 1.0
var _cooldown: float = 0.0
var _box: DialogueBox
var _player: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_box = DialogueBox.new()
	_box.name = "DialogueBox"
	add_child(_box)
	_box.choice_made.connect(_on_choice)


## True for a moment after a conversation closes so the same key press
## doesn't immediately reopen it.
func is_blocking() -> bool:
	return active or _cooldown > 0.0


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta


func register_token(token: String, provider: Callable) -> void:
	_tokens[token] = provider


func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


## Start a conversation from a JSON file.
func start(id: String, npc: Node = null) -> void:
	if is_blocking():
		return
	var data := _load(id)
	if data.is_empty():
		push_warning("Dialogue '%s' not found" % id)
		return
	_data = data
	_id = id
	_npc = npc
	_voice = float(data.get("voice", 1.0))
	var entry := str(data.get("start", "start"))
	if _talked.has(id) and data.has("return"):
		entry = str(data["return"])
	_talked[id] = true
	_open()
	_goto(entry)


## Show one-off lines without a JSON file (barks, signs, discoveries).
func say(speaker: String, lines: Array, npc: Node = null, voice: float = 1.0) -> void:
	if is_blocking():
		return
	_data = {"speaker": speaker, "nodes": {"start": {"text": lines, "next": "end"}}}
	_id = "_say"
	_npc = npc
	_voice = voice
	_open()
	_goto("start")


func _open() -> void:
	active = true
	_player = get_tree().get_first_node_in_group("player")
	if _player and _player.has_node("StateMachine"):
		var sm: StateMachine = _player.get_node("StateMachine")
		if sm.current_state and sm.states.has("talk"):
			var face := Vector3.ZERO
			if _npc is Node3D:
				face = (_npc as Node3D).global_position
			sm.current_state.transitioned.emit(sm.current_state, "Talk", {"face": face})
	_box.open()
	dialogue_started.emit(_id)


func _close() -> void:
	active = false
	_cooldown = 0.25
	_box.close()
	if _npc and _npc.has_method("set_talking"):
		_npc.set_talking(false)
	if _player and _player.has_node("StateMachine"):
		var sm: StateMachine = _player.get_node("StateMachine")
		if sm.current_state and sm.current_state.name == "Talk":
			sm.current_state.transitioned.emit(sm.current_state, "Idle", {})
	var finished := _id
	_npc = null
	dialogue_ended.emit(finished)


func _goto(node_id: String) -> void:
	if node_id == "end" or node_id == "":
		_close()
		return
	var nodes: Dictionary = _data.get("nodes", {})
	if not nodes.has(node_id):
		push_warning("Dialogue '%s' has no node '%s'" % [_id, node_id])
		_close()
		return
	_node = nodes[node_id]
	if _node.has("set_flag"):
		set_flag(str(_node["set_flag"]))
	if _node.has("event"):
		dialogue_event.emit(str(_node["event"]))
	var text = _node.get("text", "")
	_pages = text if text is Array else [text]
	_page = 0
	_show_page()


func _speaker() -> String:
	return str(_node.get("speaker", _data.get("speaker", "")))


func _show_page() -> void:
	var speaker := _speaker()
	var line := _fill_tokens(str(_pages[_page]))
	var is_last := _page >= _pages.size() - 1
	var choices: Array = []
	if is_last and _node.has("choices"):
		for c in _node["choices"]:
			if c.has("requires") and not has_flag(str(c["requires"])):
				continue
			if c.has("hide_if") and has_flag(str(c["hide_if"])):
				continue
			choices.append(c)
	var voice := _voice if speaker != PLAYER_SPEAKER else 1.25
	_box.show_line(speaker, line, choices, voice)
	if _npc and _npc.has_method("set_talking"):
		_npc.set_talking(speaker != PLAYER_SPEAKER)
	line_shown.emit(speaker, line)


func _fill_tokens(line: String) -> String:
	if line.find("{") == -1:
		return line
	for token in _tokens.keys():
		var key := "{%s}" % token
		if line.find(key) != -1:
			line = line.replace(key, str(_tokens[token].call()))
	return line


func _input(event: InputEvent) -> void:
	if not active or get_tree().paused:
		return
	# Leave function keys (F2/F3/F11...) and Alt+Enter to the global handlers.
	if event is InputEventKey and ((event.keycode >= KEY_F1 and event.keycode <= KEY_F12) or event.alt_pressed):
		return
	if _box.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	var advance := event.is_action_pressed("interact") or event.is_action_pressed("jump") \
		or event.is_action_pressed("ui_accept") or event.is_action_pressed("light_attack")
	if advance:
		get_viewport().set_input_as_handled()
		_advance()
	elif event is InputEventKey or event is InputEventMouseButton:
		# Swallow combat/other inputs while talking (mouse look still works).
		if event.is_pressed() and not event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()


func _advance() -> void:
	if _box.is_typing():
		_box.finish_typing()
		return
	if _box.has_choices():
		_box.confirm_choice()
		return
	if _page < _pages.size() - 1:
		_page += 1
		_show_page()
		return
	_goto(str(_node.get("next", "end")))


func _on_choice(choice: Dictionary) -> void:
	if choice.has("flag"):
		set_flag(str(choice["flag"]))
	_goto(str(choice.get("next", "end")))


func _load(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var path := DIALOGUE_DIR + id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_cache[id] = parsed
		return parsed
	push_error("Dialogue '%s' is not valid JSON" % id)
	return {}
