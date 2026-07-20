class_name StorageShelfCarryController
extends Node

const SHELF_DROP_FALLBACKS: Array[Vector2] = [
	Vector2(0, 56),
	Vector2(56, 0),
	Vector2(-56, 0),
	Vector2(0, -36),
	Vector2(56, 36),
	Vector2(-56, 36),
	Vector2(56, -36),
	Vector2(-56, -36)
]

var storage: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(storage_node: Node) -> void:
	storage = storage_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func process_carry(_delta: float) -> void:
	find_player_if_needed()
	update_carried_object_position()
	handle_carry_input()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func handle_carry_input() -> void:
	if storage._is_action_locked():
		return

	if not InputMap.has_action(storage.put_action):
		return

	if not Input.is_action_just_pressed(storage.put_action):
		return

	if storage._player == null:
		return

	if storage._carried_object != null:
		drop_carried_object()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_player_if_needed() -> void:
	if storage._player != null and is_instance_valid(storage._player):
		return

	for node in storage.get_tree().get_nodes_in_group("player"):
		if node is Node2D:
			storage._player = node as Node2D
			return


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_nearest_carryable_shelf() -> Node2D:
	if storage._player == null:
		return null

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var nearest_object: Node2D = null
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var nearest_distance: float = storage.pickup_distance

	for shelf_variant in [storage.shelf_human, storage.shelf_ghost]:
		if not is_instance_valid(shelf_variant):
			continue
		if not (shelf_variant is Node2D):
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var object := shelf_variant as Node2D

		if not object.visible:
			continue

		if object.has_meta("is_carryable_storage_object") and not bool(object.get_meta("is_carryable_storage_object")):
			continue

		if object.has_meta("is_carried_storage_object") and bool(object.get_meta("is_carried_storage_object")):
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var distance: float = storage._player.global_position.distance_to(object.global_position)

		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_object = object

	return nearest_object


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func pickup_object(object: Node2D) -> void:
	if storage._player == null or not is_instance_valid(object):
		return

	storage._carried_object = object
	object.reparent(storage._player, true)
	object.position = storage.carry_offset
	object.z_index = 80
	object.visible = true
	object.set_meta("is_carried_storage_object", true)
	object.set_meta("is_installed_in_store", false)
	set_node_enabled_recursive(object, false)

	if object is Shelf and storage.has_method("register_shelf_picked_up_from_storage"):
		storage.call("register_shelf_picked_up_from_storage", object as Shelf)

	if storage._player.has_method("update_carried_object_visual"):
		storage._player.call("update_carried_object_visual", object)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_pickup_shelf(shelf: Shelf) -> bool:
	find_player_if_needed()

	if storage._player == null:
		return false

	if storage._carried_object != null:
		return false

	if not is_instance_valid(shelf):
		return false

	if storage.has_method("is_managed_storage_shelf"):
		if not bool(storage.call("is_managed_storage_shelf", shelf)):
			return false
	elif not (shelf in [storage.shelf_human, storage.shelf_ghost]):
		return false

	if not shelf.visible:
		return false

	if shelf.has_meta("is_carryable_storage_object") and not bool(shelf.get_meta("is_carryable_storage_object")):
		return false

	if storage._player.global_position.distance_to(shelf.global_position) > storage.pickup_distance:
		return false

	pickup_object(shelf)
	storage._show_notification("Shelf picked up. Press Q to place it.")
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_drop_carried_object() -> bool:
	find_player_if_needed()

	if storage._player == null or storage._carried_object == null:
		return false

	drop_carried_object()
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func drop_carried_object() -> void:
	if storage._player == null or storage._carried_object == null:
		return
	if not is_instance_valid(storage._carried_object):
		storage._carried_object = null
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var drop_position := find_safe_drop_position(storage._carried_object)

	if drop_position == Vector2.INF:
		storage._show_notification("No room to put the shelf here.", 0.5)
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var object: Node2D = storage._carried_object
	object.reparent(storage, true)
	object.global_position = drop_position
	object.z_index = 0
	object.set_meta("is_carried_storage_object", false)
	object.set_meta("is_installed_in_store", false)
	set_node_enabled_recursive(object, true)

	if object is Shelf and storage.has_method("register_shelf_dropped_in_storage"):
		storage.call("register_shelf_dropped_in_storage", object as Shelf)

	storage._carried_object = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func update_carried_object_position() -> void:
	if storage._player == null:
		return

	if storage._carried_object != null and not is_instance_valid(storage._carried_object):
		storage._carried_object = null

	if storage._carried_object == null:
		storage._carried_object = get_carried_object_from_player()

	if storage._carried_object != null and storage._carried_object.get_parent() == storage._player:
		if storage._player.has_method("update_carried_object_visual"):
			storage._player.call("update_carried_object_visual", storage._carried_object)
		else:
			storage._carried_object.position = storage.carry_offset


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_carried_object_from_player() -> Node2D:
	if storage._player == null:
		return null

	for child in storage._player.get_children():
		if child is Node2D and child.has_meta("is_carried_storage_object"):
			if bool(child.get_meta("is_carried_storage_object")):
				return child as Node2D

	return null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func find_safe_drop_position(object: Node2D) -> Vector2:
	for candidate in get_drop_candidates():
		if is_drop_position_clear(object, candidate):
			return candidate

	return Vector2.INF


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_drop_candidates() -> Array[Vector2]:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var candidates: Array[Vector2] = []
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var base_position: Vector2 = storage._player.global_position
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var facing := get_player_facing_direction()

	candidates.append(base_position + facing * 56.0)

	for offset in SHELF_DROP_FALLBACKS:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var candidate: Vector2 = base_position + offset

		if candidate not in candidates:
			candidates.append(candidate)

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var legacy_candidate: Vector2 = base_position + storage.drop_offset

	if legacy_candidate not in candidates:
		candidates.append(legacy_candidate)

	return candidates


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_player_facing_direction() -> Vector2:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var facing: Variant = storage._player.get("facing_direction") if storage._player != null else Vector2.DOWN

	if facing is Vector2 and not facing.is_zero_approx():
		return (facing as Vector2).normalized()

	return Vector2.DOWN


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_drop_position_clear(object: Node2D, candidate: Vector2) -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var collision_shape := get_object_collision_shape(object)

	if collision_shape == null or collision_shape.shape == null:
		return true

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = Transform2D(0.0, candidate + collision_shape.position)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hits: Array[Dictionary] = storage.get_world_2d().direct_space_state.intersect_shape(query, 16)

	for hit in hits:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var collider: Node = hit.get("collider", null)

		if collider == null:
			continue

		if collider == object or is_descendant_of(collider, object):
			continue

		return false

	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_object_collision_shape(object: Node2D) -> CollisionShape2D:
	if object == null:
		return null

	return object.get_node_or_null("PhysicsBody/CollisionShape2D") as CollisionShape2D


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_descendant_of(node: Node, ancestor: Node) -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var current := node

	while current != null:
		if current == ancestor:
			return true

		current = current.get_parent()

	return false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_node_enabled_recursive(node: Node, enabled: bool) -> void:
	if node == null:
		return

	if node is Area2D:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var area := node as Area2D
		area.monitoring = enabled
		area.monitorable = enabled

	if node is CollisionShape2D:
		(node as CollisionShape2D).disabled = not enabled

	if node is CollisionPolygon2D:
		(node as CollisionPolygon2D).disabled = not enabled

	node.set_process(enabled)
	node.set_physics_process(enabled)
	node.set_process_input(enabled)
	node.set_process_unhandled_input(enabled)

	for child in node.get_children():
		set_node_enabled_recursive(child, enabled)
