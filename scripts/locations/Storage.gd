class_name Storage
extends Node2D
## Backroom for Day 1 restocking.
## Human and ghost shelves start here. The mystery box is locked behind the
## dark storage section until the human shelf has been installed and stocked.
## The ghost shelf remains gated until the Phantom Ice Cream has been examined,
## taken, and unsuccessfully tried on the human shelf.

@warning_ignore("unused_signal")
signal return_to_store(door_type: String)
@warning_ignore("unused_signal")
signal mystery_discovered()
@warning_ignore("unused_signal")
signal mystery_item_taken(item_id: String)
@warning_ignore("unused_signal")
signal mystery_supply_depleted()
@warning_ignore("unused_signal")
signal ghost_shelf_item_placed(slot_index: int, item_id: String)
@warning_ignore("unused_signal")
signal restock_item_purchased(item_id: String, quantity: int)
@warning_ignore("unused_signal")
signal restock_order_purchased(order_items: Array)
@warning_ignore("unused_signal")
signal restock_panel_opened()
@warning_ignore("unused_signal")
signal restock_panel_closed(had_checkout: bool)

@export var pickup_distance: float = 70.0
@export var carry_offset: Vector2 = Vector2(0, -18)
@export var drop_offset: Vector2 = Vector2(0, 28)
@export var put_action: StringName = &"put"

@onready var return_door: Area2D = get_node_or_null("ReturnDoor") as Area2D
@onready var player_spawn: Marker2D = get_node_or_null("StorageMarkers/PlayerSpawn") as Marker2D
@onready var background: ColorRect = get_node_or_null("StorageRoomShell/Background") as ColorRect
@onready var normal_box: SupplyBox = get_node_or_null("StorageSupplyArea/Normal") as SupplyBox
@onready var mystery_box: MysterySupplyBox = get_node_or_null("StorageSupplyArea/Mystery") as MysterySupplyBox
@onready var shelf_human: Shelf = get_node_or_null("StorageShelves/ShelfHuman") as Shelf
@onready var shelf_ghost: Shelf = get_node_or_null("StorageShelves/ShelfGhost") as Shelf
@onready var locked_overlay: CanvasItem = get_node_or_null("StorageSupplyArea/LockedGhostSection") as CanvasItem
@onready var locked_blocker: Node = get_node_or_null("StorageSupplyArea/LockedGhostBlocker")
@onready var restock_terminal: Area2D = get_node_or_null("RestockTerminal") as Area2D
@onready var scene_flow: Node = get_node_or_null("SceneFlow")
@onready var restock_flow: Node = get_node_or_null("RestockFlow")
@onready var shelf_carry_controller: Node = get_node_or_null("ShelfCarryController")
@onready var mystery_flow: Node = get_node_or_null("MysteryFlow")
@onready var presentation: Node = get_node_or_null("Presentation")

