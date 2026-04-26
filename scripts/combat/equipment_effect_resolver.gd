class_name EquipmentEffectResolver
extends RefCounted

const CombatStateScript = preload("res://scripts/combat/combat_state.gd")
const DiceFaceDefinitionScript = preload("res://scripts/combat/dice_face_definition.gd")
const ActionLoggerScript = preload("res://scripts/core/action_logger.gd")
const ActionLogEntryScript = preload("res://scripts/core/action_log_entry.gd")

const BASE_REROLLS_PER_TURN := 2

func initialize_battle(state: CombatStateScript, equipment_instances: Array, logger: ActionLoggerScript) -> void:
	state.equipment_instances = []
	state.equipment_battle_flags = {}
	state.equipment_turn_flags = {}
	state.player.equipment_attack_flat = 0
	for item_any in equipment_instances:
		if typeof(item_any) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_any.duplicate(true)
		if String(item.get("damage_state", "intact")) == "broken":
			continue
		state.equipment_instances.append(item)
		var equipment_id := String(item.get("equipment_id", ""))
		var damaged := _is_damaged(item)
		match equipment_id:
			"field_jacket":
				var block_gain := state.player.add_block(2 if damaged else 4)
				_log(logger, state, "field_jacket", "battle_start", {"block": block_gain})
			"glass_fang":
				state.player.equipment_attack_flat += 1 if damaged else 2
				_log(logger, state, "glass_fang", "battle_start", {"attack_flat": state.player.equipment_attack_flat})
			"lucky_knuckle":
				state.equipment_battle_flags["lucky_knuckle_ready"] = true
			"micro_drone_dock", "companion_whistle", "emergency_battery":
				state.equipment_battle_flags[equipment_id + "_active_ready"] = true

func before_face(state: CombatStateScript, face: DiceFaceDefinitionScript, effects: Array[Dictionary], logger: ActionLoggerScript) -> void:
	if _has_equipment(state, "throwing_harness") and face.has_tag("finisher") and not bool(state.equipment_battle_flags.get("throwing_harness_used", false)):
		var damaged := _equipment_damaged(state, "throwing_harness")
		state.player.next_attack_ignore_block += 1 if damaged else 3
		state.equipment_battle_flags["throwing_harness_used"] = true
		if state.player.resource.resource_type != "none":
			var delta := state.player.resource.apply_delta(1)
			_log(logger, state, "throwing_harness", "finisher_refund", {"pre_resource": delta["before"], "post_resource": delta["after"], "ignore_block": state.player.next_attack_ignore_block})
	if _has_equipment(state, "heat_sink_plating") and (face.is_negative or face.has_tag("negative") or _effects_have_op(effects, "damage_self")) and not bool(state.equipment_battle_flags.get("heat_sink_used", false)):
		state.equipment_battle_flags["heat_sink_used"] = true
		state.equipment_battle_flags["prevent_next_self_damage"] = true
		_log(logger, state, "heat_sink_plating", "armed", {"face_id": face.face_id})
	if int(state.equipment_battle_flags.get("emergency_battery_strain", 0)) > 0:
		state.equipment_battle_flags["emergency_battery_strain"] = 0
		state.player.next_attack_flat -= 1
		_log(logger, state, "emergency_battery", "strain", {"next_attack_flat": state.player.next_attack_flat})

