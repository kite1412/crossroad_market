class_name PlayerShelfFlow
extends RefCounted

const MAX_WRONG_ATTEMPTS: int = 1
const PHANTOM_ICE_CREAM_ID: String = "phantom_ice_cream"

var player = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(player_node) -> void:
	player = player_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func interact_with_shelf(shelf: Shelf) -> void:
	if shelf.has_meta("is_carried_storage_object") and bool(shelf.get_meta("is_carried_storage_object")):
		player._show_notification("Press Q to place the shelf first.", 0.8)
		return

	if PlayerShelfInteraction.is_story_locked_ghost_shelf(player.get_tree(), shelf):
		player._show_notification("Unable to pick up the shelf.", 0.8)
		return

	if not is_shelf_installed_in_store(shelf):
		if try_pickup_shelf(shelf):
			return

		player._show_notification("Press E to pick up this shelf.", 0.8)
		return

	if try_pickup_shelf(shelf):
		return

	player._show_notification("Press Q to stock this shelf.", 0.8)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func try_put() -> void:
	if player._is_action_locked():
		return

	if try_drop_carried_object():
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var shelf := get_best_shelf_target()

	if shelf == null:
		player._show_notification("No place target in reach.", 0.5)
		return

	if not is_shelf_installed_in_store(shelf):
		if PlayerShelfInteraction.is_story_locked_ghost_shelf(player.get_tree(), shelf):
			player._show_notification("Unable to pick up the shelf.", 0.8)
		else:
			player._show_notification("Press E to pick up this shelf first.", 0.8)
		return

	put_item_on_shelf(shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func put_item_on_shelf(shelf: Shelf) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var inventory_items: Dictionary = Inventory.get_all()

	if inventory_items.is_empty():
		player._show_notification("No item to put.", 0.6)
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item_id: String = get_item_to_place(inventory_items, shelf)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item: ItemData = ItemDatabase.get_item(item_id)

	if item == null:
		player._show_notification("That item cannot be stocked yet.", 0.8)
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_best_shelf_target() -> Shelf:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var areas: Array[Area2D] = player.interaction_area.get_overlapping_areas()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_shelf: Shelf = null
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var best_distance: float = INF

	for area in areas:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var parent := area.get_parent()

		if not parent is Shelf:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var distance: float = player.global_position.distance_squared_to(area.global_position)

		if distance < best_distance:
			best_shelf = parent as Shelf
			best_distance = distance

	return best_shelf


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func take_item_from_shelf(shelf: Shelf) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item_id: String = shelf.remove_first_item()

	if item_id == "":
		player._show_notification("Shelf is empty.", 0.5)
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item: ItemData = ItemDatabase.get_item(item_id)

	if item != null:
		player._show_notification("Took %s" % item.display_name, 0.5)
	else:
		player._show_notification("Took %s" % item_id, 0.5)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func handle_wrong_shelf_attempt(
	item_id: String,
	item: ItemData,
	shelf: Shelf
) -> void:
	if (
		item_id == PHANTOM_ICE_CREAM_ID
		and shelf.shelf_type == ItemData.ShelfType.HUMAN
	):
		var store: Node = player.get_tree().get_first_node_in_group("store")
		if (
			store != null
			and store.has_method("_should_prioritize_phantom_for_human_shelf")
			and bool(store.call("_should_prioritize_phantom_for_human_shelf"))
			and store.has_method("_on_phantom_human_shelf_attempted")
		):
			await store.call("_on_phantom_human_shelf_attempted")
			return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var attempt_key: String = get_wrong_shelf_key(item_id, shelf)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var attempts: int = int(player._wrong_shelf_attempts.get(attempt_key, 0))

	if attempts >= MAX_WRONG_ATTEMPTS:
		return

	attempts += 1
	player._wrong_shelf_attempts[attempt_key] = attempts

	if attempts >= MAX_WRONG_ATTEMPTS:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var messages: Array[String] = [
			"%s does not fit on this shelf." % item.display_name,
			"Try the %s shelf." % get_shelf_type_label(item.shelf_type)
		]
		await player._show_notification_sequence(messages)
	else:
		player._show_notification(
			"The item fell off the shelf... (%d/%d)" %
			[attempts, MAX_WRONG_ATTEMPTS]
		)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_shelf_full(shelf: Shelf) -> bool:
	for slot_index in shelf.max_slots:
		if shelf.get_slot_content(slot_index) == "":
			return false

	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_type_label(shelf_type: ItemData.ShelfType) -> String:
	match shelf_type:
		ItemData.ShelfType.HUMAN:
			return "human"
		ItemData.ShelfType.GHOST:
			return "ghost"

	return "matching"


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_item_to_place(inventory_items: Dictionary, shelf: Shelf) -> String:
	if shelf.shelf_type == ItemData.ShelfType.GHOST and inventory_items.has(PHANTOM_ICE_CREAM_ID):
		return PHANTOM_ICE_CREAM_ID

	if shelf.shelf_type == ItemData.ShelfType.HUMAN and inventory_items.has(PHANTOM_ICE_CREAM_ID):
		var store: Node = player.get_tree().get_first_node_in_group("store")
		if (
			store != null
			and store.has_method("_should_prioritize_phantom_for_human_shelf")
			and bool(store.call("_should_prioritize_phantom_for_human_shelf"))
		):
			return PHANTOM_ICE_CREAM_ID

	return str(inventory_items.keys()[0])


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_wrong_shelf_key(item_id: String, shelf: Shelf) -> String:
	return PlayerShelfInteraction.get_wrong_shelf_key(item_id, shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_shelf_installed_in_store(shelf: Shelf) -> bool:
	return PlayerShelfInteraction.is_shelf_installed_in_store(shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_carried_shelf() -> Shelf:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var carried_object := get_carried_object()

	return carried_object as Shelf if carried_object is Shelf else null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_carried_object() -> Node2D:
	for child in player.get_children():
		if child is Node2D and child.has_meta("is_carried_storage_object"):
			if bool(child.get_meta("is_carried_storage_object")):
				return child as Node2D

	return null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func try_pickup_shelf(shelf: Shelf) -> bool:
	for group_name in ["store", "storage"]:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var location: Node = player.get_tree().get_first_node_in_group(group_name)

		if location != null and location.has_method("request_pickup_shelf"):
			if bool(location.call("request_pickup_shelf", shelf)):
				return true

	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func try_drop_carried_object() -> bool:
	for group_name in ["store", "storage"]:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var location: Node = player.get_tree().get_first_node_in_group(group_name)

		if location != null and location.has_method("request_drop_carried_shelf"):
			if bool(location.call("request_drop_carried_shelf")):
				return true

		if location != null and location.has_method("request_drop_carried_object"):
			if bool(location.call("request_drop_carried_object")):
				return true

	return false
