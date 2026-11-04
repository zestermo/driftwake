extends SceneTree
## Every vendor trade has its own sign (VendorMarks.SIGNS) that resolves to a texture: each trade of Shops' stalls, the
## trades the villages, artisans, libraries, merchant ships and canal/capital vendors give their shops, and the services.
const TK := preload("res://tools/dev/test_kit.gd")
const VM := preload("res://scripts/ui/vendor_marks.gd")
const SHOPS := preload("res://scripts/game/shops.gd")
## trades set where a shop is made at run time (Shops.extra: artisans, libraries, merchant ships, restaurants, villages)
const MADE := ["artisan", "books", "merchant", "cook", "grocer", "treasure", "smith", "tailor", "luthier"]
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var trades := {}
	for id in SHOPS.SHOPS:
		trades[str(SHOPS.SHOPS[id].get("trade", ""))] = id
	for t in MADE:
		trades[t] = "made"
	for s in VM.SERVICES:
		trades[str(s[1]).substr(1)] = str(s[1])
	for t in trades:
		check("trade '%s' (%s) has its own sign" % [t, trades[t]], VM.SIGNS.has(t))
		check("trade '%s' resolves to an icon" % t, VM.sign_for(t) != null)
	return TK.done(fails)
