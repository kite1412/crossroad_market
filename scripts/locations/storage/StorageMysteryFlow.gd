class_name StorageMysteryFlow
extends Node

const STORED_IN_STORAGE_META: StringName = &"stored_in_storage"

var storage: Node = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(storage_node: Node) -> void:
	storage = storage_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_shelf_install_state(human_installed: bool, ghost_installed: bool) -> void:
	storage._human_shelf_installed = human_installed
	storage._ghost_shelf_installed = ghost_installed
	apply_shelf_install_state()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_normal_supply_depleted(is_depleted: bool) -> void:
	storage._normal_supply_depleted = is_depleted
	apply_normal_box_state()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_locked_half_unlocked(is_unlocked: bool) -> void:
	set_mystery_phase_unlocked(is_unlocked)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_mystery_phase_unlocked(is_unlocked: bool) -> void:
	storage._mystery_phase_unlocked = is_unlocked
	apply_mystery_phase_state(true)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_mystery_discovered(is_discovered: bool) -> void:
	storage._mystery_discovered = is_discovered

	if storage.mystery_box != null and storage._mystery_discovered and storage.mystery_box.has_method("mark_discovered"):
		storage.mystery_box.mark_discovered()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_mystery_supply_depleted(is_depleted: bool) -> void:
	storage._mystery_supply_depleted = is_depleted
	apply_mystery_box_item_state()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func set_mystery_items_taken(item_ids: Array[String]) -> void:
	if storage.mystery_box == null:
		return

	for item_id in item_ids:
		if storage.mystery_box.has_method("mark_item_taken_without_inventory"):
			storage.mystery_box.mark_item_taken_without_inventory(item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func unlock_locked_half() -> void:
	set_mystery_phase_unlocked(true)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func unlock_mystery_phase() -> void:
	set_mystery_phase_unlocked(true)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup_shelves() -> void:
	for shelf_variant in [storage.shelf_human, storage.shelf_ghost]:
		if not is_instance_valid(shelf_variant):
			continue
		if not (shelf_variant is Shelf):
			continue

		var shelf := shelf_variant as Shelf
		shelf.remove_from_group("shelves")
		shelf.set_meta("is_installed_in_store", false)
		shelf.set_meta("is_carried_storage_object", false)
		shelf.set_meta("is_carryable_storage_object", true)

	apply_shelf_install_state()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_shelf_install_state() -> void:
	# Only scene placeholders should be removed when a matching shelf is installed
	# in Store. A restored shelf carries stored_in_storage=true and must survive
	# even if an older install flag was temporarily stale.
	if _should_remove_placeholder(storage.shelf_human, storage._human_shelf_installed):
		storage.shelf_human.free()
		storage.shelf_human = null
	elif not is_instance_valid(storage.shelf_human):
		storage.shelf_human = null

	if _should_remove_placeholder(storage.shelf_ghost, storage._ghost_shelf_installed):
		storage.shelf_ghost.free()
		storage.shelf_ghost = null
	elif not is_instance_valid(storage.shelf_ghost):
		storage.shelf_ghost = null


func _should_remove_placeholder(shelf_variant: Variant, installed: bool) -> bool:
	if not installed:
		return false
	if not is_instance_valid(shelf_variant):
		return false
	if not (shelf_variant is Shelf):
		return false

	var shelf := shelf_variant as Shelf
	if bool(shelf.get_meta(STORED_IN_STORAGE_META, false)):
		return false
	if bool(shelf.get_meta("is_carried_storage_object", false)):
		return false
	return true


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_normal_box_state() -> void:
	if storage.normal_box == null:
		return

	storage.normal_box.visible = true
	storage._set_node_enabled_recursive(storage.normal_box, true)

	if storage._normal_supply_depleted and storage.normal_box.has_method("mark_all_taken_without_inventory"):
		storage.normal_box.mark_all_taken_without_inventory()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_mystery_phase_state(animated: bool) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var is_open: bool = storage._mystery_phase_unlocked

	if storage.mystery_box != null:
		storage.mystery_box.visible = is_open
		storage._set_node_enabled_recursive(storage.mystery_box, is_open)

		if is_open:
			if storage._mystery_discovered and storage.mystery_box.has_method("mark_discovered"):
				storage.mystery_box.mark_discovered()
			else:
				storage.mystery_box.unlock_mystery()
			apply_mystery_box_item_state()

	var ghost_variant: Variant = storage.shelf_ghost
	if is_instance_valid(ghost_variant) and ghost_variant is Shelf:
		var ghost_shelf := ghost_variant as Shelf
		ghost_shelf.visible = is_open
		storage._set_node_enabled_recursive(ghost_shelf, is_open)
		ghost_shelf.set_meta("is_carryable_storage_object", is_open)

		if is_open:
			ghost_shelf.apply_ghost_glow(true)

	storage._set_node_enabled_recursive(storage.locked_blocker, not is_open)

	if storage.locked_overlay == null:
		return

	if is_open and animated:
		storage.locked_overlay.visible = true
		storage.locked_overlay.modulate.a = 0.78

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var tween := storage.create_tween()
		tween.tween_property(storage.locked_overlay, "modulate:a", 0.0, 0.45)
		await tween.finished

		storage.locked_overlay.visible = false
	elif is_open:
		storage.locked_overlay.visible = false
		storage.locked_overlay.modulate.a = 0.0
	else:
		storage.locked_overlay.visible = true
		storage.locked_overlay.modulate.a = 0.78


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_mystery_box_discovered() -> void:
	storage._mystery_discovered = true
	storage.mystery_discovered.emit()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_mystery_box_item_taken(item_id: String) -> void:
	storage.mystery_item_taken.emit(item_id)

	if storage.mystery_box != null and storage.mystery_box.is_empty():
		storage._mystery_supply_depleted = true
		storage.mystery_supply_depleted.emit()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func on_ghost_shelf_item_placed(slot_index: int, item_id: String) -> void:
	storage.ghost_shelf_item_placed.emit(slot_index, item_id)


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_mystery_box_item_state() -> void:
	if storage.mystery_box == null:
		return

	if not storage._mystery_supply_depleted:
		return

	if storage.mystery_box.has_method("mark_all_taken_without_inventory"):
		storage.mystery_box.mark_all_taken_without_inventory()
