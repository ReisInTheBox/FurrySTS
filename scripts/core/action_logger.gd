class_name ActionLogger
extends RefCounted

const ActionLogEntryScript = preload("res://scripts/core/action_log_entry.gd")

var _entries: Array[ActionLogEntryScript] = []

func append(entry: ActionLogEntryScript) -> void:
    _entries.append(entry)

func entries() -> Array[ActionLogEntryScript]:
    return _entries.duplicate()
