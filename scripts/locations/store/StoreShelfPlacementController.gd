class_name StoreShelfPlacementController
extends Node

const StorePlacementGrid = preload("res://scripts/locations/store/StorePlacementGrid.gd")
const StoreShelfController = preload("res://scripts/locations/store/StoreShelfController.gd")

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
const PERF_SHELF_THRESHOLD_MSEC: float = 16.0

var store: Node = null


func setup(store_node: Node) -> void:
	store = store_node


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


func rect_has_area(rect: Rect2) -> bool:
	return rect.size.x > 0.0 and rect.size.y > 0.0


func get_object_body_rect_at(object: Node2D, candidate: Vector2) -> Rect2:
	var collision_shape := get_object_collision_shape(object)

	if collision_shape == null:
		return Rect2(candidate - Vector2(32, 24), Vector2(64, 48))

	var rectangle := collision_shape.shape as RectangleShape2D

	if rectangle == null:
		return Rect2(candidate - Vector2(32, 24), Vector2(64, 48))

	var center := candidate + collision_shape.position
	return Rect2(center - rectangle.size * 0.5, rectangle.size)


func get_door_no_drop_rect(area: Area2D, margin: float) -> Rect2:
	if area == null:
		return Rect2()

	var area_rect := get_area_rect(area)

	if area_rect.size == Vector2.ZERO:
		return Rect2()

	return area_rect.grow(margin)


func get_area_rect(area: Area2D) -> Rect2:
	if area == null:
		return Rect2()

	var collision_shape := area.get_node_or_null("CollisionShape2D") as CollisionShape2D

	if collision_shape == null:
		return Rect2(area.global_position - Vector2(20, 20), Vector2(40, 40))

	var rectangle := collision_shape.shape as RectangleShape2D

	if rectangle == null:
		return Rect2(area.global_position - Vector2(20, 20), Vector2(40, 40))

	var center := area.global_position + collision_shape.position
	return Rect2(center - rectangle.size * 0.5, rectangle.size)


func get_collision_shape_rect(collision_shape: CollisionShape2D) -> Rect2:
	if collision_shape == null:
		return Rect2()

	var rectangle := collision_shape.shape as RectangleShape2D

	if rectangle == null:
		return Rect2()

	return Rect2(collision_shape.global_position - rectangle.size * 0.5, rectangle.size)


func get_object_collision_shape(object: Node2D) -> CollisionShape2D:
	if object == null:
		return null

	return object.get_node_or_null("PhysicsBody/CollisionShape2D") as CollisionShape2D


func get_carried_object_from_player() -> Node2D:
	return StoreShelfController.get_carried_object_from_player(store.player)


func request_drop_carried_shelf() -> bool:
	var request_start_usec := Time.get_ticks_usec()
	var carried_object := get_carried_object_from_player()

	if carried_object == null:
		print_shelf_drop_flow("request_drop_no_object", request_start_usec, null, Vector2.INF, {})
		return false

	print_shelf_drop_flow("request_drop", request_start_usec, carried_object, carried_object.global_position, {})
	drop_carried_shelf_in_store(carried_object)
	return true


func request_pickup_shelf(shelf: Shelf) -> bool:
	if shelf == null or store.player == null:
		return false

	if not StoreShelfController.is_descendant_of(shelf, store):
		return false

	if shelf.has_meta("is_carried_storage_object") and bool(shelf.get_meta("is_carried_storage_object")):
		return false

	var is_within_pickup_distance: bool = store.player.global_position.distance_to(shelf.global_position) <= STORE_SHELF_PICKUP_DISTANCE

	if not is_within_pickup_distance and not is_player_overlapping_shelf_interaction(shelf):
		return false

	pickup_installed_shelf(shelf)
	return true


func is_player_carrying_shelf_named(shelf_name: String) -> bool:
	return StoreShelfController.is_player_carrying_shelf_named(store.player, shelf_name)


