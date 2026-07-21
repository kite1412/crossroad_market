class_name NPCLayeredNavigationRouteController
extends "res://scripts/npc/runtime/NPCResolvedExitRouteController.gd"


func move_to(
	target: Vector2,
	arrival_threshold: float = -1.0
) -> bool:
	var threshold: float = (
		npc.ARRIVAL_THRESHOLD
		if arrival_threshold < 0.0
		else arrival_threshold
	)

	if should_rebuild_movement_route(target):
		npc._movement_route = build_movement_route(target)
		npc._movement_route_destination = target

	_trim_arrived_route_points(threshold)
	if npc._movement_route.is_empty():
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
	var adjustment := _get_local_avoidance_adjustment(next_target)
	if bool(adjustment.get("wait", false)):
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		return false

	var movement_target := next_target
	var adjusted_variant: Variant = adjustment.get("target", next_target)
	if adjusted_variant is Vector2:
		movement_target = adjusted_variant as Vector2

	var using_sidestep := movement_target.distance_to(next_target) > 1.0
	var reached_movement_target := NPCMovement.move_to(
		npc,
		movement_target,
		npc.SPEED,
		threshold
	)
	if not reached_movement_target:
		return false

	# A temporary sidestep is not a completed route waypoint. Keep the original
	# waypoint so the NPC converges back onto the planned path after passing the
	# dynamic blocker.
	if using_sidestep:
		return false

	npc._movement_route.remove_at(0)
	_trim_arrived_route_points(threshold)
	return npc._movement_route.is_empty()


func get_shelf_egress_queue_route(
	store: Node,
	queue_index: int,
	destination: Vector2
) -> Array[Vector2]:
	var route_provider := _get_nested_route_provider(store)
	if (
		route_provider != null
		and npc._queue_entry_shelf != null
		and is_instance_valid(npc._queue_entry_shelf)
		and route_provider.has_method(
			"get_npc_route_from_shelf_to_queue_target"
		)
	):
		var layered_route := call_store_route(
			route_provider,
			&"get_npc_route_from_shelf_to_queue_target",
			[
				npc._queue_entry_shelf,
				npc.global_position,
				queue_index,
				npc
			]
		)
		if not layered_route.is_empty():
			return _finish_queue_route(layered_route, destination)
	return super.get_shelf_egress_queue_route(
		store,
		queue_index,
		destination
	)


func _get_local_avoidance_adjustment(
	desired_target: Vector2
) -> Dictionary:
	var store := get_store_route_provider()
	var route_provider := _get_nested_route_provider(store)
	if (
		route_provider == null
		or not route_provider.has_method(
			"get_npc_local_avoidance_adjustment"
		)
	):
		return {"target": desired_target, "wait": false}

	var result: Variant = route_provider.call(
		"get_npc_local_avoidance_adjustment",
		npc,
		desired_target
	)
	if result is Dictionary:
		return result as Dictionary
	return {"target": desired_target, "wait": false}
