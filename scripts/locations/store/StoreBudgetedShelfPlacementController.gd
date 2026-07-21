extends "res://scripts/locations/store/StoreShelfPlacementCollisionController.gd"

## Placement integration for budgeted shelf access metadata.
##
## The inherited drop lifecycle and restrictions remain unchanged. Only access
## metadata construction is redirected to StoreNpcRoutes so it runs through the
## per-frame coordinator instead of blocking the drop or warmup frame.


func store_shelf_access_metadata(
	object: Node2D,
	_drop_position: Vector2
) -> void:
	var shelf := object as Shelf
	if shelf == null or store == null or store.npc_routes == null:
		return
	if store.npc_routes.has_method("request_npc_shelf_access_state"):
		store.npc_routes.call(
			"request_npc_shelf_access_state",
			shelf,
			true
		)


func defer_shelf_access_warmup(
	warmup_token: int,
	delay: float
) -> void:
	await store.get_tree().process_frame
	if delay > 0.0:
		await store.get_tree().create_timer(delay).timeout

	if warmup_token != store._shelf_access_warmup_token:
		return
	if not can_run_shelf_access_warmup():
		schedule_shelf_access_warmup(SHELF_ACCESS_WARMUP_DELAY)
		return
	if store.npc_routes == null:
		return

	for shelf_node in store.get_tree().get_nodes_in_group("shelves"):
		if warmup_token != store._shelf_access_warmup_token:
			return
		var shelf := shelf_node as Shelf
		if shelf == null or not is_instance_valid(shelf):
			continue
		if store.npc_routes.has_method("request_npc_shelf_access_state"):
			store.npc_routes.call(
				"request_npc_shelf_access_state",
				shelf,
				false
			)
		await store.get_tree().process_frame


func clear_shelf_access_metadata(object: Node2D) -> void:
	var shelf := object as Shelf
	if (
		shelf != null
		and store != null
		and store.npc_routes != null
		and store.npc_routes.has_method("invalidate_npc_shelf_access")
	):
		store.npc_routes.call("invalidate_npc_shelf_access", shelf)
	elif object != null:
		var graph: StorePathGraph = store._get_store_path_graph()
		graph.clear_shelf_access_metadata(object)

	if object != null and object.has_meta(PENDING_ACCESS_UPDATE_META):
		object.remove_meta(PENDING_ACCESS_UPDATE_META)
