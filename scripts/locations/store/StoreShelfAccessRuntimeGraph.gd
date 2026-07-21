class_name StoreShelfAccessRuntimeGraph
extends "res://scripts/locations/store/StoreRuntimePathGraph.gd"

## Strict compatibility graph used by StoreNpcRoutes.
##
## Metadata construction is owned by StoreShelfAccessCoordinator. Read methods
## never start a synchronous access search, which keeps NPC state and movement
## requests free from hidden pathfinding work.


func get_shelf_access_position(shelf: Shelf) -> Vector2:
	if (
		shelf == null
		or not is_instance_valid(shelf)
		or not has_cached_shelf_access_metadata(shelf)
	):
		return Vector2.INF

	var stored_access: Variant = shelf.get_meta(
		ACCESS_META,
		Vector2.INF
	)
	if stored_access is Vector2:
		return stored_access as Vector2
	return Vector2.INF


func get_shelf_access_graph_node(shelf: Shelf) -> StringName:
	if (
		shelf == null
		or not is_instance_valid(shelf)
		or not has_cached_shelf_access_metadata(shelf)
	):
		return StringName()

	var stored_graph_node: Variant = shelf.get_meta(
		ACCESS_NODE_META,
		StringName()
	)
	if stored_graph_node is StringName:
		return stored_graph_node as StringName
	if stored_graph_node is String:
		return StringName(stored_graph_node)
	return StringName()


func get_route_to_shelf_access(
	shelf: Shelf,
	from_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Array[Vector2]:
	if (
		shelf == null
		or not is_instance_valid(shelf)
		or not from_position.is_finite()
		or not has_cached_shelf_access_metadata(shelf)
	):
		return []
	return super.get_route_to_shelf_access(
		shelf,
		from_position,
		npc_node
	)
