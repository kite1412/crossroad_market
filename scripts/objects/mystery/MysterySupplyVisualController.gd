class_name MysterySupplyVisualController
extends RefCounted

var box: MysterySupplyBox = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(box_node: MysterySupplyBox) -> void:
	box = box_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_glow(enabled: bool) -> void:
	if enabled:
		apply_visual_tint(Color(0.4, 0.3, 0.8, 1.0))
	else:
		apply_visual_tint(Color(0.2, 0.2, 0.2, 0.3))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_visual_tint(color: Color) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var color_rect := box.get_node_or_null("VisualRoot/PlaceholderRect") as ColorRect

	if color_rect != null:
		color_rect.color = color
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var visual := box.get_node_or_null("VisualRoot/AssetSprite") as CanvasItem

	if visual != null:
		visual.modulate = color
