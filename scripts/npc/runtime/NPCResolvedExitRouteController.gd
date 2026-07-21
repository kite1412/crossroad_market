extends "res://scripts/npc/runtime/NPCTargetArrivalRouteController.gd"


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_store_route_for_current_state(
	destination: Vector2
) -> Array[Vector2]:
	if npc.current_state != NPC.State.EXIT:
		return super.get_store_route_for_current_state(destination)

	var store := get_store_route_provider()
	var route_provider := _get_nested_route_provider(store)
	if route_provider == null:
		return super.get_store_route_for_current_state(destination)

	var origin_shelf: Variant = null
	if npc.has_meta(EXIT_ORIGIN_SHELF_META):
		origin_shelf = npc.get_meta(EXIT_ORIGIN_SHELF_META)

	if (
		is_instance_valid(origin_shelf)
		and origin_shelf is Shelf
		and route_provider.has_method("get_npc_exit_route_from_shelf")
	):
		var shelf_exit_route := call_store_route(
			route_provider,
			&"get_npc_exit_route_from_shelf",
			[origin_shelf, npc.global_position]
		)
		if not shelf_exit_route.is_empty():
			return shelf_exit_route

	var use_solo_checkout_exit: bool = (
		npc._exit_after_checkout
		and npc.has_meta(SOLO_CHECKOUT_EXIT_META)
		and bool(npc.get_meta(SOLO_CHECKOUT_EXIT_META))
	)
	if (
		use_solo_checkout_exit
		and route_provider.has_method(
			"get_npc_single_customer_exit_route"
		)
	):
		var solo_exit_route := call_store_route(
			route_provider,
			&"get_npc_single_customer_exit_route",
			[npc.global_position]
		)
		if not solo_exit_route.is_empty():
			return solo_exit_route

	return super.get_store_route_for_current_state(destination)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_egress_queue_route(
	store: Node,
	queue_index: int,
	destination: Vector2
) -> Array[Vector2]:
	# Queue membership is already resolved here. Prefer a route that knows the
	# source shelf, assigned queue slot, and moving NPC collider.
	var route_provider := _get_nested_route_provider(store)
	if (
		route_provider != null
		and npc._queue_entry_shelf != null
		and is_instance_valid(npc._queue_entry_shelf)
	):
		var shelf_queue_route := _call_shelf_queue_graph_route(
			route_provider,
			queue_index
		)
		if not shelf_queue_route.is_empty():
			return _finish_queue_route(
				shelf_queue_route,
				destination
			)

	# Generic queue routing remains a safe fallback after the NPC has already
	# moved clear of the shelf. It still targets the actual assigned slot.
	if store != null and store.has_method("get_npc_route_to_queue_target_from"):
		var queue_route := call_store_route(
			store,
			&"get_npc_route_to_queue_target_from",
			[npc.global_position, queue_index]
		)
		if not queue_route.is_empty():
			return _finish_queue_route(queue_route, destination)

	# The old shelf→cashier composition is retained only for the front customer;
	# using it for a back slot would recreate Front→Back movement.
	if queue_index <= 0:
		return super.get_shelf_egress_queue_route(
			store,
			queue_index,
			destination
		)
	return []


func _call_shelf_queue_graph_route(
	route_provider: Node,
	queue_index: int
) -> Array[Vector2]:
	if not route_provider.has_method("get_store_path_graph"):
		return []

	var graph_variant: Variant = route_provider.call(
		"get_store_path_graph"
	)
	if not is_instance_valid(graph_variant):
		return []
	if not graph_variant.has_method(
		"get_route_from_shelf_to_queue_target"
	):
		return []

	var route_variant: Variant = graph_variant.call(
		"get_route_from_shelf_to_queue_target",
		npc._queue_entry_shelf,
		npc.global_position,
		queue_index,
		npc
	)
	return _variant_to_route(route_variant)


func _variant_to_route(route_variant: Variant) -> Array[Vector2]:
	var route: Array[Vector2] = []
	if not (route_variant is Array):
		return route
	for point_variant in route_variant:
		if point_variant is Vector2:
			route.append(point_variant as Vector2)
	return dedupe_route_points(route)


func _finish_queue_route(
	route: Array[Vector2],
	destination: Vector2
) -> Array[Vector2]:
	var result := route.duplicate()
	if (
		destination.is_finite()
		and (
			result.is_empty()
			or result.back().distance_to(destination) > npc.ARRIVAL_THRESHOLD
		)
	):
		result.append(destination)
	return dedupe_route_points(result)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_nested_route_provider(store: Node) -> Node:
	if store == null:
		return null

	var route_provider_variant: Variant = store.get("npc_routes")
	if not is_instance_valid(route_provider_variant):
		return null
	if not (route_provider_variant is Node):
		return null

	return route_provider_variant as Node
