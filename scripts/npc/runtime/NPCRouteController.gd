class_name NPCRouteController
extends RefCounted

const StoreRouteSafetyScript = preload("res://scripts/npc/runtime/StoreRouteSafety.gd")
const NPCMovementReservationSystemScript = preload("res://scripts/npc/runtime/NPCMovementReservationSystem.gd")
const NPCQueueReservationControllerScript = preload("res://scripts/npc/runtime/NPCQueueReservationController.gd")
const NPCPathRequestServiceScript = preload("res://scripts/npc/runtime/NPCPathRequestService.gd")
const NPCShoppingJobScript = preload("res://scripts/npc/runtime/NPCShoppingJob.gd")
const StoreRuntimeDebugProbeScript = preload("res://scripts/debug/StoreRuntimeDebugProbe.gd")

const NO_ROUTE_RETRY_COOLDOWN_MSEC: int = 450
const PATH_REQUEST_RETRY_COOLDOWN_MSEC: int = 1500
const PATH_REQUEST_BACKOFF_MAX_MSEC: int = 5000
const ROUTE_REQUEST_PROBE_COOLDOWN_MSEC: int = 650

var npc = null
@warning_ignore("unused_private_class_variable")
var _route_safety = null
var _no_route_retry_destination: Vector2 = Vector2.INF
var _next_no_route_retry_msec: int = 0
var _last_path_request_destination: Vector2 = Vector2.INF
var _next_path_request_msec: int = 0
var _path_request_backoff_msec: int = PATH_REQUEST_RETRY_COOLDOWN_MSEC
var _pending_path_request: Dictionary = {}
var _next_route_request_probe_msec: int = 0


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
	if _consume_pending_path_request(target):
		pass
	elif should_rebuild_movement_route(target):
		NPCMovementReservationSystemScript.release_for(npc)

		if uses_store_navigation_state():
			if not _can_request_path_to(target):
				npc.velocity = Vector2.ZERO
				npc.move_and_slide()
				_mark_waiting_for_path()
				_record_route_request_probe(&"npc_route_request_state", {
					"reason": "throttled",
					"destination": _format_vector(target),
					"retry_in_msec": maxi(
						0,
						_next_path_request_msec - Time.get_ticks_msec()
					)
				})
				return false

			_request_movement_route(target)
			npc.velocity = Vector2.ZERO
			npc.move_and_slide()
			return false

		npc._movement_route = build_movement_route(target)
		npc._movement_route_destination = target

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
	if not _pending_path_request.is_empty():
		NPCPathRequestServiceScript.cancel(_pending_path_request)
	_pending_path_request.clear()
	npc._last_watchdog_position = Vector2.INF
	npc._stuck_watchdog_timer = 0.0
	npc._stuck_watchdog_rebuilds = 0
	_no_route_retry_destination = Vector2.INF
	_next_no_route_retry_msec = 0
	_last_path_request_destination = Vector2.INF
	_next_path_request_msec = 0
	_path_request_backoff_msec = PATH_REQUEST_RETRY_COOLDOWN_MSEC


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
func _can_request_path_to(target: Vector2) -> bool:
	if not _last_path_request_destination.is_finite():
		return true

	if not _last_path_request_destination.is_equal_approx(target):
		return true

	return Time.get_ticks_msec() >= _next_path_request_msec


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _request_movement_route(target: Vector2) -> void:
	if not _pending_path_request.is_empty():
		var pending_destination: Vector2 = _pending_path_request.get(
			"destination",
			Vector2.INF
		) as Vector2
		if pending_destination.is_equal_approx(target):
			_mark_waiting_for_path()
			return
		NPCPathRequestServiceScript.cancel(_pending_path_request)

	_pending_path_request = NPCPathRequestServiceScript.request_route(
		npc,
		target,
		Callable(self, "build_movement_route").bind(target),
		_get_path_request_priority()
	)
	_last_path_request_destination = target
	_next_path_request_msec = Time.get_ticks_msec() + _path_request_backoff_msec
	npc._movement_route.clear()
	npc._movement_route_destination = target
	_mark_waiting_for_path()
	_record_route_request_probe(&"npc_route_request_state", {
		"reason": "requested",
		"destination": _format_vector(target),
		"request_id": int(_pending_path_request.get("id", -1))
	})


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _consume_pending_path_request(target: Vector2) -> bool:
	if _pending_path_request.is_empty():
		return false

	var destination: Vector2 = _pending_path_request.get(
		"destination",
		Vector2.INF
	) as Vector2
	if not destination.is_equal_approx(target):
		NPCPathRequestServiceScript.cancel(_pending_path_request)
		_pending_path_request.clear()
		return false

	var status := StringName(str(_pending_path_request.get("status", &"pending")))
	if status == NPCPathRequestServiceScript.STATUS_PENDING:
		_mark_waiting_for_path()
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		_record_route_request_probe(&"npc_route_request_state", {
			"reason": "pending",
			"destination": _format_vector(target),
			"request_id": int(_pending_path_request.get("id", -1))
		})
		return true

	if status == NPCPathRequestServiceScript.STATUS_COMPLETED:
		npc._movement_route = _variant_route_to_vector2_array(
			_pending_path_request.get("route", [])
		)
		npc._movement_route_destination = target
		_pending_path_request.clear()
		if npc._movement_route.is_empty() and uses_store_navigation_state():
			_record_route_request_probe(&"npc_route_request_state", {
				"reason": "completed_empty",
				"destination": _format_vector(target)
			})
			_handle_empty_store_route(target)
		else:
			_record_route_request_probe(&"npc_route_request_state", {
				"reason": "completed_route",
				"destination": _format_vector(target),
				"route_points": npc._movement_route.size()
			})
			_reset_path_request_backoff()
			_clear_target_shelf_route_failure()
		return true

	_pending_path_request.clear()
	if uses_store_navigation_state():
		_record_route_request_probe(&"npc_route_request_state", {
			"reason": "failed",
			"destination": _format_vector(target)
		})
		_handle_empty_store_route(target)
	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _set_no_route_retry(target: Vector2) -> void:
	_no_route_retry_destination = target
	_next_no_route_retry_msec = (
		Time.get_ticks_msec() + maxi(
			NO_ROUTE_RETRY_COOLDOWN_MSEC,
			_path_request_backoff_msec
		)
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _increase_path_request_backoff(target: Vector2) -> void:
	_last_path_request_destination = target
	_path_request_backoff_msec = mini(
		PATH_REQUEST_BACKOFF_MAX_MSEC,
		maxi(
			PATH_REQUEST_RETRY_COOLDOWN_MSEC,
			_path_request_backoff_msec * 2
		)
	)
	_next_path_request_msec = Time.get_ticks_msec() + _path_request_backoff_msec


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _reset_path_request_backoff() -> void:
	_last_path_request_destination = Vector2.INF
	_next_path_request_msec = 0
	_path_request_backoff_msec = PATH_REQUEST_RETRY_COOLDOWN_MSEC


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _handle_empty_store_route(target: Vector2) -> void:
	_set_no_route_retry(target)
	_increase_path_request_backoff(target)

	if npc.current_state != NPC.State.WALK_TO_SHELF:
		return

	_mark_target_shelf_route_failed()
	if try_recover_to_alternate_shelf():
		return

	abandon_purchase_and_exit()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _mark_target_shelf_route_failed() -> void:
	if npc._target_shelf == null or not is_instance_valid(npc._target_shelf):
		return
	if npc._shopping_flow == null:
		return
	if not npc._shopping_flow.has_method("mark_shelf_route_failed"):
		return

	npc._shopping_flow.mark_shelf_route_failed(npc._target_shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _clear_target_shelf_route_failure() -> void:
	if npc._target_shelf == null or not is_instance_valid(npc._target_shelf):
		return
	if npc._shopping_flow == null:
		return
	if not npc._shopping_flow.has_method("clear_shelf_route_failure"):
		return

	npc._shopping_flow.clear_shelf_route_failure(npc._target_shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_path_request_priority() -> int:
	if npc.current_state == NPC.State.WAIT_IN_QUEUE:
		return 10
	if npc.current_state == NPC.State.WALK_TO_SHELF:
		return 20
	if npc.current_state == NPC.State.TAKE_ITEM:
		return 30
	if npc.current_state == NPC.State.EXIT:
		return 40
	return 100


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _mark_waiting_for_path() -> void:
	if npc._shopping_job != null:
		npc._shopping_job.set_state(NPCShoppingJobScript.STATE_WAITING_FOR_PATH)


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
					_record_route_probe(&"npc_queue_route_branch", {
						"branch": "shelf_egress",
						"queue_index": queue_index,
						"route_points": egress_queue_route.size(),
						"destination": _format_vector(destination)
					})
					return egress_queue_route

			if npc._is_moving_from_queue_to_cashier:
				var cashier_route := call_store_route(
					store,
					&"get_npc_route_to_cashier_from",
					[npc.global_position]
				)
				_record_route_probe(&"npc_queue_route_branch", {
					"branch": "direct_cashier",
					"queue_index": queue_index,
					"route_points": cashier_route.size(),
					"destination": _format_vector(destination)
				})
				return cashier_route

			if (
				queue_index >= 0
				and store.has_method("get_npc_route_to_queue_target_from")
			):
				if queue_index == 0 and NPCQueueReservationControllerScript.size() <= 1:
					var solo_cashier_route := call_store_route(
						store,
						&"get_npc_route_to_cashier_from",
						[npc.global_position]
					)
					_record_route_probe(&"npc_queue_route_branch", {
						"branch": "solo_cashier",
						"queue_index": queue_index,
						"route_points": solo_cashier_route.size(),
						"destination": _format_vector(destination)
					})
					return solo_cashier_route

				var queue_target_route := call_store_route(
					store,
					&"get_npc_route_to_queue_target_from",
					[npc.global_position, queue_index]
				)
				_record_route_probe(&"npc_queue_route_branch", {
					"branch": "queue_target",
					"queue_index": queue_index,
					"route_points": queue_target_route.size(),
					"destination": _format_vector(destination)
				})
				return queue_target_route

			var fallback_cashier_route := call_store_route(
				store,
				&"get_npc_route_to_cashier_from",
				[npc.global_position]
			)
			_record_route_probe(&"npc_queue_route_branch", {
				"branch": "fallback_cashier",
				"queue_index": queue_index,
				"route_points": fallback_cashier_route.size(),
				"destination": _format_vector(destination)
			})
			return fallback_cashier_route

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
		_record_route_probe(&"npc_shelf_egress_route", {
			"reason": "missing_shelf",
			"queue_index": queue_index,
			"destination": _format_vector(destination)
		})
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var egress_route := call_store_route(
		store,
		&"get_npc_route_from_shelf_to_cashier",
		[npc._queue_entry_shelf]
	)

	if egress_route.is_empty():
		_record_route_probe(&"npc_shelf_egress_route", {
			"reason": "shelf_to_cashier_empty",
			"queue_index": queue_index,
			"destination": _format_vector(destination),
			"entry_shelf_id": String(npc._queue_entry_shelf.get_shelf_id()),
			"entry_shelf_revision": npc._queue_entry_shelf.get_revision()
		})
		return []

	var access_position: Vector2 = egress_route.front()
	if npc._queue_entry_shelf.has_meta(&"npc_access_point"):
		var access_variant: Variant = npc._queue_entry_shelf.get_meta(
			&"npc_access_point",
			Vector2.INF
		)
		if access_variant is Vector2:
			access_position = access_variant as Vector2

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var egress_end: Vector2 = egress_route.back()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var queue_route := call_store_route(
		store,
		&"get_npc_route_to_queue_target_from",
		[egress_end, queue_index]
	)

	if queue_route.is_empty():
		_record_route_probe(&"npc_shelf_egress_route", {
			"reason": "queue_route_empty",
			"queue_index": queue_index,
			"destination": _format_vector(destination),
			"access_position": _format_vector(access_position),
			"egress_end": _format_vector(egress_end),
			"shelf_route_points": egress_route.size()
		})
		return []

	var route: Array[Vector2] = []
	var best_distance := INF
	for horizontal_first in [true, false]:
		var candidate_route := make_orthogonal_route(
			npc.global_position,
			access_position,
			horizontal_first
		)
		if (
			candidate_route.is_empty()
			or candidate_route.back().distance_to(access_position)
			> npc.ARRIVAL_THRESHOLD
		):
			candidate_route.append(access_position)
		candidate_route.append_array(egress_route)
		candidate_route.append_array(queue_route)
		candidate_route = dedupe_route_points(candidate_route)
		var sanitized_route: Array[Vector2] = candidate_route
		if _route_safety != null:
			sanitized_route = _route_safety.sanitize_store_route(
				candidate_route
			)
		if sanitized_route.is_empty():
			_record_route_probe(&"npc_shelf_egress_route", {
				"reason": "sanitized_empty",
				"queue_index": queue_index,
				"horizontal_first": horizontal_first,
				"destination": _format_vector(destination),
				"access_position": _format_vector(access_position),
				"candidate_points": candidate_route.size()
			})
			continue

		var route_distance := _get_route_distance(
			npc.global_position,
			sanitized_route
		)
		if route_distance >= best_distance:
			continue

		best_distance = route_distance
		route = sanitized_route

	if (
		not route.is_empty()
		and route.back().distance_to(destination) > npc.ARRIVAL_THRESHOLD
	):
		route.append(destination)

	_record_route_probe(&"npc_shelf_egress_route", {
		"reason": "success" if not route.is_empty() else "no_safe_candidate",
		"queue_index": queue_index,
		"destination": _format_vector(destination),
		"access_position": _format_vector(access_position),
		"egress_end": _format_vector(egress_end),
		"shelf_route_points": egress_route.size(),
		"queue_route_points": queue_route.size(),
		"route_points": route.size()
	})
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
func _get_route_distance(from_position: Vector2, route: Array[Vector2]) -> float:
	var distance := 0.0
	var current := from_position
	for point in route:
		distance += current.distance_to(point)
		current = point
	return distance


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _record_route_probe(label: StringName, extra_context: Dictionary) -> void:
	if npc == null:
		return

	var context: Dictionary = {
		"npc_id": npc.get_instance_id(),
		"state": int(npc.current_state),
		"position": _format_vector(npc.global_position),
		"target": _format_vector(npc.target_position),
		"target_distance": snappedf(
			npc.global_position.distance_to(npc.target_position),
			0.01
		),
		"current_route_points": npc._movement_route.size(),
		"egress_pending": npc._queue_egress_route_pending,
		"moving_to_cashier": npc._is_moving_from_queue_to_cashier,
		"has_origin_shelf": npc.has_meta(&"exit_origin_shelf")
	}

	if npc._queue_entry_shelf != null and is_instance_valid(npc._queue_entry_shelf):
		context["entry_shelf_id"] = String(npc._queue_entry_shelf.get_shelf_id())
		context["entry_shelf_revision"] = npc._queue_entry_shelf.get_revision()

	for key in extra_context:
		context[key] = extra_context[key]

	StoreRuntimeDebugProbeScript.record(label, 0.0, context, 0.0)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _record_route_request_probe(
	label: StringName,
	extra_context: Dictionary
) -> void:
	var now_msec := Time.get_ticks_msec()
	if now_msec < _next_route_request_probe_msec:
		return

	_next_route_request_probe_msec = now_msec + ROUTE_REQUEST_PROBE_COOLDOWN_MSEC
	_record_route_probe(label, extra_context)


func _format_vector(value: Vector2) -> String:
	return "%.1f,%.1f" % [value.x, value.y]


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _variant_route_to_vector2_array(route_variant: Variant) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route: Array[Vector2] = []
	if not route_variant is Array:
		return route

	for point_variant in route_variant:
		if point_variant is Vector2:
			route.append(point_variant as Vector2)

	return dedupe_route_points(route)


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
