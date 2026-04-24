class_name RunResult
extends RefCounted

var result_type: String
var hero_id: String
var nodes_cleared: int
var credits: int
var growth_count: int
var summary: String
var node_results: Array[Dictionary]

func _init(
	p_result_type: String = "ongoing",
	p_hero_id: String = "cyan_ryder",
	p_nodes_cleared: int = 0,
	p_credits: int = 0,
	p_growth_count: int = 0,
	p_summary: String = "",
	p_node_results: Array[Dictionary] = []
) -> void:
	result_type = p_result_type
	hero_id = p_hero_id
	nodes_cleared = p_nodes_cleared
	credits = p_credits
	growth_count = p_growth_count
	summary = p_summary
	node_results = []
	for item_any in p_node_results:
		node_results.append(item_any)

func to_dict() -> Dictionary:
	return {
		"result_type": result_type,
		"hero_id": hero_id,
		"nodes_cleared": nodes_cleared,
		"credits": credits,
		"growth_count": growth_count,
		"summary": summary,
		"node_results": node_results.duplicate(true)
	}
