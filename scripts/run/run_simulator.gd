class_name RunSimulator
extends RefCounted

const SeedBundleScript = preload("res://scripts/core/seed_bundle.gd")
const RngStreamsScript = preload("res://scripts/core/rng_streams.gd")
const ActionLoggerScript = preload("res://scripts/core/action_logger.gd")
const CombatStateScript = preload("res://scripts/combat/combat_state.gd")
const BattleSimulatorScript = preload("res://scripts/combat/battle_simulator.gd")
const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const UnitFactoryScript = preload("res://scripts/content/unit_factory.gd")
const CombatCatalogScript = preload("res://scripts/content/combat_catalog.gd")
const RunCatalogScript = preload("res://scripts/run/run_catalog.gd")
const RunStateScript = preload("res://scripts/run/run_state.gd")
const RewardDraftServiceScript = preload("res://scripts/run/reward_draft_service.gd")

var _loader: ContentLoaderScript
var _combat_catalog: CombatCatalogScript
var _run_catalog: RunCatalogScript
var _reward_service: RewardDraftServiceScript = RewardDraftServiceScript.new()

func _init(loader: ContentLoaderScript) -> void:
	_loader = loader
	_combat_catalog = CombatCatalogScript.new(loader)
	_run_catalog = RunCatalogScript.new(loader)

func create_run(master_seed: int, hero_id: String = "cyan_ryder", route_length: int = 13, setup: Dictionary = {}) -> Dictionary:
	var rngs := RngStreamsScript.new(SeedBundleScript.new(master_seed))
	var run_state := RunStateScript.new()
	run_state.hero_id = hero_id
	for face_id_any in setup.get("loadout_face_ids", []):
		run_state.loadout_face_ids.append(String(face_id_any))
	for growth_any in setup.get("persistent_growths", []):
		var growth: Dictionary = growth_any
		run_state.progress.add_growth(growth)
	run_state.configure_starting_equipment(setup.get("equipment_instances", []))
	run_state.route_layers = generate_route_map(rngs, {"total_layers": route_length})
	run_state.route_nodes = _flatten_route_layers(run_state.route_layers)
	if not run_state.route_layers.is_empty():
		for node_any in run_state.route_layers[0]:
			var node: Dictionary = node_any
			run_state.current_available_uids.append(String(node.get("route_node_uid", "")))
		if not run_state.current_available_uids.is_empty():
			run_state.current_node_uid = run_state.current_available_uids[0]
	return {"state": run_state, "rngs": rngs}

func select_route_node(run_state: RunStateScript, route_node_uid: String) -> Dictionary:
	return {"ok": run_state.select_route_node(route_node_uid), "route_node_uid": route_node_uid}

func resolve_current_node(run_state: RunStateScript, rngs: RngStreamsScript) -> Dictionary:
	if run_state.completed:
		return {"ok": false, "reason": "run_completed"}
	if not run_state.pending_reward_choices.is_empty():
		return {"ok": false, "reason": "reward_choice_pending"}
	var node := run_state.current_node()
	if node.is_empty():
		run_state.finish("completed", "Route ended.")
		return {"ok": false, "reason": "no_current_node"}

	var node_type := String(node.get("node_type", ""))
	match node_type:
		"battle", "elite", "boss":
			return _resolve_battle_node(run_state, rngs, node)
		"event":
			return _resolve_event_node(run_state, rngs, node)
		"supply":
			return _resolve_supply_node(run_state, rngs, node)
		"shop":
			return _resolve_reward_node(run_state, rngs, node, "shop", 3)
		"rest":
			return _resolve_rest_node(run_state, node)
		"evac":
			return evacuate(run_state)
		_:
			return {"ok": false, "reason": "unsupported_node_type", "node_type": node_type}

