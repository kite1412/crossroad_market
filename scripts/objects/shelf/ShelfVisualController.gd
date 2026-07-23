class_name ShelfVisualController
extends RefCounted

var shelf: Shelf = null


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func setup(shelf_node: Shelf) -> void:
	shelf = shelf_node


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_shelf_color() -> void:
	if shelf.shelf_type == ItemData.ShelfType.HUMAN:
		apply_visual_tint(Color(0.7, 0.5, 0.3, 1.0))
	else:
		apply_visual_tint(Color(0.15, 0.1, 0.25, 0.7))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_ghost_glow(enabled: bool) -> void:
	if enabled:
		apply_visual_tint(Color(0.5, 0.35, 0.9, 1.0))
	else:
		apply_visual_tint(Color(0.15, 0.1, 0.25, 0.7))


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func apply_visual_tint(color: Color) -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var color_rect := shelf.get_node_or_null("VisualRoot/PlaceholderRect") as ColorRect

	if color_rect != null:
		color_rect.color = color
		return

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var visual := shelf.get_node_or_null("VisualRoot/AssetSprite") as CanvasItem

	if visual != null:
		visual.modulate = color


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func refresh_slot_visual(_slot_index: int, _item_id: String) -> void:
	refresh_all_slot_visuals()


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func refresh_all_slot_visuals() -> void:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var shown_item_ids: Dictionary = {}

	# Clear the previous compacted layout first. A visible icon is allowed to
	# move when an earlier stocked item is removed or when a duplicate is added.
	for current_slot_index in shelf.max_slots:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var slot := shelf.get_node_or_null("Slots/Slot%d" % current_slot_index) as Node2D
		if slot == null:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item_sprite := slot.get_node_or_null("ItemSprite") as Sprite2D
		if item_sprite != null:
			item_sprite.texture = null
			item_sprite.visible = false

	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	var display_slot_index := 0

	for current_slot_index in shelf.max_slots:
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var slot_item_id := shelf.get_slot_content(current_slot_index)
		if slot_item_id == "" or shown_item_ids.has(slot_item_id):
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item: ItemData = ItemDatabase.get_item(slot_item_id)
		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var icon := item.get_icon() if item != null else null
		if icon == null or display_slot_index >= shelf.max_slots:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var display_slot := shelf.get_node_or_null("Slots/Slot%d" % display_slot_index) as Node2D
		if display_slot == null:
			continue

		@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
		var item_sprite := _get_item_sprite(display_slot)
		if item_sprite == null:
			push_error("Shelf slot scene missing required Sprite2D node: %s/ItemSprite" % display_slot.get_path())
			continue
		item_sprite.texture = icon
		item_sprite.visible = true
		shown_item_ids[slot_item_id] = true
		display_slot_index += 1


@warning_ignore("unused_parameter", "shadowed_variable", "shadowed_variable_base_class")
func _get_item_sprite(slot: Node2D) -> Sprite2D:
	@warning_ignore("unused_variable", "shadowed_variable", "incompatible_ternary")
	return slot.get_node_or_null("ItemSprite") as Sprite2D
