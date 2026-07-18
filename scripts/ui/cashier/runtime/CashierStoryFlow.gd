class_name CashierStoryFlow
extends RefCounted

var cashier: Cashier = null


func setup(cashier_node: Cashier) -> void:
	cashier = cashier_node


func is_story_gift_checkout() -> bool:
	if not cashier._has_scanned_customer():
		return false

	if cashier._scanned_npc.checkout_outcome != "reject_return":
		return false

	return is_gooby_npc(cashier._scanned_npc)


func apply_story_interaction_trust(npc: NPC) -> int:
	if npc == null or npc.npc_data == null:
		return 0

	if npc.npc_data.npc_category != NPCData.NPCCategory.STORY:
		return 0

	RelationshipManager.add_trust(npc.npc_data.npc_id, cashier.STORY_INTERACTION_TRUST_GAIN)
	return cashier.STORY_INTERACTION_TRUST_GAIN


func is_gooby_npc(npc: NPC) -> bool:
	return npc != null and npc.npc_data != null and npc.npc_data.npc_id == cashier.GOOBY_ID


func request_gooby_slime_follow_up() -> void:
	if NPCScheduler.has_method("spawn_day_one_night_monster_customer"):
		NPCScheduler.spawn_day_one_night_monster_customer()


func notify_store_gooby_resolved() -> void:
	var store := cashier.get_tree().get_first_node_in_group("store")

	if store != null and store.has_method("on_gooby_resolved"):
		store.call("on_gooby_resolved")
