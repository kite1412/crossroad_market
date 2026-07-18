extends CanvasLayer

signal notification_finished()
signal tax_payment_requested()

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

func _ready() -> void:
	add_to_group("hud")
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


func _process(delta: float) -> void:
	if _action_lock_timer > 0.0:
		_action_lock_timer = max(0.0, _action_lock_timer - delta)

	_update_objective_toast(delta)
	_update_cursor_hover_tooltip()
	_update_hint_dialog_timer(delta)

	if _notify_timer <= 0.0:
		return

	_notify_timer -= delta

	var elapsed: float = _notify_duration - _notify_timer
	var progress: float = clamp(elapsed / _notify_duration, 0.0, 1.0)

	if _notify_instant_text:
		notification_label.visible_characters = _notify_full_chars
	else:
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
	return (
		_has_visible_overlay_named("CashierUILayer")
		or _has_visible_overlay_named("ActivityBoardLayer")
		or _has_visible_overlay_named("StorageRestockLayer")
		or _has_visible_overlay_named("TaxReportLayer")
	)


func _has_visible_overlay_named(node_name: String) -> bool:
	var root := get_tree().root

	if root == null:
		return false

	return _find_visible_overlay_named(root, node_name)


func _find_visible_overlay_named(node: Node, node_name: String) -> bool:
	if node.name == node_name:
		if node is CanvasLayer:
			return (node as CanvasLayer).visible and _has_visible_overlay_content(node)

		if node is CanvasItem and (node as CanvasItem).visible:
			return true

	for child in node.get_children():
		if _find_visible_overlay_named(child, node_name):
			return true

	return false


func _has_visible_overlay_content(node: Node) -> bool:
	for child in node.get_children():
		if child is CanvasItem and (child as CanvasItem).is_visible_in_tree():
			return true

		if _has_visible_overlay_content(child):
			return true

	return false


func show_notification(
	text: String,
	duration: float = NOTIFY_DURATION,
	blocks_actions: bool = true,
	instant_text: bool = false
) -> void:
	notification_label.visible = true
	notification_label.text = text
	_notify_full_chars = text.length()
	_notify_duration = _get_readable_notification_duration(text, duration)
	_notify_timer = _notify_duration
	_notify_instant_text = instant_text
	notification_label.visible_characters = _notify_full_chars if instant_text else 0
	notification_label.modulate.a = 1.0
	_notification_finished_emitted = false

	if blocks_actions:
		_action_lock_timer = _notify_duration


func show_tax_report(report: Dictionary) -> void:
	_ensure_tax_panel()
	_render_tax_report(report, "")
	_tax_layer.visible = true
	_tax_panel.visible = true
	begin_action_lock()


func show_tax_warning(message: String, report: Dictionary = {}) -> void:
	_ensure_tax_panel()

	if not report.is_empty():
		_render_tax_report(report, message)
	elif _tax_warning_label != null:
		_tax_warning_label.text = message

	_tax_layer.visible = true
	_tax_panel.visible = true


func hide_tax_report() -> void:
	if _tax_panel != null:
		_tax_panel.visible = false

	if _tax_layer != null:
		_tax_layer.visible = false

	end_action_lock()


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
	_hint_dialog_timer = HINT_DIALOG_DURATION
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
	_cursor_tooltip_tween = null

	if _cursor_tooltip_text != text:
		_cursor_tooltip_text = text
		_cursor_tooltip_label.text = text
		_cursor_tooltip_label.reset_size()
		_cursor_tooltip.size = _cursor_tooltip_label.get_minimum_size() + CURSOR_TOOLTIP_PADDING
		_cursor_tooltip_label.position = CURSOR_TOOLTIP_PADDING * 0.5

	_update_cursor_tooltip_position()

	_cursor_tooltip.visible = true
	_cursor_tooltip_visible = true
	_cursor_tooltip.modulate.a = 1.0
	_cursor_tooltip.scale = Vector2.ONE


func hide_cursor_tooltip() -> void:
	if _cursor_tooltip == null:
		return

	if _cursor_tooltip_tween != null and _cursor_tooltip_tween.is_valid():
		_cursor_tooltip_tween.kill()
	_cursor_tooltip_tween = null

	_cursor_tooltip_visible = false
	_cursor_tooltip_text = ""
	_cursor_tooltip.visible = false
	_cursor_tooltip.modulate.a = 0.0


