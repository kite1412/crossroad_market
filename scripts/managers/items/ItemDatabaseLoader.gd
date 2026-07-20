class_name ItemDatabaseLoader
extends RefCounted

var database: Node = null


func setup(database_node: Node) -> void:
	database = database_node


func load_items() -> void:
	_load_items_from_directory("res://data/items")


func _load_items_from_directory(directory_path: String) -> void:
	var dir := DirAccess.open(directory_path)
	if dir == null:
		pass
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		var path := directory_path.path_join(file_name)

		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_load_items_from_directory(path)
		elif file_name.ends_with(".tres"):
			var item := load(path) as ItemData
			if item and item.item_id != "":
				database._items[item.item_id] = item
			else:
				pass
		file_name = dir.get_next()

	dir.list_dir_end()


func get_item(item_id: String) -> ItemData:
	return database._items.get(item_id, null)


func get_all_items() -> Array[ItemData]:
	return database._items.values()


func get_items_by_shelf(shelf_type: ItemData.ShelfType) -> Array[ItemData]:
	return database._items.values().filter(func(item): return item.shelf_type == shelf_type)
