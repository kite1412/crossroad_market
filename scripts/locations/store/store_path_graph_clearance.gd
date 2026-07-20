extends RefCounted
class_name StorePathGraphClearance

## Clearance checking functions for StorePathGraph.
## Handles collision detection along routes and physics queries.

var _graph  # StorePathGraph – untyped to avoid cyclic class_name reference


func _init(graph = null) -> void:
	_graph = graph


# ---------------------------------------------------------------------------
#  Route-level clearance
# ---------------------------------------------------------------------------

func is_route_clear(
	start: Vector2,
	route: Array[Vector2],
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF
) -> bool:
	var current := start

	for point in route:
		if not is_route_segment_clear(current, point, shelf_object, shelf_position):
			return false

		current = point

	return true


func is_checkout_route_from_access_clear(
	start: Vector2,
	route: Array[Vector2],
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF
) -> bool:
	var current := start

	for index in range(route.size()):
		var point := route[index]

		if index == 0:
			if not is_route_segment_clear_except_start(current, point, shelf_object, shelf_position):
				return false
		elif not is_route_segment_clear(current, point, shelf_object, shelf_position):
			return false

		current = point

	return true


func is_queue_route_clear(start: Vector2, route: Array[Vector2]) -> bool:
	var current := start

	for index in range(route.size()):
		var point := route[index]
		var allow_blocked_endpoint := index == route.size() - 1

		if allow_blocked_endpoint:
			if not is_route_segment_clear_except_endpoint(current, point):
				return false
		elif not is_route_segment_clear(current, point):
			return false

		current = point

	return true


func is_queue_route_clear_from_current_position(start: Vector2, route: Array[Vector2]) -> bool:
	var current := start

	for index in range(route.size()):
		var point := route[index]
		var allow_blocked_endpoint := index == route.size() - 1

		if index == 0:
			if allow_blocked_endpoint:
				if not is_route_segment_clear_except_start_and_endpoint(current, point):
					return false
			elif not is_route_segment_clear_except_start(current, point):
				return false
		elif allow_blocked_endpoint:
			if not is_route_segment_clear_except_endpoint(current, point):
				return false
		elif not is_route_segment_clear(current, point):
			return false

		current = point

	return true


func is_route_clear_from_current_position(start: Vector2, route: Array[Vector2]) -> bool:
	var current := start

	for index in range(route.size()):
		var point := route[index]

		if index == 0:
			if not is_route_segment_clear_except_start(current, point):
				return false
		elif not is_route_segment_clear(current, point):
			return false

		current = point

	return true


func is_route_to_access_clear(start: Vector2, route: Array[Vector2], shelf: Shelf, npc_node: Node = null) -> bool:
	if route.is_empty():
		return true

	var current := start
	var shelf_position: Vector2 = shelf.global_position if shelf != null else Vector2.INF

	for index in range(route.size()):
		var point := route[index]
		var is_last_segment := index == route.size() - 1

		if index == 0 and is_last_segment:
			if not is_route_segment_clear_except_start_and_endpoint(current, point, shelf, shelf_position, npc_node):
				return false
		elif index == 0:
			if not is_route_segment_clear_except_start(current, point, shelf, shelf_position, npc_node):
				return false
		elif is_last_segment:
			if not is_route_segment_clear_except_endpoint(current, point, shelf, shelf_position, npc_node):
				return false
		elif not is_route_segment_clear(current, point, shelf, shelf_position, npc_node):
			return false

		current = point

	return true


# ---------------------------------------------------------------------------
#  Segment-level clearance (bool variants)
# ---------------------------------------------------------------------------

func is_route_segment_clear(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> bool:
	if from_pos.distance_to(to_pos) <= _graph.ROUTE_CLEARANCE_EPSILON:
		return true

	var distance := from_pos.distance_to(to_pos)
	var steps: int = maxi(1, int(ceil(distance / _graph.ROUTE_SAMPLE_STEP)))

	for index in range(steps + 1):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))

		if not is_npc_access_point_clear(point, shelf_object, shelf_position, npc_node):
			return false

	return true


