extends CanvasLayer


@warning_ignore("unused_signal")
signal notification_finished()
@warning_ignore("unused_signal")
signal tax_payment_requested()
@warning_ignore("unused_signal")
signal tax_ignore_requested()

@onready var gold_label: Label = $TopLeftHUD/GoldLabel
@onready var target_label: Label = $TopLeftHUD/TargetLabel
@onready var day_label: Label = $TopCenterHUD/DayLabel
@onready var phase_label: Label = $TopCenterHUD/PhaseLabel
@onready var time_label: Label = $TopCenterHUD/TimeLabel
@onready var notification_label: Label = $NotificationLabel
@onready var objective_label: Label = $ObjectiveLabel
@onready var dialog: Dialog = $Dialog
@onready var settings_button: Button = $TopRightHUD/SettingsButton

const NOTIFY_DURATION: float = 2.0
const MIN_NOTIFY_DURATION: float = 0.9
const NOTIFY_CHARS_PER_SECOND: float = 34.0
const HINT_DIALOG_WIDTH: float = 300.0
const HINT_DIALOG_HEIGHT: float = 54.0
const HINT_DIALOG_BOTTOM_MARGIN: float = 74.0
const HINT_DIALOG_DURATION: float = 1.0
const CURSOR_TOOLTIP_OFFSET := Vector2(12, 14)
const CURSOR_TOOLTIP_PADDING := Vector2(12, 8)
const CURSOR_HOVER_QUERY_LIMIT: int = 32
const OBJECTIVE_TOAST_DURATION: float = 5.0
const OBJECTIVE_ANIM_DURATION: float = 0.22

const SETTINGS_LAYER: int = 100

@warning_ignore("unused_private_class_variable")
var _settings_menu: SettingsMenu = null
@warning_ignore("unused_private_class_variable")
var _settings_layer: CanvasLayer = null

@warning_ignore("unused_private_class_variable")
var _notify_timer: float = 0.0
@warning_ignore("unused_private_class_variable")
var _notify_duration: float = NOTIFY_DURATION
@warning_ignore("unused_private_class_variable")
var _notify_full_chars: int = 0
@warning_ignore("unused_private_class_variable")
var _notify_instant_text: bool = false
@warning_ignore("unused_private_class_variable")
var _action_lock_timer: float = 0.0
@warning_ignore("unused_private_class_variable")
var _action_lock_sessions: int = 0
@warning_ignore("unused_private_class_variable")
var _notification_finished_emitted: bool = true
@warning_ignore("unused_private_class_variable")
var _hint_dialog: ColorRect = null
@warning_ignore("unused_private_class_variable")
var _hint_label: Label = null
@warning_ignore("unused_private_class_variable")
var _hint_tween: Tween = null
@warning_ignore("unused_private_class_variable")
var _hint_dialog_visible: bool = false
@warning_ignore("unused_private_class_variable")
var _hint_dialog_timer: float = 0.0
@warning_ignore("unused_private_class_variable")
var _cursor_tooltip: ColorRect = null
@warning_ignore("unused_private_class_variable")
var _cursor_tooltip_label: Label = null
@warning_ignore("unused_private_class_variable")
var _cursor_tooltip_tween: Tween = null
@warning_ignore("unused_private_class_variable")
var _cursor_tooltip_visible: bool = false
@warning_ignore("unused_private_class_variable")
var _cursor_tooltip_text: String = ""
@warning_ignore("unused_private_class_variable")
var _objective_tween: Tween = null
@warning_ignore("unused_private_class_variable")
var _objective_timer: float = 0.0
@warning_ignore("unused_private_class_variable")
var _objective_base_position: Vector2 = Vector2.ZERO
@warning_ignore("unused_private_class_variable")
var _tax_layer: CanvasLayer = null
@warning_ignore("unused_private_class_variable")
var _tax_panel: ColorRect = null
@warning_ignore("unused_private_class_variable")
var _tax_title_label: Label = null
@warning_ignore("unused_private_class_variable")
var _tax_report_label: Label = null
@warning_ignore("unused_private_class_variable")
var _tax_warning_label: Label = null

@warning_ignore("unused_private_class_variable")
var _tax_notice_button: Button = null
@warning_ignore("unused_private_class_variable")
var _pending_tax_report: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _pending_tax_warning: String = ""

