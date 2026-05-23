extends RefCounted
class_name BTNode

enum Status { SUCCESS, FAILURE, RUNNING }


func tick(_context, _delta: float) -> int:
	return Status.FAILURE
