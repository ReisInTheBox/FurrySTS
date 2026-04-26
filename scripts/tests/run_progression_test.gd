class_name RunProgressionTest
extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const RunSimulatorScript = preload("res://scripts/run/run_simulator.gd")

func run() -> bool:
	var loader := ContentLoaderScript.new()
	var simulator := RunSimulatorScript.new(loader)
	var run_bundle := simulator.create_run(20260426)
	var run_state = run_bundle["state"]
	var rngs = run_bundle["rngs"]

	if run_state.route_nodes.is_empty():
		return false

	if run_state.route_layers.size() != 13:
		return false

	var safety := 0
	while not run_state.completed and safety < 80:
		safety += 1
		if not run_state.pending_reward_choices.is_empty():
			var choose := simulator.choose_reward(run_state, 0)
			if not bool(choose.get("ok", false)):
				return false
			continue
		var node: Dictionary = run_state.current_node()
		var resolved := {}
		if ["battle", "elite", "boss"].has(String(node.get("node_type", ""))):
			resolved = simulator.complete_battle_node(run_state, rngs, true, String(node.get("battle_enemy_id", "boss_vanguard")), {"turns": 1, "log_size": 0})
		else:
			resolved = simulator.resolve_current_node(run_state, rngs)
		if not bool(resolved.get("ok", false)):
			return false
	if safety >= 80:
		return false
	return run_state.completed and ["completed", "evacuated"].has(run_state.result.result_type)
