extends Node
## Utility script for handling location transitions
## Handles player movement between different game locations


## Transition to a new location
## [code]location_path[/code] - Path to the location scene to transition to
@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func transition_to(location_path: String) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var scene_loader = Node.new()
	add_child(scene_loader)
	# TODO: Implement actual scene transition logic
	scene_loader.queue_free()


## Get the current location the player is in
@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_current_location() -> Node:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var locations = get_tree().get_nodes_in_group("location")
	if not locations.is_empty():
		return locations[0]
	return null


## Check if player can transition to a specific location
@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func can_transition_to(location_path: String) -> bool:
	# TODO: Implement transition permission logic
	return true
