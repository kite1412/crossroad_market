class_name NPCQueueReservationController
extends RefCounted


static func join(npc: Node) -> void:
	NPCQueueSystem.join_queue(NPC.current_queue, npc)
	sync_compat_queue_positions()


static func leave(npc: Node) -> void:
	NPCQueueSystem.leave_queue(NPC.current_queue, npc)
	sync_compat_queue_positions()


static func index_of(npc: Node) -> int:
	prune_invalid()
	return NPC.current_queue.find(npc)


static func size() -> int:
	prune_invalid()
	return NPC.current_queue.size()


static func is_front(npc: Node) -> bool:
	prune_invalid()
	return not NPC.current_queue.is_empty() and NPC.current_queue[0] == npc


static func get_target(npc: Node, counter_position: Vector2) -> Vector2:
	prune_invalid()
	return NPCQueueSystem.get_queue_target(
		NPC.current_queue,
		npc,
		counter_position
	)


static func prune_invalid() -> void:
	NPCQueueSystem.prune_invalid(NPC.current_queue)
	sync_compat_queue_positions()


static func sync_compat_queue_positions() -> void:
	for i in NPC.current_queue.size():
		var queued_npc = NPC.current_queue[i]
		if queued_npc != null and is_instance_valid(queued_npc):
			queued_npc.queue_position = i + 1
