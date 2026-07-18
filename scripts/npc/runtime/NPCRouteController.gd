class_name NPCRouteController
extends RefCounted

var npc = null


func setup(npc_node) -> void:
	npc = npc_node


func move_to(target: Vector2) -> bool:
	if should_rebuild_movement_route(target):
		npc._movement_route = build_movement_route(target)
		npc._movement_route_destination = target

	if npc._movement_route.is_empty():
		return NPCMovement.move_to(npc, target, npc.SPEED, npc.ARRIVAL_THRESHOLD)

	var next_target: Vector2 = npc._movement_route[0]

	if not NPCMovement.move_to(npc, next_target, npc.SPEED, npc.ARRIVAL_THRESHOLD):
		return false

	npc._movement_route.remove_at(0)
	return npc._movement_route.is_empty()


func update_stuck_watchdog(delta: float) -> void:
	if not is_movement_state():
		reset_stuck_watchdog()
		return

	if npc._dialog_timer > 0.0 or npc._take_item_pause_timer > 0.0:
		reset_stuck_watchdog()
		return

	if npc.current_state == NPC.State.EXIT and npc.global_position.distance_to(npc.target_position) <= npc.ARRIVAL_THRESHOLD:
		reset_stuck_watchdog()
		return

	if not npc._last_watchdog_position.is_finite():
		npc._last_watchdog_position = npc.global_position
		npc._stuck_watchdog_timer = 0.0
		return

	if npc.global_position.distance_to(npc._last_watchdog_position) > npc.STUCK_MIN_MOVE_DISTANCE:
		npc._last_watchdog_position = npc.global_position
		npc._stuck_watchdog_timer = 0.0
		return

	npc._stuck_watchdog_timer += delta

	if npc._stuck_watchdog_timer < npc.STUCK_WATCHDOG_SECONDS:
		return

	if npc.current_state == NPC.State.WALK_TO_SHELF and npc._refresh_shelf_visit_target():
		reset_stuck_watchdog()
		return

	if npc._stuck_watchdog_rebuilds >= npc.STUCK_WATCHDOG_MAX_REBUILDS:
		print(
			"NPC route watchdog giving up: state=%s pos=%s target=%s route=%s" %
			[str(npc.current_state), str(npc.global_position), str(npc.target_position), str(npc._movement_route)]
		)
		if npc.current_state == NPC.State.EXIT:
			# Use direct orthogonal path as last resort for EXIT
			var fallback := make_orthogonal_route(npc.global_position, NPC.exit_position, true)
			fallback.append(NPC.exit_position)
			npc._movement_route = dedupe_route_points(fallback)
			npc._movement_route_destination = NPC.exit_position
			npc._stuck_watchdog_rebuilds = 0
			return
		npc.target_position = get_exit_position()
		npc._set_state(NPC.State.EXIT)
		return

	print(
		"NPC route watchdog: state=%s pos=%s target=%s route=%s" %
		[str(npc.current_state), str(npc.global_position), str(npc.target_position), str(npc._movement_route)]
	)
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	npc._last_watchdog_position = npc.global_position
	npc._stuck_watchdog_timer = 0.0
	npc._stuck_watchdog_rebuilds += 1


func is_movement_state() -> bool:
	return npc.current_state in [
		NPC.State.WALK_TO_SHELF,
		NPC.State.TAKE_ITEM,
		NPC.State.WAIT_IN_QUEUE,
		NPC.State.EXIT
	]


func reset_stuck_watchdog() -> void:
	npc._last_watchdog_position = Vector2.INF
	npc._stuck_watchdog_timer = 0.0
	npc._stuck_watchdog_rebuilds = 0


func should_rebuild_movement_route(target: Vector2) -> bool:
	if npc._movement_route.is_empty():
		return true

	return not npc._movement_route_destination.is_equal_approx(target)


func build_movement_route(destination: Vector2) -> Array[Vector2]:
	var route := get_store_route_for_current_state(destination)

	if not route.is_empty():
		return append_destination_to_route(route, destination)

	route = []
	var path_position := get_store_path_position()

	if should_use_store_path(destination, path_position):
		route.append_array(make_orthogonal_route(npc.global_position, path_position, true))
		route.append_array(make_orthogonal_route(path_position, destination, true))
	else:
		route.append_array(make_orthogonal_route(npc.global_position, destination, true))

	return dedupe_route_points(route)