func drop_carried_shelf_in_store(object: Node2D) -> void:
	if store.player == null:
		return

	var stage_start_usec := Time.get_ticks_usec()
	var primary_drop_position := get_primary_shelf_drop_position()
	print_shelf_drop_flow("primary_drop_position", stage_start_usec, object, primary_drop_position, get_drop_debug_context(object, 0))
	stage_start_usec = Time.get_ticks_usec()
	var primary_restriction := evaluate_shelf_drop_restriction(object, primary_drop_position)
	print_shelf_drop_flow("evaluate_primary_restriction", stage_start_usec, object, primary_drop_position, get_drop_debug_context(object, 0, primary_restriction))

	if primary_restriction.get("type", DROP_REJECTION_NONE) == DROP_REJECTION_CASHIER_FLOW:
		show_drop_restriction_feedback(primary_restriction)
		return

	var drop_candidates: Array[Vector2] = []
	var drop_position := primary_drop_position

	if bool(primary_restriction.get("blocked", false)):
		stage_start_usec = Time.get_ticks_usec()
		drop_candidates = get_drop_candidates()
		print_shelf_drop_flow("get_drop_candidates", stage_start_usec, object, primary_drop_position, get_drop_debug_context(object, drop_candidates.size(), primary_restriction))
		stage_start_usec = Time.get_ticks_usec()
		drop_position = find_safe_drop_position(object, drop_candidates)
		print_shelf_drop_flow("find_safe_drop_position", stage_start_usec, object, drop_position, get_drop_debug_context(object, drop_candidates.size(), primary_restriction))

	if drop_position == Vector2.INF:
		if not bool(primary_restriction.get("blocked", false)):
			primary_restriction = get_drop_failure_context(object, drop_candidates)

		if not bool(primary_restriction.get("blocked", false)):
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

	stage_start_usec = Time.get_ticks_usec()
	object.reparent(store, true)
	object.global_position = drop_position
	object.z_index = 0
	print_shelf_drop_flow("reparent", stage_start_usec, object, drop_position, get_drop_debug_context(object, drop_candidates.size()))

	stage_start_usec = Time.get_ticks_usec()
	set_shelf_carried_state(object, false)
	print_shelf_drop_flow("set_carried_state", stage_start_usec, object, drop_position, get_drop_debug_context(object, drop_candidates.size()))
	if not object.is_in_group("shelves"):
		object.add_to_group("shelves")

	stage_start_usec = Time.get_ticks_usec()
	store._show_passive_notification("Shelf placed in the store.", 2.0, true)
	print_shelf_drop_flow("show_notification", stage_start_usec, object, drop_position, get_drop_debug_context(object, drop_candidates.size()))

	stage_start_usec = Time.get_ticks_usec()
	schedule_post_shelf_drop_update(object, drop_position)
	print_shelf_drop_flow("schedule_post_update", stage_start_usec, object, drop_position, get_drop_debug_context(object, drop_candidates.size()))
	set_customer_path_visual_visible(false)


func create_carry_shelf_blocker() -> void:
	store._carry_shelf_blocker = StaticBody2D.new()
	store._carry_shelf_blocker.name = "CarryShelfCashierBlocker"
	store._carry_shelf_blocker.visible = false
	store.add_child(store._carry_shelf_blocker)

	var shape := RectangleShape2D.new()
	shape.size = CARRY_SHELF_CASHIER_BLOCKER_SIZE

	store._carry_shelf_blocker_shape = CollisionShape2D.new()
	store._carry_shelf_blocker_shape.name = "CollisionShape2D"
	store._carry_shelf_blocker_shape.shape = shape
	store._carry_shelf_blocker.add_child(store._carry_shelf_blocker_shape)

	set_carry_shelf_blocker_enabled(false)


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


func update_carry_shelf_blocker() -> void:
	if store._carry_shelf_blocker != null:
		store._carry_shelf_blocker.global_position = get_carry_shelf_blocker_position()

	set_carry_shelf_blocker_enabled(false)


func update_customer_path_visual() -> void:
	set_customer_path_visual_visible(false)


func set_customer_path_visual_visible(should_show: bool) -> void:
	if store.customer_path_zones == null:
		return

	store.customer_path_zones.visible = should_show


func set_carry_shelf_blocker_enabled(_enabled: bool) -> void:
	if store._carry_shelf_blocker_shape == null:
		return

	store._carry_shelf_blocker_shape.disabled = true


func find_safe_drop_position(object: Node2D, candidates: Array[Vector2]) -> Vector2:
	for candidate in candidates:
		if not bool(evaluate_shelf_drop_restriction(object, candidate).get("blocked", false)):
			return candidate

	return Vector2.INF


func get_drop_failure_context(object: Node2D, candidates: Array[Vector2]) -> Dictionary:
	for candidate in candidates:
		var rejection := evaluate_shelf_drop_restriction(object, candidate)

		if bool(rejection.get("blocked", false)):
			return rejection

	return make_drop_restriction()


