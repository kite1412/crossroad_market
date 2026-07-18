class_name NPCMetadataFlow
extends RefCounted

var npc = null


func setup(npc_node) -> void:
	npc = npc_node


func apply_scripted_metadata() -> void:
	npc.shopping_list.clear()
	npc._cart_items.clear()
	npc.checkout_total_override = -1
	npc.checkout_outcome = "paid"

	if npc.npc_data == null:
		return

	if npc.npc_data.has_meta("shopping_list"):
		for item_id in npc.npc_data.get_meta("shopping_list"):
			npc.shopping_list.append(str(item_id))

	if npc.npc_data.has_meta("checkout_total"):
		npc.checkout_total_override = int(npc.npc_data.get_meta("checkout_total"))

	if npc.npc_data.has_meta("checkout_outcome"):
		npc.checkout_outcome = str(npc.npc_data.get_meta("checkout_outcome"))
