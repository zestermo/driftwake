class_name MasteredGuard
## A weapon's mastered guard (1.18.4): its tree's big node at ~15 ("guard2_<tree>") gives a second stance, and once
## owned a double-tap of block (two parry presses within TAP s) switches between the two guards, any time. The pick
## is kept per weapon tree in Progression.guards (saved); the body shows it through Humanoid.guard2 (synced).

const TAP := 0.32
## tree -> [the first guard's name, the mastered guard's].
const NAMES := {"axe": ["Brawler's Guard", "Bearded Guard"], "katana": ["Middle Guard", "Waki Guard"], "sword": ["Swashbuckler's Guard", "Easy Guard"]}


static func owns(p: Player) -> bool:
	var tree := SkillTree.style_tree(p.style())
	return tree != "" and p.progression.has_flag("guard2_" + tree)


## The mastered guard is up with the weapon in hand.
static func on(p: Player) -> bool:
	return owns(p) and p.progression.guards.has(SkillTree.style_tree(p.style()))


## A parry press (InputBuffer.pressed, game time): the second of two within TAP s switches the guard. True when it did.
static func tapped(p: Player, now: float) -> bool:
	if not owns(p) or not p.armed or now - p.parry_tap > TAP:
		p.parry_tap = now
		return false
	p.parry_tap = -10.0
	toggle(p)
	return true


static func toggle(p: Player) -> void:
	var tree := SkillTree.style_tree(p.style())
	var g: Dictionary = p.progression.guards
	if g.has(tree):
		g.erase(tree)
	else:
		g[tree] = true
	p.body_model.guard2 = on(p)
	p.call("_toast", NAMES[tree][1 if g.has(tree) else 0])
	p.get_node("/root/Net").fx("sfx", ["whoosh", p.global_position + Vector3(0, 1.1, 0), -10.0, 0.08, 1.3])
	p.squash(-1.0)
