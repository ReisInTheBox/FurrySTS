extends RefCounted

const BattleVisualizerScript = preload("res://scripts/app/battle_visualizer.gd")
const DiceFaceDefinitionScript = preload("res://scripts/combat/dice_face_definition.gd")
const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const CombatCatalogScript = preload("res://scripts/content/combat_catalog.gd")

func run() -> bool:
	var visualizer := BattleVisualizerScript.new()
	visualizer._build_ui()
	visualizer._start_manual_battle()

	if visualizer._state == null:
		push_error("Battle visualizer failed to initialize state.")
		return false

	var pickable: Array = visualizer._simulator.get_manual_pickable_faces(visualizer._state)
	if pickable.is_empty():
		push_error("Battle visualizer produced no pickable faces at start.")
		return false

	var first_face: DiceFaceDefinitionScript = pickable[0]
	visualizer._set_card_help(first_face)
	visualizer._on_card_pressed(0)
	visualizer._on_reroll_mode_toggled()
	visualizer._on_card_pressed(0)
	visualizer._on_reroll_pressed()
	visualizer._on_end_turn_pressed()

	var shift_face: Variant = visualizer._find_face_by_id("cyan_shift")
	if shift_face != null:
		visualizer._set_card_help(shift_face)

	visualizer._state.enemy.hp = 0
	visualizer._render_ui()
	if visualizer._pending_rewards.is_empty():
		push_error("Battle visualizer failed to draft post-battle rewards.")
		return false
	visualizer._on_reward_selected(0)
	if not visualizer._reward_claimed_this_battle:
		push_error("Battle visualizer failed to claim selected reward.")
		return false

	visualizer.free()
	if not _test_active_item_button():
		return false
	return true

func _test_active_item_button() -> bool:
	var loader := ContentLoaderScript.new()
	var catalog := CombatCatalogScript.new(loader)
	var visualizer := BattleVisualizerScript.new()
	visualizer._build_ui()
	visualizer._equipment_instances = [_instance(catalog, "emergency_battery")]
	visualizer._start_manual_battle()
	visualizer._render_ui()
	if visualizer._active_item_btn == null or not visualizer._active_item_btn.visible or visualizer._active_item_btn.disabled:
		push_error("Active item button should be visible and enabled when an active item is equipped.")
		return false
	visualizer._on_active_item_pressed()
	if not visualizer._active_item_btn.disabled:
		push_error("Active item button should disable after one use.")
		return false
	visualizer.free()
	return true

func _instance(catalog: CombatCatalogScript, equipment_id: String) -> Dictionary:
	var equipment := catalog.equipment_by_id(equipment_id)
	return {
		"equipment_instance_id": "ui_" + equipment_id,
		"equipment_id": equipment_id,
		"display_name": String(equipment.get("display_name", equipment_id)),
		"equip_slot": String(equipment.get("equip_slot", "")),
		"item_mode": String(equipment.get("item_mode", "none")),
		"damage_state": "intact",
		"definition": equipment
	}
