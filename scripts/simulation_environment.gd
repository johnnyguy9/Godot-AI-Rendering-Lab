extends Node3D
class_name SimulationEnvironment

const FLOOR_EXTENTS := Vector2(17.0, 11.0)
const WALKABLE_MARGIN := 1.1
const BEACON_HEIGHT := 0.34
const NAV_CELL_SIZE := 1.0
const DEFAULT_RUBRIC_PATH := "res://data/asset_review_rubric.json"
const RUBRIC_SCHEMA_PATH := "res://data/asset_review_rubric.schema.json"

var bounds_min := Vector2(-FLOOR_EXTENTS.x + WALKABLE_MARGIN, -FLOOR_EXTENTS.y + WALKABLE_MARGIN)
var bounds_max := Vector2(FLOOR_EXTENTS.x - WALKABLE_MARGIN, FLOOR_EXTENTS.y - WALKABLE_MARGIN)
var obstacles: Array[Dictionary] = []
var beacons: Array[Dictionary] = []
var asset_quality_score := 0.0
var dense_preset := false
var navigation_region: NavigationRegion3D
var navigation_mesh: NavigationMesh
var navigation_graph := AStar3D.new()
var navigation_point_ids: Array[int] = []
var navigation_point_lookup: Dictionary = {}
var rubric_path := DEFAULT_RUBRIC_PATH
var rubric_data: Dictionary = {}
var startup_valid := true


func _ready() -> void:
	dense_preset = _has_cli_flag("--dense")
	if not _load_and_validate_rubric():
		startup_valid = false
		set_process(false)
		get_tree().quit(1)
		return
	_build_floor()
	_build_grid()
	_build_digital_assets()
	_build_sensor_beacons()
	_bake_navigation_region()
	asset_quality_score = _calculate_asset_quality_score()
	if dense_preset:
		print("[NAV] Dense preset enabled: navmesh contains %d walkable cells around %d assets." % [navigation_point_ids.size(), obstacles.size()])


func sample_navigable_point(rng: RandomNumberGenerator, clearance: float = 0.75) -> Vector3:
	if not navigation_point_ids.is_empty():
		for graph_attempt in range(64):
			var point_id: int = navigation_point_ids[rng.randi_range(0, navigation_point_ids.size() - 1)]
			var graph_point := navigation_graph.get_point_position(point_id)
			var jitter := Vector3(
				rng.randf_range(-NAV_CELL_SIZE * 0.32, NAV_CELL_SIZE * 0.32),
				0.0,
				rng.randf_range(-NAV_CELL_SIZE * 0.32, NAV_CELL_SIZE * 0.32)
			)
			var candidate := Vector3(graph_point.x + jitter.x, BEACON_HEIGHT, graph_point.z + jitter.z)
			if is_navigable(candidate, clearance):
				return candidate

	for attempt in range(128):
		var candidate := Vector3(
			rng.randf_range(bounds_min.x, bounds_max.x),
			BEACON_HEIGHT,
			rng.randf_range(bounds_min.y, bounds_max.y)
		)
		if is_navigable(candidate, clearance):
			return candidate
	push_warning("Navigation sampler exhausted attempts; returning origin fallback.")
	return Vector3(0.0, BEACON_HEIGHT, 0.0)


func is_navigable(point: Vector3, clearance: float = 0.75) -> bool:
	if not contains_point(point):
		return false

	var point_2d := Vector2(point.x, point.z)
	for obstacle in obstacles:
		var obstacle_position: Vector3 = obstacle["position"]
		var obstacle_2d := Vector2(obstacle_position.x, obstacle_position.z)
		if point_2d.distance_to(obstacle_2d) <= obstacle["radius"] + clearance:
			return false
	return true


func contains_point(point: Vector3) -> bool:
	return point.x >= bounds_min.x and point.x <= bounds_max.x and point.z >= bounds_min.y and point.z <= bounds_max.y


func clamp_to_bounds(point: Vector3) -> Vector3:
	return Vector3(
		clampf(point.x, bounds_min.x, bounds_max.x),
		point.y,
		clampf(point.z, bounds_min.y, bounds_max.y)
	)


func get_obstacles() -> Array[Dictionary]:
	return obstacles


func get_asset_review_snapshot() -> Dictionary:
	return {
		"asset_count": obstacles.size(),
		"beacon_count": beacons.size(),
		"quality_score": asset_quality_score,
		"rubric": rubric_data,
		"rubric_path": rubric_path,
		"nav_cells": navigation_point_ids.size(),
		"dense_preset": dense_preset,
	}


