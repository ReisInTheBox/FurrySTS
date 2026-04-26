extends Control

signal start_run_requested(hero_id: String)

const HubStateScript = preload("res://scripts/hub/hub_state.gd")

var _hub_state: HubStateScript

var _summary_label: Label
var _hero_buttons_row: HFlowContainer
var _selected_hero_label: Label
var _upgrade_row: HFlowContainer
var _equipment_row: HFlowContainer
var _equipment_detail_box: RichTextLabel
var _loadout_row: HFlowContainer
var _reserve_row: HFlowContainer
var _die_detail_box: RichTextLabel
var _last_run_label: Label
var _last_run_details: RichTextLabel
var _relationship_details: RichTextLabel
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

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 18)
	root.add_theme_constant_override("margin_right", 18)
	root.add_theme_constant_override("margin_top", 14)
	root.add_theme_constant_override("margin_bottom", 14)
	add_child(root)

	var page := VBoxContainer.new()
	page.size_flags_horizontal = SIZE_EXPAND_FILL
	page.size_flags_vertical = SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	root.add_child(page)

	page.add_child(_build_top_panel())

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
	content.add_child(_build_progression_panel())
	content.add_child(_build_equipment_panel())
	content.add_child(_build_relationship_panel())
	content.add_child(_build_loadout_panel())
	content.add_child(_build_result_panel())

	page.add_child(_build_action_bar())

func _build_top_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.11, 0.08, 0.12), Color(0.62, 0.47, 0.33), 14))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = "Hub - 前线整备"
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color(1.0, 0.97, 0.92)
	v.add_child(title)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_summary_label.modulate = Color(0.83, 0.9, 1.0)
	v.add_child(_summary_label)

	var hero_title := Label.new()
	hero_title.text = "选择出战角色"
	hero_title.add_theme_font_size_override("font_size", 17)
	hero_title.modulate = Color(0.96, 0.97, 1.0)
	v.add_child(hero_title)

	_hero_buttons_row = HFlowContainer.new()
	_hero_buttons_row.add_theme_constant_override("h_separation", 8)
	_hero_buttons_row.add_theme_constant_override("v_separation", 8)
	v.add_child(_hero_buttons_row)

	_selected_hero_label = Label.new()
	_selected_hero_label.autowrap_mode = TextServer.AUTOWRAP_WORD
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

	var hint := Label.new()
	hint.text = "消耗 Credits 购买永久整备项，下一局 Run 会自动生效。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.modulate = Color(0.78, 0.88, 0.82)
	v.add_child(hint)

	_upgrade_row = HFlowContainer.new()
	_upgrade_row.add_theme_constant_override("h_separation", 8)
	_upgrade_row.add_theme_constant_override("v_separation", 8)
	v.add_child(_upgrade_row)

	return panel

func _build_relationship_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.09, 0.08, 0.12), Color(0.52, 0.42, 0.72), 12))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = "关系与解锁"
	title.add_theme_font_size_override("font_size", 19)
	title.modulate = Color(0.96, 0.92, 1.0)
	v.add_child(title)

	_relationship_details = RichTextLabel.new()
	_relationship_details.bbcode_enabled = false
	_relationship_details.fit_content = false
	_relationship_details.custom_minimum_size = Vector2(0, 84)
	v.add_child(_relationship_details)
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
	loadout_title.text = "已装备 D6（点击移除，至少保留 2 颗；每颗骰子包含 6 个面）"
	loadout_title.modulate = Color(0.82, 0.88, 0.98)
	v.add_child(loadout_title)

	_loadout_row = HFlowContainer.new()
	_loadout_row.add_theme_constant_override("h_separation", 8)
	_loadout_row.add_theme_constant_override("v_separation", 8)
	v.add_child(_loadout_row)

	var reserve_title := Label.new()
	reserve_title.text = "备用 D6（点击装备，当前最多装备 3 颗）"
	reserve_title.modulate = Color(0.82, 0.88, 0.98)
	v.add_child(reserve_title)

	_reserve_row = HFlowContainer.new()
	_reserve_row.add_theme_constant_override("h_separation", 8)
	_reserve_row.add_theme_constant_override("v_separation", 8)
	v.add_child(_reserve_row)

	var detail_title := Label.new()
	detail_title.text = "骰面详情（点击任意 D6 查看；悬停按钮也有说明）"
	detail_title.modulate = Color(0.82, 0.88, 0.98)
	v.add_child(detail_title)

	_die_detail_box = RichTextLabel.new()
	_die_detail_box.bbcode_enabled = false
	_die_detail_box.fit_content = false
	_die_detail_box.custom_minimum_size = Vector2(0, 112)
	v.add_child(_die_detail_box)

	return panel

