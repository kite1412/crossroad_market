extends "res://scripts/npc/runtime/NPCShoppingFlow.gd"

const PATH_REFRESH_COOLDOWN_MSEC: int = 500

@warning_ignore("unused_private_class_variable")
var _path_refresh_after_msec: Dictionary = {}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func choose_available_item_to_buy() -> void:
	if npc.npc_data == null:
		return

	# Story customers keep their scripted shopping list and favorite behavior.
	# Generic customers choose from stock that is physically available and
	# reachable when they enter the store.
	if npc.npc_data.npc_category != NPCData.NPCCategory.GENERIC:
		super.choose_available_item_to_buy()
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var available_item_ids := _get_available_generic_item_ids()
	if available_item_ids.is_empty():
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var selected_index := randi_range(0, available_item_ids.size() - 1)
	set_requested_item(available_item_ids[selected_index])


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
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var available_item_ids: Array[String] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var target_shelf_type := ItemData.ShelfType.HUMAN

	if npc.npc_data.visit_phase == NPCData.VisitPhase.NIGHT:
		target_shelf_type = ItemData.ShelfType.GHOST

	for shelf_node in npc.get_tree().get_nodes_in_group("shelves"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var shelf := shelf_node as Shelf

		if shelf == null or not is_instance_valid(shelf):
			continue
		if shelf.shelf_type != target_shelf_type:
			continue
		if (
			shelf.has_meta("is_carried_storage_object")
			and bool(shelf.get_meta("is_carried_storage_object"))
		):
			continue
		if not _ensure_shelf_path_ready(shelf):
			continue

		for slot_index in shelf.max_slots:
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var item_id: String = shelf.get_slot_content(slot_index)
			if item_id == "" or item_id in available_item_ids:
				continue

			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var item: ItemData = ItemDatabase.get_item(item_id)
			if item == null or item.shelf_type != target_shelf_type:
				continue

			available_item_ids.append(item_id)

	return available_item_ids


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ensure_shelf_path_ready(shelf: Shelf) -> bool:
	if shelf == null or not is_instance_valid(shelf):
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var shelf_id := shelf.get_instance_id()

	if bool(shelf.get_meta("npc_path_ready", false)):
		_path_refresh_after_msec.erase(shelf_id)
		return get_shelf_visit_position(shelf).is_finite()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var now_msec := Time.get_ticks_msec()
	if now_msec < int(_path_refresh_after_msec.get(shelf_id, 0)):
		return false

	_path_refresh_after_msec[shelf_id] = now_msec + PATH_REFRESH_COOLDOWN_MSEC

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store: Node = npc._get_store_route_provider()
	if store == null or not store.has_method("_get_store_path_graph"):
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var graph_variant: Variant = store.call("_get_store_path_graph")
	if not (graph_variant is StorePathGraph):
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var graph := graph_variant as StorePathGraph
	graph.store_shelf_access_metadata(shelf, shelf.global_position)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var path_ready := (
		bool(shelf.get_meta("npc_path_ready", false))
		and get_shelf_visit_position(shelf).is_finite()
	)

	if path_ready:
		_path_refresh_after_msec.erase(shelf_id)

	return path_ready
