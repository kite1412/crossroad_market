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


func refresh_slot_visual(slot_index: int, item_id: String) -> void:
	var slot := shelf.get_node_or_null("Slots/Slot%d" % slot_index) as Node2D

	if slot == null:
		return

	var item_sprite := slot.get_node_or_null("ItemSprite") as Sprite2D

	if item_sprite == null:
		item_sprite = Sprite2D.new()
		item_sprite.scale = Vector2(0.5, 0.5)
		item_sprite.name = "ItemSprite"
		item_sprite.z_index = 1
		var collision_shape := slot.get_node_or_null("CollisionShape2D") as CollisionShape2D
		item_sprite.position = collision_shape.position if collision_shape != null else Vector2.ZERO
		slot.add_child(item_sprite)

	var item: ItemData = null

	if item_id != "":
		item = ItemDatabase.get_item(item_id)

	item_sprite.texture = item.icon if item != null else null
	item_sprite.visible = item != null and item.icon != null
