extends "res://scripts/npc/runtime/NPCRouteController.gd"

const SOLO_CHECKOUT_EXIT_META: StringName = &"solo_checkout_exit"
const EXIT_ORIGIN_SHELF_META: StringName = &"exit_origin_shelf"


func get_store_route_for_current_state(
	destination: Vector2
) -> Array[Vector2]:
	if npc.current_state == NPC.State.EXIT:
		var store := get_store_route_provider()

		if store != null:
			var origin_shelf: Variant = null
			if npc.has_meta(EXIT_ORIGIN_SHELF_META):
				origin_shelf = npc.get_meta(EXIT_ORIGIN_SHELF_META)

			if (
				origin_shelf is Shelf
				and is_instance_valid(origin_shelf)
				and store.has_method("get_npc_exit_route_from_shelf")
			):
				var shelf_exit_route := call_store_route(
					store,
					&"get_npc_exit_route_from_shelf",
					[origin_shelf, npc.global_position]
				)

				if not shelf_exit_route.is_empty():
					return shelf_exit_route

			var use_solo_checkout_exit := (
				npc._exit_after_checkout
				and npc.has_meta(SOLO_CHECKOUT_EXIT_META)
				and bool(npc.get_meta(SOLO_CHECKOUT_EXIT_META))
			)

			if (
				use_solo_checkout_exit
				and store.has_method(
					"get_npc_single_customer_exit_route"
				)
			):
				var solo_exit_route := call_store_route(
					store,
					&"get_npc_single_customer_exit_route",
					[npc.global_position]
				)

				if not solo_exit_route.is_empty():
					return solo_exit_route

	return super.get_store_route_for_current_state(destination)


func move_to(target: Vector2, arrival_threshold: float = -1.0) -> bool:
	var threshold: float = (
		npc.ARRIVAL_THRESHOLD
		if arrival_threshold < 0.0
		else arrival_threshold
	)

	if should_rebuild_movement_route(target):
		npc._movement_route = build_movement_route(target)
		npc._movement_route_destination = target

	_trim_arrived_route_points(threshold)

	# Route exhaustion is not the same as destination arrival. A generated
	# store route can end at an approach marker before the real interaction
	# target. Only report success when the NPC itself is within the requested
	# threshold of the real target position.
	if npc._movement_route.is_empty():
		if npc.global_position.distance_to(target) <= threshold:
			npc.velocity = Vector2.ZERO
			npc.move_and_slide()
			return true

		if uses_store_navigation_state():
			npc.velocity = Vector2.ZERO
			npc.move_and_slide()
			return false

		return NPCMovement.move_to(
			npc,
			target,
			npc.SPEED,
			threshold
		)

	var next_target: Vector2 = npc._movement_route[0]

	if not NPCMovement.move_to(
		npc,
		next_target,
		npc.SPEED,
		threshold
	):
		return false

	npc._movement_route.remove_at(0)
	_trim_arrived_route_points(threshold)

	if not npc._movement_route.is_empty():
		return false

	return npc.global_position.distance_to(target) <= threshold
