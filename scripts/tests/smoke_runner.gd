extends RefCounted

const SeedBundle = preload("res://scripts/core/seed_bundle.gd")
const RngStreams = preload("res://scripts/core/rng_streams.gd")
const ActionLogger = preload("res://scripts/core/action_logger.gd")
const CombatState = preload("res://scripts/combat/combat_state.gd")
const BattleSimulator = preload("res://scripts/combat/battle_simulator.gd")
const ContentLoader = preload("res://scripts/content/content_loader.gd")
const UnitFactory = preload("res://scripts/content/unit_factory.gd")
const CombatCatalog = preload("res://scripts/content/combat_catalog.gd")

const HEROES := ["cyan_ryder", "helios_windchaser", "umbral_draxx"]
const ENEMY_ID := "boss_vanguard"

func run() -> bool:
    var loader := ContentLoader.new()
    if not _check_content_tables(loader):
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

    if not _run_mechanic_coverage_smoke(loader):
        push_error("Mechanic coverage smoke failed.")
        return false

    var stats_ok := _run_balance_smoke(loader)
    return stats_ok

func _check_content_tables(loader: ContentLoader) -> bool:
    var names := ["npcs", "enemies", "dice", "status_effects"]
    for table in names:
        var rows := loader.load_rows(table)
        if rows.is_empty():
            push_error("Missing table rows: " + table)
            return false
    return true

func _check_dice_pool_depth(loader: ContentLoader) -> bool:
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

func _simulate_once(seed: int, hero_id: String, loader: ContentLoader) -> Dictionary:
    var bundle := SeedBundle.new(seed)
    var rngs := RngStreams.new(bundle)
    var logger := ActionLogger.new()
    var factory := UnitFactory.new(loader)
    var catalog := CombatCatalog.new(loader)
    var enemy_row := loader.find_row_by_id("enemies", ENEMY_ID)
    var state := CombatState.new(factory.create_npc(hero_id), factory.create_enemy(ENEMY_ID))
    var simulator := BattleSimulator.new(catalog, enemy_row)
    var result := simulator.run(state, rngs, logger)
    result["log_size"] = logger.entries().size()
    result["resource"] = state.player.resource.current_value
    result["entries"] = logger.entries()
    result["next_attack_mult"] = state.player.next_attack_mult
    result["next_attack_ignore_block"] = state.player.next_attack_ignore_block
    return result

func _check_determinism(loader: ContentLoader) -> bool:
    var outcome_a := _simulate_once(20260407, "cyan_ryder", loader)
    var outcome_b := _simulate_once(20260407, "cyan_ryder", loader)
    return outcome_a["winner"] == outcome_b["winner"] and outcome_a["turns"] == outcome_b["turns"] and outcome_a["log_size"] == outcome_b["log_size"]

func _check_ai_isolation() -> bool:
    var seed := 10101
    var bundle_a := SeedBundle.new(seed)
    var bundle_b := SeedBundle.new(seed)
    var rngs_a := RngStreams.new(bundle_a)
    var rngs_b := RngStreams.new(bundle_b)
    var ai_before := rngs_a.ai_pick(3)
    rngs_b.roll_dice(1, 6)
    rngs_b.roll_dice(1, 6)
    rngs_b.roll_dice(1, 6)
    var ai_after := rngs_b.ai_pick(3)
    return ai_before == ai_after

func _check_resource_bounds(loader: ContentLoader) -> bool:
    for hero in HEROES:
        var result := _simulate_once(3000 + HEROES.find(hero), hero, loader)
        var row := loader.find_row_by_id("npcs", hero)
        var cap := int(row.get("resource_cap", "0"))
        if int(result["resource"]) < 0 or int(result["resource"]) > cap:
            return false
    return true

func _run_balance_smoke(loader: ContentLoader) -> bool:
    var all_ok := true
    var hero_win_rates: Dictionary = {}
    for hero in HEROES:
        var wins := 0
        var turns_total := 0
        for i in range(100):
            var res := _simulate_once(100000 + i, hero, loader)
            if String(res["winner"]) == hero:
                wins += 1
            turns_total += int(res["turns"])
        var win_rate := float(wins) / 100.0
        var avg_turns := float(turns_total) / 100.0
        hero_win_rates[hero] = win_rate
        print("[SMOKE][BALANCE] hero=", hero, " win_rate=", win_rate, " avg_turns=", avg_turns)
        if win_rate < 0.40 or win_rate > 0.60:
            push_error("Win-rate out of target for " + hero + ": " + str(win_rate))
            all_ok = false
        if avg_turns < 4.8 or avg_turns > 10.8:
            push_error("Avg turns out of target for " + hero + ": " + str(avg_turns))
            all_ok = false

    var min_rate := 1.0
    var max_rate := 0.0
    for hero in HEROES:
        var r := float(hero_win_rates.get(hero, 0.0))
        min_rate = min(min_rate, r)
        max_rate = max(max_rate, r)
    if (max_rate - min_rate) > 0.12:
        push_error("Hero win-rate spread too high: " + str(max_rate - min_rate))
        all_ok = false

    return all_ok

func _check_mechanic_invariants(loader: ContentLoader) -> bool:
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

func _check_turn_cap_guard(loader: ContentLoader) -> bool:
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

func _check_role_mechanic_signals(loader: ContentLoader) -> bool:
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

func _check_dice_type_resonance(loader: ContentLoader) -> bool:
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

func _run_mechanic_coverage_smoke(loader: ContentLoader) -> bool:
    var all_ok := true
    var per_hero_samples := 60
    for hero in HEROES:
        var overclock_events := 0
        var focus_events := 0
        var counter_events := 0
        var resonance_events := 0
        var style_bonus_events := 0
        for i in range(per_hero_samples):
            var res := _simulate_once(900000 + (HEROES.find(hero) * 2000) + i, hero, loader)
            var entries: Array = res["entries"]
            for e_any in entries:
                var e = e_any
                var ev := String(e.event_type)
                if ev == "overclock_changed":
                    overclock_events += 1
                elif ev == "focus_changed":
                    focus_events += 1
                elif ev == "counter_attack":
                    counter_events += 1
                elif ev == "dice_type_resonance":
                    resonance_events += 1
                elif ev == "style_bonus":
                    style_bonus_events += 1

        var avg_resonance := float(resonance_events) / float(per_hero_samples)
        print("[SMOKE][COVERAGE] hero=", hero, " resonance_avg=", avg_resonance, " style_bonus=", style_bonus_events, " overclock=", overclock_events, " focus=", focus_events, " counter=", counter_events)
        if avg_resonance < 0.35:
            push_error("Resonance density too low for " + hero + ": " + str(avg_resonance))
            all_ok = false
        if style_bonus_events <= 0:
            push_error("Style bonus never triggered for " + hero)
            all_ok = false

        if hero == "cyan_ryder" and overclock_events <= 0:
            push_error("Cyan overclock events not observed in coverage smoke.")
            all_ok = false
        if hero == "helios_windchaser" and focus_events <= 0:
            push_error("Helios focus events not observed in coverage smoke.")
            all_ok = false
        if hero == "umbral_draxx" and counter_events <= 0:
            push_error("Umbral counter events not observed in coverage smoke.")
            all_ok = false
    return all_ok
