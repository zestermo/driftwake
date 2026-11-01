# Life systems (1.28): reading, cooking, fishing

The preview for docs/v1_28_plan.md "Reading, cooking, fishing" (decided 2026-10-31). Zach is away: these are first
guesses, built to as written, all numbers in one data file per system so retuning is a data edit:

| System | Data file | Logic |
|---|---|---|
| Books | `scripts/books/book_data.gd` (BookData) | `scripts/books/books.gd` (Books), `book_shelf.gd`, `scripts/ui/bookshelf_screen.gd` |
| Cooking | `scripts/items/food.gd` (Food: INGREDIENTS, MEALS, QUALITY) | `scripts/items/cook_timing.gd` (CookTiming), `scripts/ui/cook_game_screen.gd` |
| Fishing | `scripts/fishing/fish_table.gd` (FishTable: CATCHES, LEGENDS, PAGES) | `fish_fight.gd`, `fish_journal.gd`, `spear.gd`, `fish_contest.gd` |

Values are an item's base worth (G); shops price on the economy's curve (Economy), x1.6 a rarity tier.

## Books

A book is an item (loot, stack 5). Reading one, from the bag (click: READ) or with the wheel's Read aboard or at camp
(the first interval reads the first unread book you carry; with none, Read is the old XP-and-lore loop), teaches its one
thing, and the book goes on your shelf (Progression.downtime["books"], saved with the captain; each captain's own). A
second copy of a book already read is worth selling; a sea chart can be read again (it marks the waters ahead again).

### What each teaches

| Book | Kind | Teaches | Rarity | Worth |
|---|---|---|---|---|
| The Spice Merchant's Revenge | blueprint | Pepper Bomb (bp_pepper) | uncommon | 50 |
| Cliffs and How to Cheat Them | blueprint | Climbing Spike (bp_spike) | uncommon | 50 |
| Breathing Under the Sea | blueprint | Diving Helmet (bp_diving_helmet) | rare | 50 |
| The Lazy Angler's Workshop | blueprint | Auto-Reel (bp_auto_reel) | uncommon | 50 |
| On Wings of Canvas | blueprint | Pocket Glider (bp_glider) | rare | 50 |
| The Straw Captain | blueprint | Decoy (bp_decoy) | rare | 50 |
| Galley Secrets of the Southern Isles | recipe | Captain's Feast | uncommon | 40 |
| The Roasting Pit | recipe | Boar Roast Feast (crew feast) | uncommon | 40 |
| A Cook's Atlas | recipe | Feast of the Isles (crew feast) | rare | 40 |
| Deck Footwork | manual | +3% run speed, +3% sprint | rare | 70 |
| The Iron Grip | manual | +3% damage | rare | 70 |
| Pearl Diver's Breath | manual | +8% swim speed | uncommon | 70 |
| The Ship's Cook's Companion | manual | meals last +15% | uncommon | 70 |
| Notes of an Old Angler | manual | bites 10% sooner, reel window +10% | uncommon | 70 |
| Turning the Blade | manual | +2 defense | rare | 70 |
| Second Wind | manual | +10 max stamina | uncommon | 70 |
| A Trader's Sea Chart | chart | marks the next sea stop on the log pose's legs (2 layers ahead) | uncommon | 60 |
| The Whaler's Chart | chart | marks the Sea King's waters on the legs ahead | rare | 60 |
| The Salvager's Chart | chart | marks the wrecks on the legs ahead | uncommon | 60 |
| The Drowned King, I-IV | lore (4) | one volume each; the set: a Will point | rare | 30 |
| Voyages of Captain Orla, I-III | lore (3) | the set: 400 gold and the Feast of the Isles | uncommon | 30 |
| A Bestiary of the Deep, I-III | lore (3) | the set: +15% rare fish, for good | uncommon | 30 |

(19 single books and three lore sets of 10 volumes: 29 books.)

A chart with nothing left to mark ahead (no stop, king or wreck on the next two layers' legs) says so and pays 20 XP.
Marks go on the held map (MapMarks "x" with the stop's name, "spot" for kings and wrecks) and are re-put on load.

### Where books come from

| Source | What | Odds / stock |
|---|---|---|
| Chests (Loot.chest) | ordinary: recipe, chart, lore; hidden: + manual, blueprint; hoard: any | 4% / 10% / 25% a book, a volume you haven't read first |
| A village's old library (UniquePlaces "library") | "Browse the shelves": recipe, manual, chart, lore | 4 a day from the pool |
| The forge town's master tinkerer | "Any books?": blueprint books and Second Wind / The Iron Grip | 3 a day |
| The wandering merchant ship (MerchantShip.book_pool) | charts, manuals, blueprints | 2 a visit (its own roll) |
| F4 debug menu | any book; every book read | - |

### The bookshelf aboard

A shelf against the cabin's front wall (starboard of the door). Its rows fill with one spine per book read (each
kind its cover colour). "Browse the bookshelf" opens the collection: the five kinds as rows of spines, a read book
lit with its name and what it taught, an unread one "???"; the lore sets with their volumes (n/4) and their reward.
Each captain sees their own collection.

## Cooking

### Island dishes (12): each theme's own ingredient (in a recipe by item id)

A theme's ingredient is a staple at that island's village cookpot (always in stock) and in its grocer's pool. Dishes
are known from the start but can only be made with that ingredient. Stronger than a plain galley meal (a plain one is
~10-12 "points" of buff; these ~15-18) and slanted to the island.

| Theme | Ingredient (tag, worth) | Dish | Recipe | Buff | Min |
|---|---|---|---|---|---|
| jungle | Fire Chili (spice, 4) | Jungle Pepperpot | chili, meat, greens | +12% damage, +4% crit | 15 |
| jungle | | Reef-Fruit Ceviche | chili, fish, fruit | +20% swim, +8% run | 15 |
| snow | Frost Berries (fruit, 4) | Frostberry Pie | berries, 2 grain | +30 stamina, +25% stamina regen | 20 |
| snow | | Ice Cod Chowder | berries, fish, grain | +35 max hp, +5 defense | 20 |
| desert | Desert Dates (fruit, 4) | Date Bread | dates, grain, spice | +25 energy, +30% energy regen | 15 |
| desert | | Dune Skewers | dates, meat, spice | +10% damage, +8% sprint | 12 |
| forest | Black Truffle (greens, 5) | Truffle Risotto | truffle, grain, greens | +8% crit, +5% damage | 15 |
| forest | | Hunter's Stew | truffle, meat, grain | +30 max hp, +80% regen | 20 |
| fog | Ghost Lily (greens, 4) | Lily Broth | lily, fish, spice | +20 energy, +30% energy regen, +3 defense | 15 |
| fog | | Mist Dumplings | lily, grain, meat | +6 defense, +20 max hp | 15 |
| volcanic | Ember Salt (spice, 5) | Lava-Stone Grill | ember salt, meat, fish | +14% damage | 12 |
| volcanic | | Ember Curry | ember salt, greens, grain | +6% crit, +6% damage, +20% stamina regen | 15 |

### The timing game: quality sets the strength

Cook at the galley or a fire: Cook plays the game, Quick cook skips it (Fair). Three beats, each scored 0-1 by how
close the press lands to its mark (F, Space or a click):
1. **Stir** (3 presses): a spoon circles the pot (1.1 turns/s); press as it passes the glowing mark (full marks within
   12 deg, nothing past 60 deg).
2. **Flip**: the heat bar rises (0 to 1 in 1.6 s, then falls); press in the gold band (0.72-0.86; nothing below 0.4 or
   once it falls back past it).
3. **Plate**: the plate slides across (1.4 s a sweep, back and forth); press when it's centred under the dish (full
   within 6%, nothing past 35%).

Quality = the beats' mean (stir counts as one beat, its three presses averaged). Grade by quality:

| Grade | Quality | Strength (x the meal's buff and minutes) | The item |
|---|---|---|---|
| Burnt | < 0.35 | x0.8 | "<meal>@0", grey, "Burnt ..." |
| Fair | 0.35-0.65 (also Quick cook, shops) | x1.0 | the meal itself, green |
| Good | 0.65-0.88 | x1.15 | "<meal>@2", blue, "Good ..." |
| Perfect | >= 0.88 | x1.3 | "<meal>@3", purple, "Perfect ..." |

A Perfect first cook of a dish doubles its Cooking XP again (x4 the first time). **Reusable** for the floating
restaurant's cook-off: `GameMenu.open_cook_game(title, done: Callable(quality: float, grade: int), opts := {})`
(opts: "speed" x the beats' speed, "beats" a subset like ["stir", "plate"]); the logic alone is `CookTiming`.

### Crew feasts

A feast (MEALS "feast": true) is cooked aboard at the galley only, from a big recipe. Every captain aboard the ship
then gets its buff at once (Net.everyone("_all_feast")), each at the cook's strength (quality and perks), and the
feast's leftovers (the galley's portions - 1) go on the galley table as usual.

| Feast | Recipe | Buff | Min | Known |
|---|---|---|---|---|
| Harbour Feast | 3 fish, 2 grain, 2 greens, 1 spice | +30 max hp, +60% regen, +5% damage | 25 | from the start |
| Boar Roast Feast | 3 meat, 2 fruit, 2 grain, 2 spice | +8% damage, +25 stamina, +4 defense | 25 | The Roasting Pit |
| Feast of the Isles | 3 theme ingredients (any), 2 fish, 2 meat | +40 max hp, +10% damage, +5% crit, +5 defense | 30 | A Cook's Atlas / Orla's set |

## Fishing

### Fish per theme and the open sea (new catches; the old 21 stay)

| Fish | Rarity | Worth | Waters | Theme | Time |
|---|---|---|---|---|---|
| Flying Fish | common | 3 | sea, deep | open sea | day |
| Mahi-Mahi | rare | 9 | sea, deep | open sea | - |
| Jungle Tarpon | uncommon | 6 | shore, sea | jungle | - |
| Frost Char | uncommon | 6 | shore | snow | - |
| Sand Mullet | common | 3 | shore | desert | - |
| Speckled Char | uncommon | 6 | shore, sea | forest | - |
| Pale Smelt | common | 3 | shore, sea | fog | - |
| Gloom Perch | rare | 9 | sea | fog | night |
| Ash Goby | common | 3 | shore | volcanic | - |
| Ember Bass | rare | 9 | shore, sea | volcanic | - |
| Blue Tang | common | 3 | shore | coral | day |
| Coral Trout | uncommon | 6 | shore, sea | coral | - |
| Clown Wrasse | rare | 9 | shore | coral | - |

### One legendary per theme, with its own fight

| Legendary | Theme | Waters | Time | Worth | Pull (fight) |
|---|---|---|---|---|---|
| Jade Gar | jungle | shore, sea | - | 24 | 1.0 |
| Glacier Sturgeon | snow | sea, deep | - | 24 | 1.1 |
| Mirage Sailfish | desert | sea, deep | day | 24 | 1.15 |
| Elder Pike | forest | shore, sea | - | 24 | 1.0 |
| Lantern Wraith | fog | sea, deep | night | 26 | 1.2 |
| Cinder Koi | volcanic | shore, sea | - | 26 | 1.2 |
| Reef Emperor | coral | shore, sea | - | 28 | 1.25 |
| King Marlin / Abyss Eel | open sea | (as before) | | 22 | 1.3 |

Odds as any legendary (WEIGHT 0.6 x the rare odds); the coral atoll's pool is weighted x1.5 rare (the best spot).
**The fight** (FishFight) replaces the reel for a legendary: the line's tension (0-1) and the distance (16 m to 0).
Hold F (or the mouse) to reel: distance -2.2 m/s, tension +0.45/s x pull while the fish runs, +0.12/s while it rests;
let go: tension -0.6/s, the fish takes line back at 1.2 m/s x pull while running. It runs in surges (1.2-2.4 s, rests
0.8-1.8 s). Tension at 1 snaps the line; slack (tension 0) for 2.5 s throws the hook. Distance 0 lands it.

### The fish journal

J's journal gets a Fish page (GameMenu "fish_journal", also N's wheel "Fish journal"): every catch by theme page, each
with times caught, the biggest (each catch rolls a length x0.75-1.4 of its size) and where it was first caught (the
island's name, or "the open sea"). A page done (every fish on it caught) pays once: a reward per page.

| Page | Fish | Reward |
|---|---|---|
| Home waters | sardine, mackerel, bream, snapper, flounder, sea bass, tuna, swordfish, moonfish, ghost ray, golden carp, flying fish, mahi-mahi | steel-tipped rod + 150 gold |
| Jungle | parrotfish, lionfish, jungle tarpon, Jade Gar | 6 glow bait + 120 gold |
| Snow | ice cod, frost char, Glacier Sturgeon | 6 glow bait + 120 gold |
| Desert | sand grouper, sand mullet, Mirage Sailfish | 6 glow bait + 120 gold |
| Forest | sea trout, speckled char, Elder Pike | 6 glow bait + 120 gold |
| Fog | pale smelt, gloom perch, Lantern Wraith | 6 glow bait + 120 gold |
| Volcanic | ash goby, ember bass, Cinder Koi | 6 glow bait + 120 gold |
| Coral | blue tang, coral trout, clown wrasse, Reef Emperor | master's rod + 200 gold |
| Legends of the deep | King Marlin, Abyss Eel | "A Bestiary of the Deep, III" + 300 gold |

### Spearfishing

Diving (underwater, any depth over 2.5 m): a small school of the waters' fish swims round you (3-5 fish, from the same
pool as the rod off that coast, never a legendary). Right mouse aims (a slow-time aim line), left mouse throws the
spear (18 m/s, 9 m reach, 1.2 s to recover). A hit lands the fish (the journal records it, Fishing mastery as a rod
catch, no bait used). The spear is the diver's own: no item needed.

### Fishing contests in towns

A village's harbour (the cookpot keeper, "Fishing contest?") runs one a day: 3 minutes (game time), score = the
weight-points of what you land (a catch's worth x its length ratio). Three town anglers post scores (rolled 18-60 by
the island's tier); every captain in co-op who entered competes (their scores go to the crew by Net.event), and the
best wins:

| Place | Prize |
|---|---|
| 1st | 150 gold + 4 shrimp bait + a book from the contest's pool (a chart or Notes of an Old Angler) |
| 2nd | 70 gold + 3 shrimp bait |
| 3rd | 30 gold |

Entry 10 gold. Once a game day per town.
