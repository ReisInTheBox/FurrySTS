class_name UnitFactory
extends RefCounted

const CombatUnitScript = preload("res://scripts/combat/combat_unit.gd")
const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")

var _loader: ContentLoaderScript

func _init(loader: ContentLoaderScript) -> void:
    _loader = loader

func create_npc(unit_id: String, loadout_face_ids: Array[String] = []) -> CombatUnitScript:
    var row := _loader.find_row_by_id("npcs", unit_id)
    if row.is_empty():
        push_error("NPC row not found: " + unit_id)
        return CombatUnitScript.new(unit_id, 1)
    var hp := int(row.get("base_hp", "1"))
    var resource_type := String(row.get("resource_type", "none"))
    var resource_init := int(row.get("resource_init", "0"))
    var resource_cap := int(row.get("resource_cap", "0"))
    var unit := CombatUnitScript.new(unit_id, hp, 0, resource_type, resource_init, resource_cap)
    unit.power_mul = float(row.get("base_power_mul", "1.0"))
    if loadout_face_ids.is_empty():
        for die_any in String(row.get("starting_dice_loadout", row.get("dice_pool", ""))).split("|", false):
            var die_id := String(die_any).strip_edges()
            if die_id != "":
                unit.loadout_die_ids.append(die_id)
    else:
        for face_id_any in loadout_face_ids:
            var face_id := String(face_id_any).strip_edges()
            if face_id != "":
                unit.loadout_face_ids.append(face_id)
                unit.loadout_die_ids.append(face_id)
    return unit

func create_enemy(unit_id: String) -> CombatUnitScript:
    var row := _loader.find_row_by_id("enemies", unit_id)
    if row.is_empty():
        push_error("Enemy row not found: " + unit_id)
        return CombatUnitScript.new(unit_id, 1)
    var hp := int(row.get("base_hp", "1"))
    return CombatUnitScript.new(unit_id, hp)
