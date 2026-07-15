class_name ActivityBoard
extends StaticBody2D

const DEFAULT_TITLE: String = "Today's Work"
const DEFAULT_LINES: Array[String] = [
	"Check storage for shelves and stock.",
	"Stock shelves, then serve customers."
]
const PANEL_SIZE := Vector2(292, 164)
const BOARD_GLOW_CYCLES: int = 3
const BOARD_GLOW_CYCLE_DURATION: float = 0.45

var _board_layer: CanvasLayer = null
var _board_panel: ColorRect = null
var _glow_line: Line2D = null
var _glow_tween: Tween = null
var _board_lock_active: bool = false


func _ready() -> void:
	_setup_cursor_hover()
	_setup_completion_glow()


func _exit_tree() -> void:
	_unlock_player_actions()


func open_board() -> void:
	if _board_panel != null and _board_panel.visible:
		return

	if _has_visible_overlay_named("CashierUILayer"):
		return

	var guidance := _get_guidance()
	_show_board_panel(
		str(guidance.get("title", DEFAULT_TITLE)),
		guidance.get("lines", DEFAULT_LINES)
	)


func play_completion_glow() -> void:
	if _glow_line == null:
		_setup_completion_glow()

	if _glow_line == null:
		return

	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()

	_glow_line.visible = true
	_glow_line.modulate.a = 0.0

	_glow_tween = create_tween()

	for i in BOARD_GLOW_CYCLES:
		_glow_tween.tween_property(
			_glow_line,
			"modulate:a",
			1.0,
			BOARD_GLOW_CYCLE_DURATION * 0.5
		)
		_glow_tween.tween_property(
			_glow_line,
			"modulate:a",
			0.0,
			BOARD_GLOW_CYCLE_DURATION * 0.5
		)

	_glow_tween.tween_callback(func() -> void:
		if _glow_line != null:
			_glow_line.visible = false
	)


func _unhandled_input(event: InputEvent) -> void:
	if _board_panel == null or not _board_panel.visible:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_hide_board_panel()
			get_viewport().set_input_as_handled()
		return

	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_ESCAPE or event.is_action_pressed("ui_cancel"):
		_hide_board_panel()
		get_viewport().set_input_as_handled()


func _get_guidance() -> Dictionary:
	var store := get_tree().get_first_node_in_group("store")

	if store != null and store.has_method("get_activity_board_guidance"):
		return store.call("get_activity_board_guidance")

	return {
		"title": DEFAULT_TITLE,
		"lines": DEFAULT_LINES
	}


func _show_board_panel(title: String, lines_variant: Variant) -> void:
	_ensure_board_panel()

	var content := _board_panel.get_node("Content") as VBoxContainer
	_clear_container(content)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 12)
	content.add_child(title_label)

	var scroll := ScrollContainer.new()
	scroll.name = "LineScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	var line_container := VBoxContainer.new()
	line_container.name = "Lines"
	line_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_container.add_theme_constant_override("separation", 4)
	scroll.add_child(line_container)

	var lines: Array[String] = []

	for line_variant in lines_variant:
		lines.append(str(line_variant))

	for line in lines:
		var label := Label.new()
		label.text = "%s" % line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 9)
		line_container.add_child(label)

	var hint_label := Label.new()
	hint_label.text = "Esc / Right Click to close"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 8)
	hint_label.modulate = Color(1.0, 0.92, 0.72, 0.78)
	content.add_child(hint_label)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(_hide_board_panel)
	content.add_child(close_button)

	_lock_player_actions()
	_board_panel.visible = true


func _ensure_board_panel() -> void:
	if _board_layer != null and is_instance_valid(_board_layer):
		return

	_board_layer = CanvasLayer.new()
	_board_layer.name = "ActivityBoardLayer"
	_board_layer.layer = 18
	add_child(_board_layer)

	_board_panel = ColorRect.new()
	_board_panel.name = "ActivityBoardPanel"
	_board_panel.color = Color(0.1, 0.08, 0.05, 0.94)
	_board_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_board_panel.custom_minimum_size = PANEL_SIZE
	_board_panel.offset_left = -PANEL_SIZE.x * 0.5
	_board_panel.offset_top = -PANEL_SIZE.y * 0.5
	_board_panel.offset_right = PANEL_SIZE.x * 0.5
	_board_panel.offset_bottom = PANEL_SIZE.y * 0.5
	_board_panel.visible = false
	_board_layer.add_child(_board_panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 10.0
	content.offset_top = 8.0
	content.offset_right = -10.0
	content.offset_bottom = -8.0
	content.add_theme_constant_override("separation", 4)
	_board_panel.add_child(content)


func _hide_board_panel() -> void:
	if _board_panel != null:
		_board_panel.visible = false

	_unlock_player_actions()


func _lock_player_actions() -> void:
	if _board_lock_active:
		return

	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("begin_action_lock"):
		hud.call("begin_action_lock")
		_board_lock_active = true


func _unlock_player_actions() -> void:
	if not _board_lock_active:
		return

	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("end_action_lock"):
		hud.call("end_action_lock")

	_board_lock_active = false


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()


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


func _setup_cursor_hover() -> void:
	var hover_area := get_node_or_null("InteractionArea") as Area2D

	if hover_area == null:
		return

	hover_area.input_pickable = true
	var entered := Callable(self, "_on_cursor_mouse_entered")
	var exited := Callable(self, "_on_cursor_mouse_exited")

	if not hover_area.mouse_entered.is_connected(entered):
		hover_area.mouse_entered.connect(entered)

	if not hover_area.mouse_exited.is_connected(exited):
		hover_area.mouse_exited.connect(exited)


func _on_cursor_mouse_entered() -> void:
	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_cursor_tooltip"):
		hud.call("show_cursor_tooltip", "Activity Board")


func _on_cursor_mouse_exited() -> void:
	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("hide_cursor_tooltip"):
		hud.call("hide_cursor_tooltip")


func _setup_completion_glow() -> void:
	if _glow_line != null:
		return

	_glow_line = Line2D.new()
	_glow_line.name = "CompletionGlow"
	_glow_line.points = _get_board_glow_points()
	_glow_line.closed = true
	_glow_line.width = 3.0
	_glow_line.default_color = Color(1.0, 0.86, 0.32, 1.0)
	_glow_line.visible = false
	_glow_line.z_index = 20
	_glow_line.modulate.a = 0.0
	add_child(_glow_line)


func _get_board_glow_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-40, -40),
		Vector2(40, -40),
		Vector2(40, 0),
		Vector2(-40, 0)
	])
