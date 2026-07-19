class_name NPCRouteController
extends RefCounted

const DEBUG_NPC_ROUTE_BUILD: bool = true

var npc = null
var _last_route_debug_key: String = ""
var _last_stuck_debug_key: String = ""


func setup(npc_node) -> void:
	npc = npc_node


func move_to(target: Vector2, arrival_threshold: float = -1.0) -> bool:
	var threshold: float = npc.ARRIVAL_THRESHOLD if arrival_threshold < 0.0 else arrival_threshold
	var rebuilt_route := false

	if should_rebuild_movement_route(target):
		npc._movement_route = build_movement_route(target)
		npc._movement_route_destination = target
		rebuilt_route = true

	if npc._movement_route.is_empty():
		if npc.current_state == NPC.State.WAIT_IN_QUEUE:
			pass
			return false

		return NPCMovement.move_to(npc, target, npc.SPEED, threshold)

	var next_target: Vector2 = npc._movement_route[0]

	if not NPCMovement.move_to(npc, next_target, npc.SPEED, threshold):
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
		pass
		reset_stuck_watchdog()
		return

	if npc._stuck_watchdog_rebuilds >= npc.STUCK_WATCHDOG_MAX_REBUILDS:
		pass
		pass
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

	pass
	pass
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
		return dedupe_route_points(route)

	if npc.current_state == NPC.State.WAIT_IN_QUEUE:
		if not route.is_empty():
			return dedupe_route_points(route)
		# Store route empty — fall back to direct fallback path so NPC is not stuck
		return build_direct_fallback(destination)

	return build_direct_fallback(destination)

func build_direct_fallback(destination: Vector2) -> Array[Vector2]:
	if not destination.is_finite():
		return []

	if npc.global_position.distance_to(destination) <= npc.ARRIVAL_THRESHOLD:
		return []

	return [destination]


func get_store_route_for_current_state(destination: Vector2) -> Array[Vector2]:
	var store := get_store_route_provider()

	if store == null:
		return []

	match npc.current_state:
		NPC.State.WALK_TO_SHELF:
			if npc._target_shelf != null and is_instance_valid(npc._target_shelf):
				var shelf_route := call_store_route(store, &"get_npc_route_to_shelf_access", [npc._target_shelf, npc.global_position, npc])
				pass
				return shelf_route

			var entry_route := call_store_route(store, &"get_npc_entry_route_to_shelf", [destination, npc.global_position])
			pass
			return entry_route
		NPC.State.WAIT_IN_QUEUE:
			var queue_index := NPC.current_queue.find(npc)

			if npc._is_moving_from_queue_to_cashier:
				var cashier_route := call_store_route(store, &"get_npc_route_to_cashier_from", [npc.global_position])
				pass
				return cashier_route

			if queue_index >= 0 and npc._queue_egress_route_pending and npc._queue_entry_shelf != null and is_instance_valid(npc._queue_entry_shelf):
				var egress_queue_route := get_shelf_egress_queue_route(store, queue_index, destination)
				pass

				if not egress_queue_route.is_empty():
					npc._queue_egress_route_pending = false
					npc._queue_entry_shelf = null
					pass
					return egress_queue_route

			if queue_index >= 0 and store.has_method("get_npc_route_to_queue_target_from"):
				if queue_index == 0 and NPC.current_queue.size() <= 1:
					var direct_cashier_route := call_store_route(store, &"get_npc_route_to_cashier_from", [npc.global_position])
					pass
					return direct_cashier_route

				var queue_route := call_store_route(store, &"get_npc_route_to_queue_target_from", [npc.global_position, queue_index])
				pass
				return queue_route

			var fallback_cashier_route := call_store_route(store, &"get_npc_route_to_cashier_from", [npc.global_position])
			pass
			return fallback_cashier_route
		NPC.State.EXIT:
			var exit_route := call_store_route(store, &"get_npc_exit_route_from", [npc.global_position])
			pass
			return exit_route

	return []


func get_shelf_egress_queue_route(store: Node, queue_index: int, destination: Vector2) -> Array[Vector2]:
	if store == null or npc._queue_entry_shelf == null or not is_instance_valid(npc._queue_entry_shelf):
		return []

	var egress_route := call_store_route(store, &"get_npc_route_from_shelf_to_cashier", [npc._queue_entry_shelf])

	if egress_route.is_empty():
		return []

	var egress_end := egress_route[egress_route.size() - 1]
	var queue_route: Array[Vector2] = []

	if store.has_method("get_npc_route_to_queue_target_from"):
		queue_route = call_store_route(store, &"get_npc_route_to_queue_target_from", [egress_end, queue_index])

	if queue_route.is_empty():
		return []

	var route := egress_route.duplicate()
	route.append_array(queue_route)
	route = dedupe_route_points(route)

	if not route.is_empty() and route[route.size() - 1].distance_to(destination) > npc.ARRIVAL_THRESHOLD:
		route.append(destination)

	return dedupe_route_points(route)


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
	var result := route.duplicate()

	if not destination.is_finite():
		return dedupe_route_points(result)

	if result.is_empty():
		result.append(destination)
		return result

	var last_point: Vector2 = result[result.size() - 1]

	if last_point.distance_to(destination) > npc.ARRIVAL_THRESHOLD:
		result.append(destination)

	return dedupe_route_points(result)


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


func should_print_route_debug(source: String, destination: Vector2, route: Array[Vector2]) -> bool:
	var debug_key := "%s:%s:%d,%d:%d,%d:%d" % [
		source,
		str(npc.current_state),
		roundi(npc.global_position.x),
		roundi(npc.global_position.y),
		roundi(destination.x),
		roundi(destination.y),
		route.size()
	]

	if route.is_empty() and debug_key == _last_route_debug_key:
		return false

	_last_route_debug_key = debug_key
	return true


func _get_debug_npc_label() -> String:
	if npc != null and npc.npc_data != null and npc.npc_data.npc_id != "":
		return npc.npc_data.npc_id

	return npc.name if npc != null else "<null>"


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
