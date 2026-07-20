class_name PersistentStorage
extends "res://scripts/locations/Storage.gd"

const STORED_IN_STORAGE_META: StringName = &"stored_in_storage"
const STORAGE_POSITION_META: StringName = &"stored_storage_position"
const STORAGE_SHELF_KIND_META: StringName = &"stored_shelf_kind"
const STORAGE_REGISTRY_META: StringName = &"is_storage_shelf_registry"
const REGISTRY_NAME: StringName = &"PersistedStorageShelves"
const HUMAN_KIND: StringName = &"human"
const GHOST_KIND: StringName = &"ghost"
const HUMAN_SHELF_NAME: StringName = &"ShelfHuman"
const GHOST_SHELF_NAME: StringName = &"ShelfGhost"


func _ready() -> void:
	super._ready()
	_restore_persisted_store_shelves()
	# The base ready pass connects before restored shelf references exist.
	_connect_signals()


func register_shelf_dropped_in_storage(shelf: Shelf) -> void:
	if not is_instance_valid(shelf):
		return

	var kind := _get_shelf_kind(shelf)
	if kind == StringName():
		return

	shelf.set_meta(STORED_IN_STORAGE_META, true)
	shelf.set_meta(STORAGE_SHELF_KIND_META, kind)
	shelf.set_meta(STORAGE_POSITION_META, shelf.global_position)
	shelf.set_meta("is_carried_storage_object", false)
	shelf.set_meta("is_installed_in_store", false)
	_assign_storage_reference(kind, shelf)
	_assign_store_reference(_get_store(), kind, shelf, false)


func register_shelf_picked_up_from_storage(shelf: Shelf) -> void:
	if not is_instance_valid(shelf):
		return

	var kind := _get_shelf_kind(shelf)
	if kind == StringName():
		return

	shelf.set_meta(STORED_IN_STORAGE_META, false)
	shelf.set_meta(STORAGE_SHELF_KIND_META, kind)
	_assign_storage_reference(kind, shelf)
	_assign_store_reference(_get_store(), kind, shelf, false)


func is_managed_storage_shelf(shelf: Shelf) -> bool:
	if not is_instance_valid(shelf):
		return false
	if _player != null and _is_descendant_of(shelf, _player):
		return false
	return _is_descendant_of(shelf, self)


func prepare_for_scene_exit() -> void:
	var store := _get_store()
	if store == null:
		return

	var shelves: Array[Shelf] = []
	_collect_storage_shelves(self, shelves)
	for shelf in shelves:
		if not is_instance_valid(shelf):
			continue
		if _player != null and _is_descendant_of(shelf, _player):
			continue
		if bool(shelf.get_meta("is_carried_storage_object", false)):
			continue
		_park_storage_shelf(store, shelf)


func _restore_persisted_store_shelves() -> void:
	var store := _get_store()
	if store == null:
		return

	var human := _find_persisted_shelf(store, HUMAN_KIND)
	if is_instance_valid(human):
		_restore_shelf_to_storage(store, human, HUMAN_KIND)

	var ghost := _find_persisted_shelf(store, GHOST_KIND)
	if is_instance_valid(ghost):
		_restore_shelf_to_storage(store, ghost, GHOST_KIND)


func _find_persisted_shelf(store: Node, kind: StringName) -> Shelf:
	var property_name := &"human_shelf" if kind == HUMAN_KIND else &"ghost_shelf"
	var shelf_variant: Variant = store.get(property_name)

	# A freed Object cannot be used as the left operand of `is`. Validate first,
	# then inspect its type. Clear stale Store references immediately.
	if is_instance_valid(shelf_variant):
		if shelf_variant is Shelf:
			var referenced_shelf := shelf_variant as Shelf
			if _is_persisted_kind(referenced_shelf, kind):
				return referenced_shelf
	else:
		store.set(property_name, null)

	var registry := _get_or_create_registry(store)
	for child in registry.get_children():
		if not is_instance_valid(child):
			continue
		if child is Shelf:
			var registry_shelf := child as Shelf
			if _is_persisted_kind(registry_shelf, kind):
				return registry_shelf

	# Migration fallback for shelves parked directly under Store by PR #28.
	for child in store.get_children():
		if not is_instance_valid(child) or not (child is Shelf):
			continue
		var legacy_shelf := child as Shelf
		if _is_persisted_kind(legacy_shelf, kind):
			return legacy_shelf

	return null


