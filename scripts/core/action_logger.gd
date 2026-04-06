class_name ActionLogger
extends RefCounted

const ActionLogEntry = preload("res://scripts/core/action_log_entry.gd")

var _entries: Array[ActionLogEntry] = []

func append(entry: ActionLogEntry) -> void:
    _entries.append(entry)

func entries() -> Array[ActionLogEntry]:
    return _entries.duplicate()
