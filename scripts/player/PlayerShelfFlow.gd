class_name PlayerShelfFlow
extends RefCounted

const MAX_WRONG_ATTEMPTS: int = 1

var player = null


func setup(player_node) -> void:
	player = player_node


func interact_with_shelf(shelf: Shelf) -> void:
	if shelf.has_meta("is_carried_storage_object") and bool(shelf.get_meta("is_carried_storage_object")):
		player._show_notification("Press Q to place the shelf first.", 0.8)
		return

	if not is_shelf_installed_in_store(shelf):
		if try_pickup_shelf(shelf):
			return

		player._show_notification("Press E to pick up this shelf.", 0.8)
		return

	if try_pickup_shelf(shelf):
		return

	player._show_notification("Press Q to stock this shelf.", 0.8)


func try_put() -> void:
	if player._is_action_locked():
		return

	if try_drop_carried_object():
		return

	var shelf := get_best_shelf_target()

	if shelf == null:
		player._show_notification("No place target in reach.", 0.5)
		return

	if not is_shelf_installed_in_store(shelf):
		player._show_notification("Press E to pick up this shelf first.", 0.8)
		return

	put_item_on_shelf(shelf)


func put_item_on_shelf(shelf: Shelf) -> void:
	var inventory_items: Dictionary = Inventory.get_all()

	if inventory_items.is_empty():
		player._show_notification("No item to put.", 0.6)
		return

	var item_id: String = str(inventory_items.keys()[0])
	var item: ItemData = ItemDatabase.get_item(item_id)

	if item == null:
		player._show_notification("That item cannot be stocked yet.", 0.8)
		return

	var result: int = shelf.place_item(item_id)

	if result >= 0:
		player._wrong_shelf_attempts.erase(get_wrong_shelf_key(item_id, shelf))
		player._show_notification("Put %s on shelf." % item.display_name, 0.5)
		return

	if item.shelf_type != shelf.shelf_type:
		handle_wrong_shelf_attempt(item_id, item, shelf)
	elif is_shelf_full(shelf):
		player._show_notification("Shelf is full.", 0.6)
	else:
		player._show_notification("Could not put %s here." % item.display_name, 0.5)


func get_best_shelf_target() -> Shelf:
	var areas: Array[Area2D] = player.interaction_area.get_overlapping_areas()
	var best_shelf: Shelf = null
	var best_distance: float = INF

	for area in areas:
		var parent := area.get_parent()

		if not parent is Shelf:
			continue

		var distance: float = player.global_position.distance_squared_to(area.global_position)

		if distance < best_distance:
			best_shelf = parent as Shelf
			best_distance = distance

	return best_shelf


func take_item_from_shelf(shelf: Shelf) -> void:
	var item_id: String = shelf.remove_first_item()

	if item_id == "":
		player._show_notification("Shelf is empty.", 0.5)
		return

	var item: ItemData = ItemDatabase.get_item(item_id)

	if item != null:
		player._show_notification("Took %s" % item.display_name, 0.5)
	else:
		player._show_notification("Took %s" % item_id, 0.5)


func handle_wrong_shelf_attempt(
	item_id: String,
	item: ItemData,
	shelf: Shelf
) -> void:
	var attempt_key: String = get_wrong_shelf_key(item_id, shelf)
	var attempts: int = int(player._wrong_shelf_attempts.get(attempt_key, 0))

	if attempts >= MAX_WRONG_ATTEMPTS:
		return

	attempts += 1
	player._wrong_shelf_attempts[attempt_key] = attempts

	if attempts >= MAX_WRONG_ATTEMPTS:
		await player._show_notification_sequence([
			"%s does not fit on this shelf." % item.display_name,
			"Try the %s shelf." % get_shelf_type_label(item.shelf_type)
		])
	else:
		player._show_notification(
			"The item fell off the shelf... (%d/%d)" %
			[attempts, MAX_WRONG_ATTEMPTS]
		)


func is_shelf_full(shelf: Shelf) -> bool:
	for slot_index in shelf.max_slots:
		if shelf.get_slot_content(slot_index) == "":
			return false

	return true


func get_shelf_type_label(shelf_type: ItemData.ShelfType) -> String:
	match shelf_type:
		ItemData.ShelfType.HUMAN:
			return "human"
		ItemData.ShelfType.GHOST:
			return "ghost"

	return "matching"


func get_wrong_shelf_key(item_id: String, shelf: Shelf) -> String:
	return PlayerShelfInteraction.get_wrong_shelf_key(item_id, shelf)


func is_shelf_installed_in_store(shelf: Shelf) -> bool:
	return PlayerShelfInteraction.is_shelf_installed_in_store(shelf)


func get_carried_shelf() -> Shelf:
	var carried_object := get_carried_object()

	return carried_object as Shelf if carried_object is Shelf else null


func get_carried_object() -> Node2D:
	for child in player.get_children():
		if child is Node2D and child.has_meta("is_carried_storage_object"):
			if bool(child.get_meta("is_carried_storage_object")):
				return child as Node2D

	return null


func try_pickup_shelf(shelf: Shelf) -> bool:
	for group_name in ["store", "storage"]:
		var location: Node = player.get_tree().get_first_node_in_group(group_name)

		if location != null and location.has_method("request_pickup_shelf"):
			if bool(location.call("request_pickup_shelf", shelf)):
				return true

	return false


func try_drop_carried_object() -> bool:
	for group_name in ["store", "storage"]:
		var location: Node = player.get_tree().get_first_node_in_group(group_name)

		if location != null and location.has_method("request_drop_carried_shelf"):
			if bool(location.call("request_drop_carried_shelf")):
				return true

		if location != null and location.has_method("request_drop_carried_object"):
			if bool(location.call("request_drop_carried_object")):
				return true

	return false
