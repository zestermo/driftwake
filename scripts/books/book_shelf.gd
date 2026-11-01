class_name BookShelf
extends Node3D
## The bookshelf in the ship's cabin (1.28): its rows fill with a spine per book this screen's captain has read, and F
## at it opens the collection (GameMenu "books": BookshelfScreen). Each captain sees their own books. Faces +Z.
## Per frame: nothing; a 1 s timer compares Books.rev and the captain's count, and rebuilds the spines on a change.

var _spines: MeshInstance3D
var _shown := -1


static func place(parent: Node3D, at: Vector3, yaw: float) -> BookShelf:
	var s := BookShelf.new()
	s.name = "BookShelf"
	parent.add_child(s)
	s.position = at
	s.rotation.y = yaw
	return s


func _ready() -> void:
	add_to_group("bookshelves")
	var mi := MeshInstance3D.new()
	mi.name = "Model"
	mi.mesh = BookModels.shelf()
	mi.visibility_range_end = 40.0
	add_child(mi)
	_spines = MeshInstance3D.new()
	_spines.name = "Spines"
	_spines.visibility_range_end = 30.0
	_spines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spines)
	var it := Interactable.new()
	it.name = "Use"
	it.collision_layer = 512
	it.collision_mask = 0
	it.prompt_text = "Browse the bookshelf"
	it.gesture = "reach"
	it.reach = 1.2
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.8
	cs.shape = sph
	it.add_child(cs)
	add_child(it)
	it.position = Vector3(0, 1.0, BookModels.SHELF_D + 0.5)
	it.interacted.connect(func(_p: Player): GameMenu.open("books"))
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(refresh)
	add_child(t)
	refresh()


## The spines for this screen's captain's books (rebuilt only when the count changed).
func refresh() -> void:
	var p := get_tree().get_first_node_in_group("player")
	# (the ship is built before the captain's ready in the world scene: the timer catches up)
	if p == null or p.progression == null:
		return
	var n: int = Books.count(p.progression)
	if n == _shown:
		return
	_shown = n
	var ids := Books.read_ids(p.progression)
	_spines.mesh = BookModels.spines(ids.map(func(id): return BookData.kind_of(id)), 7177) if not ids.is_empty() else null


func spine_count() -> int:
	return _shown
