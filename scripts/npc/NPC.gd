class_name NPC
extends CharacterBody2D

const NPCStateFlowScript = preload("res://scripts/npc/runtime/NPCStateFlow.gd")
const NPCRouteControllerScript = preload("res://scripts/npc/runtime/NPCRouteController.gd")
const NPCShoppingFlowScript = preload("res://scripts/npc/runtime/NPCShoppingFlow.gd")
const NPCQueueFlowScript = preload("res://scripts/npc/runtime/NPCQueueFlow.gd")
const NPCCheckoutFlowScript = preload("res://scripts/npc/runtime/NPCCheckoutFlow.gd")
const NPCPresentationRuntimeScript = preload("res://scripts/npc/runtime/NPCPresentationRuntime.gd")
const NPCAssetRuntimeScript = preload("res://scripts/npc/runtime/NPCAssetRuntime.gd")
const NPCMetadataFlowScript = preload("res://scripts/npc/runtime/NPCMetadataFlow.gd")

enum State {
	ENTER,
	WALK_TO_SHELF,
	SEARCH_ITEM,
	BROWSE_ITEM,
	TAKE_ITEM,
	WAIT_IN_QUEUE,
	CHECKOUT,
	EXIT
}

const SPEED: float = 80.0
const ARRIVAL_THRESHOLD: float = 5.0
const ENTER_PAUSE: float = 0.5
const DEBUG_ENTER_TIMING: bool = false
const DIALOG_DURATION: float = 2.5
const CHECKOUT_PATIENCE: float = 20.0
const SEARCH_PATIENCE: float = 15.0
const SHELF_SEARCH_MIN_TIME: float = 1.0
const SHELF_TAKE_PAUSE_TIME: float = 1.25
const SHELF_VISIT_OFFSET: Vector2 = Vector2(0, 34)
const SHELF_ACTION_DISTANCE: float = 12.0
const SHELF_VISIT_ARRIVAL_DISTANCE: float = 8.0
const QUEUE_ACTION_DISTANCE: float = 8.0
const DEBUG_QUEUE_TARGET: bool = false
const STUCK_WATCHDOG_SECONDS: float = 1.5
const STUCK_MIN_MOVE_DISTANCE: float = 1.0
const STUCK_WATCHDOG_MAX_REBUILDS: int = 2

static var current_queue: Array[NPC] = []
static var counter_position: Vector2 = Vector2.ZERO
static var entrance_position: Vector2 = Vector2.ZERO
static var exit_position: Vector2 = Vector2.ZERO
static var store_path_position: Vector2 = Vector2.INF

signal purchase_completed(npc: NPC, item_id: String, price: int)
signal npc_exited(npc: NPC)

var npc_data: NPCData
var current_state: State = State.ENTER
var target_position: Vector2 = Vector2.ZERO
var item_to_buy: String = ""
var item_to_buy_original: String = ""
var queue_position: int = 0
var shopping_list: Array[String] = []
var checkout_total_override: int = -1
var checkout_outcome: String = "paid"

var _browse_item: String = ""
var _cart_items: Array[String] = []
var _enter_pause_timer: float = 0.0
var _dialog_timer: float = 0.0
var _checkout_timer: float = 0.0
var _search_timer: float = 0.0
var _search_announced: bool = false
var _take_item_pause_timer: float = 0.0
var _has_taken_shelf_item: bool = false
var _trust_label: Label = null
var _movement_route: Array[Vector2] = []
var _movement_route_destination: Vector2 = Vector2.INF
var _target_shelf: Shelf = null
var _last_queue_index: int = -1
var _last_watchdog_position: Vector2 = Vector2.INF
var _stuck_watchdog_timer: float = 0.0
var _stuck_watchdog_rebuilds: int = 0
var _exit_completed: bool = false

var _state_flow = null
var _route_controller = null
var _shopping_flow = null
var _queue_flow = null
var _checkout_flow = null
var _presentation_runtime = null
var _asset_runtime = null
var _metadata_flow = null

