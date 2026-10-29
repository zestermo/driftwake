class_name IslandArcs
extends Node3D
## A chain island's story arc (1.23, docs/v1_23_previews.md section 5): a local problem with a villain, in three beats.
## Beat 1: the elder, the folk's rumours and a poster on the board tell of it (taking it puts the arc in the crew's
## Journal). Beat 2: 2-3 story steps on the island's own places (a squad to break, a thing to take back, someone to
## talk to, a night to hold). Beat 3: the showdown with the villain (the island's camp captain, its beast, or a villain
## the arc brings). Its fall drops the arc's chest, raises the bounty and the Admiralty answers (Admiralty.deed "arc");
## the elder's thanks close it. Replies (Replies) at the villain's first meeting and one moment in beat 2 change the
## next line and sometimes the outcome; a hidden finish, met in the showdown, pays a cache besides.
##
## One template per island (TEMPLATES), rolled from what the island has (`pick`: an outpost, a cave, the fog) and the
## chain's seed, so neighbours differ. State is the crew's Journal entry (the step) and world flags under `key`
## (the island's id and seed: saved, sent to a captain who joins), so every machine builds the same squads and props
## from it. The host decides (Net.arc_ask -> decide), everyone applies (Net._all_arc -> apply).

const TICK := 0.5
## The villain's first meeting: a captain this close (m) to the villain is spoken to.
const MEET_R := 30.0
## A meeting asked of a captain who hasn't answered in this long (s) is asked again.
const ASK_WAIT := 45.0
const NIGHT_FROM := 20.0
const NIGHT_TO := 5.0
## The beast's hidden finish while beasts have no parts to break (the beast pass): felled within this long of waking.
const QUICK_KILL := 120.0
const WEAPONS := ["cutlass", "katana", "polearm", "hammer", "greatsword", "pistol"]
const CONTACT_NAMES := ["Ibo", "Maren", "Tull", "Seska", "Orrin", "Pell", "Dagny", "Kofi", "Wren", "Haldo"]
## Fights at the village's edge stay this far (m) past its plaza: out of a Marine outpost's town (MarineOutpost.TOWN_PAD).
const EDGE := 38.0
## The ghost snuffs a festival lantern this often (s) while he fights.
const SNUFF_EVERY := 20.0
## The Poisoned Well's hidden finish: the queen dead within this long (s) of waking.
const POISON := 150.0
## Villagers who march with the Rebellion; one with a foe at its side this long (s) falls.
const MILITIA := 3
const MILITIA_FALL := 4.0
## The castaway noble's blow: this close (m) to the villain, once, a share of his health.
const BLOW_R := 3.0
const BLOW := 0.08
## Festival lanterns round the showdown's place, this far out (m).
const LANTERN_R := 12.0
const Shops := preload("res://scripts/game/shops.gd")
## Tests and tools: every island rolls this template ("" for the roll).
static var force := ""

