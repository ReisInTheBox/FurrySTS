extends Control

signal battle_closed(victory: bool, payload: Dictionary)

const SeedBundleScript = preload("res://scripts/core/seed_bundle.gd")
const RngStreamsScript = preload("res://scripts/core/rng_streams.gd")
const ActionLoggerScript = preload("res://scripts/core/action_logger.gd")
const CombatStateScript = preload("res://scripts/combat/combat_state.gd")
const BattleSimulatorScript = preload("res://scripts/combat/battle_simulator.gd")
const ContentLoaderScript = preload("res://scripts/content/content_loader.gd")
const UnitFactoryScript = preload("res://scripts/content/unit_factory.gd")
const CombatCatalogScript = preload("res://scripts/content/combat_catalog.gd")
const DiceFaceDefinitionScript = preload("res://scripts/combat/dice_face_definition.gd")
const ActionLogEntryScript = preload("res://scripts/core/action_log_entry.gd")
const RunProgressStateScript = preload("res://scripts/run/run_progress_state.gd")
const RewardDraftServiceScript = preload("res://scripts/run/reward_draft_service.gd")

const DEFAULT_HERO_ID := "cyan_ryder"
const DEFAULT_ENEMY_ID := "boss_vanguard"
const DEFAULT_BATTLE_SEED := 20260410

var _loader: ContentLoaderScript
var _state: CombatStateScript
var _rngs: RngStreamsScript
var _logger: ActionLoggerScript
var _simulator: BattleSimulatorScript
var _catalog: CombatCatalogScript
var _run_progress: RunProgressStateScript = RunProgressStateScript.new()
var _reward_service: RewardDraftServiceScript = RewardDraftServiceScript.new()

var _hero_id := DEFAULT_HERO_ID
var _enemy_id := DEFAULT_ENEMY_ID
var _battle_seed := DEFAULT_BATTLE_SEED
var _loadout_face_ids: Array[String] = []
var _managed_by_run := false
var _standalone_rewards := true
var _auto_start := true
var _node_title := ""
var _pending_rewards: Array[Dictionary] = []
var _reward_claimed_this_battle := false
var _reroll_selection: Dictionary = {}
var _is_reroll_mode := false
var _ui_built := false

var _turn_value: Label
var _seed_value: Label
var _result_value: Label
var _feedback_value: Label
var _enemy_intent_value: Label

var _player_name: Label
var _player_hp_bar: ProgressBar
var _player_meta: Label
var _player_status: Label

var _enemy_name: Label
var _enemy_hp_bar: ProgressBar
var _enemy_meta: Label
var _enemy_status: Label

var _reroll_btn: Button
var _reroll_mode_btn: Button
var _clear_reroll_selection_btn: Button
var _end_turn_btn: Button
var _new_battle_btn: Button
var _return_btn: Button
var _card_row: HBoxContainer
var _card_scroll: ScrollContainer
var _log_view: RichTextLabel
var _card_help_title: Label
var _card_help_desc: RichTextLabel
var _run_summary: Label
var _run_preview: Label

var _reward_panel: PanelContainer
var _reward_title: Label
var _reward_desc: Label
var _reward_row: HBoxContainer
var _reward_history_label: Label

func configure_for_run(
	master_seed: int,
	hero_id: String,
	enemy_id: String,
	run_progress: RunProgressStateScript,
	node_title: String = "",
	loadout_face_ids: Array[String] = []
) -> void:
	_battle_seed = master_seed
	_hero_id = hero_id
	_enemy_id = enemy_id
	_run_progress = run_progress
	_loadout_face_ids = []
	for face_id_any in loadout_face_ids:
		_loadout_face_ids.append(String(face_id_any))
	_managed_by_run = true
	_standalone_rewards = false
	_node_title = node_title
	if _ui_built:
		_start_manual_battle()

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()
	if _auto_start:
		_start_manual_battle()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _ui_built and _state != null:
		_render_cards()
		_render_rewards()

func _build_ui() -> void:
	if _ui_built:
		return
	_ui_built = true

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.11, 1.0)
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 18)
	root.add_theme_constant_override("margin_right", 18)
	root.add_theme_constant_override("margin_top", 14)
	root.add_theme_constant_override("margin_bottom", 14)
	add_child(root)

	var main_v := VBoxContainer.new()
	main_v.size_flags_vertical = SIZE_EXPAND_FILL
	main_v.add_theme_constant_override("separation", 10)
	root.add_child(main_v)

	main_v.add_child(_build_header_bar())
	main_v.add_child(_build_battle_stage())
	main_v.add_child(_build_center_info())
	main_v.add_child(_build_actions_tray())
	main_v.add_child(_build_reward_panel())
	main_v.add_child(_build_log_panel())

