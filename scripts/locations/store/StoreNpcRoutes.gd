class_name StoreNpcRoutes
extends Node

const STORE_ENTRY_FALLBACK_POSITION := Vector2(240, 204)
const PERF_SHELF_DISTANCE_THRESHOLD: float = 48.0
const DEBUG_SHELF_FLOW: bool = true

var store: Node = null


func setup(store_node: Node) -> void:
	store = store_node


func get_npc_entry_route_to_shelf(shelf_position: Vector2, from_position: Vector2 = Vector2.INF) -> Array[Vector2]:
	return get_store_path_graph().get_entry_route_to_shelf(shelf_position, from_position)


func get_npc_shelf_access_position(shelf: Shelf) -> Vector2:
	return get_store_path_graph().get_shelf_access_position(shelf)


func get_npc_shelf_visit_position(shelf: Shelf, _npc: Node = null) -> Vector2:
	var has_metadata := has_npc_shelf_access_metadata(shelf)
	var visit_position := Vector2.INF
	var source := "metadata"

	if not has_metadata:
		source = "missing_metadata"
	else:
		visit_position = get_npc_shelf_access_position(shelf)

	print_shelf_visit_metadata_debug(shelf, _npc, visit_position, source, has_metadata)
	print_shelf_visit_perf_if_needed(shelf, _npc, visit_position, source, has_metadata)
	return visit_position


func has_npc_shelf_access_metadata(shelf: Shelf) -> bool:
	return get_store_path_graph().has_cached_shelf_access_metadata(shelf)


func get_npc_route_to_shelf_access(shelf: Shelf, from_position: Vector2 = Vector2.INF, npc_node: Node = null) -> Array[Vector2]:
	if not has_npc_shelf_access_metadata(shelf):
		return []

	return get_store_path_graph().get_route_to_shelf_access(shelf, from_position, npc_node)


func get_npc_route_to_cashier_from(from_position: Vector2) -> Array[Vector2]:
	return get_store_path_graph().get_route_to_cashier_from(from_position)


func get_npc_route_to_queue_target_from(from_position: Vector2, queue_index: int) -> Array[Vector2]:
	return get_store_path_graph().get_route_to_queue_target_from(from_position, queue_index)


func get_npc_queue_target(queue_index: int, fallback_position: Vector2) -> Vector2:
	return get_store_path_graph().get_queue_target_position(queue_index, fallback_position)


func get_npc_cashier_target(fallback_position: Vector2) -> Vector2:
	return get_store_path_graph().get_cashier_target_position(fallback_position)


func get_npc_route_from_shelf_to_cashier(shelf: Shelf) -> Array[Vector2]:
	return get_store_path_graph().get_route_from_shelf_to_cashier(shelf)


func get_npc_exit_route_from(from_position: Vector2) -> Array[Vector2]:
	var exit_position: Vector2 = get_marker_position_or(store.npc_exit_marker, STORE_ENTRY_FALLBACK_POSITION)
	return get_store_path_graph().get_exit_route_from(from_position, exit_position)


func get_npc_exit_route_from_cashier() -> Array[Vector2]:
	var fallback_position: Vector2 = get_marker_position_or(store.counter_pos, Vector2(96, 160))
	var from_position: Vector2 = get_marker_position_or(store.npc_queue_marker, fallback_position)
	return get_npc_exit_route_from(from_position)


func get_store_path_graph() -> StorePathGraph:
	if store._store_path_graph == null:
		store._store_path_graph = StorePathGraph.new(store, store.store_path_markers)
	else:
		store._store_path_graph.setup(store, store.store_path_markers)

	store._store_path_graph.set_shelf_access_points(store._get_shelf_placement_grid_positions())
	return store._store_path_graph


func get_marker_position_or(marker: Marker2D, fallback: Vector2) -> Vector2:
	if marker == null:
		return fallback

	return marker.global_position


func print_shelf_visit_perf_if_needed(
	shelf: Shelf,
	npc_node: Node,
	visit_position: Vector2,
	source: String,
	has_metadata: bool
) -> void:
	var shelf_position := shelf.global_position if shelf != null else Vector2.INF
	var distance_to_shelf := shelf_position.distance_to(visit_position) if shelf_position.is_finite() and visit_position.is_finite() else INF

	if source != "fallback_bottom" and distance_to_shelf <= PERF_SHELF_DISTANCE_THRESHOLD:
		return

	print(
		"[DEBUG][PERF_SHELF] stage=visit_position npc=%s item=%s shelf=%s source=%s has_metadata=%s shelf_pos=%s visit_pos=%s distance_to_shelf=%.2f graph_node=%s access_side=%s checkout_source=%s" % [
			_get_perf_npc_label(npc_node),
			_get_perf_npc_item_id(npc_node),
			shelf.name if shelf != null else "<null>",
			source,
			str(has_metadata),
			str(shelf_position),
			str(visit_position),
			distance_to_shelf,
			str(shelf.get_meta(&"npc_access_graph_node") if shelf != null and shelf.has_meta(&"npc_access_graph_node") else ""),
			str(shelf.get_meta(&"npc_access_side") if shelf != null and shelf.has_meta(&"npc_access_side") else ""),
			str(shelf.get_meta(&"npc_access_checkout_source") if shelf != null and shelf.has_meta(&"npc_access_checkout_source") else "")
		]
	)


func print_shelf_visit_metadata_debug(
	shelf: Shelf,
	npc_node: Node,
	visit_position: Vector2,
	source: String,
	has_metadata: bool
) -> void:
	if not DEBUG_SHELF_FLOW:
		return

	var surface_route: Variant = shelf.get_meta(&"npc_access_surface_route") if shelf != null and shelf.has_meta(&"npc_access_surface_route") else []
	var surface_route_size := (surface_route as Array).size() if surface_route is Array else 0
	print(
		"[DEBUG][SHELF_FLOW] stage=visit_metadata npc=%s item=%s shelf=%s source=%s has_metadata=%s shelf_pos=%s visit_pos=%s access_point=%s access_side=%s graph_node=%s surface_route_size=%d checkout_source=%s unreachable=%s" % [
			_get_perf_npc_label(npc_node),
			_get_perf_npc_item_id(npc_node),
			shelf.name if shelf != null else "<null>",
			source,
			str(has_metadata),
			str(shelf.global_position if shelf != null else Vector2.INF),
			str(visit_position),
			str(shelf.get_meta(&"npc_access_point") if shelf != null and shelf.has_meta(&"npc_access_point") else Vector2.INF),
			str(shelf.get_meta(&"npc_access_side") if shelf != null and shelf.has_meta(&"npc_access_side") else ""),
			str(shelf.get_meta(&"npc_access_graph_node") if shelf != null and shelf.has_meta(&"npc_access_graph_node") else ""),
			surface_route_size,
			str(shelf.get_meta(&"npc_access_checkout_source") if shelf != null and shelf.has_meta(&"npc_access_checkout_source") else ""),
			str(not visit_position.is_finite())
		]
	)


func _get_perf_npc_label(npc_node: Node) -> String:
	var npc_object := npc_node as NPC

	if npc_object != null and npc_object.npc_data != null and npc_object.npc_data.npc_id != "":
		return npc_object.npc_data.npc_id

	return npc_node.name if npc_node != null else "<none>"


func _get_perf_npc_item_id(npc_node: Node) -> String:
	var npc_object := npc_node as NPC

	if npc_object == null:
		return ""

	return npc_object.item_to_buy
