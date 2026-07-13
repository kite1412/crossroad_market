extends Node2D
## Backroom for Day 1 restocking.
## Human and ghost shelves start here. Ghost shelf and mystery box are locked
## behind the dark storage section until the human shelf has been installed
## and stocked in the store.

signal return_to_store(door_type: String)
signal mystery_discovered()
signal mystery_item_taken()
signal ghost_shelf_item_placed(slot_index: int, item_id: String)

const SUPPLY_BOX_DEPTH_HALF_WIDTH: float = 34.0
const SUPPLY_BOX_DEPTH_BACK_OFFSET: float = 48.0
const SUPPLY_BOX_DEPTH_FRONT_OFFSET: float = 8.0
const SHELF_DEPTH_HALF_WIDTH: float = 48.0
const SHELF_DEPTH_BACK_OFFSET: float = 56.0
const SHELF_DEPTH_FRONT_OFFSET: float = 8.0
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

@export var pickup_distance: float = 70.0
@export var carry_offset: Vector2 = Vector2(0, -34)
@export var drop_offset: Vector2 = Vector2(0, 28)
@export var put_action: StringName = &"put"

@onready var return_door: Area2D = get_node_or_null("ReturnDoor") as Area2D
@onready var player_spawn: Marker2D = get_node_or_null("PlayerSpawn") as Marker2D
@onready var background: ColorRect = get_node_or_null("Background") as ColorRect
@onready var normal_box: SupplyBox = get_node_or_null("Normal") as SupplyBox
@onready var mystery_box: MysterySupplyBox = get_node_or_null("Mystery") as MysterySupplyBox
@onready var shelf_human: Shelf = get_node_or_null("ShelfHuman") as Shelf
@onready var shelf_ghost: Shelf = get_node_or_null("ShelfGhost") as Shelf
@onready var locked_overlay: CanvasItem = get_node_or_null("LockedGhostSection") as CanvasItem
@onready var locked_blocker: Node = get_node_or_null("LockedGhostBlocker")

var _entry_door: String = "storage"
var _mystery_phase_unlocked: bool = false
var _mystery_discovered: bool = false
var _mystery_supply_depleted: bool = false
var _human_shelf_installed: bool = false
var _ghost_shelf_installed: bool = false
var _normal_supply_depleted: bool = false
var _player: Node2D = null
var _carried_object: Node2D = null


func _ready() -> void:
	add_to_group("location")
	add_to_group("storage")

	_resize_background_to_viewport()
	_connect_signals()
	_setup_shelves()
	_apply_normal_box_state()
	_apply_mystery_phase_state(false)


func _process(_delta: float) -> void:
	_find_player_if_needed()
	_update_player_depth_override()
	_update_carried_object_position()
	_handle_carry_input()


func set_entry_door(door_type: String) -> void:
	_entry_door = door_type


func set_shelf_install_state(human_installed: bool, ghost_installed: bool) -> void:
	_human_shelf_installed = human_installed
	_ghost_shelf_installed = ghost_installed
	_apply_shelf_install_state()


func set_normal_supply_depleted(is_depleted: bool) -> void:
	_normal_supply_depleted = is_depleted
	_apply_normal_box_state()


func set_locked_half_unlocked(is_unlocked: bool) -> void:
	set_mystery_phase_unlocked(is_unlocked)


func set_mystery_phase_unlocked(is_unlocked: bool) -> void:
	_mystery_phase_unlocked = is_unlocked
	_apply_mystery_phase_state(true)


func set_mystery_discovered(is_discovered: bool) -> void:
	_mystery_discovered = is_discovered

	if mystery_box != null and _mystery_discovered and mystery_box.has_method("mark_discovered"):
		mystery_box.mark_discovered()


func set_mystery_supply_depleted(is_depleted: bool) -> void:
	_mystery_supply_depleted = is_depleted
	_apply_mystery_box_item_state()


