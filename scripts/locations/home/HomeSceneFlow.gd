class_name HomeSceneFlow
extends Node

var home: Node = null


func setup(home_node: Node) -> void:
	home = home_node


func configure_return_door() -> void:
	if home.return_door == null:
		push_error("Home: ReturnDoor is missing.")
		return

	home.return_door.set_meta("door_type", "home_return")


func request_return_to_yard() -> bool:
	if is_action_locked():
		return false

	home.return_to_yard.emit("home")
	return true


func is_action_locked() -> bool:
	var hud: Node = home.get_tree().get_first_node_in_group("hud")

	if hud == null or not hud.has_method("is_action_locked"):
		return false

	return bool(hud.call("is_action_locked"))