func _update_cursor_hover_tooltip() -> void:
	if _has_interactive_overlay_open():
		hide_cursor_tooltip()
		return

	var hover_text := _get_cursor_world_hover_text()

	if hover_text != "":
		show_cursor_tooltip(hover_text)
	elif _cursor_tooltip_visible:
		hide_cursor_tooltip()


func _get_cursor_world_hover_text() -> String:
	var viewport := get_viewport()

	if viewport == null:
		return ""

	var world_2d := viewport.world_2d

	if world_2d == null:
		return ""

	var query := PhysicsPointQueryParameters2D.new()
	query.position = viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var hits := world_2d.direct_space_state.intersect_point(query, CURSOR_HOVER_QUERY_LIMIT)
	var best_text := ""
	var best_priority := 999

	for hit in hits:
		var collider: Variant = hit.get("collider", null)

		if not (collider is Area2D):
			continue

		var area := collider as Area2D
		var candidate := _get_hover_candidate_from_area(area)

		if candidate.is_empty():
			continue

		var priority := int(candidate.get("priority", 999))

		if priority < best_priority:
			best_priority = priority
			best_text = str(candidate.get("text", ""))

	return best_text


func _get_hover_candidate_from_area(area: Area2D) -> Dictionary:
	if area == null:
		return {}

	var shelf_slot_candidate := _get_shelf_slot_hover_candidate(area)

	if not shelf_slot_candidate.is_empty():
		return shelf_slot_candidate

	var door_text := _get_door_hover_text(area)

	if door_text != "":
		return {
			"text": door_text,
			"priority": 10
		}

	var current: Node = area

	while current != null and current != self and current != get_tree().root:
		if current.has_method("get_hover_display_name"):
			return {
				"text": str(current.call("get_hover_display_name")),
				"priority": _get_hover_target_priority(current)
			}

		if current is Cashier:
			return {
				"text": "Cashier",
				"priority": 20
			}

		if current is ActivityBoard:
			return {
				"text": "Activity Board",
				"priority": 30
			}

		current = current.get_parent()

	return {}


func _get_shelf_slot_hover_candidate(area: Area2D) -> Dictionary:
	var slot_node := area.get_parent()

	if slot_node == null:
		return {}

	var slot_name := String(slot_node.name)

	if not slot_name.begins_with("Slot"):
		return {}

	var slot_index := int(slot_name.trim_prefix("Slot"))
	var current := slot_node.get_parent()

	while current != null and current != get_tree().root:
		if current is Shelf:
			var shelf := current as Shelf
			var text := ""

			if shelf.has_method("_get_slot_hover_name"):
				text = str(shelf.call("_get_slot_hover_name", slot_index))
			elif shelf.has_method("get_hover_display_name"):
				text = str(shelf.call("get_hover_display_name"))

			if text == "":
				return {}

			return {
				"text": text,
				"priority": 4
			}

		current = current.get_parent()

	return {}


func _get_door_hover_text(area: Area2D) -> String:
	if not area.has_meta("door_type"):
		return ""

	var door_type := str(area.get_meta("door_type"))

	if door_type == "storage":
		return "Storage Door"

	if door_type == "yard":
		return "Yard Door"

	if door_type.ends_with("_return") or door_type == "return":
		return "Store Door"

	return ""


func _get_hover_target_priority(target: Node) -> int:
	if target is Shelf:
		return 5

	if target is SupplyBox:
		return 15

	return 50


func set_objective(text: String) -> void:
	if objective_label == null:
		return

	if text == "":
		_hide_objective_toast(false)
		return

	objective_label.visible = true
	objective_label.text = "Objective: %s" % text
	objective_label.position = _objective_base_position + Vector2(0, 8)
	objective_label.modulate.a = 0.0
	_objective_timer = OBJECTIVE_TOAST_DURATION

	if _objective_tween != null and _objective_tween.is_valid():
		_objective_tween.kill()

	_objective_tween = create_tween()
	_objective_tween.set_parallel(true)
	_objective_tween.tween_property(objective_label, "modulate:a", 1.0, OBJECTIVE_ANIM_DURATION)
	_objective_tween.tween_property(objective_label, "position", _objective_base_position, OBJECTIVE_ANIM_DURATION)


func _update_objective_toast(delta: float) -> void:
	if objective_label == null or not objective_label.visible:
		return

	if _objective_timer <= 0.0:
		return

	_objective_timer = max(0.0, _objective_timer - delta)

	if _objective_timer <= 0.0:
		_hide_objective_toast(true)


