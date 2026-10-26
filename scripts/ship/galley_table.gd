class_name GalleyTable
extends Node3D
## The galley table (1.23, docs/v1_23_plan.md "Galley meals"): a pot cooked aboard with more than one portion goes on
## the table by the galley, the cook keeping one. Any crewmate takes a portion (E) and eats it on the spot, with the
## COOK's strength and length (their Cooking tree: meal_power_pct, meal_time_pct), named for them ("Zach's Sea Stew").
## One pot at a time (a new one replaces what's left). The host counts the portions (Net.table_take); every screen
## shows the same pot (Net._all_table).

const MAX_BOWLS := 6

var meal := ""
var left := 0
var cook := ""
## The cook's strength and seconds for this pot.
var k := 1.0
var secs := 0.0
var _use: Interactable
var _bowls: Array[MeshInstance3D] = []


static func of(tree: SceneTree) -> GalleyTable:
	var s := tree.get_first_node_in_group("ship")
	return s.get_node_or_null("ShipModel/GalleyTable") as GalleyTable if s else null


func _ready() -> void:
	_use = Interactable.new()
	_use.name = "Eat"
	_use.collision_layer = 512
	_use.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.1
	cs.shape = sph
	_use.add_child(cs)
	_use.position = Vector3(0, 0.9, 0)
	add_child(_use)
	_use.interacted.connect(func(_p: Player): get_node("/root/Net").table_take())
	var mat := PSXMat.flat(Color(0.55, 0.36, 0.2))
	for i in range(MAX_BOWLS):
		var m := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.09
		cyl.bottom_radius = 0.06
		cyl.height = 0.06
		cyl.radial_segments = 8
		m.mesh = cyl
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visibility_range_end = 30.0
		m.position = Vector3(-0.2 + 0.2 * (i % 3), 0.93, -0.15 + 0.3 * (i / 3))
		add_child(m)
		_bowls.append(m)
	_show()


## (every machine) the pot on the table now.
func set_pot(meal_: String, left_: int, cook_: String, k_: float, secs_: float) -> void:
	meal = meal_
	left = left_
	cook = cook_
	k = k_
	secs = secs_
	_show()


func _show() -> void:
	for i in range(_bowls.size()):
		_bowls[i].visible = meal != "" and i < left
	_use.enabled = meal != "" and left > 0
	_use.prompt_text = ("Eat %s's %s (%d left)" % [cook, str(Food.MEALS[meal]["name"]), left]) if meal != "" and left > 0 else ""


## The name it goes by: "Zach's Sea Stew".
func dish() -> String:
	return "%s's %s" % [cook, str(Food.MEALS[meal]["name"])] if meal != "" else ""