@onready var sprite_move: CharacterSprite = $VisualRoot/SpriteMove
@onready var sprite_idle: CharacterSprite = $VisualRoot/SpriteIdle

var _move_direction: CharacterSprite.Direction = CharacterSprite.Direction.DOWN


func _ready() -> void:
	_ensure_npc_controllers()
	add_to_group("npcs")
	add_to_group("dialog_skip_target")
	_trust_label = get_node_or_null("TrustLabel") as Label
	_update_trust_display()
	_set_dialog_mouse_filter()
	_update_character_sprite()


func _exit_tree() -> void:
	_ensure_npc_controllers()
	_disconnect_trust_signal()
	_leave_queue()


func setup(data: NPCData) -> void:
	_ensure_npc_controllers()
	npc_data = data
	_load_character_assets()
	_apply_scripted_metadata()
	_choose_item_to_buy()
	item_to_buy_original = item_to_buy
	_apply_name_label()
	_apply_visual()
	_setup_trust_display()
	_set_state(State.ENTER)


func _physics_process(delta: float) -> void:
	_ensure_npc_controllers()

	match current_state:
		State.ENTER:
			_process_enter()
		State.WALK_TO_SHELF:
			_process_walk_to_shelf()
		State.SEARCH_ITEM:
			_process_search_item(delta)
		State.BROWSE_ITEM:
			_process_browse_item(delta)
		State.TAKE_ITEM:
			_process_take_item()
		State.WAIT_IN_QUEUE:
			_process_wait_in_queue(delta)
		State.CHECKOUT:
			_process_checkout(delta)
		State.EXIT:
			_process_exit()

	if is_queued_for_deletion():
		return

	_update_stuck_watchdog(delta)
	_update_dialog(delta)
	_update_character_sprite()


func _ensure_npc_controllers() -> void:
	if _state_flow != null:
		return

	_state_flow = NPCStateFlowScript.new()
	_route_controller = NPCRouteControllerScript.new()
	_shopping_flow = NPCShoppingFlowScript.new()
	_queue_flow = NPCQueueFlowScript.new()
	_checkout_flow = NPCCheckoutFlowScript.new()
	_presentation_runtime = NPCPresentationRuntimeScript.new()
	_asset_runtime = NPCAssetRuntimeScript.new()
	_metadata_flow = NPCMetadataFlowScript.new()

	for controller in [
		_state_flow,
		_route_controller,
		_shopping_flow,
		_queue_flow,
		_checkout_flow,
		_presentation_runtime,
		_asset_runtime,
		_metadata_flow
	]:
		controller.setup(self)


func complete_checkout() -> void:
	_ensure_npc_controllers()
	_checkout_flow.complete_checkout()


func complete_story_gift(dialog_text: String = "Thank you...") -> void:
	_ensure_npc_controllers()
	_checkout_flow.complete_story_gift(dialog_text)


func reject_checkout_and_return_items(dialog_text: String = "Boo...") -> void:
	_ensure_npc_controllers()
	_checkout_flow.reject_checkout_and_return_items(dialog_text)


func get_checkout_total() -> int:
	_ensure_npc_controllers()
	return _checkout_flow.get_checkout_total()


func get_checkout_item_label() -> String:
	_ensure_npc_controllers()
	return _checkout_flow.get_checkout_item_label()


func get_cart_item_ids() -> Array[String]:
	_ensure_npc_controllers()
	return _checkout_flow.get_cart_item_ids()


func repeat_checkout_request() -> void:
	_ensure_npc_controllers()
	_checkout_flow.repeat_checkout_request()


func skip_dialog() -> bool:
	_ensure_npc_controllers()
	return _presentation_runtime.skip_dialog()


func cancel_checkout_and_leave() -> void:
	_ensure_npc_controllers()
	_checkout_flow.cancel_checkout_and_leave()


func queue_done() -> void:
	queue_free()


func is_ready_for_checkout_service() -> bool:
	_ensure_npc_controllers()
	return _queue_flow.is_ready_for_checkout_service()