func _build_header_bar() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.09, 0.12, 0.18), 10, Color(0.25, 0.33, 0.5)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	var title := Label.new()
	title.text = "FurrySTS 战斗演示"
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color(0.9, 0.93, 1.0)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(title)

	_turn_value = Label.new()
	_turn_value.text = "回合 -"
	_turn_value.modulate = Color(0.8, 0.88, 1.0)
	row.add_child(_turn_value)

	_seed_value = Label.new()
	_seed_value.text = "种子 -"
	_seed_value.modulate = Color(0.8, 0.88, 1.0)
	row.add_child(_seed_value)

	return panel

func _build_battle_stage() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 260)
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.07, 0.1, 0.16), 14, Color(0.22, 0.28, 0.42)))

	var stage := HBoxContainer.new()
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_theme_constant_override("separation", 30)
	panel.add_child(stage)

	stage.add_child(_build_unit_panel(false))
	stage.add_child(_build_center_token())
	stage.add_child(_build_unit_panel(true))
	return panel

func _build_unit_panel(is_enemy: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 220)
	var card_color := Color(0.11, 0.14, 0.22) if not is_enemy else Color(0.19, 0.11, 0.14)
	var border_color := Color(0.37, 0.47, 0.73) if not is_enemy else Color(0.75, 0.3, 0.35)
	card.add_theme_stylebox_override("panel", _style_panel(card_color, 12, border_color))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.modulate = Color(0.95, 0.97, 1.0)
	v.add_child(name_label)

	var hp_bar := ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.show_percentage = true
	hp_bar.custom_minimum_size = Vector2(0, 28)
	v.add_child(hp_bar)

	var meta := Label.new()
	meta.modulate = Color(0.78, 0.83, 0.96)
	v.add_child(meta)

	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD
	status.modulate = Color(0.8, 0.86, 1.0)
	v.add_child(status)

	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	v.add_child(spacer)

	var art_stub := ColorRect.new()
	art_stub.custom_minimum_size = Vector2(0, 64)
	art_stub.color = Color(0.14, 0.2, 0.31, 0.75) if not is_enemy else Color(0.33, 0.14, 0.16, 0.75)
	v.add_child(art_stub)

	if is_enemy:
		_enemy_name = name_label
		_enemy_hp_bar = hp_bar
		_enemy_meta = meta
		_enemy_status = status
	else:
		_player_name = name_label
		_player_hp_bar = hp_bar
		_player_meta = meta
		_player_status = status

	return card

func _build_center_token() -> Control:
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.custom_minimum_size = Vector2(200, 180)
	center.add_theme_constant_override("separation", 10)

	var intent_panel := PanelContainer.new()
	intent_panel.add_theme_stylebox_override("panel", _style_panel(Color(0.15, 0.11, 0.22), 10, Color(0.55, 0.42, 0.8)))
	center.add_child(intent_panel)

	_enemy_intent_value = Label.new()
	_enemy_intent_value.custom_minimum_size = Vector2(170, 34)
	_enemy_intent_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_intent_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_enemy_intent_value.add_theme_font_size_override("font_size", 18)
	_enemy_intent_value.modulate = Color(0.95, 0.9, 1.0)
	intent_panel.add_child(_enemy_intent_value)

	_result_value = Label.new()
	_result_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_value.add_theme_font_size_override("font_size", 16)
	_result_value.modulate = Color(0.92, 0.95, 1.0)
	center.add_child(_result_value)

	_feedback_value = Label.new()
	_feedback_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_value.autowrap_mode = TextServer.AUTOWRAP_WORD
	_feedback_value.custom_minimum_size = Vector2(230, 0)
	_feedback_value.modulate = Color(0.75, 0.87, 1.0)
	center.add_child(_feedback_value)

	return center

func _build_center_info() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.08, 0.1, 0.16), 10, Color(0.22, 0.28, 0.42)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var labels := [
		"流程：掷 3 选 2，然后敌方行动。",
		"操作：点骰子释放技能；进入重骰模式后可多选。",
		"目标：在自己倒下前把敌方血量打到 0。"
	]
	for text in labels:
		var chip := Label.new()
		chip.text = text
		chip.modulate = Color(0.78, 0.86, 1.0)
		chip.size_flags_horizontal = SIZE_EXPAND_FILL
		chip.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(chip)
	return panel

