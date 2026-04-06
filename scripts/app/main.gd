extends Node

func _ready() -> void:
    var runner := preload("res://scripts/tests/smoke_runner.gd").new()
    var result := runner.run()
    if result:
        print("[SMOKE] PASS")
    else:
        push_error("[SMOKE] FAIL")
