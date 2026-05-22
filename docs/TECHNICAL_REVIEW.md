# Technical Review Guide

This project is designed as a compact but serious Godot review artifact. It demonstrates both visible game craft and the engineering systems needed to judge behavior quality.

## Review Checklist

- The project opens directly from `project.godot`.
- The scene builds itself from script-driven components.
- Agents are visible, colored by state, and accompanied by FOV volumes.
- The HUD reports state counts, vector samples, asset scores, and review events.
- Reset and camera-cycle controls work without restarting the editor.
- The console logs FSM transitions and steering vectors.

## Runtime Loop

The simulation follows this order:

1. `Main` configures environment, lights, camera, director, and HUD.
2. `DigitalTwinEnvironment` builds procedural assets and exposes navigability services.
3. `SimulationDirector` spawns agents and aggregates telemetry.
4. Each `AutonomousAgent` advances FSM state in `_physics_process`.
5. The HUD consumes metrics snapshots from the director.

## Asset Evaluation

Assets are evaluated against a rubric:

- Silhouette readability.
- Material language.
- Navigation affordance.
- Telemetry value.
- Render budget awareness.

The goal is not just to show objects in a scene. The goal is to show assets that are inspectable, navigable, and useful to simulation behavior.

## Engineering Extension Points

- Replace the FSM with a behavior tree while keeping the same perception and steering functions.
- Replace procedural boxes with imported GLB assets while preserving obstacle metadata.
- Emit telemetry snapshots to JSON for offline review.
- Add deterministic scenario seeds for regression testing.
- Add camera bookmarks for before/after asset refinement comparisons.

## Reviewer Summary

This is a project about judgment: scene composition, AI readability, runtime tooling, and asset-quality evaluation are built together instead of treated as separate concerns.
