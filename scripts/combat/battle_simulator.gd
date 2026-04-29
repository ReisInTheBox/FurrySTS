class_name BattleSimulator
extends RefCounted

const CombatStateScript = preload("res://scripts/combat/combat_state.gd")
const RngStreamsScript = preload("res://scripts/core/rng_streams.gd")
const ActionLoggerScript = preload("res://scripts/core/action_logger.gd")
const ActionLogEntryScript = preload("res://scripts/core/action_log_entry.gd")
const TurnStateMachineScript = preload("res://scripts/core/turn_state_machine.gd")
const CombatCatalogScript = preload("res://scripts/content/combat_catalog.gd")
const DiceFaceDefinitionScript = preload("res://scripts/combat/dice_face_definition.gd")
const EffectResolverScript = preload("res://scripts/combat/effect_resolver.gd")
const EquipmentEffectResolverScript = preload("res://scripts/combat/equipment_effect_resolver.gd")
const EnemyIntentScript = preload("res://scripts/combat/enemy_intent.gd")

const EVENT_BATTLE_END := "battle_end"
const EVENT_BATTLE_STALEMATE := "battle_stalemate"
const EVENT_DICE_LOCKED := "dice_locked"
const EVENT_ENEMY_ATTACK := "enemy_attack"
const EVENT_ENEMY_BLOCK := "enemy_block"
const EVENT_ENEMY_DEBUFF := "enemy_debuff"
const EVENT_ACTION_REJECTED := "action_rejected"
const EVENT_COUNTER_ATTACK := "counter_attack"
const EVENT_STYLE_BONUS := "style_bonus"
const EVENT_NEGATIVE_FACE := "negative_face_resolved"
const MAX_TURNS := 60
const DICE_PER_TURN := 3
const BASE_REROLLS_PER_TURN := 2

var _catalog: CombatCatalogScript
var _effects: EffectResolverScript = EffectResolverScript.new()
var _equipment_effects: EquipmentEffectResolverScript = EquipmentEffectResolverScript.new()
var _enemy_data: Dictionary = {}

func _init(catalog: CombatCatalogScript, enemy_data: Dictionary) -> void:
    _catalog = catalog
    _enemy_data = enemy_data

