# CROWNFRONT: REALMS — DEVELOPMENT 04 FINAL REPORT

## Verification status

- **LOGIC VERIFIED: YES**
- **PROJECT STRUCTURE VERIFIED: YES** — schema, static GDScript structure, paths and project contracts were verified without Godot runtime.
- **GODOT RUNTIME VERIFIED: NO** — no Godot executable is available in this workspace, and DEVELOPMENT 04 intentionally did not retry the already-known runtime acquisition blocker.

## CITY

### Buildings and levels

Implemented all 10 existing buildings:

1. Royal Citadel — 4×4
2. Barracks — 3×3
3. Archery Range — 3×3
4. Royal Stable — 4×3
5. Grand Academy — 4×4
6. Farm — 2×2
7. Lumber Mill — 2×2
8. Stone Quarry — 3×2
9. Watchtower — 2×2
10. Alliance Hall — 4×4

Every building has a data-driven level table **1–20**, for **200 explicit level rows** total. Level records carry progression-specific cost, construction/upgrade duration, Citadel requirement, power, storage/population contributions and building-specific functional stats rather than one copied curve for all buildings.

Royal Citadel is the main city progression gate. Non-Citadel building upgrades check the target level's Citadel requirement. Citadel milestones also expose research tiers and later feature hooks through data definitions rather than UI hardcoding.

### Grid / placement / movement

The city uses a configurable **32×32 grid**, cell size 2.0, 90° rotation steps.

Implemented:
- world ↔ grid conversion;
- rotated footprints;
- occupied/free cells;
- reservations;
- overlap/bounds checks;
- build preview validity;
- confirm/cancel;
- transactional building movement;
- cancel restoring the original cells/state;
- footprint-centered world transforms so large buildings align with the cells they actually occupy.

Mobile placement is confirmation-based: touch/mouse motion moves the preview; **Rotate / Confirm / Cancel** are separate controls. Desktop test shortcuts remain available.

`decoration_bush_cluster` is supported through the same data-driven placement architecture and can be placed, moved transactionally and removed. It contributes no progression power by default.

### Construction / upgrade

ConstructionService provides one initial builder slot with a queue-array architecture that can later expand to three slots without a save-schema redesign.

Implemented:
- new construction;
- upgrades;
- target level stored separately from current level;
- finish timestamps;
- offline completion;
- cancellation and configured refund;
- speed-up hooks;
- save/load persistence;
- progression/resource/population checks.

Building functionality respects states `PLACING`, `CONSTRUCTING`, `ACTIVE`, `UPGRADING`, and `DISABLED` where applicable.

The production/upgrade timestamp boundary was fixed so a producer accrues exactly up to upgrade start, stops while UPGRADING, and does not retroactively count upgrade time after cancellation.

### UI architecture

City HUD now contains functional mobile-oriented panels for:
- Food / Wood / Stone / Gold current and capacity;
- City Power and Population;
- Build;
- Building details;
- Construction queue;
- Troops;
- Research;
- Heroes data-only hook;
- World transition hook;
- placement Rotate / Confirm / Cancel.

Building details show current level/state/function, next-level cost/duration, meaningful stat changes, prerequisites/status, and disable Upgrade/Move/Collect when the domain state does not permit the action.

Building gameplay scripts never contain direct GLB paths; visuals resolve `asset_id → AssetService → shipping LOD`.

## ECONOMY

Resources:
- Food
- Wood
- Stone
- Gold

Starting amounts/capacities are data-driven. EconomyService implements:
- add;
- capacity clamping;
- overflow handling;
- `can_afford`;
- atomic multi-resource spending;
- reward transaction hooks.

A multi-resource cost is validated in full before anything is removed, so partial spending cannot occur.

Production mapping:
- Farm → Food
- Lumber Mill → Wood
- Stone Quarry → Stone
- Royal Citadel → Gold

Production is timestamp-based rather than frame-based. Producers have production rate, local production cap, stored amount, last-production timestamp, claim and offline accrual.

Offline production has a **10-hour base cap (36,000 s)** and a maximum accepted timestamp delta of **7 days** for corruption protection. Negative deltas are rejected/clamped and repeated claims do not duplicate the same accumulated period.

Storage uses the four shared capacities plus data-driven storage contribution from existing buildings; no unsupported Warehouse visual asset was introduced.

## POPULATION & CITY POWER

Population remains deliberately lightweight:
- base current/capacity;
- building population-cap contributions;
- deterministic recalculation;
- training-capacity influence;
- progression requirement checks;
- a small economy modifier hook at configured population conditions.

The population recalculation is idempotent and no longer self-inflates when refreshed repeatedly.

City Power is deterministic and currently includes:
- active building level power;
- completed research power;
- trained troop power;
- modifier aggregation hooks for future systems.

No random power values are used.

## TROOPS

