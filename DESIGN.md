# Miniquest — Design Document (v0.1)

Status: agreed in session on 2026-07-27. Art direction (sections 5.6 and 9)
revised on 2026-09-28 to match the hero assets already drawn. Run structure,
difficulty and rewards (sections 3, 4, 6.3, 6.5, 6.6) revised on 2026-10-10:
fixed-length runs with a win, a level-shifted ramp, and banked rewards.

## 1. Concept

A persistent hero, built up over many short run-based quests. Quests are the
action layer; the hub is the build layer. You never lose the hero — you lose the
run, bank what you collected, and spend it on making the next run go further.

Reference points: Vampire Survivors / Brotato for the run, MapleStory for the
hero, class advancement and visible gear.

## 2. Pillars

1. **The hero is the save.** Runs are disposable; the hero is permanent.
2. **Difficulty lives inside the run, never outside it.** No difficulty tier to
   pick. The one thing that shapes a run's difficulty is the hero's level, and it
   only shifts where the run's ramp begins (section 4).
3. **Your gear is visible on your character.** Equipment is a visual reward, not
   just a stat line.
4. **Stats drive everything.** Class restrictions are emergent, never hardcoded.

## 3. Core loop

```
Hub (hero + buttons)
  → pick a quest
  → arena run (3 min, ends in a win, a death or a retreat)
  → collect exp / gold / item drops during the run
  → return to hub, spend, equip, advance class
  → repeat
```

## 4. Difficulty model

**Every run lasts the same time and ramps on a timer, along one curve shared by
every hero.** The hero's level only decides *where on that curve the run begins*.

A level 1 hero starts at the curve's first second. A higher-level hero starts
further along it, so it skips the trivial opening instead of idling through it.
Every run is the same length at every level (3:00, section 6.3), so a strong hero
still gets the whole run; it just meets denser, tougher enemies from the first
seconds and meets the lethal end of the curve at the finish line.

```
ramp start = min(START_CAP, START_PER_LEVEL × (level − 1))
run covers   ramp start → ramp start + 3:00
```

Starting values: START_PER_LEVEL 5 s, START_CAP 120 s (reached at level 25). Both
are placeholders, to be tuned by play. They live in the quest's `QuestData`
(`resources/quests/meadow_run.tres`) along with the ramp itself, so the ramp is
one file per quest.

The ramp is a few values that rise linearly from the start of the ramp (0:00) to
its end (START_CAP + 3:00 = 5:00): the seconds between spawns (1.5 s to 0.3 s),
the most enemies alive at once (8 to 50), and the multipliers on every enemy's
health (1× to 4×) and contact damage (1× to 2×). A `RunDirector` runs the
clock and spawns enemies to match. These are placeholders too.

Consequences relied on elsewhere in this document:
- Any hero can attempt any quest at any time. A weak hero is shorter-lived, not
  locked out.
- One curve per quest type, forever. No per-level balance tables: level only
  moves the start point.
- A weak hero still banks something, so a fresh build is never a wasted session.

**The shift must grow slower than hero power.** Levelling gives stats, gear and
class advancement; the start shift is deliberately small and capped, so a
levelled hero is still stronger relative to the enemies it meets. If playtests
show levelling feeling like nothing, shrink START_PER_LEVEL, not the stats.

**Explicitly rejected:** a global difficulty tier, and enemies that scale to hero
level in proportion to hero power. Both silently cancel out earned power.

## 5. Hero

### 5.1 Slots

- **Three hero slots**, fully isolated. Separate level, class, skills, equipment,
  gold, gacha. A second hero starts from absolute zero.
- Isolated slots *are* the respec system — see 5.4.
- Optional per-hero **hardcore flag** chosen at creation: the hero is lost if a
  run ends in death or a retreat, in exchange for increased gold. Opt-in only, never forced.

### 5.2 Stats

Four stats: **STR, DEX, INT, VIT**.

Each level grants:
- **Automatic class growth** — the majority of stat gain, applied without input.
  Every base class gains 4.0 points per level, distributed differently.
- **Two free points** allocated by the player. Points are staged on the hub's
  stats panel and only spent for good when the player applies them, since there
  is no respec.

Automatic growth deliberately dominates. With isolated slots and no respec, a
badly allocated hero must be *suboptimal*, never *broken*.

### 5.3 Class tree

Concrete classes, skills and numbers live in `design/classes.json` and
`design/skills.json`.

- **Tier 0 "Novice" from level 1.** Levels 1–4 are not classless: Novice is a
  real class that grows every stat slowly and grants two skills. Without it a
  level 1 hero has no defined growth and no skill to bring into a run.
- **Tier 1 at ~level 5**, three base classes. Short enough that nobody plays a
  Novice for an hour, long enough that the choice feels earned.
- **Tier 2 at ~level 15**, branching. **Tier 3 later**, once the game is known.
- Each advancement is permanent and adds stat growth and a skill list on top of
  what came before.
- **An advancement may have more than one prerequisite.** Hybrids list two, so
  they are reachable from either parent.

**A class never restricts anything.** It defines stat growth, scaling affinity
and `health_per_vitality`. Weapons and skills declare which stats they scale
off — a sword draws on STR, a staff on INT, a crossbow on DEX. A mage swinging a
sword deals poor damage *because they have no STR*, not because a rule forbids
it. Hybrids therefore cost nothing to express.

**Skills scale off a map of stats, not a single one.** A Spellblade's Rune Slash
draws on STR and INT together. With one stat per skill, half the investment that
defines a hybrid would do nothing on any given skill, and the class would be a
label rather than a playstyle.

**Durability is `health_per_vitality`, set per class** — Warrior 1.2, Mage 0.8,
Ranger 1.0, inherited from the nearest ancestor that sets it. VIT growth is
deliberately identical across all three base classes, because unequal VIT growth
was what broke the symmetry of advancement costs. This is the one place a class
carries a property rather than expressing it through stats, and it is a
concession, not a pattern to repeat.

Maximum health is `vitality × health_per_vitality × 10`, so a level 1 Novice has
50. The 10 is a placeholder until enemy damage exists.

**Tier-2 advancements are gated on stat thresholds**, which is what makes free
point allocation matter:

| Advancement | Requires | Reached by |
| --- | --- | --- |
| Berserker | STR 45 | A warrior spending points naturally |
| Spellblade | STR 25 + INT 25 | A warrior who invested INT, *or* a mage who invested STR |
| Archmage | INT 45 | A mage spending points naturally |

Verified against the growth numbers: by level 15 a hero has 28 free points, every
pure advancement costs 8 of them and every hybrid costs 13, from either parent.
Default allocation walks into the pure advancement; a hybrid takes ten levels of
deliberate off-class investment at a real cost to early power. The tree crosses
and converges rather than being three isolated columns.

Balance rule: hybrids are slightly weaker than pure builds at their specialty but
cover more situations. Otherwise nobody picks pure.

### 5.4 No respec

Not for stats, at launch. Isolated hero slots already serve that purpose, and a
respec would undermine the weight of the tier-2 stat commitment.

**Skill points can be reset, for gold, from the skill tree.** A hero earns only
one a level and has a capped number to spend, so an early choice would otherwise
be punished for good, and skills do not define a hero the way stats and class
do. The price is 5 gold for each point taken back (`SKILL_RESET_COST_PER_POINT`),
so a hero who has invested more pays more to change their mind, and a level-up
is worth spending carefully without being a trap. Resetting returns every point
and puts skills back to level 1; a class whose skills needed points in the one
before closes again until they are re-spent. It is a gold sink for the economy
(section 11), and the 5 is a placeholder.

### 5.5 Skills

- **Class-granted.** Each advancement unlocks its skill list; skill points level
  them up. Skills accumulate down the lineage, so a hero keeps everything earlier
  tiers gave them.
- **A run starts with one equipped skill.** More are acquired mid-run from the
  upgrade offers.
- **Maximum four active skills** at the end of a run.
- Skills have cooldowns. One **auto-cast / manual switch** covers every skill,
  and it is flipped in the run (a button on the skill bar, or `Tab`), not in the
  hub. Auto fires a skill the moment its cooldown is ready; manual waits for a
  key press, so a heal or panic button can be held for timing. A few reactive
  skills refuse auto-cast entirely and are always cast by hand — a panic button
  that fires itself is not a panic button. The switch starts on at each run.
- **Damage is split deliberately**: half from stats, a third from skill levels,
  the rest flat. Stats stay the largest contributor, maxing a skill roughly
  doubles it, and no skill is ever build-independent.
- Because skills accumulate, **Novice's skills must stay useful to every class**.
  Whirl therefore scales off STR, DEX and INT equally, so an Archmage is not
  offered a dead strength skill for the rest of the hero's life.

**Built.** A hero has every skill granted by a class in their lineage
(`resources/skills/`, one `SkillData` per skill, generated from
`design/skills.json` by `tools/build_skills.gd`, which also holds how each skill
is carried out in the arena: area, strike, projectile, delayed area, heal, buff
or trap). Each skill has a 16×16 icon, drawn by `tools/build_skill_icons.gd` and
shown in a chamfered square frame (`SkillFrame`) in the tree, on the skill bar
and on level-up cards. Each level gained earns **1 skill point**, spent in the
hub's skill tree to raise a skill one level for good, up to its max of 5.
**A class's skills open only after the hero has spent enough points on the
skills of the class before it** (3 for a base class, 6 for an advancement;
`skill_points_required`), so the lower skills cannot be skipped. A skill's top
level costs 4 points, so a pair of skills holds 8 at most.
Points are spent on the click, not staged: a point is small, and one mis-click
does not warrant a confirmation. **Skill points can be reset for gold**, all at
once, and spent again; see 5.4. The tree also picks the skill a run **starts
with**. Skills are cast with the keys `1`–`4` in the order of the on-screen skill
bar, whether or not auto-cast is on, and `Tab` switches auto-cast.

Auto-cast waits for a reason: an aimed skill needs an enemy in reach, an area
skill an enemy inside its radius, a self buff an enemy within its cast range,
and Second Wind a hero below 60% health. A manual press never wastes a cooldown
either; it does nothing when there is nothing to hit or heal. Skill damage
scales with the run's damage upgrades; healing and buffs do not.

Statuses the skills add to the hero are timed (`HeroBuffs`), and recasting one
refreshes rather than stacks it. Vanish makes enemies stop hurting the hero but
not stop chasing. Shadow Strike blinks behind its target but has no critical
hit, because the game has no crit system yet. Skill cast ranges, area radii,
projectile counts and the buff durations are placeholders in the tool.

### 5.6 Equipment

Four slots, each with a distinct job so no two ever compete for the same stat:

| Slot | Carries |
| --- | --- |
| Weapon | Damage, scaling type, attack speed |
| Armour | VIT, plus a stat its class leans on (Defence is not built) |
| Boots | Move speed, plus a few stat points |
| Accessory | Cooldown reduction, crit, pickup radius |

- **Armour is worn as a hat, shirt and pants.** One Armour item always carries
  all of its layers, and they are never equipped separately. Novice armour has no
  hat.
- **Armour looks are rolled per piece.** Each base class has its own pool of hat,
  shirt and pants art. When an Armour item is acquired, each piece is rolled
  separately from its class's pool, so two Mages rarely look the same. The pieces
  are stored on the item, by piece id, so adding art to a pool never changes what
  an existing item looks like. Advanced classes wear their base class's armour.
  Mage, Ranger and Warrior each have ten variants of every piece (Novice has
  one, so far).
- **Armour stats are rolled once per item.** Each Armour item rolls a few stat
  points when acquired and keeps them: 2 to 4 VIT, plus 1 to 3 points of the stat
  its base class leans on (Mage INT, Ranger DEX, Warrior STR). **Novice armour is
  plain clothes:** exactly 1 VIT at Common and nothing else, but it has rarity like
  any other armour. These are the Common values, saved on the item as
  `stat_points`; rarity multiplies them when read, so an item keeps its roll if
  its rarity changes. Armour gives no Defence: there is no such stat, and the
  existing four are all it uses. The rolls are placeholders. This is the one place
  an item has a random roll, because armour has no fixed template the way weapons
  and boots do. Saves from before this get a roll for their armour on load
  (`HeroData.upgrade()`).
- **Armour, Boots and Weapon are drawn on the hero** (see 9.2): Armour as its
  three layers, Boots as a layer over the feet, and the Weapon in the near hand,
  in front of the body: the sword and wand are held low, pointing forward and
  down, and the crossbow is
  held level.
  Whether an Accessory is drawn is undecided (section 11).
- **Boots are fixed templates, and speed is their main stat.** There are 13
  pairs, each one `BootsData` in `resources/boots/` with its own art, its own
  move-speed bonus (6% to 22% of base speed) and a few points of STR, DEX, INT or
  VIT. The stat mix is what makes a pair a choice: Wind Walkers are the fastest
  and add almost nothing else, Iron Greaves are the slowest and add the most
  STR and VIT, and Mystic Boots lean on INT. Other pairs trade between the two.
  Worn gear's stat points count towards damage and health but are not part of
  the hero's own stats, so they never show up as spendable or permanent points.
  All the numbers are placeholders.
- **Boots are dropped like armour.** 30% of the items a run drops are
  boots, rolled from all 13 pairs whatever the hero's class (boots are not
  class art). A hero starts with none.
- **Three base weapons: Sword (STR), Crossbow (DEX), Wand (INT).** A weapon's
  strength is purely its stat scaling, with no class bonus: a Warrior hits
  hardest with a sword only because Warriors grow STR, and a Novice, growing
  every stat evenly, favours none. Each weapon is a fixed template; its numbers
  are placeholders until enemies exist.
- **Ten weapons per type.** Sword, Crossbow and Wand are each the first of ten:
  a type is a way of attacking (slash, piercing bolt, bursting bolt), and each
  of its ten templates has its own name, art and numbers, so they differ in
  damage, attack speed and reach and none is strictly better than the others.
  Some add a small secondary scaling (a Katana's DEX, a Flamberge's INT). Every
  variant keeps its type's grip, tip and release point, so the shared slash
  and bolt effects line up. The extra templates are not yet given to heroes or
  dropped; see section 11.
- **Every hero starts with all three weapons**, the Sword held and the Crossbow and
  Wand carried, so the first runs are a chance to find the one that suits the
  build. Heroes saved before weapons existed are given the same set on load.
- **The DEX weapon is a crossbow, not a bow.** A bow needs a second hand to
  draw, which a side-on hero with one visible arm cannot show; a crossbow is
  held and loosed one-handed. Bows in older saves load as crossbows.
