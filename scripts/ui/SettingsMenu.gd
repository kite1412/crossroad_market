extends Control
class_name SettingsMenu

## A modal settings overlay. Built entirely in code so it can be instantiated
## from any scene that needs it (typically the HUD).

@warning_ignore("unused_signal")
signal closed()

const PANEL_WIDTH: float = 220.0
const PANEL_HEIGHT: float = 160.0
const BUTTON_HEIGHT: float = 22.0
const FONT_SIZE: int = 9
const TITLE_FONT_SIZE: int = 10

@warning_ignore("unused_private_class_variable")
var _overlay: ColorRect = null
@warning_ignore("unused_private_class_variable")
var _panel: ColorRect = null
@warning_ignore("unused_private_class_variable")
var _vbox: VBoxContainer = null
@warning_ignore("unused_private_class_variable")
var _difficulty_buttons: Array[Button] = []


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_highlight_current_difficulty()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _build_ui() -> void:
	# Dimmed background overlay
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color(0, 0, 0, 0.5)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(_on_overlay_input)
	add_child(_overlay)

	# Centered panel
	_panel = ColorRect.new()
	_panel.name = "SettingsPanel"
	_panel.color = Color(0.1, 0.08, 0.06, 0.96)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -PANEL_WIDTH * 0.5
	_panel.offset_top = -PANEL_HEIGHT * 0.5
	_panel.offset_right = PANEL_WIDTH * 0.5
	_panel.offset_bottom = PANEL_HEIGHT * 0.5
	_overlay.add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vbox.offset_left = 10.0
	_vbox.offset_top = 8.0
	_vbox.offset_right = -10.0
	_vbox.offset_bottom = -8.0
	_vbox.add_theme_constant_override("separation", 5)
	_panel.add_child(_vbox)

	# Title
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var title := _make_label("Settings", TITLE_FONT_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(title)

	# Difficulty section
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var diff_label := _make_label("Difficulty", FONT_SIZE)
	_vbox.add_child(diff_label)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 4)
	_vbox.add_child(diff_row)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var difficulty_names := ["Easy", "Medium", "Hard"]
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var difficulty_values := [
		SettingsManager.Difficulty.EASY,
		SettingsManager.Difficulty.MEDIUM,
		SettingsManager.Difficulty.HARD,
	]

	for i in difficulty_names.size():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var btn := Button.new()
		btn.text = difficulty_names[i]
		btn.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", FONT_SIZE)
		btn.pressed.connect(_on_difficulty_pressed.bind(difficulty_values[i]))
		diff_row.add_child(btn)
		_difficulty_buttons.append(btn)

	# Close button
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	close_btn.add_theme_font_size_override("font_size", FONT_SIZE)
	close_btn.pressed.connect(_close)
	_vbox.add_child(close_btn)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _highlight_current_difficulty() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var current: int = SettingsManager.get_difficulty()
	for btn in _difficulty_buttons:
		btn.modulate = Color.WHITE
	match current:
		SettingsManager.Difficulty.EASY:
			if _difficulty_buttons.size() > 0:
				_difficulty_buttons[0].modulate = Color(0.6, 1.0, 0.6)
		SettingsManager.Difficulty.MEDIUM:
			if _difficulty_buttons.size() > 1:
				_difficulty_buttons[1].modulate = Color(1.0, 1.0, 0.6)
		SettingsManager.Difficulty.HARD:
			if _difficulty_buttons.size() > 2:
				_difficulty_buttons[2].modulate = Color(1.0, 0.6, 0.6)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_difficulty_pressed(difficulty: int) -> void:
	SettingsManager.set_value("difficulty", difficulty)
	_highlight_current_difficulty()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Only close if clicking the overlay itself (not the panel)
			if event.position.x < _panel.offset_left + _panel.position.x or \
			   event.position.x > _panel.offset_right + _panel.position.x or \
			   event.position.y < _panel.offset_top + _panel.position.y or \
			   event.position.y > _panel.offset_bottom + _panel.position.y:
				_close()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _close() -> void:
	closed.emit()
	queue_free()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _make_label(text: String, size: int) -> Label:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label
