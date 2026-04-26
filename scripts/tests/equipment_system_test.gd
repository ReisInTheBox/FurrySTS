class_name EquipmentSystemTest
extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const CombatCatalogScript = preload("res://scripts/content/combat_catalog.gd")
const SeedBundleScript = preload("res://scripts/core/seed_bundle.gd")
const RngStreamsScript = preload("res://scripts/core/rng_streams.gd")
const ActionLoggerScript = preload("res://scripts/core/action_logger.gd")
const CombatStateScript = preload("res://scripts/combat/combat_state.gd")
const BattleSimulatorScript = preload("res://scripts/combat/battle_simulator.gd")
const UnitFactoryScript = preload("res://scripts/content/unit_factory.gd")
const HubStateScript = preload("res://scripts/hub/hub_state.gd")
const RunStateScript = preload("res://scripts/run/run_state.gd")

func run() -> bool:
	var loader := ContentLoaderScript.new()
	var catalog := CombatCatalogScript.new(loader)
	return _test_equipment_data(catalog) \
		and _test_run_slot_replacement(catalog) \
		and _test_hub_cross_hero_and_broken_rules(loader) \
		and _test_carryback_and_failure_rules(loader, catalog) \
		and _test_damaged_equipment_is_weaker(loader, catalog) \
		and _test_battle_equipment_hooks(loader, catalog)

func _test_equipment_data(catalog: CombatCatalogScript) -> bool:
	var rows := catalog.all_equipment()
	if rows.size() < 17:
		push_error("Need at least 17 MVP equipment rows.")
		return false
	var slot_counts := {"weapon": 0, "armor": 0, "item": 0}
	for row in rows:
		var slot := String(row.get("equip_slot", ""))
		if not slot_counts.has(slot):
			push_error("Invalid equipment slot: " + slot)
			return false
		slot_counts[slot] = int(slot_counts[slot]) + 1
		if slot == "item" and not ["passive", "active"].has(String(row.get("item_mode", ""))):
			push_error("Item equipment must declare passive or active mode: " + String(row.get("equipment_id", "")))
			return false
		if slot != "item" and String(row.get("item_mode", "none")) != "none":
			push_error("Weapon/armor cannot use item mode: " + String(row.get("equipment_id", "")))
			return false
	return int(slot_counts["weapon"]) >= 5 and int(slot_counts["armor"]) >= 5 and int(slot_counts["item"]) >= 7

func _test_run_slot_replacement(catalog: CombatCatalogScript) -> bool:
	var run_state := RunStateScript.new()
	var field_jacket := _reward(catalog, "field_jacket")
	var iron_banner := _reward(catalog, "iron_banner")
	var lucky := _reward(catalog, "lucky_knuckle")
	var first := run_state.apply_equipment_reward(field_jacket, "test_node")
	if not bool(first.get("ok", false)) or String(first.get("equip_slot", "")) != "armor":
		push_error("Armor reward did not equip into armor slot.")
		return false
	var second := run_state.apply_equipment_reward(iron_banner, "test_node")
	if not bool(second.get("ok", false)) or String(run_state.equipment_in_slot("armor").get("equipment_id", "")) != "iron_banner":
		push_error("Armor replacement did not update armor slot.")
		return false
	if not run_state.temporary_equipment_pack.is_empty():
		push_error("Run-origin replacement should drop old run gear instead of packing it.")
		return false
	var item_result := run_state.apply_equipment_reward(lucky, "test_node")
	if not bool(item_result.get("ok", false)) or String(run_state.equipment_in_slot("item").get("equipment_id", "")) != "lucky_knuckle":
		push_error("Item reward did not equip into item slot.")
		return false
	return run_state.equipment_in_slot("weapon").is_empty()

func _test_hub_cross_hero_and_broken_rules(loader: ContentLoaderScript) -> bool:
	var hub := HubStateScript.new()
	hub.ensure_content(loader)
	if hub.equipment_storage.size() < 3:
		push_error("Hub should seed starter equipment.")
		return false
	var weapon_id := _first_instance_for_slot(hub, "weapon")
	var equip_cyan := hub.equip_storage_instance("cyan_ryder", weapon_id)
	if not bool(equip_cyan.get("ok", false)):
		push_error("Cyan could not equip starter weapon.")
		return false
	var equip_helios := hub.equip_storage_instance("helios_windchaser", weapon_id)
	if not bool(equip_helios.get("ok", false)):
		push_error("Helios could not equip the same cross-role weapon.")
		return false
	if String(hub.equipment_loadout_for_hero("cyan_ryder").get("weapon", "")) != "":
		push_error("Equipping one instance on Helios should clear it from Cyan.")
		return false
	for i in range(hub.equipment_storage.size()):
		var item: Dictionary = hub.equipment_storage[i]
		if String(item.get("equipment_instance_id", "")) == weapon_id:
			item["damage_state"] = "broken"
			hub.equipment_storage[i] = item
			break
	var broken := hub.equip_storage_instance("cyan_ryder", weapon_id)
	if bool(broken.get("ok", false)):
		push_error("Broken equipment should not be equipable.")
		return false
	return true

