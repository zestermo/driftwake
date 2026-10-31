class_name Workbench
extends Node3D
## A workbench where gadgets are built, upgraded and refilled (1.28, docs/v1_28_plan.md "Gadgets and tinkering").
## CONTRACT (lead, 2026-10-31): the gadgets agent owns this file (its model, interaction and UI). Places that have one
## (the ship, camps, the volcanic isle's forge town) only call:
##   Workbench.place(parent: Node3D, at: Vector3, yaw: float, opts := {}) -> Workbench
## (`at` in parent's local space; opts may carry "style" for the place's look, e.g. "forge").


static func place(parent: Node3D, at: Vector3, yaw: float, opts := {}) -> Workbench:
	var w := Workbench.new()
	w.name = "Workbench"
	w.set_meta("opts", opts)
	parent.add_child(w)
	w.position = at
	w.rotation.y = yaw
	return w
