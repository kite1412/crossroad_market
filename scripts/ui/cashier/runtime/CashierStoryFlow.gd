class_name CashierStoryFlow
extends RefCounted

const INTERACTION_PURCHASE: StringName = &"purchase"
const INTERACTION_GIFT: StringName = &"gift"
const DAY_ONE_IRENE_TRUST_GAIN: int = 20
const DAY_ONE_GOOBY_TRUST_GAIN: int = 20

var cashier: Cashier = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(cashier_node: Cashier) -> void:
	cashier = cashier_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_story_gift_checkout() -> bool:
	if not cashier._has_scanned_customer():
		return false

	if cashier._scanned_npc.checkout_outcome != "reject_return":
		return false

	return is_gooby_npc(cashier._scanned_npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_story_interaction_trust(
	npc: NPC,
	interaction_type: StringName = INTERACTION_PURCHASE
) -> int:
	if npc == null or npc.npc_data == null:
		return 0

	if npc.npc_data.npc_category != NPCData.NPCCategory.STORY:
		return 0

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var npc_id := npc.npc_data.npc_id
	if not RelationshipManager.is_main_npc(npc_id):
		return 0

	# Irene's first successful purchase establishes her initial trust. Gooby's
	# Day 1 trust remains exclusive to gifting the Phantom Ice Cream.
	if TimeManager.current_day == 1:
		if npc_id == "irene" and interaction_type == INTERACTION_PURCHASE:
			RelationshipManager.add_trust(npc_id, DAY_ONE_IRENE_TRUST_GAIN)
			return DAY_ONE_IRENE_TRUST_GAIN

		if npc_id == cashier.GOOBY_ID and interaction_type == INTERACTION_GIFT:
			RelationshipManager.add_trust(npc_id, DAY_ONE_GOOBY_TRUST_GAIN)
			return DAY_ONE_GOOBY_TRUST_GAIN

		return 0

	RelationshipManager.add_trust(
		npc_id,
		RelationshipManager.INTERACTION_TRUST_GAIN
	)
	return RelationshipManager.INTERACTION_TRUST_GAIN


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_gooby_gift_trust(npc: NPC) -> int:
	return apply_story_interaction_trust(npc, INTERACTION_GIFT)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_gooby_npc(npc: NPC) -> bool:
	return npc != null and npc.npc_data != null and npc.npc_data.npc_id == cashier.GOOBY_ID


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_gooby_slime_follow_up() -> void:
	if NPCScheduler.has_method("spawn_day_one_night_monster_customer"):
		NPCScheduler.spawn_day_one_night_monster_customer()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func notify_store_gooby_resolved() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store := cashier.get_tree().get_first_node_in_group("store")

	if store != null and store.has_method("on_gooby_resolved"):
		store.call("on_gooby_resolved")