## Each template: "title"; "needs" (what the island must have: camp, beast, outpost, cave, fog); "villain" ({"kind":
## camp / beast / squad ...}); "place" (the showdown's spot); the elder's telling ("elder"), the folk's "rumours", the
## board's "poster"; "steps" (beat 2: {"do": squad / pickup / talk / wave, "at": a spot, "goal", "said", ...});
## "showdown" (its goal); "meet" and "moment" (replies: {"lines", "replies": [{"tone", "text", "answer", "out"}],
## "default"}; a moment is at "step", spoken by "contact"); "hidden" ({"kind", "name", "said"}); "thanks", "settled".
## Steps: squad (men to break), pickup (a thing to take), talk (a contact; their moment moves it on), talks (every
## contact listed tells what they saw: "tells"), reach (a place; "race": the hidden finish's time), pieces (things at
## several spots, any order), light (festival lanterns round the place), wave (a night's brood), escort (a contact
## follows the nearest captain to the village). Villains: camp (the camp's captain), beast (the island's), squad (the
## arc's own men and captain at "at"), queen (a brood queen at "at"), ghost (the fog isle's drowned captain, or the
## drowned crew's captain). Outcomes: fight, settle, pay:N, gain:N, hated, raid, more, wounded:K, step, now, allies, fair.
## Tokens: {villain} {village} {elder} {place} {c0}... (the arc's contacts).
const TEMPLATES := {
	"tyrant": {
		"title": "The Tyrant's Tax",
		"needs": ["camp"],
		"villain": {"kind": "camp"},
		"place": "camp",
		"place_name": "the pirate camp",
		"elder": ["Since the rains, {villain} and his crew have bled {village} dry. A tax, he calls it.",
			"His collectors take half of every catch, and last week they took our strongbox: the whole village's savings.",
			"We can't fight him. But you look like you could."],
		"remind": ["His collectors work the road to the camp. The strongbox is at the camp's edge, under his nose."],
		"rumours": ["{villain}'s collectors came by again. Took my nets this time.",
			"They say {villain} keeps our strongbox at the edge of his camp, where he can see it from his chair.",
			"Half the village wants to pay {villain} and be done. The other half wants him gone.",
			"His men aren't all bad, you know. Half of them were fishermen here before he came."],
		"poster": "By order of the village: a reward to whoever ends {villain}'s 'tax'. Ask {elder}.",
		"contacts": [{"name": "Quartermaster {n}", "at": "camp_edge", "look": "pirate", "line": "I only keep the books, friend. Don't look at me like that."}],
		"steps": [
			{"do": "squad", "at": "road_camp", "men": 3, "look": "pirate", "goal": "Break {villain}'s tax collectors on the road to the camp",
				"said": "The collectors are broken. Now take back the strongbox."},
			{"do": "pickup", "at": "camp_edge", "goal": "Take back {village}'s strongbox from the edge of {villain}'s camp", "search": "Take the village strongbox",
				"said": "The strongbox is the village's again. {villain} won't let that stand."},
		],
		"showdown": "Face {villain} at the pirate camp",
		"moment": {"step": 1, "contact": 0,
			"lines": ["Easy, easy! I keep his books, that's all. That box isn't worth dying over.", "So what's it to be?"],
			"replies": [
				{"tone": "cocky", "text": "Run and tell your captain I'm coming.", "answer": "He'll have every man he's got waiting for you!", "out": ["more"]},
				{"tone": "cool", "text": "Walk away. I never saw you.", "answer": "Never saw you either. Good luck. You'll need it.", "out": []},
				{"tone": "diplomatic", "text": "Thirty gold says you tell me how he fights.", "cost": 30,
					"answer": "His left knee's bad from the last mutiny. Kick it and he's half the man. You didn't hear it from me.", "out": ["pay:30", "wounded:0.25"]},
			]},
		"meet": {
			"lines": ["So you're the ones stirring up my village.",
				"Here's my offer: you pay the tax like everyone else, a captain's share, and we part friends. Or you don't, and my boys visit {village} tonight."],
			"replies": [
				{"tone": "diplomatic", "text": "Fine. Take the gold and leave them be.", "cost": 150, "answer": "Smart captain. Now get off my island.", "out": ["pay:150", "settle", "hated"]},
				{"tone": "cool", "text": "Not one coin.", "answer": "Then I'll take it out of them tonight. Every house.", "out": ["raid"]},
				{"tone": "cocky", "text": "Your tax days are over, old man.", "answer": "Old?! Cut them down, lads!", "out": ["fight"]},
			],
			"default": 2},
		"hidden": {"kind": "spare_men", "name": "Mercy", "said": "With their captain down and not one of them killed, his men throw down their blades and surrender."},
		"thanks": ["{villain}... gone? Truly?", "Then {village} keeps its catch and its savings. Take this, with all our thanks."],
		"settled": ["You paid him. With our strongbox in your hands, you paid him.", "Leave us be, Captain. You've done enough."],
	},
	"beast": {
		"title": "The Beast of the Hollow",
		"needs": ["beast"],
		"villain": {"kind": "beast"},
		"place": "boss",
		"place_name": "its hollow",
		"elder": ["Something comes down from the hollow at night. {villain}, the old ones call it.",
			"It took two goats, then a fence, then a boat shed. Next it will take a child.",
			"{c0} has been tracking it. Find them, Captain, and end this."],
		"remind": ["{c0} is out on the trail toward the hollow, reading its tracks."],
		"rumours": ["I heard {villain} last night. Like a tree falling, over and over.",
			"There are tracks the size of a cart wheel on the trail to the hollow.",
			"{villain} sleeps in its hollow by day. Only a fool goes in.",
			"Old hunters say you never just kill a beast like that. You take it apart, piece by piece."],
		"poster": "DANGER: {villain}. {village} pays whoever ends it. Ask {elder}.",
		"contacts": [{"name": "Hunter {n}", "at": "tracks", "look": "villager", "line": "Quiet. It passed here an hour ago."}],
		"steps": [
			{"do": "talk", "at": "tracks", "contact": 0, "goal": "Find {c0} on {villain}'s trail", "said": "The trap is set for nightfall."},
			{"do": "wave", "at": "village_edge", "bugs": 5, "goal": "Hold {village} through the night: {villain}'s brood comes first",
				"said": "The night's quiet again. {villain} limps back to its hollow, hurt and angry."},
		],
		"showdown": "Hunt {villain} down in its hollow",
		"moment": {"step": 0, "contact": 0,
			"lines": ["You're after {villain} too? Look at these tracks: it comes down to the village every night.",
				"We can hunt it in its hollow now, while it sleeps. Or we bait a trap at the village tonight and let it come to us. It won't leave a trap whole."],
			"replies": [
				{"tone": "cocky", "text": "Now. I want it awake and angry.", "answer": "Ha! Then go. I'll tell them to bar their doors.", "out": ["now"]},
				{"tone": "cool", "text": "Set the trap. We hold the village tonight.", "answer": "Good. The bait goes out at dusk. Its brood will come first.", "out": ["step", "wounded:0.3"]},
				{"tone": "diplomatic", "text": "What does the village want?", "answer": "To sleep. A trap, then: we hold the village tonight and it limps home hurt.", "out": ["step", "wounded:0.3"]},
			]},
		"hidden": {"kind": "parts", "name": "Trophy hunter", "said": "Taken apart before it fell, just as the old hunters said. They'll sing of this one."},
		"thanks": ["It's dead? You're sure?", "Then we sleep tonight, all of us. Take this, Captain. It isn't enough."],
		"settled": ["It's gone quiet. Whatever you did, thank you."],
	},
	"iron_boot": {
		"title": "Iron Boot",
		"needs": ["outpost"],
		"villain": {"kind": "squad", "at": "outpost_yard", "men": 3, "look": "marine", "title": "Captain {n} of the Admiralty", "names": ["Vane", "Holt", "Crane", "Morrow", "Strake", "Ashby"]},
		"place": "outpost_yard",
		"place_name": "the outpost",
		"elder": ["The Admiralty came to protect us. {villain} protects only his purse.",
			"Fines for fishing, fines for mending nets, fines for being poor. Those who can't pay go in his cell.",
			"{c0} at the dock has seen his books. Ask them. Please."],
		"remind": ["{c0} works the dock. They know where {villain} keeps his ledger."],
		"rumours": ["{villain} fined my brother for whistling. Whistling!",
			"The prisoner in the outpost's cell sold a man some rope. That's all he did.",
			"They say {villain} writes every bribe in a ledger. Thinks it makes him an honest crook.",
			"His own marines hate him. If they ever saw what's in that ledger..."],
		"poster": "Anonymous: {villain} is a thief in a uniform. Whoever proves it will be paid. Ask {elder}.",
		"contacts": [{"name": "Dock clerk {n}", "at": "dock_land", "look": "villager", "line": "Keep your voice down. The Admiralty has ears on the dock."}],
		"steps": [
			{"do": "talk", "at": "dock_land", "contact": 0, "goal": "Hear what {c0} knows at the dock", "said": "His ledger is behind the outpost, in the strongroom."},
			{"do": "pickup", "at": "outpost_back", "goal": "Steal {villain}'s ledger from behind the outpost", "search": "Take the ledger",
				"said": "The ledger's in your hands. Every bribe, every false fine, in his own writing."},
		],
		"showdown": "Confront {villain} at the outpost",
		"moment": {"step": 0, "contact": 0,
			"lines": ["He keeps a ledger: every bribe, in his own hand. It's behind the outpost, in the strongroom.",
				"Take it, and his own men will know what he is. Or skip it and go at him now, if you're in a hurry."],
			"replies": [
				{"tone": "cocky", "text": "Forget the ledger. I'll go and knock his teeth out.", "answer": "Then do it fast, before he calls the whole garrison.", "out": ["now"]},
				{"tone": "cool", "text": "I'll get the ledger.", "answer": "Go round the back. Good luck.", "out": ["step"]},
				{"tone": "diplomatic", "text": "Ten gold for your trouble. Where exactly?", "cost": 10, "answer": "Under the loose stone by the back wall. And he drinks before noon: slow on his feet.", "out": ["pay:10", "step", "wounded:0.15"]},
			]},
		"meet": {
			"lines": ["A pirate at my outpost. What a treat for my report.",
				"Of course, reports can be... adjusted. Everything has a price on this island. What's yours?"],
			"replies": [
				{"tone": "diplomatic", "text": "Two hundred gold, and you look away.", "cost": 200, "answer": "Pleasure doing business. The outpost saw nothing.", "out": ["pay:200", "settle"]},
				{"tone": "cool", "text": "I know what's in your ledger. So will everyone.", "answer": "You little... Guards! Arrest them!", "out": ["fight"]},
				{"tone": "cocky", "text": "My price is your hat. With your head still in it.", "answer": "Insolence! Cut them down!", "out": ["fight"]},
			],
			"default": 1},
		"hidden": {"kind": "ledger", "name": "Turncoats", "said": "His own marines read the ledger and lowered their muskets. He faced you alone."},
		"thanks": ["The fines... gone with him. And the cell door open.", "You did what the Admiralty wouldn't. Take this."],
		"settled": ["You bought him off. He'll keep fining us, and now he knows pirates pay."],
	},
	"heirloom": {
		"title": "The Stolen Heirloom",
		"needs": ["cave"],
		"villain": {"kind": "squad", "at": "cave_in", "men": 3, "look": "pirate", "title": "{n} the Fox", "names": ["Silk", "Marrow", "Quill", "Lark", "Tansy", "Rook"]},
		"place": "cave_in",
		"place_name": "the thieves' hideout",
		"meet_r": 14.0,
		"elder": ["Three nights ago thieves broke into my home and took the island's heirloom: the old captain's compass.",
			"Without it, the festival can't be held. Without the festival... well. We're nobody.",
			"Someone saw something. Ask {c0}, {c1} and {c2}."],
		"remind": ["Ask {c0}, {c1} and {c2} what they saw that night."],
		"rumours": ["I saw torches going up toward the caves the night the heirloom went.",
			"{villain} the thief? He never fights fair. Never fights at all, if he can help it.",
			"Whoever took the compass knew the elder's house. Someone from here helped.",
			"Thieves sleep light. Hit one before he sees you and he's half caught."],
		"poster": "STOLEN: the old captain's compass. A reward for its return. Ask {elder}.",
		"contacts": [
			{"name": "Net-mender {n}", "at": "witness0", "look": "villager", "line": "Terrible business, the heirloom."},
			{"name": "Night-fisher {n}", "at": "witness1", "look": "villager", "line": "I fish at night. I see things."},
			{"name": "Old {n}", "at": "witness2", "look": "villager", "line": "Hm? Speak up."}],
		"steps": [
			{"do": "talks", "contacts": [0, 1, 2], "goal": "Ask the witnesses what they saw", "said": "Three stories, one answer: the caves."},
			{"do": "reach", "at": "cave", "r": 10.0, "goal": "Find the thieves' way into the caves", "said": "The thieves' hideout. Quietly, now."},
		],
		"tells": ["Torches. Going up toward the caves, three of them. Laughing.", "A man in a fox-fur collar sold a gold chain at the dock. Cheap.",
			"The Fox, they call him. He hides in the caves up the hill, deep in, where the tunnel bends."],
		"showdown": "Take back the heirloom from {villain} in the caves",
		"moment": {"step": 0, "contact": 2,
			"lines": ["The Fox? I know where he hides. I know a quiet way in, too.", "What's an old man's memory worth to you?"],
			"replies": [
				{"tone": "cocky", "text": "Tell me or I'll shake it out of you.", "answer": "Fine! The caves! Brute. And I'll tell him you're coming.", "out": ["more"]},
				{"tone": "cool", "text": "Nothing. I'll find him.", "answer": "Suit yourself. Mind the caves.", "out": []},
				{"tone": "diplomatic", "text": "Twenty gold and my thanks.", "cost": 20, "answer": "He sleeps after noon, with a bad shoulder. Light feet.", "out": ["pay:20", "wounded:0.2"]},
			]},
		"meet": {
			"lines": ["Ah. The elder's hired blade. I wondered when.",
				"I'm a businessman. You want the compass? Buy it. Or try to take it, and see how fast a fox runs."],
			"replies": [
				{"tone": "diplomatic", "text": "How much?", "cost": 120, "answer": "Hundred and twenty. A bargain. Pleasure.", "out": ["pay:120", "settle"]},
				{"tone": "cool", "text": "I'll take it back.", "answer": "Then earn it!", "out": ["fight"]},
				{"tone": "cocky", "text": "Run, fox. I like a chase.", "answer": "Lads! Do something useful!", "out": ["fight"]},
			],
			"default": 1},
		"hidden": {"kind": "unseen", "name": "Ghost", "said": "He never saw you coming. The thieves will tell stories about you."},
		"thanks": ["The compass! It's the compass!", "The festival goes ahead. And you'll be the guest of honour. Take this."],
		"settled": ["You bought it back from him? With what was meant for us? ...Well. It's back."],
	},
	"festival": {
		"title": "The Cursed Festival",
		"needs": ["fog"],
		"villain": {"kind": "ghost"},
		"place": "boss",
		"place_name": "the drowned captain's ground",
		"elder": ["Tonight should be the festival of lanterns. Instead the drowned walk, and {villain} calls them up.",
			"Every year we light the lanterns and the dead stay down. This year the lanterns won't stay lit.",
			"Light them, Captain. Then put {villain} back where he belongs."],
		"remind": ["The festival lanterns stand round {place}. Light them, and the dead lose their way."],
		"rumours": ["My grandfather's coat walked past my window last night. He's been dead ten years.",
			"The lanterns are what keep the drowned down. Everyone knows that.",
			"{villain} snuffs lanterns like candles. Keep them burning and he weakens.",
			"Promise the dead an offering and they go quiet. For a while."],
		"poster": "THE FESTIVAL IS CANCELLED until the drowned are laid. Brave souls: see {elder}.",
		"contacts": [{"name": "Lantern-keeper {n}", "at": "village", "look": "villager", "line": "The lanterns must burn. They must."}],
		"steps": [
			{"do": "squad", "at": "village_edge", "men": 4, "look": "pirate", "goal": "Banish the drowned walking at the edge of {village}", "said": "The drowned fall back. Now the lanterns."},
			{"do": "light", "n": 4, "goal": "Light the festival lanterns round {place}", "said": "Every lantern burns. {villain} stirs."},
		],
		"showdown": "Lay {villain} to rest, and keep the lanterns burning",
		"moment": {"step": 1, "contact": 0,
			"lines": ["You'll light the lanterns? Then hear me: he'll put them out. He always does.", "Will you make the old offering first, or go as you are?"],
			"replies": [
				{"tone": "cocky", "text": "I don't make offerings to dead men.", "answer": "Then he'll be angry. Very angry.", "out": ["more"]},
				{"tone": "cool", "text": "As I am.", "answer": "Then go, and keep them burning.", "out": []},
				{"tone": "diplomatic", "text": "Teach me the offering.", "answer": "A coin in the sea and a word for the drowned. There. They'll be weaker for it.", "out": ["wounded:0.2"]},
			]},
		"meet": {
			"lines": ["Lanterns... always lanterns. Every year they shut us out.", "The sea took us, and the sea wants its offering. Promise it, living one, or join us."],
			"replies": [
				{"tone": "diplomatic", "text": "I promise. Every year, an offering.", "answer": "Then we sleep. Remember your promise.", "out": ["settle"]},
				{"tone": "cool", "text": "No. Go back to the sea.", "answer": "Then the sea will come for you!", "out": ["fight"]},
				{"tone": "cocky", "text": "I'll send you back myself.", "answer": "Ha! The drowned do not drown twice!", "out": ["fight"]},
			],
			"default": 1},
		"hidden": {"kind": "lanterns", "name": "Festival of lights", "said": "Every lantern burned through the fight. The drowned will sleep for a hundred years."},
		"thanks": ["The lanterns burn and the drowned sleep. We'll hold the festival tonight!", "Take this, and come and dance."],
		"settled": ["A promise to the dead... I hope you keep it, Captain. We'll be the ones who pay if you don't."],
	},
	"rebellion": {
		"title": "The Rebellion",
		"needs": ["outpost"],
		"villain": {"kind": "squad", "at": "outpost_yard", "men": 4, "look": "marine", "title": "Commander {n}", "names": ["Graves", "Thorne", "Vex", "Harrow", "Kell", "Mordane"]},
		"place": "outpost_yard",
		"place_name": "the outpost",
		"elder": ["{villain} rules {village} from that outpost like a king. The Admiralty never answers our letters.",
			"The young ones want to fight. They have courage, and nothing else.",
			"{c0} leads them. If you'd arm them... maybe we could be free."],
		"remind": ["{c0} is gathering the young ones. They need weapons: there's a smugglers' cache at the old stones."],
		"rumours": ["{villain} took half our harvest for 'the garrison'. The garrison is twelve men.",
			"There's a smugglers' cache of muskets at the old stones. Everyone knows. Nobody dares.",
			"{c0} says we'll rise. My mother says we'll hang.",
			"If the villagers fight, someone will die. Unless someone's watching their backs."],
		"poster": "(scrawled) FREE {village}. Ask {elder}. Burn this.",
		"contacts": [{"name": "Rebel {n}", "at": "village", "look": "villager", "line": "Keep your voice down. The walls listen."}],
		"steps": [
			{"do": "pickup", "at": "ruins", "goal": "Recover the smuggled muskets at the old stones", "search": "Take the musket crate", "said": "Muskets. Old, but they'll fire. Take them to {c0}."},
			{"do": "talk", "at": "village", "contact": 0, "goal": "Arm {c0}'s rebels", "said": "The rebels are armed. The outpost next."},
		],
		"showdown": "Raid the outpost and bring down {villain}",
		"moment": {"step": 1, "contact": 0,
			"lines": ["Muskets! Real ones!", "So how do we do it? You lead the charge, or we fight beside you?"],
			"replies": [
				{"tone": "cocky", "text": "I lead. You watch and learn.", "answer": "Ha! Fine. We'll cheer.", "out": ["step"]},
				{"tone": "cool", "text": "Fight beside me. Stay close.", "answer": "Beside you, then. For {village}!", "out": ["step", "allies"]},
				{"tone": "diplomatic", "text": "It's your island. You fight for it, I'll keep you alive.", "answer": "Then we march together!", "out": ["step", "allies"]},
			]},
		"meet": {
			"lines": ["So the rabble found a pirate to hide behind.", "Lay down those muskets, all of you, and I'll only hang the pirate."],
			"replies": [
				{"tone": "cocky", "text": "Come and take them.", "answer": "Fire! Fire at will!", "out": ["fight"]},
				{"tone": "cool", "text": "{village} is free. Leave.", "answer": "Free? I'll show you free. Guards!", "out": ["fight"]},
				{"tone": "diplomatic", "text": "Leave now and nobody dies today.", "answer": "Generous. And foolish. Take them!", "out": ["fight"]},
			],
			"default": 1},
		"hidden": {"kind": "no_fall", "name": "Not one lost", "said": "Every villager who marched with you walks home. {village} will tell this story for ever."},
		"thanks": ["{village} is free. Free! I never thought I'd say it.", "Take this. It was hidden from {villain} for years."],
		"settled": ["It's over. Somehow."],
	},
	"noble": {
		"title": "The Castaway Noble",
		"needs": [],
		"villain": {"kind": "squad", "at": "dock_land", "men": 3, "look": "pirate", "title": "Captain {n} the Ransomer", "names": ["Brack", "Sly", "Varga", "Scald", "Drum", "Hessan"]},
		"place": "dock_land",
		"place_name": "the dock",
		"elder": ["A ship went down off the point last week. Rich folk's ship. One of them washed up alive, they say.",
			"And now there's a crew sniffing round asking after a noble. Ransom hunters.",
			"Find the castaway before they do, Captain. Bring them here."],
		"remind": ["The castaway is somewhere up toward the lookout. Bring them back to {village}."],
		"rumours": ["I saw smoke up by the lookout. A signal fire, maybe.",
			"{villain}'s crew offered a hundred gold for 'a lost relative'. Lost relative my foot.",
			"A noble! Here! What would a noble even eat?",
			"Nobles learn the sword, you know. Even a castaway might land a blow, given the chance."],
		"poster": "MISSING: a noble of the mainland, shipwrecked. A reward for their safe return. Ask {elder}.",
		"contacts": [{"name": "Lady {n}", "at": "summit_near", "look": "villager", "line": "Oh thank the tides. Are you... are you with them?"}],
		"steps": [
			{"do": "talk", "at": "summit_near", "contact": 0, "goal": "Find the castaway near the lookout", "said": "The castaway follows you. Get them to {village}."},
			{"do": "escort", "contact": 0, "goal": "Bring {c0} safely to {village}", "said": "{c0} is safe in {village}. And here come {villain}'s crew, at the dock."},
		],
		"showdown": "Stop {villain}'s crew at the dock",
		"moment": {"step": 0, "contact": 0,
			"lines": ["A crew landed yesterday. They want me alive, for the money. I heard them.", "Will you... will you take me to the village? I can walk. Mostly."],
			"replies": [
				{"tone": "cocky", "text": "Keep up and keep quiet.", "answer": "I... yes. Of course.", "out": ["step"]},
				{"tone": "cool", "text": "Stay behind me.", "answer": "Behind you. Yes.", "out": ["step"]},
				{"tone": "diplomatic", "text": "You're safe now. I'll get you home.", "answer": "Thank you. I won't forget it. And I can hold a sword, you know.", "out": ["step"]},
			]},
		"meet": {
			"lines": ["Well, well. You've got something of mine, pirate.", "Hand the noble over and I'll cut you in. Two hundred gold. Or don't, and I take them anyway."],
			"replies": [
				{"tone": "diplomatic", "text": "Two hundred. Done.", "answer": "Pleasure. Come along, your ladyship.", "out": ["gain:200", "settle"]},
				{"tone": "cool", "text": "They stay with me.", "answer": "Then you go in the sea!", "out": ["fight"]},
				{"tone": "cocky", "text": "Come and get them.", "answer": "Gladly!", "out": ["fight"]},
			],
			"default": 1},
		"hidden": {"kind": "noble_blow", "name": "Noblesse oblige", "said": "The castaway's own blade landed a blow. They'll knight you for this, somewhere."},
		"thanks": ["You brought them back! And saw off the ransomers!", "The noble's family will pay handsomely. Here's our share for you."],
		"settled": ["You sold them. To ransomers. I hope the gold is heavy, Captain."],
	},
	"well": {
		"title": "The Poisoned Well",
		"needs": [],
		"villain": {"kind": "queen", "at": "lair"},
		"place": "lair",
		"place_name": "the burrows",
		"elder": ["The well's gone green. Half the village is sick, and the healer says it's venom.",
			"Something's nesting under the burrows. A queen, the old hunters say: her brood poisons everything they touch.",
			"{c0} needs herbs to cure the sick. And someone has to end the queen."],
		"remind": ["{c0} needs herbs from the old stones. The queen nests under the burrows."],
		"rumours": ["My little one's been sick three days. The healer's herbs are the only thing that helps.",
			"The bugs at the burrows have gone mad. There's a queen down there, mark me.",
			"Kill the queen and the venom thins. That's how it works with brood.",
			"The poison spreads faster every day. Whoever goes after the queen had better be quick."],
		"poster": "WELL POISONED. Do not drink. A reward to whoever ends the brood. Ask {elder}.",
		"contacts": [{"name": "Healer {n}", "at": "village", "look": "villager", "line": "Don't drink the water. Don't drink anything."}],
		"steps": [
			{"do": "pickup", "at": "ruins", "goal": "Gather the healer's herbs at the old stones", "search": "Gather the herbs", "said": "Herbs enough for the sick. Take them to {c0}."},
			{"do": "talk", "at": "village", "contact": 0, "goal": "Bring the herbs to {c0}", "said": "The sick will live. Now the queen."},
		],
		"showdown": "Kill the brood queen at the burrows",
		"moment": {"step": 1, "contact": 0,
			"lines": ["The herbs! I can brew enough for everyone, but it takes time.", "Do I cure the village first, or do you go now, while she's weak from laying?"],
			"replies": [
				{"tone": "cocky", "text": "Now. She won't see me coming.", "answer": "Then go, and be quick: the poison won't wait.", "out": ["step", "wounded:0.2"]},
				{"tone": "cool", "text": "Cure them first.", "answer": "Thank you. The village will be on its feet by the time you're back.", "out": ["step"]},
				{"tone": "diplomatic", "text": "What's best for the village?", "answer": "The cure first. I'll send word when it's done.", "out": ["step"]},
			]},
		"hidden": {"kind": "timer", "name": "Antidote", "said": "The queen fell before the poison spread. Not one villager lost."},
		"thanks": ["The well runs clear! The sick are standing!", "We owe you our lives. Take this."],
		"settled": ["It's quiet at the burrows now."],
	},
	"champion": {
		"title": "The Champion's Challenge",
		"needs": [],
		"villain": {"kind": "squad", "at": "ruins", "men": 0, "look": "pirate", "title": "Swordmaster {n}", "names": ["Ryuen", "Kasha", "Tobin", "Isolde", "Garreth", "Mirai"]},
		"place": "ruins",
		"place_name": "the old stones",
		"elder": ["{villain} came to {village} to find a worthy opponent. He has found none.",
			"Now he beats our young ones bloody for sport, and calls it teaching.",
			"Beat his students, Captain, and he'll have to face you. Maybe that will humble him."],
		"remind": ["His students train at the old stones. He watches from the steps."],
		"rumours": ["{villain} broke my son's arm. 'A lesson', he said.",
			"His students fight one at a time. He insists. Honour, he calls it.",
			"They say {villain} has never lost a fair fight.",
			"Beat him without tricks and he'll teach you his secret stroke. That's the old way."],
		"poster": "A CHALLENGE: {villain} will face any fighter who can beat his three students. At the old stones.",
		"contacts": [{"name": "Student {n}", "at": "ruins_near", "look": "villager", "line": "The master is watching. Don't embarrass yourself."}],
		"steps": [
			{"do": "squad", "at": "ruins_near", "men": 3, "look": "pirate", "duel": true, "goal": "Beat {villain}'s three students at the old stones", "said": "His students are down. The master rises."},
		],
		"showdown": "Duel {villain} at the old stones",
		"moment": {"step": 0, "contact": 0,
			"lines": ["You want to fight us? One at a time, as the master teaches.", "Or are you the kind who fights three at once and calls it bravery?"],
			"replies": [
				{"tone": "cocky", "text": "All three. Now.", "answer": "Arrogant! The master will hear of this.", "out": ["more"]},
				{"tone": "cool", "text": "One at a time, then.", "answer": "Good. Maybe you're worth something.", "out": []},
				{"tone": "diplomatic", "text": "I'll fight however your master wishes.", "answer": "Respectful. He'll like that. He favours his left, you know.", "out": ["wounded:0.1"]},
			]},
		"meet": {
			"lines": ["You beat my students. Barely. Now face a real blade.", "A fair fight, steel on steel, no tricks? Or do you fight like a pirate?"],
			"replies": [
				{"tone": "cool", "text": "Fair. Steel on steel.", "answer": "Then show me your steel.", "out": ["fair"]},
				{"tone": "cocky", "text": "I fight to win.", "answer": "Pirate. Then I'll fight to kill.", "out": ["fight"]},
				{"tone": "diplomatic", "text": "However you like, master.", "answer": "Then fairly. And may the better blade win.", "out": ["fair"]},
			],
			"default": 0},
		"hidden": {"kind": "fair", "name": "The fair fight", "said": "Steel on steel and nothing else. {villain} bows, and shows you his secret stroke."},
		"thanks": ["You beat {villain}! Fairly or not, he's gone quiet.", "Our young ones can train in peace. Take this."],
		"settled": ["He's gone, anyway."],
	},
	"treasure": {
		"title": "The Treasure Race",
		"needs": ["cave"],
		"villain": {"kind": "squad", "at": "cave", "men": 3, "look": "pirate", "title": "Captain {n} of the Gilded Gull", "names": ["Rask", "Mercer", "Fallow", "Juno", "Krell", "Bastien"]},
		"place": "cave",
		"place_name": "the treasure cave",
		"elder": ["An old map's been torn into three and scattered. Every fool on the island is after the pieces.",
			"And now a rival crew, {villain}'s, has come for it too. If they find it first, they'll strip the island bare looking for more.",
			"Find the pieces before they do, Captain."],
		"remind": ["The map pieces are hidden by the camp, the burrows and the lookout."],
		"rumours": ["{villain}'s crew is digging up half the island looking for map pieces.",
			"My uncle had a piece of that map. Lost it near the lookout, drunk.",
			"The treasure's in a cave, they say. Whoever gets there first keeps it.",
			"If you get the pieces, run. Don't stop for anything. First there wins."],
		"poster": "THREE PIECES OF A MAP. Whoever finds them, finds the treasure. (The elder knows more.)",
		"contacts": [{"name": "Old digger {n}", "at": "village", "look": "villager", "line": "Treasure, treasure. Everyone wants treasure."}],
		"steps": [
			{"do": "pieces", "at": ["camp_edge", "lair_edge", "summit_near"], "goal": "Find the three map pieces", "search": "Take the map piece",
				"said": "The map's whole. The treasure's in a cave, and {villain}'s crew is already moving. Run!"},
			{"do": "reach", "at": "cave", "r": 12.0, "race": 150.0, "goal": "Race {villain}'s crew to the treasure cave", "said": "The cave. And here they come."},
		],
		"showdown": "Hold the treasure against {villain}'s crew",
		"moment": {"step": 0, "contact": 0,
			"lines": ["You're after the map too? I had a piece once. Lost it.", "I know which way that rival crew went, though. For a price."],
			"replies": [
				{"tone": "cocky", "text": "Tell me, or I tell them you're helping me.", "answer": "You wouldn't! ...They went north. And they'll know you're coming now.", "out": ["more"]},
				{"tone": "cool", "text": "Keep it. I'm faster than them.", "answer": "Hope so, for your sake.", "out": []},
				{"tone": "diplomatic", "text": "Fifteen gold. Where are they digging?", "cost": 15, "answer": "The wrong end of the island. You've got time. Not much.", "out": ["pay:15", "slow:60"]},
			]},
		"meet": {
			"lines": ["Ha! Beat us here, did you? Doesn't matter.", "There's plenty for two crews. Share it, and we all sail rich. Or fight us for it."],
			"replies": [
				{"tone": "diplomatic", "text": "Half each. Fair's fair.", "answer": "A sensible pirate! Half it is.", "out": ["gain:150", "settle"]},
				{"tone": "cool", "text": "It's ours.", "answer": "Then we take it off your corpses!", "out": ["fight"]},
				{"tone": "cocky", "text": "Race you for it. Oh wait, I won.", "answer": "Get them!", "out": ["fight"]},
			],
			"default": 1},
		"hidden": {"kind": "first", "name": "First there", "said": "You beat them there and held it. The treasure's yours, every coin."},
		"thanks": ["You found it! The island's old treasure!", "Keep what you found. And take this, for keeping {villain}'s crew off our island."],
		"settled": ["Half to the rival crew? ...Well. Half's better than nothing."],
	},
}

