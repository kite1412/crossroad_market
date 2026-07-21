class_name NPCPathRequestService
extends RefCounted

const StoreRuntimeDebugProbeScript = preload("res://scripts/debug/StoreRuntimeDebugProbe.gd")

const STATUS_PENDING: StringName = &"pending"
const STATUS_COMPLETED: StringName = &"completed"
const STATUS_FAILED: StringName = &"failed"
const MAX_COMPLETED_ROUTES_PER_TICK: int = 1
const REQUEST_TIMEOUT_MSEC: int = 2500

static var _next_request_id: int = 0
static var _requests: Array[Dictionary] = []
static var _finished_requests: Dictionary = {}


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

	var npc_id: int = npc.get_instance_id()
	var existing_request := _find_pending_request(npc_id, destination)
	if not existing_request.is_empty():
		return existing_request

	_next_request_id += 1
	var handle := {
		"id": _next_request_id,
		"npc_id": npc_id,
		"destination": destination,
		"build_route": build_route,
		"priority": priority,
		"context": _build_request_context(npc, destination),
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
		var route_elapsed_msec := StoreRuntimeDebugProbeScript.elapsed_msec(
			route_start_usec
		)
		if route_variant is Array:
			request["route"] = (route_variant as Array).duplicate()
			request["status"] = STATUS_COMPLETED
			request["reason"] = &"completed"
		else:
			request["route"] = []
			request["status"] = STATUS_FAILED
			request["reason"] = &"invalid_result"

		var debug_context: Dictionary = (
			request.get("context", {}) as Dictionary
		).duplicate(true)
		debug_context["priority"] = int(request.get("priority", 100))
		debug_context["status"] = String(request.get("status", STATUS_PENDING))
		debug_context["reason"] = String(request.get("reason", &""))
		debug_context["route_points"] = (request.get("route", []) as Array).size()
		_finished_requests[int(request.get("id", -1))] = request.duplicate(true)
		_trim_finished_requests()
		StoreRuntimeDebugProbeScript.record(
			&"npc_path_request",
			route_elapsed_msec,
			debug_context,
			0.0
		)

		completed_count += 1


static func cancel(handle: Dictionary) -> void:
	if handle.is_empty():
		return

	handle["status"] = STATUS_FAILED
	handle["reason"] = &"cancelled"
	var request_id: int = int(handle.get("id", -1))
	_finished_requests.erase(request_id)
	for i in range(_requests.size() - 1, -1, -1):
		if int(_requests[i].get("id", -2)) == request_id:
			_requests.remove_at(i)


static func has_pending_requests() -> bool:
	return not _requests.is_empty()


static func get_finished_request(request_id: int) -> Dictionary:
	if request_id < 0 or not _finished_requests.has(request_id):
		return {}
	return (_finished_requests[request_id] as Dictionary).duplicate(true)


static func consume_finished_request(request_id: int) -> Dictionary:
	var result := get_finished_request(request_id)
	if not result.is_empty():
		_finished_requests.erase(request_id)
	return result


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


static func _find_pending_request(
	npc_id: int,
	destination: Vector2
) -> Dictionary:
	for request in _requests:
		if int(request.get("npc_id", -1)) != npc_id:
			continue
		if StringName(str(request.get("status", STATUS_PENDING))) != STATUS_PENDING:
			continue

		var request_destination := request.get(
			"destination",
			Vector2.INF
		) as Vector2
		if request_destination.is_equal_approx(destination):
			return request

	return {}


static func _build_request_context(
	npc: Node,
	destination: Vector2
) -> Dictionary:
	var context: Dictionary = {
		"npc_id": npc.get_instance_id(),
		"destination": _format_vector(destination)
	}

	var state_variant: Variant = npc.get("current_state")
	context["state"] = int(state_variant) if state_variant is int else -1

	var target_shelf_variant: Variant = npc.get("_target_shelf")
	if target_shelf_variant is Shelf and is_instance_valid(target_shelf_variant):
		var target_shelf := target_shelf_variant as Shelf
		context["shelf_id"] = String(target_shelf.get_shelf_id())
		context["shelf_revision"] = target_shelf.get_revision()

	var queue_entry_shelf_variant: Variant = npc.get("_queue_entry_shelf")
	if (
		queue_entry_shelf_variant is Shelf
		and is_instance_valid(queue_entry_shelf_variant)
	):
		var queue_entry_shelf := queue_entry_shelf_variant as Shelf
		context["entry_shelf_id"] = String(queue_entry_shelf.get_shelf_id())
		context["entry_shelf_revision"] = queue_entry_shelf.get_revision()
	context["egress_pending"] = bool(npc.get("_queue_egress_route_pending"))

	return context


static func _format_vector(value: Vector2) -> String:
	return "%.1f,%.1f" % [value.x, value.y]


static func _sort_requests() -> void:
	_requests.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority: int = int(a.get("priority", 100))
		var b_priority: int = int(b.get("priority", 100))
		if a_priority != b_priority:
			return a_priority < b_priority
		return int(a.get("requested_msec", 0)) < int(b.get("requested_msec", 0))
	)


static func _trim_finished_requests() -> void:
	const MAX_FINISHED_REQUESTS: int = 160
	if _finished_requests.size() <= MAX_FINISHED_REQUESTS:
		return

	var ranked: Array[Dictionary] = []
	for request_id in _finished_requests.keys():
		var request := _finished_requests[request_id] as Dictionary
		ranked.append({
			"id": int(request_id),
			"requested_msec": int(request.get("requested_msec", 0))
		})

	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("requested_msec", 0)) < int(b.get("requested_msec", 0))
	)

	while _finished_requests.size() > MAX_FINISHED_REQUESTS and not ranked.is_empty():
		var oldest := ranked.pop_front() as Dictionary
		_finished_requests.erase(int(oldest.get("id", -1)))
