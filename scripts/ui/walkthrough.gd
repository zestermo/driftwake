class_name Walkthrough
extends CanvasLayer
## The first-time tips (1.23 tutorial, docs/v1_23_plan.md): the first time a captain opens a screen or a wheel, a small
## card explains it in a few lines (Enter or a click to close). Each is shown once per player (Settings "tips"), and
## Options' "Replay the tips" clears them. Tests and tools never show them.

## screen id -> [title, lines]
const TIPS := {
	"skills": ["The skill map (K)", [
		"Every weapon you fight with has its own tree. Use a weapon and its mastery rises; each level gives that tree points.",
		"Click a node to buy it once its level is reached. Techniques go on your bar (1-5), passives in your passive slots.",
		"Versions and talents switch at a rest spot: the ship's bunk, an inn, or your camp."]],
	"inventory": ["Your bag (I)", [
		"Drag gear onto your body to wear it, a weapon into your hands to wield it. Shift+click moves a whole stack.",
		"Your empty hand slot switches fists and kicks (once you know black leg).",
		"Each loadout (X) remembers what's in your hands: set one up here, then swap to it in a fight."]],
	"loadout": ["Loadouts (X)", [
		"A loadout is a weapon setup: twin daggers in one, a cutlass and pistol in another, your kicks in a third.",
		"Tap X to swap to the next, hold X to pick. Your techniques follow the weapon they belong to.",
		"Set a loadout up by equipping what you want while it's the one in use."]],
	"action": ["The action wheel (N)", [
		"Everything you can do where you stand: make camp, cook, train, fish, read, sleep aboard.",
		"Hold N and point at one. It only shows what fits where you are."]],
	"journal": ["The journal (J)", [
		"Every quest the crew has taken, what's done, and the rumours you've heard.",
		"T tracks a quest (the marker and the goal at the top of the screen follow it); X twice drops one."]],
	"wanted": ["Wanted", [
		"Your bounty and what it brings down on you: patrols, hunters, shops that won't serve you.",
		"It rises with what you sink, raid and beat. A day without a deed cools the heat."]],
	"crew": ["Your crew", [
		"Your crew's name and flag, who's aboard and who's sailed with you. The Captain renames the crew and paints the flag."]],
}

static var _tree: SceneTree


## Show screen `id`'s tip if this player hasn't seen it.
static func first(tree: SceneTree, id: String) -> void:
	if not TIPS.has(id):
		return
	var s := tree.root.get_node_or_null("Settings")
	if s == null or s.call("tool_run"):
		return
	var got = s.call("get_value", "tips", "seen")
	var seen: Array = (got as Array).duplicate() if got is Array else []
	if seen.has(id):
		return
	seen.append(id)
	s.call("set_value", "tips", "seen", seen)
	for old in tree.get_nodes_in_group("walkthrough"):
		old.queue_free()
	var w := Walkthrough.new()
	w.add_to_group("walkthrough")
	tree.root.add_child(w)
	w._build(TIPS[id])


## Options: every tip again.
static func reset(tree: SceneTree) -> void:
	var s := tree.root.get_node_or_null("Settings")
	if s:
		s.call("set_value", "tips", "seen", [])


func _build(tip: Array) -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIStyle.chrome("slate", 12, 9))
	pc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pc.offset_bottom = -64.0
	pc.custom_minimum_size = Vector2(380, 0)
	add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pc.add_child(vb)
	vb.add_child(UIStyle.label(str(tip[0]), 12, UIStyle.ACCENT))
	for line in tip[1]:
		var l := UIStyle.label(str(line), 8, UIStyle.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(360, 0)
		vb.add_child(l)
	var ok := UIStyle.button("Got it (Enter)", 110)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(queue_free)
	vb.add_child(ok)
	UIStyle.sfx("open")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		queue_free()
