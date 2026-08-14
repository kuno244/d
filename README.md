# CROWNFRONT: REALMS

Android-first stylized 3D strategy project for Godot 4.x.

## Current state — DEVELOPMENT 04

The project now includes a data-driven city gameplay layer on top of the DEVELOPMENT 03 shipping/static-asset foundation:

- 32×32 configurable city grid with world/grid conversion, rotation, occupancy, reservation and transactional move/cancel.
- Build mode for all 10 real building definitions plus `decoration_bush_cluster` placement/move/removal.
- 10 buildings with explicit level data for levels 1–20 (200 level rows total), Citadel progression gates, costs, timers, power, storage, population and building-specific stats.
- Food/Wood/Stone/Gold economy with capacity, atomic multi-resource spending and overflow clamping.
- Time-based and offline resource production with a 10-hour base offline cap and timestamp corruption guards.
- Versioned construction queue architecture with one initial builder slot, upgrades, cancellation/refund and speed-up hooks.
- Population and deterministic City Power derived from buildings, research and trained troops.
- Five troop types with building/Citadel unlocks, training queues, capacity, costs, timers and persistent troop inventory.
- Research system with 20 nodes across Economy, Military, Development and Exploration, real dependency DAG, Academy/Citadel gates and data-driven modifiers.
- Save schema v2 with v0/v1 migrations, timers, queues, grid positions, rotations, production timestamps, research, troops, modifiers and atomic backup recovery.
- Functional mobile-first City HUD architecture: resources, Build, Building, Construction, Troops, Research, Heroes data hook, World transition hook and placement confirmation controls.
- Asset usage remains shipping-safe: 14 processed static assets / 42 mobile LOD GLBs; 20 character/troop/PvE source visuals remain RAW_ONLY data entities.

## Verification

`LOGIC VERIFIED: YES`

`PROJECT STRUCTURE VERIFIED: YES` through deterministic Python reference tests plus schema/path/static GDScript validation.

`GODOT RUNTIME VERIFIED: NO` — the existing DEVELOPMENT 03 workspace limitation remains. Runtime execution/compile is not claimed.

Fresh DEVELOPMENT 04 verification: 26/26 script tests PASS, schema PASS, Python compile PASS, shipping gate PASS.

Reports are under `reports/`.
