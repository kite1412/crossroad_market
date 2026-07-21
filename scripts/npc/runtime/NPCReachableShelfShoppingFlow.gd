extends "res://scripts/npc/runtime/NPCShoppingFlow.gd"


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func choose_available_item_to_buy() -> void:
	if npc.npc_data == null:
		return

	# Story customers keep their scripted shopping list and favorite behavior.
	# Generic customers choose from stock that is physically available and whose
	# shelf access metadata is already READY.
	if npc.npc_data.npc_category != NPCData.NPCCategory.GENERIC:
		super.choose_available_item_to_buy()
		return

	var available_item_ids := _get_available_generic_item_ids()
	if available_item_ids.is_empty():
		return

	var selected_index := randi_range(0, available_item_ids.size() - 1)
	set_requested_item(available_item_ids[selected_index])


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_matching_shelf_candidates() -> Array[Shelf]:
	var stocked_shelves: Array[Shelf] = []
	var fallback_shelves: Array[Shelf] = []
	var item: ItemData = ItemDatabase.get_item(npc.item_to_buy)

	if item == null:
		return []

	for shelf_node in npc.get_tree().get_nodes_in_group("shelves"):
		var shelf := shelf_node as Shelf
		if shelf == null or not is_instance_valid(shelf):
			continue
		if shelf.shelf_type != item.shelf_type:
			continue
		if not _ensure_shelf_path_ready(shelf):
			continue

		if shelf.has_item(npc.item_to_buy):
			stocked_shelves.append(shelf)
		else:
			fallback_shelves.append(shelf)

	stocked_shelves.append_array(fallback_shelves)
	return stocked_shelves


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_available_generic_item_ids() -> Array[String]:
	var available_item_ids: Array[String] = []
	var target_shelf_type := ItemData.ShelfType.HUMAN

	if npc.npc_data.visit_phase == NPCData.VisitPhase.NIGHT:
		target_shelf_type = ItemData.ShelfType.GHOST

	for shelf_node in npc.get_tree().get_nodes_in_group("shelves"):
		var shelf := shelf_node as Shelf
		if shelf == null or not is_instance_valid(shelf):
			continue
		if shelf.shelf_type != target_shelf_type:
			continue
		if bool(shelf.get_meta("is_carried_storage_object", false)):
			continue
		if not _ensure_shelf_path_ready(shelf):
			continue

		for slot_index in shelf.max_slots:
			var item_id: String = shelf.get_slot_content(slot_index)
			if item_id == "" or item_id in available_item_ids:
				continue

			var item: ItemData = ItemDatabase.get_item(item_id)
			if item == null or item.shelf_type != target_shelf_type:
				continue
			available_item_ids.append(item_id)

	return available_item_ids


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ensure_shelf_path_ready(shelf: Shelf) -> bool:
	if shelf == null or not is_instance_valid(shelf):
		return false

	var store: Node = npc._get_store_route_provider()
	var route_provider := _get_nested_route_provider(store)
	if (
		route_provider == null
		or not route_provider.has_method("request_npc_shelf_access_state")
	):
		return (
			bool(shelf.get_meta("npc_path_ready", false))
			and get_shelf_visit_position(shelf).is_finite()
		)

	var state := StringName(
		route_provider.call(
			"request_npc_shelf_access_state",
			shelf,
			false
		)
	)
	if state != StoreShelfAccessCoordinator.READY:
		return false
	return get_shelf_visit_position(shelf).is_finite()


func _get_nested_route_provider(store: Node) -> Node:
	if store == null:
		return null
	var route_provider_variant: Variant = store.get("npc_routes")
	if not is_instance_valid(route_provider_variant):
		return null
	if not (route_provider_variant is Node):
		return null
	return route_provider_variant as Node
