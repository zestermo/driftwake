extends Crab
## Coconut crabs (the coral atoll's): the shore crab's brain - claws up and clacking, then the lunging pinch, its shell
## turning blows from the front, flipped by a heavy one - in a crab the size of a dog that lives up on the islets under
## the palms, violet-blue and rust, slow and very strong. Its meat is the best on the atoll, and it drops the nuts it
## was carrying.


func _setup(args: Dictionary) -> void:
	args = args.duplicate()
	args["morph"] = 1
	super._setup(args)
	kind = "coconut_crab"
	size_k = 1.4 if not giant else 2.0
	max_hp = 70.0 * (2.2 if giant else 1.0)
	xp = 90 if giant else 40
	coins = Vector2i(1, 4)
	drops = [["crab_meat", 0.95, 2], ["coconut", 0.45, 1]]
