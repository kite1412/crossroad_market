extends "res://scripts/npc/runtime/NPCRouteController.gd"

const NPCStoreDebugTraceScript = preload(
	"res://scripts/npc/runtime/NPCStoreDebugTrace.gd"
)
const SOLO_CHECKOUT_EXIT_META: StringName = &"solo_checkout_exit"
const EXIT_ORIGIN_SHELF_META: StringName = &"exit_origin_shelf"
const ROUTE_LOG_INTERVAL_MSEC: int = 500

var _last_route_choice_key: String = ""
var _last_route_choice_log_msec: int = -ROUTE_LOG_INTERVAL_MSEC
var _last_route_build_key: String = ""
var _last_route_build_log_msec: int = -ROUTE_LOG_INTERVAL_MSEC
var _last_empty_route_log_msec: int = -ROUTE_LOG_INTERVAL_MSEC


func get_store_route_for_current_state(
	destination: Vector2
) -> Array[Vector2]:
	if npc.current_state != NPC.State.EXIT:
		return super.get_store_route_for_current_state(destination)

	var store := get_store_route_provider()
	if store == null:
		var no_store_route := super.get_store_route_for_current_state(
			destination
		)
		_trace_exit_route_choice(
			"base_no_store_provider",
			no_store_route,
			0.0
		)
		return no_store_route

	var origin_shelf: Variant = null
	if npc.has_meta(EXIT_ORIGIN_SHELF_META):
		origin_shelf = npc.get_meta(EXIT_ORIGIN_SHELF_META)

	if (
		origin_shelf is Shelf
		and is_instance_valid(origin_shelf)
		and store.has_method("get_npc_exit_route_from_shelf")
	):
		var shelf_started_usec := Time.get_ticks_usec()
		var shelf_exit_route := call_store_route(
			store,
			&"get_npc_exit_route_from_shelf",
			[origin_shelf, npc.global_position]
		)
		var shelf_elapsed_msec := float(
			Time.get_ticks_usec() - shelf_started_usec
		) / 1000.0
		_trace_exit_route_choice(
			"out_of_stock_shelf_exit",
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
		and store.has_method("get_npc_single_customer_exit_route")
	):
		var solo_started_usec := Time.get_ticks_usec()
		var solo_exit_route := call_store_route(
			store,
			&"get_npc_single_customer_exit_route",
			[npc.global_position]
		)
		var solo_elapsed_msec := float(
			Time.get_ticks_usec() - solo_started_usec
		) / 1000.0
		_trace_exit_route_choice(
			"solo_checkout_exit",
			solo_exit_route,
			solo_elapsed_msec
		)

		if not solo_exit_route.is_empty():
			return solo_exit_route

	var fallback_started_usec := Time.get_ticks_usec()
	var fallback_route := super.get_store_route_for_current_state(
		destination
	)
	var fallback_elapsed_msec := float(
		Time.get_ticks_usec() - fallback_started_usec
	) / 1000.0
	_trace_exit_route_choice(
		"base_exit_fallback",
		fallback_route,
		fallback_elapsed_msec
	)
	return fallback_route


func move_to(target: Vector2, arrival_threshold: float = -1.0) -> bool:
	var threshold: float = (
		npc.ARRIVAL_THRESHOLD
		if arrival_threshold < 0.0
		else arrival_threshold
	)

	if should_rebuild_movement_route(target):
		var build_started_usec := Time.get_ticks_usec()
		npc._movement_route = build_movement_route(target)
		npc._movement_route_destination = target
		var build_elapsed_msec := float(
			Time.get_ticks_usec() - build_started_usec
		) / 1000.0
		_trace_route_build(target, build_elapsed_msec)

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
			_trace_empty_route_wait(target)
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


func _trace_exit_route_choice(
	route_kind: String,
	route: Array[Vector2],
	elapsed_msec: float
) -> void:
	var route_key := "%s|%s" % [
		route_kind,
		str(NPCStoreDebugTraceScript.route_points(route))
	]
	var now_msec := Time.get_ticks_msec()

	if (
		route_key == _last_route_choice_key
		and now_msec - _last_route_choice_log_msec
		< ROUTE_LOG_INTERVAL_MSEC
	):
		return

	_last_route_choice_key = route_key
	_last_route_choice_log_msec = now_msec
	NPCStoreDebugTraceScript.emit(
		npc,
		"exit_route_choice",
		{
			"route_kind": route_kind,
			"elapsed_msec": elapsed_msec,
			"route_size": route.size(),
			"route": NPCStoreDebugTraceScript.route_points(route),
			"position": NPCStoreDebugTraceScript.vector(
				npc.global_position
			),
			"target": NPCStoreDebugTraceScript.vector(
				npc.target_position
			),
			"exit_after_checkout": npc._exit_after_checkout,
			"solo_meta_present": npc.has_meta(
				SOLO_CHECKOUT_EXIT_META
			),
			"solo": (
				bool(npc.get_meta(SOLO_CHECKOUT_EXIT_META))
				if npc.has_meta(SOLO_CHECKOUT_EXIT_META)
				else false
			),
			"origin_meta_present": npc.has_meta(
				EXIT_ORIGIN_SHELF_META
			)
		}
	)


func _trace_route_build(
	target: Vector2,
	elapsed_msec: float
) -> void:
	var route_key := "%s|%s" % [
		NPCStoreDebugTraceScript.state_name(int(npc.current_state)),
		str(NPCStoreDebugTraceScript.route_points(npc._movement_route))
	]
	var now_msec := Time.get_ticks_msec()

	if (
		route_key == _last_route_build_key
		and now_msec - _last_route_build_log_msec
		< ROUTE_LOG_INTERVAL_MSEC
	):
		return

	_last_route_build_key = route_key
	_last_route_build_log_msec = now_msec
	NPCStoreDebugTraceScript.emit(
		npc,
		"route_build",
		{
			"elapsed_msec": elapsed_msec,
			"state": NPCStoreDebugTraceScript.state_name(
				int(npc.current_state)
			),
			"route_size": npc._movement_route.size(),
			"route": NPCStoreDebugTraceScript.route_points(
				npc._movement_route
			),
			"position": NPCStoreDebugTraceScript.vector(
				npc.global_position
			),
			"target": NPCStoreDebugTraceScript.vector(target),
			"distance_to_target": npc.global_position.distance_to(
				target
			)
		}
	)


func _trace_empty_route_wait(target: Vector2) -> void:
	var now_msec := Time.get_ticks_msec()
	if (
		now_msec - _last_empty_route_log_msec
		< ROUTE_LOG_INTERVAL_MSEC
	):
		return

	_last_empty_route_log_msec = now_msec
	NPCStoreDebugTraceScript.emit(
		npc,
		"route_empty_wait",
		{
			"state": NPCStoreDebugTraceScript.state_name(
				int(npc.current_state)
			),
			"position": NPCStoreDebugTraceScript.vector(
				npc.global_position
			),
			"target": NPCStoreDebugTraceScript.vector(target),
			"distance_to_target": npc.global_position.distance_to(
				target
			),
			"exit_after_checkout": npc._exit_after_checkout
		}
	)
