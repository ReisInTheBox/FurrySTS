class_name CombatRulesTest
extends RefCounted

const SeedBundleScript = preload("res://scripts/core/seed_bundle.gd")
const RngStreamsScript = preload("res://scripts/core/rng_streams.gd")
const TurnStateMachineScript = preload("res://scripts/core/turn_state_machine.gd")
const CombatUnitScript = preload("res://scripts/combat/combat_unit.gd")

func run() -> bool:
	return _test_damage_and_block() and _test_heal_boundaries() and _test_seed_consistency() and _test_turn_phase_order()

func _test_damage_and_block() -> bool:
	var unit := CombatUnitScript.new("test_unit", 20, 5)
	var result := unit.apply_damage(8)
	return int(result["blocked"]) == 5 and int(result["damage"]) == 3 and unit.hp == 17 and unit.block == 0

func _test_heal_boundaries() -> bool:
	var unit := CombatUnitScript.new("test_unit", 20, 0)
	unit.apply_damage(10)
	var healed := unit.apply_heal(99)
	return healed == 10 and unit.hp == 20

func _test_seed_consistency() -> bool:
	var a := RngStreamsScript.new(SeedBundleScript.new(20260408))
	var b := RngStreamsScript.new(SeedBundleScript.new(20260408))
	return a.roll_dice(1, 6) == b.roll_dice(1, 6) and a.ai_pick(3) == b.ai_pick(3) and a.run_pick(4) == b.run_pick(4)

func _test_turn_phase_order() -> bool:
	var fsm := TurnStateMachineScript.new()
	fsm.reset_for_new_turn()
	var phases := [fsm.current_phase()]
	while fsm.advance():
		phases.append(fsm.current_phase())
	return phases == [
		TurnStateMachineScript.PHASE_PLAYER_START,
		TurnStateMachineScript.PHASE_PLAYER_ACTION,
		TurnStateMachineScript.PHASE_ENEMY_ACTION,
		TurnStateMachineScript.PHASE_TURN_END
	]
