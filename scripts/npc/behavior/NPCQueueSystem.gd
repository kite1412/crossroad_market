class_name NPCQueueSystem
extends RefCounted

const CHECKOUT_TICKET_META: StringName = &"checkout_item_pickup_ticket"

static var _next_checkout_ticket: int = 0


static func mark_item_taken(npc: Node) -> int:
	if npc == null or not is_instance_valid(npc):
		return -1

	if npc.has_meta(CHECKOUT_TICKET_META):
		return int(npc.get_meta(CHECKOUT_TICKET_META))

	_next_checkout_ticket += 1
	npc.set_meta(CHECKOUT_TICKET_META, _next_checkout_ticket)
	return _next_checkout_ticket


static func join_queue(queue: Array, npc: Node) -> void:
	if npc == null or not is_instance_valid(npc):
		return

	# Normal flow issues this ticket at the exact successful shelf pickup. Keep a
	# fallback here for older/special flows so every queued customer remains
	# sortable.
	mark_item_taken(npc)

	if npc not in queue:
		queue.append(npc)

	sort_by_item_pickup(queue)


static func leave_queue(queue: Array, npc: Node) -> void:
	queue.erase(npc)
	if npc != null and is_instance_valid(npc) and npc.has_meta(CHECKOUT_TICKET_META):
		npc.remove_meta(CHECKOUT_TICKET_META)


static func sort_by_item_pickup(queue: Array) -> void:
	prune_invalid(queue)
	queue.sort_custom(func(a: Variant, b: Variant) -> bool:
		if not (a is Node) or not (b is Node):
			return false

		var a_node := a as Node
		var b_node := b as Node
		var a_ticket := int(a_node.get_meta(CHECKOUT_TICKET_META, 2147483647))
		var b_ticket := int(b_node.get_meta(CHECKOUT_TICKET_META, 2147483647))

		if a_ticket != b_ticket:
			return a_ticket < b_ticket

		return a_node.get_instance_id() < b_node.get_instance_id()
	)


static func get_queue_target(queue: Array, npc: Node, counter_position: Vector2) -> Vector2:
	var position_in_queue := queue.find(npc)

	if position_in_queue < 0:
		return counter_position

	# Space queue slots 28px apart (based on STANDING_SHAPE_SIZE ~21px + clearance).
	# 20px caused NPCs to visually overlap in queue.
	return counter_position + Vector2(0, position_in_queue * 28.0)


static func prune_invalid(queue: Array) -> void:
	for i in range(queue.size() - 1, -1, -1):
		if not is_instance_valid(queue[i]):
			queue.remove_at(i)
