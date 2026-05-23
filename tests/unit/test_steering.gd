extends GutTest

const AutonomousAgent := preload("res://scripts/autonomous_agent.gd")
const SimulationEnvironment := preload("res://scripts/simulation_environment.gd")


func _make_environment() -> SimulationEnvironment:
	var environment := SimulationEnvironment.new()
	add_child_autofree(environment)
	environment.obstacles = []
	environment.bounds_min = Vector2(-10.0, -10.0)
	environment.bounds_max = Vector2(10.0, 10.0)
	return environment


func _make_agent(environment: SimulationEnvironment) -> AutonomousAgent:
	var agent := AutonomousAgent.new()
	add_child_autofree(agent)
	agent.environment = environment
	return agent


func test_obstacle_repulsion_magnitude_scales_inversely_with_distance() -> void:
	var environment := _make_environment()
	environment.obstacles = [{
		"id": "test_block",
		"label": "Test Block",
		"position": Vector3.ZERO,
		"radius": 1.0,
		"review_score": 1.0,
	}]
	var agent := _make_agent(environment)

	var near_force := agent.calculate_obstacle_avoidance_at(Vector3(1.1, 0.0, 0.0))
	var far_force := agent.calculate_obstacle_avoidance_at(Vector3(2.8, 0.0, 0.0))

	assert_gt(near_force.length(), far_force.length(), "Obstacle repulsion should grow as distance closes.")
	assert_gt(far_force.length(), 0.0, "Far sample should still be inside the influence radius.")


func test_peer_separation_is_symmetric() -> void:
	var environment := _make_environment()
	var agent := _make_agent(environment)

	var left_force := agent.calculate_peer_separation_at(Vector3.ZERO, [Vector3(1.0, 0.0, 0.0)])
	var right_force := agent.calculate_peer_separation_at(Vector3(1.0, 0.0, 0.0), [Vector3.ZERO])

	assert_almost_eq(left_force.length(), right_force.length(), 0.001, "Equal spacing should produce equal force magnitude.")
	assert_almost_eq((left_force + right_force).length(), 0.0, 0.001, "Symmetric peer samples should cancel.")


func test_boundary_bias_pushes_agent_back_inside_world_bounds() -> void:
	var environment := _make_environment()
	var agent := _make_agent(environment)
	var near_left_edge := Vector3(environment.bounds_min.x + 0.2, 0.0, 0.0)

	var bias := agent.calculate_boundary_bias_at(near_left_edge)

	assert_gt(bias.x, 0.0, "Left boundary bias should push toward positive X.")
	assert_true(environment.contains_point(environment.clamp_to_bounds(Vector3(-999.0, 0.0, 0.0))))


func test_final_steering_vector_is_unit_length() -> void:
	var environment := _make_environment()
	var agent := _make_agent(environment)

	var steering := agent.compose_steering_vector(
		Vector3(1.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.45),
		Vector3(-0.15, 0.0, 0.0),
		Vector3(0.0, 0.0, -0.2)
	)

	assert_almost_eq(steering.length(), 1.0, 0.001, "Composed steering must be normalized before integration.")
