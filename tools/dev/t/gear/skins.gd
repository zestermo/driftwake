extends SceneTree
## Skins (1.24): a tailor's patterned piece is named for its pattern and wears it (taking it off or swapping for a plain
## one drops it); a village tailor and smith stock skins; a weapon skin hits like the plain weapon and never drops as
## loot.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var gear = load("res://scripts/loot/gear.gd")
			var vv = load("res://scripts/island/village_vendors.gd")
			var wd = load("res://scripts/props/weapon_designs.gd")
			var db = load("res://scripts/loot/item_db.gd")
			var coat = gear.make("coat", "longcoat", {"coat": "longcoat", "coat_color": Color(0.4, 0.1, 0.12), "coat_pattern": "brocade"}, "", 1)
			check("a patterned coat is named for it (%s)" % coat.display_name, coat.display_name.begins_with("Brocade "))
			p.equipment.equip(coat)
			p.refresh_look()
			check("worn, the body has the pattern", str(p.body_model.look.get("coat_pattern", "")) == "brocade")
			p.equipment.equip(gear.make("coat", "jacket", {"coat": "jacket"}, "", 0))
			p.refresh_look()
			check("a plain coat over it: no pattern left", not p.body_model.look.has("coat_pattern"))
			var tailor: Dictionary = vv.shop("tailor", "Mira")
			var pats := (tailor["pool"] as Array).filter(func(e): return e.size() > 2 and str((e[2] as Dictionary).keys()).contains("_pattern"))
			check("a village tailor stocks patterned skins (%d)" % pats.size(), pats.size() >= 8)
			var smith: Dictionary = vv.shop("smith", "Bram")
			var skins: Array = wd.skin_ids()
			check("a village smith stocks the weapon skins (%d)" % skins.size(), skins.size() >= 8
				and skins.all(func(id): return (smith["pool"] as Array).has([id])))
			var gilded = db.get_item("gilded_cutlass")
			var plain = db.get_item("cutlass")
			check("a skin hits like the plain weapon", gilded != null and is_equal_approx(gilded.damage_mult, plain.damage_mult) and gilded.design == "gilded")
			check("...and its mesh builds", wd.build(gilded.model()) != null and gilded.icon != null)
			var looted := true
			for kind in wd.BASE_ITEM.keys():
				for id in wd.item_ids(kind):
					if id in skins:
						looted = false
			check("skins never come up as loot", looted)
			return TK.done(fails)
	step += 1
	return false
