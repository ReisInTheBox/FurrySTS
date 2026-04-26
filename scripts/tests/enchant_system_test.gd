class_name EnchantSystemTest
extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const CombatCatalogScript = preload("res://scripts/content/combat_catalog.gd")
const RewardDraftServiceScript = preload("res://scripts/run/reward_draft_service.gd")
const RunProgressStateScript = preload("res://scripts/run/run_progress_state.gd")
const UnitFactoryScript = preload("res://scripts/content/unit_factory.gd")
const CombatStateScript = preload("res://scripts/combat/combat_state.gd")
const BattleSimulatorScript = preload("res://scripts/combat/battle_simulator.gd")
const ActionLoggerScript = preload("res://scripts/core/action_logger.gd")
const SeedBundleScript = preload("res://scripts/core/seed_bundle.gd")
const RngStreamsScript = preload("res://scripts/core/rng_streams.gd")

func run() -> bool:
	var loader := ContentLoaderScript.new()
	var catalog := CombatCatalogScript.new(loader)
	return _test_enchant_data(catalog) \
		and _test_reward_binding_rules() \
		and _test_build_replacement_removes_enchant() \
		and _test_battle_enchant_determinism(loader, catalog)

func _test_enchant_data(catalog: CombatCatalogScript) -> bool:
	var rows := catalog.all_enchantments()
	if rows.size() < 6:
		push_error("Need at least 6 MVP enchantments.")
		return false
	for row in rows:
		if String(row.get("enchant_id", "")) == "" or String(row.get("op_type", "")) == "":
			push_error("Invalid enchantment row.")
			return false
	return true

func _test_reward_binding_rules() -> bool:
	var service := RewardDraftServiceScript.new()
	var run_state := RunProgressStateScript.new()
	var grant := {
		"reward_id": "test_grant",
		"type": "grant_enchant",
		"value": "cyan_pulse_die:1:ench_spark_edge"
	}
	var result := service.apply_reward(run_state, grant)
	if not bool(result.get("ok", false)):
		push_error("Grant enchant failed.")
		return false
	var duplicate := service.apply_reward(run_state, grant)
	if bool(duplicate.get("ok", false)) or String(duplicate.get("reason", "")) != "duplicate_enchant_slot":
		push_error("Duplicate enchant slot should be rejected.")
		return false
	var replace := {
		"reward_id": "test_replace",
		"type": "replace_enchant",
		"value": "cyan_pulse_die:1:ench_guard_rune"
	}
	result = service.apply_reward(run_state, replace)
	if not bool(result.get("ok", false)):
		push_error("Replace enchant failed.")
		return false
	if String(run_state.all_enchant_bindings()[0].get("enchant_id", "")) != "ench_guard_rune":
		push_error("Replace enchant did not update the slot.")
		return false
	var remove := {
		"reward_id": "test_remove",
		"type": "remove_enchant",
		"value": "cyan_pulse_die:1"
	}
	result = service.apply_reward(run_state, remove)
	return bool(result.get("ok", false)) and run_state.all_enchant_bindings().is_empty()

func _test_build_replacement_removes_enchant() -> bool:
	var run_state := RunProgressStateScript.new()
	var grant_result := run_state.grant_enchant({
		"die_id": "cyan_core_die",
		"face_index": 1,
		"enchant_id": "ench_spark_edge"
	})
	if not bool(grant_result.get("ok", false)):
		return false
	run_state.add_build_change({
		"change_type": "remove_negative",
		"die_id": "cyan_core_die",
		"fallback_die_id": "cyan_pulse_die"
	})
	if not run_state.all_enchant_bindings().is_empty():
		push_error("Replacing/removing a die should remove enchant bindings on the old die.")
		return false
	return true

func _test_battle_enchant_determinism(loader: ContentLoaderScript, catalog: CombatCatalogScript) -> bool:
	var a := _manual_enchant_signature(loader, catalog)
	var b := _manual_enchant_signature(loader, catalog)
	if a != b:
		push_error("Same build and enchant binding should produce identical logs.")
		return false
	if a.find("enchant_triggered:ench_spark_edge") < 0:
		push_error("Battle did not trigger the bound enchantment.")
		return false
	return true

func _manual_enchant_signature(loader: ContentLoaderScript, catalog: CombatCatalogScript) -> String:
	var factory := UnitFactoryScript.new(loader)
	var player := factory.create_npc("cyan_ryder", ["cyan_pulse_die", "cyan_shift_die", "cyan_core_die"])
	var run_state := RunProgressStateScript.new()
	run_state.grant_enchant({
		"die_id": "cyan_pulse_die",
		"face_index": 1,
		"enchant_id": "ench_spark_edge",
		"source": "test"
	})
	run_state.apply_all_to_unit(player, false)
	var state := CombatStateScript.new(player, factory.create_enemy("boss_vanguard"))
	var faces := catalog.faces_for_die("cyan_pulse_die")
	state.rolled_faces = [faces[0]]
	state.picks_budget = 1
	state.rerolls_left = 2
	var logger := ActionLoggerScript.new()
	var simulator := BattleSimulatorScript.new(catalog, loader.find_row_by_id("enemies", "boss_vanguard"))
	var rngs := RngStreamsScript.new(SeedBundleScript.new(123456))
	simulator.apply_manual_face_pick_at(state, rngs, logger, 0)
	var parts: Array[String] = []
	for entry_any in logger.entries():
		var entry = entry_any
		var payload: Dictionary = entry.payload if typeof(entry.payload) == TYPE_DICTIONARY else {}
		parts.append("%s:%s:%s" % [
			str(entry.event_type),
			str(payload.get("enchant_id", payload.get("face_id", ""))),
			str(payload.get("damage", payload.get("value", "")))
		])
	return "|".join(parts)