func run(state: CombatStateScript, rngs: RngStreamsScript, logger: ActionLoggerScript) -> Dictionary:
    var turn_fsm := TurnStateMachineScript.new()
    while not state.battle_ended() and state.turn_index <= MAX_TURNS:
        turn_fsm.reset_for_new_turn()
        while true:
            match turn_fsm.current_phase():
                TurnStateMachineScript.PHASE_PLAYER_START:
                    _start_player_turn(state, rngs, logger)
                TurnStateMachineScript.PHASE_PLAYER_ACTION:
                    _player_phase(state, rngs, logger)
                TurnStateMachineScript.PHASE_ENEMY_ACTION:
                    if not state.battle_ended():
                        _enemy_turn(state, rngs, logger)
                TurnStateMachineScript.PHASE_TURN_END:
                    _end_turn(state, logger)
            if state.battle_ended() or not turn_fsm.advance():
                break
        state.turn_index += 1

    var ended_by_cap := (not state.battle_ended()) and state.turn_index > MAX_TURNS
    if ended_by_cap:
        logger.append(ActionLogEntryScript.new(
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

    logger.append(ActionLogEntryScript.new(
        EVENT_BATTLE_END,
        state.turn_index,
        "system",
        winner,
        {"player_hp": state.player.hp, "enemy_hp": state.enemy.hp, "ended_by_cap": ended_by_cap}
    ))
    return {"winner": winner, "turns": state.turn_index, "ended_by_cap": ended_by_cap}

func initialize_equipment_for_battle(state: CombatStateScript, equipment_instances: Array, logger: ActionLoggerScript) -> void:
    _equipment_effects.initialize_battle(state, equipment_instances, logger)

func can_use_active_item(state: CombatStateScript) -> bool:
    return _equipment_effects.can_use_active_item(state)

func active_item_label(state: CombatStateScript) -> String:
    return _equipment_effects.active_item_label(state)

func use_active_item(state: CombatStateScript, logger: ActionLoggerScript) -> Dictionary:
    return _equipment_effects.use_active_item(state, logger)

func start_manual_player_turn(state: CombatStateScript, rngs: RngStreamsScript, logger: ActionLoggerScript) -> void:
    _start_player_turn(state, rngs, logger)

func get_manual_pickable_faces(state: CombatStateScript) -> Array[DiceFaceDefinitionScript]:
    var out: Array[DiceFaceDefinitionScript] = []
    for face_any in state.rolled_faces:
        var face: DiceFaceDefinitionScript = face_any
        if state.locked_face_ids.has(face.face_id):
            continue
        out.append(face)
    return out

func can_player_act(state: CombatStateScript) -> bool:
    if state.battle_ended():
        return false
    if state.picks_used >= state.picks_budget:
        return false
    return not get_manual_pickable_faces(state).is_empty()

func manual_reroll_once(state: CombatStateScript, rngs: RngStreamsScript) -> bool:
    if state.battle_ended() or state.rerolls_left <= 0:
        return false
    if not _reroll_one(state, rngs):
        return false
    _consume_reroll_cost(state, null)
    return true

func manual_reroll_selected(state: CombatStateScript, rngs: RngStreamsScript, selected_indices: Array[int]) -> bool:
    if state.battle_ended() or state.rerolls_left <= 0:
        return false
    if selected_indices.is_empty():
        return false
    var normalized: Array[int] = []
    for idx in selected_indices:
        if idx < 0 or idx >= state.rolled_faces.size():
            continue
        if normalized.has(idx):
            continue
        var face: DiceFaceDefinitionScript = state.rolled_faces[idx]
        if state.locked_face_ids.has(face.face_id):
            continue
        normalized.append(idx)
    if normalized.is_empty():
        return false

    normalized.sort()
    for idx in normalized:
        var current: DiceFaceDefinitionScript = state.rolled_faces[idx]
        var die_faces := _catalog.faces_for_die(current.die_id)
        if die_faces.is_empty():
            die_faces = _catalog.dice_for_owner(state.player.unit_id, state.player.loadout_face_ids)
        if die_faces.is_empty():
            continue
        var next_idx := rngs.roll_dice(0, die_faces.size() - 1)
        state.rolled_faces[idx] = die_faces[next_idx]

    _consume_reroll_cost(state, null)
    return true

func apply_manual_face_pick(state: CombatStateScript, rngs: RngStreamsScript, logger: ActionLoggerScript, face_id: String) -> bool:
    if state.battle_ended() or state.picks_used >= state.picks_budget:
        logger.append(ActionLogEntryScript.new(
            EVENT_ACTION_REJECTED,
            state.turn_index,
            state.player.unit_id,
            state.player.unit_id,
            {"face_id": face_id, "reason": "turn_locked_or_battle_end"}
        ))
        return false
    var picked: DiceFaceDefinitionScript = null
    for face_any in state.rolled_faces:
        var face: DiceFaceDefinitionScript = face_any
        if face.face_id == face_id and not state.locked_face_ids.has(face.face_id):
            picked = face
            break
    if picked == null:
        logger.append(ActionLogEntryScript.new(
            EVENT_ACTION_REJECTED,
            state.turn_index,
            state.player.unit_id,
            state.player.unit_id,
            {"face_id": face_id, "reason": "face_not_pickable"}
        ))
        return false
    state.rolled_faces.erase(picked)
    _execute_face(state, picked, logger)
    state.picks_used += 1
    return true

func apply_manual_face_pick_at(state: CombatStateScript, rngs: RngStreamsScript, logger: ActionLoggerScript, slot_index: int) -> bool:
    if state.battle_ended() or state.picks_used >= state.picks_budget:
        logger.append(ActionLogEntryScript.new(
            EVENT_ACTION_REJECTED,
            state.turn_index,
            state.player.unit_id,
            state.player.unit_id,
            {"slot_index": slot_index, "reason": "turn_locked_or_battle_end"}
        ))
        return false
    if slot_index < 0 or slot_index >= state.rolled_faces.size():
        logger.append(ActionLogEntryScript.new(
            EVENT_ACTION_REJECTED,
            state.turn_index,
            state.player.unit_id,
            state.player.unit_id,
            {"slot_index": slot_index, "reason": "slot_out_of_range"}
        ))
        return false
    var picked: DiceFaceDefinitionScript = state.rolled_faces[slot_index]
    if state.locked_face_ids.has(picked.face_id):
        logger.append(ActionLogEntryScript.new(
            EVENT_ACTION_REJECTED,
            state.turn_index,
            state.player.unit_id,
            state.player.unit_id,
            {"slot_index": slot_index, "face_id": picked.face_id, "reason": "face_not_pickable"}
        ))
        return false

    state.rolled_faces.remove_at(slot_index)
    _execute_face(state, picked, logger)
    state.picks_used += 1
    return true

func preview_enemy_intent(state: CombatStateScript, rngs: RngStreamsScript) -> EnemyIntentScript:
    var ai_state := rngs.rng_ai.state
    var intent := _build_enemy_intent(state, rngs)
    rngs.rng_ai.state = ai_state
    return intent

func run_manual_enemy_phase(state: CombatStateScript, rngs: RngStreamsScript, logger: ActionLoggerScript) -> void:
    if state.battle_ended():
        return
    _enemy_turn(state, rngs, logger)
    _end_turn(state, logger)
    state.turn_index += 1

func _start_player_turn(state: CombatStateScript, rngs: RngStreamsScript, logger: ActionLoggerScript) -> void:
    state.reset_turn_state()
    state.rerolls_left = BASE_REROLLS_PER_TURN
    var dice_pool := _catalog.dice_for_owner(state.player.unit_id, _active_loadout_ids(state))
    if state.player.pending_lock_faces > 0:
        for _i in range(state.player.pending_lock_faces):
            if dice_pool.is_empty():
                break
            var idx := rngs.roll_dice(0, dice_pool.size() - 1)
            var face: DiceFaceDefinitionScript = dice_pool[idx]
            if not state.locked_face_ids.has(face.face_id):
                state.locked_face_ids.append(face.face_id)
        logger.append(ActionLogEntryScript.new(
            EVENT_DICE_LOCKED,
            state.turn_index,
            state.player.unit_id,
            state.player.unit_id,
            {"locked_faces": state.locked_face_ids}
        ))
        state.player.pending_lock_faces = 0
    _roll_loadout_dice(state, rngs)
    state.picks_budget = state.rolled_faces.size()

func _player_phase(state: CombatStateScript, rngs: RngStreamsScript, logger: ActionLoggerScript) -> void:
    while state.picks_used < state.picks_budget and not state.battle_ended():
        var pick := _pick_best_face(state)
        if pick == null:
            if state.rerolls_left > 0 and _reroll_one(state, rngs):
                _consume_reroll_cost(state, logger)
                continue
            break
        var face: DiceFaceDefinitionScript = pick
        state.rolled_faces.erase(face)
        _execute_face(state, face, logger)
        state.picks_used += 1

func _execute_face(state: CombatStateScript, face: DiceFaceDefinitionScript, logger: ActionLoggerScript) -> void:
    var pre_resource := state.player.resource.current_value
    var pre_block := state.player.block
    var effects := _catalog.effects_for_bundle(face.effect_bundle_id)
    for enchant_effect in _enchant_effects_for_face(state, face, logger):
        effects.append(enchant_effect)
    _equipment_effects.before_face(state, face, effects, logger)
    if face.is_negative or face.has_tag("negative"):
        logger.append(ActionLogEntryScript.new(
            EVENT_NEGATIVE_FACE,
            state.turn_index,
            state.player.unit_id,
            state.player.unit_id,
            {"face_id": face.face_id, "die_id": face.die_id}
        ))
    var paid := _try_pay_cost(state, face)
    if not paid:
        _effects.apply_bundle(state, face, [{"op_type": "damage", "value": "1", "trigger": "OnDiceResolved", "effect_id": "fallback_min_damage"}], logger)
        return
    _effects.apply_bundle(state, face, effects, logger)
    _equipment_effects.after_face(state, face, effects, pre_block, logger)
    _apply_face_post_rules(state, face, pre_resource, logger)
    _apply_character_face_passives(state, face, logger)
    _apply_dice_type_resonance(state, face, logger)

func _enchant_effects_for_face(state: CombatStateScript, face: DiceFaceDefinitionScript, logger: ActionLoggerScript) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for binding_any in state.player.enchant_bindings:
        var binding: Dictionary = binding_any
        if String(binding.get("die_id", "")) != face.die_id:
            continue
        if int(binding.get("face_index", "0")) != face.face_index:
            continue
        var enchant_id := String(binding.get("enchant_id", ""))
        var enchantment := _catalog.enchantment_by_id(enchant_id)
        if enchantment.is_empty():
            continue
        out.append({
            "effect_id": "enchant_" + enchant_id,
            "bundle_id": "enchant_" + enchant_id,
            "trigger": String(enchantment.get("trigger", "OnDiceResolved")),
            "op_type": String(enchantment.get("op_type", "")),
            "value": String(enchantment.get("value", "")),
            "duration": "0",
            "stack_rule": "none",
            "source": "enchant",
            "target": "target",
            "tags": String(enchantment.get("tags", ""))
        })
        logger.append(ActionLogEntryScript.new(
            "enchant_triggered",
            state.turn_index,
            state.player.unit_id,
            state.player.unit_id,
            {
                "face_id": face.face_id,
                "die_id": face.die_id,
                "face_index": face.face_index,
                "enchant_id": enchant_id,
                "op_type": String(enchantment.get("op_type", "")),
                "value": String(enchantment.get("value", "")),
                "source": String(binding.get("source", "reward"))
            }
        ))
    return out

func _apply_face_post_rules(state: CombatStateScript, face: DiceFaceDefinitionScript, pre_resource: int, logger: ActionLoggerScript) -> void:
    if state.player.resource.has_type("overload"):
        var post_resource := state.player.resource.current_value
        logger.append(ActionLogEntryScript.new(
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
            logger.append(ActionLogEntryScript.new(
                "overclock_changed",
                state.turn_index,
                state.player.unit_id,
                state.player.unit_id,
                {"face_id": face.face_id, "overclock_charges": state.player.overclock_charges, "source": "overload_capped"}
            ))

func _apply_character_face_passives(state: CombatStateScript, face: DiceFaceDefinitionScript, logger: ActionLoggerScript) -> void:
    if state.player.unit_id == "cyan_ryder" and face.has_tag("ranged"):
        if state.last_ranged_face_id != "" and state.last_ranged_face_id != face.face_id:
            state.cyan_prism_chain += 1
            if state.cyan_prism_chain >= 1:
                state.rerolls_left = min(BASE_REROLLS_PER_TURN, state.rerolls_left + 1)
                state.cyan_prism_chain = 0
                logger.append(ActionLogEntryScript.new(
                    "bonus_roll_granted",
                    state.turn_index,
                    state.player.unit_id,
                    state.player.unit_id,
                    {"face_id": face.face_id, "rerolls_left": state.rerolls_left, "source": "prism_chain"}
                ))
        state.last_ranged_face_id = face.face_id

func _try_pay_cost(state: CombatStateScript, face: DiceFaceDefinitionScript) -> bool:
    if face.cost_type == "none" or face.cost_value <= 0:
        return true
    if not state.player.resource.has_type(face.cost_type):
        return false
    return state.player.resource.spend(face.cost_value)

func _enemy_turn(state: CombatStateScript, rngs: RngStreamsScript, logger: ActionLoggerScript) -> void:
    var intent := _build_enemy_intent(state, rngs)
    if intent.block_value > 0:
        var enemy_block := state.enemy.add_block(intent.block_value)
        logger.append(ActionLogEntryScript.new(
            EVENT_ENEMY_BLOCK,
            state.turn_index,
            state.enemy.unit_id,
            state.enemy.unit_id,
            {
                "value": enemy_block,
                "intent_type": intent.intent_type,
                "intent_source": intent.source,
                "telegraph": intent.telegraph
            }
        ))

    var result := {"blocked": 0, "damage": 0}
    if intent.attack_value > 0:
        var incoming := _equipment_effects.before_enemy_attack(state, intent.attack_value, logger)
        result = state.player.apply_damage(incoming)
        logger.append(ActionLogEntryScript.new(
            EVENT_ENEMY_ATTACK,
            state.turn_index,
            state.enemy.unit_id,
            state.player.unit_id,
            {
                "value": incoming,
                "base_value": intent.attack_value,
                "intent_type": intent.intent_type,
                "intent_source": intent.source,
                "telegraph": intent.telegraph,
                "counter_tag": intent.counter_tag,
                "blocked": result["blocked"],
                "damage": result["damage"],
                "target_hp": state.player.hp
            }
        ))
    if intent.status_type != "":
        _apply_enemy_status_intent(state, intent, logger)
    if state.player.thorns_value > 0 and state.enemy.is_alive():
        var thorns := state.player.thorns_value
        state.player.thorns_value = 0
        var retaliation := state.enemy.apply_damage(thorns)
        logger.append(ActionLogEntryScript.new(
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
        logger.append(ActionLogEntryScript.new(
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

func _build_enemy_intent(state: CombatStateScript, rngs: RngStreamsScript) -> EnemyIntentScript:
    var scripted := _scripted_enemy_intent(state)
    if scripted != null:
        return scripted
    var low := int(_enemy_data.get("atk_low", "6"))
    var high := int(_enemy_data.get("atk_high", "9"))
    var choose_high := rngs.ai_pick(2) == 1
    var value := high if choose_high else low
    var source := "atk_high" if choose_high else "atk_low"
    var every := int(_enemy_data.get("bonus_every_turns", "3"))
    if every > 0 and state.turn_index % every == 0:
        value += int(_enemy_data.get("bonus_flat", "0"))
        source = source + "+bonus"
    return EnemyIntentScript.new(value, source, "attack")

func _scripted_enemy_intent(state: CombatStateScript) -> EnemyIntentScript:
    var rows := _catalog.enemy_intents_for(state.enemy.unit_id)
    if rows.is_empty():
        return null
    var best: Dictionary = {}
    var best_priority := -999999
    var cycle_length := 1
    for row_any in rows:
        var row: Dictionary = row_any
        cycle_length = max(cycle_length, int(row.get("turn_mod", "0")))
    var cycle_slot := ((state.turn_index - 1) % cycle_length) + 1
    for row_any in rows:
        var row: Dictionary = row_any
        var turn_mod := int(row.get("turn_mod", "0"))
        if turn_mod > 0:
            if cycle_slot != turn_mod:
                continue
        elif cycle_slot != cycle_length:
            continue
        var priority := int(row.get("priority", "0"))
        if priority > best_priority:
            best_priority = priority
            best = row
    if best.is_empty():
        best = rows[(state.turn_index - 1) % rows.size()]
    return EnemyIntentScript.new(
        int(best.get("attack_value", "0")),
        String(best.get("intent_type", "scripted")),
        String(best.get("intent_type", "attack")),
        int(best.get("block_value", "0")),
        String(best.get("status_type", "")),
        int(best.get("status_value", "0")),
        String(best.get("telegraph", "")),
        String(best.get("counter_tag", ""))
    )

func _apply_enemy_status_intent(state: CombatStateScript, intent: EnemyIntentScript, logger: ActionLoggerScript) -> void:
    var status_result: Dictionary = {}
    match intent.status_type:
        "lock_die":
            state.player.pending_lock_faces += intent.status_value
            status_result["pending_lock_faces"] = state.player.pending_lock_faces
        "pollute_die":
            state.rerolls_left = max(0, state.rerolls_left - intent.status_value)
            status_result["rerolls_left"] = state.rerolls_left
        "tax_reroll":
            state.rerolls_left = max(0, state.rerolls_left - intent.status_value)
            status_result["rerolls_left"] = state.rerolls_left
        "drain_resource":
            if state.player.resource.resource_type != "none":
                var delta := state.player.resource.apply_delta(-intent.status_value)
                status_result["pre_resource"] = delta["before"]
                status_result["post_resource"] = delta["after"]
                status_result["resource_type"] = state.player.resource.resource_type
        "shed_mark":
            var consumed := state.enemy.consume_all_marks()
            status_result["marks_removed"] = consumed
        "disable_summon":
            var before := int(state.equipment_battle_flags.get("summon_count", 0))
            state.equipment_battle_flags["summon_count"] = max(0, before - intent.status_value)
            status_result["summon_before"] = before
            status_result["summon_after"] = state.equipment_battle_flags["summon_count"]
        _:
            pass
    logger.append(ActionLogEntryScript.new(
        EVENT_ENEMY_DEBUFF,
        state.turn_index,
        state.enemy.unit_id,
        state.player.unit_id,
        {
            "intent_type": intent.intent_type,
            "intent_source": intent.source,
            "status_type": intent.status_type,
            "status_value": intent.status_value,
            "telegraph": intent.telegraph,
            "counter_tag": intent.counter_tag,
            "status_result": status_result
        }
    ))

func _end_turn(state: CombatStateScript, logger: ActionLoggerScript) -> void:
    _equipment_effects.end_turn(state, logger)
    var distinct_types := 0
    for k in state.dice_type_counts.keys():
        if int(state.dice_type_counts.get(k, 0)) > 0:
            distinct_types += 1
    if distinct_types >= 2:
        var healed := state.player.apply_heal(1)
        if healed > 0:
            logger.append(ActionLogEntryScript.new(
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
        if _equipment_effects.prevent_overheat_self_damage(state, logger):
            state.player.temp_ranged_flat = 0
            return
        var burn := state.player.apply_damage(1, 999)
        if int(burn["damage"]) > 0:
            logger.append(ActionLogEntryScript.new(
                "self_damage",
                state.turn_index,
                state.player.unit_id,
                state.player.unit_id,
                {"source": "overheat_burn", "damage": burn["damage"], "hp": state.player.hp}
            ))
            state.player.overclock_charges = max(0, state.player.overclock_charges - 1)
            logger.append(ActionLogEntryScript.new(
                "overclock_changed",
                state.turn_index,
                state.player.unit_id,
                state.player.unit_id,
                {"face_id": "turn_end", "overclock_charges": state.player.overclock_charges, "source": "overheat_decay"}
            ))
    state.player.temp_ranged_flat = 0

func _roll_faces(state: CombatStateScript, rngs: RngStreamsScript, count: int) -> void:
    var die_ids := _active_die_ids(state)
    var pool := _catalog.dice_for_owner(state.player.unit_id, _active_loadout_ids(state))
    if pool.is_empty():
        return
    for _i in range(count):
        if die_ids.is_empty():
            var idx := rngs.roll_dice(0, pool.size() - 1)
            state.rolled_faces.append(pool[idx])
        else:
            var die_idx := rngs.roll_dice(0, die_ids.size() - 1)
            var faces := _catalog.faces_for_die(die_ids[die_idx])
            if faces.is_empty():
                continue
            var face_idx := rngs.roll_dice(0, faces.size() - 1)
            state.rolled_faces.append(faces[face_idx])

func _roll_loadout_dice(state: CombatStateScript, rngs: RngStreamsScript) -> void:
    var die_ids := _active_die_ids(state)
    if die_ids.is_empty():
        _roll_faces(state, rngs, DICE_PER_TURN)
        return
    var turn_die_ids := _choose_turn_die_ids(die_ids, rngs)
    for die_id in turn_die_ids:
        var faces := _catalog.faces_for_die(die_id)
        if faces.is_empty():
            continue
        var idx := rngs.roll_dice(0, faces.size() - 1)
        state.rolled_faces.append(faces[idx])

func _choose_turn_die_ids(die_ids: Array[String], rngs: RngStreamsScript) -> Array[String]:
    var pool := die_ids.duplicate()
    var out: Array[String] = []
    while not pool.is_empty() and out.size() < DICE_PER_TURN:
        var idx := rngs.roll_dice(0, pool.size() - 1)
        out.append(pool[idx])
        pool.remove_at(idx)
    return out

func _pick_best_face(state: CombatStateScript) -> DiceFaceDefinitionScript:
    var best: DiceFaceDefinitionScript = null
    var best_score := -999999
    for face_any in state.rolled_faces:
        var face: DiceFaceDefinitionScript = face_any
        if state.locked_face_ids.has(face.face_id):
            continue
        var score := _face_score(state, face)
        if score > best_score:
            best_score = score
            best = face
    return best

func _face_score(state: CombatStateScript, face: DiceFaceDefinitionScript) -> int:
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
            score += int(missing / 2.0) + (state.player.resource.current_value * 18)
        if face.face_id == "black_guard" and state.player.hp < int(state.player.max_hp * 0.7):
            score += 10
        if face.face_id == "black_parry" and state.player.hp < int(state.player.max_hp * 0.75):
            score += 14
        if face.face_id == "black_reap" and state.player.resource.current_value >= 1:
            score += 9
    return score

func _apply_dice_type_resonance(state: CombatStateScript, face: DiceFaceDefinitionScript, logger: ActionLoggerScript) -> void:
    var d_type := face.die_type
    if d_type == "":
        d_type = "standard"
    var count := int(state.dice_type_counts.get(d_type, 0)) + 1
    state.dice_type_counts[d_type] = count
    if count != 2:
        return

    var payload := {"face_id": face.face_id, "die_type": d_type}
    if d_type == "burst":
        if state.rerolls_left >= BASE_REROLLS_PER_TURN:
            return
        state.rerolls_left = min(BASE_REROLLS_PER_TURN, state.rerolls_left + 1)
        payload["rerolls_left"] = state.rerolls_left
    elif d_type == "setup":
        if state.rerolls_left >= BASE_REROLLS_PER_TURN:
            return
        state.rerolls_left = min(BASE_REROLLS_PER_TURN, state.rerolls_left + 1)
        payload["rerolls_left"] = state.rerolls_left
    elif d_type == "defense":
        var gain := state.player.add_block(2)
        payload["add_block"] = gain
    elif d_type == "finisher":
        state.player.next_attack_ignore_block += 2
        payload["next_attack_ignore_block"] = state.player.next_attack_ignore_block
    else:
        return

    logger.append(ActionLogEntryScript.new(
        "dice_type_resonance",
        state.turn_index,
        state.player.unit_id,
        state.player.unit_id,
        payload
    ))

func _reroll_one(state: CombatStateScript, rngs: RngStreamsScript) -> bool:
    if state.rolled_faces.is_empty():
        return false
    var target_idx := rngs.roll_dice(0, state.rolled_faces.size() - 1)
    var current: DiceFaceDefinitionScript = state.rolled_faces[target_idx]
    var pool := _catalog.faces_for_die(current.die_id)
    if pool.is_empty():
        pool = _catalog.dice_for_owner(state.player.unit_id, _active_loadout_ids(state))
    if pool.is_empty():
        return false
    var next_idx := rngs.roll_dice(0, pool.size() - 1)
    state.rolled_faces[target_idx] = pool[next_idx]
    return true

func _consume_reroll_cost(state: CombatStateScript, logger: Variant) -> void:
    if logger != null and _equipment_effects.should_free_reroll(state, logger):
        return
    if logger == null and _equipment_effects.has_equipment(state, "lucky_knuckle") and bool(state.equipment_battle_flags.get("lucky_knuckle_ready", false)):
        state.equipment_battle_flags["lucky_knuckle_ready"] = false
        return
    state.rerolls_left -= 1

func _active_loadout_ids(state: CombatStateScript) -> Array[String]:
    if not state.player.loadout_die_ids.is_empty():
        return state.player.loadout_die_ids
    return state.player.loadout_face_ids

func _active_die_ids(state: CombatStateScript) -> Array[String]:
    var raw_ids := _active_loadout_ids(state)
    if raw_ids.is_empty():
        return _catalog.die_ids_for_owner(state.player.unit_id, [])
    var out: Array[String] = []
    for id_any in raw_ids:
        var id := String(id_any)
        if not _catalog.faces_for_die(id).is_empty():
            out.append(id)
        else:
            for die_id in _catalog.die_ids_for_owner(state.player.unit_id, [id]):
                out.append(die_id)
    return out
