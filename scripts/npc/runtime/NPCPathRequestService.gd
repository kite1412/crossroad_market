class_name NPCPathRequestService
extends RefCounted

const StoreRuntimeDebugProbeScript = preload("res://scripts/debug/StoreRuntimeDebugProbe.gd")

const STATUS_PENDING: StringName = &"pending"
const STATUS_COMPLETED: StringName = &"completed"
const STATUS_FAILED: StringName = &"failed"
const MAX_COMPLETED_ROUTES_PER_TICK: int = 3
const REQUEST_TIMEOUT_MSEC: int = 2500

static var _next_request_id: int = 0
static var _requests: Array[Dictionary] = []


static func request_route(
	npc: Node,
	destination: Vector2,
	build_route: Callable,
	priority: int = 100
) -> Dictionary:
	if npc == null or not is_instance_valid(npc):
		return _make_failed_handle(destination, &"npc_missing")

	if not destination.is_finite() or not build_route.is_valid():
		return _make_failed_handle(destination, &"invalid_request")

	_next_request_id += 1
	var handle := {
		"id": _next_request_id,
		"npc_id": npc.get_instance_id(),
		"destination": destination,
		"build_route": build_route,
		"priority": priority,
		"status": STATUS_PENDING,
		"route": [],
		"reason": &"pending",
		"requested_msec": Time.get_ticks_msec(),
		"timeout_msec": Time.get_ticks_msec() + REQUEST_TIMEOUT_MSEC
	}
	_requests.append(handle)
	_sort_requests()
	return handle


static func tick(max_completed: int = MAX_COMPLETED_ROUTES_PER_TICK) -> void:
	var completed_count: int = 0
	var now_msec: int = Time.get_ticks_msec()

	while not _requests.is_empty() and completed_count < max_completed:
		var request: Dictionary = _requests.pop_front()
		if StringName(str(request.get("status", STATUS_PENDING))) != STATUS_PENDING:
			continue

		if now_msec > int(request.get("timeout_msec", 0)):
			request["status"] = STATUS_FAILED
			request["reason"] = &"timeout"
			completed_count += 1
			continue

		var route_start_usec: int = Time.get_ticks_usec()
		var route_variant: Variant = request.get("build_route", Callable()).call()
		StoreRuntimeDebugProbeScript.record(
			&"npc_path_request",
			StoreRuntimeDebugProbeScript.elapsed_msec(route_start_usec),
			{
				"npc_id": int(request.get("npc_id", 0)),
				"priority": int(request.get("priority", 100))
			}
		)
		if route_variant is Array:
			request["route"] = (route_variant as Array).duplicate()
			request["status"] = STATUS_COMPLETED
			request["reason"] = &"completed"
		else:
			request["route"] = []
			request["status"] = STATUS_FAILED
			request["reason"] = &"invalid_result"

		completed_count += 1


static func cancel(handle: Dictionary) -> void:
	if handle.is_empty():
		return

	handle["status"] = STATUS_FAILED
	handle["reason"] = &"cancelled"
	var request_id: int = int(handle.get("id", -1))
	for i in range(_requests.size() - 1, -1, -1):
		if int(_requests[i].get("id", -2)) == request_id:
			_requests.remove_at(i)


static func has_pending_requests() -> bool:
	return not _requests.is_empty()


static func _make_failed_handle(destination: Vector2, reason: StringName) -> Dictionary:
	return {
		"id": -1,
		"npc_id": 0,
		"destination": destination,
		"build_route": Callable(),
		"priority": 0,
		"status": STATUS_FAILED,
		"route": [],
		"reason": reason,
		"requested_msec": Time.get_ticks_msec(),
		"timeout_msec": Time.get_ticks_msec()
	}


static func _sort_requests() -> void:
	_requests.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority: int = int(a.get("priority", 100))
		var b_priority: int = int(b.get("priority", 100))
		if a_priority != b_priority:
			return a_priority < b_priority
		return int(a.get("requested_msec", 0)) < int(b.get("requested_msec", 0))
	)