func is_route_segment_clear_except_endpoint(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> bool:
	if from_pos.distance_to(to_pos) <= _graph.ROUTE_CLEARANCE_EPSILON:
		return true

	var distance := from_pos.distance_to(to_pos)
	var steps: int = maxi(1, int(ceil(distance / _graph.ROUTE_SAMPLE_STEP)))

	for index in range(steps):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))

		if not is_npc_access_point_clear(point, shelf_object, shelf_position, npc_node):
			return false

	return true


func is_route_segment_clear_except_start(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> bool:
	if from_pos.distance_to(to_pos) <= _graph.ROUTE_CLEARANCE_EPSILON:
		return true

	var distance := from_pos.distance_to(to_pos)
	var steps: int = maxi(1, int(ceil(distance / _graph.ROUTE_SAMPLE_STEP)))

	for index in range(1, steps + 1):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))

		if not is_npc_access_point_clear(point, shelf_object, shelf_position, npc_node):
			return false

	return true


func is_route_segment_clear_except_start_and_endpoint(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> bool:
	if from_pos.distance_to(to_pos) <= _graph.ROUTE_CLEARANCE_EPSILON:
		return true

	var distance := from_pos.distance_to(to_pos)
	var steps: int = maxi(1, int(ceil(distance / _graph.ROUTE_SAMPLE_STEP)))

	for index in range(1, steps):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))

		if not is_npc_access_point_clear(point, shelf_object, shelf_position, npc_node):
			return false

	return true


func is_any_direction_segment_clear(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null,
	ignore_start: bool = false,
	ignore_endpoint: bool = false
) -> bool:
	if not from_pos.is_finite() or not to_pos.is_finite():
		return false

	var distance := from_pos.distance_to(to_pos)

	if distance <= _graph.ROUTE_CLEARANCE_EPSILON:
		return true

	var steps := maxi(
		1,
		int(ceil(distance / _graph.ROUTE_SAMPLE_STEP))
	)

	var first_index := 1 if ignore_start else 0
	var last_index := steps - 1 if ignore_endpoint else steps

	if first_index > last_index:
		return true

	for index in range(first_index, last_index + 1):
		var progress := float(index) / float(steps)
		var point := from_pos.lerp(to_pos, progress)

		if not is_npc_access_point_clear(
			point,
			shelf_object,
			shelf_position,
			npc_node
		):
			return false

	return true


# ---------------------------------------------------------------------------
#  Debug segment clearance (Dictionary variants)
# ---------------------------------------------------------------------------

func debug_route_clear(
	start: Vector2,
	route: Array[Vector2],
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF
) -> Dictionary:
	var current := start

	for index in range(route.size()):
		var point := route[index]
		var segment_result := debug_route_segment_clear(current, point, shelf_object, shelf_position)

		if not bool(segment_result.get("valid", false)):
			segment_result["blocked_segment_index"] = index
			segment_result["blocked_from"] = current
			segment_result["blocked_to"] = point
			return segment_result

		current = point

	return {"valid": true}


func debug_checkout_route_from_access_clear(
	start: Vector2,
	route: Array[Vector2],
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF
) -> Dictionary:
	var current := start

	for index in range(route.size()):
		var point := route[index]
		var segment_result: Dictionary

		if index == 0:
			segment_result = debug_route_segment_clear_except_start(current, point, shelf_object, shelf_position)
		else:
			segment_result = debug_route_segment_clear(current, point, shelf_object, shelf_position)

		if not bool(segment_result.get("valid", false)):
			segment_result["blocked_segment_index"] = index
			segment_result["blocked_from"] = current
			segment_result["blocked_to"] = point
			return segment_result

		current = point

	return {"valid": true}


