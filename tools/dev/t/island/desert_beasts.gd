extends SceneTree
## The desert's beasts on the light stage, each woken with the captain 9 m off: the Sand King
## comes up under the captain (nothing reaches it while it's under the sand, it throws the
## captain down when it erupts, then rears up); the Dune Emperor, the Basilisk, the Sand Lion,
## the hyena alpha and the Dune Strider each fight and land a blow. Every kind in the desert's
## pool has its script, names, a banner and its ground's dressing.
const TK := preload("res://tools/dev/test_kit.gd")
const KINDS := ["sandworm", "giant_scorpion", "basilisk", "sand_lion", "hyena", "dune_strider"]
var stage
var p
var step := 0
var until := 0
var fails := 0
var ki := 0
var beast
var hp0 := 0.0
var seen := {}
var looks := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _hp() -> float:
	return p.get_node("HealthComponent").current_health


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var d = load("res://scripts/island/themes/island_themes.gd").of("desert")
	match step:
		0:
			p = stage.player
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			var bad: Array = []
			for k in d.bosses + d.minis + d.roamers:
				var info: Dictionary = d.beasts[k]
				if not ResourceLoader.exists(info["script"]) or (info["names"] as Array).is_empty():
					bad.append(k)
				if d.bosses.has(k) and not (info.has("banner") and info.has("dress")):
					bad.append(k + " (banner, dress)")
			check("every desert beast has its script and names, every boss a banner and its ground's dressing %s" % [bad], bad.is_empty() and d.bosses.size() >= 4)
			step = 1
		1:
			# the next beast, 9 m in front of the captain, woken
			var kind: String = KINDS[ki]
			var at: Vector3 = p.global_position + Vector3(0, 0, -9.0)
			beast = load(d.beasts[kind]["script"]).new()
			beast.setup({"post": at, "yaw": 0.0, "level": 6, "variant": ki % 3, "name": d.beasts[kind]["names"][0]})
			stage.add_child(beast)
			beast.global_position = at
			seen = {"under_shielded": false, "erupted": false, "reared": false}
			looks = 0
			hp0 = _hp()
			until = TK.wait_ticks(10)
			step = 2
		2:
			beast.alert()
			step = 3
			until = TK.wait_secs(0.2)
		3:
			# 9 s in 0.25 s looks
			looks += 1
			if KINDS[ki] == "sandworm":
				if beast.rise < 0.5 and not beast.hurtbox.monitorable:
					seen["under_shielded"] = true
				if beast.move == "erupt" and beast.mv_t > 1.2:
					seen["erupted"] = true
				if beast.rise > 0.9:
					seen["reared"] = true
			if looks < 36 and not (_hp() < hp0 and (KINDS[ki] != "sandworm" or seen["reared"])):
				until = TK.wait_secs(0.25)
				return false
			var kind: String = KINDS[ki]
			check("%s fights and lands a blow (%s, %.0f hp taken)" % [kind, beast.state_name(), hp0 - _hp()], beast.in_combat() and _hp() < hp0)
			if kind == "sandworm":
				check("...under the sand nothing reaches it, it erupts under the captain and rears up %s" % [seen], seen["under_shielded"] and seen["erupted"] and seen["reared"])
			beast.queue_free()
			p.get_node("HealthComponent").current_health = 99999.0
			ki += 1
			if ki >= KINDS.size():
				return TK.done(fails)
			step = 1
			until = TK.wait_secs(0.5)
	return false
