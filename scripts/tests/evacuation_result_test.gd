class_name EvacuationResultTest
extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const RunSimulatorScript = preload("res://scripts/run/run_simulator.gd")

func run() -> bool:
	var loader := ContentLoaderScript.new()
	var simulator := RunSimulatorScript.new(loader)
	var run_bundle := simulator.create_run(20260427)
	var run_state = run_bundle["state"]
	var rngs = run_bundle["rngs"]

	if run_state.can_evac():
		push_error("Run should not allow evacuation at start.")
		return false

	var safety := 0
	while not run_state.completed and run_state.cleared_layer_count < 12 and safety < 80:
		safety += 1
		if not _advance_once(simulator, run_state, rngs):
			return false
		if not run_state.pending_reward_choices.is_empty():
			if run_state.can_evac():
				push_error("Run should not allow evacuation while reward choice is pending.")
				return false
			continue
		var expected := [4, 8, 12].has(run_state.cleared_layer_count)
		if run_state.can_evac() != expected:
			push_error("Evac window mismatch after layer " + str(run_state.cleared_layer_count))
			return false

	if safety >= 80 or not run_state.can_evac() or run_state.cleared_layer_count != 12:
		return false
	var evac := simulator.evacuate(run_state)
	return bool(evac.get("ok", false)) and run_state.completed and run_state.result.result_type == "evacuated"

func _advance_once(simulator: RunSimulatorScript, run_state, rngs) -> bool:
	if not run_state.pending_reward_choices.is_empty():
		var choose := simulator.choose_reward(run_state, 0)
		return bool(choose.get("ok", false))
	var node: Dictionary = run_state.current_node()
	var resolved := {}
	if ["battle", "elite", "boss"].has(String(node.get("node_type", ""))):
		resolved = simulator.complete_battle_node(run_state, rngs, true, String(node.get("battle_enemy_id", "boss_vanguard")), {"turns": 1, "log_size": 0})
	else:
		resolved = simulator.resolve_current_node(run_state, rngs)
	return bool(resolved.get("ok", false))
