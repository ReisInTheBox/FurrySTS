extends Control

signal run_finished(result: Dictionary)

const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const RunSimulatorScript = preload("res://scripts/run/run_simulator.gd")
const BattleVisualizerScene = preload("res://scenes/battle_visualizer.tscn")

const MASTER_SEED := 20260430
const HERO_ID := "cyan_ryder"

var _loader: ContentLoaderScript
var _simulator: RunSimulatorScript
var _run_state
var _rngs
var _active_battle: Control

var _seed_label: Label
var _summary_label: Label
var _hero_label: Label
var _status_row: HBoxContainer
var _route_flow: HFlowContainer
var _route_hint_label: Label
var _current_node_label: Label
var _current_node_badge: Label
var _detail_label: Label
var _node_hint_label: Label
var _feedback_label: Label
var _reward_panel: PanelContainer
var _reward_row: HBoxContainer
var _node_result_panel: PanelContainer
var _node_result_title: Label
var _node_result_detail: Label
var _node_result_continue_btn: Button
var _log_view: RichTextLabel
var _resolve_btn: Button
var _evac_btn: Button
var _new_run_btn: Button
var _root_layout: Control
var _master_seed: int = MASTER_SEED
var _run_hero_id: String = HERO_ID
var _run_setup: Dictionary = {}

func configure_run(hero_id: String = HERO_ID, master_seed: int = MASTER_SEED, setup: Dictionary = {}) -> void:
	if hero_id.strip_edges() != "":
		_run_hero_id = hero_id
	_master_seed = master_seed
	_run_setup = setup.duplicate(true)

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()
	_start_run()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0.035, 0.045, 0.07, 1.0)
	add_child(bg)

	var glow_top := ColorRect.new()
	glow_top.anchor_right = 1.0
	glow_top.color = Color(0.07, 0.13, 0.2, 0.18)
	glow_top.custom_minimum_size = Vector2(0, 220)
	glow_top.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(glow_top)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 20)
	root.add_theme_constant_override("margin_right", 20)
	root.add_theme_constant_override("margin_top", 16)
	root.add_theme_constant_override("margin_bottom", 16)
	add_child(root)

	var page := VBoxContainer.new()
	page.size_flags_horizontal = SIZE_EXPAND_FILL
	page.size_flags_vertical = SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	root.add_child(page)
	_root_layout = page

	page.add_child(_build_header())

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	page.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	content.add_child(_build_status_strip())
	content.add_child(_build_route_panel())
	content.add_child(_build_current_node_panel())
	content.add_child(_build_log_panel())

	page.add_child(_build_action_bar())

func _build_header() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.08, 0.11, 0.18), Color(0.28, 0.42, 0.66), 14))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 4)
	row.add_child(title_box)

	var title := Label.new()
	title.text = "FurrySTS Run 原型"
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color(0.96, 0.98, 1.0)
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "线性推进，不做分支选择。当前重点是验证节点节奏、奖励闭环和撤离判断。"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	subtitle.modulate = Color(0.75, 0.84, 0.96)
	title_box.add_child(subtitle)

	var meta_box := VBoxContainer.new()
	meta_box.alignment = BoxContainer.ALIGNMENT_CENTER
	meta_box.add_theme_constant_override("separation", 6)
	row.add_child(meta_box)

	_seed_label = Label.new()
	_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_seed_label.modulate = Color(0.88, 0.92, 1.0)
	meta_box.add_child(_seed_label)

	_hero_label = Label.new()
	_hero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hero_label.modulate = Color(0.95, 0.82, 0.66)
	meta_box.add_child(_hero_label)

	return panel

func _build_status_strip() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.08, 0.095, 0.13), Color(0.2, 0.28, 0.42), 12))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_summary_label.modulate = Color(0.82, 0.9, 1.0)
	v.add_child(_summary_label)

	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 10)
	v.add_child(_status_row)

	return panel

