class_name EnemyIntent
extends RefCounted

var attack_value: int = 0
var block_value: int = 0
var source: String = "basic"
var intent_type: String = "attack"
var status_type: String = ""
var status_value: int = 0
var telegraph: String = ""
var counter_tag: String = ""

func _init(
	p_attack_value: int = 0,
	p_source: String = "basic",
	p_intent_type: String = "attack",
	p_block_value: int = 0,
	p_status_type: String = "",
	p_status_value: int = 0,
	p_telegraph: String = "",
	p_counter_tag: String = ""
) -> void:
	attack_value = max(0, p_attack_value)
	block_value = max(0, p_block_value)
	source = p_source
	intent_type = p_intent_type
	status_type = p_status_type
	status_value = max(0, p_status_value)
	telegraph = p_telegraph
	counter_tag = p_counter_tag
