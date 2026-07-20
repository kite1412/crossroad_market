class_name Home
extends Node2D

@warning_ignore("unused_signal")
signal return_to_yard(door_type: String)

@onready var return_door: Area2D = get_node_or_null("ReturnDoor") as Area2D
@onready var scene_flow: Node = get_node_or_null("SceneFlow")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	add_to_group("location")
	add_to_group("home")
	_setup_home_controllers()
	_configure_return_door()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _setup_home_controllers() -> void:
	if scene_flow != null and scene_flow.has_method("setup"):
		scene_flow.call("setup", self)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _configure_return_door() -> void:
	if scene_flow != null:
		scene_flow.configure_return_door()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_return_to_yard() -> bool:
	return scene_flow != null and scene_flow.request_return_to_yard()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _is_action_locked() -> bool:
	return scene_flow != null and scene_flow.is_action_locked()
