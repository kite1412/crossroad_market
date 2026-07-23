class_name RestockPackagePresentation
extends RefCounted

var package: RestockPackage = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(package_node: RestockPackage) -> void:
	package = package_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func ensure_visual() -> void:
	if package.get_node_or_null("CollisionShape2D") == null:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var rect := RectangleShape2D.new()
		rect.size = Vector2(40, 28)
		shape.shape = rect
		shape.position = Vector2(0, -10)
		package.add_child(shape)

	if package.get_node_or_null("VisualRoot") == null:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var visual_root := Node2D.new()
		visual_root.name = "VisualRoot"
		package.add_child(visual_root)

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var box := ColorRect.new()
		box.name = "SupplyBox"
		box.offset_left = -18.0
		box.offset_top = -22.0
		box.offset_right = 18.0
		box.offset_bottom = 2.0
		box.color = Color(0.46, 0.31, 0.16, 1.0)
		visual_root.add_child(box)

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var lid := ColorRect.new()
		lid.name = "SupplyBoxLid"
		lid.offset_left = -19.0
		lid.offset_top = -23.0
		lid.offset_right = 19.0
		lid.offset_bottom = -16.0
		lid.color = Color(0.32, 0.21, 0.11, 1.0)
		visual_root.add_child(lid)

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var strap := ColorRect.new()
		strap.name = "SupplyBoxStrap"
		strap.offset_left = -3.0
		strap.offset_top = -23.0
		strap.offset_right = 3.0
		strap.offset_bottom = 2.0
		strap.color = Color(0.86, 0.67, 0.36, 1.0)
		visual_root.add_child(strap)

		package._label = Label.new()
		package._label.name = "SupplyBoxLabel"
		package._label.position = Vector2(-24, 4)
		package._label.size = Vector2(48, 14)
		package._label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		package._label.add_theme_font_size_override("font_size", 7)
		visual_root.add_child(package._label)
	else:
		package._label = package.get_node_or_null("VisualRoot/SupplyBoxLabel") as Label


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func refresh_label() -> void:
	if package._label == null:
		return

	package._label.text = "x%d" % package.quantity


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_notification(text: String, duration: float) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("shadowed_variable")
	var hud := package.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, duration, false)