func mark_checkout_ready() -> void:
	_ensure_npc_controllers()
	_queue_flow.mark_checkout_ready()


func _apply_name_label() -> void:
	_presentation_runtime.apply_name_label()


func _apply_visual() -> void:
	_presentation_runtime.apply_visual()


func _setup_trust_display() -> void:
	_presentation_runtime.setup_trust_display()


func _disconnect_trust_signal() -> void:
	_presentation_runtime.disconnect_trust_signal()


func _should_show_trust_display() -> bool:
	return _presentation_runtime.should_show_trust_display()


func _update_trust_display() -> void:
	_ensure_npc_controllers()
	_presentation_runtime.update_trust_display()


func _on_trust_changed(npc_id: String, _new_trust: int, _delta: int) -> void:
	_presentation_runtime.on_trust_changed(npc_id, _new_trust, _delta)


func _process_enter() -> void:
	_state_flow.process_enter()


func _print_enter_timing(choose_duration_usec: int, shelf_duration_usec: int, route_duration_usec: int) -> void:
	_state_flow.print_enter_timing(choose_duration_usec, shelf_duration_usec, route_duration_usec)


func _process_walk_to_shelf() -> void:
	_state_flow.process_walk_to_shelf()


func _process_search_item(delta: float) -> void:
	_state_flow.process_search_item(delta)


func _process_browse_item(delta: float) -> void:
	_state_flow.process_browse_item(delta)


func _process_take_item() -> void:
	_state_flow.process_take_item()


func _process_wait_in_queue(delta: float) -> void:
	_queue_flow.process_wait_in_queue(delta)


func _process_checkout(delta: float) -> void:
	_state_flow.process_checkout(delta)


func _process_exit() -> void:
	_state_flow.process_exit()


func _complete_exit() -> void:
	_state_flow.complete_exit()


func _finish_checkout_and_exit() -> void:
	_state_flow.finish_checkout_and_exit()


func _set_state(new_state: State) -> void:
	_state_flow.set_state(new_state)


func _move_to(target: Vector2) -> bool:
	return _route_controller.move_to(target)


func _update_stuck_watchdog(delta: float) -> void:
	_route_controller.update_stuck_watchdog(delta)


func _is_movement_state() -> bool:
	return _route_controller.is_movement_state()


func _reset_stuck_watchdog() -> void:
	_route_controller.reset_stuck_watchdog()


func _should_rebuild_movement_route(target: Vector2) -> bool:
	return _route_controller.should_rebuild_movement_route(target)


func _build_movement_route(destination: Vector2) -> Array[Vector2]:
	return _route_controller.build_movement_route(destination)


func _get_store_route_for_current_state(destination: Vector2) -> Array[Vector2]:
	return _route_controller.get_store_route_for_current_state(destination)


func _get_store_route_provider() -> Node:
	return _route_controller.get_store_route_provider()


func _call_store_route(store: Node, method_name: StringName, args: Array) -> Array[Vector2]:
	return _route_controller.call_store_route(store, method_name, args)


func _append_destination_to_route(route: Array[Vector2], destination: Vector2) -> Array[Vector2]:
	return _route_controller.append_destination_to_route(route, destination)


func _make_orthogonal_route(from_pos: Vector2, to_pos: Vector2, horizontal_first: bool = true) -> Array[Vector2]:
	return _route_controller.make_orthogonal_route(from_pos, to_pos, horizontal_first)


func _dedupe_route_points(route: Array[Vector2]) -> Array[Vector2]:
	return _route_controller.dedupe_route_points(route)


func _should_use_store_path(destination: Vector2, path_position: Vector2) -> bool:
	return _route_controller.should_use_store_path(destination, path_position)


func _is_valid_route_point(point: Vector2) -> bool:
	return _route_controller.is_valid_route_point(point)


func _is_near_cashier_area() -> bool:
	return _route_controller.is_near_cashier_area()


func _get_store_path_position() -> Vector2:
	return _route_controller.get_store_path_position()


func _get_exit_position() -> Vector2:
	return _route_controller.get_exit_position()


