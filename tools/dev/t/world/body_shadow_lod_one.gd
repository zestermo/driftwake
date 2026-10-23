extends "res://tools/dev/t/world/body_shadow_lod.gd"
## body_shadow_lod with BodyBuilder.one_skin on: shadows off past SHADOW_R still reach every part of a one-skin body,
## and come back the same.


func _initialize() -> void:
	BodyBuilder.one_skin = true
	super._initialize()


func _process(d: float) -> bool:
	if step == 0 and stage.up and stage.npc:
		check("the villager is one skin (no ArmBody)", stage.npc.humanoid.torso.get_node_or_null("ArmBody") == null)
	return super._process(d)
