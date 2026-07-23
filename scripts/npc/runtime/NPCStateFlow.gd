class_name NPCStateFlow
extends RefCounted

const NPCShoppingJobScript = preload("res://scripts/npc/runtime/NPCShoppingJob.gd")
const StoreRuntimeDebugProbeScript = preload("res://scripts/debug/StoreRuntimeDebugProbe.gd")
const PERF_SHELF_THRESHOLD_MSEC: float = 16.0
const OUT_OF_STOCK_WARNING_SECONDS: float = 10.0
const OUT_OF_STOCK_EXIT_SECONDS: float = 15.0
const SHELF_APPROACH_PROBE_COOLDOWN_MSEC: int = 650
const SHELF_APPROACH_ARRIVAL_DISTANCE: float = 6.0
const SHELF_BODY_ADJACENCY_DISTANCE: float = 18.0
const SHELF_TAKE_ACCESS_ARRIVAL_DISTANCE: float = 1.0
const SHELF_FINAL_ACCESS_MICRO_MOVE_DISTANCE: float = 8.0
const ENTER_STAGING_PROBE_COOLDOWN_MSEC: int = 650

var npc = null
var _next_shelf_approach_probe_msec: int = 0
var _next_enter_staging_probe_msec: int = 0


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(npc_node) -> void:
	npc = npc_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_enter() -> void:
	npc._shopping_job.wanted_item = npc.item_to_buy
	npc._shopping_job.set_state(NPCShoppingJobScript.STATE_CHOOSING_ITEM)
	npc._enter_pause_timer += npc.get_process_delta_time()

	if npc._enter_pause_timer < npc.ENTER_PAUSE:
		return

	if _move_to_store_entry_staging():
		return

	npc._choose_available_item_to_buy()
	npc._shopping_job.wanted_item = npc.item_to_buy
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var target_shelf: Shelf = npc._find_reachable_matching_shelf()

	if target_shelf == null:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var fallback_shelf: Shelf = npc._find_matching_shelf()
		if fallback_shelf != null:
			_begin_wait_for_shelf("enter_no_shelf_fallback")
		else:
			_begin_wait_for_shelf("enter_no_shelf")
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var visit_position: Vector2 = npc._get_shelf_visit_position(target_shelf)

	if not visit_position.is_finite():
		npc._show_dialog("I can't reach that shelf.")
		npc._dialog_timer = npc.DIALOG_DURATION
		npc._exit_after_checkout = false
		npc.target_position = npc._get_exit_position()
		set_state(NPC.State.EXIT)
		return

	npc._target_shelf = target_shelf
	npc._shopping_job.set_target_shelf(target_shelf)
	npc.target_position = visit_position
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var route_info = get_route_travel_info(visit_position)
	npc.shelf_route_ready.emit(
		npc,
		float(route_info.get("travel_seconds", 0.0))
	)
	set_state(NPC.State.WALK_TO_SHELF)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _move_to_store_entry_staging() -> bool:
	var staging_position: Vector2 = npc._get_store_path_position()
	if not staging_position.is_finite():
		return false

	var distance: float = npc.global_position.distance_to(staging_position)
	if distance <= npc.ARRIVAL_THRESHOLD:
		return false

	npc.target_position = staging_position
	var arrived: bool = npc._move_to_with_arrival_threshold(
		staging_position,
		npc.ARRIVAL_THRESHOLD
	)
	_record_enter_staging_probe(arrived, staging_position, distance)
	return not arrived


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_route_travel_seconds(destination: Vector2) -> float:
	return float(
		get_route_travel_info(destination).get(
			"travel_seconds",
			0.0
		)
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_route_travel_info(destination: Vector2) -> Dictionary:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var distance = 0.0
	if destination.is_finite():
		distance = npc.global_position.distance_to(destination)

	if npc.SPEED <= 0.0:
		return {
			"travel_seconds": 0.0,
			"route_points": 0,
			"route_distance": distance
		}

	return {
		"travel_seconds": distance / npc.SPEED,
		"route_points": 0,
		"route_distance": distance
	}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_walk_to_shelf() -> void:
	npc._shopping_job.set_state(NPCShoppingJobScript.STATE_MOVING_TO_SHELF)
	if not npc._is_target_shelf_valid():
		_record_shelf_probe(&"npc_shelf_target_invalid", {
			"reason": "walk_shelf_lost"
		})
		if _handle_shelf_wait_or_leave("walk_shelf_lost"):
			return

	var shelf_arrival_distance: float = _get_shelf_approach_access_arrival_distance()
	var shelf_access_position := _get_shelf_take_access_position()
	if shelf_access_position.is_finite():
		npc.target_position = shelf_access_position
	if (
		npc.global_position.distance_to(npc.target_position)
		<= shelf_arrival_distance
	):
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		npc._face_target_shelf()
		set_state(NPC.State.SEARCH_ITEM)
		return

	var arrived: bool = npc._move_to_with_arrival_threshold(
		npc.target_position,
		shelf_arrival_distance
	)
	if not arrived and _can_micro_move_to_shelf_access():
		_record_shelf_probe(
			&"npc_shelf_final_access_blocked_by_empty_route",
			_get_shelf_final_access_context({
				"movement_block_reason": "empty_store_route",
				"movement_phase": "walk_to_shelf"
			})
		)
		var final_access_result := _micro_move_to_shelf_access(
			shelf_arrival_distance
		)
		arrived = bool(final_access_result.get("arrived", false))
		if (
			not arrived
			and _is_shelf_take_body_adjacent()
			and bool(final_access_result.get("blocked_by_target_shelf", false))
		):
			arrived = true
	_record_shelf_approach_probe(arrived)
	if arrived:
		npc._face_target_shelf()
		set_state(NPC.State.SEARCH_ITEM)


func _record_enter_staging_probe(
	arrived: bool,
	staging_position: Vector2,
	distance: float
) -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec < _next_enter_staging_probe_msec:
		return

	_next_enter_staging_probe_msec = now_msec + ENTER_STAGING_PROBE_COOLDOWN_MSEC
	StoreRuntimeDebugProbeScript.record(
		&"npc_enter_staging_move",
		0.0,
		{
			"arrived": arrived,
			"npc_id": npc.get_instance_id(),
			"position": _format_vector(npc.global_position),
			"staging_position": _format_vector(staging_position),
			"distance": snappedf(distance, 0.01)
		},
		0.0
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_search_item(delta: float) -> void:
	if not npc._is_target_shelf_valid():
		_handle_shelf_wait_or_leave("search_shelf_lost")
		return

	npc.velocity = Vector2.ZERO
	npc.move_and_slide()
	npc._search_timer += delta

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var stocked_shelf = _find_reachable_stocked_shelf()

	if stocked_shelf != null:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var visit_position: Vector2 = npc._get_shelf_visit_position(stocked_shelf)

		if stocked_shelf != npc._target_shelf:
			npc._target_shelf = stocked_shelf
			npc._shopping_job.set_target_shelf(stocked_shelf)
			npc.target_position = visit_position
			set_state(NPC.State.WALK_TO_SHELF)
			return

		if npc._search_timer >= npc.SHELF_SEARCH_MIN_TIME:
			set_state(NPC.State.TAKE_ITEM)
		return

	if (
		npc._search_timer >= OUT_OF_STOCK_WARNING_SECONDS
		and not npc._search_announced
	):
		npc._search_announced = true
		npc._show_dialog(
			"This is taking a while... Are you going to restock it?"
		)

	if npc._search_timer < OUT_OF_STOCK_EXIT_SECONDS:
		return

	npc._show_dialog(
		"I'm disappointed. I'll shop somewhere else."
	)
	npc._dialog_timer = npc.DIALOG_DURATION
	npc._exit_after_checkout = false
	npc.target_position = npc._get_exit_position()
	set_state(NPC.State.EXIT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_browse_item(delta: float) -> void:
	npc._search_timer += delta

	if npc._search_timer < 8.0:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var alt_item: String = npc._find_alternative_item()

	if alt_item != "":
		npc._browse_item = alt_item
		npc.item_to_buy = alt_item
		npc._show_dialog("This one will do!")
		set_state(NPC.State.TAKE_ITEM)
	else:
		npc._show_dialog("Nothing here for me...")
		npc._exit_after_checkout = false
		npc.target_position = npc._get_exit_position()
		set_state(NPC.State.EXIT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_take_item() -> void:
	npc._shopping_job.set_state(NPCShoppingJobScript.STATE_PICKING_UP_ITEM)
	if not npc._is_target_shelf_valid() and not npc._has_taken_shelf_item:
		_record_shelf_probe(&"npc_shelf_target_invalid", {
			"reason": "take_shelf_lost"
		})
		if _handle_shelf_wait_or_leave("take_shelf_lost"):
			return

	if npc._has_taken_shelf_item:
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		npc._take_item_pause_timer += npc.get_process_delta_time()

		if npc._take_item_pause_timer < npc.SHELF_TAKE_PAUSE_TIME:
			return

		if npc._target_shelf != null and is_instance_valid(npc._target_shelf):
			npc._queue_entry_shelf = npc._target_shelf
			npc._queue_egress_route_pending = true
			npc._queue_egress_target_position = Vector2.INF

		npc._take_item_pause_timer = 0.0
		npc._enter_checkout_queue()
		return

	var shelf_action_distance: float = _get_shelf_take_arrival_distance()
	var shelf_take_arrival_distance: float = _get_shelf_take_access_arrival_distance()
	var shelf_access_position := _get_shelf_take_access_position()
	if shelf_access_position.is_finite():
		npc.target_position = shelf_access_position

	_record_shelf_take_range_probe(shelf_action_distance)
	if (
		not _is_shelf_take_position_valid(shelf_take_arrival_distance)
		or not _is_shelf_take_body_adjacent()
	):
		var moved_to_access := false
		var final_access_result: Dictionary = {}
		if npc.target_position.is_finite():
			moved_to_access = npc._move_to_with_arrival_threshold(
				npc.target_position,
				shelf_take_arrival_distance
			)
			if (
				not moved_to_access
				and _can_micro_move_to_shelf_access()
			):
				_record_shelf_probe(
					&"npc_shelf_final_access_blocked_by_empty_route",
					_get_shelf_final_access_context({
						"movement_block_reason": "empty_store_route"
					})
				)
				final_access_result = _micro_move_to_shelf_access(
					shelf_take_arrival_distance
				)
				moved_to_access = bool(final_access_result.get("arrived", false))

		var body_adjacent := _is_shelf_take_body_adjacent()
		var position_valid := _is_shelf_take_position_valid(
			shelf_take_arrival_distance
		)
		var reached_by_collision := (
			body_adjacent
			and bool(final_access_result.get("blocked_by_target_shelf", false))
		)
		if (
			not body_adjacent
			or (not position_valid and not reached_by_collision)
		):
			var wait_context := _get_shelf_final_access_context({
				"action_distance": shelf_action_distance,
				"take_arrival_distance": shelf_take_arrival_distance,
				"access_target": _format_vector(npc.target_position),
				"moved_to_access": moved_to_access,
				"body_distance": snappedf(_get_shelf_body_distance(), 0.01),
				"distance_to_access": snappedf(
					npc.global_position.distance_to(npc.target_position),
					0.01
				),
				"position_valid": position_valid,
				"body_adjacent": body_adjacent,
				"reached_by_collision": reached_by_collision
			})
			for key in final_access_result:
				wait_context[key] = final_access_result[key]
			_record_shelf_probe(&"npc_shelf_take_waiting_for_range", wait_context)
			return

	npc._face_target_shelf()

	if npc._take_requested_items_from_shelves():
		_record_shelf_probe(&"npc_shelf_take_success", {})
		npc._has_taken_shelf_item = true
		npc._take_item_pause_timer = 0.0
		npc._show_dialog("I'll take this.")
		return

	# Another NPC may have taken the final item between SEARCH_ITEM and
	# TAKE_ITEM. Return to the same hidden 15-second waiting behavior instead
	# of leaving immediately.
	npc._show_dialog("Someone must have taken it already.")
	set_state(NPC.State.SEARCH_ITEM)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _record_shelf_approach_probe(arrived: bool) -> void:
	var now_msec := Time.get_ticks_msec()
	if now_msec < _next_shelf_approach_probe_msec:
		return

	_next_shelf_approach_probe_msec = now_msec + SHELF_APPROACH_PROBE_COOLDOWN_MSEC
	_record_shelf_probe(&"npc_shelf_approach", {
		"arrived": arrived
	})


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _record_shelf_probe(
	label: StringName,
	extra_context: Dictionary
) -> void:
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
		"route_points": npc._movement_route.size(),
		"item": npc.item_to_buy
	}

	if (
		npc._movement_route != null
		and not npc._movement_route.is_empty()
	):
		context["next_route_point"] = _format_vector(npc._movement_route[0])

	if npc._target_shelf != null and is_instance_valid(npc._target_shelf):
		context["shelf_id"] = String(npc._target_shelf.get_shelf_id())
		context["shelf_revision"] = npc._target_shelf.get_revision()
		context["shelf_position"] = _format_vector(
			npc._target_shelf.global_position
		)
		context["shelf_distance"] = snappedf(
			npc.global_position.distance_to(npc._target_shelf.global_position),
			0.01
		)
		context["npc_path_ready"] = bool(
			npc._target_shelf.get_meta("npc_path_ready", false)
		)
		var access_variant: Variant = npc._target_shelf.get_meta(
			&"npc_access_point",
			Vector2.INF
		)
		if access_variant is Vector2:
			context["npc_access_point"] = _format_vector(access_variant as Vector2)
		context["npc_access_source"] = str(
			npc._target_shelf.get_meta(&"npc_access_source", "")
		)
		context["npc_access_port_id"] = str(
			npc._target_shelf.get_meta(&"npc_access_port_id", "")
		)
		context["npc_access_checkout_source"] = str(
			npc._target_shelf.get_meta(&"npc_access_checkout_source", "")
		)

	for key in extra_context:
		context[key] = extra_context[key]

	StoreRuntimeDebugProbeScript.record(label, 0.0, context, 0.0)


func _get_shelf_final_access_context(extra_context: Dictionary = {}) -> Dictionary:
	var context: Dictionary = {
		"distance_to_access": snappedf(
			npc.global_position.distance_to(_get_shelf_take_access_position()),
			0.01
		),
		"body_distance": snappedf(_get_shelf_body_distance(), 0.01),
		"body_adjacent": _is_shelf_take_body_adjacent(),
		"route_points": npc._movement_route.size(),
		"movement_block_reason": "",
		"pending_path_request": false,
		"no_route_retry_active": false
	}

	if npc._route_controller != null:
		context["pending_path_request"] = (
			not npc._route_controller._pending_path_request.is_empty()
		)
		context["no_route_retry_active"] = (
			npc._route_controller._no_route_retry_destination.is_finite()
			and Time.get_ticks_msec() < npc._route_controller._next_no_route_retry_msec
		)

	var collision_shape := npc.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		context["npc_collision_shape_disabled"] = collision_shape.disabled
		context["npc_collision_shape_position"] = _format_vector(collision_shape.position)
		context["npc_collision_shape_global_position"] = _format_vector(
			collision_shape.global_position
		)
		var rectangle := collision_shape.shape as RectangleShape2D
		if rectangle != null:
			context["npc_collision_shape_size"] = _format_vector(rectangle.size)

	var collision_context := _get_slide_collision_context()
	for key in collision_context:
		context[key] = collision_context[key]

	for key in extra_context:
		context[key] = extra_context[key]

	return context


func _get_slide_collision_context() -> Dictionary:
	var collision_count: int = npc.get_slide_collision_count()
	var context: Dictionary = {
		"slide_collisions": collision_count
	}
	if collision_count <= 0:
		return context

	var collision: KinematicCollision2D = npc.get_slide_collision(0)
	if collision == null:
		return context

	context["collision_position"] = _format_vector(collision.get_position())
	context["collision_normal"] = _format_vector(collision.get_normal())
	context["collision_travel"] = _format_vector(collision.get_travel())
	context["collision_remainder"] = _format_vector(collision.get_remainder())

	var collider: Object = collision.get_collider()
	if collider is Node:
		var collider_node := collider as Node
		context["collider_name"] = String(collider_node.name)
		context["collider_path"] = String(collider_node.get_path())
		var collider_owner := collider_node.get_owner()
		if collider_owner != null:
			context["collider_owner"] = String(collider_owner.name)

	return context


func _can_micro_move_to_shelf_access() -> bool:
	if npc.current_state not in [
		NPC.State.WALK_TO_SHELF,
		NPC.State.TAKE_ITEM
	]:
		return false
	if not npc._movement_route.is_empty():
		return false
	if not npc.target_position.is_finite():
		return false
	if not _is_targeting_selected_shelf_access():
		return false
	return (
		npc.global_position.distance_to(npc.target_position)
		<= SHELF_FINAL_ACCESS_MICRO_MOVE_DISTANCE
	)


func _is_targeting_selected_shelf_access() -> bool:
	var access_position := _get_shelf_take_access_position()
	if not access_position.is_finite():
		return false
	return npc.target_position.distance_to(access_position) <= 0.1


func _micro_move_to_shelf_access(arrival_distance: float) -> Dictionary:
	var before_move: Vector2 = npc.global_position
	var before_distance: float = before_move.distance_to(npc.target_position)
	var arrived := NPCMovement.move_to(
		npc,
		npc.target_position,
		npc.SPEED,
		arrival_distance
	)
	var after_distance: float = npc.global_position.distance_to(npc.target_position)
	var moved_distance: float = before_move.distance_to(npc.global_position)
	var collision_context := _get_slide_collision_context()
	var blocked_by_target_shelf := _is_collision_with_target_shelf(collision_context)
	var context := _get_shelf_final_access_context({
		"arrived": arrived,
		"before_distance": snappedf(before_distance, 0.01),
		"after_distance": snappedf(after_distance, 0.01),
		"moved_distance": snappedf(moved_distance, 0.01),
		"blocked_by_target_shelf": blocked_by_target_shelf,
		"movement_block_reason": (
			"target_shelf_collision"
			if blocked_by_target_shelf
			else ("collision" if int(collision_context.get("slide_collisions", 0)) > 0 else "")
		)
	})
	for key in collision_context:
		context[key] = collision_context[key]

	_record_shelf_probe(&"npc_shelf_final_access_move", context)
	return context


func _is_collision_with_target_shelf(collision_context: Dictionary) -> bool:
	if npc._target_shelf == null or not is_instance_valid(npc._target_shelf):
		return false

	var collider_path := String(collision_context.get("collider_path", ""))
	if collider_path == "":
		return false

	var target_path := String(npc._target_shelf.get_path())
	return collider_path.begins_with(target_path)


func _record_shelf_take_range_probe(action_distance: float) -> void:
	var context: Dictionary = {
		"action_distance": snappedf(action_distance, 0.01),
		"within_target_action_distance": (
			npc.global_position.distance_to(npc.target_position)
			<= action_distance
		),
		"body_distance": snappedf(_get_shelf_body_distance(), 0.01),
		"body_adjacent": _is_shelf_take_body_adjacent()
	}
	if npc._target_shelf != null and is_instance_valid(npc._target_shelf):
		var access_variant: Variant = npc._target_shelf.get_meta(
			&"npc_access_point",
			Vector2.INF
		)
		if access_variant is Vector2:
			var access_position := access_variant as Vector2
			context["distance_to_access"] = snappedf(
				npc.global_position.distance_to(access_position),
				0.01
			)
			if npc._target_shelf.has_method("get_body_distance_to"):
				context["access_body_distance"] = snappedf(
					float(npc._target_shelf.call(
						"get_body_distance_to",
						access_position
					)),
					0.01
				)
		context["access_port_id"] = str(
			npc._target_shelf.get_meta(&"npc_access_port_id", "")
		)
		context["access_side"] = str(
			npc._target_shelf.get_meta(&"npc_access_side", "")
		)
		var access_port_id := StringName(str(
			npc._target_shelf.get_meta(&"npc_access_port_id", "")
		))
		if (
			access_port_id != StringName()
			and npc._target_shelf.has_method("get_interaction_port")
		):
			var port: Dictionary = npc._target_shelf.get_interaction_port(access_port_id)
			var raw_marker_position := (
				port.get("raw_marker_position", Vector2.INF) as Vector2
			)
			var port_position := port.get("position", Vector2.INF) as Vector2
			if port_position.is_finite():
				context["selected_port_position"] = _format_vector(port_position)
				context["selected_port_body_distance"] = snappedf(
					float(port.get("port_body_distance", INF)),
					0.01
				)
			if raw_marker_position.is_finite():
				context["selected_raw_marker_position"] = _format_vector(
					raw_marker_position
				)
				context["selected_raw_marker_body_distance"] = snappedf(
					float(port.get("raw_marker_body_distance", INF)),
					0.01
				)
				context["selected_marker_fit_distance"] = snappedf(
					float(port.get("marker_fit_distance", 0.0)),
					0.01
				)
	_record_shelf_probe(&"npc_shelf_take_range_check", context)


func _format_vector(value: Vector2) -> String:
	return "%.1f,%.1f" % [value.x, value.y]


func _get_shelf_approach_arrival_distance() -> float:
	return maxf(
		SHELF_APPROACH_ARRIVAL_DISTANCE,
		maxf(
			npc.SHELF_VISIT_ARRIVAL_DISTANCE,
			npc.SHELF_ACTION_DISTANCE
		)
	)


func _get_shelf_approach_access_arrival_distance() -> float:
	return SHELF_TAKE_ACCESS_ARRIVAL_DISTANCE


func _get_shelf_take_arrival_distance() -> float:
	return maxf(
		SHELF_APPROACH_ARRIVAL_DISTANCE,
		maxf(
			npc.SHELF_VISIT_ARRIVAL_DISTANCE,
			npc.SHELF_ACTION_DISTANCE
		)
	)


func _get_shelf_take_access_arrival_distance() -> float:
	return SHELF_TAKE_ACCESS_ARRIVAL_DISTANCE


func _get_shelf_take_access_position() -> Vector2:
	if npc._target_shelf == null or not is_instance_valid(npc._target_shelf):
		return npc.target_position

	var access_port_id := StringName(str(
		npc._target_shelf.get_meta(&"npc_access_port_id", "")
	))
	if (
		access_port_id != StringName()
		and npc._target_shelf.has_method("get_interaction_port")
	):
		var port: Dictionary = npc._target_shelf.get_interaction_port(
			access_port_id
		)
		var port_position := port.get("position", Vector2.INF) as Vector2
		if port_position.is_finite():
			return port_position

	var access_variant: Variant = npc._target_shelf.get_meta(
		&"npc_access_point",
		Vector2.INF
	)
	if access_variant is Vector2:
		var access_position := access_variant as Vector2
		if access_position.is_finite():
			return access_position

	return npc.target_position


func _is_shelf_take_position_valid(action_distance: float) -> bool:
	var access_position := _get_shelf_take_access_position()
	if not access_position.is_finite():
		return false
	return npc.global_position.distance_to(access_position) <= action_distance


func _is_shelf_take_body_adjacent() -> bool:
	return _get_shelf_body_distance() <= SHELF_BODY_ADJACENCY_DISTANCE


func _get_shelf_body_distance() -> float:
	if npc._target_shelf == null or not is_instance_valid(npc._target_shelf):
		return INF
	if not npc._target_shelf.has_method("get_body_distance_to"):
		return npc.global_position.distance_to(npc._target_shelf.global_position)
	return float(npc._target_shelf.call(
		"get_body_distance_to",
		npc.global_position
	))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_checkout(delta: float) -> void:
	npc._shopping_job.set_state(NPCShoppingJobScript.STATE_CHECKING_OUT)
	if npc._checkout_timer == 0.0:
		npc._show_dialog(
			"I'd like to buy %s." % npc.get_checkout_item_label()
		)

	npc._checkout_timer += delta

	if (
		npc.npc_data.patience_type == NPCData.PatienceType.IMPATIENT
		and npc._checkout_timer >= npc.CHECKOUT_PATIENCE
	):
		@warning_ignore("static_called_on_instance")
		npc._show_dialog(
			BlueprintManager.get_checkout_wait_dialog(npc)
		)
		npc._leave_queue()
		npc._return_item_to_shelf()
		npc._exit_after_checkout = false
		npc.target_position = npc._get_exit_position()
		set_state(NPC.State.EXIT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_exit() -> void:
	if (
		npc.global_position.distance_to(npc.target_position)
		<= npc.ARRIVAL_THRESHOLD
	):
		npc.velocity = Vector2.ZERO
		complete_exit()
		return

	if npc._dialog_timer > 0.0:
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()
		return

	if npc in NPC.current_queue:
		npc._leave_queue()

	if npc._move_to(npc.target_position):
		complete_exit()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func complete_exit() -> void:
	if npc._exit_completed or npc.is_queued_for_deletion():
		return

	npc._exit_completed = true
	npc.velocity = Vector2.ZERO
	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	npc._reset_stuck_watchdog()
	npc.npc_exited.emit(npc)

	if npc in NPC.current_queue:
		npc._leave_queue()

	npc.queue_done()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _begin_wait_for_shelf(_reason: String) -> void:
	npc._waiting_for_shelf_return = true
	npc._shelf_wait_timer = 0.0
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store_provider = _get_store_provider()

	if (
		store_provider == null
		or not store_provider.has_method("get_npc_shelf_wait_position")
	):
		npc._exit_after_checkout = false
		npc.target_position = npc._get_exit_position()
		set_state(NPC.State.EXIT)
		return

	npc.target_position = store_provider.get_npc_shelf_wait_position(
		npc.get_instance_id() % 2
	)
	set_state(NPC.State.WAIT_FOR_SHELF)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_wait_for_shelf(delta: float) -> void:
	if (
		npc.global_position.distance_to(npc.target_position)
		> npc.ARRIVAL_THRESHOLD
	):
		npc._move_to(npc.target_position)
	else:
		npc.velocity = Vector2.ZERO
		npc.move_and_slide()

	npc._shelf_wait_timer += delta

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var replacement_shelf: Shelf = npc._find_reachable_matching_shelf()
	if replacement_shelf != null:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var visit_position: Vector2 = npc._get_shelf_visit_position(
			replacement_shelf
		)
		if visit_position.is_finite():
			npc._target_shelf = replacement_shelf
			npc._shopping_job.set_target_shelf(replacement_shelf)
			npc.target_position = visit_position
			npc._waiting_for_shelf_return = false
			npc._shelf_wait_timer = 0.0
			set_state(NPC.State.WALK_TO_SHELF)
			return

	if npc._shelf_wait_timer >= npc.SHELF_WAIT_GRACE_PERIOD:
		npc._waiting_for_shelf_return = false
		npc._shelf_wait_timer = 0.0
		npc._show_dialog("Where'd the shelf go?")
		npc._dialog_timer = npc.DIALOG_DURATION
		npc._exit_after_checkout = false
		npc.target_position = npc._get_exit_position()
		set_state(NPC.State.EXIT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _find_reachable_stocked_shelf() -> Shelf:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var requested_items: Array[String] = npc._get_requested_items()

	for shelf in npc._get_matching_shelf_candidates():
		if shelf == null or not is_instance_valid(shelf):
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var has_requested_stock = false
		for item_id in requested_items:
			if shelf.has_item(item_id):
				has_requested_stock = true
				break

		if not has_requested_stock:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var visit_position: Vector2 = npc._get_shelf_visit_position(shelf)
		if visit_position.is_finite():
			return shelf

	return null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_store_provider() -> Node:
	return npc._get_store_route_provider()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func finish_checkout_and_exit() -> void:
	npc._dialog_timer = npc.DIALOG_DURATION
	npc._target_shelf = null
	npc._shopping_job.clear_target_shelf()
	if npc in NPC.current_queue:
		npc._leave_queue()
	npc._exit_after_checkout = true
	npc.target_position = npc._get_exit_position()
	set_state(NPC.State.EXIT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _handle_shelf_wait_or_leave(wait_stage: String) -> bool:
	_begin_wait_for_shelf(wait_stage)
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_state(new_state: int) -> void:
	_update_shopping_job_state(new_state)
	if new_state == NPC.State.ENTER:
		npc._enter_pause_timer = 0.0

	if new_state == NPC.State.SEARCH_ITEM:
		npc._search_timer = 0.0
		npc._search_announced = false

	if new_state == NPC.State.TAKE_ITEM:
		npc._take_item_pause_timer = 0.0
		npc._has_taken_shelf_item = false

	if new_state == NPC.State.CHECKOUT:
		npc._checkout_timer = 0.0

	if new_state == NPC.State.EXIT:
		npc._target_shelf = null
		npc._shopping_job.clear_target_shelf()

	if new_state in [
		NPC.State.WALK_TO_SHELF,
		NPC.State.SEARCH_ITEM,
		NPC.State.TAKE_ITEM
	]:
		npc._waiting_for_shelf_return = false
		npc._shelf_wait_timer = 0.0

	npc._movement_route.clear()
	npc._movement_route_destination = Vector2.INF
	npc._reset_stuck_watchdog()
	npc.current_state = new_state


func _update_shopping_job_state(new_state: int) -> void:
	if npc == null or npc._shopping_job == null:
		return

	match new_state:
		NPC.State.ENTER:
			npc._shopping_job.set_state(NPCShoppingJobScript.STATE_CHOOSING_ITEM)
		NPC.State.WALK_TO_SHELF:
			npc._shopping_job.set_state(NPCShoppingJobScript.STATE_MOVING_TO_SHELF)
		NPC.State.SEARCH_ITEM:
			npc._shopping_job.set_state(NPCShoppingJobScript.STATE_RESOLVING_SHELF)
		NPC.State.TAKE_ITEM:
			npc._shopping_job.set_state(NPCShoppingJobScript.STATE_PICKING_UP_ITEM)
		NPC.State.WAIT_IN_QUEUE:
			npc._shopping_job.set_state(NPCShoppingJobScript.STATE_WAITING_IN_QUEUE)
		NPC.State.CHECKOUT:
			npc._shopping_job.set_state(NPCShoppingJobScript.STATE_CHECKING_OUT)
		NPC.State.EXIT:
			npc._shopping_job.set_state(NPCShoppingJobScript.STATE_LEAVING_STORE)
		NPC.State.WAIT_FOR_SHELF:
			npc._shopping_job.set_state(NPCShoppingJobScript.STATE_RECOVERING)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_perf_npc_label() -> String:
	if (
		npc != null
		and npc.npc_data != null
		and npc.npc_data.npc_id != ""
	):
		return npc.npc_data.npc_id

	return npc.name if npc != null else "<none>"
