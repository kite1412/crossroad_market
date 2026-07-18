class_name PlayerLocationFlow
extends RefCounted

var player = null


func setup(player_node) -> void:
	player = player_node


func try_storage_door_interaction(area: Area2D) -> bool:
	var door_type: String = player._get_storage_door_type(area)

	if door_type == "":
		return false

	if door_type.ends_with("_return") or door_type == "return":
		return try_location_return()

	if door_type == "home":
		var yard: Node = player.get_tree().get_first_node_in_group("yard")

		if yard == null or not yard.has_method("request_enter_home"):
			return false

		return bool(yard.call("request_enter_home"))

	var store: Node = player.get_tree().get_first_node_in_group("store")

	if store == null:
		return false

	if not store.has_method("request_enter_storage"):
		if door_type != "yard" or not store.has_method("request_enter_yard"):
			return false

	if door_type == "yard" and store.has_method("request_enter_yard"):
		store.call("request_enter_yard", door_type)
		return true

	store.call("request_enter_storage", door_type)
	return true


func try_location_return() -> bool:
	var home: Node = player.get_tree().get_first_node_in_group("home")

	if home != null and home.has_method("request_return_to_yard"):
		return bool(home.call("request_return_to_yard"))

	for group_name in ["storage", "yard"]:
		var location: Node = player.get_tree().get_first_node_in_group(group_name)

		if location != null and location.has_method("request_return_to_store"):
			return bool(location.call("request_return_to_store"))

	return false