func is_startup_valid() -> bool:
	return startup_valid


func query_beacon_in_fov(origin: Vector3, forward: Vector3, fov_degrees: float, scan_radius: float, rng: RandomNumberGenerator) -> Dictionary:
	var best_beacon: Dictionary = {}
	var best_weight := -1.0
	var half_angle := deg_to_rad(fov_degrees * 0.5)
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()

	for index in range(beacons.size()):
		var beacon: Dictionary = beacons[index]
		if beacon["cooldown"] > 0.0:
			continue

		var to_beacon: Vector3 = beacon["position"] - origin
		var flat_to_beacon := Vector3(to_beacon.x, 0.0, to_beacon.z)
		var distance := flat_to_beacon.length()
		if distance <= 0.01 or distance > scan_radius:
			continue

		var angle := flat_forward.angle_to(flat_to_beacon.normalized())
		if angle > half_angle:
			continue

		var priority: float = beacon["priority"]
		var score := calculate_beacon_score(priority, distance, scan_radius, rng)
		if score > best_weight:
			best_weight = score
			best_beacon = beacon

	if not best_beacon.is_empty():
		_mark_beacon_triggered(best_beacon["id"])
	return best_beacon


func calculate_beacon_score(priority: float, distance: float, scan_radius: float, rng: RandomNumberGenerator) -> float:
	var distance_weight := 1.0 - clampf(distance / scan_radius, 0.0, 1.0)
	return priority + distance_weight + rng.randf_range(0.0, 0.12)


func get_navigation_path(start: Vector3, target: Vector3) -> PackedVector3Array:
	if navigation_point_ids.is_empty():
		return PackedVector3Array([clamp_to_bounds(target)])

	var start_id := _nearest_navigation_point_id(start)
	var target_id := _nearest_navigation_point_id(target)
	if start_id == -1 or target_id == -1:
		return PackedVector3Array([clamp_to_bounds(target)])

	var point_ids := navigation_graph.get_id_path(start_id, target_id)
	var path := PackedVector3Array()
	for point_id in point_ids:
		var point := navigation_graph.get_point_position(point_id)
		path.append(Vector3(point.x, BEACON_HEIGHT, point.z))

	var final_target := clamp_to_bounds(target)
	if path.is_empty() or path[path.size() - 1].distance_to(final_target) > 0.2:
		path.append(final_target)
	return path


func get_navigation_point_count() -> int:
	return navigation_point_ids.size()


func _bake_navigation_region() -> void:
	navigation_graph.clear()
	navigation_point_ids.clear()
	navigation_point_lookup.clear()

	navigation_region = NavigationRegion3D.new()
	navigation_region.name = "ProceduralNavigationRegion"
	add_child(navigation_region)

	navigation_mesh = NavigationMesh.new()
	var vertices := PackedVector3Array()
	var vertex_lookup: Dictionary = {}
	var polygons: Array[PackedInt32Array] = []

	var x_cells := int(floor((bounds_max.x - bounds_min.x) / NAV_CELL_SIZE))
	var z_cells := int(floor((bounds_max.y - bounds_min.y) / NAV_CELL_SIZE))
	for x_index in range(x_cells):
		for z_index in range(z_cells):
			var center_2d := Vector2(
				bounds_min.x + (float(x_index) + 0.5) * NAV_CELL_SIZE,
				bounds_min.y + (float(z_index) + 0.5) * NAV_CELL_SIZE
			)
			var center := Vector3(center_2d.x, BEACON_HEIGHT, center_2d.y)
			if not is_navigable(center, 0.55):
				continue

			var polygon := PackedInt32Array([
				_nav_vertex_index(vertices, vertex_lookup, x_index, z_index),
				_nav_vertex_index(vertices, vertex_lookup, x_index + 1, z_index),
				_nav_vertex_index(vertices, vertex_lookup, x_index + 1, z_index + 1),
				_nav_vertex_index(vertices, vertex_lookup, x_index, z_index + 1),
			])
			polygons.append(polygon)

			var point_id := x_index * 1000 + z_index
			navigation_graph.add_point(point_id, center)
			navigation_point_ids.append(point_id)
			navigation_point_lookup[_nav_key(x_index, z_index)] = point_id

	navigation_mesh.set_vertices(vertices)
	for polygon in polygons:
		navigation_mesh.add_polygon(polygon)
	navigation_region.navigation_mesh = navigation_mesh

	for key in navigation_point_lookup.keys():
		var parts := String(key).split(":")
		var x_index := int(parts[0])
		var z_index := int(parts[1])
		var point_id: int = navigation_point_lookup[key]
		for offset in [Vector2i(1, 0), Vector2i(0, 1)]:
			var neighbor_key := _nav_key(x_index + offset.x, z_index + offset.y)
			if navigation_point_lookup.has(neighbor_key):
				navigation_graph.connect_points(point_id, int(navigation_point_lookup[neighbor_key]), true)


func _nav_vertex_index(vertices: PackedVector3Array, vertex_lookup: Dictionary, x_index: int, z_index: int) -> int:
	var key := _nav_key(x_index, z_index)
	if vertex_lookup.has(key):
		return int(vertex_lookup[key])

	var vertex := Vector3(
		bounds_min.x + float(x_index) * NAV_CELL_SIZE,
		0.02,
		bounds_min.y + float(z_index) * NAV_CELL_SIZE
	)
	var index := vertices.size()
	vertices.append(vertex)
	vertex_lookup[key] = index
	return index


func _nearest_navigation_point_id(point: Vector3) -> int:
	var best_id := -1
	var best_distance := INF
	var flat_point := Vector3(point.x, BEACON_HEIGHT, point.z)
	for point_id in navigation_point_ids:
		var candidate := navigation_graph.get_point_position(point_id)
		var distance := flat_point.distance_squared_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best_id = point_id
	return best_id


func _nav_key(x_index: int, z_index: int) -> String:
	return "%d:%d" % [x_index, z_index]


func _has_cli_flag(flag: String) -> bool:
	return OS.get_cmdline_args().has(flag) or OS.get_cmdline_user_args().has(flag)


func _get_cli_value(flag: String, default_value: String = "") -> String:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for index in range(args.size()):
		var arg := str(args[index])
		if arg == flag and index + 1 < args.size():
			return str(args[index + 1])
		if arg.begins_with("%s=" % flag):
			return arg.substr(flag.length() + 1)
	return default_value


func _resolve_data_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path():
		return path
	return "res://%s" % path


func _process(delta: float) -> void:
	for index in range(beacons.size()):
		if beacons[index]["cooldown"] > 0.0:
			beacons[index]["cooldown"] = maxf(0.0, beacons[index]["cooldown"] - delta)


func _build_floor() -> void:
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(FLOOR_EXTENTS.x * 2.0, 0.18, FLOOR_EXTENTS.y * 2.0)

	var floor := MeshInstance3D.new()
	floor.name = "ProceduralOperationsFloor"
	floor.mesh = floor_mesh
	floor.position = Vector3(0.0, -0.12, 0.0)
	floor.material_override = _material(Color(0.08, 0.10, 0.12), 0.86, 0.12)
	add_child(floor)


func _build_grid() -> void:
	var grid_mesh := ImmediateMesh.new()
	grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var grid_color := Color(0.22, 0.34, 0.38, 0.52)
	for x_index in range(int(FLOOR_EXTENTS.x * 2.0) + 1):
		var x := -FLOOR_EXTENTS.x + float(x_index)
		grid_mesh.surface_set_color(grid_color)
		grid_mesh.surface_add_vertex(Vector3(x, 0.015, -FLOOR_EXTENTS.y))
		grid_mesh.surface_add_vertex(Vector3(x, 0.015, FLOOR_EXTENTS.y))
	for z_index in range(int(FLOOR_EXTENTS.y * 2.0) + 1):
		var z := -FLOOR_EXTENTS.y + float(z_index)
		grid_mesh.surface_set_color(grid_color)
		grid_mesh.surface_add_vertex(Vector3(-FLOOR_EXTENTS.x, 0.015, z))
		grid_mesh.surface_add_vertex(Vector3(FLOOR_EXTENTS.x, 0.015, z))
	grid_mesh.surface_end()

	var grid := MeshInstance3D.new()
	grid.name = "DigitalTwinGrid"
	grid.mesh = grid_mesh
	var grid_material := StandardMaterial3D.new()
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.vertex_color_use_as_albedo = true
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid.material_override = grid_material
	add_child(grid)


