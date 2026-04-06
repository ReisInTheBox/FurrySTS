class_name CombatCatalog
extends RefCounted

const ContentLoader = preload("res://scripts/content/content_loader.gd")
const DiceFaceDefinition = preload("res://scripts/combat/dice_face_definition.gd")

var _loader: ContentLoader
var _dice_by_owner: Dictionary = {}
var _effects_by_bundle: Dictionary = {}

func _init(loader: ContentLoader) -> void:
    _loader = loader
    _build_cache()

func _build_cache() -> void:
    _dice_by_owner.clear()
    _effects_by_bundle.clear()

    var dice_rows := _loader.load_rows("dice")
    for row in dice_rows:
        var face := DiceFaceDefinition.new(row)
        if not _dice_by_owner.has(face.owner_id):
            _dice_by_owner[face.owner_id] = []
        var arr: Array = _dice_by_owner[face.owner_id]
        arr.append(face)
        _dice_by_owner[face.owner_id] = arr

    var effect_rows := _loader.load_rows("status_effects")
    for row in effect_rows:
        var bundle := String(row.get("bundle_id", ""))
        if bundle == "":
            continue
        if not _effects_by_bundle.has(bundle):
            _effects_by_bundle[bundle] = []
        var items: Array = _effects_by_bundle[bundle]
        items.append(row)
        _effects_by_bundle[bundle] = items

func dice_for_owner(owner_id: String) -> Array[DiceFaceDefinition]:
    if not _dice_by_owner.has(owner_id):
        return []
    var src: Array = _dice_by_owner[owner_id]
    var out: Array[DiceFaceDefinition] = []
    for item in src:
        out.append(item)
    return out

func effects_for_bundle(bundle_id: String) -> Array[Dictionary]:
    if not _effects_by_bundle.has(bundle_id):
        return []
    var src: Array = _effects_by_bundle[bundle_id]
    var out: Array[Dictionary] = []
    for item in src:
        if typeof(item) == TYPE_DICTIONARY:
            out.append(item)
    return out