func get_drop_candidates() -> Array[Vector2]:
	var candidates: Array[Vector2] = []
	var primary_position: Vector2 = get_primary_shelf_drop_position()

	candidates.append(primary_position)
	candidates.append_array(get_nearby_shelf_anchor_drop_candidates(primary_position, true))
	candidates.append_array(get_nearby_shelf_anchor_drop_candidates(store.player.global_position, false))

	for offset in get_directional_shelf_drop_fallbacks():
		var candidate: Vector2 = store.player.global_position + offset

		if candidate not in candidates:
			candidates.append(candidate)

	return candidates


func get_nearby_shelf_anchor_drop_candidates(origin: Vector2, use_direction_filter: bool) -> Array[Vector2]:
	var anchors: Array[Vector2] = get_shelf_placement_grid_positions()

	if anchors.is_empty():
		return []

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

	var limited: Array[Vector2] = []

	for anchor in nearby:
		limited.append(anchor)

		if limited.size() >= SHELF_DROP_ANCHOR_LIMIT:
			break

	return limited


func get_shelf_anchor_drop_score(anchor: Vector2, origin: Vector2, use_direction_filter: bool) -> float:
	var score: float = anchor.distance_to(origin)

	if store.player == null or not use_direction_filter:
		return score

	var facing: Vector2 = get_player_facing_direction()
	var to_anchor: Vector2 = anchor - store.player.global_position

	if to_anchor.length() <= 2.0:
		return score

	var forward_distance: float = to_anchor.dot(facing)
	var lateral_distance: float = absf(to_anchor.dot(Vector2(-facing.y, facing.x)))

	if forward_distance < 0.0:
		score += abs(forward_distance) * 2.0

	score += lateral_distance * 0.35
	return score


func get_shelf_placement_grid_positions() -> Array[Vector2]:
	if not store._placement_surface_anchor_cache.is_empty():
		return store._placement_surface_anchor_cache

	if store._placement_surface == null:
		store._placement_surface = store.get_node_or_null("StorePlacementSurface")

	if store._placement_surface != null and store._placement_surface.has_method("get_anchor_positions"):
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


func get_primary_shelf_drop_position() -> Vector2:
	var facing: Vector2 = get_player_facing_direction()
	return store.player.global_position + facing * get_shelf_drop_distance_for_facing(facing)


func get_directional_shelf_drop_fallbacks() -> Array[Vector2]:
	var facing: Vector2 = get_player_facing_direction()
	var forward: Vector2 = facing * get_shelf_drop_distance_for_facing(facing)
	var right: Vector2 = Vector2(-facing.y, facing.x) * SHELF_DROP_FALLBACK_DISTANCE
	var back: Vector2 = - facing * SHELF_DROP_FALLBACK_DISTANCE

	return [
		forward,
		forward + right * 0.75,
		forward - right * 0.75,
		right,
		- right,
		back
	]


func is_anchor_in_player_drop_direction(anchor: Vector2, primary_position: Vector2) -> bool:
	if store.player == null:
		return true

	var facing: Vector2 = get_player_facing_direction()
	var to_anchor: Vector2 = anchor - store.player.global_position

	if to_anchor.length() <= 2.0:
		return true

	if to_anchor.normalized().dot(facing) >= -0.35:
		return true

	return anchor.distance_to(primary_position) <= get_shelf_drop_distance_for_facing(facing) * 0.75


func get_shelf_drop_distance_for_facing(facing: Vector2) -> float:
	if facing.y > 0.75 and absf(facing.x) < 0.25:
		return SHELF_DROP_FRONT_DISTANCE

	return SHELF_DROP_DISTANCE


func get_player_facing_direction() -> Vector2:
	var facing: Variant = store.player.get("facing_direction") if store.player != null else Vector2.DOWN

	if facing is Vector2 and not facing.is_zero_approx():
		return (facing as Vector2).normalized()

	return Vector2.DOWN


func is_drop_position_clear(object: Node2D, candidate: Vector2) -> bool:
	var collision_shape: CollisionShape2D = get_object_collision_shape(object)

	if collision_shape == null or collision_shape.shape == null:
		return true

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = Transform2D(0.0, candidate + collision_shape.position)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hits: Array = store.get_world_2d().direct_space_state.intersect_shape(query, 16)

	for hit in hits:
		var collider: Node = hit.get("collider", null)

		if collider == null:
			continue

		if collider == object or StoreShelfController.is_descendant_of(collider, object):
			continue

		return false

	return true


