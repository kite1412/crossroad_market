class_name HUDDialogController
extends RefCounted

## Controls the reusable full-screen Dialog instance owned by the HUD.
##
## Dialog lines are dictionaries with `name`, `content`, and optional `portrait`
## and `frame` fields.

signal sequence_finished
signal _next_line_requested

var hud: CanvasLayer = null
var dialog: Dialog = null

var _active: bool = false
var _advance_requested: bool = false


func setup(hud_node: CanvasLayer) -> void:
	hud = hud_node
	dialog = hud.get_node_or_null("Dialog") as Dialog

	if dialog == null:
		push_error("HUDDialogController: HUD is missing its Dialog instance.")
		return

	var next_callable := Callable(self, "_on_next_requested")
	if not dialog.next_requested.is_connected(next_callable):
		dialog.next_requested.connect(next_callable)

	dialog.visible = false


func show_dialog_sequence(dialogues: Array[Dictionary]) -> void:
	if dialog == null or dialogues.is_empty():
		return

	if _active:
		await sequence_finished

	_active = true
	_begin_action_lock()

	for index in dialogues.size():
		var line: Dictionary = dialogues[index]
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


func is_visible() -> bool:
	return _active and dialog != null and dialog.visible


func _wait_for_next() -> void:
	if _advance_requested:
		_advance_requested = false
		return

	await _next_line_requested
	_advance_requested = false


func _on_next_requested() -> void:
	if not _active:
		return

	_advance_requested = true
	_next_line_requested.emit()


func _begin_action_lock() -> void:
	if hud != null and hud.has_method("begin_action_lock"):
		hud.call("begin_action_lock")


func _end_action_lock() -> void:
	if hud != null and hud.has_method("end_action_lock"):
		hud.call("end_action_lock")