var isl: GenIsland
var life: IslandLife
var village: IslandVillage
## The template's id and its table.
var arc := ""
var T: Dictionary
## Its quest's id in the Journal, and the prefix of its world flags.
var key := ""
var def: Dictionary
## name -> island point; `ys` the few with a floor of their own (a cave's chamber).
var spots := {}
var ys := {}
## The showdown's spot (the template's, or where the fog isle's villain is).
var place := ""
var tok := {}
var contacts: Array = []
var militia: Array = []
var villain_name := ""
var _t := 0.0
var _asking := 0
var _ask_t := 0.0
var _men0 := -1
var _woke_t := -1.0
var _fight_t := 0.0
var _wounded: Array = []
## Lanterns the ghost put out (every machine, in the fight; not saved).
var _snuffed := {}
var _snuff_t := 0.0
## Hit before he'd seen anyone (unseen), and seen first.
var _sneak := false
var _spotted := false
var _race_from := -1.0
var _poison := -1.0
var _peril := {}
var _foul_sent := false
var _empty_t := 0.0


## On a GenIsland's worker (IslandLife.plan): the template it will likely roll (the outpost isn't built yet: its roll
## is), and the contacts' bodies built ahead. {"id", "looks"}.
static func plan(gi: GenIsland) -> Dictionary:
	var id := pick(facts(gi, MarineOutpost.rolls(gi)))
	if id == "":
		return {}
	var looks := _looks(gi, id)
	for lk in looks:
		var h := Humanoid.new()
		h.setup(lk)
		Humanoid.stock(h, lk)
	return {"id": id, "looks": looks}


