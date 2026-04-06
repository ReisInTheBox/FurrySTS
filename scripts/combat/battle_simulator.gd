class_name BattleSimulator
extends RefCounted

const CombatState = preload("res://scripts/combat/combat_state.gd")
const RngStreams = preload("res://scripts/core/rng_streams.gd")
const ActionLogger = preload("res://scripts/core/action_logger.gd")
const ActionLogEntry = preload("res://scripts/core/action_log_entry.gd")
const CombatCatalog = preload("res://scripts/content/combat_catalog.gd")
const DiceFaceDefinition = preload("res://scripts/combat/dice_face_definition.gd")
const EffectResolver = preload("res://scripts/combat/effect_resolver.gd")

const EVENT_BATTLE_END := "battle_end"
const EVENT_BATTLE_STALEMATE := "battle_stalemate"
const EVENT_DICE_LOCKED := "dice_locked"
const EVENT_ENEMY_ATTACK := "enemy_attack"
const EVENT_COUNTER_ATTACK := "counter_attack"
const EVENT_STYLE_BONUS := "style_bonus"
const MAX_TURNS := 60

var _catalog: CombatCatalog
var _effects: EffectResolver = EffectResolver.new()
var _enemy_data: Dictionary = {}

func _init(catalog: CombatCatalog, enemy_data: Dictionary) -> void:
    _catalog = catalog
    _enemy_data = enemy_data

func run(state: CombatState, rngs: RngStreams, logger: ActionLogger) -> Dictionary:
    while not state.battle_ended() and state.turn_index <= MAX_TURNS:
        _start_player_turn(state, rngs, logger)
        _player_phase(state, rngs, logger)
        if state.battle_ended():
            break
        _enemy_turn(state, rngs, logger)
        _end_turn(state, logger)
        state.turn_index += 1

    var ended_by_cap := (not state.battle_ended()) and state.turn_index > MAX_TURNS
    if ended_by_cap:
        logger.append(ActionLogEntry.new(
            EVENT_BATTLE_STALEMATE,
            state.turn_index,
            "system",
            "system",
            {"reason": "max_turns_reached", "max_turns": MAX_TURNS}
        ))

    var winner := "none"
    if state.player.is_alive():
        winner = state.player.unit_id
    elif state.enemy.is_alive():
        winner = state.enemy.unit_id

    logger.append(ActionLogEntry.new(
        EVENT_BATTLE_END,
        state.turn_index,
        "system",
        winner,
        {"player_hp": state.player.hp, "enemy_hp": state.enemy.hp, "ended_by_cap": ended_by_cap}
    ))
    return {"winner": winner, "turns": state.turn_index, "ended_by_cap": ended_by_cap}

func _start_player_turn(state: CombatState, rngs: RngStreams, logger: ActionLogger) -> void:
    state.reset_turn_state()
    var dice_pool := _catalog.dice_for_owner(state.player.unit_id)
    if state.player.pending_lock_faces > 0:
        for _i in range(state.player.pending_lock_faces):
            if dice_pool.is_empty():
                break
            var idx := rngs.roll_dice(0, dice_pool.size() - 1)
            var face: DiceFaceDefinition = dice_pool[idx]
            if not state.locked_face_ids.has(face.face_id):
                state.locked_face_ids.append(face.face_id)
        logger.append(ActionLogEntry.new(
            EVENT_DICE_LOCKED,
            state.turn_index,
            state.player.unit_id,
            state.player.unit_id,
            {"locked_faces": state.locked_face_ids}
        ))
        state.player.pending_lock_faces = 0
    _roll_faces(state, rngs, 3)

func _player_phase(state: CombatState, rngs: RngStreams, logger: ActionLogger) -> void:
    while state.picks_used < state.picks_budget and not state.battle_ended():
        var pick := _pick_best_face(state)
        if pick == null:
            if state.rerolls_left > 0 and _reroll_one(state, rngs):
                state.rerolls_left -= 1
                continue
            break
        var face: DiceFaceDefinition = pick
        state.rolled_faces.erase(face)
        _execute_face(state, face, logger)
        state.picks_used += 1
        if state.bonus_rolls > 0:
            state.bonus_rolls -= 1
            _roll_faces(state, rngs, 1)

func _execute_face(state: CombatState, face: DiceFaceDefinition, logger: ActionLogger) -> void:
    var pre_resource := state.player.resource.current_value
    var paid := _try_pay_cost(state, face)
    if not paid:
        _effects.apply_bundle(state, face, [{"op_type": "damage", "value": "1", "trigger": "OnDiceResolved", "effect_id": "fallback_min_damage"}], logger)
        return
    var effects := _catalog.effects_for_bundle(face.effect_bundle_id)
    _effects.apply_bundle(state, face, effects, logger)
    _apply_face_post_rules(state, face, pre_resource, logger)
    _apply_character_face_passives(state, face, logger)
    _apply_dice_type_resonance(state, face, logger)

