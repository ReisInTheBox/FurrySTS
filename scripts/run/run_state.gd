class_name RunState
extends RefCounted

const RunProgressStateScript = preload("res://scripts/run/run_progress_state.gd")
const RunResultScript = preload("res://scripts/run/run_result.gd")

var hero_id: String = "cyan_ryder"
var route_nodes: Array[Dictionary] = []
var current_node_index: int = 0
var pending_reward_choices: Array[Dictionary] = []
var node_results: Array[Dictionary] = []
var progress: RunProgressStateScript = RunProgressStateScript.new()
var completed: bool = false
var result: RunResultScript = RunResultScript.new()
var loadout_face_ids: Array[String] = []

func current_node() -> Dictionary:
	if route_nodes.is_empty():
		return {}
	if current_node_index < 0 or current_node_index >= route_nodes.size():
		return {}
	return route_nodes[current_node_index]

func nodes_cleared() -> int:
	return node_results.size()

func can_evac() -> bool:
	if completed:
		return false
	var node := current_node()
	if node.is_empty():
		return false
	return String(node.get("allow_evac", "false")) == "true" and current_node_index > 0

func advance_node() -> void:
	current_node_index += 1
	if current_node_index >= route_nodes.size():
		completed = true
		result = RunResultScript.new(
			"completed",
			hero_id,
			node_results.size(),
			progress.get_currency("credits"),
			progress.all_growths().size(),
			"已完成路线终点。",
			node_results
		)

func finish(result_type: String, summary: String) -> void:
	completed = true
	result = RunResultScript.new(
		result_type,
		hero_id,
		node_results.size(),
		progress.get_currency("credits"),
		progress.all_growths().size(),
		summary,
		node_results
	)
