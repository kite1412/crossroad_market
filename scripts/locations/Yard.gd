class_name Yard
extends Node2D

@warning_ignore("unused_signal")
signal return_to_store(door_type: String)
@warning_ignore("unused_signal")
signal enter_home()
@warning_ignore("unused_signal")
signal restock_delivery_collected(delivery_id: int)

@onready var return_door: Area2D = get_node_or_null("ReturnDoor") as Area2D
@onready var home_door: Area2D = get_node_or_null("YardObjects/PlayerHouse/HomeDoor") as Area2D
@onready var restock_drop_zone: Node2D = get_node_or_null("RestockDropZone") as Node2D
@onready var scene_flow: Node = get_node_or_null("SceneFlow")
@onready var restock_flow: Node = get_node_or_null("RestockFlow")

@warning_ignore("unused_private_class_variable")
var _restock_deliveries: Array[Dictionary] = []


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	add_to_group("location")
	add_to_group("yard")
	_setup_yard_controllers()
	_configure_doors()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_yard_controllers() -> void:
	for controller in [scene_flow, restock_flow]:
		if controller != null and controller.has_method("setup"):
			controller.call("setup", self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _configure_doors() -> void:
	if scene_flow != null:
		scene_flow.configure_doors()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_return_to_store() -> bool:
	return scene_flow != null and scene_flow.request_return_to_store()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_enter_home() -> bool:
	return scene_flow != null and scene_flow.request_enter_home()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_restock_deliveries(deliveries: Array) -> void:
	if restock_flow != null:
		restock_flow.set_restock_deliveries(deliveries)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_action_locked() -> bool:
	return scene_flow != null and scene_flow.is_action_locked()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _refresh_restock_packages() -> void:
	if restock_flow != null:
		restock_flow.refresh_restock_packages()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_restock_drop_markers() -> Array[Marker2D]:
	if restock_flow != null:
		return restock_flow.get_restock_drop_markers()

	return []


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _on_restock_package_collected(delivery_id: int) -> void:
	if restock_flow != null:
		restock_flow.on_restock_package_collected(delivery_id)
