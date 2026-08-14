# CROWNFRONT: REALMS

Offline Android-first stylized 3D strategy game built with Godot 4.7.1.

## Playable release 1.0.0

- Build and move 10 real city buildings on a 32×32 data-driven grid.
- Upgrade every functional building from level 1 through 20.
- Manage Food, Wood, Stone and Gold with storage, production and offline progress.
- Train five troop types and unlock a 20-node research dependency tree.
- Explore a deterministic 64×64 world split into 64 streamed chunks and six biomes.
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

Verified Android 1.0.0 artifact:

- size: 60,035,613 bytes;
- SHA-256: `4221647e9903f91a2f91647b94b2f41af9679325adb40ae056f8d2eb8ac3d711`;
- APK Signature Scheme v2/v3: verified;
- native ABI: `arm64-v8a` only.

The downloadable APK is debug-signed for direct installation and testing. A store release must be signed with the publisher's private production key.
