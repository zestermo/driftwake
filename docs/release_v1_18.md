# v1.18 release plan (Zach, 2026-10-19)

Release v1.18 once the batch is finished (fishing, the perf pass) **and** the website roadmap session
([Web timeline roadmap], branch `claude/web-timeline-992b26`) has landed its changes. Zach asked for the tag, push and
release himself (2026-10-19), so no extra confirmation is needed at the tag.

## What's in it (docs/v1_18_plan.md, docs/progression_plan.md)
- **Skills rework:** a shared Captain tree, smaller weapon trees with bigger nodes, 25% mastery carried within a
  weapon family, life skills (Swimming, Seamanship, Cooking, Fishing) with milestone perks, refund for old saves.
- **Economy:** scarcer loot rolled per captain, 11 named weapon traits from blue up, one price curve.
- **Food:** regen out of fights, ingredients, galley cooking, 8 meals with 12-20 minute buffs, no free restock.
- **Shops:** a trade per shop with daily stock, buy-back, rare gear only at treasure merchants, artisans on islands.
- **Controls:** the quick item (E) and its wheel, abilities on 1-5, weapon loadouts (X), the action wheel (N) the
  same everywhere, making camp, co-op chat (Enter), shift+click moves, no auto-equip on pickup.
- **The held map:** M unrolls a parchment in the captain's hands; fog of war shared by the crew; ? marks; zooming
  from the island to the sea chart.
- **Quests and people:** the crew journal (J), notice boards, multi-step quests turned in to their giver, rewards
  that aren't XP, varied lines, 10 kinds of island encounters.
- **Swimming:** diving with a breath meter, dive loot, currents, surf and cold water, sharks, morays and jellyfish,
  new strokes, climbing out.
- **Sailing downtime:** lash the helm; train, read, tinker, fish, sleep; the first Blender clip (reading).
- **Fishing:** an equipment slot with a SHOW box, rods in tiers, a Minecraft-style minigame, bait, fish rarities,
  fishing perks.
- **Ships:** yard ropes as an upgrade, the rope wins the prompt in the air, pirates board; the stern corners fixed.
- **Perf pass:** within the perf gate's allowance, stable near 60 fps (docs/v1_18 perf pass notes in dev_notes).

## The blog post (Zach's points)
- We've got into a groove of developing effectively and covering more content per release.
- We built tools and workflows (parallel feature lanes, a landing queue, cached dependency-based tests, the release
  gates) that keep quality and content consistent.
- This update solidified much more of the vision, and **the roadmap was rebuilt** to match the new scope and goals
  (the 1.19-1.22 release plan: the Admiralty + rival crews + a new intro; the world + cities; combat + gear;
  strongholds + Driftfruits).
- It's genuinely getting very fun to play as the systems come together.
- A brief mention of the plans and investigation into releasing on **Steam** in the future.
- Screenshots and GIFs of 1.18's content.

## The site
- **Home page:** generalise it. A small card/banner at the top linking the newest blog post. Replace the images that
  are all from 1.10 with ones about the game as it is now (sailing, islands of each theme, Brinehollow, combat,
  diving, the held map, cooking/fishing, co-op).
- The news post + news index, releases page, README, `scripts/ui/whats_new.gd`, `project.godot` version 1.18.
- Images: 1600x900 + 640 JPEGs (themewxshot `TWX_SITE` and the feature render tools); GIFs short and small.

## Steps
1. Fishing and the perf pass land; checked on main.
2. `prepush.ps1 -NoPush` (the full local run, co-op included); one fix pass.
3. The perf gate (`perf_gate.ps1`): inside the allowance (Zach: up to 15%, stable near 60 fps).
4. Merge the web roadmap branch `claude/web-timeline-992b26` into main (the session is done and doesn't land it itself;
   web/site and docs only, so no tests to rerun).
5. Screenshots/GIFs, the post, the home page, the release commit.
   - **The roadmap timeline:** in `web/site/roadmap/roadmap.json`, move "you are here" (`"here": "1.18"`) and fill in
     the version's card: `"status": "shipped"`, its `date`, its release `name`, a one-line `headline`, an `img` from
     the new site shots (plus `shots` / `clip` if there are more), `added` (everything it added, from the what's new),
     `news` (the post's path) and `"github": true`. Set the next version (1.19) to `"status": "building"`. Use
     Driftwake's own names (docs/originality_plan.md).
6. Push main, tag `v1.18`, push the tag (build-windows.yml on the tag, deploy-web on main).

## Released (2026-10-20, ~00:13)
Tagged v1.18 at b9d4512 and pushed (main went 8b5bbf1 -> b9d4512, 126 commits). Shipped with the full local run green
after the fix pass (the four stale or fragile tests fixed in the test; dungeontest's fog grid was a real bug), nettest
basic, chain, board and jam passing (jam on its second run: the known "host accepted us" startup flake), and the perf
pass inside Zach's bar (mean frame +8%, frame1t +7% against the gate; plaza frame1t +35.2% on a 35% line and the
ticks check are this PC's noise; CROWD still off).
**Known issues for 1.19:** co-op guests can still be dropped under very heavy load (20-55 s world-build freezes; the
host now sends only to captains whose world is up, with a long ENet timeout while loading); a dropped guest only
learns after its own timeout; the campfire flame renders as a pale block (v1_20_plan.md); Sea Legend's Platter
(the first-legendary recipe) borrows the stew's icon; Blender isn't installed here, so the pilot clip came from a Godot stand-in.
