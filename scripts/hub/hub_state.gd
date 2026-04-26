class_name HubState
extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const BuildManagerScript = preload("res://scripts/content/build_manager.gd")
const RelationshipStateScript = preload("res://scripts/story/relationship_state.gd")
const RelationshipServiceScript = preload("res://scripts/story/relationship_service.gd")

const DEFAULT_LOADOUT_SIZE := 3
const MIN_LOADOUT_SIZE := 2
const DEFAULT_EQUIPMENT_STORAGE_CAPACITY := 8
const MAX_EQUIPMENT_STORAGE_CAPACITY := 24
const EQUIPMENT_SLOTS := ["weapon", "armor", "item"]

const FALLBACK_UPGRADE_DEFS := {
	"hp_boost": {
		"title": "舰体强化",
		"description": "本英雄最大生命 +2",
		"base_cost": 18,
		"cost_step": 8,
		"max_level": 3,
		"growth": {"type": "stat", "target": "base_hp", "delta": "2", "duration_scope": "run", "grant_once": "false"}
	},
	"guard_boost": {
		"title": "护甲预载",
		"description": "本英雄开场护甲 +2",
		"base_cost": 14,
		"cost_step": 8,
		"max_level": 3,
		"growth": {"type": "stat", "target": "block", "delta": "2", "duration_scope": "run", "grant_once": "false"}
	},
	"resource_cap": {
		"title": "资源上限",
		"description": "本英雄资源上限 +1",
		"base_cost": 24,
		"cost_step": 10,
		"max_level": 2,
		"growth": {"type": "resource", "target": "resource_cap", "delta": "1", "duration_scope": "run", "grant_once": "false"}
	}
}

var banked_credits: int = 0
var run_count: int = 0
var completed_runs: int = 0
var evacuated_runs: int = 0
var failed_runs: int = 0
var selected_hero_id: String = "cyan_ryder"
var last_run_result: Dictionary = {}
var available_heroes: Array[String] = ["cyan_ryder", "helios_windchaser", "umbral_draxx"]
var hero_all_faces: Dictionary = {}
var hero_loadouts: Dictionary = {}
var hero_upgrade_levels: Dictionary = {}
var upgrade_defs: Dictionary = {}
var equipment_storage: Array[Dictionary] = []
var equipment_storage_capacity: int = DEFAULT_EQUIPMENT_STORAGE_CAPACITY
var hero_equipment_loadouts: Dictionary = {}
var repair_materials: int = 0
var relationship_state: RelationshipStateScript = RelationshipStateScript.new()
var relationship_events: Array[Dictionary] = []

var _content_ready: bool = false
var _loader: ContentLoaderScript
var _build_manager: BuildManagerScript = BuildManagerScript.new()
var _relationship_service: RelationshipServiceScript

func ensure_content(loader: ContentLoaderScript) -> void:
	_loader = loader
	if _content_ready:
		return
	_load_upgrade_defs(loader)
	_relationship_service = RelationshipServiceScript.new(loader)
	var npc_rows := loader.load_rows("npcs")
	for row_any in npc_rows:
		var row: Dictionary = row_any
		var hero_id := String(row.get("id", ""))
		if hero_id == "":
			continue
		if not available_heroes.has(hero_id):
			available_heroes.append(hero_id)
		var all_faces: Array[String] = []
		for face_any in String(row.get("starting_dice_loadout", row.get("dice_pool", ""))).split("|", false):
			var face_id := String(face_any).strip_edges()
			if face_id != "":
				all_faces.append(face_id)
		hero_all_faces[hero_id] = all_faces
		var default_loadout: Array[String] = []
		for i in range(mini(DEFAULT_LOADOUT_SIZE, all_faces.size())):
			default_loadout.append(all_faces[i])
		hero_loadouts[hero_id] = default_loadout
		hero_upgrade_levels[hero_id] = _blank_upgrade_levels()
		if not hero_equipment_loadouts.has(hero_id):
			hero_equipment_loadouts[hero_id] = _blank_equipment_slots()
	if not available_heroes.is_empty() and not available_heroes.has(selected_hero_id):
		selected_hero_id = available_heroes[0]
	_ensure_starter_equipment()
	_content_ready = true

