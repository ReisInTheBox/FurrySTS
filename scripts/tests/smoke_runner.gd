extends RefCounted

const SeedBundleScript = preload("res://scripts/core/seed_bundle.gd")
const RngStreamsScript = preload("res://scripts/core/rng_streams.gd")
const ActionLoggerScript = preload("res://scripts/core/action_logger.gd")
const CombatStateScript = preload("res://scripts/combat/combat_state.gd")
const BattleSimulatorScript = preload("res://scripts/combat/battle_simulator.gd")
const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const UnitFactoryScript = preload("res://scripts/content/unit_factory.gd")
const CombatCatalogScript = preload("res://scripts/content/combat_catalog.gd")
const CombatRulesTestScript = preload("res://scripts/tests/combat_rules_test.gd")
const BattleFlowTestScript = preload("res://scripts/tests/battle_flow_test.gd")
const BalanceSmokeTestScript = preload("res://scripts/tests/balance_smoke_test.gd")
const MechanicCoverageTestScript = preload("res://scripts/tests/mechanic_coverage_test.gd")
const InrunGrowthTestScript = preload("res://scripts/tests/inrun_growth_test.gd")
const BattleVisualizerUiTestScript = preload("res://scripts/tests/battle_visualizer_ui_test.gd")
const RewardDraftFlowTestScript = preload("res://scripts/tests/reward_draft_flow_test.gd")
const RouteGenerationTestScript = preload("res://scripts/tests/route_generation_test.gd")
const RunProgressionTestScript = preload("res://scripts/tests/run_progression_test.gd")
const EvacuationResultTestScript = preload("res://scripts/tests/evacuation_result_test.gd")
const RunVisualizerUiTestScript = preload("res://scripts/tests/run_visualizer_ui_test.gd")
const HubLoopTestScript = preload("res://scripts/tests/hub_loop_test.gd")

const HEROES := ["cyan_ryder", "helios_windchaser", "umbral_draxx"]
const ENEMY_ID := "boss_vanguard"
const MIN_ENEMY_TEMPLATES := 3
const STRICT_BALANCE_GATE := false

func run() -> bool:
    var rules_test := CombatRulesTestScript.new()
    if not rules_test.run():
        push_error("Combat rules tests failed.")
        return false

    var loader := ContentLoaderScript.new()
    if not _check_phase1_table_validations(loader):
        return false

    var flow_test := BattleFlowTestScript.new()
    if not flow_test.run(loader):
        push_error("Battle flow tests failed.")
        return false
    var growth_test := InrunGrowthTestScript.new()
    if not growth_test.run():
        push_error("Inrun growth tests failed.")
        return false
    var visualizer_ui_test := BattleVisualizerUiTestScript.new()
    if not visualizer_ui_test.run():
        push_error("Battle visualizer UI test failed.")
        return false
    var reward_flow_test := RewardDraftFlowTestScript.new()
    if not reward_flow_test.run():
        push_error("Reward draft flow test failed.")
        return false
    var route_generation_test := RouteGenerationTestScript.new()
    if not route_generation_test.run():
        push_error("Route generation test failed.")
        return false
    var run_progression_test := RunProgressionTestScript.new()
    if not run_progression_test.run():
        push_error("Run progression test failed.")
        return false
    var evacuation_result_test := EvacuationResultTestScript.new()
    if not evacuation_result_test.run():
        push_error("Evacuation result test failed.")
        return false
    var run_visualizer_ui_test := RunVisualizerUiTestScript.new()
    if not run_visualizer_ui_test.run():
        push_error("Run visualizer UI test failed.")
        return false
    var hub_loop_test := HubLoopTestScript.new()
    if not hub_loop_test.run():
        push_error("Hub loop test failed.")
        return false

    if not _check_content_tables(loader):
        return false
    if not _check_enemy_template_depth(loader):
        push_error("Enemy template depth check failed.")
        return false

    if not _check_dice_pool_depth(loader):
        push_error("Dice pool depth check failed.")
        return false

    if not _check_ai_isolation():
        push_error("AI RNG stream isolation failed.")
        return false

    if not _check_determinism(loader):
        push_error("Determinism check failed.")
        return false

    if not _check_resource_bounds(loader):
        push_error("Resource bound checks failed.")
        return false

    if not _check_mechanic_invariants(loader):
        push_error("Mechanic invariant checks failed.")
        return false

    if not _check_turn_cap_guard(loader):
        push_error("Turn cap guard checks failed.")
        return false

    if not _check_role_mechanic_signals(loader):
        push_error("Role mechanic signal checks failed.")
        return false

    if not _check_dice_type_resonance(loader):
        push_error("Dice type resonance checks failed.")
        return false

    var coverage_test := MechanicCoverageTestScript.new()
    if not coverage_test.run(loader, HEROES, Callable(self, "_simulate_once")):
        push_error("Mechanic coverage smoke failed.")
        return false

    var balance_test := BalanceSmokeTestScript.new()
    var stats_ok := balance_test.run(loader, HEROES, STRICT_BALANCE_GATE, Callable(self, "_simulate_once"))
    return stats_ok

