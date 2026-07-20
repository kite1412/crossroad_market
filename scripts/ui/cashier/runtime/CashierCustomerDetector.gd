class_name CashierCustomerDetector
extends RefCounted

const DEBUG_CASHIER_READY: bool = true

var cashier: Cashier = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(cashier_node: Cashier) -> void:
	cashier = cashier_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_player_nearby() -> bool:
	if cashier.interaction_area == null:
		return false

	for body in cashier.interaction_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			return true

	for area in cashier.interaction_area.get_overlapping_areas():
		if area.is_in_group("player"):
			return true

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var parent: Node = area.get_parent()

		if parent != null and parent.is_in_group("player"):
			return true

	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_first_checkout_npc() -> NPC:
	NPCQueueSystem.prune_invalid(NPC.current_queue)

	if NPC.current_queue.is_empty():
		pass
		return null

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var front_npc := NPC.current_queue[0]

	if not is_instance_valid(front_npc):
		pass
		return null

	if front_npc.has_method("is_ready_for_checkout_service"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var ready := bool(front_npc.call("is_ready_for_checkout_service"))
		pass
		if ready:
			if front_npc.has_method("mark_checkout_ready"):
				front_npc.call("mark_checkout_ready")
			return front_npc

	if front_npc.current_state != NPC.State.CHECKOUT:
		pass
		return null

	pass
	return front_npc


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_customer_approaching_counter() -> bool:
	for npc in NPC.current_queue:
		if not is_instance_valid(npc):
			continue

		if npc.current_state == NPC.State.WAIT_IN_QUEUE or npc.current_state == NPC.State.CHECKOUT:
			return true

	return false


