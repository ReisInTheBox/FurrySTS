class_name CombatUnit
extends RefCounted

const CombatResourceStateScript = preload("res://scripts/combat/combat_resource_state.gd")

var unit_id: String
var hp: int
var max_hp: int
var block: int
var power_mul: float = 1.0
var resource: CombatResourceStateScript
var marks: int = 0
var rupture_bonus: int = 0
var temp_ranged_flat: int = 0
var pending_lock_faces: int = 0
var next_attack_mult: float = 1.0
var next_attack_ignore_block: int = 0
var thorns_value: int = 0
var overclock_charges: int = 0
var focus_stacks: int = 0
var loadout_face_ids: Array[String] = []

func _init(
    p_unit_id: String,
    p_hp: int,
    p_block: int = 0,
    resource_type: String = "none",
    resource_init: int = 0,
    resource_cap: int = 0
) -> void:
    unit_id = p_unit_id
    hp = p_hp
    max_hp = p_hp
    block = p_block
    resource = CombatResourceStateScript.new(resource_type, resource_init, resource_cap)

func is_alive() -> bool:
    return hp > 0

func apply_damage(raw_value: int, ignore_block: int = 0) -> Dictionary:
    var incoming: int = max(raw_value, 0)
    var effective_block: int = max(0, block - max(ignore_block, 0))
    var blocked: int = min(effective_block, incoming)
    block -= blocked
    var final_damage: int = incoming - blocked
    hp = max(0, hp - final_damage)
    return {"blocked": blocked, "damage": final_damage, "ignore_block": ignore_block}

func apply_heal(value: int) -> int:
    var heal_value: int = max(value, 0)
    var before: int = hp
    hp = min(max_hp, hp + heal_value)
    return hp - before

func add_block(value: int) -> int:
    var gain: int = max(value, 0)
    block += gain
    return gain

func set_mark(value: int) -> void:
    marks = max(0, value)

func add_mark(value: int) -> int:
    marks = max(0, marks + value)
    return marks

func consume_mark_on_hit() -> int:
    if marks <= 0:
        return 0
    marks -= 1
    return 1

func consume_all_marks() -> int:
    var out := marks
    marks = 0
    return out
