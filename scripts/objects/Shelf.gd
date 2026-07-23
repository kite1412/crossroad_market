class_name Shelf
extends Node2D


const META_SHELF_ID: StringName = &"shelf_id"
const META_SHELF_REVISION: StringName = &"shelf_revision"
const META_SHELF_LIFECYCLE: StringName = &"shelf_lifecycle"
const LIFECYCLE_PLACED: StringName = &"placed"
const LIFECYCLE_BEING_PICKED_UP: StringName = &"being_picked_up"
const LIFECYCLE_CARRIED: StringName = &"carried"
const LIFECYCLE_BEING_DROPPED: StringName = &"being_dropped"
const LIFECYCLE_DESTROYED: StringName = &"destroyed"
const NPC_APPROACH_PORTS_PATH: NodePath = NodePath("NPCApproachPorts")
const NPC_PORT_ID_META: StringName = &"npc_shelf_port_id"
const NPC_PORT_FACING_META: StringName = &"npc_shelf_port_facing"

@export var shelf_type: ItemData.ShelfType = ItemData.ShelfType.HUMAN
@export var max_slots: int = 9

@warning_ignore("unused_signal")
signal item_placed(slot_index: int, item_id: String)
@warning_ignore("unused_signal")
signal item_removed(slot_index: int, item_id: String)
@warning_ignore("unused_signal")
signal shelf_invalidated(shelf: Shelf, old_revision: int, new_revision: int)
@warning_ignore("unused_signal")
signal shelf_lifecycle_changed(shelf: Shelf, old_lifecycle: StringName, new_lifecycle: StringName)

@warning_ignore("unused_private_class_variable")
var _slots: Array = []
@warning_ignore("unused_private_class_variable")
var _slot_quantities: Array[int] = []
@warning_ignore("unused_private_class_variable")
var _slot_reserved_quantities: Array[int] = []
@warning_ignore("unused_private_class_variable")
var _is_shelf_hovered: bool = false

