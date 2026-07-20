class_name StorageRestockTerminal
extends Area2D


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _ready() -> void:
	input_pickable = true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_hover_display_name() -> String:
	return "Storage Restock Terminal"


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_interaction() -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var storage := get_tree().get_first_node_in_group("storage")

	if storage == null or not storage.has_method("open_restock_panel"):
		return false

	storage.call("open_restock_panel")
	return true
