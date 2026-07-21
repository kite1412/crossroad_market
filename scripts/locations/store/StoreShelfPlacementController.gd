class_name StoreShelfPlacementController
extends Node


const STORE_SHELF_PICKUP_DISTANCE: float = 60.0
const CARRY_SHELF_CASHIER_BLOCKER_SIZE := Vector2(96, 36)
const CARRY_SHELF_CASHIER_BLOCKER_OFFSET := Vector2(0, -70)
const CASHIER_FLOW_RESTRICTED_SIZE := Vector2(180, 110)
const CASHIER_FLOW_RESTRICTED_OFFSET := Vector2(0, -40)
const SHELF_DROP_DISTANCE: float = 28.0
const SHELF_DROP_FRONT_DISTANCE: float = 8.0
const SHELF_DROP_ANCHOR_SEARCH_RADIUS: float = 72.0
const SHELF_DROP_ANCHOR_LIMIT: int = 12
const RESTRICTED_DROP_MESSAGE_COUNT: int = 3
const RESTRICTED_DROP_MESSAGE_DURATION: float = 0.55
const RESTRICTED_DANGER_LINE_CYCLES: int = 3
const RESTRICTED_DANGER_LINE_CYCLE_DURATION: float = 1.5
const RESTRICTED_DANGER_LINE_WIDTH: float = 3.0
const RESTRICTED_DANGER_LINE_COLOR := Color(1.0, 0.16, 0.08, 1.0)
const DROP_REJECTION_NONE: StringName = &"none"
const DROP_REJECTION_CASHIER_FLOW: StringName = &"cashier_flow"
const DROP_REJECTION_COLLISION: StringName = &"collision"
const SHELF_DROP_FALLBACK_DISTANCE: float = 44.0
const QUEUE_MARKER_DROP_BLOCK_SIZE := Vector2(56, 18)
const PENDING_ACCESS_UPDATE_META: StringName = &"pending_shelf_access_update_token"
const SHELF_ACCESS_WARMUP_DELAY: float = 1.0

