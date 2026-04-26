class_name RelationshipCatalog
extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")

var _loader: ContentLoaderScript
var _nodes: Array[Dictionary] = []
var _rewards_by_id: Dictionary = {}
var _story_by_node_id: Dictionary = {}

func _init(loader: ContentLoaderScript) -> void:
	_loader = loader
	_build_cache()

func _build_cache() -> void:
	_nodes.clear()
	_rewards_by_id.clear()
	_story_by_node_id.clear()
	for row_any in _loader.load_rows("relationship_nodes"):
		var row: Dictionary = row_any
		if String(row.get("id", "")) != "":
			_nodes.append(row)
	for reward_any in _loader.load_rows("relationship_rewards"):
		var reward: Dictionary = reward_any
		var reward_id := String(reward.get("id", ""))
		if reward_id != "":
			_rewards_by_id[reward_id] = reward
	for event_any in _loader.load_rows("story_events"):
		var event: Dictionary = event_any
		var node_id := String(event.get("relationship_node_id", ""))
		if node_id != "":
			_story_by_node_id[node_id] = event

func nodes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in _nodes:
		out.append(row)
	return out

func reward_by_id(reward_id: String) -> Dictionary:
	if not _rewards_by_id.has(reward_id):
		return {}
	return _rewards_by_id[reward_id]

func story_for_node(node_id: String) -> Dictionary:
	return _story_by_node_id.get(node_id, {})
