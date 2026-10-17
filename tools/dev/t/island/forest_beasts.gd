extends SceneTree
## The forest's beasts on the light stage, each woken with the captain 9 m off: the Stag King, the Elder Treant,
## the moss golem and the Wild Hunt each fight and land a blow. The Wild Hunt is nowhere by day (hidden, nothing
## to hit or bump into) and abroad at night. Every kind in the forest's pool has its script and names, every boss
## a banner and its ground's dressing; the pool has four bosses, its minis keep different sites.
const TK := preload("res://tools/dev/test_kit.gd")
const KINDS := ["stag_king", "elder_treant", "moss_golem", "wild_hunt"]
var stage
var p
var step := 0
var until := 0
var fails := 0
var ki := 0
var beast
var hp0 := 0.0
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
	var f = load("res://scripts/island/themes/island_themes.gd").of("forest")
	var wx = root.get_node("Weather")
	match step:
		0:
			p = stage.player
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			var bad: Array = []
			for k in f.bosses + f.minis + f.roamers:
				var info: Dictionary = f.beasts[k]
				if not ResourceLoader.exists(info["script"]) or (info["names"] as Array).is_empty():
					bad.append(k)
				if ["stag_king", "elder_treant"].has(k) and not (info.has("banner") and info.has("dress")):
					bad.append(k + " (banner, dress)")
			var sites: Array = f.minis.map(func(m): return f.beasts[m]["site"])
			check("every forest beast has its script and names, its own bosses a banner and their ground's dressing %s; minis at %s" % [bad, sites],
				bad.is_empty() and f.bosses.size() >= 4 and sites.size() == _uniq(sites))
			step = 1
		1:
			var kind: String = KINDS[ki]
			var at: Vector3 = p.global_position + Vector3(0, 0, -9.0)
			wx.night = 0.0
			beast = load(f.beasts[kind]["script"]).new()
			beast.setup({"post": at, "yaw": 0.0, "level": 6, "variant": ki % 3, "name": f.beasts[kind]["names"][0]})
			stage.add_child(beast)
			beast.global_position = at
			looks = 0
			hp0 = _hp()
			until = TK.wait_ticks(10)
			step = 2
		2:
			if KINDS[ki] == "wild_hunt":
				# by day it isn't anywhere
				wx.night = 0.0
				until = TK.wait_ticks(6)
				step = 20
				return false
			beast.alert()
			step = 3
			until = TK.wait_secs(0.2)
		20:
			check("by day the Wild Hunt is nowhere: hidden, nothing to bump into or hit", not beast.model.visible and beast.collision_layer == 0 and not beast.hurtbox.monitorable)
			wx.night = 1.0
			until = TK.wait_ticks(6)
			step = 21
		21:
			check("at night it rides: seen and solid", beast.model.visible and beast.collision_layer != 0)
			beast.alert()
			step = 3
			until = TK.wait_secs(0.2)
		3:
			looks += 1
			# (the captain stands still: a beast that walks into them can lift them onto its back - put them down again in front of it)
			if p.global_position.y > beast.global_position.y + 1.5:
				p.global_position = beast.global_position + beast._fwd() * 4.0 + Vector3.UP * 0.2
				p.reset_physics_interpolation()
			if looks < 40 and _hp() >= hp0:
				until = TK.wait_secs(0.25)
				return false
			check("%s fights and lands a blow (%s, %.0f hp taken)" % [KINDS[ki], beast.state_name(), hp0 - _hp()], beast.in_combat() and _hp() < hp0)
			beast.queue_free()
			p.get_node("HealthComponent").current_health = 99999.0
			ki += 1
			if ki >= KINDS.size():
				wx.night = 0.0
				return TK.done(fails)
			step = 1
			until = TK.wait_secs(0.5)
	return false


func _uniq(a: Array) -> int:
	var d := {}
	for x in a:
		d[x] = true
	return d.size()
