class_name ArtCatalog
extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")

var _loader: ContentLoaderScript
var _assets_by_id: Dictionary = {}

func _init(loader: ContentLoaderScript) -> void:
	_loader = loader
	_build_cache()

func _build_cache() -> void:
	_assets_by_id.clear()
	for row_any in _loader.load_rows("art_assets"):
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any
		var art_id := String(row.get("art_id", ""))
		if art_id == "":
			continue
		_assets_by_id[art_id] = row

func art_by_id(art_id: String) -> Dictionary:
	if _assets_by_id.has(art_id):
		return Dictionary(_assets_by_id[art_id]).duplicate(true)
	return {}
