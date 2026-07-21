class_name StoreNavigationRequest
extends RefCounted

const GOAL_POSITION: StringName = &"position"
const GOAL_SHELF: StringName = &"shelf"
const GOAL_QUEUE: StringName = &"queue"
const GOAL_CASHIER: StringName = &"cashier"
const GOAL_EXIT: StringName = &"exit"

var start_position: Vector2 = Vector2.INF
var goal_position: Vector2 = Vector2.INF
var goal_type: StringName = GOAL_POSITION
var goal_id: StringName = StringName()
var source_shelf: Shelf = null
var target_shelf: Shelf = null
var npc: Node = null
var queue_index: int = -1
var agent_radius: float = 10.5
var allow_direct: bool = true
var force_semantic: bool = false
var allow_incremental_repair: bool = true
var use_shared_goal_cache: bool = true
var avoid_queue_front: bool = false
var ignore_start_collision: bool = true
var ignore_goal_collision: bool = false
var required_nodes: Array[StringName] = []
var context: Dictionary = {}


func duplicate_request() -> StoreNavigationRequest:
	var copy := StoreNavigationRequest.new()
	copy.start_position = start_position
	copy.goal_position = goal_position
	copy.goal_type = goal_type
	copy.goal_id = goal_id
	copy.source_shelf = source_shelf
	copy.target_shelf = target_shelf
	copy.npc = npc
	copy.queue_index = queue_index
	copy.agent_radius = agent_radius
	copy.allow_direct = allow_direct
	copy.force_semantic = force_semantic
	copy.allow_incremental_repair = allow_incremental_repair
	copy.use_shared_goal_cache = use_shared_goal_cache
	copy.avoid_queue_front = avoid_queue_front
	copy.ignore_start_collision = ignore_start_collision
	copy.ignore_goal_collision = ignore_goal_collision
	copy.required_nodes = required_nodes.duplicate()
	copy.context = context.duplicate(true)
	return copy


func get_policy_context() -> Dictionary:
	var result := context.duplicate(true)
	result["goal_type"] = goal_type
	result["queue_index"] = queue_index
	result["avoid_queue_front"] = avoid_queue_front
	result["agent_radius"] = agent_radius
	return result


func get_cache_key(cell_size: float = 12.0) -> String:
	var start_cell := _quantize(start_position, cell_size)
	var goal_cell := _quantize(goal_position, cell_size)
	var required_text := PackedStringArray()
	for node_name in required_nodes:
		required_text.append(String(node_name))

	var source_id := 0
	if source_shelf != null and is_instance_valid(source_shelf):
		source_id = source_shelf.get_instance_id()

	var target_id := 0
	if target_shelf != null and is_instance_valid(target_shelf):
		target_id = target_shelf.get_instance_id()

	return "%s|%s|%d,%d|%d,%d|px%d,%d:%d,%d|q%d|s%d|t%d|r%d|d%d|f%d|a%d|%s" % [
		String(goal_type),
		String(goal_id),
		start_cell.x,
		start_cell.y,
		goal_cell.x,
		goal_cell.y,
		roundi(start_position.x),
		roundi(start_position.y),
		roundi(goal_position.x),
		roundi(goal_position.y),
		queue_index,
		source_id,
		target_id,
		roundi(agent_radius * 10.0),
		int(allow_direct),
		int(force_semantic),
		int(avoid_queue_front),
		",".join(required_text)
	]


func _quantize(position: Vector2, cell_size: float) -> Vector2i:
	if not position.is_finite():
		return Vector2i(-2147483648, -2147483648)
	var safe_size := maxf(1.0, cell_size)
	return Vector2i(
		roundi(position.x / safe_size),
		roundi(position.y / safe_size)
	)
