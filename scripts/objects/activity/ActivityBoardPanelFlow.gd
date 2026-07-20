class_name ActivityBoardPanelFlow
extends RefCounted

var board: ActivityBoard = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(board_node: ActivityBoard) -> void:
	board = board_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func open_board() -> void:
	if board._board_panel != null and board._board_panel.visible:
		return

	if board._has_visible_overlay_named("CashierUILayer"):
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var guidance := get_guidance()
	show_board_panel(
		str(guidance.get("title", board.DEFAULT_TITLE)),
		guidance.get("lines", board.DEFAULT_LINES)
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_interaction() -> void:
	if TimeManager.has_method("start_clock"):
		TimeManager.start_clock()

	open_board()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func handle_unhandled_input(event: InputEvent) -> void:
	if board._board_panel == null or not board._board_panel.visible:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			hide_board_panel()
			board.get_viewport().set_input_as_handled()
		return

	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_ESCAPE or event.is_action_pressed("ui_cancel"):
		hide_board_panel()
		board.get_viewport().set_input_as_handled()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_guidance() -> Dictionary:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store := board.get_tree().get_first_node_in_group("store")

	if store != null and store.has_method("get_activity_board_guidance"):
		return store.call("get_activity_board_guidance")

	return {
		"title": board.DEFAULT_TITLE,
		"lines": board.DEFAULT_LINES
	}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_board_panel(title: String, lines_variant: Variant) -> void:
	ensure_board_panel()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var content := board._board_panel.get_node("Content") as VBoxContainer
	clear_container(content)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 12)
	content.add_child(title_label)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var scroll := ScrollContainer.new()
	scroll.name = "LineScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var line_container := VBoxContainer.new()
	line_container.name = "Lines"
	line_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_container.add_theme_constant_override("separation", 4)
	scroll.add_child(line_container)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var lines: Array[String] = []

	for line_variant in lines_variant:
		lines.append(str(line_variant))

	for line in lines:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var label := Label.new()
		label.text = "%s" % line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 9)
		line_container.add_child(label)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hint_label := Label.new()
	hint_label.text = "Esc / Right Click to close"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 8)
	hint_label.modulate = Color(1.0, 0.92, 0.72, 0.78)
	content.add_child(hint_label)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(board._hide_board_panel)
	content.add_child(close_button)

	board._lock_player_actions()
	board._board_panel.visible = true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func ensure_board_panel() -> void:
	if board._board_layer != null and is_instance_valid(board._board_layer):
		return

	board._board_layer = CanvasLayer.new()
	board._board_layer.name = "ActivityBoardLayer"
	board._board_layer.layer = 18
	board.add_child(board._board_layer)

	board._board_panel = ColorRect.new()
	board._board_panel.name = "ActivityBoardPanel"
	board._board_panel.color = Color(0.1, 0.08, 0.05, 0.94)
	board._board_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	board._board_panel.custom_minimum_size = board.PANEL_SIZE
	board._board_panel.offset_left = -board.PANEL_SIZE.x * 0.5
	board._board_panel.offset_top = -board.PANEL_SIZE.y * 0.5
	board._board_panel.offset_right = board.PANEL_SIZE.x * 0.5
	board._board_panel.offset_bottom = board.PANEL_SIZE.y * 0.5
	board._board_panel.visible = false
	board._board_layer.add_child(board._board_panel)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var content := VBoxContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 10.0
	content.offset_top = 8.0
	content.offset_right = -10.0
	content.offset_bottom = -8.0
	content.add_theme_constant_override("separation", 4)
	board._board_panel.add_child(content)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func hide_board_panel() -> void:
	if board._board_panel != null:
		board._board_panel.visible = false

	board._unlock_player_actions()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func clear_container(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()