func complete_battle_node(
	run_state: RunStateScript,
	rngs: RngStreamsScript,
	victory: bool,
	enemy_id: String,
	battle_meta: Dictionary = {}
) -> Dictionary:
	if run_state.completed:
		return {"ok": false, "reason": "run_completed"}
	if not run_state.pending_reward_choices.is_empty():
		return {"ok": false, "reason": "reward_choice_pending"}
	var node := run_state.current_node()
	if node.is_empty():
		return {"ok": false, "reason": "no_current_node"}
	var node_type := String(node.get("node_type", ""))
	if not ["battle", "elite", "boss"].has(node_type):
		return {"ok": false, "reason": "current_node_not_battle"}

	var node_id := String(node.get("id", ""))
	if not victory:
		run_state.node_results.append({
			"node_id": node_id,
			"node_type": node_type,
			"result": "defeat",
			"enemy_id": enemy_id,
			"turns": int(battle_meta.get("turns", 0)),
			"log_size": int(battle_meta.get("log_size", 0))
		})
		run_state.finish("failed", "Battle failed. Run ended.")
		return {"ok": true, "node_type": node_type, "battle_result": "defeat"}

	return _grant_node_rewards(run_state, rngs, node, node_type, {
		"result": "victory",
		"enemy_id": enemy_id,
		"turns": int(battle_meta.get("turns", 0)),
		"log_size": int(battle_meta.get("log_size", 0))
	})

func choose_reward(run_state: RunStateScript, reward_index: int) -> Dictionary:
	if reward_index < 0 or reward_index >= run_state.pending_reward_choices.size():
		return {"ok": false, "reason": "reward_index_out_of_range"}
	var reward: Dictionary = run_state.pending_reward_choices[reward_index]
	var apply_result := _apply_pending_choice(run_state, reward)
	if not bool(apply_result.get("ok", false)):
		return apply_result
	run_state.node_results.append({
		"node_id": String(run_state.current_node().get("id", "")),
		"node_type": String(run_state.current_node().get("node_type", "")),
		"result": "reward_selected",
		"reward_id": String(reward.get("reward_id", ""))
	})
	run_state.pending_reward_choices.clear()
	run_state.advance_node()
	return {"ok": true, "reward": reward}

func evacuate(run_state: RunStateScript) -> Dictionary:
	if not run_state.can_evac():
		return {"ok": false, "reason": "evac_not_available"}
	run_state.finish("evacuated", "Evacuated successfully.")
	return {"ok": true, "result_type": "evacuated"}

func generate_route_map(rngs: RngStreamsScript, config: Dictionary = {}) -> Array:
	var total_layers := int(config.get("total_layers", 13))
	var boss_layer := int(config.get("boss_layer", total_layers))
	var lanes_min := int(config.get("lanes_min", 2))
	var lanes_max := int(config.get("lanes_max", 4))
	var layers: Array = []
	for layer_index in range(1, total_layers + 1):
		var layer: Array = []
		var lane_count := 1
		if layer_index != boss_layer:
			lane_count = lanes_min + rngs.run_pick(max(1, lanes_max - lanes_min + 1))
		for lane_index in range(lane_count):
			var node_type := _node_type_for_layer(layer_index, lane_index, boss_layer, rngs)
			var row := _pick_route_template(layer_index, node_type, rngs)
			var node := row.duplicate(true)
			node["route_node_uid"] = "L%02dN%02d_%s" % [layer_index, lane_index + 1, String(node.get("id", node_type))]
			node["template_id"] = String(node.get("id", ""))
			node["layer_index"] = layer_index
			node["lane_index"] = lane_index + 1
			node["node_type"] = node_type
			node["phase"] = _phase_for_layer(layer_index, boss_layer)
			node["outgoing_uids"] = []
			layer.append(node)
		layers.append(layer)
	_connect_route_layers(layers, rngs)
	return layers

func _generate_route(rngs: RngStreamsScript, route_length: int) -> Array[Dictionary]:
	var route: Array[Dictionary] = []
	var current_pool := "start"
	for _i in range(route_length):
		var pool_rows := _run_catalog.nodes_for_pool(current_pool)
		if pool_rows.is_empty():
			break
		var pick_index := _weighted_pick(pool_rows, rngs)
		var row: Dictionary = pool_rows[pick_index]
		route.append(row)
		var next_pool := String(row.get("next_pool", current_pool))
		if next_pool == "":
			break
		current_pool = next_pool
	return route

