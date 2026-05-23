extends GutTest

const RUBRIC_PATH := "res://data/asset_review_rubric.json"
const RUBRIC_SCHEMA := {
	"type": TYPE_DICTIONARY,
	"required": ["name", "purpose", "criteria"],
	"properties": {
		"name": {"type": TYPE_STRING},
		"purpose": {"type": TYPE_STRING},
		"criteria": {
			"type": TYPE_ARRAY,
			"min_items": 1,
			"items": {
				"type": TYPE_DICTIONARY,
				"required": ["id", "weight", "description"],
				"properties": {
					"id": {"type": TYPE_STRING},
					"weight": {"type": TYPE_FLOAT, "minimum": 0.0, "maximum": 1.0},
					"description": {"type": TYPE_STRING},
				},
			},
		},
	},
}


func test_asset_review_rubric_matches_written_schema() -> void:
	assert_true(FileAccess.file_exists(RUBRIC_PATH), "Rubric file must exist.")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(RUBRIC_PATH))

	var errors: Array[String] = []
	_validate_schema(parsed, RUBRIC_SCHEMA, "$", errors)

	assert_eq(errors, [], "Rubric schema errors: %s" % ", ".join(errors))


func test_rubric_weights_are_normalized() -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RUBRIC_PATH))
	var total := 0.0
	for criterion in parsed["criteria"]:
		total += float(criterion["weight"])

	assert_almost_eq(total, 1.0, 0.001, "Rubric weights should sum to 1.0.")


func _validate_schema(value, schema: Dictionary, path: String, errors: Array[String]) -> void:
	var expected_type: int = int(schema["type"])
	var actual_type := typeof(value)
	if expected_type == TYPE_FLOAT and actual_type == TYPE_INT:
		actual_type = TYPE_FLOAT
	if actual_type != expected_type:
		errors.append("%s expected type %s, got %s" % [path, str(expected_type), str(typeof(value))])
		return

	if schema.has("minimum") and float(value) < float(schema["minimum"]):
		errors.append("%s below minimum %.3f" % [path, float(schema["minimum"])])
	if schema.has("maximum") and float(value) > float(schema["maximum"]):
		errors.append("%s above maximum %.3f" % [path, float(schema["maximum"])])

	if expected_type == TYPE_DICTIONARY:
		for required_key in schema.get("required", []):
			if not value.has(required_key):
				errors.append("%s missing required key %s" % [path, required_key])
		var properties: Dictionary = schema.get("properties", {})
		for key in properties.keys():
			if value.has(key):
				_validate_schema(value[key], properties[key], "%s.%s" % [path, key], errors)

	if expected_type == TYPE_ARRAY:
		if schema.has("min_items") and value.size() < int(schema["min_items"]):
			errors.append("%s expected at least %d item(s)" % [path, int(schema["min_items"])])
		if schema.has("items"):
			for index in range(value.size()):
				_validate_schema(value[index], schema["items"], "%s[%d]" % [path, index], errors)
