class_name RelationshipTrustStore
extends RefCounted

var relationship: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(relationship_node: Node) -> void:
	relationship = relationship_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_trust(npc_id: String, value: int) -> void:
	if npc_id == "":
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var previous := get_trust(npc_id)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var next_value := clampi(value, relationship.MIN_TRUST, relationship.MAX_TRUST)

	if previous == next_value:
		return

	relationship._trust_by_npc[npc_id] = next_value
	relationship.trust_changed.emit(npc_id, next_value, next_value - previous)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func add_trust(npc_id: String, amount: int) -> void:
	if amount == 0:
		return

	set_trust(npc_id, get_trust(npc_id) + amount)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_trust(npc_id: String) -> int:
	return int(relationship._trust_by_npc.get(npc_id, 0))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_all_trust() -> Dictionary[String, int]:
	return relationship._trust_by_npc.duplicate()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func reset_trust() -> void:
	relationship._trust_by_npc.clear()
