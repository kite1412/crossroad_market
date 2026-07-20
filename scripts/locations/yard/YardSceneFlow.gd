class_name YardSceneFlow
extends Node

var yard: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(yard_node: Node) -> void:
	yard = yard_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func configure_doors() -> void:
	if yard.return_door == null:
		pass
		return

	yard.return_door.set_meta("door_type", "yard_return")

	if yard.home_door == null:
		pass
	else:
		yard.home_door.set_meta("door_type", "home")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_return_to_store() -> bool:
	if is_action_locked():
		return false

	yard.return_to_store.emit("yard")
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_enter_home() -> bool:
	if is_action_locked():
		return false

	yard.enter_home.emit()
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func is_action_locked() -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var hud: Node = yard.get_tree().get_first_node_in_group("hud")

	if hud == null or not hud.has_method("is_action_locked"):
		return false

	return bool(hud.call("is_action_locked"))
