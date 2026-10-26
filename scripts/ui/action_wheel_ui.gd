extends RadialWheel
## The action wheel (hold N): everything a captain can do, the same list ashore and aboard, from the
## ActionWheel registry; what can't be done here is greyed with the reason under it.

var _where := ""
## id -> why it's greyed ("" = it can be done), as the wheel opened.
var _why: Dictionary = {}


func _init() -> void:
	action = "action_wheel"


func _list() -> Array:
	_where = ActionWheel.place(player)
	var ids := ActionWheel.entries_for(player)
	_why.clear()
	for id in ids:
		_why[id] = ActionWheel.why_not(id, player)
	return ids


func _title() -> String:
	return ActionWheel.place_name(_where) if not entries.is_empty() else "Nothing to do"


func _label(id) -> String:
	return ActionWheel.label_of(id, player)


func _sub(id) -> String:
	return str(_why.get(id, ""))


func _dim(id) -> bool:
	return str(_why.get(id, "")) != ""


func _icon(id) -> Texture2D:
	return ActionWheel.icon_of(id)


func _do(id) -> void:
	ActionWheel.run(id, player)


func tip_id() -> String:
	return "action"