@warning_ignore("unused_private_class_variable")
var _entry_door: String = "storage"
@warning_ignore("unused_private_class_variable")
var _mystery_phase_unlocked: bool = false
@warning_ignore("unused_private_class_variable")
var _mystery_discovered: bool = false
@warning_ignore("unused_private_class_variable")
var _mystery_supply_depleted: bool = false
@warning_ignore("unused_private_class_variable")
var _phantom_human_shelf_attempted: bool = false
@warning_ignore("unused_private_class_variable")
var _human_shelf_installed: bool = false
@warning_ignore("unused_private_class_variable")
var _ghost_shelf_installed: bool = false
@warning_ignore("unused_private_class_variable")
var _normal_supply_depleted: bool = false
@warning_ignore("unused_private_class_variable")
var _player: Node2D = null
@warning_ignore("unused_private_class_variable")
var _carried_object: Node2D = null
@warning_ignore("unused_private_class_variable")
var _restock_layer: CanvasLayer = null
@warning_ignore("unused_private_class_variable")
var _restock_panel: ColorRect = null
@warning_ignore("unused_private_class_variable")
var _restock_item_list: VBoxContainer = null
@warning_ignore("unused_private_class_variable")
var _restock_wallet_label: Label = null
@warning_ignore("unused_private_class_variable")
var _restock_selected_label: Label = null
@warning_ignore("unused_private_class_variable")
var _restock_guide_label: Label = null
@warning_ignore("unused_private_class_variable")
var _restock_action_row: Container = null
@warning_ignore("unused_private_class_variable")
var _selected_restock_item_id: String = ""
@warning_ignore("unused_private_class_variable")
var _restock_cart: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _restock_checkout_completed_this_session: bool = false


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	add_to_group("location")
	add_to_group("storage")

	_setup_storage_controllers()
	_resize_background_to_viewport()
	_connect_signals()
	_setup_shelves()
	_apply_normal_box_state()
	_apply_mystery_phase_state(false)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_storage_controllers() -> void:
	for controller in [
		scene_flow,
		restock_flow,
		shelf_carry_controller,
		mystery_flow,
		presentation
	]:
		if controller != null and controller.has_method("setup"):
			controller.call("setup", self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _process(_delta: float) -> void:
	_find_player_if_needed()
	_update_player_depth_override()
	_update_carried_object_position()
	_handle_carry_input()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_entry_door(door_type: String) -> void:
	if scene_flow != null:
		scene_flow.set_entry_door(door_type)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_shelf_install_state(human_installed: bool, ghost_installed: bool) -> void:
	if mystery_flow != null:
		mystery_flow.set_shelf_install_state(human_installed, ghost_installed)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_normal_supply_depleted(is_depleted: bool) -> void:
	if mystery_flow != null:
		mystery_flow.set_normal_supply_depleted(is_depleted)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_locked_half_unlocked(is_unlocked: bool) -> void:
	if mystery_flow != null:
		mystery_flow.set_locked_half_unlocked(is_unlocked)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_mystery_phase_unlocked(is_unlocked: bool) -> void:
	if mystery_flow != null:
		mystery_flow.set_mystery_phase_unlocked(is_unlocked)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_mystery_discovered(is_discovered: bool) -> void:
	if mystery_flow != null:
		mystery_flow.set_mystery_discovered(is_discovered)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_mystery_supply_depleted(is_depleted: bool) -> void:
	if mystery_flow != null:
		mystery_flow.set_mystery_supply_depleted(is_depleted)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_phantom_human_shelf_attempted(was_attempted: bool) -> void:
	if mystery_flow != null:
		mystery_flow.set_phantom_human_shelf_attempted(was_attempted)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_mystery_items_taken(item_ids: Array[String]) -> void:
	if mystery_flow != null:
		mystery_flow.set_mystery_items_taken(item_ids)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func unlock_locked_half() -> void:
	if mystery_flow != null:
		mystery_flow.unlock_locked_half()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func unlock_mystery_phase() -> void:
	if mystery_flow != null:
		mystery_flow.unlock_mystery_phase()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_player_spawn_position() -> Vector2:
	if scene_flow != null:
		return scene_flow.get_player_spawn_position()

	return Vector2(42, 68)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_return_to_store() -> bool:
	return scene_flow != null and scene_flow.request_return_to_store()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func open_restock_panel() -> void:
	if restock_flow != null:
		restock_flow.open_restock_panel()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_pickup_shelf(shelf: Shelf) -> bool:
	return shelf_carry_controller != null and shelf_carry_controller.request_pickup_shelf(shelf)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_ghost_shelf_story_unlocked() -> bool:
	return (
		mystery_flow != null
		and mystery_flow.is_ghost_shelf_story_unlocked()
	)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_drop_carried_object() -> bool:
	return shelf_carry_controller != null and shelf_carry_controller.request_drop_carried_object()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _connect_signals() -> void:
	if scene_flow != null:
		scene_flow.connect_signals()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _resize_background_to_viewport() -> void:
	if presentation != null:
		presentation.resize_background_to_viewport()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_shelves() -> void:
	if mystery_flow != null:
		mystery_flow.setup_shelves()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _apply_shelf_install_state() -> void:
	if mystery_flow != null:
		mystery_flow.apply_shelf_install_state()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _apply_normal_box_state() -> void:
	if mystery_flow != null:
		mystery_flow.apply_normal_box_state()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _apply_mystery_phase_state(animated: bool) -> void:
	if mystery_flow != null:
		await mystery_flow.apply_mystery_phase_state(animated)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _handle_carry_input() -> void:
	if shelf_carry_controller != null:
		shelf_carry_controller.handle_carry_input()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _find_player_if_needed() -> void:
	if shelf_carry_controller != null:
		shelf_carry_controller.find_player_if_needed()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_player_depth_override() -> void:
	if presentation != null:
		presentation.update_player_depth_override()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_nearest_carryable_shelf() -> Node2D:
	if shelf_carry_controller != null:
		return shelf_carry_controller.get_nearest_carryable_shelf()

	return null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _pickup_object(object: Node2D) -> void:
	if shelf_carry_controller != null:
		shelf_carry_controller.pickup_object(object)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _drop_carried_object() -> void:
	if shelf_carry_controller != null:
		shelf_carry_controller.drop_carried_object()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _update_carried_object_position() -> void:
	if shelf_carry_controller != null:
		shelf_carry_controller.update_carried_object_position()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_carried_object_from_player() -> Node2D:
	if shelf_carry_controller != null:
		return shelf_carry_controller.get_carried_object_from_player()

	return null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _set_node_enabled_recursive(node: Node, enabled: bool) -> void:
	if shelf_carry_controller != null:
		shelf_carry_controller.set_node_enabled_recursive(node, enabled)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_mystery_box_discovered() -> void:
	if mystery_flow != null:
		mystery_flow.on_mystery_box_discovered()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_mystery_box_item_taken(item_id: String) -> void:
	if mystery_flow != null:
		mystery_flow.on_mystery_box_item_taken(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_ghost_shelf_item_placed(slot_index: int, item_id: String) -> void:
	if mystery_flow != null:
		mystery_flow.on_ghost_shelf_item_placed(slot_index, item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _apply_mystery_box_item_state() -> void:
	if mystery_flow != null:
		mystery_flow.apply_mystery_box_item_state()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_gold_changed(_amount: int) -> void:
	if restock_flow != null:
		restock_flow.on_gold_changed(_amount)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_action_locked() -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud: Node = get_tree().get_first_node_in_group("hud")

	if hud == null or not hud.has_method("is_action_locked"):
		return false

	return bool(hud.call("is_action_locked"))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_notification(text: String, duration: float = 2.0) -> void:
	if presentation != null:
		presentation.show_notification(text, duration)
