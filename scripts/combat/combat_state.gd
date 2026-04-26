class_name CombatState
extends RefCounted

const CombatUnitScript = preload("res://scripts/combat/combat_unit.gd")
const DiceFaceDefinitionScript = preload("res://scripts/combat/dice_face_definition.gd")

var turn_index: int = 1
var player: CombatUnitScript
var enemy: CombatUnitScript
var rolled_faces: Array[DiceFaceDefinitionScript] = []
var locked_face_ids: Array[String] = []
var picks_budget: int = 3
var picks_used: int = 0
var rerolls_left: int = 2
var bonus_rolls: int = 0
var last_ranged_face_id: String = ""
var cyan_prism_chain: int = 0
var dice_type_counts: Dictionary = {}
var equipment_instances: Array[Dictionary] = []
var equipment_battle_flags: Dictionary = {}
var equipment_turn_flags: Dictionary = {}

func _init(p_player: CombatUnitScript, p_enemy: CombatUnitScript) -> void:
    player = p_player
    enemy = p_enemy

func battle_ended() -> bool:
    return (not player.is_alive()) or (not enemy.is_alive())

func reset_turn_state() -> void:
    rolled_faces = []
    locked_face_ids = []
    picks_budget = 0
    picks_used = 0
    rerolls_left = 2
    bonus_rolls = 0
    last_ranged_face_id = ""
    cyan_prism_chain = 0
    dice_type_counts = {}
    equipment_turn_flags = {}
