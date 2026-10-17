extends SceneTree
## The shipwright's work: the plain sloop, each upgrade line at each of its
## levels (that line alone, from where it shows), fully refitted in two colour
## schemes (side, bow, masthead), at night, Tackett at his timber, and the
## yard screen's two tabs.
## Args: <out_prefix> [psx] [lines=armour,guns] (only those lines' shots)
var t := 0.0
var out := ""
var cam: Camera3D
var ship
var p
var gm
var shots: Array = []
var i := -1
var t0 := 0.0
## Where each line shows: [camera, look at] (ship-local).
const VIEWS := {
	"armour": [Vector3(12, 3, -9), Vector3(0, 0.3, -3)],
	"guns": [Vector3(-5.5, 6.5, 5), Vector3(2.5, 0.6, -3)],
	"sails": [Vector3(24, 8, 5), Vector3(0, 8.5, -4)],
	"rudder": [Vector3(7, 4.5, 17), Vector3(0, 1.8, 8)],
	"copper": [Vector3(12, 1.5, -6), Vector3(0, -0.8, -2)],
	"chaser": [Vector3(5, 4, -17), Vector3(0, 1, -10)],
	"nest": [Vector3(7, 16, 6), Vector3(0, 15, -1.8)],
	"lanterns": [Vector3(16, 9, 8), Vector3(0, 4, -2)],
	"rails": [Vector3(9, 5, -2), Vector3(0, 0.8, -2)],
	"grove": [Vector3(-6, 6.5, 13), Vector3(0, 3, 7.5)],
	"galley": [Vector3(-7, 6, 12), Vector3(0, 2.5, 6.5)],
	"chest": [Vector3(-6, 5, 2), Vector3(-1, 0.6, -0.5)],
}
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func kit(k: Dictionary) -> void:
	var full: Dictionary = load("res://scripts/ship/ship_kit.gd").merged(k)
	root.get_node("Net").set_ship_kit(full)
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	if cam == null:
		# ("psx": the game's sharper preset, for the README; not saved)
		var args := OS.get_cmdline_user_args()
		if args.has("psx"): root.get_node("Settings").set_value("video", "pixelate", true, false)
		else: root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		ship = get_first_node_in_group("ship")
		p = get_first_node_in_group("player")
		gm = root.get_node("GameManager")
		cam = Camera3D.new(); cam.fov = 55; cam.far = 1500; root.add_child(cam); cam.current = true
		var tackett = null
		for n in current_scene.find_children("*", "NPC", true, false):
			if n.dialogue_id == "tackett": tackett = n
		var only: Array = []
		for a in args:
			if a.begins_with("lines="): only = a.substr(6).split(",")
		var lines = load("res://scripts/ship/ship_lines.gd")
		var full := {}
		for id in lines.ORDER:
			full[id] = lines.max_level(id)
		shots = [["plain", {}, Vector3(14, 4, 3), Vector3(0, 2, 0)]]
		for id in lines.ORDER:
			if not only.is_empty() and not only.has(id): continue
			for lv in range(1, lines.max_level(id) + 1):
				shots.append(["%s_%d" % [id, lv], {id: lv}, VIEWS[id][0], VIEWS[id][1]])
		if only.is_empty():
			shots.append_array([
				["full_side", full.merged({"hull": 2, "sail": 1, "field": 1, "emblem": 1, "mark": 0, "figure": 1}), Vector3(15, 4, 3), Vector3(0, 3, 0)],
				["full_bow", full.merged({"hull": 2, "sail": 1, "field": 1, "emblem": 1, "mark": 0, "figure": 1}), Vector3(5, 3, -16), Vector3(0, 2, -7)],
				["full_stern", full.merged({"hull": 3, "sail": 4, "field": 2, "emblem": 3, "mark": 2, "figure": 2}), Vector3(-8, 6, 18), Vector3(0, 3, 4)],
				["full_far", full.merged({"hull": 3, "sail": 4, "field": 2, "emblem": 3, "mark": 2, "figure": 2}), Vector3(-45, 12, -25), Vector3(0, 5, 0)],
				["full_deck", full.merged({"hull": 3, "sail": 4, "field": 2, "emblem": 3, "mark": 2, "figure": 2}), Vector3(1.5, 4.5, 8.5), Vector3(0, 2, -6)],
				["full_night", full.merged({"hull": 5, "sail": 2, "field": 3, "emblem": 2, "mark": 2, "figure": 3}), Vector3(16, 6, 6), Vector3(0, 4, 0)],
			])
			if tackett:
				shots.append(["tackett", null, tackett.global_position + tackett.global_basis.z * 4.0 + Vector3(1.5, 1.6, 0), tackett.global_position + Vector3(0, 1.0, 0)])
			shots.append(["screen", {"armour": 2, "guns": 1, "sails": 5}, Vector3.ZERO, Vector3.ZERO])
			shots.append(["screen_paint", null, Vector3.ZERO, Vector3.ZERO])
		t0 = t
		return false
	if i < 0 or t - t0 > 1.2:
		if i >= 0:
			root.get_texture().get_image().save_png("%s_%s.png" % [out, shots[i][0]])
			print("shot ", shots[i][0])
		i += 1
		if i >= shots.size():
			quit()
			return false
		var s: Array = shots[i]
		var wx = root.get_node("Weather")
		wx.set_world_time(wx.time_at(22.0 if s[0] == "full_night" else 13.0))
		if s[0] == "screen":
			kit(s[1])
			p.inventory_component.add_item(load("res://resources/items/gold.tres"), 300)
			root.get_node("GameMenu").open("yard")
		elif s[0] == "screen_paint":
			root.get_node("GameMenu")._yard.show_tab("paint")
		elif s[0] == "tackett":
			cam.global_position = s[2]
			cam.look_at(s[3], Vector3.UP)
		else:
			kit(s[1])
			# (sails set, so the jib and studding sails show; she's at anchor)
			ship.sail = 1.0
			ship.sail_shown = 1.0
			cam.global_position = ship.global_transform * s[2]
			cam.look_at(ship.global_transform * s[3], Vector3.UP)
		t0 = t
	elif not shots[i][0].begins_with("screen") and shots[i][0] != "tackett":
		cam.global_position = ship.global_transform * (shots[i][2] as Vector3)
		cam.look_at(ship.global_transform * (shots[i][3] as Vector3), Vector3.UP)
	return false
