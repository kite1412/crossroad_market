class_name StoreRouteSafety
extends RefCounted

const StoreRuntimeDebugProbeScript = preload("res://scripts/debug/StoreRuntimeDebugProbe.gd")

const STANDING_SHAPE_SIZE := Vector2(21, 9)
const STANDING_SHAPE_OFFSET := Vector2(0, -8)
const ROUTE_SAMPLE_STEP: float = 6.0
const START_CLEARANCE: float = 16.0
const ENDPOINT_CLEARANCE: float = 8.0
const START_OBSTACLE_RELEASE_DISTANCE: float = 28.0
const MARKER_CORRIDOR_RADIUS: float = 7.0
const POINT_EPSILON: float = 2.0
const ALL_PHYSICS_LAYERS: int = 0x7FFFFFFF
const EXIT_ORIGIN_SHELF_META: StringName = &"exit_origin_shelf"

var npc: CharacterBody2D = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(npc_node: CharacterBody2D) -> void:
	npc = npc_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func sanitize_store_route(route: Array[Vector2]) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var clean_route := _dedupe_route_points(route)
	var raw_route_points := clean_route.size()

	if npc == null or clean_route.is_empty():
		return clean_route

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var store := _get_store()
	if store == null:
		return clean_route

	clean_route = _insert_intermediate_markers(
		npc.global_position,
		clean_route,
		store
	)
	var after_marker_insert_points := clean_route.size()

	# StorePathGraph already treats the selected shelf as the allowed endpoint
	# obstacle. Preserve that behavior here: only the final approach may ignore
	# the target shelf body. An out-of-stock exit uses the source shelf as a
	# temporary start obstacle until the NPC has moved clear of it.
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var start_obstacle := _get_start_obstacle()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var endpoint_obstacle := _get_endpoint_obstacle()

	var reject_context := _get_route_reject_context(
		npc.global_position,
		clean_route,
		store,
		start_obstacle,
		endpoint_obstacle
	)
	if not reject_context.is_empty():
		reject_context["raw_route_points"] = raw_route_points
		reject_context["after_marker_insert_points"] = after_marker_insert_points
		reject_context["sanitized_route_points"] = 0
		_record_safety_probe(&"npc_route_safety_reject", reject_context)
		return []

	_record_safety_probe(&"npc_route_safety_accept", {
		"raw_route_points": raw_route_points,
		"after_marker_insert_points": after_marker_insert_points,
		"sanitized_route_points": clean_route.size(),
		"has_origin_shelf": start_obstacle != null and is_instance_valid(start_obstacle)
	})
	return clean_route


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _insert_intermediate_markers(
	start_position: Vector2,
	route: Array[Vector2],
	store: Node2D
) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result: Array[Vector2] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_markers_between(
	from_position: Vector2,
	to_position: Vector2,
	store: Node2D
) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result: Array[Vector2] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var markers := store.get_node_or_null("StorePathMarkers") as Node2D

	if markers == null:
		return result

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var segment := to_position - from_position
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var length_squared := segment.length_squared()

	if length_squared <= POINT_EPSILON * POINT_EPSILON:
		return result

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var ranked: Array[Dictionary] = []

	for child in markers.get_children():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
		var marker := child as Marker2D
		if marker == null:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var marker_position := marker.global_position
		if (
			marker_position.distance_to(from_position) <= POINT_EPSILON
			or marker_position.distance_to(to_position) <= POINT_EPSILON
		):
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var progress := (
			(marker_position - from_position).dot(segment)
			/ length_squared
		)

		if progress <= 0.02 or progress >= 0.98:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_route_clear(
	start_position: Vector2,
	route: Array[Vector2],
	store: Node2D,
	start_obstacle: Node = null,
	endpoint_obstacle: Node = null
) -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var current := start_position
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var start_obstacle_active := (
		start_obstacle != null
		and is_instance_valid(start_obstacle)
	)

	for index in range(route.size()):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var target := route[index]
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var start_clearance := START_CLEARANCE if index == 0 else ENDPOINT_CLEARANCE
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var allowed_obstacles: Array[Node] = []

		if start_obstacle_active:
			allowed_obstacles.append(start_obstacle)

		if (
			index == route.size() - 1
			and endpoint_obstacle != null
			and is_instance_valid(endpoint_obstacle)
			and endpoint_obstacle not in allowed_obstacles
		):
			allowed_obstacles.append(endpoint_obstacle)

		if not _is_segment_clear(
			current,
			target,
			store,
			start_clearance,
			allowed_obstacles
		):
			return false

		if (
			start_obstacle_active
			and target.distance_to(start_position)
			>= START_OBSTACLE_RELEASE_DISTANCE
		):
			start_obstacle_active = false

		current = target

	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_route_reject_context(
	start_position: Vector2,
	route: Array[Vector2],
	store: Node2D,
	start_obstacle: Node = null,
	endpoint_obstacle: Node = null
) -> Dictionary:
	var current := start_position
	var start_obstacle_active := (
		start_obstacle != null
		and is_instance_valid(start_obstacle)
	)

	for index in range(route.size()):
		var target := route[index]
		var start_clearance := START_CLEARANCE if index == 0 else ENDPOINT_CLEARANCE
		var allowed_obstacles: Array[Node] = []

		if start_obstacle_active:
			allowed_obstacles.append(start_obstacle)

		if (
			index == route.size() - 1
			and endpoint_obstacle != null
			and is_instance_valid(endpoint_obstacle)
			and endpoint_obstacle not in allowed_obstacles
		):
			allowed_obstacles.append(endpoint_obstacle)

		var segment_reject := _get_segment_reject_context(
			current,
			target,
			store,
			start_clearance,
			allowed_obstacles
		)
		if not segment_reject.is_empty():
			segment_reject["failed_segment_index"] = index
			segment_reject["failed_from"] = _format_vector(current)
			segment_reject["failed_to"] = _format_vector(target)
			segment_reject["has_origin_shelf"] = (
				start_obstacle != null
				and is_instance_valid(start_obstacle)
			)
			segment_reject["start_obstacle_active"] = start_obstacle_active
			segment_reject["allowed_origin_shelf_mismatch"] = (
				start_obstacle_active
				and start_obstacle != null
				and is_instance_valid(start_obstacle)
				and not _is_node_or_descendant_of_path(
					str(segment_reject.get("collider_path", "")),
					start_obstacle
				)
			)
			return segment_reject

		if (
			start_obstacle_active
			and target.distance_to(start_position)
			>= START_OBSTACLE_RELEASE_DISTANCE
		):
			start_obstacle_active = false

		current = target

	return {}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_segment_clear(
	from_position: Vector2,
	to_position: Vector2,
	store: Node2D,
	start_clearance: float,
	allowed_obstacles: Array[Node] = []
) -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var distance := from_position.distance_to(to_position)
	if distance <= start_clearance + ENDPOINT_CLEARANCE:
		return true

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direction := from_position.direction_to(to_position)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var sample_start := from_position + direction * start_clearance
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var sample_end := to_position - direction * ENDPOINT_CLEARANCE
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var sample_distance := sample_start.distance_to(sample_end)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var steps := maxi(1, int(ceil(sample_distance / ROUTE_SAMPLE_STEP)))
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var shape := RectangleShape2D.new()
	shape.size = STANDING_SHAPE_SIZE
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var exclusions := _get_collision_exclusion_rids(
		store,
		allowed_obstacles
	)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var space_state := store.get_world_2d().direct_space_state

	for index in range(steps + 1):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var progress := float(index) / float(steps)
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var point := sample_start.lerp(sample_end, progress)
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
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


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_segment_reject_context(
	from_position: Vector2,
	to_position: Vector2,
	store: Node2D,
	start_clearance: float,
	allowed_obstacles: Array[Node] = []
) -> Dictionary:
	var distance := from_position.distance_to(to_position)
	if distance <= start_clearance + ENDPOINT_CLEARANCE:
		return {}

	var direction := from_position.direction_to(to_position)
	var sample_start := from_position + direction * start_clearance
	var sample_end := to_position - direction * ENDPOINT_CLEARANCE
	var sample_distance := sample_start.distance_to(sample_end)
	var steps := maxi(1, int(ceil(sample_distance / ROUTE_SAMPLE_STEP)))
	var shape := RectangleShape2D.new()
	shape.size = STANDING_SHAPE_SIZE
	var exclusions := _get_collision_exclusion_rids(store, allowed_obstacles)
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

		var hits := space_state.intersect_shape(query, 8)
		if hits.is_empty():
			continue

		var collider := _get_first_collision_node(hits)
		return {
			"sample_point": _format_vector(point),
			"collider_name": collider.name if collider != null else "",
			"collider_path": str(collider.get_path()) if collider != null else "",
			"collider_owner": _get_collision_owner_name(collider)
		}

	return {}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_collision_exclusion_rids(
	store: Node2D,
	allowed_obstacles: Array[Node] = []
) -> Array[RID]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result := _get_dynamic_actor_rids(store)

	for obstacle in allowed_obstacles:
		if obstacle == null or not is_instance_valid(obstacle):
			continue
		_append_collision_object_rids(obstacle, result)

	return result


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_dynamic_actor_rids(store: Node2D) -> Array[RID]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result: Array[RID] = []

	if npc is CollisionObject2D:
		result.append((npc as CollisionObject2D).get_rid())

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var player_variant: Variant = store.get("player")
	if player_variant is CollisionObject2D:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var player_rid := (player_variant as CollisionObject2D).get_rid()
		if player_rid not in result:
			result.append(player_rid)

	for node in store.get_tree().get_nodes_in_group("npcs"):
		if not (node is CollisionObject2D):
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var rid := (node as CollisionObject2D).get_rid()
		if rid not in result:
			result.append(rid)

	return result


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_start_obstacle() -> Node:
	if npc == null or not npc.has_meta(EXIT_ORIGIN_SHELF_META):
		return null

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var origin_variant: Variant = npc.get_meta(
		EXIT_ORIGIN_SHELF_META,
		null
	)
	if origin_variant is Node and is_instance_valid(origin_variant):
		return origin_variant as Node

	return null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_endpoint_obstacle() -> Node:
	if npc == null:
		return null

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var target_variant: Variant = npc.get("_target_shelf")
	if target_variant is Node and is_instance_valid(target_variant):
		return target_variant as Node

	return null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _append_collision_object_rids(
	node: Node,
	result: Array[RID]
) -> void:
	if node is CollisionObject2D:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var rid := (node as CollisionObject2D).get_rid()
		if rid not in result:
			result.append(rid)

	for child in node.get_children():
		_append_collision_object_rids(child, result)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_store() -> Node2D:
	if npc == null or npc.get_tree() == null:
		return null
	return npc.get_tree().get_first_node_in_group("store") as Node2D


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _append_unique_point(
	points: Array[Vector2],
	point: Vector2
) -> void:
	if not point.is_finite():
		return
	if not points.is_empty() and points.back().distance_to(point) <= POINT_EPSILON:
		return
	points.append(point)