func _check_phase1_table_validations(loader: ContentLoaderScript) -> bool:
    var required := {
        "npcs": ["id", "name", "base_hp", "resource_type", "resource_init", "resource_cap"],
        "dice": ["owner_id", "face_id", "effect_bundle_id", "cost_type", "cost_value", "die_type"],
        "enemies": ["id", "name", "base_hp", "atk_low", "atk_high"]
    }
    for table_any in required.keys():
        var table := String(table_any)
        var rows := loader.load_rows(table)
        if rows.is_empty():
            push_error("Missing rows for table: " + table)
            return false
        var fields: Array = required[table]
        for i in range(rows.size()):
            var row: Dictionary = rows[i]
            for field_any in fields:
                var field := String(field_any)
                if not row.has(field) or String(row.get(field, "")).strip_edges() == "":
                    push_error(table + " row[" + str(i) + "] missing required field '" + field + "'")
                    return false
            if table == "npcs":
                if not _is_int_field(row, "base_hp") or not _is_int_field(row, "resource_init") or not _is_int_field(row, "resource_cap"):
                    push_error(table + " row[" + str(i) + "] has invalid numeric fields")
                    return false
            elif table == "dice":
                if not _is_int_field(row, "cost_value"):
                    push_error(table + " row[" + str(i) + "] has invalid cost_value")
                    return false
            elif table == "enemies":
                if not _is_int_field(row, "base_hp") or not _is_int_field(row, "atk_low") or not _is_int_field(row, "atk_high"):
                    push_error(table + " row[" + str(i) + "] has invalid numeric fields")
                    return false
    return true

func _is_int_field(row: Dictionary, field: String) -> bool:
    var raw := String(row.get(field, "")).strip_edges()
    return raw != "" and raw.is_valid_int()

func _check_content_tables(loader: ContentLoaderScript) -> bool:
    var names := ["npcs", "enemies", "dice", "status_effects", "rewards", "inrun_growth", "run_nodes", "run_rewards", "events"]
    for table in names:
        var rows := loader.load_rows(table)
        if rows.is_empty():
            push_error("Missing table rows: " + table)
            return false
    return true

func _check_enemy_template_depth(loader: ContentLoaderScript) -> bool:
    var enemies := loader.load_rows("enemies")
    if enemies.size() < MIN_ENEMY_TEMPLATES:
        push_error("Need at least %d enemy templates, got %d" % [MIN_ENEMY_TEMPLATES, enemies.size()])
        return false
    return true

func _check_dice_pool_depth(loader: ContentLoaderScript) -> bool:
    var dice_rows := loader.load_rows("dice")
    var counts: Dictionary = {}
    for row in dice_rows:
        var owner := String(row.get("owner_id", ""))
        counts[owner] = int(counts.get(owner, 0)) + 1
    for hero in HEROES:
        var c := int(counts.get(hero, 0))
        if c < 8:
            push_error("Dice count too low for " + hero + ": " + str(c))
            return false
    return true

func _simulate_once(seed_value: int, hero_id: String, loader: ContentLoaderScript) -> Dictionary:
    var bundle := SeedBundleScript.new(seed_value)
    var rngs := RngStreamsScript.new(bundle)
    var logger := ActionLoggerScript.new()
    var factory := UnitFactoryScript.new(loader)
    var catalog := CombatCatalogScript.new(loader)
    var enemy_row := loader.find_row_by_id("enemies", ENEMY_ID)
    var state := CombatStateScript.new(factory.create_npc(hero_id), factory.create_enemy(ENEMY_ID))
    var simulator := BattleSimulatorScript.new(catalog, enemy_row)
    var result := simulator.run(state, rngs, logger)
    result["log_size"] = logger.entries().size()
    result["resource"] = state.player.resource.current_value
    result["entries"] = logger.entries()
    result["next_attack_mult"] = state.player.next_attack_mult
    result["next_attack_ignore_block"] = state.player.next_attack_ignore_block
    return result

func _check_determinism(loader: ContentLoaderScript) -> bool:
    var outcome_a := _simulate_once(20260407, "cyan_ryder", loader)
    var outcome_b := _simulate_once(20260407, "cyan_ryder", loader)
    return outcome_a["winner"] == outcome_b["winner"] and outcome_a["turns"] == outcome_b["turns"] and outcome_a["log_size"] == outcome_b["log_size"]

