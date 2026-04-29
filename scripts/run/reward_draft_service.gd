class_name RewardDraftService
extends RefCounted

const CombatCatalogScript = preload("res://scripts/content/combat_catalog.gd")
const RngStreamsScript = preload("res://scripts/core/rng_streams.gd")
const RunProgressStateScript = preload("res://scripts/run/run_progress_state.gd")

const BUILD_REWARD_TYPES := ["add_die", "replace_die", "remove_negative", "upgrade_die"]
const ENCHANT_REWARD_TYPES := ["grant_enchant", "replace_enchant", "remove_enchant"]

func draft_rewards(
	catalog: CombatCatalogScript,
	rngs: RngStreamsScript,
	choice_count: int = 3
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = catalog.rewards()
	return _draft_from_rows(pool, catalog, rngs, choice_count)

func draft_rewards_from_ids(
	catalog: CombatCatalogScript,
	rngs: RngStreamsScript,
	reward_ids: Array[String],
	choice_count: int = 3
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for reward_id in reward_ids:
		var row := catalog.reward_by_id(reward_id)
		if not row.is_empty():
			pool.append(row)
	return _draft_from_rows(pool, catalog, rngs, choice_count)

func _draft_from_rows(
	pool: Array[Dictionary],
	catalog: CombatCatalogScript,
	rngs: RngStreamsScript,
	choice_count: int
) -> Array[Dictionary]:
	if pool.is_empty():
		return []

	var candidates: Array[Dictionary] = []
	for row in pool:
		var expanded: Dictionary = _expand_reward_row(row, catalog)
		if expanded.is_empty():
			continue
		expanded["title"] = _reward_title(expanded)
		expanded["description"] = _reward_description(expanded)
		expanded["rarity_label"] = _rarity_label(str(expanded.get("rarity", "common")))
		expanded["scope_label"] = _scope_label(expanded)
		var bd_tags := _bd_tags(expanded)
		expanded["bd_tags"] = bd_tags
		expanded["bd_label"] = _bd_label(bd_tags)
		candidates.append(expanded)

	if candidates.is_empty():
		return []

	var chosen: Array[Dictionary] = []
	var used_ids: Dictionary = {}
	var max_count: int = mini(choice_count, candidates.size())
	while chosen.size() < max_count:
		var weighted_total: int = 0
		for item in candidates:
			var reward_id := str(item.get("reward_id", ""))
			if used_ids.has(reward_id):
				continue
			weighted_total += max(1, int(item.get("weight", "1")))
		if weighted_total <= 0:
			break

		var roll: int = rngs.ai_pick(weighted_total)
		var cursor: int = 0
		for item in candidates:
			var reward_id := str(item.get("reward_id", ""))
			if used_ids.has(reward_id):
				continue
			cursor += max(1, int(item.get("weight", "1")))
			if roll < cursor:
				chosen.append(item)
				used_ids[reward_id] = true
				break

	return chosen

func apply_reward(run_state: RunProgressStateScript, reward: Dictionary) -> Dictionary:
	var reward_type := str(reward.get("type", ""))
	var reward_id := str(reward.get("reward_id", ""))
	match reward_type:
		"growth":
			var growth: Dictionary = reward.get("growth", {})
			if growth.is_empty():
				return {"ok": false, "reason": "missing_growth"}
			run_state.add_growth(growth)
			return {"ok": true, "reward_id": reward_id, "kind": "growth", "growth_id": str(growth.get("growth_id", ""))}
		"currency":
			var amount := int(reward.get("value", "0"))
			var total := run_state.add_currency("credits", amount)
			return {"ok": true, "reward_id": reward_id, "kind": "currency", "amount": amount, "total": total}
		"add_die", "replace_die", "remove_negative", "upgrade_die":
			var change := _build_change_from_reward(reward)
			if change.is_empty():
				return {"ok": false, "reason": "missing_build_change"}
			run_state.add_build_change(change)
			return {"ok": true, "reward_id": reward_id, "kind": reward_type, "change": change}
		"grant_enchant", "replace_enchant", "remove_enchant":
			var enchant_change := _enchant_change_from_reward(reward)
			if enchant_change.is_empty():
				return {"ok": false, "reason": "missing_enchant_change"}
			match reward_type:
				"grant_enchant":
					var grant_result := run_state.grant_enchant(enchant_change)
					grant_result["reward_id"] = reward_id
					grant_result["kind"] = reward_type
					return grant_result
				"replace_enchant":
					var replace_result := run_state.replace_enchant(enchant_change)
					replace_result["reward_id"] = reward_id
					replace_result["kind"] = reward_type
					return replace_result
				"remove_enchant":
					var remove_result := run_state.remove_enchant(String(enchant_change.get("die_id", "")), int(enchant_change.get("face_index", "0")))
					remove_result["reward_id"] = reward_id
					remove_result["kind"] = reward_type
					return remove_result
				_:
					return {"ok": false, "reason": "unsupported_enchant_reward_type", "reward_type": reward_type}
		"equipment":
			return {"ok": true, "reward_id": reward_id, "kind": "equipment_preview", "equipment_id": String(reward.get("value", ""))}
		_:
			return {"ok": false, "reason": "unsupported_reward_type", "reward_type": reward_type}

func _expand_reward_row(row: Dictionary, catalog: CombatCatalogScript) -> Dictionary:
	var reward_type := str(row.get("type", ""))
	if reward_type == "growth":
		var growth_id := str(row.get("value", ""))
		var growth := catalog.growth_by_id(growth_id)
		if growth.is_empty():
			return {}
		var out := row.duplicate()
		out["growth"] = growth
		return out
	if reward_type == "equipment":
		var equipment_id := str(row.get("value", ""))
		var equipment := catalog.equipment_by_id(equipment_id)
		if equipment.is_empty():
			return {}
		var out := row.duplicate()
		out["equipment"] = equipment
		out["equip_slot"] = String(equipment.get("equip_slot", ""))
		out["item_mode"] = String(equipment.get("item_mode", "none"))
		return out
	if ENCHANT_REWARD_TYPES.has(reward_type):
		var change := _enchant_change_from_reward(row)
		if change.is_empty():
			return {}
		if reward_type != "remove_enchant" and catalog.enchantment_by_id(String(change.get("enchant_id", ""))).is_empty():
			return {}
		var out := row.duplicate()
		if change.has("enchant_id"):
			out["enchantment"] = catalog.enchantment_by_id(String(change.get("enchant_id", "")))
		out["enchant_change"] = change
		return out
	if reward_type == "currency" or BUILD_REWARD_TYPES.has(reward_type):
		return row.duplicate()
	return {}

func _reward_title(reward: Dictionary) -> String:
	var reward_type := str(reward.get("type", ""))
	if BUILD_REWARD_TYPES.has(reward_type):
		return String(reward.get("title", reward.get("reward_id", "Dice reward")))
	if reward_type == "equipment":
		var equipment: Dictionary = reward.get("equipment", {})
		return String(reward.get("title", equipment.get("display_name", "Equipment")))
	if ENCHANT_REWARD_TYPES.has(reward_type):
		var enchantment: Dictionary = reward.get("enchantment", {})
		return String(reward.get("title", enchantment.get("name", "Enchant")))
	if reward_type == "currency":
		return "补给缓存"
	var growth: Dictionary = reward.get("growth", {})
	var scope := str(growth.get("duration_scope", "battle"))
	return "强化模块（%s）" % ("下一场" if scope == "battle" else "本 Run")

func _reward_description(reward: Dictionary) -> String:
	var reward_type := str(reward.get("type", ""))
	if BUILD_REWARD_TYPES.has(reward_type):
		return String(reward.get("description", reward.get("value", "")))
	if reward_type == "equipment":
		var equipment: Dictionary = reward.get("equipment", {})
		var slot := String(equipment.get("equip_slot", "equipment"))
		var mode := String(equipment.get("item_mode", "none"))
		var mode_text := "" if mode == "none" else " / " + mode
		return "[%s%s] %s" % [slot, mode_text, String(reward.get("description", equipment.get("description", "")))]
	if ENCHANT_REWARD_TYPES.has(reward_type):
		var change: Dictionary = reward.get("enchant_change", {})
		var enchantment: Dictionary = reward.get("enchantment", {})
		var name := String(enchantment.get("name", change.get("enchant_id", "Enchant")))
		if reward_type == "remove_enchant":
			return "移除 %s 第 %d 面的附魔。" % [String(change.get("die_id", "")), int(change.get("face_index", 0))]
		return "%s -> %s 第 %d 面。%s" % [
			name,
			String(change.get("die_id", "")),
			int(change.get("face_index", 0)),
			String(reward.get("description", ""))
		]
	if reward_type == "currency":
		return "获得 %d Credits。" % int(reward.get("value", "0"))
	var growth: Dictionary = reward.get("growth", {})
	return _growth_description(growth)

func _scope_label(reward: Dictionary) -> String:
	var reward_type := str(reward.get("type", ""))
	if BUILD_REWARD_TYPES.has(reward_type):
		return "Run 构筑"
	if reward_type == "equipment":
		var equipment: Dictionary = reward.get("equipment", {})
		return "装备：" + String(equipment.get("equip_slot", "slot"))
	if ENCHANT_REWARD_TYPES.has(reward_type):
		return "附魔"
	if reward_type == "currency":
		return "立即"
	var growth: Dictionary = reward.get("growth", {})
	var scope := str(growth.get("duration_scope", "battle"))
	return "下一场" if scope == "battle" else "本 Run"

func _rarity_label(rarity: String) -> String:
	match rarity:
		"rare":
			return "稀有"
		"uncommon":
			return "优秀"
		_:
			return "普通"

func _growth_description(growth: Dictionary) -> String:
	var growth_type := str(growth.get("type", ""))
	var target := str(growth.get("target", ""))
	var delta := int(growth.get("delta", "0"))
	var scope := str(growth.get("duration_scope", "battle"))
	var scope_text := "场战斗" if scope == "battle" else " Run"
	if growth_type == "combat" and target == "temp_ranged_flat":
		return "本%s远程伤害 +%d。" % [scope_text, delta]
	if growth_type == "stat" and target == "base_hp":
		return "本%s最大 HP +%d。" % [scope_text, delta]
	if growth_type == "stat" and target == "block":
		return "本%s开局护甲 +%d。" % [scope_text, delta]
	if growth_type == "resource" and target == "resource_cap":
		return "本%s资源上限 +%d。" % [scope_text, delta]
	var delta_text := ("+" if delta >= 0 else "") + str(delta)
	return "成长 %s:%s %s，作用于本%s。" % [growth_type, target, delta_text, scope_text]

func _bd_tags(reward: Dictionary) -> Array[String]:
	var haystack := _reward_search_text(reward)
	var out: Array[String] = []
	if _has_any(haystack, ["cyan", "overload", "pulse", "core", "multi_hit", "overheat", "tech"]):
		_add_unique(out, "Cyan:反应炉爆发")
	if _has_any(haystack, ["shift", "cooldown", "vent", "reroll", "stable"]):
		_add_unique(out, "Cyan:棱镜控制")
	if _has_any(haystack, ["drone", "summon", "tech"]):
		_add_unique(out, "Cyan:无人机火线")
	if _has_any(haystack, ["helios", "mark", "scope", "precision", "pierce", "quiver"]):
		_add_unique(out, "Helios:标记处决")
	if _has_any(haystack, ["hunt", "wild", "reroll", "stable", "field_jacket"]):
		_add_unique(out, "Helios:游击循环")
	if _has_any(haystack, ["companion", "whistle", "summon"]):
		_add_unique(out, "Helios:伙伴猎杀")
	if _has_any(haystack, ["aurian", "guard", "block", "counter", "banner", "spiked", "stance"]):
		_add_unique(out, "Aurian:铁壁反击")
	if _has_any(haystack, ["blade", "might", "execute", "finisher", "throwing", "rupture"]):
		_add_unique(out, "Aurian:誓约处决")
	if _has_any(haystack, ["blood", "self_damage", "negative", "risk", "whetstone"]):
		_add_unique(out, "Aurian:血价狂战")
	if out.is_empty():
		if String(reward.get("type", "")) == "currency":
			out.append("通用:经济")
		elif String(reward.get("type", "")) == "growth":
			out.append("通用:安全垫")
		elif ENCHANT_REWARD_TYPES.has(String(reward.get("type", ""))):
			out.append("通用:附魔构筑")
		else:
			out.append("通用:构筑修正")
	return out

func _bd_label(tags: Array[String]) -> String:
	if tags.is_empty():
		return ""
	return " / ".join(PackedStringArray(tags))

func _reward_search_text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["reward_id", "type", "value", "title", "description"]:
		parts.append(String(reward.get(key, "")))
	if reward.has("equipment"):
		var equipment: Dictionary = reward.get("equipment", {})
		for key in ["equipment_id", "display_name", "tags", "description"]:
			parts.append(String(equipment.get(key, "")))
	if reward.has("enchantment"):
		var enchantment: Dictionary = reward.get("enchantment", {})
		for key in ["enchant_id", "name", "op_type", "tags"]:
			parts.append(String(enchantment.get(key, "")))
	if reward.has("growth"):
		var growth: Dictionary = reward.get("growth", {})
		for key in ["growth_id", "type", "target"]:
			parts.append(String(growth.get(key, "")))
	return " ".join(parts).to_lower()

func _has_any(text: String, needles: Array) -> bool:
	for needle_any in needles:
		if text.find(String(needle_any).to_lower()) >= 0:
			return true
	return false

func _add_unique(out: Array[String], value: String) -> void:
	if not out.has(value):
		out.append(value)

func _build_change_from_reward(reward: Dictionary) -> Dictionary:
	var reward_type := String(reward.get("type", ""))
	var value := String(reward.get("value", ""))
	var parts := value.split(":", true)
	match reward_type:
		"add_die":
			if value == "":
				return {}
			return {"change_type": "add_die", "die_id": value}
		"replace_die":
			if parts.size() < 2:
				return {}
			return {"change_type": "replace_die", "from_die_id": parts[0], "to_die_id": parts[1]}
		"remove_negative":
			if parts.size() < 2:
				return {}
			return {"change_type": "remove_negative", "die_id": parts[0], "fallback_die_id": parts[1]}
		"upgrade_die":
			if parts.size() < 2:
				return {}
			return {"change_type": "upgrade_die", "base_die_id": parts[0], "upgraded_die_id": parts[1]}
	return {}

func _enchant_change_from_reward(reward: Dictionary) -> Dictionary:
	var reward_type := String(reward.get("type", ""))
	var value := String(reward.get("value", ""))
	var parts := value.split(":", false)
	match reward_type:
		"grant_enchant", "replace_enchant":
			if parts.size() < 3:
				return {}
			return {
				"die_id": parts[0],
				"face_index": int(parts[1]),
				"enchant_id": parts[2],
				"source": String(reward.get("reward_id", "reward")),
				"grant_run_id": "current_run"
			}
		"remove_enchant":
			if parts.size() < 2:
				return {}
			return {
				"die_id": parts[0],
				"face_index": int(parts[1])
			}
	return {}
