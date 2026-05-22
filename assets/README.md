# Procedural Digital Asset Kit

This demo intentionally builds the visible environment at runtime so reviewers can inspect the asset architecture directly in GDScript. The scene uses procedural mesh primitives, authored material rules, sensor beacons, clearance zones, and an external review rubric to demonstrate both game-development execution and asset-evaluation judgment.

The important asset-facing systems live in:

- `scripts/simulation_environment.gd`
- `data/asset_review_rubric.json`
- `scripts/debug_hud.gd`

The result is a small but complete digital twin: readable silhouettes, emissive inspection targets, navigation-aware clearance, field-of-view perception, and a live quality dashboard.