func unlock_locked_half() -> void:
	set_mystery_phase_unlocked(true)


func unlock_mystery_phase() -> void:
	set_mystery_phase_unlocked(true)


func get_player_spawn_position() -> Vector2:
	if player_spawn != null:
		return player_spawn.global_position

	return Vector2(42, 68)


func _connect_signals() -> void:
	if return_door == null:
		push_error("Storage: ReturnDoor is missing.")
		return

	return_door.set_meta("door_type", "storage_return")

	if mystery_box != null and not mystery_box.discovered.is_connected(_on_mystery_box_discovered):
		mystery_box.discovered.connect(_on_mystery_box_discovered)

	if mystery_box != null and not mystery_box.item_taken.is_connected(_on_mystery_box_item_taken):
		mystery_box.item_taken.connect(_on_mystery_box_item_taken)

	if shelf_ghost != null and not shelf_ghost.item_placed.is_connected(_on_ghost_shelf_item_placed):
		shelf_ghost.item_placed.connect(_on_ghost_shelf_item_placed)


func request_return_to_store() -> bool:
	if _is_action_locked():
		return false

	return_to_store.emit(_entry_door)
	return true


func _resize_background_to_viewport() -> void:
	if background == null:
		return

	background.position = Vector2.ZERO
	background.size = get_viewport_rect().size


func _setup_shelves() -> void:
	for shelf in [shelf_human, shelf_ghost]:
		if shelf == null:
			continue

		shelf.remove_from_group("shelves")
		shelf.set_meta("is_installed_in_store", false)
		shelf.set_meta("is_carried_storage_object", false)
		shelf.set_meta("is_carryable_storage_object", true)

	_apply_shelf_install_state()


func _apply_shelf_install_state() -> void:
	if shelf_human != null and _human_shelf_installed:
		shelf_human.queue_free()
		shelf_human = null

	if shelf_ghost != null and _ghost_shelf_installed:
		shelf_ghost.queue_free()
		shelf_ghost = null


func _apply_normal_box_state() -> void:
	if normal_box == null:
		return

	normal_box.visible = true
	_set_node_enabled_recursive(normal_box, true)

	if _normal_supply_depleted and normal_box.has_method("mark_all_taken_without_inventory"):
		normal_box.mark_all_taken_without_inventory()


func _apply_mystery_phase_state(animated: bool) -> void:
	var is_open := _mystery_phase_unlocked

	if mystery_box != null:
		mystery_box.visible = is_open
		_set_node_enabled_recursive(mystery_box, is_open)

		if is_open:
			if _mystery_discovered and mystery_box.has_method("mark_discovered"):
				mystery_box.mark_discovered()
			else:
				mystery_box.unlock_mystery()

			_apply_mystery_box_item_state()

	if shelf_ghost != null:
		shelf_ghost.visible = is_open
		_set_node_enabled_recursive(shelf_ghost, is_open)
		shelf_ghost.set_meta("is_carryable_storage_object", is_open)

		if is_open:
			shelf_ghost.apply_ghost_glow(true)

	_set_node_enabled_recursive(locked_blocker, not is_open)

	if locked_overlay == null:
		return

	if is_open and animated:
		locked_overlay.visible = true
		locked_overlay.modulate.a = 0.78

		var tween := create_tween()
		tween.tween_property(locked_overlay, "modulate:a", 0.0, 0.45)
		await tween.finished

		locked_overlay.visible = false
	elif is_open:
		locked_overlay.visible = false
		locked_overlay.modulate.a = 0.0
	else:
		locked_overlay.visible = true
		locked_overlay.modulate.a = 0.78


func _handle_carry_input() -> void:
	if _is_action_locked():
		return

	if not InputMap.has_action(put_action):
		return

	if not Input.is_action_just_pressed(put_action):
		return

	if _player == null:
		return

	if _carried_object != null:
		_drop_carried_object()


