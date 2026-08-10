# Dungeoneers — Current Feature Inventory

> Bullet-heaven / auto-battler (Brotato / HoloCure-inspired), top-down 2D, mouse-aimed player.

## 🎮 Core Gameplay
- Top-down 2D auto-battler; player is a **CharacterBody2D** with WASD movement; **sprite flips left/right** (no full rotation) to face the cursor
- Right-click reserved as a future **ability button** (abilities inherit from the `Weapon` base class)
- **Lifesteal** with a 0.1s internal cooldown
- **Armor** is a flat stat applying `100/(100+armor)` damage reduction
- **Difficulty stat** grows **1× per minute**, with compensated mob scaling so real threat matches the old rate; per-difficulty-point scaling is tuned low so leveling the "Difficulty" stat is gentle

## 🗡️ Weapons (9 total, balanced to ~25 average DPS, 0.5x-1.5x band by AOE)
| Weapon | Class | Notes |
|---|---|---|
| Pistol | Manual (LMB) | fast single-target, top-end DPS |
| Sword Slash | Manual (RMB) | melee arc, top-end DPS |
| Magic Bolts | Auto → Reworked | now Mage **primary** (Arcane Bolts) |
| Book | Auto | homing projectiles |
| Spinning Blade | Auto | orbiting blade |
| Dagger Fan | Auto | **360° ring of daggers**, **pierces up to 3 enemies**, damage 25 |
| Lightning Bolt | Auto | chains ×4 |
| Frost Nova | Auto | radial burst, **slows enemies** |
| Aura Pulse | Auto | damage pulse around player |

- Auto weapons split into starting arsenal vs. **chest-earned** automatic weapons
- Balance: AOE-heavy weapons ≈0.5x, single-target/manual ≈1.5x
- **Dagger pierce** future-proofed via `pierce_count` + `player.get_extra_pierce()` hook (a future stat/upgrade can raise it)
- **Area stat** — level-up upgrade that scales the radius of AOE skills *and* the visual/collision size of projectiles (frost nova, rain of arrows, aura, lightning chain, spinning blade orbit, sword slashes, arrow/bolt/dagger/book/blade projectiles)

## 🎭 Class System (3 classes, expandable)
- **Class-selection menu** builds one button per class in the `GameState` roster automatically — new classes added to the roster appear in the menu with no extra UI work
- Each class defines a **left-click (primary)** and **right-click (secondary)** ability; picked class is stored in `GameState` and its weapons are granted at run start
- **Knight** — primary: *Knight Blade* (3-hit combo: wide cone slash → reversed cone slash → heavy forward stab at 1.5×; slashes emanate from player, ~3× longer reach); secondary: *Tower Shield* (appears only while RMB held, has its own HP bar, HP persists between raises and only repairs after a full break + recharge; blocks enemy projectiles + shoves enemies back, and enemies touching it drain its HP; own HP/armor *lower* than player's, thorns *equal*)
- **Ranger** — primary: *Longbow* (piercing arrow, pierces 6 targets, slower than the gun but similar DPS); secondary: *Rain of Arrows* (area damage circle around the cursor, radius 150, knockback)
- **Mage** — primary: *Arcane Bolts* (repurposed automatic Magic Missiles, now manual homing); secondary: *Mana Overload* (buffs to **halve all cooldowns** for 4s; the ability's own recharge only starts **after** the buff ends, unaffected by the buff)
- Keyboard/gamepad friendly: first class auto-focused, Enter selects

## 💰 Gold Economy
- Gold drops from enemies; spent to **reroll** reward menus
- Reroll cost scales `base × 2^rerolls` per menu: **level-up = 10g, weapon = 50g, artefact = 300g**
- **Greed stat** (tuned like *growth*) boosts gold gain
- Gold-related artefacts
- XP + Leveling system (team XP)

## 👹 Enemies
- **Skeleton** — basic melee chaser
- **Skeleton Archer** — ranged; **capped at 6 per batch**
- **Skeleton Brute** — heavy melee; scales stats
- Enemies **scale stats with difficulty** (per-type multipliers); **spawn frequency scaled** separately
- **Floating damage numbers** + colored HP bars
- No hard enemy cap (effectively unlimited)

## ⭐ Bosses
- **Skeleton General** boss — reusable `BossEnemy` template + `Event` base class
- Telegraphed **sequenced attacks**: visible warning zones, non-instant, guaranteed dodgeable
- Spawns **once on a timer (5-minute mark)**, boosted stat pool to match a leveled-up player
- Drops **artefacts**
- Spawn **clamped inside arena bounds**
- `TargetPointer` base class for objective indicators (e.g., pointing to the chest)

## 💎 Rarity System (level-up bonuses)
- 5 tiers + colors + weights: **Common 60 (gray) / Uncommon 25 (green) / Rare 10 (blue) / Epic 4 (purple) / Legendary 1 (orange)**
- Each upgrade has a `min_rarity`; values scale up from base rarity
- **Luck stat** redistributes weight from Common toward rarer outcomes
- Level-up menu offers readable choices

## 🏺 Artefact System
- Artefacts **drop from bosses**; cross-stat interactions
- **5 equip slots** (Artifact counter `0/5` UI)
- When offered, **choice of 1 of 3 random** artefacts with readable effects (truly uniform random — explicitly desired)
- Artefact pool includes gold-related ones (golden touch, greed→XP, armor→gold, etc.)

## 💰 Treasure Chest & Auto-Weapons Loop
- Chests spawn; opening grants a choice of a new **automatic weapon**
- Chests **keep spawning until player has 3 chest-earned automatic weapons** (cap counts *auto* only)
- Pointer/indicator toward the chest
- Chest gives gold-tinted weapon choices + reroll

## 🎛️ UI / HUD
- Top **single-row header**: level, XP bar, XP text, Map Difficulty, Session timer
- Bottom-right **vertical weapon hotbar** with full weapon names + badges (LMB/RMB/A1-A3) + cooldown bars
- **Weapon choice menu** — compact, **bottom-right**
- **Artefact choice menu** — **bottom-left** (kept larger)
- **Main menu / title screen** — game boots to a menu with PLAY + QUIT; PLAY → **class-selection screen** → arena
- Enemy HP bars (clean colored bars; numeric garbling removed)
- Boss health bar; gold counter; artefact slot counter

## 🔧 Technical / Quality
- Godot 4.2+ (running on **v4.7.1**), TileMapLayer-based arena, `.gd` scripts with full type hints & `class_name`s
- Git repo on GitHub (`origin` → `ZiMoar/BKubaj_Godot_Game`, branch `main`, 402 files)
- Arena bounds clamping; boss/mob spawner system; weapon cooldown bars

## 🚧 Known Gaps / Likely Next Steps
- Skeleton General boss stats are still **placeholder guesses** (4200 HP etc.)
- Boss sprite is still a temp placeholder (`icon.svg`)
- **Luck stat has no HUD readout**; no rarity legend/tooltip
- Repeated identical upgrades can be offered across level-ups
- Floating damage numbers still overlap in dense crowds
- Rain of Arrows currently just applies area damage + a visual ring; the literal "arrows raining down" animation is planned for later
- Knight shield recharge/HP tuning and Ranger/Mage cooldown/DPS numbers are initial passes (not yet balanced against the ~25 DPS target)
