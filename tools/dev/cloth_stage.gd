extends Node3D
## The cloth stage (1.30.3): a playable test stage for judging clothing by hand. Open tools/dev/cloth_stage.tscn in the
## editor and press F6 (Run Current Scene). The light stage (flat ground, a dummy, a cutlass) with the captain in one
## outfit at a time and a mannequin in the same outfit turning back and forth beside the spawn.
## Keys: L toggles the cloth: chains or sewn chains (BodyBuilder.cloth_sewn); PageDown / PageUp next / previous outfit, Insert the body (masc, fem, stout, slim), Home the cloth's weight
## (BodyBuilder.CLOTH_FEELS), End slow motion (x0.3), Delete the mannequin on/off. Shift+F1 still toggles every net.

const OUTFITS := [
	["skirt", {"body": "fem", "hair": "short", "legs": "skirt", "coat": "none"}],
	["twin tails + skirt", {"body": "fem", "hair": "twintails", "legs": "skirt", "coat": "none"}],
	["jacket", {"hair": "short", "hat": "none", "coat": "jacket", "coat_color": Color(0.36, 0.12, 0.1)}],
	["long coat + sash", {"hair": "long", "coat": "longcoat", "belt": "sash"}],
	["captain's coat", {"hair": "short", "coat": "captain"}],
	["greatcoat", {"hair": "short", "coat": "greatcoat"}],
	["duster", {"hair": "short", "coat": "duster", "belt": "wide_belt"}],
	["admiral", {"hair": "short", "coat": "admiral"}],
	["frock", {"hair": "ponytail", "coat": "frock"}],
	["kimono + hakama", {"hair": "topknot", "hat": "none", "top": "kimono", "legs": "hakama", "coat": "none"}],
	["haori + hakama", {"hair": "topknot", "hat": "none", "top": "kimono", "legs": "hakama", "coat": "haori"}],
	["tunic", {"hair": "short", "top": "tunic", "coat": "none"}],
	["skirt under a long coat", {"body": "fem", "hair": "ponytail", "legs": "skirt", "coat": "longcoat"}],
	["bandana, braid, apron", {"hair": "braid", "hat": "bandana", "apron": true, "coat": "none"}],
	["cape", {"hair": "short", "coat": "none", "cape": true}],
	["cloak", {"hair": "short", "coat": "none", "cloak": true}],
	["draped long coat", {"hair": "short", "hat": "none", "coat": "longcoat", "coat_drape": true, "belt": "sash"}],
	["long hair", {"body": "fem", "hair": "long", "hat": "none", "coat": "none"}],
	["flowing hair", {"body": "fem", "hair": "cascade", "hat": "none", "coat": "none"}],
	["ponytail", {"hair": "ponytail", "hat": "none", "coat": "none"}],
	["dreadlocks", {"hair": "dreads", "hat": "none", "coat": "none"}],
]
const BODIES := [["masc", {"body": "masc", "build": "average"}], ["fem", {"body": "fem", "build": "average"}],
	["stout", {"body": "masc", "build": "stout"}], ["slim", {"body": "fem", "build": "slim"}]]
const MANNEQUIN_AT := Vector3(2.2, 0, -1.5)

var stage
var outfit := 0
var body := 0
var slow := false
var mannequin: Node3D
var mannequin_on := true
var _turn := 0.0
var _looked := false
var _label: Label


func _ready() -> void:
	stage = load("res://tools/dev/stage.gd").new()
	stage.build({"dummy": true, "weapon": "cutlass"})
	# (on the root, beside this node: the stage makes itself the current scene)
	get_tree().root.add_child.call_deferred(stage)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(12, 12)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)


func _process(delta: float) -> void:
	if not _looked and stage.up:
		_looked = true
		_apply()
	if mannequin and mannequin.visible:
		# back and forth through a half turn every 2.4 s, with a quick snap at each end: the cloth's swing and settle
		_turn += delta
		var ph := fmod(_turn, 2.4) / 2.4
		var target := 0.0 if ph < 0.5 else PI
		mannequin.rotation.y = lerp_angle(mannequin.rotation.y, target, minf(1.0, 9.0 * delta))
	_show()


func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if not k or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_PAGEDOWN:
			outfit = (outfit + 1) % OUTFITS.size()
			_apply()
		KEY_PAGEUP:
			outfit = (outfit - 1 + OUTFITS.size()) % OUTFITS.size()
			_apply()
		KEY_INSERT:
			body = (body + 1) % BODIES.size()
			_apply()
		KEY_J:
			BodyBuilder.hair_feel = (BodyBuilder.hair_feel + 1) % BodyBuilder.HAIR_FEELS.size()
			_apply()
		KEY_HOME:
			BodyBuilder.cloth_feel = (BodyBuilder.cloth_feel + 1) % BodyBuilder.CLOTH_FEELS.size()
			_apply()
		KEY_L:
			BodyBuilder.cloth_sewn = not BodyBuilder.cloth_sewn
			_apply()
		KEY_END:
			slow = not slow
			Engine.time_scale = 0.3 if slow else 1.0
		KEY_DELETE:
			if mannequin:
				mannequin_on = not mannequin_on
				mannequin.visible = mannequin_on
		_:
			return
	get_viewport().set_input_as_handled()


func _look() -> Dictionary:
	var lk: Dictionary = CharacterLook.default_look()
	lk.merge(BODIES[body][1], true)
	lk.merge(OUTFITS[outfit][1], true)
	# (a key of its own per cloth weight: Humanoid.make pools prebuilt bodies by look)
	lk["_cloth_feel"] = BodyBuilder.cloth_feel
	lk["_cloth_sewn"] = BodyBuilder.cloth_sewn
	lk["_hair_feel"] = BodyBuilder.hair_feel
	return lk


func _apply() -> void:
	if not stage.up:
		return
	var lk := _look()
	stage.player.body_model.apply_look(lk)
	if mannequin:
		mannequin.queue_free()
	mannequin = Humanoid.make(lk)
	mannequin.position = Vector3(0, stage.GROUND_Y, 0) + MANNEQUIN_AT
	mannequin.visible = mannequin_on
	add_child(mannequin)


func _show() -> void:
	var feel: Array = BodyBuilder.CLOTH_FEELS[BodyBuilder.cloth_feel]
	_label.text = "CLOTH STAGE   %d/%d %s   body: %s   cloth weight: %s   hair weight: %s   cloth: %s%s\n" % [outfit + 1,
		OUTFITS.size(), OUTFITS[outfit][0], BODIES[body][0], feel[0], BodyBuilder.HAIR_FEELS[BodyBuilder.hair_feel][0],
		"SEWN CHAINS" if BodyBuilder.cloth_sewn else "chains",
		"   SLOW x0.3" if slow else ""] + \
		"PgDn/PgUp outfit   Ins body   Home cloth weight   J hair weight   L chains/sewn   End slow-mo   Del mannequin   Shift+F1 nets"