## What the roll reads off an island.
static func facts(gi: GenIsland, outpost: bool) -> Dictionary:
	return {"id": int(gi.node["id"]), "theme": gi.theme, "outpost": outpost, "cave": not gi.interiors.is_empty(),
		"village": not gi.village_plan.is_empty() and not (gi is CapitalIsland), "chain": int(gi.node.get("chain", 0))}


static func fits(f: Dictionary, id: String) -> bool:
	for n in TEMPLATES[id]["needs"]:
		match str(n):
			"outpost", "cave":
				if not f[n]:
					return false
			"fog":
				if f["theme"] != "fog":
					return false
	return true


## The template an island rolls ("" for none: no village to tell of it). The fog isle rolls the Cursed Festival; any
## other its turn in the chain's own order of the templates that fit, so the islands of one sea differ.
static func pick(f: Dictionary) -> String:
	if force != "":
		return force
	if not f["village"]:
		return ""
	if TEMPLATES.has("festival") and fits(f, "festival"):
		return "festival"
	var order: Array = TEMPLATES.keys()
	order.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(f["chain"]), 5120])
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var start := (int(f["id"]) * 3) % order.size()
	for i in range(order.size()):
		var id: String = order[(start + i) % order.size()]
		if id != "festival" and fits(f, id):
			return id
	return ""


## The contacts' looks (seeded by the island and the template).
static func _looks(gi: GenIsland, id: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(gi.node["seed"]), 5121, id])
	var out: Array = []
	for c in TEMPLATES[id].get("contacts", []):
		var lk: Dictionary
		match str(c["look"]):
			"pirate":
				lk = PirateGrunt.crew_look(rng)
			"marine":
				lk = CharacterLook.random_look(rng)
				EnemyShip.marine_look(lk, rng, false)
			_:
				lk = IslandVillage._villager_look(rng)
		lk["name"] = LifePools.fill(str(c["name"]), {"n": CONTACT_NAMES[rng.randi() % CONTACT_NAMES.size()]})
		out.append(lk)
	return out


## The life step (IslandLife._setup, every machine, after every site and the outpost): the arc the island rolled, its
## contacts, its quest and its hooks on the elder and the board. null: none.
static func make(L: IslandLife, v: IslandVillage) -> IslandArcs:
	var gi := L.isl
	var id := pick(facts(gi, gi.get_node_or_null("MarineOutpost") != null))
	var planned: Dictionary = L.arc_plan
	L.arc_plan = {}
	var looks: Array = planned.get("looks", [])
	if planned.get("id", "") != id:
		for lk in looks:
			Humanoid.unstock(lk)
		looks = _looks(gi, id) if id != "" else []
	if id == "" or v == null:
		for lk in looks:
			Humanoid.unstock(lk)
		return null
	var a := IslandArcs.new()
	a.name = "Arc"
	a.isl = gi
	a.life = L
	a.village = v
	a.arc = id
	a.T = TEMPLATES[id]
	a.key = L.key("arc")
	gi.add_child(a)
	a._setup(looks)
	return a


func _setup(looks: Array) -> void:
	place = str(T["place"])
	var place_name := str(T["place_name"])
	if str(T["villain"]["kind"]) == "ghost" and str(isl.node["beast"]) != "ghost_captain":
		place = "camp"
		place_name = "the drowned crew's camp"
	_spots()
	villain_name = _villain_name()
	tok = {"villain": villain_name, "village": isl.island_name, "elder": village.elder_name, "place": place_name}
	for i in range(looks.size()):
		tok["c%d" % i] = str(looks[i]["name"])
	for i in range(looks.size()):
		_contact(i, looks[i])
	var t := IslandContent.tier(isl)
	var steps: Array = []
	for s in T["steps"]:
		steps.append({"do": s["do"], "goal": fill(s["goal"]), "said": fill(s["said"])})
	steps.append({"do": "villain", "goal": fill(T["showdown"]), "said": "%s is finished. Tell %s." % [villain_name, village.elder_name]})
	steps.append({"do": "turnin", "goal": "Tell %s it's over" % village.elder_name})
	def = {"id": key, "title": str(T["title"]), "giver": village.elder_name, "isle": isl.island_name, "pos": isl.position, "src": "arc",
		"steps": steps, "reward": {"gold": 50 + t * 25}}
	Journal.register(def, self)
	village.elder_hooks.append(_elder_talk)
	village.board_hooks.append(_poster)
	if flag("fell"):
		_chests(flag("hidden"))


func _ready() -> void:
	Dialogue.dialogue_event.connect(_on_event)


func fill(s) -> String:
	return LifePools.fill(str(s), tok)


func fill_all(a: Array) -> Array:
	return a.map(func(l): return fill(l))


