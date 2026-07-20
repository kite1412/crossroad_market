class_name ActivityBoardGlowController
extends RefCounted

var board: ActivityBoard = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(board_node: ActivityBoard) -> void:
	board = board_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func play_completion_glow() -> void:
	if board._glow_line == null:
		setup_completion_glow()

	if board._glow_line == null:
		return

	if board._glow_tween != null and board._glow_tween.is_valid():
		board._glow_tween.kill()

	board._glow_line.visible = true
	board._glow_line.modulate.a = 0.0

	board._glow_tween = board.create_tween()

	for i in board.BOARD_GLOW_CYCLES:
		board._glow_tween.tween_property(
			board._glow_line,
			"modulate:a",
			1.0,
			board.BOARD_GLOW_CYCLE_DURATION * 0.5
		)
		board._glow_tween.tween_property(
			board._glow_line,
			"modulate:a",
			0.0,
			board.BOARD_GLOW_CYCLE_DURATION * 0.5
		)

	board._glow_tween.tween_callback(func() -> void:
		if board._glow_line != null:
			board._glow_line.visible = false
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup_completion_glow() -> void:
	if board._glow_line != null:
		return

	board._glow_line = Line2D.new()
	board._glow_line.name = "CompletionGlow"
	board._glow_line.points = get_board_glow_points()
	board._glow_line.closed = true
	board._glow_line.width = 3.0
	board._glow_line.default_color = Color(1.0, 0.86, 0.32, 1.0)
	board._glow_line.visible = false
	board._glow_line.z_index = 20
	board._glow_line.modulate.a = 0.0
	board.add_child(board._glow_line)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_board_glow_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-40, -40),
		Vector2(40, -40),
		Vector2(40, 0),
		Vector2(-40, 0)
	])
