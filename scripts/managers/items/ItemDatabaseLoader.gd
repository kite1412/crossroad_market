class_name ItemDatabaseLoader
extends RefCounted

var database: Node = null


func setup(database_node: Node) -> void:
	database = database_node


func load_items() -> void:
	var dir := DirAccess.open("res://data/items")
	if dir == null:
		push_error("ItemDatabase: folder data/items/ not found")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var path := "res://data/items/" + file_name
			var item := load(path) as ItemData
			if item and item.item_id != "":
				database._items[item.item_id] = item
			else:
				push_warning("ItemDatabase: skip file %s (empty item_id or not ItemData)" % file_name)
		file_name = dir.get_next()


func get_item(item_id: String) -> ItemData:
	return database._items.get(item_id, null)


func get_all_items() -> Array[ItemData]:
	return database._items.values()


func get_items_by_shelf(shelf_type: ItemData.ShelfType) -> Array[ItemData]:
	return database._items.values().filter(func(item): return item.shelf_type == shelf_type)
