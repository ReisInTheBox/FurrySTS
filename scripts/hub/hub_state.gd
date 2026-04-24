class_name HubState
extends RefCounted

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const BuildManagerScript = preload("res://scripts/content/build_manager.gd")

const DEFAULT_LOADOUT_SIZE := 6
const MIN_LOADOUT_SIZE := 4

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

var _content_ready: bool = false
var _build_manager: BuildManagerScript = BuildManagerScript.new()

func ensure_content(loader: ContentLoaderScript) -> void:
	if _content_ready:
		return
	_load_upgrade_defs(loader)
	var npc_rows := loader.load_rows("npcs")
	for row_any in npc_rows:
		var row: Dictionary = row_any
		var hero_id := String(row.get("id", ""))
		if hero_id == "":
			continue
		if not available_heroes.has(hero_id):
			available_heroes.append(hero_id)
		var all_faces: Array[String] = []
		for face_any in String(row.get("dice_pool", "")).split("|", false):
			var face_id := String(face_any).strip_edges()
			if face_id != "":
				all_faces.append(face_id)
		hero_all_faces[hero_id] = all_faces
		var default_loadout: Array[String] = []
		for i in range(mini(DEFAULT_LOADOUT_SIZE, all_faces.size())):
			default_loadout.append(all_faces[i])
		hero_loadouts[hero_id] = default_loadout
		hero_upgrade_levels[hero_id] = _blank_upgrade_levels()
	if not available_heroes.is_empty() and not available_heroes.has(selected_hero_id):
		selected_hero_id = available_heroes[0]
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

func persistent_growths_for_hero(hero_id: String) -> Array[Dictionary]:
	var growths: Array[Dictionary] = []
	var levels: Dictionary = hero_upgrade_levels.get(hero_id, _blank_upgrade_levels())
	for upgrade_id_any in upgrade_defs.keys():
		var upgrade_id := String(upgrade_id_any)
		var level := int(levels.get(upgrade_id, 0))
		for i in range(level):
			var base_growth: Dictionary = upgrade_defs[upgrade_id]["growth"].duplicate()
			base_growth["growth_id"] = "hub_%s_%s_%d" % [hero_id, upgrade_id, i]
			growths.append(base_growth)
	return growths

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
	return {"ok": true, "cost": cost, "new_level": level + 1}

func upgrade_cost(upgrade_id: String, current_level: int) -> int:
	if not upgrade_defs.has(upgrade_id):
		return 9999
	var def: Dictionary = upgrade_defs[upgrade_id]
	return int(def.get("base_cost", 10)) + (current_level * int(def.get("cost_step", 8)))

func run_setup_for_selected_hero() -> Dictionary:
	return {
		"loadout_face_ids": selected_loadout(),
		"persistent_growths": persistent_growths_for_hero(selected_hero_id)
	}

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