func evaluate_shelf_drop_restriction(object: Node2D, candidate: Vector2) -> Dictionary:
	# All restrictions removed — shelf can be placed anywhere.
	# NPC vertical flow handles access point validity; player places freely.
	return make_drop_restriction()


func get_cashier_flow_restricted_rect() -> Rect2:
	var center: Vector2 = Vector2(96, 132)

	if store.counter_pos != null:
		center = store.counter_pos.global_position
	elif store.cashier != null:
		center = store.cashier.global_position + Vector2(0, 38)

	center += CASHIER_FLOW_RESTRICTED_OFFSET
	return Rect2(center - CASHIER_FLOW_RESTRICTED_SIZE * 0.5, CASHIER_FLOW_RESTRICTED_SIZE)


func get_queue_marker_drop_restricted_rect(object_rect: Rect2) -> Rect2:
	for marker in get_queue_drop_block_markers():
		if marker == null:
			continue

		var marker_rect := Rect2(
			marker.global_position - QUEUE_MARKER_DROP_BLOCK_SIZE * 0.5,
			QUEUE_MARKER_DROP_BLOCK_SIZE
		)

		if object_rect.intersects(marker_rect):
			return marker_rect

	return Rect2()


func get_cashier_drop_restricted_rect(object_rect: Rect2) -> Rect2:
	if store.cashier == null:
		store.cashier = store.get_node_or_null("Cashier") as Node2D

	if store.cashier == null:
		return Rect2()

	var restricted_rects: Array[Rect2] = []

	for shape_name in ["CollisionShape2D", "BackCounterCollision"]:
		var collision_shape := store.cashier.get_node_or_null(shape_name) as CollisionShape2D
		var rect := get_collision_shape_rect(collision_shape)

		if rect_has_area(rect):
			restricted_rects.append(rect)

	for rect in restricted_rects:
		if object_rect.intersects(rect):
			return rect

	return Rect2()


func get_queue_drop_block_markers() -> Array[Marker2D]:
	var markers: Array[Marker2D] = []

	if store.store_path_markers == null:
		return markers

	for child in store.store_path_markers.get_children():
		var marker := child as Marker2D
		if marker == null:
			continue

		var role := StringName()
		if marker.has_meta("store_path_role"):
			var role_value: Variant = marker.get_meta("store_path_role")
			role = StringName(str(role_value))

		if role == &"queue_front" or role == &"queue_back":
			markers.append(marker)

	return markers


func has_reachable_store_shelf_visit_position(object: Node2D, candidate: Vector2) -> bool:
	return store._get_store_path_graph().has_reachable_shelf_access(object, candidate)


func get_nearest_installed_shelf() -> Node2D:
	if store.player == null:
		return null

	var nearest_shelf: Node2D = null
	var nearest_distance: float = STORE_SHELF_PICKUP_DISTANCE

	for node in store.get_tree().get_nodes_in_group("shelves"):
		if not node is Shelf:
			continue

		var shelf := node as Shelf

		if not StoreShelfController.is_descendant_of(shelf, store):
			continue

		if shelf.has_meta("is_carried_storage_object") and bool(shelf.get_meta("is_carried_storage_object")):
			continue

		var distance: float = store.player.global_position.distance_to(shelf.global_position)

		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_shelf = shelf

	return nearest_shelf


func is_player_overlapping_shelf_interaction(shelf: Shelf) -> bool:
	if store.player == null or shelf == null:
		return false

	var player_area := store.player.get_node_or_null("InteractionArea") as Area2D
	var shelf_area := shelf.get_node_or_null("InteractionArea") as Area2D

	if player_area == null or shelf_area == null:
		return false

	return shelf_area in player_area.get_overlapping_areas()


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


func store_shelf_access_metadata(object: Node2D, drop_position: Vector2) -> void:
	var metadata_start_usec := Time.get_ticks_usec()
	print_shelf_drop_flow("metadata_start", metadata_start_usec, object, drop_position, get_drop_debug_context(object))
	var graph: StorePathGraph = store._get_store_path_graph()
	graph.store_shelf_access_metadata(object, drop_position)
	print_shelf_drop_flow("metadata_done", metadata_start_usec, object, drop_position, get_drop_debug_context(object))
	print_perf_shelf_if_slow("drop_metadata", metadata_start_usec, object, drop_position)


