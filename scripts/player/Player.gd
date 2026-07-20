extends CharacterBody2D


@export var speed: float = 120.0
@export var interaction_distance: float = 20.0

@onready var interaction_area: Area2D = $InteractionArea
@onready var sprite_move: AnimatedSprite2D = $VisualRoot/SpriteMove
@onready var sprite_sprint: AnimatedSprite2D = $VisualRoot/SpriteSprint
@onready var sprite_idle: AnimatedSprite2D = $VisualRoot/SpriteIdle
@onready var sprite_action: AnimatedSprite2D = $VisualRoot/SpriteAction
@onready var sprite_action_sprint: AnimatedSprite2D = $VisualRoot/SpriteActionSprint

var facing_direction: Vector2 = Vector2.DOWN
@warning_ignore("unused_private_class_variable")
var _supply_box_cursor: int = 0
@warning_ignore("unused_private_class_variable")
var _wrong_shelf_attempts: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _seen_item_ids: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _seen_guidance_keys: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _move_direction: CharacterSprite.Direction = CharacterSprite.Direction.DOWN
var is_sprinting: bool = false

@warning_ignore("unused_private_class_variable")
var _movement_controller: PlayerMovementController
@warning_ignore("unused_private_class_variable")
var _visual_controller: PlayerVisualController
@warning_ignore("unused_private_class_variable")
var _interaction_flow: PlayerInteractionFlow
@warning_ignore("unused_private_class_variable")
var _location_flow: PlayerLocationFlow
@warning_ignore("unused_private_class_variable")
var _guidance_flow: PlayerGuidanceFlow
@warning_ignore("unused_private_class_variable")
var _shelf_flow: PlayerShelfFlow
@warning_ignore("unused_private_class_variable")
var _supply_flow: PlayerSupplyFlow


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	_setup_player_controllers()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")
	_update_interaction_area_position()
	_visual_controller.initialize()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _physics_process(_delta: float) -> void:
	if _is_action_locked():
		_movement_controller.process_locked_movement()
		_update_character_sprite(Vector2.ZERO)
		update_carried_object_visual()
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var input_dir := _movement_controller.process_movement()
	_update_character_sprite(input_dir)
	update_carried_object_visual()
	_update_interaction_hint()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _unhandled_input(event: InputEvent) -> void:
	if _is_action_locked():
		return

	if event.is_action_pressed("put"):
		_try_put()
		return

	if event.is_action_pressed("interact"):
		_try_interact()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_player_controllers() -> void:
	_movement_controller = PlayerMovementController.new()
	_visual_controller = PlayerVisualController.new()
	_interaction_flow = PlayerInteractionFlow.new()
	_location_flow = PlayerLocationFlow.new()
	_guidance_flow = PlayerGuidanceFlow.new()
	_shelf_flow = PlayerShelfFlow.new()
	_supply_flow = PlayerSupplyFlow.new()

	for controller in [
		_movement_controller,
		_visual_controller,
		_interaction_flow,
		_location_flow,
		_guidance_flow,
		_shelf_flow,
		_supply_flow
	]:
		controller.setup(self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_interaction_area_position() -> void:
	_movement_controller.update_interaction_area_position()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_character_sprite(motion: Vector2) -> void:
	_visual_controller.update_character_sprite(motion)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_active_character_sprite(is_carrying_shelf: bool, is_moving: bool) -> AnimatedSprite2D:
	return _visual_controller.get_active_character_sprite(is_carrying_shelf, is_moving)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _set_character_sprite_visibility(active_sprite: AnimatedSprite2D) -> void:
	_visual_controller.set_character_sprite_visibility(active_sprite)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func update_carried_object_visual(carried_object: Node2D = null) -> void:
	_visual_controller.update_carried_object_visual(carried_object)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_carrying_shelf() -> bool:
	return _visual_controller.is_carrying_shelf()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_direction(motion: Vector2) -> CharacterSprite.Direction:
	return _visual_controller.get_direction(motion)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_carried_object_offset() -> Vector2:
	return _visual_controller.get_carried_object_offset()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_carried_object_z_index() -> int:
	return _visual_controller.get_carried_object_z_index()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _apply_sprite_base_z_indexes() -> void:
	_visual_controller.apply_sprite_base_z_indexes()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _apply_carry_sprite_z_index() -> void:
	_visual_controller.apply_carry_sprite_z_index()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _try_interact() -> void:
	_interaction_flow.try_interact()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_storage_door_type(area: Area2D) -> String:
	return _interaction_flow.get_storage_door_type(area)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_interaction_priority(target: Node) -> int:
	return _interaction_flow.get_interaction_priority(target)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_best_interaction_target(areas: Array[Area2D]) -> Node:
	return _interaction_flow.get_best_interaction_target(areas)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _try_storage_door_interaction(area: Area2D) -> bool:
	return _location_flow.try_storage_door_interaction(area)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _try_location_return() -> bool:
	return _location_flow.try_location_return()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_interaction_hint() -> void:
	_guidance_flow.update_interaction_hint()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _trigger_interaction_guidance(areas: Array[Area2D]) -> void:
	_guidance_flow.trigger_interaction_guidance(areas)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _trigger_shelf_guidance(shelf: Shelf) -> void:
	_guidance_flow.trigger_shelf_guidance(shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_guided_hint_once(key: String, first_time_text: String) -> void:
	_guidance_flow.show_guided_hint_once(key, first_time_text)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_object_prompt_name(target: Node) -> String:
	return _guidance_flow.get_object_prompt_name(target)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _interact_with_npc(npc: NPC) -> void:
	_interaction_flow.interact_with_npc(npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _apply_story_npc_interaction_trust(npc: NPC) -> String:
	return _interaction_flow.apply_story_npc_interaction_trust(npc)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _interact_with_open_close_board(board: OpenCloseBoard) -> void:
	_interaction_flow.interact_with_open_close_board(board)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _interact_with_cashier(cashier: Cashier) -> void:
	_interaction_flow.interact_with_cashier(cashier)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _interact_with_activity_board(activity_board: ActivityBoard) -> void:
	_interaction_flow.interact_with_activity_board(activity_board)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _interact_with_sleep_bed(sleep_bed: SleepBed) -> void:
	_interaction_flow.interact_with_sleep_bed(sleep_bed)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _interact_with_storage_restock_terminal(terminal: StorageRestockTerminal) -> void:
	_interaction_flow.interact_with_storage_restock_terminal(terminal)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _interact_with_restock_package(restock_package: RestockPackage) -> void:
	_interaction_flow.interact_with_restock_package(restock_package)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _interact_with_shelf(shelf: Shelf) -> void:
	_shelf_flow.interact_with_shelf(shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _try_put() -> void:
	_shelf_flow.try_put()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _put_item_on_shelf(shelf: Shelf) -> void:
	_shelf_flow.put_item_on_shelf(shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_best_shelf_target() -> Shelf:
	return _shelf_flow.get_best_shelf_target()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _take_item_from_shelf(shelf: Shelf) -> void:
	_shelf_flow.take_item_from_shelf(shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _handle_wrong_shelf_attempt(item_id: String, item: ItemData, shelf: Shelf) -> void:
	await _shelf_flow.handle_wrong_shelf_attempt(item_id, item, shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_shelf_full(shelf: Shelf) -> bool:
	return _shelf_flow.is_shelf_full(shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_shelf_type_label(shelf_type: ItemData.ShelfType) -> String:
	return _shelf_flow.get_shelf_type_label(shelf_type)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_wrong_shelf_key(item_id: String, shelf: Shelf) -> String:
	return _shelf_flow.get_wrong_shelf_key(item_id, shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_shelf_installed_in_store(shelf: Shelf) -> bool:
	return _shelf_flow.is_shelf_installed_in_store(shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_carried_shelf() -> Shelf:
	return _shelf_flow.get_carried_shelf()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_carried_object() -> Node2D:
	return _shelf_flow.get_carried_object()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _try_pickup_shelf(shelf: Shelf) -> bool:
	return _shelf_flow.try_pickup_shelf(shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _try_drop_carried_object() -> bool:
	return _shelf_flow.try_drop_carried_object()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _interact_with_supply_box(box: SupplyBox) -> void:
	_supply_flow.interact_with_supply_box(box)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_supply_box_shelf_ready(available_items: Array) -> bool:
	return _supply_flow.is_supply_box_shelf_ready(available_items)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _has_installed_shelf_type(shelf_type: int) -> bool:
	return _supply_flow.has_installed_shelf_type(shelf_type)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _notify_mystery_taken() -> void:
	_supply_flow.notify_mystery_taken()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_pickup_notification(item_id: String, item: ItemData) -> void:
	_supply_flow.show_pickup_notification(item_id, item)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_notification(text: String, duration: float = 2.0) -> void:
	PlayerNotificationBridge.show(get_tree(), text, duration)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_notification_sequence(messages: Array[String]) -> void:
	await PlayerNotificationBridge.show_sequence(self, messages)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_action_locked() -> bool:
	return PlayerNotificationBridge.is_action_locked(get_tree())
