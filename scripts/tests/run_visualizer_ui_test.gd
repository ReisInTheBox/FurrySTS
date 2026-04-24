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

	var forced_route: Array[Dictionary] = []
	forced_route.append(visualizer._run_state.route_nodes[0])
	forced_route.append({"id": "ui_supply", "node_type": "supply", "pool": "mid", "weight": "1", "next_pool": "late", "allow_evac": "true", "battle_enemy_id": "", "event_id": "", "text": "UI smoke supply"})
	visualizer._run_state.route_nodes = forced_route
	visualizer._run_state.current_node_index = 1
	visualizer._on_resolve_pressed()
	if not visualizer._node_result_active():
		push_error("Run visualizer did not show event/supply result panel.")
		return false
	if not visualizer._resolve_btn.disabled:
		push_error("Run visualizer allowed node advance while result panel is open.")
		return false
	visualizer._on_node_result_continue_pressed()
	if visualizer._node_result_active():
		push_error("Run visualizer did not hide result panel after continue.")
		return false

	visualizer.free()
	return true
