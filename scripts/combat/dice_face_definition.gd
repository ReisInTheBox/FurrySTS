class_name DiceFaceDefinition
extends RefCounted

var owner_id: String
var die_id: String
var face_index: int
var face_id: String
var effect_bundle_id: String
var cost_type: String
var cost_value: int
var die_type: String
var risk_grade: String
var is_negative: bool
var upgrade_group: String
var upgrade_a_id: String
var upgrade_b_id: String
var tags: Array[String] = []

func _init(row: Dictionary) -> void:
    owner_id = String(row.get("owner_id", ""))
    die_id = String(row.get("die_id", ""))
    face_index = int(row.get("face_index", "0"))
    face_id = String(row.get("face_id", ""))
    effect_bundle_id = String(row.get("effect_bundle_id", ""))
    cost_type = String(row.get("cost_type", "none"))
    cost_value = int(row.get("cost_value", "0"))
    die_type = String(row.get("die_type", "standard"))
    risk_grade = String(row.get("risk_grade", "stable"))
    is_negative = String(row.get("is_negative", "false")).to_lower() == "true"
    upgrade_group = String(row.get("upgrade_group", ""))
    upgrade_a_id = String(row.get("upgrade_a_id", ""))
    upgrade_b_id = String(row.get("upgrade_b_id", ""))
    if die_id == "":
        die_id = face_id
    if face_index <= 0:
        face_index = 1
    var raw_tags := String(row.get("tags", ""))
    tags = []
    for token in raw_tags.split("|", false):
        var clean := token.strip_edges()
        if clean != "":
            tags.append(clean)

func has_tag(tag: String) -> bool:
    return tags.has(tag)
