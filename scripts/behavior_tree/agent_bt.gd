extends RefCounted
class_name AgentBT

const BTNodeScript := preload("res://scripts/behavior_tree/bt_node.gd")
const BTSequenceScript := preload("res://scripts/behavior_tree/bt_sequence.gd")
const BTSelectorScript := preload("res://scripts/behavior_tree/bt_selector.gd")
const BTActionScript := preload("res://scripts/behavior_tree/bt_action.gd")
const BTConditionScript := preload("res://scripts/behavior_tree/bt_condition.gd")

var root: BTSelector


func _init() -> void:
	root = BTSelectorScript.new([
		BTSequenceScript.new([
			BTConditionScript.new(Callable(self, "_is_patrol")),
			BTActionScript.new(Callable(self, "_tick_patrol")),
		]),
		BTSequenceScript.new([
			BTConditionScript.new(Callable(self, "_is_seek")),
			BTActionScript.new(Callable(self, "_tick_seek")),
		]),
		BTSequenceScript.new([
			BTConditionScript.new(Callable(self, "_is_idle")),
			BTActionScript.new(Callable(self, "_tick_idle")),
		]),
	])


func tick(agent, delta: float) -> int:
	return root.tick(agent, delta)


func _is_patrol(agent) -> bool:
	return agent.current_state == agent.AgentState.PATROL


func _is_seek(agent) -> bool:
	return agent.current_state == agent.AgentState.SEEK


func _is_idle(agent) -> bool:
	return agent.current_state == agent.AgentState.IDLE


func _tick_patrol(agent, delta: float) -> int:
	agent._update_patrol(delta)
	return BTNodeScript.Status.SUCCESS


func _tick_seek(agent, delta: float) -> int:
	agent._update_seek(delta)
	return BTNodeScript.Status.SUCCESS


func _tick_idle(agent, _delta: float) -> int:
	agent._update_idle()
	return BTNodeScript.Status.SUCCESS
