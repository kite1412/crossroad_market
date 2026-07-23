class_name HUDStoryModeController
extends RefCounted

signal choice_selected(index: int)

const NORMAL_HUD_PATHS: Array[NodePath] = [
	NodePath("TopLeftHUD"),
	NodePath("TopCenterHUD"),
	NodePath("TopRightHUD"),
	NodePath("InventoryUI"),
	NodePath("NotificationLabel"),
	NodePath("ObjectiveLabel"),
]

var hud: CanvasLayer = null
var _active: bool = false
var _choice_pending: bool = false
var _choice_overlay: Control = null


func setup(hud_node: CanvasLayer) -> void:
	hud = hud_node


func begin_story_mode() -> void:
	if hud == null or _active:
		return

	_active = true
	hud._notification_flow.finish_notification()
	hud._objective_toast_flow.hide_objective_toast(false)
	hud._hint_dialog_flow.hide_hint_dialog(false)
	hud._cursor_tooltip_flow.hide_cursor_tooltip()

	for path in NORMAL_HUD_PATHS:
		var item := hud.get_node_or_null(path) as CanvasItem
		if item != null:
			item.visible = false

	hud._notification_flow.begin_action_lock()


func end_story_mode() -> void:
	if hud == null or not _active:
		return

	_destroy_choice_overlay()
	for path in NORMAL_HUD_PATHS:
		var item := hud.get_node_or_null(path) as CanvasItem
		if item == null:
			continue
		item.visible = path in [
			NodePath("TopLeftHUD"),
			NodePath("TopCenterHUD"),
			NodePath("TopRightHUD"),
			NodePath("InventoryUI"),
		]

	_active = false
	hud._notification_flow.end_action_lock()
	hud._status_labels.update_all()


func is_active() -> bool:
	return _active


func has_pending_choice() -> bool:
	return _choice_pending


func show_choice(prompt: String, options: Array[String]) -> int:
	if hud == null or not _active or options.is_empty():
		return -1

	_destroy_choice_overlay()
	_build_choice_overlay(prompt, options)
	_choice_pending = true
	var selected_index: int = await choice_selected
	_choice_pending = false
	_destroy_choice_overlay()
	return selected_index


func select_choice(index: int) -> void:
	if not _choice_pending or _choice_overlay == null:
		return
	_choice_pending = false
	choice_selected.emit(index)


func _build_choice_overlay(prompt: String, options: Array[String]) -> void:
	_choice_overlay = Control.new()
	_choice_overlay.name = "StoryChoiceOverlay"
	_choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_choice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(_choice_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.015, 0.06, 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "ChoicePanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -132.0
	panel.offset_top = -62.0
	panel.offset_right = 132.0
	panel.offset_bottom = 62.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.98, 0.86, 0.78, 1.0)
	panel_style.border_color = Color(0.29, 0.16, 0.1, 1.0)
	panel_style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", panel_style)
	_choice_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 6)
	margin.add_child(choices)

	var prompt_label := Label.new()
	prompt_label.text = prompt
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_color_override("font_color", Color(0.29, 0.16, 0.1, 1.0))
	prompt_label.add_theme_font_size_override("font_size", 10)
	choices.add_child(prompt_label)

	var first_button: Button = null
	for index in options.size():
		var button := Button.new()
		button.text = options[index]
		button.custom_minimum_size = Vector2(0, 25)
		button.add_theme_font_size_override("font_size", 9)
		button.pressed.connect(Callable(self, "_on_choice_pressed").bind(index))
		choices.add_child(button)
		if first_button == null:
			first_button = button

	if first_button != null:
		first_button.call_deferred("grab_focus")


func _on_choice_pressed(index: int) -> void:
	select_choice(index)


func _destroy_choice_overlay() -> void:
	_choice_pending = false
	if _choice_overlay != null and is_instance_valid(_choice_overlay):
		_choice_overlay.queue_free()
	_choice_overlay = null