func _build_route_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.075, 0.085, 0.12), Color(0.23, 0.34, 0.52), 14))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	v.add_child(title_row)

	var title := Label.new()
	title.text = "路线预览"
	title.add_theme_font_size_override("font_size", 19)
	title.modulate = Color(0.96, 0.98, 1.0)
	title_row.add_child(title)

	_route_hint_label = Label.new()
	_route_hint_label.text = "只读预览，不可点击。"
	_route_hint_label.modulate = Color(0.78, 0.86, 1.0)
	title_row.add_child(_route_hint_label)

	_route_flow = HFlowContainer.new()
	_route_flow.add_theme_constant_override("h_separation", 10)
	_route_flow.add_theme_constant_override("v_separation", 10)
	v.add_child(_route_flow)

	return panel

func _build_current_node_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.09, 0.1, 0.15), Color(0.25, 0.36, 0.56), 16))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	v.add_child(top_row)

	_current_node_label = Label.new()
	_current_node_label.add_theme_font_size_override("font_size", 22)
	_current_node_label.modulate = Color(0.97, 0.98, 1.0)
	_current_node_label.size_flags_horizontal = SIZE_EXPAND_FILL
	top_row.add_child(_current_node_label)

	_current_node_badge = Label.new()
	_current_node_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_current_node_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_current_node_badge.custom_minimum_size = Vector2(110, 28)
	top_row.add_child(_current_node_badge)

	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_label.modulate = Color(0.82, 0.88, 0.98)
	v.add_child(_detail_label)

	_node_hint_label = Label.new()
	_node_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_node_hint_label.modulate = Color(0.92, 0.82, 0.68)
	v.add_child(_node_hint_label)

	_feedback_label = Label.new()
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_feedback_label.modulate = Color(0.97, 0.88, 0.74)
	v.add_child(_feedback_label)

	_node_result_panel = PanelContainer.new()
	_node_result_panel.visible = false
	_node_result_panel.add_theme_stylebox_override("panel", _style_panel(Color(0.08, 0.13, 0.11), Color(0.44, 0.8, 0.62), 12))
	v.add_child(_node_result_panel)

	var result_v := VBoxContainer.new()
	result_v.add_theme_constant_override("separation", 8)
	_node_result_panel.add_child(result_v)

	_node_result_title = Label.new()
	_node_result_title.text = "节点结算"
	_node_result_title.add_theme_font_size_override("font_size", 17)
	_node_result_title.modulate = Color(0.9, 1.0, 0.94)
	result_v.add_child(_node_result_title)

	_node_result_detail = Label.new()
	_node_result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	_node_result_detail.modulate = Color(0.82, 0.94, 0.88)
	result_v.add_child(_node_result_detail)

	_node_result_continue_btn = Button.new()
	_node_result_continue_btn.text = "继续路线"
	_node_result_continue_btn.pressed.connect(_on_node_result_continue_pressed)
	result_v.add_child(_node_result_continue_btn)

	_reward_panel = PanelContainer.new()
	_reward_panel.visible = false
	_reward_panel.add_theme_stylebox_override("panel", _style_panel(Color(0.14, 0.11, 0.07), Color(0.72, 0.6, 0.26), 12))
	v.add_child(_reward_panel)

	var reward_v := VBoxContainer.new()
	reward_v.add_theme_constant_override("separation", 8)
	_reward_panel.add_child(reward_v)

	var reward_title := Label.new()
	reward_title.text = "节点奖励"
	reward_title.add_theme_font_size_override("font_size", 17)
	reward_title.modulate = Color(1.0, 0.95, 0.86)
	reward_v.add_child(reward_title)

	_reward_row = HBoxContainer.new()
	_reward_row.add_theme_constant_override("separation", 8)
	reward_v.add_child(_reward_row)

	return panel

