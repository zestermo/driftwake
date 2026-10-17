extends SceneTree
## The snow village's dressing and life: its fences (snow on the rails, a collider), its iron lamps for the
## jungle's torches (a Flame), its firs in tubs, most yards fenced (the jungle's none); no butterflies or fireflies
## on a snow island (the jungle keeps them); the chain's wreck is the snow's frozen one; the tame shagback wears
## its packs, minds nobody, shies a few steps when struck and comes back to its post, its LOD on its own timer.
const TK := preload("res://tools/dev/test_kit.gd")
const SHAG := "res://scripts/enemies/fauna/shagback.gd"
var stage
var p
var beast
var home := Vector3.ZERO
var step := 0
var until := 0
var fails := 0
var far := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var KS = load("res://scripts/island/kit/kit_style.gd")
	match step:
		0:
			p = stage.player
			var st: Dictionary = KS.of("snow")
			var items: Dictionary = st["item_models"]
			var rng := RandomNumberGenerator.new()
			rng.seed = 3
			var fence: Node3D = KS.model(items["fence"], rng, 1.0)
			var lamp: Node3D = KS.model(items["torch"], rng, 1.0)
			var tub: Node3D = KS.model(items["planter"], rng, 1.0)
			check("snow fences (a collider), iron lamps for torches (a Flame), firs in tubs (a collider)",
				fence.find_children("*", "CollisionShape3D", true, false).size() > 0 and lamp.get_node_or_null("Flame") != null
				and tub.find_children("*", "CollisionShape3D", true, false).size() > 0)
			for n in [fence, lamp, tub]:
				n.free()
			check("most snow yards are fenced, the jungle's never", float(st["yard_fences"]) >= 0.5 and float(KS.of("jungle")["yard_fences"]) == 0.0)
			var FS = load("res://scripts/island/fauna_spawner.gd")
			var snow_bugs := 0
			var jungle_bugs := 0
			for s in range(12):
				var a: Dictionary = FS.roll("snow", s * 101)["ambient"]
				var b: Dictionary = FS.roll("jungle", s * 101)["ambient"]
				snow_bugs += int(a["butterflies"]) + int(a["fireflies"])
				jungle_bugs += int(b["butterflies"]) + int(b["fireflies"])
			check("no butterflies or fireflies on snow islands (%d), the jungle's as before (%d)" % [snow_bugs, jungle_bugs], snow_bugs == 0 and jungle_bugs > 12)
			var snow = load("res://scripts/island/themes/island_themes.gd").of("snow")
			check("the chain's wreck is the snow's frozen one", snow.place_kind("wreck") == "snow_wreck" and snow.place_kind("temple") == "")
			# the village's beast of burden, 8 m in front of the captain
			home = p.global_position + Vector3(0, 0, -8.0)
			beast = load(SHAG).new()
			beast.setup(home, {"tame": true, "morph": 1})
			beast.name = "VillageShagback"
			stage.add_child(beast)
			beast.global_position = home + Vector3.UP * 0.2
			until = TK.wait_secs(2.0)
		1:
			check("tame: minds nobody, worth nothing, its own LOD timer", not beast.hostile and beast.xp == 0 and beast.get_node_or_null("Lod") is Timer
				and beast.lod == 0)
			check("it stays about its post (%.1f m)" % beast.global_position.distance_to(home), beast.global_position.distance_to(home) < 4.0)
			beast._stampede(p.global_position)
			until = TK.wait_secs(1.2)
		2:
			far = beast.global_position.distance_to(home)
			until = TK.wait_secs(9.0)
		3:
			var back: float = beast.global_position.distance_to(home)
			check("struck, it shies a few steps (%.1f m) and comes back to its post (%.1f m)" % [far, back], far > 1.0 and far < 9.0 and back < 4.0)
			return TK.done(fails)
	step += 1
	return false
