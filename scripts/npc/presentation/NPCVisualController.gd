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

	var name_label := npc.get_node_or_null("NameLabel") as Label

	if npc_data == null:
		return
		
	name_label.add_theme_font_size_override("font_size", 6)

	if npc_data.npc_category == NPCData.NPCCategory.STORY:
		if npc_data.npc_id == "irene":
			_apply_visual_tint(npc, Color(0.2, 0.7, 0.3, 1.0))
			if name_label != null:
				name_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4, 1.0))
		elif npc_data.npc_id == "gooby":
			_apply_visual_tint(npc, Color(0.4, 0.2, 0.8, 1.0))
			if name_label != null:
				name_label.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0, 1.0))
		return

	if npc_data.visit_phase == NPCData.VisitPhase.DAY:
		_apply_visual_tint(npc, Color(1.0, 0.5, 0.0, 0.75))
		if name_label != null:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4, 1.0))
	else:
		_apply_visual_tint(npc, Color(0.3, 0.5, 0.9, 0.75))
		if name_label != null:
			name_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 1.0))


static func _apply_visual_tint(npc: Node, color: Color) -> void:
	#var idle_visual := npc.get_node_or_null("VisualRoot/SpriteIdle") as CanvasItem
	#var walk_visual := npc.get_node_or_null("VisualRoot/SpriteMove") as CanvasItem
	#if idle_visual != null or walk_visual != null:
		#if idle_visual != null:
			#idle_visual.modulate = color
		#if walk_visual != null:
			#walk_visual.modulate = color
		#return

	var color_rect := npc.get_node_or_null("VisualRoot/PlaceholderRect") as ColorRect

	if color_rect != null:
		color_rect.color = color
		return
