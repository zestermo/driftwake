# Driftwake 1.30: draft changelog

*Draft, 2026-11-03. Built from the four-captain playtest of 1.29. Marked: ✅ on main, 🔨 being built, 📋 planned for 1.30.*

## Knowing what to do next
- ✅ **The objective box always has a goal.** When you follow nothing else, it shows the chain's next step: finish the story, see Morrow, reach level 5, then "Sail to <island>" with the bearing and distance in km. On a chain island, the next step is its elder, its trouble, its beast, then exploring. The box used to sit blank for hours after the story.
- ✅ **The Captain's Log (J)**, one place for what's next:
  - Tabs: NEXT, QUESTS, NEWS and DONE.
  - The followed goal is shown big, with a chip for each captain that's following it.
  - Numbered leads carry YOURS, <NAME>'S or SHARED chips. A map uses the same numbers.
  - A "news you might have missed" list.
  - Press T to follow a lead or the chain.
- ✅ **News you won't miss.** Important news (a new quest, a chart marked, a story step, a rival crew) pins as a card under the objective box until you open the log. Small news stacks bottom left and is kept in the log.
- ✅ **The capital's lines are real quests.** The Queen's line and the Doge's line are journal quests that advance as things happen in the world, for guests and after a load too.
- ✅ **The stronghold run is a quest**: the seals, Vane, the vault, the escape. Each district shows a line telling you what to do there.
- ✅ **Enemy health bars.** A small bar and red marker appear over a foe that's fighting you, was just hit, or is close and after you, and fade 5 s after. Bosses keep their big bar, and townsfolk never get one, so hostiles stand out in a crowd.

## Movement
- ✅ **Slope slide, free for everyone.** Press C running down a hill, or on the way down to land in a slide. It picks up speed downhill, and jumping out keeps the speed.
- ✅ **Wall moves (Acrobatics):** Wall Jump, Wall Kick, Wall Run, Wall Cling, Spring Heels and Rebound.
- ✅ **Air dash (Acrobatics):** Air Dash, Twin Dash, Dash Distance, Dash Strike, and Skyward Dash (straight up).
- ✅ **More for an aerial build:** Hang Time, Aerial Combo, Air Control and Feather Fall.
  - Moonstep is remapped: jump kicks off the air for 2 s once your air steps are spent.
  - Sky Leap tops out at 25 m, 45 m with Heavenward. Will Legs is gone.
- ✅ **Livelier air.** Air steps are bouncier, and long falls windmill and pedal.

## Skills and progression
- ✅ **Every tree is one branching map.** Zoom with the wheel, triggers or +/-, pan by dragging or with the right stick, and press N to centre on what you can buy next.
- ✅ **Node shapes say what a node is:** abilities are gold circles, passives blue diamonds, stat steps small pips, and nodes linking two branches dashed coral.
- ✅ **Acrobatics remapped** into Air, Walls, Slides and Footwork branches around one root.
- ✅ **Fixed: buying a node without its parent.** Old saves keep what they bought.
- ✅ **Strike speed.** Quick Hands steps in every melee tree: katana 5 × 4%, light weapons 4 × 4%, medium 3 × 4%, heavy 3 × 3%. Flowing Edge for the katana at mastery 20. Capped at +35%, for light and heavy attacks only.
- ✅ **Edy is rarer and means more.** Bosses give 1 point and story villains and Leviathans 2; officers and minibosses give none. Meditation gives one every 6 game days.
- ✅ **Adventure trees level faster.** They have their own curve and twice the xp for doing things. Acrobatics xp only comes from moves that count. Old saves are re-levelled without anyone losing a level.
- ✅ **Vey's rack and drills:**
  - The rack no longer gives mastery or points.
  - You don't start with a cutlass.
  - Vey tells you when the drills are ready.
  - The katana can finish the drills: Iai and techniques count.

## Combat and bosses
- ✅ **Tougher enemies.** Pirates and marines have +30% health. In co-op every enemy also does +10% damage per extra captain.
- ✅ **Bosses scale for the crew**: health × (1 + 0.85 per extra captain), and poise scales too. The stronghold bosses scale as well, and rescale when someone joins or leaves.
- ✅ **Phase resets.** At each new phase a boss leaps back to its arena's middle, lands with a shockwave that throws everyone out, then roars for 1.5 s while it can't be hurt. This covers:
  - every arena beast, the Silverback and the Brood Queen;
  - Morrow, the bandit chief and the huntsman;
  - the drowned captain, Kesh, Marrow and Vane.
- ✅ **No more pinning in corners.** Crowd a beast boss for about 4 s, or land 8 hits in 3 s, and it roars a ring that pushes everyone back. If it's pinned at the edge, it leaps to the middle instead.
- ✅ **Knockback slides you along walls** instead of pinning you against them.
- ✅ **Morrow's Tide Rush** stops before water or a drop and ends in a hard skid, so he no longer dashes into the sea.
- ✅ **Overkill launches and wall splats:**
  - A big overkill throws a foe flat, backwards or up into a wall or ceiling. It leaves a crack, sticks a second, then ragdolls down. With nothing near, it skids or lands with a small mark.
  - Blood where it fits.
  - Strong enemy moves can do it to you: you're dazed for a second and slower to get up.
  - Captains can do it to each other in duels and to AI captains.
  - The throw's power follows the overkill. Just past the line, the body drops a step or two. A huge overkill sends it flying at 25 m/s, knocking down anyone in its path.
