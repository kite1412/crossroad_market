class_name HUDHintDialog
extends RefCounted

var hud: CanvasLayer = null


func setup(hud_node: CanvasLayer) -> void:
	hud = hud_node


func show_hint_dialog(_key: String, text: String) -> void:
	if text == "" or hud._has_interactive_overlay_open():
		return

	if hud._hint_dialog == null or hud._hint_label == null:
		create_hint_dialog()

	if hud._hint_tween != null and hud._hint_tween.is_valid():
		hud._hint_tween.kill()

	hud._hint_label.text = text
	hud._hint_dialog.visible = true
	hud._hint_dialog_visible = true
	hud._hint_dialog_timer = hud.HINT_DIALOG_DURATION
	hud._hint_dialog.modulate.a = 0.0
	hud._hint_dialog.position.y = get_hint_dialog_base_position().y + 8.0
	hud._hint_dialog.scale = Vector2(0.98, 0.98)

	hud._hint_tween = hud.create_tween()
	hud._hint_tween.set_parallel(true)
	hud._hint_tween.tween_property(hud._hint_dialog, "modulate:a", 1.0, 0.18)
	hud._hint_tween.tween_property(hud._hint_dialog, "position:y", get_hint_dialog_base_position().y, 0.18)
	hud._hint_tween.tween_property(hud._hint_dialog, "scale", Vector2.ONE, 0.18)


func create_hint_dialog() -> void:
	if hud._hint_dialog != null:
		return

	hud._hint_dialog = ColorRect.new()
	hud._hint_dialog.name = "OneTimeHintDialog"
	hud._hint_dialog.color = Color(0.08, 0.07, 0.05, 0.94)
	hud._hint_dialog.size = Vector2(hud.HINT_DIALOG_WIDTH, hud.HINT_DIALOG_HEIGHT)
	hud._hint_dialog.position = get_hint_dialog_base_position()
	hud._hint_dialog.pivot_offset = hud._hint_dialog.size * 0.5
	hud._hint_dialog.visible = false
	hud._hint_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud._hint_dialog)

	hud._hint_label = Label.new()
	hud._hint_label.name = "HintLabel"
	hud._hint_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud._hint_label.offset_left = 8.0
	hud._hint_label.offset_top = 6.0
	hud._hint_label.offset_right = -8.0
	hud._hint_label.offset_bottom = -6.0
	hud._hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud._hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud._hint_label.theme_type_variation = "SmallLabel"
	hud._hint_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.76, 1.0))
	hud._hint_label.add_theme_font_size_override("font_size", 9)
	hud._hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._hint_dialog.add_child(hud._hint_label)


func get_hint_dialog_base_position() -> Vector2:
	var viewport_size := hud.get_viewport().get_visible_rect().size
	return Vector2(
		(viewport_size.x - hud.HINT_DIALOG_WIDTH) * 0.5,
		viewport_size.y - hud.HINT_DIALOG_BOTTOM_MARGIN - hud.HINT_DIALOG_HEIGHT
	)


func update_hint_dialog_timer(delta: float) -> void:
	if not hud._hint_dialog_visible:
		return

	hud._hint_dialog_timer = max(0.0, hud._hint_dialog_timer - delta)

	if hud._hint_dialog_timer <= 0.0:
		hide_hint_dialog(true)


func hide_hint_dialog(animated: bool = true) -> void:
	if hud._hint_dialog == null:
		return

	if hud._hint_tween != null and hud._hint_tween.is_valid():
		hud._hint_tween.kill()

	hud._hint_dialog_visible = false
	hud._hint_dialog_timer = 0.0

	if not animated:
		hud._hint_dialog.visible = false
		hud._hint_dialog.modulate.a = 0.0
		return

	hud._hint_tween = hud.create_tween()
	hud._hint_tween.tween_property(hud._hint_dialog, "modulate:a", 0.0, 0.12)
	hud._hint_tween.tween_callback(func() -> void:
		if hud._hint_dialog != null:
			hud._hint_dialog.visible = false
	)


func is_visible() -> bool:
	return hud._hint_dialog_visible
