# Godot AI Rendering Lab

An expert-level Godot 4 demo built to showcase practical game-development, interactive-systems, AI behavior, procedural asset, and rendering-review skills for AI gaming and digital asset refinement roles.

## Why This Exists

The target signal is simple: when someone reviews this repository, they should see that the developer can build in Godot, reason about autonomous agents, create readable digital assets, expose useful telemetry, and judge whether a simulation is visually and mechanically working.

This project is intentionally not a static scene. It is a live AI rendering lab:

- Three autonomous agents patrol a procedural digital twin.
- Agents use a finite state machine with `Patrol`, `Seek`, and `Idle` states.
- Each agent has field-of-view perception and locks onto sensor beacons.
- Steering combines target pursuit, obstacle avoidance, boundary correction, and peer separation.
- The environment is built from procedural digital assets with material language and clearance semantics.
- A live evaluation HUD reports transitions, FOV locks, vector samples, and asset quality data.

## Portfolio Fit

This repository maps directly to the kind of experience requested by game-development and AI rendering teams:

- Godot implementation, not just pseudocode.
- Procedural asset construction and material styling.
- Multi-agent behavior with readable AI state transitions.
- Runtime telemetry for debugging and judging simulation quality.
- A digital twin style environment designed for inspection and refinement.
- Clear architecture that separates rendering, environment semantics, agent logic, and review UI.

## Controls

- `F3`: Toggle evaluation HUD.
- `C`: Cycle review camera angles.
- `R`: Reset the simulation.

## System Architecture

```text
Main Scene
├── SimulationApplication setup
│   ├── WorldEnvironment, lighting, camera
│   ├── DigitalTwinEnvironment
│   ├── SimulationDirector
│   └── Evaluation HUD
├── DigitalTwinEnvironment
│   ├── Procedural floor and grid
│   ├── Digital asset blocks with emissive accents
│   ├── Navigation bounds and obstacle clearances
│   ├── Sensor beacons
│   └── Asset review rubric
├── AutonomousAgent
│   ├── FSM: Patrol, Seek, Idle
│   ├── FOV perception cone
│   ├── Steering vectors
│   ├── Boundary correction
│   └── Console telemetry
└── DebugHud
    ├── Runtime metrics
    ├── Vector sample summaries
    ├── Asset quality score
    └── Review event log
```

## Core Mechanics

### Multi-Agent FSM

Each agent runs a finite state machine:

- `Patrol`: Samples navigable waypoints and roams the digital twin.
- `Seek`: Locks onto a perceived sensor beacon and moves at a faster response speed.
- `Idle`: Pauses briefly to create believable cadence and allow route replanning.

Transitions are emitted to the console and HUD with the triggering reason, making the AI readable to reviewers.

### Field-of-View Perception

Agents do not globally know about every target. They scan for beacons inside a forward-facing FOV cone. This makes perception visual, inspectable, and connected to the rendered scene.

### Steering and Spatial Evaluation

Movement is driven by a blended steering model:

- Desired direction toward the active target.
- Obstacle avoidance around digital assets.
- Peer separation between agents.
- Boundary bias near the navigable limits.
- Final clamp against the environment bounds.

The console logs vector calculations so reviewers can see the agent reasoning loop.

### Digital Asset Review

The project includes `data/asset_review_rubric.json`, which describes how assets are evaluated for readability, material language, navigation affordance, telemetry value, and render budget awareness. The HUD surfaces this as a live quality score.

## Requirements

- Godot 4.6 or newer.

No third-party Godot plugins are required.

## Running The Demo

Open the repository folder in Godot and run the project.

Command-line launch:

```powershell
godot --path .
```

If Godot is installed through Winget, the executable is usually available as `godot` after restarting the terminal. The editor executable can also be launched directly from the Winget package folder.

## Files Of Interest

- `scenes/main.tscn`: Main scene entry point.
- `scripts/main.gd`: Rendering setup, camera modes, simulation lifecycle.
- `scripts/simulation_environment.gd`: Procedural digital twin assets, navigability, beacons, asset review loading.
- `scripts/autonomous_agent.gd`: FSM, FOV perception, steering, vector telemetry.
- `scripts/simulation_director.gd`: Multi-agent orchestration and metrics aggregation.
- `scripts/debug_hud.gd`: Live review HUD.
- `data/asset_review_rubric.json`: Asset-quality framework.

## Future Roadmap

- Add screenshot capture and replay export for review packets.
- Add behavior-tree experiments alongside the FSM.
- Add navmesh-based path planning for dense asset layouts.
- Add model import examples for authored GLB assets.
- Add agentic orchestration hooks for external planners assigning inspection objectives.
- Add automated visual scoring for digital asset refinement workflows.

## Professional Signal

This project is designed to show that the developer can do more than assemble a scene. It demonstrates the ability to create a game-system prototype, reason about AI behavior, build digital assets with production constraints, expose evaluation telemetry, and document the work for technical reviewers.