func after_face(state: CombatStateScript, face: DiceFaceDefinitionScript, effects: Array[Dictionary], pre_block: int, logger: ActionLoggerScript) -> void:
	if face.has_tag("summon"):
		state.equipment_battle_flags["summon_count"] = int(state.equipment_battle_flags.get("summon_count", 0)) + 1
	if _has_equipment(state, "pulse_carbine") and _effects_have_op(effects, "damage_multihit") and not bool(state.equipment_battle_flags.get("pulse_carbine_used", false)):
		state.equipment_battle_flags["pulse_carbine_used"] = true
		_grant_resource(state, 1, logger, "pulse_carbine", "multi_hit_resource")
	if _has_equipment(state, "hunter_scope"):
		_apply_hunter_scope(state, face, logger)
	if _has_equipment(state, "blood_whetstone") and (face.is_negative or face.has_tag("negative") or _effects_have_op(effects, "damage_self")) and not bool(state.equipment_turn_flags.get("blood_whetstone_used", false)):
		state.equipment_turn_flags["blood_whetstone_used"] = true
		state.player.next_attack_flat += 2 if _equipment_damaged(state, "blood_whetstone") else 3
		_log(logger, state, "blood_whetstone", "self_damage_power", {"next_attack_flat": state.player.next_attack_flat})
	if _has_equipment(state, "risk_ledger") and (face.is_negative or face.has_tag("negative")):
		var negatives := int(state.equipment_battle_flags.get("risk_ledger_negatives", 0)) + 1
		state.equipment_battle_flags["risk_ledger_negatives"] = negatives
		if negatives % 2 == 0:
			state.rerolls_left = min(BASE_REROLLS_PER_TURN, state.rerolls_left + 1)
			_log(logger, state, "risk_ledger", "negative_reroll", {"rerolls_left": state.rerolls_left, "negatives": negatives})
	if _has_equipment(state, "iron_banner"):
		var gained: int = max(0, state.player.block - pre_block)
		if gained > 0:
			var total := int(state.equipment_turn_flags.get("block_gained", 0)) + gained
			state.equipment_turn_flags["block_gained"] = total
			if total >= 8 and not bool(state.equipment_battle_flags.get("iron_banner_used", false)):
				state.equipment_battle_flags["iron_banner_used"] = true
				state.player.thorns_value += 2 if _equipment_damaged(state, "iron_banner") else 4
				_log(logger, state, "iron_banner", "counter_ready", {"thorns_value": state.player.thorns_value})

func before_enemy_attack(state: CombatStateScript, incoming: int, logger: ActionLoggerScript) -> int:
	var value := incoming
	if value <= 0:
		return value
	if _has_equipment(state, "spiked_guard") and state.player.block > 0:
		var counter := 1 if _equipment_damaged(state, "spiked_guard") else 2
		var result := state.enemy.apply_damage(counter)
		_log(logger, state, "spiked_guard", "pre_hit_counter", {"damage": result["damage"], "target_hp": state.enemy.hp})
	if _has_equipment(state, "guardian_totem") and int(state.equipment_battle_flags.get("summon_count", 0)) > 0 and not bool(state.equipment_battle_flags.get("guardian_totem_used", false)):
		state.equipment_battle_flags["guardian_totem_used"] = true
		var reduction := int(ceil(float(value) * (0.35 if _equipment_damaged(state, "guardian_totem") else 0.5)))
		value = max(0, value - reduction)
		_log(logger, state, "guardian_totem", "summon_protect", {"reduction": reduction, "incoming_after": value})
	state.equipment_turn_flags["was_attacked"] = true
	return value

func end_turn(state: CombatStateScript, logger: ActionLoggerScript) -> void:
	if _has_equipment(state, "spiked_guard") and not bool(state.equipment_turn_flags.get("was_attacked", false)):
		var loss := mini(state.player.block, 2)
		if loss > 0:
			state.player.block = max(0, state.player.block - loss)
			_log(logger, state, "spiked_guard", "idle_block_loss", {"block_lost": loss, "block": state.player.block})

func prevent_overheat_self_damage(state: CombatStateScript, logger: ActionLoggerScript) -> bool:
	if not _has_equipment(state, "heat_sink_plating") or bool(state.equipment_battle_flags.get("heat_sink_used", false)):
		return false
	state.equipment_battle_flags["heat_sink_used"] = true
	var loss := mini(state.player.block, 2)
	state.player.block = max(0, state.player.block - loss)
	_log(logger, state, "heat_sink_plating", "overheat_prevented", {"block_lost": loss, "block": state.player.block})
	return true

func should_free_reroll(state: CombatStateScript, logger: ActionLoggerScript) -> bool:
	if _has_equipment(state, "lucky_knuckle") and bool(state.equipment_battle_flags.get("lucky_knuckle_ready", false)):
		state.equipment_battle_flags["lucky_knuckle_ready"] = false
		_log(logger, state, "lucky_knuckle", "free_reroll", {"rerolls_left": state.rerolls_left})
		return true
	return false

func active_item_label(state: CombatStateScript) -> String:
	var item := _active_item(state)
	if item.is_empty():
		return "使用道具"
	return "使用 " + String(item.get("display_name", item.get("equipment_id", "道具")))

func can_use_active_item(state: CombatStateScript) -> bool:
	var item := _active_item(state)
	if item.is_empty() or state.battle_ended():
		return false
	return bool(state.equipment_battle_flags.get(String(item.get("equipment_id", "")) + "_active_ready", false))