func apply_run_result(result: Dictionary) -> void:
	run_count += 1
	last_run_result = result.duplicate(true)
	banked_credits += int(result.get("credits", 0))
	match String(result.get("result_type", "")):
		"completed":
			completed_runs += 1
		"evacuated":
			evacuated_runs += 1
		"failed":
			failed_runs += 1
	_process_equipment_result(result)
	_process_relationship_result(result)

func select_hero(hero_id: String) -> void:
	if available_heroes.has(hero_id):
		selected_hero_id = hero_id

func selected_loadout() -> Array[String]:
	return loadout_for_hero(selected_hero_id)

func loadout_for_hero(hero_id: String) -> Array[String]:
	var out: Array[String] = []
	for face_any in hero_loadouts.get(hero_id, []):
		out.append(String(face_any))
	return out

func reserve_faces_for_hero(hero_id: String) -> Array[String]:
	var loadout := loadout_for_hero(hero_id)
	var out: Array[String] = []
	for face_any in hero_all_faces.get(hero_id, []):
		var face_id := String(face_any)
		if not loadout.has(face_id):
			out.append(face_id)
	return out

func selected_die_loadout() -> Array[String]:
	return selected_loadout()

func reserve_dice_for_hero(hero_id: String) -> Array[String]:
	return reserve_faces_for_hero(hero_id)

func toggle_die_in_selected_loadout(die_id: String) -> Dictionary:
	return toggle_face_in_selected_loadout(die_id)

func toggle_face_in_selected_loadout(face_id: String) -> Dictionary:
	var hero_id := selected_hero_id
	var loadout := loadout_for_hero(hero_id)
	if loadout.has(face_id):
		if loadout.size() <= MIN_LOADOUT_SIZE:
			return {"ok": false, "reason": "min_loadout_size"}
		loadout.erase(face_id)
	else:
		if loadout.size() >= DEFAULT_LOADOUT_SIZE:
			return {"ok": false, "reason": "loadout_full"}
		if not Array(hero_all_faces.get(hero_id, [])).has(face_id):
			return {"ok": false, "reason": "face_not_owned"}
		loadout.append(face_id)

	var validation := _build_manager.validate_loadout(loadout, DEFAULT_LOADOUT_SIZE)
	if not bool(validation.get("ok", false)):
		return validation
	hero_loadouts[hero_id] = loadout
	return {"ok": true, "loadout": loadout}

func die_summary(hero_id: String, die_id: String) -> Dictionary:
	var faces := die_face_rows(hero_id, die_id)
	var tags: Dictionary = {}
	var types: Dictionary = {}
	var negative_count := 0
	for row in faces:
		var die_type := String(row.get("die_type", "")).strip_edges()
		if die_type != "":
			types[die_type] = true
		for tag_any in String(row.get("tags", "")).split("|", false):
			var tag := String(tag_any).strip_edges()
			if tag != "":
				tags[tag] = true
		if String(row.get("is_negative", "false")).to_lower() == "true":
			negative_count += 1
	return {
		"die_id": die_id,
		"face_count": faces.size(),
		"negative_count": negative_count,
		"types": types.keys(),
		"tags": tags.keys()
	}

func die_detail_lines(hero_id: String, die_id: String) -> Array[String]:
	var out: Array[String] = []
	var rows := die_face_rows(hero_id, die_id)
	if rows.is_empty():
		out.append("未找到骰子数据：" + die_id)
		return out
	var summary := die_summary(hero_id, die_id)
	out.append("%s：%d 面，负面 %d，类型 %s" % [
		die_display_name(die_id),
		int(summary.get("face_count", 0)),
		int(summary.get("negative_count", 0)),
		", ".join(PackedStringArray(summary.get("types", [])))
	])
	for row in rows:
		var tags := String(row.get("tags", "")).replace("|", "/")
		out.append("%s. %s [%s]" % [
			String(row.get("face_index", "?")),
			face_display_name(String(row.get("face_id", ""))),
			tags
		])
	return out

func die_face_rows(hero_id: String, die_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _loader == null:
		return out
	for row_any in _loader.load_rows("dice"):
		var row: Dictionary = row_any
		if String(row.get("owner_id", "")) == hero_id and String(row.get("die_id", "")) == die_id:
			out.append(row)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("face_index", "0")) < int(b.get("face_index", "0"))
	)
	return out