Five gameplay/data troop types are implemented without importing their RAW high-poly character meshes:

| Troop | Training building | Building unlock | Citadel unlock |
|---|---|---:|---:|
| Swordsmen | Barracks | 1 | 2 |
| Spearmen | Barracks | 3 | 3 |
| Archers | Archery Range | 1 | 3 |
| Cavalry | Royal Stable | 1 | 5 |
| Battle Mages | Grand Academy | 5 | 7 |

TrainingService supports:
- troop type/amount;
- atomic resource cost;
- building-specific capacity;
- training speed modifiers;
- finish timestamps;
- per-building queue checks;
- offline completion;
- cancellation policy hooks;
- speed-up hooks;
- save/load;
- transfer of completed troops into persistent `troop_id → available_count` inventory.

Trained troop inventory remains separate from future army instances.

## RESEARCH

Implemented **20 research nodes** across four branches, five nodes each:

- ECONOMY
- MILITARY
- DEVELOPMENT
- EXPLORATION

The tree is a real acyclic dependency graph, including cross-branch prerequisites where defined. Research nodes support levels 1–5, costs/time curves, effects, power and prerequisite data.

Every research start checks:
1. prerequisite research levels;
2. Grand Academy requirement;
3. direct Royal Citadel research-tier requirement;
4. current queue availability;
5. full resource affordability.

Citadel tier requirements are data-driven at levels **3 / 5 / 7 / 10 / 16** for research tiers 1–5.

Modifier effects are generic rather than research-specific `if` statements. The modifier system supports FLAT and PERCENT aggregation and currently includes production, storage, construction, training, unit combat, scouting/march/gather/supply and reward hooks.

Research has one active queue initially, finish timestamp persistence, offline completion and speed-up architecture.

## SAVE

**save_version: 2**

Migration path:
- v0 → v1
- v1 → v2

Legacy DEVELOPMENT 03 saves are migrated instead of being rejected.

Dynamic save data includes:
- resources and capacities;
- building instance IDs and building definition IDs;
- grid positions / rotations;
- building levels / states;
- construction queue(s) and finish timestamps;
- producer stored amounts / timestamps;
- decorations;
- population;
- City Power;
- troop inventory / training queues;
- research progress / active research queue;
- modifiers;
- world placeholder state.

Static definitions are not duplicated into saves.

Atomic persistence remains:
`temporary → validate → previous backup → replace active`.

Malformed construction/training queue entries and corrupted numeric/timestamp values are sanitized during load/migration, and backup recovery remains covered by automated tests.

## TESTS

Fresh final verification after the last code changes:

- Existing DEVELOPMENT 03 tests: **14 / 14 PASS**
- New DEVELOPMENT 04 tests: **12 / 12 PASS**
- **Total: 26 / 26 PASS**
- Failures: **0**

A monolithic shell invocation hit the workspace aggregate timeout, so the exact same suite was rerun in three bounded groups **9 + 9 + 8**; every test returned success.

Additional final gates:
- DEVELOPMENT 04 schema validator: **PASS**, 0 errors;
- 10 buildings / 200 level rows / 20 research nodes / acyclic research DAG / save v2;
- Python `py_compile`: **PASS**;
- static GDScript/path validator: **PASS**, 0 errors;
- 26 GDScript files / 7 scene files validated structurally;
- duplicate `class_name`: 0;
- duplicate functions: 0;
- missing literal `res://` references: 0;
- forbidden source/processed runtime references: 0.

The static validator reports one advisory category: 45 lines use semicolon-separated GDScript statements. This is not reported as a compile/runtime result because Godot runtime is unavailable.

## SHIPPING

Final shipping gate:

- phase: **DEVELOPMENT_04**
- shipping static assets: **14**
- mobile LOD GLBs checked: **42**
- RAW_ONLY character/troop/PvE visual assets excluded: **20**
- shipping errors: **0**
- result: **PASS**

No source high-poly GLB, `assets/source/`, `assets/processed/`, or `Meshy_AI_model` runtime reference is used by City gameplay scenes/scripts.

The exportable DEVELOPMENT 04 package excludes high-poly source/processed content while preserving the complete Godot project, mobile static LODs, registries, data, scripts, scenes, tests, tools, docs and reports.

## RUNTIME

**GODOT RUNTIME VERIFIED: NO**

This is the unchanged DEVELOPMENT 03 environment limitation. DEVELOPMENT 04 did not spend time retrying runtime acquisition, as required. Therefore no claim is made that the GDScript project was compiled or executed by Godot in this workspace.

## BLOCKERS

The only blocker relevant to verification is **Godot runtime execution/compile validation** in the current workspace.

It does not block the next data-first World Map stage; the City/Economy/Research logic and project structure are independently verified by the deterministic and static test suite.

**CITY, ECONOMY & RESEARCH COMPLETE — READY FOR DEVELOPMENT 05**
