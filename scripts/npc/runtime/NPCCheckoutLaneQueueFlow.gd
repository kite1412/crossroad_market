extends "res://scripts/npc/runtime/NPCQueueFlow.gd"

const NPCStoreDebugTraceScript = preload(
	"res://scripts/npc/runtime/NPCStoreDebugTrace.gd"
)
const SOLO_CHECKOUT_EXIT_META: StringName = &"solo_checkout_exit"


func enter_checkout_queue() -> void:
	NPCStoreDebugTraceScript.emit(
		npc,
		"queue_enter_before",
		{
			"queue": NPCStoreDebugTraceScript.queue_snapshot(
				NPC.current_queue
			)
		}
	)
	super.enter_checkout_queue()
	NPCStoreDebugTraceScript.emit(
		npc,
		"queue_enter_after",
		{
			"queue_index": NPC.current_queue.find(npc),
			"queue": NPCStoreDebugTraceScript.queue_snapshot(
				NPC.current_queue
			)
		}
	)


func start_queue_to_cashier(queue_index: int) -> void:
	_capture_checkout_lane("start_queue_to_cashier")
	super.start_queue_to_cashier(queue_index)


func mark_checkout_ready() -> void:
	if not npc.has_meta(SOLO_CHECKOUT_EXIT_META):
		_capture_checkout_lane("mark_checkout_ready_fallback")
	else:
		NPCStoreDebugTraceScript.emit(
			npc,
			"checkout_lane_preserved",
			{
				"solo": bool(
					npc.get_meta(SOLO_CHECKOUT_EXIT_META)
				),
				"queue": NPCStoreDebugTraceScript.queue_snapshot(
					NPC.current_queue
				)
			}
		)

	super.mark_checkout_ready()


func _capture_checkout_lane(source: String) -> void:
	var started_usec := Time.get_ticks_usec()
	NPCQueueSystem.prune_invalid(NPC.current_queue)
	var has_waiting_customer := false
	var waiting_customer_ids: Array[int] = []

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
		waiting_customer_ids.append(queued_npc.get_instance_id())

	var solo := not has_waiting_customer
	npc.set_meta(SOLO_CHECKOUT_EXIT_META, solo)

	NPCStoreDebugTraceScript.emit(
		npc,
		"checkout_lane_capture",
		{
			"source": source,
			"solo": solo,
			"waiting_customer_ids": waiting_customer_ids,
			"queue_index": NPC.current_queue.find(npc),
			"queue": NPCStoreDebugTraceScript.queue_snapshot(
				NPC.current_queue
			),
			"elapsed_msec": float(
				Time.get_ticks_usec() - started_usec
			) / 1000.0
		}
	)