func _build_action_bar() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.08, 0.095, 0.13), Color(0.55, 0.62, 0.82), 12))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var hint := Label.new()
	hint.text = "操作栏固定在底部：推进节点、撤离或重新开始 Run。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.size_flags_horizontal = SIZE_EXPAND_FILL
	hint.modulate = Color(0.82, 0.9, 1.0)
	row.add_child(hint)

	_new_run_btn = Button.new()
	_new_run_btn.text = "? Run"
	_new_run_btn.custom_minimum_size = Vector2(110, 42)
	_new_run_btn.pressed.connect(_start_run)
	row.add_child(_new_run_btn)

	_resolve_btn = Button.new()
	_resolve_btn.text = "推进当前节点"
	_resolve_btn.custom_minimum_size = Vector2(150, 42)
	_resolve_btn.pressed.connect(_on_resolve_pressed)
	row.add_child(_resolve_btn)

	_evac_btn = Button.new()
	_evac_btn.text = "立即撤离"
	_evac_btn.custom_minimum_size = Vector2(110, 42)
	_evac_btn.pressed.connect(_on_evac_pressed)
	row.add_child(_evac_btn)
	return panel

func _build_log_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 180)
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.045, 0.055, 0.09), Color(0.2, 0.28, 0.42), 12))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = "推进记录"
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(0.93, 0.96, 1.0)
	v.add_child(title)

	_log_view = RichTextLabel.new()
	_log_view.bbcode_enabled = false
	_log_view.scroll_following = true
	_log_view.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(_log_view)

	return panel

func _start_run() -> void:
	if _active_battle != null:
		_active_battle.queue_free()
		_active_battle = null
	_loader = ContentLoaderScript.new()
	_simulator = RunSimulatorScript.new(_loader)
	var bundle: Dictionary = _simulator.create_run(_master_seed, _run_hero_id, 13, _run_setup)
	_run_state = bundle["state"]
	_rngs = bundle["rngs"]
	_hide_node_result_panel()
	_feedback_label.text = "Run 已初始化，准备推进第一处节点。"
	_render_ui()

func _render_ui() -> void:
	if _run_state == null:
		return

	_seed_label.text = "Seed %d" % _master_seed
	_hero_label.text = "主出战：%s" % _hero_name(_run_state.hero_id)
	_summary_label.text = "已清理 %d 个节点，当前持有 %d Credits，已获得 %d 项成长。" % [
		_run_state.nodes_cleared(),
		_run_state.progress.get_currency("credits"),
		_run_state.progress.all_growths().size()
	]

	_render_status_cards()
	_render_route_nodes()
	_current_node_label.text = _current_node_title()
	_current_node_badge.text = _node_type_name(_current_node_type())
	_current_node_badge.add_theme_color_override("font_color", _node_colors(_current_node_type())["text"])
	_current_node_badge.add_theme_font_size_override("font_size", 15)
	_detail_label.text = _current_node_detail()
	_node_hint_label.text = _current_node_hint()
	_render_rewards()
	_render_log()

	var battle_open := _active_battle != null
	var node_result_open: bool = _node_result_active()
	_resolve_btn.disabled = battle_open or node_result_open or _run_state.completed or not _run_state.pending_reward_choices.is_empty()
	_evac_btn.disabled = battle_open or node_result_open or not _run_state.can_evac()
	_new_run_btn.disabled = battle_open

