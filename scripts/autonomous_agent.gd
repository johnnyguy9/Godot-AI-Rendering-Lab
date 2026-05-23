extends Node3D
class_name AutonomousAgent

signal transitioned(agent_id: String, from_state: String, to_state: String, reason: String)
signal vector_evaluated(agent_id: String, payload: Dictionary)
signal perception_locked(agent_id: String, beacon_name: String)

const AgentBT := preload("res://scripts/behavior_tree/agent_bt.gd")

enum AgentState { PATROL, SEEK, IDLE }
enum ControllerMode { FSM, BEHAVIOR_TREE }

const STATE_NAMES := ["Patrol", "Seek", "Idle"]
const CONTROLLER_NAMES := ["FSM", "BT"]

var environment
var peers: Array = []
var agent_id := "Agent"
var palette := Color(0.2, 0.9, 1.0)
var rng := RandomNumberGenerator.new()

var current_state := AgentState.IDLE
var state_time := 0.0
var idle_duration := 1.0
var scan_elapsed := 0.0
var vector_log_elapsed := 0.0
var current_target := Vector3.ZERO
var active_beacon: Dictionary = {}
var controller_mode := ControllerMode.FSM
var behavior_tree := AgentBT.new()

var patrol_speed := 3.0
var seek_speed := 4.8
var arrival_radius := 0.34
var fov_degrees := 78.0
var scan_radius := 11.5
var scan_interval := 0.55
var seek_timeout := 5.5
var obstacle_clearance := 0.84

var body_node: MeshInstance3D
var fov_node: MeshInstance3D
var state_ring: MeshInstance3D


func configure(p_environment, p_agent_id: String, p_palette: Color, seed_value: int) -> void:
	environment = p_environment
	agent_id = p_agent_id
	palette = p_palette
	rng.seed = seed_value
	_build_visuals()
	global_position = environment.sample_navigable_point(rng, obstacle_clearance)
	current_target = environment.sample_navigable_point(rng, obstacle_clearance)
	idle_duration = _next_idle_duration()
	set_physics_process(true)
	_transition_to(AgentState.PATROL, "initial route seeded")


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if environment == null:
		return

	state_time += delta
	scan_elapsed += delta
	vector_log_elapsed += delta

	if controller_mode == ControllerMode.BEHAVIOR_TREE:
		behavior_tree.tick(self, delta)
	else:
		_tick_fsm(delta)

	_update_state_ring()


func _tick_fsm(delta: float) -> void:
	match current_state:
		AgentState.PATROL:
			_update_patrol(delta)
		AgentState.SEEK:
			_update_seek(delta)
		AgentState.IDLE:
			_update_idle()


func set_controller_mode(mode: int) -> void:
	controller_mode = mode


func get_controller_name() -> String:
	return CONTROLLER_NAMES[controller_mode]


func _update_patrol(delta: float) -> void:
	var vector := _steer_toward(current_target, patrol_speed, delta)
	_emit_vector("patrol", vector)

	if vector["boundary_corrected"]:
		current_target = environment.sample_navigable_point(rng, obstacle_clearance)
		_transition_to(AgentState.IDLE, "boundary correction requested replanning")
		return

	if _arrived_at(current_target):
		_transition_to(AgentState.IDLE, "patrol waypoint reached")
		return

	if scan_elapsed >= scan_interval:
		scan_elapsed = 0.0
		var beacon: Dictionary = environment.query_beacon_in_fov(global_position, _forward_vector(), fov_degrees, scan_radius, rng)
		if not beacon.is_empty():
			active_beacon = beacon
			current_target = beacon["position"]
			perception_locked.emit(agent_id, beacon["name"])
			_transition_to(AgentState.SEEK, "FOV perception lock: %s" % beacon["name"])


func _update_seek(delta: float) -> void:
	var vector := _steer_toward(current_target, seek_speed, delta)
	_emit_vector("seek", vector)

	if vector["boundary_corrected"]:
		active_beacon = {}
		_transition_to(AgentState.IDLE, "seek path corrected at boundary")
		return

	if _arrived_at(current_target):
		var beacon_name := "unknown target"
		if not active_beacon.is_empty():
			beacon_name = active_beacon["name"]
		active_beacon = {}
		_transition_to(AgentState.IDLE, "completed inspection: %s" % beacon_name)
		return

	if state_time >= seek_timeout:
		active_beacon = {}
		_transition_to(AgentState.IDLE, "seek timeout; returning to patrol cadence")


