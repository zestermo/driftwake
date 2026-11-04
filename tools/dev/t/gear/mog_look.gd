extends SceneTree
## (1.30) Transmog: a mogged slot's body shows the cosmetic piece while the worn one still gives every stat; an empty
## cosmetic slot shows the worn piece, unticking shows it again, and a crewmate's screen (the look on the wire) shows
## the mogged look.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pup
var gear
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "crew": [{"name": "Wren", "at": Vector3(3, 0, -2)}]})


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
			pup = stage.crew[0]
			gear = load("res://scripts/loot/gear.gd")
			p.equipment.clear()
			p.equipment.equip(gear.make("coat", "greatcoat", {"coat": "greatcoat"}, "", 0))
			p.equipment.equip(gear.make("head", "kettle", {"hat": "kettle"}, "", 0))
			p.refresh_look()
			var mv: float = p.move_speed
			var df: float = p.defense()
			check("worn: a greatcoat and a kettle helm", p.body_model.look.get("coat") == "greatcoat" and p.body_model.look.get("hat") == "kettle")
			p.equipment.set_mog("coat", true)
			p.refresh_look()
			check("MOG ticked with an empty cosmetic slot shows the worn coat", p.body_model.look.get("coat") == "greatcoat")
			p.equipment.wear_cosmetic(gear.make("coat", "jacket", {"coat": "jacket"}, "", 0), "coat")
			p.equipment.wear_cosmetic(gear.make("head", "tricorn", {"hat": "tricorn"}, "", 0), "head")
			p.refresh_look()
			check("a cosmetic piece in an unticked slot isn't drawn", p.body_model.look.get("hat") == "kettle")
			p.equipment.set_mog("head", true)
			p.refresh_look()
			check("mogged: the body wears the jacket and tricorn (%s, %s)" % [p.body_model.look.get("coat"), p.body_model.look.get("hat")],
				p.body_model.look.get("coat") == "jacket" and p.body_model.look.get("hat") == "tricorn")
			check("...the stats are still the greatcoat's and the helm's (speed %.2f, defence %.1f)" % [p.move_speed, p.defense()],
				is_equal_approx(p.move_speed, mv) and is_equal_approx(p.defense(), df))
			check("...the worn slots still hold the real pieces", p.equipment.get_item("coat").display_name != p.equipment.get_cosmetic("coat").display_name)
			pup.net_event("look", [p.body_model.look.duplicate(true), false])
			until = TK.wait_ticks(4)
		1:
			check("a crewmate's screen shows the mogged look", pup.body_model.look.get("coat") == "jacket" and pup.body_model.look.get("hat") == "tricorn")
			p.drape_coat(true)
			check("DRAPE drapes the coat that's shown", p.equipment.is_draped(p.equipment.get_cosmetic("coat")) and p.body_model.look.get("coat_drape") == true)
			p.drape_coat(false)
			p.equipment.set_mog("coat", false)
			p.equipment.set_mog("head", false)
			p.refresh_look()
			check("unticked: the worn greatcoat and helm show again", p.body_model.look.get("coat") == "greatcoat" and p.body_model.look.get("hat") == "kettle")
			check("...and the cosmetic pieces wait in their slots", p.equipment.get_cosmetic("coat") != null and p.equipment.get_cosmetic("head") != null)
			var ok := true
			for s in gear.SLOTS:
				if not s[0] in p.equipment.MOG_SLOTS:
					continue
				var bare: Dictionary = gear.bare(s[0], false)
				ok = ok and gear.SLOT_KEYS.has(s[0]) and not bare.is_empty()
			check("every mog slot draws on the body", ok and p.equipment.MOG_SLOTS.size() == 10)
			return TK.done(fails)
	step += 1
	return false
