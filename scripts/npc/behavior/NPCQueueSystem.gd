class_name NPCQueueSystem
extends RefCounted


static func join_queue(queue: Array, npc: Node) -> void:
	if npc not in queue:
		queue.append(npc)


static func leave_queue(queue: Array, npc: Node) -> void:
	queue.erase(npc)


static func get_queue_target(queue: Array, npc: Node, counter_position: Vector2) -> Vector2:
	var position_in_queue := queue.find(npc)

	if position_in_queue < 0:
		return counter_position

	return counter_position + Vector2(0, position_in_queue * 20.0)


static func prune_invalid(queue: Array) -> void:
	for i in range(queue.size() - 1, -1, -1):
		if not is_instance_valid(queue[i]):
			queue.remove_at(i)
