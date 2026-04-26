extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const HubStateScript = preload("res://scripts/hub/hub_state.gd")

func run() -> bool:
	var hub := HubStateScript.new()
	hub.ensure_content(ContentLoaderScript.new())
	hub.apply_run_result({"result_type": "completed", "hero_id": "helios_windchaser", "nodes_cleared": 5, "credits": 10, "growth_count": 0, "summary": "test"})
	hub.select_hero("umbral_draxx")
	var setup := hub.run_setup_for_selected_hero()
	var growths: Array = setup.get("persistent_growths", [])
	var found_relationship_growth := false
	for growth_any in growths:
		var growth: Dictionary = growth_any
		if String(growth.get("growth_id", "")).begins_with("relationship_umbral_draxx"):
			found_relationship_growth = true
			break
	if not found_relationship_growth:
		push_error("Relationship reward did not flow into next Aurian run setup.")
		return false
	return true
