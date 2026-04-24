extends Control

signal start_run_requested(hero_id: String)

const HubStateScript = preload("res://scripts/hub/hub_state.gd")

var _hub_state: HubStateScript

var _summary_label: Label
var _hero_buttons_row: HBoxContainer
var _selected_hero_label: Label
var _upgrade_row: HBoxContainer
var _loadout_row: HBoxContainer
var _reserve_row: HBoxContainer
var _last_run_label: Label
var _last_run_details: RichTextLabel
var _feedback_label: Label
var _start_run_btn: Button

func configure_hub(hub_state: HubStateScript) -> void:
	_hub_state = hub_state
	if is_inside_tree():
		_render_ui()

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()
	_render_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0.045, 0.035, 0.06, 1.0)
	add_child(bg)

	var accent := ColorRect.new()
	accent.anchor_right = 1.0
	accent.color = Color(0.18, 0.12, 0.08, 0.18)
	accent.custom_minimum_size = Vector2(0, 240)
	add_child(accent)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_top", 20)
	root.add_theme_constant_override("margin_bottom", 20)
	add_child(root)

	var main_v := VBoxContainer.new()
	main_v.add_theme_constant_override("separation", 12)
	root.add_child(main_v)

	main_v.add_child(_build_top_panel())
	main_v.add_child(_build_progression_panel())
	main_v.add_child(_build_loadout_panel())
	main_v.add_child(_build_result_panel())

func _build_top_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.11, 0.08, 0.12), Color(0.62, 0.47, 0.33), 14))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title := Label.new()
	title.text = "Hub - 前线整备"
	title.add_theme_font_size_override("font_size", 25)
	title.modulate = Color(1.0, 0.97, 0.92)
	v.add_child(title)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_summary_label.modulate = Color(0.83, 0.9, 1.0)
	v.add_child(_summary_label)

	var hero_title := Label.new()
	hero_title.text = "当前出战角色"
	hero_title.add_theme_font_size_override("font_size", 18)
	hero_title.modulate = Color(0.96, 0.97, 1.0)
	v.add_child(hero_title)

	_hero_buttons_row = HBoxContainer.new()
	_hero_buttons_row.add_theme_constant_override("separation", 8)
	v.add_child(_hero_buttons_row)

	_selected_hero_label = Label.new()
	_selected_hero_label.modulate = Color(0.95, 0.82, 0.67)
	v.add_child(_selected_hero_label)

	_feedback_label = Label.new()
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_feedback_label.modulate = Color(0.98, 0.83, 0.68)
	v.add_child(_feedback_label)

	return panel

func _build_progression_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.08, 0.1, 0.13), Color(0.3, 0.47, 0.42), 12))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = "局外成长"
	title.add_theme_font_size_override("font_size", 19)
	title.modulate = Color(0.94, 1.0, 0.94)
	v.add_child(title)

	_upgrade_row = HBoxContainer.new()
	_upgrade_row.add_theme_constant_override("separation", 8)
	v.add_child(_upgrade_row)

	return panel

func _build_loadout_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.08, 0.09, 0.13), Color(0.31, 0.38, 0.58), 12))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = "基础构筑"
	title.add_theme_font_size_override("font_size", 19)
	title.modulate = Color(0.94, 0.97, 1.0)
	v.add_child(title)

	var loadout_title := Label.new()
	loadout_title.text = "已装备骰面"
	loadout_title.modulate = Color(0.82, 0.88, 0.98)
	v.add_child(loadout_title)

	_loadout_row = HBoxContainer.new()
	_loadout_row.add_theme_constant_override("separation", 8)
	v.add_child(_loadout_row)

	var reserve_title := Label.new()
	reserve_title.text = "备用骰面"
	reserve_title.modulate = Color(0.82, 0.88, 0.98)
	v.add_child(reserve_title)

	_reserve_row = HBoxContainer.new()
	_reserve_row.add_theme_constant_override("separation", 8)
	v.add_child(_reserve_row)

	return panel

func _build_result_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.08, 0.09, 0.13), Color(0.26, 0.35, 0.56), 14))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title := Label.new()
	title.text = "上次 Run 结算"
	title.add_theme_font_size_override("font_size", 20)
	title.modulate = Color(0.96, 0.98, 1.0)
	v.add_child(title)

	_last_run_label = Label.new()
	_last_run_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_last_run_label.modulate = Color(0.84, 0.9, 0.98)
	v.add_child(_last_run_label)

	_last_run_details = RichTextLabel.new()
	_last_run_details.bbcode_enabled = false
	_last_run_details.custom_minimum_size = Vector2(0, 110)
	_last_run_details.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(_last_run_details)

	_start_run_btn = Button.new()
	_start_run_btn.text = "进入下一局 Run"
	_start_run_btn.custom_minimum_size = Vector2(0, 42)
	_start_run_btn.pressed.connect(_on_start_run_pressed)
	v.add_child(_start_run_btn)

	return panel

