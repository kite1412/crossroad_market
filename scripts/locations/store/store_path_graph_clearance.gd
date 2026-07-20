extends RefCounted
class_name StorePathGraphClearance

## Clearance checking functions for StorePathGraph
## Handles collision detection along routes

## Reference to constants (set by parent)
var _constants: StorePathGraphConstants
## Reference to store (set by parent)
var _store: Node2D = null

func _init(consts: StorePathGraphConstants = null) -> void:
	_constants = consts


## Checks if all segments in a route are clear
func is_route_clear(
	start: Vector2,
	route: Array[Vector2],
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	is_segment_clear_func: Callable = Callable()
) -> bool:
	var current := start

	for point in route:
		if not is_segment_clear_func.call(current, point, shelf_object, shelf_position):
			return false

		current = point

	return true


## Checks if a single route segment is clear (no collision)
func is_route_segment_clear(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null,
	is_access_point_clear_func: Callable = Callable()
) -> bool:
	if from_pos.distance_to(to_pos) <= _constants.ROUTE_CLEARANCE_EPSILON:
		return true

	var distance := from_pos.distance_to(to_pos)
	var steps := maxi(1, int(ceil(distance / _constants.ROUTE_SAMPLE_STEP)))

	for index in range(steps + 1):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))

		if not is_access_point_clear_func.call(point, shelf_object, shelf_position, npc_node):
			return false

	return true


## Checks if a route segment is clear, ignoring the endpoint
func is_route_segment_clear_except_endpoint(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null,
	is_access_point_clear_func: Callable = Callable()
) -> bool:
	if from_pos.distance_to(to_pos) <= _constants.ROUTE_CLEARANCE_EPSILON:
		return true

	var distance := from_pos.distance_to(to_pos)
	var steps := maxi(1, int(ceil(distance / _constants.ROUTE_SAMPLE_STEP)))

	for index in range(steps):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))

		if not is_access_point_clear_func.call(point, shelf_object, shelf_position, npc_node):
			return false

	return true


## Checks if a route segment is clear, ignoring the start point
func is_route_segment_clear_except_start(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null,
	is_access_point_clear_func: Callable = Callable()
) -> bool:
	if from_pos.distance_to(to_pos) <= _constants.ROUTE_CLEARANCE_EPSILON:
		return true

	var distance := from_pos.distance_to(to_pos)
	var steps := maxi(1, int(ceil(distance / _constants.ROUTE_SAMPLE_STEP)))

	for index in range(1, steps + 1):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))

		if not is_access_point_clear_func.call(point, shelf_object, shelf_position, npc_node):
			return false

	return true


## Checks if a route segment is clear, ignoring both start and endpoint
func is_route_segment_clear_except_start_and_endpoint(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null,
	is_access_point_clear_func: Callable = Callable()
) -> bool:
	if from_pos.distance_to(to_pos) <= _constants.ROUTE_CLEARANCE_EPSILON:
		return true

	var distance := from_pos.distance_to(to_pos)
	var steps := maxi(1, int(ceil(distance / _constants.ROUTE_SAMPLE_STEP)))

	for index in range(1, steps):
		var point := from_pos.lerp(to_pos, float(index) / float(steps))

		if not is_access_point_clear_func.call(point, shelf_object, shelf_position, npc_node):
			return false

	return true


## Checks if an ANY direction route segment is clear (supports diagonal movement)
## This is the key function that enables diagonal movement after shelf access
func is_any_direction_segment_clear(
	from_pos: Vector2,
	to_pos: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null,
	ignore_start: bool = false,
	ignore_endpoint: bool = false,
	is_access_point_clear_func: Callable = Callable()
) -> bool:
	if not from_pos.is_finite() or not to_pos.is_finite():
		return false

	var distance := from_pos.distance_to(to_pos)

	if distance <= _constants.ROUTE_CLEARANCE_EPSILON:
		return true

	var steps := maxi(
		1,
		int(ceil(distance / _constants.ROUTE_SAMPLE_STEP))
	)

	var first_index := 1 if ignore_start else 0
	var last_index := steps - 1 if ignore_endpoint else steps

	if first_index > last_index:
		return true

	for index in range(first_index, last_index + 1):
		var progress := float(index) / float(steps)
		var point := from_pos.lerp(to_pos, progress)

		if not is_access_point_clear_func.call(
			point,
			shelf_object,
			shelf_position,
			npc_node
		):
			return false

	return true


## Checks if checkout route from access point is clear
func is_checkout_route_from_access_clear(
	start: Vector2,
	route: Array[Vector2],
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	is_segment_clear_except_start_func: Callable = Callable(),
	is_segment_clear_func: Callable = Callable()
) -> bool:
	var current := start

	for index in range(route.size()):
		var point := route[index]

		if index == 0:
			if not is_segment_clear_except_start_func.call(current, point, shelf_object, shelf_position):
				return false
		elif not is_segment_clear_func.call(current, point, shelf_object, shelf_position):
			return false

		current = point

	return true


## Checks if queue route is clear
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


## Checks if queue route is clear from current position
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


## Checks if route to access point is clear
func is_route_to_access_clear(
	start: Vector2,
	route: Array[Vector2],
	shelf: Node,
	npc_node: Node = null
) -> bool:
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


## Checks if route is clear from current position
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


## Checks if an NPC standing position is clear (physics check)
func is_npc_standing_position_clear(position: Vector2, npc: Node = null) -> bool:
	if _store == null:
		return false

	var shape := RectangleShape2D.new()
	shape.size = _constants.STANDING_SHAPE_SIZE

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, position + _constants.STANDING_SHAPE_OFFSET)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 1

	if npc is CollisionObject2D:
		query.exclude = [(npc as CollisionObject2D).get_rid()]

	var hits := _store.get_world_2d().direct_space_state.intersect_shape(query, 16)
	return hits.is_empty()


## Checks if an NPC access point is clear (shelf collision + physics)
func is_npc_access_point_clear(
	position: Vector2,
	shelf_object: Node2D = null,
	shelf_position: Vector2 = Vector2.INF,
	npc_node: Node = null,
	get_object_body_rect_func: Callable = Callable(),
	get_npc_standing_rect_func: Callable = Callable()
) -> bool:
	if shelf_object != null and shelf_position.is_finite():
		var shelf_rect := get_object_body_rect_func.call(shelf_object, shelf_position)

		if _rect_has_area(shelf_rect) and get_npc_standing_rect_func.call(position).intersects(shelf_rect):
			return false

	return is_npc_standing_position_clear(position, npc_node)


## Gets the NPC standing rect at a position
func get_npc_standing_rect(position: Vector2) -> Rect2:
	var center := position + _constants.STANDING_SHAPE_OFFSET
	return Rect2(center - _constants.STANDING_SHAPE_SIZE * 0.5, _constants.STANDING_SHAPE_SIZE)


## Gets the body rect of an object at a position
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