func _check_ai_isolation() -> bool:
    var seed_value := 10101
    var bundle_a := SeedBundleScript.new(seed_value)
    var bundle_b := SeedBundleScript.new(seed_value)
    var rngs_a := RngStreamsScript.new(bundle_a)
    var rngs_b := RngStreamsScript.new(bundle_b)
    var ai_before := rngs_a.ai_pick(3)
    rngs_b.roll_dice(1, 6)
    rngs_b.roll_dice(1, 6)
    rngs_b.roll_dice(1, 6)
    var ai_after := rngs_b.ai_pick(3)
    return ai_before == ai_after

func _check_resource_bounds(loader: ContentLoaderScript) -> bool:
    for hero in HEROES:
        var result := _simulate_once(3000 + HEROES.find(hero), hero, loader)
        var row := loader.find_row_by_id("npcs", hero)
        var cap := int(row.get("resource_cap", "0"))
        if int(result["resource"]) < 0 or int(result["resource"]) > cap:
            return false
    return true


func _check_mechanic_invariants(loader: ContentLoaderScript) -> bool:
    var cyan_locked := false
    for i in range(40):
        var cyan := _simulate_once(400000 + i, "cyan_ryder", loader)
        var entries: Array = cyan["entries"]
        for e_any in entries:
            var e = e_any
            if String(e.event_type) == "dice_locked":
                cyan_locked = true
                break
        if cyan_locked:
            break
    if not cyan_locked:
        push_error("Cyan overload lock never triggered in sample window.")
        return false

    var black := _simulate_once(500000, "umbral_draxx", loader)
    if float(black["next_attack_mult"]) != 1.0:
        push_error("Black next_attack_mult leaked across battle end.")
        return false
    if int(black["next_attack_ignore_block"]) != 0:
        push_error("Black next_attack_ignore_block leaked across battle end.")
        return false
    return true

func _check_turn_cap_guard(loader: ContentLoaderScript) -> bool:
    var res := _simulate_once(600001, "cyan_ryder", loader)
    var turns := int(res.get("turns", 0))
    var ended_by_cap := bool(res.get("ended_by_cap", false))
    if turns <= 0 or turns > 61:
        push_error("Turn cap bound invalid: " + str(turns))
        return false
    if ended_by_cap:
        var has_stalemate_event := false
        var entries: Array = res["entries"]
        for e_any in entries:
            var e = e_any
            if String(e.event_type) == "battle_stalemate":
                has_stalemate_event = true
                break
        if not has_stalemate_event:
            push_error("ended_by_cap set but battle_stalemate event missing.")
            return false
    return true

func _check_role_mechanic_signals(loader: ContentLoaderScript) -> bool:
    var cyan_ok := false
    var helios_ok := false
    var umbral_ok := false
    for i in range(80):
        if not cyan_ok:
            var cyan := _simulate_once(700000 + i, "cyan_ryder", loader)
            for e_any in cyan["entries"]:
                var e = e_any
                if String(e.event_type) == "overclock_changed":
                    cyan_ok = true
                    break
        if not helios_ok:
            var helios := _simulate_once(710000 + i, "helios_windchaser", loader)
            for e_any in helios["entries"]:
                var e = e_any
                if String(e.event_type) == "focus_changed" or String(e.event_type) == "mark_consumed":
                    helios_ok = true
                    break
        if not umbral_ok:
            var umbral := _simulate_once(720000 + i, "umbral_draxx", loader)
            for e_any in umbral["entries"]:
                var e = e_any
                var payload: Dictionary = e.payload if typeof(e.payload) == TYPE_DICTIONARY else {}
                if String(e.event_type) == "counter_attack":
                    umbral_ok = true
                    break
                if String(e.event_type) == "resource_changed" and (
                    String(payload.get("source", "")) == "execute_spend_all" or
                    String(payload.get("source", "")) == "blocked_enemy_attack"
                ):
                    umbral_ok = true
                    break
        if cyan_ok and helios_ok and umbral_ok:
            return true
    if not cyan_ok:
        push_error("Cyan overclock signal not observed.")
    if not helios_ok:
        push_error("Helios focus signal not observed.")
    if not umbral_ok:
        push_error("Umbral stance mechanic signal not observed.")
    return false

func _check_dice_type_resonance(loader: ContentLoaderScript) -> bool:
    for hero in HEROES:
        var seen := false
        for i in range(80):
            var res := _simulate_once(800000 + (HEROES.find(hero) * 1000) + i, hero, loader)
            var entries: Array = res["entries"]
            for e_any in entries:
                var e = e_any
                if String(e.event_type) == "dice_type_resonance":
                    seen = true
                    break
            if seen:
                break
        if not seen:
            push_error("No dice_type_resonance observed for " + hero)
            return false
    return true