func _apply_face_post_rules(state: CombatState, face: DiceFaceDefinition, pre_resource: int, logger: ActionLogger) -> void:
    if state.player.resource.has_type("overload"):
        var post_resource := state.player.resource.current_value
        logger.append(ActionLogEntry.new(
            "resource_changed",
            state.turn_index,
            state.player.unit_id,
            state.player.unit_id,
            {
                "face_id": face.face_id,
                "resource_type": "overload",
                "pre_resource": pre_resource,
                "post_resource": post_resource
            }
        ))
        if state.player.unit_id == "cyan_ryder" and pre_resource < state.player.resource.cap_value and post_resource >= state.player.resource.cap_value:
            state.player.overclock_charges = min(2, state.player.overclock_charges + 1)
            logger.append(ActionLogEntry.new(
                "overclock_changed",
                state.turn_index,
                state.player.unit_id,
                state.player.unit_id,
                {"face_id": face.face_id, "overclock_charges": state.player.overclock_charges, "source": "overload_capped"}
            ))

func _apply_character_face_passives(state: CombatState, face: DiceFaceDefinition, logger: ActionLogger) -> void:
    if state.player.unit_id == "cyan_ryder" and face.has_tag("ranged"):
        if state.last_ranged_face_id != "" and state.last_ranged_face_id != face.face_id:
            state.cyan_prism_chain += 1
            if state.cyan_prism_chain >= 1:
                state.bonus_rolls += 1
                state.cyan_prism_chain = 0
                logger.append(ActionLogEntry.new(
                    "bonus_roll_granted",
                    state.turn_index,
                    state.player.unit_id,
                    state.player.unit_id,
                    {"face_id": face.face_id, "bonus_rolls": state.bonus_rolls, "source": "prism_chain"}
                ))
        state.last_ranged_face_id = face.face_id

func _try_pay_cost(state: CombatState, face: DiceFaceDefinition) -> bool:
    if face.cost_type == "none" or face.cost_value <= 0:
        return true
    if not state.player.resource.has_type(face.cost_type):
        return false
    return state.player.resource.spend(face.cost_value)

func _enemy_turn(state: CombatState, rngs: RngStreams, logger: ActionLogger) -> void:
    var low := int(_enemy_data.get("atk_low", "6"))
    var high := int(_enemy_data.get("atk_high", "9"))
    var choose_high := rngs.ai_pick(2) == 1
    var value := high if choose_high else low
    var every := int(_enemy_data.get("bonus_every_turns", "3"))
    if every > 0 and state.turn_index % every == 0:
        value += int(_enemy_data.get("bonus_flat", "0"))
    var result := state.player.apply_damage(value)
    logger.append(ActionLogEntry.new(
        EVENT_ENEMY_ATTACK,
        state.turn_index,
        state.enemy.unit_id,
        state.player.unit_id,
        {
            "value": value,
            "blocked": result["blocked"],
            "damage": result["damage"],
            "target_hp": state.player.hp
        }
    ))
    if state.player.thorns_value > 0 and state.enemy.is_alive():
        var thorns := state.player.thorns_value
        state.player.thorns_value = 0
        var retaliation := state.enemy.apply_damage(thorns)
        logger.append(ActionLogEntry.new(
            EVENT_COUNTER_ATTACK,
            state.turn_index,
            state.player.unit_id,
            state.enemy.unit_id,
            {
                "value": thorns,
                "blocked": retaliation["blocked"],
                "damage": retaliation["damage"],
                "target_hp": state.enemy.hp
            }
        ))
    if state.player.unit_id == "umbral_draxx" and int(result["blocked"]) > 0 and state.player.resource.has_type("stance"):
        var stance := state.player.resource.apply_delta(1)
        logger.append(ActionLogEntry.new(
            "resource_changed",
            state.turn_index,
            state.player.unit_id,
            state.player.unit_id,
            {
                "face_id": "umbral_shadow_counter",
                "resource_type": "stance",
                "pre_resource": stance["before"],
                "post_resource": stance["after"],
                "source": "blocked_enemy_attack"
            }
        ))

func _end_turn(state: CombatState, logger: ActionLogger) -> void:
    var distinct_types := 0
    for k in state.dice_type_counts.keys():
        if int(state.dice_type_counts.get(k, 0)) > 0:
            distinct_types += 1
    if distinct_types >= 3:
        var healed := state.player.apply_heal(1)
        if healed > 0:
            logger.append(ActionLogEntry.new(
                EVENT_STYLE_BONUS,
                state.turn_index,
                state.player.unit_id,
                state.player.unit_id,
                {"distinct_types": distinct_types, "healed": healed, "hp": state.player.hp}
            ))

    if state.player.resource.has_type("overload") and state.player.resource.current_value >= 3:
        state.player.pending_lock_faces = 1
        state.player.resource.apply_delta(-2)
    if state.player.unit_id == "cyan_ryder" and state.player.resource.has_type("overload") and state.player.resource.current_value >= 2:
        var burn := state.player.apply_damage(1, 999)
        if int(burn["damage"]) > 0:
            logger.append(ActionLogEntry.new(
                "self_damage",
                state.turn_index,
                state.player.unit_id,
                state.player.unit_id,
                {"source": "overheat_burn", "damage": burn["damage"], "hp": state.player.hp}
            ))
            state.player.overclock_charges = max(0, state.player.overclock_charges - 1)
            logger.append(ActionLogEntry.new(
                "overclock_changed",
                state.turn_index,
                state.player.unit_id,
                state.player.unit_id,
                {"face_id": "turn_end", "overclock_charges": state.player.overclock_charges, "source": "overheat_decay"}
            ))
    state.player.temp_ranged_flat = 0

