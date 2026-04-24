extends Control

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const HubStateScript = preload("res://scripts/hub/hub_state.gd")
const HubVisualizerScene = preload("res://scenes/hub_visualizer.tscn")
const RunVisualizerScene = preload("res://scenes/run_visualizer.tscn")

var _hub_state: HubStateScript = HubStateScript.new()
var _active_view: Control
var _run_seed_counter: int = 0
var _loader: ContentLoaderScript = ContentLoaderScript.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_hub_state.ensure_content(_loader)
	_show_hub()

func _show_hub() -> void:
	var hub_view := HubVisualizerScene.instantiate()
	hub_view.configure_hub(_hub_state)
	_swap_view(hub_view)
	_active_view.start_run_requested.connect(_on_start_run_requested)

func _show_run(hero_id: String) -> void:
	_run_seed_counter += 1
	var seed_value := 20260430 + _run_seed_counter
	var run_view := RunVisualizerScene.instantiate()
	run_view.configure_run(hero_id, seed_value, _hub_state.run_setup_for_selected_hero())
	_swap_view(run_view)
	_active_view.run_finished.connect(_on_run_finished)

func _swap_view(view: Control) -> void:
	if _active_view != null:
		_active_view.queue_free()
	_active_view = view
	add_child(_active_view)

func _on_start_run_requested(hero_id: String) -> void:
	_show_run(hero_id)

func _on_run_finished(result: Dictionary) -> void:
	_hub_state.apply_run_result(result)
	_show_hub()
