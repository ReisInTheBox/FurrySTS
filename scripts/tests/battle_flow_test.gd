class_name BattleFlowTest
extends RefCounted

const SeedBundleScript = preload("res://scripts/core/seed_bundle.gd")
const RngStreamsScript = preload("res://scripts/core/rng_streams.gd")
const ActionLoggerScript = preload("res://scripts/core/action_logger.gd")
const CombatStateScript = preload("res://scripts/combat/combat_state.gd")
const BattleSimulatorScript = preload("res://scripts/combat/battle_simulator.gd")
const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const UnitFactoryScript = preload("res://scripts/content/unit_factory.gd")
const CombatCatalogScript = preload("res://scripts/content/combat_catalog.gd")

const HERO_ID := "cyan_ryder"
const ENEMIES := ["boss_vanguard", "reef_stalker", "void_howler"]

func run(loader: ContentLoaderScript) -> bool:
	for enemy_id in ENEMIES:
		var a := _simulate_once(loader, 20260409, enemy_id)
		var b := _simulate_once(loader, 20260409, enemy_id)
		if String(a.get("winner", "")) == "":
			return false
		if int(a.get("turns", 0)) <= 0 or int(a.get("turns", 0)) > 61:
			return false
		if String(a.get("winner", "")) != String(b.get("winner", "")):
			return false
		if int(a.get("turns", 0)) != int(b.get("turns", 0)):
			return false
	if not _test_invalid_manual_action(loader):
		return false
	if not _test_turn_dice_economy(loader):
		return false
	return true

func _simulate_once(loader: ContentLoaderScript, seed_value: int, enemy_id: String) -> Dictionary:
	var bundle := SeedBundleScript.new(seed_value)
	var rngs := RngStreamsScript.new(bundle)
	var logger := ActionLoggerScript.new()
	var factory := UnitFactoryScript.new(loader)
	var catalog := CombatCatalogScript.new(loader)
	var enemy_row := loader.find_row_by_id("enemies", enemy_id)
	var state := CombatStateScript.new(factory.create_npc(HERO_ID), factory.create_enemy(enemy_id))
	var simulator := BattleSimulatorScript.new(catalog, enemy_row)
	return simulator.run(state, rngs, logger)

func _test_invalid_manual_action(loader: ContentLoaderScript) -> bool:
	var bundle := SeedBundleScript.new(998877)
	var rngs := RngStreamsScript.new(bundle)
	var logger := ActionLoggerScript.new()
	var factory := UnitFactoryScript.new(loader)
	var catalog := CombatCatalogScript.new(loader)
	var enemy_row := loader.find_row_by_id("enemies", ENEMIES[0])
	var state := CombatStateScript.new(factory.create_npc(HERO_ID), factory.create_enemy(ENEMIES[0]))
	var simulator := BattleSimulatorScript.new(catalog, enemy_row)
	simulator.start_manual_player_turn(state, rngs, logger)
	var ok := simulator.apply_manual_face_pick(state, rngs, logger, "nonexistent_face")
	if ok:
		return false
	for e_any in logger.entries():
		var e = e_any
		var payload: Dictionary = e.payload if typeof(e.payload) == TYPE_DICTIONARY else {}
		if String(e.event_type) == "action_rejected" and String(payload.get("reason", "")) == "face_not_pickable":
			return true
	return false

func _test_turn_dice_economy(loader: ContentLoaderScript) -> bool:
	var bundle := SeedBundleScript.new(112233)
	var rngs := RngStreamsScript.new(bundle)
	var logger := ActionLoggerScript.new()
	var factory := UnitFactoryScript.new(loader)
	var catalog := CombatCatalogScript.new(loader)
	var enemy_row := loader.find_row_by_id("enemies", ENEMIES[0])
	var state := CombatStateScript.new(
		factory.create_npc(HERO_ID, ["cyan_pulse_die", "cyan_shift_die", "cyan_core_die", "cyan_pulse_die"]),
		factory.create_enemy(ENEMIES[0])
	)
	var simulator := BattleSimulatorScript.new(catalog, enemy_row)
	simulator.start_manual_player_turn(state, rngs, logger)
	if state.rolled_faces.size() != 3:
		push_error("A player turn must roll exactly 3 D6, got " + str(state.rolled_faces.size()))
		return false
	if state.picks_budget != 3:
		push_error("A player turn must require exactly 3 dice uses, got " + str(state.picks_budget))
		return false
	if state.rerolls_left != 2:
		push_error("A player turn must start with 2 rerolls, got " + str(state.rerolls_left))
		return false

	state.bonus_rolls = 2
	var actions := 0
	while simulator.can_player_act(state):
		if not simulator.apply_manual_face_pick_at(state, rngs, logger, 0):
			push_error("Manual pick failed during dice economy test.")
			return false
		actions += 1
		if actions > 3:
			push_error("Turn allowed more than 3 dice uses.")
			return false
	if actions != 3 or state.picks_used != 3:
		push_error("Turn did not consume exactly 3 dice: actions=%d picks=%d" % [actions, state.picks_used])
		return false
	if not state.rolled_faces.is_empty():
		push_error("Turn left extra rolled faces after using all dice: " + str(state.rolled_faces.size()))
		return false
	return true
