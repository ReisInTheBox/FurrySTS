extends Node

func _ready() -> void:
    var runner := preload("res://scripts/tests/smoke_runner.gd").new()
    var result := runner.run()
    if result:
        print("[SMOKE] PASS")
    else:
        push_error("[SMOKE] FAIL")

    # Keep smoke as startup gate, then show the Hub -> Run root flow in non-headless mode.
    if DisplayServer.get_name() == "headless":
        return

    var root_flow_scene: PackedScene = preload("res://scenes/root_flow.tscn")
    add_child(root_flow_scene.instantiate())
