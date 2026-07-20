extends "res://scripts/npc/runtime/NPCTargetArrivalRouteController.gd"


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_store_route_for_current_state(
	destination: Vector2
) -> Array[Vector2]:
	if npc.current_state != NPC.State.EXIT:
		return super.get_store_route_for_current_state(destination)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store := get_store_route_provider()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route_provider := _get_nested_route_provider(store)

	if route_provider == null:
		return super.get_store_route_for_current_state(destination)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var origin_shelf: Variant = null
	if npc.has_meta(EXIT_ORIGIN_SHELF_META):
		origin_shelf = npc.get_meta(EXIT_ORIGIN_SHELF_META)

	if (
		origin_shelf is Shelf
		and is_instance_valid(origin_shelf)
		and route_provider.has_method("get_npc_exit_route_from_shelf")
	):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var shelf_exit_route := call_store_route(
			route_provider,
			&"get_npc_exit_route_from_shelf",
			[origin_shelf, npc.global_position]
		)

		if not shelf_exit_route.is_empty():
			return shelf_exit_route

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
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
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var solo_exit_route := call_store_route(
			route_provider,
			&"get_npc_single_customer_exit_route",
			[npc.global_position]
		)

		if not solo_exit_route.is_empty():
			return solo_exit_route

	return super.get_store_route_for_current_state(destination)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_nested_route_provider(store: Node) -> Node:
	if store == null:
		return null

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route_provider_variant: Variant = store.get("npc_routes")
	if not (route_provider_variant is Node):
		return null

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route_provider := route_provider_variant as Node
	if not is_instance_valid(route_provider):
		return null

	return route_provider