func _render_status_cards() -> void:
	for child in _status_row.get_children():
		child.queue_free()

	var cards := [
		{"title": "当前状态", "value": _run_state.result.result_type, "color": Color(0.47, 0.76, 0.98)},
		{"title": "当前进度", "value": "%d / %d" % [_run_state.current_node_index + 1 if not _run_state.completed else _run_state.route_nodes.size(), _run_state.route_nodes.size()], "color": Color(0.48, 0.86, 0.64)},
		{"title": "可撤离", "value": "是" if _run_state.can_evac() else "否", "color": Color(0.98, 0.74, 0.46)},
		{"title": "待选奖励", "value": str(_run_state.pending_reward_choices.size()), "color": Color(0.87, 0.67, 0.98)}
	]
	for data_any in cards:
		var data: Dictionary = data_any
		var card := PanelContainer.new()
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 70)
		card.add_theme_stylebox_override("panel", _style_panel(Color(0.1, 0.11, 0.16), Color(data["color"]), 10))
		_status_row.add_child(card)

		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		card.add_child(v)

		var title := Label.new()
		title.text = str(data.get("title", ""))
		title.modulate = Color(0.74, 0.82, 0.94)
		v.add_child(title)

		var value := Label.new()
		value.text = str(data.get("value", ""))
		value.add_theme_font_size_override("font_size", 18)
		value.modulate = Color(0.96, 0.98, 1.0)
		v.add_child(value)