func _test_carryback_and_failure_rules(loader: ContentLoaderScript, catalog: CombatCatalogScript) -> bool:
	var hub := HubStateScript.new()
	hub.ensure_content(loader)
	var setup := hub.run_setup_for_selected_hero()
	var run_state := RunStateScript.new()
	run_state.configure_starting_equipment(setup.get("equipment_instances", []))
	run_state.apply_equipment_reward(_reward(catalog, "field_jacket"), "L01")
	run_state.finish("completed", "test completed")
	var result := run_state.result.to_dict()
	if result.get("extracted_equipment_instances", []).is_empty():
		push_error("Completed run should extract equipped equipment.")
		return false
	hub.apply_run_result(result)
	if hub.equipment_storage.size() > hub.equipment_storage_capacity:
		push_error("Hub storage exceeded capacity after carryback.")
		return false

	var failed := RunStateScript.new()
	failed.apply_equipment_reward(_reward(catalog, "hunter_scope"), "L02")
	failed.finish("failed", "test failed")
	var failed_result := failed.result.to_dict()
	if failed_result.get("extracted_equipment_instances", []).size() != 0:
		push_error("Failed run should not extract newly found run equipment.")
		return false
	if failed_result.get("lost_equipment_instances", []).size() != 1:
		push_error("Failed run should report newly found equipment as lost.")
		return false
	return true

func _test_battle_equipment_hooks(loader: ContentLoaderScript, catalog: CombatCatalogScript) -> bool:
	var factory := UnitFactoryScript.new(loader)
	var player := factory.create_npc("cyan_ryder")
	var enemy := factory.create_enemy("boss_vanguard")
	var state := CombatStateScript.new(player, enemy)
	var logger := ActionLoggerScript.new()
	var simulator := BattleSimulatorScript.new(catalog, loader.find_row_by_id("enemies", "boss_vanguard"))
	var equipment := [
		_instance(catalog, "field_jacket"),
		_instance(catalog, "lucky_knuckle"),
		_instance(catalog, "glass_fang")
	]
	simulator.initialize_equipment_for_battle(state, equipment, logger)
	if state.player.block < 4:
		push_error("Field Jacket should grant battle-start block.")
		return false
	if state.player.equipment_attack_flat < 2:
		push_error("Glass Fang should grant attack flat bonus.")
		return false
	state.rolled_faces = catalog.faces_for_die("cyan_pulse_die")
	state.rerolls_left = 2
	var rngs := RngStreamsScript.new(SeedBundleScript.new(999))
	if not simulator.manual_reroll_selected(state, rngs, [0]):
		push_error("Manual reroll with equipment setup failed.")
		return false
	if state.rerolls_left != 2:
		push_error("Lucky Knuckle should make the first reroll free.")
		return false

	var item_state := CombatStateScript.new(factory.create_npc("cyan_ryder"), factory.create_enemy("boss_vanguard"))
	var item_logger := ActionLoggerScript.new()
	simulator.initialize_equipment_for_battle(item_state, [_instance(catalog, "emergency_battery")], item_logger)
	if not simulator.can_use_active_item(item_state):
		push_error("Emergency Battery active item should be usable at battle start.")
		return false
	var active := simulator.use_active_item(item_state, item_logger)
	if not bool(active.get("ok", false)):
		push_error("Emergency Battery active item failed.")
		return false
	if item_state.player.resource.current_value < 2:
		push_error("Emergency Battery should grant 2 resource when intact.")
		return false
	if simulator.can_use_active_item(item_state):
		push_error("Active item should not be reusable in the same battle.")
		return false
	return _test_equipment_never_adds_usable_dice(loader, catalog)

