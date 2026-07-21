class_name NPCRouteController
extends RefCounted

const StoreRouteSafetyScript = preload("res://scripts/npc/runtime/StoreRouteSafety.gd")
const NPCMovementReservationSystemScript = preload("res://scripts/npc/runtime/NPCMovementReservationSystem.gd")
const NPCQueueReservationControllerScript = preload("res://scripts/npc/runtime/NPCQueueReservationController.gd")

const NO_ROUTE_RETRY_COOLDOWN_MSEC: int = 450

var npc = null
@warning_ignore("unused_private_class_variable")
var _route_safety = null
var _no_route_retry_destination: Vector2 = Vector2.INF
var _next_no_route_retry_msec: int = 0


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(npc_node) -> void:
	npc = npc_node
	if _route_safety == null:
		_route_safety = StoreRouteSafetyScript.new()
	_route_safety.setup(npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func move_to(target: Vector2, arrival_threshold: float = -1.0) -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var threshold: float = npc.ARRIVAL_THRESHOLD if arrival_threshold < 0.0 else arrival_threshold

	if should_rebuild_movement_route(target):
		NPCMovementReservationSystemScript.release_for(npc)
		npc._movement_route = build_movement_route(target)
		npc._movement_route_destination = target
		if npc._movement_route.is_empty() and uses_store_navigation_state():
			_no_route_retry_destination = target
			_next_no_route_retry_msec = (
				Time.get_ticks_msec() + NO_ROUTE_RETRY_COOLDOWN_MSEC
			)

	_trim_arrived_route_points(threshold)

	if npc._movement_route.is_empty():
		NPCMovementReservationSystemScript.release_for(npc)
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

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var next_target: Vector2 = npc._movement_route[0]
	if not NPCMovementReservationSystemScript.reserve_next_position(npc, next_target):
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		return false

	if not NPCMovement.move_to(
		npc,
		next_target,
		npc.SPEED,
		threshold
	):
		return false

	npc._movement_route.remove_at(0)
	NPCMovementReservationSystemScript.release_for(npc)
	_trim_arrived_route_points(threshold)
	return npc._movement_route.is_empty()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func update_stuck_watchdog(delta: float) -> void:
	if not is_movement_state():
		reset_stuck_watchdog()
		return

	if npc._dialog_timer > 0.0 or npc._take_item_pause_timer > 0.0:
		reset_stuck_watchdog()
		return

	if (
		npc.current_state == NPC.State.EXIT
		and npc.global_position.distance_to(npc.target_position)
		<= npc.ARRIVAL_THRESHOLD
	):
		reset_stuck_watchdog()
		return

	if not npc._last_watchdog_position.is_finite():
		npc._last_watchdog_position = npc.global_position
		npc._stuck_watchdog_timer = 0.0
		return

	if (
		npc.global_position.distance_to(npc._last_watchdog_position)
		> npc.STUCK_MIN_MOVE_DISTANCE
	):
		npc._last_watchdog_position = npc.global_position
		npc._stuck_watchdog_timer = 0.0
		return

	npc._stuck_watchdog_timer += delta

	if npc._stuck_watchdog_timer < npc.STUCK_WATCHDOG_SECONDS:
		return

	if (
		npc.current_state == NPC.State.WALK_TO_SHELF
		and npc._refresh_shelf_visit_target()
	):
		reset_stuck_watchdog()
		return

	if npc._stuck_watchdog_rebuilds >= npc.STUCK_WATCHDOG_MAX_REBUILDS:
		# Never replace a failed store route with a direct segment. Direct
		# fallbacks were allowing NPCs to skip markers and cross PhysicsBody2D
		# obstacles. An exiting NPC waits and retries; other states safely
		# transition to the normal graph-based exit state.
		if npc.current_state == NPC.State.EXIT:
			npc._movement_route.clear()
			npc._movement_route_destination = Vector2.INF
			npc._last_watchdog_position = npc.global_position
			npc._stuck_watchdog_timer = 0.0
			npc._stuck_watchdog_rebuilds = 0
			return

		if try_recover_to_alternate_shelf():
			reset_stuck_watchdog()
			return

		abandon_purchase_and_exit()
		return

	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	npc._last_watchdog_position = npc.global_position
	npc._stuck_watchdog_timer = 0.0
	npc._stuck_watchdog_rebuilds += 1


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_movement_state() -> bool:
	return npc.current_state in [
		NPC.State.WALK_TO_SHELF,
		NPC.State.TAKE_ITEM,
		NPC.State.WAIT_IN_QUEUE,
		NPC.State.EXIT,
		NPC.State.WAIT_FOR_SHELF
	]


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func uses_store_navigation_state() -> bool:
	return npc.current_state in [
		NPC.State.WALK_TO_SHELF,
		NPC.State.TAKE_ITEM,
		NPC.State.WAIT_IN_QUEUE,
		NPC.State.EXIT,
		NPC.State.WAIT_FOR_SHELF
	]


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func reset_stuck_watchdog() -> void:
	NPCMovementReservationSystemScript.release_for(npc)
	npc._last_watchdog_position = Vector2.INF
	npc._stuck_watchdog_timer = 0.0
	npc._stuck_watchdog_rebuilds = 0
	_no_route_retry_destination = Vector2.INF
	_next_no_route_retry_msec = 0


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func should_rebuild_movement_route(target: Vector2) -> bool:
	if npc.has_meta(&"path_possibly_invalid"):
		npc.remove_meta(&"path_possibly_invalid")
		NPCMovementReservationSystemScript.release_for(npc)
		return true

	if npc._movement_route.is_empty():
		if (
			uses_store_navigation_state()
			and _no_route_retry_destination.is_finite()
			and _no_route_retry_destination.is_equal_approx(target)
			and Time.get_ticks_msec() < _next_no_route_retry_msec
		):
			return false
		return true

	return not npc._movement_route_destination.is_equal_approx(target)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func try_recover_to_alternate_shelf() -> bool:
	if npc._has_taken_shelf_item or not npc._cart_items.is_empty():
		return false

	if not (npc.current_state in [
		NPC.State.WALK_TO_SHELF,
		NPC.State.SEARCH_ITEM,
		NPC.State.TAKE_ITEM,
		NPC.State.WAIT_FOR_SHELF
	]):
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var replacement_shelf: Shelf = npc._find_reachable_matching_shelf()
	if replacement_shelf == null:
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var visit_position: Vector2 = npc._get_shelf_visit_position(replacement_shelf)
	if not visit_position.is_finite():
		return false

	npc._target_shelf = replacement_shelf
	if npc._shopping_job != null:
		npc._shopping_job.set_target_shelf(replacement_shelf)
	npc.target_position = visit_position
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	npc._set_state(NPC.State.WALK_TO_SHELF)
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func abandon_purchase_and_exit() -> void:
	if not npc._cart_items.is_empty():
		npc._return_cart_items_to_shelf()

	npc._exit_after_checkout = false
	npc.target_position = get_exit_position()
	npc._set_state(NPC.State.EXIT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func build_movement_route(destination: Vector2) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route := get_store_route_for_current_state(destination)

	if not route.is_empty():
		route = dedupe_route_points(route)
		if _route_safety != null:
			route = _route_safety.sanitize_store_route(route)
		return dedupe_route_points(route)

	# Store movement must wait for a valid graph route. Falling back to a
	# direct destination makes NPCs cut across queue markers, shelves, items,
	# counters, and other static physics bodies.
	if uses_store_navigation_state():
		return []

	return build_direct_fallback(destination)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func build_direct_fallback(destination: Vector2) -> Array[Vector2]:
	if not destination.is_finite():
		return []

	if npc.global_position.distance_to(destination) <= npc.ARRIVAL_THRESHOLD:
		return []

	return [destination]


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_store_route_for_current_state(destination: Vector2) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store := get_store_route_provider()

	if store == null:
		return []

	match npc.current_state:
		NPC.State.WALK_TO_SHELF:
			if (
				npc._target_shelf != null
				and is_instance_valid(npc._target_shelf)
			):
				return call_store_route(
					store,
					&"get_npc_route_to_shelf_access",
					[
						npc._target_shelf,
						npc.global_position,
						npc
					]
				)

			return call_store_route(
				store,
				&"get_npc_entry_route_to_shelf",
				[destination, npc.global_position]
			)

		NPC.State.WAIT_IN_QUEUE:
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var queue_index := NPCQueueReservationControllerScript.index_of(npc)

			if npc._is_moving_from_queue_to_cashier:
				return call_store_route(
					store,
					&"get_npc_route_to_cashier_from",
					[npc.global_position]
				)

			if (
				queue_index >= 0
				and npc._queue_egress_route_pending
				and npc._queue_entry_shelf != null
				and is_instance_valid(npc._queue_entry_shelf)
			):
				@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
				var egress_queue_route := get_shelf_egress_queue_route(
					store,
					queue_index,
					destination
				)

				if not egress_queue_route.is_empty():
					npc._queue_egress_route_pending = false
					npc._queue_entry_shelf = null
					return egress_queue_route

			if (
				queue_index >= 0
				and store.has_method("get_npc_route_to_queue_target_from")
			):
				if queue_index == 0 and NPCQueueReservationControllerScript.size() <= 1:
					return call_store_route(
						store,
						&"get_npc_route_to_cashier_from",
						[npc.global_position]
					)

				return call_store_route(
					store,
					&"get_npc_route_to_queue_target_from",
					[npc.global_position, queue_index]
				)

			return call_store_route(
				store,
				&"get_npc_route_to_cashier_from",
				[npc.global_position]
			)

		NPC.State.EXIT:
			if (
				npc._exit_after_checkout
				and store.has_method("get_npc_exit_route_from_cashier")
			):
				return call_store_route(
					store,
					&"get_npc_exit_route_from_cashier",
					[npc.global_position]
				)

			return call_store_route(
				store,
				&"get_npc_exit_route_from",
				[npc.global_position]
			)

	return []


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_egress_queue_route(
	store: Node,
	queue_index: int,
	destination: Vector2
) -> Array[Vector2]:
	if (
		store == null
		or npc._queue_entry_shelf == null
		or not is_instance_valid(npc._queue_entry_shelf)
	):
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var egress_route := call_store_route(
		store,
		&"get_npc_route_from_shelf_to_cashier",
		[npc._queue_entry_shelf]
	)

	if egress_route.is_empty():
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var egress_end: Vector2 = egress_route.back()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var queue_route := call_store_route(
		store,
		&"get_npc_route_to_queue_target_from",
		[egress_end, queue_index]
	)

	if queue_route.is_empty():
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route := egress_route.duplicate()
	route.append_array(queue_route)
	route = dedupe_route_points(route)

	if (
		not route.is_empty()
		and route.back().distance_to(destination) > npc.ARRIVAL_THRESHOLD
	):
		route.append(destination)

	return dedupe_route_points(route)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_store_route_provider() -> Node:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var tree: SceneTree = npc.get_tree()

	if tree == null:
		return null

	return tree.get_first_node_in_group("store")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func call_store_route(
	store: Node,
	method_name: StringName,
	args: Array
) -> Array[Vector2]:
	if store == null or not store.has_method(method_name):
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result: Variant = store.callv(method_name, args)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route: Array[Vector2] = []

	if not result is Array:
		return route

	for point_variant in result:
		if point_variant is Vector2:
			route.append(point_variant as Vector2)

	return dedupe_route_points(route)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func append_destination_to_route(
	route: Array[Vector2],
	destination: Vector2
) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result := route.duplicate()

	if not destination.is_finite():
		return dedupe_route_points(result)

	if result.is_empty():
		result.append(destination)
		return result

	if result.back().distance_to(destination) > npc.ARRIVAL_THRESHOLD:
		result.append(destination)

	return dedupe_route_points(result)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func make_orthogonal_route(
	from_pos: Vector2,
	to_pos: Vector2,
	horizontal_first: bool = true
) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route: Array[Vector2] = []

	if from_pos.distance_to(to_pos) <= 2.0:
		return route

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var corner := (
		Vector2(to_pos.x, from_pos.y)
		if horizontal_first
		else Vector2(from_pos.x, to_pos.y)
	)

	if from_pos.distance_to(corner) > 2.0:
		route.append(corner)

	if corner.distance_to(to_pos) > 2.0:
		route.append(to_pos)

	return route


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func dedupe_route_points(route: Array[Vector2]) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var deduped: Array[Vector2] = []

	for point in route:
		if not point.is_finite():
			continue

		if (
			not deduped.is_empty()
			and deduped.back().distance_to(point) <= 2.0
		):
			continue

		deduped.append(point)

	return deduped


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _trim_arrived_route_points(threshold: float) -> void:
	while (
		not npc._movement_route.is_empty()
		and npc.global_position.distance_to(npc._movement_route[0]) <= threshold
	):
		npc._movement_route.remove_at(0)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func should_use_store_path(
	destination: Vector2,
	path_position: Vector2
) -> bool:
	if not is_valid_route_point(path_position):
		return false

	if npc.global_position.distance_to(path_position) <= npc.ARRIVAL_THRESHOLD:
		return false

	if destination.distance_to(path_position) <= npc.ARRIVAL_THRESHOLD:
		return false

	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_valid_route_point(point: Vector2) -> bool:
	return point.is_finite()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_near_cashier_area() -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cashier_threshold: float = 160.0
	return (
		NPC.counter_position != Vector2.ZERO
		and npc.global_position.distance_to(NPC.counter_position)
		<= cashier_threshold
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_store_path_position() -> Vector2:
	return NPC.store_path_position


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_exit_position() -> Vector2:
	if (
		is_valid_route_point(NPC.exit_position)
		and NPC.exit_position != Vector2.ZERO
	):
		return NPC.exit_position

	return NPC.entrance_position
