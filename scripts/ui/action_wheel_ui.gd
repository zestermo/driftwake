extends RadialWheel
## The action wheel (hold N): what the captain can do where they are, from the ActionWheel registry
## (ashore: make camp, train; aboard: the downtime activities; in town: the town's own things).

var _where := ""


func _init() -> void:
	action = "action_wheel"


func _list() -> Array:
	_where = ActionWheel.place(player)
	return ActionWheel.entries_for(player)


func _title() -> String:
	return ActionWheel.place_name(_where) if not entries.is_empty() else "Nothing to do"


func _label(id) -> String:
	return ActionWheel.label_of(id, player)


func _icon(id) -> Texture2D:
	return ActionWheel.icon_of(id)


func _do(id) -> void:
	ActionWheel.run(id, player)