func _hide_objective_toast(animated: bool) -> void:
	_objective_timer = 0.0

	if objective_label == null:
		return

	if _objective_tween != null and _objective_tween.is_valid():
		_objective_tween.kill()
	_objective_tween = null

	if not animated:
		objective_label.visible = false
		objective_label.modulate.a = 0.0
		objective_label.position = _objective_base_position
		return

	_objective_tween = create_tween()
	_objective_tween.set_parallel(true)
	_objective_tween.tween_property(objective_label, "modulate:a", 0.0, OBJECTIVE_ANIM_DURATION)
	_objective_tween.tween_property(
		objective_label,
		"position",
		_objective_base_position + Vector2(0, 8),
		OBJECTIVE_ANIM_DURATION
	)
	_objective_tween.set_parallel(false)
	_objective_tween.tween_callback(func() -> void:
		if objective_label != null:
			objective_label.visible = false
			objective_label.position = _objective_base_position
	)


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


func has_interactive_overlay_open() -> bool:
	return _has_interactive_overlay_open()


func _finish_notification() -> void:
	_notify_timer = 0.0
	_notify_instant_text = false
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


func _ensure_tax_panel() -> void:
	if _tax_layer != null and is_instance_valid(_tax_layer):
		return

	_tax_layer = CanvasLayer.new()
	_tax_layer.name = "TaxReportLayer"
	_tax_layer.layer = 30
	_tax_layer.visible = false
	add_child(_tax_layer)

	_tax_panel = ColorRect.new()
	_tax_panel.name = "TaxReportPanel"
	_tax_panel.color = Color(0.08, 0.065, 0.045, 0.96)
	_tax_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tax_panel.offset_left = 84.0
	_tax_panel.offset_top = 54.0
	_tax_panel.offset_right = -84.0
	_tax_panel.offset_bottom = -42.0
	_tax_panel.clip_contents = true
	_tax_layer.add_child(_tax_panel)

	var root := VBoxContainer.new()
	root.name = "Content"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12.0
	root.offset_top = 10.0
	root.offset_right = -12.0
	root.offset_bottom = -10.0
	root.add_theme_constant_override("separation", 5)
	_tax_panel.add_child(root)

	_tax_title_label = Label.new()
	_tax_title_label.text = "DAY REPORT"
	_tax_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tax_title_label.add_theme_font_size_override("font_size", 11)
	root.add_child(_tax_title_label)

	_tax_report_label = Label.new()
	_tax_report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tax_report_label.add_theme_font_size_override("font_size", 9)
	root.add_child(_tax_report_label)

	_tax_warning_label = Label.new()
	_tax_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tax_warning_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.45, 1.0))
	_tax_warning_label.add_theme_font_size_override("font_size", 8)
	root.add_child(_tax_warning_label)

	var pay_button := Button.new()
	pay_button.text = "Pay Tax"
	pay_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pay_button.pressed.connect(func() -> void:
		tax_payment_requested.emit()
	)
	root.add_child(pay_button)


func _render_tax_report(report: Dictionary, warning: String) -> void:
	_ensure_tax_panel()

	var day := int(report.get("day", TimeManager.current_day))
	var revenue := int(report.get("revenue", EconomyManager.daily_revenue))
	var expenses := int(report.get("expenses", EconomyManager.daily_expenses))
	var tax := int(report.get("tax", EconomyManager.get_daily_tax()))
	var net_profit := int(report.get("net_profit", revenue - expenses - tax))
	var total_gold := int(report.get("total_gold", EconomyManager.gold))
	var target_reached := bool(report.get("target_reached", revenue >= EconomyManager.daily_target))

	_tax_title_label.text = "DAY %d REPORT" % day
	_tax_report_label.text = "Revenue: %dG\nExpenses: %dG\nTax: %dG\nNet Profit: %dG\nWallet: %dG\nTarget: %s" % [
		revenue,
		expenses,
		tax,
		net_profit,
		total_gold,
		"REACHED" if target_reached else "MISSED"
	]
	_tax_warning_label.text = warning


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


func _update_hint_dialog_timer(delta: float) -> void:
	if not _hint_dialog_visible:
		return

	_hint_dialog_timer = max(0.0, _hint_dialog_timer - delta)

	if _hint_dialog_timer <= 0.0:
		_hide_hint_dialog(true)


func _hide_hint_dialog(animated: bool = true) -> void:
	if _hint_dialog == null:
		return

	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()

	_hint_dialog_visible = false
	_hint_dialog_timer = 0.0

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
