class_name HUDDialogController
extends RefCounted

## Controls the reusable full-screen Dialog instance owned by the HUD.
##
## Dialog lines are dictionaries with `name`, `content`, and optional `portrait`
## and `frame` fields.

@warning_ignore("unused_signal")
signal sequence_finished
@warning_ignore("unused_signal")
signal _next_line_requested

var hud: CanvasLayer = null
var dialog: Dialog = null

@warning_ignore("unused_private_class_variable")
var _active: bool = false
@warning_ignore("unused_private_class_variable")
var _advance_requested: bool = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(hud_node: CanvasLayer) -> void:
	hud = hud_node
	dialog = hud.get_node_or_null("Dialog") as Dialog

	if dialog == null:
		pass
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var next_callable := Callable(self, "_on_next_requested")
	if not dialog.next_requested.is_connected(next_callable):
		dialog.next_requested.connect(next_callable)

	dialog.visible = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_dialog_sequence(dialogues: Array[Dictionary]) -> void:
	if dialog == null or dialogues.is_empty():
		return

	if _active:
		await sequence_finished

	_active = true
	_begin_action_lock()

	for index in dialogues.size():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var line: Dictionary = dialogues[index]
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var is_last_line := index == dialogues.size() - 1

		dialog.next_text = "Close" if is_last_line else "Next..."
		dialog.show_dialog(
			str(line.get("name", "")),
			str(line.get("content", "")),
			line.get("portrait", null) as Texture2D,
			int(line.get("frame", 0))
		)
		dialog.close_on_next = false
		dialog.close_on_escape = false
		await _wait_for_next()

	dialog.hide_dialog()
	_active = false
	_end_action_lock()
	sequence_finished.emit()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_visible() -> bool:
	return _active and dialog != null and dialog.visible


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _wait_for_next() -> void:
	if _advance_requested:
		_advance_requested = false
		return

	await _next_line_requested
	_advance_requested = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_next_requested() -> void:
	if not _active:
		return

	_advance_requested = true
	_next_line_requested.emit()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _begin_action_lock() -> void:
	if hud != null and hud.has_method("begin_action_lock"):
		hud.call("begin_action_lock")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _end_action_lock() -> void:
	if hud != null and hud.has_method("end_action_lock"):
		hud.call("end_action_lock")
