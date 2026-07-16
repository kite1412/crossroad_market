class_name RestockPackage
extends Area2D

signal collected(delivery_id: int)

var delivery_id: int = -1
var item_id: String = ""
var quantity: int = 1

var _label: Label = null


func _ready() -> void:
	input_pickable = true
	monitoring = true
	monitorable = true
	_ensure_visual()
	_refresh_label()


func setup(id: int, package_item_id: String, package_quantity: int) -> void:
	delivery_id = id
	item_id = package_item_id
	quantity = maxi(package_quantity, 1)
	_refresh_label()


func get_hover_display_name() -> String:
	var item := ItemDatabase.get_item(item_id)
	var item_name := item.display_name if item != null and item.display_name != "" else item_id.capitalize()
	return "%s Package" % item_name


func request_interaction() -> bool:
	if item_id == "":
		return false

	Inventory.add_item(item_id, quantity)
	_show_notification("Picked up %s x%d." % [_get_item_name(), quantity], 0.9)
	collected.emit(delivery_id)
	queue_free()
	return true


func _get_item_name() -> String:
	var item := ItemDatabase.get_item(item_id)
	return item.display_name if item != null and item.display_name != "" else item_id.capitalize()


func _ensure_visual() -> void:
	if get_node_or_null("CollisionShape2D") == null:
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(48, 34)
		shape.shape = rect
		add_child(shape)

	if get_node_or_null("VisualRoot") == null:
		var visual_root := Node2D.new()
		visual_root.name = "VisualRoot"
		add_child(visual_root)

		var box := ColorRect.new()
		box.name = "PackageBox"
		box.offset_left = -22.0
		box.offset_top = -26.0
		box.offset_right = 22.0
		box.offset_bottom = 10.0
		box.color = Color(0.48, 0.32, 0.16, 1.0)
		visual_root.add_child(box)

		var strap := ColorRect.new()
		strap.name = "PackageStrap"
		strap.offset_left = -22.0
		strap.offset_top = -10.0
		strap.offset_right = 22.0
		strap.offset_bottom = -4.0
		strap.color = Color(0.86, 0.67, 0.36, 1.0)
		visual_root.add_child(strap)

		_label = Label.new()
		_label.name = "PackageLabel"
		_label.position = Vector2(-28, 12)
		_label.size = Vector2(56, 16)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 7)
		visual_root.add_child(_label)
	else:
		_label = get_node_or_null("VisualRoot/PackageLabel") as Label


func _refresh_label() -> void:
	if _label == null:
		return

	_label.text = "x%d" % quantity


func _show_notification(text: String, duration: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, duration, false)
