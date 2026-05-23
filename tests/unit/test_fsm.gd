extends GutTest

const AutonomousAgent := preload("res://scripts/autonomous_agent.gd")
const SimulationEnvironment := preload("res://scripts/simulation_environment.gd")


func _make_environment() -> SimulationEnvironment:
	var environment := SimulationEnvironment.new()
	add_child_autofree(environment)
	environment.obstacles = []
	environment.beacons = []
	environment.navigation_graph.clear()
	environment.navigation_point_ids.clear()
	environment.bounds_min = Vector2(-12.0, -12.0)
	environment.bounds_max = Vector2(12.0, 12.0)
	return environment


func _make_agent(environment: SimulationEnvironment) -> AutonomousAgent:
	var agent := AutonomousAgent.new()
	add_child_autofree(agent)
	agent.environment = environment
	agent.agent_id = "Spec-Agent"
	agent.rng.seed = 5001
	agent.global_position = Vector3.ZERO
	agent.current_target = Vector3(0.0, 0.34, -8.0)
	return agent


func _beacon(id: String, position: Vector3) -> Dictionary:
	return {
		"id": id,
		"name": id.capitalize(),
		"position": position,
		"priority": 0.95,
		"cooldown": 0.0,
	}


func test_patrol_to_seek_requires_perceived_beacon() -> void:
	var environment := _make_environment()
	var agent := _make_agent(environment)
	agent.current_state = AutonomousAgent.AgentState.PATROL
	agent.scan_elapsed = agent.scan_interval
	environment.beacons = [_beacon("side_target", Vector3(6.0, 0.34, 0.0))]

	agent._update_patrol(0.016)
	assert_eq(agent.get_state_name(), "Patrol", "Out-of-cone beacon must not trigger Seek.")

	agent.scan_elapsed = agent.scan_interval
	environment.beacons = [_beacon("front_target", Vector3(0.0, 0.34, -4.0))]

	agent._update_patrol(0.016)
	assert_eq(agent.get_state_name(), "Seek", "Visible beacon should trigger Patrol -> Seek.")


func test_seek_to_idle_on_timeout() -> void:
	var environment := _make_environment()
	var agent := _make_agent(environment)
	agent.current_state = AutonomousAgent.AgentState.SEEK
	agent.state_time = agent.seek_timeout
	agent.current_target = Vector3(10.0, 0.34, -10.0)
	agent.active_beacon = _beacon("timeout_target", agent.current_target)

	agent._update_seek(0.016)

	assert_eq(agent.get_state_name(), "Idle")
	assert_true(agent.active_beacon.is_empty(), "Timed-out Seek should clear the active beacon.")


func test_idle_to_patrol_on_dwell_expiry() -> void:
	var environment := _make_environment()
	var agent := _make_agent(environment)
	agent.current_state = AutonomousAgent.AgentState.IDLE
	agent.idle_duration = 0.5
	agent.state_time = 0.5

	agent._update_idle()

	assert_eq(agent.get_state_name(), "Patrol")