func _roll_faces(state: CombatState, rngs: RngStreams, count: int) -> void:
    var pool := _catalog.dice_for_owner(state.player.unit_id)
    if pool.is_empty():
        return
    for _i in range(count):
        var idx := rngs.roll_dice(0, pool.size() - 1)
        state.rolled_faces.append(pool[idx])

func _pick_best_face(state: CombatState) -> DiceFaceDefinition:
    var best: DiceFaceDefinition = null
    var best_score := -999999
    for face_any in state.rolled_faces:
        var face: DiceFaceDefinition = face_any
        if state.locked_face_ids.has(face.face_id):
            continue
        var score := _face_score(state, face)
        if score > best_score:
            best_score = score
            best = face
    return best

func _face_score(state: CombatState, face: DiceFaceDefinition) -> int:
    var score := 0
    if face.has_tag("attack"):
        score += 30
    if face.has_tag("defense"):
        score += 10 if state.player.hp < int(state.player.max_hp * 0.6) else 3
    if face.has_tag("mark"):
        score += 20 if state.enemy.marks == 0 else 8
    if face.cost_type != "none":
        if state.player.resource.has_type(face.cost_type) and state.player.resource.current_value >= face.cost_value:
            score += 25
        else:
            score -= 20
    if face.face_id == "cyan_burst" and state.player.resource.current_value >= 2:
        score -= 8
    if face.face_id == "black_charge" and state.player.next_attack_mult > 1.0:
        score -= 15
    var type_count := int(state.dice_type_counts.get(face.die_type, 0))
    if type_count == 1:
        score += 7
    if state.player.unit_id == "cyan_ryder":
        if face.has_tag("ranged") and state.player.overclock_charges > 0:
            score += 14
        if face.face_id == "cyan_burst" and state.player.resource.current_value <= 1:
            score += 10
        if face.face_id == "cyan_cooldown" and state.player.resource.current_value >= 2:
            score += 10
        if face.face_id == "cyan_arcflare" and state.player.resource.current_value >= 1:
            score += 12
        if face.face_id == "cyan_vent" and state.player.resource.current_value >= 2:
            score += 16
    if state.player.unit_id == "helios_windchaser":
        if face.face_id == "helios_sniper" or face.face_id == "helios_pierce":
            score += state.player.focus_stacks * 12
        if face.face_id == "helios_mark" and state.enemy.marks <= 1:
            score += 12
        if face.face_id == "helios_trap" and state.enemy.marks <= 2:
            score += 15
        if face.face_id == "helios_volley" and state.enemy.marks >= 1:
            score += 10
    if state.player.unit_id == "umbral_draxx":
        if face.face_id == "black_execute":
            var missing := state.enemy.max_hp - state.enemy.hp
            score += int(missing / 2) + (state.player.resource.current_value * 18)
        if face.face_id == "black_guard" and state.player.hp < int(state.player.max_hp * 0.7):
            score += 10
        if face.face_id == "black_parry" and state.player.hp < int(state.player.max_hp * 0.75):
            score += 14
        if face.face_id == "black_reap" and state.player.resource.current_value >= 1:
            score += 9
    return score

func _apply_dice_type_resonance(state: CombatState, face: DiceFaceDefinition, logger: ActionLogger) -> void:
    var d_type := face.die_type
    if d_type == "":
        d_type = "standard"
    var count := int(state.dice_type_counts.get(d_type, 0)) + 1
    state.dice_type_counts[d_type] = count
    if count != 2:
        return

    var payload := {"face_id": face.face_id, "die_type": d_type}
    if d_type == "burst":
        if state.bonus_rolls >= 2:
            return
        state.bonus_rolls += 1
        payload["bonus_rolls"] = state.bonus_rolls
    elif d_type == "setup":
        if state.rerolls_left >= 2:
            return
        state.rerolls_left += 1
        payload["rerolls_left"] = state.rerolls_left
    elif d_type == "defense":
        var gain := state.player.add_block(2)
        payload["add_block"] = gain
    elif d_type == "finisher":
        state.player.next_attack_ignore_block += 2
        payload["next_attack_ignore_block"] = state.player.next_attack_ignore_block
    else:
        return

    logger.append(ActionLogEntry.new(
        "dice_type_resonance",
        state.turn_index,
        state.player.unit_id,
        state.player.unit_id,
        payload
    ))

func _reroll_one(state: CombatState, rngs: RngStreams) -> bool:
    if state.rolled_faces.is_empty():
        return false
    var pool := _catalog.dice_for_owner(state.player.unit_id)
    if pool.is_empty():
        return false
    var target_idx := rngs.roll_dice(0, state.rolled_faces.size() - 1)
    var next_idx := rngs.roll_dice(0, pool.size() - 1)
    state.rolled_faces[target_idx] = pool[next_idx]
    return true
