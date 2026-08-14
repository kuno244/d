# CROWNFRONT: REALMS

Offline Android-first stylized 3D strategy game built with Godot 4.7.1.

## Playable release 1.1.0

- Build and move 10 real city buildings on a 32×32 data-driven grid.
- Upgrade every functional building from level 1 through 20.
- Manage Food, Wood, Stone and Gold with storage, production and offline progress.
- Train five troop types and unlock a 20-node research dependency tree.
- Explore a deterministic 1024×1024 world (8192×8192 world units) split into 1024 streamed chunks and six biomes.
- Discover 1,097 world sites, including 600 resource deposits, 240 PvE encounters, ruins, villages, monster camps and fortresses.
- Navigate a rebuilt premium mobile HUD with resource chips, realm status, contextual actions, strategic overview and a live minimap.
- See upward-facing sculpted terrain, a daylight sky, visible water, biome color variation and batched environmental detail instead of a black world surface.
- Interact with resource nodes, ruins, villages, fortresses, PvE encounters and monster camps.
- Command the Crown Vanguard in deterministic tactical battles with Commander Strike, Shield Wall, auto battle and retreat.
- Continue through Save v3 with migrations from earlier Development 03/04 saves and atomic backup recovery.

The Android release uses the 14 approved static assets and 42 mobile LOD GLBs. The 20 unrigged high-poly character sources are never included in runtime scenes; tactical units use lightweight procedural presentation.

## Verification

- Godot 4.7.1 `Boot → MainMenu`: verified.
- City scene runtime: verified.
- World Map runtime and chunk budget: verified.
- Tactical Battle scene and reward persistence: verified.
- Automated suite: 30 PASS, one optional VTK offline-tooling test skipped, zero failures.
- Shipping gate: 14 assets, 42 mobile LODs, zero RAW source leakage.
- Android CI: imports, tests, exports, checks APK ZIP integrity and verifies its signing certificate.

## Build

Open the project in Godot 4.7.1 or run the `Crownfront Android Release` GitHub Actions workflow on branch `crownfront-realms-release`. The Android preset produces `build/CrownfrontRealms.apk` for ARM64 devices in landscape orientation.

The Android 1.1.0 release gate verifies terrain orientation, World Map runtime, screenshot brightness/color diversity, APK ZIP integrity, APK Signature Scheme v2/v3 and the `arm64-v8a` native ABI.

The downloadable APK is debug-signed for direct installation and testing. A store release must be signed with the publisher's private production key.
