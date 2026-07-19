extends "res://scripts/npc/runtime/NPCTargetArrivalRouteController.gd"


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
		origin_shelf is Shelf
		and is_instance_valid(origin_shelf)
		and route_provider.has_method("get_npc_exit_route_from_shelf")
	):
		var shelf_started_usec := Time.get_ticks_usec()
		var shelf_exit_route := call_store_route(
			route_provider,
			&"get_npc_exit_route_from_shelf",
			[origin_shelf, npc.global_position]
		)
		var shelf_elapsed_msec := float(
			Time.get_ticks_usec() - shelf_started_usec
		) / 1000.0
		_trace_exit_route_choice(
			"out_of_stock_shelf_exit_direct",
			shelf_exit_route,
			shelf_elapsed_msec
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
		var solo_started_usec := Time.get_ticks_usec()
		var solo_exit_route := call_store_route(
			route_provider,
			&"get_npc_single_customer_exit_route",
			[npc.global_position]
		)
		var solo_elapsed_msec := float(
			Time.get_ticks_usec() - solo_started_usec
		) / 1000.0
		_trace_exit_route_choice(
			"solo_checkout_exit_direct",
			solo_exit_route,
			solo_elapsed_msec
		)

		if not solo_exit_route.is_empty():
			return solo_exit_route

	return super.get_store_route_for_current_state(destination)


func _get_nested_route_provider(store: Node) -> Node:
	if store == null:
		return null

	var route_provider_variant: Variant = store.get("npc_routes")
	if not (route_provider_variant is Node):
		return null

	var route_provider := route_provider_variant as Node
	if not is_instance_valid(route_provider):
		return null

	return route_provider
