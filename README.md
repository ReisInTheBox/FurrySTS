# Beacon Dice MVP Scaffold

This repository now includes a Godot 4 MVP scaffold aligned with `mvp_tech_plan.md`.

## Implemented in this step

- Godot project bootstrap (`project.godot`, `scenes/main.tscn`)
- Pure data combat core:
  - `SeedBundle` and isolated RNG streams (`run`, `dice`, `ai`)
  - `CombatUnit`, `CombatState`, `BattleSimulator`
  - `CombatResourceState`, `DiceFaceDefinition`, `EffectResolver`
  - Structured `ActionLogEntry` and `ActionLogger`
- Smoke test entrypoint (`scripts/tests/smoke_runner.gd`)
- CSV content pipeline skeleton:
  - Editor plugin: `addons/csv_importer/plugin.gd`
  - Sample CSV tables in `content/csv/`
  - Generated output folder `content/generated/`
- Runtime content loading:
  - `scripts/content/content_loader.gd` (generated JSON first, CSV fallback)
  - `scripts/content/unit_factory.gd` (table-driven unit instantiation)
  - `scripts/content/combat_catalog.gd` (dice/effect indexing)

## Project layout

- `scripts/core/` seed + RNG + logging primitives
- `scripts/combat/` pure simulation layer
- `scripts/tests/` deterministic checks
- `content/csv/` source tables
- `content/generated/` generated data cache
- `addons/csv_importer/` editor importer plugin

## Running

1. Open project in Godot 4.x.
2. Confirm plugin `CSV Importer` is enabled.
3. Launch main scene to run smoke checks.
4. Use editor menu: `CSV Importer/Rebuild Now` to rebuild generated cache.

## Known limitations (intentional for phase 1)

- No UI replay consumer for action logs yet.
- CSV parser is minimal and does not handle quoted commas.
- No Hub/Run loop yet; only single-NPC vs single-boss combat prototype.
- Player action selection is auto-policy driven (no manual battle UI yet).
