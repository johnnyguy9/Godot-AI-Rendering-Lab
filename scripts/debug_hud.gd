extends CanvasLayer
class_name DebugHud

var director
var metrics_label: Label
var latest_vector_label: Label
var asset_label: Label
var event_log: RichTextLabel
var event_lines: Array[String] = []


func _ready() -> void:
	_build_hud()


func bind(p_director) -> void:
	director = p_director
	if not is_node_ready():
		await ready
	director.event_logged.connect(_on_event_logged)
	director.metrics_changed.connect(_on_metrics_changed)
	_on_metrics_changed(director.get_metrics_snapshot())


func _build_hud() -> void:
	var root := Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var panel := PanelContainer.new()
	panel.name = "TelemetryPanel"
	panel.offset_left = 18.0
	panel.offset_top = 18.0
	panel.custom_minimum_size = Vector2(500.0, 310.0)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var title := Label.new()
	title.text = "AI Rendering Lab // Live Evaluation"
	title.add_theme_font_size_override("font_size", 18)
	stack.add_child(title)

	metrics_label = Label.new()
	metrics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(metrics_label)

	latest_vector_label = Label.new()
	latest_vector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(latest_vector_label)

	asset_label = Label.new()
	asset_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(asset_label)

	event_log = RichTextLabel.new()
	event_log.custom_minimum_size = Vector2(460.0, 118.0)
	event_log.scroll_active = false
	event_log.bbcode_enabled = true
	stack.add_child(event_log)

	var footer := Label.new()
	footer.text = "F3 HUD  |  C Camera  |  R Reset  |  B Controller"
	footer.add_theme_color_override("font_color", Color(0.70, 0.80, 0.84))
	stack.add_child(footer)


func _on_metrics_changed(snapshot: Dictionary) -> void:
	if metrics_label == null:
		return

	metrics_label.text = "Controller %s | Runtime %.1fs | Agents %d | Transitions %d | FOV Locks %d | Vector Samples %d" % [
		snapshot.get("controller", "FSM"),
		snapshot["runtime"],
		snapshot["agents"],
		snapshot["transitions"],
		snapshot["perception_locks"],
		snapshot["vector_samples"],
	]

	var counts: Dictionary = snapshot.get("state_counts", {})
	latest_vector_label.text = "States P/S/I %d/%d/%d | Avg target distance %.2fm | Latest steering: %s" % [
		int(counts.get("Patrol", 0)),
		int(counts.get("Seek", 0)),
		int(counts.get("Idle", 0)),
		float(snapshot.get("average_target_distance", 0.0)),
		snapshot["latest_vector"],
	]

	var review: Dictionary = snapshot["asset_review"]
	var rubric: Dictionary = review.get("rubric", {})
	var rubric_name := str(rubric.get("name", "Asset Quality Rubric"))
	var score: float = float(review.get("quality_score", 0.0)) * 100.0
	asset_label.text = "%s | assets %d | beacons %d | quality %.1f%%" % [
		rubric_name,
		review.get("asset_count", 0),
		review.get("beacon_count", 0),
		score,
	]


func _on_event_logged(line: String) -> void:
	event_lines.push_front(line)
	while event_lines.size() > 5:
		event_lines.pop_back()
	event_log.text = "[b]Review Log[/b]\n%s" % "\n".join(event_lines)
