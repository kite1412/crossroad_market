class_name PlayerShelfInteraction
extends RefCounted


static func get_wrong_shelf_key(item_id: String, shelf: Shelf) -> String:
	return "%s_%s" % [item_id, str(shelf.get_instance_id())]


static func is_shelf_installed_in_store(shelf: Shelf) -> bool:
	if shelf == null:
		return false

	if not shelf.has_meta("is_installed_in_store"):
		return true

	return bool(shelf.get_meta("is_installed_in_store"))


static func is_supply_box_shelf_ready(tree: SceneTree, available_items: Array) -> bool:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var required_shelf_types: Dictionary = {}

	for item_id_variant in available_items:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item := ItemDatabase.get_item(str(item_id_variant))

		if item == null:
			continue

		required_shelf_types[item.shelf_type] = true

	if required_shelf_types.is_empty():
		return true

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var world: Node = tree.get_first_node_in_group("store") if tree != null else null

	if world != null and world.has_method("is_shelf_type_installed"):
		for shelf_type in required_shelf_types.keys():
			if not bool(world.call("is_shelf_type_installed", shelf_type)):
				return false

		return true

	var storage: Node = tree.get_first_node_in_group("storage") if tree != null else null
	if storage != null:
		for shelf_type in required_shelf_types.keys():
			if not _is_storage_shelf_type_installed(storage, int(shelf_type)):
				return false

		return true

	for shelf_type in required_shelf_types.keys():
		if not has_installed_shelf_type(tree, int(shelf_type)):
			return false

	return true


static func has_installed_shelf_type(tree: SceneTree, shelf_type: int) -> bool:
	if tree == null:
		return false

	for node in tree.get_nodes_in_group("shelves"):
		if not node is Shelf:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var shelf := node as Shelf

		if shelf.shelf_type == shelf_type and is_shelf_installed_in_store(shelf):
			return true

	return false


static func _is_storage_shelf_type_installed(
	storage: Node,
	shelf_type: int
) -> bool:
	match shelf_type:
		ItemData.ShelfType.HUMAN:
			return bool(storage.get("_human_shelf_installed"))
		ItemData.ShelfType.GHOST:
			return bool(storage.get("_ghost_shelf_installed"))

	return false
