class_name TurnStateMachine
extends RefCounted

const PHASE_PLAYER_START := "player_start"
const PHASE_PLAYER_ACTION := "player_action"
const PHASE_ENEMY_ACTION := "enemy_action"
const PHASE_TURN_END := "turn_end"

var _phase_order: Array[String] = [
	PHASE_PLAYER_START,
	PHASE_PLAYER_ACTION,
	PHASE_ENEMY_ACTION,
	PHASE_TURN_END
]
var _phase_index: int = 0

func reset_for_new_turn() -> void:
	_phase_index = 0

func current_phase() -> String:
	return _phase_order[_phase_index]

func advance() -> bool:
	_phase_index += 1
	return _phase_index < _phase_order.size()
