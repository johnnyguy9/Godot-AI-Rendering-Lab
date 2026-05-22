extends Node3D
class_name SimulationDirector

const AutonomousAgent := preload("res://scripts/autonomous_agent.gd")

signal event_logged(line: String)
signal metrics_changed(snapshot: Dictionary)

var environment
var agents: Array = []
var transitions := 0
var perception_locks := 0
var vector_samples := 0
var runtime_seconds := 0.0
var metrics_elapsed := 0.0
var latest_vector_summary := "Awaiting first vector sample"
var asset_review := {}


func configure(p_environment) -> void:
	environment = p_environment
	asset_review = environment.get_asset_review_snapshot()
	_spawn_agents()
	_log("Director online: multi-agent FSM, steering, FOV perception, and asset review telemetry enabled.")


func _process(delta: float) -> void:
	runtime_seconds += delta
	metrics_elapsed += delta
	if metrics_elapsed >= 0.5:
		metrics_elapsed = 0.0
		metrics_changed.emit(get_metrics_snapshot())


func get_metrics_snapshot() -> Dictionary:
	return {
		"runtime": runtime_seconds,
		"agents": agents.size(),
		"transitions": transitions,
		"perception_locks": perception_locks,
		"vector_samples": vector_samples,
		"latest_vector": latest_vector_summary,
		"asset_review": asset_review,
	}


func _spawn_agents() -> void:
	var palettes := [
		Color(0.10, 0.78, 0.92),
		Color(0.72, 0.92, 0.34),
		Color(0.94, 0.42, 0.58),
	]
	for index in range(3):
		var agent = AutonomousAgent.new()
		agent.name = "AutonomousAgent_%02d" % (index + 1)
		add_child(agent)
		agent.configure(environment, "Unit-%02d" % (index + 1), palettes[index], 9301 + index * 997)
		agent.transitioned.connect(_on_agent_transitioned)
		agent.perception_locked.connect(_on_agent_perception_locked)
		agent.vector_evaluated.connect(_on_agent_vector_evaluated)
		agents.append(agent)

	for agent in agents:
		agent.peers = agents


func _on_agent_transitioned(agent_id: String, from_state: String, to_state: String, reason: String) -> void:
	transitions += 1
	_log("%s: %s -> %s | %s" % [agent_id, from_state, to_state, reason])


func _on_agent_perception_locked(agent_id: String, beacon_name: String) -> void:
	perception_locks += 1
	_log("%s acquired FOV target: %s" % [agent_id, beacon_name])


func _on_agent_vector_evaluated(agent_id: String, payload: Dictionary) -> void:
	vector_samples += 1
	latest_vector_summary = "%s dist %.2f step %.2f steer %s" % [
		agent_id,
		payload["distance"],
		payload["step_length"],
		_vector_to_short_string(payload["steering"]),
	]


func _vector_to_short_string(value: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]


func _log(line: String) -> void:
	print("[DIRECTOR] %s" % line)
	event_logged.emit(line)