func _flatten_route_layers(layers: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for layer_any in layers:
		var layer: Array = layer_any
		for node_any in layer:
			var node: Dictionary = node_any
			out.append(node)
	return out

func _node_type_for_layer(layer_index: int, lane_index: int, boss_layer: int, rngs: RngStreamsScript) -> String:
	if layer_index == boss_layer:
		return "boss"
	if layer_index == 1:
		return "battle"
	if (layer_index == 6 or layer_index == 10) and lane_index == 0:
		return "elite"
	var weighted: Array[Dictionary] = []
	if layer_index <= 4:
		weighted = [
			{"type": "battle", "weight": 60},
			{"type": "event", "weight": 25},
			{"type": "supply", "weight": 15}
		]
	elif layer_index <= 8:
		weighted = [
			{"type": "battle", "weight": 48},
			{"type": "event", "weight": 22},
			{"type": "supply", "weight": 12},
			{"type": "shop", "weight": 10},
			{"type": "elite", "weight": 3}
		]
	else:
		weighted = [
			{"type": "battle", "weight": 45},
			{"type": "event", "weight": 18},
			{"type": "rest", "weight": 12},
			{"type": "shop", "weight": 10},
			{"type": "elite", "weight": 5}
		]
	var pick := _weighted_pick(weighted, rngs)
	return String(weighted[pick].get("type", "battle"))

func _pick_route_template(layer_index: int, node_type: String, rngs: RngStreamsScript) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for row in _loader.load_rows("run_nodes"):
		if String(row.get("node_type", "")) != node_type:
			continue
		if node_type == "evac":
			continue
		var min_layer := _int_or(row.get("min_layer", "1"), 1)
		var max_layer := _int_or(row.get("max_layer", "99"), 99)
		var requires_after := _int_or(row.get("requires_after_layer", "0"), 0)
		if layer_index < min_layer or layer_index > max_layer:
			continue
		if requires_after > 0 and layer_index <= requires_after:
			continue
		candidates.append(row)
	if candidates.is_empty():
		for row in _loader.load_rows("run_nodes"):
			if String(row.get("node_type", "")) == node_type:
				candidates.append(row)
	if candidates.is_empty():
		return {"id": "fallback_" + node_type, "node_type": node_type, "weight": "1", "text": node_type}
	return candidates[_weighted_pick(candidates, rngs)]

func _phase_for_layer(layer_index: int, boss_layer: int) -> String:
	if layer_index == boss_layer:
		return "boss"
	if layer_index <= 4:
		return "starter"
	if layer_index <= 8:
		return "mid"
	return "deep"

func _connect_route_layers(layers: Array, rngs: RngStreamsScript) -> void:
	for layer_index in range(layers.size() - 1):
		var current_layer: Array = layers[layer_index]
		var next_layer: Array = layers[layer_index + 1]
		if current_layer.is_empty() or next_layer.is_empty():
			continue
		var incoming := {}
		for next_node_any in next_layer:
			var next_node: Dictionary = next_node_any
			incoming[String(next_node.get("route_node_uid", ""))] = false
		for i in range(current_layer.size()):
			var node: Dictionary = current_layer[i]
			var outgoing: Array[String] = []
			var primary_index: int = int(min(i, next_layer.size() - 1))
			var primary: Dictionary = next_layer[primary_index]
			var primary_uid := String(primary.get("route_node_uid", ""))
			outgoing.append(primary_uid)
			incoming[primary_uid] = true
			if next_layer.size() > 1 and rngs.run_pick(100) < 55:
				var secondary_index: int = int(clamp(primary_index + (1 if rngs.run_pick(2) == 0 else -1), 0, next_layer.size() - 1))
				var secondary: Dictionary = next_layer[secondary_index]
				var secondary_uid := String(secondary.get("route_node_uid", ""))
				if not outgoing.has(secondary_uid):
					outgoing.append(secondary_uid)
					incoming[secondary_uid] = true
			node["outgoing_uids"] = outgoing
			current_layer[i] = node
		for j in range(next_layer.size()):
			var next_node: Dictionary = next_layer[j]
			var next_uid := String(next_node.get("route_node_uid", ""))
			if bool(incoming.get(next_uid, false)):
				continue
			var source_index := j % current_layer.size()
			var source: Dictionary = current_layer[source_index]
			var source_outgoing: Array = source.get("outgoing_uids", [])
			if not source_outgoing.has(next_uid):
				source_outgoing.append(next_uid)
			source["outgoing_uids"] = source_outgoing
			current_layer[source_index] = source
		layers[layer_index] = current_layer

func _int_or(value, fallback: int) -> int:
	var raw := String(value).strip_edges()
	if raw.is_valid_int():
		return int(raw)
	return fallback

func _weighted_pick(rows: Array[Dictionary], rngs: RngStreamsScript) -> int:
	var total := 0
	for row in rows:
		total += max(1, int(row.get("weight", "1")))
	var roll := rngs.run_pick(max(1, total))
	var cursor := 0
	for i in range(rows.size()):
		cursor += max(1, int(rows[i].get("weight", "1")))
		if roll < cursor:
			return i
	return max(0, rows.size() - 1)

func _resolve_battle_node(run_state: RunStateScript, rngs: RngStreamsScript, node: Dictionary) -> Dictionary:
	var node_type := String(node.get("node_type", "battle"))
	var enemy_id := String(node.get("battle_enemy_id", "boss_vanguard"))
	var factory := UnitFactoryScript.new(_loader)
	var player := factory.create_npc(run_state.hero_id, run_state.loadout_face_ids)
	run_state.progress.apply_all_to_unit(player, true)
	var enemy := factory.create_enemy(enemy_id)
	var state := CombatStateScript.new(player, enemy)
	var logger := ActionLoggerScript.new()
	var enemy_row := _loader.find_row_by_id("enemies", enemy_id)
	var simulator := BattleSimulatorScript.new(_combat_catalog, enemy_row)
	simulator.initialize_equipment_for_battle(state, run_state.equipped_equipment_instances(), logger)
	var result := simulator.run(state, rngs, logger)
	if String(result.get("winner", "")) != run_state.hero_id:
		run_state.node_results.append({
			"node_id": String(node.get("id", "")),
			"node_type": node_type,
			"result": "defeat",
			"enemy_id": enemy_id
		})
		run_state.finish("failed", "Battle failed. Run ended.")
		return {"ok": true, "node_type": node_type, "battle_result": "defeat", "log_size": logger.entries().size()}

	var grant_result := _grant_node_rewards(run_state, rngs, node, node_type, {
		"result": "victory",
		"enemy_id": enemy_id
	})
	grant_result["battle_result"] = "victory"
	grant_result["enemy_id"] = enemy_id
	grant_result["log_size"] = logger.entries().size()
	return grant_result

func _resolve_event_node(run_state: RunStateScript, rngs: RngStreamsScript, node: Dictionary) -> Dictionary:
	var event_id := String(node.get("event_id", ""))
	var event_row := _run_catalog.event_by_id(event_id)
	var source := String(event_row.get("reward_source", "event"))
	var reward_ids := _run_catalog.reward_ids_for_source(source)
	var drafted := _reward_service.draft_rewards_from_ids(_combat_catalog, rngs, reward_ids, 2)
	var options: Array[Dictionary] = []
	options.append(_node_effect_choice(
		"event_safe_salvage",
		"Safe salvage",
		"Gain 18 credits. Low impact, no risk.",
		"event",
		{"currency_id": "credits", "amount": 18}
	))
	if _run_has_equipment(run_state, "old_compass"):
		options.append(_node_effect_choice(
			"event_old_compass_route",
			"Old Compass route",
			"Take the safer hidden line: gain 12 credits and a next-battle reroll buffer.",
			"event",
			{"currency_id": "credits", "amount": 12, "growth": {"growth_id": "old_compass_reroll_buffer", "type": "combat", "target": "temp_ranged_flat", "delta": "1", "duration_scope": "battle", "grant_once": "false"}}
		))
	for reward in drafted:
		var option := reward.duplicate(true)
		option["choice_kind"] = "event_reward"
		option["source_node_type"] = "event"
		option["title"] = "Risk cache: " + String(option.get("title", "reward"))
		option["description"] = String(option.get("description", "")) + " Event choice: stronger build tempo instead of credits."
		options.append(option)
	if options.is_empty():
		run_state.node_results.append({"node_id": String(node.get("id", "")), "node_type": "event", "result": "empty", "event_id": event_id})
		run_state.advance_node()
		return {"ok": true, "node_type": "event", "event_id": event_id}
	run_state.pending_reward_choices = options
	run_state.node_results.append({
		"node_id": String(node.get("id", "")),
		"node_type": "event",
		"result": "pending_choice",
		"event_id": event_id
	})
	return {"ok": true, "node_type": "event", "event_id": event_id, "pending_rewards": run_state.pending_reward_choices.size()}

func _resolve_supply_node(run_state: RunStateScript, rngs: RngStreamsScript, node: Dictionary) -> Dictionary:
	var reward_ids := _run_catalog.reward_ids_for_source("supply")
	var drafted := _reward_service.draft_rewards_from_ids(_combat_catalog, rngs, reward_ids, 2)
	if drafted.is_empty():
		run_state.node_results.append({"node_id": String(node.get("id", "")), "node_type": "supply", "result": "empty"})
		run_state.advance_node()
		return {"ok": true, "node_type": "supply"}
	run_state.pending_reward_choices = []
	for reward in drafted:
		var option := reward.duplicate(true)
		option["choice_kind"] = "supply_reward"
		option["source_node_type"] = "supply"
		run_state.pending_reward_choices.append(option)
	run_state.pending_reward_choices.append(_node_effect_choice(
		"supply_field_kit",
		"Field kit",
		"Gain 2 starting block for the next battle and 10 credits.",
		"supply",
		{"currency_id": "credits", "amount": 10, "growth": {"growth_id": "supply_field_kit_block", "type": "stat", "target": "block", "delta": "2", "duration_scope": "battle", "grant_once": "false"}}
	))
	run_state.node_results.append({
		"node_id": String(node.get("id", "")),
		"node_type": "supply",
		"result": "pending_choice"
	})
	return {"ok": true, "node_type": "supply", "pending_rewards": run_state.pending_reward_choices.size()}

func _resolve_reward_node(run_state: RunStateScript, rngs: RngStreamsScript, node: Dictionary, source: String, choice_count: int) -> Dictionary:
	var reward_ids := _run_catalog.reward_ids_for_source(source)
	run_state.pending_reward_choices = _reward_service.draft_rewards_from_ids(_combat_catalog, rngs, reward_ids, choice_count)
	if source == "shop":
		for i in range(run_state.pending_reward_choices.size()):
			var reward: Dictionary = run_state.pending_reward_choices[i]
			reward["choice_kind"] = "shop_reward"
			reward["price"] = _shop_price(reward)
			reward["description"] = String(reward.get("description", "")) + " Price: %d credits." % int(reward.get("price", 0))
			run_state.pending_reward_choices[i] = reward
		run_state.pending_reward_choices.append(_node_effect_choice(
			"shop_skip",
			"Leave shop",
			"Buy nothing and move on.",
			"shop",
			{}
		))
	run_state.node_results.append({
		"node_id": String(node.get("id", "")),
		"node_type": source,
		"result": "pending_reward" if not run_state.pending_reward_choices.is_empty() else "empty"
	})
	if run_state.pending_reward_choices.is_empty():
		run_state.advance_node()
	return {"ok": true, "node_type": source, "pending_rewards": run_state.pending_reward_choices.size()}

func _resolve_rest_node(run_state: RunStateScript, node: Dictionary) -> Dictionary:
	run_state.pending_reward_choices = [
		_node_effect_choice(
			"rest_repair",
			"Repair armor",
			"Gain 4 max HP for this run.",
			"rest",
			{"growth": {"growth_id": "rest_repair_hull", "type": "stat", "target": "base_hp", "delta": "4", "duration_scope": "run", "grant_once": "false"}}
		),
		_node_effect_choice(
			"rest_prepare",
			"Prepare stance",
			"Gain 4 starting block for the next battle.",
			"rest",
			{"growth": {"growth_id": "rest_prepare_block", "type": "stat", "target": "block", "delta": "4", "duration_scope": "battle", "grant_once": "false"}}
		),
		_node_effect_choice(
			"rest_scout",
			"Scout ahead",
			"Gain 15 credits and keep your build unchanged.",
			"rest",
			{"currency_id": "credits", "amount": 15}
		)
	]
	run_state.node_results.append({
		"node_id": String(node.get("id", "")),
		"node_type": "rest",
		"result": "pending_choice"
	})
	return {"ok": true, "node_type": "rest", "pending_rewards": run_state.pending_reward_choices.size()}

func _grant_node_rewards(run_state: RunStateScript, rngs: RngStreamsScript, node: Dictionary, source: String, extra_result: Dictionary) -> Dictionary:
	var reward_ids := _run_catalog.reward_ids_for_source(source)
	run_state.pending_reward_choices = _reward_service.draft_rewards_from_ids(_combat_catalog, rngs, reward_ids, 3)
	var node_result := {
		"node_id": String(node.get("id", "")),
		"node_type": source,
		"result": String(extra_result.get("result", "resolved"))
	}
	for key in extra_result.keys():
		node_result[key] = extra_result[key]
	if run_state.pending_reward_choices.is_empty():
		run_state.node_results.append(node_result)
		run_state.advance_node()
	else:
		node_result["result"] = String(extra_result.get("result", "resolved")) + "_pending_reward"
		run_state.node_results.append(node_result)
	return {
		"ok": true,
		"node_type": source,
		"pending_rewards": run_state.pending_reward_choices.size()
	}

func _apply_pending_choice(run_state: RunStateScript, choice: Dictionary) -> Dictionary:
	var choice_kind := String(choice.get("choice_kind", ""))
	if choice_kind == "shop_reward":
		var price := int(choice.get("price", 0))
		if not run_state.progress.spend_currency("credits", price):
			return {"ok": false, "reason": "not_enough_credits", "price": price}
		if String(choice.get("type", "")) == "equipment":
			return run_state.apply_equipment_reward(choice, String(run_state.current_node().get("route_node_uid", "")))
		return _reward_service.apply_reward(run_state.progress, choice)
	if choice_kind == "node_effect":
		return _apply_node_effect(run_state, choice)
	if choice_kind in ["event_reward", "supply_reward"]:
		if String(choice.get("type", "")) == "equipment":
			return run_state.apply_equipment_reward(choice, String(run_state.current_node().get("route_node_uid", "")))
		return _reward_service.apply_reward(run_state.progress, choice)
	if String(choice.get("type", "")) == "equipment":
		return run_state.apply_equipment_reward(choice, String(run_state.current_node().get("route_node_uid", "")))
	return _reward_service.apply_reward(run_state.progress, choice)

func _apply_node_effect(run_state: RunStateScript, choice: Dictionary) -> Dictionary:
	var effect: Dictionary = choice.get("node_effect", {})
	if effect.has("amount"):
		run_state.progress.add_currency(String(effect.get("currency_id", "credits")), int(effect.get("amount", 0)))
	if effect.has("growth"):
		var growth: Dictionary = effect.get("growth", {})
		if not growth.is_empty():
			run_state.progress.add_growth(growth)
	return {"ok": true, "reward_id": String(choice.get("reward_id", "")), "kind": "node_effect"}

func _node_effect_choice(choice_id: String, title: String, description: String, source: String, effect: Dictionary) -> Dictionary:
	return {
		"reward_id": choice_id,
		"type": "node_effect",
		"choice_kind": "node_effect",
		"source_node_type": source,
		"rarity": "common",
		"rarity_label": "Node",
		"scope_label": "Immediate",
		"title": title,
		"description": description,
		"node_effect": effect
	}

func _shop_price(reward: Dictionary) -> int:
	match String(reward.get("rarity", "common")):
		"rare":
			return 45
		"uncommon":
			return 30
		_:
			return 20

func _run_has_equipment(run_state: RunStateScript, equipment_id: String) -> bool:
	for item in run_state.equipped_equipment_instances():
		if String(item.get("equipment_id", "")) == equipment_id and String(item.get("damage_state", "intact")) != "broken":
			return true
	return false
