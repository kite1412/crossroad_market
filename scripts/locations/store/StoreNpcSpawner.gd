class_name StoreNpcSpawner
extends RefCounted


static func spawn_npc(
	owner: Node,
	npc_scene: PackedScene,
	entrance_pos: Marker2D,
	npc_data: NPCData,
	purchase_completed_callback: Callable,
	npc_exited_callback: Callable
) -> NPC:
	if npc_scene == null:
		pass
		return null

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var npc := npc_scene.instantiate() as NPC

	if npc == null:
		pass
		return null

	owner.add_child(npc)

	if entrance_pos != null:
		npc.global_position = entrance_pos.global_position

	if purchase_completed_callback.is_valid() and not npc.purchase_completed.is_connected(purchase_completed_callback):
		npc.purchase_completed.connect(purchase_completed_callback)

	if npc_exited_callback.is_valid() and not npc.npc_exited.is_connected(npc_exited_callback):
		npc.npc_exited.connect(npc_exited_callback)

	npc.setup(npc_data)
	return npc
