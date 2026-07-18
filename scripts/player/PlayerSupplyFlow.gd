class_name PlayerSupplyFlow
extends RefCounted

var player = null


func setup(player_node) -> void:
	player = player_node


func interact_with_supply_box(box: SupplyBox) -> void:
	var available: Array = box.get_available_items()

	if available.is_empty():
		player._show_notification("This box is already empty.")
		return

	if not is_supply_box_shelf_ready(available):
		player._show_notification("maybe I should move the shelf out first")
		return

	player._supply_box_cursor = player._supply_box_cursor % available.size()

	var item_id: String = str(available[player._supply_box_cursor])

	if box.collect_one(item_id):
		var item: ItemData = ItemDatabase.get_item(item_id)

		show_pickup_notification(item_id, item)

		if not (box is MysterySupplyBox):
			notify_mystery_taken()

	var updated_available: Array = box.get_available_items()

	if updated_available.size() > 0:
		player._supply_box_cursor = (player._supply_box_cursor + 1) % updated_available.size()
	else:
		player._supply_box_cursor = 0


func is_supply_box_shelf_ready(available_items: Array) -> bool:
	return PlayerShelfInteraction.is_supply_box_shelf_ready(player.get_tree(), available_items)


func has_installed_shelf_type(shelf_type: int) -> bool:
	return PlayerShelfInteraction.has_installed_shelf_type(player.get_tree(), shelf_type)


func notify_mystery_taken() -> void:
	var world: Node = player.get_tree().get_first_node_in_group("store")

	if world == null:
		return

	if world.has_method("on_normal_item_taken"):
		world.on_normal_item_taken()


func show_pickup_notification(item_id: String, item: ItemData) -> void:
	var item_name := item.display_name if item != null else item_id

	if player._seen_item_ids.has(item_id):
		player._show_notification("Took %s" % item_name, 0.5)
		return

	player._seen_item_ids[item_id] = true

	if item == null:
		player._show_notification("Took %s. Press Q near a shelf to try putting it there." % item_name, 2.2)
		return

	player._show_notification(
		"Took %s. Press Q near the %s shelf to stock it. Press E near a shelf to take stock." %
		[item.display_name, player._get_shelf_type_label(item.shelf_type)],
		3.0
	)
