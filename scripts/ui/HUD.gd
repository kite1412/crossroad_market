extends CanvasLayer

signal notification_finished()

@onready var gold_label: Label = $TopLeftHUD/GoldLabel
@onready var target_label: Label = $TopLeftHUD/TargetLabel
@onready var day_label: Label = $TopCenterHUD/DayLabel
@onready var phase_label: Label = $TopCenterHUD/PhaseLabel
@onready var time_label: Label = $TopCenterHUD/TimeLabel
@onready var notification_label: Label = $NotificationLabel
@onready var objective_label: Label = $ObjectiveLabel

const NOTIFY_DURATION: float = 2.0
const MIN_NOTIFY_DURATION: float = 0.9
const NOTIFY_CHARS_PER_SECOND: float = 34.0
const HINT_DIALOG_WIDTH: float = 300.0
const HINT_DIALOG_HEIGHT: float = 54.0
const HINT_DIALOG_BOTTOM_MARGIN: float = 74.0
const CURSOR_TOOLTIP_OFFSET := Vector2(12, 14)
const CURSOR_TOOLTIP_PADDING := Vector2(12, 8)

var _notify_timer: float = 0.0
var _notify_duration: float = NOTIFY_DURATION
var _notify_full_chars: int = 0
var _action_lock_timer: float = 0.0
var _action_lock_sessions: int = 0
var _notification_finished_emitted: bool = true
var _hint_dialog: ColorRect = null
var _hint_label: Label = null
var _hint_tween: Tween = null
var _hint_dialog_visible: bool = false
var _cursor_tooltip: ColorRect = null
var _cursor_tooltip_label: Label = null
var _cursor_tooltip_tween: Tween = null
var _cursor_tooltip_visible: bool = false

func _ready() -> void:
	add_to_group("hud")
	notification_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _process(delta: float) -> void:
	if _action_lock_timer > 0.0:
		_action_lock_timer = max(0.0, _action_lock_timer - delta)

	if _cursor_tooltip_visible:
		if _has_interactive_overlay_open():
			hide_cursor_tooltip()
		else:
			_update_cursor_tooltip_position()

	if _notify_timer <= 0.0:
		return

	_notify_timer -= delta

	var elapsed: float = _notify_duration - _notify_timer
	var progress: float = clamp(elapsed / _notify_duration, 0.0, 1.0)

	var reveal_progress: float = clamp(progress / 0.35, 0.0, 1.0)
	notification_label.visible_characters = int(reveal_progress * _notify_full_chars)

	if progress < 0.75:
		notification_label.modulate.a = 1.0
	else:
		var fade_progress: float = clamp((progress - 0.75) / 0.25, 0.0, 1.0)
		notification_label.modulate.a = 1.0 - fade_progress

	if _notify_timer <= 0.0:
		_finish_notification()


func _input(event: InputEvent) -> void:
	_handle_dialog_skip_input(event)


func _unhandled_input(event: InputEvent) -> void:
	_handle_dialog_skip_input(event)


func _handle_dialog_skip_input(event: InputEvent) -> void:
	if not _is_dialog_skip_event(event):
		return

	var skipped := false

	if _hint_dialog_visible:
		_hide_hint_dialog(true)
		get_viewport().set_input_as_handled()
		return

	if notification_label.visible and not _has_interactive_overlay_open():
		_finish_notification()
		skipped = true

	if _skip_world_dialogs():
		skipped = true

	if skipped:
		get_viewport().set_input_as_handled()


func _is_dialog_skip_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index in [
			MOUSE_BUTTON_LEFT,
			MOUSE_BUTTON_RIGHT,
			MOUSE_BUTTON_MIDDLE
		]

	if event is InputEventScreenTouch:
		return event.pressed

	return false


func _skip_world_dialogs() -> bool:
	var skipped := false

	for node in get_tree().get_nodes_in_group("dialog_skip_target"):
		if node != null and node.has_method("skip_dialog"):
			skipped = bool(node.call("skip_dialog")) or skipped

	return skipped


func _has_interactive_overlay_open() -> bool:
	return _has_visible_overlay_named("CashierUILayer") or _has_visible_overlay_named("ActivityBoardLayer")


func _has_visible_overlay_named(node_name: String) -> bool:
	var root := get_tree().root

	if root == null:
		return false

	return _find_visible_overlay_named(root, node_name)


