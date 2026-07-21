class_name StoreDynamicObstacleTracker
extends RefCounted

const MAX_DIRTY_HISTORY: int = 24
const DEFAULT_SHELF_SIZE := Vector2(64, 48)
const POSITION_EPSILON: float = 0.5
const FULL_INVALIDATION_RECT := Rect2(-1000000, -1000000, 2000000, 2000000)

var _records: Dictionary = {}
var _revision: int = 0
var _dirty_history: Dictionary = {}
var _latest_dirty_regions: Array[Rect2] = []


func refresh(store: Node) -> Array[Rect2]:
	var next_records: Dictionary = {}
	var dirty_regions: Array[Rect2] = []

	if store != null and store.get_tree() != null:
		for shelf_variant in store.get_tree().get_nodes_in_group("shelves"):
			if not (shelf_variant is Shelf):
				continue
			var shelf := shelf_variant as Shelf
			if not is_instance_valid(shelf):
				continue
			if not _is_descendant_of(shelf, store):
				continue
			if bool(shelf.get_meta("is_carried_storage_object", false)):
				continue
			if shelf.has_meta("is_installed_in_store") and not bool(
				shelf.get_meta("is_installed_in_store", false)
			):
				continue

			var instance_id := shelf.get_instance_id()
			var shelf_rect := _get_shelf_rect(shelf)
			next_records[instance_id] = {
				"rect": shelf_rect,
				"position": shelf.global_position,
				"shelf": shelf
			}

			if not _records.has(instance_id):
				dirty_regions.append(shelf_rect.grow(12.0))
				continue

			var previous_record: Dictionary = _records[instance_id]
			var previous_position: Vector2 = previous_record.get(
				"position",
				Vector2.INF
			)
			var previous_rect: Rect2 = previous_record.get("rect", Rect2())
			if (
				not previous_position.is_finite()
				or previous_position.distance_to(shelf.global_position) > POSITION_EPSILON
				or not previous_rect.is_equal_approx(shelf_rect)
			):
				dirty_regions.append(previous_rect.grow(12.0))
				dirty_regions.append(shelf_rect.grow(12.0))

	for old_id_variant in _records.keys():
		var old_id := int(old_id_variant)
		if next_records.has(old_id):
			continue
		var removed_record: Dictionary = _records[old_id]
		var removed_rect: Rect2 = removed_record.get("rect", Rect2())
		if removed_rect.size != Vector2.ZERO:
			dirty_regions.append(removed_rect.grow(12.0))

	_records = next_records
	_latest_dirty_regions = _merge_dirty_regions(dirty_regions)
	if not _latest_dirty_regions.is_empty():
		_revision += 1
		_dirty_history[_revision] = _latest_dirty_regions.duplicate()
		_trim_history()
	elif _revision == 0:
		_revision = 1
		_dirty_history[_revision] = []

	return _latest_dirty_regions.duplicate()


func get_revision() -> int:
	return _revision


func get_latest_dirty_regions() -> Array[Rect2]:
	return _latest_dirty_regions.duplicate()


func get_dirty_regions_since(revision: int) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if revision >= _revision:
		return result

	var retained_revisions: Array[int] = []
	for revision_variant in _dirty_history.keys():
		retained_revisions.append(int(revision_variant))
	retained_revisions.sort()
	if (
		retained_revisions.is_empty()
		or revision < retained_revisions.front() - 1
	):
		return [FULL_INVALIDATION_RECT]

	for history_revision in retained_revisions:
		if history_revision <= revision:
			continue
		var regions_variant: Variant = _dirty_history[history_revision]
		if not (regions_variant is Array):
			continue
		for region_variant in regions_variant:
			if region_variant is Rect2:
				result.append(region_variant as Rect2)
	return _merge_dirty_regions(result)