func debug_queue_route_clear_from_current_position(start: Vector2, route: Array[Vector2]) -> Dictionary:
	if route.is_empty():
		return {"valid": true}

	var current := start

	for index in range(route.size()):
		var point := route[index]
		var allow_blocked_endpoint := index == route.size() - 1
		var segment_result: Dictionary

		if index == 0:
			if allow_blocked_endpoint:
				segment_result = debug_route_segment_clear_except_start_and_endpoint(current, point)
			else:
				segment_result = debug_route_segment_clear_except_start(current, point)
		elif allow_blocked_endpoint:
			segment_result = debug_route_segment_clear_except_endpoint(current, point)
		else:
			segment_result = debug_route_segment_clear(current, point)

		if not bool(segment_result.get("valid", false)):
			segment_result["blocked_segment_index"] = index
			segment_result["blocked_from"] = current
			segment_result["blocked_to"] = point
			return segment_result

		current = point

	return {"valid": true}


func debug_route_clear_from_current_position(start: Vector2, route: Array[Vector2]) -> Dictionary:
	if route.is_empty():
		return {"valid": true}

	var current := start

	for index in range(route.size()):
		var point := route[index]
		var segment_result: Dictionary

		if index == 0:
			segment_result = debug_route_segment_clear_except_start(current, point)
		else:
			segment_result = debug_route_segment_clear(current, point)

		if not bool(segment_result.get("valid", false)):
			segment_result["blocked_segment_index"] = index
			segment_result["blocked_from"] = current
			segment_result["blocked_to"] = point
			return segment_result

		current = point

	return {"valid": true}


func debug_route_to_access_clear(start: Vector2, route: Array[Vector2], shelf: Shelf, npc_node: Node = null) -> Dictionary:
	var start_clear := debug_npc_access_point_clear(start, null, Vector2.INF, npc_node)

	if route.is_empty():
		return {
			"valid": true,
			"route_start": start,
			"route_distance": 0.0,
			"is_start_blocked": not bool(start_clear.get("valid", false)),
			"start_blocker": start_clear.get("blocker", ""),
			"blocked_segment_index": -1,
			"blocked_from": Vector2.INF,
			"blocked_to": Vector2.INF,
			"blocked_point": Vector2.INF,
			"blocked_reason": "",
			"blocker": ""
		}

	var current := start
	var shelf_position: Vector2 = shelf.global_position if shelf != null else Vector2.INF

	for index in range(route.size()):
		var point := route[index]
		var is_last_segment := index == route.size() - 1
		var segment_result := {}

		if index == 0 and is_last_segment:
			segment_result = debug_route_segment_clear_except_start_and_endpoint(current, point, shelf, shelf_position, npc_node)
		elif index == 0:
			segment_result = debug_route_segment_clear_except_start(current, point, shelf, shelf_position, npc_node)
		elif is_last_segment:
			segment_result = debug_route_segment_clear_except_endpoint(current, point, shelf, shelf_position, npc_node)
		else:
			segment_result = debug_route_segment_clear(current, point, shelf, shelf_position, npc_node)

		if not bool(segment_result.get("valid", false)):
			segment_result["blocked_segment_index"] = index
			segment_result["blocked_from"] = current
			segment_result["blocked_to"] = point
			segment_result["is_start_blocked"] = not bool(start_clear.get("valid", false))
			segment_result["start_blocker"] = start_clear.get("blocker", "")
			return segment_result

		current = point

	return {
		"valid": true,
		"route_start": start,
		"route_distance": _graph._routes.get_route_distance(start, route),
		"is_start_blocked": not bool(start_clear.get("valid", false)),
		"start_blocker": start_clear.get("blocker", ""),
		"blocked_segment_index": -1,
		"blocked_from": Vector2.INF,
		"blocked_to": Vector2.INF,
		"blocked_point": Vector2.INF,
		"blocked_reason": "",
		"blocker": ""
	}


