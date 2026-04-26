class_name RunBuildRewardTest
extends RefCounted

const RunProgressStateScript = preload("res://scripts/run/run_progress_state.gd")
const RewardDraftServiceScript = preload("res://scripts/run/reward_draft_service.gd")
const CombatUnitScript = preload("res://scripts/combat/combat_unit.gd")

func run() -> bool:
	return (
		_test_add_die()
		and _test_replace_die()
		and _test_remove_negative()
		and _test_upgrade_die()
	)

func _unit_with_loadout(loadout: Array[String]) -> CombatUnitScript:
	var unit := CombatUnitScript.new("cyan_ryder", 22, 0, "overload", 0, 3)
	unit.loadout_die_ids = loadout.duplicate()
	return unit

func _apply_reward(reward_type: String, value: String, initial_loadout: Array[String]) -> Array[String]:
	var service := RewardDraftServiceScript.new()
	var run_state := RunProgressStateScript.new()
	var reward := {
		"reward_id": "test_" + reward_type,
		"type": reward_type,
		"value": value
	}
	var result := service.apply_reward(run_state, reward)
	if not bool(result.get("ok", false)):
		push_error("Reward application failed for " + reward_type + ": " + String(result.get("reason", "unknown")))
		return []
	var unit := _unit_with_loadout(initial_loadout)
	run_state.apply_all_to_unit(unit, true)
	return unit.loadout_die_ids

func _test_add_die() -> bool:
	var initial: Array[String] = ["cyan_pulse_die", "cyan_shift_die", "cyan_core_die"]
	var result := _apply_reward("add_die", "cyan_shift_die", initial)
	return result == ["cyan_pulse_die", "cyan_shift_die", "cyan_core_die", "cyan_shift_die"]

func _test_replace_die() -> bool:
	var initial: Array[String] = ["cyan_pulse_die", "cyan_shift_die", "cyan_core_die"]
	var result := _apply_reward("replace_die", "cyan_core_die:cyan_pulse_die", initial)
	return result == ["cyan_pulse_die", "cyan_shift_die", "cyan_pulse_die"]

func _test_remove_negative() -> bool:
	var initial: Array[String] = ["cyan_pulse_die", "cyan_shift_die", "cyan_core_die"]
	var result := _apply_reward("remove_negative", "cyan_core_die:cyan_pulse_die", initial)
	return result == ["cyan_pulse_die", "cyan_shift_die", "cyan_pulse_die"]

func _test_upgrade_die() -> bool:
	var initial: Array[String] = ["cyan_pulse_die", "cyan_shift_die", "cyan_core_die"]
	var result := _apply_reward("upgrade_die", "cyan_shift_die:cyan_core_die", initial)
	return result == ["cyan_pulse_die", "cyan_core_die", "cyan_core_die"]
