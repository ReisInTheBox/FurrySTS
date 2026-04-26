extends RefCounted

const HubVisualizerScript = preload("res://scripts/app/hub_visualizer.gd")
const RunVisualizerScript = preload("res://scripts/app/run_visualizer.gd")
const BattleVisualizerScript = preload("res://scripts/app/battle_visualizer.gd")
const HubStateScript = preload("res://scripts/hub/hub_state.gd")
const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const RunProgressStateScript = preload("res://scripts/run/run_progress_state.gd")

const TEST_SIZE := Vector2(1280, 720)

func run() -> bool:
	if not _check_hub_layout():
		return false
	if not _check_run_layout():
		return false
	if not _check_battle_layout():
		return false
	return true

func _check_hub_layout() -> bool:
	var hub_state := HubStateScript.new()
	hub_state.ensure_content(ContentLoaderScript.new())
	var view := HubVisualizerScript.new()
	view.size = TEST_SIZE
	view.configure_hub(hub_state)
	view._build_ui()
	view._render_ui()
	if view._start_run_btn == null or not view._start_run_btn.visible:
		push_error("Hub layout lost fixed start-run button.")
		return false
	if view._loadout_row == null or view._loadout_row.get_child_count() <= 0:
		push_error("Hub layout lost loadout controls.")
		return false
	view.free()
	return true

func _check_run_layout() -> bool:
	var view := RunVisualizerScript.new()
	view.size = TEST_SIZE
	view._build_ui()
	view._start_run()
	if view._resolve_btn == null or not view._resolve_btn.visible:
		push_error("Run layout lost resolve button.")
		return false
	if view._evac_btn == null or not view._evac_btn.visible:
		push_error("Run layout lost evac button.")
		return false
	if view._new_run_btn == null or not view._new_run_btn.visible:
		push_error("Run layout lost new run button.")
		return false
	view.free()
	return true

func _check_battle_layout() -> bool:
	var view := BattleVisualizerScript.new()
	view.size = TEST_SIZE
	view.configure_for_run(20260425, "cyan_ryder", "boss_vanguard", RunProgressStateScript.new(), "UI layout smoke", [])
	view._build_ui()
	view._start_manual_battle()
	if view._return_btn == null or not view._return_btn.visible:
		push_error("Battle layout lost return-to-run button.")
		return false
	if view._reroll_mode_btn == null or not view._reroll_mode_btn.visible:
		push_error("Battle layout lost reroll mode button.")
		return false
	if view._reroll_btn == null or not view._reroll_btn.visible:
		push_error("Battle layout lost reroll button.")
		return false
	if view._end_turn_btn == null or not view._end_turn_btn.visible:
		push_error("Battle layout lost end-turn button.")
		return false
	if view._card_scroll == null or not view._card_scroll.visible:
		push_error("Battle layout lost dice scroll area.")
		return false
	view.free()
	return true