func _find_player_if_needed() -> void:
	if _player != null and is_instance_valid(_player):
		return

	for node in get_tree().get_nodes_in_group("player"):
		if node is Node2D:
			_player = node as Node2D
			return


func _update_player_depth_override() -> void:
	if _player == null:
		return

	var is_behind_depth_object: bool = (
		_is_player_behind_depth_object(normal_box, SUPPLY_BOX_DEPTH_HALF_WIDTH, SUPPLY_BOX_DEPTH_BACK_OFFSET, SUPPLY_BOX_DEPTH_FRONT_OFFSET)
		or _is_player_behind_depth_object(mystery_box, SUPPLY_BOX_DEPTH_HALF_WIDTH, SUPPLY_BOX_DEPTH_BACK_OFFSET, SUPPLY_BOX_DEPTH_FRONT_OFFSET)
		or _is_player_behind_depth_object(shelf_human, SHELF_DEPTH_HALF_WIDTH, SHELF_DEPTH_BACK_OFFSET, SHELF_DEPTH_FRONT_OFFSET)
		or _is_player_behind_depth_object(shelf_ghost, SHELF_DEPTH_HALF_WIDTH, SHELF_DEPTH_BACK_OFFSET, SHELF_DEPTH_FRONT_OFFSET)
	)

	_player.z_index = -1 if is_behind_depth_object else 0


func _is_player_behind_depth_object(
	object: Node2D,
	half_width: float,
	back_offset: float,
	front_offset: float
) -> bool:
	if _player == null or object == null or not is_instance_valid(object):
		return false

	if not object.visible:
		return false

	if object.has_meta("is_carried_storage_object") and bool(object.get_meta("is_carried_storage_object")):
		return false

	var player_pos: Vector2 = _player.global_position
	var object_pos: Vector2 = object.global_position
	var overlaps_x: bool = abs(player_pos.x - object_pos.x) <= half_width
	var overlaps_y: bool = (
		player_pos.y >= object_pos.y - back_offset
		and player_pos.y <= object_pos.y + front_offset
	)

	return overlaps_x and overlaps_y and player_pos.y < object_pos.y


func _get_nearest_carryable_shelf() -> Node2D:
	if _player == null:
		return null

	var nearest_object: Node2D = null
	var nearest_distance := pickup_distance

	for shelf in [shelf_human, shelf_ghost]:
		if not shelf is Node2D:
			continue

		var object := shelf as Node2D

		if not object.visible:
			continue

		if object.has_meta("is_carryable_storage_object") and not bool(object.get_meta("is_carryable_storage_object")):
			continue

		if object.has_meta("is_carried_storage_object") and bool(object.get_meta("is_carried_storage_object")):
			continue

		var distance := _player.global_position.distance_to(object.global_position)

		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_object = object

	return nearest_object


func _pickup_object(object: Node2D) -> void:
	if _player == null:
		return

	_carried_object = object
	object.reparent(_player, true)
	object.position = carry_offset
	object.z_index = 80
	object.visible = true
	object.set_meta("is_carried_storage_object", true)
	object.set_meta("is_installed_in_store", false)
	_set_node_enabled_recursive(object, false)


func request_pickup_shelf(shelf: Shelf) -> bool:
	_find_player_if_needed()

	if _player == null:
		return false

	if _carried_object != null:
		return false

	if shelf == null or not (shelf in [shelf_human, shelf_ghost]):
		return false

	if not shelf.visible:
		return false

	if shelf.has_meta("is_carryable_storage_object") and not bool(shelf.get_meta("is_carryable_storage_object")):
		return false

	if _player.global_position.distance_to(shelf.global_position) > pickup_distance:
		return false

	_pickup_object(shelf)
	_show_notification("Shelf picked up. Press Q to place it.")
	return true


func request_drop_carried_object() -> bool:
	_find_player_if_needed()

	if _player == null or _carried_object == null:
		return false

	_drop_carried_object()
	return true


