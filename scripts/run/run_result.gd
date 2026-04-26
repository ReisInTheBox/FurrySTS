class_name RunResult
extends RefCounted

var result_type: String
var hero_id: String
var nodes_cleared: int
var credits: int
var growth_count: int
var summary: String
var node_results: Array[Dictionary]
var extracted_equipment_instances: Array[Dictionary]
var lost_equipment_instances: Array[Dictionary]

func _init(
	p_result_type: String = "ongoing",
	p_hero_id: String = "cyan_ryder",
	p_nodes_cleared: int = 0,
	p_credits: int = 0,
	p_growth_count: int = 0,
	p_summary: String = "",
	p_node_results: Array[Dictionary] = [],
	p_extracted_equipment_instances: Array[Dictionary] = [],
	p_lost_equipment_instances: Array[Dictionary] = []
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
	extracted_equipment_instances = []
	for item_any in p_extracted_equipment_instances:
		extracted_equipment_instances.append(item_any)
	lost_equipment_instances = []
	for item_any in p_lost_equipment_instances:
		lost_equipment_instances.append(item_any)

func to_dict() -> Dictionary:
	return {
		"result_type": result_type,
		"hero_id": hero_id,
		"nodes_cleared": nodes_cleared,
		"credits": credits,
		"growth_count": growth_count,
		"summary": summary,
		"node_results": node_results.duplicate(true),
		"extracted_equipment_instances": extracted_equipment_instances.duplicate(true),
		"lost_equipment_instances": lost_equipment_instances.duplicate(true)
	}
