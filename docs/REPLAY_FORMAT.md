# Replay JSONL Format

Replay files are newline-delimited JSON records written once per simulation tick for each live agent.

## Capture

```powershell
godot --path . --record captures/run.jsonl
```

Headless smoke capture:

```powershell
godot --headless --path . --quit-after 6 --record captures/headless-smoke.jsonl
```

## Playback

```powershell
godot --path . --replay captures/run.jsonl
```

Press `P` to toggle ghost playback. Ghost agents render as cyan translucent comparison bodies alongside the live simulation.

## Record Schema

Each line contains:

```json
{
  "time": 1.25,
  "agent_id": "Unit-01",
  "state": "Seek",
  "pos": [4.1, 0.34, -2.8],
  "vel": [1.2, 0.0, -0.4],
  "target": [9.3, 0.34, -7.8]
}
```

Fields:

- `time`: Director runtime in seconds.
- `agent_id`: Stable simulation identifier.
- `state`: Current controller state: `Patrol`, `Seek`, or `Idle`.
- `pos`: Agent world position `[x, y, z]`.
- `vel`: Last integrated world velocity `[x, y, z]`.
- `target`: Current navigation or inspection target `[x, y, z]`.
