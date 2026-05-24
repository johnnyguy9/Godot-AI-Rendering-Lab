# Code audit — May 2026

A close read of every script in the repo against the README and TECHNICAL_REVIEW promises. This document records what was found and the changes shipped in the same PR.

## Summary

The codebase is small (~30 KB of GDScript across five scripts) and reads as portfolio-quality. There are no crashing bugs and no security issues. The improvements below address gaps between what the docs promise and what the code currently does, plus a handful of small robustness issues.

## Findings

### 1. CI only validates that the project boots, not that it behaves
`.github/workflows/ci.yml` runs `godot --headless --path . --quit` and greps for `ERROR` in the log. That catches script-parse failures and missing resource references, but it does not catch behavior regressions. The roadmap calls out "deterministic scenario seeds for regression testing" — the hooks exist (seeds are already hardcoded in `simulation_director._spawn_agents`) but no runner consumes them.

**Fix shipped:** new `scripts/scenario_runner.gd` plus a CI step that runs a fixed-frame headless scenario and asserts on the JSON output. The assertion catches real behavior breaks (agents stop transitioning, perception locks vanish, beacons never get triggered).

### 2. No pause control
Every reviewer asks for one. The HUD says "F3 HUD | C Camera | R Reset" — no pause.

**Fix shipped:** `pause_simulation` input action bound to `Space`, handled in `main.gd`. HUD footer updated to advertise it.

### 3. `_transition_to(next_state: int, ...)` is untyped
`AgentState` is a typed enum, but the transition function takes `int`. Passing a non-enum int compiles. Other callers happen to pass enum values, so it works — but the type information is lost.

**Fix shipped:** parameter typed as `AgentState`.

### 4. HUD snapshot access is fragile
`debug_hud._on_metrics_changed` accesses `snapshot["latest_vector"]` and `snapshot["asset_review"]` without guards. If the director is in a transient state (e.g. during a reset between `queue_free` and `_build_simulation`), accessing missing keys raises an error.

**Fix shipped:** defensive `get()` with fallbacks. Doesn't change rendered output for the normal path.

### 5. No `.editorconfig`
GDScript indentation is tabs by convention. Mixed-indent commits from editors that default to spaces break the diff view.

**Fix shipped:** `.editorconfig` enforcing tab indentation on `.gd`, two-space on YAML/JSON.

## Non-issues considered and left as-is

- **Obstacle/peer query performance.** Linear scans over 6 obstacles and 3 agents are fine. A spatial index would be premature optimization at this scale.
- **`look_at()` degeneracy when steering is vertical.** `steering.y` is forced to 0 upstream (`target_delta.y = 0.0`), so the up vector and look direction can't go parallel. No guard needed.
- **`_obstacle_avoidance` divide-by-zero.** The `distance > 0.001` guard handles it, and Godot's `.normalized()` is safe on zero-length anyway.
- **`SimulationEnvironment` size (266 lines).** Could be split into `digital_assets.gd` + `beacons.gd`, but the docs explicitly favor one-file-per-system for portfolio readability. Defer.
- **HUD misses the director's startup `event_logged` calls.** They happen before `hud.bind()` runs. Currently those lines only appear in the console. Could be fixed by reordering construction, but the console log is the primary record and the HUD picks up everything from the first metrics tick onward. Defer.
- **No GUT (Godot Unit Test) framework.** Adding an `addons/gut/` directory is a sizable footprint for a portfolio repo and the scenario runner gives better behavior coverage than unit tests would.
