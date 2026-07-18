class_name ShelfHoverController
extends RefCounted

var shelf: Shelf = null


func setup(shelf_node: Shelf) -> void:
	shelf = shelf_node


func setup_cursor_hover() -> void:
	var interaction_area := shelf.get_node_or_null("InteractionArea") as Area2D

	if interaction_area != null:
		interaction_area.input_pickable = true
		var shelf_entered := Callable(shelf, "_on_shelf_mouse_entered")
		var shelf_exited := Callable(shelf, "_on_shelf_mouse_exited")

		if not interaction_area.mouse_entered.is_connected(shelf_entered):
			interaction_area.mouse_entered.connect(shelf_entered)

		if not interaction_area.mouse_exited.is_connected(shelf_exited):
			interaction_area.mouse_exited.connect(shelf_exited)

	var slots := shelf.get_node_or_null("Slots")

	if slots == null:
		return

	for i in range(shelf.max_slots):
		var slot_area := slots.get_node_or_null("Slot%d" % i) as Area2D

		if slot_area == null:
			continue

		slot_area.input_pickable = true
		var slot_entered := Callable(shelf, "_on_slot_mouse_entered").bind(i)
		var slot_exited := Callable(shelf, "_on_slot_mouse_exited")

		if not slot_area.mouse_entered.is_connected(slot_entered):
			slot_area.mouse_entered.connect(slot_entered)

		if not slot_area.mouse_exited.is_connected(slot_exited):
			slot_area.mouse_exited.connect(slot_exited)


func on_shelf_mouse_entered() -> void:
	shelf._is_shelf_hovered = true
	show_cursor_tooltip(shelf.get_hover_display_name())


func on_shelf_mouse_exited() -> void:
	shelf._is_shelf_hovered = false
	hide_cursor_tooltip()


func on_slot_mouse_entered(slot_index: int) -> void:
	show_cursor_tooltip(get_slot_hover_name(slot_index))


func on_slot_mouse_exited() -> void:
	if shelf._is_shelf_hovered:
		show_cursor_tooltip(shelf.get_hover_display_name())
	else:
		hide_cursor_tooltip()


func get_slot_hover_name(slot_index: int) -> String:
	var item_id := shelf.get_slot_content(slot_index)

	if item_id == "":
		return shelf.get_hover_display_name()

	var item := ItemDatabase.get_item(item_id)
	return item.display_name if item != null and item.display_name != "" else item_id.capitalize()


func show_cursor_tooltip(text: String) -> void:
	var hud := shelf.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_cursor_tooltip"):
		hud.call("show_cursor_tooltip", text)


func hide_cursor_tooltip() -> void:
	var hud := shelf.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("hide_cursor_tooltip"):
		hud.call("hide_cursor_tooltip")
