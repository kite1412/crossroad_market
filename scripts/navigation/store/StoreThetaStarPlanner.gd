class_name StoreThetaStarPlanner
extends RefCounted

const DEFAULT_STANDING_SIZE := Vector2(21, 9)
const DEFAULT_STANDING_OFFSET := Vector2(0, -8)
const ROUTE_SAMPLE_STEP: float = 8.0
const CONNECTOR_LIMIT: int = 4
const CONNECTOR_SCAN_LIMIT: int = 48
const MAX_EXPANSIONS: int = 1200
const DIRECT_EPSILON: float = 2.0

var _store: Node2D = null
var _anchors: Array[Vector2] = []
var _anchor_index: Dictionary = {}
var _spacing: float = 12.0
var _obstacles: StoreDynamicObstacleTracker = null
var _line_cache: Dictionary = {}
var _anchor_signature: String = ""


func setup(
	store: Node2D,
	anchors: Array[Vector2],
	obstacles: StoreDynamicObstacleTracker
) -> void:
	_store = store
	_obstacles = obstacles
	var next_signature := _make_anchor_signature(anchors)
	if next_signature == _anchor_signature and not _anchors.is_empty():
		return
	_anchor_signature = next_signature
	_anchors = anchors.duplicate()
	_spacing = _detect_spacing(_anchors)
	_rebuild_anchor_index()
	_line_cache.clear()


func clear_dynamic_cache() -> void:
	_line_cache.clear()


func find_path(
	start_position: Vector2,
	goal_position: Vector2,
	context: Dictionary = {}
) -> Array[Vector2]:
	if not start_position.is_finite() or not goal_position.is_finite():
		return []
	if start_position.distance_to(goal_position) <= DIRECT_EPSILON:
		return []

	if _is_segment_clear(
		start_position,
		goal_position,
		context,
		bool(context.get("ignore_start_collision", true)),
		bool(context.get("ignore_goal_collision", false))
	):
		return [goal_position]

	if _anchors.is_empty():
		return []

	var start_connectors := _get_nearest_clear_anchor_indices(
		start_position,
		context,
		true
	)
	var goal_connectors := _get_nearest_clear_anchor_indices(
		goal_position,
		context,
		false
	)
	if start_connectors.is_empty() or goal_connectors.is_empty():
		return []

	var best_route: Array[Vector2] = []
	var best_distance := INF
	for start_index in start_connectors:
		for goal_index in goal_connectors:
			var anchor_path := _find_anchor_path(
				start_index,
				goal_index,
				context
			)
			if anchor_path.is_empty():
				continue

			var route: Array[Vector2] = []
			for anchor_index in anchor_path:
				_append_unique(route, _anchors[anchor_index])
			_append_unique(route, goal_position)
			route = _simplify_route(start_position, route, context)
			var distance := _get_route_distance(start_position, route)
			if distance < best_distance:
				best_distance = distance
				best_route = route
	return best_route


func is_direct_path_clear(
	start_position: Vector2,
	goal_position: Vector2,
	context: Dictionary = {}
) -> bool:
	return _is_segment_clear(
		start_position,
		goal_position,
		context,
		bool(context.get("ignore_start_collision", true)),
		bool(context.get("ignore_goal_collision", false))
	)


func _find_anchor_path(
	start_index: int,
	goal_index: int,
	context: Dictionary
) -> Array[int]:
	if start_index == goal_index:
		return [start_index]

	var open_set: Array[int] = [start_index]
	var closed: Dictionary = {}
	var g_score: Dictionary = {start_index: 0.0}
	var f_score: Dictionary = {
		start_index: _anchors[start_index].distance_to(_anchors[goal_index])
	}
	var parent: Dictionary = {start_index: start_index}
	var expansions := 0

	while not open_set.is_empty() and expansions < MAX_EXPANSIONS:
		expansions += 1
		var current := _pop_lowest_score(open_set, f_score)
		if current == goal_index:
			return _reconstruct_anchor_path(parent, start_index, goal_index)
		if closed.has(current):
			continue
		closed[current] = true

		for neighbor in _get_neighbor_indices(current):
			if closed.has(neighbor):
				continue

			var parent_index := int(parent.get(current, current))
			var candidate_parent := current
			var tentative_cost := float(g_score.get(current, INF)) + (
				_anchors[current].distance_to(_anchors[neighbor])
			)

			if (
				parent_index != current
				and _is_segment_clear(
					_anchors[parent_index],
					_anchors[neighbor],
					context,
					false,
					false
				)
			):
				var parent_cost := float(g_score.get(parent_index, INF)) + (
					_anchors[parent_index].distance_to(_anchors[neighbor])
				)
				if parent_cost < tentative_cost:
					tentative_cost = parent_cost
					candidate_parent = parent_index

			if tentative_cost >= float(g_score.get(neighbor, INF)):
				continue

			parent[neighbor] = candidate_parent
			g_score[neighbor] = tentative_cost
			f_score[neighbor] = tentative_cost + (
				_anchors[neighbor].distance_to(_anchors[goal_index])
			)
			if neighbor not in open_set:
				open_set.append(neighbor)

	return []


