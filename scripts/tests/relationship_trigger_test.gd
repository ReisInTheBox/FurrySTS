extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const HubStateScript = preload("res://scripts/hub/hub_state.gd")

func run() -> bool:
	var hub := HubStateScript.new()
	hub.ensure_content(ContentLoaderScript.new())
	if not hub.relationship_state.completed_nodes.is_empty():
		push_error("Relationship state should start empty.")
		return false
	hub.apply_run_result({"result_type": "evacuated", "hero_id": "cyan_ryder", "nodes_cleared": 2, "credits": 4, "growth_count": 0, "summary": "test"})
	if not hub.relationship_state.has_completed("rel_aurian_intro"):
		push_error("Aurian intro relationship node did not trigger after first run.")
		return false
	if hub.relationship_events.is_empty():
		push_error("Relationship trigger did not expose a story event.")
		return false
	hub.apply_run_result({"result_type": "completed", "hero_id": "cyan_ryder", "nodes_cleared": 5, "credits": 8, "growth_count": 0, "summary": "test"})
	if not hub.relationship_state.has_completed("rel_aurian_trust"):
		push_error("Aurian trust relationship node did not trigger after completed run.")
		return false
	return true
