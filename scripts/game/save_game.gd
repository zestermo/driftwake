class_name SaveGame
extends RefCounted
## Three save slots (user://save_1.dat .. save_3.dat): your captain's look,
## level and skill map, skill bar, Devil Fruit, inventory, worn gear and
## weapons, banked loot, which chests you've opened and which thornbrush
## you've burned, dialogue you've had, play time, and where you and the ship
## are. Saved automatically when you level up, eat a fruit, bank loot at the
## ship, every couple of minutes, and when you quit.
##
## The title screen picks the slot (SaveGame.begin) before the world loads.
## Starting the world scene directly (the editor's "Run current scene")
## continues the most recent slot, or starts a new game in slot 1.
##
## Disabled when the game runs under a test script (--script), so test runs
## neither load nor overwrite your saves.

const SLOTS := 3
const LEGACY_PATH := "user://savegame.dat"
const VERSION := 2
const WORLD_SCENE := "res://scenes/world/world.tscn"
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

static var _loading: bool = false
## Tests can switch saving on with their own file (see use_test_file).
static var _test_path: String = ""
## Tests can run the slot system in their own folder (see use_test_dir).
static var _test_dir: String = ""
## The slot this session plays in (0 = none chosen yet).
static var slot: int = 0
## True from "New Game" until the first save (the creator is open meanwhile).
static var new_game: bool = false


static func use_test_file(path_: String) -> void:
	_test_path = path_


static func use_test_dir(dir: String) -> void:
	_test_dir = dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))


static func slot_path(i: int) -> String:
	if _test_dir != "":
		return _test_dir.path_join("save_%d.dat" % i)
	return "user://save_%d.dat" % i


static func path() -> String:
	if _test_path != "":
		return _test_path
	return slot_path(slot if slot > 0 else 1)


static func enabled() -> bool:
	if _test_path != "" or _test_dir != "":
		return true
	return not ("--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args())


static func exists() -> bool:
	return FileAccess.file_exists(path())


static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path()))


static func delete_slot(i: int) -> void:
	if FileAccess.file_exists(slot_path(i)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(i)))


## The old single save becomes slot 1.
static func migrate() -> void:
	if _test_dir != "" or _test_path != "":
		return
	if FileAccess.file_exists(LEGACY_PATH) and not FileAccess.file_exists(slot_path(1)):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(LEGACY_PATH), ProjectSettings.globalize_path(slot_path(1)))


static func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return {}
	var data = f.get_var()
	f.close()
	if not (data is Dictionary) or int(data.get("version", 0)) < 1:
		return {}
	return data


## What the slot list shows: {} when empty, else name, level, fruit,
## play_time (s), saved_at (unix time).
static func slot_info(i: int) -> Dictionary:
	var d := _read(slot_path(i))
	if d.is_empty():
		return {}
	var meta: Dictionary = d.get("meta", {})
	var prog: Dictionary = d.get("progression", {})
	var pw: Dictionary = d.get("power", {})
	return {
		"name": str(meta.get("name", d.get("look", {}).get("name", "Captain"))),
		"level": int(meta.get("level", prog.get("level", 1))),
		"fruit": str(meta.get("fruit", pw.get("fruit", ""))),
		"play_time": float(meta.get("play_time", d.get("play_time", 0.0))),
		"saved_at": int(meta.get("saved_at", FileAccess.get_modified_time(slot_path(i)))),
	}


## The most recently saved slot (0 = no saves).
static func latest_slot() -> int:
	var best := 0
	var best_t := -1
	for i in range(1, SLOTS + 1):
		var info := slot_info(i)
		if not info.is_empty() and int(info["saved_at"]) > best_t:
			best_t = int(info["saved_at"])
			best = i
	return best


static func first_free_slot() -> int:
	for i in range(1, SLOTS + 1):
		if slot_info(i).is_empty():
			return i
	return 0


## Choose the slot before loading the world. fresh: a new game (the slot is
## wiped and the character creator opens).
static func begin(i: int, fresh: bool, tree: SceneTree = null) -> void:
	slot = i
	new_game = fresh
	if fresh:
		delete_slot(i)
	if tree:
		var gm := tree.root.get_node_or_null("GameManager")
		if gm and gm.has_method("reset_session"):
			gm.reset_session()
		var dm := tree.root.get_node_or_null("Dialogue")
		if dm:
			dm.flags.clear()
			dm._talked.clear()


## The world was started without the title screen: continue the latest save
## or start fresh in slot 1.
static func ensure_session() -> void:
	if slot > 0 or not enabled() or _test_path != "":
		return
	migrate()
	var latest := latest_slot()
	if latest > 0:
		slot = latest
		new_game = false
	else:
		slot = 1
		new_game = true


## The saved look of the current slot ({} if none).
static func peek_look() -> Dictionary:
	if not enabled() or new_game:
		return {}
	var lk = _read(path()).get("look", {})
	return lk if lk is Dictionary else {}