func _get_nearest_clear_anchor_indices(
	position: Vector2,
	context: Dictionary,
	is_start: bool
) -> Array[int]:
	var ordered: Array[int] = []
	for index in range(_anchors.size()):
		ordered.append(index)
	ordered.sort_custom(func(a: int, b: int) -> bool:
		return _anchors[a].distance_squared_to(position) < (
			_anchors[b].distance_squared_to(position)
		)
	)

	var result: Array[int] = []
	var scanned := 0
	for index in ordered:
		scanned += 1
		if scanned > CONNECTOR_SCAN_LIMIT:
			break
		var clear := _is_segment_clear(
			position,
			_anchors[index],
			context,
			is_start,
			not is_start
		)
		if not clear:
			continue
		result.append(index)
		if result.size() >= CONNECTOR_LIMIT:
			break
	return result


func _get_neighbor_indices(index: int) -> Array[int]:
	var result: Array[int] = []
	if index < 0 or index >= _anchors.size():
		return result
	var key := _to_grid_key(_anchors[index])
	for offset in [
		Vector2i(-1, -1),
		Vector2i(0, -1),
		Vector2i(1, -1),
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(-1, 1),
		Vector2i(0, 1),
		Vector2i(1, 1)
	]:
		var neighbor_key := key + offset
		if not _anchor_index.has(neighbor_key):
			continue
		var neighbor_index := int(_anchor_index[neighbor_key])
		if neighbor_index == index:
			continue
		result.append(neighbor_index)
	return result


func _simplify_route(
	start_position: Vector2,
	route: Array[Vector2],
	context: Dictionary
) -> Array[Vector2]:
	if route.size() <= 1:
		return route
	var simplified: Array[Vector2] = []
	var anchor := start_position
	var cursor := 0

	while cursor < route.size():
		var farthest := cursor
		for candidate_index in range(route.size() - 1, cursor - 1, -1):
			var is_first := simplified.is_empty()
			var is_last := candidate_index == route.size() - 1
			if _is_segment_clear(
				anchor,
				route[candidate_index],
				context,
				is_first and bool(context.get("ignore_start_collision", true)),
				is_last and bool(context.get("ignore_goal_collision", false))
			):
				farthest = candidate_index
				break
		_append_unique(simplified, route[farthest])
		anchor = route[farthest]
		cursor = farthest + 1
	return simplified


func _is_segment_clear(
	from_position: Vector2,
	to_position: Vector2,
	context: Dictionary,
	ignore_start: bool,
	ignore_endpoint: bool
) -> bool:
	if from_position.distance_to(to_position) <= DIRECT_EPSILON:
		return true

	var cache_key := _make_line_cache_key(
		from_position,
		to_position,
		context,
		ignore_start,
		ignore_endpoint
	)
	if _line_cache.has(cache_key):
		return bool(_line_cache[cache_key])

	var ignored_shelf: Shelf = null
	var ignored_shelf_variant: Variant = context.get("ignored_shelf", null)
	if is_instance_valid(ignored_shelf_variant) and ignored_shelf_variant is Shelf:
		ignored_shelf = ignored_shelf_variant as Shelf
	var agent_margin := float(context.get("agent_radius", 10.5))
	if (
		_obstacles != null
		and _obstacles.is_segment_blocked(
			from_position,
			to_position,
			ignored_shelf,
			agent_margin
		)
	):
		_line_cache[cache_key] = false
		return false

	var clear := _physics_segment_clear(
		from_position,
		to_position,
		context,
		ignore_start,
		ignore_endpoint,
		ignored_shelf
	)
	_line_cache[cache_key] = clear
	return clear