func _render_route_nodes() -> void:
	for child in _route_flow.get_children():
		child.queue_free()

	if not _run_state.route_layers.is_empty():
		for layer_any in _run_state.route_layers:
			var layer: Array = layer_any
			if layer.is_empty():
				continue
			var layer_box := VBoxContainer.new()
			layer_box.custom_minimum_size = Vector2(178, 0)
			layer_box.add_theme_constant_override("separation", 6)
			_route_flow.add_child(layer_box)

			var first: Dictionary = layer[0]
			var layer_label := Label.new()
			layer_label.text = "Layer %02d" % int(first.get("layer_index", 0))
			layer_label.modulate = Color(0.72, 0.82, 0.96)
			layer_box.add_child(layer_label)

			for node_any in layer:
				var node: Dictionary = node_any
				layer_box.add_child(_build_route_node_button(node))
		return

	for i in range(_run_state.route_nodes.size()):
		var node: Dictionary = _run_state.route_nodes[i]
		var node_type := String(node.get("node_type", ""))
		var colors := _node_colors(node_type)
		var state_label := "后续"
		if i < _run_state.current_node_index:
			state_label = "已完成"
		elif i == _run_state.current_node_index and not _run_state.completed:
			state_label = "当前"
		elif _run_state.completed and i == _run_state.route_nodes.size() - 1:
			state_label = "终点"

		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(145, 92)
		chip.add_theme_stylebox_override("panel", _style_panel(colors["bg"], colors["border"], 12))
		_route_flow.add_child(chip)

		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		chip.add_child(v)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 6)
		v.add_child(header)

		var index_label := Label.new()
		index_label.text = "#%d" % (i + 1)
		index_label.modulate = colors["text"]
		header.add_child(index_label)

		var type_label := Label.new()
		type_label.text = _node_type_name(node_type)
		type_label.modulate = Color(0.97, 0.98, 1.0)
		type_label.size_flags_horizontal = SIZE_EXPAND_FILL
		header.add_child(type_label)

		var status := Label.new()
		status.text = state_label
		status.modulate = Color(0.86, 0.9, 0.98)
		header.add_child(status)

		var desc := Label.new()
		desc.text = String(node.get("text", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.modulate = Color(0.8, 0.86, 0.96)
		desc.custom_minimum_size = Vector2(0, 42)
		v.add_child(desc)

func _build_route_node_button(node: Dictionary) -> Button:
	var node_type := String(node.get("node_type", ""))
	var uid := String(node.get("route_node_uid", ""))
	var colors := _node_colors(node_type)
	var state_label := "Locked"
	if _run_state.selected_path.has(uid):
		state_label = "Done"
	elif uid == _run_state.current_node_uid:
		state_label = "Current"
	elif _run_state.is_node_available(uid):
		state_label = "Available"

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(168, 82)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = "#%d %s [%s]\n%s" % [
		int(node.get("lane_index", 0)),
		_node_type_name(node_type),
		state_label,
		String(node.get("text", ""))
	]
	var border: Color = colors["border"]
	var bg: Color = colors["bg"]
	if state_label == "Current":
		border = Color(1.0, 0.86, 0.42)
	elif state_label == "Available":
		border = Color(0.55, 0.9, 1.0)
	elif state_label == "Done":
		border = Color(0.48, 0.86, 0.64)
		bg = Color(0.08, 0.13, 0.11)
	else:
		border = Color(0.22, 0.26, 0.34)
		bg = Color(0.06, 0.065, 0.085)
	btn.add_theme_stylebox_override("normal", _style_panel(bg, border, 10))
	btn.add_theme_stylebox_override("hover", _style_panel(bg.lightened(0.08), border.lightened(0.1), 10))
	btn.add_theme_stylebox_override("disabled", _style_panel(bg.darkened(0.15), border.darkened(0.2), 10))
	btn.disabled = state_label == "Locked" or state_label == "Done" or not _run_state.pending_reward_choices.is_empty()
	if not btn.disabled:
		btn.pressed.connect(_on_route_node_pressed.bind(uid))
	return btn

func _render_rewards() -> void:
	for child in _reward_row.get_children():
		child.queue_free()
	var has_rewards: bool = _run_state != null and not _run_state.pending_reward_choices.is_empty()
	_reward_panel.visible = has_rewards
	if not has_rewards:
		return

	for i in range(_run_state.pending_reward_choices.size()):
		var reward: Dictionary = _run_state.pending_reward_choices[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(250, 108)
		var price := int(reward.get("price", 0))
		var price_text := ""
		if price > 0:
			price_text = "\nCost: %d credits" % price
		btn.text = "[%s | %s]\n%s\n%s%s" % [
			str(reward.get("rarity_label", "普通")),
			str(reward.get("scope_label", "下一场")),
			str(reward.get("title", "奖励")),
			str(reward.get("description", "")),
			price_text
		]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_stylebox_override("normal", _style_panel(Color(0.19, 0.15, 0.09), Color(0.76, 0.62, 0.26), 10))
		btn.add_theme_stylebox_override("hover", _style_panel(Color(0.24, 0.18, 0.11), Color(0.92, 0.77, 0.33), 10))
		btn.add_theme_stylebox_override("disabled", _style_panel(Color(0.11, 0.1, 0.09), Color(0.3, 0.28, 0.24), 10))
		btn.disabled = price > _run_state.progress.get_currency("credits")
		btn.pressed.connect(_on_reward_selected.bind(i))
		_reward_row.add_child(btn)

func _render_log() -> void:
	_log_view.clear()
	for item_any in _run_state.node_results:
		var item: Dictionary = item_any
		_log_view.append_text(_format_log_item(item) + "\n")
	if _run_state.completed:
		_log_view.append_text("Run 结果：%s | %s\n" % [_run_state.result.result_type, _run_state.result.summary])

func _on_resolve_pressed() -> void:
	if _active_battle != null:
		return
	var node: Dictionary = _run_state.current_node()
	if node.is_empty():
		_feedback_label.text = "当前没有可推进的节点。"
		_render_ui()
		return
	if ["battle", "elite", "boss"].has(String(node.get("node_type", ""))):
		_open_battle_node(node)
		return
	var result: Dictionary = _simulator.resolve_current_node(_run_state, _rngs)
	if bool(result.get("ok", false)):
		_feedback_label.text = _resolve_feedback(result)
		_show_node_result(result)
	else:
		_feedback_label.text = "节点进入失败：%s" % str(result.get("reason", "unknown"))
	_render_ui()

func _show_node_result(result: Dictionary) -> void:
	if _node_result_panel == null:
		return
	var node_type := String(result.get("node_type", ""))
	var reward: Dictionary = result.get("reward", {})
	_node_result_title.text = "%s结算完成" % _node_type_name(node_type)
	var lines: Array[String] = []
	lines.append(_resolve_feedback(result))
	if not reward.is_empty():
		lines.append("获得：%s" % String(reward.get("title", "奖励")))
		lines.append(String(reward.get("description", "")))
	lines.append("当前 Credits：%d" % _run_state.progress.get_currency("credits"))
	if _run_state.completed:
		lines.append("Run 已结束，点击继续返回 Hub。")
	_node_result_detail.text = "\n".join(lines)
	_node_result_panel.visible = true

func _hide_node_result_panel() -> void:
	if _node_result_panel == null:
		return
	_node_result_panel.visible = false
	_node_result_detail.text = ""

func _node_result_active() -> bool:
	return _node_result_panel != null and _node_result_panel.visible

func _on_node_result_continue_pressed() -> void:
	_hide_node_result_panel()
	_emit_run_finished_if_needed()
	_render_ui()

func _on_reward_selected(index: int) -> void:
	var result: Dictionary = _simulator.choose_reward(_run_state, index)
	if bool(result.get("ok", false)):
		var reward: Dictionary = result.get("reward", {})
		_feedback_label.text = "已领取奖励：%s" % str(reward.get("title", "奖励"))
		_emit_run_finished_if_needed()
	else:
		var reason := str(result.get("reason", "unknown"))
		if reason == "not_enough_credits":
			_feedback_label.text = "Credits 不足：需要 %d。" % int(result.get("price", 0))
		else:
			_feedback_label.text = "奖励领取失败：%s" % reason
	_render_ui()

func _on_route_node_pressed(route_node_uid: String) -> void:
	var result: Dictionary = _simulator.select_route_node(_run_state, route_node_uid)
	if bool(result.get("ok", false)):
		_feedback_label.text = "Selected route node: %s" % route_node_uid
	else:
		_feedback_label.text = "This route node is not currently reachable."
	_render_ui()

func _on_evac_pressed() -> void:
	var result: Dictionary = _simulator.evacuate(_run_state)
	if bool(result.get("ok", false)):
		_feedback_label.text = "撤离成功，本次 Run 已结束。"
		_emit_run_finished_if_needed()
	else:
		_feedback_label.text = "当前不可撤离。"
	_render_ui()

func _open_battle_node(node: Dictionary) -> void:
	var battle := BattleVisualizerScene.instantiate()
	_active_battle = battle
	add_child(battle)
	var enemy_id := String(node.get("battle_enemy_id", "boss_vanguard"))
	var title := "%s: %s" % [_node_type_name(String(node.get("node_type", "battle"))), String(node.get("text", ""))]
	var battle_seed := _battle_seed_for_node(node)
	battle.configure_for_run(battle_seed, _run_state.hero_id, enemy_id, _run_state.progress, title, _run_state.loadout_face_ids, _run_state.equipped_equipment_instances())
	battle.battle_closed.connect(_on_battle_closed)
	_feedback_label.text = "已进入战斗节点，请在战斗界面完成结算。"
	_render_ui()

func _on_battle_closed(victory: bool, payload: Dictionary) -> void:
	var enemy_id := str(payload.get("enemy_id", "boss_vanguard"))
	var result := _simulator.complete_battle_node(_run_state, _rngs, victory, enemy_id, payload)
	_active_battle = null
	if bool(result.get("ok", false)):
		if victory:
			_feedback_label.text = "战斗胜利，已返回 Run。"
			if int(result.get("pending_rewards", 0)) > 0:
				_feedback_label.text += " 请选择一个奖励后继续。"
		else:
			_feedback_label.text = "战斗失败，Run 结束。"
			_emit_run_finished_if_needed()
	else:
		_feedback_label.text = "战斗结果回写失败：%s" % str(result.get("reason", "unknown"))
	_render_ui()

func _battle_seed_for_node(node: Dictionary) -> int:
	var node_id := String(node.get("id", ""))
	var acc: int = _master_seed + (_run_state.current_node_index * 101)
	for i in range(node_id.length()):
		acc += node_id.unicode_at(i) * (i + 1)
	return acc

func _emit_run_finished_if_needed() -> void:
	if _run_state == null or not _run_state.completed:
		return
	run_finished.emit(_run_state.result.to_dict())

func _current_node_type() -> String:
	if _run_state == null or _run_state.completed:
		return "completed"
	return String(_run_state.current_node().get("node_type", ""))

func _current_node_title() -> String:
	if _run_state.completed:
		return "Run 已结束"
	var node: Dictionary = _run_state.current_node()
	return "当前节点：%s" % String(node.get("text", _node_type_name(String(node.get("node_type", "")))))

func _current_node_detail() -> String:
	if _run_state.completed:
		return _run_state.result.summary
	var node: Dictionary = _run_state.current_node()
	if node.is_empty():
		return "没有可用节点。"
	var node_type := String(node.get("node_type", ""))
	var details: Array[String] = []
	details.append("节点类型：%s" % _node_type_name(node_type))
	if ["battle", "elite", "boss"].has(node_type):
		details.append("敌人：%s" % _enemy_name(String(node.get("battle_enemy_id", "boss_vanguard"))))
		details.append("结算方式：进入真实战斗界面，打完后回到 Run。")
	elif node_type == "event":
		details.append("事件 ID：%s" % String(node.get("event_id", "")))
		details.append(_event_text(String(node.get("event_id", ""))))
	elif node_type == "supply":
		details.append("补给节点会直接从补给奖池中结算一份奖励。")
	elif node_type == "shop":
		details.append("商店节点提供更定向的构筑奖励选择。")
	elif node_type == "rest":
		details.append("休息节点用于在高压层之间恢复节奏。")
	details.append("可撤离：%s" % ("是" if _run_state.can_evac() else "否"))
	return "\n".join(details)

func _current_node_hint() -> String:
	if _run_state.completed:
		return "可以直接开始一局新的 Run，或者把这套路线节奏作为后续 Hub 回流的基础。"
	var node_type := _current_node_type()
	if not _run_state.pending_reward_choices.is_empty():
		return "当前有待领取奖励，先选 1 个奖励，才能继续推进路线。"
	if ["battle", "elite", "boss"].has(node_type):
		return "这是压力节点：会消耗真实战斗时间，但也是主要成长来源。"
	if node_type == "event":
		return "这是缓冲节点：先做轻量事件结算，验证奖励与文本反馈。"
	if node_type == "supply":
		return "这是补给节点：节奏更轻，适合放在中后段给玩家回口气。"
	return "按顺序推进即可。"

func _resolve_feedback(result: Dictionary) -> String:
	var node_type := String(result.get("node_type", ""))
	if ["battle", "elite", "boss"].has(node_type):
		return "战斗节点已结算：%s" % String(result.get("battle_result", ""))
	if node_type == "event":
		var reward: Dictionary = result.get("reward", {})
		return "事件节点结算完成：%s" % str(reward.get("title", "已应用事件奖励"))
	if node_type == "supply":
		var reward_supply: Dictionary = result.get("reward", {})
		return "补给节点结算完成：%s" % str(reward_supply.get("title", "已获得补给"))
	return "节点已结算。"

func _render_badge(label: Label, colors: Dictionary) -> void:
	label.add_theme_color_override("font_color", colors["text"])

func _format_log_item(item: Dictionary) -> String:
	var node_type := _node_type_name(String(item.get("node_type", "")))
	var result := String(item.get("result", ""))
	var node_id := String(item.get("node_id", ""))
	var enemy_id := String(item.get("enemy_id", ""))
	if result == "victory_pending_reward":
		return "• [%s] %s：战斗胜利，等待奖励选择。" % [node_type, node_id]
	if result == "victory":
		return "• [%s] %s：战斗胜利。敌人 %s" % [node_type, node_id, _enemy_name(enemy_id)]
	if result == "defeat":
		return "• [%s] %s：战斗失败。敌人 %s" % [node_type, node_id, _enemy_name(enemy_id)]
	if result == "resolved" and item.has("event_id"):
		return "• [%s] %s：事件完成，获得 %s。" % [node_type, node_id, String(item.get("reward_id", "奖励"))]
	if result == "resolved":
		return "• [%s] %s：节点完成，获得 %s。" % [node_type, node_id, String(item.get("reward_id", "奖励"))]
	if result == "reward_selected":
		return "• [奖励] %s：已领取 %s。" % [node_id, String(item.get("reward_id", "reward"))]
	return "• [%s] %s：%s" % [node_type, node_id, result]

func _hero_name(hero_id: String) -> String:
	match hero_id:
		"cyan_ryder":
			return "Cyan Ryder（蓝龙）"
		"helios_windchaser":
			return "Helios Windchaser（狮鹫）"
		"umbral_draxx":
			return "Aurian（奥瑞恩）"
		_:
			return hero_id

func _enemy_name(enemy_id: String) -> String:
	match enemy_id:
		"boss_vanguard":
			return "先锋巨兽"
		"reef_stalker":
			return "礁海潜猎体"
		"void_howler":
			return "虚空嚎兽"
		_:
			return enemy_id

func _event_text(event_id: String) -> String:
	if _loader == null or event_id == "":
		return "事件文本缺失。"
	var row := _loader.find_row_by_id("events", event_id)
	if row.is_empty():
		return "事件文本缺失。"
	return String(row.get("text", "事件文本缺失。"))

func _node_type_name(node_type: String) -> String:
	match node_type:
		"battle":
			return "战斗"
		"elite":
			return "精英"
		"event":
			return "事件"
		"supply":
			return "补给"
		"shop":
			return "商店"
		"rest":
			return "休息"
		"evac":
			return "撤离"
		"boss":
			return "Boss"
		"completed":
			return "完成"
		_:
			return node_type

func _node_colors(node_type: String) -> Dictionary:
	match node_type:
		"battle":
			return {
				"bg": Color(0.22, 0.1, 0.12),
				"border": Color(0.82, 0.34, 0.38),
				"text": Color(1.0, 0.85, 0.86)
			}
		"elite":
			return {
				"bg": Color(0.25, 0.12, 0.08),
				"border": Color(0.95, 0.55, 0.26),
				"text": Color(1.0, 0.9, 0.78)
			}
		"event":
			return {
				"bg": Color(0.11, 0.16, 0.24),
				"border": Color(0.46, 0.68, 0.98),
				"text": Color(0.88, 0.94, 1.0)
			}
		"supply":
			return {
				"bg": Color(0.12, 0.18, 0.13),
				"border": Color(0.45, 0.83, 0.56),
				"text": Color(0.9, 1.0, 0.92)
			}
		"shop":
			return {
				"bg": Color(0.18, 0.14, 0.08),
				"border": Color(0.85, 0.66, 0.28),
				"text": Color(1.0, 0.94, 0.78)
			}
		"rest":
			return {
				"bg": Color(0.09, 0.16, 0.16),
				"border": Color(0.42, 0.82, 0.78),
				"text": Color(0.86, 1.0, 0.98)
			}
		"boss":
			return {
				"bg": Color(0.2, 0.08, 0.2),
				"border": Color(0.9, 0.48, 0.95),
				"text": Color(1.0, 0.86, 1.0)
			}
		"completed":
			return {
				"bg": Color(0.16, 0.16, 0.18),
				"border": Color(0.74, 0.8, 0.88),
				"text": Color(0.94, 0.96, 1.0)
			}
		_:
			return {
				"bg": Color(0.16, 0.16, 0.2),
				"border": Color(0.62, 0.68, 0.84),
				"text": Color(0.92, 0.94, 1.0)
			}

func _style_panel(bg: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = border
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb
