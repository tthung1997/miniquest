# Miniquest — Design Document (v0.1)

Status: agreed in session on 2026-07-27. Art direction (sections 5.6 and 9)
revised on 2026-09-28 to match the hero assets already drawn.

## 1. Concept

A persistent hero, built up over many short run-based quests. Quests are the
action layer; the hub is the build layer. You never lose the hero — you lose the
run, bank what you collected, and spend it on making the next run go further.

Reference points: Vampire Survivors / Brotato for the run, MapleStory for the
hero, class advancement and visible gear.

## 2. Pillars

1. **The hero is the save.** Runs are disposable; the hero is permanent.
2. **Difficulty lives inside the run, never outside it.** No global difficulty
   tier, no adaptive scaling.
3. **Your gear is visible on your character.** Equipment is a visual reward, not
   just a stat line.
4. **Stats drive everything.** Class restrictions are emergent, never hardcoded.

## 3. Core loop

```
Hub (hero + buttons)
  → pick a quest
  → arena run (3–5 min for a strong hero, endless, ends in death)
  → collect exp / gold / item drops during the run
  → return to hub, spend, equip, advance class
  → repeat
```

## 4. Difficulty model

**Every run starts at the same trivial difficulty and ramps on a timer.** Minute
one is easy for everybody; minute eight is lethal for everybody.

A level 1 hero and a level 40 hero begin identically. The difference is purely how
far along the shared curve they survive. Progress is measured as "I reached 4:30
last time, 6:10 now."

Consequences relied on elsewhere in this document:
- Any hero can attempt any quest at any time. Never under-levelled, just shorter-lived.
- One curve per quest type, forever. No per-level balance tables.
- A weak hero still banks something, so a fresh build is never a wasted session.

**Explicitly rejected:** adaptive difficulty that scales to hero level. It
silently cancels out earned power and makes levelling feel like nothing.

## 5. Hero

### 5.1 Slots

- **Three hero slots**, fully isolated. Separate level, class, skills, equipment,
  gold, gacha. A second hero starts from absolute zero.
- Isolated slots *are* the respec system — see 5.4.
- Optional per-hero **hardcore flag** chosen at creation: the hero is lost if a
  run ends, in exchange for increased gold. Opt-in only, never forced.

### 5.2 Stats

Four stats: **STR, DEX, INT, VIT**.

Each level grants:
- **Automatic class growth** — the majority of stat gain, applied without input.
  Every base class gains 4.0 points per level, distributed differently.
- **Two free points** allocated by the player.

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
off — a sword draws on STR, a staff on INT, a bow on DEX. A mage swinging a
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

Not at launch. Isolated hero slots already serve that purpose, and a respec would
undermine the weight of the tier-2 stat commitment.

### 5.5 Skills

- **Class-granted.** Each advancement unlocks its skill list; skill points level
  them up. Skills accumulate down the lineage, so a hero keeps everything earlier
  tiers gave them.
- **A run starts with one equipped skill.** More are acquired mid-run from the
  upgrade offers.
- **Maximum four active skills** at the end of a run.
- Skills have cooldowns, and each has a per-skill **auto-cast / manual toggle**.
  Auto fires the moment the cooldown is ready; manual waits for a key press. Set
  per skill, so filler damage can be automated while a heal or panic button is
  held for timing. A few reactive skills refuse auto-cast entirely — a panic
  button that fires itself is not a panic button.
- **Damage is split deliberately**: half from stats, a third from skill levels,
  the rest flat. Stats stay the largest contributor, maxing a skill roughly
  doubles it, and no skill is ever build-independent.
- Because skills accumulate, **Novice's skills must stay useful to every class**.
  Whirl therefore scales off STR, DEX and INT equally, so an Archmage is not
  offered a dead strength skill for the rest of the hero's life.

### 5.6 Equipment

Four slots, each with a distinct job so no two ever compete for the same stat:

| Slot | Carries |
| --- | --- |
| Weapon | Damage, scaling type, attack speed |
| Armour | Defence, VIT |
| Boots | Move speed |
| Accessory | Cooldown reduction, crit, pickup radius |

- **Armour is worn as a hat, shirt and pants.** One Armour item always carries
  all of its layers, and they are never equipped separately. Novice armour has no
  hat.
- **Armour looks are rolled per piece.** Each base class has its own pool of hat,
  shirt and pants art. When an Armour item is acquired, each piece is rolled
  separately from its class's pool, so two Mages rarely look the same. The roll is
  cosmetic only: stats still come from the template and rarity. The rolled pieces
  are stored on the item, by piece id, so adding art to a pool never changes what
  an existing item looks like. Advanced classes wear their base class's armour.
- **Armour, Boots and Weapon are drawn on the hero** (see 9.2): Armour as its
  three layers, Boots as a layer over the feet, and the Weapon in the hand.
  Whether an Accessory is drawn is undecided (section 11).
- **Fixed templates with rarity tiers.** An Iron Sword is always the same item; a
  higher rarity is strictly better. No rolled affixes at launch.
- **Rarity is a palette shader, not new art.** Draw a sword once, get five tiers.
- One weapon slot only. Weapon proficiency lives in the scaling numbers.
- **Rejected:** a secondary weapon slot. Alternating auto-attacks between two
  weapons felt fussy and the fantasy doesn't hold up.

### 5.7 Acquisition

- **Items drop during runs**, randomly, and must be physically picked up.
- **Gold buys gacha packs** in the hub.

## 6. The arena run (quest type 1)

