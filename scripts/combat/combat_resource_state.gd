class_name CombatResourceState
extends RefCounted

var resource_type: String = "none"
var current_value: int = 0
var cap_value: int = 0

func _init(p_type: String, p_init: int, p_cap: int) -> void:
    resource_type = p_type
    cap_value = max(0, p_cap)
    current_value = clamp(p_init, 0, cap_value)

func has_type(t: String) -> bool:
    return resource_type == t

func apply_delta(delta: int) -> Dictionary:
    var before: int = current_value
    current_value = clamp(current_value + delta, 0, cap_value)
    return {"before": before, "after": current_value}

func spend(cost: int) -> bool:
    if cost <= 0:
        return true
    if current_value < cost:
        return false
    current_value -= cost
    return true
