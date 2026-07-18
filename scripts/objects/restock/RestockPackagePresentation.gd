class_name RestockPackagePresentation
extends RefCounted

var package: RestockPackage = null


func setup(package_node: RestockPackage) -> void:
	package = package_node


func ensure_visual() -> void:
	if package.get_node_or_null("CollisionShape2D") == null:
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(64, 42)
		shape.shape = rect
		package.add_child(shape)

	if package.get_node_or_null("VisualRoot") == null:
		var visual_root := Node2D.new()
		visual_root.name = "VisualRoot"
		package.add_child(visual_root)

		var box := ColorRect.new()
		box.name = "SupplyBox"
		box.offset_left = -30.0
		box.offset_top = -28.0
		box.offset_right = 30.0
		box.offset_bottom = 14.0
		box.color = Color(0.46, 0.31, 0.16, 1.0)
		visual_root.add_child(box)

		var strap := ColorRect.new()
		strap.name = "SupplyBoxStrap"
		strap.offset_left = -30.0
		strap.offset_top = -10.0
		strap.offset_right = 30.0
		strap.offset_bottom = -3.0
		strap.color = Color(0.86, 0.67, 0.36, 1.0)
		visual_root.add_child(strap)

		package._label = Label.new()
		package._label.name = "SupplyBoxLabel"
		package._label.position = Vector2(-36, 15)
		package._label.size = Vector2(72, 16)
		package._label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		package._label.add_theme_font_size_override("font_size", 7)
		visual_root.add_child(package._label)
	else:
		package._label = package.get_node_or_null("VisualRoot/SupplyBoxLabel") as Label


func refresh_label() -> void:
	if package._label == null:
		return

	package._label.text = "x%d" % package.quantity


func show_notification(text: String, duration: float) -> void:
	var hud := package.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, duration, false)