func _get_first_collision_node(hits: Array) -> Node:
	for hit in hits:
		if not (hit is Dictionary):
			continue
		var collider_variant: Variant = (hit as Dictionary).get("collider", null)
		if collider_variant is Node:
			return collider_variant as Node
	return null


func _get_collision_owner_name(collider: Node) -> String:
	var current := collider
	while current != null:
		if current is Shelf:
			return String(current.get_shelf_id())
		if current.name != StringName():
			var name_text := String(current.name)
			if name_text.begins_with("Store") or name_text.begins_with("NPC"):
				return name_text
		current = current.get_parent()
	return ""


func _is_node_or_descendant_of_path(candidate_path: String, root: Node) -> bool:
	if candidate_path == "" or root == null or not is_instance_valid(root):
		return false
	var root_path := str(root.get_path())
	return candidate_path == root_path or candidate_path.begins_with(root_path + "/")


func _record_safety_probe(label: StringName, extra_context: Dictionary) -> void:
	if npc == null:
		return

	var target_variant: Variant = npc.get("target_position")
	var route_variant: Variant = npc.get("_movement_route")

	var context: Dictionary = {
		"npc_id": npc.get_instance_id(),
		"state": int(npc.get("current_state")),
		"position": _format_vector(npc.global_position),
		"target": _format_vector(
			target_variant as Vector2
			if target_variant is Vector2
			else Vector2.INF
		),
		"current_route_points": (
			(route_variant as Array).size()
			if route_variant is Array
			else 0
		)
	}

	for key in extra_context:
		context[key] = extra_context[key]

	StoreRuntimeDebugProbeScript.record(label, 0.0, context, 0.0)


func _format_vector(value: Vector2) -> String:
	return "%.1f,%.1f" % [value.x, value.y]


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _dedupe_route_points(route: Array[Vector2]) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var result: Array[Vector2] = []
	for point in route:
		_append_unique_point(result, point)
	return result
