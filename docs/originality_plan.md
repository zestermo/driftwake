# Driftwake's own names (Zach, 2026-10-19): the originality pass for 1.20

## Why
Driftwake started as a One Piece fan game. To ever sell it (Steam), the coined names and signature systems
taken from One Piece have to become Driftwake's own. Genre ideas stay: pirates, sailing a chain of islands,
fruit that grants powers, bounties, swords + guns, shonen fights. What goes: One Piece's coined terms, its
signature naming sets, and any wording that says "One Piece" in the game, the site or the README.
Get a short consult with a games/IP lawyer before charging money (and check the name "Driftwake" itself).

## Rules for the pass
- **Display text only.** Skill names and descriptions, the skill map, HUD banners and toasts, the controls list,
  dialogue JSON, the sea chart, item names, the website and README. **Internal ids stay** (`conquerors_haki`,
  `sea_king_fist`, `log_pose.gd`, `devil_fruits.gd`, fruit `type` values): saves and co-op carry those ids, so
  keeping them means no save migration. Renaming ids is optional tidying for later, with a `settings.gd` migration.
- **New content from now on uses the new names**, so 1.19's Marines and the 1.22 strongholds are written with
  them from the start instead of renamed afterwards.
- **Check borrowed rules, not just names.** Example: if fruit users can't swim, that is One Piece's rule; give
  Driftwake's fruits a cost of their own. **Decided (Zach, 2026-10-24): the sea rule stays** (Driftfruit users sink and
  drown in deep water); offered and turned down: a salt-water penalty, a Drift meter, a reserved bar slot.
- Comments in code can keep the old words for now; they don't ship to players.

## The names (bold = picked, others are the alternatives)

### Powers
| Now | New | Alternatives | Note |
|---|---|---|---|
| Devil Fruit | **Driftfruit** | Brinefruit, Deepfruit | Washed up from the deep; ties to the game's name |
| Logia / Zoan / Paramecia | **Flux / Feral / Knack** | Element / Beast / Gift | Become a substance / become a beast / a strange talent |
| Haki (umbrella) | **Will** | Mettle, Grit | |
| Armament Haki, "Armament: Coat" | **Iron Will**, "Iron Will: Coat" | | |
| Observation Haki | **Weather Eye** | | Sailing idiom for staying watchful |
| Conqueror's Haki | **Captain's Will** | Sovereign Roar | |
| Ryuo | **Outflow** | Breaking Wave | |
| Future Sight | keep | | Generic phrase |

### Techniques
| Now | New | Alternatives |
|---|---|---|
| Soru | **Squall Step** | Gale Step |
| Tekkai | **Ballast** | Ironhide (Walking Iron can stay) |
| Fire Fist | **Cinder Fist** | Flare Knuckle |
| Sea King Fist | **Leviathan Fist** | Deepwater Fist |

The other skill names (Thousand Petals, Hundred Fists, Kraken's Wake, Tempest of Steel...) are generic and stay.

### World
| Now | New | Alternatives | Example line |
|---|---|---|---|
| Sea King | **Leviathan** | the Drowned King, the Maw | "here be a Leviathan" |
| Log Pose | **Lodestone** | Tide Needle, Wake Needle | "The lodestone has set. Its needle points on, past this island." |
| Marines | **the Admiralty** | Tidewardens, the Navy | "Retired Admiralty man, twenty years." |

### Still to name (planned content)
- The strongholds plan's Warlords / Emperors (the "Seven Warlords" / "Four Emperors" structure is One Piece's),
  Enies Lobby as a reference, and any Marine ranks beyond generic naval ones (Admiral is fine as a word).
- "Grand Line", "New World", "East Blue" if they ever appear: the First Sea is already Driftwake's own.

## Going back over the past (Zach, 2026-10-19)
Rename the One Piece material in everything already published too, so that by the time Driftwake goes on Steam
the public paper trail reads as an original game. Rewrite the wording, don't delete the history: each old
version keeps its post and its notes, just in the new names (and without "One Piece-inspired" framing).
- **The website** (`web/site/`): the front page, the roadmap page, the releases page, and every news post
  (`news/v1-10-the-living-isles`, `v1-14-smooth-sailing`, `v1-16-sand-and-snow`, `v1-17-timber-and-tide`, and the
  news index). 10 published files had matches on 2026-10-19. Old screenshots or clips that show a renamed term
  on screen (a "Devil Fruit" banner, the skill map) get retaken or dropped.
- **GitHub releases** v1.8 to v1.17: edit each release's notes (`gh release edit vX --notes-file ...`) to the
  new names. The tags and their builds stay; only the notes text changes.
- **README.md** and `documentation/gdd.html`.
- **Release notes in the repo** (`docs/release_v1_17.md` and any others) and the in-game "what's new" text, if any.
- **What can't be cleaned this way:** the repo is **public**, so old commit messages, old file contents and the
  `docs/*_plan.md` history stay readable on GitHub, and web archives may hold old copies of the site. Rewriting
  git history isn't worth it (force pushes, broken tags, every worktree). The practical fix is to **make the repo
  private before the Steam page goes up** (or keep developing in a private repo and publish only builds). Decide
  that before the store page; see "Still to name" for the rest.
- Internal docs (`docs/dev_notes.md`, the plans, skills, CLAUDE.md) can keep the old words where they describe
  the past; new writing uses the new names.

## Where the text lives (from a 2026-10-19 search)
`scripts/progression/skills.gd`, `skill_tree.gd`, `scripts/powers/devil_fruits.gd`, `scripts/ui/game_menu.gd`
(controls list, toasts), `scripts/ui/sea_chart.gd`, `scripts/game/game_manager.gd` (log pose banners),
`scripts/world/sea_legs.gd` (lines), `data/dialogue/*.json` (gus, nessa, odile, tackett, vey), `resources/items/*_fruit.tres`,
`README.md`, `web/site/**`, `documentation/gdd.html`. About 510 matches in 110 files, many of them comments.
A fixer can do it in one piece; tests that check those strings (grep the tests for the old names) change with it.