func _choose_item_to_buy() -> void:
	_shopping_flow.choose_item_to_buy()


func _choose_available_item_to_buy() -> void:
	_shopping_flow.choose_available_item_to_buy()


func _find_alternative_item() -> String:
	return _shopping_flow.find_alternative_item()


func _set_requested_item(item_id: String) -> void:
	_shopping_flow.set_requested_item(item_id)


func _can_substitute_available_stock() -> bool:
	return _shopping_flow.can_substitute_available_stock()


func _find_available_stock_substitute() -> String:
	return _shopping_flow.find_available_stock_substitute()


func _return_item_to_shelf() -> void:
	_shopping_flow.return_item_to_shelf()


func _find_matching_shelf() -> Shelf:
	return _shopping_flow.find_matching_shelf()


func _find_reachable_matching_shelf() -> Shelf:
	return _shopping_flow.find_reachable_matching_shelf()


func _get_matching_shelf_candidates() -> Array[Shelf]:
	return _shopping_flow.get_matching_shelf_candidates()


func _find_shelf_with_item(item_id: String) -> Shelf:
	return _shopping_flow.find_shelf_with_item(item_id)


func _get_shelf_visit_position(shelf: Shelf) -> Vector2:
	return _shopping_flow.get_shelf_visit_position(shelf)


func _refresh_shelf_visit_target() -> bool:
	return _shopping_flow.refresh_shelf_visit_target()


func _has_any_requested_item_available() -> bool:
	return _shopping_flow.has_any_requested_item_available()


func _take_requested_items_from_shelves() -> bool:
	return _shopping_flow.take_requested_items_from_shelves()


func _get_requested_items() -> Array[String]:
	return _shopping_flow.get_requested_items()


func _return_cart_items_to_shelf() -> void:
	_shopping_flow.return_cart_items_to_shelf()


func _join_queue() -> void:
	_queue_flow.join_queue()


func _leave_queue() -> void:
	_queue_flow.leave_queue()


func _enter_checkout_queue() -> void:
	_queue_flow.enter_checkout_queue()


func _get_queue_target() -> Vector2:
	return _queue_flow.get_queue_target()


func _print_queue_target_debug(queue_index: int) -> void:
	_queue_flow.print_queue_target_debug(queue_index)


func _apply_scripted_metadata() -> void:
	_metadata_flow.apply_scripted_metadata()


func _update_character_sprite() -> void:
	_presentation_runtime.update_character_sprite()


func _get_direction(motion: Vector2) -> CharacterSprite.Direction:
	return _presentation_runtime.get_direction(motion)


func _face_target_shelf() -> void:
	_presentation_runtime.face_target_shelf()


func _load_character_assets() -> void:
	_asset_runtime.load_character_assets()


func _load_directional_textures(assets_path: String) -> Dictionary:
	return _asset_runtime.load_directional_textures(assets_path)


func _create_character_sprite_config(textures: Dictionary, row: int, frames: int, end_column: int) -> AnimatedCharacterSpriteConfig:
	return _asset_runtime.create_character_sprite_config(textures, row, frames, end_column)


func _configure_character_direction(config: AnimatedCharacterSpriteConfig, direction: String, texture: Texture2D, row: int, frames: int, end_column: int) -> void:
	_asset_runtime.configure_character_direction(config, direction, texture, row, frames, end_column)


func _validate_character_sprite(label: String, sprite: CharacterSprite, expected_frames: int) -> void:
	_asset_runtime.validate_character_sprite(label, sprite, expected_frames)


func _get_character_animation_name(direction: CharacterSprite.Direction) -> StringName:
	return _asset_runtime.get_character_animation_name(direction)


func _show_dialog(text: String) -> void:
	_presentation_runtime.show_dialog(text)


func _update_dialog(delta: float) -> void:
	_presentation_runtime.update_dialog(delta)


func _hide_dialog() -> void:
	_presentation_runtime.hide_dialog()


func _set_dialog_mouse_filter() -> void:
	_presentation_runtime.set_dialog_mouse_filter()