func _build_equipment_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.09, 0.105, 0.08), Color(0.48, 0.62, 0.34), 12))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = "Equipment - weapon / armor / item"
	title.add_theme_font_size_override("font_size", 19)
	title.modulate = Color(0.94, 1.0, 0.9)
	v.add_child(title)

	var hint := Label.new()
	hint.text = "Click stored equipment to equip it into its fixed slot. Broken gear cannot be carried."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.modulate = Color(0.8, 0.9, 0.75)
	v.add_child(hint)

	_equipment_detail_box = RichTextLabel.new()
	_equipment_detail_box.bbcode_enabled = false
	_equipment_detail_box.fit_content = false
	_equipment_detail_box.custom_minimum_size = Vector2(0, 78)
	v.add_child(_equipment_detail_box)

	_equipment_row = HFlowContainer.new()
	_equipment_row.add_theme_constant_override("h_separation", 8)
	_equipment_row.add_theme_constant_override("v_separation", 8)
	v.add_child(_equipment_row)
	return panel


func _build_result_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.08, 0.09, 0.13), Color(0.26, 0.35, 0.56), 14))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = "上次 Run 结算"
	title.add_theme_font_size_override("font_size", 19)
	title.modulate = Color(0.96, 0.98, 1.0)
	v.add_child(title)

	_last_run_label = Label.new()
	_last_run_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_last_run_label.modulate = Color(0.84, 0.9, 0.98)
	v.add_child(_last_run_label)

	_last_run_details = RichTextLabel.new()
	_last_run_details.bbcode_enabled = false
	_last_run_details.fit_content = false
	_last_run_details.custom_minimum_size = Vector2(0, 95)
	v.add_child(_last_run_details)

	return panel

func _build_action_bar() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.12, 0.09, 0.08), Color(0.78, 0.55, 0.32), 12))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var label := Label.new()
	label.text = "准备好后进入下一局。若内容超出屏幕，请滚动中间区域。"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.modulate = Color(0.96, 0.9, 0.78)
	row.add_child(label)

	_start_run_btn = Button.new()
	_start_run_btn.text = "进入下一局 Run"
	_start_run_btn.custom_minimum_size = Vector2(190, 44)
	_start_run_btn.pressed.connect(_on_start_run_pressed)
	row.add_child(_start_run_btn)
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
	_selected_hero_label.text = "当前出战：%s | D6 构筑 %d/%d | 已购成长 %d 项" % [
		_hero_name(_hub_state.selected_hero_id),
		_hub_state.selected_loadout().size(),
		HubStateScript.DEFAULT_LOADOUT_SIZE,
		_hub_state.persistent_growths_for_hero(_hub_state.selected_hero_id).size()
	]
	_last_run_label.text = _hub_state.last_run_summary()
	_render_hero_buttons()
	_render_upgrades()
	_render_equipment()
	_render_relationship()
	_render_loadout()
	_render_last_run_details()

func _render_hero_buttons() -> void:
	for child in _hero_buttons_row.get_children():
		child.queue_free()

	for hero_id in _hub_state.available_heroes:
		var btn := Button.new()
		btn.text = _hero_name(hero_id)
		btn.custom_minimum_size = Vector2(190, 42)
		btn.disabled = hero_id == _hub_state.selected_hero_id
		btn.pressed.connect(_on_hero_selected.bind(hero_id))
		_hero_buttons_row.add_child(btn)

func _render_upgrades() -> void:
	for child in _upgrade_row.get_children():
		child.queue_free()

	for offer_any in _hub_state.upgrade_offer_list(_hub_state.selected_hero_id):
		var offer: Dictionary = offer_any
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(245, 96)
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

func _render_relationship() -> void:
	if _relationship_details == null:
		return
	_relationship_details.clear()
	for line in _hub_state.relationship_summary_lines():
		_relationship_details.append_text(line + "\n")