func _update_idle() -> void:
	if state_time >= idle_duration:
		current_target = environment.sample_navigable_point(rng, obstacle_clearance)
		_transition_to(AgentState.PATROL, "idle dwell complete")


func _steer_toward(target: Vector3, speed: float, delta: float) -> Dictionary:
	var origin := global_position
	var target_delta := target - origin
	target_delta.y = 0.0
	var distance := target_delta.length()
	var desired := Vector3.ZERO
	if distance > 0.001:
		desired = target_delta.normalized()

	var avoidance := _obstacle_avoidance()
	var separation := _peer_separation()
	var boundary_bias := _boundary_bias()
	var steering := compose_steering_vector(desired, avoidance, separation, boundary_bias)

	var step_length := minf(speed * delta, distance)
	var proposed := origin + steering * step_length
	var corrected: Vector3 = environment.clamp_to_bounds(proposed)
	var boundary_corrected: bool = corrected.distance_to(proposed) > 0.001
	global_position = corrected

	if steering.length() > 0.001:
		look_at(global_position + steering, Vector3.UP)

	return {
		"origin": origin,
		"target": target,
		"desired": desired,
		"avoidance": avoidance,
		"separation": separation,
		"boundary_bias": boundary_bias,
		"steering": steering,
		"distance": distance,
		"step_length": step_length,
		"proposed": proposed,
		"corrected": corrected,
		"boundary_corrected": boundary_corrected,
	}


func _obstacle_avoidance() -> Vector3:
	return calculate_obstacle_avoidance_at(global_position)


func calculate_obstacle_avoidance_at(sample_position: Vector3) -> Vector3:
	var influence := Vector3.ZERO
	var position_2d := Vector2(sample_position.x, sample_position.z)
	for obstacle in environment.get_obstacles():
		var obstacle_position: Vector3 = obstacle["position"]
		var obstacle_2d := Vector2(obstacle_position.x, obstacle_position.z)
		var distance := position_2d.distance_to(obstacle_2d)
		var radius: float = obstacle["radius"] + obstacle_clearance + 1.65
		if distance < radius and distance > 0.001:
			var away := Vector3(sample_position.x - obstacle_position.x, 0.0, sample_position.z - obstacle_position.z).normalized()
			var strength := 1.0 - clampf(distance / radius, 0.0, 1.0)
			influence += away * strength
	return influence


func _peer_separation() -> Vector3:
	var peer_positions: Array[Vector3] = []
	for peer in peers:
		if peer != self:
			peer_positions.append(peer.global_position)
	return calculate_peer_separation_at(global_position, peer_positions)


func calculate_peer_separation_at(sample_position: Vector3, peer_positions: Array[Vector3]) -> Vector3:
	var influence := Vector3.ZERO
	for peer_position in peer_positions:
		var delta: Vector3 = sample_position - peer_position
		delta.y = 0.0
		var distance: float = delta.length()
		if distance < 2.05 and distance > 0.001:
			influence += delta.normalized() * (1.0 - distance / 2.05)
	return influence


func _boundary_bias() -> Vector3:
	return calculate_boundary_bias_at(global_position)


func calculate_boundary_bias_at(sample_position: Vector3) -> Vector3:
	var bias := Vector3.ZERO
	var buffer := 2.2
	if sample_position.x < environment.bounds_min.x + buffer:
		bias.x += 1.0
	if sample_position.x > environment.bounds_max.x - buffer:
		bias.x -= 1.0
	if sample_position.z < environment.bounds_min.y + buffer:
		bias.z += 1.0
	if sample_position.z > environment.bounds_max.y - buffer:
		bias.z -= 1.0
	return bias.normalized() if bias.length() > 0.001 else Vector3.ZERO


func compose_steering_vector(desired: Vector3, avoidance: Vector3, separation: Vector3, boundary_bias: Vector3) -> Vector3:
	var steering := desired + avoidance * 1.25 + separation * 0.86 + boundary_bias * 0.78
	if steering.length() <= 0.001:
		return desired.normalized() if desired.length() > 0.001 else Vector3.ZERO
	return steering.normalized()


func _arrived_at(target: Vector3) -> bool:
	var flat_delta := target - global_position
	flat_delta.y = 0.0
	return flat_delta.length() <= arrival_radius


