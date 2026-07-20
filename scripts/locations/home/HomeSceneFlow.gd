class_name HomeSceneFlow
extends Node

var home: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(home_node: Node) -> void:
	home = home_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func configure_return_door() -> void:
	if home.return_door == null:
		pass
		return

	home.return_door.set_meta("door_type", "home_return")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_return_to_yard() -> bool:
	if is_action_locked():
		return false

	home.return_to_yard.emit("home")
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_action_locked() -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud: Node = home.get_tree().get_first_node_in_group("hud")

	if hud == null or not hud.has_method("is_action_locked"):
		return false

	return bool(hud.call("is_action_locked"))