func schedule_post_shelf_drop_update(object: Node2D, drop_position: Vector2) -> void:
	if object == null:
		return

	store._shelf_access_metadata_update_token += 1
	var update_token: int = int(store._shelf_access_metadata_update_token)
	object.set_meta(PENDING_ACCESS_UPDATE_META, update_token)
	defer_post_shelf_drop_update(object, drop_position, update_token)


func defer_post_shelf_drop_update(object: Node2D, drop_position: Vector2, update_token: int) -> void:
	var post_update_start_usec := Time.get_ticks_usec()
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

	print_shelf_drop_flow("post_update_resume", post_update_start_usec, object, drop_position, get_drop_debug_context(object))
	var register_start_usec := Time.get_ticks_usec()
	store_shelf_access_metadata(object, drop_position)
	store._register_installed_shelf(object)
	print_shelf_drop_flow("register_installed_shelf", register_start_usec, object, drop_position, get_drop_debug_context(object))


func schedule_shelf_access_warmup(delay: float = SHELF_ACCESS_WARMUP_DELAY) -> void:
	store._shelf_access_warmup_token += 1
	var warmup_token: int = int(store._shelf_access_warmup_token)
	defer_shelf_access_warmup(warmup_token, delay)


func defer_shelf_access_warmup(warmup_token: int, delay: float) -> void:
	await store.get_tree().process_frame

	if delay > 0.0:
		await store.get_tree().create_timer(delay).timeout

	if warmup_token != store._shelf_access_warmup_token:
		return

	if not can_run_shelf_access_warmup():
		schedule_shelf_access_warmup(SHELF_ACCESS_WARMUP_DELAY)
		return

	var graph: StorePathGraph = store._get_store_path_graph()

	for shelf_node in store.get_tree().get_nodes_in_group("shelves"):
		if warmup_token != store._shelf_access_warmup_token:
			return

		var shelf := shelf_node as Shelf

		if shelf == null:
			continue

		if graph.has_cached_shelf_access_metadata(shelf):
			continue

		graph.store_shelf_access_metadata(shelf, shelf.global_position)

		await store.get_tree().process_frame


func can_run_shelf_access_warmup() -> bool:
	if store._current_storage != null or store._current_yard != null or store._current_home != null or store._is_transitioning:
		return false

	if store._is_action_locked():
		return false

	return get_carried_object_from_player() == null


func clear_shelf_access_metadata(object: Node2D) -> void:
	var graph: StorePathGraph = store._get_store_path_graph()
	graph.clear_shelf_access_metadata(object)

	if object != null and object.has_meta(PENDING_ACCESS_UPDATE_META):
		object.remove_meta(PENDING_ACCESS_UPDATE_META)


func print_perf_shelf_if_slow(stage: String, start_usec: int, object: Node2D, position: Vector2) -> void:
	var elapsed_msec := float(Time.get_ticks_usec() - start_usec) / 1000.0

	if elapsed_msec < PERF_SHELF_THRESHOLD_MSEC:
		return

	print(
		"[DEBUG][PERF_SHELF] stage=%s shelf=%s position=%s elapsed_ms=%.2f" % [
			stage,
			object.name if object != null else "<null>",
			str(position),
			elapsed_msec
		]
	)


func get_drop_debug_context(
	object: Node2D,
	candidate_count: int = 0,
	restriction: Dictionary = {}
) -> Dictionary:
	var player_pos := Vector2.INF
	var facing := Vector2.ZERO

	if store != null and store.player != null:
		player_pos = store.player.global_position
		facing = get_player_facing_direction()

	return {
		"player_pos": player_pos,
		"facing": facing,
		"candidate_count": candidate_count,
		"restriction_blocked": bool(restriction.get("blocked", false)),
		"restriction_type": str(restriction.get("type", DROP_REJECTION_NONE)),
		"restriction_message": str(restriction.get("message", "")),
		"npc_access_point": _get_object_meta_value(object, "npc_access_point", Vector2.INF),
		"npc_access_side": str(_get_object_meta_value(object, "npc_access_side", "")),
		"npc_access_graph_node": str(_get_object_meta_value(object, "npc_access_graph_node", "")),
		"npc_access_checkout_source": str(_get_object_meta_value(object, "npc_access_checkout_source", ""))
	}


