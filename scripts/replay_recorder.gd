extends Node
class_name ReplayRecorder

var output_path := ""
var file: FileAccess
var records_written := 0


func configure(path: String) -> bool:
	output_path = _resolve_path(path)
	var directory := output_path.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)

	file = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("ReplayRecorder failed to open %s: %s" % [output_path, error_string(FileAccess.get_open_error())])
		return false

	print("[REPLAY] Recording JSONL telemetry to %s" % output_path)
	return true


func record_tick(time_seconds: float, agents: Array) -> void:
	if file == null:
		return

	for agent in agents:
		var payload: Dictionary = agent.get_replay_payload(time_seconds)
		file.store_line(JSON.stringify(payload))
		records_written += 1
	file.flush()


func close() -> void:
	if file != null:
		file.flush()
		file = null
		print("[REPLAY] Wrote %d agent records to %s" % [records_written, output_path])


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		close()


func _resolve_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return ProjectSettings.globalize_path(path) if path.is_relative_path() else path