var store: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(store_node: Node) -> void:
	store = store_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func make_drop_restriction(
	blocked: bool = false,
	rejection_type: StringName = DROP_REJECTION_NONE,
	message: String = "",
	warning_rect: Rect2 = Rect2(),
	show_warning: bool = false
) -> Dictionary:
	return {
		"blocked": blocked,
		"type": rejection_type,
		"message": message,
		"warning_rect": warning_rect,
		"show_warning": show_warning
	}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func rect_has_area(rect: Rect2) -> bool:
	return rect.size.x > 0.0 and rect.size.y > 0.0


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_object_body_rect_at(object: Node2D, candidate: Vector2) -> Rect2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var collision_shape := get_object_collision_shape(object)

	if collision_shape == null:
		return Rect2(candidate - Vector2(32, 24), Vector2(64, 48))

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var rectangle := collision_shape.shape as RectangleShape2D

	if rectangle == null:
		return Rect2(candidate - Vector2(32, 24), Vector2(64, 48))

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var center := candidate + collision_shape.position
	return Rect2(center - rectangle.size * 0.5, rectangle.size)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_door_no_drop_rect(area: Area2D, margin: float) -> Rect2:
	if area == null:
		return Rect2()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var area_rect := get_area_rect(area)

	if area_rect.size == Vector2.ZERO:
		return Rect2()

	return area_rect.grow(margin)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_area_rect(area: Area2D) -> Rect2:
	if area == null:
		return Rect2()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var collision_shape := area.get_node_or_null("CollisionShape2D") as CollisionShape2D

	if collision_shape == null:
		return Rect2(area.global_position - Vector2(20, 20), Vector2(40, 40))

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var rectangle := collision_shape.shape as RectangleShape2D

	if rectangle == null:
		return Rect2(area.global_position - Vector2(20, 20), Vector2(40, 40))

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var center := area.global_position + collision_shape.position
	return Rect2(center - rectangle.size * 0.5, rectangle.size)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_collision_shape_rect(collision_shape: CollisionShape2D) -> Rect2:
	if collision_shape == null:
		return Rect2()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var rectangle := collision_shape.shape as RectangleShape2D

	if rectangle == null:
		return Rect2()

	return Rect2(collision_shape.global_position - rectangle.size * 0.5, rectangle.size)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_object_collision_shape(object: Node2D) -> CollisionShape2D:
	if object == null:
		return null

	return object.get_node_or_null("PhysicsBody/CollisionShape2D") as CollisionShape2D


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_carried_object_from_player() -> Node2D:
	return StoreShelfController.get_carried_object_from_player(store.player)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_drop_carried_shelf() -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var carried_object := get_carried_object_from_player()

	if carried_object == null:
		return false

	drop_carried_shelf_in_store(carried_object)
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_pickup_shelf(shelf: Shelf) -> bool:
	if shelf == null or store.player == null:
		return false

	if not StoreShelfController.is_descendant_of(shelf, store):
		return false

	if shelf.has_meta("is_carried_storage_object") and bool(shelf.get_meta("is_carried_storage_object")):
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var is_within_pickup_distance: bool = store.player.global_position.distance_to(shelf.global_position) <= STORE_SHELF_PICKUP_DISTANCE

	if not is_within_pickup_distance and not is_player_overlapping_shelf_interaction(shelf):
		return false

	pickup_installed_shelf(shelf)
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_player_carrying_shelf_named(shelf_name: String) -> bool:
	return StoreShelfController.is_player_carrying_shelf_named(store.player, shelf_name)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func drop_carried_shelf_in_store(object: Node2D) -> void:
	if store.player == null:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var primary_drop_position := get_primary_shelf_drop_position()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var primary_restriction := evaluate_shelf_drop_restriction(object, primary_drop_position)

	if primary_restriction.get("type", DROP_REJECTION_NONE) == DROP_REJECTION_CASHIER_FLOW:
		show_drop_restriction_feedback(primary_restriction)
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var drop_candidates: Array[Vector2] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var drop_position := primary_drop_position

	if bool(primary_restriction.get("blocked", false)):
		drop_candidates = get_drop_candidates()
		drop_position = find_safe_drop_position(object, drop_candidates)

	if drop_position == Vector2.INF:
		if not bool(primary_restriction.get("blocked", false)):
			primary_restriction = get_drop_failure_context(object, drop_candidates)

		if not bool(primary_restriction.get("blocked", false)):
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var primary_object_rect := get_object_body_rect_at(object, primary_drop_position)
			primary_restriction = make_drop_restriction(
				true,
				DROP_REJECTION_COLLISION,
				"I can't place the shelf here.",
				primary_object_rect,
				false
			)

		show_drop_restriction_feedback(primary_restriction)
		return

	object.reparent(store, true)
	object.global_position = drop_position
	object.z_index = 0
	set_shelf_carried_state(object, false)
	if not object.is_in_group("shelves"):
		object.add_to_group("shelves")

	store._show_passive_notification("Shelf placed in the store.", 2.0, true)
	schedule_post_shelf_drop_update(object, drop_position)
	pass
	set_customer_path_visual_visible(false)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func create_carry_shelf_blocker() -> void:
	store._carry_shelf_blocker = StaticBody2D.new()
	store._carry_shelf_blocker.name = "CarryShelfCashierBlocker"
	store._carry_shelf_blocker.visible = false
	store.add_child(store._carry_shelf_blocker)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var shape := RectangleShape2D.new()
	shape.size = CARRY_SHELF_CASHIER_BLOCKER_SIZE

	store._carry_shelf_blocker_shape = CollisionShape2D.new()
	store._carry_shelf_blocker_shape.name = "CollisionShape2D"
	store._carry_shelf_blocker_shape.shape = shape
	store._carry_shelf_blocker.add_child(store._carry_shelf_blocker_shape)

	set_carry_shelf_blocker_enabled(false)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func create_restricted_placement_warning() -> void:
	store._restricted_placement_warning = Node2D.new()
	store._restricted_placement_warning.name = "RestrictedPlacementWarning"
	store._restricted_placement_warning.z_index = 90
	store._restricted_placement_warning.visible = false
	store._restricted_placement_warning.modulate.a = 0.0
	store.add_child(store._restricted_placement_warning)

	store._restricted_placement_warning_line = Line2D.new()
	store._restricted_placement_warning_line.name = "RestrictedPlacementWarningLine"
	store._restricted_placement_warning_line.width = RESTRICTED_DANGER_LINE_WIDTH
	store._restricted_placement_warning_line.default_color = RESTRICTED_DANGER_LINE_COLOR
	store._restricted_placement_warning_line.closed = true
	store._restricted_placement_warning_line.visible = false
	store._restricted_placement_warning.add_child(store._restricted_placement_warning_line)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func update_carry_shelf_blocker() -> void:
	if store._carry_shelf_blocker != null:
		store._carry_shelf_blocker.global_position = get_carry_shelf_blocker_position()

	set_carry_shelf_blocker_enabled(false)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func update_customer_path_visual() -> void:
	set_customer_path_visual_visible(false)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_customer_path_visual_visible(should_show: bool) -> void:
	if store.customer_path_zones == null:
		return

	store.customer_path_zones.visible = should_show


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_carry_shelf_blocker_enabled(_enabled: bool) -> void:
	if store._carry_shelf_blocker_shape == null:
		return

	store._carry_shelf_blocker_shape.disabled = true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_safe_drop_position(object: Node2D, candidates: Array[Vector2]) -> Vector2:
	for candidate in candidates:
		if not bool(evaluate_shelf_drop_restriction(object, candidate).get("blocked", false)):
			return candidate

	return Vector2.INF


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_drop_failure_context(object: Node2D, candidates: Array[Vector2]) -> Dictionary:
	for candidate in candidates:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var rejection := evaluate_shelf_drop_restriction(object, candidate)

		if bool(rejection.get("blocked", false)):
			return rejection

	return make_drop_restriction()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_drop_candidates() -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var candidates: Array[Vector2] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var primary_position: Vector2 = get_primary_shelf_drop_position()

	candidates.append(primary_position)
	candidates.append_array(get_nearby_shelf_anchor_drop_candidates(primary_position, true))
	candidates.append_array(get_nearby_shelf_anchor_drop_candidates(store.player.global_position, false))

	for offset in get_directional_shelf_drop_fallbacks():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var candidate: Vector2 = store.player.global_position + offset

		if candidate not in candidates:
			candidates.append(candidate)

	return candidates


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_nearby_shelf_anchor_drop_candidates(origin: Vector2, use_direction_filter: bool) -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var anchors: Array[Vector2] = get_shelf_placement_grid_positions()

	if anchors.is_empty():
		return []

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var nearby: Array[Vector2] = []

	for anchor in anchors:
		if anchor.distance_to(origin) > SHELF_DROP_ANCHOR_SEARCH_RADIUS:
			continue
		if use_direction_filter and not is_anchor_in_player_drop_direction(anchor, origin):
			continue

		nearby.append(anchor)

	nearby.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return get_shelf_anchor_drop_score(a, origin, use_direction_filter) < get_shelf_anchor_drop_score(b, origin, use_direction_filter)
	)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var limited: Array[Vector2] = []

	for anchor in nearby:
		limited.append(anchor)

		if limited.size() >= SHELF_DROP_ANCHOR_LIMIT:
			break

	return limited


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_anchor_drop_score(anchor: Vector2, origin: Vector2, use_direction_filter: bool) -> float:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var score: float = anchor.distance_to(origin)

	if store.player == null or not use_direction_filter:
		return score

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var facing: Vector2 = get_player_facing_direction()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var to_anchor: Vector2 = anchor - store.player.global_position

	if to_anchor.length() <= 2.0:
		return score

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var forward_distance: float = to_anchor.dot(facing)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var lateral_distance: float = absf(to_anchor.dot(Vector2(-facing.y, facing.x)))

	if forward_distance < 0.0:
		score += abs(forward_distance) * 2.0

	score += lateral_distance * 0.35
	return score


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_placement_grid_positions() -> Array[Vector2]:
	if not store._placement_surface_anchor_cache.is_empty():
		return store._placement_surface_anchor_cache

	if store._placement_surface == null:
		store._placement_surface = store.get_node_or_null("StorePlacementSurface")

	if store._placement_surface != null and store._placement_surface.has_method("get_anchor_positions"):
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var anchors: Variant = store._placement_surface.call("get_anchor_positions")

		if anchors is Array:
			store._placement_surface_anchor_cache.clear()

			for anchor in anchors:
				if anchor is Vector2:
					store._placement_surface_anchor_cache.append(anchor)

		return store._placement_surface_anchor_cache

	if store._placement_grid == null:
		store._placement_grid = StorePlacementGrid.new()

	store._placement_grid.setup(
		store.shelf_placement_fallback_polygon,
		store.shelf_placement_fallback_spacing
	)
	store._placement_surface_anchor_cache = store._placement_grid.get_positions()
	return store._placement_surface_anchor_cache


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_primary_shelf_drop_position() -> Vector2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var facing: Vector2 = get_player_facing_direction()
	return store.player.global_position + facing * get_shelf_drop_distance_for_facing(facing)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_directional_shelf_drop_fallbacks() -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var facing: Vector2 = get_player_facing_direction()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var forward: Vector2 = facing * get_shelf_drop_distance_for_facing(facing)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var right: Vector2 = Vector2(-facing.y, facing.x) * SHELF_DROP_FALLBACK_DISTANCE
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var back: Vector2 = - facing * SHELF_DROP_FALLBACK_DISTANCE

	return [
		forward,
		forward + right * 0.75,
		forward - right * 0.75,
		right,
		- right,
		back
	]


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_anchor_in_player_drop_direction(anchor: Vector2, primary_position: Vector2) -> bool:
	if store.player == null:
		return true

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var facing: Vector2 = get_player_facing_direction()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var to_anchor: Vector2 = anchor - store.player.global_position

	if to_anchor.length() <= 2.0:
		return true

	if to_anchor.normalized().dot(facing) >= -0.35:
		return true

	return anchor.distance_to(primary_position) <= get_shelf_drop_distance_for_facing(facing) * 0.75


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_drop_distance_for_facing(facing: Vector2) -> float:
	if facing.y > 0.75 and absf(facing.x) < 0.25:
		return SHELF_DROP_FRONT_DISTANCE

	return SHELF_DROP_DISTANCE


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_player_facing_direction() -> Vector2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var facing: Variant = store.player.get("facing_direction") if store.player != null else Vector2.DOWN

	if facing is Vector2 and not facing.is_zero_approx():
		return (facing as Vector2).normalized()

	return Vector2.DOWN


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_drop_position_clear(object: Node2D, candidate: Vector2) -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var collision_shape: CollisionShape2D = get_object_collision_shape(object)

	if collision_shape == null or collision_shape.shape == null:
		return true

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = Transform2D(0.0, candidate + collision_shape.position)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hits: Array = store.get_world_2d().direct_space_state.intersect_shape(query, 16)

	for hit in hits:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var collider: Node = hit.get("collider", null)

		if collider == null:
			continue

		if collider == object or StoreShelfController.is_descendant_of(collider, object):
			continue

		return false

	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func evaluate_shelf_drop_restriction(object: Node2D, candidate: Vector2) -> Dictionary:
	# All restrictions removed — shelf can be placed anywhere.
	# NPC vertical flow handles access point validity; player places freely.
	return make_drop_restriction()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_cashier_flow_restricted_rect() -> Rect2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var center: Vector2 = Vector2(96, 132)

	if store.counter_pos != null:
		center = store.counter_pos.global_position
	elif store.cashier != null:
		center = store.cashier.global_position + Vector2(0, 38)

	center += CASHIER_FLOW_RESTRICTED_OFFSET
	return Rect2(center - CASHIER_FLOW_RESTRICTED_SIZE * 0.5, CASHIER_FLOW_RESTRICTED_SIZE)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_queue_marker_drop_restricted_rect(object_rect: Rect2) -> Rect2:
	for marker in get_queue_drop_block_markers():
		if marker == null:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var marker_rect := Rect2(
			marker.global_position - QUEUE_MARKER_DROP_BLOCK_SIZE * 0.5,
			QUEUE_MARKER_DROP_BLOCK_SIZE
		)

		if object_rect.intersects(marker_rect):
			return marker_rect

	return Rect2()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_cashier_drop_restricted_rect(object_rect: Rect2) -> Rect2:
	if store.cashier == null:
		store.cashier = store.get_node_or_null("Cashier") as Node2D

	if store.cashier == null:
		return Rect2()

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var restricted_rects: Array[Rect2] = []

	for shape_name in ["CollisionShape2D", "BackCounterCollision"]:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var collision_shape := store.cashier.get_node_or_null(shape_name) as CollisionShape2D
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var rect := get_collision_shape_rect(collision_shape)

		if rect_has_area(rect):
			restricted_rects.append(rect)

	for rect in restricted_rects:
		if object_rect.intersects(rect):
			return rect

	return Rect2()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_queue_drop_block_markers() -> Array[Marker2D]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var markers: Array[Marker2D] = []

	if store.store_path_markers == null:
		return markers

	for child in store.store_path_markers.get_children():
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
		var marker_node := child as Marker2D
		if marker_node == null:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var role := StringName()
		if marker_node.has_meta("store_path_role"):
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var role_value: Variant = marker_node.get_meta("store_path_role")
			role = StringName(str(role_value))

		if role == &"queue_front" or role == &"queue_back":
			markers.append(marker_node)

	return markers


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_reachable_store_shelf_visit_position(object: Node2D, candidate: Vector2) -> bool:
	return store._get_store_path_graph().has_reachable_shelf_access(object, candidate)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_nearest_installed_shelf() -> Node2D:
	if store.player == null:
		return null

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var nearest_shelf: Node2D = null
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var nearest_distance: float = STORE_SHELF_PICKUP_DISTANCE

	for node in store.get_tree().get_nodes_in_group("shelves"):
		if not node is Shelf:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var shelf := node as Shelf

		if not StoreShelfController.is_descendant_of(shelf, store):
			continue

		if shelf.has_meta("is_carried_storage_object") and bool(shelf.get_meta("is_carried_storage_object")):
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var distance: float = store.player.global_position.distance_to(shelf.global_position)

		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_shelf = shelf

	return nearest_shelf


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_player_overlapping_shelf_interaction(shelf: Shelf) -> bool:
	if store.player == null or shelf == null:
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var player_area := store.player.get_node_or_null("InteractionArea") as Area2D
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var shelf_area := shelf.get_node_or_null("InteractionArea") as Area2D

	if player_area == null or shelf_area == null:
		return false

	return shelf_area in player_area.get_overlapping_areas()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func pickup_installed_shelf(object: Node2D) -> void:
	if store.player == null:
		return

	if object == store.human_shelf:
		store._human_shelf_installed = false
	elif object == store.ghost_shelf:
		store._ghost_shelf_installed = false

	object.reparent(store.player, true)
	object.position = Vector2(0, -18)
	object.z_index = 80
	set_shelf_carried_state(object, true)
	if store.player.has_method("update_carried_object_visual"):
		store.player.call("update_carried_object_visual", object)
	clear_shelf_access_metadata(object)
	store._update_objective()
	store._show_notification("Shelf picked up. Press Q to place it.")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_shelf_carried_state(object: Node2D, is_carried: bool) -> void:
	if object == null:
		return

	object.set_meta("is_carried_storage_object", is_carried)
	object.set_meta("is_installed_in_store", not is_carried)

	if is_carried:
		object.remove_from_group("shelves")
		store._set_node_enabled_recursive(object, false)
	else:
		store._set_node_enabled_recursive(object, true)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func store_shelf_access_metadata(object: Node2D, drop_position: Vector2) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var graph: StorePathGraph = store._get_store_path_graph()
	graph.store_shelf_access_metadata(object, drop_position)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func schedule_post_shelf_drop_update(object: Node2D, drop_position: Vector2) -> void:
	if object == null:
		return

	store._shelf_access_metadata_update_token += 1
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var update_token: int = int(store._shelf_access_metadata_update_token)
	object.set_meta(PENDING_ACCESS_UPDATE_META, update_token)
	defer_post_shelf_drop_update(object, drop_position, update_token)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func defer_post_shelf_drop_update(object: Node2D, drop_position: Vector2, update_token: int) -> void:
	await store.get_tree().process_frame
	await store.get_tree().physics_frame

	if object == null or not is_instance_valid(object):
		return

	if not object.has_meta(PENDING_ACCESS_UPDATE_META):
		return

	if int(object.get_meta(PENDING_ACCESS_UPDATE_META)) != update_token:
		return

	if object.has_meta("is_carried_storage_object") and bool(object.get_meta("is_carried_storage_object")):
		object.remove_meta(PENDING_ACCESS_UPDATE_META)
		return

	object.remove_meta(PENDING_ACCESS_UPDATE_META)
	await store.get_tree().create_timer(0.15).timeout

	if object == null or not is_instance_valid(object):
		return

	if object.has_meta("is_carried_storage_object") and bool(object.get_meta("is_carried_storage_object")):
		return

	store_shelf_access_metadata(object, drop_position)
	store._register_installed_shelf(object)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func schedule_shelf_access_warmup(delay: float = SHELF_ACCESS_WARMUP_DELAY) -> void:
	store._shelf_access_warmup_token += 1
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var warmup_token: int = int(store._shelf_access_warmup_token)
	defer_shelf_access_warmup(warmup_token, delay)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func defer_shelf_access_warmup(warmup_token: int, delay: float) -> void:
	await store.get_tree().process_frame

	if delay > 0.0:
		await store.get_tree().create_timer(delay).timeout

	if warmup_token != store._shelf_access_warmup_token:
		return

	if not can_run_shelf_access_warmup():
		schedule_shelf_access_warmup(SHELF_ACCESS_WARMUP_DELAY)
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var graph: StorePathGraph = store._get_store_path_graph()

	for shelf_node in store.get_tree().get_nodes_in_group("shelves"):
		if warmup_token != store._shelf_access_warmup_token:
			return

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var shelf := shelf_node as Shelf

		if shelf == null:
			continue

		if graph.has_cached_shelf_access_metadata(shelf):
			continue

		graph.store_shelf_access_metadata(shelf, shelf.global_position)

		await store.get_tree().process_frame


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func can_run_shelf_access_warmup() -> bool:
	if store._current_storage != null or store._current_yard != null or store._current_home != null or store._is_transitioning:
		return false

	if store._is_action_locked():
		return false

	return get_carried_object_from_player() == null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func clear_shelf_access_metadata(object: Node2D) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var graph: StorePathGraph = store._get_store_path_graph()
	graph.clear_shelf_access_metadata(object)

	if object != null and object.has_meta(PENDING_ACCESS_UPDATE_META):
		object.remove_meta(PENDING_ACCESS_UPDATE_META)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_drop_restriction_feedback(restriction: Dictionary) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var message := str(restriction.get("message", "I can't place the shelf here."))

	if bool(restriction.get("show_warning", false)):
		show_restricted_drop_feedback(restriction)
		return

	store._show_notification(message, 0.9)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_restricted_drop_feedback(restriction: Dictionary) -> void:
	store._restricted_drop_feedback_token += 1
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var feedback_token: int = int(store._restricted_drop_feedback_token)
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var message := str(restriction.get("message", "Keep this area clear for customers."))
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var warning_rect := get_warning_rect_from_restriction(restriction)

	play_restricted_placement_warning(warning_rect)

	for i in RESTRICTED_DROP_MESSAGE_COUNT:
		if feedback_token != store._restricted_drop_feedback_token:
			return

		store._show_notification(message, RESTRICTED_DROP_MESSAGE_DURATION)
		await store.get_tree().create_timer(2.0 / float(RESTRICTED_DROP_MESSAGE_COUNT)).timeout


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_warning_rect_from_restriction(restriction: Dictionary) -> Rect2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var rect_variant: Variant = restriction.get("warning_rect", Rect2())

	if rect_variant is Rect2:
		return rect_variant as Rect2

	return Rect2()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func play_restricted_placement_warning(rect: Rect2) -> void:
	if store._current_storage != null or store._current_yard != null or store._is_transitioning:
		hide_restricted_placement_warning()
		return

	if store._restricted_placement_warning == null:
		return

	if store._restricted_placement_warning_tween != null and store._restricted_placement_warning_tween.is_valid():
		store._restricted_placement_warning_tween.kill()
	store._restricted_placement_warning_tween = null

	if not rect_has_area(rect):
		hide_restricted_placement_warning()
		return

	sync_restricted_placement_warning(rect)
	store._restricted_placement_warning.visible = true
	store._restricted_placement_warning.modulate.a = 0.0

	store._restricted_placement_warning_tween = store.create_tween()

	for i in RESTRICTED_DANGER_LINE_CYCLES:
		store._restricted_placement_warning_tween.tween_property(
			store._restricted_placement_warning,
			"modulate:a",
			1.0,
			RESTRICTED_DANGER_LINE_CYCLE_DURATION * 0.5
		)
		store._restricted_placement_warning_tween.tween_property(
			store._restricted_placement_warning,
			"modulate:a",
			0.0,
			RESTRICTED_DANGER_LINE_CYCLE_DURATION * 0.5
		)

	store._restricted_placement_warning_tween.tween_callback(func() -> void:
		store._restricted_placement_warning_tween = null
		hide_restricted_placement_warning()
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func sync_restricted_placement_warning(rect: Rect2) -> void:
	if store._restricted_placement_warning_line == null:
		return

	sync_restricted_warning_line_to_rect(store._restricted_placement_warning_line, rect)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func hide_restricted_placement_warning() -> void:
	if store._restricted_placement_warning_tween != null and store._restricted_placement_warning_tween.is_valid():
		store._restricted_placement_warning_tween.kill()
	store._restricted_placement_warning_tween = null

	if store._restricted_placement_warning == null:
		return

	store._restricted_placement_warning.visible = false
	store._restricted_placement_warning.modulate.a = 0.0

	if store._restricted_placement_warning_line != null:
		store._restricted_placement_warning_line.visible = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func cancel_restricted_drop_feedback() -> void:
	store._restricted_drop_feedback_token += 1
	hide_restricted_placement_warning()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func sync_restricted_warning_line_to_rect(line: Line2D, rect: Rect2) -> void:
	if line == null:
		return

	line.visible = true

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var points := PackedVector2Array([
		store.to_local(rect.position),
		store.to_local(rect.position + Vector2(rect.size.x, 0.0)),
		store.to_local(rect.position + rect.size),
		store.to_local(rect.position + Vector2(0.0, rect.size.y))
	])
	line.points = points


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_carry_shelf_blocker_position() -> Vector2:
	if store.counter_pos != null:
		return store.counter_pos.global_position + CARRY_SHELF_CASHIER_BLOCKER_OFFSET

	if store.cashier != null:
		return store.cashier.global_position + Vector2(0, 20)

	return Vector2(96, 142)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func update_player_depth_override() -> void:
	if store.player == null:
		store.player = store.get_node_or_null("Player") as Node2D

	if store.cashier == null:
		store.cashier = store.get_node_or_null("Cashier") as Node2D

	if store.player == null or store.cashier == null:
		return

	store.player.z_index = 0


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_player_behind_depth_object(
	object: Node2D,
	half_width: float,
	back_offset: float,
	front_offset: float
) -> bool:
	return StoreShelfController.is_player_behind_depth_object(
		store.player,
		object,
		half_width,
		back_offset,
		front_offset
	)