The first quest type to build. Chosen over the platformer because combat is the
only thing that can *test whether the build layer works* — a mage and a warrior
jump identically, so the platformer would validate nothing about classes, scaling
or items. It also generates infrastructure the platformer later reuses (pickups,
upgrade overlay, damage, run-end summary, ramp timer); the reverse is not true.

### 6.1 Control

**Move only.** Four-direction movement, already bound as `move_left/right/up/down`.
Auto-attack fires continuously at the nearest target. Skills fire on cooldown per
their auto/manual toggle. No aiming, no attack button.

### 6.2 Arena

**Bounded, roughly two to three screens across, camera follows the hero.**

- Walls keep difficulty honest — running is a delaying tactic, not an exploit.
- Enough room to kite, so being swarmed has counterplay. A single fixed screen was
  rejected because with move-only controls, being cornered removes the player's
  only verb at the worst possible moment.
- Still one tiled map — no streaming, no procedural terrain.
- Off-screen threat indicators to recover the visibility a static screen would give.

### 6.3 Run structure

- **Endless.** No boss, no clear state. You always die; the score is how long you
  lasted.
- **3–5 minutes** for a well-built hero. Snappy and repeatable.
- **Two progression tracks:**
  - *In-run levels* — earned during the run, grant upgrade picks, reset at the end.
  - *Permanent* exp, gold and items — awarded from what you collected.

### 6.4 Upgrade offers

Presented as a choice of options on in-run level up (and from pickups).

- The pool is **the hero's unlocked skills** plus **generic upgrades** (move speed,
  heal, damage, pickup radius).
- Skills offered are drawn *only from what that hero has unlocked*, so permanent
  progression widens the possibility space rather than only raising numbers.

### 6.5 Rewards

**Kills and pickups only** — what you physically collected is what you keep.
Nothing is awarded for time survived directly.

This makes greed a real mechanic: diving toward a drop while swarmed is a genuine
decision, and pickup radius becomes a meaningful stat.

Nothing is ever lost on death (except a hardcore hero).

## 7. Quest selection

The player **picks the quest from a list**. Not randomised — it respects the
player's time and lets them practise a specific mode.

Only the arena exists at launch, so this matters from quest type 2 onward.

## 8. Hub

**The hero stands in the centre, surrounded by buttons** — Equipment, Skills,
Gacha, Stats, Start Quest.

The hero is rendered with full visible equipment at integer scale (3× or 4×). This
is where the player admires their character, so it's worth the screen space.

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
  than redrawn.
- **The body's animation set stays small: idle (1 frame) and walk (4 frames).**
  Hurt, death and attacks are effects and shaders, not new body frames. Every body
  frame added must be redrawn for every generated garment, so this is the budget
  to protect.

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
  pack art works fine alongside a custom hero.
- Leading pack candidate: **Ninja Adventure by Pixel-Boy** — CC0 (commercial use
  allowed, attribution appreciated not required), 16×16, 50+ characters, 30+
  monsters, 9 bosses, 60+ items, 30+ visual effects, UI, 2 fonts, 100+ SFX,
  37 music tracks, plus an official Godot 4 example project. **Not yet confirmed.**
- Code can proceed immediately with placeholder layers. The architecture is
  what matters; art drops in later without code changes.

### 9.4 Engine settings

Unchanged: 640×360 base (1280×720 windowed), `canvas_items` stretch, Nearest
filtering, `gl_compatibility` renderer. Desktop keyboard first, web export kept
working.

## 10. Version 1 scope

In:
- Paper-doll hero with its Armour layers (hat, shirt, pants) wired; Boots and
  Weapon layers still to add.
- Arena run: movement, auto-attack, auto-target, one enemy type ramping, damage,
  death, run-end summary.
- In-run level ups and the choose-an-upgrade overlay.
- Item and gold drops with pickup.
- Hub with hero, equipment and start-quest.
- Save with three hero slots.

Out until later:
- Platformer quest type.
- Gacha.
- Tier-2 and tier-3 class advancements.
- Hardcore heroes.
- Audio.

## 11. Still undecided

- **Whether a Spellblade reached via Warrior and one reached via Mage should be
  the same class.** Growth accumulates along the lineage, so today they are not:
  the Warrior route carries STR and VIT growth, the Mage route INT and VIT. Same
  name, different character. Possibly a feature, possibly confusing — the
  alternative is for an advancement to normalise growth rather than add to it.
- Enemy roster and the shape of the difficulty ramp (spawn rate, hp, damage curves).
- The generic in-run upgrade pool — heals, stat boosts, screen clears. Run-to-run
  variety before tier 2 depends on it, and it does not exist as data yet.
- Whether `health_per_vitality` alone is enough to make a Mage feel fragile.
- Cooldown reduction stacks from skill levels, the accessory slot and Arcane
  Surge against only a 0.2s floor. An obvious place for a build to break the game.
- Whether single-target skills survive contact with a real swarm. The balance
  numbers assume an area skill touches three enemies and a single-target skill
  one; if a swarm is denser, single-target skills are dead.
- Item list, and the xp curve.
- Gacha pack contents and pricing.
- Whether gold has sinks other than gacha.
- Exact arena dimensions, and whether pack art is shown at 2× beside the 64×64
  hero or a pack drawn at a larger size is chosen instead (see 9.2).
- Whether an Accessory is drawn on the hero, given that visible gear is a pillar.
- Whether a player can re-roll an Armour item's look, and at what cost.

**None of the balance numbers are anchored.** Enemy health and damage do not
exist, so `design/skills.json` is internally consistent and validated against
nothing. It will need revisiting the moment the arena is playable.