func _physics_segment_clear(
	from_position: Vector2,
	to_position: Vector2,
	context: Dictionary,
	ignore_start: bool,
	ignore_endpoint: bool,
	ignored_shelf: Shelf
) -> bool:
	if _store == null or _store.get_world_2d() == null:
		return false
	var distance := from_position.distance_to(to_position)
	var steps := maxi(1, int(ceil(distance / ROUTE_SAMPLE_STEP)))
	var first_index := 1 if ignore_start else 0
	var last_index := steps - 1 if ignore_endpoint else steps
	if first_index > last_index:
		return true

	var standing_shape := RectangleShape2D.new()
	standing_shape.size = DEFAULT_STANDING_SIZE
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = standing_shape
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 1

	var npc_variant: Variant = context.get("npc", null)
	if is_instance_valid(npc_variant) and npc_variant is CollisionObject2D:
		query.exclude = [(npc_variant as CollisionObject2D).get_rid()]

	for index in range(first_index, last_index + 1):
		var progress := float(index) / float(steps)
		var point := from_position.lerp(to_position, progress)
		query.transform = Transform2D(0.0, point + DEFAULT_STANDING_OFFSET)
		var hits: Array[Dictionary] = (
			_store.get_world_2d().direct_space_state.intersect_shape(query, 16)
		)
		for hit in hits:
			var collider_variant: Variant = hit.get("collider", null)
			if not is_instance_valid(collider_variant):
				continue
			var collider := collider_variant as Node
			if collider == null:
				continue
			if ignored_shelf != null and _is_descendant_of(collider, ignored_shelf):
				continue
			if collider is NPC or collider.is_in_group("npcs"):
				continue
			if collider.name.to_lower().contains("player"):
				continue
			return false
	return true


func _reconstruct_anchor_path(
	parent: Dictionary,
	start_index: int,
	goal_index: int
) -> Array[int]:
	var result: Array[int] = [goal_index]
	var cursor := goal_index
	var guard := 0
	while cursor != start_index and guard < _anchors.size() + 4:
		guard += 1
		cursor = int(parent.get(cursor, -1))
		if cursor < 0:
			return []
		result.push_front(cursor)
	return result


func _pop_lowest_score(
	open_set: Array[int],
	f_score: Dictionary
) -> int:
	var best_list_index := 0
	var best_score := INF
	for list_index in range(open_set.size()):
		var node_index := open_set[list_index]
		var score := float(f_score.get(node_index, INF))
		if score < best_score:
			best_score = score
			best_list_index = list_index
	return open_set.pop_at(best_list_index)


func _rebuild_anchor_index() -> void:
	_anchor_index.clear()
	for index in range(_anchors.size()):
		_anchor_index[_to_grid_key(_anchors[index])] = index


func _to_grid_key(position: Vector2) -> Vector2i:
	var safe_spacing := maxf(1.0, _spacing)
	return Vector2i(
		roundi(position.x / safe_spacing),
		roundi(position.y / safe_spacing)
	)


func _detect_spacing(points: Array[Vector2]) -> float:
	if points.size() < 2:
		return 12.0
	var best := INF
	var sample_count := mini(points.size(), 80)
	for a_index in range(sample_count):
		for b_index in range(a_index + 1, sample_count):
			var delta := points[a_index] - points[b_index]
			if absf(delta.x) > 0.1:
				best = minf(best, absf(delta.x))
			if absf(delta.y) > 0.1:
				best = minf(best, absf(delta.y))
	if best == INF:
		return 12.0
	return maxf(4.0, best)


func _get_route_distance(
	start_position: Vector2,
	route: Array[Vector2]
) -> float:
	var total := 0.0
	var previous := start_position
	for point in route:
		total += previous.distance_to(point)
		previous = point
	return total


func _append_unique(route: Array[Vector2], point: Vector2) -> void:
	if not point.is_finite():
		return
	if not route.is_empty() and route.back().distance_to(point) <= DIRECT_EPSILON:
		return
	route.append(point)


func _make_line_cache_key(
	from_position: Vector2,
	to_position: Vector2,
	context: Dictionary,
	ignore_start: bool,
	ignore_endpoint: bool
) -> String:
	var revision := 0
	if _obstacles != null:
		revision = _obstacles.get_revision()
	var shelf_id := 0
	var shelf_variant: Variant = context.get("ignored_shelf", null)
	if is_instance_valid(shelf_variant) and shelf_variant is Shelf:
		shelf_id = (shelf_variant as Shelf).get_instance_id()
	return "%d:%d,%d:%d,%d:%d:%d:%d" % [
		revision,
		roundi(from_position.x),
		roundi(from_position.y),
		roundi(to_position.x),
		roundi(to_position.y),
		shelf_id,
		int(ignore_start),
		int(ignore_endpoint)
	]


func _make_anchor_signature(points: Array[Vector2]) -> String:
	if points.is_empty():
		return "empty"
	return "%d:%d:%d:%d:%d" % [
		points.size(),
		roundi(points.front().x),
		roundi(points.front().y),
		roundi(points.back().x),
		roundi(points.back().y)
	]


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false