@warning_ignore("unused_private_class_variable")
var _status_labels: HUDStatusLabels = HUDStatusLabels.new()
@warning_ignore("unused_private_class_variable")
var _notification_flow: HUDNotificationFlow = HUDNotificationFlow.new()
@warning_ignore("unused_private_class_variable")
var _dialog_controller: HUDDialogController = HUDDialogController.new()
@warning_ignore("unused_private_class_variable")
var _dialog_skip_flow: HUDDialogSkipFlow = HUDDialogSkipFlow.new()
@warning_ignore("unused_private_class_variable")
var _tax_panel_flow: HUDTaxPanel = HUDTaxPanel.new()
@warning_ignore("unused_private_class_variable")
var _hint_dialog_flow: HUDHintDialog = HUDHintDialog.new()
@warning_ignore("unused_private_class_variable")
var _cursor_tooltip_flow: HUDCursorTooltip = HUDCursorTooltip.new()
@warning_ignore("unused_private_class_variable")
var _objective_toast_flow: HUDObjectiveToast = HUDObjectiveToast.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_hud_controllers()
	notification_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_base_position = objective_label.position
	objective_label.visible = false
	objective_label.modulate.a = 0.0
	_create_hint_dialog()
	_create_cursor_tooltip()

	EconomyManager.gold_changed.connect(_on_gold_changed)
	EconomyManager.daily_target_reached.connect(_on_target_reached)
	TimeManager.time_updated.connect(_on_time_updated)
	TimeManager.phase_changed.connect(_on_phase_changed)
	TimeManager.day_started.connect(_on_day_started)

	settings_button.pressed.connect(_on_settings_pressed)

	_update_all()

	notification_label.visible = false
	notification_label.modulate.a = 0.0
	notification_label.visible_characters = 0


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_hud_controllers() -> void:
	for controller in [
		_status_labels,
		_notification_flow,
		_dialog_controller,
		_dialog_skip_flow,
		_tax_panel_flow,
		_hint_dialog_flow,
		_cursor_tooltip_flow,
		_objective_toast_flow
	]:
		controller.setup(self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_objective_toast_flow.update_objective_toast(delta)
	_cursor_tooltip_flow.update_cursor_hover_tooltip()
	_hint_dialog_flow.update_hint_dialog_timer(delta)
	_notification_flow.process(delta)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _input(event: InputEvent) -> void:
	_handle_dialog_skip_input(event)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _unhandled_input(event: InputEvent) -> void:
	_handle_dialog_skip_input(event)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _handle_dialog_skip_input(event: InputEvent) -> void:
	_dialog_skip_flow.handle_dialog_skip_input(event)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_dialog_skip_event(event: InputEvent) -> bool:
	return _dialog_skip_flow.is_dialog_skip_event(event)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _skip_world_dialogs() -> bool:
	return _dialog_skip_flow.skip_world_dialogs()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _has_interactive_overlay_open() -> bool:
	return _dialog_skip_flow.has_interactive_overlay_open()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _has_visible_overlay_named(node_name: String) -> bool:
	return _dialog_skip_flow.has_visible_overlay_named(node_name)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _find_visible_overlay_named(node: Node, node_name: String) -> bool:
	return _dialog_skip_flow.find_visible_overlay_named(node, node_name)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _has_visible_overlay_content(node: Node) -> bool:
	return _dialog_skip_flow.has_visible_overlay_content(node)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_notification(
	text: String,
	duration: float = NOTIFY_DURATION,
	blocks_actions: bool = true,
	instant_text: bool = false
) -> void:
	_notification_flow.show_notification(text, duration, blocks_actions, instant_text)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_dialog_sequence(dialogues: Array[Dictionary]) -> void:
	await _dialog_controller.show_dialog_sequence(dialogues)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_dialog_visible() -> bool:
	return _dialog_controller.is_visible()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_tax_report(report: Dictionary) -> void:
	_tax_panel_flow.show_tax_report(report)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_tax_warning(message: String, report: Dictionary = {}) -> void:
	_tax_panel_flow.show_tax_warning(message, report)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func hide_tax_report() -> void:
	_tax_panel_flow.hide_tax_report()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_tax_notice(report: Dictionary, warning: String = "") -> void:
	_tax_panel_flow.show_tax_notice(report, warning)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func hide_tax_notice() -> void:
	_tax_panel_flow.hide_tax_notice()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_hint_dialog(key: String, text: String) -> void:
	_hint_dialog_flow.show_hint_dialog(key, text)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_cursor_tooltip(text: String) -> void:
	_cursor_tooltip_flow.show_cursor_tooltip(text)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func hide_cursor_tooltip() -> void:
	_cursor_tooltip_flow.hide_cursor_tooltip()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_cursor_hover_tooltip() -> void:
	_cursor_tooltip_flow.update_cursor_hover_tooltip()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_cursor_world_hover_text() -> String:
	return _cursor_tooltip_flow.get_cursor_world_hover_text()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_hover_candidate_from_area(area: Area2D) -> Dictionary:
	return _cursor_tooltip_flow.get_hover_candidate_from_area(area)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_shelf_slot_hover_candidate(area: Area2D) -> Dictionary:
	return _cursor_tooltip_flow.get_shelf_slot_hover_candidate(area)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_door_hover_text(area: Area2D) -> String:
	return _cursor_tooltip_flow.get_door_hover_text(area)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_hover_target_priority(target: Node) -> int:
	return _cursor_tooltip_flow.get_hover_target_priority(target)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_objective(text: String) -> void:
	_objective_toast_flow.set_objective(text)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_objective_toast(delta: float) -> void:
	_objective_toast_flow.update_objective_toast(delta)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _hide_objective_toast(animated: bool) -> void:
	_objective_toast_flow.hide_objective_toast(animated)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_readable_notification_duration(text: String, requested_duration: float) -> float:
	return _notification_flow.get_readable_notification_duration(text, requested_duration)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func wait_for_notification_finished() -> void:
	await _notification_flow.wait_for_notification_finished()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func begin_action_lock() -> void:
	_notification_flow.begin_action_lock()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func end_action_lock() -> void:
	_notification_flow.end_action_lock()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_action_locked() -> bool:
	return _notification_flow.is_action_locked()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_interactive_overlay_open() -> bool:
	return _has_interactive_overlay_open()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _finish_notification() -> void:
	_notification_flow.finish_notification()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _create_hint_dialog() -> void:
	_hint_dialog_flow.create_hint_dialog()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _create_cursor_tooltip() -> void:
	_cursor_tooltip_flow.create_cursor_tooltip()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ensure_tax_panel() -> void:
	_tax_panel_flow.ensure_tax_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _render_tax_report(report: Dictionary, warning: String) -> void:
	_tax_panel_flow.render_tax_report(report, warning)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_cursor_tooltip_position() -> void:
	_cursor_tooltip_flow.update_cursor_tooltip_position()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_hint_dialog_base_position() -> Vector2:
	return _hint_dialog_flow.get_hint_dialog_base_position()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_hint_dialog_timer(delta: float) -> void:
	_hint_dialog_flow.update_hint_dialog_timer(delta)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _hide_hint_dialog(animated: bool = true) -> void:
	_hint_dialog_flow.hide_hint_dialog(animated)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_all() -> void:
	_status_labels.update_all()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_gold_changed(amount: int) -> void:
	_status_labels.on_gold_changed(amount)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_target_reached() -> void:
	_status_labels.on_target_reached()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_time_updated(seconds: float) -> void:
	_status_labels.on_time_updated(seconds)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_phase_changed(phase) -> void:
	_status_labels.on_phase_changed(phase)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_day_started(day: int) -> void:
	_status_labels.on_day_started(day)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_target_label() -> void:
	_status_labels.update_target_label()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_settings_pressed() -> void:
	if _settings_menu != null and is_instance_valid(_settings_menu):
		_free_settings_layer()
		_resume_game()
		return

	_pause_game()
	_settings_layer = CanvasLayer.new()
	_settings_layer.name = "SettingsUILayer"
	_settings_layer.layer = SETTINGS_LAYER
	add_child(_settings_layer)
	_settings_menu = SettingsMenu.new()
	_settings_menu.closed.connect(_on_settings_menu_closed)
	_settings_layer.add_child(_settings_menu)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_settings_menu_closed() -> void:
	_free_settings_layer()
	_resume_game()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _free_settings_layer() -> void:
	if _settings_layer != null and is_instance_valid(_settings_layer):
		_settings_layer.queue_free()
	_settings_layer = null
	_settings_menu = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _pause_game() -> void:
	get_tree().paused = true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _resume_game() -> void:
	get_tree().paused = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _exit_tree() -> void:
	get_tree().paused = false
