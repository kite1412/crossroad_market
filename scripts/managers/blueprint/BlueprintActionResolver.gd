class_name BlueprintActionResolver
extends RefCounted

enum Action {
	LEAVE,
	QUEUE,
	BROWSE_BUY
}


static func evaluate_no_item_action(npc) -> Action:
	match npc.npc_data.patience_type:
		NPCData.PatienceType.IMPATIENT: return Action.LEAVE
		NPCData.PatienceType.PATIENT: return Action.QUEUE
		NPCData.PatienceType.QUITTER: return Action.BROWSE_BUY
	return Action.LEAVE


static func get_bp_type(npc) -> int:
	match npc.npc_data.patience_type:
		NPCData.PatienceType.IMPATIENT: return 0
		NPCData.PatienceType.PATIENT: return 1
		NPCData.PatienceType.QUITTER: return 2
	return 1


static func item_name(item_id: String) -> String:
	var item: ItemData = ItemDatabase.get_item(item_id)
	return item.display_name if item else item_id