static func format_time(secs: float) -> String:
	var m := int(secs / 60.0)
	return "%dh %02dm" % [m / 60, m % 60] if m >= 60 else "%dm" % maxi(m, 0)


## An item as data: gear is rebuilt from its parts, everything else by id.
static func item_ref(item: ItemData) -> Array:
	if item == null:
		return []
	if item.is_gear():
		return ["gear", item.gear_slot, item.icon_kind, item.look, item.display_name, int(item.rarity)]
	return ["id", item.id]


static func item_from(ref: Array) -> ItemData:
	if ref.is_empty():
		return null
	if str(ref[0]) == "gear" and ref.size() >= 5:
		# (saves from before tiers have no tier: common)
		return Gear.make(str(ref[1]), str(ref[2]), ref[3], str(ref[4]), int(ref[5]) if ref.size() >= 6 else 0)
	return ItemDB.get_item(str(ref[1]))


## Co-op: true while playing in someone else's world. Your slot then keeps
## your captain (level, gear, fruit, loot, chests you opened...) but not
## that world's state (burnt brush, where the ship is, where you stand).
static func _guest(player: Node) -> bool:
	var net := player.get_node_or_null("/root/Net") if player and player.is_inside_tree() else null
	return net != null and net.is_client()


static func save(player: Player) -> bool:
	if not enabled() or _loading or player == null or not is_instance_valid(player):
		return false
	if not player.is_local:
		return false
	var gm := player.get_node_or_null("/root/GameManager")
	var inv := player.inventory_component
	var items: Array = []
	for st in inv.items:
		items.append([item_ref(st.item), st.quantity])
	var worn := {}
	for slot in player.equipment.slots.keys():
		var it: ItemData = player.equipment.slots[slot]
		if it:
			worn[slot] = item_ref(it)
	var stored: Array = []
	if gm:
		for st in gm.storage:
			stored.append([item_ref(st.item), st.quantity])
	# your grave, if you've one: where, and what's in it (a grave on a ship's
	# deck is kept by the deck spot, so it sails with her)
	var grave: Array = []
	var g: LootBag = gm.grave if gm and gm.grave and is_instance_valid(gm.grave) else null
	if g:
		var on_ship := g.get_parent() is Node3D and g.get_parent().get_parent() is Ship
		grave = [g.position if on_ship else g.global_position, on_ship, g.floating, g.refs()]
	var ship := player.get_tree().get_first_node_in_group("ship") as Node3D
	var on_foot := player.context == Player.Context.ON_FOOT and not player.is_swimming() and player.current_state_name() != "Downed"
	var dm := player.get_node_or_null("/root/Dialogue")
	var play_time: float = float(gm.play_time) if gm else 0.0
	var data := {
		"version": VERSION,
		"meta": {
			"name": str(player.appearance.get("name", "Captain")),
			"level": player.progression.level,
			"fruit": player.power.fruit,
			"play_time": play_time,
			"saved_at": int(Time.get_unix_time_from_system()),
		},
		"look": player.appearance.duplicate(true),
		"play_time": play_time,
		"flags": dm.flags.duplicate() if dm else {},
		"talked": dm._talked.duplicate() if dm else {},
		"progression": player.progression.to_dict(),
		"power": player.power.to_dict(),
		"hybrid": player.hybrid,
		"health": player.health_component.current_health,
		"items": items,
		"hotbar": inv.hotbar.duplicate(),
		"worn": worn,
		"weapon": item_ref(player.equipped_weapon),
		"offhand": item_ref(player.offhand_weapon),
		"storage": stored,
		"grave": grave,
		"opened": gm.opened.keys() if gm else [],
		"maps": gm.maps.keys() if gm else [],
		"charted": gm.charted.keys() if gm else [],
		"burned": gm.burned.keys() if gm else [],
		"fruit_claims": gm.fruit_claims.duplicate() if gm else {},
		"ship_kit": gm.ship_kit.duplicate() if gm else {},
		"player_pos": player.global_position if on_foot else Vector3.INF,
		"player_yaw": player.player_model.rotation.y,
		"ship_pos": ship.global_position if ship else Vector3.INF,
		"ship_yaw": ship.global_rotation.y if ship else 0.0,
		"world_time": float(player.get_node("/root/Weather").world_time()) if player.get_node_or_null("/root/Weather") else 0.0,
	}
	var old := _read(path())
	data["char_id"] = str(old.get("char_id", "%08x%08x" % [randi(), randi()]))
	if _guest(player):
		# keep our own world's state, not the host's
		# (and our own ship's storage and our grave, in our own world)
		for k in ["burned", "fruit_claims", "ship_kit", "ship_pos", "ship_yaw", "player_pos", "player_yaw", "world_time", "storage", "grave"]:
			if old.has(k):
				data[k] = old[k]
			else:
				data.erase(k)
	var f := FileAccess.open(path(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(data)
	f.close()
	new_game = false
	return true


## Apply the save to a freshly started world. Returns false with no save.
static func load_into(player: Player) -> bool:
	if not enabled() or new_game or not exists() or player == null:
		return false
	var data := _read(path())
	if data.is_empty():
		return false
	_loading = true
	var gm := player.get_node_or_null("/root/GameManager")
	# progression first (the skill map decides stats and what's on the bar)
	player.progression.from_dict(data.get("progression", {}))
	player.power.from_dict(data.get("power", {}))
	player.progression.after_load()
	# inventory, gear, weapons
	var inv := player.inventory_component
	inv.items.clear()
	for e in data.get("items", []):
		var it := item_from(e[0])
		if it:
			var st := ItemStack.new()
			st.item = it
			st.quantity = int(e[1])
			inv.items.append(st)
	var hb: Array = data.get("hotbar", [])
	for i in range(inv.hotbar.size()):
		inv.hotbar[i] = ""
	# quick slots hold consumables only (older saves had weapons there too)
	var qi := 0
	for id in hb:
		if qi < inv.hotbar.size() and InventoryComponent.quick_ok(ItemDB.get_item(str(id))):
			inv.hotbar[qi] = str(id)
			qi += 1
	var lk = data.get("look", {})
	if lk is Dictionary and not lk.is_empty():
		player.appearance = (lk as Dictionary).duplicate(true)
	player.equipment.slots.clear()
	var worn: Dictionary = data.get("worn", {})
	for slot in worn.keys():
		var it := item_from(worn[slot])
		if it:
			player.equipment.slots[slot] = it
	player.refresh_look()
	var w := item_from(data.get("weapon", []))
	if w:
		player.equip_weapon(w, false)
	else:
		player.unequip_weapon()
	var off := item_from(data.get("offhand", []))
	if off:
		player.set_offhand(off)
	inv.inventory_changed.emit()
	inv.hotbar_changed.emit()
	if data.get("hybrid", false) and player.power.fruit_type() == "zoan":
		player.set_hybrid(true)
	player.call("_recalc_stats")
	var hc := player.health_component
	hc.current_health = clampf(float(data.get("health", hc.max_health)), 1.0, hc.max_health)
	hc.health_changed.emit(hc.current_health, hc.max_health)
	# the world
	var dm := player.get_node_or_null("/root/Dialogue")
	if dm:
		dm.flags = (data.get("flags", {}) as Dictionary).duplicate()
		dm._talked = (data.get("talked", {}) as Dictionary).duplicate()
	if gm:
		gm.play_time = float(data.get("play_time", 0.0))
		gm.opened.clear()
		for k in data.get("opened", []):
			gm.opened[str(k)] = true
		gm.maps.clear()
		for k in data.get("maps", []):
			gm.maps[int(k)] = true
		gm.charted.clear()
		for k in data.get("charted", []):
			gm.charted[str(k)] = true
		var guest := _guest(player)
		if not guest:
			gm.burned.clear()
			for k in data.get("burned", []):
				gm.burned[str(k)] = true
			gm.fruit_claims = (data.get("fruit_claims", {}) as Dictionary).duplicate()
			gm.ship_kit = ShipKit.merged(data.get("ship_kit", {}))
			# the ship's storage (older saves: what was banked), in place: the
			# chest in the cabin holds this very array
			gm.storage.clear()
			for e in data.get("storage", data.get("banked", [])):
				var it := item_from(e[0])
				if it:
					var st := ItemStack.new()
					st.item = it
					st.quantity = int(e[1])
					gm.storage.append(st)
			var wn := player.get_node_or_null("/root/Weather")
			if wn and data.has("world_time"):
				wn.set_world_time(float(data["world_time"]))
		gm.apply_world_state()
		if guest:
			_loading = false
			return true  # the world (ship, where we stand) is the host's
	var ship := player.get_tree().get_first_node_in_group("ship")
	if ship and gm:
		ship.apply_kit(gm.ship_kit)
	var sp: Vector3 = data.get("ship_pos", Vector3.INF)
	if ship and sp != Vector3.INF and ship.has_method("place"):
		ship.call("place", sp, float(data.get("ship_yaw", 0.0)))
	# your grave, where you left it
	var gd: Array = data.get("grave", [])
	if gm and gd.size() >= 4 and (gm.grave == null or not is_instance_valid(gm.grave)):
		var stacks: Array[ItemStack] = []
		for e in gd[3]:
			var it := item_from(e[0])
			if it:
				var st := ItemStack.new()
				st.item = it
				st.quantity = int(e[1])
				stacks.append(st)
		if not stacks.is_empty():
			gm.grave = gm.restore_grave(stacks, gd[0], bool(gd[1]), bool(gd[2]))
	var pp: Vector3 = data.get("player_pos", Vector3.INF)
	if pp != Vector3.INF:
		player.global_position = pp + Vector3.UP * 0.3
		player.player_model.rotation.y = float(data.get("player_yaw", 0.0))
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
	_loading = false
	return true
