class_name Shelf
extends Node2D

@export var shelf_type: ItemData.ShelfType = ItemData.ShelfType.HUMAN
@export var max_slots: int = 6

signal item_placed(slot_index: int, item_id: String)
signal item_removed(slot_index: int, item_id: String)

var _slots: Array = []
var _is_shelf_hovered: bool = false

func _ready() -> void:
	y_sort_enabled = true
	_slots.resize(max_slots)
	_slots.fill(null)
	_apply_shelf_color()
	_setup_cursor_hover()

func _apply_shelf_color() -> void:
	if shelf_type == ItemData.ShelfType.HUMAN:
		_apply_visual_tint(Color(0.7, 0.5, 0.3, 1.0))
	else:
		# ghost shelf starts dim, revealed after mystery box discovery
		_apply_visual_tint(Color(0.15, 0.1, 0.25, 0.7))

func apply_ghost_glow(enabled: bool) -> void:
	if enabled:
		_apply_visual_tint(Color(0.5, 0.35, 0.9, 1.0))
	else:
		_apply_visual_tint(Color(0.15, 0.1, 0.25, 0.7))

func place_item(item_id: String) -> int:
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null:
		push_warning("Shelf: item '%s' not found in database" % item_id)
		return -1

	if item.shelf_type != shelf_type:
		return -1

	var slot := _get_empty_slot()
	if slot == -1:
		return -1

	if not Inventory.remove_item(item_id):
		return -1

	_slots[slot] = item_id
	_refresh_slot_visual(slot, item_id)
	item_placed.emit(slot, item_id)
	return slot

func stock_item_direct(item_id: String) -> int:
	var item: ItemData = ItemDatabase.get_item(item_id)
	if item == null:
		push_warning("Shelf: item '%s' not found in database" % item_id)
		return -1

	if item.shelf_type != shelf_type:
		return -1

	var slot := _get_empty_slot()
	if slot == -1:
		return -1

	_slots[slot] = item_id
	_refresh_slot_visual(slot, item_id)
	item_placed.emit(slot, item_id)
	return slot

func remove_item(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= _slots.size():
		return ""

	var item_id: String = _slots[slot_index]
	if item_id == null:
		return ""

	_slots[slot_index] = null
	_refresh_slot_visual(slot_index, "")
	Inventory.add_item(item_id)
	item_removed.emit(slot_index, item_id)
	return item_id

func remove_first_item() -> String:
	for i in _slots.size():
		if _slots[i] != null:
			return remove_item(i)

	return ""

func take_item_for_npc(item_id: String) -> bool:
	for i in _slots.size():
		if _slots[i] == item_id:
			_slots[i] = null
			_refresh_slot_visual(i, "")
			item_removed.emit(i, item_id)
			return true
	return false

func has_item(item_id: String) -> bool:
	return _slots.has(item_id)

func has_stock() -> bool:
	for item_id in _slots:
		if item_id != null:
			return true

	return false

func get_first_stocked_item_id() -> String:
	for item_id in _slots:
		if item_id != null:
			return item_id

	return ""

func get_slot_content(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= _slots.size():
		return ""

	return _slots[slot_index] if _slots[slot_index] != null else ""


func get_hover_display_name() -> String:
	match shelf_type:
		ItemData.ShelfType.GHOST:
			return "Ghost Shelf"
		_:
			return "Human Shelf"


func _get_empty_slot() -> int:
	for i in _slots.size():
		if _slots[i] == null:
			return i
	return -1


func _apply_visual_tint(color: Color) -> void:
	var color_rect := get_node_or_null("VisualRoot/PlaceholderRect") as ColorRect

	if color_rect != null:
		color_rect.color = color
		return

	var visual := get_node_or_null("VisualRoot/AssetSprite") as CanvasItem

	if visual != null:
		visual.modulate = color


func _refresh_slot_visual(slot_index: int, item_id: String) -> void:
	var slot := get_node_or_null("Slots/Slot%d" % slot_index) as Node2D

	if slot == null:
		return

	var item_sprite := slot.get_node_or_null("ItemSprite") as Sprite2D

	if item_sprite == null:
		item_sprite = Sprite2D.new()
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


func _setup_cursor_hover() -> void:
	var interaction_area := get_node_or_null("InteractionArea") as Area2D

	if interaction_area != null:
		interaction_area.input_pickable = true
		var shelf_entered := Callable(self, "_on_shelf_mouse_entered")
		var shelf_exited := Callable(self, "_on_shelf_mouse_exited")

		if not interaction_area.mouse_entered.is_connected(shelf_entered):
			interaction_area.mouse_entered.connect(shelf_entered)

		if not interaction_area.mouse_exited.is_connected(shelf_exited):
			interaction_area.mouse_exited.connect(shelf_exited)

	var slots := get_node_or_null("Slots")

	if slots == null:
		return

	for i in range(max_slots):
		var slot_area := slots.get_node_or_null("Slot%d" % i) as Area2D

		if slot_area == null:
			continue

		slot_area.input_pickable = true
		var slot_entered := Callable(self, "_on_slot_mouse_entered").bind(i)
		var slot_exited := Callable(self, "_on_slot_mouse_exited")

		if not slot_area.mouse_entered.is_connected(slot_entered):
			slot_area.mouse_entered.connect(slot_entered)

		if not slot_area.mouse_exited.is_connected(slot_exited):
			slot_area.mouse_exited.connect(slot_exited)


func _on_shelf_mouse_entered() -> void:
	_is_shelf_hovered = true
	_show_cursor_tooltip(get_hover_display_name())


func _on_shelf_mouse_exited() -> void:
	_is_shelf_hovered = false
	_hide_cursor_tooltip()


func _on_slot_mouse_entered(slot_index: int) -> void:
	_show_cursor_tooltip(_get_slot_hover_name(slot_index))


func _on_slot_mouse_exited() -> void:
	if _is_shelf_hovered:
		_show_cursor_tooltip(get_hover_display_name())
	else:
		_hide_cursor_tooltip()


func _get_slot_hover_name(slot_index: int) -> String:
	var item_id := get_slot_content(slot_index)

	if item_id == "":
		return get_hover_display_name()

	var item := ItemDatabase.get_item(item_id)
	return item.display_name if item != null and item.display_name != "" else item_id.capitalize()


func _show_cursor_tooltip(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("show_cursor_tooltip"):
		hud.call("show_cursor_tooltip", text)


func _hide_cursor_tooltip() -> void:
	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null and hud.has_method("hide_cursor_tooltip"):
		hud.call("hide_cursor_tooltip")
