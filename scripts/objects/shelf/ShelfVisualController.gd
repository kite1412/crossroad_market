class_name ShelfVisualController
extends RefCounted

var shelf: Shelf = null


func setup(shelf_node: Shelf) -> void:
	shelf = shelf_node


func apply_shelf_color() -> void:
	if shelf.shelf_type == ItemData.ShelfType.HUMAN:
		apply_visual_tint(Color(0.7, 0.5, 0.3, 1.0))
	else:
		apply_visual_tint(Color(0.15, 0.1, 0.25, 0.7))


func apply_ghost_glow(enabled: bool) -> void:
	if enabled:
		apply_visual_tint(Color(0.5, 0.35, 0.9, 1.0))
	else:
		apply_visual_tint(Color(0.15, 0.1, 0.25, 0.7))


func apply_visual_tint(color: Color) -> void:
	var color_rect := shelf.get_node_or_null("VisualRoot/PlaceholderRect") as ColorRect

	if color_rect != null:
		color_rect.color = color
		return

	var visual := shelf.get_node_or_null("VisualRoot/AssetSprite") as CanvasItem

	if visual != null:
		visual.modulate = color


func refresh_slot_visual(_slot_index: int, _item_id: String) -> void:
	refresh_all_slot_visuals()


func refresh_all_slot_visuals() -> void:
	var shown_item_ids: Dictionary = {}

	for current_slot_index in shelf.max_slots:
		var slot := shelf.get_node_or_null("Slots/Slot%d" % current_slot_index) as Node2D
		if slot == null:
			continue

		var slot_item_id := shelf.get_slot_content(current_slot_index)
		var item_sprite := _get_or_create_item_sprite(slot)
		var item: ItemData = ItemDatabase.get_item(slot_item_id) if slot_item_id != "" else null
		var icon := item.get_icon() if item != null else null
		var is_first_visible_copy := icon != null and not shown_item_ids.has(slot_item_id)

		item_sprite.texture = icon
		item_sprite.visible = is_first_visible_copy

		if is_first_visible_copy:
			shown_item_ids[slot_item_id] = true


func _get_or_create_item_sprite(slot: Node2D) -> Sprite2D:
	var item_sprite := slot.get_node_or_null("ItemSprite") as Sprite2D
	if item_sprite != null:
		return item_sprite

	item_sprite = Sprite2D.new()
	item_sprite.scale = Vector2(0.5, 0.5)
	item_sprite.name = "ItemSprite"
	item_sprite.z_index = 1
	var collision_shape := slot.get_node_or_null("CollisionShape2D") as CollisionShape2D
	item_sprite.position = collision_shape.position if collision_shape != null else Vector2.ZERO
	slot.add_child(item_sprite)
	return item_sprite
