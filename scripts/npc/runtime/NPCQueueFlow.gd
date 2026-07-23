class_name NPCQueueFlow
extends RefCounted

const NPCQueueReservationControllerScript = preload("res://scripts/npc/runtime/NPCQueueReservationController.gd")
const NPCMovementReservationSystemScript = preload("res://scripts/npc/runtime/NPCMovementReservationSystem.gd")
const StoreRuntimeDebugProbeScript = preload("res://scripts/debug/StoreRuntimeDebugProbe.gd")
const EXIT_ORIGIN_SHELF_META: StringName = &"exit_origin_shelf"
const QUEUE_MOVE_PROBE_COOLDOWN_MSEC: int = 650
const QUEUE_EGRESS_TARGET_TOLERANCE: float = 3.0

var npc = null
var _next_queue_move_probe_msec: int = 0


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(npc_node) -> void:
	npc = npc_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_wait_in_queue(delta: float) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var queue_index := NPCQueueReservationControllerScript.index_of(npc)

	if queue_index < 0:
		enter_checkout_queue()
		return

	if queue_index != npc._last_queue_index:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var previous_index: int = npc._last_queue_index
		var previous_egress_target: Vector2 = npc._queue_egress_target_position

		npc._last_queue_index = queue_index
		npc._movement_route.clear()
		npc._movement_route_destination = Vector2.INF
		npc._is_moving_from_queue_to_cashier = false
		npc._queue_egress_target_position = Vector2.INF
		npc._queue_back_facing_done = false
		npc._queue_back_facing_logged = false
		_record_queue_probe(&"npc_queue_index_changed", {
			"previous_index": previous_index,
			"queue_index": queue_index,
			"queue_size": NPCQueueReservationControllerScript.size(),
			"egress_pending": npc._queue_egress_route_pending,
			"previous_egress_target": _format_vector(previous_egress_target)
		})

		if previous_index > queue_index and previous_index >= 0:
			npc._queue_advance_delay_timer = npc.QUEUE_ADVANCE_DELAY
			npc._queue_advance_clear_wait_timer = npc.QUEUE_ADVANCE_CLEAR_WAIT
			npc._queue_advance_waiting_for_clear = true

	if npc._is_moving_from_queue_to_cashier:
		process_queue_to_cashier(queue_index)
		return

	if npc._queue_egress_route_pending:
		process_shelf_egress_to_queue_lane(queue_index)
		return

	npc.target_position = get_queue_target()
	var has_shelf_egress_context: bool = (
		npc._queue_egress_route_pending
		or npc.has_meta(EXIT_ORIGIN_SHELF_META)
		or (
			npc._queue_entry_shelf != null
			and is_instance_valid(npc._queue_entry_shelf)
		)
	)

	if npc._queue_advance_delay_timer > 0.0:
		npc._queue_advance_delay_timer = maxf(0.0, npc._queue_advance_delay_timer - delta)
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		face_queue_forward(queue_index, "advance_delay")

		return

	if npc._queue_advance_waiting_for_clear:
		if is_queue_advance_path_clear(queue_index):
			npc._queue_advance_waiting_for_clear = false
		else:
			npc._queue_advance_clear_wait_timer = maxf(0.0, npc._queue_advance_clear_wait_timer - delta)
			npc._queue_advance_clear_wait_timer = npc.QUEUE_ADVANCE_CLEAR_WAIT

		if npc._queue_advance_waiting_for_clear:
			npc.velocity = Vector2.ZERO
			npc.move_and_slide()
			face_queue_forward(queue_index, "waiting_path_clear")
			return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var arrived: bool = npc.global_position.distance_to(npc.target_position) <= npc.QUEUE_SLOT_ARRIVAL_DISTANCE

	if not arrived:
		arrived = npc._move_to_with_arrival_threshold(npc.target_position, npc.QUEUE_SLOT_ARRIVAL_DISTANCE)
		_record_queue_move_probe(&"npc_queue_move_wait", {
			"queue_index": queue_index,
			"arrived": arrived,
			"target_kind": "queue_slot",
			"distance": snappedf(
				npc.global_position.distance_to(npc.target_position),
				0.01
			)
		})

	if (
		queue_index == 0
		and NPCQueueReservationControllerScript.size() <= 1
		and not npc._is_moving_from_queue_to_cashier
		and not has_shelf_egress_context
	):
		start_queue_to_cashier(queue_index)
		return

	if arrived and queue_index == 0:
		pass
		_clear_queue_entry_shelf_obstacle()
		start_queue_to_cashier(queue_index)
		return
	elif arrived:
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		_clear_queue_entry_shelf_obstacle()
		if not npc._queue_back_facing_done:
			npc._queue_back_facing_done = true
		if not npc._queue_back_facing_logged:
			face_queue_forward(queue_index, "arrived_back")
			npc._queue_back_facing_logged = true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_shelf_egress_to_queue_lane(queue_index: int) -> void:
	var queue_slot_target: Vector2 = get_queue_target()
	if queue_index == 0 and NPCQueueReservationControllerScript.size() <= 1:
		var solo_approach_marker: Vector2 = queue_slot_target
		var solo_blocking_context := (
			NPCMovementReservationSystemScript.get_blocking_context(
				npc,
				solo_approach_marker
			)
		)
		if bool(solo_blocking_context.get("blocked", false)):
			_wait_for_blocked_queue_egress(
				queue_index,
				queue_slot_target,
				solo_approach_marker,
				solo_blocking_context
			)
			return

		if (
			not npc._queue_egress_target_position.is_finite()
			or npc._queue_egress_target_position.distance_to(solo_approach_marker)
			> QUEUE_EGRESS_TARGET_TOLERANCE
		):
			npc._queue_egress_target_position = solo_approach_marker
			npc._movement_route.clear()
			npc._movement_route_destination = Vector2.INF
			npc.set_meta(&"path_possibly_invalid", true)
			_record_queue_probe(&"npc_queue_solo_shelf_egress", {
				"queue_index": queue_index,
				"queue_size": NPCQueueReservationControllerScript.size(),
				"queue_slot_target": _format_vector(queue_slot_target),
				"queue_approach_marker": _format_vector(solo_approach_marker)
			})

	var egress_target: Vector2 = npc._queue_egress_target_position
	var target_source: String = "cached"
	var resolved_egress_target: Vector2 = get_queue_egress_target(queue_index)
	if (
		not egress_target.is_finite()
		or (
			resolved_egress_target.is_finite()
			and egress_target.distance_to(resolved_egress_target)
			> QUEUE_EGRESS_TARGET_TOLERANCE
		)
	):
		var old_egress_target := egress_target
		egress_target = resolved_egress_target
		npc._queue_egress_target_position = egress_target
		target_source = "resolved"
		if old_egress_target.is_finite():
			npc._movement_route.clear()
			npc._movement_route_destination = Vector2.INF
			npc.set_meta(&"path_possibly_invalid", true)
			_record_queue_probe(&"npc_queue_egress_retarget", {
				"queue_index": queue_index,
				"old_egress_target": _format_vector(old_egress_target),
				"new_egress_target": _format_vector(egress_target),
				"queue_size": NPCQueueReservationControllerScript.size()
			})

	if not egress_target.is_finite():
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		_record_queue_move_probe(&"npc_queue_egress_invalid", {
			"queue_index": queue_index,
			"queue_size": NPCQueueReservationControllerScript.size(),
			"target_source": target_source,
			"queue_slot_target": _format_vector(queue_slot_target)
		})
		return

	var blocking_context := (
		NPCMovementReservationSystemScript.get_blocking_context(
			npc,
			egress_target
		)
	)
	if bool(blocking_context.get("blocked", false)):
		_wait_for_blocked_queue_egress(
			queue_index,
			queue_slot_target,
			egress_target,
			blocking_context
		)
		return

	npc.target_position = egress_target
	var arrived: bool = (
		egress_target.is_finite()
		and npc.global_position.distance_to(egress_target)
		<= npc.QUEUE_SLOT_ARRIVAL_DISTANCE
	)

	if not arrived:
		arrived = npc._move_to_with_arrival_threshold(
			egress_target,
			npc.QUEUE_SLOT_ARRIVAL_DISTANCE
		)
		_record_queue_move_probe(&"npc_queue_egress_wait", {
			"queue_index": queue_index,
			"arrived": arrived,
			"target_kind": "queue_egress",
			"egress_pending": npc._queue_egress_route_pending,
			"moving_to_cashier": npc._is_moving_from_queue_to_cashier,
			"has_origin_shelf": npc.has_meta(EXIT_ORIGIN_SHELF_META),
			"distance": snappedf(
				npc.global_position.distance_to(egress_target),
				0.01
			),
			"egress_target": _format_vector(egress_target),
			"egress_target_source": target_source,
			"queue_slot_target": _format_vector(queue_slot_target)
		})

	if not arrived:
		return

	npc.velocity = Vector2.ZERO
	npc.move_and_slide()
	_clear_queue_entry_shelf_obstacle()
	npc.target_position = queue_slot_target
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	npc.set_meta(&"path_possibly_invalid", true)
	_record_queue_probe(&"npc_queue_egress_complete", {
		"queue_index": queue_index,
		"queue_slot_target": _format_vector(npc.target_position),
		"queue_approach_marker": _format_vector(egress_target)
	})
	if queue_index == 0:
		start_queue_to_cashier(queue_index)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func join_queue() -> void:
	NPCQueueReservationControllerScript.join(npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func leave_queue() -> void:
	NPCQueueReservationControllerScript.leave(npc)
	npc._last_queue_index = -1
	npc._is_moving_from_queue_to_cashier = false
	npc._queue_entry_shelf = null
	npc._queue_egress_route_pending = false
	npc._queue_egress_target_position = Vector2.INF


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func enter_checkout_queue() -> void:
	if npc._queue_entry_shelf != null and is_instance_valid(npc._queue_entry_shelf):
		npc.set_meta(EXIT_ORIGIN_SHELF_META, npc._queue_entry_shelf)
	join_queue()
	npc._last_queue_index = NPCQueueReservationControllerScript.index_of(npc)
	npc._is_moving_from_queue_to_cashier = false
	npc.target_position = get_queue_target()
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	_record_queue_probe(&"npc_queue_enter", {
		"queue_index": npc._last_queue_index,
		"queue_target": _format_vector(npc.target_position),
		"has_origin_shelf": npc.has_meta(EXIT_ORIGIN_SHELF_META)
	})
	npc._set_state(NPC.State.WAIT_IN_QUEUE)
	npc._target_shelf = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_ready_for_checkout_service() -> bool:
	if npc.is_queued_for_deletion():
		return false

	if not NPCQueueReservationControllerScript.is_front(npc):
		return false

	if npc.current_state == NPC.State.CHECKOUT:
		return true

	if npc.current_state != NPC.State.WAIT_IN_QUEUE:
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cashier_target := get_cashier_target()
	return (
		npc.global_position.distance_to(cashier_target)
		<= _get_cashier_arrival_distance()
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func mark_checkout_ready() -> void:
	if not is_ready_for_checkout_service():
		return

	npc.velocity = Vector2.ZERO
	npc._is_moving_from_queue_to_cashier = false
	npc.target_position = get_cashier_target()
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	npc._set_state(NPC.State.CHECKOUT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func start_queue_to_cashier(queue_index: int) -> void:
	npc.velocity = Vector2.ZERO
	npc.move_and_slide()
	face_queue_forward(queue_index, "arrived_front")
	npc._is_moving_from_queue_to_cashier = true
	npc.target_position = get_cashier_target()
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	_record_queue_probe(&"npc_queue_to_cashier", {
		"queue_index": queue_index,
		"queue_target": _format_vector(get_queue_target()),
		"cashier_target": _format_vector(npc.target_position),
		"cashier_face_target": _format_vector(get_cashier_face_target())
	})
	if is_ready_for_checkout_service():
		mark_checkout_ready()
		return


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _begin_direct_cashier_from_shelf(queue_index: int, reason: String) -> void:
	var previous_egress_target: Vector2 = npc._queue_egress_target_position
	npc._queue_egress_route_pending = false
	npc._queue_egress_target_position = Vector2.INF
	npc._is_moving_from_queue_to_cashier = true
	npc.target_position = get_cashier_target()
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	npc.set_meta(&"path_possibly_invalid", true)
	_record_queue_probe(&"npc_queue_solo_direct_cashier", {
		"queue_index": queue_index,
		"queue_size": NPCQueueReservationControllerScript.size(),
		"reason": reason,
		"previous_egress_target": _format_vector(previous_egress_target),
		"cashier_target": _format_vector(npc.target_position),
		"queue_slot_target": _format_vector(get_queue_target())
	})


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _redirect_blocked_approach_to_queue_slot(
	queue_index: int,
	queue_slot_target: Vector2,
	queue_approach_marker: Vector2,
	blocking_context: Dictionary
) -> void:
	npc._queue_egress_route_pending = false
	npc._queue_egress_target_position = Vector2.INF
	npc._is_moving_from_queue_to_cashier = false
	npc.target_position = queue_slot_target
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	npc.set_meta(&"path_possibly_invalid", true)

	var context: Dictionary = {
		"queue_index": queue_index,
		"queue_size": NPCQueueReservationControllerScript.size(),
		"action": "target_queue_slot",
		"queue_slot_target": _format_vector(queue_slot_target),
		"queue_approach_marker": _format_vector(queue_approach_marker)
	}
	for key in blocking_context:
		context["blocking_%s" % String(key)] = blocking_context[key]
	_record_queue_probe(&"npc_queue_approach_blocked", context)


func _wait_for_blocked_queue_egress(
	queue_index: int,
	queue_slot_target: Vector2,
	queue_approach_marker: Vector2,
	blocking_context: Dictionary
) -> void:
	npc.velocity = Vector2.ZERO
	npc.move_and_slide()
	npc.target_position = queue_approach_marker
	npc._queue_egress_route_pending = true
	npc._queue_egress_target_position = queue_approach_marker

	var context: Dictionary = {
		"queue_index": queue_index,
		"queue_size": NPCQueueReservationControllerScript.size(),
		"action": "wait_for_queue_egress_clear",
		"queue_slot_target": _format_vector(queue_slot_target),
		"queue_approach_marker": _format_vector(queue_approach_marker)
	}
	for key in blocking_context:
		context["blocking_%s" % String(key)] = blocking_context[key]
	_record_queue_probe(&"npc_queue_egress_blocked_wait", context)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _clear_queue_entry_shelf_obstacle() -> void:
	if npc.has_meta(EXIT_ORIGIN_SHELF_META):
		npc.remove_meta(EXIT_ORIGIN_SHELF_META)
	npc._queue_entry_shelf = null
	npc._queue_egress_route_pending = false
	npc._queue_egress_target_position = Vector2.INF


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _record_queue_probe(
	label: StringName,
	extra_context: Dictionary
) -> void:
	var context: Dictionary = {
		"npc_id": npc.get_instance_id(),
		"state": int(npc.current_state),
		"position": _format_vector(npc.global_position),
		"target": _format_vector(npc.target_position),
		"route_points": npc._movement_route.size(),
		"route_destination": _format_vector(npc._movement_route_destination),
		"next_route_point": _format_vector(
			npc._movement_route[0]
			if not npc._movement_route.is_empty()
			else Vector2.INF
		),
		"queue_size": NPCQueueReservationControllerScript.size(),
		"last_queue_index": npc._last_queue_index,
		"egress_pending": npc._queue_egress_route_pending,
		"egress_target": _format_vector(npc._queue_egress_target_position),
		"moving_to_cashier": npc._is_moving_from_queue_to_cashier
	}

	if npc._queue_entry_shelf != null and is_instance_valid(npc._queue_entry_shelf):
		context["entry_shelf_id"] = String(npc._queue_entry_shelf.get_shelf_id())
		context["entry_shelf_revision"] = npc._queue_entry_shelf.get_revision()

	for key in extra_context:
		context[key] = extra_context[key]

	StoreRuntimeDebugProbeScript.record(label, 0.0, context, 0.0)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _record_queue_move_probe(
	label: StringName,
	extra_context: Dictionary
) -> void:
	var now_msec := Time.get_ticks_msec()
	if now_msec < _next_queue_move_probe_msec:
		return

	_next_queue_move_probe_msec = now_msec + QUEUE_MOVE_PROBE_COOLDOWN_MSEC
	_record_queue_probe(label, extra_context)


func _format_vector(value: Vector2) -> String:
	return "%.1f,%.1f" % [value.x, value.y]


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_queue_to_cashier(queue_index: int) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var cashier_target := get_cashier_target()
	npc.target_position = cashier_target
	var cashier_arrival_distance := _get_cashier_arrival_distance()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var arrived: bool = (
		npc.global_position.distance_to(cashier_target)
		<= cashier_arrival_distance
	)

	if not arrived:
		arrived = npc._move_to_with_arrival_threshold(
			cashier_target,
			cashier_arrival_distance
		)
		_record_queue_move_probe(&"npc_queue_move_wait", {
			"queue_index": queue_index,
			"arrived": arrived,
			"target_kind": "cashier",
			"queue_target": _format_vector(get_queue_target()),
			"cashier_target": _format_vector(cashier_target),
			"next_route_point": _format_vector(
				npc._movement_route[0]
				if not npc._movement_route.is_empty()
				else Vector2.INF
			),
			"distance": snappedf(
				npc.global_position.distance_to(cashier_target),
				0.01
			)
		})

	if arrived:
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		_clear_queue_entry_shelf_obstacle()
		face_queue_forward(queue_index, "arrived_cashier")
		mark_checkout_ready()


func _get_cashier_arrival_distance() -> float:
	return maxf(npc.QUEUE_ACTION_DISTANCE, npc.QUEUE_SLOT_ARRIVAL_DISTANCE)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_cashier_target() -> Vector2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store: Node = npc._get_store_route_provider()

	if store != null and store.has_method("get_npc_cashier_target"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var result: Variant = store.call("get_npc_cashier_target", NPC.counter_position)

		if result is Vector2:
			return result as Vector2

	return NPC.counter_position


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_cashier_face_target() -> Vector2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("unused_variable")
	var standing_target := get_cashier_target()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store: Node = npc._get_store_route_provider()

	if store != null and store.has_method("get_npc_cashier_face_target"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var result: Variant = store.call("get_npc_cashier_face_target", standing_target + Vector2(0.0, -24.0))

		if result is Vector2:
			return result as Vector2

	return standing_target + Vector2(0.0, -24.0)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_queue_target() -> Vector2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var position_in_queue := NPCQueueReservationControllerScript.index_of(npc)

	if position_in_queue < 0:
		return NPC.counter_position

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store: Node = npc._get_store_route_provider()

	if store != null and store.has_method("get_npc_queue_target"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var result: Variant = store.call("get_npc_queue_target", position_in_queue, NPC.counter_position)

		if result is Vector2:
			return result as Vector2

	return NPCQueueReservationControllerScript.get_target(npc, NPC.counter_position)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_queue_egress_target(queue_index: int) -> Vector2:
	var queue_target := get_queue_target()
	var store: Node = npc._get_store_route_provider()
	if store != null and store.has_method("get_npc_queue_egress_target"):
		var result: Variant = store.call(
			"get_npc_queue_egress_target",
			queue_index,
			queue_target
		)
		if result is Vector2:
			return result as Vector2

	return queue_target


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
@warning_ignore("unused_parameter")
func face_queue_forward(queue_index: int, reason: String) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("unused_variable")
	var standing_target := get_queue_target()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var face_target := get_cashier_face_target()

	if not face_target.is_finite() or face_target == Vector2.ZERO:
		face_target = npc.target_position + Vector2(0.0, -24.0)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direction: Vector2 = face_target - npc.global_position
	pass

	if direction.length() <= 0.1:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	@warning_ignore("unused_variable")
	var previous_direction: CharacterSprite.Direction = npc._move_direction
	npc._move_direction = npc._get_direction(direction)
	npc._update_character_sprite()
	pass


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_queue_advance_path_clear(queue_index: int) -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store: Node = npc._get_store_route_provider()

	if (
		store != null
		and store.has_method("get_npc_checkout_exit_blocking_context")
	):
		var blocking_context: Variant = store.call(
			"get_npc_checkout_exit_blocking_context",
			npc,
			queue_index
		)
		if blocking_context is Dictionary:
			var context := blocking_context as Dictionary
			if bool(context.get("blocked", false)):
				_record_queue_move_probe(
					&"npc_queue_advance_blocked",
					context
				)
				return false

	if store == null or not store.has_method("get_npc_route_to_queue_target_from"):
		return true

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route_variant: Variant = store.call("get_npc_route_to_queue_target_from", npc.global_position, queue_index)

	if not (route_variant is Array):
		_record_queue_move_probe(&"npc_queue_advance_blocked", {
			"reason": "queue_route_invalid",
			"queue_index": queue_index
		})
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route := route_variant as Array
	var is_clear := not route.is_empty()
	if not is_clear:
		_record_queue_move_probe(&"npc_queue_advance_blocked", {
			"reason": "queue_route_empty",
			"queue_index": queue_index
		})
	return is_clear
