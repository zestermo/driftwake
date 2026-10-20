class_name Bait
extends RefCounted
## Fishing bait (v1.18): stacks in the bag, one used up for every catch landed (Fishing's Bait Saver keeps it now
## and then). On the hook is the bait the captain picked (a click on it in the bag: InventoryComponent.bait), or,
## with none picked or none of it left, the best they carry; with none at all it's a bare hook. Better bait brings
## bites sooner and/or rarer fish; glow bait is better again by night. Sold by fishers and grocers, or cut on the
## action wheel (Cut bait: Fishing.cut_bait) from a crab, a fish or an urchin with some kelp.
## (Data only: ItemDB names this class, and test scripts name ItemDB before the autoloads exist.)

## id -> [name, value, bite time k, rare odds k, description]
const ITEMS := {
	"bait_worm": ["Worms", 1, 0.8, 1.0, "A tin of fat red worms. Every fish likes a worm: bites come sooner."],
	"bait_cut": ["Cut Bait", 1, 0.75, 1.05, "Strips of fresh fish. The smell brings them quick."],
	"bait_shrimp": ["Shrimp Bait", 2, 0.9, 1.35, "Peeled shrimp on the hook. The better fish come for it."],
	"bait_glow": ["Glow Bait", 4, 0.9, 1.55, "Urchin roe and luminous kelp rolled into a pellet that shines underwater. The rarest fish come for it, by night most of all."],
}
## Best first: the bait used when nothing's picked or what was picked has run out.
const ORDER := ["bait_glow", "bait_shrimp", "bait_cut", "bait_worm"]
## Glow bait's rare odds by night are this much better again.
const NIGHT_K := 1.4
## Cut bait (the action wheel), tried in order: [[what it takes: [item id, count]...], [what it makes, how many]].
const CUT := [[[["sea_urchin", 1], ["seaweed", 1]], ["bait_glow", 3]], [[["crab_meat", 1]], ["bait_shrimp", 3]], [[["fish", 1]], ["bait_cut", 4]]]

static var _icons: Dictionary = {}


static func is_bait(it: ItemData) -> bool:
	return it != null and ITEMS.has(it.id)


static func bite_k(id: String) -> float:
	return float(ITEMS[id][2]) if id != "" else 1.0


static func rare_k(id: String, night: bool) -> float:
	if id == "":
		return 1.0
	return float(ITEMS[id][3]) * (NIGHT_K if night and id == "bait_glow" else 1.0)


## (ItemDB._load_all) the baits into the item table.
static func make_items(items: Dictionary) -> void:
	for id in ITEMS.keys():
		var e: Array = ITEMS[id]
		var it := ItemData.new()
		it.id = id
		it.display_name = str(e[0])
		it.value = int(e[1])
		it.description = str(e[4])
		it.item_type = ItemData.ItemType.LOOT
		it.max_stack = 30
		it.icon_kind = "bait"
		it.icon = icon(id)
		items[id] = it


## The first CUT recipe `inv` holds everything for (-1: none).
static func recipe_for(inv) -> int:
	for i in range(CUT.size()):
		var ok := true
		for need in CUT[i][0]:
			ok = ok and inv.count(str(need[0])) >= int(need[1])
		if ok:
			return i
	return -1


static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		_icons[id] = WeaponDesigns.mesh_icon(mesh(id), Basis.from_euler(Vector3(0.5, 0.0, 0.0)), 0.0)
	return _icons[id]


## A small model of the bait (for its icon): a tin of worms, a curled shrimp, strips of fish, a glowing pellet.
static func mesh(id: String) -> ArrayMesh:
	var mb := MeshBuilder.new()
	match id:
		"bait_worm":
			mb.add_cylinder(PSXMat.lit("metal", Color(0.6, 0.6, 0.62)), Transform3D.IDENTITY, 0.05, 0.05, 0.035, 8, 4.0, Color.WHITE, true, true)
			for k in range(3):
				var a := k * 2.1
				mb.add_tube(PSXMat.flat(Color(0.75, 0.35, 0.35)), MeshBuilder.curve_points(Vector3(cos(a) * 0.02, 0.03, sin(a) * 0.02),
					Vector3(cos(a + 1.0) * 0.05, 0.07, sin(a + 1.0) * 0.05), Vector3(cos(a + 2.0) * 0.03, 0.04, sin(a + 2.0) * 0.03), 5), 0.007, 0.006, 4)
		"bait_shrimp":
			mb.add_tube(PSXMat.flat(Color(0.95, 0.55, 0.45)), MeshBuilder.curve_points(Vector3(-0.05, 0.0, 0.0), Vector3(0.0, 0.06, 0.0), Vector3(0.05, 0.0, 0.0), 6), 0.016, 0.006, 5)
		"bait_cut":
			for k in range(3):
				mb.add_box(PSXMat.flat(Color(0.85, 0.75, 0.75)), Transform3D(Basis(Vector3.UP, k * 0.5), Vector3(k * 0.02 - 0.02, k * 0.012, 0)), Vector3(0.08, 0.01, 0.025), 4.0, Color.WHITE, false)
		"bait_glow":
			mb.add_blob(PSXMat.glow(Color(0.45, 0.95, 0.75), 2.0), Transform3D.IDENTITY, Vector3(0.03, 0.03, 0.03), RandomNumberGenerator.new(), 0.0, 4, 6, 4.0, Color.WHITE, false)
	return mb.commit()