# ---------------------------------------------------------------------------
#  Debug segment clearance (Dictionary)
# ---------------------------------------------------------------------------

func debug_route_segment_clear_except_endpoint(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Dictionary:
	if from_pos.distance_to(to_pos) <= _graph.ROUTE_CLEARANCE_EPSILON:
		return {"valid": true}

	var distance := from_pos.distance_to(to_pos)
	var steps: int = maxi(1, int(ceil(distance / _graph.ROUTE_SAMPLE_STEP)))

	for index in range(steps):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))
		var point_result := debug_npc_access_point_clear(point, shelf_object, shelf_position, npc_node)

		if not bool(point_result.get("valid", false)):
			return {
				"valid": false,
				"blocked_point": point,
				"blocked_reason": "blocked_except_endpoint:%s" % str(point_result.get("blocked_reason", "")),
				"blocker": point_result.get("blocker", "")
			}

	return {"valid": true}


func debug_route_segment_clear_except_start(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Dictionary:
	if from_pos.distance_to(to_pos) <= _graph.ROUTE_CLEARANCE_EPSILON:
		return {"valid": true}

	var distance := from_pos.distance_to(to_pos)
	var steps: int = maxi(1, int(ceil(distance / _graph.ROUTE_SAMPLE_STEP)))

	for index in range(1, steps + 1):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))
		var point_result := debug_npc_access_point_clear(point, shelf_object, shelf_position, npc_node)

		if not bool(point_result.get("valid", false)):
			return {
				"valid": false,
				"blocked_point": point,
				"blocked_reason": "blocked_except_start:%s" % str(point_result.get("blocked_reason", "")),
				"blocker": point_result.get("blocker", "")
			}

	return {"valid": true}


func debug_route_segment_clear_except_start_and_endpoint(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Dictionary:
	if from_pos.distance_to(to_pos) <= _graph.ROUTE_CLEARANCE_EPSILON:
		return {"valid": true}

	var distance := from_pos.distance_to(to_pos)
	var steps: int = maxi(1, int(ceil(distance / _graph.ROUTE_SAMPLE_STEP)))

	for index in range(1, steps):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))
		var point_result := debug_npc_access_point_clear(point, shelf_object, shelf_position, npc_node)

		if not bool(point_result.get("valid", false)):
			return {
				"valid": false,
				"blocked_point": point,
				"blocked_reason": "blocked_except_start_and_endpoint:%s" % str(point_result.get("blocked_reason", "")),
				"blocker": point_result.get("blocker", "")
			}

	return {"valid": true}


func debug_route_segment_clear(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Dictionary:
	if from_pos.distance_to(to_pos) <= _graph.ROUTE_CLEARANCE_EPSILON:
		return {"valid": true}

	var distance := from_pos.distance_to(to_pos)
	var steps: int = maxi(1, int(ceil(distance / _graph.ROUTE_SAMPLE_STEP)))

	for index in range(steps + 1):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))
		var point_result := debug_npc_access_point_clear(point, shelf_object, shelf_position, npc_node)

		if not bool(point_result.get("valid", false)):
			return {
				"valid": false,
				"blocked_point": point,
				"blocked_reason": "blocked:%s" % str(point_result.get("blocked_reason", "")),
				"blocker": point_result.get("blocker", "")
			}

	return {"valid": true}


# ---------------------------------------------------------------------------
#  Point-level clearance
# ---------------------------------------------------------------------------