func _find_visible_overlay_named(node: Node, node_name: String) -> bool:
	if node.name == node_name and node is CanvasItem and (node as CanvasItem).visible:
		return true

	for child in node.get_children():
		if _find_visible_overlay_named(child, node_name):
			return true

	return false


func show_notification(text: String, duration: float = NOTIFY_DURATION, blocks_actions: bool = true) -> void:
	notification_label.visible = true
	notification_label.text = text
	_notify_full_chars = text.length()
	_notify_duration = _get_readable_notification_duration(text, duration)
	_notify_timer = _notify_duration
	notification_label.visible_characters = 0
	notification_label.modulate.a = 1.0
	_notification_finished_emitted = false

	if blocks_actions:
		_action_lock_timer = _notify_duration


func show_hint_dialog(_key: String, text: String) -> void:
	if text == "" or _has_interactive_overlay_open():
		return

	if _hint_dialog == null or _hint_label == null:
		_create_hint_dialog()

	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()

	_hint_label.text = text
	_hint_dialog.visible = true
	_hint_dialog_visible = true
	_hint_dialog.modulate.a = 0.0
	_hint_dialog.position.y = _get_hint_dialog_base_position().y + 8.0
	_hint_dialog.scale = Vector2(0.98, 0.98)

	_hint_tween = create_tween()
	_hint_tween.set_parallel(true)
	_hint_tween.tween_property(_hint_dialog, "modulate:a", 1.0, 0.18)
	_hint_tween.tween_property(_hint_dialog, "position:y", _get_hint_dialog_base_position().y, 0.18)
	_hint_tween.tween_property(_hint_dialog, "scale", Vector2.ONE, 0.18)


func show_cursor_tooltip(text: String) -> void:
	if text == "" or _has_interactive_overlay_open():
		return

	if _cursor_tooltip == null or _cursor_tooltip_label == null:
		_create_cursor_tooltip()

	if _cursor_tooltip_tween != null and _cursor_tooltip_tween.is_valid():
		_cursor_tooltip_tween.kill()

	_cursor_tooltip_label.text = text
	_cursor_tooltip_label.reset_size()
	_cursor_tooltip.size = _cursor_tooltip_label.get_minimum_size() + CURSOR_TOOLTIP_PADDING
	_cursor_tooltip_label.position = CURSOR_TOOLTIP_PADDING * 0.5
	_update_cursor_tooltip_position()

	_cursor_tooltip.visible = true
	_cursor_tooltip_visible = true
	_cursor_tooltip.modulate.a = 0.0
	_cursor_tooltip.scale = Vector2(0.96, 0.96)

	_cursor_tooltip_tween = create_tween()
	_cursor_tooltip_tween.set_parallel(true)
	_cursor_tooltip_tween.tween_property(_cursor_tooltip, "modulate:a", 1.0, 0.12)
	_cursor_tooltip_tween.tween_property(_cursor_tooltip, "scale", Vector2.ONE, 0.12)


func hide_cursor_tooltip() -> void:
	if _cursor_tooltip == null:
		return

	if _cursor_tooltip_tween != null and _cursor_tooltip_tween.is_valid():
		_cursor_tooltip_tween.kill()

	_cursor_tooltip_visible = false
	_cursor_tooltip_tween = create_tween()
	_cursor_tooltip_tween.tween_property(_cursor_tooltip, "modulate:a", 0.0, 0.08)
	_cursor_tooltip_tween.tween_callback(func() -> void:
		if _cursor_tooltip != null:
			_cursor_tooltip.visible = false
	)


func set_objective(text: String) -> void:
	if objective_label == null:
		return

	if text == "":
		objective_label.visible = false
		return

	objective_label.visible = true
	objective_label.text = "Objective: %s" % text


func _get_readable_notification_duration(text: String, requested_duration: float) -> float:
	var readable_duration := float(text.length()) / NOTIFY_CHARS_PER_SECOND
	return max(requested_duration, MIN_NOTIFY_DURATION, readable_duration)


func wait_for_notification_finished() -> void:
	if _notify_timer <= 0.0:
		return

	await notification_finished


func begin_action_lock() -> void:
	_action_lock_sessions += 1


func end_action_lock() -> void:
	_action_lock_sessions = max(0, _action_lock_sessions - 1)


