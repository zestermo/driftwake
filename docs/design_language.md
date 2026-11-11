# Driftwake design language

A brief for anyone (a person, an image model, a coding model, an asset tool) making art for Driftwake:
icons, UI, textures, models, effects, key art, store or site imagery. Every colour and size here is
taken from the game's own code (2026-11-11), so work made to this document matches what is on screen.

**How to use it.** Read sections 1-4 whatever you are making. Then read the section for your asset
type (5 3D, 6 characters, 7 UI, 8 icons, 9 effects, 10 key art). Section 11 is the checklist to hold
the result against, section 12 has prompt text to paste, section 13 the machine-readable tokens.

---

## 1. The game in one paragraph

Driftwake is a pirate action RPG with a PlayStation 1 look, for one to four players in co-op. You wake
on the sand of Brinehollow, a sleepy fishing island, make a captain, earn a cutlass and a sloop, and
follow the lodestone down a chain of islands: past pirate fleets, the Admiralty, reefs, whirlpools,
storms and very large things in the deep. Fights are fast and readable in the manner of shonen
adventure anime: blades, guns, fists and kicks, strange fruit that grants powers, and Will. Tagline:
*The sea remembers every wake.*

**Tone:** adventurous, warm, a little whimsical. Bright tropical days, gold sunsets, lantern-lit
nights. Danger is real (storms, sea monsters, boss fights) but the world is a storybook, not grimdark.
Characters are confident and expressive; the big moments are big.

## 2. Five rules everything follows

1. **Readable first.** One clear subject, a strong silhouette, big shapes. If it does not read at the
   size it ships at (a 32 px icon, a figure 40 px tall on screen), it is wrong however good the detail.
2. **Hard edges, stepped light.** Light comes in steps: a lit side and a shadow side, never a smooth
   gradient, never blur, never soft glow, never airbrush. Glowing things are hard bands, brightest at
   the core.
3. **Ink.** Dark outlines round shapes and between overlapping parts (near-black in 2D, warm dark brown
   on 3D silhouettes).
4. **PS1 means the real thing.** Low resolution, chunky pixels, few polygons, small textures, ordered
   dither, 15-bit colour. Not a retro filter over modern art, and not 16-bit console sprite art either.
5. **Shonen energy, not cartoon.** Punchy poses, speed lines, impact bursts, signature attacks with a
   colour identity. Not goofy, not rubber-hose, not chibi, not arcade neon.

## 3. World, themes and what to draw

