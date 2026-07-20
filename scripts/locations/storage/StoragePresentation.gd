class_name StoragePresentation
extends Node

const SUPPLY_BOX_DEPTH_HALF_WIDTH: float = 34.0
const SUPPLY_BOX_DEPTH_BACK_OFFSET: float = 48.0
const SUPPLY_BOX_DEPTH_FRONT_OFFSET: float = 8.0

var storage: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(storage_node: Node) -> void:
	storage = storage_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func resize_background_to_viewport() -> void:
	if storage.background == null:
		return

	storage.background.position = Vector2.ZERO
	storage.background.size = storage.get_viewport_rect().size


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func update_player_depth_override() -> void:
	if storage._player == null:
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var is_behind_depth_object: bool = (
		is_player_behind_depth_object(
			storage.normal_box,
			SUPPLY_BOX_DEPTH_HALF_WIDTH,
			SUPPLY_BOX_DEPTH_BACK_OFFSET,
			SUPPLY_BOX_DEPTH_FRONT_OFFSET
		)
		or is_player_behind_depth_object(
			storage.mystery_box,
			SUPPLY_BOX_DEPTH_HALF_WIDTH,
			SUPPLY_BOX_DEPTH_BACK_OFFSET,
			SUPPLY_BOX_DEPTH_FRONT_OFFSET
		)
	)

	storage._player.z_index = -1 if is_behind_depth_object else 0


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_player_behind_depth_object(
	object: Node2D,
	half_width: float,
	back_offset: float,
	front_offset: float
) -> bool:
	if storage._player == null or object == null or not is_instance_valid(object):
		return false

	if not object.visible:
		return false

	if object.has_meta("is_carried_storage_object") and bool(object.get_meta("is_carried_storage_object")):
		return false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var player_pos: Vector2 = storage._player.global_position
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var object_pos: Vector2 = object.global_position
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var overlaps_x: bool = abs(player_pos.x - object_pos.x) <= half_width
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var overlaps_y: bool = (
		player_pos.y >= object_pos.y - back_offset
		and player_pos.y <= object_pos.y + front_offset
	)

	return overlaps_x and overlaps_y and player_pos.y < object_pos.y


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func show_notification(text: String, duration: float = 2.0) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud: Node = storage.get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_notification"):
		hud.call("show_notification", text, duration)
