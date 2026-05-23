extends Node3D

const SimulationEnvironment := preload("res://scripts/simulation_environment.gd")
const SimulationDirector := preload("res://scripts/simulation_director.gd")
const DebugHud := preload("res://scripts/debug_hud.gd")

var environment
var director
var hud
var camera: Camera3D
var camera_mode := 0


func _ready() -> void:
	_configure_rendering()
	_build_simulation()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_hud") and hud:
		hud.visible = not hud.visible
	if event.is_action_pressed("reset_simulation"):
		_reset_simulation()
	if event.is_action_pressed("cycle_camera"):
		camera_mode = (camera_mode + 1) % 3
		_apply_camera_mode()
	if event.is_action_pressed("toggle_controller") and director:
		director.toggle_controller()


func _configure_rendering() -> void:
	var world_environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color(0.035, 0.043, 0.052)
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color(0.32, 0.38, 0.44)
	environment_resource.ambient_light_energy = 0.85
	environment_resource.glow_enabled = true
	environment_resource.glow_intensity = 0.22
	environment_resource.glow_strength = 0.68
	world_environment.environment = environment_resource
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.light_energy = 2.2
	key_light.rotation_degrees = Vector3(-58.0, -38.0, 0.0)
	key_light.shadow_enabled = true
	add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "SoftFillLight"
	fill_light.position = Vector3(-6.5, 8.0, 8.5)
	fill_light.light_energy = 1.25
	fill_light.omni_range = 24.0
	add_child(fill_light)

	camera = Camera3D.new()
	camera.name = "ReviewCamera"
	camera.fov = 58.0
	camera.current = true
	add_child(camera)
	_apply_camera_mode()


func _build_simulation() -> void:
	environment = SimulationEnvironment.new()
	environment.name = "DigitalTwinEnvironment"
	add_child(environment)

	director = SimulationDirector.new()
	director.name = "SimulationDirector"
	add_child(director)
	director.configure(environment)

	hud = DebugHud.new()
	hud.name = "EvaluationHUD"
	add_child(hud)
	hud.bind(director)


func _reset_simulation() -> void:
	if hud:
		hud.queue_free()
	if director:
		director.queue_free()
	if environment:
		environment.queue_free()
	await get_tree().process_frame
	_build_simulation()


func _apply_camera_mode() -> void:
	if camera == null:
		return

	match camera_mode:
		0:
			camera.position = Vector3(0.0, 21.0, 24.0)
			camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
		1:
			camera.position = Vector3(-17.5, 13.0, 11.0)
			camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
		_:
			camera.position = Vector3(16.0, 10.0, -13.5)
			camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
