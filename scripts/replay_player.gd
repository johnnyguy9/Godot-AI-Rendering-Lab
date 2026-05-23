extends Node3D
class_name ReplayPlayer

var source_path := ""
var playback_enabled := false
var playback_time := 0.0
var duration := 0.0
var records_by_agent: Dictionary = {}
var cursors: Dictionary = {}
var ghost_nodes: Dictionary = {}


func load_jsonl(path: String) -> bool:
	source_path = _resolve_path(path)
	if not FileAccess.file_exists(source_path):
		push_warning("ReplayPlayer could not find replay file: %s" % source_path)
		return false

	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		push_warning("ReplayPlayer failed to open %s" % source_path)
		return false

	records_by_agent.clear()
	cursors.clear()
	duration = 0.0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed = JSON.parse_string(line)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var agent_id := str(parsed.get("agent_id", "unknown"))
		if not records_by_agent.has(agent_id):
			records_by_agent[agent_id] = []
			cursors[agent_id] = 0
		records_by_agent[agent_id].append(parsed)
		duration = maxf(duration, float(parsed.get("time", 0.0)))

	_build_ghosts()
	visible = false
	print("[REPLAY] Loaded %d agent track(s) from %s" % [records_by_agent.size(), source_path])
	return true


func toggle_playback() -> void:
	if records_by_agent.is_empty():
		print("[REPLAY] No replay loaded. Pass --replay path/to/run.jsonl to enable ghost playback.")
		return
	playback_enabled = not playback_enabled
	visible = playback_enabled
	if playback_enabled:
		playback_time = 0.0
		for key in cursors.keys():
			cursors[key] = 0
	print("[REPLAY] Ghost playback %s" % ("enabled" if playback_enabled else "disabled"))


func _process(delta: float) -> void:
	if not playback_enabled or records_by_agent.is_empty():
		return

	playback_time += delta
	if duration > 0.0 and playback_time > duration:
		playback_time = 0.0
		for key in cursors.keys():
			cursors[key] = 0

	for agent_id in records_by_agent.keys():
		_apply_agent_record(agent_id)


func _build_ghosts() -> void:
	for node in ghost_nodes.values():
		node.queue_free()
	ghost_nodes.clear()

	for agent_id in records_by_agent.keys():
		var ghost := MeshInstance3D.new()
		ghost.name = "ReplayGhost_%s" % str(agent_id).replace(" ", "_")
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.72, 0.22, 0.72)
		ghost.mesh = mesh
		ghost.material_override = _ghost_material()
		add_child(ghost)
		ghost_nodes[agent_id] = ghost


func _apply_agent_record(agent_id: String) -> void:
	var records: Array = records_by_agent[agent_id]
	if records.is_empty():
		return

	var cursor := int(cursors.get(agent_id, 0))
	while cursor < records.size() - 1 and float(records[cursor + 1].get("time", 0.0)) <= playback_time:
		cursor += 1
	cursors[agent_id] = cursor

	var record: Dictionary = records[cursor]
	var ghost: MeshInstance3D = ghost_nodes[agent_id]
	ghost.global_position = _array_to_vector(record.get("pos", [])) + Vector3(0.0, 0.12, 0.0)


func _array_to_vector(value) -> Vector3:
	if typeof(value) != TYPE_ARRAY or value.size() < 3:
		return Vector3.ZERO
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _ghost_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.95, 1.0, 0.38)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.25, 0.95, 1.0)
	material.emission_energy_multiplier = 0.45
	return material


func _resolve_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return ProjectSettings.globalize_path(path) if path.is_relative_path() else path
