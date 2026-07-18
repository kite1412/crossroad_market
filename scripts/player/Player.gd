extends CharacterBody2D

const PlayerMovementController = preload("res://scripts/player/PlayerMovementController.gd")
const PlayerVisualController = preload("res://scripts/player/PlayerVisualController.gd")
const PlayerInteractionFlow = preload("res://scripts/player/PlayerInteractionFlow.gd")
const PlayerLocationFlow = preload("res://scripts/player/PlayerLocationFlow.gd")
const PlayerGuidanceFlow = preload("res://scripts/player/PlayerGuidanceFlow.gd")
const PlayerShelfFlow = preload("res://scripts/player/PlayerShelfFlow.gd")
const PlayerSupplyFlow = preload("res://scripts/player/PlayerSupplyFlow.gd")
const PlayerNotificationBridge = preload("res://scripts/player/PlayerNotificationBridge.gd")

@export var speed: float = 150.0
@export var interaction_distance: float = 20.0

@onready var interaction_area: Area2D = $InteractionArea
@onready var sprite_move: AnimatedSprite2D = $VisualRoot/SpriteMove
@onready var sprite_idle: AnimatedSprite2D = $VisualRoot/SpriteIdle
@onready var sprite_action: AnimatedSprite2D = $VisualRoot/SpriteAction

var facing_direction: Vector2 = Vector2.DOWN
var _supply_box_cursor: int = 0
var _wrong_shelf_attempts: Dictionary = {}
var _seen_item_ids: Dictionary = {}
var _seen_guidance_keys: Dictionary = {}
var _move_direction: CharacterSprite.Direction = CharacterSprite.Direction.DOWN

var _movement_controller: PlayerMovementController
var _visual_controller: PlayerVisualController
var _interaction_flow: PlayerInteractionFlow
var _location_flow: PlayerLocationFlow
var _guidance_flow: PlayerGuidanceFlow
var _shelf_flow: PlayerShelfFlow
var _supply_flow: PlayerSupplyFlow


func _ready() -> void:
	_setup_player_controllers()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")
	_update_interaction_area_position()
	_visual_controller.initialize()


func _physics_process(_delta: float) -> void:
	if _is_action_locked():
		_movement_controller.process_locked_movement()
		_update_character_sprite(Vector2.ZERO)
		update_carried_object_visual()
		return

	var input_dir := _movement_controller.process_movement()
	_update_character_sprite(input_dir)
	update_carried_object_visual()
	_update_interaction_hint()


func _unhandled_input(event: InputEvent) -> void:
	if _is_action_locked():
		return

	if event.is_action_pressed("put"):
		_try_put()
		return

	if event.is_action_pressed("interact"):
		_try_interact()


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


func _update_interaction_area_position() -> void:
	_movement_controller.update_interaction_area_position()


func _update_character_sprite(motion: Vector2) -> void:
	_visual_controller.update_character_sprite(motion)


func _get_active_character_sprite(is_carrying_shelf: bool, is_moving: bool) -> AnimatedSprite2D:
	return _visual_controller.get_active_character_sprite(is_carrying_shelf, is_moving)


func _set_character_sprite_visibility(active_sprite: AnimatedSprite2D) -> void:
	_visual_controller.set_character_sprite_visibility(active_sprite)


func update_carried_object_visual(carried_object: Node2D = null) -> void:
	_visual_controller.update_carried_object_visual(carried_object)


func _is_carrying_shelf() -> bool:
	return _visual_controller.is_carrying_shelf()


func _get_direction(motion: Vector2) -> CharacterSprite.Direction:
	return _visual_controller.get_direction(motion)


func _get_carried_object_offset() -> Vector2:
	return _visual_controller.get_carried_object_offset()


func _get_carried_object_z_index() -> int:
	return _visual_controller.get_carried_object_z_index()


func _apply_sprite_base_z_indexes() -> void:
	_visual_controller.apply_sprite_base_z_indexes()


func _apply_carry_sprite_z_index() -> void:
	_visual_controller.apply_carry_sprite_z_index()


func _try_interact() -> void:
	_interaction_flow.try_interact()


func _get_storage_door_type(area: Area2D) -> String:
	return _interaction_flow.get_storage_door_type(area)


func _get_interaction_priority(target: Node) -> int:
	return _interaction_flow.get_interaction_priority(target)


func _get_best_interaction_target(areas: Array[Area2D]) -> Node:
	return _interaction_flow.get_best_interaction_target(areas)


func _try_storage_door_interaction(area: Area2D) -> bool:
	return _location_flow.try_storage_door_interaction(area)


