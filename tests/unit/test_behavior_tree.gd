extends GutTest

const AutonomousAgent := preload("res://scripts/autonomous_agent.gd")
const SimulationEnvironment := preload("res://scripts/simulation_environment.gd")


func _environment_with_front_beacon() -> SimulationEnvironment:
	var environment := SimulationEnvironment.new()
	add_child_autofree(environment)
	environment.obstacles = []
	environment.navigation_graph.clear()
	environment.navigation_point_ids.clear()
	environment.beacons = [{
		"id": "front_target",
		"name": "Front Target",
		"position": Vector3(0.0, 0.34, -4.0),
		"priority": 0.95,
		"cooldown": 0.0,
	}]
	environment.bounds_min = Vector2(-12.0, -12.0)
	environment.bounds_max = Vector2(12.0, 12.0)
	return environment


func _make_agent(environment: SimulationEnvironment) -> AutonomousAgent:
	var agent := AutonomousAgent.new()
	add_child_autofree(agent)
	agent.environment = environment
	agent.agent_id = "Parity-Agent"
	agent.rng.seed = 9101
	agent.global_position = Vector3.ZERO
	agent.current_target = Vector3(0.0, 0.34, -8.0)
	agent.current_state = AutonomousAgent.AgentState.PATROL
	agent.scan_elapsed = agent.scan_interval
	return agent


func test_behavior_tree_matches_fsm_patrol_seek_transition_at_same_seed() -> void:
	var fsm_agent := _make_agent(_environment_with_front_beacon())
	var bt_agent := _make_agent(_environment_with_front_beacon())
	bt_agent.set_controller_mode(AutonomousAgent.ControllerMode.BEHAVIOR_TREE)

	fsm_agent._tick_fsm(0.016)
	bt_agent.behavior_tree.tick(bt_agent, 0.016)

	assert_eq(bt_agent.get_state_name(), fsm_agent.get_state_name())
	assert_eq(bt_agent.active_beacon["id"], fsm_agent.active_beacon["id"])
	assert_almost_eq(bt_agent.global_position.distance_to(fsm_agent.global_position), 0.0, 0.001)
