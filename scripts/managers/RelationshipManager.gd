extends Node


@warning_ignore("unused_signal")
signal trust_changed(npc_id: String, new_trust: int, delta: int)

const MIN_TRUST: int = 0
const MAX_TRUST: int = 100
const INTERACTION_TRUST_GAIN: int = 25
const MAIN_NPC_IDS: Array[String] = ["irene", "gooby"]

@warning_ignore("unused_private_class_variable")
var _trust_by_npc: Dictionary[String, int] = {}
@warning_ignore("unused_private_class_variable")
var _trust_store: RelationshipTrustStore = RelationshipTrustStore.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_trust_store.setup(self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_main_npc(npc_id: String) -> bool:
	return npc_id in MAIN_NPC_IDS


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_trust(npc_id: String, value: int) -> void:
	if not is_main_npc(npc_id):
		return
	_trust_store.set_trust(npc_id, value)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func add_trust(npc_id: String, amount: int) -> void:
	if not is_main_npc(npc_id):
		return
	_trust_store.add_trust(npc_id, amount)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_trust(npc_id: String) -> int:
	if not is_main_npc(npc_id):
		return 0
	return _trust_store.get_trust(npc_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_all_trust() -> Dictionary[String, int]:
	return _trust_store.get_all_trust()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func reset_trust() -> void:
	_trust_store.reset_trust()
