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

func create_run(master_seed: int, hero_id: String = "cyan_ryder", route_length: int = 5, setup: Dictionary = {}) -> Dictionary:
	var rngs := RngStreamsScript.new(SeedBundleScript.new(master_seed))
	var run_state := RunStateScript.new()
	run_state.hero_id = hero_id
	for face_id_any in setup.get("loadout_face_ids", []):
		run_state.loadout_face_ids.append(String(face_id_any))
	for growth_any in setup.get("persistent_growths", []):
		var growth: Dictionary = growth_any
		run_state.progress.add_growth(growth)
	run_state.route_nodes = _generate_route(rngs, route_length)
	return {"state": run_state, "rngs": rngs}

func resolve_current_node(run_state: RunStateScript, rngs: RngStreamsScript) -> Dictionary:
	if run_state.completed:
		return {"ok": false, "reason": "run_completed"}
	if not run_state.pending_reward_choices.is_empty():
		return {"ok": false, "reason": "reward_choice_pending"}
	var node := run_state.current_node()
	if node.is_empty():
		run_state.finish("completed", "路线已结束。")
		return {"ok": false, "reason": "no_current_node"}

	var node_type := String(node.get("node_type", ""))
	match node_type:
		"battle":
			return _resolve_battle_node(run_state, rngs, node)
		"event":
			return _resolve_event_node(run_state, rngs, node)
		"supply":
			return _resolve_supply_node(run_state, rngs, node)
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
	if String(node.get("node_type", "")) != "battle":
		return {"ok": false, "reason": "current_node_not_battle"}

	var node_id := String(node.get("id", ""))
	if not victory:
		run_state.node_results.append({
			"node_id": node_id,
			"node_type": "battle",
			"result": "defeat",
			"enemy_id": enemy_id,
			"turns": int(battle_meta.get("turns", 0)),
			"log_size": int(battle_meta.get("log_size", 0))
		})
		run_state.finish("failed", "战斗失败，Run 结束。")
		return {"ok": true, "node_type": "battle", "battle_result": "defeat"}

	var reward_ids := _run_catalog.reward_ids_for_source("battle")
	run_state.pending_reward_choices = _reward_service.draft_rewards_from_ids(_combat_catalog, rngs, reward_ids, 3)
	if run_state.pending_reward_choices.is_empty():
		run_state.node_results.append({
			"node_id": node_id,
			"node_type": "battle",
			"result": "victory",
			"enemy_id": enemy_id,
			"turns": int(battle_meta.get("turns", 0)),
			"log_size": int(battle_meta.get("log_size", 0))
		})
		run_state.advance_node()
	else:
		run_state.node_results.append({
			"node_id": node_id,
			"node_type": "battle",
			"result": "victory_pending_reward",
			"enemy_id": enemy_id,
			"turns": int(battle_meta.get("turns", 0)),
			"log_size": int(battle_meta.get("log_size", 0))
		})
	return {
		"ok": true,
		"node_type": "battle",
		"battle_result": "victory",
		"enemy_id": enemy_id,
		"pending_rewards": run_state.pending_reward_choices.size()
	}

