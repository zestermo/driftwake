extends SceneTree
## Vendors at a glance (VendorMarks): an NPC with a shop wears a gold badge with their trade's sign over their head
## while you're within VendorMarks.SHOW_R, and is on the held map (MapMarks "shop", with the trade); an NPC whose talk
## opens a shop ("shop:<id>", Vey) is a vendor too; someone without one has neither. Saves a screenshot to look at.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var smith
var talker
var plain
var wright
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func npc(cfg: Dictionary, at: Vector3) -> Node3D:
	var n = load("res://scripts/npc/npc.gd").new().setup(cfg)
	stage.add_child(n)
	n.global_position = at
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			root.size = Vector2i(1280, 720)
			smith = npc({"name": "Haldor Test", "shop": "haldor"}, p.global_position + Vector3(-1.5, 0, -5.0))
			talker = npc({"name": "Vey Test", "dialogue": "vey"}, p.global_position + Vector3(1.5, 0, -5.0))
			plain = npc({"name": "Plain Test"}, p.global_position + Vector3(0, 0, -7.0))
			wright = npc({"name": "Tackett Test", "dialogue": "tackett"}, p.global_position + Vector3(3.0, 0, -6.0))
			stage.camera_rig.rotation.y = 0.0
			until = TK.wait_secs(2.5)
		1:
			var MM = load("res://scripts/map/map_marks.gd")
			var a = smith.get_node_or_null("VendorMark")
			check("the smith wears a vendor's badge, shown close by", a != null and a.visible)
			check("...on the map as a shop, a smith's sign", MM.has("vendor:haldor:Haldor Test") and MM.marks["vendor:haldor:Haldor Test"]["kind"] == "shop" and MM.marks["vendor:haldor:Haldor Test"]["trade"] == "smith")
			var b = talker.get_node_or_null("VendorMark")
			check("Vey (a shop opened from her talk) wears one too", b != null and b.visible)
			check("someone with no shop has none", plain.get_node_or_null("VendorMark") == null)
			var w = wright.get_node_or_null("VendorMark")
			check("(1.26) a shipwright wears one, a shipwright's sign on the map", w != null and w.visible and MM.has("vendor:@shipwright:Tackett Test") and MM.marks["vendor:@shipwright:Tackett Test"]["trade"] == "shipwright")
			# (a window to look at when run by hand; the runner's headless)
			var img = root.get_texture().get_image()
			if img:
				img.save_png(ProjectSettings.globalize_path("res://tools/dev/out/vendor_marks.png"))
			p.global_position += Vector3(0, 0, 60.0)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.5)
		2:
			check("far off (60 m): the badge hides", not smith.get_node("VendorMark").visible)
			smith.queue_free()
			until = TK.wait_ticks(3)
		3:
			check("gone: off the map", not load("res://scripts/map/map_marks.gd").has("vendor:haldor:Haldor Test"))
			return TK.done(fails)
	step += 1
	return false
