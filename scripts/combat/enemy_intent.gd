class_name EnemyIntent
extends RefCounted

var attack_value: int = 0
var source: String = "basic"

func _init(p_attack_value: int = 0, p_source: String = "basic") -> void:
	attack_value = max(0, p_attack_value)
	source = p_source
