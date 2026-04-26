class_name RelationshipState
extends RefCounted

var completed_nodes: Dictionary = {}
var claimed_rewards: Dictionary = {}
var event_log: Array[Dictionary] = []

func has_completed(node_id: String) -> bool:
	return completed_nodes.has(node_id)

func has_claimed_reward(reward_id: String) -> bool:
	return claimed_rewards.has(reward_id)

func complete_node(node: Dictionary, reward: Dictionary) -> Dictionary:
	var node_id := String(node.get("id", ""))
	var reward_id := String(reward.get("id", node.get("reward_id", "")))
	if node_id == "" or has_completed(node_id):
		return {"ok": false, "reason": "already_completed"}
	completed_nodes[node_id] = {
		"node_id": node_id,
		"npc_id": String(node.get("npc_id", "")),
		"title": String(node.get("title", node_id)),
		"description": String(node.get("description", "")),
		"reward_id": reward_id
	}
	if reward_id != "":
		claimed_rewards[reward_id] = true
	var event: Dictionary = completed_nodes[node_id].duplicate(true)
	event["event_type"] = "relationship_node_completed"
	event_log.append(event)
	return {"ok": true, "event": event}

func completed_for_npc(npc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for node_any in completed_nodes.values():
		var node: Dictionary = node_any
		if String(node.get("npc_id", "")) == npc_id:
			out.append(node.duplicate(true))
	return out

func completed_count_for_npc(npc_id: String) -> int:
	return completed_for_npc(npc_id).size()
