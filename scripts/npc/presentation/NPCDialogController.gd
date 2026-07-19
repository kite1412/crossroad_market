class_name NPCDialogController
extends RefCounted


static func set_mouse_filter(npc: Node) -> void:
	if npc == null:
		return

	var bubble := npc.get_node_or_null("DialogBubble") as Control
	var label := npc.get_node_or_null("DialogBubble/DialogLabel") as Control

	if bubble != null:
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if label != null:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func show_dialog(npc: Node, npc_data: NPCData, text: String) -> bool:
	if npc == null:
		return false

	var bubble := npc.get_node_or_null("DialogBubble") as ColorRect
	var label := npc.get_node_or_null("DialogBubble/DialogLabel") as Label

	if label == null:
		label = npc.get_node_or_null("DialogLabel") as Label

	if bubble == null or label == null:
		pass
		return false

	set_mouse_filter(npc)
	label.text = text
	bubble.visible = true
	return true


static func hide_dialog(npc: Node) -> void:
	if npc == null:
		return

	var bubble := npc.get_node_or_null("DialogBubble") as ColorRect

	if bubble != null:
		bubble.visible = false
