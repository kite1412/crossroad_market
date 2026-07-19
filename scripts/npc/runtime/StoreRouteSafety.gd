class_name StoreRouteSafety
extends RefCounted

const STANDING_SHAPE_SIZE := Vector2(21, 9)
const STANDING_SHAPE_OFFSET := Vector2(0, -8)
const ROUTE_SAMPLE_STEP: float = 6.0
const ENDPOINT_CLEARANCE: float = 8.0
const MARKER_CORRIDOR_RADIUS: float = 5.5
const POINT_EPSILON: float = 2.0
const ALL_PHYSICS_LAYERS: int = 0x7FFFFFFF

var npc: CharacterBody2D = null


func setup(npc_node: CharacterBody2D) -> void:
	npc = npc_node


func sanitize_store_route(route: Array[Vector2]) -> Array[Vector2]:
	var clean_route := _dedupe_route_points(route)

	if npc == null or clean_route.is_empty():
		return clean_route

	var store := _get_store()
	if store == null:
		return clean_route

	clean_route = _insert_intermediate_markers(
		npc.global_position,
		clean_route,
		store
	)

	if not _is_route_clear(
		npc.global_position,
		clean_route,
		store
	):
		return []

	return clean_route


func _insert_intermediate_markers(
	start_position: Vector2,
	route: Array[Vector2],
	store: Node
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var current := start_position

	for target in route:
		for marker_position in _get_markers_between(
			current,
			target,
			store
		):
			_append_unique_point(result, marker_position)

		_append_unique_point(result, target)
		current = target

	return result


func _get_markers_between(
	from_position: Vector2,
	to_position: Vector2,
	store: Node
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var markers := store.get_node_or_null("StorePathMarkers") as Node2D

	if markers == null:
		return result

	var segment := to_position - from_position
	var length_squared := segment.length_squared()

	if length_squared <= POINT_EPSILON * POINT_EPSILON:
		return result

	var ranked: Array[Dictionary] = []

	for child in markers.get_children():
		var marker := child as Marker2D
		if marker == null:
			continue

		var marker_position := marker.global_position
		if (
			marker_position.distance_to(from_position) <= POINT_EPSILON
			or marker_position.distance_to(to_position) <= POINT_EPSILON
		):
			continue

		var progress := (
			(marker_position - from_position).dot(segment)
			/ length_squared
		)

		if progress <= 0.02 or progress >= 0.98:
			continue

		var closest := from_position + segment * progress
		if marker_position.distance_to(closest) > MARKER_CORRIDOR_RADIUS:
			continue

		ranked.append({
			"position": marker_position,
			"progress": progress
		})

	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("progress", 0.0)) < float(b.get("progress", 0.0))
	)

	for entry in ranked:
		result.append(entry.get("position", Vector2.INF) as Vector2)

	return _dedupe_route_points(result)


func _is_route_clear(
	start_position: Vector2,
	route: Array[Vector2],
	store: Node
) -> bool:
	var current := start_position

	for target in route:
		if not _is_segment_clear(current, target, store):
			return false
		current = target

	return true


func _is_segment_clear(
	from_position: Vector2,
	to_position: Vector2,
	store: Node
) -> bool:
	var distance := from_position.distance_to(to_position)
	if distance <= ENDPOINT_CLEARANCE * 2.0:
		return true

	var direction := from_position.direction_to(to_position)
	var sample_start := from_position + direction * ENDPOINT_CLEARANCE
	var sample_end := to_position - direction * ENDPOINT_CLEARANCE
	var sample_distance := sample_start.distance_to(sample_end)
	var steps := maxi(1, int(ceil(sample_distance / ROUTE_SAMPLE_STEP)))
	var shape := RectangleShape2D.new()
	shape.size = STANDING_SHAPE_SIZE
	var exclusions := _get_dynamic_actor_rids(store)
	var space_state := store.get_world_2d().direct_space_state

	for index in range(steps + 1):
		var progress := float(index) / float(steps)
		var point := sample_start.lerp(sample_end, progress)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(
			0.0,
			point + STANDING_SHAPE_OFFSET
		)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.collision_mask = ALL_PHYSICS_LAYERS
		query.exclude = exclusions

		if not space_state.intersect_shape(query, 8).is_empty():
			return false

	return true


func _get_dynamic_actor_rids(store: Node) -> Array[RID]:
	var result: Array[RID] = []

	if npc is CollisionObject2D:
		result.append((npc as CollisionObject2D).get_rid())

	var player_variant: Variant = store.get("player")
	if player_variant is CollisionObject2D:
		var player_rid := (player_variant as CollisionObject2D).get_rid()
		if player_rid not in result:
			result.append(player_rid)

	for node in store.get_tree().get_nodes_in_group("npcs"):
		if not node is CollisionObject2D:
			continue

		var rid := (node as CollisionObject2D).get_rid()
		if rid not in result:
			result.append(rid)

	return result


func _get_store() -> Node:
	if npc == null or npc.get_tree() == null:
		return null
	return npc.get_tree().get_first_node_in_group("store")


func _append_unique_point(
	points: Array[Vector2],
	point: Vector2
) -> void:
	if not point.is_finite():
		return
	if not points.is_empty() and points.back().distance_to(point) <= POINT_EPSILON:
		return
	points.append(point)


func _dedupe_route_points(route: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point in route:
		_append_unique_point(result, point)
	return result
