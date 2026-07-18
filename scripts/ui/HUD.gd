extends CanvasLayer

const HUDStatusLabels = preload("res://scripts/ui/hud/HUDStatusLabels.gd")
const HUDNotificationFlow = preload("res://scripts/ui/hud/HUDNotificationFlow.gd")
const HUDDialogController = preload("res://scripts/ui/hud/HUDDialogController.gd")
const HUDDialogSkipFlow = preload("res://scripts/ui/hud/HUDDialogSkipFlow.gd")
const HUDTaxPanel = preload("res://scripts/ui/hud/HUDTaxPanel.gd")
const HUDHintDialog = preload("res://scripts/ui/hud/HUDHintDialog.gd")
const HUDCursorTooltip = preload("res://scripts/ui/hud/HUDCursorTooltip.gd")
const HUDObjectiveToast = preload("res://scripts/ui/hud/HUDObjectiveToast.gd")

signal notification_finished()
signal tax_payment_requested()

@onready var gold_label: Label = $TopLeftHUD/GoldLabel
@onready var target_label: Label = $TopLeftHUD/TargetLabel
@onready var day_label: Label = $TopCenterHUD/DayLabel
@onready var phase_label: Label = $TopCenterHUD/PhaseLabel
@onready var time_label: Label = $TopCenterHUD/TimeLabel
@onready var notification_label: Label = $NotificationLabel
@onready var objective_label: Label = $ObjectiveLabel
@onready var dialog: Dialog = $Dialog

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

var _notify_timer: float = 0.0
var _notify_duration: float = NOTIFY_DURATION
var _notify_full_chars: int = 0
var _notify_instant_text: bool = false
var _action_lock_timer: float = 0.0
var _action_lock_sessions: int = 0
var _notification_finished_emitted: bool = true
var _hint_dialog: ColorRect = null
var _hint_label: Label = null
var _hint_tween: Tween = null
var _hint_dialog_visible: bool = false
var _hint_dialog_timer: float = 0.0
var _cursor_tooltip: ColorRect = null
var _cursor_tooltip_label: Label = null
var _cursor_tooltip_tween: Tween = null
var _cursor_tooltip_visible: bool = false
var _cursor_tooltip_text: String = ""
var _objective_tween: Tween = null
var _objective_timer: float = 0.0
var _objective_base_position: Vector2 = Vector2.ZERO
var _tax_layer: CanvasLayer = null
var _tax_panel: ColorRect = null
var _tax_title_label: Label = null
var _tax_report_label: Label = null
var _tax_warning_label: Label = null

var _status_labels: HUDStatusLabels = HUDStatusLabels.new()
var _notification_flow: HUDNotificationFlow = HUDNotificationFlow.new()
var _dialog_controller: HUDDialogController = HUDDialogController.new()
var _dialog_skip_flow: HUDDialogSkipFlow = HUDDialogSkipFlow.new()
var _tax_panel_flow: HUDTaxPanel = HUDTaxPanel.new()
var _hint_dialog_flow: HUDHintDialog = HUDHintDialog.new()
var _cursor_tooltip_flow: HUDCursorTooltip = HUDCursorTooltip.new()
var _objective_toast_flow: HUDObjectiveToast = HUDObjectiveToast.new()


func _ready() -> void:
	add_to_group("hud")
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

	_update_all()

	notification_label.visible = false
	notification_label.modulate.a = 0.0
	notification_label.visible_characters = 0


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


func _process(delta: float) -> void:
	_objective_toast_flow.update_objective_toast(delta)
	_cursor_tooltip_flow.update_cursor_hover_tooltip()
	_hint_dialog_flow.update_hint_dialog_timer(delta)
	_notification_flow.process(delta)


func _input(event: InputEvent) -> void:
	_handle_dialog_skip_input(event)


func _unhandled_input(event: InputEvent) -> void:
	_handle_dialog_skip_input(event)


func _handle_dialog_skip_input(event: InputEvent) -> void:
	_dialog_skip_flow.handle_dialog_skip_input(event)


func _is_dialog_skip_event(event: InputEvent) -> bool:
	return _dialog_skip_flow.is_dialog_skip_event(event)


func _skip_world_dialogs() -> bool:
	return _dialog_skip_flow.skip_world_dialogs()


func _has_interactive_overlay_open() -> bool:
	return _dialog_skip_flow.has_interactive_overlay_open()


func _has_visible_overlay_named(node_name: String) -> bool:
	return _dialog_skip_flow.has_visible_overlay_named(node_name)


func _find_visible_overlay_named(node: Node, node_name: String) -> bool:
	return _dialog_skip_flow.find_visible_overlay_named(node, node_name)