- **Each weapon hits in its own shape**, so they differ by more than numbers.
  The hero turns to the nearest enemy in range first, then:
  - **Sword:** a broad greatsword whose slash hits every enemy on the facing side
    within its range. That pays for having to close in. (The slash art is
    a tall arc; the hit area is a half circle of `attack_range` rather than the
    arc's exact shape.)
  - **Crossbow:** a fast bolt, aimed at the target, that pierces, hitting every
    enemy in a line.
  - **Wand:** a slower bolt that bursts in a small area where it first hits an
    enemy, or at the end of its range. **Homing is not built yet**: the bolt
    flies straight at where the target was.
- **Fixed templates with rarity tiers.** An Iron Sword is always the same item; a
  higher rarity is strictly better. No rolled affixes at launch.
- **Five rarities: Common, Uncommon, Rare, Epic, Legendary.** Each is a
  `RarityData` in `resources/rarities/` and an item stores only its id (saves
  from before rarities load as Common). A rarity sets a stat multiplier (x1.0,
  1.25, 1.5, 1.8, 2.2), a drop weight (60, 25, 10, 4, 1) and how it looks; all
  placeholders. The multiplier scales a weapon's damage and scaling, a pair of
  boots' speed and stat points, and an armour's rolled stat points (points round
  up, so a 1-point bonus still improves). Every item a run drops, armour or
  boots, rolls its rarity by weight. Weapons do not drop in runs yet; they come
  from the store (Common) and gacha packs and merges (any rarity).
- **Rarity is shown three ways.** Menus draw a frame in the rarity's colour
  around the item (none for Common, so a full inventory is not a wall of
  borders), and the tooltip names the rarity. Behind the item sits a glow in the
  same colour, drawn in a few hard bands to suit the pixel art; on the hero, the
  glow is an aura behind the doll in the colour of the best rarity worn, and the
  held weapon gets a one-pixel outline (`shaders/item_outline.gdshader`). Epic
  and Legendary pulse. Only the weapon is outlined, since it is the top layer and
  cannot paint over another. Glow is brightness, not a recolour: a plain recolour
  of the art was tried first and did not read as special. It needs no new art.
- One weapon slot only. Weapon proficiency lives in the scaling numbers.
- **Rejected:** a secondary weapon slot. Alternating auto-attacks between two
  weapons felt fussy and the fantasy doesn't hold up.
- **Each hero carries up to 25 items** in an inventory to begin with, and the
  store sells upgrades that add more (see 5.7). Unworn items live there. The hub
  shows them in a grid that scrolls once it is longer than the panel.
- **An item's icon is stacked from its pieces.** Every Armour piece variant has
  a 16×16 icon, drawn on a shared canvas with a fixed zone per piece (hat on
  top, shirt, pants below), and the item's icon is its pieces' icons layered.
  Two items differ wherever any piece does.

### 5.7 Acquisition

- **Items drop during runs**, randomly, and must be physically picked up.
- **Gold buys gear in two places.** The store sells chosen items, always Common;
  gacha packs sell a random roll at any rarity. Both pay out into the
  inventory, so both need free cells.
- **The store is a shop with shelves.** Clicking the gold count in the hub opens it.
  Weapons (30), Boots (13) and Armour (a class's art at a time) stand on wooden
  shelves under a striped awning, each with a hanging price tag with a coin;
  what the hero cannot afford is dimmed and its price shown in red. Picking
  anything puts it on the hero's doll in place of what they wear, with WALK and
  ATTACK buttons to see it move, and RESET to dress the doll as the hero again.
  Beside the doll, rows set what the item gives against what the hero wears in
  that slot, with the change in green or red: damage, attack speed and range for a
  weapon (damage uses the hero's own stats), move speed and stat points for boots,
  and the range of points an unbought armour can roll against the worn armour's
  (`ItemCompare`). It also says how many of that weapon or boots the hero already
  has. BUY pays the price and puts a new **Common** copy in the inventory
  (disabled, with the reason on hover, when the hero lacks gold or room), with
  coins flying from the gold count, the count running down, and SOLD on the tag.
  Armour is priced by the piece and sold as a set the player assembles from one
  class's pieces, with its stat points rolled on purchase, which is a
  placeholder: it lets a player choose an Armour item's look, which the
  rolled-look design above and the open question in section 11 do not yet settle.
- **Selling happens in the store's Sell tab** (under a green awning), and from the
  hub by right-clicking a carried item. The tab lists everything carried, each with
  what it fetches on its tag. Tick any number of items (or ALL COMMON) and press
  SELL; coins fly into the gold count. Hovering an item shows what it gives next
  to what is worn, so a keeper is easy to spot. An item sells for its Common store
  price times its rarity's `sell_fraction` (25%, 35%, 50%, 70%, 90% from Common to
  Legendary), so selling rises with rarity yet always pays less than the store
  charges for the same item. Rare and above ask first. Worn items must be taken
  off to be sold.
- **Inventory upgrades are sold by the store** too. A button in the store's top bar
  buys the hero's next upgrade, which adds 5 slots, after a confirmation; each costs
  more than the last (400, 800, 1,600, 3,200, 6,400 gold), up to 50 slots. They are
  held in `resources/store/bag_upgrades.tres`, and the hero's count is saved
  (`HeroData.bag_upgrades`). All placeholders: a gold sink for a hero with gold to
  spare, and a way out of a full inventory besides selling.
- **The gacha is advertised on a poster** under the shelves: a golden chest, some
  sparks, and "Packs from 200 gold", or "A guaranteed Legendary awaits!" when some
  pack's next pull is the guaranteed one. Pressing it opens the gacha, a slot
  machine; Back returns to the store. The Slots tab has a shelf of three
  packs on the left, each a chest recoloured in the pack's colour (`PackData.color`,
  via `ChestArt`) with a gem per tier and its price, and the machine on the right: a
  marquee of chasing light bulbs round the cabinet, the pack's odds as a stacked
  colour bar, a grid of reels, and a meter for the guarantee. Every pull is a reel
  that spins and stops, left to right, on its item, flashing in the item's rarity
  colour; one pull is one big reel, ten are a grid of ten. SKIP stops them all at
  once. An Epic or Legendary makes the marquee blink in its colour. The result is
  decided and paid for the moment the button is pressed; the reels only reveal it.
  The packs (`resources/packs/`, a `PackData` each) can all give weapons, armour and
  boots of any rarity, a third each; they differ only in price, odds and
  guarantee: Traveller (200 gold, 60/28/9/2.5/0.5% Common to Legendary, a
  Legendary within 100 pulls), Adventurer (400, 25/40/22/10/3%, within 75) and
  Champion (900, no Common, 0/15/45/30/10%, within 50). Pull one at a time, or
  ten for 10% off. A pull needs a free inventory cell for each item, so a
  ten-pull needs ten. **Each hero counts pulls since their last Legendary from each
  pack** (`HeroData.pity`); the pull that reaches the pack's limit is a Legendary
  whatever the dice say, and any Legendary resets the count. The meter fills as
  pulls go by and its star lights when the next pull is the guaranteed one. Armour
  pulled comes from a random class's art (mage, ranger or warrior, never Novice's
  plain clothes), whoever pulls it, as do forge results. All numbers are placeholders;
  selling pulls back less than a pack costs on average, so packs cannot be farmed
  for gold.
- **Merging happens in the Forge tab.** Tick five carried items of the same rarity,
  of any kinds, in the stash; they sit in the five sockets, and Merge turns them
  into one random item (a weapon, armour or boots, rolled like a pull) a rarity
  higher, which stops on a reel of its own. Free; Legendary cannot be merged. It is
  how gear the hero cannot use becomes something better.
