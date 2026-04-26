class_name BuildLoadoutTest
extends RefCounted

const SeedBundleScript = preload("res://scripts/core/seed_bundle.gd")
const RngStreamsScript = preload("res://scripts/core/rng_streams.gd")
const ActionLoggerScript = preload("res://scripts/core/action_logger.gd")
const CombatStateScript = preload("res://scripts/combat/combat_state.gd")
const BattleSimulatorScript = preload("res://scripts/combat/battle_simulator.gd")
const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const UnitFactoryScript = preload("res://scripts/content/unit_factory.gd")
const CombatCatalogScript = preload("res://scripts/content/combat_catalog.gd")

func run() -> bool:
	var loader := ContentLoaderScript.new()
	return _test_same_build_same_seed_reproducible(loader) and _test_different_die_loadouts_change_roll_pool(loader)

func _rolled_signature(loader: ContentLoaderScript, hero_id: String, loadout_die_ids: Array[String], seed_value: int) -> String:
	var factory := UnitFactoryScript.new(loader)
	var catalog := CombatCatalogScript.new(loader)
	var enemy_row := loader.find_row_by_id("enemies", "boss_vanguard")
	var player := factory.create_npc(hero_id, loadout_die_ids)
	var enemy := factory.create_enemy("boss_vanguard")
	var state := CombatStateScript.new(player, enemy)
	var simulator := BattleSimulatorScript.new(catalog, enemy_row)
	var rngs := RngStreamsScript.new(SeedBundleScript.new(seed_value))
	var logger := ActionLoggerScript.new()
	simulator.start_manual_player_turn(state, rngs, logger)
	var parts: Array[String] = []
	for face_any in state.rolled_faces:
		parts.append(String(face_any.die_id) + ":" + String(face_any.face_id))
	return "|".join(parts)

func _test_same_build_same_seed_reproducible(loader: ContentLoaderScript) -> bool:
	var loadout: Array[String] = ["cyan_pulse_die", "cyan_shift_die", "cyan_core_die"]
	var a := _rolled_signature(loader, "cyan_ryder", loadout, 20260426)
	var b := _rolled_signature(loader, "cyan_ryder", loadout, 20260426)
	if a != b:
		push_error("Same seed and same die_id loadout did not reproduce: %s vs %s" % [a, b])
		return false
	return true

func _test_different_die_loadouts_change_roll_pool(loader: ContentLoaderScript) -> bool:
	var standard: Array[String] = ["cyan_pulse_die", "cyan_shift_die", "cyan_core_die"]
	var shifted: Array[String] = ["cyan_pulse_die", "cyan_pulse_die", "cyan_shift_die"]
	var a := _rolled_signature(loader, "cyan_ryder", standard, 20260426)
	var b := _rolled_signature(loader, "cyan_ryder", shifted, 20260426)
	if a == b:
		push_error("Different die_id loadouts produced identical roll signature: " + a)
		return false
	return true
