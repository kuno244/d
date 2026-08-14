# CROWNFRONT: REALMS — DEVELOPMENT 03 FINAL REPORT

## Status

DEVELOPMENT 03 produced the complete static mobile batch and a real Godot 4.x project foundation. Project files and all non-runtime validations are complete. Godot executable runtime validation is **not** claimed because the executable could not be materialized in this workspace.

## STATIC ASSETS

- Static assets in scope: **14 / 14 processed**.
- Quality gate passed: **14**.
- Rejected: **0**.
- Mobile LOD files: **42** (LOD0/LOD1/LOD2 for every static asset).
- All mobile LOD GLBs contain **0 embedded texture images**; the verified shipping strategy bakes the existing Base Color into vertex colors to prevent the UV-collapse corruption demonstrated during DEVELOPMENT 02.
- Source PBR is retained only in source files: Base Color 4096×4096, Normal 4096×4096, Metallic/Roughness 2048×2048.
- A differentiated full-material/UV-preserving LOD0 candidate was attempted on Royal Citadel, but the UV-preserving decimator did not finish within the 120-second tooling gate. It was not promoted. Therefore no unverified full-material mobile LOD0 is claimed.
- No 4K texture leaks exist in shipping GLBs.

| Asset ID | Source tris | LOD0 | LOD1 | LOD2 | Collision | Quality |
|---|---:|---:|---:|---:|---|---|
| `world_rock_cluster` | 1,998,096 | 38,120 | 14,644 | 4,387 | compound_boxes | PASS |
| `world_stylized_tree` | 1,953,030 | 27,933 | 11,971 | 3,999 | compound_boxes | PASS |
| `decoration_bush_cluster` | 1,977,478 | 15,843 | 6,565 | 2,623 | none | PASS |
| `building_watchtower` | 1,990,500 | 50,350 | 23,862 | 9,001 | compound_boxes | PASS |
| `world_stone_bridge` | 1,949,618 | 48,374 | 22,035 | 7,949 | compound_boxes | PASS |
| `building_archery_range` | 1,990,584 | 48,056 | 22,913 | 9,166 | compound_boxes | PASS |
| `building_grand_academy` | 1,976,750 | 77,939 | 37,823 | 16,066 | compound_boxes | PASS |
| `building_royal_citadel` | 1,917,250 | 74,689 | 38,100 | 16,785 | compound_boxes | PASS |
| `building_lumber_mill` | 1,976,988 | 37,641 | 17,857 | 6,753 | compound_boxes | PASS |
| `building_alliance_hall` | 1,958,076 | 72,067 | 35,623 | 14,869 | compound_boxes | PASS |
| `building_barracks` | 1,879,474 | 45,067 | 22,471 | 8,459 | compound_boxes | PASS |
| `building_farm` | 1,994,620 | 36,441 | 16,981 | 6,523 | compound_boxes | PASS |
| `building_stone_quarry` | 1,981,100 | 39,809 | 18,972 | 7,136 | compound_boxes | PASS |
| `building_royal_stable` | 1,972,208 | 52,116 | 26,204 | 10,401 | compound_boxes | PASS |

Collision policy:
- buildings: compound primitive boxes, collision mesh triangles = 0;
- tree/bridge/rock: simple compound primitive boxes, collision mesh triangles = 0;
- bush decoration: no collision by default.

The visual gate verified that LOD0/LOD1 retain the large silhouette/forms for the isometric strategy camera. LOD2 is explicitly tagged **distance-only**. Geometry validation found no degenerate triangles in the 42 shipping LOD files.

## ASSET REGISTRY / SHIPPING

`registry/asset_registry.json` is schema version 3 / DEVELOPMENT_03 and remains the single source of truth. Each static asset now records source triangles, all three LOD triangle counts and paths, source texture sizes, mobile texture strategy, collision metadata, quality gate status, shipping status, and working/processed paths.

Shipping manifest:
- shipping asset IDs: **14**;
- shipping LOD files: **42**;
- remaining RAW_ONLY/BLOCKED assets: **20** (10 heroes, 5 troops, 5 PvE creatures);
- source leakage: **0**;
- undeclared mobile GLBs: **0**;
- shipping gate errors: **0**;
- result: **PASS**.

No HERO/TROOP/PVE source mesh is referenced by Boot, Frontend, City, World, Battle, scripts, or data runtime paths. Those entities are data-only in DEVELOPMENT 03.

## GODOT TOOLCHAIN

Official Godot release discovery succeeded through the official `godotengine/godot-builds` repository:
- official stable release identified: **Godot 4.7.1-stable**;
- target portable binary: `Godot_v4.7.1-stable_linux.x86_64.zip`;
- release SHA-256 from official metadata: `c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba`.

Runtime status:
- preinstalled Godot executable: **not found**;
- apt/package-manager Godot 4.x candidate: **not found**;
- portable executable downloaded: **no**;
- executable path: **none**;
- `godot --version`: **not run**;
- headless smoke test: **not run**;
- renderer runtime test: **not run**;
- status: **GODOT_RUNTIME_TEST_BLOCKED**.