func get_store_route_for_current_state(destination: Vector2) -> Array[Vector2]:
	var store := get_store_route_provider()

	if store == null:
		return []

	match npc.current_state:
		NPC.State.WALK_TO_SHELF:
			if npc._target_shelf != null and is_instance_valid(npc._target_shelf):
				return call_store_route(store, &"get_npc_route_to_shelf_access", [npc._target_shelf])

			return call_store_route(store, &"get_npc_entry_route_to_shelf", [destination, npc.global_position])
		NPC.State.WAIT_IN_QUEUE:
			var queue_index := NPC.current_queue.find(npc)

			if queue_index >= 0 and store.has_method("get_npc_route_to_queue_target_from"):
				return call_store_route(store, &"get_npc_route_to_queue_target_from", [npc.global_position, queue_index])

			return call_store_route(store, &"get_npc_route_to_cashier_from", [npc.global_position])
		NPC.State.EXIT:
			return call_store_route(store, &"get_npc_exit_route_from", [npc.global_position])

	return []


func get_store_route_provider() -> Node:
	var tree: SceneTree = npc.get_tree()

	if tree == null:
		return null

	var store: Node = tree.get_first_node_in_group("store")

	if store == null:
		return null

	return store


func call_store_route(store: Node, method_name: StringName, args: Array) -> Array[Vector2]:
	if store == null or not store.has_method(method_name):
		return []

	var result: Variant = store.callv(method_name, args)
	var route: Array[Vector2] = []

	if not (result is Array):
		return route

	for point_variant in result:
		if point_variant is Vector2:
			route.append(point_variant as Vector2)

	return dedupe_route_points(route)


func append_destination_to_route(route: Array[Vector2], destination: Vector2) -> Array[Vector2]:
	if route.is_empty():
		return make_orthogonal_route(npc.global_position, destination, true)

	var last_point := route[route.size() - 1]

	if last_point.distance_to(destination) > npc.ARRIVAL_THRESHOLD:
		route.append_array(make_orthogonal_route(last_point, destination, true))

	return dedupe_route_points(route)


func make_orthogonal_route(from_pos: Vector2, to_pos: Vector2, horizontal_first: bool = true) -> Array[Vector2]:
	var route: Array[Vector2] = []

	if from_pos.distance_to(to_pos) <= 2.0:
		return route

	var corner := Vector2(to_pos.x, from_pos.y) if horizontal_first else Vector2(from_pos.x, to_pos.y)

	if from_pos.distance_to(corner) > 2.0:
		route.append(corner)

	if corner.distance_to(to_pos) > 2.0:
		route.append(to_pos)

	return route


func dedupe_route_points(route: Array[Vector2]) -> Array[Vector2]:
	var deduped: Array[Vector2] = []

	for point in route:
		if not point.is_finite():
			continue

		if not deduped.is_empty() and deduped[deduped.size() - 1].distance_to(point) <= 2.0:
			continue

		deduped.append(point)

	return deduped


func should_use_store_path(destination: Vector2, path_position: Vector2) -> bool:
	if not is_valid_route_point(path_position):
		return false

	if npc.global_position.distance_to(path_position) <= npc.ARRIVAL_THRESHOLD:
		return false

	if destination.distance_to(path_position) <= npc.ARRIVAL_THRESHOLD:
		return false

	return true


func is_valid_route_point(point: Vector2) -> bool:
	return point.is_finite()


func is_near_cashier_area() -> bool:
	var cashier_threshold: float = 160.0
	return (
		NPC.counter_position != Vector2.ZERO
		and npc.global_position.distance_to(NPC.counter_position) <= cashier_threshold
	)


func get_store_path_position() -> Vector2:
	return NPC.store_path_position


func get_exit_position() -> Vector2:
	if is_valid_route_point(NPC.exit_position) and NPC.exit_position != Vector2.ZERO:
		return NPC.exit_position

	return NPC.entrance_position
