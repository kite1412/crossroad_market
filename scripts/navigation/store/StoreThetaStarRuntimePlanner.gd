class_name StoreThetaStarRuntimePlanner
extends "res://scripts/navigation/store/StoreThetaStarPlanner.gd"


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

	var endpoint_shelf := _get_segment_endpoint_shelf(
		context,
		ignore_start,
		ignore_endpoint
	)
	var agent_margin := float(context.get("agent_radius", 10.5))
	if (
		_obstacles != null
		and _obstacles.is_segment_blocked(
			from_position,
			to_position,
			endpoint_shelf,
			agent_margin
		)
	):
		_line_cache[cache_key] = false
		return false

	# The coarse rectangle check may omit the shelf attached to an exempt start or
	# endpoint. Physics still keeps that shelf active for all intermediate samples,
	# so a route can leave/arrive beside a shelf but can never pass through it.
	var clear := _physics_segment_clear(
		from_position,
		to_position,
		context,
		ignore_start,
		ignore_endpoint
	)
	_line_cache[cache_key] = clear
	return clear


func _physics_segment_clear(
	from_position: Vector2,
	to_position: Vector2,
	context: Dictionary,
	ignore_start: bool,
	ignore_endpoint: bool
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
			if collider is NPC or collider.is_in_group("npcs"):
				continue
			if String(collider.name).to_lower().contains("player"):
				continue
			return false
	return true


func _get_segment_endpoint_shelf(
	context: Dictionary,
	ignore_start: bool,
	ignore_endpoint: bool
) -> Shelf:
	if ignore_start:
		var source_variant: Variant = context.get("source_shelf", null)
		if is_instance_valid(source_variant) and source_variant is Shelf:
			return source_variant as Shelf
	if ignore_endpoint:
		var target_variant: Variant = context.get("target_shelf", null)
		if is_instance_valid(target_variant) and target_variant is Shelf:
			return target_variant as Shelf
	return null


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
	var endpoint_shelf := _get_segment_endpoint_shelf(
		context,
		ignore_start,
		ignore_endpoint
	)
	if endpoint_shelf != null:
		shelf_id = endpoint_shelf.get_instance_id()
	var radius_key := roundi(float(context.get("agent_radius", 10.5)) * 10.0)
	return "%d:%d,%d:%d,%d:%d:%d:%d:r%d" % [
		revision,
		roundi(from_position.x),
		roundi(from_position.y),
		roundi(to_position.x),
		roundi(to_position.y),
		shelf_id,
		int(ignore_start),
		int(ignore_endpoint),
		radius_key
	]