func get_state_name() -> String:
	return STATE_NAMES[current_state]


func distance_to_target() -> float:
	var flat_delta := current_target - global_position
	flat_delta.y = 0.0
	return flat_delta.length()


func _transition_to(next_state: int, reason: String) -> void:
	var previous_state := current_state
	current_state = next_state
	state_time = 0.0
	if next_state == AgentState.IDLE:
		idle_duration = _next_idle_duration()
	_update_agent_material()
	print("[FSM] %s | %s -> %s | %s" % [agent_id, STATE_NAMES[previous_state], STATE_NAMES[next_state], reason])
	transitioned.emit(agent_id, STATE_NAMES[previous_state], STATE_NAMES[next_state], reason)


func _next_idle_duration() -> float:
	return rng.randf_range(0.75, 1.85)


func _forward_vector() -> Vector3:
	return -global_transform.basis.z.normalized()


func _emit_vector(channel: String, vector: Dictionary) -> void:
	if vector_log_elapsed < 0.45:
		return
	vector_log_elapsed = 0.0
	print(
		"[VECTOR] %s/%s | dist=%.2f step=%.2f desired=%s steering=%s boundary=%s"
		% [
			agent_id,
			channel,
			vector["distance"],
			vector["step_length"],
			_vec_to_string(vector["desired"]),
			_vec_to_string(vector["steering"]),
			str(vector["boundary_corrected"]),
		]
	)
	vector_evaluated.emit(agent_id, vector)


func _vec_to_string(value: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]


func _build_visuals() -> void:
	if body_node != null:
		return

	body_node = MeshInstance3D.new()
	body_node.name = "AgentBody"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.62, 0.74, 0.95)
	body_node.mesh = body_mesh
	body_node.position = Vector3(0.0, 0.52, 0.0)
	add_child(body_node)

	var sensor_mesh := CylinderMesh.new()
	sensor_mesh.top_radius = 0.18
	sensor_mesh.bottom_radius = 0.28
	sensor_mesh.height = 0.22
	sensor_mesh.radial_segments = 18
	var sensor := MeshInstance3D.new()
	sensor.name = "SensorCrown"
	sensor.mesh = sensor_mesh
	sensor.position = Vector3(0.0, 1.02, -0.18)
	sensor.material_override = _agent_material(palette.lightened(0.2), 0.85)
	add_child(sensor)

	fov_node = MeshInstance3D.new()
	fov_node.name = "FieldOfViewVolume"
	fov_node.mesh = _build_fov_mesh()
	fov_node.material_override = _transparent_material(palette, 0.16)
	add_child(fov_node)

	state_ring = MeshInstance3D.new()
	state_ring.name = "StateRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.52
	ring_mesh.outer_radius = 0.56
	ring_mesh.rings = 36
	ring_mesh.ring_segments = 8
	state_ring.mesh = ring_mesh
	state_ring.position = Vector3(0.0, 0.04, 0.0)
	add_child(state_ring)

	_update_agent_material()


func _build_fov_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var half_angle := deg_to_rad(fov_degrees * 0.5)
	var segments := 18
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segments):
		var a0 := -half_angle + (float(index) / float(segments)) * half_angle * 2.0
		var a1 := -half_angle + (float(index + 1) / float(segments)) * half_angle * 2.0
		mesh.surface_add_vertex(Vector3(0.0, 0.035, -0.25))
		mesh.surface_add_vertex(Vector3(sin(a0) * scan_radius, 0.035, -cos(a0) * scan_radius))
		mesh.surface_add_vertex(Vector3(sin(a1) * scan_radius, 0.035, -cos(a1) * scan_radius))
	mesh.surface_end()
	return mesh


func _update_state_ring() -> void:
	if state_ring == null:
		return
	state_ring.rotate_y(0.032)


func _update_agent_material() -> void:
	if body_node == null:
		return
	var state_color := palette
	if current_state == AgentState.SEEK:
		state_color = Color(1.0, 0.37, 0.22)
	elif current_state == AgentState.IDLE:
		state_color = Color(0.82, 0.84, 0.88)
	body_node.material_override = _agent_material(state_color, 0.52)
	if state_ring:
		state_ring.material_override = _agent_material(state_color, 0.85)


func _agent_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.42
	material.metallic = 0.22
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	return material


func _transparent_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	return material