func use_active_item(state: CombatStateScript, logger: ActionLoggerScript) -> Dictionary:
	var item := _active_item(state)
	if item.is_empty():
		return {"ok": false, "reason": "no_active_item"}
	var equipment_id := String(item.get("equipment_id", ""))
	var key := equipment_id + "_active_ready"
	if not bool(state.equipment_battle_flags.get(key, false)):
		return {"ok": false, "reason": "active_item_used"}
	state.equipment_battle_flags[key] = false
	var damaged := _is_damaged(item)
	match equipment_id:
		"micro_drone_dock":
			state.equipment_battle_flags["summon_count"] = int(state.equipment_battle_flags.get("summon_count", 0)) + 1
			var damage := 1 if damaged else 2
			var result := state.enemy.apply_damage(damage)
			_log(logger, state, equipment_id, "active_drone", {"damage": result["damage"], "summon_count": state.equipment_battle_flags["summon_count"]})
			return {"ok": true, "equipment_id": equipment_id, "effect": "summon_drone"}
		"companion_whistle":
			var base := 2 if damaged else 3
			var bonus := 2 if state.enemy.marks > 0 else 0
			var result := state.enemy.apply_damage(base + bonus)
			_log(logger, state, equipment_id, "active_companion", {"damage": result["damage"], "mark_bonus": bonus})
			return {"ok": true, "equipment_id": equipment_id, "effect": "companion_attack"}
		"emergency_battery":
			_grant_resource(state, 1 if damaged else 2, logger, equipment_id, "active_resource")
			state.equipment_battle_flags["emergency_battery_strain"] = 1
			return {"ok": true, "equipment_id": equipment_id, "effect": "resource_battery"}
	return {"ok": false, "reason": "unsupported_active_item", "equipment_id": equipment_id}

func has_equipment(state: CombatStateScript, equipment_id: String) -> bool:
	return _has_equipment(state, equipment_id)

func _apply_hunter_scope(state: CombatStateScript, face: DiceFaceDefinitionScript, logger: ActionLoggerScript) -> void:
	var damaged := _equipment_damaged(state, "hunter_scope")
	if face.has_tag("mark") and not bool(state.equipment_battle_flags.get("hunter_scope_mark_used", false)):
		state.equipment_battle_flags["hunter_scope_mark_used"] = true
		var amount := 1 if damaged else 2
		state.enemy.add_mark(amount)
		_log(logger, state, "hunter_scope", "mark_boost", {"mark_added": amount, "marks": state.enemy.marks})
	elif face.has_tag("attack") and not bool(state.equipment_battle_flags.get("hunter_scope_attack_used", false)):
		state.equipment_battle_flags["hunter_scope_attack_used"] = true
		state.enemy.add_mark(1)
		_log(logger, state, "hunter_scope", "attack_mark", {"mark_added": 1, "marks": state.enemy.marks})

func _grant_resource(state: CombatStateScript, amount: int, logger: ActionLoggerScript, equipment_id: String, source: String) -> void:
	if state.player.resource.resource_type == "none" or amount == 0:
		return
	var delta := state.player.resource.apply_delta(amount)
	_log(logger, state, equipment_id, source, {"pre_resource": delta["before"], "post_resource": delta["after"], "resource_type": state.player.resource.resource_type})

func _active_item(state: CombatStateScript) -> Dictionary:
	for item_any in state.equipment_instances:
		var item: Dictionary = item_any
		if String(item.get("equip_slot", "")) == "item" and String(item.get("item_mode", "none")) == "active":
			return item
	return {}

func _has_equipment(state: CombatStateScript, equipment_id: String) -> bool:
	for item_any in state.equipment_instances:
		var item: Dictionary = item_any
		if String(item.get("equipment_id", "")) == equipment_id and String(item.get("damage_state", "intact")) != "broken":
			return true
	return false

func _equipment_damaged(state: CombatStateScript, equipment_id: String) -> bool:
	for item_any in state.equipment_instances:
		var item: Dictionary = item_any
		if String(item.get("equipment_id", "")) == equipment_id:
			return _is_damaged(item)
	return false

func _is_damaged(item: Dictionary) -> bool:
	return String(item.get("damage_state", "intact")) == "damaged"

func _effects_have_op(effects: Array[Dictionary], op_type: String) -> bool:
	for effect in effects:
		if String(effect.get("op_type", "")) == op_type:
			return true
	return false

func _log(logger: ActionLoggerScript, state: CombatStateScript, equipment_id: String, trigger: String, payload: Dictionary) -> void:
	var out := payload.duplicate(true)
	out["equipment_id"] = equipment_id
	out["trigger"] = trigger
	logger.append(ActionLogEntryScript.new("equipment_triggered", state.turn_index, state.player.unit_id, state.player.unit_id, out))
