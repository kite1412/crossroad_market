class_name StoreShelfPlacementController
extends Node

const StoreRuntimeDebugProbeScript = preload("res://scripts/debug/StoreRuntimeDebugProbe.gd")

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
const SHELF_SPACING_WARNING_LINE_WIDTH: float = 1.0
const SHELF_SPACING_WARNING_DURATION: float = 2.0
const RESTRICTED_DANGER_LINE_COLOR := Color(1.0, 0.16, 0.08, 1.0)
const DROP_REJECTION_NONE: StringName = &"none"
const DROP_REJECTION_CASHIER_FLOW: StringName = &"cashier_flow"
const DROP_REJECTION_COLLISION: StringName = &"collision"
const DROP_REJECTION_SHELF_SPACING: StringName = &"shelf_spacing"
const SHELF_DROP_FALLBACK_DISTANCE: float = 44.0
const QUEUE_MARKER_DROP_BLOCK_SIZE := Vector2(56, 18)
const SHELF_SPACING_AREA_NAME: String = "ShelfSpacingArea"
const SHELF_SPACING_AREA_PATH: NodePath = NodePath("ShelfSpacingArea")
const ALL_PHYSICS_LAYERS: int = 0x7FFFFFFF
const PENDING_ACCESS_UPDATE_META: StringName = &"pending_shelf_access_update_token"
const NPC_PATH_PENDING_META: StringName = &"npc_path_pending"
const DEFERRED_ACCESS_DELAY_MSEC: int = 150
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
	show_warning: bool = false,
	warning_circle_center: Vector2 = Vector2.INF,
	warning_circle_radius: float = 0.0
) -> Dictionary:
	return {
		"blocked": blocked,
		"type": rejection_type,
		"message": message,
		"warning_rect": warning_rect,
		"show_warning": show_warning,
		"warning_circle_center": warning_circle_center,
		"warning_circle_radius": warning_circle_radius
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
func get_shelf_spacing_circle_at(object: Node2D, candidate: Vector2) -> Dictionary:
	if object == null:
		return {"valid": false}

	var spacing_area := object.get_node_or_null(SHELF_SPACING_AREA_PATH) as Area2D
	if spacing_area == null:
		return {"valid": false}

	var collision_shape := spacing_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return {"valid": false}

	var circle := collision_shape.shape as CircleShape2D
	if circle == null:
		return {"valid": false}

	return {
		"valid": true,
		"center": candidate + spacing_area.position + collision_shape.position,
		"radius": circle.radius
	}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_spacing_circle(object: Node2D) -> Dictionary:
	if object == null:
		return {"valid": false}

	return get_shelf_spacing_circle_at(object, object.global_position)


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
	if not store._is_store_world_active:
		return false

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
	if not store._is_store_world_active:
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
	var debug_start_usec: int = Time.get_ticks_usec()
	if store.player == null:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var primary_drop_position := get_primary_shelf_drop_position()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var primary_restriction := evaluate_shelf_drop_restriction(object, primary_drop_position)
	record_shelf_drop_decision(
		&"shelf_drop_primary_check",
		object,
		primary_drop_position,
		primary_restriction,
		"primary"
	)

	if primary_restriction.get("type", DROP_REJECTION_NONE) == DROP_REJECTION_CASHIER_FLOW:
		show_drop_restriction_feedback(primary_restriction)
		return
	if primary_restriction.get("type", DROP_REJECTION_NONE) == DROP_REJECTION_SHELF_SPACING:
		show_drop_restriction_feedback(primary_restriction)
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var drop_candidates: Array[Vector2] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var drop_position := primary_drop_position

	if bool(primary_restriction.get("blocked", false)):
		drop_candidates = get_drop_candidates()
		drop_position = find_safe_drop_position(object, drop_candidates)
		record_shelf_drop_decision(
			&"shelf_drop_fallback_select",
			object,
			drop_position,
			primary_restriction,
			"fallback",
			drop_candidates.size()
		)

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
		record_shelf_drop_decision(
			&"shelf_drop_rejected",
			object,
			primary_drop_position,
			primary_restriction,
			"final",
			drop_candidates.size()
		)
		return

	if object is Shelf:
		(object as Shelf).set_lifecycle(Shelf.LIFECYCLE_BEING_DROPPED)

	var dirty_rect := get_object_body_rect_at(object, drop_position).grow(16.0)
	object.reparent(store, true)
	object.global_position = drop_position
	object.z_index = 0
	set_shelf_carried_state(object, false)
	if not object.is_in_group("shelves"):
		object.add_to_group("shelves")

	if object is Shelf:
		object.set_meta(NPC_PATH_PENDING_META, true)
		object.set_meta("npc_path_ready", false)

	store._register_installed_shelf(object)
	record_shelf_spacing_accept(object, drop_position)

	if store.has_method("mark_navigation_dirty"):
		store.call("mark_navigation_dirty", dirty_rect)

	store._show_passive_notification("Shelf placed in the store.", 2.0, true)
	schedule_post_shelf_drop_update(object, drop_position)
	record_shelf_drop_decision(
		&"shelf_drop_committed",
		object,
		drop_position,
		make_drop_restriction(),
		"committed",
		drop_candidates.size()
	)
	pass
	set_customer_path_visual_visible(false)
	StoreRuntimeDebugProbeScript.record(
		&"store_drop_shelf",
		StoreRuntimeDebugProbeScript.elapsed_msec(debug_start_usec),
		{
			"object": object.name,
			"candidate": drop_position
		},
		2.0
	)


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
	if object == null or not candidate.is_finite():
		return make_drop_restriction(
			true,
			DROP_REJECTION_COLLISION,
			"I can't place the shelf here.",
			Rect2(),
			false
		)

	var object_rect: Rect2 = get_object_body_rect_at(object, candidate)

	var spacing_restriction := get_shelf_spacing_restriction(object, candidate)
	if bool(spacing_restriction.get("blocked", false)):
		return spacing_restriction

	if not is_drop_position_clear(object, candidate):
		return make_drop_restriction(
			true,
			DROP_REJECTION_COLLISION,
			"I can't place the shelf here.",
			object_rect,
			false
		)

	var cashier_flow_rect: Rect2 = get_cashier_flow_restricted_rect()
	if rect_has_area(cashier_flow_rect) and object_rect.intersects(cashier_flow_rect):
		return make_drop_restriction(
			true,
			DROP_REJECTION_CASHIER_FLOW,
			"Keep this area clear for customers.",
			cashier_flow_rect,
			true
		)

	var cashier_rect: Rect2 = get_cashier_drop_restricted_rect(object_rect)
	if rect_has_area(cashier_rect):
		return make_drop_restriction(
			true,
			DROP_REJECTION_CASHIER_FLOW,
			"Keep the cashier clear.",
			cashier_rect,
			true
		)

	var queue_rect: Rect2 = get_queue_marker_drop_restricted_rect(object_rect)
	if rect_has_area(queue_rect):
		return make_drop_restriction(
			true,
			DROP_REJECTION_CASHIER_FLOW,
			"Keep the checkout queue clear.",
			queue_rect,
			true
		)

	return make_drop_restriction()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_spacing_restriction(object: Node2D, candidate: Vector2) -> Dictionary:
	var candidate_circle := get_shelf_spacing_circle_at(object, candidate)
	if not bool(candidate_circle.get("valid", false)):
		return make_drop_restriction()

	var candidate_center := candidate_circle.get("center", Vector2.INF) as Vector2
	var candidate_radius := float(candidate_circle.get("radius", 0.0))
	if not candidate_center.is_finite() or candidate_radius <= 0.0:
		return make_drop_restriction()

	var physics_restriction := get_shelf_spacing_physics_restriction(
		object,
		candidate_center,
		candidate_radius
	)
	if bool(physics_restriction.get("blocked", false)):
		return physics_restriction

	var shelves_checked := 0
	for shelf in get_spacing_candidate_shelves(object):
		var shelf_circle := get_shelf_spacing_circle(shelf)
		if not bool(shelf_circle.get("valid", false)):
			continue

		var shelf_center := shelf_circle.get("center", Vector2.INF) as Vector2
		var shelf_radius := float(shelf_circle.get("radius", 0.0))
		if not shelf_center.is_finite() or shelf_radius <= 0.0:
			continue

		shelves_checked += 1
		var distance := candidate_center.distance_to(shelf_center)
		var required_distance := candidate_radius + shelf_radius
		if distance >= required_distance:
			continue

		var restriction := make_drop_restriction(
			true,
			DROP_REJECTION_SHELF_SPACING,
			"Leave space between shelves for customers.",
			Rect2(),
			true,
			candidate_center,
			candidate_radius
		)
		restriction["candidate_center"] = candidate_center
		restriction["candidate_radius"] = candidate_radius
		restriction["other_shelf"] = shelf.name
		restriction["other_shelf_path"] = str(shelf.get_path())
		restriction["other_center"] = shelf_center
		restriction["other_radius"] = shelf_radius
		restriction["distance"] = distance
		restriction["required_distance"] = required_distance
		restriction["shelves_checked"] = shelves_checked
		return restriction

	return make_drop_restriction()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_spacing_physics_restriction(
	object: Node2D,
	candidate_center: Vector2,
	candidate_radius: float
) -> Dictionary:
	if store == null or not candidate_center.is_finite() or candidate_radius <= 0.0:
		return make_drop_restriction()

	var circle := CircleShape2D.new()
	circle.radius = candidate_radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, candidate_center)
	query.collide_with_bodies = false
	query.collide_with_areas = true
	query.collision_mask = ALL_PHYSICS_LAYERS

	var hits: Array[Dictionary] = store.get_world_2d().direct_space_state.intersect_shape(query, 32)
	var spacing_hits := 0
	for hit in hits:
		if not (hit is Dictionary):
			continue

		var collider_variant: Variant = (hit as Dictionary).get("collider", null)
		var collider := collider_variant as Node
		if collider == null or not is_instance_valid(collider):
			continue
		if not _is_shelf_spacing_area(collider):
			continue
		if collider == object or StoreShelfController.is_descendant_of(collider, object):
			continue

		var shelf := _get_shelf_from_spacing_area(collider)
		if shelf == null or not is_instance_valid(shelf):
			continue
		if shelf == object or StoreShelfController.is_descendant_of(shelf, object):
			continue
		if StoreShelfController.is_descendant_of(object, shelf):
			continue
		if not StoreShelfController.is_descendant_of(shelf, store):
			continue

		var shelf_circle := get_shelf_spacing_circle(shelf)
		var shelf_center := shelf_circle.get("center", Vector2.INF) as Vector2
		var shelf_radius := float(shelf_circle.get("radius", 0.0))
		spacing_hits += 1

		var distance := 0.0
		if shelf_center.is_finite():
			distance = candidate_center.distance_to(shelf_center)
		var required_distance := candidate_radius + shelf_radius
		var restriction := make_drop_restriction(
			true,
			DROP_REJECTION_SHELF_SPACING,
			"Leave space between shelves for customers.",
			Rect2(),
			true,
			candidate_center,
			candidate_radius
		)
		restriction["candidate_center"] = candidate_center
		restriction["candidate_radius"] = candidate_radius
		restriction["other_shelf"] = shelf.name
		restriction["other_shelf_path"] = str(shelf.get_path())
		restriction["other_center"] = shelf_center
		restriction["other_radius"] = shelf_radius
		restriction["distance"] = distance
		restriction["required_distance"] = required_distance
		restriction["shelves_checked"] = spacing_hits
		restriction["spacing_query_hits"] = hits.size()
		restriction["source"] = "physics_area"
		return restriction

	return make_drop_restriction()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func record_shelf_spacing_accept(object: Node2D, drop_position: Vector2) -> void:
	var candidate_circle := get_shelf_spacing_circle_at(object, drop_position)
	if not bool(candidate_circle.get("valid", false)):
		StoreRuntimeDebugProbeScript.record(
			&"shelf_spacing_accept",
			0.0,
			{
				"object": _get_node_name_or_empty(object),
				"reason": "candidate_circle_missing"
			},
			0.5
		)
		return

	var candidate_center := candidate_circle.get("center", Vector2.INF) as Vector2
	var candidate_radius := float(candidate_circle.get("radius", 0.0))
	var nearest_gap := INF
	var nearest_distance := INF
	var nearest_required := 0.0
	var nearest_shelf := ""
	var nearest_shelf_path := ""
	var shelves_checked := 0

	for shelf in get_spacing_candidate_shelves(object):
		var shelf_circle := get_shelf_spacing_circle(shelf)
		if not bool(shelf_circle.get("valid", false)):
			continue

		var shelf_center := shelf_circle.get("center", Vector2.INF) as Vector2
		var shelf_radius := float(shelf_circle.get("radius", 0.0))
		if not candidate_center.is_finite() or not shelf_center.is_finite():
			continue
		if candidate_radius <= 0.0 or shelf_radius <= 0.0:
			continue

		shelves_checked += 1
		var distance := candidate_center.distance_to(shelf_center)
		var required_distance := candidate_radius + shelf_radius
		var gap := distance - required_distance
		if gap >= nearest_gap:
			continue

		nearest_gap = gap
		nearest_distance = distance
		nearest_required = required_distance
		nearest_shelf = shelf.name
		nearest_shelf_path = str(shelf.get_path())

	StoreRuntimeDebugProbeScript.record(
		&"shelf_spacing_accept",
		0.0,
		{
			"object": _get_node_name_or_empty(object),
			"center": _format_vector(candidate_center),
			"radius": snappedf(candidate_radius, 0.01),
			"shelves_checked": shelves_checked,
			"nearest_shelf": nearest_shelf,
			"nearest_shelf_path": nearest_shelf_path,
			"nearest_distance": snappedf(nearest_distance, 0.01) if is_finite(nearest_distance) else -1.0,
			"nearest_required_distance": snappedf(nearest_required, 0.01),
			"nearest_gap": snappedf(nearest_gap, 0.01) if is_finite(nearest_gap) else -1.0,
			"source": "accepted_after_spacing_checks"
		},
		0.5
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_spacing_candidate_shelves(object: Node2D) -> Array[Node2D]:
	var shelves: Array[Node2D] = []
	var seen := {}

	if store == null:
		return shelves

	for shelf_variant in store.get_tree().get_nodes_in_group("shelves"):
		append_spacing_candidate_shelf(shelves, seen, shelf_variant, object)

	append_spacing_candidate_shelves_from_tree(store, shelves, seen, object)
	return shelves


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func append_spacing_candidate_shelves_from_tree(
	root: Node,
	shelves: Array[Node2D],
	seen: Dictionary,
	object: Node2D
) -> void:
	if root == null:
		return

	for child in root.get_children():
		append_spacing_candidate_shelf(shelves, seen, child, object)
		append_spacing_candidate_shelves_from_tree(child, shelves, seen, object)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func append_spacing_candidate_shelf(
	shelves: Array[Node2D],
	seen: Dictionary,
	node: Variant,
	object: Node2D
) -> void:
	var shelf := node as Node2D
	if shelf == null or not is_instance_valid(shelf):
		return
	if shelf == object or StoreShelfController.is_descendant_of(shelf, object):
		return
	if StoreShelfController.is_descendant_of(object, shelf):
		return
	if not StoreShelfController.is_descendant_of(shelf, store):
		return
	if shelf.get_node_or_null(SHELF_SPACING_AREA_PATH) == null:
		return

	var instance_id := shelf.get_instance_id()
	if seen.has(instance_id):
		return

	seen[instance_id] = true
	shelves.append(shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_shelf_spacing_area(node: Node) -> bool:
	return node is Area2D and String(node.name) == SHELF_SPACING_AREA_NAME


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_shelf_from_spacing_area(node: Node) -> Node2D:
	var current := node
	while current != null:
		if current is Shelf:
			return current as Node2D
		current = current.get_parent()
	return null


func _get_node_name_or_empty(node: Node) -> String:
	if node == null:
		return ""
	return String(node.name)


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
		var marker := child as Marker2D
		if marker == null:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var role := StringName()
		if marker.has_meta("store_path_role"):
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var role_value: Variant = marker.get_meta("store_path_role")
			role = StringName(str(role_value))

		if role == &"queue_front" or role == &"queue_back":
			markers.append(marker)

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

	var dirty_rect := get_object_body_rect_at(object, object.global_position).grow(16.0)
	if store.has_method("mark_navigation_dirty"):
		store.call("mark_navigation_dirty", dirty_rect)

	if object is Shelf:
		(object as Shelf).set_lifecycle(Shelf.LIFECYCLE_BEING_PICKED_UP)
		_notify_npcs_shelf_picked_up(object as Shelf)

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
		if object is Shelf:
			(object as Shelf).set_lifecycle(Shelf.LIFECYCLE_CARRIED)
		object.remove_from_group("shelves")
		store._set_node_enabled_recursive(object, false)
	else:
		if object is Shelf:
			(object as Shelf).set_lifecycle(Shelf.LIFECYCLE_PLACED)
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
	var ready_msec: int = Time.get_ticks_msec() + DEFERRED_ACCESS_DELAY_MSEC
	if store != null and store.has_method("enqueue_simulation_job"):
		store.call(
			"enqueue_simulation_job",
			Callable(
				self,
				"execute_deferred_shelf_access_update"
			).bind(object, drop_position, update_token, ready_msec),
			&"normal",
			&"shelf_access_update"
		)
	else:
		defer_post_shelf_drop_update(object, drop_position, update_token)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func execute_deferred_shelf_access_update(
	object: Node2D,
	drop_position: Vector2,
	update_token: int,
	ready_msec: int
) -> bool:
	if Time.get_ticks_msec() < ready_msec:
		return false

	if object == null or not is_instance_valid(object):
		_record_deferred_shelf_access_update_skip(
			object,
			drop_position,
			update_token,
			"object_invalid"
		)
		return true

	if not object.has_meta(PENDING_ACCESS_UPDATE_META):
		_record_deferred_shelf_access_update_skip(
			object,
			drop_position,
			update_token,
			"pending_token_missing"
		)
		return true

	if int(object.get_meta(PENDING_ACCESS_UPDATE_META)) != update_token:
		_record_deferred_shelf_access_update_skip(
			object,
			drop_position,
			update_token,
			"pending_token_stale"
		)
		return true

	if object.has_meta("is_carried_storage_object") and bool(object.get_meta("is_carried_storage_object")):
		object.remove_meta(PENDING_ACCESS_UPDATE_META)
		object.remove_meta(NPC_PATH_PENDING_META)
		_record_deferred_shelf_access_update_skip(
			object,
			drop_position,
			update_token,
			"object_carried"
		)
		return true

	object.remove_meta(PENDING_ACCESS_UPDATE_META)
	var access_start_usec: int = Time.get_ticks_usec()
	store_shelf_access_metadata(object, drop_position)
	var access_context := _get_deferred_shelf_access_update_context(
		object,
		drop_position,
		update_token
	)
	StoreRuntimeDebugProbeScript.record(
		&"shelf_access_metadata",
		StoreRuntimeDebugProbeScript.elapsed_msec(access_start_usec),
		access_context,
		2.0
	)
	object.remove_meta(NPC_PATH_PENDING_META)

	if object is Shelf and not bool(object.get_meta("npc_path_ready", false)):
		store._show_passive_notification(
			"Customers can't reach this shelf.",
			2.0,
			true
		)
		return true
	if object is Shelf:
		_notify_npcs_shelf_access_changed(object as Shelf)
	return true


func _record_deferred_shelf_access_update_skip(
	object: Node2D,
	drop_position: Vector2,
	update_token: int,
	reason: String
) -> void:
	var context := _get_deferred_shelf_access_update_context(
		object,
		drop_position,
		update_token
	)
	context["reason"] = reason
	StoreRuntimeDebugProbeScript.record(
		&"shelf_access_update_skip",
		0.0,
		context,
		0.0
	)


func _get_deferred_shelf_access_update_context(
	object: Node2D,
	drop_position: Vector2,
	update_token: int
) -> Dictionary:
	var object_name := ""
	if object != null and is_instance_valid(object):
		object_name = object.name

	var context: Dictionary = {
		"object": object_name,
		"drop_position": _format_vector(drop_position),
		"update_token": update_token
	}
	if object == null or not is_instance_valid(object):
		return context

	context["object_path"] = str(object.get_path())
	context["position"] = _format_vector(object.global_position)
	context["pending_access_update"] = object.has_meta(PENDING_ACCESS_UPDATE_META)
	context["path_pending"] = bool(object.get_meta(NPC_PATH_PENDING_META, false))
	context["npc_path_ready"] = bool(object.get_meta("npc_path_ready", false))
	context["is_carried"] = bool(object.get_meta("is_carried_storage_object", false))

	var access_point_variant: Variant = object.get_meta("npc_access_point", Vector2.INF)
	if access_point_variant is Vector2:
		context["npc_access_point"] = _format_vector(access_point_variant as Vector2)
	var graph_node_variant: Variant = object.get_meta("npc_access_graph_node", Vector2.INF)
	if graph_node_variant is Vector2:
		context["npc_access_graph_node"] = _format_vector(graph_node_variant as Vector2)
	context["npc_access_source"] = str(object.get_meta("npc_access_source", ""))
	context["npc_access_port_id"] = str(object.get_meta("npc_access_port_id", ""))
	context["npc_access_checkout_source"] = str(object.get_meta("npc_access_checkout_source", ""))

	if object is Shelf:
		var shelf := object as Shelf
		context["shelf_id"] = String(shelf.get_shelf_id())
		context["shelf_revision"] = shelf.get_revision()
		context["lifecycle"] = String(shelf.get_lifecycle())

	return context


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _notify_npcs_shelf_access_changed(shelf: Shelf) -> void:
	if store == null or shelf == null or not is_instance_valid(shelf):
		return
	if not bool(shelf.get_meta("npc_path_ready", false)):
		_record_shelf_move_probe(&"npc_shelf_retarget_after_drop", shelf, {
			"reason": "path_not_ready",
			"matched_npcs": 0,
			"retargeted_npcs": 0
		})
		return

	var matched_count := 0
	var retargeted_count := 0
	for npc_node in store.get_tree().get_nodes_in_group("npcs"):
		if npc_node == null or not is_instance_valid(npc_node):
			continue
		if not _is_npc_targeting_shelf(npc_node, shelf):
			continue
		matched_count += 1
		if bool(npc_node.get("_has_taken_shelf_item")):
			_record_npc_shelf_move_probe(
				&"npc_shelf_retarget_after_drop",
				shelf,
				npc_node,
				{"reason": "already_has_item"}
			)
			continue

		var visit_position: Vector2 = npc_node._get_shelf_visit_position(shelf)
		if not visit_position.is_finite():
			_record_npc_shelf_move_probe(
				&"npc_shelf_retarget_after_drop",
				shelf,
				npc_node,
				{"reason": "visit_position_invalid"}
			)
			continue

		npc_node._target_shelf = shelf
		if npc_node._shopping_job != null:
			npc_node._shopping_job.set_target_shelf(shelf)
		if (
			npc_node._shopping_flow != null
			and npc_node._shopping_flow.has_method("clear_shelf_route_failure")
		):
			npc_node._shopping_flow.clear_shelf_route_failure(shelf)

		npc_node.target_position = visit_position
		npc_node._movement_route.clear()
		npc_node._movement_route_destination = Vector2.INF
		if npc_node.has_method("_reset_stuck_watchdog"):
			npc_node._reset_stuck_watchdog()
		npc_node.set_meta(&"path_possibly_invalid", true)
		if npc_node.current_state == NPC.State.WAIT_FOR_SHELF:
			npc_node._set_state(NPC.State.WALK_TO_SHELF)
		retargeted_count += 1
		_record_npc_shelf_move_probe(
			&"npc_shelf_retarget_after_drop",
			shelf,
			npc_node,
			{
				"reason": "retargeted",
				"visit_position": _format_vector(visit_position)
			}
		)

	_record_shelf_move_probe(&"npc_shelf_retarget_after_drop", shelf, {
		"reason": "summary",
		"matched_npcs": matched_count,
		"retargeted_npcs": retargeted_count
	})


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _notify_npcs_shelf_picked_up(shelf: Shelf) -> void:
	if store == null or shelf == null or not is_instance_valid(shelf):
		return

	var matched_count := 0
	var waiting_count := 0
	for npc_node in store.get_tree().get_nodes_in_group("npcs"):
		if npc_node == null or not is_instance_valid(npc_node):
			continue
		if not _is_npc_targeting_shelf(npc_node, shelf):
			continue
		matched_count += 1
		if bool(npc_node.get("_has_taken_shelf_item")):
			_record_npc_shelf_move_probe(
				&"npc_shelf_move_notify",
				shelf,
				npc_node,
				{"reason": "already_has_item"}
			)
			continue

		npc_node.velocity = Vector2.ZERO
		npc_node._movement_route.clear()
		npc_node._movement_route_destination = Vector2.INF
		if npc_node.has_method("_reset_stuck_watchdog"):
			npc_node._reset_stuck_watchdog()
		npc_node.target_position = npc_node.global_position
		npc_node._waiting_for_shelf_return = true
		npc_node._shelf_wait_timer = 0.0
		npc_node.set_meta(&"path_possibly_invalid", true)
		if npc_node.current_state != NPC.State.WAIT_FOR_SHELF:
			npc_node._set_state(NPC.State.WAIT_FOR_SHELF)
		waiting_count += 1
		_record_npc_shelf_move_probe(
			&"npc_shelf_move_notify",
			shelf,
			npc_node,
			{"reason": "set_wait_for_shelf"}
		)

	_record_shelf_move_probe(&"npc_shelf_move_notify", shelf, {
		"reason": "summary",
		"matched_npcs": matched_count,
		"waiting_npcs": waiting_count
	})


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _record_npc_shelf_move_probe(
	label: StringName,
	shelf: Shelf,
	npc_node: Node,
	extra_context: Dictionary
) -> void:
	var context: Dictionary = _get_shelf_move_context(shelf)
	if npc_node != null and is_instance_valid(npc_node):
		context["npc_id"] = npc_node.get_instance_id()
		context["npc_state"] = int(npc_node.get("current_state"))
		if npc_node is Node2D:
			context["npc_position"] = _format_vector((npc_node as Node2D).global_position)
		var target_variant: Variant = npc_node.get("target_position")
		if target_variant is Vector2:
			context["npc_target"] = _format_vector(target_variant as Vector2)
		var route_variant: Variant = npc_node.get("_movement_route")
		context["npc_route_points"] = (
			(route_variant as Array).size()
			if route_variant is Array
			else 0
		)
		context["npc_waiting_for_shelf"] = bool(npc_node.get("_waiting_for_shelf_return"))
		context["npc_has_item"] = bool(npc_node.get("_has_taken_shelf_item"))

	for key in extra_context:
		context[key] = extra_context[key]

	StoreRuntimeDebugProbeScript.record(label, 0.0, context, 0.0)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _record_shelf_move_probe(
	label: StringName,
	shelf: Shelf,
	extra_context: Dictionary
) -> void:
	var context: Dictionary = _get_shelf_move_context(shelf)
	for key in extra_context:
		context[key] = extra_context[key]

	StoreRuntimeDebugProbeScript.record(label, 0.0, context, 0.0)


func record_shelf_drop_decision(
	label: StringName,
	object: Node2D,
	candidate: Vector2,
	restriction: Dictionary,
	stage: String,
	candidate_count: int = 0
) -> void:
	var context: Dictionary = {
		"stage": stage,
		"object": object.name if object != null else "",
		"candidate": _format_vector(candidate),
		"blocked": bool(restriction.get("blocked", false)),
		"type": StringName(str(restriction.get("type", DROP_REJECTION_NONE))),
		"message": str(restriction.get("message", "")),
		"candidate_count": candidate_count
	}
	if object is Shelf:
		var shelf := object as Shelf
		context["shelf_id"] = String(shelf.get_shelf_id())
		context["shelf_revision"] = shelf.get_revision()
		context["shelf_position"] = _format_vector(shelf.global_position)
		context["lifecycle"] = String(shelf.get_lifecycle())
	if restriction.has("other_shelf"):
		context["other_shelf"] = str(restriction.get("other_shelf", ""))
	if restriction.has("other_shelf_path"):
		context["other_shelf_path"] = str(restriction.get("other_shelf_path", ""))
	if restriction.has("source"):
		context["source"] = str(restriction.get("source", ""))
	if restriction.has("object_rect"):
		context["object_rect"] = str(restriction.get("object_rect", Rect2()))
	if restriction.has("restricted_rect"):
		context["restricted_rect"] = str(restriction.get("restricted_rect", Rect2()))
	if restriction.has("candidate_center"):
		var candidate_center_variant: Variant = restriction.get("candidate_center", Vector2.INF)
		if candidate_center_variant is Vector2:
			context["candidate_center"] = _format_vector(candidate_center_variant as Vector2)
	if restriction.has("other_center"):
		var other_center_variant: Variant = restriction.get("other_center", Vector2.INF)
		if other_center_variant is Vector2:
			context["other_center"] = _format_vector(other_center_variant as Vector2)
	if restriction.has("distance"):
		context["distance"] = snappedf(float(restriction.get("distance", 0.0)), 0.01)
	if restriction.has("required_distance"):
		context["required_distance"] = snappedf(
			float(restriction.get("required_distance", 0.0)),
			0.01
		)
	if restriction.has("candidate_radius"):
		context["candidate_radius"] = snappedf(
			float(restriction.get("candidate_radius", 0.0)),
			0.01
		)
	if restriction.has("other_radius"):
		context["other_radius"] = snappedf(
			float(restriction.get("other_radius", 0.0)),
			0.01
		)
	if restriction.has("shelves_checked"):
		context["shelves_checked"] = int(restriction.get("shelves_checked", -1))
	if restriction.has("spacing_query_hits"):
		context["spacing_query_hits"] = int(restriction.get("spacing_query_hits", -1))

	StoreRuntimeDebugProbeScript.record(label, 0.0, context, 0.0)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_shelf_move_context(shelf: Shelf) -> Dictionary:
	var context: Dictionary = {}
	if shelf != null and is_instance_valid(shelf):
		context["shelf_id"] = String(shelf.get_shelf_id())
		context["shelf_revision"] = shelf.get_revision()
		context["shelf_position"] = _format_vector(shelf.global_position)
		context["npc_path_ready"] = bool(shelf.get_meta("npc_path_ready", false))
		var access_variant: Variant = shelf.get_meta("npc_access_point", Vector2.INF)
		if access_variant is Vector2:
			context["npc_access_point"] = _format_vector(access_variant as Vector2)

	return context


func _format_vector(value: Vector2) -> String:
	if not value.is_finite():
		return "inf,inf"
	return "%.1f,%.1f" % [value.x, value.y]


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_npc_targeting_shelf(npc_node: Node, shelf: Shelf) -> bool:
	var target_shelf_variant: Variant = npc_node.get("_target_shelf")
	if target_shelf_variant == shelf:
		return true

	var shopping_job_variant: Variant = npc_node.get("_shopping_job")
	if shopping_job_variant == null:
		return false

	var target_shelf_id: StringName = StringName(str(
		shopping_job_variant.get("target_shelf_id")
	))
	return (
		target_shelf_id != StringName()
		and target_shelf_id == shelf.get_shelf_id()
	)


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
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var warning_circle := get_warning_circle_from_restriction(restriction)
	if restriction.get("type", DROP_REJECTION_NONE) == DROP_REJECTION_SHELF_SPACING:
		var other_center := restriction.get("other_center", Vector2.INF) as Vector2
		var candidate_center := restriction.get("candidate_center", Vector2.INF) as Vector2
		StoreRuntimeDebugProbeScript.record(
			&"shelf_spacing_reject",
			0.0,
			{
				"center": _format_vector(
					warning_circle.get("center", Vector2.INF) as Vector2
				),
				"candidate_center": _format_vector(candidate_center),
				"radius": snappedf(
					float(warning_circle.get("radius", 0.0)),
					0.01
				),
				"other_shelf": str(restriction.get("other_shelf", "")),
				"other_shelf_path": str(restriction.get("other_shelf_path", "")),
				"other_center": _format_vector(other_center),
				"distance": snappedf(float(restriction.get("distance", 0.0)), 0.01),
				"required_distance": snappedf(float(restriction.get("required_distance", 0.0)), 0.01),
				"shelves_checked": int(restriction.get("shelves_checked", 0)),
				"spacing_query_hits": int(restriction.get("spacing_query_hits", -1)),
				"source": str(restriction.get("source", "node_scan"))
			},
			0.5
		)

	if bool(warning_circle.get("valid", false)):
		play_restricted_placement_warning_circle(
			warning_circle.get("center", Vector2.INF) as Vector2,
			float(warning_circle.get("radius", 0.0))
		)
	else:
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
func get_warning_circle_from_restriction(restriction: Dictionary) -> Dictionary:
	var center := restriction.get("warning_circle_center", Vector2.INF) as Vector2
	var radius := float(restriction.get("warning_circle_radius", 0.0))
	return {
		"valid": center.is_finite() and radius > 0.0,
		"center": center,
		"radius": radius
	}


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
func play_restricted_placement_warning_circle(center: Vector2, radius: float) -> void:
	if store._current_storage != null or store._current_yard != null or store._is_transitioning:
		hide_restricted_placement_warning()
		return

	if store._restricted_placement_warning == null:
		return

	if store._restricted_placement_warning_tween != null and store._restricted_placement_warning_tween.is_valid():
		store._restricted_placement_warning_tween.kill()
	store._restricted_placement_warning_tween = null

	if not center.is_finite() or radius <= 0.0:
		hide_restricted_placement_warning()
		return

	if store._restricted_placement_warning_line != null:
		store._restricted_placement_warning_line.width = SHELF_SPACING_WARNING_LINE_WIDTH

	sync_restricted_placement_warning_circle(center, radius)
	store._restricted_placement_warning.visible = true
	store._restricted_placement_warning.modulate.a = 0.0
	store._restricted_placement_warning_tween = store.create_tween()
	store._restricted_placement_warning_tween.tween_property(
		store._restricted_placement_warning,
		"modulate:a",
		1.0,
		SHELF_SPACING_WARNING_DURATION * 0.5
	)
	store._restricted_placement_warning_tween.tween_property(
		store._restricted_placement_warning,
		"modulate:a",
		0.0,
		SHELF_SPACING_WARNING_DURATION * 0.5
	)
	store._restricted_placement_warning_tween.tween_callback(func() -> void:
		store._restricted_placement_warning_tween = null
		hide_restricted_placement_warning()
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func sync_restricted_placement_warning(rect: Rect2) -> void:
	if store._restricted_placement_warning_line == null:
		return

	store._restricted_placement_warning_line.width = RESTRICTED_DANGER_LINE_WIDTH
	sync_restricted_warning_line_to_rect(store._restricted_placement_warning_line, rect)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func sync_restricted_placement_warning_circle(center: Vector2, radius: float) -> void:
	if store._restricted_placement_warning_line == null:
		return

	sync_restricted_warning_line_to_circle(
		store._restricted_placement_warning_line,
		center,
		radius
	)


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
func sync_restricted_warning_line_to_circle(
	line: Line2D,
	center: Vector2,
	radius: float
) -> void:
	if line == null:
		return

	line.visible = true
	line.closed = true

	var points := PackedVector2Array()
	var segment_count := 48
	for index in range(segment_count):
		var angle := TAU * float(index) / float(segment_count)
		var world_point := center + Vector2(cos(angle), sin(angle)) * radius
		points.append(store.to_local(world_point))
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