- ✅ **Levels matter in a fight.** The gap between a foe's level and yours scales damage both ways, its poise, and how easily it splats. 4 levels below you, a foe takes ×1.24 damage, hits you for ×0.52, and has half the poise. 5 above, it hits you ×1.6 harder.
- ✅ **Smaller health bars with a level badge:** grey when the foe is far below you, white normally, red when it's 3+ levels above you.
- ✅ **Enemy personalities:**
  - Berserkers, Opportunists (they wait for others to engage first), Duelists (they parry) and Bulwarks (they block), each with a tell you can read.
  - Jumping attacks from strong foes.
  - Riflemen that move between shots, hip-fire close up, bayonet when rushed, kneel for aimed shots, and roll.

## At sea
- ✅ **Ships catch you.** The chase clock only runs while fighting, and pursuers have a distance edge. An upgraded sloop is caught in about two minutes.
- ✅ **Pirates sail alongside** and trade broadsides on the run.
- ✅ **No false "Escaped"** mid-fight near islands, in storms, in smoke or at low hull.
- ✅ **The Admiralty arrives without the 2-3 s freezes.** Ships and crews are built in the background, one ship a frame, on guests too.
- ✅ **The skimmer is faster:** 11 / 13.5 / 16 m/s by tier (was 9 / 11 / 13), and it keeps 55% of its speed straight into the wind (was 45%).
- ✅ **Rival crews never come to the capital, the canal city or the stronghold.** The check that kept them out was broken.
- ✅ **Rival crews arrive in a ship you can see.** It sails in and anchors off the harbour, with a named banner, a music sting, and their captain calling you out by name.

## The Admiralty stronghold
- ✅ **The vault works.** The chest sits on the hall floor and is marked. It gives a legendary Driftfruit, the first fruit in the world (one per save). Seeds with broken legendary ids no longer lose their vault.
- ✅ **Fixed: falling through the fortress.** Every district has a solid floor under its cobbles.
- ✅ **Stronghold fixes:** the Scouring is announced as ordered (the fortress "has fallen" only when Vane does), Vane's hall hazards rest while he's on the roof, a late joiner no longer gets every missed reinforcement wave at once, and the cell block matches the rest of the fortress. Boss bars show the level badge, and Brinehollow's apes no longer read as 3 levels above you.
- ✅ **Fixed: stuck dead after Vane.** A captain beaten by an AI captain in co-op was left down for good: no respawn, no revive. Now they bleed out normally, so a crewmate can revive them, and they get up on their own if nobody comes.
- ✅ **The Scouring ends** once you're 300 m out ("Out of the ring"). It no longer follows the ship.
- ✅ **The Scouring as an escape set piece:**
  - The sky goes dark grey with smoke, even at noon.
  - Huge explosions and fireballs on the walls, roofs and water around you, with heavy screen shake and orange flashes.
  - Fires many times a captain's height.
  - The ring of warships fires broadsides.
  - Sirens and drums, and an "Escape the ring" objective.
- ✅ **The run reworked as a raid in acts:**
  - Breach the Landing's gate, by winch, lever or charge. Take both seals in either order, then the keep and Vane, the vault, and the escape.
  - A placed garrison of 77, mostly fodder marines 4 levels under the fortress. A raised alarm brings about 130 more: from hall doors, through the prison gate, and by longboat to the quay. Cleared districts stay clear.
  - Up to 25 fighting at once, kept cheap on the frame.
  - Stealth: silent takedowns from behind, or on foes stunned by flash or smoke. A marine runs for the alarm bell, and you can cut its rope.
  - Boss set pieces:
    - Kesh pours molten crucibles across the foundry.
    - Marrow's prison riot comes in waves out of the cell block.
    - Vane leaps onto the roof at 65% and orders the Scouring at 30%.
    - Each has an intro name card and a telegraphed leap attack.
  - Downed in a boss fight: a crewmate revives you. If you bleed out, you're back up at the arena's checkpoint after 8 s and go back in through a side door. Only a full wipe resets the boss.
  - Crew-split objectives: one captain winds the gate while the others hold off the boats, a sniper perch with long guns, and the vault's two locks pulled together. Each still has a solo window.
