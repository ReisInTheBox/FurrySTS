class_name EffectResolver
extends RefCounted

const CombatStateScript = preload("res://scripts/combat/combat_state.gd")
const DiceFaceDefinitionScript = preload("res://scripts/combat/dice_face_definition.gd")
const ActionLoggerScript = preload("res://scripts/core/action_logger.gd")
const ActionLogEntryScript = preload("res://scripts/core/action_log_entry.gd")

func apply_bundle(
	state: CombatStateScript,
	face: DiceFaceDefinitionScript,
	effects: Array[Dictionary],
	logger: ActionLoggerScript
) -> void:
	for effect in effects:
		if String(effect.get("trigger", "")) != "OnDiceResolved":
			continue
		_apply_effect(state, face, effect, logger)

func _apply_effect(
	state: CombatStateScript,
	face: DiceFaceDefinitionScript,
	effect: Dictionary,
	logger: ActionLoggerScript
) -> void:
	var op_type := String(effect.get("op_type", ""))
	match op_type:
		"damage":
			_do_damage(state, face, int(effect.get("value", "0")), 0, logger, [String(effect.get("effect_id", ""))])
		"damage_multihit":
			var parsed := _parse_multihit(String(effect.get("value", "1x1")))
			for _i in range(parsed["hits"]):
				_do_damage(state, face, parsed["base"], 0, logger, [String(effect.get("effect_id", ""))])
		"damage_ignore_block":
			var parts := String(effect.get("value", "0:0")).split(":", false)
			var base := int(parts[0]) if parts.size() > 0 else 0
			var ignore := int(parts[1]) if parts.size() > 1 else 0
			_do_damage(state, face, base, ignore, logger, [String(effect.get("effect_id", ""))])
		"add_block":
			var gain := state.player.add_block(int(effect.get("value", "0")))
			_log_simple(logger, state, "status_applied", state.player.unit_id, state.player.unit_id, face.face_id, {"add_block": gain})
		"mod_resource":
			_mod_resource(state, String(effect.get("value", "")), face, logger)
		"add_temp_ranged_flat":
			state.player.temp_ranged_flat = int(effect.get("value", "0"))
			_log_simple(logger, state, "status_applied", state.player.unit_id, state.player.unit_id, face.face_id, {"temp_ranged_flat": state.player.temp_ranged_flat})
		"conditional_damage_if_resource_ge":
			var cond := String(effect.get("value", "none:0:0")).split(":", false)
			if cond.size() >= 3 and state.player.resource.has_type(cond[0]) and state.player.resource.current_value >= int(cond[1]):
				_do_damage(state, face, int(cond[2]), 0, logger, [String(effect.get("effect_id", ""))])
		"grant_reroll":
			state.rerolls_left += int(effect.get("value", "0"))
			_log_simple(logger, state, "status_applied", state.player.unit_id, state.player.unit_id, face.face_id, {"rerolls_left": state.rerolls_left})
		"grant_bonus_roll":
			state.bonus_rolls += int(effect.get("value", "0"))
			_log_simple(logger, state, "bonus_roll_granted", state.player.unit_id, state.player.unit_id, face.face_id, {"bonus_rolls": state.bonus_rolls})
		"add_mark":
			state.enemy.add_mark(int(effect.get("value", "0")))
			_log_simple(logger, state, "status_applied", state.player.unit_id, state.enemy.unit_id, face.face_id, {"mark": state.enemy.marks})
		"mod_resource_if_marked":
			if state.enemy.marks > 0:
				_mod_resource(state, String(effect.get("value", "")), face, logger)
		"mod_resource_if_mark_ge":
			var mark_cond := String(effect.get("value", "none:0:0")).split(":", false)
			if mark_cond.size() >= 3 and state.enemy.marks >= int(mark_cond[1]):
				_mod_resource(state, mark_cond[0] + ":" + mark_cond[2], face, logger)
		"mod_resource_if_resource_ge":
			var res_cond := String(effect.get("value", "none:0:0")).split(":", false)
			if res_cond.size() >= 3 and state.player.resource.has_type(res_cond[0]) and state.player.resource.current_value >= int(res_cond[1]):
				_mod_resource(state, res_cond[0] + ":" + res_cond[2], face, logger)
		"conditional_bonus_roll_if_resource_ge":
			var br_cond := String(effect.get("value", "none:0:0")).split(":", false)
			if br_cond.size() >= 3 and state.player.resource.has_type(br_cond[0]) and state.player.resource.current_value >= int(br_cond[1]):
				state.bonus_rolls += int(br_cond[2])
				_log_simple(logger, state, "bonus_roll_granted", state.player.unit_id, state.player.unit_id, face.face_id, {"bonus_rolls": state.bonus_rolls})
		"set_next_attack_mult":
			state.player.next_attack_mult = float(effect.get("value", "1.0"))
			_log_simple(logger, state, "status_applied", state.player.unit_id, state.player.unit_id, face.face_id, {"next_attack_mult": state.player.next_attack_mult})
		"set_next_attack_ignore_block":
			state.player.next_attack_ignore_block = int(effect.get("value", "0"))
			_log_simple(logger, state, "status_applied", state.player.unit_id, state.player.unit_id, face.face_id, {"next_attack_ignore_block": state.player.next_attack_ignore_block})
		"add_rupture":
			state.enemy.rupture_bonus = int(effect.get("value", "0"))
			_log_simple(logger, state, "status_applied", state.player.unit_id, state.enemy.unit_id, face.face_id, {"rupture_bonus": state.enemy.rupture_bonus})
		"conditional_block_if_resource_ge":
			var c := String(effect.get("value", "none:0:0")).split(":", false)
			if c.size() >= 3 and state.player.resource.has_type(c[0]) and state.player.resource.current_value >= int(c[1]):
				var bonus := state.player.add_block(int(c[2]))
				_log_simple(logger, state, "status_applied", state.player.unit_id, state.player.unit_id, face.face_id, {"add_block": bonus})
		"consume_mark_to_damage":
			var consume := String(effect.get("value", "0:0")).split(":", false)
			var per_mark := int(consume[0]) if consume.size() > 0 else 0
			var mark_cap := int(consume[1]) if consume.size() > 1 else 99
			var consumed: int = int(min(mark_cap, state.enemy.consume_all_marks()))
			if consumed > 0:
				_do_damage(state, face, consumed * per_mark, 0, logger, [String(effect.get("effect_id", ""))])
				_log_simple(logger, state, "mark_consumed", state.player.unit_id, state.enemy.unit_id, face.face_id, {"consumed_marks": consumed, "bonus_damage": consumed * per_mark})
		"set_thorns":
			state.player.thorns_value = max(0, int(effect.get("value", "0")))
			_log_simple(logger, state, "status_applied", state.player.unit_id, state.player.unit_id, face.face_id, {"thorns_value": state.player.thorns_value})
		"damage_self":
			var self_damage: int = int(max(0, int(effect.get("value", "0"))))
			var self_result := state.player.apply_damage(self_damage, 999)
			_log_simple(logger, state, "self_damage", state.player.unit_id, state.player.unit_id, face.face_id, {"value": self_damage, "damage": self_result["damage"], "self_hp": state.player.hp})
		_:
			push_warning("Unsupported op_type: " + op_type)

