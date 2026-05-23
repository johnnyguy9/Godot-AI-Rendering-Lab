extends BTNode
class_name BTSequence

var children: Array[BTNode] = []


func _init(p_children: Array[BTNode] = []) -> void:
	children = p_children


func tick(context, delta: float) -> int:
	for child in children:
		var status := child.tick(context, delta)
		if status != Status.SUCCESS:
			return status
	return Status.SUCCESS