func _get_object_meta_value(object: Node2D, key: StringName, fallback: Variant) -> Variant:
	if object == null:
		return fallback

	if not object.has_meta(key):
		return fallback

	return object.get_meta(key)


func print_shelf_drop_flow(
	stage: String,
	start_usec: int,
	object: Node2D,
	position: Vector2,
	context: Dictionary = {}
) -> void:
	var elapsed_msec := float(Time.get_ticks_usec() - start_usec) / 1000.0
	var shelf_name: String = object.name if object != null else "<null>"
	var is_human_shelf: bool = shelf_name == "ShelfHuman"

	if not is_human_shelf and elapsed_msec < PERF_SHELF_THRESHOLD_MSEC:
		return

	print(
		"[DEBUG][SHELF_DROP_FLOW] stage=%s shelf=%s position=%s elapsed_ms=%.2f player_pos=%s facing=%s candidate_count=%d restriction_blocked=%s restriction_type=%s restriction_message=%s npc_access_point=%s npc_access_side=%s npc_access_graph_node=%s npc_access_checkout_source=%s" % [
			stage,
			shelf_name,
			str(position),
			elapsed_msec,
			str(context.get("player_pos", Vector2.INF)),
			str(context.get("facing", Vector2.ZERO)),
			int(context.get("candidate_count", 0)),
			str(context.get("restriction_blocked", false)),
			str(context.get("restriction_type", "")),
			str(context.get("restriction_message", "")),
			str(context.get("npc_access_point", Vector2.INF)),
			str(context.get("npc_access_side", "")),
			str(context.get("npc_access_graph_node", "")),
			str(context.get("npc_access_checkout_source", ""))
		]
	)


func show_drop_restriction_feedback(restriction: Dictionary) -> void:
	var message := str(restriction.get("message", "I can't place the shelf here."))

	if bool(restriction.get("show_warning", false)):
		show_restricted_drop_feedback(restriction)
		return

	store._show_notification(message, 0.9)


func show_restricted_drop_feedback(restriction: Dictionary) -> void:
	store._restricted_drop_feedback_token += 1
	var feedback_token: int = int(store._restricted_drop_feedback_token)
	var message := str(restriction.get("message", "Keep this area clear for customers."))
	var warning_rect := get_warning_rect_from_restriction(restriction)

	play_restricted_placement_warning(warning_rect)

	for i in RESTRICTED_DROP_MESSAGE_COUNT:
		if feedback_token != store._restricted_drop_feedback_token:
			return

		store._show_notification(message, RESTRICTED_DROP_MESSAGE_DURATION)
		await store.get_tree().create_timer(2.0 / float(RESTRICTED_DROP_MESSAGE_COUNT)).timeout


func get_warning_rect_from_restriction(restriction: Dictionary) -> Rect2:
	var rect_variant: Variant = restriction.get("warning_rect", Rect2())

	if rect_variant is Rect2:
		return rect_variant as Rect2

	return Rect2()


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


func sync_restricted_placement_warning(rect: Rect2) -> void:
	if store._restricted_placement_warning_line == null:
		return

	sync_restricted_warning_line_to_rect(store._restricted_placement_warning_line, rect)


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


func cancel_restricted_drop_feedback() -> void:
	store._restricted_drop_feedback_token += 1
	hide_restricted_placement_warning()


func sync_restricted_warning_line_to_rect(line: Line2D, rect: Rect2) -> void:
	if line == null:
		return

	line.visible = true

	var points := PackedVector2Array([
		store.to_local(rect.position),
		store.to_local(rect.position + Vector2(rect.size.x, 0.0)),
		store.to_local(rect.position + rect.size),
		store.to_local(rect.position + Vector2(0.0, rect.size.y))
	])
	line.points = points


func get_carry_shelf_blocker_position() -> Vector2:
	if store.counter_pos != null:
		return store.counter_pos.global_position + CARRY_SHELF_CASHIER_BLOCKER_OFFSET

	if store.cashier != null:
		return store.cashier.global_position + Vector2(0, 20)

	return Vector2(96, 142)


func update_player_depth_override() -> void:
	if store.player == null:
		store.player = store.get_node_or_null("Player") as Node2D

	if store.cashier == null:
		store.cashier = store.get_node_or_null("Cashier") as Node2D

	if store.player == null or store.cashier == null:
		return

	store.player.z_index = 0


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