func _do_damage(
	state: CombatStateScript,
	face: DiceFaceDefinitionScript,
	base_damage: int,
	ignore_block: int,
	logger: ActionLoggerScript,
	source_effect_ids: Array[String]
) -> void:
	var unit_id := state.player.unit_id
	var face_bonus_flat := 0
	if unit_id == "cyan_ryder" and face.has_tag("ranged") and state.player.overclock_charges > 0:
		state.player.overclock_charges -= 1
		state.bonus_rolls += 1
		face_bonus_flat += 4
		_log_simple(
			logger,
			state,
			"overclock_changed",
			unit_id,
			unit_id,
			face.face_id,
			{"overclock_charges": state.player.overclock_charges, "bonus_rolls": state.bonus_rolls}
		)

	var mark_bonus := state.enemy.consume_mark_on_hit()
	var ranged_bonus := state.player.temp_ranged_flat if face.has_tag("ranged") else 0
	var overload_bonus := 0
	if face.has_tag("ranged") and state.player.resource.has_type("overload"):
		overload_bonus = state.player.resource.current_value * 2
	var rupture_bonus := state.enemy.rupture_bonus
	var execute_bonus := 0
	var spent_stance := 0
	var charged_mult := state.player.next_attack_mult
	if unit_id == "helios_windchaser" and (face.face_id == "helios_sniper" or face.face_id == "helios_pierce"):
		var focus_used: int = int(min(3, state.player.focus_stacks))
		if focus_used > 0:
			state.player.focus_stacks -= focus_used
			charged_mult *= (1.0 + (0.25 * focus_used))
			_log_simple(
				logger,
				state,
				"focus_changed",
				unit_id,
				unit_id,
				face.face_id,
				{"focus_stacks": state.player.focus_stacks, "focus_used": focus_used}
			)
			if focus_used >= 2 and state.player.resource.has_type("quiver"):
				var q := state.player.resource.apply_delta(1)
				_log_simple(
					logger,
					state,
					"resource_changed",
					unit_id,
					unit_id,
					face.face_id,
					{"pre_resource": q["before"], "post_resource": q["after"], "resource_type": "quiver", "source": "focus_refund"}
				)
	if unit_id == "umbral_draxx" and (face.face_id == "black_execute" or face.face_id == "black_reap"):
		execute_bonus = int((state.enemy.max_hp - state.enemy.hp) / 4.0)
		if state.player.resource.has_type("stance"):
			spent_stance = state.player.resource.current_value
			if spent_stance > 0:
				var s := state.player.resource.apply_delta(-spent_stance)
				_log_simple(
					logger,
					state,
					"resource_changed",
					unit_id,
					unit_id,
					face.face_id,
					{"pre_resource": s["before"], "post_resource": s["after"], "resource_type": "stance", "source": "execute_spend_all"}
				)

	var flat_total := base_damage + mark_bonus + ranged_bonus + overload_bonus + rupture_bonus + face_bonus_flat + execute_bonus + (spent_stance * 3)
	var multiplied := int(round(flat_total * charged_mult * state.player.power_mul))
	var ignore_total := ignore_block + state.player.next_attack_ignore_block + (spent_stance * 2)
	var result := state.enemy.apply_damage(multiplied, ignore_total)
	state.player.next_attack_mult = 1.0
	state.player.next_attack_ignore_block = 0
	state.enemy.rupture_bonus = 0

	if unit_id == "helios_windchaser" and mark_bonus > 0:
		state.player.focus_stacks = min(3, state.player.focus_stacks + mark_bonus)
		_log_simple(
			logger,
			state,
			"focus_changed",
			unit_id,
			unit_id,
			face.face_id,
			{"focus_stacks": state.player.focus_stacks, "focus_gained": mark_bonus}
		)

	logger.append(ActionLogEntryScript.new(
		"player_attack",
		state.turn_index,
		state.player.unit_id,
		state.enemy.unit_id,
		{
			"face_id": face.face_id,
			"damage_breakdown": {
				"base": base_damage,
				"mark_bonus": mark_bonus,
				"ranged_bonus": ranged_bonus,
				"overload_bonus": overload_bonus,
				"rupture_bonus": rupture_bonus,
				"face_bonus_flat": face_bonus_flat,
				"execute_bonus": execute_bonus,
				"spent_stance": spent_stance,
				"multiplier": state.player.power_mul,
				"next_attack_mult": charged_mult
			},
			"value": multiplied,
			"blocked": result["blocked"],
			"damage": result["damage"],
			"target_hp": state.enemy.hp,
			"source_effect_ids": source_effect_ids
		}
	))

func _mod_resource(state: CombatStateScript, spec: String, face: DiceFaceDefinitionScript, logger: ActionLoggerScript) -> void:
	var parts := spec.split(":", false)
	if parts.size() < 2:
		return
	var t := parts[0]
	if not state.player.resource.has_type(t):
		return
	var delta := int(parts[1])
	var r := state.player.resource.apply_delta(delta)
	_log_simple(
		logger,
		state,
		"resource_changed",
		state.player.unit_id,
		state.player.unit_id,
		face.face_id,
		{"pre_resource": r["before"], "post_resource": r["after"], "resource_type": t}
	)

func _parse_multihit(text: String) -> Dictionary:
	var parts := text.split("x", false)
	var base := int(parts[0]) if parts.size() > 0 else 1
	var hits := int(parts[1]) if parts.size() > 1 else 1
	return {"base": base, "hits": max(1, hits)}

func _log_simple(
	logger: ActionLoggerScript,
	state: CombatStateScript,
	event_type: String,
	actor_id: String,
	target_id: String,
	face_id: String,
	payload: Dictionary
) -> void:
	var out := payload.duplicate()
	out["face_id"] = face_id
	logger.append(ActionLogEntryScript.new(event_type, state.turn_index, actor_id, target_id, out))