func _has_visible_overlay_content(node: Node) -> bool:
	return _dialog_skip_flow.has_visible_overlay_content(node)


func show_notification(
	text: String,
	duration: float = NOTIFY_DURATION,
	blocks_actions: bool = true,
	instant_text: bool = false
) -> void:
	_notification_flow.show_notification(text, duration, blocks_actions, instant_text)


func show_dialog_sequence(dialogues: Array[Dictionary]) -> void:
	await _dialog_controller.show_dialog_sequence(dialogues)


func is_dialog_visible() -> bool:
	return _dialog_controller.is_visible()


func show_tax_report(report: Dictionary) -> void:
	_tax_panel_flow.show_tax_report(report)


func show_tax_warning(message: String, report: Dictionary = {}) -> void:
	_tax_panel_flow.show_tax_warning(message, report)


func hide_tax_report() -> void:
	_tax_panel_flow.hide_tax_report()


func show_hint_dialog(key: String, text: String) -> void:
	_hint_dialog_flow.show_hint_dialog(key, text)


func show_cursor_tooltip(text: String) -> void:
	_cursor_tooltip_flow.show_cursor_tooltip(text)


func hide_cursor_tooltip() -> void:
	_cursor_tooltip_flow.hide_cursor_tooltip()


func _update_cursor_hover_tooltip() -> void:
	_cursor_tooltip_flow.update_cursor_hover_tooltip()


func _get_cursor_world_hover_text() -> String:
	return _cursor_tooltip_flow.get_cursor_world_hover_text()


func _get_hover_candidate_from_area(area: Area2D) -> Dictionary:
	return _cursor_tooltip_flow.get_hover_candidate_from_area(area)


func _get_shelf_slot_hover_candidate(area: Area2D) -> Dictionary:
	return _cursor_tooltip_flow.get_shelf_slot_hover_candidate(area)


func _get_door_hover_text(area: Area2D) -> String:
	return _cursor_tooltip_flow.get_door_hover_text(area)


func _get_hover_target_priority(target: Node) -> int:
	return _cursor_tooltip_flow.get_hover_target_priority(target)


func set_objective(text: String) -> void:
	_objective_toast_flow.set_objective(text)


func _update_objective_toast(delta: float) -> void:
	_objective_toast_flow.update_objective_toast(delta)


func _hide_objective_toast(animated: bool) -> void:
	_objective_toast_flow.hide_objective_toast(animated)


func _get_readable_notification_duration(text: String, requested_duration: float) -> float:
	return _notification_flow.get_readable_notification_duration(text, requested_duration)


func wait_for_notification_finished() -> void:
	await _notification_flow.wait_for_notification_finished()


func begin_action_lock() -> void:
	_notification_flow.begin_action_lock()


func end_action_lock() -> void:
	_notification_flow.end_action_lock()


func is_action_locked() -> bool:
	return _notification_flow.is_action_locked()


func has_interactive_overlay_open() -> bool:
	return _has_interactive_overlay_open()


func _finish_notification() -> void:
	_notification_flow.finish_notification()


func _create_hint_dialog() -> void:
	_hint_dialog_flow.create_hint_dialog()


func _create_cursor_tooltip() -> void:
	_cursor_tooltip_flow.create_cursor_tooltip()


func _ensure_tax_panel() -> void:
	_tax_panel_flow.ensure_tax_panel()


func _render_tax_report(report: Dictionary, warning: String) -> void:
	_tax_panel_flow.render_tax_report(report, warning)


func _update_cursor_tooltip_position() -> void:
	_cursor_tooltip_flow.update_cursor_tooltip_position()


func _get_hint_dialog_base_position() -> Vector2:
	return _hint_dialog_flow.get_hint_dialog_base_position()


func _update_hint_dialog_timer(delta: float) -> void:
	_hint_dialog_flow.update_hint_dialog_timer(delta)


func _hide_hint_dialog(animated: bool = true) -> void:
	_hint_dialog_flow.hide_hint_dialog(animated)


func _update_all() -> void:
	_status_labels.update_all()


func _on_gold_changed(amount: int) -> void:
	_status_labels.on_gold_changed(amount)


func _on_target_reached() -> void:
	_status_labels.on_target_reached()


func _on_time_updated(seconds: float) -> void:
	_status_labels.on_time_updated(seconds)


func _on_phase_changed(phase) -> void:
	_status_labels.on_phase_changed(phase)


func _on_day_started(day: int) -> void:
	_status_labels.on_day_started(day)


func _update_target_label() -> void:
	_status_labels.update_target_label()
