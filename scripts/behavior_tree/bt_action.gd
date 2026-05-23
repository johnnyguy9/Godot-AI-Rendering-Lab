extends BTNode
class_name BTAction

var action: Callable


func _init(p_action: Callable = Callable()) -> void:
	action = p_action


func tick(context, delta: float) -> int:
	if not action.is_valid():
		return Status.FAILURE

	var result = action.call(context, delta)
	if typeof(result) == TYPE_INT:
		return int(result)
	return Status.SUCCESS