- **Starting prices** (a won run pays about 100 gold, so 100 is about one run):
  weapons run from 100 for the three originals up to 900 for the fanciest of
  each kind, with the secondary-scaling and special designs at the top; boots
  run from 100 for Leather Shoes to 1,200 for Wind Walkers, priced mostly by
  move speed; armour pieces cost 60 for a hat, 90 for a shirt and 60 for pants
  whichever variant, so a full set is 210. All are placeholders, held in the
  weapons' and boots' own `price` fields and in `resources/store/armour_prices.tres`.

## 6. The arena run (quest type 1)

The first quest type to build. Chosen over the platformer because combat is the
only thing that can *test whether the build layer works* — a mage and a warrior
jump identically, so the platformer would validate nothing about classes, scaling
or items. It also generates infrastructure the platformer later reuses (pickups,
upgrade overlay, damage, run-end summary, ramp timer); the reverse is not true.

### 6.1 Control

**Move only.** Four-direction movement, already bound as `move_left/right/up/down`.
Auto-attack fires at the nearest enemy whenever one is within the weapon's
`attack_range`, once per `attack_interval`; with no enemy in range the hero does
not attack. Skills fire on cooldown per their auto/manual toggle. No aiming, no
attack button.

### 6.2 Arena

**Bounded, roughly two to three screens across, camera follows the hero.**

- Walls keep difficulty honest — running is a delaying tactic, not an exploit.
- Enough room to kite, so being swarmed has counterplay. A single fixed screen was
  rejected because with move-only controls, being cornered removes the player's
  only verb at the worst possible moment.
- Still one tiled map — no streaming, no procedural terrain.
- Off-screen threat indicators to recover the visibility a static screen would give.

The first arena is a **meadow**: a grass field 48×27 tiles of 32px
(1536×864, about 2.4 screens each way) with scattered dirt patches and
decorative tufts and flowers that never collide, ringed by a tree line four
tiles deep. It uses the pack's darker green grass, dirt and trees rather than the
lime set, and a slightly dark, cool tint over every map layer (not the hero or
enemies), so the field stays quiet and the characters stand out. The walls are one plain rectangle per side at the field's edge,
not per-tree shapes, so kiting along an edge is predictable. Trees are y-sorted
with the hero: the hero passes in front of the top row and behind the canopies
of the bottom row, which stands a tile back so only the feet are covered. The
camera stops at the map's edge. The map is generated, not painted, by
`tools/build_arena_map.gd` from a fixed seed, so it is the same on every run
and every clone.

### 6.3 Run structure

- **Fixed length: 3:00 for every hero.** Survive to the finish line and the run is
  won; a final elite spawns at the end of the curve (enemy to be chosen). Dying
  ends the run early. Opening the pause menu offers **Retreat**, which asks to
  confirm and then ends the run exactly like a death, so there is always a way
  out and never a reason to stall. Whichever way it ends, a results panel shows
  how it went before the hero returns to the hub.
- **A weak hero is expected to die before the finish.** The score for a lost run
  is how long it lasted; a won run needs no score.
- **Two progression tracks:**
  - *In-run levels* — earned during the run, grant upgrade picks, reset at the end.
  - *Permanent* exp, gold and items — banked when the run ends (section 6.5).

### 6.4 Upgrade offers

Presented as a choice of options on in-run level up (and from pickups).

- The pool is **the hero's unlocked skills** plus **generic upgrades** (move speed,
  heal, damage, pickup radius).
- Skills offered are drawn *only from what that hero has unlocked*, so permanent
  progression widens the possibility space rather than only raising numbers.

**Built.** Kills feed the run's own levelling, which starts at level 1 each run
and is forgotten at the end: leaving level L takes `round(8 × L ^ 1.3)` of the
experience earned in the run, so a full run is worth roughly eight to ten
levels (`QuestData`; placeholders). Each level pauses the run behind a choice of
three separate cards, each clickable as a whole, or picked with the arrow keys
and Enter, or `1`–`3`. The
cards ignore input for 0.4 s so a skill key pressed as the level lands does not
pick one by accident. Levels earned together are offered one after another.

An offer is one of:

- **A skill the hero carries, one level higher** for the rest of the run, until
  it reaches its max (5). The level is shared with the permanent one: a skill
  trained to 3 at the hub starts the run at 3 and can be offered up to 5.
- **A skill the hero has unlocked but is not carrying**, while they carry fewer
  than four. It joins at its permanent level and follows the hero's auto/manual
  setting for it.
- **A generic upgrade**, which can be taken again and again: *Light Feet* (+10%
  speed), *Sharpened* (+10% damage), *Second Helping* (heal 30%) and *Magnet*
  (+16 px pickup radius), as `GenericUpgrade` files in `resources/upgrades/`.

Three distinct options are drawn evenly from that pool. Upgrades from pickups,
which the design mentions, are not built; there are no upgrade pickups to find.

### 6.5 Rewards

**Kills and pickups feed the run's tally; ending the run banks it.** Nothing is
awarded for time survived directly.

| | Won | Died or retreated |
|---|---|---|
| **Exp** | Banked | Banked |
| **Gold and item drops picked up** | Banked | Lost |
| **Win bonus** | Extra gold and exp, plus one extra item | None |

Every run pays exp, so a fresh build is never a wasted session, but a win is
clearly worth more. A win adds 60 exp, 40 gold and one item, the same for every
hero. **The amount of loot never depends on the hero's level; its quality does**:
a hero who starts further along the ramp (section 4) rolls higher rarities more
often (`QuestData.start_difficulty`, 0 at level 1 up to 1 at the level shift's
cap, and `RarityData.DIFFICULTY_GAIN`). All of these are starting values, to be
tuned.