func _build_actions_tray() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 210)
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.07, 0.09, 0.14), 12, Color(0.24, 0.3, 0.45)))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	v.add_child(controls)

	_new_battle_btn = Button.new()
	_new_battle_btn.text = "新战斗"
	_new_battle_btn.pressed.connect(_start_manual_battle)
	controls.add_child(_new_battle_btn)

	_return_btn = Button.new()
	_return_btn.text = "返回 Run"
	_return_btn.visible = _managed_by_run
	_return_btn.disabled = true
	_return_btn.pressed.connect(_on_return_pressed)
	controls.add_child(_return_btn)

	_reroll_mode_btn = Button.new()
	_reroll_mode_btn.text = "选择重骰：关"
	_reroll_mode_btn.pressed.connect(_on_reroll_mode_toggled)
	controls.add_child(_reroll_mode_btn)

	_reroll_btn = Button.new()
	_reroll_btn.text = "执行重骰"
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	controls.add_child(_reroll_btn)

	_clear_reroll_selection_btn = Button.new()
	_clear_reroll_selection_btn.text = "清空重骰选择"
	_clear_reroll_selection_btn.pressed.connect(_on_clear_reroll_selection_pressed)
	controls.add_child(_clear_reroll_selection_btn)

	_end_turn_btn = Button.new()
	_end_turn_btn.text = "结束回合"
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	controls.add_child(_end_turn_btn)

	var tray_title := Label.new()
	tray_title.text = "骰子区"
	tray_title.modulate = Color(0.92, 0.95, 1.0)
	tray_title.add_theme_font_size_override("font_size", 18)
	v.add_child(tray_title)

	_run_summary = Label.new()
	_run_summary.autowrap_mode = TextServer.AUTOWRAP_WORD
	_run_summary.modulate = Color(0.76, 0.86, 1.0)
	v.add_child(_run_summary)

	_run_preview = Label.new()
	_run_preview.autowrap_mode = TextServer.AUTOWRAP_WORD
	_run_preview.modulate = Color(0.9, 0.82, 0.66)
	v.add_child(_run_preview)

	_card_scroll = ScrollContainer.new()
	_card_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card_scroll.custom_minimum_size = Vector2(0, 138)
	v.add_child(_card_scroll)

	_card_row = HBoxContainer.new()
	_card_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_card_row.add_theme_constant_override("separation", 10)
	_card_row.size_flags_horizontal = SIZE_EXPAND_FILL
	_card_scroll.add_child(_card_row)

	var help_panel := PanelContainer.new()
	help_panel.custom_minimum_size = Vector2(0, 90)
	help_panel.add_theme_stylebox_override("panel", _style_panel(Color(0.09, 0.12, 0.18), 8, Color(0.24, 0.36, 0.56)))
	v.add_child(help_panel)

	var help_v := VBoxContainer.new()
	help_v.add_theme_constant_override("separation", 4)
	help_panel.add_child(help_v)

	_card_help_title = Label.new()
	_card_help_title.text = "技能说明"
	_card_help_title.add_theme_font_size_override("font_size", 16)
	_card_help_title.modulate = Color(0.92, 0.96, 1.0)
	help_v.add_child(_card_help_title)

	_card_help_desc = RichTextLabel.new()
	_card_help_desc.bbcode_enabled = false
	_card_help_desc.fit_content = false
	_card_help_desc.scroll_active = false
	_card_help_desc.custom_minimum_size = Vector2(0, 52)
	_card_help_desc.add_theme_font_size_override("normal_font_size", 14)
	help_v.add_child(_card_help_desc)

	return panel

func _build_reward_panel() -> Control:
	_reward_panel = PanelContainer.new()
	_reward_panel.visible = false
	_reward_panel.custom_minimum_size = Vector2(0, 150)
	_reward_panel.add_theme_stylebox_override("panel", _style_panel(Color(0.1, 0.11, 0.08), 12, Color(0.68, 0.58, 0.28)))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_reward_panel.add_child(v)

	_reward_title = Label.new()
	_reward_title.text = "战后奖励"
	_reward_title.add_theme_font_size_override("font_size", 18)
	_reward_title.modulate = Color(1.0, 0.96, 0.85)
	v.add_child(_reward_title)

	_reward_desc = Label.new()
	_reward_desc.text = "胜利后选择 1 个奖励，强化会带到下一场战斗。"
	_reward_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_reward_desc.modulate = Color(0.96, 0.9, 0.76)
	v.add_child(_reward_desc)

	_reward_history_label = Label.new()
	_reward_history_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_reward_history_label.modulate = Color(0.85, 0.82, 0.7)
	v.add_child(_reward_history_label)

	_reward_row = HBoxContainer.new()
	_reward_row.add_theme_constant_override("separation", 10)
	v.add_child(_reward_row)

	return _reward_panel

