class_name RelationshipTrustStore
extends RefCounted

var relationship: Node = null


func setup(relationship_node: Node) -> void:
	relationship = relationship_node


func set_trust(npc_id: String, value: int) -> void:
	if npc_id == "":
		return

	var previous := get_trust(npc_id)
	var next_value := clampi(value, relationship.MIN_TRUST, relationship.MAX_TRUST)

	if previous == next_value:
		return

	relationship._trust_by_npc[npc_id] = next_value
	relationship.trust_changed.emit(npc_id, next_value, next_value - previous)


func add_trust(npc_id: String, amount: int) -> void:
	if amount == 0:
		return

	set_trust(npc_id, get_trust(npc_id) + amount)


func get_trust(npc_id: String) -> int:
	return int(relationship._trust_by_npc.get(npc_id, 0))


func get_all_trust() -> Dictionary[String, int]:
	return relationship._trust_by_npc.duplicate()


func reset_trust() -> void:
	relationship._trust_by_npc.clear()
