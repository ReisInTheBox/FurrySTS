class_name RunProgressState
extends RefCounted

const CombatUnitScript = preload("res://scripts/combat/combat_unit.gd")

var battle_growths: Array[Dictionary] = []
var run_growths: Array[Dictionary] = []
var build_changes: Array[Dictionary] = []
var enchant_bindings: Array[Dictionary] = []
var granted_growth_ids: Dictionary = {}
var currencies: Dictionary = {}

func add_growth(growth: Dictionary) -> void:
	var growth_id := String(growth.get("growth_id", ""))
	var grant_once := String(growth.get("grant_once", "false")) == "true"
	if grant_once and growth_id != "" and granted_growth_ids.has(growth_id):
		return
	var scope := String(growth.get("duration_scope", "battle"))
	if scope == "run":
		run_growths.append(growth)
	else:
		battle_growths.append(growth)
	if grant_once and growth_id != "":
		granted_growth_ids[growth_id] = true

func apply_all_to_unit(unit: CombatUnitScript, consume_battle_growths: bool = false) -> void:
	for growth in run_growths:
		_apply_growth(unit, growth)
	for growth in battle_growths:
		_apply_growth(unit, growth)
	for change in build_changes:
		_apply_build_change(unit, change)
	unit.enchant_bindings = _valid_enchant_bindings_for_unit(unit)
	if consume_battle_growths:
		battle_growths.clear()

func clear_battle_growths() -> void:
	battle_growths.clear()

func clear_run_growths() -> void:
	run_growths.clear()

func add_currency(currency_id: String, amount: int) -> int:
	var key := currency_id.strip_edges()
	if key == "":
		key = "credits"
	var before := int(currencies.get(key, 0))
	var after: int = max(0, before + amount)
	currencies[key] = after
	return after

func spend_currency(currency_id: String, amount: int) -> bool:
	var key := currency_id.strip_edges()
	if key == "":
		key = "credits"
	var cost: int = max(0, amount)
	var before := int(currencies.get(key, 0))
	if before < cost:
		return false
	currencies[key] = before - cost
	return true

func get_currency(currency_id: String = "credits") -> int:
	return int(currencies.get(currency_id, 0))

func all_growths() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for growth in run_growths:
		out.append(growth)
	for growth in battle_growths:
		out.append(growth)
	return out

func add_build_change(change: Dictionary) -> void:
	build_changes.append(change.duplicate())
	_cleanup_enchants_for_build_change(change)

func all_build_changes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for change in build_changes:
		out.append(change.duplicate())
	return out

func grant_enchant(binding: Dictionary) -> Dictionary:
	var normalized := _normalized_enchant_binding(binding)
	if normalized.is_empty():
		return {"ok": false, "reason": "invalid_enchant_binding"}
	var idx := _find_enchant_slot(int(normalized["face_index"]), String(normalized["die_id"]))
	if idx >= 0:
		return {"ok": false, "reason": "duplicate_enchant_slot", "binding": normalized}
	enchant_bindings.append(normalized)
	return {"ok": true, "binding": normalized}

func replace_enchant(binding: Dictionary) -> Dictionary:
	var normalized := _normalized_enchant_binding(binding)
	if normalized.is_empty():
		return {"ok": false, "reason": "invalid_enchant_binding"}
	var idx := _find_enchant_slot(int(normalized["face_index"]), String(normalized["die_id"]))
	if idx >= 0:
		enchant_bindings[idx] = normalized
	else:
		enchant_bindings.append(normalized)
	return {"ok": true, "binding": normalized}

func remove_enchant(die_id: String, face_index: int) -> Dictionary:
	var idx := _find_enchant_slot(face_index, die_id)
	if idx < 0:
		return {"ok": false, "reason": "missing_enchant_slot", "die_id": die_id, "face_index": face_index}
	var removed: Dictionary = enchant_bindings[idx]
	enchant_bindings.remove_at(idx)
	return {"ok": true, "removed": removed}

func all_enchant_bindings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for binding in enchant_bindings:
		out.append(binding.duplicate(true))
	return out

