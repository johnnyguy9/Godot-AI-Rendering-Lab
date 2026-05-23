# Contributing to Godot AI Rendering Lab

Thanks for your interest. This is a portfolio / demo project, but PRs and issues are welcome.

## Reporting bugs

Open an issue with:

- Godot version (e.g. `4.4-stable`, `4.6.dev`)
- OS and GPU (Windows / macOS / Linux, integrated vs. discrete)
- Reproduction steps starting from a fresh clone
- Console output (the project logs FSM transitions and director events — please include them)

## Proposing changes

1. Open an issue first for any change larger than a typo or small bug fix.
2. Fork and branch from `main` using a descriptive name (`feat/navmesh-pathing`, `fix/fov-clamp`).
3. Keep PRs focused — one behavior change per PR.
4. Update `README.md` and `docs/TECHNICAL_REVIEW.md` if you change a public-facing system (HUD keys, agent states, rubric schema).

## Local checks before pushing

Run the same headless smoke test CI runs:

```bash
godot --headless --path . --import
godot --headless --path . --quit
```

Neither command should print `ERROR` or `SCRIPT ERROR`.

## Code style (GDScript)

- Use `snake_case` for variables and functions, `PascalCase` for classes and nodes.
- Prefer typed signatures (`func step(delta: float) -> void:`) — they catch real bugs and make the HUD samples readable.
- Keep agent logic in `scripts/autonomous_agent.gd`. Orchestration belongs in `simulation_director.gd`. Rendering / camera concerns belong in `main.gd`.
- Data the reviewer touches (rubric, weights) goes in `data/` as JSON, not hardcoded in scripts.

## License

By contributing you agree your contributions will be licensed under the MIT License (`LICENSE`).
