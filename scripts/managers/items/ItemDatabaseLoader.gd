class_name ItemDatabaseLoader
extends RefCounted

var database: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(database_node: Node) -> void:
	database = database_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func load_items() -> void:
	_load_items_from_directory("res://data/items")


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _load_items_from_directory(directory_path: String) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var dir := DirAccess.open(directory_path)
	if dir == null:
		pass
		return

	dir.list_dir_begin()
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var file_name := dir.get_next()

	while file_name != "":
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var path := directory_path.path_join(file_name)

		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_load_items_from_directory(path)
		elif file_name.ends_with(".tres"):
			@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
			var item := load(path) as ItemData
			if item and item.item_id != "":
				database._items[item.item_id] = item
			else:
				pass
		file_name = dir.get_next()

	dir.list_dir_end()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_item(item_id: String) -> ItemData:
	return database._items.get(item_id, null)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_all_items() -> Array[ItemData]:
	return database._items.values()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func get_items_by_shelf(shelf_type: ItemData.ShelfType) -> Array[ItemData]:
	return database._items.values().filter(func(item): return item.shelf_type == shelf_type)