func _render_ui() -> void:
	if _hub_state == null:
		_hub_state = HubStateScript.new()

	_summary_label.text = "累计 Run %d 局 | 完成 %d | 撤离 %d | 失败 %d | 库存 %d Credits" % [
		_hub_state.run_count,
		_hub_state.completed_runs,
		_hub_state.evacuated_runs,
		_hub_state.failed_runs,
		_hub_state.banked_credits
	]
	_selected_hero_label.text = "当前出战：%s | 构筑 %d/%d | 已购成长 %d 项" % [
		_hero_name(_hub_state.selected_hero_id),
		_hub_state.selected_loadout().size(),
		HubStateScript.DEFAULT_LOADOUT_SIZE,
		_hub_state.persistent_growths_for_hero(_hub_state.selected_hero_id).size()
	]
	_last_run_label.text = _hub_state.last_run_summary()
	_render_hero_buttons()
	_render_upgrades()
	_render_loadout()
	_render_last_run_details()

func _render_hero_buttons() -> void:
	for child in _hero_buttons_row.get_children():
		child.queue_free()

	for hero_id in _hub_state.available_heroes:
		var btn := Button.new()
		btn.text = _hero_name(hero_id)
		btn.custom_minimum_size = Vector2(180, 44)
		btn.disabled = hero_id == _hub_state.selected_hero_id
		btn.pressed.connect(_on_hero_selected.bind(hero_id))
		_hero_buttons_row.add_child(btn)

func _render_upgrades() -> void:
	for child in _upgrade_row.get_children():
		child.queue_free()

	for offer_any in _hub_state.upgrade_offer_list(_hub_state.selected_hero_id):
		var offer: Dictionary = offer_any
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 92)
		var maxed := int(offer.get("level", 0)) >= int(offer.get("max_level", 0))
		var cost_text := "已满级" if maxed else "%d Credits" % int(offer.get("next_cost", 0))
		btn.text = "%s Lv.%d/%d\n%s\n%s" % [
			String(offer.get("title", "")),
			int(offer.get("level", 0)),
			int(offer.get("max_level", 0)),
			String(offer.get("description", "")),
			cost_text
		]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = not bool(offer.get("can_buy", false))
		btn.pressed.connect(_on_upgrade_pressed.bind(String(offer.get("upgrade_id", ""))))
		_upgrade_row.add_child(btn)

func _render_loadout() -> void:
	for child in _loadout_row.get_children():
		child.queue_free()
	for child in _reserve_row.get_children():
		child.queue_free()

	for face_id in _hub_state.selected_loadout():
		_loadout_row.add_child(_face_button(face_id, true))
	for face_id in _hub_state.reserve_faces_for_hero(_hub_state.selected_hero_id):
		_reserve_row.add_child(_face_button(face_id, false))

func _face_button(face_id: String, equipped: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 52)
	btn.text = "%s\n%s" % [_face_name(face_id), "移除" if equipped else "装备"]
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD
	btn.pressed.connect(_on_face_toggled.bind(face_id))
	return btn

func _render_last_run_details() -> void:
	_last_run_details.clear()
	for line in _hub_state.last_run_detail_lines():
		_last_run_details.append_text(line + "\n")

func _on_hero_selected(hero_id: String) -> void:
	_hub_state.select_hero(hero_id)
	_feedback_label.text = "已切换出战角色：%s" % _hero_name(hero_id)
	_render_ui()

func _on_upgrade_pressed(upgrade_id: String) -> void:
	var result := _hub_state.purchase_upgrade(_hub_state.selected_hero_id, upgrade_id)
	if bool(result.get("ok", false)):
		_feedback_label.text = "购买成功，花费 %d Credits。" % int(result.get("cost", 0))
	else:
		_feedback_label.text = "购买失败：%s" % String(result.get("reason", "unknown"))
	_render_ui()

func _on_face_toggled(face_id: String) -> void:
	var result := _hub_state.toggle_face_in_selected_loadout(face_id)
	if bool(result.get("ok", false)):
		_feedback_label.text = "构筑已更新：%s" % _face_name(face_id)
	else:
		_feedback_label.text = "构筑更新失败：%s" % String(result.get("reason", "unknown"))
	_render_ui()

func _on_start_run_pressed() -> void:
	start_run_requested.emit(_hub_state.selected_hero_id)

func _hero_name(hero_id: String) -> String:
	match hero_id:
		"cyan_ryder":
			return "Cyan Ryder（蓝龙）"
		"helios_windchaser":
			return "Helios Windchaser（狮鹫）"
		"umbral_draxx":
			return "黑龙（暂名）"
		_:
			return hero_id

func _face_name(face_id: String) -> String:
	var parts := face_id.split("_", false)
	var out: Array[String] = []
	for part in parts:
		if part in ["cyan", "helios", "black", "umbral"]:
			continue
		out.append(String(part).capitalize())
	if out.is_empty():
		return face_id
	return " ".join(out)

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
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb
