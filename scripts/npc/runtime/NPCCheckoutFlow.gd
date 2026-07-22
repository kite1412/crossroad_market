class_name NPCCheckoutFlow
extends RefCounted

var npc = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(npc_node) -> void:
	npc = npc_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func complete_checkout(
	paid_total: int = -1,
	show_completion_dialog: bool = true
) -> void:
	if npc.checkout_outcome == "reject_return":
		reject_checkout_and_return_items("Boo...")
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var total: int = paid_total if paid_total >= 0 else get_checkout_total()

	if total > 0:
		npc.purchase_completed.emit(npc, npc.item_to_buy, total)
		if show_completion_dialog:
			@warning_ignore("static_called_on_instance")
			npc._show_dialog(BlueprintManager.get_done_dialog(npc))

	npc._finish_checkout_and_exit()
	if not show_completion_dialog:
		# The cashier conversation already provided the farewell. Do not leave the
		# NPC paused for the duration of an invisible world-dialog bubble.
		npc._dialog_timer = 0.0


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func complete_story_gift(dialog_text: String = "Thank you...") -> void:
	npc._cart_items.clear()
	npc._show_dialog(dialog_text)
	npc._finish_checkout_and_exit()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func reject_checkout_and_return_items(dialog_text: String = "Boo...") -> void:
	npc._return_cart_items_to_shelf()
	npc._show_dialog(dialog_text)
	npc._finish_checkout_and_exit()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func cancel_checkout_and_leave() -> void:
	npc._return_cart_items_to_shelf()
	npc._show_dialog("Never mind. I'll come back later.")
	npc._finish_checkout_and_exit()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_checkout_total() -> int:
	return NPCCheckoutBehavior.get_checkout_total(npc._cart_items, npc.item_to_buy, npc.checkout_total_override)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_checkout_item_label() -> String:
	return NPCCheckoutBehavior.get_checkout_item_label(npc._cart_items, npc.item_to_buy)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_cart_item_ids() -> Array[String]:
	return NPCCheckoutBehavior.get_cart_item_ids(npc._cart_items, npc.item_to_buy)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func repeat_checkout_request() -> void:
	npc._show_dialog("I'm buying %s." % get_checkout_item_label())
