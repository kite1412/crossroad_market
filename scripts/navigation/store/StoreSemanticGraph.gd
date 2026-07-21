class_name StoreSemanticGraph
extends RefCounted

const PATH_ROLE_META: StringName = &"store_path_role"
const QUEUE_INDEX_META: StringName = &"store_queue_index"
const VIRTUAL_ROLE: StringName = &"navigation_region"
const MAX_GENERAL_EDGE_DISTANCE: float = 180.0
const REGION_X_FRACTIONS: Array[float] = [0.2, 0.5, 0.8]
const REGION_Y_FRACTIONS: Array[float] = [0.35, 0.65]

var _nodes: Dictionary = {}
var _adjacency: Dictionary = {}
var _marker_root: Node2D = null
var _obstacles: StoreDynamicObstacleTracker = null
var _policy: StoreNavigationCostPolicy = null
var _topology_signature: String = ""


func setup(
	marker_root: Node2D,
	placement_anchors: Array[Vector2],
	obstacles: StoreDynamicObstacleTracker,
	policy: StoreNavigationCostPolicy
) -> void:
	_marker_root = marker_root
	_obstacles = obstacles
	_policy = policy
	var next_signature := _make_topology_signature(
		marker_root,
		placement_anchors
	)
	if next_signature == _topology_signature and not _nodes.is_empty():
		return
	_topology_signature = next_signature
	_rebuild(placement_anchors)


func get_node_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for node_id_variant in _nodes.keys():
		result.append(StringName(node_id_variant))
	result.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b)
	)
	return result


func has_node(node_id: StringName) -> bool:
	return _nodes.has(node_id)


func get_position(node_id: StringName) -> Vector2:
	if not _nodes.has(node_id):
		return Vector2.INF
	var node_data: Dictionary = _nodes[node_id]
	return node_data.get("position", Vector2.INF) as Vector2


func get_role(node_id: StringName) -> StringName:
	if not _nodes.has(node_id):
		return StringName()
	var node_data: Dictionary = _nodes[node_id]
	return StringName(node_data.get("role", StringName()))


func get_queue_index(node_id: StringName) -> int:
	if not _nodes.has(node_id):
		return -1
	var node_data: Dictionary = _nodes[node_id]
	return int(node_data.get("queue_index", -1))


func get_neighbors(node_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var raw_neighbors: Variant = _adjacency.get(node_id, [])
	if not (raw_neighbors is Array):
		return result
	for neighbor_variant in raw_neighbors:
		var neighbor_id := StringName(neighbor_variant)
		if _nodes.has(neighbor_id):
			result.append(neighbor_id)
	return result


func get_edge_cost(
	from_node: StringName,
	to_node: StringName,
	context: Dictionary = {}
) -> float:
	if not has_node(from_node) or not has_node(to_node):
		return INF
	if to_node not in get_neighbors(from_node):
		return INF

	var from_position := get_position(from_node)
	var to_position := get_position(to_node)
	var edge_context := context.duplicate(true)
	var ignored_shelf: Shelf = null
	var ignored_variant: Variant = context.get("ignored_shelf", null)
	if is_instance_valid(ignored_variant) and ignored_variant is Shelf:
		ignored_shelf = ignored_variant as Shelf

	var agent_margin := float(context.get("agent_radius", 10.5))
	edge_context["dynamic_blocked"] = (
		_obstacles != null
		and _obstacles.is_segment_blocked(
			from_position,
			to_position,
			ignored_shelf,
			agent_margin
		)
	)
	edge_context["from_role"] = get_role(from_node)
	edge_context["to_role"] = get_role(to_node)
	edge_context["is_goal"] = to_node == StringName(
		context.get("goal_node", StringName())
	)
	return _policy.calculate_edge_cost(
		from_position,
		to_position,
		edge_context
	)


func find_nearest_node_ids(
	position: Vector2,
	limit: int = 4,
	include_queue_nodes: bool = false
) -> Array[StringName]:
	var candidates: Array[Dictionary] = []
	if not position.is_finite():
		return []

	for node_id in get_node_ids():
		var role := get_role(node_id)
		if not include_queue_nodes and _is_queue_role(role):
			continue
		if role == &"cashier":
			continue
		candidates.append({
			"node": node_id,
			"distance": position.distance_to(get_position(node_id))
		})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)
	var result: Array[StringName] = []
	for candidate in candidates:
		result.append(candidate.get("node", StringName()) as StringName)
		if result.size() >= maxi(1, limit):
			break
	return result


