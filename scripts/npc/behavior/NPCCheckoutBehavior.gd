class_name NPCCheckoutBehavior
extends RefCounted


static func get_checkout_total(cart_items: Array[String], fallback_item_id: String, total_override: int) -> int:
	if total_override >= 0:
		return total_override

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var total := 0

	for cart_item_id in cart_items:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item: ItemData = ItemDatabase.get_item(cart_item_id)

		if item != null:
			total += item.sell_price

	if total > 0:
		return total

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var fallback_item: ItemData = ItemDatabase.get_item(fallback_item_id)
	return fallback_item.sell_price if fallback_item != null else 0


static func get_checkout_item_label(cart_items: Array[String], fallback_item_id: String) -> String:
	if cart_items.is_empty():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item: ItemData = ItemDatabase.get_item(fallback_item_id)
		return item.display_name if item != null else fallback_item_id

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var names: Array[String] = []

	for cart_item_id in cart_items:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item: ItemData = ItemDatabase.get_item(cart_item_id)
		names.append(item.display_name if item != null else cart_item_id)

	return ", ".join(names)


static func get_cart_item_ids(cart_items: Array[String], fallback_item_id: String) -> Array[String]:
	if not cart_items.is_empty():
		return cart_items.duplicate()

	return [fallback_item_id] if fallback_item_id != "" else []
