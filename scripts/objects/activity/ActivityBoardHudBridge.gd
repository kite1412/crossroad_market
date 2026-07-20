class_name ActivityBoardHudBridge
extends RefCounted

var board: ActivityBoard = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(board_node: ActivityBoard) -> void:
	board = board_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func lock_player_actions() -> void:
	if board._board_lock_active:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud := board.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("begin_action_lock"):
		hud.call("begin_action_lock")
		board._board_lock_active = true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func unlock_player_actions() -> void:
	if not board._board_lock_active:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud := board.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("end_action_lock"):
		hud.call("end_action_lock")

	board._board_lock_active = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_visible_overlay_named(node_name: String) -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var root := board.get_tree().root

	if root == null:
		return false

	return find_visible_overlay_named(root, node_name)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_visible_overlay_named(node: Node, node_name: String) -> bool:
	if node.name == node_name and node is CanvasItem and (node as CanvasItem).visible:
		return true

	for child in node.get_children():
		if find_visible_overlay_named(child, node_name):
			return true

	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup_cursor_hover() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hover_area := board.get_node_or_null("InteractionArea") as Area2D

	if hover_area == null:
		return

	hover_area.input_pickable = true
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var entered := Callable(board, "_on_cursor_mouse_entered")
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var exited := Callable(board, "_on_cursor_mouse_exited")

	if not hover_area.mouse_entered.is_connected(entered):
		hover_area.mouse_entered.connect(entered)

	if not hover_area.mouse_exited.is_connected(exited):
		hover_area.mouse_exited.connect(exited)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_cursor_mouse_entered() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud := board.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_cursor_tooltip"):
		hud.call("show_cursor_tooltip", "Activity Board")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_cursor_mouse_exited() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud := board.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("hide_cursor_tooltip"):
		hud.call("hide_cursor_tooltip")
