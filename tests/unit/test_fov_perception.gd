extends GutTest

const SimulationEnvironment := preload("res://scripts/simulation_environment.gd")


func _make_environment() -> SimulationEnvironment:
	var environment := SimulationEnvironment.new()
	add_child_autofree(environment)
	environment.beacons = []
	return environment


func _make_beacon(id: String, position: Vector3, priority: float, cooldown: float = 0.0) -> Dictionary:
	return {
		"id": id,
		"name": id.capitalize(),
		"position": position,
		"priority": priority,
		"cooldown": cooldown,
	}


func test_in_cone_target_is_acquired() -> void:
	var environment := _make_environment()
	environment.beacons = [_make_beacon("front", Vector3(0.0, 0.34, -4.0), 0.8)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 101

	var result := environment.query_beacon_in_fov(Vector3.ZERO, Vector3(0.0, 0.0, -1.0), 90.0, 10.0, rng)

	assert_false(result.is_empty(), "Beacon inside forward cone should be visible.")
	assert_eq(result["id"], "front")


func test_out_of_cone_target_is_rejected() -> void:
	var environment := _make_environment()
	environment.beacons = [_make_beacon("side", Vector3(5.0, 0.34, 0.0), 0.9)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 102

	var result := environment.query_beacon_in_fov(Vector3.ZERO, Vector3(0.0, 0.0, -1.0), 70.0, 10.0, rng)

	assert_true(result.is_empty(), "Beacon outside the FOV angle must not be acquired.")


func test_cooldown_gates_recently_triggered_beacons() -> void:
	var environment := _make_environment()
	environment.beacons = [_make_beacon("cooling", Vector3(0.0, 0.34, -4.0), 1.0, 2.0)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 103

	var result := environment.query_beacon_in_fov(Vector3.ZERO, Vector3(0.0, 0.0, -1.0), 90.0, 10.0, rng)

	assert_true(result.is_empty(), "Cooldown should suppress otherwise visible beacons.")


func test_priority_ordering_beats_lower_priority_candidate() -> void:
	var environment := _make_environment()
	environment.beacons = [
		_make_beacon("low", Vector3(-0.4, 0.34, -4.0), 0.1),
		_make_beacon("high", Vector3(0.4, 0.34, -4.0), 0.9),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 104

	var result := environment.query_beacon_in_fov(Vector3.ZERO, Vector3(0.0, 0.0, -1.0), 90.0, 10.0, rng)

	assert_eq(result["id"], "high", "Priority delta should dominate the stochastic tie-breaker.")


func test_stochastic_weight_stays_inside_expected_bounds() -> void:
	var environment := _make_environment()
	var rng := RandomNumberGenerator.new()
	rng.seed = 105
	var base_score := 1.0

	for index in range(64):
		var score := environment.calculate_beacon_score(0.5, 5.0, 10.0, rng)
		assert_gte(score, base_score, "Randomized beacon score should never fall below deterministic base.")
		assert_lte(score, base_score + 0.12, "Randomized beacon score should stay within jitter budget.")