**Drops.** Each kill can leave gold on the ground (a Bamboo: 35% for 1 to 3) and,
rarely, an item (2%), though never more than 2 items a run (`max_item_drops` on
the quest), however lucky the rolls. With the win bonus that is at most 3 items
in a won run, for every hero. Items are armour, rolled from the art pool of a
random class (mage, ranger or warrior, equally; any hero can wear it, and what
does not suit the build is for selling or forging), or boots (30% of them, section
5.6), each at a rarity rolled by weight;
weapons do not drop yet, though they have rarity now. The hero collects a drop by
getting within its pickup radius (28 px). A won run's pickups and bonus are
banked, and any item that does not fit the inventory is lost, which the
results panel warns of. A death or retreat shows what was forfeited.

This keeps greed a real mechanic: diving toward a drop while swarmed is a genuine
decision, because a drop only counts if you live (or win) to bank it. Pickup
radius becomes a meaningful stat.

Nothing about the hero itself is lost on death (except a hardcore hero).

### 6.6 Levelling (placeholder numbers)

```
exp to leave level L = round(40 × L ^ 1.25)        MAX_LEVEL = 30
```

| Level | Total exp |
|---|---|
| 2 | 40 |
| 5 (first class advancement) | 519 |
| 10 | 2,811 |
| 15 (second class advancement) | 7,286 |
| 20 | 14,198 |
| 25 | 23,734 |
| 30 (max) | 36,048 |

Each level needs a little more than the one before, so the climb is gradual. At
roughly 100 exp a run, rising as the ramp starts later, that is about 4 runs to
level 5, about 37 to level 15 and about 117 to the cap. Those run counts are
guesses until enemies give real exp, so tune the curve by play.

A hero's `experience` is a running total and their level follows from it. **At
the max level experience stops accumulating**; if the cap is raised later (the
curve itself does not change) it resumes from where it stopped. Each level
gained grows the hero's stats by their class's `stat_growth` and gives 2 free
points. Growth is fractional (Novice gains half a point of each stat a level),
so the leftover is carried in the hero between level-ups.

