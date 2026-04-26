class_name D6DataIntegrityTest
extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")

const HEROES := ["cyan_ryder", "helios_windchaser", "umbral_draxx"]

func run() -> bool:
	var loader := ContentLoaderScript.new()
	return _check_starting_loadouts(loader) and _check_each_die_is_d6(loader)

func _check_starting_loadouts(loader: ContentLoaderScript) -> bool:
	for hero_id in HEROES:
		var row := loader.find_row_by_id("npcs", hero_id)
		var dice := String(row.get("starting_dice_loadout", "")).split("|", false)
		if dice.size() != 3:
			push_error("Hero must start with exactly 3 D6: %s has %d" % [hero_id, dice.size()])
			return false
		var seen: Dictionary = {}
		for die_any in dice:
			var die_id := String(die_any).strip_edges()
			if die_id == "" or seen.has(die_id):
				push_error("Hero starting D6 loadout has blank or duplicate die_id: " + hero_id)
				return false
			seen[die_id] = true
	return true

func _check_each_die_is_d6(loader: ContentLoaderScript) -> bool:
	var faces_by_die: Dictionary = {}
	for row_any in loader.load_rows("dice"):
		var row: Dictionary = row_any
		var die_id := String(row.get("die_id", ""))
		if die_id == "":
			push_error("Dice row missing die_id.")
			return false
		if not faces_by_die.has(die_id):
			faces_by_die[die_id] = {}
		var index_map: Dictionary = faces_by_die[die_id]
		var face_index := int(row.get("face_index", "0"))
		if face_index < 1 or face_index > 6:
			push_error("D6 face_index out of range for " + die_id + ": " + str(face_index))
			return false
		if index_map.has(face_index):
			push_error("D6 duplicate face_index for " + die_id + ": " + str(face_index))
			return false
		index_map[face_index] = true
	for die_id_any in faces_by_die.keys():
		var die_id := String(die_id_any)
		var index_map: Dictionary = faces_by_die[die_id]
		if index_map.keys().size() != 6:
			push_error("D6 must have exactly 6 faces: %s has %d" % [die_id, index_map.keys().size()])
			return false
	return true
