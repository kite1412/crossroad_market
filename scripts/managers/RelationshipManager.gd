extends Node

const RelationshipTrustStore = preload("res://scripts/managers/relationship/RelationshipTrustStore.gd")

signal trust_changed(npc_id: String, new_trust: int, delta: int)

const MIN_TRUST: int = 0
const MAX_TRUST: int = 100
const INTERACTION_TRUST_GAIN: int = 25
const MAIN_NPC_IDS: Array[String] = ["irene", "gooby"]

var _trust_by_npc: Dictionary[String, int] = {}
var _trust_store: RelationshipTrustStore = RelationshipTrustStore.new()


func _ready() -> void:
	_trust_store.setup(self)


func is_main_npc(npc_id: String) -> bool:
	return npc_id in MAIN_NPC_IDS


func set_trust(npc_id: String, value: int) -> void:
	if not is_main_npc(npc_id):
		return
	_trust_store.set_trust(npc_id, value)


func add_trust(npc_id: String, amount: int) -> void:
	if not is_main_npc(npc_id):
		return
	_trust_store.add_trust(npc_id, amount)


func get_trust(npc_id: String) -> int:
	if not is_main_npc(npc_id):
		return 0
	return _trust_store.get_trust(npc_id)


func get_all_trust() -> Dictionary[String, int]:
	return _trust_store.get_all_trust()


func reset_trust() -> void:
	_trust_store.reset_trust()