func is_action_locked() -> bool:
	return _action_lock_sessions > 0 or _action_lock_timer > 0.0


func _finish_notification() -> void:
	_notify_timer = 0.0
	_action_lock_timer = 0.0
	notification_label.modulate.a = 0.0
	notification_label.visible_characters = 0
	notification_label.visible = false

	if not _notification_finished_emitted:
		_notification_finished_emitted = true
		notification_finished.emit()


func _create_hint_dialog() -> void:
	if _hint_dialog != null:
		return

	_hint_dialog = ColorRect.new()
	_hint_dialog.name = "OneTimeHintDialog"
	_hint_dialog.color = Color(0.08, 0.07, 0.05, 0.94)
	_hint_dialog.size = Vector2(HINT_DIALOG_WIDTH, HINT_DIALOG_HEIGHT)
	_hint_dialog.position = _get_hint_dialog_base_position()
	_hint_dialog.pivot_offset = _hint_dialog.size * 0.5
	_hint_dialog.visible = false
	_hint_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_dialog)

	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint_label.offset_left = 8.0
	_hint_label.offset_top = 6.0
	_hint_label.offset_right = -8.0
	_hint_label.offset_bottom = -6.0
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.theme_type_variation = "SmallLabel"
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.76, 1.0))
	_hint_label.add_theme_font_size_override("font_size", 9)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_dialog.add_child(_hint_label)


func _create_cursor_tooltip() -> void:
	if _cursor_tooltip != null:
		return

	_cursor_tooltip = ColorRect.new()
	_cursor_tooltip.name = "CursorNameTooltip"
	_cursor_tooltip.color = Color(0.05, 0.045, 0.035, 0.94)
	_cursor_tooltip.visible = false
	_cursor_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cursor_tooltip)

	_cursor_tooltip_label = Label.new()
	_cursor_tooltip_label.name = "TooltipLabel"
	_cursor_tooltip_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.82, 1.0))
	_cursor_tooltip_label.add_theme_font_size_override("font_size", 9)
	_cursor_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_tooltip.add_child(_cursor_tooltip_label)


func _update_cursor_tooltip_position() -> void:
	if _cursor_tooltip == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var tooltip_position := get_viewport().get_mouse_position() + CURSOR_TOOLTIP_OFFSET
	tooltip_position.x = min(tooltip_position.x, viewport_size.x - _cursor_tooltip.size.x - 4.0)
	tooltip_position.y = min(tooltip_position.y, viewport_size.y - _cursor_tooltip.size.y - 4.0)
	tooltip_position.x = max(4.0, tooltip_position.x)
	tooltip_position.y = max(4.0, tooltip_position.y)
	_cursor_tooltip.position = tooltip_position


func _get_hint_dialog_base_position() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	return Vector2(
		(viewport_size.x - HINT_DIALOG_WIDTH) * 0.5,
		viewport_size.y - HINT_DIALOG_BOTTOM_MARGIN - HINT_DIALOG_HEIGHT
	)


func _hide_hint_dialog(animated: bool = true) -> void:
	if _hint_dialog == null:
		return

	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()

	_hint_dialog_visible = false

	if not animated:
		_hint_dialog.visible = false
		_hint_dialog.modulate.a = 0.0
		return

	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint_dialog, "modulate:a", 0.0, 0.12)
	_hint_tween.tween_callback(func() -> void:
		if _hint_dialog != null:
			_hint_dialog.visible = false
	)


func _update_all() -> void:
	_on_gold_changed(EconomyManager.gold)
	_on_day_started(TimeManager.current_day)
	_on_phase_changed(TimeManager.current_phase)
	_on_time_updated(TimeManager.time_remaining)


func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Wallet: %dG" % amount
	_update_target_label()


func _on_target_reached() -> void:
	_update_target_label()


func _on_time_updated(_seconds: float) -> void:
	time_label.text = TimeManager.get_time_display()


func _on_phase_changed(_phase) -> void:
	phase_label.text = TimeManager.get_phase_name()


func _on_day_started(day: int) -> void:
	day_label.text = "Day %d" % day
	_update_target_label()


func _update_target_label() -> void:
	var target_text := "%dG / %dG" % [
		EconomyManager.daily_revenue,
		EconomyManager.daily_target
	]

	if EconomyManager.daily_revenue >= EconomyManager.daily_target:
		target_text += " TARGET"

	target_label.text = target_text