**Built so far:** kills give their enemy's `experience` (Bamboo: 2), a finished
run banks the total, and levelling, stat growth, free points, the cap and
spending free points (on the hub's stats panel, section 8) work.

**Class advancement is built** for tiers 0–2 (section 5.3). A hero's growth each
level is the sum over their lineage, which is saved as `past_classes` plus the
current `class_id`. Advancing is done by clicking the class tag under the hero's
name, which gains a cue (`!` when a class can be taken now) while there is
somewhere to advance to; the dialog lists what the hero can become
and what they still lack. Requirements count earned stats only, so gear cannot
unlock a class, and staged points must be applied first. Skills are built
(section 5.5), and tier 3 is not: it only needs new `ClassData` files naming the
tier below as their prerequisite. Each level also earns a skill point
(`SKILL_POINTS_PER_LEVEL`); heroes saved before skills existed are given the
points their levels earned.

`armour_pool` and `health_per_vitality` are inherited from the nearest class in
the lineage that sets one, so a Spellblade wears the armour of whichever parent
the hero came through.

## 7. Quest selection

The player **picks the quest from a list**. Not randomised — it respects the
player's time and lets them practise a specific mode.

Only the arena exists at launch, so this matters from quest type 2 onward.

## 8. Hub

**The hero stands on the left in a warm glow, between their four equipment
slots, with their name and level above and their stats and Start Quest below;
their inventory fills the right.** Inventory, Advance and Skills sit in
the top bar. Inventory and Skills are two views of the same right-hand panel,
and the panel keeps one size whichever is up (a view that runs long scrolls
rather than resizing the screen). Skills is marked with an exclamation mark
while the hero has points to spend. The gold count opens the store, which leads
on to the gacha (section 5.7).

The skill tree shows only skills the hero can learn: a coloured box for each
class on their path (each class has its own colour in its file), oldest first,
holding its name and its pair of skills. A class they did not take never
appears. A box that is not open yet says how many skill points the hero has
spent on the class above out of the number it needs
(`ClassData.skill_points_required`), and its skills are padlocked: they cannot
be trained, started with or offered in a run. Picking a skill (click, or arrow
keys) shows its details below, with **Level up**, **Start with** and **Reset**
buttons; Reset shows its gold price and asks to confirm.

The hero is rendered with full visible equipment at integer scale (2×). 3× would
look better but leaves no room for the stats beneath on 360 lines. This is
where the player admires their character, so it's worth the screen space.

- **Stats are always visible, not behind a button.** Under the hero: free points
  left, each stat with −/+ buttons, and the numbers they lead to (health, and the
  held weapon's damage, attack speed and range). Equipping a different weapon
  and staging points both update those numbers at once, and a change that is
  still pending shows in the accent colour (`HP 50 → 60`).
- **Points are staged, then applied.** −/+ only change a pending allocation;
  **Apply** spends it for good (there is no respec, section 5.4) and **Reset**
  drops it. Leaving the hub with points still pending asks to apply or discard
  them.
- Equipment slots and inventory cells share one tile size, so the two panels
  read as one system. Empty inventory cells are faded so items stand out.
- Items move between the inventory and the slots by **drag-and-drop**, a
  **right-click menu** (Equip / Unequip), or by activating a cell with Enter,
  Space or a double-click. Arrow keys move between cells.
- Equipping swaps: whatever was worn takes the new item's place in the
  inventory, so a swap never needs a free cell. Taking an item off needs one,
  and is refused when the inventory is full.
- A slot whose items do not exist yet is shown but locked.

## 9. Art and rendering

### 9.1 View

**Side-view sprites on a top-down field** — Vampire Survivors / Brotato style.
The hero is drawn in profile facing right and flips horizontally when moving
left. Vertical movement reuses the same walk, keeping whichever way the hero last
faced. The character never rotates, while the field is top-down.

Chosen over true 4-directional top-down because it quarters the art requirement
forever, and keeps MapleStory's readable profile charm — true top-down mostly
shows the top of everyone's head.

Cost: less facing clarity. Irrelevant here, since the player never aims.

### 9.2 Character rig — frame-by-frame paper doll

**The hero is a paper doll**: a base body drawn frame by frame on a 64×64
canvas, with every visible piece of equipment as a layer drawn over it on the same
frame. Each layer is driven from the body's frame index, so the layers never drift
apart.

Frame-by-frame means every layer is redrawn for every body frame — the cost a
cut-out (skeletal) rig would avoid. It was chosen anyway because the hero already
exists in this form and reads well, and because the cost is contained:

- **Garments are generated from the body, not hand-drawn per frame.** Shirts,
  pants and boots are traced from each body frame's own silhouette and shading,
  recoloured to the item's palette, with trim added by rule. A new garment is
  mostly a palette and a few trim decisions.
- **The head does not move between frames**, so a hat is drawn once and reused on
  every frame.
- **The weapon is drawn once** and placed at a per-frame hand position, rather
  than redrawn. It is held in the near hand, pointing the way the hero faces,
  on the top layer; each frame redraws the body's fist over the grip, so the
  hand holds it without a separate hand layer and the weapon swings with it.
- **The body's animation set stays small: idle (1 frame) and walk (4 frames).**
  Hurt, death and attacks are effects and shaders, not new body frames. Every body
  frame added must be redrawn for every generated garment, so this is the budget
  to protect.
- **Each weapon has its own attack, drawn on the weapon layer alone.** The
  weapon plays a short attack clip on its own clock while the body keeps idling
  or walking, so the hero attacks mid-stride: the sword winds up, swings and
  follows through, the crossbow kicks as it looses, the wand lifts and flicks. The arm
  does not move — the weapon pivots in the still fist — which was accepted over
  an attack frame per weapon for the body and every shirt. The clip is drawn
  once at the idle pose's hand and shifted by the hand's offset on each body
  frame. What the attack throws is an effect: the sword's slash crescent is
  drawn on the hero, and the crossbow bolt and magic bolt fly ahead for the
  weapon's range, carried along by the hero's own speed so a shot fired on the
  run is never overtaken. The crossbow bolt trails a speed streak; the magic
  bolt ends in a burst.

In Godot: a `CharacterBody2D` with an `AnimatedSprite2D` body and one
`AnimatedSprite2D` per equipment layer. `tools/build_sprite_frames.gd` builds each
layer's `SpriteFrames` from its sheets. Equipping an item swaps a layer's
`SpriteFrames`.

**Consequences:**
- The body is ~48px tall on its 64×64 frame. It is shown at 1× in the arena and
  at **integer scale** in the hub. Pixel art scaled by whole numbers stays crisp;
  it cannot be scaled down, so the hero's size is fixed.
- **One body type.** Hair and colour provide variety. Every additional body
  doubles the wardrobe cost permanently.
- **All classes share one silhouette.** Classes differ by colour, headgear, hair
  and effects — never by body shape. This is nearly unfixable later.
- Every layer must share an identical canvas and registration point. This is a
  discipline problem, not a difficulty one, and it is what actually breaks
  projects.
- Empty slots need defaults (bare arms, plain tunic).
- **Scale is matched on the pack side.** The hero is bigger than 16×16 pack art,
  so enemies and environment are shown at an integer scale — 16×16 art at 2× puts
  enemies around 32px beside the 48px hero — or come from a pack drawn larger.

### 9.3 Art sourcing

- **Hero and all equipment: custom**, drawn to fit this body. Ninja Adventure's
  16×16 characters are flat single sprites with no layers; LPC's layered wardrobe
  is built for a different body and frame layout. This was accepted as a
  deliberate commitment.
- **Enemies, environment, VFX, UI, audio: asset pack.** Enemies need no gear, so
  pack art works fine alongside a custom hero. **Enemies use the pack's monsters
  at 2×**, as the arena's ground and trees do, which puts them around 32px beside
  the 48px hero. The pack's bosses are the candidates for the final elite.
- Pack: **Ninja Adventure by Pixel-Boy** — CC0 (commercial use allowed,
  attribution appreciated not required), 16×16, 50+ characters, 30+ monsters,
  9 bosses, 60+ items, 30+ visual effects, UI, 2 fonts, 100+ SFX, 37 music
  tracks, plus an official Godot 4 example project. **Confirmed.** Only the
  files in use are copied into `assets/packs/ninja_adventure/` (currently the
  Wood UI theme pieces, the back arrow, `NormalFont.ttf`, four hub item icons,
  and the floor, nature and floor-detail tilesets for the arena, and the Bamboo
  monster sheet, with the licence).
  UI follows the pack's own palette: orange frames around a warm brown interior, dark olive
  wells, light text, on a warm olive-grey background. The rest of the pack
  stays outside the repo until something uses it.
- The hub's dais, ground shadow, EXP star and empty equipment slot silhouettes
  are custom LibreSprite art, with editable `.ase` sources beside their PNGs
  under `assets/sprites/props/`, `assets/sprites/effects/` and
  `assets/sprites/ui/`. Armour piece icons sit beside their sheets the same way.
- **Boots art is custom and traced from the body.** Each of the 13 pairs is
  drawn over the body's own leg pixels on every frame, so it cannot drift from
  the walk, then differs by height, toe, cuff, trim and palette. Each pair's
  `.ase` and 16×16 icon sit beside its sheets under
  `assets/sprites/chibi/equipment/boots/`. The body's legs are only about six
  rows tall and the pants cover most of them, so boots are small; the shape and
  colour carry the difference.
- **Weapon attack effects are custom too**: the sword's slash crescent, the
  crossbow bolt, the magic bolt and its burst, in the weapons' own palettes, with `.ase` sources
  in `assets/sprites/effects/`. They are drawn at the hero's pixel density, which
  pack effects are not.
- **The wand starts from the pack.** Its 16×16 icon is the pack's own
  MagicWand with two shaft
  rows removed to fit. The in-hand art is redrawn at the hero's pixel density
  from the pack weapon at 2×, keeping its palette but using the hero's warm
  outline. The pack's 16×16-scale art at 2× would have pixels twice the size of
  the hero's. The greatsword and crossbow are custom throughout, icons
  included: the greatsword in the palette of the pack's Sword2 it grew from,
  and the crossbow in that of the pack Bow it replaced, as the pack has none.
- **Class icons are custom 16×16 LibreSprite art**, one per class, in
  `assets/sprites/ui/class_icons/<class>.png` with `.ase` sources beside them,
  in the pack's palette with the items' dark-brown outline. Each is set as
  `ClassData.icon` and shown on the hub nameplate, the hero slot cards and the
  advance dialog. Sword-like classes are told apart by silhouette: Spellblade
  has sparks and a purple grip, Duelist a thin rapier with a red guard, and
  Assassin crossed daggers.
- **Tier is marked on the icon** by a `ClassBadge`: a bronze, silver or gold
  plate around it (tier 0, 1, 2) on the hub and the advance dialog, or the bare
  icon with a gem per tier under it on the hero slot cards, where a plate would
  crowd the card. Plate and gem art is in `assets/sprites/ui/tier/`. A tier past
  the art shows as gold until it gets its own plate.
- Code can proceed immediately with placeholder layers. The architecture is
  what matters; art drops in later without code changes.

### 9.4 Engine settings

Unchanged: 640×360 base (1280×720 windowed), `canvas_items` stretch, Nearest
filtering, `gl_compatibility` renderer. Desktop keyboard first, web export kept
working.

## 10. Version 1 scope

In:
- Paper-doll hero with its Armour layers (hat, shirt, pants), Boots layer and
  Weapon layer wired.
- Arena run: movement, auto-attack, auto-target, one enemy type ramping, damage,
  death, retreat, a fixed-length win, run-end summary.
- In-run level ups and the choose-an-upgrade overlay.
- Item and gold drops with pickup.
- Gacha packs, the store and selling (section 5.7).
- Hub with hero, equipment and start-quest.
- Save with three hero slots.

Out until later:
- Platformer quest type.
- Tier-3 class advancements.
- Hardcore heroes.
- Audio.

## 11. Still undecided

- **Whether a Spellblade reached via Warrior and one reached via Mage should be
  the same class.** Growth accumulates along the lineage, so today they are not:
  the Warrior route carries STR and VIT growth, the Mage route INT and VIT. Same
  name, different character. Possibly a feature, possibly confusing — the
  alternative is for an advancement to normalise growth rather than add to it.
- Enemy roster and the final shape of the difficulty ramp (it starts linear), and
  the START_PER_LEVEL and START_CAP values in section 4. The roster comes from
  the Ninja Adventure monsters (section 9.3).
- The generic in-run upgrade pool is four placeholders (section 6.4): speed,
  damage, a heal and pickup radius. Screen clears and the like are not built.
  Run-to-run variety before tier 2 still leans mostly on it.
- Whether an in-run skill level should be able to pass the max a hero has trained
  the skill to; today the cap is the skill's own (5) for both.
- Whether `health_per_vitality` alone is enough to make a Mage feel fragile.
- Cooldown reduction stacks from skill levels, the accessory slot and Arcane
  Surge against only a 0.2s floor. An obvious place for a build to break the game.
- Whether single-target skills survive contact with a real swarm. The balance
  numbers assume an area skill touches three enemies and a single-target skill
  one; if a swarm is denser, single-target skills are dead.
- Item list. (The xp curve is in 6.6.)
- **What keeps a hero playing at the max level.** XP stops at level 30, so the
  endgame has to come from elsewhere: the gear chase (rarity tiers and gacha), build
  variety (hybrid classes, skills), and fresh heroes in the other slots. None of
  these exist yet. Difficulty tiers, which many games use here, are ruled out by
  pillar 2. Whether the cap should rise, and whether a post-cap track is needed,
  waits on seeing play.
- Gacha pack prices, odds and guarantees are placeholders (section 5.7), as are
  the sell fractions and the five-item merge. Whether packs should be split by
  slot, or offer a rate-up on one item, is open.
- Whether gold has sinks other than gacha, the store and skill resets.
- What the final elite at the end of the run is, and whether it is worth a
  dedicated reward.
- Whether the way difficulty shifts loot rarity (section 6.5) rewards high-level
  heroes too much, given that they also start further along the ramp.
- Whether an Accessory is drawn on the hero, given that visible gear is a pillar.
- Whether a player can re-roll an Armour item's look, and at what cost. The store's
  armour tab already lets a player pick pieces, so this and the store's
  assembled sets should be decided together.
- Whether the 27 extra weapons should also drop in runs or be run rewards (they are
  in the store, packs and merges now), and whether weapons of one type should be
  restricted by hero level.

**None of the balance numbers are anchored.** Enemy health and damage do not
exist, so `design/skills.json` is internally consistent and validated against
nothing. It will need revisiting the moment the arena is playable.