func get_node_for_role(
	role: StringName,
	queue_index: int = -1
) -> StringName:
	for node_id in get_node_ids():
		if get_role(node_id) != role:
			continue
		if queue_index >= 0 and get_queue_index(node_id) != queue_index:
			continue
		return node_id
	return StringName()


func get_nodes_touching_regions(
	regions: Array[Rect2],
	margin: float = 18.0
) -> Array[StringName]:
	var result: Array[StringName] = []
	if regions.is_empty():
		return result
	for node_id in get_node_ids():
		var position := get_position(node_id)
		for region in regions:
			if region.grow(margin).has_point(position):
				result.append(node_id)
				break
	return result


func get_topology_signature() -> String:
	return _topology_signature


func _rebuild(placement_anchors: Array[Vector2]) -> void:
	_nodes.clear()
	_adjacency.clear()
	_add_marker_nodes()
	_add_virtual_region_nodes(placement_anchors)
	_connect_semantic_lanes()
	_connect_general_regions()


func _add_marker_nodes() -> void:
	if _marker_root == null:
		return
	for child in _marker_root.get_children():
		var marker := child as Marker2D
		if marker == null:
			continue
		var role := StringName()
		if marker.has_meta(PATH_ROLE_META):
			role = StringName(str(marker.get_meta(PATH_ROLE_META)))
		_add_node(
			StringName(marker.name),
			marker.global_position,
			role,
			int(marker.get_meta(QUEUE_INDEX_META, -1)),
			false
		)


func _add_virtual_region_nodes(anchors: Array[Vector2]) -> void:
	if anchors.is_empty():
		return
	var bounds := Rect2(anchors[0], Vector2.ZERO)
	for anchor in anchors:
		bounds = bounds.expand(anchor)

	for x_index in range(REGION_X_FRACTIONS.size()):
		for y_index in range(REGION_Y_FRACTIONS.size()):
			var desired := Vector2(
				lerpf(bounds.position.x, bounds.end.x, REGION_X_FRACTIONS[x_index]),
				lerpf(bounds.position.y, bounds.end.y, REGION_Y_FRACTIONS[y_index])
			)
			var snapped := _find_nearest_anchor(desired, anchors)
			_add_node(
				StringName("VirtualRegion_%d_%d" % [x_index, y_index]),
				snapped,
				VIRTUAL_ROLE,
				-1,
				true
			)


func _connect_semantic_lanes() -> void:
	var entry := get_node_for_role(&"entry")
	var exit := get_node_for_role(&"exit")
	var aisle_right := get_node_for_role(&"aisle_right")
	var storage_return := get_node_for_role(&"storage_return")
	var queue_exit_right := get_node_for_role(&"queue_exit_right")
	var cashier := get_node_for_role(&"cashier")
	var queue_front := get_node_for_role(&"queue_front", 0)

	_connect_if_valid(entry, aisle_right)
	_connect_if_valid(exit, aisle_right)
	_connect_if_valid(storage_return, aisle_right)
	_connect_if_valid(aisle_right, queue_exit_right)
	_connect_if_valid(queue_front, cashier)

	var right_nodes: Array[StringName] = []
	var target_nodes: Array[StringName] = []
	for queue_index in range(3):
		var right_role := &"queue_front_right" if queue_index == 0 else &"queue_back_right"
		var target_role := &"queue_front" if queue_index == 0 else &"queue_back"
		var right_node := get_node_for_role(right_role, queue_index)
		var target_node := get_node_for_role(target_role, queue_index)
		if right_node != StringName():
			right_nodes.append(right_node)
		if target_node != StringName():
			target_nodes.append(target_node)
		_connect_if_valid(right_node, target_node)

	right_nodes.sort_custom(func(a: StringName, b: StringName) -> bool:
		return get_queue_index(a) < get_queue_index(b)
	)
	for index in range(right_nodes.size() - 1):
		_connect_if_valid(right_nodes[index], right_nodes[index + 1])
	if not right_nodes.is_empty():
		_connect_if_valid(right_nodes.back(), queue_exit_right)


