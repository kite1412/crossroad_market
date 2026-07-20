class_name MysterySupplyBox
extends SupplyBox


@warning_ignore("unused_signal")
signal discovered()

@export var trigger_area_path: NodePath = NodePath("Area2D")
@export var auto_place_on_ghost_shelf: bool = false

const REQUIRED: int = 4

@warning_ignore("unused_private_class_variable")
var _discovered: bool = false
@warning_ignore("unused_private_class_variable")
var _unlocked: bool = false
@warning_ignore("unused_private_class_variable")
var _items_taken: int = 0
@warning_ignore("unused_private_class_variable")
var _items_placed: int = 0
@warning_ignore("unused_private_class_variable")
var _discovery_running: bool = false
@warning_ignore("unused_private_class_variable")
var _player_inside_trigger: bool = false

@onready var trigger_area: Area2D = get_node_or_null(trigger_area_path) as Area2D

@warning_ignore("unused_private_class_variable")
var _trigger_flow: MysterySupplyTriggerFlow = MysterySupplyTriggerFlow.new()
@warning_ignore("unused_private_class_variable")
var _dialog_flow: MysterySupplyDialogFlow = MysterySupplyDialogFlow.new()
@warning_ignore("unused_private_class_variable")
var _auto_collect_flow: MysterySupplyAutoCollectFlow = MysterySupplyAutoCollectFlow.new()
@warning_ignore("unused_private_class_variable")
var _visual_controller: MysterySupplyVisualController = MysterySupplyVisualController.new()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	super._ready()
	_setup_mystery_controllers()
	_apply_glow(false)
	_trigger_flow.setup_trigger()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_mystery_controllers() -> void:
	_trigger_flow.setup(self)
	_dialog_flow.setup(self)
	_auto_collect_flow.setup(self)
	_visual_controller.setup(self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _process(_delta: float) -> void:
	_trigger_flow.process()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func unlock_mystery() -> void:
	_trigger_flow.unlock_mystery()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func mark_discovered() -> void:
	_trigger_flow.mark_discovered()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_normal_item_taken() -> void:
	_trigger_flow.on_normal_item_taken()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_human_item_placed() -> void:
	_trigger_flow.on_human_item_placed()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_unlocked() -> bool:
	return _trigger_flow.is_unlocked()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_trigger_body_entered(body: Node) -> void:
	_trigger_flow.on_trigger_body_entered(body)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_trigger_body_exited(body: Node) -> void:
	_trigger_flow.on_trigger_body_exited(body)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_trigger_area_entered(area: Area2D) -> void:
	_trigger_flow.on_trigger_area_entered(area)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_trigger_area_exited(area: Area2D) -> void:
	_trigger_flow.on_trigger_area_exited(area)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_player_node(node: Node) -> bool:
	return _trigger_flow.is_player_node(node)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_player_area(area: Area2D) -> bool:
	return _trigger_flow.is_player_area(area)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _refresh_player_inside_trigger() -> void:
	_trigger_flow.refresh_player_inside_trigger()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _try_trigger_discovery() -> void:
	_trigger_flow.try_trigger_discovery()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _trigger_discovery() -> void:
	await _trigger_flow.trigger_discovery()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_discovery_dialog() -> void:
	await _dialog_flow.show_discovery_dialog()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _show_dialog_line(text: String, duration: float) -> void:
	await _dialog_flow.show_dialog_line(text, duration)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_hud() -> Node:
	return _dialog_flow.get_hud()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _find_node_with_method(node: Node, method_name: String) -> Node:
	return _dialog_flow.find_node_with_method(node, method_name)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_available_items() -> Array[String]:
	if not _discovered:
		return []

	if _discovery_running:
		return []

	return super.get_available_items()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func collect_one(item_id: String) -> bool:
	if not _discovered:
		return false

	if _discovery_running:
		return false

	if is_empty():
		return false

	return super.collect_one(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _auto_collect_to_shelf() -> void:
	_auto_collect_flow.auto_collect_to_shelf()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _mark_item_as_taken_without_inventory(item_id: String) -> void:
	_auto_collect_flow.mark_item_as_taken_without_inventory(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_ghost_shelf() -> Shelf:
	return _auto_collect_flow.get_ghost_shelf()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _apply_glow(enabled: bool) -> void:
	_visual_controller.apply_glow(enabled)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _apply_visual_tint(color: Color) -> void:
	_visual_controller.apply_visual_tint(color)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_empty() -> bool:
	if not _discovered:
		return true

	return super.is_empty()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_discovered() -> bool:
	return _discovered


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_discovery_running() -> bool:
	return _discovery_running