func _drop_carried_object() -> void:
	if _player == null or _carried_object == null:
		return

	var drop_position := _find_safe_drop_position(_carried_object)

	if drop_position == Vector2.INF:
		_show_notification("No room to put the shelf here.", 0.5)
		return

	var object := _carried_object
	object.reparent(self, true)
	object.global_position = drop_position
	object.z_index = 0
	object.set_meta("is_carried_storage_object", false)
	object.set_meta("is_installed_in_store", false)
	_set_node_enabled_recursive(object, true)

	_carried_object = null


func _update_carried_object_position() -> void:
	if _player == null:
		return

	if _carried_object == null:
		_carried_object = _get_carried_object_from_player()

	if _carried_object != null and _carried_object.get_parent() == _player:
		_carried_object.position = carry_offset


func _get_carried_object_from_player() -> Node2D:
	if _player == null:
		return null

	for child in _player.get_children():
		if child is Node2D and child.has_meta("is_carried_storage_object"):
			if bool(child.get_meta("is_carried_storage_object")):
				return child as Node2D

	return null


func _find_safe_drop_position(object: Node2D) -> Vector2:
	for candidate in _get_drop_candidates():
		if _is_drop_position_clear(object, candidate):
			return candidate

	return Vector2.INF


func _get_drop_candidates() -> Array[Vector2]:
	var candidates: Array[Vector2] = []
	var base_position := _player.global_position
	var facing := _get_player_facing_direction()

	candidates.append(base_position + facing * 56.0)

	for offset in SHELF_DROP_FALLBACKS:
		var candidate := base_position + offset

		if candidate not in candidates:
			candidates.append(candidate)

	var legacy_candidate := base_position + drop_offset

	if legacy_candidate not in candidates:
		candidates.append(legacy_candidate)

	return candidates


func _get_player_facing_direction() -> Vector2:
	var facing: Variant = _player.get("facing_direction") if _player != null else Vector2.DOWN

	if facing is Vector2 and not facing.is_zero_approx():
		return (facing as Vector2).normalized()

	return Vector2.DOWN


func _is_drop_position_clear(object: Node2D, candidate: Vector2) -> bool:
	var collision_shape := _get_object_collision_shape(object)

	if collision_shape == null or collision_shape.shape == null:
		return true

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = Transform2D(0.0, candidate + collision_shape.position)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hits := get_world_2d().direct_space_state.intersect_shape(query, 16)

	for hit in hits:
		var collider: Node = hit.get("collider", null)

		if collider == null:
			continue

		if collider == object or _is_descendant_of(collider, object):
			continue

		return false

	return true


func _get_object_collision_shape(object: Node2D) -> CollisionShape2D:
	if object == null:
		return null

	return object.get_node_or_null("PhysicsBody/CollisionShape2D") as CollisionShape2D


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node

	while current != null:
		if current == ancestor:
			return true

		current = current.get_parent()

	return false


func _set_node_enabled_recursive(node: Node, enabled: bool) -> void:
	if node == null:
		return

	if node is Area2D:
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
		_set_node_enabled_recursive(child, enabled)


func _on_mystery_box_discovered() -> void:
	_mystery_discovered = true
	mystery_discovered.emit()


func _on_mystery_box_item_taken(_item_id: String) -> void:
	_mystery_supply_depleted = true
	mystery_item_taken.emit()


func _on_ghost_shelf_item_placed(slot_index: int, item_id: String) -> void:
	ghost_shelf_item_placed.emit(slot_index, item_id)


func _apply_mystery_box_item_state() -> void:
	if mystery_box == null:
		return

	if not _mystery_supply_depleted:
		return

	if mystery_box.has_method("mark_all_taken_without_inventory"):
		mystery_box.mark_all_taken_without_inventory()


func _is_action_locked() -> bool:
	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud == null or not hud.has_method("is_action_locked"):
		return false

	return bool(hud.call("is_action_locked"))


func _show_notification(text: String, duration: float = 2.0) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, duration)
