extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const HubStateScript = preload("res://scripts/hub/hub_state.gd")

func run() -> bool:
	var hub := HubStateScript.new()
	hub.ensure_content(ContentLoaderScript.new())
	hub.apply_run_result({"result_type": "evacuated", "hero_id": "cyan_ryder", "nodes_cleared": 2, "credits": 0, "growth_count": 0, "summary": "test"})
	var first_growths := hub.relationship_growths_for_hero("umbral_draxx")
	if first_growths.size() != 1:
		push_error("Expected exactly one Aurian relationship growth after intro.")
		return false
	hub.apply_run_result({"result_type": "evacuated", "hero_id": "cyan_ryder", "nodes_cleared": 2, "credits": 0, "growth_count": 0, "summary": "test"})
	var second_growths := hub.relationship_growths_for_hero("umbral_draxx")
	if second_growths.size() != 1:
		push_error("Relationship reward was duplicated after repeated run result.")
		return false
	if Array(hub.relationship_growths_for_hero("cyan_ryder")).size() != 0:
		push_error("Aurian relationship reward leaked to another hero.")
		return false
	return true