func _apply_growth(unit: CombatUnitScript, growth: Dictionary) -> void:
	var growth_type := String(growth.get("type", ""))
	var target := String(growth.get("target", ""))
	var delta := int(growth.get("delta", "0"))

	if growth_type == "stat":
		if target == "base_hp":
			unit.max_hp = max(1, unit.max_hp + delta)
			unit.hp = min(unit.max_hp, unit.hp + max(delta, 0))
		elif target == "block":
			unit.block = max(0, unit.block + delta)
	elif growth_type == "resource":
		if target == "resource_cap" or target == unit.resource.resource_type + "_cap":
			unit.resource.cap_value = max(0, unit.resource.cap_value + delta)
			unit.resource.current_value = clamp(unit.resource.current_value, 0, unit.resource.cap_value)
		elif unit.resource.has_type(target):
			unit.resource.apply_delta(delta)
	elif growth_type == "combat":
		if target == "temp_ranged_flat":
			unit.temp_ranged_flat = max(0, unit.temp_ranged_flat + delta)

func _apply_build_change(unit: CombatUnitScript, change: Dictionary) -> void:
	var change_type := String(change.get("change_type", ""))
	match change_type:
		"add_die":
			var die_id := String(change.get("die_id", ""))
			if die_id != "":
				unit.loadout_die_ids.append(die_id)
		"replace_die":
			var from_die := String(change.get("from_die_id", ""))
			var to_die := String(change.get("to_die_id", ""))
			if from_die != "" and to_die != "":
				var idx := unit.loadout_die_ids.find(from_die)
				if idx >= 0:
					unit.loadout_die_ids[idx] = to_die
		"remove_negative":
			var die_id := String(change.get("die_id", ""))
			var fallback_die := String(change.get("fallback_die_id", ""))
			if die_id != "" and fallback_die != "":
				var idx := unit.loadout_die_ids.find(die_id)
				if idx >= 0:
					unit.loadout_die_ids[idx] = fallback_die
		"upgrade_die":
			var base_die := String(change.get("base_die_id", ""))
			var upgraded_die := String(change.get("upgraded_die_id", ""))
			if base_die != "" and upgraded_die != "":
				var idx := unit.loadout_die_ids.find(base_die)
				if idx >= 0:
					unit.loadout_die_ids[idx] = upgraded_die

func _normalized_enchant_binding(binding: Dictionary) -> Dictionary:
	var die_id := String(binding.get("die_id", "")).strip_edges()
	var face_index := int(binding.get("face_index", "0"))
	var enchant_id := String(binding.get("enchant_id", "")).strip_edges()
	if die_id == "" or enchant_id == "" or face_index < 1 or face_index > 6:
		return {}
	return {
		"die_id": die_id,
		"face_index": face_index,
		"enchant_id": enchant_id,
		"source": String(binding.get("source", "reward")),
		"grant_run_id": String(binding.get("grant_run_id", "current_run"))
	}

func _find_enchant_slot(face_index: int, die_id: String) -> int:
	for i in range(enchant_bindings.size()):
		var binding: Dictionary = enchant_bindings[i]
		if String(binding.get("die_id", "")) == die_id and int(binding.get("face_index", "0")) == face_index:
			return i
	return -1

func _valid_enchant_bindings_for_unit(unit: CombatUnitScript) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for binding_any in enchant_bindings:
		var binding: Dictionary = binding_any
		if unit.loadout_die_ids.has(String(binding.get("die_id", ""))):
			out.append(binding.duplicate(true))
	return out

func _cleanup_enchants_for_build_change(change: Dictionary) -> void:
	var die_ids: Array[String] = []
	match String(change.get("change_type", "")):
		"replace_die":
			die_ids.append(String(change.get("from_die_id", "")))
		"remove_negative":
			die_ids.append(String(change.get("die_id", "")))
		"upgrade_die":
			die_ids.append(String(change.get("base_die_id", "")))
	for die_id in die_ids:
		if die_id == "":
			continue
		for i in range(enchant_bindings.size() - 1, -1, -1):
			var binding: Dictionary = enchant_bindings[i]
			if String(binding.get("die_id", "")) == die_id:
				enchant_bindings.remove_at(i)
