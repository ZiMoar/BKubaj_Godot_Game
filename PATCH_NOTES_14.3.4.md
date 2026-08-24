# Patch 14.3.4

## CHa0s Relic Rework

- **CHa0s no longer skips the choice menus.** Level-ups, Anvils, and Winged Boots still open their normal windows, but every slot now shows the **same random upgrade** — so you can see exactly what you're getting before you take it (the effect is still tripled).
- Routing through the normal window flow also keeps the pause block balanced for co-op, which the old auto-apply path could desync.

## Fixes

- **Smith's Hammer** — Fixed a bug where an anvil saved by the relic could never be picked up a second time (the internal "already used" flag never reset, so it stayed locked forever).
- **Storm Conduit** — Added a range cap to both the initial strike and chain hops so lightning bolts stay tight instead of streaking across the whole screen (the Area stat no longer inflates their reach).

## Balance

- **Black Hole** — Tick damage increased 12 → 18 (+50%).
- **Smite** — Base damage increased 55 → 70 (another buff on top of 14.3.2).

## Text Fixes

- **Life Steal** level-up description now correctly reads "heal on **kill**" (it was still saying "on hit", but lifesteal procs on kills).
- Projectile-count anvil upgrade description no longer shows the "(100% = guaranteed)" parenthetical.
