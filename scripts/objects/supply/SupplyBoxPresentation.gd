class_name SupplyBoxPresentation
extends RefCounted

var supply_box: SupplyBox = null


func setup(supply_box_node: SupplyBox) -> void:
	supply_box = supply_box_node


func get_hover_display_name() -> String:
	if supply_box.is_empty():
		return "Empty Supply Box"

	if supply_box.items_to_give.size() == 1:
		var item := ItemDatabase.get_item(supply_box.items_to_give[0])

		if item != null and item.display_name != "":
			return "%s Box" % item.display_name

	return "Supply Box"


func setup_cursor_hover() -> void:
	var hover_area := supply_box.get_node_or_null("Area2D") as Area2D

	if hover_area == null:
		return

	hover_area.input_pickable = true
	var entered := Callable(supply_box, "_on_cursor_mouse_entered")
	var exited := Callable(supply_box, "_on_cursor_mouse_exited")

	if not hover_area.mouse_entered.is_connected(entered):
		hover_area.mouse_entered.connect(entered)

	if not hover_area.mouse_exited.is_connected(exited):
		hover_area.mouse_exited.connect(exited)


func on_cursor_mouse_entered() -> void:
	show_cursor_tooltip(supply_box.get_hover_display_name())


func on_cursor_mouse_exited() -> void:
	hide_cursor_tooltip()


func show_cursor_tooltip(text: String) -> void:
	var hud := supply_box.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_cursor_tooltip"):
		hud.call("show_cursor_tooltip", text)


func hide_cursor_tooltip() -> void:
	var hud := supply_box.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("hide_cursor_tooltip"):
		hud.call("hide_cursor_tooltip")
