extends "res://scripts/npc/runtime/NPCStateFlow.gd"

const NPCStoreDebugTraceScript = preload(
	"res://scripts/npc/runtime/NPCStoreDebugTrace.gd"
)
const SOLO_CHECKOUT_EXIT_META: StringName = &"solo_checkout_exit"
const EXIT_ORIGIN_SHELF_META: StringName = &"exit_origin_shelf"
const SLOW_SEARCH_FRAME_MSEC: float = 4.0
const SLOW_SEARCH_LOG_INTERVAL_MSEC: int = 500

var _last_slow_search_log_msec: int = -SLOW_SEARCH_LOG_INTERVAL_MSEC


func finish_checkout_and_exit() -> void:
	# NPCCheckoutLaneQueueFlow normally captures this when cashier movement
	# starts. Keep a safe fallback for checkout paths that bypass that flow, but
	# never overwrite the earlier snapshot with customers who joined later.
	if not npc.has_meta(SOLO_CHECKOUT_EXIT_META):
		_capture_solo_checkout_fallback()

	if npc.has_meta(EXIT_ORIGIN_SHELF_META):
		npc.remove_meta(EXIT_ORIGIN_SHELF_META)

	NPCStoreDebugTraceScript.emit(
		npc,
		"checkout_finish_exit",
		{
			"solo_meta_present": npc.has_meta(
				SOLO_CHECKOUT_EXIT_META
			),
			"solo": (
				bool(npc.get_meta(SOLO_CHECKOUT_EXIT_META))
				if npc.has_meta(SOLO_CHECKOUT_EXIT_META)
				else false
			),
			"queue": NPCStoreDebugTraceScript.queue_snapshot(
				NPC.current_queue
			)
		}
	)

	super.finish_checkout_and_exit()


func process_search_item(delta: float) -> void:
	var started_usec := Time.get_ticks_usec()
	var shelf_before_exit := npc._target_shelf as Shelf
	var previous_state: int = npc.current_state
	var search_timer_before: float = npc._search_timer
	var announced_before: bool = npc._search_announced
	var shelf_valid_before: bool = npc._is_target_shelf_valid()

	super.process_search_item(delta)

	# The base flow clears _target_shelf when the out-of-stock timeout changes
	# the state to EXIT. Keep a separate reference so route building can use the
	# shelf-aware egress and avoid being rejected by the shelf's own body.
	if (
		previous_state == NPC.State.SEARCH_ITEM
		and npc.current_state == NPC.State.EXIT
		and not npc._exit_after_checkout
		and shelf_before_exit != null
		and is_instance_valid(shelf_before_exit)
	):
		npc.set_meta(EXIT_ORIGIN_SHELF_META, shelf_before_exit)
		npc.set_meta(SOLO_CHECKOUT_EXIT_META, false)
		NPCStoreDebugTraceScript.emit(
			npc,
			"out_of_stock_origin_captured",
			{
				"shelf": shelf_before_exit.name,
				"shelf_instance_id": shelf_before_exit.get_instance_id(),
				"position": NPCStoreDebugTraceScript.vector(
					npc.global_position
				)
			}
		)

	var elapsed_msec := float(
		Time.get_ticks_usec() - started_usec
	) / 1000.0

	if not announced_before and npc._search_announced:
		NPCStoreDebugTraceScript.emit(
			npc,
			"out_of_stock_warning_transition",
			{
				"timer_before": search_timer_before,
				"timer_after": npc._search_timer,
				"elapsed_msec": elapsed_msec,
				"shelf_valid_before": shelf_valid_before
			}
		)

	if previous_state != NPC.State.EXIT and npc.current_state == NPC.State.EXIT:
		NPCStoreDebugTraceScript.emit(
			npc,
			"out_of_stock_exit_transition",
			{
				"timer_before": search_timer_before,
				"timer_after": npc._search_timer,
				"elapsed_msec": elapsed_msec,
				"origin_meta_present": npc.has_meta(
					EXIT_ORIGIN_SHELF_META
				),
				"target": NPCStoreDebugTraceScript.vector(
					npc.target_position
				)
			}
		)

	var now_msec := Time.get_ticks_msec()
	if (
		elapsed_msec >= SLOW_SEARCH_FRAME_MSEC
		and now_msec - _last_slow_search_log_msec
		>= SLOW_SEARCH_LOG_INTERVAL_MSEC
	):
		_last_slow_search_log_msec = now_msec
		NPCStoreDebugTraceScript.emit(
			npc,
			"search_frame_slow",
			{
				"elapsed_msec": elapsed_msec,
				"search_timer": npc._search_timer,
				"state": NPCStoreDebugTraceScript.state_name(
					int(npc.current_state)
				),
				"shelf_valid_before": shelf_valid_before
			}
		)


