class_name StoreNpcRoutes
extends Node

const STORE_ENTRY_FALLBACK_POSITION := Vector2(240, 204)

var store: Node = null


func setup(store_node: Node) -> void:
	store = store_node


func get_npc_entry_route_to_shelf(shelf_position: Vector2, from_position: Vector2 = Vector2.INF) -> Array[Vector2]:
	return get_store_path_graph().get_entry_route_to_shelf(shelf_position, from_position)


func get_npc_shelf_access_position(shelf: Shelf) -> Vector2:
	return get_store_path_graph().get_shelf_access_position(shelf)


func get_npc_shelf_visit_position(shelf: Shelf, _npc: Node = null) -> Vector2:
	if not has_npc_shelf_access_metadata(shelf):
		return Vector2.INF

	return get_npc_shelf_access_position(shelf)


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

func get_npc_shelf_wait_position(index: int = 0) -> Vector2:
	return get_store_path_graph().get_shelf_wait_position(index)


func get_npc_exit_route_from_cashier(from_position: Vector2) -> Array[Vector2]:
	var exit_position: Vector2 = get_marker_position_or(store.npc_exit_marker, STORE_ENTRY_FALLBACK_POSITION)
	return get_store_path_graph().get_cashier_exit_route(from_position, exit_position)


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