func _try_location_return() -> bool:
	return _location_flow.try_location_return()


func _update_interaction_hint() -> void:
	_guidance_flow.update_interaction_hint()


func _trigger_interaction_guidance(areas: Array[Area2D]) -> void:
	_guidance_flow.trigger_interaction_guidance(areas)


func _trigger_shelf_guidance(shelf: Shelf) -> void:
	_guidance_flow.trigger_shelf_guidance(shelf)


func _show_guided_hint_once(key: String, first_time_text: String) -> void:
	_guidance_flow.show_guided_hint_once(key, first_time_text)


func _get_object_prompt_name(target: Node) -> String:
	return _guidance_flow.get_object_prompt_name(target)


func _interact_with_npc(npc: NPC) -> void:
	_interaction_flow.interact_with_npc(npc)


func _apply_story_npc_interaction_trust(npc: NPC) -> String:
	return _interaction_flow.apply_story_npc_interaction_trust(npc)


func _interact_with_open_close_board(board: OpenCloseBoard) -> void:
	_interaction_flow.interact_with_open_close_board(board)


func _interact_with_cashier(cashier: Cashier) -> void:
	_interaction_flow.interact_with_cashier(cashier)


func _interact_with_activity_board(activity_board: ActivityBoard) -> void:
	_interaction_flow.interact_with_activity_board(activity_board)


func _interact_with_sleep_bed(sleep_bed: SleepBed) -> void:
	_interaction_flow.interact_with_sleep_bed(sleep_bed)


func _interact_with_storage_restock_terminal(terminal: StorageRestockTerminal) -> void:
	_interaction_flow.interact_with_storage_restock_terminal(terminal)


func _interact_with_restock_package(restock_package: RestockPackage) -> void:
	_interaction_flow.interact_with_restock_package(restock_package)


func _interact_with_shelf(shelf: Shelf) -> void:
	_shelf_flow.interact_with_shelf(shelf)


func _try_put() -> void:
	_shelf_flow.try_put()


func _put_item_on_shelf(shelf: Shelf) -> void:
	_shelf_flow.put_item_on_shelf(shelf)


func _get_best_shelf_target() -> Shelf:
	return _shelf_flow.get_best_shelf_target()


func _take_item_from_shelf(shelf: Shelf) -> void:
	_shelf_flow.take_item_from_shelf(shelf)


func _handle_wrong_shelf_attempt(item_id: String, item: ItemData, shelf: Shelf) -> void:
	await _shelf_flow.handle_wrong_shelf_attempt(item_id, item, shelf)


func _is_shelf_full(shelf: Shelf) -> bool:
	return _shelf_flow.is_shelf_full(shelf)


func _get_shelf_type_label(shelf_type: ItemData.ShelfType) -> String:
	return _shelf_flow.get_shelf_type_label(shelf_type)


func _get_wrong_shelf_key(item_id: String, shelf: Shelf) -> String:
	return _shelf_flow.get_wrong_shelf_key(item_id, shelf)


func _is_shelf_installed_in_store(shelf: Shelf) -> bool:
	return _shelf_flow.is_shelf_installed_in_store(shelf)


func _get_carried_shelf() -> Shelf:
	return _shelf_flow.get_carried_shelf()


func _get_carried_object() -> Node2D:
	return _shelf_flow.get_carried_object()


func _try_pickup_shelf(shelf: Shelf) -> bool:
	return _shelf_flow.try_pickup_shelf(shelf)


func _try_drop_carried_object() -> bool:
	return _shelf_flow.try_drop_carried_object()


func _interact_with_supply_box(box: SupplyBox) -> void:
	_supply_flow.interact_with_supply_box(box)


func _is_supply_box_shelf_ready(available_items: Array) -> bool:
	return _supply_flow.is_supply_box_shelf_ready(available_items)


func _has_installed_shelf_type(shelf_type: int) -> bool:
	return _supply_flow.has_installed_shelf_type(shelf_type)


func _notify_mystery_taken() -> void:
	_supply_flow.notify_mystery_taken()


func _show_pickup_notification(item_id: String, item: ItemData) -> void:
	_supply_flow.show_pickup_notification(item_id, item)


func _show_notification(text: String, duration: float = 2.0) -> void:
	PlayerNotificationBridge.show(get_tree(), text, duration)


func _show_notification_sequence(messages: Array[String]) -> void:
	await PlayerNotificationBridge.show_sequence(self, messages)


func _is_action_locked() -> bool:
	return PlayerNotificationBridge.is_action_locked(get_tree())