func _build_digital_assets() -> void:
	_add_asset("control_cabinet", "Control Cabinet", Vector3(-8.5, 0.68, 4.8), Vector3(1.25, 1.35, 2.65), Color(0.88, 0.57, 0.24), 1.65, 0.92)
	_add_asset("cooling_stack", "Cooling Stack", Vector3(7.9, 0.82, 4.2), Vector3(2.6, 1.64, 1.2), Color(0.44, 0.70, 0.92), 1.8, 0.88)
	_add_asset("asset_rack", "Asset Rack", Vector3(-4.2, 0.92, -5.9), Vector3(3.1, 1.84, 1.15), Color(0.58, 0.73, 0.48), 1.95, 0.86)
	_add_asset("render_node", "Render Node", Vector3(4.8, 0.95, -6.2), Vector3(1.45, 1.9, 1.45), Color(0.88, 0.30, 0.38), 1.55, 0.94)
	_add_asset("sensor_tower", "Sensor Tower", Vector3(0.0, 1.12, 6.9), Vector3(1.0, 2.25, 1.0), Color(0.62, 0.50, 0.96), 1.4, 0.90)
	_add_asset("lighting_probe", "Lighting Probe", Vector3(11.0, 0.55, -1.4), Vector3(1.15, 1.1, 1.15), Color(0.98, 0.80, 0.36), 1.25, 0.84)
	if dense_preset:
		_add_asset("dense_left_gate", "Dense Left Gate", Vector3(-1.9, 0.72, 1.2), Vector3(1.2, 1.45, 4.6), Color(0.30, 0.62, 0.88), 1.35, 0.86)
		_add_asset("dense_right_gate", "Dense Right Gate", Vector3(1.9, 0.72, 1.2), Vector3(1.2, 1.45, 4.6), Color(0.30, 0.62, 0.88), 1.35, 0.86)
		_add_asset("dense_offset_rack", "Dense Offset Rack", Vector3(-6.7, 0.82, 0.9), Vector3(1.6, 1.64, 3.8), Color(0.70, 0.55, 0.88), 1.45, 0.84)
		_add_asset("dense_budget_wall", "Dense Budget Wall", Vector3(6.5, 0.78, -1.6), Vector3(1.4, 1.56, 3.6), Color(0.92, 0.48, 0.34), 1.38, 0.83)


func _add_asset(id: String, label: String, position: Vector3, size: Vector3, color: Color, radius: float, review_score: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size

	var asset := MeshInstance3D.new()
	asset.name = label.replace(" ", "")
	asset.mesh = mesh
	asset.position = position
	asset.material_override = _material(color, 0.58, 0.26, color * 0.16)
	add_child(asset)

	var accent_mesh := CylinderMesh.new()
	accent_mesh.top_radius = 0.08
	accent_mesh.bottom_radius = 0.08
	accent_mesh.height = size.y + 0.22
	accent_mesh.radial_segments = 12
	var accent := MeshInstance3D.new()
	accent.name = "%sAccent" % asset.name
	accent.mesh = accent_mesh
	accent.position = position + Vector3(size.x * 0.42, 0.04, -size.z * 0.42)
	accent.material_override = _emissive_material(Color(0.22, 0.93, 1.0), 0.55)
	add_child(accent)

	obstacles.append({
		"id": id,
		"label": label,
		"position": position,
		"radius": radius,
		"review_score": review_score,
	})


func _build_sensor_beacons() -> void:
	_add_beacon("thermal_spike", "Thermal Spike", Vector3(-12.2, BEACON_HEIGHT, -2.8), Color(1.0, 0.34, 0.20), 0.96)
	_add_beacon("texture_artifact", "Texture Artifact", Vector3(-6.2, BEACON_HEIGHT, 8.5), Color(0.96, 0.82, 0.28), 0.78)
	_add_beacon("render_budget_alert", "Render Budget Alert", Vector3(12.8, BEACON_HEIGHT, 6.6), Color(0.25, 0.92, 1.0), 0.88)
	_add_beacon("asset_review", "Asset Review Target", Vector3(9.3, BEACON_HEIGHT, -7.8), Color(0.62, 0.96, 0.45), 0.82)
	_add_beacon("fov_lock", "FOV Lock Target", Vector3(-11.6, BEACON_HEIGHT, 6.5), Color(0.78, 0.45, 1.0), 0.90)


func _add_beacon(id: String, label: String, position: Vector3, color: Color, priority: float) -> void:
	var beacon_mesh := SphereMesh.new()
	beacon_mesh.radius = 0.28
	beacon_mesh.height = 0.56
	var beacon_node := MeshInstance3D.new()
	beacon_node.name = label.replace(" ", "")
	beacon_node.mesh = beacon_mesh
	beacon_node.position = position
	beacon_node.material_override = _emissive_material(color, 1.15)
	add_child(beacon_node)

	beacons.append({
		"id": id,
		"name": label,
		"position": position,
		"priority": priority,
		"cooldown": 0.0,
	})


func _mark_beacon_triggered(beacon_id: String) -> void:
	for index in range(beacons.size()):
		if beacons[index]["id"] == beacon_id:
			beacons[index]["cooldown"] = 5.5
			return


func _calculate_asset_quality_score() -> float:
	var total := 0.0
	for obstacle in obstacles:
		total += obstacle["review_score"]
	return total / maxf(float(obstacles.size()), 1.0)


func _load_and_validate_rubric() -> bool:
	rubric_path = _resolve_data_path(_get_cli_value("--rubric", DEFAULT_RUBRIC_PATH))
	var schema := _read_json_dictionary(RUBRIC_SCHEMA_PATH)
	rubric_data = _read_json_dictionary(rubric_path)
	var errors := validate_rubric_data(rubric_data, schema)
	if not errors.is_empty():
		push_error("Asset rubric validation failed for %s:\n- %s" % [rubric_path, "\n- ".join(errors)])
		return false
	print("[RUBRIC] Loaded %s from %s" % [rubric_data.get("name", "Unnamed rubric"), rubric_path])
	return true


func validate_rubric_data(data: Dictionary, schema: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if schema.is_empty():
		errors.append("schema file is missing or invalid")
	if data.is_empty():
		errors.append("rubric file is missing, empty, or invalid JSON")
	if errors.is_empty():
		_validate_json_schema(data, schema, "$", errors)
		_validate_rubric_weight_total(data, errors)
	return errors


func _validate_json_schema(value, schema: Dictionary, path: String, errors: Array[String]) -> void:
	var expected_type := str(schema.get("type", ""))
	if not _json_type_matches(value, expected_type):
		errors.append("%s expected %s, got %s" % [path, expected_type, _json_type_name(value)])
		return

	if expected_type == "object":
		for key in schema.get("required", []):
			if not value.has(key):
				errors.append("%s missing required key '%s'" % [path, key])
		var properties: Dictionary = schema.get("properties", {})
		for key in properties.keys():
			if value.has(key):
				_validate_json_schema(value[key], properties[key], "%s.%s" % [path, key], errors)
		if bool(schema.get("additionalProperties", true)) == false:
			for key in value.keys():
				if not properties.has(key):
					errors.append("%s contains unexpected key '%s'" % [path, key])

	if expected_type == "array":
		if schema.has("minItems") and value.size() < int(schema["minItems"]):
			errors.append("%s expected at least %d item(s)" % [path, int(schema["minItems"])])
		var item_schema: Dictionary = schema.get("items", {})
		for index in range(value.size()):
			_validate_json_schema(value[index], item_schema, "%s[%d]" % [path, index], errors)

	if expected_type == "number":
		if schema.has("minimum") and float(value) < float(schema["minimum"]):
			errors.append("%s is below minimum %.3f" % [path, float(schema["minimum"])])
		if schema.has("maximum") and float(value) > float(schema["maximum"]):
			errors.append("%s is above maximum %.3f" % [path, float(schema["maximum"])])

	if expected_type == "string":
		if schema.has("minLength") and str(value).length() < int(schema["minLength"]):
			errors.append("%s is shorter than %d characters" % [path, int(schema["minLength"])])
		if schema.has("pattern"):
			var regex := RegEx.new()
			regex.compile(str(schema["pattern"]))
			if regex.search(str(value)) == null:
				errors.append("%s does not match pattern %s" % [path, schema["pattern"]])


func _validate_rubric_weight_total(data: Dictionary, errors: Array[String]) -> void:
	var total := 0.0
	for criterion in data.get("criteria", []):
		total += float(criterion.get("weight", 0.0))
	if absf(total - 1.0) > 0.001:
		errors.append("criteria weights must sum to 1.0; got %.4f" % total)


func _json_type_matches(value, expected_type: String) -> bool:
	match expected_type:
		"object":
			return typeof(value) == TYPE_DICTIONARY
		"array":
			return typeof(value) == TYPE_ARRAY
		"string":
			return typeof(value) == TYPE_STRING
		"number":
			return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT
		_:
			return false


func _json_type_name(value) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			return "object"
		TYPE_ARRAY:
			return "array"
		TYPE_STRING:
			return "string"
		TYPE_FLOAT, TYPE_INT:
			return "number"
		_:
			return str(typeof(value))


func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _material(color: Color, roughness: float, metallic: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 0.42
	return material


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.35
	return material