func _is_persisted_kind(shelf: Shelf, kind: StringName) -> bool:
	if not is_instance_valid(shelf):
		return false
	if not bool(shelf.get_meta(STORED_IN_STORAGE_META, false)):
		return false
	if bool(shelf.get_meta("is_carried_storage_object", false)):
		return false
	if bool(shelf.get_meta("is_installed_in_store", false)):
		return false

	var stored_kind := StringName(str(shelf.get_meta(STORAGE_SHELF_KIND_META, "")))
	if stored_kind == StringName():
		stored_kind = _get_shelf_kind(shelf)
	return stored_kind == kind


func _restore_shelf_to_storage(
	store: Node,
	shelf: Shelf,
	kind: StringName
) -> void:
	if not is_instance_valid(shelf):
		return

	var placeholder := _get_storage_reference(kind)
	if is_instance_valid(placeholder) and placeholder != shelf:
		placeholder.free()

	var shelf_root := get_node_or_null("StorageShelves")
	if shelf_root == null:
		shelf_root = self

	var saved_position := shelf.global_position
	var saved_variant: Variant = shelf.get_meta(STORAGE_POSITION_META, saved_position)
	if saved_variant is Vector2:
		saved_position = saved_variant as Vector2

	shelf.reparent(shelf_root, true)
	shelf.name = _get_canonical_name(kind)
	shelf.global_position = saved_position
	shelf.z_index = 0
	shelf.visible = true
	shelf.set_meta(STORED_IN_STORAGE_META, true)
	shelf.set_meta(STORAGE_SHELF_KIND_META, kind)
	shelf.set_meta("is_carried_storage_object", false)
	shelf.set_meta("is_installed_in_store", false)
	shelf.set_meta("is_carryable_storage_object", true)
	shelf.remove_from_group("shelves")
	_set_node_enabled_recursive(shelf, true)
	_assign_storage_reference(kind, shelf)
	_assign_store_reference(store, kind, shelf, false)


func _park_storage_shelf(store: Node, shelf: Shelf) -> void:
	if not is_instance_valid(shelf):
		return

	var kind := _get_shelf_kind(shelf)
	if kind == StringName():
		return

	var registry := _get_or_create_registry(store)
	shelf.set_meta(STORAGE_POSITION_META, shelf.global_position)
	shelf.set_meta(STORED_IN_STORAGE_META, true)
	shelf.set_meta(STORAGE_SHELF_KIND_META, kind)
	shelf.set_meta("is_carried_storage_object", false)
	shelf.set_meta("is_installed_in_store", false)
	shelf.remove_from_group("shelves")
	shelf.reparent(registry, true)
	shelf.name = _get_canonical_name(kind)
	shelf.visible = false
	shelf.z_index = 0
	_set_node_enabled_recursive(shelf, false)
	_assign_store_reference(store, kind, shelf, false)


func _get_or_create_registry(store: Node) -> Node2D:
	var existing := store.get_node_or_null(String(REGISTRY_NAME)) as Node2D
	if existing != null:
		return existing

	var registry := Node2D.new()
	registry.name = REGISTRY_NAME
	registry.visible = false
	registry.set_meta(STORAGE_REGISTRY_META, true)
	store.add_child(registry)
	return registry


func _collect_storage_shelves(node: Node, result: Array[Shelf]) -> void:
	for child in node.get_children():
		if not is_instance_valid(child):
			continue
		if child is Shelf:
			var shelf := child as Shelf
			if shelf not in result:
				result.append(shelf)
			continue
		_collect_storage_shelves(child, result)


func _get_shelf_kind(shelf: Shelf) -> StringName:
	if not is_instance_valid(shelf):
		return StringName()
	match shelf.shelf_type:
		ItemData.ShelfType.HUMAN:
			return HUMAN_KIND
		ItemData.ShelfType.GHOST:
			return GHOST_KIND
	return StringName()


func _get_canonical_name(kind: StringName) -> StringName:
	return HUMAN_SHELF_NAME if kind == HUMAN_KIND else GHOST_SHELF_NAME


func _get_storage_reference(kind: StringName) -> Shelf:
	var shelf_variant: Variant = shelf_human if kind == HUMAN_KIND else shelf_ghost
	if is_instance_valid(shelf_variant) and shelf_variant is Shelf:
		return shelf_variant as Shelf
	return null


func _assign_storage_reference(kind: StringName, shelf: Shelf) -> void:
	if kind == HUMAN_KIND:
		shelf_human = shelf
	else:
		shelf_ghost = shelf


func _assign_store_reference(
	store: Node,
	kind: StringName,
	shelf: Shelf,
	installed: bool
) -> void:
	if store == null:
		return
	if kind == HUMAN_KIND:
		store.set("human_shelf", shelf)
		store.set("_human_shelf_installed", installed)
	else:
		store.set("ghost_shelf", shelf)
		store.set("_ghost_shelf_installed", installed)


func _get_store() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("store")


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false
