class_name RewardDraftFlowTest
extends RefCounted

const SeedBundleScript = preload("res://scripts/core/seed_bundle.gd")
const RngStreamsScript = preload("res://scripts/core/rng_streams.gd")
const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const CombatCatalogScript = preload("res://scripts/content/combat_catalog.gd")
const RunProgressStateScript = preload("res://scripts/run/run_progress_state.gd")
const RewardDraftServiceScript = preload("res://scripts/run/reward_draft_service.gd")
const CombatUnitScript = preload("res://scripts/combat/combat_unit.gd")

func run() -> bool:
	return _test_reward_draft() and _test_growth_application()

func _test_reward_draft() -> bool:
	var loader := ContentLoaderScript.new()
	var catalog := CombatCatalogScript.new(loader)
	var rngs := RngStreamsScript.new(SeedBundleScript.new(20260422))
	var service := RewardDraftServiceScript.new()
	var rewards := service.draft_rewards(catalog, rngs, 3)
	if rewards.size() < 3:
		return false
	for reward_any in rewards:
		var reward: Dictionary = reward_any
		if str(reward.get("title", "")) == "":
			return false
		if str(reward.get("description", "")) == "":
			return false
		if str(reward.get("rarity_label", "")) == "":
			return false
		if str(reward.get("scope_label", "")) == "":
			return false
	return true

func _test_growth_application() -> bool:
	var loader := ContentLoaderScript.new()
	var catalog := CombatCatalogScript.new(loader)
	var service := RewardDraftServiceScript.new()
	var reward := {
		"reward_id": "rw_growth_hull",
		"type": "growth",
		"value": "gr_run_hull_plate",
		"growth": catalog.growth_by_id("gr_run_hull_plate")
	}
	var run_state := RunProgressStateScript.new()
	var result := service.apply_reward(run_state, reward)
	if not bool(result.get("ok", false)):
		return false

	var unit_a := CombatUnitScript.new("cyan_ryder", 22, 0, "overload", 0, 3)
	run_state.apply_all_to_unit(unit_a, true)
	if unit_a.max_hp != 26:
		return false

	var battle_reward := {
		"reward_id": "rw_growth_guard",
		"type": "growth",
		"value": "gr_battle_guard_matrix",
		"growth": catalog.growth_by_id("gr_battle_guard_matrix")
	}
	result = service.apply_reward(run_state, battle_reward)
	if not bool(result.get("ok", false)):
		return false

	var unit_b := CombatUnitScript.new("cyan_ryder", 22, 0, "overload", 0, 3)
	run_state.apply_all_to_unit(unit_b, true)
	if unit_b.block != 3:
		return false

	var unit_c := CombatUnitScript.new("cyan_ryder", 22, 0, "overload", 0, 3)
	run_state.apply_all_to_unit(unit_c, true)
	return unit_c.block == 0 and unit_c.max_hp == 26
