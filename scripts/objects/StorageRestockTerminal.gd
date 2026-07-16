class_name StorageRestockTerminal
extends Area2D


func _ready() -> void:
	input_pickable = true


func get_hover_display_name() -> String:
	return "Storage Restock Terminal"


func request_interaction() -> bool:
	var storage := get_tree().get_first_node_in_group("storage")

	if storage == null or not storage.has_method("open_restock_panel"):
		return false

	storage.call("open_restock_panel")
	return true