- ✅ **The fortress dressed, Marineford style:** white stone with navy and gold trim, gull-crest banners and flags, battlements and carved tower tops, a cannon battery on the quay, warships moored round the harbour. Every district dressed for what it is (the foundry's slag, coal, tramway and crucible; the prison's barred tiers and catwalks; the Lower Ward's covered walkways, drill corner and laundry). The halls inside have vaulted ceilings, arches, tall windows, fireplaces and a lived-in clutter of food, racks, charts and bunks. New walkways along the Arsenal's and the Prison's outer walls for sneaking in.
- ✅ **Gadget packs:** buy smoke, flash, powder charges and the grappling hook at Nessa's and the chandlers (U uses, O cycles). Smoke now hides you behind the cloud too and lasts longer; flash stuns longer and dazzles a captain looking at it; the new powder charge blows gates, crates and crowds.

## The world
- ✅ **Fixed: falling through the capital's roofs.** About 330 houses behind the front rows are now solid.
- ✅ **Unstuck** in the pause menu: back to the last safe ground you stood on, back on the deck if that was a ship, otherwise the bunk. 10 s cooldown. If you end up under the ground, you're put back on your own after about a second.
- ✅ **Missing textures fixed** in the capital and the Admiralty muster.
- ✅ **The atoll under the water:** the seabed's hard edges and the dark square round the island are gone, and the floor is dressed with seagrass, rubble, shells, starfish, urchins and sponges. Clear tropical water in the lagoon. A deep reef basin (about 30 m down) with towering coral pillars, table corals, giant fans, arches, overhangs and swim-through caves, breathing vents to refill your air, big shoals, rays, turtles, morays and prowling reef sharks. Clams, coral spar and new pen shells (Sea-silk) glow and sparkle when you're near, so the skimmer's parts are easy to gather, and the pearl trader points you to the deep reef.
- ✅ **Redtide's mountain.** Morrow's arena sits in a bowl inside a horseshoe of red rock rising from the sea, with spires, a sea arch, sea stacks, pines on the tops and birds wheeling over the peaks. The stair from the jetty is the only way in (and no longer stops you dead at its bend).
- ✅ **The brig and the galleon**, ships you buy at the canal city's shipyard: the brig with two masts, a gun deck down the waist and a two-room cabin; the galleon with three masts, a walkable gun deck below, a high stern castle and a library stateroom. Keep every ship you own and swap at a yard; paint and figurehead go with you.
- ✅ **New creatures** for the fog islands (eerie things, bigger graveyards with zombies rising from the graves) and the forest islands (fairy-tale beasts).
- ✅ **Islands read clearer:** fewer villagers, vendors always at their stalls, landing objectives (find the town, talk to the elder, check the board), and the board as an island tracker (explored, main and side quests, places found) with its bounties and who needs what.
- ✅ **Brinehollow polished:** Tackett's ironwood grove off the path (trees you fell), a chapel square left of Old Pell with three walk-in houses whose keepers teach fishing, gadgets and reading, a new lighthouse on a graded hill road with the keeper's cottage, and the opening now takes you to the farmlands mill, Wick's bench and Aldous's book.
- ✅ **Frozen rivers and lakes walk clean** on the snow islands (no falling through the ice, no lips at the banks).
- ✅ **Much more is solid:** roofs on every house, tavern, chapel and tower; the canal city's and lagoon houses; desert flat roofs; tree trunks that follow their lean and twist; big trees, rocks and fallen logs; cacti, stumps, snow crystals; shallow coral; pier rails and posts; coast rocks. Bamboo stays a thicket you push through.
- ✅ **Step-up:** walking into a ledge up to about 0.6 m (a log, a low wall, a step) carries you up onto it; taller ones still need a jump.
- ✅ **The helm camera:** taking the wheel eases in from your view instead of cutting to a view from under the sea, the scroll wheel zooms at the helm, and with a weapon out the scroll wheel works at once.
- ✅ **Transmog:** every clothing slot has a MOG box; tick it and a LOOK slot opens beside it. Wear any piece there for looks while the real slot keeps its stats (co-op crews see your look).
- ✅ **The sea stops dressed up:** the floating restaurant is twice the size, with a carved fish's head for a bow, a two-storey timber-framed hall and a candlelit dining room with an open kitchen; the warlord's flagship and the Admiralty warship are three-masters with gunports, stern windows and figureheads; the merchant's deck has a real stall.
- ✅ **Calmer crowds:** the market murmur has no voices layered in it any more, laughs, cheers and shouts are softer and capped at two at a time nearby; every vendor has its own sign icon.
- ✅ **Menus laid out for 1080p:** the UI canvas is 960x540 (an exact 2x at 1080p, 4x at 4K), with bigger inventory slots, a roomier Captain's Log, notice board, dialogue, galley, workbench, bookshelf, creator and wheels; small windows no longer fall back to a cramped layout.
- ✅ **The chain sickle moves like a reaper:** the heavy coils low and bursts into a two-turn whirl with the weight thrown out wide and a lunging reap to finish; the lights are its own hook and rip, a bigger lash with a haul, and the weight swings in your hand as you move.

## Behind the scenes
- ✅ **The browser version is retired.** The website deploys on its own, and /play links go home.
- ✅ **New tests** for the chain goal, the log, pinned news, health bars, the skill maps' parent check and strike speed, every new move, solid ground in the capital and the fortress, Unstuck, the boss resets and clearing moves, and the co-op revive after a duel.
