class_name StorageSceneFlow
extends Node

var storage: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(storage_node: Node) -> void:
	storage = storage_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_entry_door(door_type: String) -> void:
	storage._entry_door = door_type


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_player_spawn_position() -> Vector2:
	if storage.player_spawn != null:
		return storage.player_spawn.global_position

	return Vector2(42, 68)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func connect_signals() -> void:
	if storage.return_door == null:
		pass
		return

	storage.return_door.set_meta("door_type", "storage_return")

	if storage.mystery_box != null and not storage.mystery_box.discovered.is_connected(storage._on_mystery_box_discovered):
		storage.mystery_box.discovered.connect(storage._on_mystery_box_discovered)

	if storage.mystery_box != null and not storage.mystery_box.item_taken.is_connected(storage._on_mystery_box_item_taken):
		storage.mystery_box.item_taken.connect(storage._on_mystery_box_item_taken)

	if storage.shelf_ghost != null and not storage.shelf_ghost.item_placed.is_connected(storage._on_ghost_shelf_item_placed):
		storage.shelf_ghost.item_placed.connect(storage._on_ghost_shelf_item_placed)

	if storage.restock_terminal != null:
		storage.restock_terminal.input_pickable = true

	if not EconomyManager.gold_changed.is_connected(storage._on_gold_changed):
		EconomyManager.gold_changed.connect(storage._on_gold_changed)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func request_return_to_store() -> bool:
	if storage._is_action_locked():
		return false

	# Storage is instantiated temporarily and is queue_freed after returning to
	# the Store. Move any shelf returned from the Store to its persistent Store
	# owner before the temporary scene emits its return signal.
	if storage.has_method("prepare_for_scene_exit"):
		storage.call("prepare_for_scene_exit")

	storage.return_to_store.emit(storage._entry_door)
	return true