func die_display_name(die_id: String) -> String:
	var names := {
		"cyan_pulse_die": "脉冲骰",
		"cyan_shift_die": "跃迁骰",
		"cyan_core_die": "核心骰",
		"helios_hunt_die": "狩猎骰",
		"helios_mark_die": "标记骰",
		"helios_wild_die": "乱射骰",
		"aurian_blade_die": "黑刃骰",
		"aurian_guard_die": "铁壁骰",
		"aurian_might_die": "重斩骰"
	}
	if names.has(die_id):
		return names[die_id]
	return die_id

func face_display_name(face_id: String) -> String:
	var names := {
		"cyan_beam_a": "光束射击 A",
		"cyan_beam_b": "光束射击 B",
		"cyan_shift": "空间跃迁",
		"cyan_burst": "异能爆发",
		"cyan_pulse": "脉冲校准",
		"cyan_cooldown": "冷却循环",
		"cyan_arcflare": "电弧闪击",
		"cyan_vent": "过载泄放",
		"helios_mark": "校准标记",
		"helios_sniper": "鹰眼射击",
		"helios_swoop": "低空掠过",
		"helios_recover": "箭矢回收",
		"helios_pierce": "穿透射击",
		"helios_hunt": "追猎步伐",
		"helios_trap": "追踪陷阱",
		"helios_volley": "连发齐射",
		"black_sweep": "大剑横扫",
		"black_charge": "蓄力",
		"black_shock": "震荡",
		"black_guard": "铁壁",
		"black_execute": "断罪重斩",
		"black_pose": "处决姿态",
		"black_parry": "偏斜格挡",
		"black_reap": "终结收割"
	}
	if names.has(face_id):
		return names[face_id]
	return face_id


func persistent_growths_for_hero(hero_id: String) -> Array[Dictionary]:
	var growths: Array[Dictionary] = []
	var levels: Dictionary = hero_upgrade_levels.get(hero_id, _blank_upgrade_levels())
	for upgrade_id_any in upgrade_defs.keys():
		var upgrade_id := String(upgrade_id_any)
		var level := int(levels.get(upgrade_id, 0))
		for i in range(level):
			var base_growth: Dictionary = upgrade_defs[upgrade_id]["growth"].duplicate()
			if String(base_growth.get("type", "")) == "equipment":
				continue
			base_growth["growth_id"] = "hub_%s_%s_%d" % [hero_id, upgrade_id, i]
			growths.append(base_growth)
	for relationship_growth in relationship_growths_for_hero(hero_id):
		growths.append(relationship_growth)
	return growths

func relationship_growths_for_hero(hero_id: String) -> Array[Dictionary]:
	if _relationship_service == null:
		return []
	return _relationship_service.reward_growths_for_hero(relationship_state, hero_id)

func relationship_summary_lines() -> Array[String]:
	var out: Array[String] = []
	if _relationship_service == null:
		out.append("Relationship system is not ready.")
		return out
	for line in _relationship_service.summary_lines(relationship_state, available_heroes):
		out.append(_localize_relationship_line(line))
	if not relationship_events.is_empty():
		out.append("Latest story event:")
		for event in relationship_events:
			out.append("- %s / %s" % [String(event.get("title", "Relationship")), String(event.get("reward_title", "Reward"))])
	return out

func upgrade_levels_for_hero(hero_id: String) -> Dictionary:
	return hero_upgrade_levels.get(hero_id, _blank_upgrade_levels()).duplicate()