func _test_damaged_equipment_is_weaker(loader: ContentLoaderScript, catalog: CombatCatalogScript) -> bool:
	var factory := UnitFactoryScript.new(loader)
	var simulator := BattleSimulatorScript.new(catalog, loader.find_row_by_id("enemies", "boss_vanguard"))
	var intact_state := CombatStateScript.new(factory.create_npc("cyan_ryder"), factory.create_enemy("boss_vanguard"))
	var damaged_state := CombatStateScript.new(factory.create_npc("cyan_ryder"), factory.create_enemy("boss_vanguard"))
	simulator.initialize_equipment_for_battle(intact_state, [_instance(catalog, "field_jacket")], ActionLoggerScript.new())
	simulator.initialize_equipment_for_battle(damaged_state, [_instance(catalog, "field_jacket", "damaged")], ActionLoggerScript.new())
	if damaged_state.player.block >= intact_state.player.block:
		push_error("Damaged Field Jacket must grant less block than intact Field Jacket.")
		return false

	var intact_item_state := CombatStateScript.new(factory.create_npc("cyan_ryder"), factory.create_enemy("boss_vanguard"))
	var damaged_item_state := CombatStateScript.new(factory.create_npc("cyan_ryder"), factory.create_enemy("boss_vanguard"))
	simulator.initialize_equipment_for_battle(intact_item_state, [_instance(catalog, "emergency_battery")], ActionLoggerScript.new())
	simulator.initialize_equipment_for_battle(damaged_item_state, [_instance(catalog, "emergency_battery", "damaged")], ActionLoggerScript.new())
	simulator.use_active_item(intact_item_state, ActionLoggerScript.new())
	simulator.use_active_item(damaged_item_state, ActionLoggerScript.new())
	if damaged_item_state.player.resource.current_value >= intact_item_state.player.resource.current_value:
		push_error("Damaged Emergency Battery must grant less resource than intact Emergency Battery.")
		return false
	return true

func _test_equipment_never_adds_usable_dice(loader: ContentLoaderScript, catalog: CombatCatalogScript) -> bool:
	var factory := UnitFactoryScript.new(loader)
	var state := CombatStateScript.new(factory.create_npc("cyan_ryder"), factory.create_enemy("boss_vanguard"))
	var logger := ActionLoggerScript.new()
	var simulator := BattleSimulatorScript.new(catalog, loader.find_row_by_id("enemies", "boss_vanguard"))
	var rngs := RngStreamsScript.new(SeedBundleScript.new(4567))
	simulator.initialize_equipment_for_battle(state, [
		_instance(catalog, "lucky_knuckle"),
		_instance(catalog, "risk_ledger"),
		_instance(catalog, "emergency_battery")
	], logger)
	simulator.start_manual_player_turn(state, rngs, logger)
	if state.rolled_faces.size() != 3 or state.picks_budget != 3:
		push_error("Equipment setup must still roll exactly 3 usable dice.")
		return false
	simulator.use_active_item(state, logger)
	var actions := 0
	while simulator.can_player_act(state):
		if not simulator.apply_manual_face_pick_at(state, rngs, logger, 0):
			push_error("Failed to consume a die during equipment dice economy test.")
			return false
		actions += 1
		if actions > 3:
			push_error("Equipment allowed more than 3 dice actions in a turn.")
			return false
	return actions == 3 and state.picks_used == 3 and state.rolled_faces.is_empty()

func _reward(catalog: CombatCatalogScript, equipment_id: String) -> Dictionary:
	var equipment := catalog.equipment_by_id(equipment_id)
	return {
		"reward_id": "test_eq_" + equipment_id,
		"type": "equipment",
		"value": equipment_id,
		"rarity": String(equipment.get("rarity", "common")),
		"equipment": equipment
	}

func _first_instance_for_slot(hub: HubStateScript, slot: String) -> String:
	for item_any in hub.equipment_storage:
		var item: Dictionary = item_any
		if String(item.get("equip_slot", "")) == slot:
			return String(item.get("equipment_instance_id", ""))
	return ""

func _instance(catalog: CombatCatalogScript, equipment_id: String, damage_state: String = "intact") -> Dictionary:
	var equipment := catalog.equipment_by_id(equipment_id)
	return {
		"equipment_instance_id": "test_" + equipment_id,
		"equipment_id": equipment_id,
		"display_name": String(equipment.get("display_name", equipment_id)),
		"equip_slot": String(equipment.get("equip_slot", "")),
		"item_mode": String(equipment.get("item_mode", "none")),
		"rarity": String(equipment.get("rarity", "common")),
		"tags": String(equipment.get("tags", "")),
		"damage_state": damage_state,
		"origin": "home",
		"definition": equipment
	}
