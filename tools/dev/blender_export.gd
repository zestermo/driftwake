extends SceneTree
## The default captain baked into art/blender/captain.blend (and the game's model) through
## Blender: see BlenderBody. In game, Ctrl+F4 exports your own captain as worn.
func _initialize() -> void:
	print(BlenderBody.export_captain(CharacterLook.default_look(), true, true))
	quit()
