extends RefCounted
class_name StorePathGraphShelfAccess

## Shelf access candidate functions for StorePathGraph.
## Handles finding and scoring shelf access points.

@warning_ignore("unused_private_class_variable")
var _graph  # StorePathGraph – untyped to avoid cyclic class_name reference


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _init(graph = null) -> void:
	_graph = graph


## Gets shelf access candidates for a shelf position.
@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_access_candidates(shelf_position: Vector2, vertical_only: bool = false) -> Array[Dictionary]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var candidates: Array[Dictionary] = []

	if vertical_only:
		append_rect_vertical_shelf_access_candidates(candidates, shelf_position)

	for node_name in _graph._nav.get_graph_node_names():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var marker: Marker2D = _graph._nav.get_graph_marker(node_name)

		if marker == null:
			continue

		if not _graph._nav.is_shelf_access_marker(marker):
			continue

		append_shelf_access_candidate(candidates, marker.global_position, shelf_position, node_name, vertical_only)

	for access_point in _graph._shelf_access_points:
		append_shelf_access_candidate(candidates, access_point, shelf_position, StringName(), vertical_only)

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var tier_a := int(a.get("tier", 2))
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var tier_b := int(b.get("tier", 2))

		if tier_a != tier_b:
			return tier_a < tier_b

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var horizontal_a := float(a.get("horizontal_distance", INF))
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var horizontal_b := float(b.get("horizontal_distance", INF))

		if not is_equal_approx(horizontal_a, horizontal_b):
			return horizontal_a < horizontal_b

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var vertical_a := float(a.get("vertical_distance", INF))
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var vertical_b := float(b.get("vertical_distance", INF))

		if not is_equal_approx(vertical_a, vertical_b):
			return vertical_a < vertical_b

		return float(a.get("direct_distance", INF)) < float(b.get("direct_distance", INF))
	)

	return candidates


## Appends vertical shelf access candidates (above and below shelf).
@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func append_rect_vertical_shelf_access_candidates(candidates: Array[Dictionary], shelf_position: Vector2) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var shelf_object := find_shelf_object_at_position(shelf_position)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var shelf_rect: Rect2 = _graph._clearance.get_object_body_rect_at(shelf_object, shelf_position) if shelf_object != null else Rect2()

	if not _rect_has_area(shelf_rect):
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var standing_half_height: float = _graph.STANDING_SHAPE_SIZE.y * 0.5
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var standing_offset_y: float = _graph.STANDING_SHAPE_OFFSET.y
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var standing_center_above_y: float = shelf_rect.position.y - _graph.SHELF_ACCESS_STANDING_CLEARANCE - standing_half_height - standing_offset_y
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var standing_center_below_y: float = shelf_rect.position.y + shelf_rect.size.y + _graph.SHELF_ACCESS_STANDING_CLEARANCE + standing_half_height - standing_offset_y
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var x_positions: Array[float] = [
		shelf_position.x
	]

	for x_position in x_positions:
		_append_rect_shelf_access_candidate(candidates, Vector2(x_position, standing_center_above_y), shelf_position, "above")
		_append_rect_shelf_access_candidate(candidates, Vector2(x_position, standing_center_below_y), shelf_position, "below")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _append_rect_shelf_access_candidate(
	candidates: Array[Dictionary],
	access_point: Vector2,
	shelf_position: Vector2,
	access_side: String
) -> void:
	if not access_point.is_finite():
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var horizontal_distance := absf(access_point.x - shelf_position.x)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var vertical_distance := absf(access_point.y - shelf_position.y)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direct_distance := access_point.distance_to(shelf_position)

	if direct_distance <= _graph.MARKER_ALIGNMENT_EPSILON or direct_distance > _graph.MAX_SHELF_ACCESS_DISTANCE:
		return

	if horizontal_distance > _graph.SHELF_ACCESS_COLUMN_EPSILON:
		return

	if vertical_distance > _graph.MAX_VERTICAL_SHELF_ACCESS_DISTANCE:
		return

	for candidate in candidates:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var candidate_point := candidate.get("access_point", Vector2.INF) as Vector2

		if candidate_point.distance_to(access_point) <= _graph.MARKER_ALIGNMENT_EPSILON:
			return

	candidates.append({
		"access_point": access_point,
		"graph_node": StringName(),
		"vertical_access": true,
		"access_side": access_side,
		"tier": 0,
		"horizontal_distance": horizontal_distance,
		"vertical_distance": vertical_distance,
		"direct_distance": direct_distance
	})


## Appends a shelf access candidate from a marker or point.
@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func append_shelf_access_candidate(
	candidates: Array[Dictionary],
	access_point: Vector2,
	shelf_position: Vector2,
	graph_node: StringName,
	vertical_only: bool = false
) -> void:
	if not access_point.is_finite():
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var horizontal_distance := absf(access_point.x - shelf_position.x)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var vertical_distance := absf(access_point.y - shelf_position.y)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var direct_distance := access_point.distance_to(shelf_position)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var access_side := "below" if access_point.y >= shelf_position.y else "above"

	if direct_distance <= _graph.MARKER_ALIGNMENT_EPSILON or direct_distance > _graph.MAX_SHELF_ACCESS_DISTANCE:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var vertical_access: bool = horizontal_distance <= _graph.SHELF_ACCESS_COLUMN_EPSILON and vertical_distance > _graph.MARKER_ALIGNMENT_EPSILON

	if vertical_only and not vertical_access:
		return

	if vertical_access and vertical_distance > _graph.MAX_VERTICAL_SHELF_ACCESS_DISTANCE:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var tier := 2

	if vertical_access:
		tier = 0
	elif horizontal_distance <= _graph.SHELF_ACCESS_NEAR_COLUMN_EPSILON and vertical_distance > _graph.MARKER_ALIGNMENT_EPSILON:
		tier = 1

	candidates.append({
		"access_point": access_point,
		"graph_node": graph_node,
		"vertical_access": vertical_access,
		"access_side": access_side,
		"tier": tier,
		"horizontal_distance": horizontal_distance,
		"vertical_distance": vertical_distance,
		"direct_distance": direct_distance
	})


## Finds a shelf object at the given position.
@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_shelf_object_at_position(shelf_position: Vector2) -> Node2D:
	if _graph._store == null:
		return null

	for node in _graph._store.get_tree().get_nodes_in_group("shelves"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var shelf := node as Node2D

		if shelf == null:
			continue

		if shelf.global_position.distance_to(shelf_position) <= _graph.MAX_VERTICAL_SHELF_ACCESS_DISTANCE:
			return shelf

	return null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _rect_has_area(rect: Rect2) -> bool:
	return rect.size.x > 0.0 and rect.size.y > 0.0
