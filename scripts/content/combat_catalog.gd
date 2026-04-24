class_name CombatCatalog
extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const DiceFaceDefinitionScript = preload("res://scripts/combat/dice_face_definition.gd")

var _loader: ContentLoaderScript
var _dice_by_owner: Dictionary = {}
var _effects_by_bundle: Dictionary = {}
var _rewards: Array[Dictionary] = []
var _growths_by_id: Dictionary = {}
var _rewards_by_id: Dictionary = {}

func _init(loader: ContentLoaderScript) -> void:
    _loader = loader
    _build_cache()

func _build_cache() -> void:
    _dice_by_owner.clear()
    _effects_by_bundle.clear()
    _rewards.clear()
    _growths_by_id.clear()
    _rewards_by_id.clear()

    var dice_rows := _loader.load_rows("dice")
    for row in dice_rows:
        var face := DiceFaceDefinitionScript.new(row)
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

    var reward_rows := _loader.load_rows("rewards")
    for row_any in reward_rows:
        if typeof(row_any) == TYPE_DICTIONARY:
            _rewards.append(row_any)
            var reward_id := String(row_any.get("reward_id", ""))
            if reward_id != "":
                _rewards_by_id[reward_id] = row_any

    var growth_rows := _loader.load_rows("inrun_growth")
    for row_any in growth_rows:
        if typeof(row_any) != TYPE_DICTIONARY:
            continue
        var growth_id := String(row_any.get("growth_id", ""))
        if growth_id == "":
            continue
        _growths_by_id[growth_id] = row_any

func dice_for_owner(owner_id: String, allowed_face_ids: Array[String] = []) -> Array[DiceFaceDefinitionScript]:
    if not _dice_by_owner.has(owner_id):
        return []
    var src: Array = _dice_by_owner[owner_id]
    var out: Array[DiceFaceDefinitionScript] = []
    var allow_all := allowed_face_ids.is_empty()
    for item in src:
        var face: DiceFaceDefinitionScript = item
        if allow_all or allowed_face_ids.has(face.face_id):
            out.append(face)
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

func rewards() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for row in _rewards:
        out.append(row)
    return out

func growth_by_id(growth_id: String) -> Dictionary:
    if not _growths_by_id.has(growth_id):
        return {}
    return _growths_by_id[growth_id]

func reward_by_id(reward_id: String) -> Dictionary:
    if not _rewards_by_id.has(reward_id):
        return {}
    return _rewards_by_id[reward_id]

func all_growths() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for growth_id in _growths_by_id.keys():
        var row: Dictionary = _growths_by_id[growth_id]
        out.append(row)
    return out