## The island's places the arc uses (island space).
func _spots() -> void:
	var c: Vector2 = village.plaza["c"]
	spots["village"] = c
	for s in ["camp", "lair", "ruins", "summit", "boss", "dock"]:
		spots[s] = isl.sites[s]
	var camp: Vector2 = isl.sites["camp"]
	var to_v: Vector2 = (c - camp).normalized()
	spots["camp_edge"] = camp + to_v * 15.0 + Vector2(-to_v.y, to_v.x) * 4.0
	spots["road_camp"] = _along(camp, 0.5, 3.0)
	spots["tracks"] = _along(isl.sites["boss"], 0.45, 3.5)
	var path: PackedVector2Array = life._path_to(isl.sites["boss"])
	var cum := KitLife.measure(path)
	spots["village_edge"] = KitLife.sample(path, cum, minf(float(village.plaza["r"]) + EDGE, cum[cum.size() - 1] * 0.6))[0]
	for i in range(3):
		spots["witness%d" % i] = c + Vector2.from_angle(1.3 + i * 2.1) * (float(village.plaza["r"]) * 0.7 + 3.0)
	spots["dock_land"] = isl.sites["dock"] + (c - isl.sites["dock"]).normalized() * 10.0
	spots["summit_near"] = _along(isl.sites["summit"], 0.85, 3.0)
	spots["ruins_near"] = isl.sites["ruins"] + (c - isl.sites["ruins"]).normalized() * 10.0
	spots["lair_edge"] = isl.sites["lair"] + (c - isl.sites["lair"]).normalized() * 15.0
	var o := isl.get_node_or_null("MarineOutpost") as Node3D
	if o:
		var op := Vector2(o.position.x, o.position.z)
		var f: Vector2 = (c - op).normalized()
		spots["outpost_yard"] = op + f * 9.0
		spots["outpost_back"] = op - f * 4.5 + Vector2(-f.y, f.x) * 3.5
	if not isl.interiors.is_empty():
		var e: Dictionary = KitDungeons.poi(isl.interiors[0])
		spots["cave"] = (e["mouth"] as Vector2) + (e["mouth_dir"] as Vector2) * 5.0
		var ch: Dictionary = e["chambers"][mini(1, e["chambers"].size() - 1)]
		spots["cave_in"] = ch["c"]
		ys["cave_in"] = float(ch["y"])
	spots["more"] = spots[place] + (c - spots[place]).normalized() * 6.0
	if ys.has(place):
		ys["more"] = ys[place]


## A point `k` of the way along the village's path to `to`, `off` m to its side.
func _along(to: Vector2, k: float, off: float) -> Vector2:
	var path: PackedVector2Array = life._path_to(to)
	var cum := KitLife.measure(path)
	var smp := KitLife.sample(path, cum, cum[cum.size() - 1] * k)
	var d: Vector2 = smp[1]
	return smp[0] + Vector2(-d.y, d.x) * off


func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, isl.hv(p), p.y)


## A spot (by name) on its floor; `off` beside it on the same floor.
func _at(name_: String, off := Vector2.ZERO) -> Vector3:
	var p: Vector2 = spots[name_] + off
	return Vector3(p.x, float(ys[name_]) if ys.has(name_) else isl.hv(p), p.y)


func _villain_name() -> String:
	var V: Dictionary = T["villain"]
	match str(V["kind"]):
		"camp":
			return life._site_name("camp")
		"beast":
			return str(isl.node["beast_name"])
		"ghost":
			return str(isl.node["beast_name"]) if place == "boss" else life._site_name("camp")
		"queen":
			return "the Brood Queen"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([key, "villain"])
	return LifePools.fill(str(V["title"]), {"n": V["names"][rng.randi() % V["names"].size()]})


func _contact(i: int, lk: Dictionary) -> void:
	var c: Dictionary = T["contacts"][i]
	var p: Vector2 = spots[c["at"]]
	if c["at"] == "village":
		p += Vector2.from_angle(0.6 + i * 2.3) * (float(village.plaza["r"]) * 0.5 + 2.5)
	var face: Vector2 = (spots["village"] - p).normalized() if p.distance_to(spots["village"]) > 1.0 else Vector2(0, 1)
	var npc := NPC.new()
	npc.setup({"name": lk["name"], "look": lk, "dialogue": "%s_c%d" % [key, i], "voice": 0.95, "yaw": atan2(-face.x, -face.y)})
	npc.name = "Contact%d" % i
	npc.ground_func = isl.walk_height
	add_child(npc)
	npc.position = _v3(p)
	contacts.append(npc)
	var nodes := {"start": {"text": [fill(c["line"])], "choices": []}}
	var choices: Array = nodes["start"]["choices"]
	var m: Dictionary = T.get("moment", {})
	if not m.is_empty() and int(m["contact"]) == i:
		choices.append({"text": "About %s..." % villain_name, "next": "m", "if": func(): return Journal.step_of(key) == int(m["step"]) and not flag("moment")})
		nodes.merge(Replies.nodes(key + ":moment", "m", fill_all(m["lines"]), _replies(m)))
	for si in range(showdown()):
		var s: Dictionary = T["steps"][si]
		if str(s["do"]) == "talks" and (s["contacts"] as Array).has(i):
			choices.push_front({"text": "What did you see that night?", "next": "tell", "if": func(): return Journal.step_of(key) == si and not flag("told%d" % i)})
			nodes["tell"] = {"text": [fill(T["tells"][(s["contacts"] as Array).find(i)])], "event": "arc:%s:told:%d" % [key, i], "next": "start"}
	choices.append({"text": "Goodbye.", "next": "end"})
	Dialogue.define("%s_c%d" % [key, i], {"speaker": lk["name"], "voice": 0.95, "start": "start", "nodes": nodes})


## A moment's replies with their texts filled and any with a price offered only to a captain who has it.
func _replies(m: Dictionary) -> Array:
	var out: Array = []
	for r in m["replies"]:
		var e := {"tone": r["tone"], "text": fill(r["text"]), "answer": fill(r["answer"]), "out": r["out"]}
		if r.has("cost"):
			var cost := int(r["cost"])
			e["if"] = func(): return _gold() >= cost
		out.append(e)
	return out


func _gold() -> int:
	var me := get_tree().get_first_node_in_group("player") as Player
	return me.inventory_component.count("gold") if me else 0


# --------------------------------------------------------------------------
# Beat 1: the elder, the board, the folk
# --------------------------------------------------------------------------
func _elder_talk(choices: Array, nodes: Dictionary) -> void:
	choices.append({"text": "Something's wrong on this island. What is it?", "next": "arc_tell", "if": func(): return not Journal.has(key)})
	nodes["arc_tell"] = {"text": fill_all(T["elder"]), "choices": [
		{"text": "We'll deal with %s." % villain_name, "next": "arc_take"}, {"text": "Not our fight.", "next": "menu"}]}
	nodes["arc_take"] = {"text": ["Thank you, Captain. %s" % fill(T["remind"][0])], "event": "arc:%s:take" % key, "next": "menu"}
	choices.append({"text": "About %s..." % villain_name, "next": "arc_remind",
		"if": func(): return Journal.has(key) and not Journal.is_done(key) and not Journal.at_turnin(key)})
	nodes["arc_remind"] = {"text": fill_all(T["remind"]), "next": "menu"}
	choices.append({"text": "It's over. %s won't trouble you again." % villain_name, "next": "arc_pay", "if": func(): return Journal.at_turnin(key)})
	nodes["arc_pay"] = {"text": fill_all(T["thanks"]) + ["(%s)" % QuestRewards.text(def["reward"])], "event": "arc:%s:pay" % key, "next": "menu"}


func _poster(choices: Array, nodes: Dictionary) -> void:
	choices.append({"text": "WANTED: %s" % villain_name, "next": "arc_poster", "if": func(): return not Journal.has(key)})
	nodes["arc_poster"] = {"text": [fill(T["poster"]), "You tear the poster down and pocket it."], "event": "arc:%s:take" % key, "next": "end"}


## What the island's folk say of it (IslandLife deals them out).
func rumours() -> Array:
	return fill_all(T["rumours"])


# --------------------------------------------------------------------------
# State
# --------------------------------------------------------------------------
func flag(f: String) -> bool:
	return GameManager.world_flags.has("%s_%s" % [key, f])


func set_flag(f: String) -> void:
	Net.world_flag("%s_%s" % [key, f])


## The reply picked at moment `m` (-1: not yet).
func picked(m: String) -> int:
	var n: int = (T[m]["replies"] as Array).size()
	for i in range(n):
		if flag("%s_%d" % [m, i]):
			return i
	return -1


## Every outcome of the replies picked so far.
func outs() -> Array:
	var out: Array = []
	for m in ["meet", "moment"]:
		if T.has(m) and picked(m) >= 0:
			out.append_array(T[m]["replies"][picked(m)]["out"])
	return out


func _out_k(name_: String) -> float:
	var k := 0.0
	for o in outs():
		if str(o).begins_with(name_ + ":"):
			k += float(str(o).get_slice(":", 1))
	return k


func showdown() -> int:
	return (T["steps"] as Array).size()


func _night() -> bool:
	var h: float = Weather.hour()
	return h >= NIGHT_FROM or h < NIGHT_TO


# --------------------------------------------------------------------------
# The villain
# --------------------------------------------------------------------------
func villain() -> Node3D:
	match str(T["villain"]["kind"]):
		"camp", "squad", "ghost":
			var camp := _villain_camp()
			if camp:
				for g in camp.grunts:
					if is_instance_valid(g) and (g as PirateGrunt).captain:
						return g
			if place == "boss":
				var a := BeastArena.of(isl)
				if a.boss and is_instance_valid(a.boss):
					return a.boss
		"beast":
			var a := BeastArena.of(isl)
			if a.boss and is_instance_valid(a.boss):
				return a.boss
		"queen":
			return get_node_or_null("Queen") as Node3D
	return null


## The crew the villain leads: the island's camp, or the arc's own.
func _villain_camp() -> GruntCamp:
	match str(T["villain"]["kind"]):
		"squad":
			return get_node_or_null("Villain") as GruntCamp
		"camp":
			return isl.site_node("camp").get_node_or_null("Camp") as GruntCamp
		"ghost":
			if place == "camp":
				return isl.site_node("camp").get_node_or_null("Camp") as GruntCamp
	return null


## The villain's men (his crew, the captain left out).
func men() -> Array:
	var camp := _villain_camp()
	return camp.grunts.filter(func(g): return is_instance_valid(g) and not (g as PirateGrunt).captain) if camp else []


func _alive(n) -> bool:
	return n != null and is_instance_valid(n) and not n.is_dead()


func villain_at() -> Vector3:
	var v := villain()
	return v.global_position if v else to_global(_at(place))


