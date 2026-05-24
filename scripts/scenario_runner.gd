extends SceneTree

# Deterministic headless scenario runner.
#
# Boots the simulation, runs it for a fixed number of physics frames at the
# project's physics tick rate, and writes a JSON snapshot of the resulting
# metrics. Designed for CI regression tests: the snapshot should not change
# unless behavior actually changes.
#
# Usage:
#   godot --headless --path . -s scripts/scenario_runner.gd -- \
#       --frames=600 --output=user://scenario_snapshot.json
#
# `user://` resolves to the OS user data directory; in CI we redirect via
# OS.set_environment("HOME", "$PWD") and read the resulting path back.

const Main := preload("res://scripts/main.gd")

var _frames_target := 600
var _output_path := "user://scenario_snapshot.json"
var _main: Node3D


func _initialize() -> void:
	_parse_args()
	_main = Main.new()
	_main.name = "Main"
	get_root().add_child(_main)


func _physics_process(delta: float) -> void:
	_frames_target -= 1
	if _frames_target <= 0:
		_write_snapshot_and_quit()


func _write_snapshot_and_quit() -> void:
	var director = null
	if _main and _main.has_method("get_director"):
		director = _main.get_director()
	if director == null and _main:
		director = _main.get_node_or_null("SimulationDirector")
	if director == null:
		push_error("Scenario runner: SimulationDirector not found")
		quit(2)
		return

	var snapshot: Dictionary = director.get_metrics_snapshot()

	# Strip the rubric body — it's static and bloats the diff.
	if snapshot.has("asset_review") and typeof(snapshot["asset_review"]) == TYPE_DICTIONARY:
		var review: Dictionary = snapshot["asset_review"].duplicate()
		review.erase("rubric")
		snapshot["asset_review"] = review

	var file := FileAccess.open(_output_path, FileAccess.WRITE)
	if file == null:
		push_error("Scenario runner: could not open output path: %s" % _output_path)
		quit(3)
		return
	file.store_string(JSON.stringify(snapshot, "  "))
	file.close()

	print("[SCENARIO] wrote %s after %d frames" % [_output_path, snapshot["transitions"]])
	quit(0)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			_frames_target = int(arg.substr("--frames=".length()))
		elif arg.begins_with("--output="):
			_output_path = arg.substr("--output=".length())
