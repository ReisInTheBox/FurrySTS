extends RefCounted

const RootFlowScript = preload("res://scripts/app/root_flow.gd")
const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const HubStateScript = preload("res://scripts/hub/hub_state.gd")

func run() -> bool:
	var root := RootFlowScript.new()
	root._hub_state.ensure_content(ContentLoaderScript.new())
	if not root._hub_state.upgrade_defs.has("guard_boost"):
		push_error("Hub state did not load outgame growth definitions from content.")
		return false
	root._show_hub()
	if root._active_view == null:
		push_error("Root flow failed to open hub view.")
		return false

	root._on_start_run_requested("helios_windchaser")
	if root._active_view == null or not root._active_view.has_signal("run_finished"):
		push_error("Root flow failed to switch into run view.")
		return false

	var result := {
		"result_type": "evacuated",
		"nodes_cleared": 3,
		"credits": 25,
		"growth_count": 2,
		"summary": "测试撤离"
	}
	root._on_run_finished(result)
	if root._hub_state.banked_credits != 25:
		push_error("Hub state did not receive banked credits from run result.")
		return false
	if root._hub_state.evacuated_runs != 1:
		push_error("Hub state did not record evacuated run count.")
		return false
	if root._active_view == null or not root._active_view.has_signal("start_run_requested"):
		push_error("Root flow failed to return to hub view after run result.")
		return false

	var buy := root._hub_state.purchase_upgrade("helios_windchaser", "guard_boost")
	if not bool(buy.get("ok", false)):
		push_error("Hub state failed to purchase an affordable upgrade.")
		return false
	if root._hub_state.banked_credits >= 25:
		push_error("Hub state did not spend credits after upgrade purchase.")
		return false

	root._hub_state.select_hero("helios_windchaser")
	var before_loadout := root._hub_state.selected_loadout()
	var remove_result := root._hub_state.toggle_face_in_selected_loadout(before_loadout[0])
	if not bool(remove_result.get("ok", false)):
		push_error("Hub state failed to remove a loadout face.")
		return false
	var reserve := root._hub_state.reserve_faces_for_hero("helios_windchaser")
	if reserve.is_empty():
		push_error("Hub state has no reserve face after removing from loadout.")
		return false
	var add_result := root._hub_state.toggle_face_in_selected_loadout(reserve[0])
	if not bool(add_result.get("ok", false)):
		push_error("Hub state failed to add a reserve face to loadout.")
		return false
	if root._hub_state.selected_loadout() == before_loadout:
		push_error("Hub loadout did not change after edit operations.")
		return false

	var setup := root._hub_state.run_setup_for_selected_hero()
	if Array(setup.get("loadout_face_ids", [])).size() != HubStateScript.DEFAULT_LOADOUT_SIZE:
		push_error("Hub run setup did not include expected loadout size.")
		return false
	if Array(setup.get("persistent_growths", [])).is_empty():
		push_error("Hub run setup did not include purchased persistent growth.")
		return false

	root.free()
	return true