func is_npc_access_point_clear(
	position: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> bool:
	if shelf_object != null and shelf_position.is_finite():
		var shelf_rect := get_object_body_rect_at(shelf_object, shelf_position)

		if _rect_has_area(shelf_rect) and get_npc_standing_rect(position).intersects(shelf_rect):
			return false

	return is_npc_standing_position_clear(position, npc_node)


func debug_npc_access_point_clear(
	position: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null
) -> Dictionary:
	if shelf_object != null and shelf_position.is_finite():
		var shelf_rect := get_object_body_rect_at(shelf_object, shelf_position)

		if _rect_has_area(shelf_rect) and get_npc_standing_rect(position).intersects(shelf_rect):
			return {
				"valid": false,
				"blocked_reason": "shelf_body_rect",
				"blocker": shelf_object.name
			}

	if _graph._store == null:
		return {
			"valid": false,
			"blocked_reason": "missing_store",
			"blocker": "<store_null>"
		}

	var shape := RectangleShape2D.new()
	shape.size = _graph.STANDING_SHAPE_SIZE

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, position + _graph.STANDING_SHAPE_OFFSET)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 1

	if npc_node is CollisionObject2D:
		query.exclude = [(npc_node as CollisionObject2D).get_rid()]

	var hits: Array[Dictionary] = _graph._store.get_world_2d().direct_space_state.intersect_shape(query, 16)

	if hits.is_empty():
		return {"valid": true}

	var hit: Dictionary = hits[0]
	var collider: Variant = hit.get("collider", null)
	var collider_node := collider as Node
	var collider_name: String = collider_node.name if collider_node != null else str(collider)
	var collider_path: String = str(collider_node.get_path()) if collider_node != null and collider_node.is_inside_tree() else ""

	return {
		"valid": false,
		"blocked_reason": _get_debug_blocker_reason(collider_node),
		"blocker": "%s%s" % [collider_name, ":%s" % collider_path if collider_path != "" else ""]
	}


func is_npc_standing_position_clear(position: Vector2, npc: Node = null) -> bool:
	if _graph._store == null:
		return false

	var shape := RectangleShape2D.new()
	shape.size = _graph.STANDING_SHAPE_SIZE

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, position + _graph.STANDING_SHAPE_OFFSET)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 1

	if npc is CollisionObject2D:
		query.exclude = [(npc as CollisionObject2D).get_rid()]

	var hits: Array[Dictionary] = _graph._store.get_world_2d().direct_space_state.intersect_shape(query, 16)
	return hits.is_empty()


# ---------------------------------------------------------------------------
#  Geometry helpers
# ---------------------------------------------------------------------------

func get_npc_standing_rect(position: Vector2) -> Rect2:
	var center: Vector2 = position + _graph.STANDING_SHAPE_OFFSET
	return Rect2(center - _graph.STANDING_SHAPE_SIZE * 0.5, _graph.STANDING_SHAPE_SIZE)


func get_object_body_rect_at(object: Node2D, candidate: Vector2) -> Rect2:
	var collision_shape := _get_object_collision_shape(object)

	if collision_shape == null:
		return Rect2(candidate - Vector2(32, 24), Vector2(64, 48))

	var rectangle := collision_shape.shape as RectangleShape2D

	if rectangle == null:
		return Rect2(candidate - Vector2(32, 24), Vector2(64, 48))

	var center := candidate + collision_shape.position
	return Rect2(center - rectangle.size * 0.5, rectangle.size)


func _get_object_collision_shape(object: Node2D) -> CollisionShape2D:
	if object == null:
		return null

	return object.get_node_or_null("PhysicsBody/CollisionShape2D") as CollisionShape2D


func _rect_has_area(rect: Rect2) -> bool:
	return rect.size.x > 0.0 and rect.size.y > 0.0


func _get_debug_blocker_reason(collider_node: Node) -> String:
	if collider_node == null:
		return "physics_body"

	var name_text := collider_node.name.to_lower()

	if collider_node is NPC:
		return "npc"

	if name_text.contains("player"):
		return "player"

	if name_text.contains("cashier"):
		return "cashier"

	if name_text.contains("shelf"):
		return "shelf"

	if name_text.contains("wall") or name_text.contains("bound"):
		return "wall_or_bounds"

	if name_text.contains("queue"):
		return "queue_area"

	return "%s:%s" % [collider_node.get_class(), collider_node.name]
