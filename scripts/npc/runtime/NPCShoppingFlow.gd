class_name NPCShoppingFlow
extends RefCounted

const DEBUG_SHELF_FLOW: bool = true

var npc = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(npc_node) -> void:
	npc = npc_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func choose_item_to_buy() -> void:
	if not npc.shopping_list.is_empty():
		npc.item_to_buy = npc.shopping_list[0]
		return

	if npc.npc_data == null or npc.npc_data.favorite_items.is_empty():
		npc.item_to_buy = ""
		return

	npc.item_to_buy = npc.npc_data.favorite_items[randi() % npc.npc_data.favorite_items.size()]


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func choose_available_item_to_buy() -> void:
	if npc.npc_data == null:
		return

	for shopping_item_id in npc.shopping_list:
		if find_shelf_with_item(shopping_item_id) != null:
			set_requested_item(shopping_item_id)
			return

	for favorite_item_id in npc.npc_data.favorite_items:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item_id := str(favorite_item_id)

		if find_shelf_with_item(item_id) != null:
			set_requested_item(item_id)
			return

	if can_substitute_available_stock():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var fallback_item_id := find_available_stock_substitute()

		if fallback_item_id != "":
			set_requested_item(fallback_item_id)
			return

	if npc.item_to_buy == "":
		choose_item_to_buy()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_alternative_item() -> String:
	return NPCShoppingBehavior.find_alternative_item(npc.get_tree(), npc.item_to_buy, npc.item_to_buy_original)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_requested_item(item_id: String) -> void:
	npc.item_to_buy = item_id
	npc.item_to_buy_original = item_id
	npc.shopping_list.clear()
	npc.shopping_list.append(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func can_substitute_available_stock() -> bool:
	return (
		npc.npc_data != null
		and npc.npc_data.npc_category == NPCData.NPCCategory.GENERIC
		and npc.npc_data.visit_phase != NPCData.VisitPhase.NIGHT
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_available_stock_substitute() -> String:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var shelf_type := ItemData.ShelfType.HUMAN
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var requested_items := get_requested_items()

	for requested_item_id in requested_items:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item := ItemDatabase.get_item(requested_item_id)

		if item != null:
			shelf_type = item.shelf_type
			break

	return NPCShoppingBehavior.find_first_stocked_item_for_shelf_type(npc.get_tree(), shelf_type)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func return_item_to_shelf() -> void:
	if not npc._cart_items.is_empty():
		return_cart_items_to_shelf()
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item: ItemData = ItemDatabase.get_item(npc.item_to_buy)

	if item == null:
		return

	for shelf in npc.get_tree().get_nodes_in_group("shelves"):
		if shelf is Shelf and shelf.shelf_type == item.shelf_type:
			Inventory.add_item(npc.item_to_buy)
			shelf.place_item(npc.item_to_buy)
			return


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_matching_shelf() -> Shelf:
	return NPCShoppingBehavior.find_matching_shelf(npc.get_tree(), npc.item_to_buy)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_reachable_matching_shelf() -> Shelf:
	for shelf in get_matching_shelf_candidates():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var visit_position: Vector2 = get_shelf_visit_position(shelf)
		pass

		if visit_position.is_finite():
			pass
			return shelf

	return null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_matching_shelf_candidates() -> Array[Shelf]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var stocked_shelves: Array[Shelf] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var fallback_shelves: Array[Shelf] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var item: ItemData = ItemDatabase.get_item(npc.item_to_buy)

	if item == null:
		return []

	for shelf_node in npc.get_tree().get_nodes_in_group("shelves"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var shelf := shelf_node as Shelf

		if shelf == null:
			continue

		if shelf.shelf_type != item.shelf_type:
			continue

		if not shelf.has_meta("npc_path_ready") or not bool(shelf.get_meta("npc_path_ready")):
			continue

		if shelf.has_item(npc.item_to_buy):
			stocked_shelves.append(shelf)
		else:
			fallback_shelves.append(shelf)

	stocked_shelves.append_array(fallback_shelves)
	return stocked_shelves


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_shelf_with_item(item_id: String) -> Shelf:
	return NPCShoppingBehavior.find_shelf_with_item(npc.get_tree(), item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_visit_position(shelf: Shelf) -> Vector2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store: Node = npc._get_store_route_provider()

	if store != null and store.has_method("get_npc_shelf_visit_position"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var result: Variant = store.call("get_npc_shelf_visit_position", shelf, npc)

		if result is Vector2:
			return result as Vector2

	return NPCShoppingBehavior.get_shelf_visit_position(shelf, npc.SHELF_VISIT_OFFSET)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_debug_npc_label() -> String:
	if npc != null and npc.npc_data != null and npc.npc_data.npc_id != "":
		return npc.npc_data.npc_id

	return npc.name if npc != null else "<null>"


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func refresh_shelf_visit_target() -> bool:
	if npc._target_shelf == null or not is_instance_valid(npc._target_shelf):
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var refreshed_position := get_shelf_visit_position(npc._target_shelf)

	if not refreshed_position.is_finite():
		return false

	if refreshed_position.distance_to(npc.target_position) <= 2.0:
		return false

	npc.target_position = refreshed_position
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_any_requested_item_available() -> bool:
	for requested_item_id in get_requested_items():
		if find_shelf_with_item(requested_item_id) != null:
			return true

	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func take_requested_items_from_shelves() -> bool:
	npc._cart_items.clear()

	for requested_item_id in get_requested_items():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var shelf: Shelf = npc._target_shelf if npc._target_shelf is Shelf else null

		if shelf != null and shelf.take_item_for_npc(requested_item_id):
			npc._cart_items.append(requested_item_id)

	if not npc._cart_items.is_empty():
		npc.item_to_buy = npc._cart_items[0]
		# The checkout order is created at the exact successful shelf pickup,
		# before the take-item pause or route-to-queue travel can reorder NPCs.
		NPCQueueSystem.mark_item_taken(npc)
		return true

	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_requested_items() -> Array[String]:
	return NPCShoppingBehavior.get_requested_items(npc.shopping_list, npc.item_to_buy)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func return_cart_items_to_shelf() -> void:
	for cart_item_id in npc._cart_items:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item: ItemData = ItemDatabase.get_item(cart_item_id)

		if item == null:
			continue

		for shelf in npc.get_tree().get_nodes_in_group("shelves"):
			if shelf is Shelf and shelf.shelf_type == item.shelf_type:
				shelf.stock_item_direct(cart_item_id)
				break

	npc._cart_items.clear()
