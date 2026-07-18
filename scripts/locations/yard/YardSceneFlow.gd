class_name YardSceneFlow
extends Node

var yard: Node = null


func setup(yard_node: Node) -> void:
	yard = yard_node


func configure_doors() -> void:
	if yard.return_door == null:
		push_error("Yard: ReturnDoor is missing.")
		return

	yard.return_door.set_meta("door_type", "yard_return")

	if yard.home_door == null:
		push_error("Yard: HomeDoor is missing.")
	else:
		yard.home_door.set_meta("door_type", "home")


func request_return_to_store() -> bool:
	if is_action_locked():
		return false

	yard.return_to_store.emit("yard")
	return true


func request_enter_home() -> bool:
	if is_action_locked():
		return false

	yard.enter_home.emit()
	return true


func is_action_locked() -> bool:
	var hud: Node = yard.get_tree().get_first_node_in_group("hud")

	if hud == null or not hud.has_method("is_action_locked"):
		return false

	return bool(hud.call("is_action_locked"))
