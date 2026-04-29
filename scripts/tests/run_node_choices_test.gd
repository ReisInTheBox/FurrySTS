class_name RunNodeChoicesTest
extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const RunSimulatorScript = preload("res://scripts/run/run_simulator.gd")

func run() -> bool:
	var loader := ContentLoaderScript.new()
	var simulator := RunSimulatorScript.new(loader)
	if not _event_choice_flow(simulator):
		return false
	if not _event_tradeoff_flow(simulator):
		return false
	if not _event_variant_flow(simulator):
		return false
	if not _supply_content_flow(simulator):
		return false
	if not _reward_filter_flow(simulator):
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
	if String(resolved.get("decision_summary", "")).find("稳定资源") < 0:
		push_error("Event node should explain its decision tradeoff.")
		return false
	if not _choices_have_decision_hints(run_state.pending_reward_choices):
		push_error("Event choices should expose decision hints for UI readability.")
		return false
	var chosen := simulator.choose_reward(run_state, 0)
	if not bool(chosen.get("ok", false)):
		push_error("Event node choice failed.")
		return false
	return run_state.completed and run_state.progress.get_currency("credits") >= 18

func _event_tradeoff_flow(simulator: RunSimulatorScript) -> bool:
	var bundle := simulator.create_run(91004, "cyan_ryder")
	var run_state = bundle["state"]
	run_state.progress.add_currency("credits", 20)
	_force_single_node(run_state, {"id": "test_event_tradeoff", "node_type": "event", "event_id": "ev_forge", "text": "test event tradeoff"})
	var resolved := simulator.resolve_current_node(run_state, bundle["rngs"])
	if not bool(resolved.get("ok", false)):
		push_error("Event tradeoff node did not resolve.")
		return false
	var enchant_index := _choice_index_by_id(run_state.pending_reward_choices, "event_field_enchant")
	if enchant_index < 0:
		push_error("Event should expose a direct enchant tradeoff choice.")
		return false
	var chosen := simulator.choose_reward(run_state, enchant_index)
	if not bool(chosen.get("ok", false)):
		push_error("Event enchant tradeoff failed: " + String(chosen.get("reason", "unknown")))
		return false
	return run_state.completed and run_state.progress.all_enchant_bindings().size() == 1 and run_state.progress.get_currency("credits") == 8

func _event_variant_flow(simulator: RunSimulatorScript) -> bool:
	var expected := {
		"ev_signal": "event_signal_trace",
		"ev_cache": "event_cache_patch",
		"ev_forge": "event_forge_hull"
	}
	for event_id in expected.keys():
		var bundle := simulator.create_run(91006, "cyan_ryder")
		var run_state = bundle["state"]
		run_state.progress.add_currency("credits", 25)
		_force_single_node(run_state, {"id": "test_" + String(event_id), "node_type": "event", "event_id": String(event_id), "text": "test event variant"})
		var resolved := simulator.resolve_current_node(run_state, bundle["rngs"])
		if not bool(resolved.get("ok", false)):
			push_error("Event variant did not resolve: " + String(event_id))
			return false
		if _choice_index_by_id(run_state.pending_reward_choices, String(expected[event_id])) < 0:
			push_error("Event variant missing expected choice: " + String(expected[event_id]))
			return false
	return true

func _supply_content_flow(simulator: RunSimulatorScript) -> bool:
	var bundle := simulator.create_run(91007)
	var run_state = bundle["state"]
	_force_single_node(run_state, {"id": "test_supply", "node_type": "supply", "text": "test supply"})
	var resolved := simulator.resolve_current_node(run_state, bundle["rngs"])
	if not bool(resolved.get("ok", false)) or run_state.pending_reward_choices.size() < 4:
		push_error("Supply node should expose several free stabilization choices.")
		return false
	if String(resolved.get("decision_summary", "")).find("免费") < 0:
		push_error("Supply node should explain free stabilization.")
		return false
	return _choice_index_by_id(run_state.pending_reward_choices, "supply_ammo_sort") >= 0 and _choice_index_by_id(run_state.pending_reward_choices, "supply_credit_ration") >= 0

func _reward_filter_flow(simulator: RunSimulatorScript) -> bool:
	var bundle := simulator.create_run(91005, "helios_windchaser")
	var run_state = bundle["state"]
	_force_single_node(run_state, {"id": "test_event_filter", "node_type": "event", "event_id": "ev_signal", "text": "test event filter"})
	var resolved := simulator.resolve_current_node(run_state, bundle["rngs"])
	if not bool(resolved.get("ok", false)):
		push_error("Event filter node did not resolve.")
		return false
	for choice_any in run_state.pending_reward_choices:
		var choice: Dictionary = choice_any
		var change: Dictionary = choice.get("enchant_change", {})
		if String(change.get("die_id", "")).begins_with("cyan_"):
			push_error("Reward filter leaked Cyan enchant into Helios run.")
			return false
	return true

func _shop_price_flow(simulator: RunSimulatorScript) -> bool:
	var bundle := simulator.create_run(91002)
	var run_state = bundle["state"]
	_force_single_node(run_state, {"id": "test_shop", "node_type": "shop", "text": "test shop"})
	var resolved := simulator.resolve_current_node(run_state, bundle["rngs"])
	if not bool(resolved.get("ok", false)) or run_state.pending_reward_choices.size() < 2:
		push_error("Shop node should create priced choices plus leave option.")
		return false
	if String(resolved.get("decision_summary", "")).find("Credits") < 0:
		push_error("Shop node should explain its Credits decision.")
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
	if not bool(resolved.get("ok", false)) or run_state.pending_reward_choices.size() < 4:
		push_error("Rest node should create at least four choices.")
		return false
	if String(resolved.get("decision_summary", "")).find("选 1 项") < 0:
		push_error("Rest node should explain its single-choice decision.")
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

func _choice_index_by_id(choices: Array[Dictionary], reward_id: String) -> int:
	for i in range(choices.size()):
		if String(choices[i].get("reward_id", "")) == reward_id:
			return i
	return -1

func _choices_have_decision_hints(choices: Array[Dictionary]) -> bool:
	for choice_any in choices:
		var choice: Dictionary = choice_any
		if String(choice.get("decision_hint", "")).strip_edges() == "":
			return false
	return true