func get_obstacle_rects(
	ignored_shelf: Shelf = null,
	agent_margin: float = 0.0
) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var ignored_id := 0
	if ignored_shelf != null and is_instance_valid(ignored_shelf):
		ignored_id = ignored_shelf.get_instance_id()

	for instance_id_variant in _records.keys():
		var instance_id := int(instance_id_variant)
		if instance_id == ignored_id:
			continue
		var record: Dictionary = _records[instance_id]
		var obstacle_rect: Rect2 = record.get("rect", Rect2())
		if obstacle_rect.size == Vector2.ZERO:
			continue
		result.append(obstacle_rect.grow(maxf(0.0, agent_margin)))
	return result


func is_segment_blocked(
	from_position: Vector2,
	to_position: Vector2,
	ignored_shelf: Shelf = null,
	agent_margin: float = 0.0
) -> bool:
	for obstacle_rect in get_obstacle_rects(ignored_shelf, agent_margin):
		if _segment_intersects_rect(from_position, to_position, obstacle_rect):
			return true
	return false


func route_intersects_regions(
	start_position: Vector2,
	route: Array[Vector2],
	regions: Array[Rect2]
) -> bool:
	if regions.is_empty():
		return false
	var previous := start_position
	for point in route:
		for region in regions:
			if _segment_intersects_rect(previous, point, region):
				return true
		previous = point
	return false


func get_layout_signature() -> String:
	var parts := PackedStringArray()
	for instance_id_variant in _records.keys():
		var instance_id := int(instance_id_variant)
		var record: Dictionary = _records[instance_id]
		var position: Vector2 = record.get("position", Vector2.ZERO)
		parts.append(
			"%d:%d:%d" % [
				instance_id,
				roundi(position.x),
				roundi(position.y)
			]
		)
	parts.sort()
	return "|".join(parts)


func _get_shelf_rect(shelf: Shelf) -> Rect2:
	var collision_shape := shelf.get_node_or_null(
		"PhysicsBody/CollisionShape2D"
	) as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return Rect2(
			shelf.global_position - DEFAULT_SHELF_SIZE * 0.5,
			DEFAULT_SHELF_SIZE
		)

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return Rect2(
			shelf.global_position - DEFAULT_SHELF_SIZE * 0.5,
			DEFAULT_SHELF_SIZE
		)

	return Rect2(
		collision_shape.global_position - rectangle.size * 0.5,
		rectangle.size
	)


func _segment_intersects_rect(
	from_position: Vector2,
	to_position: Vector2,
	rect: Rect2
) -> bool:
	if rect.has_point(from_position) or rect.has_point(to_position):
		return true

	var top_left := rect.position
	var top_right := rect.position + Vector2(rect.size.x, 0.0)
	var bottom_right := rect.end
	var bottom_left := rect.position + Vector2(0.0, rect.size.y)
	var edges := [
		[top_left, top_right],
		[top_right, bottom_right],
		[bottom_right, bottom_left],
		[bottom_left, top_left]
	]

	for edge_variant in edges:
		var edge: Array = edge_variant
		var intersection: Variant = Geometry2D.segment_intersects_segment(
			from_position,
			to_position,
			edge[0] as Vector2,
			edge[1] as Vector2
		)
		if intersection != null:
			return true
	return false


func _merge_dirty_regions(regions: Array[Rect2]) -> Array[Rect2]:
	var merged: Array[Rect2] = []
	for region in regions:
		if region.size == Vector2.ZERO:
			continue
		var combined := region
		var index := 0
		while index < merged.size():
			if merged[index].intersects(combined, true):
				combined = merged[index].merge(combined)
				merged.remove_at(index)
				index = 0
				continue
			index += 1
		merged.append(combined)
	return merged


func _trim_history() -> void:
	var revisions: Array[int] = []
	for revision_variant in _dirty_history.keys():
		revisions.append(int(revision_variant))
	revisions.sort()
	while revisions.size() > MAX_DIRTY_HISTORY:
		var oldest := revisions.pop_front()
		_dirty_history.erase(oldest)


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false
