class_name OpenCloseBoardVisualController
extends RefCounted

var board: OpenCloseBoard = null


func setup(board_node: OpenCloseBoard) -> void:
	board = board_node


func ready() -> void:
	board.add_to_group("open_close_board")

	if board.interaction_area != null:
		board.interaction_area.input_pickable = true

	set_open_state(false, false)


func set_open_state(is_open: bool, animated: bool = true) -> void:
	board._is_open = is_open

	if board.status_label != null:
		board.status_label.text = "OPEN" if board._is_open else "CLOSED"

	var target_color := board.OPEN_COLOR if board._is_open else board.CLOSED_COLOR

	if board._status_tween != null and board._status_tween.is_valid():
		board._status_tween.kill()
	board._status_tween = null

	if not animated:
		if board.status_panel != null:
			board.status_panel.color = target_color

		if board.visual_root != null:
			board.visual_root.scale = Vector2.ONE

		return

	board._status_tween = board.create_tween()
	board._status_tween.set_parallel(true)

	if board.status_panel != null:
		board._status_tween.tween_property(board.status_panel, "color", target_color, board.STATUS_ANIM_DURATION)

	if board.visual_root != null:
		board._status_tween.tween_property(board.visual_root, "scale", board.STATUS_PULSE_SCALE, 0.12)
		board._status_tween.chain().tween_property(board.visual_root, "scale", Vector2.ONE, 0.12)


func request_interaction() -> void:
	var store := board.get_tree().get_first_node_in_group("store")

	if store != null and store.has_method("request_toggle_store_open"):
		store.call("request_toggle_store_open")
