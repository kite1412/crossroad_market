class_name NPCDialogController
extends RefCounted


static func set_mouse_filter(npc: Node) -> void:
	if npc == null:
		return

	var dialog_bubble := npc.get_node_or_null("DialogBubble") as Control
	var dialog_label := npc.get_node_or_null("DialogBubble/DialogLabel") as Control

	if dialog_bubble != null:
		dialog_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if dialog_label != null:
		dialog_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func show_dialog(npc: Node, _npc_data: NPCData, text: String) -> bool:
	if npc == null:
		return false

	var dialog_bubble := npc.get_node_or_null("DialogBubble") as ColorRect
	var dialog_label := npc.get_node_or_null("DialogBubble/DialogLabel") as Label

	if dialog_label == null:
		dialog_label = npc.get_node_or_null("DialogLabel") as Label

	if dialog_bubble == null or dialog_label == null:
		return false

	set_mouse_filter(npc)
	dialog_label.text = text
	dialog_bubble.visible = true
	return true


static func hide_dialog(npc: Node) -> void:
	if npc == null:
		return

	var dialog_bubble := npc.get_node_or_null("DialogBubble") as ColorRect

	if dialog_bubble != null:
		dialog_bubble.visible = false
