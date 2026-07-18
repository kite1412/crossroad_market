class_name MysterySupplyVisualController
extends RefCounted

var box: MysterySupplyBox = null


func setup(box_node: MysterySupplyBox) -> void:
	box = box_node


func apply_glow(enabled: bool) -> void:
	if enabled:
		apply_visual_tint(Color(0.4, 0.3, 0.8, 1.0))
	else:
		apply_visual_tint(Color(0.2, 0.2, 0.2, 0.3))


func apply_visual_tint(color: Color) -> void:
	var color_rect := box.get_node_or_null("VisualRoot/PlaceholderRect") as ColorRect

	if color_rect != null:
		color_rect.color = color
		return

	var visual := box.get_node_or_null("VisualRoot/AssetSprite") as CanvasItem

	if visual != null:
		visual.modulate = color
