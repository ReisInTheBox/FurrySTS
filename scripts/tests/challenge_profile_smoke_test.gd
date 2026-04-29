class_name ChallengeProfileSmokeTest
extends RefCounted

const SeedBundleScript = preload("res://scripts/core/seed_bundle.gd")
const RngStreamsScript = preload("res://scripts/core/rng_streams.gd")
const ActionLoggerScript = preload("res://scripts/core/action_logger.gd")
const CombatStateScript = preload("res://scripts/combat/combat_state.gd")
const BattleSimulatorScript = preload("res://scripts/combat/battle_simulator.gd")
const UnitFactoryScript = preload("res://scripts/content/unit_factory.gd")
const CombatCatalogScript = preload("res://scripts/content/combat_catalog.gd")

const SAMPLE_COUNT := 24

func run(loader, heroes: Array) -> bool:
	if not _check_intent_design_rows(loader):
		return false
	return _run_challenge_matrix(loader, heroes)

func _check_intent_design_rows(loader) -> bool:
	var rows := loader.load_rows("enemy_intents")
	var tags_by_enemy: Dictionary = {}
	var status_by_enemy: Dictionary = {}
	var pressure_types := {}
	for row_any in rows:
		var row: Dictionary = row_any
		var enemy_id := String(row.get("enemy_id", ""))
		if enemy_id == "":
			continue
		if not tags_by_enemy.has(enemy_id):
			tags_by_enemy[enemy_id] = {}
		if not status_by_enemy.has(enemy_id):
			status_by_enemy[enemy_id] = {}
		var tag := String(row.get("counter_tag", ""))
		if tag != "":
			var tag_map: Dictionary = tags_by_enemy[enemy_id]
			tag_map[tag] = true
			tags_by_enemy[enemy_id] = tag_map
		var status := String(row.get("status_type", ""))
		if status != "":
			var status_map: Dictionary = status_by_enemy[enemy_id]
			status_map[status] = true
			status_by_enemy[enemy_id] = status_map
			pressure_types[status] = true

	for enemy_any in loader.load_rows("enemies"):
		var enemy: Dictionary = enemy_any
		var enemy_id := String(enemy.get("id", ""))
		var tag_count := Dictionary(tags_by_enemy.get(enemy_id, {})).keys().size()
		var status_count := Dictionary(status_by_enemy.get(enemy_id, {})).keys().size()
		if tag_count < 2:
			push_error("Enemy should target at least two build/resource axes: " + enemy_id)
			return false
		if status_count < 1:
			push_error("Enemy should have at least one resource pressure status: " + enemy_id)
			return false

	for required in ["drain_resource", "tax_reroll", "lock_die", "shed_mark", "disable_summon"]:
		if not pressure_types.has(required):
			push_error("Missing enemy pressure type: " + required)
			return false
	return true

func _run_challenge_matrix(loader, heroes: Array) -> bool:
	var all_ok := true
	var enemies := loader.load_rows("enemies")
	for enemy_index in range(enemies.size()):
		var enemy: Dictionary = enemies[enemy_index]
		var enemy_id := String(enemy.get("id", ""))
		for hero_index in range(heroes.size()):
			var hero := String(heroes[hero_index])
			var wins := 0
			var turn_total := 0
			var caps := 0
			var debuffs := 0
			for i in range(SAMPLE_COUNT):
				var result := _simulate_once(930000 + enemy_index * 1000 + hero_index * 100 + i, hero, enemy_id, loader)
				if String(result.get("winner", "")) == hero:
					wins += 1
				turn_total += int(result.get("turns", 0))
				if bool(result.get("ended_by_cap", false)):
					caps += 1
				debuffs += int(result.get("enemy_debuffs", 0))
			var win_rate := float(wins) / float(SAMPLE_COUNT)
			var avg_turns := float(turn_total) / float(SAMPLE_COUNT)
			print("[SMOKE][CHALLENGE] enemy=", enemy_id, " hero=", hero, " win_rate=", win_rate, " avg_turns=", avg_turns, " debuffs=", debuffs)
			if caps > 0:
				push_error("Challenge matrix hit turn cap for " + enemy_id + " vs " + hero)
				all_ok = false
			if avg_turns < 3.0 or avg_turns > 24.0:
				push_error("Challenge pacing out of smoke bounds for " + enemy_id + " vs " + hero + ": " + str(avg_turns))
				all_ok = false
			if debuffs <= 0:
				push_error("Enemy pressure never appeared in sample: " + enemy_id + " vs " + hero)
				all_ok = false
	return all_ok

func _simulate_once(seed_value: int, hero_id: String, enemy_id: String, loader) -> Dictionary:
	var bundle := SeedBundleScript.new(seed_value)
	var rngs := RngStreamsScript.new(bundle)
	var logger := ActionLoggerScript.new()
	var factory := UnitFactoryScript.new(loader)
	var catalog := CombatCatalogScript.new(loader)
	var enemy_row := loader.find_row_by_id("enemies", enemy_id)
	var state := CombatStateScript.new(factory.create_npc(hero_id), factory.create_enemy(enemy_id))
	var simulator := BattleSimulatorScript.new(catalog, enemy_row)
	var result := simulator.run(state, rngs, logger)
	var debuffs := 0
	for entry_any in logger.entries():
		var entry = entry_any
		if String(entry.event_type) == "enemy_debuff":
			debuffs += 1
	result["enemy_debuffs"] = debuffs
	return result