### Setting
An age-of-sail archipelago: wooden ships, rope, canvas, brass, lanterns, black powder. Fantasy enters
through the sea (monsters, ghost ships, drowned sailors), through Driftfruit (strange fruit washed up
from the deep that grants one power each) and through Will (a fighter's spirit made visible). No
modern technology, no magic schools, no elves or dwarves, no science fiction.

### Places
| Place | Look |
|---|---|
| Brinehollow (the starting island) | A fishing village: harbour and quay, a lighthouse, tavern, market, plank houses, nets, crates and barrels, notice boards, lantern posts |
| Forest, jungle islands | Tall trees, undergrowth, ruins, beast dens; green and gold light |
| Desert islands | Dunes, wells, date palms, sandstone, awnings, night lamps |
| Snow islands | Pines, ice, frost beasts, pale blue shadow |
| Fog islands | Grey murk, lanterns, wrecks, ghosts |
| Atolls | A ring of reef round a turquoise lagoon, stilt huts, pearl divers, canoes |
| Volcanic islands | Black rock, ember light, smoke |
| The capital, the canal city | Stone halls, a cathedral and bell tower, gardens, canals, crowds |
| Strongholds, Admiralty outposts | Forts with walls, towers, alarm bells, garrisons, cannon |
| The sea | Rolling graded swell, foam caps, turquoise shoals near land, whirlpools, storms with lightning, wrecks |

### People and creatures
- **Captains (players) and crews:** pirates in the romantic sense: coats, sashes, bandoliers, hats.
- **Townsfolk:** fishers, shipwrights, tavern keepers, traders, pearl divers, water-sellers.
- **Pirate crews:** grunts, bosses, rival captains with their own ships and personalities.
- **The Admiralty:** the navy that hunts pirates; uniforms, outposts, warships.
- **Beasts:** giant boar, bear, croc, basilisk, scorpion, hyena, mantis queen, jungle ape, treant,
  ice golem, dune strider, hermit crab, shore bugs and their brood queen. Each is a boss-sized animal
  with parts that break.
- **The deep:** a sea serpent the size of a ship, a leviathan, an abyssal angler, storm eels.
- **The dead:** ghosts, a ghost captain, the drowned.

### What a player does (subjects for imagery)
Sailing and steering the sloop; raising sails, dropping anchor, firing broadsides; patching holes,
pumping water and fighting fires on deck; boarding enemy ships; climbing rigging and the crow's nest;
sword duels, gunfights, kicks and brawls; signature techniques and ultimates; eating a Driftfruit;
collecting bounties and wanted posters; cooking in the galley, fishing, diving; treasure chests and
maps; four friends on one deck.

### Weapons (each has its own skill tree and colour, see 4.3)
Cutlass, katana, boarding axe, twin axes, dagger, twin daggers, spear / polearm, warhammer,
greatsword, rapier, fighting staff, chain sickle, cutlass + pistol (corsair), pistol, musket / long
gun, hand cannon, slingshot, bare fists, kicks (Black Leg).

**A weapon must look like itself.** A katana is curved, single-edged, with a slanted tip, a round
guard (tsuba), a wrapped grip with a flat cap and a curved lacquer sheath; it is never a straight
cross-guarded knight's sword. A cutlass is short, broad and curved with a cup or basket guard. A
rapier is thin and straight with a swept hilt. Firearms are flintlocks.

### Powers
- **Driftfruit** (10 so far): Ember, Storm, Gust (**Flux**: the eater becomes a substance); Wolf,
  Bear (**Feral**: becomes a beast, with a half-beast form); Vine, Clockwork, Echo, Bubble, Iron
  (**Knack**: a strange talent). A fruit is a round, odd fruit in its power's colour. Fruit eaters
  sink in deep water.
- **Will:** crimson and black. **Iron Will** coats a fist or blade dark; **Weather Eye** senses
  what is coming; **Captain's Will** is a pressure wave that drops the weak.

### Names and originality (important)
Driftwake is its own world. It is inspired by shonen pirate adventures as a genre and must never
copy one. **Never** use or imitate the characters, symbols, flags, hats, logos, coined terms or
signature designs of One Piece or any other existing series or game. Use Driftwake's names: Driftfruit
(not "devil fruit"), Flux / Feral / Knack, Will, Iron Will, Weather Eye, Captain's Will, the
Admiralty (not "marines"), the lodestone (the compass that points down the chain). No real brands,
no real flags, no real people.

## 4. Colour

### 4.1 Interface palette (menus, HUD, site)
| Role | Hex | Notes |
|---|---|---|
| Cream (text) | `#F5E8C8` | Body text on dark panels; dim text `#DACCA8` |
| Gilt / sun (accent, borders, owned, selected) | `#F2C45E` | Highlight `#FFE9A3`, low `#D9A640`, dim border `#B88A3A` |
| Teal light (highlights, passives) | `#65C9C0` | |
| Teal | `#277F89` | |
| Slate panel | `#1D5E66` | Dark `#143F46`, light `#22707A`; gradient ends `#1F6068` to `#0E2C32` |
| Coral (danger, bridges, ribbons) | `#F17C62` | Ribbon `#E0644F` / `#B5402F`; danger text `#FFB39E` |
| Good (gains, stat steps) | `#9BE08A` | |
| Disabled | `#3C5C5F` | Rim `#5E7470`, text `#93A8A3` |
| UI outline | `#0C2427` | Text outlines and dark wells |
| Wood | `#694627` | Light `#86603B`, dark `#4C311A`, wood ink `#2B1A0C` |
| Rope | `#E3C487` | Shadow `#A8823F` |
| Parchment | `#F3E6C4` | Rim `#D9B77A`, burnt edge `#7A4A1E`, ink on paper `#2B1A0C`, dim `#6B5A44` |
| Wax seal | `#D0453A` | Shadow `#9A2E24` |
| Star twinkle | `#FFF3C9` | |

The interface is teal slate and warm gold on a night sky: cool ground, warm accents. Never grey
chrome, never pure black panels, never neon.

### 4.2 Material ramps for 2D art
Every material is five steps: **dark, shadow, base, light, glint**. A shape uses base, one shadow
step and one light step; dark is for holes and deep folds; glint is the one-pixel catch-light.

| Material | dark | shadow | base | light | glint |
|---|---|---|---|---|---|
| Ink (outlines) | `#0E0C14` | | | | |
| Steel | `#27304F` | `#5A6890` | `#9AA8C6` | `#D6DFEE` | `#FFFFFF` |
| Iron | `#16141C` | `#2C2A3A` | `#4A4860` | `#74728C` | `#A8A6C0` |
| Gold / brass | `#57300F` | `#A8661C` | `#E2A22E` | `#F8D660` | `#FFF6C4` |
| Wood | `#301A12` | `#5A321E` | `#8A5630` | `#B88248` | `#D8AA70` |
| Leather | `#1E1210` | `#3C221A` | `#5E3826` | `#845238` | `#A87050` |
| Skin | `#673530` | `#B06A50` | `#E09A78` | `#F6C4A0` | `#FFE2C6` |
| Red cloth | `#5A1418` | `#921F22` | `#C83A2E` | `#EE6C4C` | `#FFA080` |
| Stone | `#282427` | `#4D4743` | `#7A7065` | `#AB9E8C` | `#D6CAB6` |
| Bone | `#5A4A3A` | `#A8987C` | `#E8DCC0` | `#FBF4E0` | `#FFFFFF` |
| Smoke | `#2A2A34` | `#55566A` | `#8A8C9E` | `#BDBFCC` | `#E8E9F0` |
| Water | `#0C2A52` | `#1858A0` | `#2E96D8` | `#86D8F4` | `#E8FBFF` |
| Wind | `#123676` | `#2874D6` | `#68BDFF` | `#C4EEFF` | `#FFFFFF` |
| Fire | `#7C1510` | `#C9331A` | `#F17C1C` | `#FFC93A` | `#FFF4B4` |
| Spark | `#7C3A10` | `#D8781C` | `#FFC93A` | `#FFF0A0` | `#FFFFFF` |
| Lightning | `#5A4A08` | `#C8A010` | `#FFE652` | `#FFF8B0` | `#FFFFFF` |
| Ice | `#1B3572` | `#3A70C2` | `#78B9EE` | `#C2ECFF` | `#FFFFFF` |
| Leaf | `#0F331C` | `#1C6229` | `#3A9A38` | `#86CC48` | `#D8F288` |
| Venom | `#1D5A12` | `#3FA01E` | `#8FDC2C` | `#DCFF6A` | `#FBFFD0` |
| Blood / crimson | `#3A0612` | `#8A1030` | `#E0244E` | `#FF8AA0` | `#FFE0E6` |
| Petal | `#5A1840` | `#C04A88` | `#FF8CC0` | `#FFD0E4` | `#FFFFFF` |
| Moonlight | `#2A2A6A` | `#6A78D8` | `#AEBCFF` | `#E4EAFF` | `#FFFFFF` |

Shadows shift cool and dark, lights shift warm and pale: never the base colour plus black or white.

### 4.3 Each fighting style's colour identity
Each style owns a colour and an element. Its icons sit on a plate of the deep colour with the bright
colour as the frame line; its effects are edged in the bright colour with a near-white core. Do not
swap or blend identities.

| Style | Element and look | Deep | Bright |
|---|---|---|---|
| Cutlass | Sea spray: blue and white water, foam rings | `#123262` | `#4DB8FF` |
| Katana | Pale steel, moonlight, pink petals, afterimages | `#3A1C48` | `#FF9ECC` |
| Axe | Ember orange, rock, dust, sparks, cracks | `#4A1C0A` | `#FF8026` |
| Twin axes | Frost: white rime, pale ice blue, glacier blue | `#14285C` | `#AEE6FF` |
| Dagger | Crimson night: crimson edge, wine-dark shadow, black wisps | `#3A0C22` | `#F22660` |
| Twin daggers | Venom: viper green, yellow-green, bubbling poison | `#163A10` | `#72F24C` |
| Dual wield | Twin colours crossing: cyan and violet, X shapes | `#0F3A44` | `#5AE6F2` |
| Polearm | Storm: lemon-white lightning, violet afterglow | `#2A2058` | `#FFE652` |
| Hammer | Earth: sandstone shockwaves, thrown rock, stone spikes | `#3A3026` | `#EBCC94` |
| Greatsword | Gale: white air pressure, pale jade wind crescents | `#0F3A30` | `#BCFFE0` |
| Rapier | Quicksilver: silver afterimages, mirror flashes | `#2A3344` | `#C8D6EA` |
| Fighting staff | Leaves and wind: spring green, autumn gold | `#2C3A12` | `#C8E04A` |
| Chain sickle | Ghost-light sea green | `#0E2E36` | `#8AFFD0` |
| Corsair (cutlass + pistol) | Black powder: scarlet flash, gold sparks, dark smoke | `#4A1210` | `#FF5742` |
| Pistol | Gold muzzle flash, grey powder smoke | `#3E2C10` | `#FFBF40` |
| Long gun | Starlight: silver-white shots, moon blue, indigo | `#1C1E5A` | `#B8D6FF` |
| Cannon | Brimstone: sulphur yellow, violet smoke, shrapnel | `#3A1A58` | `#FFCC38` |
| Slingshot | The trickster's spark: hot pink, tangerine | `#4A1236` | `#FF61B8` |
| Unarmed | White wind, warm dust, rings of air | `#5A3A1A` | `#FFF2D9` |
| Black Leg (kicks) | Heat: white-hot core, cherry red, crimson flame | `#4A0C12` | `#FF2C29` |
| General skills | Teal | `#1A343C` | `#65C9C0` |
| Perks | Night blue and gold | `#22263E` | `#F2C94C` |
| Will | Crimson and black: dark rings, red sparks | | |

Driftfruit colours: Ember `#FF8026`, Storm `#8CB8FF`, Gust `#B3F2BF`, Wolf `#BFAD8C`, Bear `#8C6647`,
Vine `#73D94D`, Clockwork `#D9B359`, Echo `#8CBFD9`, Bubble `#BFE6FF`, Iron `#9499A3`.

### 4.4 Item rarity
Common `#EBEBE6`, Uncommon `#66E061`, Rare `#5999FF`, Epic `#B866FA`, Legendary `#FFD138`,
Ultra `#FF3833`, Supreme `#0A0A0D` (black).

### 4.5 Sky and sea
| Time | Sky top | Horizon | Light |
|---|---|---|---|
| Night | `#03050F` | `#121A33` | Moonlight `#8CA8FF`, dim |
| Dawn | `#293D80` | `#E6946B` | Sun `#FF8C52` |
| Day | `#2666D1` | `#80B8EB` | Sun `#FFEBC7`, strong |
| Sunset | `#242B6B` | `#F28052` | Sun `#FF7340` |
| Storm | grey `#5C616B` over everything | | Flat, cold `#BFCCE6` |

Sea: deep `#0D294D`, facing the sky `#338099`, foam `#E6F2FF`, turquoise shoals near land `#29B8A8`,
lagoon `#1A99C7`; underwater `#217378` shallow to `#051F33` deep. Daylight is warm on the lit side
and blue in shadow; night is blue with warm lamp pools.

## 5. The 3D look (models, textures, screenshots)

- **Picture:** drawn on a 960 x 540 pixel grid and scaled up with hard pixels (2x at 1080p). 15-bit
  colour (32 levels a channel) with a 4x4 ordered dither. Vertices snap to the pixel grid, so
  geometry wobbles slightly, and textures warp a little the PS1 way.
- **Light:** cel shading in two steps (lit / shadow) whose boundary is the same 4x4 dither pattern,
  not a smooth line. Lit side slightly warm, shadow side blue and much darker. Lamps keep a soft pool.
- **Ink:** warm dark-brown (`#29140D`) one-cell outlines round silhouettes, fading with distance.
- **Models:** low polygon, **flat shaded** (hard facets, no smooth-shaded blobs), built from boxes,
  cylinders, lofts and lathes. Shape carries the design: chunky planks, thick rope, oversized nails
  and hinges, bold roof lines. Shading that is not from the light goes in vertex colour (darker
  undersides and bases), not in extra textures.
- **Textures:** 64 x 64 pixels, tileable, drawn from a small palette (a ramp of 4-8 colours),
  sampled with hard pixels. Wood planks, stone blocks, thatch, canvas, sand, grass. No photo
  textures, no normal maps, no gloss or metal maps, no baked soft shadows.
- **Do not make:** smooth high-poly meshes, PBR materials, bloom, depth of field, lens flare, motion
  blur, anti-aliased edges, soft shadows, realistic water.

## 6. Characters

- **Proportions:** about six heads tall. A large expressive head, long legs, a strong V-taper
  (broad shoulders, narrow waist), hands and feet slightly oversized. Builds: slim, average, broad,
  stout; masculine and feminine bodies. Never chibi, never realistic.
- **Faces:** a flat painted anime face on a simple head: big eyes with a clear iris colour, bold
  brows, a simple mouth, a small nose. Scars, marks, eyepatches, earrings.
- **Hair:** chunky locks and spikes in clear shapes; ponytails and braids that swing. Any colour,
  two-tone allowed.
- **Clothes:** a shirt or top, a vest, a long coat with coloured trim (a captain may wear it draped
  over the shoulders; also jackets, greatcoats, frock coats, a haori), trousers, breeches, shorts,
  a skirt or hakama, tall boots, shoes, sandals or bare feet, a sash and belt. Hats: tricorn,
  bicorne, cavalier hat, bandana, cap, hood, turban. Extras: scarf, cape, cloak or mantle, a
  shoulder guard, bandolier, baldric, gloves, bracers, arm wraps, goggles, spyglass, pouch,
  necklace. Patterns: stripes, check, brocade, patches.
- **Poses:** weight and intent: a wide stance, a hand on the hilt, a coat thrown back by wind.
  Attacks show wind-up, a long clear arc, and follow-through.

## 7. Interface

**The look is a whimsical storybook:** slate panels in a rope border with brass nails; wooden plank
buttons that turn gilt when hovered; parchment pages with burnt rims; swallowtail ribbons for
headings; rope rules with a gold star; wooden keycaps for button hints; wax seals; a starry night
sky behind full-screen menus.

- **Canvas:** 960 x 540 pixels, shown at whole-number scales (2x at 1080p, 4x at 4K). Design at
  960 x 540 and judge at 1920 x 1080. Everything sits on whole pixels.
- **Fonts:** Pixelify Sans 12 px for body text (16 where it must be larger); Silkscreen 8 px
  capitals for labels and key hints; Jacquarda Bastarda 9 (a pixel blackletter) for titles at 9, 18
  or 27 px, filled gilt with a dark wood outline and a dark coral drop shadow. Text on dark panels
  is cream with a dark outline; text on parchment is dark brown.
- **Shapes:** small corner radii (2-6 px), 1-3 px rims, a one-step bevel (raised or sunk). No
  gradients except a panel's two-tone slate. No drop shadows wider than a pixel or two, no glass,
  no blur, no thin hairline vector strokes.
- **States:** yours / selected: gilt rim, full colour. Available: pulsing gilt. Not yet reachable:
  dulled picture, thin dull rim. Locked: dark picture, dashed rim, the level it opens at. Danger:
  coral. Gains: green.

## 8. Icons

### 8.1 Skill icons: "ink and cel" (the settled style)
Sizes: **16, 32 and 48 px**, each drawn for its size (never a larger one shrunk). Square, opaque.

**Construction, back to front:**
1. **Plate:** fills the tile. An impact burst of 18 alternating rays in the style's deep colour
   (one ray slightly lighter than the next), centred a little left of and below the middle.
2. **Subject:** flat-coloured parts from the material ramps. Each part has its base colour, **one
   hard shadow band along its lower right** (about 7% of the tile wide), and a **one-pixel light
   edge up and left** (the glint step on metal). Light always comes from the upper left.
3. **Ink:** a one-pixel near-black (`#0E0C14`) line round every part and wherever two parts overlap.
4. **Glow** (wind, fire, water, lightning, energy): no ink; three hard bands, darkest outside,
   brightest at the core.
5. **Frame, over the art:** a one-pixel ink edge, then a one-pixel inner line in the style's bright
   colour (dimmer along the bottom and right). An **ultimate** has a gold frame (`#F8D660` line,
   `#7A4C14` edge). The subject may run off the tile under the frame.

**Composition:**
- One idea per icon: the move's signature moment, not an inventory picture of the weapon.
- The whole weapon need not be shown. Close-ups are welcome: a hand on a hilt, a sheath cracked
  open on a sliver of blade, a boot heel coming down, a muzzle and its flash, an eye.
- Vary the set. In one tree use different subjects, distances and angles: a figure mid-leap, a
  weapon crop, a creature's head, a pure effect, a symbol. No tree should be eight pictures of
  the same object.
- Hands only as a fist seen knuckles-on or an open palm facing out. No side-view fists.
- A diagonal through the tile reads best; keep the subject large (60-90% of the tile).
- The 16 px version keeps the silhouette and the two main colours and drops inner detail.
- No text, letters, numbers or logos in an icon.

### 8.2 Item icons
24 x 24 px on a transparent ground: one object, three-quarter or side view, filling most of the
tile, in the same ramps with a dark outline. Food, ingredients, ores, cloth, beast parts, weapons,
Driftfruit (a round odd fruit in its colour), coins and pearls. New item art should follow 8.1's
shading (hard shadow lower right, light edge upper left, ink) without the plate and frame.

### 8.3 Other marks (guidance for new work)
Map and HUD markers: one flat colour with a dark outline, readable at 8-12 px. Posters, notices
and letters: parchment with a blackletter heading, dark brown ink, a wax seal or a gold figure.

## 9. Effects

- **Layers:** a near-white hot core, an edge in the style's bright colour, and an accent that is
  the element's material (spray, petals, embers, ice chips, leaves, smoke).
- **Drawn elements:** water, wind, fire and the like are drawn as animated sprite sheets in the
  manner of Japanese woodblock prints: flowing ribbons shaded in hard bands (foam, light, bright,
  mid, deep, a dark inner line), thin dashed flow lines running along them, foam hooks curling off
  the outer edge, hollow bubbles, and a tail that breaks into round gobs. Never noise-torn edges.
- **Sheets:** 4 x 4 frames of 128 px; alpha is fully on or off (hard pixel edges, no fades).
- **Shapes, not noise:** a few bold rings, crescents, streaks and star glints rather than a cloud
  of tiny particles. A basic move gets a clean accent; an ultimate gets one signature effect, a
  screen flash and a beat of slow motion.
- **Until a style's element is mastered** its effects are plain: white, steel and dust.

## 10. Key art, store and site imagery

Either real PS1-style renders (section 5) or illustration in the icon language scaled up: flat
cel colour, one hard shadow step, ink outlines, impact rays and speed lines. Compose like a
shonen volume cover: a captain in the foreground at a low angle, coat in the wind, the ship and
sea behind, the threat (a rival sail, a serpent's coil, a storm front) at the horizon. Skies are
the section 4.5 colours; the sunset version is the game's signature (the title screen is a ship
under sail at sunset). Logo and headings in the pixel blackletter, gilt on dark.

## 11. Checklist

**Do**
- Hard pixels on a whole-pixel grid; whole-number scaling only.
- Two or three light steps per material from the ramps; cool dark shadows, warm pale lights.
- Ink outlines; light from the upper left in 2D.
- The style's own deep and bright colours for anything tied to a weapon or power.
- Weapons drawn correctly for their kind; age-of-sail materials (wood, rope, canvas, brass, iron).
- Teal slate and gold for interface; parchment, rope and wood for chrome.

**Do not**
- Gradients, airbrush, blur, soft glow, bloom, lens flare, drop shadows, glass, bevel-and-emboss.
- Anti-aliased or half-transparent edges; mixed pixel sizes; rotated or non-integer-scaled pixels.
- Photorealism, PBR, smooth high-poly shapes, realistic faces.
- Chibi, rubber-hose cartoon, mobile-game gloss, neon arcade, grimdark, gore.
- 16-bit JRPG sprite style, isometric tiles, or voxel art.
- Anything from an existing series or game: characters, flags, hats, symbols, names, logos.
- Text inside icons; modern objects; magic circles and runes; sci-fi.

## 12. Prompt text

**Style block (paste first, then describe the subject):**
> Driftwake art style: an original age-of-sail pirate adventure with shonen anime energy and a
> PlayStation 1 look. Flat cel colours with one hard shadow step on the lower right and a thin
> light edge on the upper left, light from the upper left, near-black ink outlines round every
> shape, hard pixel edges, no gradients, no blur, no soft glow, no anti-aliasing. Warm gold
> (#F2C45E) and cream (#F5E8C8) accents on deep teal (#1D5E66, #143F46). Materials: steel
> blue-grey, brass gold, warm wood, rope, canvas, parchment. Glowing things as three hard bands
> with a near-white core. Readable silhouette, one clear subject.

**Skill icon:**
> [style block] A square skill icon, 32 x 32 pixel art shown enlarged with hard pixels. Background
> plate: a burst of 18 alternating rays in [deep hex]. Subject: [the move's signature moment],
> large, on a diagonal, may be cropped by the frame. Frame: one-pixel black edge with a one-pixel
> inner line in [bright hex] (gold #F8D660 for an ultimate). No text.

**Item icon:**
> [style block] A 24 x 24 pixel art item icon on a transparent background: [object], three-quarter
> view, filling the tile, dark outline, two to three shades per material. No text.

**Interface piece:**
> [style block] A storybook pirate game menu panel on a 960 x 540 pixel canvas: deep teal slate
> panel with a rope border and brass nails at the corners, wooden plank buttons, a red swallowtail
> ribbon heading in gold pixel blackletter, cream pixel text, a parchment page with a burnt rim.
> Chunky pixels, one-step bevels, no gradients.

**Texture:**
> [style block] A 64 x 64 pixel seamless tileable PS1 game texture of [material], 6-8 colours,
> hard pixels, no lighting baked in beyond plank or block edges.

**Key art:**
> [style block] Shonen-cover composition, low angle: a pirate captain about six heads tall with a
> large expressive head, long legs, broad shoulders, a long coat blown by wind and a hand on a
> [weapon] hilt, on the deck of a wooden sloop. [Time of day colours from 4.5]. Rolling sea with
> white foam caps, [threat] on the horizon. Impact rays and speed lines. Original characters only.

**Negative prompt (where the tool takes one):**
> gradient, airbrush, blur, soft glow, bloom, lens flare, photorealistic, 3d render, smooth
> shading, anti-aliasing, text, letters, watermark, logo, chibi, modern clothing, sci-fi,
> existing anime or game characters, flags or symbols from an existing series

**Working with image models.** Most cannot hold a true pixel grid. Generate large, then reduce
to the target size with nearest-neighbour sampling, snap the colours to the ramps in 4.2, and
redraw the one-pixel ink line and frame by hand or by script. For skill icons, the game's own
generator (`tools/texture_gen/gen_skill_icons.py`) is the reference implementation of 8.1: a
coding model should extend it rather than paint pixels.

## 13. Tokens

```yaml
canvas: {ui: [960, 540], scale: integer, min_display: [1920, 1080]}
render_3d: {grid: [960, 540], colour_bits: 15, dither: bayer4x4, shading: cel_2_step, ink: "#29140D"}
fonts: {body: "Pixelify Sans 12", label: "Silkscreen 8", title: "Jacquarda Bastarda 9 (9/18/27)"}
ui:
  cream: "#F5E8C8"
  text_dim: "#DACCA8"
  gilt: "#F2C45E"
  gilt_hi: "#FFE9A3"
  gilt_lo: "#D9A640"
  teal_light: "#65C9C0"
  teal: "#277F89"
  panel: "#1D5E66"
  panel_dark: "#143F46"
  panel_light: "#22707A"
  coral: "#F17C62"
  good: "#9BE08A"
  disabled: "#3C5C5F"
  outline: "#0C2427"
  wood: "#694627"
  wood_ink: "#2B1A0C"
  rope: "#E3C487"
  parchment: "#F3E6C4"
  wax: "#D0453A"
icon:
  sizes: [16, 32, 48]
  ink: "#0E0C14"
  light_from: upper_left
  shadow: {side: lower_right, width: 0.07}
  plate_rays: 18
  ult_frame: {line: "#F8D660", edge: "#7A4C14"}
item_icon: {size: 24, background: transparent}
texture: {size: 64, tileable: true, colours: "4-8 per ramp", filter: nearest}
fx_sheet: {frames: "4x4", frame_px: 128, alpha: binary}
rarity: ["#EBEBE6", "#66E061", "#5999FF", "#B866FA", "#FFD138", "#FF3833", "#0A0A0D"]
styles:   # [deep, bright]
  cutlass: ["#123262", "#4DB8FF"]
  katana: ["#3A1C48", "#FF9ECC"]
  axe: ["#4A1C0A", "#FF8026"]
  twin_axes: ["#14285C", "#AEE6FF"]
  dagger: ["#3A0C22", "#F22660"]
  twin_daggers: ["#163A10", "#72F24C"]
  dual_wield: ["#0F3A44", "#5AE6F2"]
  polearm: ["#2A2058", "#FFE652"]
  hammer: ["#3A3026", "#EBCC94"]
  greatsword: ["#0F3A30", "#BCFFE0"]
  rapier: ["#2A3344", "#C8D6EA"]
  staff: ["#2C3A12", "#C8E04A"]
  chain_sickle: ["#0E2E36", "#8AFFD0"]
  corsair: ["#4A1210", "#FF5742"]
  pistol: ["#3E2C10", "#FFBF40"]
  long_gun: ["#1C1E5A", "#B8D6FF"]
  cannon: ["#3A1A58", "#FFCC38"]
  slingshot: ["#4A1236", "#FF61B8"]
  unarmed: ["#5A3A1A", "#FFF2D9"]
  black_leg: ["#4A0C12", "#FF2C29"]
  general: ["#1A343C", "#65C9C0"]
  perk: ["#22263E", "#F2C94C"]
fruit: {ember: "#FF8026", storm: "#8CB8FF", gust: "#B3F2BF", wolf: "#BFAD8C", bear: "#8C6647",
  vine: "#73D94D", clockwork: "#D9B359", echo: "#8CBFD9", bubble: "#BFE6FF", iron: "#9499A3"}
sky:
  night: {top: "#03050F", horizon: "#121A33", light: "#8CA8FF"}
  dawn: {top: "#293D80", horizon: "#E6946B", light: "#FF8C52"}
  day: {top: "#2666D1", horizon: "#80B8EB", light: "#FFEBC7"}
  sunset: {top: "#242B6B", horizon: "#F28052", light: "#FF7340"}
sea: {deep: "#0D294D", surface: "#338099", foam: "#E6F2FF", shoal: "#29B8A8", lagoon: "#1A99C7"}
```

## 14. Reference images and sources

Give these to a tool that accepts reference images:
- `docs/media/design/skill_icons.png`: every skill icon at 32 px (the icon style, all colour identities).
- `docs/media/design/ui_chrome.png`: the interface pieces (parchment page with a wax seal, the rope-bordered
  slate panel, wooden and gilt plank buttons, ribbons, a plank bar with a rope rule).
- `docs/media/title.jpg`, `fight.jpg`, `village.jpg`, `sailing.jpg`, `outfits.jpg`: the game itself.

Where each rule lives in the code: interface colours `scripts/ui/ui_style.gd` and `ui_chrome.gd`;
icon ramps, plates and shading `tools/texture_gen/gen_skill_icons.py`; style colours
`scripts/game/fx.gd` (`TREE_FX`); sky `scripts/world/weather.gd`; sea `scenes/ocean/ocean.gdshader`;
the PS1 picture `scripts/psx/psx_settings.gd` and `shaders/psx/`; character proportions
`scripts/npc/body_builder.gd`; names `docs/originality_plan.md`.

**Settled and not:** the skill icon style (8.1) was picked on 2026-11-11 and all 188 skill icons
follow it. Item icons (8.2) are still the older, simpler 24 px drawings and are due the same pass.
The media screenshots predate some interface changes; where they disagree with this document, the
document wins.