func _build_log_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 100)
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style_panel(Color(0.05, 0.07, 0.1), 10, Color(0.2, 0.25, 0.4)))

	_log_view = RichTextLabel.new()
	_log_view.fit_content = false
	_log_view.scroll_following = true
	_log_view.bbcode_enabled = false
	panel.add_child(_log_view)
	return panel

func _start_manual_battle() -> void:
	_loader = ContentLoaderScript.new()
	var factory := UnitFactoryScript.new(_loader)
	_catalog = CombatCatalogScript.new(_loader)
	var enemy_row := _loader.find_row_by_id("enemies", _enemy_id)

	var player := factory.create_npc(_hero_id, _loadout_face_ids)
	if _run_progress != null:
		_run_progress.apply_all_to_unit(player, true)
	_state = CombatStateScript.new(player, factory.create_enemy(_enemy_id))
	_rngs = RngStreamsScript.new(SeedBundleScript.new(_battle_seed))
	_logger = ActionLoggerScript.new()
	_simulator = BattleSimulatorScript.new(_catalog, enemy_row)
	_reroll_selection.clear()
	_is_reroll_mode = false
	_pending_rewards.clear()
	_reward_claimed_this_battle = false

	_simulator.start_manual_player_turn(_state, _rngs, _logger)
	_feedback_value.text = "战斗开始，点击骰子释放技能。"
	_set_card_help(null)
	_render_ui()

func _render_ui() -> void:
	if _state == null:
		return

	if _standalone_rewards and _state.battle_ended() and _state.player.is_alive() and not _reward_claimed_this_battle and _pending_rewards.is_empty():
		_pending_rewards = _reward_service.draft_rewards(_catalog, _rngs, 3)

	_turn_value.text = "回合 %d" % _state.turn_index
	_seed_value.text = "种子 %d" % _battle_seed

	_player_name.text = _pretty_id(_state.player.unit_id)
	_player_hp_bar.max_value = _state.player.max_hp
	_player_hp_bar.value = _state.player.hp
	_player_meta.text = "生命 %d/%d | 护甲 %d | 资源 %d/%d（%s）" % [
		_state.player.hp,
		_state.player.max_hp,
		_state.player.block,
		_state.player.resource.current_value,
		_state.player.resource.cap_value,
		_state.player.resource.resource_type
	]
	_player_status.text = "已选 %d/%d | 重骰次数 %d | 额外抽骰 %d | 锁定 %d" % [
		_state.picks_used,
		_state.picks_budget,
		_state.rerolls_left,
		_state.bonus_rolls,
		_state.locked_face_ids.size()
	]

	_enemy_name.text = _pretty_id(_state.enemy.unit_id)
	_enemy_hp_bar.max_value = _state.enemy.max_hp
	_enemy_hp_bar.value = _state.enemy.hp
	_enemy_meta.text = "生命 %d/%d | 护甲 %d | 标记 %d" % [
		_state.enemy.hp,
		_state.enemy.max_hp,
		_state.enemy.block,
		_state.enemy.marks
	]
	_enemy_status.text = "破绽增伤 +%d" % _state.enemy.rupture_bonus

	if _state.battle_ended():
		_enemy_intent_value.text = "敌方意图：-"
		_result_value.text = "战斗结果：%s" % ("胜利" if _state.player.is_alive() else "失败")
		if _managed_by_run:
			_feedback_value.text = "战斗已结束，点击“返回 Run”回到路线层。"
	else:
		var intent := _simulator.preview_enemy_intent(_state, _rngs)
		_enemy_intent_value.text = "敌方意图：攻击 %d（%s）" % [intent.attack_value, intent.source]
		_result_value.text = "战斗结果：进行中"

	_run_summary.text = _battle_context_summary()
	_run_preview.text = _next_battle_preview()

	_render_cards()
	_render_rewards()
	_render_log()
	_reroll_mode_btn.text = "选择重骰：%s" % ("开" if _is_reroll_mode else "关")
	_reroll_btn.disabled = _state.battle_ended() or _state.rerolls_left <= 0
	_clear_reroll_selection_btn.disabled = _reroll_selection.is_empty()
	_reroll_mode_btn.disabled = _state.battle_ended()
	_end_turn_btn.disabled = _state.battle_ended() or _simulator.can_player_act(_state)
	_new_battle_btn.visible = not _managed_by_run
	_new_battle_btn.disabled = _state.battle_ended() and _state.player.is_alive() and _standalone_rewards and not _reward_claimed_this_battle and not _pending_rewards.is_empty()
	_return_btn.visible = _managed_by_run
	_return_btn.disabled = not _state.battle_ended()

