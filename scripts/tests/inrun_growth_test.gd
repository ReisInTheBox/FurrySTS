class_name InrunGrowthTest
extends RefCounted

const RunProgressStateScript = preload("res://scripts/run/run_progress_state.gd")
const CombatUnitScript = preload("res://scripts/combat/combat_unit.gd")

func run() -> bool:
	return _test_growth_scopes() and _test_grant_once()

func _test_growth_scopes() -> bool:
	var unit := CombatUnitScript.new("helios_windchaser", 24, 0, "quiver", 2, 3)
	var state := RunProgressStateScript.new()
	state.add_growth({"growth_id": "g1", "type": "combat", "target": "temp_ranged_flat", "delta": "2", "duration_scope": "battle", "grant_once": "false"})
	state.add_growth({"growth_id": "g2", "type": "resource", "target": "quiver", "delta": "1", "duration_scope": "run", "grant_once": "true"})
	state.apply_all_to_unit(unit)
	var ok := unit.temp_ranged_flat == 2 and unit.resource.current_value == 3
	state.clear_battle_growths()
	unit.temp_ranged_flat = 0
	state.apply_all_to_unit(unit)
	return ok and unit.temp_ranged_flat == 0 and unit.resource.current_value == 3

func _test_grant_once() -> bool:
	var unit := CombatUnitScript.new("helios_windchaser", 24, 0, "quiver", 1, 3)
	var state := RunProgressStateScript.new()
	var growth := {"growth_id": "g_once", "type": "resource", "target": "quiver", "delta": "1", "duration_scope": "run", "grant_once": "true"}
	state.add_growth(growth)
	state.add_growth(growth)
	state.apply_all_to_unit(unit)
	return state.run_growths.size() == 1 and unit.resource.current_value == 2
