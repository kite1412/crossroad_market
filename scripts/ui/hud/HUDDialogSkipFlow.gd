class_name HUDDialogSkipFlow
extends RefCounted

var hud: CanvasLayer = null


func setup(hud_node: CanvasLayer) -> void:
	hud = hud_node


func handle_dialog_skip_input(event: InputEvent) -> void:
	if not is_dialog_skip_event(event):
		return

	if hud.has_method("is_dialog_visible") and hud.is_dialog_visible():
		return

	var skipped := false

	if hud._hint_dialog_flow != null and hud._hint_dialog_flow.is_visible():
		hud._hint_dialog_flow.hide_hint_dialog(true)
		hud.get_viewport().set_input_as_handled()
		return

	if hud.notification_label.visible and not has_interactive_overlay_open():
		hud._notification_flow.finish_notification()
		skipped = true

	if skip_world_dialogs():
		skipped = true

	if skipped:
		hud.get_viewport().set_input_as_handled()


func is_dialog_skip_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.pressed and mouse_event.button_index in [
			MOUSE_BUTTON_LEFT,
			MOUSE_BUTTON_RIGHT,
			MOUSE_BUTTON_MIDDLE
		]

	if event is InputEventScreenTouch:
		return event.pressed

	return false


func skip_world_dialogs() -> bool:
	var skipped := false

	for node in hud.get_tree().get_nodes_in_group("dialog_skip_target"):
		if node != null and node.has_method("skip_dialog"):
			skipped = bool(node.call("skip_dialog")) or skipped

	return skipped


func has_interactive_overlay_open() -> bool:
	return (
		(hud.has_method("is_dialog_visible") and hud.is_dialog_visible())
		or has_visible_overlay_named("CashierUILayer")
		or has_visible_overlay_named("ActivityBoardLayer")
		or has_visible_overlay_named("StorageRestockLayer")
		or has_visible_overlay_named("TaxReportLayer")
	)


func has_visible_overlay_named(node_name: String) -> bool:
	var root := hud.get_tree().root

	if root == null:
		return false

	return find_visible_overlay_named(root, node_name)


func find_visible_overlay_named(node: Node, node_name: String) -> bool:
	if node.name == node_name:
		if node is CanvasLayer:
			return (node as CanvasLayer).visible and has_visible_overlay_content(node)

		if node is CanvasItem and (node as CanvasItem).visible:
			return true

	for child in node.get_children():
		if find_visible_overlay_named(child, node_name):
			return true

	return false


func has_visible_overlay_content(node: Node) -> bool:
	for child in node.get_children():
		if child is CanvasItem and (child as CanvasItem).is_visible_in_tree():
			return true

		if has_visible_overlay_content(child):
			return true

	return false
