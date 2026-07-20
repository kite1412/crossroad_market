class_name CashierCartController
extends RefCounted

var cashier: Cashier = null


func setup(cashier_node: Cashier) -> void:
	cashier = cashier_node


func on_scan_item_pressed(item_id: String) -> void:
	cashier._pending_item_id = item_id
	cashier._show_scan_panel()


func on_add_item_pressed() -> void:
	if cashier._pending_item_id == "":
		cashier._show_notification("Select an item first.", 0.8)
		return

	increment_cart_item(cashier._pending_item_id)
	cashier._pending_item_id = ""
	update_selected_label()
	cashier._show_scan_panel()


func on_increment_cart_item_pressed(item_id: String) -> void:
	increment_cart_item(item_id)
	update_selected_label()
	cashier._show_scan_panel()


func on_decrement_cart_item_pressed(item_id: String) -> void:
	if not cashier._cart_quantities.has(item_id):
		return

	var quantity := int(cashier._cart_quantities[item_id]) - 1

	if quantity <= 0:
		cashier._cart_quantities.erase(item_id)
	else:
		cashier._cart_quantities[item_id] = quantity

	update_selected_label()
	cashier._show_scan_panel()


func on_delete_cart_item_pressed(item_id: String) -> void:
	if not cashier._cart_quantities.has(item_id):
		return

	cashier._cart_quantities.erase(item_id)
	update_selected_label()
	cashier._show_scan_panel()


func on_confirm_scan_pressed() -> void:
	if cashier._cart_quantities.is_empty():
		cashier._show_notification("Add an item first.", 0.9)
		return

	if not selection_matches_customer():
		cashier._show_notification("This customer did not ask for that item.", 1.2)
		return

	cashier._scanned_total = calculate_selected_total()
	cashier._scanned_item_label = get_selected_item_label()
	if cashier._is_story_gift_checkout():
		cashier._show_gooby_choice_panel()
		return

	cashier._show_paid_panel()


func selection_matches_customer() -> bool:
	return CashierCheckoutService.selection_matches_customer(get_cart_item_ids_expanded(), cashier._target_item_ids)


func calculate_selected_total() -> int:
	return CashierCheckoutService.calculate_total(get_cart_item_ids_expanded())


func get_selected_item_label() -> String:
	return get_cart_summary_label()


func get_pending_item_label() -> String:
	if cashier._pending_item_id == "":
		return "-"

	return get_item_display_label(cashier._pending_item_id)


func get_item_display_label(item_id: String) -> String:
	var item := ItemDatabase.get_item(item_id)

	if item == null:
		return item_id

	return "%s %dG" % [item.display_name, item.sell_price]


func get_store_items() -> Array[ItemData]:
	var items: Array[ItemData] = ItemDatabase.get_all_items()

	if items.is_empty():
		var fallback_items: Array[ItemData] = []
		var dir := DirAccess.open("res://data/items")

		if dir == null:
			return fallback_items

		dir.list_dir_begin()
		var file_name := dir.get_next()

		while file_name != "":
			if file_name.ends_with(".tres"):
				var item := load("res://data/items/" + file_name) as ItemData

				if item != null and item.item_id != "":
					fallback_items.append(item)

			file_name = dir.get_next()

		items = fallback_items

	items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		if a.shelf_type != b.shelf_type:
			return a.shelf_type < b.shelf_type
		return a.display_name < b.display_name
	)
	return items


func get_item_shelf_color(item: ItemData) -> Color:
	if item != null and item.shelf_type == ItemData.ShelfType.GHOST:
		return Color(0.43, 0.32, 0.78, 1.0)

	return Color(0.66, 0.48, 0.26, 1.0)


func get_item_name(item_id: String) -> String:
	var item := ItemDatabase.get_item(item_id)

	if item == null:
		return item_id

	return item.display_name


func get_item_unit_price(item_id: String) -> int:
	var item := ItemDatabase.get_item(item_id)

	if item == null:
		return 0

	return item.sell_price


func get_cart_item_ids_ordered() -> Array[String]:
	var ordered: Array[String] = []

	for item in get_store_items():
		if item == null:
			continue

		if cashier._cart_quantities.has(item.item_id):
			ordered.append(item.item_id)

	for key in cashier._cart_quantities.keys():
		var item_id := str(key)

		if item_id not in ordered:
			ordered.append(item_id)

	return ordered


func get_cart_item_ids_expanded() -> Array[String]:
	var item_ids: Array[String] = []

	for item_id in get_cart_item_ids_ordered():
		var quantity := int(cashier._cart_quantities.get(item_id, 0))

		for i in range(quantity):
			item_ids.append(item_id)

	return item_ids


func get_cart_row_label(item_id: String) -> String:
	var unit_price := get_item_unit_price(item_id)
	var quantity := int(cashier._cart_quantities.get(item_id, 0))
	var line_total := unit_price * quantity
	return "%s  %dG x%d = %dG" % [
		get_item_name(item_id),
		unit_price,
		quantity,
		line_total
	]


func get_cart_summary_label() -> String:
	var labels: Array[String] = []

	for item_id in get_cart_item_ids_ordered():
		var quantity := int(cashier._cart_quantities.get(item_id, 0))
		var item_name := get_item_name(item_id)

		if quantity > 1:
			labels.append("%s x%d" % [item_name, quantity])
		else:
			labels.append(item_name)

	return ", ".join(labels)


func increment_cart_item(item_id: String) -> void:
	if item_id == "":
		return

	cashier._cart_quantities[item_id] = int(cashier._cart_quantities.get(item_id, 0)) + 1


func update_selected_label() -> void:
	var total := calculate_selected_total()
	var label := get_selected_item_label()
	cashier._selected_label.text = "Cart: %s | Total %dG" % [label if label != "" else "-", total]