func upgrade_offer_list(hero_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var levels := upgrade_levels_for_hero(hero_id)
	for upgrade_id_any in upgrade_defs.keys():
		var upgrade_id := String(upgrade_id_any)
		var def: Dictionary = upgrade_defs[upgrade_id]
		var level := int(levels.get(upgrade_id, 0))
		out.append({
			"upgrade_id": upgrade_id,
			"title": String(def.get("title", upgrade_id)),
			"description": String(def.get("description", "")),
			"level": level,
			"next_cost": upgrade_cost(upgrade_id, level),
			"max_level": int(def.get("max_level", 1)),
			"can_buy": can_purchase_upgrade(hero_id, upgrade_id)
		})
	return out

func can_purchase_upgrade(hero_id: String, upgrade_id: String) -> bool:
	if not upgrade_defs.has(upgrade_id):
		return false
	var level := int(upgrade_levels_for_hero(hero_id).get(upgrade_id, 0))
	var max_level := int(upgrade_defs[upgrade_id].get("max_level", 1))
	if level >= max_level:
		return false
	return banked_credits >= upgrade_cost(upgrade_id, level)

func purchase_upgrade(hero_id: String, upgrade_id: String) -> Dictionary:
	if not upgrade_defs.has(upgrade_id):
		return {"ok": false, "reason": "unknown_upgrade"}
	var levels := upgrade_levels_for_hero(hero_id)
	var level := int(levels.get(upgrade_id, 0))
	var max_level := int(upgrade_defs[upgrade_id].get("max_level", 1))
	if level >= max_level:
		return {"ok": false, "reason": "max_level"}
	var cost := upgrade_cost(upgrade_id, level)
	if banked_credits < cost:
		return {"ok": false, "reason": "insufficient_credits"}
	banked_credits -= cost
	levels[upgrade_id] = level + 1
	hero_upgrade_levels[hero_id] = levels
	var def: Dictionary = upgrade_defs[upgrade_id]
	var growth: Dictionary = def.get("growth", {})
	if String(growth.get("type", "")) == "equipment" and String(growth.get("target", "")) == "storage_capacity":
		equipment_storage_capacity = mini(MAX_EQUIPMENT_STORAGE_CAPACITY, equipment_storage_capacity + int(growth.get("delta", "0")))
	return {"ok": true, "cost": cost, "new_level": level + 1}

func upgrade_cost(upgrade_id: String, current_level: int) -> int:
	if not upgrade_defs.has(upgrade_id):
		return 9999
	var def: Dictionary = upgrade_defs[upgrade_id]
	return int(def.get("base_cost", 10)) + (current_level * int(def.get("cost_step", 8)))

func run_setup_for_selected_hero() -> Dictionary:
	return {
		"loadout_face_ids": selected_loadout(),
		"persistent_growths": persistent_growths_for_hero(selected_hero_id),
		"equipment_instances": selected_equipment_instances()
	}

func selected_equipment_instances() -> Array[Dictionary]:
	return equipment_instances_for_hero(selected_hero_id)

func equipment_instances_for_hero(hero_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var slots: Dictionary = hero_equipment_loadouts.get(hero_id, _blank_equipment_slots())
	for slot in EQUIPMENT_SLOTS:
		var instance_id := String(slots.get(slot, ""))
		if instance_id == "":
			continue
		var instance := equipment_instance_by_id(instance_id)
		if not instance.is_empty() and String(instance.get("damage_state", "intact")) != "broken":
			out.append(instance)
	return out

func equipment_instance_by_id(instance_id: String) -> Dictionary:
	for item_any in equipment_storage:
		var item: Dictionary = item_any
		if String(item.get("equipment_instance_id", "")) == instance_id:
			return item.duplicate(true)
	return {}

func equipment_loadout_for_hero(hero_id: String) -> Dictionary:
	return hero_equipment_loadouts.get(hero_id, _blank_equipment_slots()).duplicate(true)

func equip_storage_instance(hero_id: String, instance_id: String) -> Dictionary:
	var instance := equipment_instance_by_id(instance_id)
	if instance.is_empty():
		return {"ok": false, "reason": "unknown_equipment_instance"}
	if String(instance.get("damage_state", "intact")) == "broken":
		return {"ok": false, "reason": "broken_equipment"}
	var slot := String(instance.get("equip_slot", ""))
	if not EQUIPMENT_SLOTS.has(slot):
		return {"ok": false, "reason": "invalid_equip_slot", "equip_slot": slot}
	for other_hero_any in hero_equipment_loadouts.keys():
		var other_hero := String(other_hero_any)
		var other_slots: Dictionary = hero_equipment_loadouts.get(other_hero, _blank_equipment_slots())
		for equip_slot in EQUIPMENT_SLOTS:
			if String(other_slots.get(equip_slot, "")) == instance_id:
				other_slots[equip_slot] = ""
		hero_equipment_loadouts[other_hero] = other_slots
	var slots: Dictionary = hero_equipment_loadouts.get(hero_id, _blank_equipment_slots())
	slots[slot] = instance_id
	hero_equipment_loadouts[hero_id] = slots
	return {"ok": true, "hero_id": hero_id, "equip_slot": slot, "equipment_instance_id": instance_id}

func unequip_slot(hero_id: String, slot: String) -> Dictionary:
	if not EQUIPMENT_SLOTS.has(slot):
		return {"ok": false, "reason": "invalid_equip_slot"}
	var slots: Dictionary = hero_equipment_loadouts.get(hero_id, _blank_equipment_slots())
	slots[slot] = ""
	hero_equipment_loadouts[hero_id] = slots
	return {"ok": true, "hero_id": hero_id, "equip_slot": slot}

func equipment_storage_lines() -> Array[String]:
	var out: Array[String] = []
	out.append("Storage %d/%d | Repair materials %d" % [equipment_storage.size(), equipment_storage_capacity, repair_materials])
	for item_any in equipment_storage:
		var item: Dictionary = item_any
		out.append("%s | %s | %s | returns %d" % [
			String(item.get("equip_slot", "")),
			String(item.get("display_name", item.get("equipment_id", ""))),
			String(item.get("damage_state", "intact")),
			int(item.get("return_count", 0))
		])
	return out

func _process_equipment_result(result: Dictionary) -> void:
	var returning: Array = result.get("extracted_equipment_instances", [])
	for item_any in returning:
		if typeof(item_any) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_any.duplicate(true)
		_return_equipment_to_storage(item)
	_trim_storage_overflow()

func _return_equipment_to_storage(item: Dictionary) -> void:
	var instance_id := String(item.get("equipment_instance_id", ""))
	if instance_id == "":
		return
	item["origin"] = "home"
	item["return_count"] = int(item.get("return_count", 0)) + 1
	item = _apply_return_damage(item)
	var replaced := false
	for i in range(equipment_storage.size()):
		var existing: Dictionary = equipment_storage[i]
		if String(existing.get("equipment_instance_id", "")) == instance_id:
			equipment_storage[i] = item
			replaced = true
			break
	if not replaced:
		equipment_storage.append(item)

func _apply_return_damage(item: Dictionary) -> Dictionary:
	var return_count := int(item.get("return_count", 0))
	var chance := _damage_chance_for_return_count(return_count)
	if chance <= 0:
		return item
	var instance_id := String(item.get("equipment_instance_id", ""))
	var roll: int = abs((instance_id + ":" + str(return_count)).hash()) % 100
	if roll >= chance:
		return item
	var state := String(item.get("damage_state", "intact"))
	if state == "intact":
		item["damage_state"] = "damaged"
	elif state == "damaged":
		item["damage_state"] = "broken"
	return item

func _damage_chance_for_return_count(return_count: int) -> int:
	if return_count < 2:
		return 0
	if return_count == 2:
		return 25
	if return_count == 3:
		return 40
	return 55

func _trim_storage_overflow() -> void:
	while equipment_storage.size() > equipment_storage_capacity:
		var remove_index := _lowest_storage_priority_index()
		var removed: Dictionary = equipment_storage[remove_index]
		_clear_equipped_instance(String(removed.get("equipment_instance_id", "")))
		equipment_storage.remove_at(remove_index)
		repair_materials += 1

func _lowest_storage_priority_index() -> int:
	var best_index := 0
	var best_score := 9999
	for i in range(equipment_storage.size()):
		var item: Dictionary = equipment_storage[i]
		var score := _storage_priority_score(item)
		if score < best_score:
			best_score = score
			best_index = i
	return best_index

func _storage_priority_score(item: Dictionary) -> int:
	var score := 0
	match String(item.get("rarity", "common")):
		"rare":
			score += 30
		"uncommon":
			score += 20
		_:
			score += 10
	match String(item.get("damage_state", "intact")):
		"broken":
			score -= 20
		"damaged":
			score -= 10
	score += max(0, 8 - int(item.get("return_count", 0)))
	return score

func _clear_equipped_instance(instance_id: String) -> void:
	if instance_id == "":
		return
	for hero_id_any in hero_equipment_loadouts.keys():
		var hero_id := String(hero_id_any)
		var slots: Dictionary = hero_equipment_loadouts.get(hero_id, _blank_equipment_slots())
		for slot in EQUIPMENT_SLOTS:
			if String(slots.get(slot, "")) == instance_id:
				slots[slot] = ""
		hero_equipment_loadouts[hero_id] = slots

func _ensure_starter_equipment() -> void:
	if _loader == null or not equipment_storage.is_empty():
		return
	for equipment_id in ["pulse_carbine", "field_jacket", "lucky_knuckle"]:
		var row := _find_equipment_row(equipment_id)
		if not row.is_empty():
			equipment_storage.append(_make_home_equipment_instance(row))

func _find_equipment_row(equipment_id: String) -> Dictionary:
	if _loader == null:
		return {}
	for row_any in _loader.load_rows("equipment"):
		var row: Dictionary = row_any
		if String(row.get("equipment_id", "")) == equipment_id:
			return row
	return {}

func _make_home_equipment_instance(equipment: Dictionary) -> Dictionary:
	return {
		"equipment_instance_id": "home_%s_%03d" % [String(equipment.get("equipment_id", "equipment")), equipment_storage.size() + 1],
		"equipment_id": String(equipment.get("equipment_id", "")),
		"display_name": String(equipment.get("display_name", equipment.get("equipment_id", ""))),
		"equip_slot": String(equipment.get("equip_slot", "")),
		"item_mode": String(equipment.get("item_mode", "none")),
		"rarity": String(equipment.get("rarity", "common")),
		"tags": String(equipment.get("tags", "")),
		"effect_bundle_id": String(equipment.get("effect_bundle_id", "")),
		"damaged_effect_bundle_id": String(equipment.get("damaged_effect_bundle_id", "")),
		"origin_run_id": "starter",
		"return_count": 0,
		"damage_state": "intact",
		"times_equipped": 0,
		"source_node_uid": "hub_starter",
		"created_at_layer": 0,
		"origin": "home",
		"definition": equipment.duplicate(true)
	}

func _blank_equipment_slots() -> Dictionary:
	return {"weapon": "", "armor": "", "item": ""}

func last_run_summary() -> String:
	if last_run_result.is_empty():
		return "还没有完成过任何一局 Run。"
	return "上次结果：%s | 清理节点 %d | 带回 Credits %d | 获得成长 %d 项" % [
		String(last_run_result.get("result_type", "unknown")),
		int(last_run_result.get("nodes_cleared", 0)),
		int(last_run_result.get("credits", 0)),
		int(last_run_result.get("growth_count", 0))
	]

func last_run_detail_lines() -> Array[String]:
	var out: Array[String] = []
	if last_run_result.is_empty():
		out.append("暂无结算记录。")
		return out
	out.append(String(last_run_result.get("summary", "")))
	for item_any in last_run_result.get("node_results", []):
		var item: Dictionary = item_any
		out.append("%s / %s / %s" % [
			String(item.get("node_type", "")),
			String(item.get("node_id", "")),
			String(item.get("result", ""))
		])
	return out

func _process_relationship_result(result: Dictionary) -> void:
	relationship_events.clear()
	if _relationship_service == null:
		return
	relationship_events = _relationship_service.process_run_result(relationship_state, _relationship_hub_stats(), result)

func _relationship_hub_stats() -> Dictionary:
	return {
		"run_count": run_count,
		"completed_runs": completed_runs,
		"evacuated_runs": evacuated_runs,
		"failed_runs": failed_runs
	}

func _localize_relationship_line(line: String) -> String:
	return line.replace("umbral_draxx", "Aurian")

func _load_upgrade_defs(loader: ContentLoaderScript) -> void:
	upgrade_defs = {}
	for row_any in loader.load_rows("outgame_growth"):
		var row: Dictionary = row_any
		var upgrade_id := String(row.get("id", "")).strip_edges()
		if upgrade_id == "":
			continue
		upgrade_defs[upgrade_id] = {
			"title": String(row.get("title", upgrade_id)),
			"description": String(row.get("description", "")),
			"base_cost": int(row.get("base_cost", "10")),
			"cost_step": int(row.get("cost_step", "8")),
			"max_level": int(row.get("max_level", "1")),
			"growth": {
				"type": String(row.get("growth_type", "stat")),
				"target": String(row.get("growth_target", "base_hp")),
				"delta": String(row.get("growth_delta", "0")),
				"duration_scope": String(row.get("duration_scope", "run")),
				"grant_once": String(row.get("grant_once", "false"))
			}
		}
	if upgrade_defs.is_empty():
		upgrade_defs = FALLBACK_UPGRADE_DEFS.duplicate(true)

func _blank_upgrade_levels() -> Dictionary:
	var out: Dictionary = {}
	var defs := upgrade_defs if not upgrade_defs.is_empty() else FALLBACK_UPGRADE_DEFS
	for upgrade_id_any in defs.keys():
		out[String(upgrade_id_any)] = 0
	return out
