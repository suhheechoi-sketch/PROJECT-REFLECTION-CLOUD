# PROJECT: REFLECTION — T/A DEMO NEW FLOORPLAN (TA-DEMO-1.0)

**Status:** PROPOSED / NOT VALIDATED IN GODOT 4.7.2. 2026-10-25.
**Scope:** T-01 through T-04, A lobby, A-01 through A-03, A restoration chamber, demo end only. Do not build H/B/C/D/E/F. Do not delete their existing source files; disable their routes for this demo.

## Authoritative design inputs
- `TA_DEMO_MAP_COORDINATES.json` is the machine-readable geometry, stable device IDs, door conditions, and proposed optical paths.
- `PROJECT_REFLECTION_TA_DIMENSIONED_BLUEPRINT_v1.pdf` is the human-readable six-sheet blueprint.
- Preserve confirmed v6.2 mechanics and current confirmed control scheme, even when this new layout changes coordinates.
- The old A01/A02 coordinates in the repository are superseded **only for the new demo map**, not evidence that the existing code was wrong.

## Coordinate mapping
1 unit = 1 meter. World `(x,y,z) = (map_x, height, map_z)`. Positive x east; positive z south; north is negative z. Laser plane y=1.15m. Wall thickness 0.45m, height 2.65m. Default door 2.4m wide except T room doors 2.2m. Body diameter approximately 0.72m. Optical-only slit width 0.5m; block player and permit ray via explicit collision masks.

## Room order and progression
T01 identity E → T02 pick up L07 and direct RN → T03 1 mirror → T04 2 mirrors → T04 **exit terminal E** → A lobby → A01 (3 mirrors) → A02 (docked L07, 2 normal mirrors, 1 rail mirror) → A03 (4 normal mirrors, 1 rail mirror, RO1 → RO2 → RN; optional RU) → A restoration terminal E → demo end.

## Key coordinates
- A01 source (35,43); M1 (35,33); M2 (45,33); M3 (45,43); RN (51,43); console (36,45).
- A02 dock/source (12,47); M1 (12,35); M2 (23,35); rail (19,41) → (23,41) at 0.25m; control receiver (23,46); final RN (28,41); console (9,46); handle (25,47).
- A03 stage1 source (10,73) → M1 (10,60) → RO1 (18,60). Stage2 source (15,73) → M2 (15,62) → M3 (25,62) → RO2 (25,71). Stage3 source (18,73) → M4 (18,66) → Rail (27,66) → RN (27,58). Rail starts (24,66), ends (27,66), 0.25m steps. Optional RU (31,74).
- Restoration terminal (47,62); E interaction only after A03 sets READY.

## Proposed reflection normals
The JSON includes `solution_mirror_normals_xz`: these are unit surface normals in `(x,z)`, **not** Godot rotation degrees. Compute final mesh/physics orientation according to the project's actual mirror normal convention. Reflection law: `r = d - 2*(d dot n)*n`. The listed paths use 90-degree direction changes at each mirror. Treat these normals as proposed analytical starting points, not confirmed engine results.

## Optical-only vault geometry
The JSON `optical_vaults` provides exact wall segments and beam-only slit segments for T03, T04, A01, A02, A03. Walls are player-and-beam blockers; slit segments block the player but must allow the laser via collision masks. Generate actual physics from these segments, and verify the full ray path. The PDF depicts these partitions as bright interior walls and cyan slots.

## Non-negotiable verification
The proposed coordinate paths are **not** mathematically/physically certified solutions. Build walls, inaccessible optical vaults and slit masks; compute exact mirror normals and angle conventions from the actual optics engine; simulate the rays; fix transforms as needed; verify from player reachable samples that RN direct firing is not possible; then record tested transforms/angles in `docs/TA_DEMO_VALIDATED_GEOMETRY.md` with Godot version, commit and screenshots. The A03 phases can be sequential separate shots with the **same** portable L07. A01 all three mirrors remain controllable. A02 dock is ownership transfer of same L07, never a new fixed emitter. Do not set A restored on A01 or A03 receiver alone: A03 sets READY, A restoration console E sets RESTORED.

## Art, sound, story
PS1 low-poly industrial horror, desaturated green/teal steel, sparse amber/red alerts, pipes, warning signs, machine hum, receiver chimes, readable HUD. Player is Subject 07; DIRECTOR gives instructions, with logs contradicting entry records. Keep ending as **demo cliffhanger** only, not a canon final ending.

## Deliverable
Playable T/A Godot 4.7.2 project, start-to-demo-end smoke test, regression tests, player-readable control hints, a reproducible 2–3 minute capture path. Separate what passed headless from what was manually validated. Commit/PR; do not auto-merge.
