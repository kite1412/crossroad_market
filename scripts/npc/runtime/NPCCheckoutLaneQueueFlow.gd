extends "res://scripts/npc/runtime/NPCQueueFlow.gd"

const SOLO_CHECKOUT_EXIT_META: StringName = &"solo_checkout_exit"


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func start_queue_to_cashier(queue_index: int) -> void:
	_capture_checkout_lane()
	super.start_queue_to_cashier(queue_index)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func mark_checkout_ready() -> void:
	if not npc.has_meta(SOLO_CHECKOUT_EXIT_META):
		_capture_checkout_lane()

	super.mark_checkout_ready()
	if npc.current_state == NPC.State.CHECKOUT:
		face_queue_forward(0, "checkout_ready")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_cashier_face_target() -> Vector2:
	var fallback := super.get_cashier_face_target()
	var store: Node = npc._get_store_route_provider()
	if store == null:
		return fallback

	var route_provider_variant: Variant = store.get("npc_routes")
	if not is_instance_valid(route_provider_variant):
		return fallback
	if not (route_provider_variant is Node):
		return fallback

	var route_provider := route_provider_variant as Node
	if not route_provider.has_method("get_npc_cashier_face_target"):
		return fallback

	var result: Variant = route_provider.call(
		"get_npc_cashier_face_target",
		fallback
	)
	if result is Vector2:
		return result as Vector2
	return fallback


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _capture_checkout_lane() -> void:
	NPCQueueSystem.prune_invalid(NPC.current_queue)
	var has_waiting_customer := false

	for queued_variant in NPC.current_queue:
		if not is_instance_valid(queued_variant):
			continue
		if not (queued_variant is NPC):
			continue

		var queued_npc := queued_variant as NPC
		if queued_npc == npc:
			continue
		if queued_npc.is_queued_for_deletion():
			continue
		if queued_npc.current_state != NPC.State.WAIT_IN_QUEUE:
			continue

		has_waiting_customer = true
		break

	npc.set_meta(
		SOLO_CHECKOUT_EXIT_META,
		not has_waiting_customer
	)
