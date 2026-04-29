class_name ArtAssetTest
extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const ArtCatalogScript = preload("res://scripts/content/art_catalog.gd")

func run() -> bool:
	var loader := ContentLoaderScript.new()
	var catalog := ArtCatalogScript.new(loader)
	for table in ["npcs", "enemies"]:
		for row_any in loader.load_rows(table):
			var row: Dictionary = row_any
			for field in ["portrait_id", "battle_sprite_id"]:
				var art_id := String(row.get(field, ""))
				if art_id == "":
					push_error("%s row missing %s: %s" % [table, field, String(row.get("id", ""))])
					return false
				if catalog.art_by_id(art_id).is_empty():
					push_error("Missing art asset '%s' referenced by %s:%s" % [art_id, table, String(row.get("id", ""))])
					return false
	for required in ["bg_hub", "bg_run", "bg_battle", "node_battle", "node_event", "node_supply", "node_shop", "node_rest", "node_boss"]:
		if catalog.art_by_id(required).is_empty():
			push_error("Missing required UI art placeholder: " + required)
			return false
	return true

