class_name RunNodeChoicesTest
extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const RunSimulatorScript = preload("res://scripts/run/run_simulator.gd")

func run() -> bool:
	var loader := ContentLoaderScript.new()
	var simulator := RunSimulatorScript.new(loader)
	if not _event_choice_flow(simulator):
		return false
	if not _shop_price_flow(simulator):
		return false
	return _rest_choice_flow(simulator)

func _event_choice_flow(simulator: RunSimulatorScript) -> bool:
	var bundle := simulator.create_run(91001)
	var run_state = bundle["state"]
	_force_single_node(run_state, {"id": "test_event", "node_type": "event", "event_id": "ev_signal", "text": "test event"})
	var resolved := simulator.resolve_current_node(run_state, bundle["rngs"])
	if not bool(resolved.get("ok", false)) or run_state.pending_reward_choices.size() < 2:
		push_error("Event node should create multiple pending choices.")
		return false
	var chosen := simulator.choose_reward(run_state, 0)
	if not bool(chosen.get("ok", false)):
		push_error("Event node choice failed.")
		return false
	return run_state.completed and run_state.progress.get_currency("credits") >= 18

func _shop_price_flow(simulator: RunSimulatorScript) -> bool:
	var bundle := simulator.create_run(91002)
	var run_state = bundle["state"]
	_force_single_node(run_state, {"id": "test_shop", "node_type": "shop", "text": "test shop"})
	var resolved := simulator.resolve_current_node(run_state, bundle["rngs"])
	if not bool(resolved.get("ok", false)) or run_state.pending_reward_choices.size() < 2:
		push_error("Shop node should create priced choices plus leave option.")
		return false
	var priced_index := _first_priced_choice(run_state.pending_reward_choices)
	if priced_index < 0:
		push_error("Shop node did not create priced reward.")
		return false
	var failed := simulator.choose_reward(run_state, priced_index)
	if bool(failed.get("ok", false)) or String(failed.get("reason", "")) != "not_enough_credits":
		push_error("Shop purchase should fail without enough credits.")
		return false
	run_state.progress.add_currency("credits", 100)
	var bought := simulator.choose_reward(run_state, priced_index)
	return bool(bought.get("ok", false)) and run_state.completed

func _rest_choice_flow(simulator: RunSimulatorScript) -> bool:
	var bundle := simulator.create_run(91003)
	var run_state = bundle["state"]
	_force_single_node(run_state, {"id": "test_rest", "node_type": "rest", "text": "test rest"})
	var resolved := simulator.resolve_current_node(run_state, bundle["rngs"])
	if not bool(resolved.get("ok", false)) or run_state.pending_reward_choices.size() != 3:
		push_error("Rest node should create exactly three choices.")
		return false
	var chosen := simulator.choose_reward(run_state, 1)
	if not bool(chosen.get("ok", false)):
		push_error("Rest node choice failed.")
		return false
	return run_state.completed and run_state.progress.all_growths().size() > 0

func _force_single_node(run_state, node: Dictionary) -> void:
	run_state.route_layers = []
	run_state.route_nodes = [node]
	run_state.current_node_index = 0
	run_state.current_node_uid = ""
	run_state.current_available_uids.clear()
	run_state.selected_path.clear()
	run_state.pending_reward_choices.clear()
	run_state.node_results.clear()
	run_state.completed = false

func _first_priced_choice(choices: Array[Dictionary]) -> int:
	for i in range(choices.size()):
		if int(choices[i].get("price", 0)) > 0:
			return i
	return -1
