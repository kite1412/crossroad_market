class_name RestockPackageDataFlow
extends RefCounted

var package: RestockPackage = null


func setup(package_node: RestockPackage) -> void:
	package = package_node


func setup_package(id: int, package_item_id: String, package_quantity: int) -> void:
	package.delivery_id = id
	package.item_id = package_item_id
	package.quantity = maxi(package_quantity, 1)
	package.deliveries = [{
		"item_id": package.item_id,
		"quantity": package.quantity
	}]
	package._refresh_label()


func setup_deliveries(package_deliveries: Array) -> void:
	package.delivery_id = -1
	package.item_id = ""
	package.quantity = 0
	package.deliveries.clear()

	for delivery in package_deliveries:
		if not (delivery is Dictionary):
			continue

		var data := delivery as Dictionary
		var delivery_items := data.get("items", []) as Array

		if delivery_items.is_empty() and data.has("item_id"):
			delivery_items = [data]

		for item in delivery_items:
			if not (item is Dictionary):
				continue

			var item_data := item as Dictionary
			var delivery_item_id := str(item_data.get("item_id", ""))
			var delivery_quantity := int(item_data.get("quantity", 0))

			if delivery_item_id == "" or delivery_quantity <= 0:
				continue

			package.deliveries.append({
				"item_id": delivery_item_id,
				"quantity": delivery_quantity
			})
			package.quantity += delivery_quantity

	package._refresh_label()


func request_interaction() -> bool:
	if package.deliveries.is_empty():
		return false

	for delivery in package.deliveries:
		Inventory.add_item(str(delivery.get("item_id", "")), int(delivery.get("quantity", 1)))

	package._show_notification("Picked up restock delivery x%d." % package.quantity, 0.9)
	package.collected.emit(package.delivery_id)
	package.queue_free()
	return true


func get_item_name() -> String:
	var item := ItemDatabase.get_item(package.item_id)
	return item.display_name if item != null and item.display_name != "" else package.item_id.capitalize()