func _render_cards() -> void:
	for child in _card_row.get_children():
		child.queue_free()

	if _state.battle_ended():
		var end_label := Label.new()
		end_label.text = "战斗已结束。"
		if _managed_by_run:
			end_label.text += " 请返回 Run 继续推进。"
		elif _standalone_rewards and _state.player.is_alive():
			end_label.text += " 请先选择战后奖励，再开始新战斗。"
		end_label.modulate = Color(0.82, 0.9, 0.96)
		_card_row.add_child(end_label)
		return

	if _state.rolled_faces.is_empty():
		var empty := Label.new()
		empty.text = "当前没有可用骰子，请结束回合。"
		empty.modulate = Color(0.72, 0.8, 0.96)
		_card_row.add_child(empty)
		return

	for slot_index in range(_state.rolled_faces.size()):
		var face: DiceFaceDefinitionScript = _state.rolled_faces[slot_index]
		var is_locked := _state.locked_face_ids.has(face.face_id)
		var is_selected_for_reroll := _reroll_selection.has(slot_index)
		var card := Button.new()
		card.custom_minimum_size = Vector2(_card_width_for(_state.rolled_faces.size()), 132)
		var face_name := _face_name(face.face_id)
		var short_desc := _face_short_desc(face)
		var slot_label := "槽位 #%d" % (slot_index + 1)
		if is_locked:
			slot_label += "（锁定）"
		elif _is_reroll_mode and is_selected_for_reroll:
			slot_label += "（已选重骰）"
		card.text = "%s\n%s\n%s\n类型:%s  消耗:%s %d" % [
			slot_label,
			face_name,
			short_desc,
			face.die_type,
			face.cost_type,
			face.cost_value
		]
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.autowrap_mode = TextServer.AUTOWRAP_WORD
		card.add_theme_font_size_override("font_size", 15)
		card.add_theme_stylebox_override("normal", _style_card(Color(0.16, 0.2, 0.31), Color(0.39, 0.5, 0.78)))
		card.add_theme_stylebox_override("hover", _style_card(Color(0.2, 0.25, 0.39), Color(0.63, 0.75, 0.99)))
		card.add_theme_stylebox_override("pressed", _style_card(Color(0.12, 0.16, 0.25), Color(0.83, 0.92, 1.0)))
		card.tooltip_text = _face_long_desc(face)
		var can_pay := face.cost_type == "none" or (face.cost_type == _state.player.resource.resource_type and _state.player.resource.current_value >= face.cost_value)
		card.disabled = is_locked or (not _is_reroll_mode and not can_pay)
		card.mouse_entered.connect(_set_card_help.bind(face))
		card.pressed.connect(_on_card_pressed.bind(slot_index))
		_card_row.add_child(card)

