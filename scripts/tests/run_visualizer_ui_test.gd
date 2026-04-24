extends RefCounted

const RunVisualizerScript = preload("res://scripts/app/run_visualizer.gd")

func run() -> bool:
	var visualizer := RunVisualizerScript.new()
	visualizer._build_ui()
	visualizer._start_run()

	if visualizer._run_state == null:
		push_error("Run visualizer failed to initialize run state.")
		return false

	var node: Dictionary = visualizer._run_state.current_node()
	if String(node.get("node_type", "")) != "battle":
		push_error("Expected first run node to be a battle node for UI smoke.")
		return false

	visualizer._on_resolve_pressed()
	if visualizer._active_battle == null:
		push_error("Run visualizer failed to open embedded battle scene.")
		return false

	var battle = visualizer._active_battle
	battle._build_ui()
	battle._start_manual_battle()
	battle._state.enemy.hp = 0
	battle._render_ui()
	battle._on_return_pressed()

	if visualizer._active_battle != null:
		push_error("Run visualizer failed to return from battle scene.")
		return false
	if visualizer._run_state.completed:
		push_error("Run should not complete immediately after the first battle victory.")
		return false
	if visualizer._run_state.pending_reward_choices.is_empty():
		push_error("Battle victory did not produce pending reward choices in run flow.")
		return false

	visualizer._on_reward_selected(0)
	if not visualizer._run_state.pending_reward_choices.is_empty():
		push_error("Run reward selection did not clear pending choices.")
		return false
	if visualizer._run_state.current_node_index <= 0:
		push_error("Run did not advance after reward selection.")
		return false

	visualizer.free()
	return true