# --------------------------------------------------------------------------
# The world for the state it's in (every machine): squads, waves, things to take
# --------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t -= delta
	_fight_t += delta
	_ask_t += delta
	if _poison >= 0.0:
		_poison_tick(delta)
	if _t > 0.0:
		return
	_t = TICK
	if not Journal.has(key) or Journal.is_done(key):
		return
	var step := Journal.step_of(key)
	var n := showdown()
	if step < n:
		var s: Dictionary = T["steps"][step]
		match str(s["do"]):
			"squad":
				_ensure_squad("S%d" % step, str(s["at"]), int(s["men"]), str(s["look"]), {"duel": s.get("duel", false)})
			"wave":
				if _night() or flag("w%d" % step):
					_ensure_wave("W%d" % step, str(s["at"]), int(s["bugs"]))
			"pickup":
				_ensure_item("Item%d" % step, _at(str(s["at"])), str(s["search"]), func(): Journal.advance(key, step))
			"pieces":
				for k in range((s["at"] as Array).size()):
					var pk: int = k
					_ensure_item("Piece%d" % k, _at(str(s["at"][k])), str(s["search"]), func(): Net.arc_ask(Net.key_of(self), "piece", [pk]), Props.sack_mesh())
			"reach":
				var me := get_tree().get_first_node_in_group("player") as Node3D
				if me and me.global_position.distance_to(to_global(_at(str(s["at"])))) < float(s["r"]):
					Journal.advance(key, step)
			"escort":
				_escort(contacts[int(s["contact"])])
	elif step == n and not flag("fell"):
		match str(T["villain"]["kind"]):
			"squad":
				var V: Dictionary = T["villain"]
				_ensure_squad("Villain", str(V["at"]), int(V["men"]), str(V["look"]), {"captain": villain_name})
			"queen":
				_ensure_queen()
		if outs().has("raid") and not flag("raid_done") and (_night() or flag("raid_on")):
			_ensure_squad("Raid", "village_edge", 4, "pirate")
		if outs().has("more"):
			_ensure_squad("More", "more", 2, "marine" if str(T["villain"].get("look", "")) == "marine" else "pirate")
		if outs().has("allies"):
			_ensure_militia()
		_follow_fight()
		_fair_watch()
		if _turncoats():
			for g in men():
				if _alive(g):
					(g as Node).queue_free()
	_show_props(step)
	if Net.is_host():
		_host(step)


## Things to take shown while their step is on (and not yet taken); lanterns once they're asked for, lit or out.
func _show_props(step: int) -> void:
	for i in range(get_child_count()):
		var it := get_child(i) as Node3D
		if it == null:
			continue
		if it.name.begins_with("Item"):
			it.visible = step == int(str(it.name).substr(4))
			(it.get_node("Take") as Interactable).enabled = it.visible
		elif it.name.begins_with("Piece"):
			it.visible = not flag("p%s" % str(it.name).substr(5))
			(it.get_node("Take") as Interactable).enabled = it.visible
	for si in range(showdown()):
		var s: Dictionary = T["steps"][si]
		if str(s["do"]) == "light" and step >= si:
			for k in range(int(s["n"])):
				_lantern(k)
		# (brought home before this session: the castaway waits in the village)
		if str(s["do"]) == "escort" and step > si:
			var npc: NPC = contacts[int(s["contact"])]
			if npc.position.distance_to(_v3(spots["village"])) > 30.0 and not (step == showdown() and _alive(villain()) and villain().in_combat()):
				npc.waypoints = []
				npc.position = _v3(spots["village"] + Vector2(2.5, 2.5))
	for k in range(militia.size()):
		if flag("fallen%d" % k) and is_instance_valid(militia[k]) and (militia[k] as Node3D).visible:
			(militia[k] as Node3D).visible = false
			(militia[k] as NPC).interactable.enabled = false
			get_tree().call_group("hud", "show_toast", "%s has fallen!" % (militia[k] as NPC).npc_name)


func _ensure_squad(tag: String, at: String, n: int, look: String, opts: Dictionary = {}) -> void:
	if has_node(tag):
		return
	var camp := GruntCamp.new()
	camp.name = tag
	camp.level = IslandContent.level(isl)
	camp.respawn_time = 1.0e9
	camp.warm_start = true
	if opts.get("duel", false):
		camp.max_attackers = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([key, tag])
	var c: Vector2 = spots[at]
	var face: Vector2 = (spots["village"] - c).normalized() if c.distance_to(spots["village"]) > 1.0 else Vector2(0, 1)
	var yaw := atan2(-face.x, -face.y)
	for i in range(n):
		var cfg := {"post": _at(at, Vector2.from_angle(TAU * i / n + 0.4) * (2.4 + (i % 2) * 1.2)), "yaw": yaw, "mode": "stand",
			"seed": hash([key, tag, i]), "role": "rifle" if n > 2 and i == n - 1 else "sword"}
		if look == "marine":
			var lk: Dictionary = CharacterLook.random_look(rng)
			EnemyShip.marine_look(lk, rng, false)
			cfg["look"] = lk
		camp.add_grunt(IslandContent.undead(isl, cfg, i) if look == "pirate" else cfg)
	if opts.has("captain"):
		var cap := {"post": _at(at), "yaw": yaw, "mode": "stand", "seed": hash([key, tag, "captain"]), "captain": true, "title": str(opts["captain"])}
		var lk: Dictionary = PirateGrunt.crew_look(rng)
		if look == "marine":
			lk = CharacterLook.random_look(rng)
			EnemyShip.marine_look(lk, rng, true)
		else:
			var C := CharacterLook.CLOTH
			lk.merge({"build": "broad", "height": 1.08, "hat": ["tricorn", "bicorne", "bandana"][rng.randi() % 3], "coat": "longcoat",
				"coat_color": C[rng.randi() % C.size()]}, true)
		lk["name"] = str(opts["captain"])
		cap["look"] = lk
		camp.add_grunt(cap)
	add_child(camp)


func _ensure_wave(tag: String, at: String, n: int) -> void:
	if has_node(tag):
		return
	var nest := ScuttlebugNest.new()
	nest.name = tag
	nest.level = IslandContent.level(isl)
	nest.respawn_time = 1.0e9
	for i in range(n):
		nest.add_spot(_at(at, Vector2.from_angle(TAU * i / n) * 5.0), i == 0)
	add_child(nest)


func _ensure_item(nm: String, at: Vector3, prompt: String, take: Callable, mesh: Mesh = null) -> void:
	if has_node(nm):
		return
	var n := Node3D.new()
	n.name = nm
	var mi := MeshInstance3D.new()
	mi.mesh = mesh if mesh else Props.treasure_chest_mesh()
	mi.scale = Vector3.ONE * (0.8 if mesh == null else 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 120.0
	n.add_child(mi)
	var it := Interactable.new()
	it.name = "Take"
	it.collision_layer = NPC.INTERACT_LAYER
	it.collision_mask = 0
	it.prompt_text = prompt
	it.gesture = "pickup"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.4
	cs.shape = sph
	cs.position = Vector3(0, 0.5, 0)
	it.add_child(cs)
	n.add_child(it)
	it.interacted.connect(func(_p): take.call())
	add_child(n)
	n.position = at
	n.rotation.y = atan2(at.x - spots["village"].x, at.z - spots["village"].y)


## A festival lantern round the showdown's place: lit once its flag is set, unless the ghost has put it out.
func _lantern(k: int) -> void:
	var nm := "Lantern%d" % k
	var l := get_node_or_null(nm) as Node3D
	if l == null:
		l = Node3D.new()
		l.name = nm
		var mb := MeshBuilder.new()
		var iron := PSXMat.flat(Color(0.12, 0.12, 0.13))
		mb.add_box(iron, Transform3D(Basis(), Vector3(0, 1.2, 0)), Vector3(0.12, 2.4, 0.12))
		mb.add_box(iron, Transform3D(Basis(), Vector3(0, 0.08, 0)), Vector3(0.36, 0.16, 0.36))
		var post := mb.to_instance("Post")
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		post.visibility_range_end = 200.0
		l.add_child(post)
		var glass := MeshInstance3D.new()
		glass.name = "Glass"
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 0.4, 0.3)
		glass.mesh = bm
		glass.position = Vector3(0, 2.6, 0)
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glass.visibility_range_end = 300.0
		l.add_child(glass)
		var it := Interactable.new()
		it.name = "Take"
		it.collision_layer = NPC.INTERACT_LAYER
		it.collision_mask = 0
		it.prompt_text = "Light the festival lantern"
		it.gesture = "reach"
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 1.4
		cs.shape = sph
		cs.position = Vector3(0, 1.2, 0)
		it.add_child(cs)
		l.add_child(it)
		it.interacted.connect(func(_p): Net.arc_ask(Net.key_of(self), "light", [k]))
		add_child(l)
		l.position = _at(place, Vector2.from_angle(TAU * k / 4.0 + 0.3) * LANTERN_R)
	var lit := lantern_lit(k)
	(l.get_node("Glass") as MeshInstance3D).material_override = PSXMat.glow(Color(1.0, 0.76, 0.42), 2.2) if lit else PSXMat.flat(Color(0.1, 0.12, 0.12))
	(l.get_node("Take") as Interactable).enabled = not lit


## Iron Boot: met with the ledger in hand, and not bought off: his marines have left him.
func _turncoats() -> bool:
	return str(T["hidden"]["kind"]) == "ledger" and flag("meet") and not outs().has("now") and not outs().has("settle")


func lantern_lit(k: int) -> bool:
	return flag("l%d" % k) and not _snuffed.get(k, false)


## The castaway follows the nearest captain while it's on (each machine moves its own copy; the host judges it home).
func _escort(npc: NPC) -> void:
	var best: Node3D = null
	for p in Net.all_players():
		if best == null or (p as Node3D).global_position.distance_to(npc.global_position) < best.global_position.distance_to(npc.global_position):
			best = p
	if best:
		npc.waypoints = [to_local(best.global_position)]
		npc.walk_speed = 4.2


## In the showdown: the castaway and the militia close on the villain once he fights; the castaway's blow lands within BLOW_R.
func _follow_fight() -> void:
	var v := villain()
	if not _alive(v) or not v.in_combat():
		return
	var at := to_local(v.global_position)
	var followers: Array = militia.duplicate()
	if str(T["hidden"]["kind"]) == "noble_blow":
		followers.append(contacts[0])
	for f in followers:
		var npc := f as NPC
		if is_instance_valid(npc) and npc.visible:
			npc.waypoints = [at + (npc.position - at).normalized() * 2.2]
			npc.walk_speed = 3.2


## Champion's fair fight: this captain's own techniques and skills near him break it (told to the host once).
func _fair_watch() -> void:
	if _foul_sent or not outs().has("fair") or flag("foul"):
		return
	var me := get_tree().get_first_node_in_group("player") as Player
	if me and me.current_state_name() in ["Technique", "Skill"] and me.global_position.distance_to(villain_at()) < 30.0:
		_foul_sent = true
		Net.arc_ask(Net.key_of(self), "foul", [])


## The villagers who march with the Rebellion, by the outpost's yard (every machine, the same bodies and names).
func _ensure_militia() -> void:
	if not militia.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([key, "militia"])
	for k in range(MILITIA):
		var lk := IslandVillage._villager_look(rng)
		lk["name"] = "Rebel %s" % CONTACT_NAMES[(k * 3 + 1) % CONTACT_NAMES.size()]
		var npc := NPC.new()
		npc.setup({"name": lk["name"], "look": lk, "barks": ["For {v}!".replace("{v}", isl.island_name), "Stay together!", "Now! Now!"], "voice": 1.0})
		npc.name = "Militia%d" % k
		npc.ground_func = isl.walk_height
		add_child(npc)
		npc.position = _at("more", Vector2.from_angle(TAU * k / MILITIA) * 2.0)
		npc.visible = not flag("fallen%d" % k)
		militia.append(npc)