func _connect_general_regions() -> void:
	var general_nodes: Array[StringName] = []
	for node_id in get_node_ids():
		var role := get_role(node_id)
		if _is_queue_role(role) or role == &"cashier":
			continue
		general_nodes.append(node_id)

	for source_index in range(general_nodes.size()):
		for target_index in range(source_index + 1, general_nodes.size()):
			var source := general_nodes[source_index]
			var target := general_nodes[target_index]
			if get_position(source).distance_to(get_position(target)) > MAX_GENERAL_EDGE_DISTANCE:
				continue
			_connect_bidirectional(source, target)

	for queue_role in [
		&"queue_front_right",
		&"queue_back_right",
		&"queue_exit_right"
	]:
		for node_id in get_node_ids():
			if get_role(node_id) != queue_role:
				continue
			for connector in find_nearest_node_ids(get_position(node_id), 3, false):
				_connect_bidirectional(node_id, connector)


func _add_node(
	node_id: StringName,
	position: Vector2,
	role: StringName,
	queue_index: int,
	is_virtual: bool
) -> void:
	if node_id == StringName() or not position.is_finite():
		return
	_nodes[node_id] = {
		"position": position,
		"role": role,
		"queue_index": queue_index,
		"virtual": is_virtual
	}
	if not _adjacency.has(node_id):
		_adjacency[node_id] = []


func _connect_if_valid(a: StringName, b: StringName) -> void:
	if a == StringName() or b == StringName():
		return
	_connect_bidirectional(a, b)


func _connect_bidirectional(a: StringName, b: StringName) -> void:
	if a == b or not has_node(a) or not has_node(b):
		return
	var neighbors_a: Array = _adjacency.get(a, [])
	var neighbors_b: Array = _adjacency.get(b, [])
	if b not in neighbors_a:
		neighbors_a.append(b)
	if a not in neighbors_b:
		neighbors_b.append(a)
	_adjacency[a] = neighbors_a
	_adjacency[b] = neighbors_b


func _find_nearest_anchor(
	position: Vector2,
	anchors: Array[Vector2]
) -> Vector2:
	var best := anchors[0]
	var best_distance := position.distance_squared_to(best)
	for anchor in anchors:
		var distance := position.distance_squared_to(anchor)
		if distance < best_distance:
			best = anchor
			best_distance = distance
	return best


func _is_queue_role(role: StringName) -> bool:
	return role in [
		&"queue_front",
		&"queue_back",
		&"queue_front_right",
		&"queue_back_right",
		&"queue_exit_right"
	]


func _make_topology_signature(
	marker_root: Node2D,
	anchors: Array[Vector2]
) -> String:
	var parts := PackedStringArray()
	if marker_root != null:
		for child in marker_root.get_children():
			var marker := child as Marker2D
			if marker == null:
				continue
			parts.append(
				"%s:%d:%d:%s:%d" % [
					marker.name,
					roundi(marker.global_position.x),
					roundi(marker.global_position.y),
					str(marker.get_meta(PATH_ROLE_META, "")),
					int(marker.get_meta(QUEUE_INDEX_META, -1))
				]
			)
	parts.append("anchors:%d" % anchors.size())
	if not anchors.is_empty():
		parts.append(
			"bounds:%d:%d:%d:%d" % [
				roundi(anchors.front().x),
				roundi(anchors.front().y),
				roundi(anchors.back().x),
				roundi(anchors.back().y)
			]
		)
	parts.sort()
	return "|".join(parts)