func _render_equipment() -> void:
	if _equipment_row == null or _equipment_detail_box == null:
		return
	for child in _equipment_row.get_children():
		child.queue_free()
	_equipment_detail_box.clear()
	_equipment_detail_box.append_text("Selected hero slots:\n")
	var slots := _hub_state.equipment_loadout_for_hero(_hub_state.selected_hero_id)
	for slot in HubStateScript.EQUIPMENT_SLOTS:
		var instance_id := String(slots.get(slot, ""))
		var item := _hub_state.equipment_instance_by_id(instance_id)
		var label := "empty"
		if not item.is_empty():
			label = "%s [%s]" % [String(item.get("display_name", item.get("equipment_id", ""))), String(item.get("damage_state", "intact"))]
		_equipment_detail_box.append_text("- %s: %s\n" % [slot, label])
	_equipment_detail_box.append_text("Storage %d/%d | Repair materials %d\n" % [
		_hub_state.equipment_storage.size(),
		_hub_state.equipment_storage_capacity,
		_hub_state.repair_materials
	])
	for item_any in _hub_state.equipment_storage:
		var item: Dictionary = item_any
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(230, 100)
		btn.text = "%s\n%s | %s\nreturn %d | %s" % [
			String(item.get("display_name", item.get("equipment_id", ""))),
			String(item.get("equip_slot", "")),
			String(item.get("rarity", "common")),
			int(item.get("return_count", 0)),
			String(item.get("damage_state", "intact"))
		]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = String(item.get("damage_state", "intact")) == "broken"
		btn.tooltip_text = String(item.get("tags", "")) + "\n" + String(item.get("definition", {}).get("description", ""))
		btn.pressed.connect(_on_equipment_pressed.bind(String(item.get("equipment_instance_id", ""))))
		_equipment_row.add_child(btn)

func _render_loadout() -> void:
	for child in _loadout_row.get_children():
		child.queue_free()
	for child in _reserve_row.get_children():
		child.queue_free()
	_die_detail_box.clear()

	for die_id in _hub_state.selected_die_loadout():
		_loadout_row.add_child(_die_button(die_id, true))
	for die_id in _hub_state.reserve_dice_for_hero(_hub_state.selected_hero_id):
		_reserve_row.add_child(_die_button(die_id, false))
	for line in _hub_state.die_detail_lines(_hub_state.selected_hero_id, _hub_state.selected_die_loadout()[0] if not _hub_state.selected_die_loadout().is_empty() else ""):
		_die_detail_box.append_text(line + "\n")

func _die_button(die_id: String, equipped: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(210, 88)
	var summary := _hub_state.die_summary(_hub_state.selected_hero_id, die_id)
	var neg := int(summary.get("negative_count", 0))
	var types := PackedStringArray(summary.get("types", []))
	var type_text := " / ".join(types)
	btn.text = "%s\n%d 面 | 负面 %d\n%s" % [
		_die_name(die_id),
		int(summary.get("face_count", 0)),
		neg,
		"移除" if equipped else "装备"
	]
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD
	btn.tooltip_text = "\n".join(PackedStringArray(_hub_state.die_detail_lines(_hub_state.selected_hero_id, die_id)))
	if type_text != "":
		btn.tooltip_text += "\n类型：" + type_text
	btn.pressed.connect(_on_die_toggled.bind(die_id))
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

func _on_die_toggled(die_id: String) -> void:
	var result := _hub_state.toggle_die_in_selected_loadout(die_id)
	if bool(result.get("ok", false)):
		_feedback_label.text = "D6 构筑已更新：%s" % _die_name(die_id)
	else:
		_feedback_label.text = "构筑更新失败：%s" % String(result.get("reason", "unknown"))
	_render_ui()

func _on_equipment_pressed(instance_id: String) -> void:
	var result := _hub_state.equip_storage_instance(_hub_state.selected_hero_id, instance_id)
	if bool(result.get("ok", false)):
		_feedback_label.text = "Equipped %s into %s." % [instance_id, String(result.get("equip_slot", ""))]
	else:
		_feedback_label.text = "Equipment failed: %s" % String(result.get("reason", "unknown"))
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
			return "Aurian（奥瑞恩）"
		_:
			return hero_id

func _die_name(die_id: String) -> String:
	return _hub_state.die_display_name(die_id)

func _face_name(face_id: String) -> String:
	var face_zh := {
		"cyan_beam_a": "光束射击 A",
		"cyan_beam_b": "光束射击 B",
		"cyan_shift": "空间跃迁",
		"cyan_burst": "异能爆发",
		"cyan_pulse": "脉冲校准",
		"cyan_cooldown": "冷却循环",
		"cyan_arcflare": "电弧闪击",
		"cyan_vent": "过载泄放",
		"helios_mark": "校准标记",
		"helios_sniper": "鹰眼射击",
		"helios_swoop": "低空掠过",
		"helios_recover": "箭矢回收",
		"helios_pierce": "穿透射击",
		"helios_hunt": "追猎步伐",
		"helios_trap": "追踪陷阱",
		"helios_volley": "连发齐射",
		"black_sweep": "大剑横扫",
		"black_charge": "蓄力",
		"black_shock": "震荡",
		"black_guard": "铁壁",
		"black_execute": "断罪重斩",
		"black_pose": "处决姿态",
		"black_parry": "偏斜格挡",
		"black_reap": "终结收割"
	}
	if face_zh.has(face_id):
		return face_zh[face_id]
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
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb
