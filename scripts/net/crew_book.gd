class_name CrewBook
extends RefCounted
## The crews you've sailed with as a guest (1.22's "Rejoin crew"): this player's own list, not any world's, in
## user://crews.json: [{"name": the crew's name, "address": its host's address}], the newest first, KEEP at most.
## Net notes one when a host's world arrives; the title screen's co-op panel lists them, one click to rejoin.

const FILE := "user://crews.json"
## (a test writes its own)
static var file := FILE
const KEEP := 6


static func all() -> Array:
	if not FileAccess.file_exists(file):
		return []
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null:
		return []
	var v = JSON.parse_string(f.get_as_text())
	return (v as Array).filter(func(e): return e is Dictionary and e.has("address")) if v is Array else []


## A crew sailed with: to the top of the list (the same host's address replaces its old line).
static func remember(crew_name: String, address: String) -> void:
	if address.strip_edges() == "":
		return
	var list: Array = all().filter(func(e): return str(e.get("address", "")) != address)
	list.push_front({"name": crew_name, "address": address})
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(list.slice(0, KEEP)))
