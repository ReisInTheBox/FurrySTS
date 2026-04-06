class_name DiceFaceDefinition
extends RefCounted

var owner_id: String
var face_id: String
var effect_bundle_id: String
var cost_type: String
var cost_value: int
var die_type: String
var tags: Array[String] = []

func _init(row: Dictionary) -> void:
    owner_id = String(row.get("owner_id", ""))
    face_id = String(row.get("face_id", ""))
    effect_bundle_id = String(row.get("effect_bundle_id", ""))
    cost_type = String(row.get("cost_type", "none"))
    cost_value = int(row.get("cost_value", "0"))
    die_type = String(row.get("die_type", "standard"))
    var raw_tags := String(row.get("tags", ""))
    tags = []
    for token in raw_tags.split("|", false):
        var clean := token.strip_edges()
        if clean != "":
            tags.append(clean)

func has_tag(tag: String) -> bool:
    return tags.has(tag)
