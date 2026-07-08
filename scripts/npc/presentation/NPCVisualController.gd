class_name NPCVisualController
extends RefCounted


static func apply_name_label(npc: Node, npc_data: NPCData) -> void:
	if npc == null:
		return

	var label := npc.get_node_or_null("NameLabel") as Label

	if label == null:
		return

	if npc_data != null:
		label.text = npc_data.display_name


static func apply_visual(npc: Node, npc_data: NPCData) -> void:
	if npc == null:
		return

	var color_rect := npc.get_node_or_null("ColorRect") as ColorRect
	var name_label := npc.get_node_or_null("NameLabel") as Label

	if color_rect == null or npc_data == null:
		return

	if npc_data.npc_category == NPCData.NPCCategory.STORY:
		if npc_data.npc_id == "irene":
			color_rect.color = Color(0.2, 0.7, 0.3, 1.0)
			if name_label != null:
				name_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4, 1.0))
		elif npc_data.npc_id == "gooby":
			color_rect.color = Color(0.4, 0.2, 0.8, 1.0)
			if name_label != null:
				name_label.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0, 1.0))
		return

	if npc_data.visit_phase == NPCData.VisitPhase.DAY:
		color_rect.color = Color(1.0, 0.5, 0.0, 0.75)
		if name_label != null:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4, 1.0))
	else:
		color_rect.color = Color(0.3, 0.5, 0.9, 0.75)
		if name_label != null:
			name_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 1.0))
