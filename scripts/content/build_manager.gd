class_name BuildManager
extends RefCounted

func merge_loadout(base_face_ids: Array[String], temp_face_ids: Array[String], max_size: int) -> Array[String]:
	var merged: Array[String] = []
	for face_id in base_face_ids:
		if not merged.has(face_id):
			merged.append(face_id)
	for face_id in temp_face_ids:
		if not merged.has(face_id):
			merged.append(face_id)
		if merged.size() >= max_size:
			break
	if merged.size() > max_size:
		merged.resize(max_size)
	return merged

func validate_loadout(face_ids: Array[String], max_size: int) -> Dictionary:
	if face_ids.is_empty():
		return {"ok": false, "reason": "empty_loadout"}
	if face_ids.size() > max_size:
		return {"ok": false, "reason": "over_capacity"}
	var seen: Dictionary = {}
	for face_id in face_ids:
		if seen.has(face_id):
			return {"ok": false, "reason": "duplicate_face"}
		seen[face_id] = true
	return {"ok": true, "reason": ""}
