class_name RunState
extends RefCounted

const RunProgressStateScript = preload("res://scripts/run/run_progress_state.gd")
const RunResultScript = preload("res://scripts/run/run_result.gd")

var hero_id: String = "cyan_ryder"
var route_nodes: Array = []
var route_layers: Array = []
var current_node_index: int = 0
var current_node_uid: String = ""
var current_available_uids: Array[String] = []
var selected_path: Array[String] = []
var evac_after_layers: Array[int] = [4, 8, 12]
var cleared_layer_count: int = 0
var pending_reward_choices: Array[Dictionary] = []
var node_results: Array[Dictionary] = []
var progress: RunProgressStateScript = RunProgressStateScript.new()
var completed: bool = false
var result: RunResultScript = RunResultScript.new()
var loadout_face_ids: Array[String] = []
var run_weapon: Dictionary = {}
var run_armor: Dictionary = {}
var run_item: Dictionary = {}
var temporary_equipment_pack: Array[Dictionary] = []
var found_equipment_this_run: Array[Dictionary] = []
var used_active_item_this_battle: bool = false
var equipment_instance_counter: int = 0

func current_node() -> Dictionary:
	if not route_layers.is_empty():
		if current_node_uid != "":
			return find_route_node(current_node_uid)
		if not current_available_uids.is_empty():
			return find_route_node(current_available_uids[0])
		return {}
	if route_nodes.is_empty():
		return {}
	if current_node_index < 0 or current_node_index >= route_nodes.size():
		return {}
	return route_nodes[current_node_index]

func find_route_node(uid: String) -> Dictionary:
	if uid == "":
		return {}
	for layer_any in route_layers:
		var layer: Array = layer_any
		for node_any in layer:
			var node: Dictionary = node_any
			if String(node.get("route_node_uid", "")) == uid:
				return node
	return {}

func is_node_available(uid: String) -> bool:
	return current_available_uids.has(uid)

func select_route_node(uid: String) -> bool:
	if completed or not pending_reward_choices.is_empty():
		return false
	if not is_node_available(uid):
		return false
	current_node_uid = uid
	return true

func nodes_cleared() -> int:
	if not route_layers.is_empty():
		return selected_path.size()
	return node_results.size()

func can_evac() -> bool:
	if completed or not pending_reward_choices.is_empty():
		return false
	if not route_layers.is_empty():
		return evac_after_layers.has(cleared_layer_count)
	var node := current_node()
	if node.is_empty():
		return false
	return String(node.get("allow_evac", "false")) == "true" and current_node_index > 0

func advance_node() -> void:
	if not route_layers.is_empty():
		advance_after_node()
		return
	current_node_index += 1
	if current_node_index >= route_nodes.size():
		_finish_completed("Route completed.")

func advance_after_node() -> void:
	if route_layers.is_empty():
		advance_node()
		return
	var completed_node := current_node()
	if completed_node.is_empty():
		_finish_completed("Route completed.")
		return

	var completed_uid := String(completed_node.get("route_node_uid", current_node_uid))
	if completed_uid != "" and not selected_path.has(completed_uid):
		selected_path.append(completed_uid)
	cleared_layer_count = max(cleared_layer_count, int(completed_node.get("layer_index", cleared_layer_count)))
	current_node_index = cleared_layer_count

	var next_layer_index := cleared_layer_count + 1
	var next_layer := _nodes_for_layer(next_layer_index)
	if next_layer.is_empty():
		current_available_uids.clear()
		current_node_uid = ""
		_finish_completed("Route completed.")
		return

	var next_uids: Array[String] = []
	var outgoing: Array = completed_node.get("outgoing_uids", [])
	for uid_any in outgoing:
		var uid := String(uid_any)
		if _node_is_in_layer(uid, next_layer_index):
			next_uids.append(uid)
	if next_uids.is_empty():
		for node_any in next_layer:
			var node: Dictionary = node_any
			next_uids.append(String(node.get("route_node_uid", "")))

	current_available_uids = next_uids
	current_node_uid = current_available_uids[0] if not current_available_uids.is_empty() else ""

func finish(result_type: String, summary: String) -> void:
	completed = true
	var settlement := _equipment_settlement_for_result(result_type)
	result = RunResultScript.new(
		result_type,
		hero_id,
		nodes_cleared(),
		progress.get_currency("credits"),
		progress.all_growths().size(),
		summary,
		node_results,
		settlement.get("extracted", []),
		settlement.get("lost", [])
	)

func _finish_completed(summary: String) -> void:
	completed = true
	var settlement := _equipment_settlement_for_result("completed")
	result = RunResultScript.new(
		"completed",
		hero_id,
		nodes_cleared(),
		progress.get_currency("credits"),
		progress.all_growths().size(),
		summary,
		node_results,
		settlement.get("extracted", []),
		settlement.get("lost", [])
	)

func _nodes_for_layer(layer_index: int) -> Array:
	for layer_any in route_layers:
		var layer: Array = layer_any
		if layer.is_empty():
			continue
		var first: Dictionary = layer[0]
		if int(first.get("layer_index", 0)) == layer_index:
			return layer
	return []

func _node_is_in_layer(uid: String, layer_index: int) -> bool:
	var node := find_route_node(uid)
	return not node.is_empty() and int(node.get("layer_index", 0)) == layer_index

