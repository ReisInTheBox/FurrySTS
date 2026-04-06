class_name UnitFactory
extends RefCounted

const CombatUnit = preload("res://scripts/combat/combat_unit.gd")
const ContentLoader = preload("res://scripts/content/content_loader.gd")

var _loader: ContentLoader

func _init(loader: ContentLoader) -> void:
    _loader = loader

func create_npc(unit_id: String) -> CombatUnit:
    var row := _loader.find_row_by_id("npcs", unit_id)
    if row.is_empty():
        push_error("NPC row not found: " + unit_id)
        return CombatUnit.new(unit_id, 1)
    var hp := int(row.get("base_hp", "1"))
    var resource_type := String(row.get("resource_type", "none"))
    var resource_init := int(row.get("resource_init", "0"))
    var resource_cap := int(row.get("resource_cap", "0"))
    var unit := CombatUnit.new(unit_id, hp, 0, resource_type, resource_init, resource_cap)
    unit.power_mul = float(row.get("base_power_mul", "1.0"))
    return unit

func create_enemy(unit_id: String) -> CombatUnit:
    var row := _loader.find_row_by_id("enemies", unit_id)
    if row.is_empty():
        push_error("Enemy row not found: " + unit_id)
        return CombatUnit.new(unit_id, 1)
    var hp := int(row.get("base_hp", "1"))
    return CombatUnit.new(unit_id, hp)