## The brood queen on the burrows, asleep until a captain comes close (her brood answers her shriek).
func _ensure_queen() -> void:
	if has_node("Queen"):
		return
	var nest := ScuttlebugNest.new()
	nest.name = "Brood"
	nest.level = IslandContent.level(isl)
	nest.start_empty = true
	nest.respawn_time = 1.0e9
	for i in range(4):
		nest.add_spot(_at(place, Vector2.from_angle(TAU * i / 4.0) * 7.0))
	add_child(nest)
	var at := to_global(_at(place, (spots["village"] - spots[place]).normalized() * 6.0))
	var q := BroodQueen.new().queen(at)
	q.name = "Queen"
	q.cave = self
	q.level = IslandContent.level(isl)
	add_child(q)
	q.global_position = at + Vector3.UP * 0.4
	q.reset_physics_interpolation()


## (BroodQueen's cave) her brood.
func call_brood() -> void:
	(get_node("Brood") as ScuttlebugNest).call_out()


func brood_alive() -> int:
	return (get_node("Brood") as ScuttlebugNest).alive_count()


## The Poisoned Well's clock on this screen: a toast as it runs down.
func _poison_tick(delta: float) -> void:
	var before := _poison
	_poison -= delta
	for mark in [60.0, 30.0, 10.0]:
		if before > mark and _poison <= mark:
			get_tree().call_group("hud", "show_toast", "The poison spreads: %d seconds to kill the queen." % int(mark))
	if _poison <= 0.0:
		_poison = -1.0
		get_tree().call_group("hud", "show_toast", "The poison has spread. Kill her anyway!")


## Cleared once all of it has turned up (a warm-started squad musters over a few frames) and all of it is down.
func _cleared(tag: String) -> bool:
	var n := get_node_or_null(tag)
	if n is GruntCamp:
		return (n as GruntCamp).grunts.size() == (n as GruntCamp).specs.size() and (n as GruntCamp).alive_count() == 0
	if n is ScuttlebugNest:
		return (n as ScuttlebugNest).spots.all(func(s): return s["bug"] != null) and (n as ScuttlebugNest).alive_count() == 0
	return false


# --------------------------------------------------------------------------
# The host's decisions
# --------------------------------------------------------------------------
func _host(step: int) -> void:
	var n := showdown()
	_race(step)
	if step < n:
		var s: Dictionary = T["steps"][step]
		match str(s["do"]):
			"squad":
				if _cleared("S%d" % step):
					Journal.advance(key, step)
			"wave":
				if _night() and not flag("w%d" % step):
					set_flag("w%d" % step)
				if _cleared("W%d" % step):
					Journal.advance(key, step)
			"talks":
				if (s["contacts"] as Array).all(func(i): return flag("told%d" % i)):
					Journal.advance(key, step)
			"pieces":
				if range((s["at"] as Array).size()).all(func(k): return flag("p%d" % k)):
					Journal.advance(key, step)
			"light":
				if range(int(s["n"])).all(func(k): return flag("l%d" % k)):
					Journal.advance(key, step)
			"escort":
				if contacts[int(s["contact"])].position.distance_to(_v3(spots["village"])) < 14.0:
					Journal.advance(key, step)
		return
	if step != n:
		return
	if outs().has("raid") and not flag("raid_done"):
		if _night() and not flag("raid_on"):
			set_flag("raid_on")
		if _cleared("Raid"):
			set_flag("raid_done")
	var v := villain()
	if v == null:
		# (a crew's captain already beaten and his body gone: he counts as fallen, as a Journal clear does)
		var camp := _villain_camp()
		if camp and camp.grunts.size() == camp.specs.size() and not flag("fell"):
			_fall(null)
		return
	if not _alive(v):
		if not flag("fell"):
			_fall(v)
		return
	_watch(v)
	if T.has("meet") and not flag("meet") and _hp(v) >= 0.999:
		_meet(v)
	if v is BroodQueen:
		_queen_host(v as BroodQueen)


## Treasure Race: the reach step's clock (the host's), its result kept as a flag ("first" in time, else "late").
func _race(step: int) -> void:
	for si in range(showdown()):
		var s: Dictionary = T["steps"][si]
		if str(s["do"]) != "reach" or not s.has("race"):
			continue
		if step == si and _race_from < 0.0:
			_race_from = _fight_t
		elif step > si and _race_from >= 0.0 and not flag("first") and not flag("late"):
			set_flag("first" if _fight_t - _race_from <= float(s["race"]) + _out_k("slow") else "late")


## The queen wakes for a captain close by, and goes back to her eggs once everyone's gone a while.
func _queen_host(q: BroodQueen) -> void:
	var near := 99999.0
	for p in Net.all_players():
		near = minf(near, (p as Node3D).global_position.distance_to(q.global_position))
	if near < 20.0:
		q.wake()
	_empty_t = 0.0 if near < 50.0 else _empty_t + TICK
	if _empty_t > 8.0 and q.in_combat():
		_empty_t = 0.0
		q.reset_fight()


func _hp(v: Node3D) -> float:
	var h = v.get("health")
	return (h as HealthComponent).current_health / maxf((h as HealthComponent).max_health, 1.0) if h is HealthComponent else 1.0


## The villain's first meeting: the nearest standing captain is spoken to (their machine shows the replies).
func _meet(v: Node3D) -> void:
	if _asking != 0 and _ask_t < ASK_WAIT:
		return
	var best: Node3D = null
	var r := float(T.get("meet_r", MEET_R))
	for p in Net.all_players():
		var pp := p as Node3D
		if pp.global_position.distance_to(v.global_position) < r and p.is_standing() \
				and (best == null or pp.global_position.distance_to(v.global_position) < best.global_position.distance_to(v.global_position)):
			best = pp
	if best == null:
		return
	_asking = _peer_of(best)
	_ask_t = 0.0
	Net.everyone("_all_arc", [Net.key_of(self), "ask", ["meet", _asking]])


func _peer_of(p: Node) -> int:
	for id in Net.players.keys():
		if Net.players[id] == p:
			return int(id)
	return Net.my_id()


func _name_of(peer: int) -> String:
	var p = Net.players.get(peer) if Net.active else get_tree().get_first_node_in_group("player")
	return p.display_name() if p and is_instance_valid(p) else "A captain"


## What the host watches in the showdown for the hidden finish, and the wound a reply dealt (once per villain body).
func _watch(v: Node3D) -> void:
	if _men0 < 0:
		_men0 = men().filter(func(g): return _alive(g)).size()
	var hp := _hp(v)
	if hp < 0.999 and not _spotted:
		_sneak = true
	if v.in_combat() and hp >= 0.999:
		_spotted = true
	match str(T["hidden"]["kind"]):
		"lanterns":
			_snuff_t += TICK
			if v.in_combat() and _snuff_t >= SNUFF_EVERY:
				_snuff_t = 0.0
				var lit: Array = range(4).filter(func(k): return lantern_lit(k))
				if not lit.is_empty():
					Net.everyone("_all_arc", [Net.key_of(self), "snuff", [lit[randi() % lit.size()]]])
		"no_fall":
			for k in range(militia.size()):
				var npc := militia[k] as Node3D
				if flag("fallen%d" % k) or not is_instance_valid(npc):
					continue
				var close := men().any(func(g): return _alive(g) and (g as Node3D).global_position.distance_to(npc.global_position) < 2.5) \
					or v.global_position.distance_to(npc.global_position) < 2.5
				_peril[k] = float(_peril.get(k, 0.0)) + TICK if close else maxf(float(_peril.get(k, 0.0)) - TICK * 0.5, 0.0)
				if _peril[k] >= MILITIA_FALL:
					set_flag("fallen%d" % k)
		"noble_blow":
			var noble := contacts[0] as Node3D
			if not flag("blow") and v.in_combat() and noble.global_position.distance_to(v.global_position) < BLOW_R:
				set_flag("blow")
				var h = v.get("health")
				if h is HealthComponent:
					(h as HealthComponent).take_damage((h as HealthComponent).max_health * BLOW)
				Net.fx("sparkle", [v.global_position + Vector3.UP * 1.2, 16, Color(1.0, 0.9, 0.6)])
				Net.everyone("_all_arc", [Net.key_of(self), "blow", []])
	if v.in_combat():
		if _woke_t < 0.0:
			_woke_t = _fight_t
			if str(T["hidden"]["kind"]) == "timer":
				Net.everyone("_all_arc", [Net.key_of(self), "poison", [POISON]])
		var k := _out_k("wounded")
		if k > 0.0 and not _wounded.has(v.get_instance_id()):
			_wounded.append(v.get_instance_id())
			var h = v.get("health")
			if h is HealthComponent:
				(h as HealthComponent).take_damage((h as HealthComponent).max_health * k)


func _hidden_met(v: Node3D) -> bool:
	match str(T["hidden"]["kind"]):
		"spare_men":
			return _men0 > 0 and men().filter(func(g): return _alive(g)).size() >= _men0
		"parts":
			if v.has_method("parts_broken"):
				return int(v.parts_broken()) >= 2
			return _woke_t >= 0.0 and _fight_t - _woke_t <= QUICK_KILL
		"ledger":
			return not outs().has("now") and not outs().has("settle")
		"unseen":
			return _sneak
		"lanterns":
			return range(4).all(func(k): return lantern_lit(k))
		"no_fall":
			return outs().has("allies") and range(MILITIA).all(func(k): return not flag("fallen%d" % k))
		"noble_blow":
			return flag("blow")
		"timer":
			return _woke_t >= 0.0 and _fight_t - _woke_t <= POISON
		"fair":
			return outs().has("fair") and not flag("foul")
		"first":
			return flag("first")
	return false


## (host) The villain is down: the arc's chest (and the hidden cache) on every screen, the bounty, the Admiralty.
func _fall(v: Node3D) -> void:
	var hidden := v != null and Journal.step_of(key) == showdown() and _men0 >= 0 and _hidden_met(v)
	set_flag("fell")
	if hidden:
		set_flag("hidden")
	var at := villain_at()
	Net.everyone("_all_arc", [Net.key_of(self), "fell", [hidden]])
	Net.bounty("arc", at, 400.0)
	Admiralty.deed(get_tree(), at, "arc")
	Journal.advance(key, showdown())


# --------------------------------------------------------------------------
# This captain's own part: their dialogue's events, a meeting asked of them
# --------------------------------------------------------------------------
func _on_event(ev: String) -> void:
	if ev.begins_with("arc:%s:" % key):
		match ev.get_slice(":", 2):
			"take":
				Journal.take(key)
			"pay":
				Journal.turn_in(key, (get_tree().get_first_node_in_group("player") as Node3D).global_position)
			"told":
				Net.arc_ask(Net.key_of(self), "told", [int(ev.get_slice(":", 3))])
	elif ev.begins_with("%s%s:" % [Replies.EVENT, key]):
		var parts := ev.split(":")
		Net.arc_ask(Net.key_of(self), "reply", [parts[2], int(parts[3])])


