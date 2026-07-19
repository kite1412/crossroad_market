class_name NPCStoreDebugTrace
extends RefCounted

const PREFIX: String = "[NPC-DIAG]"
const STATE_NAMES: Array[String] = [
	"ENTER",
	"WALK_TO_SHELF",
	"SEARCH_ITEM",
	"BROWSE_ITEM",
	"TAKE_ITEM",
	"WAIT_IN_QUEUE",
	"CHECKOUT",
	"EXIT",
	"WAIT_FOR_SHELF"
]


static func emit(
	npc: Node,
	event_name: String,
	data: Dictionary = {}
) -> void:
	var payload := data.duplicate(true)
	payload["event"] = event_name
	payload["time_msec"] = Time.get_ticks_msec()
	payload["npc"] = npc_label(npc)
	payload["instance_id"] = (
		npc.get_instance_id()
		if npc != null and is_instance_valid(npc)
		else 0
	)
	print("%s %s" % [PREFIX, JSON.stringify(payload)])


static func npc_label(npc: Node) -> String:
	if npc == null or not is_instance_valid(npc):
		return "<invalid>"

	var data: Variant = npc.get("npc_data")
	if data is NPCData and (data as NPCData).npc_id != "":
		return (data as NPCData).npc_id

	return npc.name


static func state_name(state: int) -> String:
	if state >= 0 and state < STATE_NAMES.size():
		return STATE_NAMES[state]
	return "UNKNOWN_%d" % state


static func vector(value: Vector2) -> String:
	return "(%.2f, %.2f)" % [value.x, value.y]


static func route_points(route: Array[Vector2]) -> Array[String]:
	var result: Array[String] = []
	for point in route:
		result.append(vector(point))
	return result


static func queue_snapshot(queue: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for queued in queue:
		if queued == null or not is_instance_valid(queued):
			result.append({"valid": false})
			continue

		result.append({
			"valid": true,
			"npc": npc_label(queued),
			"instance_id": queued.get_instance_id(),
			"state": state_name(int(queued.get("current_state"))),
			"queued_for_deletion": queued.is_queued_for_deletion()
		})

	return result


static func controller_path(controller: Variant) -> String:
	if controller == null:
		return "<null>"

	var script: Variant = controller.get_script()
	if script is Script:
		return (script as Script).resource_path

	return controller.get_class()
