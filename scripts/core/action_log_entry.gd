class_name ActionLogEntry
extends RefCounted

var event_type: String
var turn_index: int
var actor_id: String
var target_id: String
var payload: Dictionary

func _init(
    p_event_type: String,
    p_turn_index: int,
    p_actor_id: String,
    p_target_id: String,
    p_payload: Dictionary
) -> void:
    event_type = p_event_type
    turn_index = p_turn_index
    actor_id = p_actor_id
    target_id = p_target_id
    payload = p_payload

func to_dict() -> Dictionary:
    return {
        "event_type": event_type,
        "turn_index": turn_index,
        "actor_id": actor_id,
        "target_id": target_id,
        "payload": payload
    }
