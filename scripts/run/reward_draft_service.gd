class_name RewardDraftService
extends RefCounted

const CombatCatalogScript = preload("res://scripts/content/combat_catalog.gd")
const RngStreamsScript = preload("res://scripts/core/rng_streams.gd")
const RunProgressStateScript = preload("res://scripts/run/run_progress_state.gd")

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
	if reward_type == "currency":
		return row.duplicate()
	return {}

func _reward_title(reward: Dictionary) -> String:
	var reward_type := str(reward.get("type", ""))
	if reward_type == "currency":
		return "补给箱"
	var growth: Dictionary = reward.get("growth", {})
	var scope := str(growth.get("duration_scope", "battle"))
	return "强化模块（%s）" % ("本场" if scope == "battle" else "本次 Run")

func _reward_description(reward: Dictionary) -> String:
	var reward_type := str(reward.get("type", ""))
	if reward_type == "currency":
		return "获得 %d Credits，用于后续经济或局外验证。" % int(reward.get("value", "0"))
	var growth: Dictionary = reward.get("growth", {})
	return _growth_description(growth)

func _scope_label(reward: Dictionary) -> String:
	var reward_type := str(reward.get("type", ""))
	if reward_type == "currency":
		return "立即收益"
	var growth: Dictionary = reward.get("growth", {})
	var scope := str(growth.get("duration_scope", "battle"))
	return "下一场" if scope == "battle" else "本次 Run"

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
	var scope_text := "本场生效" if scope == "battle" else "本次 Run 生效"
	if growth_type == "combat" and target == "temp_ranged_flat":
		return "远程伤害 +%d，%s。" % [delta, scope_text]
	if growth_type == "stat" and target == "base_hp":
		return "最大生命 +%d，%s。" % [delta, scope_text]
	if growth_type == "stat" and target == "block":
		return "开场护甲 +%d，%s。" % [delta, scope_text]
	if growth_type == "resource" and target == "resource_cap":
		return "资源上限 +%d，%s。" % [delta, scope_text]
	var delta_text := ("+" if delta >= 0 else "") + str(delta)
	return "成长 %s:%s %s，%s。" % [growth_type, target, delta_text, scope_text]