func configure_starting_equipment(instances: Array) -> void:
	run_weapon.clear()
	run_armor.clear()
	run_item.clear()
	temporary_equipment_pack.clear()
	for item_any in instances:
		if typeof(item_any) != TYPE_DICTIONARY:
			continue
		var instance: Dictionary = item_any.duplicate(true)
		if String(instance.get("damage_state", "intact")) == "broken":
			continue
		instance["origin"] = String(instance.get("origin", "home"))
		var slot := String(instance.get("equip_slot", ""))
		if slot == "":
			var definition: Dictionary = instance.get("definition", {})
			slot = String(definition.get("equip_slot", ""))
			instance["equip_slot"] = slot
		_set_equipment_slot(slot, instance)

func apply_equipment_reward(reward: Dictionary, source_node_uid: String = "") -> Dictionary:
	var equipment: Dictionary = reward.get("equipment", {})
	if equipment.is_empty():
		return {"ok": false, "reason": "missing_equipment"}
	var slot := String(equipment.get("equip_slot", ""))
	if not _valid_equipment_slot(slot):
		return {"ok": false, "reason": "invalid_equip_slot", "equip_slot": slot}
	var instance := _new_equipment_instance(equipment, source_node_uid)
	var replaced := _equipment_in_slot(slot)
	var dropped: Dictionary = {}
	if not replaced.is_empty():
		if String(replaced.get("origin", "run")) == "home":
			temporary_equipment_pack.append(replaced.duplicate(true))
		else:
			dropped = replaced.duplicate(true)
	_set_equipment_slot(slot, instance)
	found_equipment_this_run.append(instance.duplicate(true))
	var out := {
		"ok": true,
		"kind": "equipment",
		"reward_id": String(reward.get("reward_id", "")),
		"equipment_id": String(equipment.get("equipment_id", "")),
		"equip_slot": slot,
		"equipped_instance": instance.duplicate(true)
	}
	if not replaced.is_empty():
		out["replaced_instance"] = replaced.duplicate(true)
	if not dropped.is_empty():
		out["dropped_instance"] = dropped
	return out

func equipment_in_slot(slot: String) -> Dictionary:
	return _equipment_in_slot(slot).duplicate(true)

func equipped_equipment_instances() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in ["weapon", "armor", "item"]:
		var item := _equipment_in_slot(slot)
		if not item.is_empty():
			out.append(item.duplicate(true))
	return out

func equipment_summary_lines() -> Array[String]:
	var out: Array[String] = []
	for slot in ["weapon", "armor", "item"]:
		var item := _equipment_in_slot(slot)
		if item.is_empty():
			out.append("%s: empty" % slot)
		else:
			out.append("%s: %s [%s]" % [
				slot,
				String(item.get("display_name", item.get("equipment_id", ""))),
				String(item.get("damage_state", "intact"))
			])
	return out

func _new_equipment_instance(equipment: Dictionary, source_node_uid: String) -> Dictionary:
	equipment_instance_counter += 1
	return {
		"equipment_instance_id": "run_%s_%03d" % [String(equipment.get("equipment_id", "equipment")), equipment_instance_counter],
		"equipment_id": String(equipment.get("equipment_id", "")),
		"display_name": String(equipment.get("display_name", equipment.get("equipment_id", ""))),
		"equip_slot": String(equipment.get("equip_slot", "")),
		"item_mode": String(equipment.get("item_mode", "none")),
		"rarity": String(equipment.get("rarity", "common")),
		"tags": String(equipment.get("tags", "")),
		"effect_bundle_id": String(equipment.get("effect_bundle_id", "")),
		"damaged_effect_bundle_id": String(equipment.get("damaged_effect_bundle_id", "")),
		"origin_run_id": "current_run",
		"return_count": 0,
		"damage_state": "intact",
		"times_equipped": 1,
		"source_node_uid": source_node_uid,
		"created_at_layer": cleared_layer_count,
		"origin": "run",
		"definition": equipment.duplicate(true)
	}

func _equipment_settlement_for_result(result_type: String) -> Dictionary:
	var extracted: Array[Dictionary] = []
	var lost: Array[Dictionary] = []
	var seen: Dictionary = {}
	for item in equipped_equipment_instances():
		_collect_settlement_item(item, result_type, extracted, lost, seen)
	for item_any in temporary_equipment_pack:
		var item: Dictionary = item_any
		_collect_settlement_item(item, result_type, extracted, lost, seen)
	return {"extracted": extracted, "lost": lost}

func _collect_settlement_item(item: Dictionary, result_type: String, extracted: Array[Dictionary], lost: Array[Dictionary], seen: Dictionary) -> void:
	var instance_id := String(item.get("equipment_instance_id", ""))
	if instance_id != "" and seen.has(instance_id):
		return
	if instance_id != "":
		seen[instance_id] = true
	if result_type == "failed" and String(item.get("origin", "run")) != "home":
		lost.append(item.duplicate(true))
		return
	extracted.append(item.duplicate(true))

func _valid_equipment_slot(slot: String) -> bool:
	return ["weapon", "armor", "item"].has(slot)

func _equipment_in_slot(slot: String) -> Dictionary:
	match slot:
		"weapon":
			return run_weapon
		"armor":
			return run_armor
		"item":
			return run_item
	return {}

func _set_equipment_slot(slot: String, instance: Dictionary) -> void:
	match slot:
		"weapon":
			run_weapon = instance.duplicate(true)
		"armor":
			run_armor = instance.duplicate(true)
		"item":
			run_item = instance.duplicate(true)
