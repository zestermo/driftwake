class_name FruitForms
extends RefCounted
## A Driftfruit power's form (1.27, docs/v1_27_raids_fruits_plan.md "Decided: the Driftfruit rework"): every power
## grows by being used, gated by its fruit's mastery:
## - ACTIVE (1): on the fruit's bar, a press, energy and a cooldown;
## - REFLEX (2): it also fires by itself when its moment comes (REFLEX_USES uses of that power, fruit mastery REFLEX_LV);
## - NATURE (3): always on, part of you (NATURE_USES uses, mastery NATURE_LV); its bar slot frees up.
## Uses are Progression's own count (note_use on every cast: saved, per captain); mastery is the fruit tree's.
## Awakened (the fruit's awakening, a 30 s buff): every power of the fruit is at NATURE while it lasts.
## What each form does is each fruit's own (its kit); this is only which form a power is in.

enum {ACTIVE = 1, REFLEX = 2, NATURE = 3}

const REFLEX_USES := 150
const REFLEX_LV := 12
const NATURE_USES := 400
const NATURE_LV := 24
const NAMES := {ACTIVE: "Active", REFLEX: "Reflex", NATURE: "Nature"}


## The form of power `skill_id` (of fruit `fruit_id`) for this captain's progression.
static func form(pr, skill_id: String, fruit_id: String) -> int:
	# (awakened, mastery 30: every power of that fruit at its Nature while it lasts)
	var pl = pr.get("player") if pr is Object else null
	if pl and is_instance_valid(pl) and pl.power and str(pl.power.fruit) == fruit_id and pl.power.buff("awakened"):
		return NATURE
	var n := int(pr.uses_of(skill_id))
	var lv := int((pr.mastery.get(fruit_id, {"lv": 1}) as Dictionary).get("lv", 1))
	if n >= NATURE_USES and lv >= NATURE_LV:
		return NATURE
	if n >= REFLEX_USES and lv >= REFLEX_LV:
		return REFLEX
	return ACTIVE


## What's left before the next form ("" at Nature): uses and mastery, for the skill map's tooltip.
static func next_step(pr, skill_id: String, fruit_id: String) -> String:
	var f := form(pr, skill_id, fruit_id)
	if f == NATURE:
		return ""
	var want_uses := REFLEX_USES if f == ACTIVE else NATURE_USES
	var want_lv := REFLEX_LV if f == ACTIVE else NATURE_LV
	var n := int(pr.uses_of(skill_id))
	var lv := int((pr.mastery.get(fruit_id, {"lv": 1}) as Dictionary).get("lv", 1))
	var parts: Array = []
	if n < want_uses:
		parts.append("%d more uses" % (want_uses - n))
	if lv < want_lv:
		parts.append("mastery %d" % want_lv)
	return "%s: %s" % [NAMES[f + 1], ", ".join(parts)]