@warning_ignore("unused_private_class_variable")
var _stock_controller: ShelfStockController = ShelfStockController.new()
@warning_ignore("unused_private_class_variable")
var _visual_controller: ShelfVisualController = ShelfVisualController.new()
@warning_ignore("unused_private_class_variable")
var _hover_controller: ShelfHoverController = ShelfHoverController.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_ensure_shelf_identity()
	_setup_shelf_controllers()
	y_sort_enabled = false
	_stock_controller.initialize_slots()
	_apply_shelf_color()
	_setup_cursor_hover()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_shelf_controllers() -> void:
	_stock_controller.setup(self)
	_visual_controller.setup(self)
	_hover_controller.setup(self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _apply_shelf_color() -> void:
	_visual_controller.apply_shelf_color()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_ghost_glow(enabled: bool) -> void:
	_visual_controller.apply_ghost_glow(enabled)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func place_item(item_id: String) -> int:
	return _stock_controller.place_item(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func stock_item_direct(item_id: String) -> int:
	return _stock_controller.stock_item_direct(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func remove_item(slot_index: int) -> String:
	return _stock_controller.remove_item(slot_index)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func remove_first_item() -> String:
	return _stock_controller.remove_first_item()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func take_item_for_npc(item_id: String) -> bool:
	return _stock_controller.take_item_for_npc(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func reserve_item_for_npc(item_id: String, npc: Node) -> Dictionary:
	return _stock_controller.reserve_item_for_npc(item_id, npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func commit_npc_item_reservation(token: Dictionary, npc: Node) -> Dictionary:
	return _stock_controller.commit_npc_item_reservation(token, npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func cancel_npc_item_reservation(token: Dictionary) -> Dictionary:
	return _stock_controller.cancel_npc_item_reservation(token)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_item(item_id: String) -> bool:
	return _stock_controller.has_item(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func has_stock() -> bool:
	return _stock_controller.has_stock()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_first_stocked_item_id() -> String:
	return _stock_controller.get_first_stocked_item_id()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_shelf_id() -> StringName:
	_ensure_shelf_identity()
	return StringName(str(get_meta(META_SHELF_ID, "")))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_revision() -> int:
	_ensure_shelf_identity()
	return int(get_meta(META_SHELF_REVISION, 0))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_lifecycle() -> StringName:
	_ensure_shelf_identity()
	return StringName(str(get_meta(META_SHELF_LIFECYCLE, LIFECYCLE_PLACED)))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_lifecycle(new_lifecycle: StringName, invalidate: bool = true) -> void:
	_ensure_shelf_identity()
	var old_lifecycle: StringName = get_lifecycle()
	if old_lifecycle == new_lifecycle:
		return

	set_meta(META_SHELF_LIFECYCLE, new_lifecycle)
	if invalidate:
		increment_revision()
	shelf_lifecycle_changed.emit(self, old_lifecycle, new_lifecycle)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func increment_revision() -> int:
	_ensure_shelf_identity()
	var old_revision: int = get_revision()
	var new_revision: int = old_revision + 1
	_stock_controller.cancel_all_npc_item_reservations()
	set_meta(META_SHELF_REVISION, new_revision)
	shelf_invalidated.emit(self, old_revision, new_revision)
	return new_revision


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_interaction_ports() -> Array[Dictionary]:
	_ensure_shelf_identity()
	if get_lifecycle() != LIFECYCLE_PLACED:
		return []

	var marker_ports := _get_marker_interaction_ports()
	if marker_ports.is_empty():
		push_error("Shelf scene missing required NPCApproachPorts markers: %s" % name)
	return marker_ports


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_marker_interaction_ports() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var port_root := get_node_or_null(NPC_APPROACH_PORTS_PATH) as Node2D
	if port_root == null:
		push_error("Shelf scene missing required Node2D: %s/%s" % [name, NPC_APPROACH_PORTS_PATH])
		return result

	var shelf_id: StringName = get_shelf_id()
	var revision: int = get_revision()
	var body_rect := _get_body_rect()
	var required_ports := {
		&"front": false,
		&"back": false,
		&"left": false,
		&"right": false
	}
	for child in port_root.get_children():
		var marker := child as Marker2D
		if marker == null:
			continue

		var port_id := StringName(str(marker.get_meta(
			NPC_PORT_ID_META,
			marker.name
		)))
		if port_id == StringName():
			continue
		if required_ports.has(port_id):
			required_ports[port_id] = true

		var raw_marker_position := marker.global_position
		var standing_position := raw_marker_position
		var port := _make_interaction_port(
			port_id,
			standing_position,
			_get_port_facing(marker),
			shelf_id,
			revision
		)
		port["raw_marker_position"] = raw_marker_position
		port["raw_marker_body_distance"] = _get_body_rect_distance_to(
			body_rect,
			raw_marker_position
		)
		port["port_body_distance"] = _get_body_rect_distance_to(
			body_rect,
			standing_position
		)
		port["fitted_from_marker"] = false
		port["marker_fit_distance"] = 0.0
		result.append(port)

	for port_id in required_ports.keys():
		if not bool(required_ports[port_id]):
			push_error("Shelf scene missing required NPCApproachPorts/%s marker: %s" % [port_id, name])

	return result


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_port_facing(marker: Marker2D) -> CharacterSprite.Direction:
	var facing := str(marker.get_meta(NPC_PORT_FACING_META, "up"))
	match facing:
		"down":
			return CharacterSprite.Direction.DOWN
		"left":
			return CharacterSprite.Direction.LEFT
		"right":
			return CharacterSprite.Direction.RIGHT
		_:
			return CharacterSprite.Direction.UP


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_interaction_port(port_id: StringName) -> Dictionary:
	for port in get_interaction_ports():
		if StringName(str(port.get("port_id", StringName()))) == port_id:
			return port
	return {}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_body_distance_to(point: Vector2) -> float:
	var body_rect := _get_body_rect()
	return _get_body_rect_distance_to(body_rect, point)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_body_rect() -> Rect2:
	return _get_body_rect()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_body_rect_distance_to(body_rect: Rect2, point: Vector2) -> float:
	if not point.is_finite():
		return INF
	if body_rect.has_point(point):
		return 0.0

	var closest_point := Vector2(
		clampf(point.x, body_rect.position.x, body_rect.position.x + body_rect.size.x),
		clampf(point.y, body_rect.position.y, body_rect.position.y + body_rect.size.y)
	)
	return point.distance_to(closest_point)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_slot_content(slot_index: int) -> String:
	return _stock_controller.get_slot_content(slot_index)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_stock_counts() -> Dictionary:
	return _stock_controller.get_stock_counts()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_hover_display_name() -> String:
	match shelf_type:
		ItemData.ShelfType.GHOST:
			return "Ghost Shelf"
		_:
			return "Human Shelf"


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_empty_slot() -> int:
	return _stock_controller.get_empty_slot()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _apply_visual_tint(color: Color) -> void:
	_visual_controller.apply_visual_tint(color)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _refresh_slot_visual(slot_index: int, item_id: String) -> void:
	_visual_controller.refresh_slot_visual(slot_index, item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_cursor_hover() -> void:
	_hover_controller.setup_cursor_hover()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_shelf_mouse_entered() -> void:
	_hover_controller.on_shelf_mouse_entered()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_shelf_mouse_exited() -> void:
	_hover_controller.on_shelf_mouse_exited()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_shelf_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_idx: int
) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if bool(get_meta("is_carried_storage_object", false)):
		return
	if has_meta("is_installed_in_store") and not bool(get_meta("is_installed_in_store")):
		return

	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("_show_shelf_stock_panel"):
		player.call("_show_shelf_stock_panel", self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_slot_mouse_entered(slot_index: int) -> void:
	_hover_controller.on_slot_mouse_entered(slot_index)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_slot_mouse_exited() -> void:
	_hover_controller.on_slot_mouse_exited()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_slot_hover_name(slot_index: int) -> String:
	return _hover_controller.get_slot_hover_name(slot_index)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_cursor_tooltip(text: String) -> void:
	_hover_controller.show_cursor_tooltip(text)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _hide_cursor_tooltip() -> void:
	_hover_controller.hide_cursor_tooltip()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ensure_shelf_identity() -> void:
	if not has_meta(META_SHELF_ID) or str(get_meta(META_SHELF_ID, "")).is_empty():
		var generated_id: StringName = StringName(
			"shelf_%d_%d" % [
				Time.get_ticks_usec(),
				get_instance_id()
			]
		)
		set_meta(META_SHELF_ID, generated_id)

	if not has_meta(META_SHELF_REVISION):
		set_meta(META_SHELF_REVISION, 0)

	if not has_meta(META_SHELF_LIFECYCLE):
		var is_carried: bool = bool(get_meta("is_carried_storage_object", false))
		set_meta(
			META_SHELF_LIFECYCLE,
			LIFECYCLE_CARRIED if is_carried else LIFECYCLE_PLACED
		)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_body_rect() -> Rect2:
	var collision_shape := get_node_or_null("PhysicsBody/CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return Rect2(global_position - Vector2(32, 24), Vector2(64, 48))

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return Rect2(global_position - Vector2(32, 24), Vector2(64, 48))

	var center: Vector2 = global_position + collision_shape.position
	return Rect2(center - rectangle.size * 0.5, rectangle.size)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _make_interaction_port(
	port_id: StringName,
	standing_position: Vector2,
	facing: CharacterSprite.Direction,
	shelf_id: StringName,
	revision: int
) -> Dictionary:
	return {
		"port_id": port_id,
		"shelf_id": shelf_id,
		"shelf_revision": revision,
		"position": standing_position,
		"standing_position": standing_position,
		"facing": facing,
		"enabled": true
	}
