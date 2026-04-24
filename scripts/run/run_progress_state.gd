class_name RunProgressState
extends RefCounted

const CombatUnitScript = preload("res://scripts/combat/combat_unit.gd")

var battle_growths: Array[Dictionary] = []
var run_growths: Array[Dictionary] = []
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

func get_currency(currency_id: String = "credits") -> int:
	return int(currencies.get(currency_id, 0))

func all_growths() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for growth in run_growths:
		out.append(growth)
	for growth in battle_growths:
		out.append(growth)
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
