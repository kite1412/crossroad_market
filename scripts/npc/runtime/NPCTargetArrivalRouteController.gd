extends "res://scripts/npc/runtime/NPCRouteController.gd"


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
