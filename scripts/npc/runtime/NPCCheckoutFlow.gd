class_name NPCCheckoutFlow
extends RefCounted

var npc = null


func setup(npc_node) -> void:
	npc = npc_node


func complete_checkout() -> void:
	if npc.checkout_outcome == "reject_return":
		reject_checkout_and_return_items("Boo...")
		return

	var total := get_checkout_total()

	if total > 0:
		npc.purchase_completed.emit(npc, npc.item_to_buy, total)
		npc._show_dialog(BlueprintManager.get_done_dialog(npc))

	npc._finish_checkout_and_exit()


func complete_story_gift(dialog_text: String = "Thank you...") -> void:
	npc._cart_items.clear()
	npc._show_dialog(dialog_text)
	npc._finish_checkout_and_exit()


func reject_checkout_and_return_items(dialog_text: String = "Boo...") -> void:
	npc._return_cart_items_to_shelf()
	npc._show_dialog(dialog_text)
	npc._finish_checkout_and_exit()


func cancel_checkout_and_leave() -> void:
	npc._return_cart_items_to_shelf()
	npc._show_dialog("Never mind. I'll come back later.")
	npc._finish_checkout_and_exit()


func get_checkout_total() -> int:
	return NPCCheckoutBehavior.get_checkout_total(npc._cart_items, npc.item_to_buy, npc.checkout_total_override)


func get_checkout_item_label() -> String:
	return NPCCheckoutBehavior.get_checkout_item_label(npc._cart_items, npc.item_to_buy)


func get_cart_item_ids() -> Array[String]:
	return NPCCheckoutBehavior.get_cart_item_ids(npc._cart_items, npc.item_to_buy)


func repeat_checkout_request() -> void:
	npc._show_dialog("I'm buying %s." % get_checkout_item_label())