func choose_reward(run_state: RunStateScript, reward_index: int) -> Dictionary:
	if reward_index < 0 or reward_index >= run_state.pending_reward_choices.size():
		return {"ok": false, "reason": "reward_index_out_of_range"}
	var reward: Dictionary = run_state.pending_reward_choices[reward_index]
	var apply_result := _reward_service.apply_reward(run_state.progress, reward)
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
	run_state.finish("evacuated", "已成功撤离。")
	return {"ok": true, "result_type": "evacuated"}

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
		if next_pool != "":
			current_pool = next_pool
	return route

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
	var enemy_id := String(node.get("battle_enemy_id", "boss_vanguard"))
	var factory := UnitFactoryScript.new(_loader)
	var player := factory.create_npc(run_state.hero_id, run_state.loadout_face_ids)
	run_state.progress.apply_all_to_unit(player, true)
	var enemy := factory.create_enemy(enemy_id)
	var state := CombatStateScript.new(player, enemy)
	var logger := ActionLoggerScript.new()
	var enemy_row := _loader.find_row_by_id("enemies", enemy_id)
	var simulator := BattleSimulatorScript.new(_combat_catalog, enemy_row)
	var result := simulator.run(state, rngs, logger)
	if String(result.get("winner", "")) != run_state.hero_id:
		run_state.node_results.append({
			"node_id": String(node.get("id", "")),
			"node_type": "battle",
			"result": "defeat",
			"enemy_id": enemy_id
		})
		run_state.finish("failed", "战斗失败，Run 结束。")
		return {"ok": true, "node_type": "battle", "battle_result": "defeat", "log_size": logger.entries().size()}

	var reward_ids := _run_catalog.reward_ids_for_source("battle")
	run_state.pending_reward_choices = _reward_service.draft_rewards_from_ids(_combat_catalog, rngs, reward_ids, 3)
	if run_state.pending_reward_choices.is_empty():
		run_state.node_results.append({
			"node_id": String(node.get("id", "")),
			"node_type": "battle",
			"result": "victory",
			"enemy_id": enemy_id
		})
		run_state.advance_node()
	else:
		run_state.node_results.append({
			"node_id": String(node.get("id", "")),
			"node_type": "battle",
			"result": "victory_pending_reward",
			"enemy_id": enemy_id
		})
	return {
		"ok": true,
		"node_type": "battle",
		"battle_result": "victory",
		"enemy_id": enemy_id,
		"log_size": logger.entries().size(),
		"pending_rewards": run_state.pending_reward_choices.size()
	}

func _resolve_event_node(run_state: RunStateScript, rngs: RngStreamsScript, node: Dictionary) -> Dictionary:
	var event_id := String(node.get("event_id", ""))
	var event_row := _run_catalog.event_by_id(event_id)
	var source := String(event_row.get("reward_source", "event"))
	var reward_ids := _run_catalog.reward_ids_for_source(source)
	var drafted := _reward_service.draft_rewards_from_ids(_combat_catalog, rngs, reward_ids, 1)
	if drafted.is_empty():
		run_state.node_results.append({"node_id": String(node.get("id", "")), "node_type": "event", "result": "empty"})
		run_state.advance_node()
		return {"ok": true, "node_type": "event", "event_id": event_id}
	var apply_result := _reward_service.apply_reward(run_state.progress, drafted[0])
	run_state.node_results.append({
		"node_id": String(node.get("id", "")),
		"node_type": "event",
		"result": "resolved",
		"event_id": event_id,
		"reward_id": String(drafted[0].get("reward_id", ""))
	})
	run_state.advance_node()
	return {"ok": bool(apply_result.get("ok", false)), "node_type": "event", "event_id": event_id, "reward": drafted[0]}

func _resolve_supply_node(run_state: RunStateScript, rngs: RngStreamsScript, node: Dictionary) -> Dictionary:
	var reward_ids := _run_catalog.reward_ids_for_source("supply")
	var drafted := _reward_service.draft_rewards_from_ids(_combat_catalog, rngs, reward_ids, 1)
	if drafted.is_empty():
		run_state.node_results.append({"node_id": String(node.get("id", "")), "node_type": "supply", "result": "empty"})
		run_state.advance_node()
		return {"ok": true, "node_type": "supply"}
	var apply_result := _reward_service.apply_reward(run_state.progress, drafted[0])
	run_state.node_results.append({
		"node_id": String(node.get("id", "")),
		"node_type": "supply",
		"result": "resolved",
		"reward_id": String(drafted[0].get("reward_id", ""))
	})
	run_state.advance_node()
	return {"ok": bool(apply_result.get("ok", false)), "node_type": "supply", "reward": drafted[0]}
