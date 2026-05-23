extends GutTest

const SimulationEnvironment := preload("res://scripts/simulation_environment.gd")
const RUBRIC_PATH := "res://data/asset_review_rubric.json"
const SCHEMA_PATH := "res://data/asset_review_rubric.schema.json"
const VARIANT_PATHS := [
	"res://data/rubric_variants/strict.json",
	"res://data/rubric_variants/lenient.json",
	"res://data/rubric_variants/render_budget_focused.json",
]


func test_asset_review_rubric_matches_json_schema() -> void:
	_assert_rubric_valid(RUBRIC_PATH)


func test_rubric_variants_match_json_schema() -> void:
	for path in VARIANT_PATHS:
		_assert_rubric_valid(path)


func test_runtime_loader_refuses_invalid_weight_totals() -> void:
	var environment: SimulationEnvironment = autofree(SimulationEnvironment.new())
	var schema := _read_json(SCHEMA_PATH)
	var invalid := _read_json(RUBRIC_PATH)
	invalid["criteria"][0]["weight"] = 0.99

	var errors := environment.validate_rubric_data(invalid, schema)

	assert_gt(errors.size(), 0)
	assert_true(str(errors).contains("sum to 1.0"))


func _assert_rubric_valid(path: String) -> void:
	assert_true(FileAccess.file_exists(path), "%s should exist." % path)
	var environment: SimulationEnvironment = autofree(SimulationEnvironment.new())
	var schema := _read_json(SCHEMA_PATH)
	var rubric := _read_json(path)

	var errors := environment.validate_rubric_data(rubric, schema)

	assert_eq(errors, [], "%s schema errors: %s" % [path, ", ".join(errors)])


func _read_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