func _render_rewards() -> void:
	if _reward_panel == null:
		return

	for child in _reward_row.get_children():
		child.queue_free()

	var show_rewards := _standalone_rewards and _state != null and _state.battle_ended() and _state.player.is_alive() and not _reward_claimed_this_battle and not _pending_rewards.is_empty()
	_reward_panel.visible = show_rewards
	if not show_rewards:
		return

	_reward_title.text = "战后奖励：三选一"
	_reward_desc.text = "选择 1 个奖励并带入下一场。战斗型强化只在下一场生效，Run 型强化会持续保留。"
	_reward_history_label.text = _reward_history_text()
	for i in range(_pending_rewards.size()):
		var reward: Dictionary = _pending_rewards[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(240, 112)
		var rarity_label := str(reward.get("rarity_label", "普通"))
		var scope_label := str(reward.get("scope_label", "下一场"))
		btn.text = "[%s | %s]\n%s\n%s" % [
			rarity_label,
			scope_label,
			str(reward.get("title", "奖励")),
			str(reward.get("description", ""))
		]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var rarity_colors := _reward_colors(str(reward.get("rarity", "common")))
		btn.add_theme_stylebox_override("normal", _style_card(rarity_colors["bg"], rarity_colors["border"]))
		btn.add_theme_stylebox_override("hover", _style_card(rarity_colors["hover_bg"], rarity_colors["hover_border"]))
		btn.pressed.connect(_on_reward_selected.bind(i))
		_reward_row.add_child(btn)

func _render_log() -> void:
	_log_view.clear()
	if _logger == null:
		return
	var entries := _logger.entries()
	var start := maxi(0, entries.size() - 16)
	for i in range(start, entries.size()):
		var entry: ActionLogEntryScript = entries[i]
		var payload: Dictionary = entry.payload if typeof(entry.payload) == TYPE_DICTIONARY else {}
		_log_view.append_text(_format_log_line(entry, payload) + "\n")

func _on_card_pressed(slot_index: int) -> void:
	if _state == null or _state.battle_ended():
		return
	if slot_index < 0 or slot_index >= _state.rolled_faces.size():
		return
	if _is_reroll_mode:
		_toggle_reroll_slot(slot_index)
		_render_ui()
		return

	var face: DiceFaceDefinitionScript = _state.rolled_faces[slot_index]
	var face_id := str(face.face_id)
	if not _simulator.apply_manual_face_pick_at(_state, _rngs, _logger, slot_index):
		_feedback_value.text = "行动被拒绝：%s" % face_id
		return

	_set_card_help(_find_face_by_id(face_id))
	_feedback_value.text = "已施放：%s" % _face_name(face_id)
	_reroll_selection.clear()
	if _state.picks_used >= _state.picks_budget and not _state.battle_ended():
		_simulator.run_manual_enemy_phase(_state, _rngs, _logger)
		if not _state.battle_ended():
			_simulator.start_manual_player_turn(_state, _rngs, _logger)
	_render_ui()

func _on_reroll_pressed() -> void:
	if _state == null or _state.battle_ended():
		return
	var selected := _selected_reroll_indices()
	if _simulator.manual_reroll_selected(_state, _rngs, selected):
		_feedback_value.text = "已重骰 %d 个槽位。" % selected.size()
		_reroll_selection.clear()
		_is_reroll_mode = false
	else:
		if selected.is_empty():
			_feedback_value.text = "请先开启重骰模式并选择至少 1 个槽位。"
		else:
			_feedback_value.text = "当前无法执行重骰。"
	_render_ui()

func _on_end_turn_pressed() -> void:
	if _state == null or _state.battle_ended():
		return
	_feedback_value.text = "回合结束。"
	_reroll_selection.clear()
	_is_reroll_mode = false
	_simulator.run_manual_enemy_phase(_state, _rngs, _logger)
	if not _state.battle_ended():
		_simulator.start_manual_player_turn(_state, _rngs, _logger)
	_render_ui()

func _on_reroll_mode_toggled() -> void:
	_is_reroll_mode = not _is_reroll_mode
	if not _is_reroll_mode:
		_reroll_selection.clear()
	_feedback_value.text = "重骰模式：%s" % ("开启，点击骰子进行选择。" if _is_reroll_mode else "关闭。")
	_render_ui()

func _on_clear_reroll_selection_pressed() -> void:
	_reroll_selection.clear()
	_feedback_value.text = "已清空重骰选择。"
	_render_ui()

func _on_reward_selected(index: int) -> void:
	if index < 0 or index >= _pending_rewards.size():
		return
	var reward := _pending_rewards[index]
	var result := _reward_service.apply_reward(_run_progress, reward)
	if not bool(result.get("ok", false)):
		_feedback_value.text = "奖励应用失败。"
		return
	_reward_claimed_this_battle = true
	_pending_rewards.clear()
	_feedback_value.text = "已获得奖励：%s" % str(reward.get("title", "奖励"))
	_render_ui()

func _on_return_pressed() -> void:
	if _state == null or not _state.battle_ended():
		return
	var payload := {
		"winner": _state.player.unit_id if _state.player.is_alive() else _state.enemy.unit_id,
		"victory": _state.player.is_alive(),
		"enemy_id": _enemy_id,
		"log_size": _logger.entries().size(),
		"turns": _state.turn_index
	}
	battle_closed.emit(_state.player.is_alive(), payload)
	queue_free()

func _toggle_reroll_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _state.rolled_faces.size():
		return
	var face: DiceFaceDefinitionScript = _state.rolled_faces[slot_index]
	if _state.locked_face_ids.has(face.face_id):
		_feedback_value.text = "该骰面已锁定，不能重骰。"
		return
	if _reroll_selection.has(slot_index):
		_reroll_selection.erase(slot_index)
		_feedback_value.text = "取消重骰：槽位 #%d" % (slot_index + 1)
	else:
		_reroll_selection[slot_index] = true
		_feedback_value.text = "选择重骰：槽位 #%d" % (slot_index + 1)

func _selected_reroll_indices() -> Array[int]:
	var out: Array[int] = []
	for key_any in _reroll_selection.keys():
		out.append(int(key_any))
	out.sort()
	return out

func _set_card_help(face: Variant) -> void:
	if face == null:
		_card_help_title.text = "技能说明"
		_card_help_desc.clear()
		_card_help_desc.append_text("把鼠标停在骰子上，或点击骰子，查看技能效果说明。")
		return
	_card_help_title.text = _face_name(str(face.face_id))
	_card_help_desc.clear()
	_card_help_desc.append_text(_face_long_desc(face))

func _find_face_by_id(face_id: String) -> Variant:
	if _state == null:
		return null
	for face_any in _state.rolled_faces:
		var face: DiceFaceDefinitionScript = face_any
		if str(face.face_id) == face_id:
			return face
	return null

func _card_width_for(card_count: int) -> float:
	var usable: float = maxf(size.x - 80.0, 540.0)
	var spacing: float = 10.0 * float(maxi(card_count - 1, 0))
	var width: float = (usable - spacing) / float(maxi(card_count, 1))
	return clamp(width, 200.0, 320.0)

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
	var words := face_id.split("_", false)
	var out: Array[String] = []
	for w_any in words:
		var w := str(w_any).strip_edges()
		if w == "":
			continue
		if w in ["cyan", "helios", "black", "umbral"]:
			continue
		out.append(w.capitalize())
	if out.is_empty():
		return face_id
	return " ".join(out)

func _face_short_desc(face: DiceFaceDefinitionScript) -> String:
	if _catalog == null:
		return "无数据"
	var effects: Array[Dictionary] = _catalog.effects_for_bundle(str(face.effect_bundle_id))
	if effects.is_empty():
		return "无效果"
	return _effect_to_text(effects[0])

func _face_long_desc(face: DiceFaceDefinitionScript) -> String:
	if _catalog == null:
		return "无数据。"
	var lines: Array[String] = []
	lines.append("技能 ID：%s" % str(face.face_id))
	lines.append("标签：%s" % "|".join(face.tags))
	var effects: Array[Dictionary] = _catalog.effects_for_bundle(str(face.effect_bundle_id))
	if effects.is_empty():
		lines.append("效果：无")
		return "\n".join(lines)
	lines.append("效果：")
	for effect_any in effects:
		var effect: Dictionary = effect_any
		lines.append("- " + _effect_to_text(effect))
	return "\n".join(lines)

func _effect_to_text(effect: Dictionary) -> String:
	var op := str(effect.get("op_type", ""))
	var value := str(effect.get("value", ""))
	match op:
		"damage":
			return "造成 %s 点伤害。" % value
		"damage_multihit":
			return "造成多段伤害（%s）。" % value
		"damage_ignore_block":
			return "造成穿透伤害（%s）。" % value
		"add_block":
			return "获得 %s 点护甲。" % value
		"add_mark":
			return "施加 %s 层标记。" % value
		"mod_resource":
			return "资源变化：%s。" % value
		"mod_resource_if_marked":
			return "若目标带标记，资源变化：%s。" % value
		"add_temp_ranged_flat":
			return "本回合远程攻击额外 +%s。" % value
		"conditional_damage_if_resource_ge":
			return "满足资源条件时追加伤害：%s。" % value
		"grant_reroll":
			return "获得 +%s 次重骰机会。" % value
		"grant_bonus_roll":
			return "获得 +%s 次额外抽骰。" % value
		"set_next_attack_mult":
			return "下一次攻击倍率设为 %s。" % value
		"set_next_attack_ignore_block":
			return "下一次攻击额外无视 %s 护甲。" % value
		"add_rupture":
			return "施加破绽增伤 +%s。" % value
		"conditional_block_if_resource_ge":
			return "满足资源条件时额外获得护甲：%s。" % value
		"consume_mark_to_damage":
			return "消耗标记转化伤害（%s）。" % value
		"set_thorns":
			return "获得反伤：%s。" % value
		_:
			return "%s：%s" % [op, value]

func _format_log_line(entry: ActionLogEntryScript, payload: Dictionary) -> String:
	var t := int(entry.turn_index)
	var ev := str(entry.event_type)
	var actor := str(entry.actor_id)
	var target := str(entry.target_id)
	var face_name := ""
	if payload.has("face_id"):
		face_name = _face_name(str(payload["face_id"]))
	if ev == "player_attack":
		return "T%02d %s 使用 %s -> %s 受到 %s 伤害（HP %s）。" % [
			t, _pretty_id(actor), face_name, _pretty_id(target), str(payload.get("damage", "?")), str(payload.get("target_hp", "?"))
		]
	if ev == "enemy_attack":
		return "T%02d 敌方攻击值 %s -> 你受到 %s 伤害（HP %s）。" % [
			t, str(payload.get("value", "?")), str(payload.get("damage", "?")), str(payload.get("target_hp", "?"))
		]
	if ev == "resource_changed":
		return "T%02d 资源变化 %s -> %s。" % [
			t, str(payload.get("pre_resource", "?")), str(payload.get("post_resource", "?"))
		]
	if ev == "dice_locked":
		return "T%02d 过载锁定骰面：%s。" % [t, str(payload.get("locked_faces", []))]
	if ev == "action_rejected":
		return "T%02d 动作被拒绝（%s）。" % [t, str(payload.get("reason", ""))]
	if ev == "bonus_roll_granted":
		return "T%02d 获得额外抽骰，当前数量 %s。" % [t, str(payload.get("bonus_rolls", "?"))]
	return "T%02d %s %s -> %s" % [t, ev, _pretty_id(actor), _pretty_id(target)]

func _battle_context_summary() -> String:
	if _managed_by_run:
		var node_suffix := _node_title if _node_title != "" else _enemy_id
		return "Run 战斗节点：%s | Credits %d | 成长 %d 项" % [
			node_suffix,
			_run_progress.get_currency("credits"),
			_run_progress.all_growths().size()
		]
	return "Standalone 战斗 | Credits %d | 已保存成长 %d 项 | %s" % [
		_run_progress.get_currency("credits"),
		_run_progress.all_growths().size(),
		_growth_summary()
	]

func _growth_summary() -> String:
	var growths := _run_progress.all_growths()
	if growths.is_empty():
		return "暂无成长"
	var parts: Array[String] = []
	for growth_any in growths:
		var growth: Dictionary = growth_any
		var target := str(growth.get("target", ""))
		var delta := int(growth.get("delta", "0"))
		if target == "temp_ranged_flat":
			parts.append("远程+%d" % delta)
		elif target == "base_hp":
			parts.append("生命+%d" % delta)
		elif target == "block":
			parts.append("护甲+%d" % delta)
		elif target == "resource_cap":
			parts.append("上限+%d" % delta)
		else:
			parts.append("%s+%d" % [target, delta])
		if parts.size() >= 3:
			break
	return "、".join(parts)

func _next_battle_preview() -> String:
	var loader := _loader if _loader != null else ContentLoaderScript.new()
	var factory := UnitFactoryScript.new(loader)
	var preview_unit := factory.create_npc(_hero_id, _loadout_face_ids)
	_run_progress.apply_all_to_unit(preview_unit, false)
	return "下一场预览：生命 %d/%d | 资源 %d/%d（%s）| 护甲 %d" % [
		preview_unit.hp,
		preview_unit.max_hp,
		preview_unit.resource.current_value,
		preview_unit.resource.cap_value,
		preview_unit.resource.resource_type,
		preview_unit.block
	]

func _reward_history_text() -> String:
	var growths := _run_progress.all_growths()
	if growths.is_empty():
		return "当前未获得强化。"
	var names: Array[String] = []
	for growth_any in growths:
		var growth: Dictionary = growth_any
		names.append(_growth_short_name(growth))
		if names.size() >= 4:
			break
	return "已获得强化：%s" % "、".join(names)

func _growth_short_name(growth: Dictionary) -> String:
	var target := str(growth.get("target", ""))
	var delta := int(growth.get("delta", "0"))
	if target == "temp_ranged_flat":
		return "远程+%d" % delta
	if target == "base_hp":
		return "生命+%d" % delta
	if target == "block":
		return "护甲+%d" % delta
	if target == "resource_cap":
		return "资源上限+%d" % delta
	return "%s+%d" % [target, delta]

func _reward_colors(rarity: String) -> Dictionary:
	match rarity:
		"rare":
			return {
				"bg": Color(0.27, 0.18, 0.08),
				"border": Color(0.98, 0.84, 0.38),
				"hover_bg": Color(0.34, 0.24, 0.11),
				"hover_border": Color(1.0, 0.92, 0.56)
			}
		"uncommon":
			return {
				"bg": Color(0.13, 0.24, 0.16),
				"border": Color(0.46, 0.88, 0.56),
				"hover_bg": Color(0.16, 0.3, 0.2),
				"hover_border": Color(0.62, 0.96, 0.68)
			}
		_:
			return {
				"bg": Color(0.2, 0.2, 0.22),
				"border": Color(0.72, 0.75, 0.82),
				"hover_bg": Color(0.25, 0.25, 0.29),
				"hover_border": Color(0.86, 0.9, 0.98)
			}

func _style_panel(bg: Color, radius: int, border: Color) -> StyleBoxFlat:
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
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _style_card(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = border
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _pretty_id(id: String) -> String:
	var zh_names := {
		"cyan_ryder": "Cyan Ryder（蓝龙）",
		"helios_windchaser": "Helios Windchaser（狮鹫）",
		"umbral_draxx": "黑龙（暂名）",
		"boss_vanguard": "先锋巨兽",
		"reef_stalker": "礁海潜猎体",
		"void_howler": "虚空嚎兽"
	}
	if zh_names.has(id):
		return zh_names[id]
	var tokens := id.split("_", false)
	for i in range(tokens.size()):
		tokens[i] = tokens[i].capitalize()
	return " ".join(tokens)
