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
var controller_mode := AutonomousAgent.ControllerMode.FSM
var replay_recorder


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
	if replay_recorder:
		replay_recorder.record_tick(runtime_seconds, agents)


func get_metrics_snapshot() -> Dictionary:
	return {
		"runtime": runtime_seconds,
		"agents": agents.size(),
		"state_counts": _state_counts(),
		"average_target_distance": _average_target_distance(),
		"transitions": transitions,
		"perception_locks": perception_locks,
		"vector_samples": vector_samples,
		"latest_vector": latest_vector_summary,
		"asset_review": asset_review,
		"controller": get_controller_name(),
	}


func toggle_controller() -> void:
	if controller_mode == AutonomousAgent.ControllerMode.FSM:
		set_controller_mode(AutonomousAgent.ControllerMode.BEHAVIOR_TREE)
	else:
		set_controller_mode(AutonomousAgent.ControllerMode.FSM)


func set_controller_mode(mode: int) -> void:
	controller_mode = mode
	for agent in agents:
		agent.set_controller_mode(mode)
	_log("Controller switched to %s" % get_controller_name())
	metrics_changed.emit(get_metrics_snapshot())


func get_controller_name() -> String:
	if agents.is_empty():
		return AutonomousAgent.CONTROLLER_NAMES[controller_mode]
	return agents[0].get_controller_name()


func bind_replay_recorder(recorder) -> void:
	replay_recorder = recorder


func _state_counts() -> Dictionary:
	var counts := {
		"Patrol": 0,
		"Seek": 0,
		"Idle": 0,
	}
	for agent in agents:
		var state_name: String = agent.get_state_name()
		counts[state_name] = int(counts.get(state_name, 0)) + 1
	return counts


func _average_target_distance() -> float:
	if agents.is_empty():
		return 0.0

	var total := 0.0
	for agent in agents:
		total += agent.distance_to_target()
	return total / float(agents.size())


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
		agent.set_controller_mode(controller_mode)
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
