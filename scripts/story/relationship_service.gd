class_name RelationshipService
extends RefCounted

const RelationshipCatalogScript = preload("res://scripts/story/relationship_catalog.gd")
const RelationshipStateScript = preload("res://scripts/story/relationship_state.gd")
const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")

var _catalog: RelationshipCatalogScript

func _init(loader: ContentLoaderScript) -> void:
	_catalog = RelationshipCatalogScript.new(loader)

func process_run_result(state: RelationshipStateScript, hub_stats: Dictionary, run_result: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for node_any in _catalog.nodes():
		var node: Dictionary = node_any
		var node_id := String(node.get("id", ""))
		if node_id == "" or state.has_completed(node_id):
			continue
		if not _condition_met(node, hub_stats, run_result):
			continue
		var reward_id := String(node.get("reward_id", ""))
		var reward := _catalog.reward_by_id(reward_id)
		if reward_id != "" and reward.is_empty():
			continue
		var completed := state.complete_node(node, reward)
		if bool(completed.get("ok", false)):
			var event: Dictionary = completed.get("event", {})
			var story := _catalog.story_for_node(node_id)
			if not story.is_empty():
				event["story_text"] = String(story.get("text", ""))
			if not reward.is_empty():
				event["reward_title"] = String(reward.get("title", reward_id))
				event["reward_description"] = String(reward.get("description", ""))
			events.append(event)
	return events

func reward_growths_for_hero(state: RelationshipStateScript, hero_id: String) -> Array[Dictionary]:
	var growths: Array[Dictionary] = []
	for node in state.completed_for_npc(hero_id):
		var reward_id := String(node.get("reward_id", ""))
		if reward_id == "":
			continue
		var reward := _catalog.reward_by_id(reward_id)
		if reward.is_empty():
			continue
		growths.append({
			"growth_id": "relationship_%s_%s" % [hero_id, reward_id],
			"type": String(reward.get("type", "stat")),
			"target": String(reward.get("target", "block")),
			"delta": String(reward.get("delta", "0")),
			"duration_scope": String(reward.get("duration_scope", "run")),
			"grant_once": String(reward.get("grant_once", "true"))
		})
	return growths

func summary_lines(state: RelationshipStateScript, hero_ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for hero_id in hero_ids:
		var count := state.completed_count_for_npc(hero_id)
		if count > 0:
			out.append("%s: relationship Lv.%d" % [hero_id, count])
	if out.is_empty():
		out.append("No relationship nodes unlocked yet.")
	return out

func _condition_met(node: Dictionary, hub_stats: Dictionary, run_result: Dictionary) -> bool:
	var trigger := String(node.get("trigger_type", ""))
	var required := int(node.get("required_value", "0"))
	match trigger:
		"run_count_at_least":
			return int(hub_stats.get("run_count", 0)) >= required
		"completed_runs_at_least":
			return int(hub_stats.get("completed_runs", 0)) >= required
		"nodes_cleared_at_least":
			return int(run_result.get("nodes_cleared", 0)) >= required
		_:
			return false