func set_state(new_state: int) -> void:
	var previous_state: int = npc.current_state
	super.set_state(new_state)

	if previous_state == new_state:
		return

	NPCStoreDebugTraceScript.emit(
		npc,
		"state_transition",
		{
			"from": NPCStoreDebugTraceScript.state_name(
				previous_state
			),
			"to": NPCStoreDebugTraceScript.state_name(new_state),
			"position": NPCStoreDebugTraceScript.vector(
				npc.global_position
			),
			"target": NPCStoreDebugTraceScript.vector(
				npc.target_position
			),
			"exit_after_checkout": npc._exit_after_checkout
		}
	)


func complete_exit() -> void:
	NPCStoreDebugTraceScript.emit(
		npc,
		"exit_complete",
		{
			"position": NPCStoreDebugTraceScript.vector(
				npc.global_position
			),
			"solo_meta_present": npc.has_meta(
				SOLO_CHECKOUT_EXIT_META
			),
			"origin_meta_present": npc.has_meta(
				EXIT_ORIGIN_SHELF_META
			)
		}
	)

	if npc.has_meta(SOLO_CHECKOUT_EXIT_META):
		npc.remove_meta(SOLO_CHECKOUT_EXIT_META)
	if npc.has_meta(EXIT_ORIGIN_SHELF_META):
		npc.remove_meta(EXIT_ORIGIN_SHELF_META)

	super.complete_exit()


func _capture_solo_checkout_fallback() -> void:
	var started_usec := Time.get_ticks_usec()
	NPCQueueSystem.prune_invalid(NPC.current_queue)
	var has_waiting_customer := false

	for queued_variant in NPC.current_queue:
		if not (queued_variant is NPC):
			continue

		var queued_npc := queued_variant as NPC
		if queued_npc == npc:
			continue
		if not is_instance_valid(queued_npc):
			continue
		if queued_npc.is_queued_for_deletion():
			continue
		if queued_npc.current_state != NPC.State.WAIT_IN_QUEUE:
			continue

		has_waiting_customer = true
		break

	var solo := not has_waiting_customer
	npc.set_meta(SOLO_CHECKOUT_EXIT_META, solo)
	NPCStoreDebugTraceScript.emit(
		npc,
		"checkout_lane_fallback_capture",
		{
			"solo": solo,
			"queue": NPCStoreDebugTraceScript.queue_snapshot(
				NPC.current_queue
			),
			"elapsed_msec": float(
				Time.get_ticks_usec() - started_usec
			) / 1000.0
		}
	)


func _find_reachable_stocked_shelf() -> Shelf:
	var requested_items: Array[String] = npc._get_requested_items()
	var current_shelf := npc._target_shelf as Shelf
	var interaction_tolerance := maxf(
		npc.SHELF_ACTION_DISTANCE,
		npc.ARRIVAL_THRESHOLD + 2.0
	)

	# Once the NPC is already standing at its assigned shelf, do not make item
	# pickup depend on another route/access lookup. Placement metadata can be
	# refreshed after a shelf drop and briefly invalidate that lookup even
	# though the NPC and stocked shelf are already correctly aligned.
	if (
		current_shelf != null
		and is_instance_valid(current_shelf)
		and current_shelf.is_in_group("shelves")
		and npc.global_position.distance_to(npc.target_position)
		<= interaction_tolerance
		and _shelf_has_requested_stock(current_shelf, requested_items)
	):
		return current_shelf

	for shelf in npc._get_matching_shelf_candidates():
		if shelf == null or not is_instance_valid(shelf):
			continue
		if not _shelf_has_requested_stock(shelf, requested_items):
			continue

		var visit_position: Vector2 = npc._get_shelf_visit_position(shelf)
		if visit_position.is_finite():
			return shelf

	return null


func _shelf_has_requested_stock(
	shelf: Shelf,
	requested_items: Array[String]
) -> bool:
	for item_id in requested_items:
		if shelf.has_item(item_id):
			return true

	return false