## (host) A captain's word: their reply at a moment ([moment, index]; -1 walked away), or that they couldn't be asked.
func decide(op: String, args: Array, by: int) -> void:
	match op:
		"busy":
			_asking = 0
		"told":
			set_flag("told%d" % int(args[0]))
		"piece":
			if not flag("p%d" % int(args[0])):
				set_flag("p%d" % int(args[0]))
				Net.everyone("_all_arc", [Net.key_of(self), "toast", ["Map piece found (%d of 3)." % (range(3).filter(func(k): return flag("p%d" % k)).size())]])
		"light":
			var k := int(args[0])
			if not flag("l%d" % k):
				set_flag("l%d" % k)
				Net.fx("sparkle", [to_global(_at(place, Vector2.from_angle(TAU * k / 4.0 + 0.3) * LANTERN_R)) + Vector3.UP * 2.6, 14, Color(1.0, 0.76, 0.42)])
			elif _snuffed.get(k, false):
				Net.everyone("_all_arc", [Net.key_of(self), "relit", [k]])
		"foul":
			if not flag("foul"):
				set_flag("foul")
				Net.everyone("_all_arc", [Net.key_of(self), "toast", ["%s: \"Tricks! So that's how you fight.\"" % villain_name]])
		"reply":
			var m := str(args[0])
			if not T.has(m) or flag(m):
				return
			var i := int(args[1])
			if i < 0:
				i = int(T[m].get("default", 0))
			if Journal.step_of(key) != (showdown() if m == "meet" else int(T["moment"]["step"])):
				return
			set_flag(m)
			set_flag("%s_%d" % [m, i])
			_asking = 0
			Net.everyone("_all_arc", [Net.key_of(self), "replied", [m, i, _name_of(by)]])
			_outcome(T[m]["replies"][i]["out"], by)


## (host) What a reply does at once (the lasting effects are read from the flags: outs()).
func _outcome(out: Array, by: int) -> void:
	var step := Journal.step_of(key)
	for o in out:
		var s := str(o)
		match s.get_slice(":", 0):
			"pay":
				Net.everyone("_all_arc", [Net.key_of(self), "pay", [by, int(s.get_slice(":", 1))]])
			"gain":
				Net.everyone("_all_arc", [Net.key_of(self), "pay", [by, -int(s.get_slice(":", 1))]])
			"settle":
				set_flag("settled")
				Journal.settle(key)
			"hated":
				Net.everyone("_all_arc", [Net.key_of(self), "hated", []])
			"step":
				Journal.advance(key, step)
			"now":
				Journal.jump(key, step, showdown())
			"fight":
				var v := villain()
				if _alive(v):
					v.alert(0.0)


## (every machine) What the host decided.
func apply(op: String, args: Array) -> void:
	match op:
		"ask":
			if int(args[1]) == Net.my_id():
				var v := villain()
				var m: Dictionary = T[str(args[0])]
				if not Replies.open(Dialogue, "%s:%s" % [key, args[0]], villain_name, 0.85, fill_all(m["lines"]), _replies(m), v):
					Net.arc_ask(Net.key_of(self), "busy", [])
		"replied":
			var m := str(args[0])
			var r: Dictionary = _replies(T[m])[int(args[1])]
			var speaker := villain_name if m == "meet" else str(contacts[int(T[m]["contact"])].npc_name)
			var who: Node = villain() if m == "meet" else contacts[int(T[m]["contact"])]
			Replies.shown(get_tree(), str(args[2]), r, speaker, who)
			# Iron Boot: the ledger in hand, his own marines turn from him at the meeting
			if m == "meet" and _turncoats():
				get_tree().call_group("hud", "show_toast", "His marines read the ledger... and lower their muskets. He stands alone.")
		"pay":
			var me := get_tree().get_first_node_in_group("player") as Player
			if int(args[0]) == Net.my_id() and me:
				var n := int(args[1])
				if n >= 0:
					me.inventory_component.remove_item(ItemDB.get_item("gold"), n)
				else:
					me.inventory_component.add_item(ItemDB.get_item("gold"), -n)
		"toast":
			get_tree().call_group("hud", "show_toast", str(args[0]))
		"snuff":
			_snuffed[int(args[0])] = true
			get_tree().call_group("hud", "show_toast", "%s snuffs a lantern! Light it again." % villain_name)
		"relit":
			_snuffed.erase(int(args[0]))
		"blow":
			get_tree().call_group("hud", "show_toast", "%s lands a blow on %s!" % [contacts[0].npc_name, villain_name])
		"poison":
			_poison = float(args[0])
			get_tree().call_group("hud", "show_toast", "The poison spreads: %d seconds to kill the queen." % int(_poison))
		"hated":
			for sid in Shops.extra.keys():
				if str(sid).begins_with(life.key("shop")) or sid == isl.save_key("trader"):
					Journal.perks["discount:" + str(sid)] = -0.2
			get_tree().call_group("hud", "show_toast", "%s won't forget that you paid %s. Prices here just went up." % [isl.island_name, villain_name])
		"fell":
			var hidden: bool = args[0]
			get_tree().call_group("hud", "show_banner", "%s: %s falls!" % [T["title"], villain_name],
				("Hidden finish: %s. %s" % [T["hidden"]["name"], T["hidden"]["said"]]) if hidden else "Tell %s it's over." % village.elder_name, true)
			# an arc villain is worth 2 Will (WillPaths "villain"), each captain near on their own machine; a beast or the queen
			# already pays its "boss" share through its own Net.bounty
			var me := get_tree().get_first_node_in_group("player") as Player
			if me and not (str(T["villain"]["kind"]) in ["beast", "queen"] or place == "boss") and me.global_position.distance_to(villain_at()) < 400.0:
				me.progression.will_deed("villain")
			if hidden and str(T["hidden"]["kind"]) == "spare_men":
				for g in men():
					if _alive(g):
						(g as Node).queue_free()
			_chests(hidden)


## The arc's chest by the showdown's place (and the hidden finish's cache), each once per character.
func _chests(hidden: bool) -> void:
	var t := IslandContent.tier(isl)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([key, "chest"])
	var off: Vector2 = (spots["village"] - spots[place]).normalized() * 4.0
	var at: Vector2 = spots[place] + off
	if not GameManager.opened.has(isl.save_key("arc_chest")) and not has_node("ArcChest"):
		var bag := isl.strongbox(self, at, 0.0, "arc_chest", [["gold", 80 + t * 40], ["treasure", 3 + t], ["rum", 2],
			[Loot.weapon(WEAPONS[rng.randi() % WEAPONS.size()], mini(t + 1, 5), rng), 1]], 1.3)
		bag.name = "ArcChest"
		if ys.has(place):
			bag.position = _at(place, off)
		FX.sparkle(bag.global_position + Vector3(0, 0.9, 0), 24, Color(1.0, 0.85, 0.4))
	if hidden and not GameManager.opened.has(isl.save_key("arc_cache")) and not has_node("ArcCache"):
		var cache := isl.strongbox(self, at + Vector2(2.2, 0.0), 0.0, "arc_cache", [["gold", 120 + t * 60], ["pearl", 2 + t],
			[Loot.weapon(WEAPONS[rng.randi() % WEAPONS.size()], mini(t + 2, 5), rng), 1]], 1.0)
		cache.name = "ArcCache"
		if ys.has(place):
			cache.position = _at(place, off + Vector2(2.2, 0.0))
		FX.sparkle(cache.global_position + Vector3(0, 0.9, 0), 30, Color(0.7, 0.9, 1.0))


# --------------------------------------------------------------------------
# The Journal's source: where each step is, and the showdown told as it stands
# --------------------------------------------------------------------------
func target(_q: Dictionary, step: int) -> Vector3:
	var n := showdown()
	if step < n:
		var s: Dictionary = T["steps"][step]
		match str(s["do"]):
			"talk":
				return contacts[int(s["contact"])].global_position + Vector3.UP * KitQuests.HEAD
			"talks":
				return _nearest((s["contacts"] as Array).filter(func(i): return not flag("told%d" % i)).map(
					func(i): return contacts[i].global_position + Vector3.UP * KitQuests.HEAD))
			"pieces":
				return _nearest(range((s["at"] as Array).size()).filter(func(k): return not flag("p%d" % k)).map(
					func(k): return to_global(_at(str(s["at"][k]))) + Vector3.UP))
			"light":
				return _nearest(range(int(s["n"])).filter(func(k): return not flag("l%d" % k)).map(
					func(k): return to_global(_at(place, Vector2.from_angle(TAU * k / 4.0 + 0.3) * LANTERN_R)) + Vector3.UP * 2.6))
			"escort":
				return to_global(_v3(spots["village"]) + Vector3.UP * 1.5)
		return to_global(_at(str(s["at"])) + Vector3.UP * 1.5)
	if step == n:
		if outs().has("raid") and not flag("raid_done"):
			return to_global(_at("village_edge") + Vector3.UP * 1.5)
		var out: Array = range(4).filter(func(k): return flag("l%d" % k) and not lantern_lit(k))
		if not out.is_empty():
			return to_global(_at(place, Vector2.from_angle(TAU * int(out[0]) / 4.0 + 0.3) * LANTERN_R)) + Vector3.UP * 2.6
		return villain_at() + Vector3.UP * 2.0
	for p in get_tree().get_nodes_in_group("npcs"):
		if (p as NPC).npc_name == village.elder_name:
			return (p as Node3D).global_position + Vector3.UP * KitQuests.HEAD
	return Vector3.INF


func is_person(q: Dictionary, step: int) -> bool:
	return q["steps"][step]["do"] in ["talk", "talks", "turnin"]


## The nearest to the local captain of `points` (world).
func _nearest(points: Array) -> Vector3:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	var best := Vector3.INF
	for p in points:
		if best == Vector3.INF or (me and (p as Vector3).distance_to(me.global_position) < best.distance_to(me.global_position)):
			best = p
	return best


func progress(_q: Dictionary, step: int) -> String:
	if step >= showdown():
		return ""
	var s: Dictionary = T["steps"][step]
	match str(s["do"]):
		"talks":
			return " (%d/%d)" % [(s["contacts"] as Array).filter(func(i): return flag("told%d" % i)).size(), (s["contacts"] as Array).size()]
		"pieces":
			return " (%d/%d)" % [range((s["at"] as Array).size()).filter(func(k): return flag("p%d" % k)).size(), (s["at"] as Array).size()]
		"light":
			return " (%d/%d)" % [range(int(s["n"])).filter(func(k): return flag("l%d" % k)).size(), int(s["n"])]
	return ""


func goal_of(_q: Dictionary, step: int, g: String) -> String:
	var n := showdown()
	if step < n and str(T["steps"][step]["do"]) == "wave" and not _night() and not flag("w%d" % step):
		return g + " (it comes at nightfall)"
	if step == n and outs().has("raid") and not flag("raid_done"):
		return "Hold %s against %s's raid%s, then %s" % [isl.island_name, villain_name, "" if _night() or flag("raid_on") else " tonight", g.to_lower()]
	return g
