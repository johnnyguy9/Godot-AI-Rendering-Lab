extends GutTest

const SimulationEnvironment := preload("res://scripts/simulation_environment.gd")


func test_environment_bakes_walkable_navigation_cells() -> void:
	var environment := SimulationEnvironment.new()
	add_child_autofree(environment)

	assert_gt(environment.get_navigation_point_count(), 100, "Procedural navmesh should expose a meaningful walkable graph.")
	assert_true(environment.navigation_region is NavigationRegion3D)
	assert_gt(environment.navigation_mesh.get_polygon_count(), 100, "NavigationRegion3D should own baked quad polygons.")


func test_navigation_path_routes_through_walkable_points() -> void:
	var environment := SimulationEnvironment.new()
	add_child_autofree(environment)

	var path := environment.get_navigation_path(Vector3(-14.0, 0.34, -8.0), Vector3(14.0, 0.34, 8.0))

	assert_gt(path.size(), 2, "Long-distance route should be decomposed into path-following waypoints.")
	for point in path:
		assert_true(environment.contains_point(point), "Path point should stay inside world bounds.")
		assert_true(environment.is_navigable(point, 0.2), "Path point should avoid asset clearance.")
