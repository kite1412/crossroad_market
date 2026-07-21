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

	var body_rect: Rect2 = _get_body_rect()
	var standing_margin: float = 18.0
	var shelf_id: StringName = get_shelf_id()
	var revision: int = get_revision()
	var center: Vector2 = body_rect.get_center()

	return [
		_make_interaction_port(
			&"front",
			Vector2(center.x, body_rect.position.y + body_rect.size.y + standing_margin),
			CharacterSprite.Direction.UP,
			shelf_id,
			revision
		),
		_make_interaction_port(
			&"back",
			Vector2(center.x, body_rect.position.y - standing_margin),
			CharacterSprite.Direction.DOWN,
			shelf_id,
			revision
		),
		_make_interaction_port(
			&"left",
			Vector2(body_rect.position.x - standing_margin, center.y),
			CharacterSprite.Direction.RIGHT,
			shelf_id,
			revision
		),
		_make_interaction_port(
			&"right",
			Vector2(body_rect.position.x + body_rect.size.x + standing_margin, center.y),
			CharacterSprite.Direction.LEFT,
			shelf_id,
			revision
		)
	]


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_interaction_port(port_id: StringName) -> Dictionary:
	for port in get_interaction_ports():
		if StringName(str(port.get("port_id", StringName()))) == port_id:
			return port
	return {}


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_slot_content(slot_index: int) -> String:
	return _stock_controller.get_slot_content(slot_index)


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
		"standing_position": standing_position,
		"facing": facing,
		"enabled": true
	}