Exact reason: the official release could be identified through GitHub, but the workspace cannot materialize the binary. Direct workspace access to `github.com` is blocked by DNS/network policy, while the GitHub connector in this session exposes release metadata but not a usable release-asset binary download. No third-party build was used.

## PROJECT FILES CREATED

Real project root: `CrownfrontRealms/`

Created `project.godot` with Android-first GL Compatibility configuration and only these persistent autoload services:
- `GameState`;
- `DataRegistry`;
- `SaveService`;
- `SceneRouter`;
- `GameClock`;
- `EventHub`.

`AssetService` is deliberately **not** an autoload. It is owned by DataRegistry and resolves gameplay references by permanent `asset_id`, never by `Meshy_AI_model.glb`.

Scenes created:
- `scenes/boot/Boot.tscn`;
- `scenes/frontend/MainMenu.tscn`;
- `scenes/city/City.tscn`;
- `scenes/world/WorldMap.tscn` foundation shell;
- `scenes/battle/TacticalBattle.tscn` foundation shell.

Boot flow implemented:
1. initialize DataRegistry;
2. validate data + Asset Registry;
3. load/recover/create save;
4. validate save;
5. populate GameState;
6. route to Frontend.

Frontend includes:
- New Game;
- Continue;
- Settings;
- desktop Quit;
- graphics preset;
- desktop test resolution;
- window/fullscreen test mode;
- camera sensitivity;
- UI scale.

No music/SFX/voice controls exist.

Save foundation includes:
- `save_version = 1`;
- profile metadata;
- Food/Wood/Stone/Gold;
- city placeholder state;
- progression placeholder state;
- world placeholder state;
- v0→v1 migration;
- temporary write → validation → backup → atomic replacement;
- backup recovery.

Data definitions created:
- Resources: **4**;
- Buildings: **10**;
- Troops: **5**;
- Heroes: **10**;
- PvE: **5**.

`hero_fire_mage_001` is preserved exactly and displayed neutrally as **Fire Mage 001**; it was not renamed to Lyra Emberveil.

City foundation contains:
- terrain/platform;
- CameraRoot + Camera3D;
- BuildingRoot;
- DecorationRoot;
- SelectionLayer;
- UIRoot;
- City controller;
- selection raycast foundation;
- selectable building component;
- building info view model;
- camera focus hook.

Production-ready LOD0 instances used in City:
- Royal Citadel;
- Grand Academy;
- Alliance Hall.

No RAW 2M-triangle model is instantiated.

Strategy camera foundation includes desktop WASD, mouse drag, wheel zoom, mobile one-finger pan, two-finger pinch, magnify gesture, inertia, zoom smoothing, bounds, and focus target. Direction contract is explicit in code: **A = Vector2(-1, 0), D = Vector2(1, 0)**.

## AUTOMATED VERIFICATION

Fresh DEVELOPMENT 03 verification:
- Python compile: **PASS**;
- automated test files: **14 / 14 PASS**;
- Asset Registry validation: PASS;
- duplicate IDs: PASS;
- static registry: PASS;
- shipping manifest: PASS;
- resource definitions: PASS;
- building/troop/hero/PvE references: PASS;
- save schema/migration: PASS;
- atomic save/recovery: PASS;
- missing resource references: PASS;
- RAW runtime leakage: PASS;
- audio scope exclusion: PASS;
- camera direction/input contract: PASS;
- scene/project foundation contract: PASS;
- shipping gate: **42 LOD checked, 0 errors, PASS**.

Because Godot runtime itself is unavailable, these results are **static/tooling verification**, not a claim that Godot parsed or executed the project. In particular, Boot → Frontend → City headless smoke remains unverified until a Godot executable can actually run.

## GITHUB

A final connected-repository search still finds no suitable `CROWNFRONT` repository. `kuno244/d` is untouched. The project is prepared as an exportable package for later import into the correct repository.

## REAL BLOCKERS

1. **Godot runtime validation** — official 4.7.1-stable was identified, but executable download/run is blocked by this workspace's binary/network limitations. This blocks runtime/headless/renderer verification only; it does not block project-file creation.
2. **Character visual production pipeline** — the 20 HERO/TROOP/PvE assets remain RAW_ONLY because Blender/production retopology+rigging tooling is unavailable and the VTK character method already failed its quality gate. This does **not** block City/Economy/Research/World/Army/PvE simulation data-first development.

Audio is intentionally outside scope and is not a blocker.

**STATIC PIPELINE & PROJECT FOUNDATION COMPLETE — READY FOR DEVELOPMENT 04**

## EXPORT PACKAGE

The DEVELOPMENT 03 ZIP contains the Godot project foundation and all 42 mobile shipping GLBs. Heavy `assets/source/*.glb` and `assets/processed/**` working data are intentionally excluded from the ZIP; originals remain on Google Drive and source identity/path metadata remains in the Asset Registry.

Package filename: `CROWNFRONT_REALMS_DEVELOPMENT_03_PACKAGE.zip`
