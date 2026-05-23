extends BTNode
class_name BTCondition

var condition: Callable


func _init(p_condition: Callable = Callable()) -> void:
	condition = p_condition


func tick(context, _delta: float) -> int:
	if not condition.is_valid():
		return Status.FAILURE
	return Status.SUCCESS if bool(condition.call(context)) else Status.FAILURE
